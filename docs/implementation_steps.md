# Implementation Steps — RoamingYourFriend

> Last updated: 2026-05-26

## Phase Overview

| Phase | Content | Status |
|-------|---------|--------|
| 1 | Python face cropping script | ✅ Complete |
| 2 | Swift project init + window skeleton | ✅ Complete |
| 3 | Character rendering (circular avatar + stick figure) | ✅ Complete |
| 4 | Global mouse tracking + heatmap | ✅ Complete |
| 5 | Q-learning roaming engine | ✅ Complete |
| 6 | SetupWindow UI (settings panel) | ✅ Complete |
| 7 | Python-Swift bridge | ✅ Complete |
| 8 | Menu bar + localization (zh/en) | ✅ Complete |
| 9 | Integration + permissions | ✅ Complete |
| 10 | Cockroach Man redesign + Q-learning anti-stuck | ✅ Complete |

---

## Phase 1: Python Face Cropping Script ✅

**Goal**: Write and debug `face_crop.py`:
1. Accept image path argument
2. Face detection and localization
3. Circular avatar cropping
4. Pixel art filter
5. Output cropped result

**Key Files**:
- `PythonScripts/face_crop.py` — main script (MediaPipe BlazeFace)
- `PythonScripts/face_crop_haar_backup.py` — OpenCV Haar Cascades backup
- `PythonScripts/blaze_face_short_range.tflite` — MediaPipe model (229KB, offline)

**Detection Approach**:

| Scheme | Engine | Keypoints | Status |
|--------|--------|-----------|--------|
| Current | MediaPipe BlazeFace (deep learning) | 6 points (eyes/nose/mouth/ears) | ✅ In use |
| Backup | OpenCV Haar Cascades | None (needs extra eye cascade) | Backup kept |

**MediaPipe Advantages**:
- Deep learning model, much higher accuracy than Haar Cascades
- Returns 6 keypoints per detection, good center consistency
- Significantly reduced detection variance across photos

**Image Processing Params** (current):
- Crop factor: `max(fw, fh) * 1.45` (~10% enlargement)
- Horizontal squeeze: 10% (better face-to-circle fit)
- Pixel filter: `pixel_block=6`

**Dependencies**: mediapipe, pillow, numpy (bundled via PyInstaller for distribution)

---

## Phase 2: Swift Project Init ✅

**Goal**: SPM project, transparent window setup

**Key Files**: `Package.swift`, `main.swift`, `AppDelegate.swift`, `CharacterWindow.swift`

**Build**: Use `build.sh` to create `.app` bundle (`build/RoamingYourFriend.app`).

---

## Phase 3: Character Rendering ✅

**Goal**: Draw circular avatar + stick figure body animation + speech bubble on transparent window

**Key Files**: `CharacterView.swift`
- `avatarImagePath`: set processed avatar image path
- `bubbleText`: set speech bubble text (driven by RoamingController)
- `drawSpeechBubble()`: programmatic bubble drawing (rounded rect + triangle tip)

---

## Phase 4: Global Mouse Tracking ✅

**Goal**: Track mouse movement and clicks, build heatmap

**Key Files**: `MouseTracker/MouseTracker.swift`, `MouseTracker/HeatmapGrid.swift`

---

## Phase 5: Q-learning Engine ✅

**Goal**: Implement Q-learning algorithm for autonomous character roaming

**Key Files**: `QLearning/QLearningEngine.swift`, `QLearning/RoamingController.swift`

**Message logic**: `RoamingController.step()` reads custom messages from `MessageStore.shared.activeMessages`. Falls back to 3 default messages when empty.

---

## Phase 6: SetupWindow UI ✅

**Goal**: Photo selection + preview + custom messages + history panel

**Key Files**: `SetupWindow.swift`, `SetupView.swift`

**Layout**: 560x440 frosted glass window, left-right two-column layout
- Left: PhotoContainer (128x144) + FlowArrow + PreviewContainer (128x144)
- Right: Title + Subtitle + MessagesHeader + 3 message cards + Hint + Buttons

**Components**: PhotoContainer, PreviewContainer, FlowArrow, MessagesHeader, MessagesCardRow (vertical, 3 cards), MessageHintRow, ButtonRow, HistoryPopover

**Key Fixes**:
- `NSBox.separator` -> `NSView` (avoid Auto Layout crash)
- Components built via `build*()` methods in `buildLayout()` (avoid constraint cycles)
- Message cards vertical layout, text and counter side by side
- HistoryPopover: NSPopover `.transient`, horizontally scrolling avatar list, click to restore

See [UI.md](UI.md) and [UI_improvement_suggestions.md](UI_improvement_suggestions.md).

---

## Phase 7: Python-Swift Bridge ✅

**Goal**: Swift calls Python script and gets results

**Key Files**: `PythonBridge/PythonBridge.swift`

**Flow**:
1. `SetupView.selectPhoto()` -> `AppDelegate.previewPhoto()`
2. `PythonBridge.process()` -> background thread runs standalone binary
3. `@MainActor` callback -> `SetupView.showProcessedPreview()`

---

## Phase 8: Menu Bar + Localization ✅

**Goal**: Menu bar icon, menu, Chinese/English bilingual UI

**Key Files**: `MainMenu.swift`, `Loc.swift`

---

## Phase 9: Integration ✅

**Completed**:
- SetupWindow/SetupView UI fully rewritten and verified
- Python bridge tested
- Custom messages -> MessageStore -> character bubble data flow verified
- History Popover (HistoryPopover)
- Face detection engine upgrade: OpenCV Haar -> MediaPipe BlazeFace
- Avatar crop tuning: center consistency, enlargement ratio, squeeze effect
- Pixel art character rendering: offscreen bitmap (1/3 scale, no antialiasing, nearest-neighbor) + full-res bubble text
- Message text fields: clear button (xmark.circle.fill) + copy/paste (Edit menu) + auto-focus fix
- Photo boxes narrowed (128x144) + gray dashed borders
- Layout tuning: right column centerX alignment + 12pt top spacing
- Preview loading indicator at bottom-center
- Display mode: after roaming starts, menu bar Settings -> 280x300 mini window shows full character + quit button
- Button hide using alphaValue (preserves layout stability)

---

## Phase 10: Cockroach Man Redesign ✅

**Goal**: Transform character into a funny "Cockroach Man" + fix Q-learning convergence stagnation

### Visual Redesign

| Element | Description |
|---------|-------------|
| Antennae x2 | Curved lines from top of head with bulb tips, independent wobble (2.3Hz) |
| Wings x2 | Semi-transparent oval wings (44x18pt, alpha 0.32), behind head, flutter (4.5Hz) |
| Six legs | Arms (upper) + middle legs + legs (lower), three pairs evenly around head circle |

All elements rendered via offscreen bitmap for unified pixel art style.

### Q-learning Anti-Stuck

- **Problem**: epsilon decays to 0.03, only 3% exploration, character stops seeking mouse after convergence
- **Solution**: RoamingController detects same-cell stay >= 40 steps (~14s), calls `QLearningEngine.boostExploration()` to reset epsilon to 0.35

### Text Updates

- Title: "RoamingYourFriend"
- Subtitle: "Select a photo with a human face, Let her/him become a Cockroach Man!"
- Button: "Let's Go!"

### Display Window Adjustment

- topPad 50pt -> 70pt, character fully visible without clipping

---

## Standalone Packaging

- PyInstaller bundles `face_crop.py` + mediapipe + pillow + numpy + .tflite model into a single 94MB binary
- `build.sh` copies the binary into `.app/Contents/Resources/`
- All writable data goes to `~/Library/Application Support/RoamingYourFriend/`
- Zero dependencies for end users — just download and run
