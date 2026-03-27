# llm-monitoring (Go + Bubble Tea)

Modern TUI implementation of the bash monitoring script using Go and Bubble Tea.

## Requirements

- Go 1.21+
- nvidia-smi (for GPU metrics)
- git

## Build

```bash
go build -o llm-monitoring .
```

## Run

```bash
./llm-monitoring
```

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

## Comparison with Bash Version

| Feature | Bash Version | Go Version |
|---------|--------------|------------|
| Lines of code | ~400 | ~350 |
| Dependencies | None | 3 libraries |
| Raw mode handling | Manual (stty) | Built-in |
| Input handling | `read -t` | Bubble Tea events |
| Signal handling | Basic | Full (SIGWINCH) |
| Terminal resize | No | Yes |
| Smooth updates | 5s intervals | Continuous |
| Cross-platform | Linux/macOS | Linux/macOS/Windows |

## Dependencies

- `bubbles` - TUI components (spinner)
- `bubbletea` - TUI framework
- `lipgloss` - Styling

## License

MIT
