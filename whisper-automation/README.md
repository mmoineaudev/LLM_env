# whisper-automation.sh

Automated workflow for whisper.cpp installation, building, and audio transcription.

## Features

- **Flexible installation**: Clone whisper.cpp from GitHub if no path provided, or use existing installation
- **Automatic ffmpeg setup**: Detects and installs ffmpeg if missing (required for audio conversion)
- **Audio format support**: Automatically converts .mp4 and .mp3 files to .wav format
- **Model selection**: Choose from multiple whisper models (tiny through large-v3)
- **Language selection**: Supports 20+ languages for transcription
- **Clean transcript output**: Saves transcription without timestamps to a text file

## Usage

```bash
./whisper-automation.sh
```

## Workflow

1. **Installation Path**: Enter whisper.cpp installation path (press Enter to clone from GitHub)
2. **Build**: Automatically builds whisper.cpp using cmake
3. **ffmpeg Check**: Verifies ffmpeg is installed, installs if needed
4. **Audio File**: Provide path to .wav, .mp4, or .mp3 file
5. **Model Selection**: Choose from available whisper models
6. **Language**: Select language code for transcription
7. **Transcription**: Runs whisper-cli and outputs transcript
8. **Save**: Optionally save transcript to text file

## Available Models

| Model | Description |
|-------|-------------|
| tiny.en | English-only tiny model |
| tiny | Tiny model (all languages) |
| base.en | English-only base model |
| base | Base model (all languages) |
| small.en | English-only small model |
| small | Small model (all languages) |
| medium.en | English-only medium model |
| medium | Medium model (all languages) |
| large-v3 | Large v3 model (all languages, recommended) |
| large-v3-turbo | Large v3 turbo (faster) |

## Available Languages

| Code | Language | Code | Language |
|------|----------|------|----------|
| en | English | ja | Japanese |
| de | German | zh | Chinese |
| fr | French | ko | Korean |
| es | Spanish | tr | Turkish |
| it | Italian | ar | Arabic |
| pt | Portuguese | hi | Hindi |
| ru | Russian | pl | Polish |
| nl | Dutch | cs | Czech |
| ro | Romanian | sv | Swedish |
| hu | Hungarian | uk | Ukrainian |
| vi | Vietnamese | | |

## Requirements

- **git**: For cloning whisper.cpp repository
- **cmake**: For building whisper.cpp
- **build-essential** (Linux) or **Xcode Command Line Tools** (macOS): For compilation
- **ffmpeg**: For audio format conversion (auto-installed if missing)

## Installation Dependencies

### Ubuntu/Debian
```bash
sudo apt update
sudo apt install -y git cmake build-essential ffmpeg
```

### Fedora/RHEL
```bash
sudo dnf install -y git cmake gcc-c++ ffmpeg
```

### Arch Linux
```bash
sudo pacman -S --noconfirm git cmake base-devel ffmpeg
```

### macOS
```bash
brew install git cmake ffmpeg
```

## Example Session

```
==============================================
       whisper.cpp Automation Script
==============================================

[INFO] Step 1: Whisper.cpp Installation Path

Enter whisper.cpp installation path (press Enter to clone from GitHub): 

[INFO] No path provided. Cloning whisper.cpp from GitHub...
[INFO] Cloning whisper.cpp...
[SUCCESS] Whisper path: /home/neo/Desktop/TTS/wisper/whisper.cpp

[INFO] Step 2: Building whisper.cpp

[INFO] Running cmake configuration...
[INFO] Building (this may take a while)...
[SUCCESS] Build completed successfully

[INFO] Checking for ffmpeg installation...
[SUCCESS] ffmpeg is already installed: ffmpeg version 5.1

[INFO] Step 3: Audio File Selection

Enter path to audio file (.wav or .mp4): ~/Desktop/audio.mp4
[SUCCESS] Conversion successful: /home/neo/Desktop/audio.wav
[SUCCESS] Audio file: /home/neo/Desktop/audio.wav

[INFO] Step 4: Model Selection

Available models:
tiny.en    - English-only tiny model
...
[default: large-v3]

Enter model name (default: large-v3): 

[SUCCESS] Model: large-v3

[INFO] Step 5: Language Selection

Available languages:
en - English
...
[default: en for English]

Enter language code (default: en for English): 

[SUCCESS] Language: en

[INFO] Step 6: Transcription

[INFO] Running transcription (this may take a while)...

And so my fellow Americans, ask not what your country can do for you...

[SUCCESS] Transcription complete

[INFO] Step 7: Save Transcript

Do you want to save the transcript to a text file? (y/n): y
Enter filename (default: transcript.txt): 

[SUCCESS] Transcript saved to: transcript.txt

==============================================
           Workflow Complete
==============================================
```

## Notes

- The script automatically downloads the selected model if it doesn't exist
- If a transcript file with the same name exists, a timestamp is appended to the filename
- The final transcript is saved without timestamps for clean text output
- Building whisper.cpp on first run may take several minutes depending on hardware

## License

This script is provided as-is for personal use. whisper.cpp is licensed under the MIT License.
