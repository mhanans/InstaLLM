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
if [ -f "build/bin/llama-cli" ]; then
    # Remove existing symlink if it exists
    if [ -L "bin/llama-cli" ]; then
        rm bin/llama-cli
    fi
    # Copy the binary directly
    cp build/bin/llama-cli bin/
    chmod +x bin/llama-cli
else
    echo "Error: llama-cli binary not found after build"
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

# Return to original directory
cd ..

print_highlight "Build fixes completed successfully!" 