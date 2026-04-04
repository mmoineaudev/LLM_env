#!/bin/bash
# llama-install-for-ubuntu24.sh
# One-stop script for llama.cpp + CUDA on Ubuntu 24.04
# Run with: bash llama-install-for-ubuntu24.sh

set -e  # Exit on error

LLAMA_DIR="$HOME/llama.cpp"
BUILD_DIR="$LLAMA_DIR/build"

echo "=== Updating system packages ==="
sudo apt update && sudo apt upgrade -y

echo "=== Installing build dependencies ==="
sudo apt install -y \
    build-essential cmake git curl libcurl4-openssl-dev \
    python3 python3-pip

# Optional but recommended for better performance
sudo apt install -y ccache

# === NVIDIA Driver + CUDA Fallback Section ===
echo "=== Checking NVIDIA setup ==="

if ! command -v nvidia-smi &> /dev/null; then
    echo "NVIDIA driver not detected. Installing driver..."
    read -p "default is nvidia-driver-550, try nvidia-driver-570 or nvidia-driver-580 ? package name : " driver_version
    sudo apt install -y "$driver_version"  # or 570/580 depending on your GPU (check ubuntu-drivers devices)
    echo "Reboot required after driver install. Run this script again after reboot."
    exit 0
fi

# Get GPU compute capability (useful for CMAKE_CUDA_ARCHITECTURES)
COMPUTE_CAP=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -n1 | tr -d '.')
echo "Detected GPU compute capability: $COMPUTE_CAP"

# Install CUDA toolkit (prefer the version that matches your driver)
echo "=== Installing CUDA toolkit ==="
# Option 1: Use Ubuntu's nvidia-cuda-toolkit (simpler, but sometimes older) => not recommended
# sudo apt install -y nvidia-cuda-toolkit

# Option 2: Official NVIDIA repo (recommended for newer CUDA) - adjust version as needed
read -p "default is cuda-toolkit-13-0, try cuda-toolkit-13-2 ? package name : " cuda_toolkit_version
wget -qO- https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb | sudo dpkg -i -
sudo apt update
sudo apt install -y "$cuda_toolkit_version"   # or cuda-12-9, cuda-toolkit-13-0 etc. Match your driver!

# Add CUDA to PATH and LD_LIBRARY_PATH (add to ~/.bashrc if not present)
if ! grep -q "cuda" "$HOME/.bashrc"; then
    # Add CUDA to PATH (overwrite any existing CUDA path entries)
    sed -i '/export PATH=.*cuda/d' "$HOME/.bashrc"
    echo 'export PATH="/usr/local/cuda-13.2/bin:$PATH"' >> "$HOME/.bashrc"

    # Set LD_LIBRARY_PATH explicitly
    sed -i '/LD_LIBRARY_PATH/d' "$HOME/.bashrc"
    echo 'export LD_LIBRARY_PATH="/usr/local/cuda-13.2/lib64"' >> "$HOME/.bashrc"

    # Add CUDACXX (or CUDACCX for newer CUDA versions)
    sed -i '/CUDACXX/d' "$HOME/.bashrc"
    echo 'export CUDACXX=/usr/local/cuda-13.2/bin/nvcc' >> "$HOME/.bashrc"
fi
source "$HOME/.bashrc"

echo "=== Verifying CUDA ==="
nvcc --version
nvidia-smi

# === llama.cpp setup ===
echo "=== Setting up llama.cpp ==="

if [ ! -d "$LLAMA_DIR" ]; then
    git clone https://github.com/ggerganov/llama.cpp.git "$LLAMA_DIR"
else
    echo "Repository already exists. Pulling latest changes..."
    cd "$LLAMA_DIR"
    git pull
fi

cd "$LLAMA_DIR"

# Clean previous build to avoid stale CUDA detection issues
rm -rf "$BUILD_DIR"

echo "=== Configuring CMake with CUDA ==="
cmake -B "$BUILD_DIR" \
    -DGGML_CUDA=ON \
    -DCMAKE_CUDA_ARCHITECTURES="$COMPUTE_CAP" \   # or "all-major" or "75;80;86;89;90" for broader support
    -DLLAMA_CURL=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER_LAUNCHER=ccache \
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache

echo "=== Building (this can take 5-15+ minutes) ==="
cmake --build "$BUILD_DIR" --config Release -j "$(nproc)"

echo "=== Installing binaries to $HOME/bin for easy access ==="
mkdir -p "$HOME/bin"
cp "$BUILD_DIR"/bin/* "$HOME/bin/" 2>/dev/null || true

# Ensure PATH includes $HOME/bin (overwrite any existing entry)
if ! grep -q 'export PATH.*"$HOME/bin' "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
fi
source "$HOME/.bashrc"

echo "=== Installation complete! ==="
echo "Test with: llama-cli --help"
echo "Or run a quick benchmark: llama-bench -m <your-model.gguf> -ngl 99"
echo ""
echo "Tips:"
echo "- For faster rebuilds next time, just run the script again (it pulls + rebuilds)."
echo "- If build fails due to CUDA detection, try purging NVIDIA packages first:"
echo "  sudo apt purge -y 'nvidia-*' cuda* && sudo apt autoremove -y && reboot"
echo "- Consider adding -DGGML_CUDA_FA=ON for Flash Attention if your model benefits."
