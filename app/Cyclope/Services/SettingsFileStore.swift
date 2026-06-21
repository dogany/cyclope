//
//  SettingsFileStore.swift
//  Cyclope
//

import Foundation

struct AppSettingsSnapshot: Codable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var windowManager: WindowManagerSettingsSnapshot
    var sleepPrevention: SleepPreventionSettingsSnapshot
    var scrollDirection: ScrollDirectionSettingsSnapshot

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        windowManager: WindowManagerSettingsSnapshot = WindowManagerSettingsSnapshot(),
        sleepPrevention: SleepPreventionSettingsSnapshot = .defaultSettings,
        scrollDirection: ScrollDirectionSettingsSnapshot = .defaultSettings
    ) {
        self.schemaVersion = schemaVersion
        self.windowManager = windowManager
        self.sleepPrevention = sleepPrevention
        self.scrollDirection = scrollDirection
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        windowManager = try container.decodeIfPresent(WindowManagerSettingsSnapshot.self, forKey: .windowManager) ?? WindowManagerSettingsSnapshot()
        sleepPrevention = try container.decodeIfPresent(SleepPreventionSettingsSnapshot.self, forKey: .sleepPrevention) ?? .defaultSettings
        scrollDirection = try container.decodeIfPresent(ScrollDirectionSettingsSnapshot.self, forKey: .scrollDirection) ?? .defaultSettings
    }

    mutating func normalizeForStorage() {
        schemaVersion = Self.currentSchemaVersion
        windowManager.normalizeForStorage()
    }
}

struct ScrollDirectionSettingsSnapshot: Codable, Equatable {
    var reverseWheelMouseScrolling: Bool

    static let defaultSettings = ScrollDirectionSettingsSnapshot(
        reverseWheelMouseScrolling: false
    )
}

struct SleepPreventionSettingsSnapshot: Codable, Equatable {
    var defaultDurationMinutes: Int?
    var disableOnBatteryPower: Bool
    var batteryDisableThresholdPercent: Int?

    static let defaultSettings = SleepPreventionSettingsSnapshot(
        defaultDurationMinutes: nil,
        disableOnBatteryPower: false,
        batteryDisableThresholdPercent: nil
    )
}

enum AppMenuCategory: String, Codable, CaseIterable, Hashable, Identifiable {
    case window
    case sleep
    case scrolling

    var id: String { rawValue }

    var title: String {
        switch self {
        case .window:
            return String(localized: "Window")
        case .sleep:
            return String(localized: "Sleep")
        case .scrolling:
            return String(localized: "Scrolling")
        }
    }
}

struct MenuCategorySettingsSnapshot: Codable, Equatable, Identifiable {
    var category: AppMenuCategory
    var showInMenu: Bool

    var id: AppMenuCategory { category }

    static var defaultSettings: [MenuCategorySettingsSnapshot] {
        AppMenuCategory.allCases.map { category in
            MenuCategorySettingsSnapshot(category: category, showInMenu: true)
        }
    }

    static func normalized(_ settings: [MenuCategorySettingsSnapshot]?) -> [MenuCategorySettingsSnapshot] {
        var result: [MenuCategorySettingsSnapshot] = []
        var seenCategories = Set<AppMenuCategory>()

        for setting in settings ?? [] where !seenCategories.contains(setting.category) {
            result.append(setting)
            seenCategories.insert(setting.category)
        }

        for category in AppMenuCategory.allCases where !seenCategories.contains(category) {
            result.append(MenuCategorySettingsSnapshot(category: category, showInMenu: true))
        }

        return result
    }
}

struct WindowManagerSettingsSnapshot: Codable {
    var modalShortcut: ModalTriggerSettingsSnapshot
    var defaultCommandPresentation: SnapMenuPresentation?
    var customCommandPresentation: SnapMenuPresentation?
    var selectedWindowCommandID: String?
    var snapActivationDwellDelay: TimeInterval?
    var menuCategories: [MenuCategorySettingsSnapshot]
    var windowCommands: [WindowCommandSettingsSnapshot]

    init(
        modalShortcut: ModalTriggerSettingsSnapshot,
        defaultCommandPresentation: SnapMenuPresentation?,
        customCommandPresentation: SnapMenuPresentation?,
        selectedWindowCommandID: String?,
        snapActivationDwellDelay: TimeInterval?,
        menuCategories: [MenuCategorySettingsSnapshot] = MenuCategorySettingsSnapshot.defaultSettings,
        windowCommands: [WindowCommandSettingsSnapshot]
    ) {
        self.modalShortcut = modalShortcut
        self.defaultCommandPresentation = defaultCommandPresentation
        self.customCommandPresentation = customCommandPresentation
        self.selectedWindowCommandID = selectedWindowCommandID
        self.snapActivationDwellDelay = snapActivationDwellDelay
        self.menuCategories = MenuCategorySettingsSnapshot.normalized(menuCategories)
        self.windowCommands = windowCommands
    }

    init(
        snapSettings: SnapSettingsSnapshot? = nil,
        shortcutSettings: ShortcutSettingsSnapshot? = nil
    ) {
        let snapSettings = snapSettings ?? SnapSettingsSnapshot.defaultSettings
        let shortcutSettings = shortcutSettings ?? ShortcutSettingsSnapshot.defaultSettings

        modalShortcut = ModalTriggerSettingsSnapshot(
            isEnabled: shortcutSettings.isModalShortcutEnabled ?? true,
            key: shortcutSettings.modalShortcutKey ?? ShortcutSettingsSnapshot.defaultModalShortcutKey
        )
        defaultCommandPresentation = snapSettings.defaultSnapPresentation ?? .expanded
        customCommandPresentation = snapSettings.customSnapPresentation ?? .collapsed
        selectedWindowCommandID = snapSettings.selectedPresetID?.uuidString
        snapActivationDwellDelay = snapSettings.snapActivationDwellDelay
        menuCategories = MenuCategorySettingsSnapshot.defaultSettings
        windowCommands = Self.windowCommands(from: snapSettings, shortcutSettings: shortcutSettings)
    }

    var snapSettings: SnapSettingsSnapshot? {
        let presets = windowCommands.compactMap(\.customSnapPreset)
        let selectedPresetID = selectedWindowCommandID.flatMap(UUID.init(uuidString:))
        var defaultCommandSnapActivations: [ShortcutCommand: SnapActivationPreference] = [:]
        for command in windowCommands {
            guard let shortcutCommand = command.shortcutCommand,
                  let snapPreference = command.snapPreference else {
                continue
            }

            defaultCommandSnapActivations[shortcutCommand] = snapPreference
        }

        return SnapSettingsSnapshot(
            presets: presets,
            selectedPresetID: selectedPresetID,
            defaultSnapPresentation: defaultCommandPresentation,
            customSnapPresentation: customCommandPresentation,
            snapActivationDwellDelay: snapActivationDwellDelay,
            defaultCommandSnapActivations: defaultCommandSnapActivations
        )
    }

    var shortcutSettings: ShortcutSettingsSnapshot? {
        var preferences: [ShortcutCommand: ShortcutCommandPreference] = [:]
        var customPreferences: [CustomSnapPreset.ID: ShortcutCommandPreference] = [:]

        for command in windowCommands {
            if let shortcutCommand = command.shortcutCommand {
                preferences[shortcutCommand] = command.shortcutPreference(for: shortcutCommand)
            } else if let id = command.customPresetID {
                customPreferences[id] = command.customShortcutPreference
            }
        }

        return ShortcutSettingsSnapshot(
            preferences: preferences,
            customPreferences: customPreferences,
            isModalShortcutEnabled: modalShortcut.isEnabled,
            modalShortcutKey: modalShortcut.key
        )
    }

    mutating func applySnapSettings(_ snapshot: SnapSettingsSnapshot) {
        defaultCommandPresentation = snapshot.defaultSnapPresentation
        customCommandPresentation = snapshot.customSnapPresentation
        selectedWindowCommandID = snapshot.selectedPresetID?.uuidString
        snapActivationDwellDelay = snapshot.snapActivationDwellDelay
        windowCommands = Self.windowCommands(
            from: snapshot,
            shortcutSettings: shortcutSettings ?? .defaultSettings
        )
    }

    mutating func applyShortcutSettings(_ snapshot: ShortcutSettingsSnapshot) {
        modalShortcut = ModalTriggerSettingsSnapshot(
            isEnabled: snapshot.isModalShortcutEnabled ?? true,
            key: snapshot.modalShortcutKey ?? ShortcutSettingsSnapshot.defaultModalShortcutKey
        )
        windowCommands = Self.windowCommands(
            from: snapSettings ?? .defaultSettings,
            shortcutSettings: snapshot
        )
    }

    mutating func applyMenuCategorySettings(_ snapshot: [MenuCategorySettingsSnapshot]) {
        menuCategories = MenuCategorySettingsSnapshot.normalized(snapshot)
    }

    mutating func normalizeForStorage() {
        guard let shortcutSettings else { return }
        applyShortcutSettings(shortcutSettings)
    }

    enum CodingKeys: String, CodingKey {
        case modalShortcut
        case defaultCommandPresentation
        case customCommandPresentation
        case selectedWindowCommandID
        case snapActivationDwellDelay
        case menuCategories
        case windowCommands
    }

    private static func windowCommands(
        from snapSettings: SnapSettingsSnapshot,
        shortcutSettings: ShortcutSettingsSnapshot
    ) -> [WindowCommandSettingsSnapshot] {
        let defaultCommands = ShortcutCommand.persistedCommands.map { command in
            WindowCommandSettingsSnapshot(
                command: command,
                preference: shortcutSettings.preferences[command] ?? .default,
                snapPreference: snapSettings.defaultCommandSnapActivations?[command] ??
                    SnapSettingsSnapshot.defaultCommandSnapActivations[command]
            )
        }

        let customCommands = snapSettings.presets.enumerated().map { index, preset in
            WindowCommandSettingsSnapshot(
                preset: preset,
                index: index,
                preference: shortcutSettings.customPreferences?[preset.id] ?? .customDefault
            )
        }

        return defaultCommands + customCommands
    }
}

struct ModalTriggerSettingsSnapshot: Codable {
    var isEnabled: Bool
    var key: CustomShortcutKey

    static let defaultSettings = ModalTriggerSettingsSnapshot(
        isEnabled: true,
        key: ShortcutSettingsSnapshot.defaultModalShortcutKey
    )
}

struct WindowCommandSettingsSnapshot: Codable {
    var id: String
    var command: String?
    var name: String
    var type: WindowCommandType
    var kind: WindowCommandKind
    var layout: SnapLayout?
    var position: CustomSnapPosition?
    var snap: WindowCommandSnapSettingsSnapshot?
    var modalShortcut: WindowCommandShortcutSettingsSnapshot
    var globalShortcut: WindowCommandShortcutSettingsSnapshot
    var display: WindowCommandDisplaySettingsSnapshot

    init(
        command: ShortcutCommand,
        preference: ShortcutCommandPreference,
        snapPreference: SnapActivationPreference?
    ) {
        id = command.settingsIdentifier
        self.command = command.settingsIdentifier
        name = command.title
        type = .horizontal
        kind = .default
        layout = command.previewLayout
        position = nil
        snap = snapPreference.map {
            WindowCommandSnapSettingsSnapshot(isEnabled: $0.isEnabled, areas: $0.layouts)
        }
        modalShortcut = WindowCommandShortcutSettingsSnapshot(
            isEnabled: preference.isPaletteEnabled,
            key: preference.paletteKey,
            defaultKey: nil,
            defaultKeys: command.defaultPaletteShortcutKeys,
            suppressesDefaultKey: nil
        )
        globalShortcut = WindowCommandShortcutSettingsSnapshot(
            isEnabled: Self.isGlobalShortcutEnabled(for: command, preference: preference),
            key: preference.directKey,
            defaultKey: command.defaultDirectShortcutKey,
            defaultKeys: nil,
            suppressesDefaultKey: preference.suppressesDefaultDirectKey ?? false
        )
        display = WindowCommandDisplaySettingsSnapshot(
            showInMenu: preference.showsInMenu ?? true,
            showInModal: preference.showsInCheatSheet ?? true
        )
    }

    init(
        preset: CustomSnapPreset,
        index: Int,
        preference: ShortcutCommandPreference
    ) {
        id = preset.id.uuidString
        command = nil
        name = preset.name
        type = preset.mode.windowCommandType
        kind = .custom
        layout = preset.layout
        position = preset.position
        snap = WindowCommandSnapSettingsSnapshot(
            isEnabled: preset.isSnapActivationEnabled,
            areas: preset.snapActivationLayouts
        )
        modalShortcut = WindowCommandShortcutSettingsSnapshot(
            isEnabled: preference.paletteKey != nil || preference.isPaletteEnabled,
            key: preference.paletteKey,
            defaultKey: GlobalShortcut.defaultCustomShortcutKey(forIndex: index),
            defaultKeys: nil,
            suppressesDefaultKey: nil
        )
        globalShortcut = WindowCommandShortcutSettingsSnapshot(
            isEnabled: preference.directKey != nil,
            key: preference.directKey,
            defaultKey: nil,
            defaultKeys: nil,
            suppressesDefaultKey: nil
        )
        display = WindowCommandDisplaySettingsSnapshot(
            showInMenu: preference.showsInMenu ?? true,
            showInModal: preference.showsInCheatSheet ?? true
        )
    }

    var shortcutCommand: ShortcutCommand? {
        guard kind == .default else { return nil }

        if let command {
            return ShortcutCommand(settingsIdentifier: command)
        }

        return ShortcutCommand(settingsIdentifier: id)
    }

    var customPresetID: UUID? {
        guard kind == .custom else { return nil }
        return UUID(uuidString: id)
    }

    var customSnapPreset: CustomSnapPreset? {
        guard let customPresetID else { return nil }

        let resolvedLayout = layout ?? SnapLayout(columns: 16, rows: 10, startColumn: 0, startRow: 0, columnSpan: 8, rowSpan: 10)
        return CustomSnapPreset(
            id: customPresetID,
            name: name,
            layout: resolvedLayout,
            mode: type.customSnapPresetMode,
            position: position ?? CustomSnapPosition(layout: resolvedLayout),
            snapActivationLayouts: snap?.areas,
            isSnapActivationEnabled: snap?.isEnabled ?? false
        )
    }

    var snapPreference: SnapActivationPreference? {
        snap.map { SnapActivationPreference(layouts: $0.areas, isEnabled: $0.isEnabled) }
    }

    var customShortcutPreference: ShortcutCommandPreference {
        ShortcutCommandPreference(
            isPaletteEnabled: modalShortcut.isEnabled,
            isDirectEnabled: globalShortcut.isEnabled,
            paletteKey: resolvedCustomPaletteKey,
            directKey: globalShortcut.isEnabled ? globalShortcut.key : nil,
            suppressesDefaultDirectKey: nil,
            showsInMenu: display.showInMenu,
            showsInCheatSheet: display.showInModal
        )
    }

    func shortcutPreference(for command: ShortcutCommand) -> ShortcutCommandPreference {
        ShortcutCommandPreference(
            isPaletteEnabled: modalShortcut.isEnabled,
            isDirectEnabled: globalShortcut.key != nil || globalShortcut.isEnabled,
            paletteKey: resolvedPaletteKey(for: command),
            directKey: resolvedDirectKey(for: command),
            suppressesDefaultDirectKey: globalShortcut.isEnabled ? (globalShortcut.suppressesDefaultKey ?? false) : true,
            showsInMenu: display.showInMenu,
            showsInCheatSheet: display.showInModal
        )
    }

    private func resolvedPaletteKey(for command: ShortcutCommand) -> CustomShortcutKey? {
        guard let key = modalShortcut.key else { return nil }
        if command.defaultPaletteShortcutKeys.contains(where: { $0.matches(key) }) {
            return nil
        }

        return key
    }

    private func resolvedDirectKey(for command: ShortcutCommand) -> CustomShortcutKey? {
        guard let key = globalShortcut.key else { return nil }
        if command.defaultDirectShortcutKey.matches(key, defaultModifiers: CustomShortcutModifier.defaultDirectModifiers) {
            return nil
        }

        return key
    }

    private var resolvedCustomPaletteKey: CustomShortcutKey? {
        guard let key = modalShortcut.key else { return nil }
        if modalShortcut.defaultKey?.matches(key) == true {
            return nil
        }

        return key
    }

    private static func isGlobalShortcutEnabled(
        for command: ShortcutCommand,
        preference: ShortcutCommandPreference
    ) -> Bool {
        if preference.directKey != nil {
            return true
        }

        guard preference.suppressesDefaultDirectKey != true else {
            return false
        }

        return command.enablesDefaultDirectShortcut || preference.isDirectEnabled
    }
}

enum WindowCommandType: String, Codable {
    case horizontal
    case vertical
    case position
}

private extension CustomSnapPresetMode {
    var windowCommandType: WindowCommandType {
        switch self {
        case .sizeAndPosition:
            return .horizontal
        case .positionOnly:
            return .position
        }
    }
}

private extension WindowCommandType {
    var customSnapPresetMode: CustomSnapPresetMode {
        switch self {
        case .position:
            return .positionOnly
        case .horizontal, .vertical:
            return .sizeAndPosition
        }
    }
}

enum WindowCommandKind: String, Codable {
    case `default`
    case custom
}

struct WindowCommandSnapSettingsSnapshot: Codable {
    var isEnabled: Bool
    var areas: [SnapActivationLayout]

    init(isEnabled: Bool, areas: [SnapActivationLayout]) {
        self.isEnabled = isEnabled
        self.areas = areas
    }

    init(preference: SnapActivationPreference) {
        isEnabled = preference.isEnabled
        areas = preference.layouts
    }
}

struct WindowCommandShortcutSettingsSnapshot: Codable {
    var isEnabled: Bool
    var key: CustomShortcutKey?
    var defaultKey: CustomShortcutKey?
    var defaultKeys: [CustomShortcutKey]?
    var suppressesDefaultKey: Bool?
}

struct WindowCommandDisplaySettingsSnapshot: Codable {
    var showInMenu: Bool
    var showInModal: Bool
}

enum SettingsFileStore {
    private static let appSupportDirectoryName = "Cyclope"
    private static let settingsFileName = "settings.json"
    private static let defaultSettingsFileName = "settings.default.json"

    static func loadUserSettings() -> AppSettingsSnapshot? {
        removeCachedDefaultSettingsFileIfPresent()
        guard var settings = loadSettings(from: settingsURL) else { return nil }
        settings.normalizeForStorage()
        save(settings)
        return settings
    }

    static func loadDefaultSettings() -> AppSettingsSnapshot? {
        removeCachedDefaultSettingsFileIfPresent()
        return loadBundledDefaultSettings()
    }

    static func saveSnapSettings(_ snapshot: SnapSettingsSnapshot) {
        var settings = loadUserSettings() ?? loadDefaultSettings() ?? AppSettingsSnapshot()
        settings.windowManager.applySnapSettings(snapshot)
        save(settings)
    }

    static func saveShortcutSettings(_ snapshot: ShortcutSettingsSnapshot) {
        var settings = loadUserSettings() ?? loadDefaultSettings() ?? AppSettingsSnapshot()
        settings.windowManager.applyShortcutSettings(snapshot)
        save(settings)
    }

    static func saveMenuCategorySettings(_ snapshot: [MenuCategorySettingsSnapshot]) {
        var settings = loadUserSettings() ?? loadDefaultSettings() ?? AppSettingsSnapshot()
        settings.windowManager.applyMenuCategorySettings(snapshot)
        save(settings)
    }

    static func saveSleepPreventionSettings(_ snapshot: SleepPreventionSettingsSnapshot) {
        var settings = loadUserSettings() ?? loadDefaultSettings() ?? AppSettingsSnapshot()
        settings.sleepPrevention = snapshot
        save(settings)
    }

    static func saveScrollDirectionSettings(_ snapshot: ScrollDirectionSettingsSnapshot) {
        var settings = loadUserSettings() ?? loadDefaultSettings() ?? AppSettingsSnapshot()
        settings.scrollDirection = snapshot
        save(settings)
    }

    @discardableResult
    static func restoreDefaultSettings() -> AppSettingsSnapshot? {
        guard let defaultSettings = loadDefaultSettings() else { return nil }
        save(defaultSettings)
        return defaultSettings
    }

    private static func save(_ settings: AppSettingsSnapshot) {
        var settings = settings
        settings.schemaVersion = AppSettingsSnapshot.currentSchemaVersion

        guard let data = encode(settings) else { return }

        do {
            try ensureApplicationSupportDirectory()
            if data == encodedDefaultSettings() {
                try removeUserSettingsFileIfPresent()
                return
            }

            if let currentData = try? Data(contentsOf: settingsURL),
               currentData == data {
                return
            }

            try data.write(to: settingsURL, options: [.atomic])
        } catch {
            return
        }
    }

    private static func loadSettings(from url: URL) -> AppSettingsSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let settings = try? decoder.decode(AppSettingsSnapshot.self, from: data),
              settings.schemaVersion == AppSettingsSnapshot.currentSchemaVersion else {
            return nil
        }

        return settings
    }

    private static func loadBundledDefaultSettings() -> AppSettingsSnapshot? {
        guard let url = Bundle.main.url(
            forResource: "settings.default",
            withExtension: "json"
        ) else {
            return nil
        }

        return loadSettings(from: url)
    }

    private static func encode(_ settings: AppSettingsSnapshot) -> Data? {
        try? encoder.encode(settings)
    }

    private static func encodedDefaultSettings() -> Data? {
        guard let defaultSettings = loadBundledDefaultSettings() else { return nil }
        return encode(defaultSettings)
    }

    private static func ensureApplicationSupportDirectory() throws {
        try FileManager.default.createDirectory(
            at: applicationSupportDirectory,
            withIntermediateDirectories: true
        )
    }

    private static func removeUserSettingsFileIfPresent() throws {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return }
        try FileManager.default.removeItem(at: settingsURL)
    }

    private static func removeCachedDefaultSettingsFileIfPresent() {
        guard FileManager.default.fileExists(atPath: defaultSettingsURL.path) else { return }
        try? FileManager.default.removeItem(at: defaultSettingsURL)
    }

    private static var applicationSupportDirectory: URL {
        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        return baseURL.appendingPathComponent(appSupportDirectoryName, isDirectory: true)
    }

    private static var settingsURL: URL {
        applicationSupportDirectory.appendingPathComponent(settingsFileName)
    }

    private static var defaultSettingsURL: URL {
        applicationSupportDirectory.appendingPathComponent(defaultSettingsFileName)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

private extension ShortcutCommand {
    var settingsIdentifier: String {
        switch self {
        case .snapLeft:
            return "snap_left"
        case .snapRight:
            return "snap_right"
        case .snapTop:
            return "snap_top"
        case .snapBottom:
            return "snap_bottom"
        case .snapFullScreen:
            return "snap_full_screen"
        case .snapCenter:
            return "snap_center"
        case .repeatLastSnap:
            return "repeat_last_snap"
        case .toggleSleepPrevention:
            return "toggle_sleep_prevention"
        case .toggleNaturalScrolling:
            return "toggle_natural_scrolling"
        case .toggleWheelMouseReverseScrolling:
            return "toggle_wheel_mouse_reverse_scrolling"
        }
    }

    init?(settingsIdentifier: String) {
        switch settingsIdentifier {
        case "snap_left", "snapLeft":
            self = .snapLeft
        case "snap_right", "snapRight":
            self = .snapRight
        case "snap_top", "snapTop":
            self = .snapTop
        case "snap_bottom", "snapBottom":
            self = .snapBottom
        case "snap_full_screen", "snapFullScreen":
            self = .snapFullScreen
        case "snap_center", "snapCenter":
            self = .snapCenter
        case "repeat_last_snap", "repeatLastSnap":
            self = .repeatLastSnap
        case "toggle_sleep_prevention", "toggleSleepPrevention":
            self = .toggleSleepPrevention
        case "toggle_natural_scrolling", "toggleNaturalScrolling":
            self = .toggleNaturalScrolling
        case "toggle_wheel_mouse_reverse_scrolling":
            self = .toggleWheelMouseReverseScrolling
        default:
            return nil
        }
    }
}

extension ShortcutSettingsSnapshot {
    static let defaultModalShortcutKey = CustomShortcutKey(
        keyCode: 1,
        symbol: "S",
        modifiers: [.option]
    )

    static var defaultSettings: ShortcutSettingsSnapshot {
        ShortcutSettingsSnapshot(
            preferences: Dictionary(uniqueKeysWithValues: ShortcutCommand.allCases.map { ($0, .default) }),
            customPreferences: defaultCustomPreferences,
            isModalShortcutEnabled: true,
            modalShortcutKey: defaultModalShortcutKey
        )
    }

    private static var defaultCustomPreferences: [CustomSnapPreset.ID: ShortcutCommandPreference] {
        Dictionary(
            uniqueKeysWithValues: CustomSnapPreset.defaults.enumerated().compactMap { index, preset in
                guard GlobalShortcut.defaultCustomShortcutKey(forIndex: index) != nil else {
                    return nil
                }

                return (
                    preset.id,
                    ShortcutCommandPreference(
                        isPaletteEnabled: true,
                        isDirectEnabled: false,
                        paletteKey: nil,
                        directKey: nil,
                        suppressesDefaultDirectKey: nil,
                        showsInMenu: true,
                        showsInCheatSheet: true
                    )
                )
            }
        )
    }
}

extension SnapSettingsSnapshot {
    static let defaultSnapActivationDwellDelay: TimeInterval = 0.45

    static var defaultSettings: SnapSettingsSnapshot {
        SnapSettingsSnapshot(
            presets: CustomSnapPreset.defaults,
            selectedPresetID: CustomSnapPreset.defaults.first?.id,
            defaultSnapPresentation: .expanded,
            customSnapPresentation: .collapsed,
            snapActivationDwellDelay: defaultSnapActivationDwellDelay,
            defaultCommandSnapActivations: defaultCommandSnapActivations
        )
    }

    static var defaultCommandSnapActivations: [ShortcutCommand: SnapActivationPreference] {
        Dictionary(
            uniqueKeysWithValues: ShortcutCommand.defaultCommands.compactMap { command in
                guard let preference = defaultCommandSnapActivation(for: command) else { return nil }
                return (command, preference)
            }
        )
    }

    private static func defaultCommandSnapActivation(for command: ShortcutCommand) -> SnapActivationPreference? {
        switch command {
        case .snapFullScreen, .snapCenter:
            return SnapActivationPreference(layouts: [], isEnabled: false)
        default:
            break
        }

        guard let layout = defaultCommandSnapActivationLayout(for: command) else { return nil }
        return SnapActivationPreference(layout: layout, isEnabled: true)
    }

    private static func defaultCommandSnapActivationLayout(for command: ShortcutCommand) -> SnapActivationLayout? {
        switch command {
        case .snapLeft:
            return SnapActivationLayout(
                startColumn: 0,
                startRow: SnapActivationLayout.desktopStartRow,
                columnSpan: 1,
                rowSpan: SnapActivationLayout.desktopRows
            )
        case .snapRight:
            return SnapActivationLayout(
                startColumn: SnapActivationLayout.columns - 1,
                startRow: SnapActivationLayout.desktopStartRow,
                columnSpan: 1,
                rowSpan: SnapActivationLayout.desktopRows
            )
        case .snapTop:
            return SnapActivationLayout(startColumn: 5, startRow: 0, columnSpan: 8, rowSpan: 1)
        case .snapFullScreen:
            return SnapActivationLayout(startColumn: 7, startRow: 0, columnSpan: 4, rowSpan: 1)
        case .snapCenter:
            return SnapActivationLayout(startColumn: 12, startRow: 0, columnSpan: 5, rowSpan: 1)
        case .snapBottom:
            return SnapActivationLayout(
                startColumn: 5,
                startRow: SnapActivationLayout.rows - 1,
                columnSpan: 8,
                rowSpan: 1
            )
        case .repeatLastSnap, .toggleSleepPrevention, .toggleNaturalScrolling, .toggleWheelMouseReverseScrolling:
            return nil
        }
    }
}
