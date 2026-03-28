# LLM Monitoring TUI - Use Case Checklist

## Goal
Build a modern TUI application for monitoring GPU and RAM usage with Git metrics, implemented in Python using Textual.

## Architectural Guidelines

### Project Structure
```
llm-monitoring/
├── main.py          # Entry point
├── app.py           # Textual application
├── gpu_monitor.py   # GPU metrics collection
├── ram_monitor.py   # RAM metrics collection
├── git_metrics.py   # Git metrics collection
├── USE_CASES/       # Use case specifications
└── tests/           # Unit tests
```

### Key Classes
- `GPUMonitor` - collects GPU data via nvidia-smi
- `RAMMonitor` - collects RAM data via /proc/meminfo
- `GitMetrics` - collects Git repository metrics
- `MonitorApp` - Textual application class
- `HelpOverlay` - help dialog component

### Patterns
- TDD approach: test first, implementation second
- One use case per commit (feat, then test)
- Atomic writes: complete UC before moving to next
- Error handling: graceful degradation, no crashes

### Dependencies
```
textual>=0.40.0
```

### Git Workflow
- Branch: feature/UC-XXX
- Commit: `feat: UC-XXX <description>`
- Commit: `test: UC-XXX <description>`
- Push after each commit

## Use Cases

### UC-001: GPU Data Collection
`USE_CASES/UC-001.md`
* [ ] implementation
* [ ] test

### UC-002: RAM Data Collection
`USE_CASES/UC-002.md`
* [ ] implementation
* [ ] test

### UC-003: Git Metrics Collection
`USE_CASES/UC-003.md`
* [ ] implementation
* [ ] test

### UC-004: TUI Application
`USE_CASES/UC-004.md`
* [ ] implementation
* [ ] test

## Feature Mapping

| User Feature | Use Cases |
|--------------|-----------|
| VRAM usage with progress bar | UC-001, UC-004 |
| GPU temperature and fan speed | UC-001, UC-004 |
| RAM usage with progress bar | UC-002, UC-004 |
| Git metrics | UC-003, UC-004 |
| Recent commits | UC-003, UC-004 |
| Keyboard controls | UC-004 |
| Auto-refresh | UC-004 |
| Resize aware | UC-004 |
| Clean UI | UC-004 |

## Progress Tracking

- **Data Collection Layer**: UC-001, UC-002, UC-003
- **Application Layer**: UC-004

## Notes

- Start with data collection (UC-001, UC-002, UC-003)
- Build UI skeleton (UC-004)
- Add interactions (UC-005)
- Add auto-refresh (UC-006)
- Test each UC before moving to next
- Push after every commit
