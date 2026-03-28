# llm-monitoring

Modern TUI implementation of a multiple bash panel for agentic development in command line mode ( LLM_env_scripts/llm-monitoring.sh ).

## Features

- bash panels with a keyboard shortcut to enable changing focus
  - LEFT one uses half of the screen, displays a interactive bash terminal 
    - at the top of the LEFT one 
      - there is a small indicator of VRAM and RAM usage in % 
  - RIGHT-TOP and RIGHT-BOTTOM ones are different colors and display a interactive bash terminal
- **Resize aware** - adapts to terminal size
- **Clean UI** with proper colors and spacing

## Implementation Plan (Python + textual)

### Prerequisites
- Python 3.9+
- Debian-based system with NVIDIA GPU and nvidia-smi available
- Git installed


## Requirements

- Python 3.9+
- textual library (`pip install textual`)
- NVIDIA drivers with nvidia-smi
- Git

## Running

```bash
python main.py
```

## Development workflow 

-Strict TDD
-Minimal external dependancies
-versionning via git on current branch, commit and push after each development step. .gitignore must be present and up to date with current tech stack.
