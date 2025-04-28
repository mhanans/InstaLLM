#!/bin/bash

# Exit on error
set -e

# Function to print highlighted messages
print_highlight() {
    local message="${1}"
    echo "" && echo "******************************************************"
    echo "$message"
    echo "******************************************************" && echo ""
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

# Function to install system dependencies
install_system_dependencies() {
    print_highlight "Checking system dependencies..."
    
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
        # Create symlink for libgomp.so.1
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

# Function to install llama-cpp-python
install_llama_cpp_python() {
    print_highlight "Installing llama-cpp-python..."
    
    # Set OpenMP library path
    export LD_LIBRARY_PATH="/usr/lib:$LD_LIBRARY_PATH"
    
    # Install with OpenMP support
    CMAKE_ARGS="-DLLAMA_OPENMP=ON -DCMAKE_SHARED_LINKER_FLAGS='-Wl,-rpath,/usr/lib'" pip install llama-cpp-python --no-cache-dir
    
    # Verify installation
    python3 -c "import llama_cpp; print('llama-cpp-python installed successfully')"
}

# Main installation process
main() {
    print_highlight "Starting llama-cpp-python installation..."
    
    # Install system dependencies
    install_system_dependencies
    
    # Install llama-cpp-python
    install_llama_cpp_python
    
    print_highlight "Installation completed successfully!"
}

# Run main function
main 