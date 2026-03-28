# llm-monitoring

Modern TUI implementation of the bash monitoring script ( LLM_env_scripts/llm-monitoring.sh ).

## Features

- **VRAM usage** with progress bar (nvidia-smi)
- **GPU temperature** and **fan speed**
- **RAM usage** with progress bar
- **Git metrics**: uncommitted lines, commit status, time since last commit
- **Recent commits** with timestamps
- **Keyboard controls**: q=quit, r=refresh, h=help, space=pause
- **Auto-refresh** every 5 seconds
- **Resize aware** - adapts to terminal size
- **Clean UI** with proper colors and spacing

## Implementation Plan (Python + textual)

### Prerequisites
- Python 3.9+
- Debian-based system with NVIDIA GPU and nvidia-smi available
- Git installed

### Setup Steps

1. Create project structure:
   ```
   llm-monitoring/
   ├── main.py
   ├── gpu_monitor.py      # nvidia-smi parsing
   ├── ram_monitor.py      # /proc/meminfo parsing
   ├── git_metrics.py      # git command wrappers
   └── app.py              # textual application
   ```

2. Install dependencies:
   ```bash
   pip install textual
   ```

3. Implement GPU monitoring:
   - Parse `nvidia-smi --query-gpu=memory.used,memory.total,temperature.gpu,fan.speed --format=csv`
   - Extract values using subprocess
   - Calculate VRAM percentage for progress bar

4. Implement RAM monitoring:
   - Read `/proc/meminfo` for MemTotal, MemAvailable
   - Calculate percentage usage

5. Implement Git metrics:
   - `git diff --stat` for uncommitted lines
   - `git log -1 --format=%ai` for last commit time
   - `git status` for staged/unstaged changes

6. Build TUI layout:
   - Use textual's Column layout
   - Progress widgets for VRAM and RAM
   - Static text for GPU metrics
   - Scrollable list for recent commits
   - Overlay for help dialog

7. Implement keyboard handlers:
   - `on_key` method for q, r, h, space
   - Auto-refresh timer using `set_interval`

### File Structure

- `main.py` - entry point, runs the app
- `gpu_monitor.py` - GPU metrics collection
- `ram_monitor.py` - RAM metrics collection
- `git_metrics.py` - Git metrics collection
- `app.py` - Textual application with UI rendering

## Requirements

- Python 3.9+
- textual library (`pip install textual`)
- NVIDIA drivers with nvidia-smi
- Git

## Running

```bash
python main.py
```

## Keyboard Controls

| Key | Action |
|-----|--------|
| q   | Quit application |
| r   | Refresh immediately |
| h   | Show help overlay |
| space | Pause/resume auto-refresh |

## License

MIT
