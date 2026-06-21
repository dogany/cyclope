# Cyclope

BMFM(By Me, For Me) Project #2

BMFM is a project that started from one idea: build what I actually need.

Cyclope was born from a menu bar that kept getting crowded. I wanted fewer icons, fewer interruptions, and one place for the small Mac controls I use every day.

Cyclope brings my most-used utilities into a single compact menu bar app. Keep the Mac awake, snap windows into place, and tune the shortcuts that fit the way I work.

![Cyclope menu bar preview](screenshots/app-store/preview/01-one-menu-bar-icon.png)

## Features

- One menu bar icon for frequently used Mac controls.
- Keep your Mac awake for a selected duration.
- Snap windows with menu commands, global shortcuts, or snap activation areas.
- Customize shortcuts, menu items, snap commands, and default behavior.
- Keep settings and app behavior on your device, with no Cyclope backend.

## Utilities

### Window Snapping

Cyclope can move the focused window to common positions such as left, right, top, bottom, full screen, and center. It also supports custom snap commands, repeat-last-snap, menu visibility controls, global shortcuts, and a modal shortcut panel.

### Sleep Prevention

Sleep Prevention keeps the system and display awake for a chosen duration. The menu offers quick presets (15 minutes, 30 minutes, 1 hour, 2 hours, and until turned off), and Settings add a default duration, battery-aware disabling with a battery-level threshold, and a global toggle shortcut.

## Permissions

Cyclope asks only for the macOS permissions needed by the enabled utilities:

- Accessibility: required for window snapping and global shortcuts.

You can review permission status from the app's Settings window.

## Requirements

- macOS 26.0 or later.
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
