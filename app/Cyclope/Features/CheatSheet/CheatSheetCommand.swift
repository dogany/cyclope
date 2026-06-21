//
//  CheatSheetCommand.swift
//  Cyclope
//

import AppKit
import Foundation

enum CheatSheetCommand: Hashable, Identifiable {
    case snap(SnapAction)
    case customSnap(CustomSnapPreset.ID, name: String, key: CustomShortcutKey)
    case repeatLastSnap
    case toggleSleepPrevention
    case toggleNaturalScrolling
    case toggleWheelMouseReverseScrolling

    var id: String {
        switch self {
        case .snap(let action):
            return action.id
        case .customSnap(let presetID, _, _):
            return "customSnap-\(presetID.uuidString)"
        case .repeatLastSnap:
            return "repeatLastSnap"
        case .toggleSleepPrevention:
            return "toggleSleepPrevention"
        case .toggleNaturalScrolling:
            return "toggleNaturalScrolling"
        case .toggleWheelMouseReverseScrolling:
            return "toggleWheelMouseReverseScrolling"
        }
    }

    var shortcutCommand: ShortcutCommand? {
        switch self {
        case .snap(.leftHalf):
            return .snapLeft
        case .snap(.rightHalf):
            return .snapRight
        case .snap(.topHalf):
            return .snapTop
        case .snap(.bottomHalf):
            return .snapBottom
        case .snap(.fullScreen):
            return .snapFullScreen
        case .snap(.center):
            return .snapCenter
        case .customSnap:
            return nil
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

    var title: String {
        if case .customSnap(_, let name, _) = self {
            return name
        }

        return shortcutCommand?.title ?? ""
    }

    var keySymbols: String {
        if case .customSnap(_, _, let key) = self {
            return key.paletteSymbols
        }

        return shortcutCommand?.paletteKeys ?? ""
    }

    func keySymbols(using settings: ShortcutSettingsStore) -> String {
        if case .customSnap(_, _, let key) = self {
            return key.paletteSymbols
        }

        guard let shortcutCommand else { return "" }
        return settings.paletteKeySymbols(for: shortcutCommand)
    }

    var systemImage: String {
        if case .customSnap = self {
            return "square.grid.3x3"
        }

        return shortcutCommand?.systemImage ?? "square.grid.3x3"
    }

    static let allCommands: [CheatSheetCommand] = [
        .snap(.leftHalf),
        .snap(.rightHalf),
        .snap(.topHalf),
        .snap(.bottomHalf),
        .snap(.fullScreen),
        .snap(.center)
    ]

    static func commands(
        using settings: ShortcutSettingsStore,
        customPresets: [CustomSnapPreset]
    ) -> [CheatSheetCommand] {
        allCommands.filter { command in
            guard let shortcutCommand = command.shortcutCommand else { return false }
            return settings.isCheatSheetDisplayEnabled(shortcutCommand)
        } +
            customCommands(using: settings, customPresets: customPresets)
    }

    static func command(
        for event: NSEvent,
        settings: ShortcutSettingsStore,
        customPresets: [CustomSnapPreset]
    ) -> CheatSheetCommand? {
        if let customCommand = customCommand(
            for: event,
            settings: settings,
            customPresets: customPresets
        ) {
            return customCommand
        }

        if let shortcutCommand = modalShortcutCommands.first(where: { command in
            settings.paletteKeys(for: command).contains { $0.matches(event) }
        }) {
            return command(for: shortcutCommand)
        }

        return nil
    }

    private static var modalShortcutCommands: [ShortcutCommand] {
        allCommands.compactMap(\.shortcutCommand)
    }

    private static func customCommands(
        using settings: ShortcutSettingsStore,
        customPresets: [CustomSnapPreset]
    ) -> [CheatSheetCommand] {
        customCommands(
            using: settings,
            customPresets: customPresets,
            requiresDisplay: true
        )
    }

    private static func customCommands(
        using settings: ShortcutSettingsStore,
        customPresets: [CustomSnapPreset],
        requiresDisplay: Bool
    ) -> [CheatSheetCommand] {
        customPresets.enumerated().compactMap { index, preset in
            guard let key = resolvedCustomPaletteKey(
                for: preset,
                index: index,
                settings: settings
            ),
                  settings.isCustomPaletteEnabled(preset.id) else {
                return nil
            }

            if requiresDisplay && !settings.isCustomCheatSheetDisplayEnabled(preset.id) {
                return nil
            }

            return .customSnap(preset.id, name: preset.name, key: key)
        }
    }

    private static func customCommand(
        for event: NSEvent,
        settings: ShortcutSettingsStore,
        customPresets: [CustomSnapPreset]
    ) -> CheatSheetCommand? {
        let customCommands = customCommands(
            using: settings,
            customPresets: customPresets,
            requiresDisplay: false
        )
        return customCommands.first { command in
            guard case .customSnap(_, _, let key) = command else {
                return false
            }

            return key.matches(event)
        }
    }

    private static func resolvedCustomPaletteKey(
        for preset: CustomSnapPreset,
        index: Int,
        settings: ShortcutSettingsStore
    ) -> CustomShortcutKey? {
        settings.customPaletteKey(for: preset.id) ??
            GlobalShortcut.defaultCustomShortcutKey(forIndex: index)
    }

    private static func command(for shortcutCommand: ShortcutCommand) -> CheatSheetCommand {
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
}
