# Requirements — RoamingYourFriend

## Project Name

RoamingYourFriend

## Description

A macOS desktop app featuring a character built from the user's photo (circular avatar + stick figure body). The character roams the desktop autonomously via Q-learning, learning to avoid mouse-click areas and gravitate toward high-activity zones.

## Core Features

### 1. Transparent Floating Window (Swift + AppKit)
- Borderless transparent window, always on top (or desktop level)
- Window size ~150x200 pixels (adjustable)
- Character drawn in window (circular avatar + stick figure animation)

### 2. Face Detection & Circular Cropping (Python subprocess)
- User selects a photo with a face
- Swift passes image path to Python script
- Python uses MediaPipe to detect face location
- Crops face region and converts to circular avatar
- Applies pixel art filter
- Outputs cropped image for Swift to display

### 3. Stick Figure Animation (Swift/Core Animation)
- Stick figure body extends from below the circular avatar
- Simple walk/idle animations (limb swinging)
- Character faces movement direction

### 4. Q-learning Autonomous Roaming
- State space: character position (discretized screen grid)
- Action space: up/down/left/right + stay (5 actions)
- Reward mechanism:
  - Moving toward high mouse-activity zones: positive reward
  - Getting hit by mouse click: negative reward
  - Exploration: small positive reward
- Character continuously learns and adapts

### 5. Global Mouse Tracking
- Track global mouse movement, record heatmap
- Track global mouse clicks, detect clicks on character
- Requires macOS Accessibility permission

### 6. Menu Bar Integration
- Menu bar icon showing app status
- Menu options: select photo, settings, quit, etc.

## Non-functional Requirements

- **Language support**: Auto-switch Chinese/English based on system language, fallback to English
- **Performance**: No impact on normal system use, CPU usage < 5%
- **Permissions**: Compliant requests for Accessibility and file access
- **Style**: macOS minimalist premium design

## User Stories

1. User launches app -> sees menu bar icon
2. User clicks "Select Photo" -> picks a photo with a face
3. App calls Python to crop face -> circular avatar appears on desktop
4. Stick figure character starts walking on desktop
5. Character observes mouse activity, gradually learns to approach frequent areas
6. User clicks character -> character gets "startled" and learns to avoid that area
