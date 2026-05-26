# SetupWindow Layout Improvement Suggestions

> Analysis of issues in v1 (640x360 horizontal layout). All issues resolved in v3 rewrite.

---

## Issue 1: Input/Preview box proportions ✅ Fixed

**Before**: 192x128pt (1.5:1 ratio), photos heavily cropped.
**Fix**: Changed to 200x180pt, near-square ratio, better photo fit.

---

## Issue 2: Left-right column visual weight imbalance ✅ Fixed

**Before**: Left 200pt, right 312pt, 36pt gap felt hollow.
**Fix**: Reduced gap to 24pt, left boxes 200x180, right message cards 256pt wide.

---

## Issue 3: Window ratio doesn't match macOS settings panel conventions ✅ Fixed

**Before**: 640x360 is 16:9 landscape ratio.
**Fix**: Changed to 560x440, closer to 4:3, more comfortable visually.

---

## Issue 4: Empty preview box is pure visual noise ✅ Fixed

**Before**: Before photo selection, preview was just an empty bordered rect.
**Fix**: Added 96x96 dashed circle placeholder + "Preview" label.

---

## Issue 5: Input -> preview lacks visual association ✅ Fixed

**Before**: Two boxes with different border styles, looked unrelated.
**Fix**: Added SF Symbol `arrow.down` 16pt between boxes suggesting "input -> process -> output" flow.

---

## Issue 6: Right column top lacks visual anchor ✅ Fixed

**Before**: Title "Create Your Companion" floating alone at top of right column.
**Fix**: Title 20pt semibold for visual weight.

---

## Issue 7: Custom message card area lacks grouping ✅ Fixed

**Before**: Message cards directly below subtitle with no section header.
**Fix**: Added "Custom Messages" section header (12pt semibold) + 1pt separator. Uses `NSView` (not `NSBox.separator`) to avoid Auto Layout constraint cycle crashes.

---

## Issue 8: Button row alignment unnatural ✅ Fixed

**Before**: Buttons left-aligned in right column, main CTA not prominent.
**Fix**: Let's Go! button 150x34pt, blue fill, white text. History and Quit as borderless text buttons.

---

## Issue 9: Input box drag-drop area too sparse ✅ Fixed

**Before**: 28pt icon + two lines of small text in 192x128 box was sparse.
**Fix**: Icon enlarged to 36pt, box enlarged to 200x180.

---

## Issue 10: Preview circle too much empty space ✅ Fixed

**Before**: 80pt circle in 192x128 box, uneven margins.
**Fix**: Preview circle enlarged to 96pt, back button placed bottom-left of circle. Box 200x180.

---

## Issue 11: Card borders in light/dark mode ✅ Fixed

**Before**: Preview box used `.separatorColor` solid border, could be too prominent in dark mode.
**Fix**: Use `separatorColor.withAlphaComponent(0.45)` for adaptive appearance.

---

## Additional fixes (added in v3 rewrite)

| Issue | Fix |
|-------|-----|
| Message cards horizontal (fillEqually) cramped | Changed to **vertical** layout (spacing 8pt) |
| Character counter below text, visually split | Moved to right side of text (horizontal, spacing 8pt) |
| `NSBox.separator` width constraint in NSStackView causes Auto Layout crash | Replaced with 1pt tall `NSView` (separatorColor background) |
| Stored property init constraint loop | `messagesHeader` built via `buildMessagesHeader()` method in `buildLayout()` |
| `swift build` direct run causes `projectPath` resolution error | Unified use of `build.sh` for `.app` bundle creation |
