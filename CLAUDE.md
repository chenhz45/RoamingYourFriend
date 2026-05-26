# CLAUDE.md — RoamingYourFriend Development Guide

## Project Overview

macOS desktop pet app: user photos cropped into circular avatars + stick figure body, Q-learning autonomous roaming — avoids mouse click areas, gravitates toward high-activity zones.

## Tech Stack

- **Main app**: Swift + AppKit (transparent windows, animation, Q-learning, global mouse tracking, menu bar)
- **Face processing**: Standalone binary (PyInstaller-bundled Python: MediaPipe face detection + Pillow image processing)
- **Build**: Swift Package Manager + shell script

## Key Files

| Document | Path |
|----------|------|
| Requirements | [docs/requirements.md](docs/requirements.md) |
| Technical Design | [docs/technical_design.md](docs/technical_design.md) |
| Implementation Steps | [docs/implementation_steps.md](docs/implementation_steps.md) |
| Dev Logs | [dev_logs/](dev_logs/) |

## Development Workflow

1. **Step by step** — each module: confirm requirements → code → debug → user confirmation → next step
2. **Don't write large chunks at once** — focus on one sub-feature at a time
3. **Python parts need careful debugging** — test collaboratively with the user
4. **UI supports Chinese/English** — auto-switch based on system language, fallback to English
5. **macOS minimalist premium style** — follow Apple HIG, transparent/frosted glass effects, clean UI

## Dev Log Convention

After each dev session, create `dev_logs/YYYY-MM-DD.md` with:
- Completed items
- To-do items
- Issues encountered and solutions

## Notes

- Always use absolute paths
- Swift code should consider macOS version compatibility
- Global mouse tracking requires Accessibility permission
