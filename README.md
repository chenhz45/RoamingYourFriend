# RoamingYourFriend

A macOS desktop pet app: turn a friend's photo into a talking pixel-art "Cockroach Man" that roams your desktop autonomously via Q-learning — avoiding mouse-click areas and gravitating toward high-activity zones.

## Features

- **Face Cropping** — MediaPipe BlazeFace face detection, circular crop + pixel art filter
- **Pixel-art Cockroach Man** — circular avatar + antennae + semi-transparent wings + six-legged stick figure, unified pixel rendering
- **Q-learning Roaming** — epsilon-greedy reinforcement learning, learns from mouse distance, click penalties, and edge collisions
- **Global Mouse Tracking** — builds heatmap, character gravitates toward frequent mouse areas and avoids clicked zones
- **Anti-stuck** — detects prolonged inactivity, automatically boosts exploration to re-seek the mouse
- **Speech Bubble** — randomly displays custom messages when near the mouse
- **Bilingual** — auto-switches between English and Chinese based on system language
- **History** — previously processed avatars can be restored

## System Requirements

- macOS 14.0+
- Accessibility permission (for global mouse tracking)

## Quick Start

### Option A: Download Pre-built App (zero setup)

Download `RoamingYourFriend.app.zip` from [GitHub Releases](../../releases), unzip, and run. No Python or dependencies needed.

First launch: grant Accessibility permission in **System Settings → Privacy & Security → Accessibility**.

### Option B: Build from Source

```bash
# 1. Install Python dependencies (only needed if standalone binary is not pre-built)
pip3 install mediapipe pillow

# 2. Build & run
bash build.sh
open build/RoamingYourFriend.app
```

Note: `build.sh` auto-detects whether the standalone `face_crop` binary exists. If it does, it bundles it (zero deps for users). If not, it falls back to `python3` + the `.py` script.

### Build Standalone Binary (for zero-dependency distribution)

```bash
pip3 install pyinstaller
cd PythonScripts
pyinstaller --onefile \
  --add-data "blaze_face_short_range.tflite:." \
  --add-binary "$(python3 -c 'import mediapipe.tasks.c; import os; print(os.path.dirname(__file__))')/c/libmediapipe.dylib:mediapipe/tasks/c" \
  --hidden-import mediapipe.tasks.c \
  --name face_crop \
  face_crop.py
```

Then `bash build.sh` will bundle the standalone binary automatically.

## Project Structure

```
RoamingYourFriend/
├── Package.swift
├── build.sh
├── CLAUDE.md
├── README.md
├── docs/
│   ├── requirements.md
│   ├── technical_design.md
│   ├── implementation_steps.md
│   ├── UI.md
│   └── UI_improvement_suggestions.md
├── dev_logs/
├── PythonScripts/
│   ├── face_crop.py                    # Face detection & cropping (MediaPipe)
│   ├── face_crop_haar_backup.py        # Fallback (OpenCV Haar)
│   └── blaze_face_short_range.tflite   # MediaPipe model (offline)
└── Sources/RoamingYourFriend/
    ├── main.swift                       # Entry point
    ├── AppDelegate.swift                # App lifecycle + coordination
    ├── CharacterView.swift              # Pixel-art character rendering
    ├── CharacterWindow.swift            # Transparent roaming window
    ├── SetupWindow.swift                # Setup window
    ├── SetupView.swift                  # Setup UI (onboarding/display modes)
    ├── Loc.swift                        # Localization (en/zh)
    ├── MainMenu.swift                   # Menu bar
    ├── MessageStore.swift               # Custom message persistence
    ├── HistoryStore.swift               # Avatar history
    ├── MouseTracker/
    │   ├── MouseTracker.swift           # Global mouse event tracking
    │   └── HeatmapGrid.swift            # Heatmap data structure
    ├── QLearning/
    │   ├── QLearningEngine.swift        # Q-learning algorithm + anti-stuck
    │   └── RoamingController.swift      # Roaming decision loop
    └── PythonBridge/
        └── PythonBridge.swift           # Subprocess bridge (binary or script)
```

## Packaging for Distribution

```bash
bash build.sh
zip -r RoamingYourFriend.zip build/RoamingYourFriend.app
```

Upload the `.zip` to GitHub Releases. Users download and run — no setup required (the standalone binary includes Python + MediaPipe + all dependencies).

### macOS Code Signing (optional, requires Apple Developer account)

```bash
codesign --deep --force --verify --sign "Developer ID Application: <Name>" build/RoamingYourFriend.app
xcrun notarytool submit RoamingYourFriend.zip --apple-id <id> --team-id <tid> --wait
```

Unsigned apps: first launch requires Control-click → Open.

## Tech Stack

| Layer | Tech |
|-------|------|
| UI | Swift + AppKit (transparent window, NSVisualEffectView) |
| Algorithm | Q-learning (epsilon-greedy with decay + anti-stuck) |
| Face Detection | MediaPipe BlazeFace (bundled via PyInstaller) |
| Image Processing | Pillow (circular crop + pixel filter, bundled) |
| Build | Swift Package Manager + shell script |

## License

For personal use only.
