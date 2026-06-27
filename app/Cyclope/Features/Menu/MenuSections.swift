//
//  MenuSections.swift
//  Cyclope
//

import AppKit
import SwiftUI

struct WindowSnappingMenuSection: View {
    @EnvironmentObject private var controller: CyclopeController

    var body: some View {
        if hasDisplayedItems {
            Section("Window") {
                defaultSnapItems
                customSnapItems
            }
        }
    }

    @ViewBuilder
    private var defaultSnapItems: some View {
        switch controller.snapSettings.defaultSnapPresentation {
        case .collapsed:
            Menu("Default Snap") {
                defaultSnapButtons
            }
        case .expanded:
            defaultSnapButtons
        }
    }

    @ViewBuilder
    private var customSnapItems: some View {
        if !displayedCustomPresets.isEmpty {
            switch controller.snapSettings.customSnapPresentation {
            case .collapsed:
                Menu("Custom Snap") {
                    customSnapButtons
                }
            case .expanded:
                Divider()
                customSnapButtons
            }
        }
    }

    @ViewBuilder
    private var defaultSnapButtons: some View {
        ForEach(displayedDefaultSnapCommands) { command in
            if let action = command.snapAction {
                Button {
                    controller.snap(action)
                } label: {
                    Label {
                        Text(command.title)
                    } icon: {
                        ShortcutCommandMenuIcon(command: command)
                    }
                }
                .keyboardShortcut(globalShortcut(for: command))
            }
        }
    }

    @ViewBuilder
    private var customSnapButtons: some View {
        ForEach(displayedCustomPresets) { preset in
            Button {
                controller.snap(preset)
            } label: {
                Label {
                    Text(preset.name)
                } icon: {
                    SnapPresetMenuIcon(preset: preset)
                }
            }
            .keyboardShortcut(globalShortcut(for: preset))
        }
    }

    private var displayedCustomPresets: [CustomSnapPreset] {
        controller.snapSettings.presets.filter { preset in
            controller.shortcutSettings.isCustomMenuDisplayEnabled(preset.id)
        }
    }

    private var displayedDefaultSnapCommands: [ShortcutCommand] {
        ShortcutCommand.defaultCommands.filter { command in
            controller.shortcutSettings.isMenuDisplayEnabled(command)
        }
    }

    private var hasDisplayedItems: Bool {
        !displayedDefaultSnapCommands.isEmpty || !displayedCustomPresets.isEmpty
    }

    // The global (direct) shortcut shown next to a menu item, or nil to show
    // nothing. Default snap commands always have one (custom or the default
    // ⌃⌥⌘ binding); custom presets only when a direct shortcut is assigned.
    private func globalShortcut(for command: ShortcutCommand) -> KeyboardShortcut? {
        menuKeyboardShortcut(from: controller.shortcutSettings.directKeyToMatch(for: command))
    }

    private func globalShortcut(for preset: CustomSnapPreset) -> KeyboardShortcut? {
        guard controller.shortcutSettings.isCustomDirectEnabled(preset.id) else { return nil }
        return menuKeyboardShortcut(from: controller.shortcutSettings.customDirectKey(for: preset.id))
    }
}

struct SleepPreventionMenuSection: View {
    @EnvironmentObject private var controller: CyclopeController

    var body: some View {
        Section("Sleep") {
            Button {
                if controller.sleepPreventer.isActive {
                    controller.disableSleepPrevention()
                } else {
                    controller.enableDefaultSleepPrevention()
                }
            } label: {
                Text(verbatim: sleepToggleTitle)
            }
            .keyboardShortcut(globalShortcut(for: .toggleSleepPrevention))

            Menu("Deactivate after") {
                ForEach(SleepDuration.deactivationOptions) { duration in
                    Button {
                        controller.enableSleepPrevention(duration)
                    } label: {
                        sleepMenuItemTitle(duration.menuTitle, isSelected: isSelected(duration))
                    }
                }

                Divider()

                Button {
                    controller.promptCustomSleepPreventionDuration()
                } label: {
                    if controller.sleepPreventer.customDurationMinutes != nil,
                       controller.sleepPreventer.isActive {
                        Label("Custom...", systemImage: "checkmark")
                    } else {
                        Text("Custom...")
                    }
                }

                Divider()

                Button {
                    controller.enableSleepPrevention(.untilTurnedOff)
                } label: {
                    sleepMenuItemTitle(String(localized: "Never"), isSelected: isSelected(.untilTurnedOff))
                }
            }

            if let remainingTitle = controller.sleepPreventer.menuRemainingTitle {
                Text(remainingTitle)
            }
        }
    }

    @ViewBuilder
    private func sleepMenuItemTitle(_ title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    private func isSelected(_ duration: SleepDuration) -> Bool {
        controller.sleepPreventer.isActive &&
            controller.sleepPreventer.customDurationMinutes == nil &&
            controller.sleepPreventer.selectedDuration == duration
    }

    private var sleepToggleTitle: String {
        controller.sleepPreventer.isActive ? "Deactivate" : "Activate"
    }

    private func globalShortcut(for command: ShortcutCommand) -> KeyboardShortcut? {
        menuKeyboardShortcut(from: controller.shortcutSettings.directKeyToMatch(for: command))
    }
}

struct ScrollDirectionMenuSection: View {
    @EnvironmentObject private var controller: CyclopeController

    var body: some View {
        Section("Scrolling") {
            Toggle("Natural Scrolling", isOn: Binding(
                get: { controller.scrollDirectionController.isNaturalScrollingEnabled },
                set: { controller.setNaturalScrollingEnabled($0) }
            ))
            .keyboardShortcut(globalShortcut(for: .toggleNaturalScrolling))

            Toggle("Reverse Mouse Scrolling", isOn: Binding(
                get: { controller.scrollDirectionController.isWheelMouseReverseScrollingEnabled },
                set: { controller.setWheelMouseReverseScrollingEnabled($0) }
            ))
            .keyboardShortcut(globalShortcut(for: .toggleWheelMouseReverseScrolling))
            .onAppear {
                controller.scrollDirectionController.refresh()
            }
        }
    }

    private func globalShortcut(for command: ShortcutCommand) -> KeyboardShortcut? {
        menuKeyboardShortcut(from: controller.shortcutSettings.directKeyToMatch(for: command))
    }
}

private func menuKeyboardShortcut(from key: CustomShortcutKey?) -> KeyboardShortcut? {
    guard let key,
          let equivalent = menuKeyEquivalent(forKeyCode: key.keyCode, symbol: key.symbol) else {
        return nil
    }

    let modifiers = key.modifiers ?? CustomShortcutModifier.defaultDirectModifiers
    return KeyboardShortcut(equivalent, modifiers: menuEventModifiers(from: modifiers))
}

private func menuKeyEquivalent(forKeyCode keyCode: Int, symbol: String) -> KeyEquivalent? {
    switch keyCode {
    case 123: return .leftArrow
    case 124: return .rightArrow
    case 125: return .downArrow
    case 126: return .upArrow
    case 36: return .return
    case 48: return .tab
    case 49: return .space
    default:
        guard let character = symbol.lowercased().first else { return nil }
        return KeyEquivalent(character)
    }
}

private func menuEventModifiers(from modifiers: [CustomShortcutModifier]) -> EventModifiers {
    var result: EventModifiers = []
    for modifier in modifiers {
        switch modifier {
        case .control: result.insert(.control)
        case .option: result.insert(.option)
        case .shift: result.insert(.shift)
        case .command: result.insert(.command)
        }
    }

    return result
}

struct ApplicationMenuSection: View {
    @EnvironmentObject private var controller: CyclopeController

    var body: some View {
        Section {
            Button {
                controller.showSettingsWindow()
            } label: {
                Text("Settings")
            }

            Button {
                controller.showSettingsWindow(category: .about)
            } label: {
                Text("About")
            }

            Button {
                NSApp.terminate(nil)
            } label: {
                Text("Quit")
            }
        }
    }
}
