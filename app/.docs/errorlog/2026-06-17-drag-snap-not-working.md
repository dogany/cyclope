# Drag-to-snap never triggers

**Date:** 2026-06-17
**Type:** Bug / postmortem
**Scope:** `WindowDragSnapManager` (drag-to-snap). Keyboard/menu snapping was unaffected.

## Summary

Dragging a window to a screen edge never snapped it. The keyboard-shortcut and
menu snap paths worked fine. Root cause: the drag detector relied on a
**CGEvent session tap**, which macOS **disables at the very start of a window
drag** (`kCGEventTapDisabledByUserInput`). After the disable, no further
mouse-dragged/up events reached the tap for that gesture, so the drag was never
classified as a "move" and never armed a snap target. Fixed by preferring
**`NSEvent` global/local monitors** (already present as a fallback) over the
tap.

## Symptom

- Drag a window's title bar to the left/right/top edge and release → nothing
  happens, no preview, no snap.
- Keyboard shortcuts (e.g. `⌘+←`, `Option+Shift+A`) and the menu snap commands
  snapped correctly.

## Investigation

The two snap paths are independent:

- **Keyboard / menu** → `GlobalShortcutManager` (hotkey registration) →
  `WindowSnapper.snap(...)` (Accessibility window manipulation).
- **Drag-to-snap** → `WindowDragSnapManager` (observes mouse events, detects a
  window move into an activation zone, then calls the same snap path).

Because keyboard snapping *moved windows*, Accessibility was confirmed granted
(`AXIsProcessTrusted() == true`) and the AX manipulation path was healthy — so
the failure was isolated to the drag **event-observation** layer.

Temporary diagnostic logging was added to `WindowDragSnapManager` at every
decision point (event arrival, session creation, move/resize classification,
activation-zone match, finish). A single drag produced:

```
start: event tap active (axTrusted=true)
tap event type=1            # leftMouseDown — received
beginDrag started initialKind=unknown
updateDrag: not a move (kind=unknown)   # synchronous call from beginDrag; expected at mouse-down
tap event type=4294967295   # kCGEventTapDisabledByUserInput — tap DISABLED
tap disabled (type=4294967295), re-enabling
# …nothing further: no type=6 (leftMouseDragged), no type=2 (leftMouseUp)
```

CGEventType reference: `1` = leftMouseDown, `2` = leftMouseUp, `6` =
leftMouseDragged, `0xFFFFFFFE` (4294967294) = disabled-by-timeout, `0xFFFFFFFF`
(4294967295) = disabled-by-user-input.

## Root cause

`WindowDragSnapManager.start()` created a CGEvent session tap
(`.cgSessionEventTap`, `.listenOnly`) and only fell back to NSEvent monitors if
tap *creation* failed. Tap creation succeeded, so the monitors never ran.

At the moment a window drag begins, macOS posts `kCGEventTapDisabledByUserInput`
and stops delivering events to the tap. The existing handler re-enables the tap,
but re-enabling does **not** resume delivery for the in-flight gesture — the
remaining `leftMouseDragged`/`leftMouseUp` events for that drag are lost. With no
drag events, `refreshDragKind` never sees the window move, the drag is never
classified as `.moving`, and `finishDrag` never snaps.

This is a known fragility of `.listenOnly` session taps for drag tracking; it is
not a permissions problem (the tap was active and Accessibility was granted).

## Fix

Prefer `NSEvent` global + local monitors for drag observation; use the CGEvent
tap only as a fallback when the monitors cannot be installed. Global NSEvent
monitors observe the same session-wide mouse events, require the Accessibility
permission the app already holds, and are **not** subject to the
disabled-by-user-input behavior — so the full drag gesture is observed.

`Cyclope/Services/WindowSnapper.swift` — `WindowDragSnapManager.start()`:

```swift
// BEFORE — tap primary, monitors only if the tap can't be created
if !startEventTap() {
    startMouseMonitors()
}

// AFTER — monitors primary, tap as fallback
if !startMouseMonitors() {
    _ = startEventTap()
}
```

`startMouseMonitors()` now returns `Bool` (whether the global monitor was
installed). An explanatory comment documents why the tap is not the primary
mechanism.

## Secondary fixes (found while investigating)

These were latent reliability issues in the same flow, fixed in the same pass:

| Area | Problem | Fix |
| --- | --- | --- |
| `finishDrag()` | Snap required the activation target to be *armed*, which only happens after a 0.45 s dwell (`defaultSnapActivationDwellDelay`). Releasing the drag before the dwell elapsed dropped the snap. | Fall back to the `pendingTarget` (the zone the cursor is currently in) when no `activeTarget` is armed yet: `let target = activeTarget ?? pendingTarget`. |
| `refreshDragKind()` | `sizeDelta > threshold` was checked before origin movement, so an incidental size jitter during a move (crossing displays, edge clamping) flipped the drag to `.resizing` and blocked snapping. | Classify as `.moving` first when the window moved much more than it resized (`originDelta > threshold && originDelta - sizeDelta > threshold`); corner/edge resizes still classify as `.resizing`. |
| Screen-edge matching (`matchingPreset` / `SnapLayout.cell`) | `CGRect.contains` excludes the max edges, so a cursor pinned to the very top/right of a display matched no screen/cell — exactly the gesture for top/maximize snapping. | Added boundary-inclusive fallbacks: `activationScreens(containing:)` in `WindowSnapper` and an inclusive `isWithinScreen` guard in `SnapLayout.cell(containing:)`. |

## Verification

- `xcodebuild -project Cyclope.xcodeproj -scheme Cyclope -configuration Debug build CODE_SIGNING_ALLOWED=NO`
  → **BUILD SUCCEEDED**.
- Manual: dragging a window to the left edge now snaps it; drag logs showed the
  monitor path delivering `leftMouseDragged`/`leftMouseUp` through the full
  gesture.
- All temporary diagnostic logging (and the `logger` property added to
  `WindowDragSnapManager`) was removed after confirmation; the `WindowSnapper`
  struct keeps its own pre-existing logger.

## Notes / follow-ups

- The CGEvent tap code path (`startEventTap`, `handleEventTapEvent`, the
  callback) is retained as a fallback. If a future case is found where NSEvent
  monitors are unavailable but a tap works, the tap would still need
  synchronous, gesture-surviving re-enable handling — the current re-enable only
  covers timeout-style disables, not the mid-gesture user-input disable.
