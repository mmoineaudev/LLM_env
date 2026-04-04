#!/bin/bash
# llama-install-for-ubuntu24.sh
# One-stop script for llama.cpp + CUDA on Ubuntu 24.04
# Run with: bash llama-install-for-ubuntu24.sh

set -e  # Exit on error

LLAMA_DIR="$HOME/llama.cpp"
BUILD_DIR="$LLAMA_DIR/build"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper function for optional prompts
ask() {
    read -p "$1 (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Helper function for colored step titles with count
step_title() {
    local current=$1
    local total=$2
    local title=$3
    echo -e "${BLUE}=== Step ${current}/${total}: ${title} ===${NC}"
}

# Helper function for success message
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Helper function for skipped message
skipped() {
    echo -e "${YELLOW}⊘ Skipped: $1${NC}"
}

# ============================================================================
# STEP 0: DANGER! Purge Old NVIDIA/CUDA Packages (Optional)
# ============================================================================
step_purge_nvidia() {
    local current=0
    local total=8

    echo -e "${RED}============================================================${NC}"
    echo -e "${RED}         ⚠️  DANGER: NUKING NVIDIA/OLD CUDA PACKAGES ⚠️   ${NC}"
    echo -e "${RED}============================================================${NC}"

    if ask "WARNING: This will DELETE all NVIDIA and CUDA packages. Continue?"; then
        echo -e "${RED}⚠️  Purging NVIDIA and CUDA packages...${NC}"
        sudo apt purge -y 'nvidia-*' cuda* && sudo apt autoremove -y
        success "Old NVIDIA/CUDA packages removed"
        echo -e "${YELLOW}⚠️  Reboot recommended before continuing.${NC}"
    else
        skipped "NVIDIA/CUDA package purge"
    fi
}

# ============================================================================
# STEP 1: Update System Packages
# ============================================================================
step_update_packages() {
    local current=1
    local total=8

    step_title "$current" "$total" "Update System Packages"

    if ask "Update system packages"; then
        sudo apt update && sudo apt upgrade -y
        success "System packages updated"
    else
        skipped "System package update"
    fi
}

# ============================================================================
# STEP 2: Install Build Dependencies
# ============================================================================
step_install_dependencies() {
    local current=2
    local total=8

    step_title "$current" "$total" "Install Build Dependencies"

    if ask "Install build dependencies (cmake, git, etc.)"; then
        sudo apt install -y \
            build-essential cmake git curl libcurl4-openssl-dev \
            python3 python3-pip
        success "Build dependencies installed"
    else
        skipped "Build dependencies installation"
    fi
}

# ============================================================================
# STEP 3: Install ccache (Optional)
# ============================================================================
step_install_ccache() {
    local current=3
    local total=8

    step_title "$current" "$total" "Install ccache (Optional)"

    if ask "Install ccache for faster rebuilds"; then
        sudo apt install -y ccache
        success "ccache installed"
    else
        skipped "ccache installation"
    fi
}

# ============================================================================
# STEP 4: NVIDIA Driver Setup
# ============================================================================
step_nvidia_driver() {
    local current=4
    local total=8

    step_title "$current" "$total" "NVIDIA Driver Setup"

    echo -e "${CYAN}Checking NVIDIA setup...${NC}"

    if ! command -v nvidia-smi &> /dev/null; then
        if ask "NVIDIA driver not detected. Install NVIDIA driver?"; then
            echo "Installing NVIDIA driver..."
            read -p "default is nvidia-driver-550, try nvidia-driver-570 or nvidia-driver-580 ? package name : " driver_version
            sudo apt install -y "$driver_version"
            echo -e "${YELLOW}Reboot required after driver install. Run this script again after reboot.${NC}"
            exit 0
        else
            skipped "NVIDIA driver installation"
        fi
    else
        success "NVIDIA driver already detected"
    fi
}

# ============================================================================
# STEP 5: CUDA Toolkit Installation
# ============================================================================
step_cuda_toolkit() {
    local current=5
    local total=8

    step_title "$current" "$total" "CUDA Toolkit Installation"

    if command -v nvidia-smi &> /dev/null; then
        if ask "Install CUDA toolkit?"; then
            # Get GPU compute capability (useful for CMAKE_CUDA_ARCHITECTURES)
            COMPUTE_CAP=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -n1 | tr -d '.')
            echo -e "${CYAN}Detected GPU compute capability: ${COMPUTE_CAP}${NC}"

            echo "=== Installing CUDA toolkit ==="
            read -p "default is cuda-toolkit-13-0, try cuda-toolkit-13-2 ? package name : " cuda_toolkit_version
            wget -qO- https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb | sudo dpkg -i -
            sudo apt update
            sudo apt install -y "$cuda_toolkit_version"
            success "CUDA toolkit installed"

            # Configure CUDA environment variables
            if ask "Add CUDA to PATH and LD_LIBRARY_PATH in ~/.bashrc?"; then
                if ! grep -q "cuda" "$HOME/.bashrc"; then
                    sed -i '/export PATH=.*cuda/d' "$HOME/.bashrc"
                    echo 'export PATH="/usr/local/cuda-13.2/bin:$PATH"' >> "$HOME/.bashrc"

                    sed -i '/LD_LIBRARY_PATH/d' "$HOME/.bashrc"
                    echo 'export LD_LIBRARY_PATH="/usr/local/cuda-13.2/lib64"' >> "$HOME/.bashrc"

                    sed -i '/CUDACXX/d' "$HOME/.bashrc"
                    echo 'export CUDACXX=/usr/local/cuda-13.2/bin/nvcc' >> "$HOME/.bashrc"
                fi
                source "$HOME/.bashrc"
                success "CUDA environment configured in ~/.bashrc"
            else
                skipped "CUDA environment configuration"
            fi

            echo -e "${CYAN}=== Verifying CUDA ===${NC}"
            nvcc --version
            nvidia-smi
        else
            skipped "CUDA toolkit installation"
        fi
    fi
}

# ============================================================================
# STEP 6: llama.cpp Repository Setup
# ============================================================================
step_llama_repo() {
    local current=6
    local total=8

    step_title "$current" "$total" "llama.cpp Repository Setup"

    if ask "Clone/install llama.cpp repository?"; then
        echo "=== Setting up llama.cpp ==="

        if [ ! -d "$LLAMA_DIR" ]; then
            git clone https://github.com/ggerganov/llama.cpp.git "$LLAMA_DIR"
            success "Repository cloned to $LLAMA_DIR"
        else
            if ask "Repository already exists. Pull latest changes?"; then
                cd "$LLAMA_DIR"
                git pull
                success "Repository updated"
            else
                skipped "Pulling latest changes"
            fi
        fi

        cd "$LLAMA_DIR"
    else
        skipped "llama.cpp repository setup"
    fi
}

# ============================================================================
# STEP 7: Build llama.cpp with CUDA
# ============================================================================
step_build_llama() {
    local current=7
    local total=8

    step_title "$current" "$total" "Build llama.cpp with CUDA"

    if [ -d "$LLAMA_DIR" ]; then
        if ask "Build llama.cpp with CUDA support?"; then
            cd "$LLAMA_DIR"

            # Clean previous build to avoid stale CUDA detection issues
            rm -rf "$BUILD_DIR"

            echo "=== Configuring CMake with CUDA ==="
            cmake -B "$BUILD_DIR" \
                -DGGML_CUDA=ON \
                -DCMAKE_CUDA_ARCHITECTURES="$COMPUTE_CAP" \
                -DLLAMA_CURL=ON \
                -DCMAKE_BUILD_TYPE=Release \
                -DCMAKE_C_COMPILER_LAUNCHER=ccache \
                -DCMAKE_CXX_COMPILER_LAUNCHER=ccache

            echo "=== Building (this can take 5-15+ minutes) ==="
            cmake --build "$BUILD_DIR" --config Release -j "$(nproc)"
            success "llama.cpp built successfully"
        else
            skipped "llama.cpp build"
        fi
    else
        echo -e "${YELLOW}⊘ Skipping build: Repository not set up${NC}"
    fi
}

# ============================================================================
# STEP 8: Install Binaries to $HOME/bin
# ============================================================================
step_install_binaries() {
    local current=8
    local total=8

    step_title "$current" "$total" "Install Binaries to $HOME/bin"

    if [ -d "$BUILD_DIR" ] && [ -d "$LLAMA_DIR" ]; then
        if ask "Install binaries to $HOME/bin for easy access?"; then
            echo "=== Installing binaries to $HOME/bin ==="
            mkdir -p "$HOME/bin"
            cp "$BUILD_DIR"/bin/* "$HOME/bin/" 2>/dev/null || true

            if ! grep -q 'export PATH.*"$HOME/bin' "$HOME/.bashrc"; then
                echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
            fi
            source "$HOME/.bashrc"
            success "Binaries installed to $HOME/bin"
        else
            skipped "Binary installation to $HOME/bin"
        fi
    else
        echo -e "${YELLOW}⊘ Skipping binary installation: Build not completed${NC}"
    fi
}

# ============================================================================
# Main Script Execution
# ============================================================================

echo -e "${GREEN}"
echo "============================================================"
echo "   llama.cpp + CUDA Installation Script for Ubuntu 24.04   "
echo "============================================================"
echo -e "${NC}"

step_purge_nvidia
step_update_packages
step_install_dependencies
step_install_ccache
step_nvidia_driver
step_cuda_toolkit
step_llama_repo
step_build_llama
step_install_binaries

echo ""
echo -e "${GREEN}=== Installation Complete! ===${NC}"
echo "Test with: llama-cli --help"
echo "Or run a quick benchmark: llama-bench -m <your-model.gguf> -ngl 99"
echo ""
echo -e "${YELLOW}Tips:${NC}"
echo "- For faster rebuilds next time, just run the script again (it pulls + rebuilds)."
echo "- If build fails due to CUDA detection, try purging NVIDIA packages first:"
echo "  sudo apt purge -y 'nvidia-*' cuda* && sudo apt autoremove -y && reboot"
echo "- Consider adding -DGGML_CUDA_FA=ON for Flash Attention if your model benefits."
