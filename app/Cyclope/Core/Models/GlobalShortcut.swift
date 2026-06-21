//
//  GlobalShortcut.swift
//  Cyclope
//

import AppKit
import Foundation

struct GlobalShortcut: Identifiable {
    enum Command: Equatable {
        case snap(SnapAction)
        case customSnap(CustomSnapPreset.ID)
        case repeatLastSnap
        case showCheatSheet
        case toggleSleepPrevention
        case toggleNaturalScrolling
        case toggleWheelMouseReverseScrolling
    }

    let id = UUID()
    let title: String
    let keys: String
    let systemImage: String

    static let cheatSheet: [GlobalShortcut] = [
        GlobalShortcut(title: "Show Command Sheet", keys: "Option + S", systemImage: "keyboard"),
        GlobalShortcut(title: ShortcutCommand.snapLeft.title, keys: ShortcutCommand.snapLeft.directKeys, systemImage: ShortcutCommand.snapLeft.systemImage),
        GlobalShortcut(title: ShortcutCommand.snapRight.title, keys: ShortcutCommand.snapRight.directKeys, systemImage: ShortcutCommand.snapRight.systemImage),
        GlobalShortcut(title: ShortcutCommand.snapTop.title, keys: ShortcutCommand.snapTop.directKeys, systemImage: ShortcutCommand.snapTop.systemImage),
        GlobalShortcut(title: ShortcutCommand.snapBottom.title, keys: ShortcutCommand.snapBottom.directKeys, systemImage: ShortcutCommand.snapBottom.systemImage),
        GlobalShortcut(title: ShortcutCommand.snapFullScreen.title, keys: ShortcutCommand.snapFullScreen.directKeys, systemImage: ShortcutCommand.snapFullScreen.systemImage),
        GlobalShortcut(title: ShortcutCommand.snapCenter.title, keys: ShortcutCommand.snapCenter.directKeys, systemImage: ShortcutCommand.snapCenter.systemImage),
        GlobalShortcut(title: ShortcutCommand.repeatLastSnap.title, keys: ShortcutCommand.repeatLastSnap.directKeys, systemImage: ShortcutCommand.repeatLastSnap.systemImage),
        GlobalShortcut(title: ShortcutCommand.toggleSleepPrevention.title, keys: ShortcutCommand.toggleSleepPrevention.directKeys, systemImage: ShortcutCommand.toggleSleepPrevention.systemImage),
        GlobalShortcut(title: ShortcutCommand.toggleNaturalScrolling.title, keys: ShortcutCommand.toggleNaturalScrolling.directKeys, systemImage: ShortcutCommand.toggleNaturalScrolling.systemImage),
        GlobalShortcut(title: ShortcutCommand.toggleWheelMouseReverseScrolling.title, keys: ShortcutCommand.toggleWheelMouseReverseScrolling.directKeys, systemImage: ShortcutCommand.toggleWheelMouseReverseScrolling.systemImage)
    ]

    var keyParts: [String] {
        keys.components(separatedBy: " + ")
    }

    static func command(
        for event: NSEvent,
        settings: ShortcutSettingsStore,
        snapSettings: SnapSettingsStore
    ) -> Command? {
        if let shortcutCommand = ShortcutCommand.allCases.first(where: { command in
            settings.directKeysToMatch(for: command).contains {
                $0.matches(event, defaultModifiers: CustomShortcutModifier.defaultDirectModifiers)
            }
        }) {
            return command(for: shortcutCommand)
        }

        if let preset = snapSettings.presets.first(where: { preset in
            settings.isCustomDirectEnabled(preset.id) &&
                settings.customDirectKey(for: preset.id)?.matches(
                    event,
                    defaultModifiers: CustomShortcutModifier.defaultDirectModifiers
                ) == true
        }) {
            return .customSnap(preset.id)
        }

        return nil
    }

    static func command(for shortcutCommand: ShortcutCommand) -> Command {
        switch shortcutCommand {
        case .snapLeft:
            return .snap(.leftHalf)
        case .snapRight:
            return .snap(.rightHalf)
        case .snapTop:
            return .snap(.topHalf)
        case .snapBottom:
            return .snap(.bottomHalf)
        case .snapFullScreen:
            return .snap(.fullScreen)
        case .snapCenter:
            return .snap(.center)
        case .repeatLastSnap:
            return .repeatLastSnap
        case .toggleSleepPrevention:
            return .toggleSleepPrevention
        case .toggleNaturalScrolling:
            return .toggleNaturalScrolling
        case .toggleWheelMouseReverseScrolling:
            return .toggleWheelMouseReverseScrolling
        }
    }

    static func defaultCustomShortcutKey(forIndex index: Int) -> CustomShortcutKey? {
        guard customShortcutKeyCodes.indices.contains(index) else { return nil }
        return CustomShortcutKey(keyCode: customShortcutKeyCodes[index], symbol: "\(index + 1)")
    }

    private static let customShortcutKeyCodes = [
        18, // 1
        19, // 2
        20, // 3
        21, // 4
        23, // 5
        22, // 6
        26, // 7
        28, // 8
        25  // 9
    ]
}
