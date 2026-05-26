# UI Components & Layout — RoamingYourFriend SetupWindow

> Last updated: 2026-05-26 (v5 — standalone packaging + cockroach man redesign)

---

## Build & Run

Must use `build.sh` to create the `.app` bundle:

```bash
bash build.sh && open build/RoamingYourFriend.app
```

---

## Modes

| Property | onboarding | display |
|----------|-----------|----------|
| Trigger | app launch | Menu bar Settings (after roaming starts) |
| Window size | 560pt x 440pt | **280pt x 300pt** |
| Photo selection | Enabled | Hidden |
| Let's Go! | Shown | Hidden |
| Custom messages | Shown (3 cards, editable) | Hidden |
| Character preview | Left side (80x80 circle) | **Full window centered** (150x180 CharacterView) |
| Quit | Shown | **Shown (only button)** |

---

## Window (SetupWindow)

| Property | Value |
|----------|-------|
| Background | `NSVisualEffectView` (`.windowBackground` + `.behindWindow`) |
| Corner radius | 20pt (`layer?.cornerRadius`, `masksToBounds: true`) |
| Title bar | Transparent (`titlebarAppearsTransparent`), close button only |
| Dragging | `isMovableByWindowBackground` |
| Level | `.floating` |
| Title | `Loc.appTitle` -> "RoamingYourFriend" |

---

## Onboarding Layout

```
SetupWindow (560x440, NSVisualEffectView)
└── SetupView (fills content)
    └── NSStackView root (horizontal, alignment: .centerY, spacing: 24pt)
        ├── LeftColumn (vertical, centerX, spacing 8pt, topSpacer 12pt)
        │   ├── PhotoContainer    (128x144) — image input, gray dashed border
        │   ├── FlowArrow         (arrow.down 16pt) — direction indicator
        │   └── PreviewContainer  (128x144) — processed preview, gray dashed border
        └── RightColumn (vertical, centerX, spacing 0, topSpacer 12pt)
            ├── TitleLabel           (20pt semibold, centered)
            ├── SubtitleLabel        (13pt secondary, centered)
            ├── MessagesHeader       ("Custom Messages" + 1pt separator)
            ├── MessagesCardRow      (3 vertical cards, 8pt spacing)
            ├── MessageHintRow       (info.circle + hint text)
            └── ButtonRow            (Let's Go! 150x34 + History + Quit)
```

---

## Display Layout

```
SetupWindow (280x300)
└── SetupView
    └── displayContainer (280x280, centered)
        └── NSStackView vertical (centerX, spacing 12)
            ├── topPad         (70pt — move character down, ensure antennae visible)
            ├── CharacterView  (150x180 — pixel art full character)
            └── Quit Button    (centered)
```

---

## Component List

### 1. PhotoContainer — Image Input

| Property | Value |
|----------|-------|
| Size | **128pt x 144pt** |
| Shape | Rounded rect, cornerRadius 20pt |
| Border | 1.5pt dashed (`[6, 3]`), `separatorColor`, drawn via `CAShapeLayer` |

**Empty state (dropStack)**:

| Child | Type | Content | Font | Color |
|-------|------|---------|------|-------|
| icon | NSImageView | SF Symbol `photo.badge.plus` **36pt** `.light` | — | `.tertiaryLabelColor` |
| label | NSTextField(label) | `Loc.choosePhoto` -> "Choose Photo" | **13pt** `.medium` | `.secondaryLabelColor` |
| hint | NSTextField(label) | `Loc.clickOrDragDrop` -> "Click or drag & drop" | 11pt `.regular` | `.tertiaryLabelColor` |
| stack spacing | — | **6pt** | — | — |

**Selected state**: originalImageView (Aspect Fill, cornerRadius 20pt, 0.2s cross-fade)

---

### 2. PreviewContainer — Processed Preview

| Property | Value |
|----------|-------|
| Size | **128pt x 144pt** |
| Shape | Rounded rect, cornerRadius 20pt |
| Border | 1.5pt dashed (`[6, 3]`), `separatorColor`, drawn via `CAShapeLayer` |

**Empty state (previewPlaceholder)**:

| Child | Description |
|-------|-------------|
| dashedCircle | 80x80 dashed circle (`[5, 3]`, `separatorColor 0.5`), cornerRadius 40 |
| label | "Preview", 11pt `.regular`, `.tertiaryLabelColor` |

**Processing**: spinner + `Loc.processing` -> "Processing...", **bottom-center** (statusLabel 16pt from bottom, spinner 8pt above)

**Processed**: 80x80 circular avatar (cornerRadius 40, white 2pt stroke, shadow offset(0,2) radius 8) + backButton (26x26 circle, semi-transparent black bg, arrow.uturn.backward, bottom-left of previewView)

---

### 3. MessagesCardRow — Custom Message Cards

| Property | Value |
|----------|-------|
| Container | NSStackView **vertical**, `.fillEqually`, spacing: **8pt** |
| Width | Fixed **256pt** |
| Count | 3 (from `MessageStore.maxMessages`) |

**Per-card internals** (horizontal stack, alignment `.centerY`, spacing 8):

| Child | Properties |
|-------|------------|
| textField | NSTextField, isBordered false, drawsBackground false, 13pt `.regular` |
| clearBtn | SF Symbol `xmark.circle.fill` 11pt, `.tertiaryLabelColor`, 16x16, one-click clear |
| counter | NSTextField(label), "0/50", 11pt, right-aligned, `.tertiaryLabelColor` |

**Interaction**: `NSTextFieldDelegate.controlTextDidChange` -> truncate > 50 + red + shake(0.1s), auto-save to `MessageStore`
Cmd+C/V/X/A supported via `NSApp.mainMenu` Edit menu

---

### 4. ButtonRow

| Button | Style | Font | Size | Color |
|--------|-------|------|------|-------|
| **Let's Go!** | Filled rounded, cornerRadius 10pt | 14pt `.semibold` | **150x34pt** | White on blue (`.controlAccentColor`) |
| History | Borderless, isBordered false | 12pt `.regular` | — | `.controlAccentColor` |
| Quit | Borderless, isBordered false | 12pt `.regular` | — | `.tertiaryLabelColor` |

Button spacing: 12pt

Mode switching uses `alphaValue = 0` + `isEnabled = false` (not `isHidden`), keeping layout stable.

---

## Vertical Spacing (RightColumn, onboarding)

| Region | Spacing |
|--------|---------|
| topSpacer -> titleLabel | — (12pt fixed height) |
| titleLabel -> subtitleLabel | 4pt |
| subtitleLabel -> messagesHeader | 20pt |
| messagesHeader -> messagesCardRow | 8pt |
| messagesCardRow -> messageHintRow | 6pt |
| messageHintRow -> buttonRow | 22pt |
| Left-right column gap | **24pt** |

---

## Pixel Art Character Rendering

CharacterView uses offscreen bitmap for unified pixel effect:

- **Render**: 1/3 resolution `NSBitmapImageRep`, antialiasing disabled (`setShouldAntialias(false)`)
- **Composite**: nearest-neighbor interpolation (`imageInterpolation = .none`) scale-up to original size
- **Bubble text**: drawn at full resolution after bitmap compositing, crisp and readable
- **Font**: `NSFont.monospacedSystemFont` (11pt) for pixel feel

### Character Elements (Cockroach Man)

| Element | Description |
|---------|-------------|
| Circular avatar | User photo (80x80 circle) |
| Antennae x2 | Curved lines + bulb tips, independent wobble (2.3Hz) |
| Wings x2 | Semi-transparent ovals (44x18pt, alpha 0.32), behind head, flutter (4.5Hz) |
| Arms x2 | Head sides, shifted up 6pt |
| Middle legs x2 | Between arms and legs |
| Legs x2 | Below head |
| Speech bubble | Pixel background + full-res text |

---

## Data Flow

### Image Processing

```
User selects photo
  -> selectPhoto(path)
    -> Input box: 0.2s cross-fade show original
    -> Preview box: bottom-center spinner + "Processing..."
    -> onPhotoSelected?(path)
      -> AppDelegate.previewPhoto()
        -> PythonBridge.process() (background thread, standalone face_crop binary)
        -> @MainActor callback
        -> showProcessedPreview()
          -> Preview: 0.25s fadeIn 80x80 circular avatar + backButton
          -> Let's Go! enabled

User clicks Let's Go!
  -> onStart?(path) -> AppDelegate.startCharacter()
    -> Close SetupWindow -> desktop character roaming begins

User clicks Menu bar Settings (while roaming)
  -> showSetupWindow(mode: .display)
    -> 280x300 mini window -> full character + quit button
```

### Custom Messages

```
User types messages in SetupView
  -> controlTextDidChange (NSTextFieldDelegate)
    -> Truncate > 50 chars + update counter + shake animation
    -> saveMessages() -> MessageStore.shared.messages = msgs
      -> MessageStore.didSet -> persist to messages.json

User clicks clear button (xmark)
  -> didTapClearMessage(_:)
    -> Clear field + reset counter + saveMessages()

Character roaming
  -> RoamingController.step()
    -> pool = MessageStore.shared.activeMessages (non-blank)
    -> Custom messages exist -> pick random one
    -> No custom messages -> use defaults
    -> view.bubbleText = selected message
    -> CharacterView draws bubble (pixel style border, full-res text)
```

### History

```
Python processing succeeds
  -> AppDelegate.previewPhoto() callback
    -> HistoryStore.shared.archiveProcessedAvatar(from: path) — copy to history dir
    -> HistoryStore.shared.add(originalPath:processedPath:) — save record
    -> view.historyEntries = HistoryStore.shared.allEntries

User clicks History button
  -> showHistoryPopover() -> horizontal scrolling avatar list
  -> Click history avatar -> restore original + processed -> Let's Go! enabled
```

---

## Key Implementation Details

### buildLayout Method Pattern

These components are built via methods in `buildLayout()` (avoid stored property init constraint cycles):

- `buildMessagesHeader()` — label + 1pt separator (NSView, not NSBox)
- `buildMessagesCardRow()` — 3 vertical cards with text fields + clear buttons + counters
- `buildMessageHintRow()` — info.circle + hint text
- `buildButtonRow()` — Let's Go! + History + Quit

### Mode Switching

`applyMode()` switches between `.onboarding` and `.display`:
- `.onboarding`: hide displayContainer, show rootStack, enable all interactions
- `.display`: hide rootStack, show displayContainer (character + quit), resize window to 280x300

### Light/Dark Mode

- `cardBackgroundColor`: dynamic `NSColor(name:block:)` -> light #F5F5F5 / dark #2C2C2C
- Photo box dashes: `separatorColor` (auto-adapts to appearance)
- `viewDidChangeEffectiveAppearance()`: triggers border redraw

### Text Field Edit Support

`LSUIElement = true` apps have no main menu bar, so Edit submenu (Cut/Copy/Paste/Select All) is added to `NSApp.mainMenu` for Cmd+C/V/X/A support.

### Data Storage

All writable data stored in `~/Library/Application Support/RoamingYourFriend/`:
- `avatar_user.png` — current processed avatar
- `history/` — archived avatars + `history.json`
- `history/messages.json` — custom messages
