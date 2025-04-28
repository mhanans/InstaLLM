#!/bin/bash

# Configuration
PYTHON_VERSION="3.10"
INSTALL_DIR="$(pwd)/install_dir"
CONDA_ROOT="${INSTALL_DIR}/conda"
ENV_DIR="${INSTALL_DIR}/env"
REQUIREMENTS_FILE="requirements.txt"

# Function to print highlighted messages
print_highlight() {
    echo -e "\n******************************************************"
    echo -e "$1"
    echo -e "******************************************************\n"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check path for spaces
check_path_for_spaces() {
    if [[ $PWD =~ \  ]]; then
        echo "The current workdir has whitespace which can lead to unintended behaviour. Please modify your path and continue later."
        exit 1
    fi
}

# Function to install Miniconda
install_miniconda() {
    # Miniconda installer is limited to two main architectures: x86_64 and arm64
    local sys_arch=$(uname -m)
    case "${sys_arch}" in
    x86_64*) sys_arch="x86_64" ;;
    arm64*) sys_arch="aarch64" ;;
    aarch64*) sys_arch="aarch64" ;;
    *) {
        echo "Unknown system architecture: ${sys_arch}! This script runs only on x86_64 or arm64"
        exit 1
    } ;;
    esac

    # if miniconda has not been installed, download and install it
    if ! "${CONDA_ROOT}/bin/conda" --version &>/dev/null; then
        if [ ! -d "$INSTALL_DIR/miniconda_installer.sh" ]; then
            echo "Downloading Miniconda from $miniconda_url"
            local miniconda_url="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-${sys_arch}.sh"

            mkdir -p "$INSTALL_DIR"
            curl -Lk "$miniconda_url" >"$INSTALL_DIR/miniconda_installer.sh"
        fi

        echo "Installing Miniconda to $CONDA_ROOT"
        chmod u+x "$INSTALL_DIR/miniconda_installer.sh"
        bash "$INSTALL_DIR/miniconda_installer.sh" -b -p "$CONDA_ROOT"
        rm -rf "$INSTALL_DIR/miniconda_installer.sh"
    fi
    echo "Miniconda is installed at $CONDA_ROOT"

    # test conda
    echo "Conda version: "
    "$CONDA_ROOT/bin/conda" --version || {
        echo "Conda not found. Will exit now..."
        exit 1
    }
}

# Function to create conda environment
create_conda_env() {
    if [ ! -d "${ENV_DIR}" ]; then
        echo "Creating conda environment with python=$PYTHON_VERSION in $ENV_DIR"
        "${CONDA_ROOT}/bin/conda" create -y -k --prefix "$ENV_DIR" python="$PYTHON_VERSION" || {
            echo "Failed to create conda environment."
            echo "Will delete the ${ENV_DIR} (if exist) and exit now..."
            rm -rf $ENV_DIR
            exit 1
        }
    else
        echo "Conda environment exists at $ENV_DIR"
    fi
}

# Function to activate conda environment
activate_conda_env() {
    # deactivate the current env(s) to avoid conflicts
    { conda deactivate && conda deactivate && conda deactivate; } 2>/dev/null

    # check if conda env is broken
    if [ ! -f "$ENV_DIR/bin/python" ]; then
        echo "Conda environment appears to be broken. You may need to remove $ENV_DIR and run the installer again."
        exit 1
    fi

    source "$CONDA_ROOT/etc/profile.d/conda.sh" # conda init
    conda activate "$ENV_DIR" || {
        echo "Failed to activate environment. Please remove $ENV_DIR and run the installer again."
        exit 1
    }
    echo "Activate conda environment at $CONDA_PREFIX"
}

# Function to deactivate conda environment
deactivate_conda_env() {
    if [ "$CONDA_PREFIX" == "$ENV_DIR" ]; then
        conda deactivate
        echo "Deactivate conda environment at $ENV_DIR"
    fi
}

# Function to verify package installation
verify_package() {
    local package=$1
    if ! python -c "import $package" 2>/dev/null; then
        echo "Failed to verify $package installation"
        return 1
    fi
    return 0
}

# Function to install dependencies
install_dependencies() {
    print_highlight "Installing Python dependencies..."
    
    # Install dependencies
    pip install --upgrade pip
    pip install -r $REQUIREMENTS_FILE

    # Verify installations
    print_highlight "Verifying package installations..."
    if ! verify_package "gradio"; then
        echo "Failed to install gradio"
        exit 1
    fi
    
    if ! verify_package "llama_cpp"; then
        echo "Failed to install llama-cpp-python"
        exit 1
    fi

    print_highlight "All packages installed successfully"
    
    # Clear cache
    conda clean --all -y
    python -m pip cache purge
}

# Function to create models directory
create_models_directory() {
    print_highlight "Creating models directory..."
    mkdir -p model
    echo "Models directory created at $(pwd)/model"
    echo "Please place your .gguf model files in this directory"
}

# Function to launch the Gradio interface
launch_interface() {
    print_highlight "Launching InstaLLM Gradio interface in your browser, please wait..."
    python app.py || {
        echo "Failed to launch interface. Will exit now..."
        exit 1
    }
}

# Main script execution
check_path_for_spaces

print_highlight "Setting up Miniconda"
install_miniconda

print_highlight "Creating conda environment"
create_conda_env
activate_conda_env

print_highlight "Installing requirements"
install_dependencies

print_highlight "Setting up models directory"
create_models_directory

print_highlight "Do you want to launch the web UI? [Y/N]"
read -p "Input> " launch
launch=${launch,,}
if [[ "$launch" == "yes" || "$launch" == "y" || "$launch" == "true" ]]; then
    launch_interface
else
    echo "Will exit now..."
    deactivate_conda_env
    echo "Please run the installer again to launch the UI."
    exit 0
fi

deactivate_conda_env
read -p "Press enter to continue" 