#!/bin/bash

# Exit on error
set -e

# Configuration
INSTALL_DIR="$(pwd)/install_dir"
CONDA_ROOT="$INSTALL_DIR/conda"
ENV_DIR="$INSTALL_DIR/env"
PYTHON_VERSION="3.10"
MODEL_PATH="models/gemma-3-1b-it-q4_0.gguf"
MODEL_URL="https://drive.google.com/uc?export=download&id=14kzV0ObIq81fBYaWR1vRPIYEvm_UHXw5"

# Function to print highlighted messages
print_highlight() {
    local message="${1}"
    echo "" && echo "******************************************************"
    echo "$message"
    echo "******************************************************" && echo ""
}

# Function to check if path contains spaces
check_path_spaces() {
    if [[ "$1" == *" "* ]]; then
        echo "Error: Path contains spaces: $1"
        echo "Please use a path without spaces"
        exit 1
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a package is installed
package_installed() {
    if command_exists apt-get; then
        dpkg -l | grep -q "^ii  $1 "
    elif command_exists yum; then
        rpm -q "$1" >/dev/null 2>&1
    elif command_exists dnf; then
        dnf list installed "$1" >/dev/null 2>&1
    else
        return 1
    fi
}

# Function to wait for package manager lock
wait_for_package_manager() {
    print_highlight "Checking package manager status..."
    
    if command_exists apt-get; then
        while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
            echo "Waiting for package manager to be available..."
            sleep 5
        done
        
        while pgrep -f unattended-upgrade >/dev/null; do
            echo "Waiting for unattended-upgrades to complete..."
            sleep 5
        done
    fi
}

# Function to install system dependencies
install_system_dependencies() {
    print_highlight "Checking system dependencies..."
    
    wait_for_package_manager
    
    local packages=("build-essential" "cmake" "python3-dev" "libomp-dev" "libcurl4-openssl-dev")
    
    local to_install=()
    
    for pkg in "${packages[@]}"; do
        if ! package_installed "$pkg"; then
            to_install+=("$pkg")
        fi
    done
    
    if [ ${#to_install[@]} -eq 0 ]; then
        echo "All system dependencies are already installed."
        return
    fi
    
    echo "Installing missing system dependencies: ${to_install[*]}"
    
    if command_exists apt-get; then
        sudo apt-get update
        sudo apt-get install -y "${to_install[@]}"
        sudo ln -sf /usr/lib/x86_64-linux-gnu/libgomp.so.1 /usr/lib/libgomp.so.1
    elif command_exists yum; then
        sudo yum groupinstall -y "Development Tools"
        sudo yum install -y "${to_install[@]}"
    elif command_exists dnf; then
        sudo dnf groupinstall -y "Development Tools"
        sudo dnf install -y "${to_install[@]}"
    else
        echo "Error: Could not detect package manager. Please install the following packages manually:"
        echo "${packages[@]}"
        exit 1
    fi
}

# Function to check if a Python package is installed
python_package_installed() {
    pip show "$1" >/dev/null 2>&1
}

# Function to install Python dependencies
install_python_dependencies() {
    print_highlight "Checking Python dependencies..."
    
    # Set OpenMP library path
    export LD_LIBRARY_PATH="/usr/lib:$LD_LIBRARY_PATH"
    
    # Install llama-cpp-python with OpenMP support
    if ! python_package_installed "llama-cpp-python"; then
        echo "Installing llama-cpp-python from source with OpenMP support..."
        CMAKE_ARGS="-DLLAMA_OPENMP=ON -DCMAKE_SHARED_LINKER_FLAGS='-Wl,-rpath,/usr/lib'" pip install llama-cpp-python>=0.2.6 --no-cache-dir
    else
        echo "llama-cpp-python is already installed."
    fi
    
    # Install Gradio and other required packages
    echo "Installing Gradio and other dependencies..."
    pip install gradio>=4.0.0
    pip install typing-extensions
    pip install requests
    pip install numpy
    pip install huggingface_hub
}

# Function to install Miniconda
install_miniconda() {
    print_highlight "Checking Miniconda installation..."
    
    if [ -d "$CONDA_ROOT" ]; then
        echo "Miniconda is already installed at $CONDA_ROOT"
        return
    fi
    
    echo "Installing Miniconda..."
    check_path_spaces "$INSTALL_DIR"
    
    mkdir -p "$INSTALL_DIR"
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O "$INSTALL_DIR/miniconda.sh"
    bash "$INSTALL_DIR/miniconda.sh" -b -p "$CONDA_ROOT"
    rm "$INSTALL_DIR/miniconda.sh"
}

# Function to create and activate Conda environment
setup_conda_env() {
    print_highlight "Setting up Conda environment..."
    
    source "$CONDA_ROOT/etc/profile.d/conda.sh"
    
    if [ ! -d "$ENV_DIR" ]; then
        echo "Creating new Conda environment..."
        conda create -y -p "$ENV_DIR" python="$PYTHON_VERSION"
    else
        echo "Conda environment already exists at $ENV_DIR"
    fi
    
    conda activate "$ENV_DIR"
    
    if ! conda list | grep -q "^libgomp"; then
        echo "Installing OpenMP in conda environment..."
        conda install -y -c conda-forge libgomp
    else
        echo "OpenMP is already installed in conda environment."
    fi
}

# Function to find or build llama library
setup_llama_library() {
    print_highlight "Setting up llama library..."
    
    # Check common library locations
    local lib_paths=(
        "/usr/local/lib/libllama.so"
        "/usr/lib/libllama.so"
        "/usr/lib/x86_64-linux-gnu/libllama.so"
        "$(pwd)/libllama.so"
    )
    
    local found_path=""
    for path in "${lib_paths[@]}"; do
        if [ -f "$path" ]; then
            found_path="$path"
            echo "Found llama library at: $path"
            break
        fi
    done
    
    if [ -z "$found_path" ]; then
        echo "llama library not found. Building from source..."
        
        # Install build dependencies
        sudo apt-get update
        sudo apt-get install -y build-essential cmake libcurl4-openssl-dev
        
        # Clean up existing llama.cpp directory if it exists
        if [ -d "llama.cpp" ]; then
            echo "Cleaning up existing llama.cpp directory..."
            rm -rf llama.cpp
        fi
        
        # Clone and build llama.cpp
        git clone https://github.com/ggerganov/llama.cpp.git
        cd llama.cpp
        
        # Clean build directory if it exists
        if [ -d "build" ]; then
            echo "Cleaning up existing build directory..."
            rm -rf build
        fi
        
        mkdir build
        cd build
        
        # Configure with CURL support and shared library
        cmake .. -DLLAMA_CURL=ON -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=Release
        
        # Build the library
        make -j$(nproc)
        
        # Find the built library
        local built_lib=""
        if [ -f "libllama.so" ]; then
            built_lib="libllama.so"
        elif [ -f "bin/libllama.so" ]; then
            built_lib="bin/libllama.so"
        elif [ -f "../libllama.so" ]; then
            built_lib="../libllama.so"
        fi
        
        if [ -z "$built_lib" ]; then
            echo "Error: Could not find the built library"
            exit 1
        fi
        
        echo "Found built library at: $built_lib"
        
        # Copy the library to a known location
        sudo cp "$built_lib" /usr/local/lib/libllama.so
        sudo ldconfig
        
        found_path="/usr/local/lib/libllama.so"
        cd ../..
    fi
    
    # Verify the library exists
    if [ ! -f "$found_path" ]; then
        echo "Error: Failed to find or build llama library"
        exit 1
    fi
    
    echo "Using llama library at: $found_path"
    export LLAMA_LIB_PATH="$found_path"
}

# Function to download model file
download_model() {
    print_highlight "Checking model file..."
    
    if [ -f "$MODEL_PATH" ]; then
        echo "Model file already exists at $MODEL_PATH"
        return
    fi
    
    echo "Downloading model file..."
    mkdir -p "$(dirname "$MODEL_PATH")"
    wget -O "$MODEL_PATH" "$MODEL_URL"
}

# Function to run the Gradio app
run_gradio_app() {
    print_highlight "Starting Gradio app..."
    
    # Ensure we're in the correct environment
    source "$CONDA_ROOT/etc/profile.d/conda.sh"
    conda activate "$ENV_DIR"
    
    # Run the app
    python app.py
}

# Function to setup BitNet
setup_bitnet() {
    print_highlight "Setting up BitNet..."
    
    # Clone BitNet repository
    if [ ! -d "BitNet" ]; then
        git clone --recursive https://github.com/microsoft/BitNet.git
    fi
    
    cd BitNet
    
    # Install BitNet dependencies
    pip install -r requirements.txt
    
    # Create necessary directories and files
    mkdir -p include
    touch include/bitnet-lut-kernels.h
    
    # Build BitNet
    mkdir -p build
    cd build
    
    # Configure with specific options
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLAMA_OPENMP=ON \
        -DLLAMA_CURL=ON \
        -DBUILD_SHARED_LIBS=ON
    
    make -j$(nproc)
    
    # Create symlink to llama-cli
    cd ..
    ln -sf build/bin/llama-cli llama-cli
    
    # Check if model already exists
    if [ ! -f "models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf" ]; then
        # Download BitNet model only if it doesn't exist
        mkdir -p models
        huggingface-cli download microsoft/BitNet-b1.58-2B-4T-gguf --local-dir models/BitNet-b1.58-2B-4T
    else
        echo "BitNet model already exists, skipping download."
    fi
    
    # Setup BitNet environment
    python setup_env.py -md models/BitNet-b1.58-2B-4T -q i2_s
    
    # Return to original directory
    cd ..
    
    # Create symbolic link to the BitNet model with correct naming
    mkdir -p models
    cd models
    if [ -f "../BitNet/models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf" ]; then
        ln -sf ../BitNet/models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf ggml-model-i2_s.gguf
    fi
    cd ..
}

# Main installation process
main() {
    print_highlight "Starting installation process..."
    
    # Install system dependencies
    install_system_dependencies
    
    # Install Miniconda
    install_miniconda
    
    # Setup Conda environment
    setup_conda_env
    
    # Install Python dependencies
    install_python_dependencies
    
    # Setup llama library
    setup_llama_library
    
    # Setup BitNet
    setup_bitnet
    
    # Download model file
    download_model
    
    # Run the Gradio app
    run_gradio_app
}

# Run main function
main

# Create models directory if it doesn't exist
mkdir -p models

# Download Gemma model
echo "Downloading Gemma model..."
huggingface-cli download google/gemma-3-1b-it-gguf --local-dir models/gemma-3-1b-it

# Create a symbolic link to the model file
cd models
ln -s gemma-3-1b-it/gemma-3-1b-it-q4_0.gguf gemma-3-1b-it-q4_0.gguf
cd ..

echo "Setup complete! You can now run the application with:"
echo "conda activate gradio-env"
echo "python app.py"