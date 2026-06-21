# Product Requirements Document

## Product Summary

Cyclope is a lightweight macOS menu bar app that brings frequently used Mac controls into one place. The current release focuses on two utilities: window snapping and sleep prevention.

## Goals

- Help users organize windows quickly with simple snapping controls.
- Keep the Mac awake when needed, with sensible duration and battery rules.
- Provide everything from one compact menu bar app, with customizable shortcuts.
- Keep all settings and behavior on-device, with no backend or account.

## Target Users

- macOS users who want faster window management.
- Users who need to keep their Mac awake during meetings, downloads, presentations, or long tasks.

## Core Features

### 1. Window Snapping

- Snap the active window to common positions:
  - Left half
  - Right half
  - Top half
  - Bottom half
  - Full screen
  - Center
- Custom snap commands and grid-based layout presets.
- Trigger snaps from menu commands, global keyboard shortcuts, a modal command palette, or screen-edge snap activation zones.
- Repeat the last used snap action.
- Customize which commands appear in the menu and the cheat sheet.

### 2. Sleep Prevention

- Toggle sleep prevention on or off from the menu bar.
- Quick duration presets:
  - 15 minutes
  - 30 minutes
  - 1 hour
  - 2 hours
  - Until turned off
- Configurable default duration (a custom number of minutes, or never / until turned off).
- Battery-aware rules: optionally disable on battery power, with a battery-level threshold.
- Optional global shortcut to toggle sleep prevention.
- Prevents system and display sleep while active, and reflects status in the menu bar icon.

## Platform & Distribution

- macOS 26.0 or later.
- Distributed as a sandboxed app, compatible with the Mac App Store.
- Bundle identifier: `com.dogany.cyclope`.

## Permissions

- Accessibility — required for window snapping and global shortcuts.
- No microphone, speech, or other privacy-sensitive permissions are requested.

## MVP Requirements

- macOS menu bar app.
- Window snapping actions with global keyboard shortcuts.
- Sleep prevention with duration and battery options.
- Clear onboarding for the Accessibility permission.

## Non-Goals

- Advanced window layout designer.
- Cloud account or settings sync.
- Team collaboration features.
- Cross-platform support.
- Voice-to-text / dictation (not part of this product).

## Success Metrics

- Users can snap a window in under 2 seconds.
- Users can enable sleep prevention in one click.
- Permission setup is completed without confusion.

## Key Risks

- The Accessibility permission can complicate onboarding, and the grant can go stale after the app is re-signed (the toggle may read as allowed while window control silently fails).
- macOS built-in edge tiling competes with Cyclope's edge snapping; users may need to disable it in Desktop & Dock.

## Release Scope

A reliable menu bar experience with simple controls, stable global shortcuts, and clear permission guidance for window snapping and sleep prevention.
