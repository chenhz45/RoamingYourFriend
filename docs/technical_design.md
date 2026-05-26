# Technical Design — RoamingYourFriend

## System Architecture

```
┌─────────────────────────────────────────┐
│              macOS Desktop               │
│  ┌───────────────────────────────────┐  │
│  │     Swift Main App (AppKit)       │  │
│  │  ┌──────────┐  ┌───────────────┐  │  │
│  │  │Transparent│  │ Menu Bar Ctrl │  │  │
│  │  │ Window    │  │ (NSStatusBar) │  │  │
│  │  │(Character)│  │               │  │  │
│  │  └──────────┘  └───────────────┘  │  │
│  │  ┌──────────┐  ┌───────────────┐  │  │
│  │  │ Q-learning│  │ Global Mouse  │  │  │
│  │  │ Engine    │  │ (CGEvent)     │  │  │
│  │  └──────────┘  └───────────────┘  │  │
│  │  ┌──────────────────────────────┐ │  │
│  │  │ Standalone Binary Caller     │ │  │
│  │  │ (Process runs face_crop bin) │ │  │
│  │  └──────────────────────────────┘ │  │
│  └───────────────────────────────────┘  │
│              ↕ subprocess                │
│  ┌───────────────────────────────────┐  │
│  │  face_crop (PyInstaller binary)   │  │
│  │  - MediaPipe Face Detection       │  │
│  │  - Pillow circular crop + pixel   │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## Tech Stack

### Swift Side
- **Frameworks**: AppKit, Core Animation, Core Graphics
- **Window**: NSWindow (borderless, transparent, floating)
- **Animation**: Timer-based (60fps) with offscreen bitmap rendering
- **Mouse tracking**: CGEvent.tapCreate (requires Accessibility permission)
- **Subprocess**: Foundation.Process (calls standalone binary)

### Face Processing
- **Binary**: PyInstaller-bundled standalone executable
- **Face detection**: MediaPipe Face Detection (BlazeFace short-range model)
- **Backup**: OpenCV Haar Cascades (`face_crop_haar_backup.py`, kept for reference)
- **Image processing**: Pillow (PIL)
- **Pixel filter**: Pillow resize + NEAREST resampling
- **Dependencies**: All bundled in the binary — no Python/pip required by end users

## Data Flow

```
User selects photo -> Swift gets image path
  -> Swift calls face_crop binary (subprocess)
  -> Binary: load image -> MediaPipe detect face -> circular crop -> pixel filter -> save output
  -> Binary returns result via stdout
  -> Swift reads output image -> renders on transparent window
```

## Q-learning Design

### State Space
- Screen divided into N x M grid
- State = (gridX, gridY) — the character's grid coordinate
- Additional dimension: mouse heatmap zone

### Action Space
- 0: up, 1: down, 2: left, 3: right, 4: stay

### Reward Function
- Move toward high-heat zone: positive
- Move toward low-heat zone: small positive
- Clicked by mouse: -50
- Hit screen edge: -5

### Parameters
- Learning rate α = 0.2
- Discount factor γ = 0.9
- Exploration rate ε = 0.08 (ε-greedy with decay to min 0.03)

### Anti-Stuck Mechanism
- Detects same-cell stay >= 40 steps (~14 seconds)
- Temporarily boosts epsilon to 0.35 to force re-exploration

## Window Design

- Size: ~150 x 200 pt
- Background: fully transparent (NSColor.clear)
- Level: NSFloatingWindowLevel
- Mouse events pass through (except character area)
- NSVisualEffectView optional frosted glass

## Project Structure

```
RoamingYourFriend/
├── CLAUDE.md
├── README.md
├── Package.swift
├── build.sh
├── docs/
│   ├── requirements.md
│   ├── technical_design.md
│   ├── implementation_steps.md
│   ├── UI.md
│   └── UI_improvement_suggestions.md
├── dev_logs/
├── PythonScripts/
│   ├── face_crop.py
│   ├── face_crop_haar_backup.py
│   ├── blaze_face_short_range.tflite
│   └── dist/
│       └── face_crop          # PyInstaller standalone binary
└── Sources/RoamingYourFriend/
    ├── main.swift
    ├── AppDelegate.swift
    ├── CharacterView.swift
    ├── CharacterWindow.swift
    ├── SetupView.swift
    ├── SetupWindow.swift
    ├── Loc.swift
    ├── MainMenu.swift
    ├── MessageStore.swift
    ├── HistoryStore.swift
    ├── MouseTracker/
    │   ├── MouseTracker.swift
    │   └── HeatmapGrid.swift
    ├── QLearning/
    │   ├── QLearningEngine.swift
    │   └── RoamingController.swift
    └── PythonBridge/
        └── PythonBridge.swift
```

## Data Storage

All writable user data stored in `~/Library/Application Support/RoamingYourFriend/`:
- `avatar_user.png` — current processed avatar
- `history/` — archived processed avatars
- `history/history.json` — history record index
- `history/messages.json` — custom messages
