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

print_highlight "Fixing BitNet build issues..."

# Remove existing BitNet directory if it exists
if [ -d "BitNet" ]; then
    echo "Removing existing BitNet directory..."
    rm -rf BitNet
fi

# Clone fresh BitNet repository
git clone --recursive https://github.com/microsoft/BitNet.git

cd BitNet

# Create necessary directories and files
mkdir -p include
touch include/bitnet-lut-kernels.h

# Create build directory
mkdir -p build
cd build

# Configure with specific options and warning suppression
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLAMA_OPENMP=ON \
    -DLLAMA_CURL=ON \
    -DBUILD_SHARED_LIBS=ON \
    -DLLAMA_NATIVE=OFF \
    -DLLAMA_AVX=ON \
    -DLLAMA_AVX2=ON \
    -DLLAMA_F16C=ON \
    -DLLAMA_FMA=ON \
    -DCMAKE_CXX_FLAGS="-Wno-unused-parameter -Wno-unused-variable -Wno-deprecated-declarations -Wno-unknown-pragmas -Wno-overflow"

# Build the project
make -j$(nproc)

# Create bin directory and copy llama-cli
cd ..
mkdir -p bin

# Handle llama-cli binary
if [ -f "build/bin/llama-cli" ]; then
    echo "Copying llama-cli binary..."
    # Remove any existing file or symlink in bin directory
    rm -f bin/llama-cli
    # Copy the binary directly
    cp -f build/bin/llama-cli bin/
    chmod +x bin/llama-cli
    
    # Verify the copy was successful and the binary is executable
    if [ -x "bin/llama-cli" ]; then
        echo "Successfully copied and verified llama-cli binary"
        echo "Binary location: $(pwd)/bin/llama-cli"
        echo "Binary permissions: $(ls -l bin/llama-cli)"
    else
        echo "Error: Failed to copy or make llama-cli binary executable"
        exit 1
    fi
else
    echo "Error: llama-cli binary not found in build/bin/"
    echo "Current directory: $(pwd)"
    echo "Build directory contents:"
    ls -la build/bin/
    exit 1
fi

# Download model if it doesn't exist
if [ ! -f "models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf" ]; then
    echo "Downloading BitNet model..."
    mkdir -p models
    huggingface-cli download microsoft/BitNet-b1.58-2B-4T-gguf --local-dir models/BitNet-b1.58-2B-4T
else
    echo "BitNet model already exists, skipping download."
fi

# Setup BitNet environment
python setup_env.py -md models/BitNet-b1.58-2B-4T -q i2_s

# Verify final setup
echo "Verifying final setup..."
if [ -x "bin/llama-cli" ]; then
    echo "llama-cli is present and executable"
else
    echo "Error: llama-cli is not present or not executable in final setup"
    exit 1
fi

# Return to original directory
cd ..

print_highlight "Build fixes completed successfully!" 