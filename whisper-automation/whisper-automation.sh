#!/bin/bash

# ==============================================================================
# whisper-automation.sh
# ==============================================================================
# A script to automate whisper.cpp installation and transcription workflow.
# 
# Features:
# - Prompts for whisper.cpp installation path (clones if empty)
# - Manual build process following whisper.cpp documentation
# - Verifies/installs ffmpeg for audio format conversion
# - Converts .mp4 to .wav if needed
# - Allows model and language selection
# - Transcribes audio and saves transcript without timestamps
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ==============================================================================
# Check if ffmpeg is installed, install if not
# ==============================================================================
check_and_install_ffmpeg() {
    log_info "Checking for ffmpeg installation..."
    
    if command -v ffmpeg &> /dev/null; then
        log_success "ffmpeg is already installed: $(ffmpeg -version | head -n1)"
        return 0
    fi
    
    log_warn "ffmpeg is not installed. Installing now..."
    
    # Detect OS and install accordingly
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux - detect distribution
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y ffmpeg
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y ffmpeg
        elif command -v yum &> /dev/null; then
            sudo yum install -y ffmpeg
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm ffmpeg
        else
            log_error "Could not detect package manager. Please install ffmpeg manually."
            return 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install ffmpeg
        else
            log_error "Homebrew not found. Please install ffmpeg manually (brew install ffmpeg)"
            return 1
        fi
    else
        log_error "Unsupported OS: $OSTYPE"
        return 1
    fi
    
    if command -v ffmpeg &> /dev/null; then
        log_success "ffmpeg installed successfully"
    else
        log_error "Failed to install ffmpeg"
        return 1
    fi
}

# ==============================================================================
# Convert mp4 to wav using ffmpeg
# ==============================================================================
convert_mp4_to_wav() {
    local input_file="$1"
    local output_file="${input_file%.*}.wav"
    
    log_info "Converting $input_file to WAV format..."
    
    ffmpeg -y -i "$input_file" -ar 16000 -ac 1 -c:a pcm_s16le "$output_file" 2>/dev/null
    
    if [[ -f "$output_file" ]]; then
        log_success "Conversion successful: $output_file"
        echo "$output_file"
    else
        log_error "Conversion failed"
        return 1
    fi
}

# ==============================================================================
# Download whisper model
# ==============================================================================
download_model() {
    local model_name="$1"
    local whisper_path="$2"
    
    log_info "Downloading model: $model_name"
    
    if [[ -f "$whisper_path/models/download-ggml-model.sh" ]]; then
        cd "$whisper_path"
        sh ./models/download-ggml-model.sh "$model_name"
        cd - > /dev/null
    else
        log_error "Model download script not found. Please download manually."
        return 1
    fi
}

# ==============================================================================
# Get available models
# ==============================================================================
get_available_models() {
    echo "tiny.en    - English-only tiny model"
    echo "tiny       - Tiny model (all languages)"
    echo "base.en    - English-only base model"
    echo "base       - Base model (all languages)"
    echo "small.en   - English-only small model"
    echo "small      - Small model (all languages)"
    echo "medium.en  - English-only medium model"
    echo "medium     - Medium model (all languages)"
    echo "large-v3   - Large v3 model (all languages, recommended)"
    echo "large-v3-turbo - Large v3 turbo (faster)"
}

# ==============================================================================
# Get available languages
# ==============================================================================
get_available_languages() {
    echo "en - English"
    echo "de - German"
    echo "fr - French"
    echo "es - Spanish"
    echo "it - Italian"
    echo "pt - Portuguese"
    echo "ru - Russian"
    echo "ja - Japanese"
    echo "zh - Chinese"
    echo "nl - Dutch"
    echo "ko - Korean"
    echo "tr - Turkish"
    echo "ar - Arabic"
    echo "hi - Hindi"
    echo "pl - Polish"
    echo "cs - Czech"
    echo "ro - Romanian"
    echo "hu - Hungarian"
    echo "sv - Swedish"
    echo "uk - Ukrainian"
    echo "vi - Vietnamese"
}

# ==============================================================================
# Main workflow
# ==============================================================================
main() {
    echo ""
    echo "=============================================="
    echo "       whisper.cpp Automation Script"
    echo "=============================================="
    echo ""
    
    # Step 1: Get whisper installation path
    log_info "Step 1: Whisper.cpp Installation Path"
    echo ""
    read -p "Enter whisper.cpp installation path (press Enter to clone from GitHub): " whisper_path
    
    if [[ -z "$whisper_path" ]]; then
        log_info "No path provided. Cloning whisper.cpp from GitHub..."
        
        # Clone whisper.cpp
        whisper_path="$HOME/Desktop/TTS/wisper/whisper.cpp"
        
        if [[ -d "$whisper_path/.git" ]]; then
            log_info "whisper.cpp already exists. Pulling latest changes..."
            cd "$whisper_path"
            git pull --rebase
            cd - > /dev/null
        else
            log_info "Cloning whisper.cpp..."
            git clone https://github.com/ggml-org/whisper.cpp.git "$whisper_path"
        fi
    else
        # Validate path
        if [[ ! -d "$whisper_path" ]]; then
            log_error "Path does not exist: $whisper_path"
            exit 1
        fi
        
        if [[ ! -d "$whisper_path/.git" ]]; then
            log_warn "This directory doesn't appear to be a git repository."
            read -p "Continue anyway? (y/n): " confirm
            if [[ "$confirm" != "y" ]]; then
                exit 0
            fi
        fi
    fi
    
    log_success "Whisper path: $whisper_path"
    echo ""
    
    # Step 2: Build whisper.cpp
    log_info "Step 2: Building whisper.cpp"
    echo ""
    
    cd "$whisper_path"
    
    # Check if build already exists
    whisper_cli="$whisper_path/build/bin/whisper-cli"
    if [[ -f "$whisper_cli" ]]; then
        log_success "Build already exists: $whisper_cli"
        read -p "Rebuild anyway? (y/n): " rebuild
        if [[ "$rebuild" == "y" ]]; then
            log_info "Cleaning previous build..."
            rm -rf build
        else
            log_info "Skipping build..."
            cd - > /dev/null
            echo ""
        fi
    fi
    
    # Only build if not skipped
    if [[ ! -f "$whisper_cli" ]] || [[ "$rebuild" == "y" ]]; then
        # Clean previous build
        if [[ -d "build" ]]; then
            log_info "Cleaning previous build..."
            rm -rf build
        fi
        
        # Configure and build
        log_info "Running cmake configuration..."
        cmake -B build
        
        log_info "Building (this may take a while)..."
        cmake --build build -j --config Release
        
        if [[ $? -eq 0 ]]; then
            log_success "Build completed successfully"
        else
            log_error "Build failed"
            exit 1
        fi
    fi
    
    cd - > /dev/null
    echo ""
    
    # Step 3: Check/install ffmpeg
    if ! check_and_install_ffmpeg; then
        log_error "ffmpeg is required for audio processing"
        exit 1
    fi
    echo ""
    
    # Step 4: Get audio file path
    log_info "Step 3: Audio File Selection"
    echo ""
    read -p "Enter path to audio file (.wav or .mp4): " audio_file
    
    if [[ ! -f "$audio_file" ]]; then
        log_error "File not found: $audio_file"
        exit 1
    fi
    
    # Convert mp4 to wav if needed
    wav_file="$audio_file"
    if [[ "$audio_file" == *.mp4 || "$audio_file" == *.mp3 ]]; then
        wav_file=$(convert_mp4_to_wav "$audio_file")
        if [[ $? -ne 0 ]]; then
            log_error "Failed to convert audio file"
            exit 1
        fi
    elif [[ "$audio_file" != *.wav ]]; then
        log_warn "Unsupported file format: ${audio_file##*.}. Expected .wav, .mp4, or .mp3"
        read -p "Continue with original file? (y/n): " confirm
        if [[ "$confirm" != "y" ]]; then
            exit 0
        fi
    fi
    
    log_success "Audio file: $wav_file"
    echo ""
    
    # Step 5: Select model
    log_info "Step 4: Model Selection"
    echo ""
    echo "Available models:"
    get_available_models
    echo ""
    read -p "Enter model name (default: large-v3): " model_name
    
    if [[ -z "$model_name" ]]; then
        model_name="large-v3"
    fi
    
    # Check if model exists, download if not
    model_path="$whisper_path/models/ggml-${model_name}.bin"
    if [[ ! -f "$model_path" ]]; then
        log_warn "Model not found. Downloading $model_name..."
        download_model "$model_name" "$whisper_path"
    fi
    
    log_success "Model: $model_name"
    echo ""
    
    # Step 6: Optional model download helper
    log_info "Step 5: Model Download Helper"
    echo ""
    echo "Download more models before continuing?"
    echo "Available models:"
    get_available_models
    echo ""
    read -p "Download a model now? (y/n, default: n): " download_more
    
    if [[ "$download_more" == "y" ]]; then
        read -p "Enter model name: " extra_model
        if [[ -n "$extra_model" ]]; then
            download_model "$extra_model" "$whisper_path"
            log_success "Model downloaded: $extra_model"
        fi
    else
        log_info "Skipping model download"
    fi
    echo ""
    
    # Step 7: Select language
    log_info "Step 6: Language Selection"
    echo ""
    echo "Available languages:"
    get_available_languages
    echo ""
    read -p "Enter language code (default: en for English): " lang_code
    
    if [[ -z "$lang_code" ]]; then
        lang_code="en"
    fi
    
    log_success "Language: $lang_code"
    echo ""
    
    # Step 8: Transcribe
    log_info "Step 7: Transcription"
    echo ""
    
    whisper_cli="$whisper_path/build/bin/whisper-cli"
    
    if [[ ! -f "$whisper_cli" ]]; then
        log_error "whisper-cli not found at: $whisper_cli"
        exit 1
    fi
    
    log_info "Running transcription (this may take a while)..."
    echo ""
    
    # Run whisper with selected model, language, and file
    "$whisper_cli" \
        -m "$model_path" \
        -f "$wav_file" \
        -l "$lang_code" \
        --no-timestamps 2>/dev/null
    
    echo ""
    log_success "Transcription complete"
    echo ""
    
    # Step 9: Save transcript
    log_info "Step 8: Save Transcript"
    echo ""
    
    read -p "Do you want to save the transcript to a text file? (y/n): " save_transcript
    
    if [[ "$save_transcript" == "y" ]]; then
        read -p "Enter filename (default: transcript.txt): " filename
        
        if [[ -z "$filename" ]]; then
            filename="transcript.txt"
        fi
        
        # Get timestamp for unique filename if file exists
        if [[ -f "$filename" ]]; then
            timestamp=$(date +%Y%m%d_%H%M%S)
            filename="transcript_${timestamp}.txt"
            log_info "File exists. Using: $filename"
        fi
        
        # Re-run to capture output (since we can't easily capture from previous run)
        transcript=$("$whisper_cli" -m "$model_path" -f "$wav_file" -l "$lang_code" --no-timestamps 2>/dev/null)
        
        echo "$transcript" > "$filename"
        log_success "Transcript saved to: $filename"
    else
        log_info "Transcript not saved"
    fi
    
    echo ""
    echo "=============================================="
    echo "           Workflow Complete"
    echo "=============================================="
}

# Run main function
main "$@"
