<h1 align="center">Cyclope</h1>

<p align="center"><strong>All-in-One Mac Control</strong></p>

BMFM(By Me, For Me) Project #2

BMFM is a project that started from one idea: build what I actually need.

Cyclope was born from a menu bar that kept getting crowded. I wanted fewer icons, fewer interruptions, and one place for the small Mac controls I use every day.

Cyclope brings my most-used utilities into a single compact menu bar app. Keep the Mac awake, snap windows into place, and tune the shortcuts that fit the way I work.

<p align="center">
  <img src="../assets/AppIcon.png" alt="Cyclope app icon" width="128">
</p>

## Features

- Window Management
- Sleep Prevention
- Scroll Direction Control

## Utilities

### Window Snapping

Cyclope can move the focused window to common positions such as left, right, top, bottom, full screen, and center. It also supports custom snap commands, repeat-last-snap, menu visibility controls, global shortcuts, and a modal shortcut panel.

### Sleep Prevention

Sleep Prevention keeps the system and display awake for a chosen duration. The menu offers quick presets (15 minutes, 30 minutes, 1 hour, 2 hours, and until turned off), and Settings add a default duration, battery-aware disabling with a battery-level threshold, and a global toggle shortcut.

### Scroll Direction

Scroll Direction provides quick toggles for macOS Natural Scrolling and wheel mouse scroll reversal.

### Settings And About

Settings cover app visibility, login behavior, menus, shortcuts, sleep defaults, permissions, updates, and About information.

## Permissions

Cyclope asks only for the macOS permissions needed by the enabled utilities:

- Accessibility: required for window snapping and global shortcuts.
- Input Monitoring: required for wheel mouse scroll reversal.

You can review permission status from the app's Settings window.

## Requirements

- macOS 15.0 or later.
- Xcode 26 or later for local development.

The app target is `Cyclope`, with bundle identifier `com.dogany.cyclope`.

## Build And Run

Open the project in Xcode:

```sh
open Cyclope.xcodeproj
```

Build from the command line:

```sh
xcodebuild -project Cyclope.xcodeproj -scheme Cyclope -configuration Debug build
```

For a release build:

```sh
xcodebuild -project Cyclope.xcodeproj -scheme Cyclope -configuration Release build
```

## Project Structure

```text
Cyclope/
  App/                App entry point and AppDelegate integration
  Core/               App controller, environment, and shared models
  Features/           Menu bar UI, settings UI, and shortcut panel UI
  Services/           Window snapping, shortcuts, permissions, sleep
  Shared/             Reusable SwiftUI and AppKit bridge components
  settings.default.json
Cyclope.xcodeproj/
screenshots/
```

## Settings

Default menu, shortcut, and snap behavior is seeded from `Cyclope/settings.default.json`. User changes are persisted locally through app settings stores and can be reset from the Settings window.

## Privacy

Cyclope is designed as a local Mac utility. There is no account system, sync service, analytics backend, or Cyclope-hosted server component.
