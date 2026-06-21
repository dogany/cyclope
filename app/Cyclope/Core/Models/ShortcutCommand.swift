//
//  ShortcutCommand.swift
//  Cyclope
//

import Foundation

enum ShortcutCommand: String, CaseIterable, Codable, Hashable, Identifiable {
    case snapLeft
    case snapRight
    case snapTop
    case snapBottom
    case snapFullScreen
    case snapCenter
    case repeatLastSnap
    case toggleSleepPrevention
    case toggleNaturalScrolling
    case toggleWheelMouseReverseScrolling

    var id: String { rawValue }

    var title: String {
        switch self {
        case .snapLeft:
            return String(localized: "Left")
        case .snapRight:
            return String(localized: "Right")
        case .snapTop:
            return String(localized: "Top")
        case .snapBottom:
            return String(localized: "Bottom")
        case .snapFullScreen:
            return String(localized: "Full Screen")
        case .snapCenter:
            return String(localized: "Center")
        case .repeatLastSnap:
            return String(localized: "Repeat Last Snap")
        case .toggleSleepPrevention:
            return String(localized: "Sleep Prevention")
        case .toggleNaturalScrolling:
            return String(localized: "Natural Scrolling")
        case .toggleWheelMouseReverseScrolling:
            return String(localized: "Reverse Mouse Scrolling")
        }
    }

    var groupTitle: String {
        switch self {
        case .snapLeft, .snapRight, .snapTop, .snapBottom, .snapFullScreen, .snapCenter, .repeatLastSnap:
            return String(localized: "Window")
        case .toggleSleepPrevention:
            return String(localized: "Utilities")
        case .toggleNaturalScrolling, .toggleWheelMouseReverseScrolling:
            return String(localized: "Scrolling")
        }
    }

    var systemImage: String {
        switch self {
        case .snapLeft:
            return SnapAction.leftHalf.systemImage
        case .snapRight:
            return SnapAction.rightHalf.systemImage
        case .snapTop:
            return SnapAction.topHalf.systemImage
        case .snapBottom:
            return SnapAction.bottomHalf.systemImage
        case .snapFullScreen:
            return SnapAction.fullScreen.systemImage
        case .snapCenter:
            return SnapAction.center.systemImage
        case .repeatLastSnap:
            return "repeat"
        case .toggleSleepPrevention:
            return "sun.max"
        case .toggleNaturalScrolling:
            return "arrow.up.arrow.down.circle"
        case .toggleWheelMouseReverseScrolling:
            return "arrow.up.arrow.down"
        }
    }

    var paletteKeys: String {
        switch self {
        case .snapLeft:
            return "⌘ + ←"
        case .snapRight:
            return "⌘ + →"
        case .snapTop:
            return "⌘ + ↑"
        case .snapBottom:
            return "⌘ + ↓"
        case .snapFullScreen:
            return "F"
        case .snapCenter:
            return "C"
        case .repeatLastSnap:
            return "R"
        case .toggleSleepPrevention:
            return "S"
        case .toggleNaturalScrolling:
            return "M"
        case .toggleWheelMouseReverseScrolling:
            return "N"
        }
    }

    var directKeys: String {
        switch self {
        case .snapLeft:
            return "Option + Shift + A"
        case .snapRight:
            return "Option + Shift + D"
        case .snapTop:
            return "Option + Shift + W"
        case .snapBottom:
            return "Option + Shift + S"
        case .snapFullScreen:
            return "Option + Shift + F"
        case .snapCenter:
            return "Option + Shift + C"
        case .repeatLastSnap:
            return "Control + Option + Command + R"
        case .toggleSleepPrevention:
            return "Control + Option + Command + S"
        case .toggleNaturalScrolling:
            return "Control + Option + Command + M"
        case .toggleWheelMouseReverseScrolling:
            return "Control + Option + Command + N"
        }
    }

    var defaultPaletteShortcutKeys: [CustomShortcutKey] {
        switch self {
        case .snapLeft:
            return [CustomShortcutKey(keyCode: 123, symbol: "←", modifiers: [.command])]
        case .snapRight:
            return [CustomShortcutKey(keyCode: 124, symbol: "→", modifiers: [.command])]
        case .snapTop:
            return [CustomShortcutKey(keyCode: 126, symbol: "↑", modifiers: [.command])]
        case .snapBottom:
            return [CustomShortcutKey(keyCode: 125, symbol: "↓", modifiers: [.command])]
        case .snapFullScreen:
            return [CustomShortcutKey(keyCode: 3, symbol: "F")]
        case .snapCenter:
            return [CustomShortcutKey(keyCode: 8, symbol: "C")]
        case .repeatLastSnap:
            return [CustomShortcutKey(keyCode: 15, symbol: "R")]
        case .toggleSleepPrevention:
            return [CustomShortcutKey(keyCode: 1, symbol: "S")]
        case .toggleNaturalScrolling:
            return [CustomShortcutKey(keyCode: 46, symbol: "M")]
        case .toggleWheelMouseReverseScrolling:
            return [CustomShortcutKey(keyCode: 45, symbol: "N")]
        }
    }

    var defaultDirectShortcutKey: CustomShortcutKey {
        switch self {
        case .snapLeft:
            return CustomShortcutKey(keyCode: 0, symbol: "A", modifiers: CustomShortcutModifier.defaultSnapDirectModifiers)
        case .snapRight:
            return CustomShortcutKey(keyCode: 2, symbol: "D", modifiers: CustomShortcutModifier.defaultSnapDirectModifiers)
        case .snapTop:
            return CustomShortcutKey(keyCode: 13, symbol: "W", modifiers: CustomShortcutModifier.defaultSnapDirectModifiers)
        case .snapBottom:
            return CustomShortcutKey(keyCode: 1, symbol: "S", modifiers: CustomShortcutModifier.defaultSnapDirectModifiers)
        case .snapFullScreen:
            return CustomShortcutKey(keyCode: 3, symbol: "F", modifiers: CustomShortcutModifier.defaultSnapDirectModifiers)
        case .snapCenter:
            return CustomShortcutKey(keyCode: 8, symbol: "C", modifiers: CustomShortcutModifier.defaultSnapDirectModifiers)
        case .repeatLastSnap:
            return CustomShortcutKey(keyCode: 15, symbol: "R", modifiers: CustomShortcutModifier.defaultDirectModifiers)
        case .toggleSleepPrevention:
            return CustomShortcutKey(keyCode: 1, symbol: "S", modifiers: CustomShortcutModifier.defaultDirectModifiers)
        case .toggleNaturalScrolling:
            return CustomShortcutKey(keyCode: 46, symbol: "M", modifiers: CustomShortcutModifier.defaultDirectModifiers)
        case .toggleWheelMouseReverseScrolling:
            return CustomShortcutKey(keyCode: 45, symbol: "N", modifiers: CustomShortcutModifier.defaultDirectModifiers)
        }
    }

    var enablesDefaultDirectShortcut: Bool {
        snapAction != nil
    }

    var snapAction: SnapAction? {
        switch self {
        case .snapLeft:
            return .leftHalf
        case .snapRight:
            return .rightHalf
        case .snapTop:
            return .topHalf
        case .snapBottom:
            return .bottomHalf
        case .snapFullScreen:
            return .fullScreen
        case .snapCenter:
            return .center
        case .repeatLastSnap, .toggleSleepPrevention, .toggleNaturalScrolling, .toggleWheelMouseReverseScrolling:
            return nil
        }
    }

    var previewLayout: SnapLayout? {
        switch self {
        case .snapLeft:
            return SnapLayout(columns: 2, rows: 2, startColumn: 0, startRow: 0, columnSpan: 1, rowSpan: 2)
        case .snapRight:
            return SnapLayout(columns: 2, rows: 2, startColumn: 1, startRow: 0, columnSpan: 1, rowSpan: 2)
        case .snapTop:
            return SnapLayout(columns: 2, rows: 2, startColumn: 0, startRow: 0, columnSpan: 2, rowSpan: 1)
        case .snapBottom:
            return SnapLayout(columns: 2, rows: 2, startColumn: 0, startRow: 1, columnSpan: 2, rowSpan: 1)
        case .snapFullScreen:
            return .full
        case .snapCenter:
            return SnapLayout(columns: 3, rows: 3, startColumn: 1, startRow: 1, columnSpan: 1, rowSpan: 1)
        case .repeatLastSnap, .toggleSleepPrevention, .toggleNaturalScrolling, .toggleWheelMouseReverseScrolling:
            return nil
        }
    }

    var usesPositionOnlyCenterPreview: Bool {
        self == .snapCenter
    }

    static let groups: [(title: String, commands: [ShortcutCommand])] = [
        ("Window", [.snapLeft, .snapRight, .snapTop, .snapBottom, .snapFullScreen, .snapCenter])
    ]

    static let defaultCommands: [ShortcutCommand] = groups.flatMap { $0.commands }

    static let utilityCommands: [ShortcutCommand] = [
        .repeatLastSnap,
        .toggleSleepPrevention,
        .toggleNaturalScrolling,
        .toggleWheelMouseReverseScrolling
    ]

    static let persistedCommands: [ShortcutCommand] = defaultCommands + utilityCommands

    static let defaultCustomSnapPresets: [CustomSnapPreset] = [
        CustomSnapPreset(
            id: UUID(uuidString: "6C334782-32B6-40A0-8632-C5E88B0DF3D9")!,
            name: "Left 8/9",
            layout: SnapLayout(columns: 9, rows: 10, startColumn: 0, startRow: 0, columnSpan: 8, rowSpan: 10),
            position: .left,
            snapActivationLayouts: []
        ),
        CustomSnapPreset(
            id: UUID(uuidString: "F73BA684-12E0-450B-BF27-F971240F834C")!,
            name: "Center 14/16",
            layout: SnapLayout(columns: 16, rows: 10, startColumn: 1, startRow: 0, columnSpan: 14, rowSpan: 10),
            position: .center,
            snapActivationLayout: SnapActivationLayout(startColumn: 0, startRow: 1, columnSpan: 1, rowSpan: 10)
        ),
        CustomSnapPreset(
            id: UUID(uuidString: "8D196C5A-7C6A-49AC-BC0F-D61D3D1AA6C8")!,
            name: "Right 8/9",
            layout: SnapLayout(columns: 9, rows: 10, startColumn: 1, startRow: 0, columnSpan: 8, rowSpan: 10),
            position: .bottomLeft,
            snapActivationLayouts: []
        ),
        CustomSnapPreset(
            id: UUID(uuidString: "D50BA24F-67ED-48D0-86BA-B3D380DA33EB")!,
            name: "Left 1/3",
            layout: SnapLayout(columns: 3, rows: 2, startColumn: 0, startRow: 0, columnSpan: 1, rowSpan: 2),
            position: .left,
            snapActivationLayout: SnapActivationLayout(startColumn: 0, startRow: 1, columnSpan: 1, rowSpan: 10)
        ),
        CustomSnapPreset(
            id: UUID(uuidString: "A0F0B6A7-4519-43D4-8C1C-7190B5DA0F12")!,
            name: "Middle 1/3",
            layout: SnapLayout(columns: 3, rows: 2, startColumn: 1, startRow: 0, columnSpan: 1, rowSpan: 2),
            position: .center,
            snapActivationLayouts: []
        ),
        CustomSnapPreset(
            id: UUID(uuidString: "9A270D2C-BCA7-41EB-8413-1BFD978B9F7A")!,
            name: "Right 1/3",
            layout: SnapLayout(columns: 3, rows: 2, startColumn: 2, startRow: 0, columnSpan: 1, rowSpan: 2),
            position: .right,
            snapActivationLayout: SnapActivationLayout(startColumn: 0, startRow: 1, columnSpan: 1, rowSpan: 10)
        )
    ]

    static func directCommand(forKeyCode keyCode: Int) -> ShortcutCommand? {
        switch keyCode {
        case 123:
            return .snapLeft
        case 124:
            return .snapRight
        case 126:
            return .snapTop
        case 125:
            return .snapBottom
        case 36:
            return .snapFullScreen
        case 8:
            return .snapCenter
        case 15:
            return .repeatLastSnap
        case 1:
            return .toggleSleepPrevention
        case 46:
            return .toggleNaturalScrolling
        case 45:
            return .toggleWheelMouseReverseScrolling
        default:
            return nil
        }
    }

    static func paletteCommand(forKeyCode keyCode: Int) -> ShortcutCommand? {
        switch keyCode {
        case 123:
            return .snapLeft
        case 124:
            return .snapRight
        case 126:
            return .snapTop
        case 125:
            return .snapBottom
        case 36, 49:
            return .snapFullScreen
        case 48, 8:
            return .snapCenter
        case 15:
            return .repeatLastSnap
        case 1:
            return .toggleSleepPrevention
        case 46:
            return .toggleNaturalScrolling
        case 45:
            return .toggleWheelMouseReverseScrolling
        default:
            return nil
        }
    }
}
