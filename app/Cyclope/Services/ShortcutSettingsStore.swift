//
//  ShortcutSettingsStore.swift
//  Cyclope
//

import Combine
import AppKit
import Foundation
import SwiftUI

struct CustomShortcutKey: Codable, Equatable, Hashable {
    let keyCode: Int
    let symbol: String
    let modifiers: [CustomShortcutModifier]?

    init?(event: NSEvent) {
        if event.keyCode == 53 || Self.isClearEvent(event) {
            return nil
        }

        guard let symbol = Self.symbol(for: Int(event.keyCode), characters: event.charactersIgnoringModifiers) else {
            return nil
        }

        self.keyCode = Int(event.keyCode)
        self.symbol = symbol
        self.modifiers = CustomShortcutModifier.modifiers(from: event)
    }

    init(keyCode: Int, symbol: String, modifiers: [CustomShortcutModifier] = []) {
        self.keyCode = keyCode
        self.symbol = symbol
        self.modifiers = modifiers
    }

    var directSymbols: String {
        symbols(defaultModifiers: CustomShortcutModifier.defaultDirectModifiers)
    }

    var paletteSymbols: String {
        symbols()
    }

    func symbols(defaultModifiers: [CustomShortcutModifier] = []) -> String {
        (resolvedModifiers(defaultModifiers: defaultModifiers).map(\.symbol) + [symbol])
            .joined(separator: " + ")
    }

    func matches(_ event: NSEvent, defaultModifiers: [CustomShortcutModifier] = []) -> Bool {
        keyCode == Int(event.keyCode) &&
            resolvedModifiers(defaultModifiers: defaultModifiers) == CustomShortcutModifier.modifiers(from: event)
    }

    func matches(_ other: CustomShortcutKey, defaultModifiers: [CustomShortcutModifier] = []) -> Bool {
        keyCode == other.keyCode &&
            resolvedModifiers(defaultModifiers: defaultModifiers) ==
            other.resolvedModifiers(defaultModifiers: defaultModifiers)
    }

    static func isClearEvent(_ event: NSEvent) -> Bool {
        event.keyCode == 51 || event.keyCode == 117
    }

    private func resolvedModifiers(defaultModifiers: [CustomShortcutModifier]) -> [CustomShortcutModifier] {
        modifiers ?? defaultModifiers
    }

    private static func symbol(for keyCode: Int, characters: String?) -> String? {
        switch keyCode {
        case 36:
            return "↩"
        case 48:
            return "⇥"
        case 49:
            return "Space"
        case 123:
            return "←"
        case 124:
            return "→"
        case 125:
            return "↓"
        case 126:
            return "↑"
        default:
            if let symbol = englishSymbol(forKeyCode: keyCode) {
                return symbol
            }

            guard let characters,
                  let character = characters.uppercased().first,
                  character.isASCII,
                  !character.isWhitespace else {
                return nil
            }

            return String(character)
        }
    }

    private static func englishSymbol(forKeyCode keyCode: Int) -> String? {
        englishKeySymbols[keyCode]
    }

    private static let englishKeySymbols: [Int: String] = [
        0: "A",
        1: "S",
        2: "D",
        3: "F",
        4: "H",
        5: "G",
        6: "Z",
        7: "X",
        8: "C",
        9: "V",
        11: "B",
        12: "Q",
        13: "W",
        14: "E",
        15: "R",
        16: "Y",
        17: "T",
        18: "1",
        19: "2",
        20: "3",
        21: "4",
        22: "6",
        23: "5",
        24: "=",
        25: "9",
        26: "7",
        27: "-",
        28: "8",
        29: "0",
        30: "]",
        31: "O",
        32: "U",
        33: "[",
        34: "I",
        35: "P",
        37: "L",
        38: "J",
        39: "'",
        40: "K",
        41: ";",
        42: "\\",
        43: ",",
        44: "/",
        45: "N",
        46: "M",
        47: ".",
        50: "`",
        65: ".",
        67: "*",
        69: "+",
        75: "/",
        76: "↩",
        78: "-",
        81: "=",
        82: "0",
        83: "1",
        84: "2",
        85: "3",
        86: "4",
        87: "5",
        88: "6",
        89: "7",
        91: "8",
        92: "9"
    ]
}

enum CustomShortcutModifier: String, Codable, Hashable, CaseIterable {
    case control
    case option
    case shift
    case command

    static let defaultDirectModifiers: [CustomShortcutModifier] = [.control, .option, .command]
    static let defaultSnapDirectModifiers: [CustomShortcutModifier] = [.option, .shift]

    var symbol: String {
        switch self {
        case .control:
            return "⌃"
        case .option:
            return "⌥"
        case .shift:
            return "⇧"
        case .command:
            return "⌘"
        }
    }

    private var flag: NSEvent.ModifierFlags {
        switch self {
        case .control:
            return .control
        case .option:
            return .option
        case .shift:
            return .shift
        case .command:
            return .command
        }
    }

    static func modifiers(from event: NSEvent) -> [CustomShortcutModifier] {
        let flags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])

        return allCases.filter { flags.contains($0.flag) }
    }
}

enum ShortcutAssignment: Equatable {
    case modalShortcut
    case commandModal(ShortcutCommand)
    case commandGlobal(ShortcutCommand)
    case customModal(CustomSnapPreset.ID)
    case customGlobal(CustomSnapPreset.ID)
}

@MainActor
final class ShortcutSettingsStore: ObservableObject {
    @Published private var preferences: [ShortcutCommand: ShortcutCommandPreference] {
        didSet { save() }
    }
    @Published private var customPreferences: [CustomSnapPreset.ID: ShortcutCommandPreference] {
        didSet { save() }
    }
    @Published var isModalShortcutEnabled: Bool {
        didSet { save() }
    }
    @Published private(set) var modalShortcutKey: CustomShortcutKey {
        didSet { save() }
    }
    @Published private(set) var menuCategories: [MenuCategorySettingsSnapshot] {
        didSet { saveMenuCategories() }
    }

    private let legacyDefaultsKey = "shortcutSettings"

    init() {
        if let settings = SettingsFileStore.loadUserSettings(),
           let snapshot = settings.windowManager.shortcutSettings {
            preferences = snapshot.preferences
            customPreferences = snapshot.customPreferences ?? [:]
            isModalShortcutEnabled = snapshot.isModalShortcutEnabled ?? true
            modalShortcutKey = snapshot.modalShortcutKey ?? Self.defaultModalShortcutKey
            menuCategories = MenuCategorySettingsSnapshot.normalized(settings.windowManager.menuCategories)
        } else if let snapshot = Self.loadSnapshot(from: legacyDefaultsKey) {
            preferences = snapshot.preferences
            customPreferences = snapshot.customPreferences ?? [:]
            isModalShortcutEnabled = snapshot.isModalShortcutEnabled ?? true
            modalShortcutKey = snapshot.modalShortcutKey ?? Self.defaultModalShortcutKey
            menuCategories = MenuCategorySettingsSnapshot.defaultSettings
        } else if let settings = SettingsFileStore.loadDefaultSettings(),
                  let snapshot = settings.windowManager.shortcutSettings {
            preferences = snapshot.preferences
            customPreferences = snapshot.customPreferences ?? [:]
            isModalShortcutEnabled = snapshot.isModalShortcutEnabled ?? true
            modalShortcutKey = snapshot.modalShortcutKey ?? Self.defaultModalShortcutKey
            menuCategories = MenuCategorySettingsSnapshot.normalized(settings.windowManager.menuCategories)
        } else {
            preferences = [:]
            customPreferences = [:]
            isModalShortcutEnabled = true
            modalShortcutKey = Self.defaultModalShortcutKey
            menuCategories = MenuCategorySettingsSnapshot.defaultSettings
        }

        normalizePreferences()
    }

    static let defaultModalShortcutKey = CustomShortcutKey(
        keyCode: 1,
        symbol: "S",
        modifiers: [.option]
    )

    func isPaletteEnabled(_ command: ShortcutCommand) -> Bool {
        preference(for: command).isPaletteEnabled
    }

    func isDirectEnabled(_ command: ShortcutCommand) -> Bool {
        preference(for: command).isDirectEnabled
    }

    func paletteKey(for command: ShortcutCommand) -> CustomShortcutKey? {
        preference(for: command).paletteKey
    }

    func directKey(for command: ShortcutCommand) -> CustomShortcutKey? {
        preference(for: command).directKey
    }

    func paletteKeys(for command: ShortcutCommand) -> [CustomShortcutKey] {
        guard isPaletteEnabled(command) else { return [] }
        if let paletteKey = paletteKey(for: command) {
            return [paletteKey]
        }

        return command.defaultPaletteShortcutKeys
    }

    func hasPaletteShortcut(for command: ShortcutCommand) -> Bool {
        !paletteKeys(for: command).isEmpty
    }

    func directKeyToMatch(for command: ShortcutCommand) -> CustomShortcutKey? {
        directKeysToMatch(for: command).first
    }

    func directKeysToMatch(for command: ShortcutCommand) -> [CustomShortcutKey] {
        let preference = preference(for: command)
        var keys: [CustomShortcutKey] = []

        if let directKey = preference.directKey {
            keys.append(directKey)
        }

        if preference.suppressesDefaultDirectKey != true,
           command.enablesDefaultDirectShortcut || preference.isDirectEnabled {
            keys.append(command.defaultDirectShortcutKey)
        }

        return keys.removingDuplicates()
    }

    func hasDirectShortcut(for command: ShortcutCommand) -> Bool {
        !directKeysToMatch(for: command).isEmpty
    }

    func paletteKeySymbols(for command: ShortcutCommand) -> String {
        guard isPaletteEnabled(command) else { return String(localized: "None") }
        if let paletteKey = paletteKey(for: command) {
            return paletteKey.paletteSymbols
        }

        return command.paletteKeys
    }

    func directKeySymbols(for command: ShortcutCommand) -> String {
        let preference = preference(for: command)

        if let directKey = preference.directKey {
            return directKey.directSymbols
        }

        guard preference.suppressesDefaultDirectKey != true,
              command.enablesDefaultDirectShortcut || preference.isDirectEnabled else {
            return String(localized: "None")
        }

        return command.defaultDirectShortcutKey.directSymbols
    }

    func bindingForPalette(_ command: ShortcutCommand) -> Binding<Bool> {
        Binding(
            get: { self.isPaletteEnabled(command) },
            set: { self.setPaletteEnabled($0, for: command) }
        )
    }

    func bindingForDirect(_ command: ShortcutCommand) -> Binding<Bool> {
        Binding(
            get: { self.isDirectEnabled(command) },
            set: { self.setDirectEnabled($0, for: command) }
        )
    }

    func isMenuDisplayEnabled(_ command: ShortcutCommand) -> Bool {
        preference(for: command).showsInMenu ?? true
    }

    func isCheatSheetDisplayEnabled(_ command: ShortcutCommand) -> Bool {
        preference(for: command).showsInCheatSheet ?? true
    }

    func bindingForMenuDisplay(_ command: ShortcutCommand) -> Binding<Bool> {
        Binding(
            get: { self.isMenuDisplayEnabled(command) },
            set: { self.setMenuDisplayEnabled($0, for: command) }
        )
    }

    func bindingForCheatSheetDisplay(_ command: ShortcutCommand) -> Binding<Bool> {
        Binding(
            get: { self.isCheatSheetDisplayEnabled(command) },
            set: { self.setCheatSheetDisplayEnabled($0, for: command) }
        )
    }

    func bindingForModalShortcutEnabled() -> Binding<Bool> {
        Binding(
            get: { self.isModalShortcutEnabled },
            set: { self.isModalShortcutEnabled = $0 }
        )
    }

    var displayedMenuCategories: [AppMenuCategory] {
        menuCategories
            .filter(\.showInMenu)
            .map(\.category)
    }

    func isMenuCategoryDisplayEnabled(_ category: AppMenuCategory) -> Bool {
        menuCategories.first { $0.category == category }?.showInMenu ?? true
    }

    func bindingForMenuCategoryDisplay(_ category: AppMenuCategory) -> Binding<Bool> {
        Binding(
            get: { self.isMenuCategoryDisplayEnabled(category) },
            set: { self.setMenuCategoryDisplayEnabled($0, for: category) }
        )
    }

    func moveMenuCategory(_ sourceCategory: AppMenuCategory, toInsertionIndex insertionIndex: Int) {
        var normalizedCategories = MenuCategorySettingsSnapshot.normalized(menuCategories)
        guard let sourceIndex = normalizedCategories.firstIndex(where: { $0.category == sourceCategory }),
              insertionIndex != sourceIndex,
              insertionIndex != sourceIndex + 1 else {
            return
        }

        let movingCategory = normalizedCategories.remove(at: sourceIndex)
        let adjustedInsertionIndex = sourceIndex < insertionIndex ? insertionIndex - 1 : insertionIndex
        let destination = max(0, min(adjustedInsertionIndex, normalizedCategories.count))
        normalizedCategories.insert(movingCategory, at: destination)
        menuCategories = normalizedCategories
    }

    func modalShortcutConflict(
        for key: CustomShortcutKey,
        excluding excludedAssignment: ShortcutAssignment? = nil,
        customPresets: [CustomSnapPreset]
    ) -> ShortcutAssignment? {
        for command in ShortcutCommand.allCases {
            let assignment = ShortcutAssignment.commandModal(command)
            guard assignment != excludedAssignment else { continue }
            if paletteKeys(for: command).contains(where: { $0.matches(key) }) {
                return assignment
            }
        }

        for (index, preset) in customPresets.enumerated() {
            let assignment = ShortcutAssignment.customModal(preset.id)
            guard assignment != excludedAssignment,
                  isCustomPaletteEnabled(preset.id) else {
                continue
            }

            let shortcutKey = customPaletteKey(for: preset.id) ??
                GlobalShortcut.defaultCustomShortcutKey(forIndex: index)
            if shortcutKey?.matches(key) == true {
                return assignment
            }
        }

        return nil
    }

    func globalShortcutConflict(
        for key: CustomShortcutKey,
        excluding excludedAssignment: ShortcutAssignment? = nil,
        customPresets: [CustomSnapPreset]
    ) -> ShortcutAssignment? {
        if excludedAssignment != .modalShortcut,
           isModalShortcutEnabled,
           modalShortcutKey.matches(key) {
            return .modalShortcut
        }

        for command in ShortcutCommand.allCases {
            let assignment = ShortcutAssignment.commandGlobal(command)
            guard assignment != excludedAssignment else {
                continue
            }

            if directKeysToMatch(for: command).contains(where: {
                $0.matches(key, defaultModifiers: CustomShortcutModifier.defaultDirectModifiers)
            }) {
                return assignment
            }
        }

        for preset in customPresets {
            let assignment = ShortcutAssignment.customGlobal(preset.id)
            guard assignment != excludedAssignment,
                  isCustomDirectEnabled(preset.id),
                  let shortcutKey = customDirectKey(for: preset.id) else {
                continue
            }

            if shortcutKey.matches(key, defaultModifiers: CustomShortcutModifier.defaultDirectModifiers) {
                return assignment
            }
        }

        return nil
    }

    func removeGlobalShortcutAssignment(_ assignment: ShortcutAssignment, matching key: CustomShortcutKey) {
        switch assignment {
        case .modalShortcut:
            isModalShortcutEnabled = false
        case .commandGlobal(let command):
            removeDirectShortcutConflict(for: command, matching: key)
        case .customGlobal(let presetID):
            clearCustomDirectKey(for: presetID)
        case .commandModal, .customModal:
            break
        }
    }

    func setModalShortcutKey(_ key: CustomShortcutKey) {
        modalShortcutKey = key
        isModalShortcutEnabled = true
    }

    func resetModalShortcutKey() {
        modalShortcutKey = Self.defaultModalShortcutKey
    }

    func apply(
        _ snapshot: ShortcutSettingsSnapshot,
        menuCategories: [MenuCategorySettingsSnapshot]? = nil
    ) {
        pendingSave?.cancel()
        pendingSave = nil
        isApplyingSnapshot = true
        defer { isApplyingSnapshot = false }

        preferences = snapshot.preferences
        customPreferences = snapshot.customPreferences ?? [:]
        isModalShortcutEnabled = snapshot.isModalShortcutEnabled ?? true
        modalShortcutKey = snapshot.modalShortcutKey ?? Self.defaultModalShortcutKey
        if let menuCategories {
            pendingMenuCategorySave?.cancel()
            pendingMenuCategorySave = nil
            self.menuCategories = MenuCategorySettingsSnapshot.normalized(menuCategories)
        }
        normalizePreferences()
    }

    func setPaletteKey(_ key: CustomShortcutKey, for command: ShortcutCommand) {
        var preference = preference(for: command)
        preference.paletteKey = key
        preference.isPaletteEnabled = true
        preference.showsInCheatSheet = preference.showsInCheatSheet ?? true
        preferences[command] = preference
    }

    func setDirectKey(_ key: CustomShortcutKey, for command: ShortcutCommand) {
        var preference = preference(for: command)
        preference.directKey = key
        preference.isDirectEnabled = true
        preference.suppressesDefaultDirectKey = false
        preference.showsInMenu = preference.showsInMenu ?? true
        preferences[command] = preference
    }

    func resetPaletteKey(for command: ShortcutCommand) {
        var preference = preference(for: command)
        preference.paletteKey = nil
        preference.isPaletteEnabled = true
        preferences[command] = preference
    }

    func resetDirectKey(for command: ShortcutCommand) {
        var preference = preference(for: command)
        preference.directKey = nil
        preference.isDirectEnabled = false
        preference.suppressesDefaultDirectKey = false
        preferences[command] = preference
    }

    func clearPaletteKey(for command: ShortcutCommand) {
        var preference = preference(for: command)
        preference.paletteKey = nil
        preference.isPaletteEnabled = false
        preferences[command] = preference
    }

    func clearDirectKey(for command: ShortcutCommand) {
        var preference = preference(for: command)
        preference.directKey = nil
        preference.isDirectEnabled = false
        preference.suppressesDefaultDirectKey = true
        preferences[command] = preference
    }

    func isCustomPaletteEnabled(_ presetID: CustomSnapPreset.ID) -> Bool {
        let preference = customPreference(for: presetID)
        return preference.paletteKey != nil || preference.isPaletteEnabled
    }

    func isCustomDirectEnabled(_ presetID: CustomSnapPreset.ID) -> Bool {
        customPreference(for: presetID).directKey != nil
    }

    func isCustomMenuDisplayEnabled(_ presetID: CustomSnapPreset.ID) -> Bool {
        customPreference(for: presetID).showsInMenu ?? true
    }

    func isCustomCheatSheetDisplayEnabled(_ presetID: CustomSnapPreset.ID) -> Bool {
        isCustomPaletteEnabled(presetID) && (customPreference(for: presetID).showsInCheatSheet ?? true)
    }

    func bindingForCustomMenuDisplay(_ presetID: CustomSnapPreset.ID) -> Binding<Bool> {
        Binding(
            get: { self.isCustomMenuDisplayEnabled(presetID) },
            set: { self.setCustomMenuDisplayEnabled($0, for: presetID) }
        )
    }

    func bindingForCustomCheatSheetDisplay(_ presetID: CustomSnapPreset.ID) -> Binding<Bool> {
        Binding(
            get: { self.isCustomCheatSheetDisplayEnabled(presetID) },
            set: { self.setCustomCheatSheetDisplayEnabled($0, for: presetID) }
        )
    }

    func customPaletteKey(for presetID: CustomSnapPreset.ID) -> CustomShortcutKey? {
        customPreference(for: presetID).paletteKey
    }

    func customDirectKey(for presetID: CustomSnapPreset.ID) -> CustomShortcutKey? {
        customPreference(for: presetID).directKey
    }

    func enableCustomPaletteShortcut(for presetID: CustomSnapPreset.ID) {
        var preference = customPreference(for: presetID)
        preference.isPaletteEnabled = true
        preference.showsInCheatSheet = preference.showsInCheatSheet ?? true
        customPreferences[presetID] = preference
    }

    func setCustomPaletteKey(_ key: CustomShortcutKey, for presetID: CustomSnapPreset.ID) {
        var preference = customPreference(for: presetID)
        preference.paletteKey = key
        preference.isPaletteEnabled = true
        preference.showsInCheatSheet = preference.showsInCheatSheet ?? true
        customPreferences[presetID] = preference
    }

    func setCustomDirectKey(_ key: CustomShortcutKey, for presetID: CustomSnapPreset.ID) {
        var preference = customPreference(for: presetID)
        preference.directKey = key
        preference.isDirectEnabled = true
        preference.showsInMenu = preference.showsInMenu ?? true
        customPreferences[presetID] = preference
    }

    func clearCustomPaletteKey(for presetID: CustomSnapPreset.ID) {
        var preference = customPreference(for: presetID)
        preference.paletteKey = nil
        preference.isPaletteEnabled = false
        customPreferences[presetID] = preference
    }

    func clearCustomDirectKey(for presetID: CustomSnapPreset.ID) {
        var preference = customPreference(for: presetID)
        preference.directKey = nil
        preference.isDirectEnabled = false
        customPreferences[presetID] = preference
    }

    func removeCustomPreference(for presetID: CustomSnapPreset.ID) {
        customPreferences.removeValue(forKey: presetID)
    }

    func removeCustomPreferences(excluding presetIDs: Set<CustomSnapPreset.ID>) {
        customPreferences = customPreferences.filter { presetIDs.contains($0.key) }
    }

    func paletteCommands() -> [ShortcutCommand] {
        ShortcutCommand.allCases.filter { isPaletteEnabled($0) }
    }

    private func setPaletteEnabled(_ isEnabled: Bool, for command: ShortcutCommand) {
        var preference = preference(for: command)
        preference.isPaletteEnabled = isEnabled
        preferences[command] = preference
    }

    private func setDirectEnabled(_ isEnabled: Bool, for command: ShortcutCommand) {
        var preference = preference(for: command)
        preference.isDirectEnabled = isEnabled
        if isEnabled {
            preference.suppressesDefaultDirectKey = false
        }
        preferences[command] = preference
    }

    private func removeDirectShortcutConflict(for command: ShortcutCommand, matching key: CustomShortcutKey) {
        var preference = preference(for: command)
        let defaultKeyMatches = command.defaultDirectShortcutKey.matches(
            key,
            defaultModifiers: CustomShortcutModifier.defaultDirectModifiers
        )

        preference.directKey = nil
        preference.isDirectEnabled = false
        preference.suppressesDefaultDirectKey = defaultKeyMatches
        preferences[command] = preference
    }

    private func setMenuDisplayEnabled(_ isEnabled: Bool, for command: ShortcutCommand) {
        var preference = preference(for: command)
        preference.showsInMenu = isEnabled
        preferences[command] = preference
    }

    private func setCheatSheetDisplayEnabled(_ isEnabled: Bool, for command: ShortcutCommand) {
        var preference = preference(for: command)
        preference.showsInCheatSheet = isEnabled
        preferences[command] = preference
    }

    private func setMenuCategoryDisplayEnabled(_ isEnabled: Bool, for category: AppMenuCategory) {
        var normalizedCategories = MenuCategorySettingsSnapshot.normalized(menuCategories)
        guard let index = normalizedCategories.firstIndex(where: { $0.category == category }) else {
            return
        }

        normalizedCategories[index].showInMenu = isEnabled
        menuCategories = normalizedCategories
    }

    private func setCustomMenuDisplayEnabled(_ isEnabled: Bool, for presetID: CustomSnapPreset.ID) {
        var preference = customPreference(for: presetID)
        preference.showsInMenu = isEnabled
        customPreferences[presetID] = preference
    }

    private func setCustomCheatSheetDisplayEnabled(_ isEnabled: Bool, for presetID: CustomSnapPreset.ID) {
        var preference = customPreference(for: presetID)
        preference.showsInCheatSheet = isEnabled
        customPreferences[presetID] = preference
    }

    private func preference(for command: ShortcutCommand) -> ShortcutCommandPreference {
        preferences[command] ?? .default
    }

    private func customPreference(for presetID: CustomSnapPreset.ID) -> ShortcutCommandPreference {
        customPreferences[presetID] ?? .customDefault
    }

    private func normalizePreferences() {
        var normalized = preferences

        for command in ShortcutCommand.allCases where normalized[command] == nil {
            normalized[command] = .default
        }

        preferences = normalized.filter { command, _ in
            ShortcutCommand.allCases.contains(command)
        }
    }

    // Coalesce rapid mutations into a single file write; flush on termination.
    private func save() {
        guard !isApplyingSnapshot else { return }
        registerTerminationFlushIfNeeded()
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.persist() }
        }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func saveMenuCategories() {
        guard !isApplyingSnapshot else { return }
        registerTerminationFlushIfNeeded()
        pendingMenuCategorySave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.persistMenuCategories() }
        }
        pendingMenuCategorySave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func persist() {
        pendingSave = nil
        let snapshot = ShortcutSettingsSnapshot(
            preferences: preferences,
            customPreferences: customPreferences,
            isModalShortcutEnabled: isModalShortcutEnabled,
            modalShortcutKey: modalShortcutKey
        )
        SettingsFileStore.saveShortcutSettings(snapshot)
    }

    private func persistMenuCategories() {
        pendingMenuCategorySave = nil
        SettingsFileStore.saveMenuCategorySettings(menuCategories)
    }

    private func registerTerminationFlushIfNeeded() {
        guard !didRegisterTerminationFlush else { return }
        didRegisterTerminationFlush = true
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.flushPendingSave() }
        }
    }

    private func flushPendingSave() {
        if pendingSave != nil {
            pendingSave?.cancel()
            persist()
        }

        if pendingMenuCategorySave != nil {
            pendingMenuCategorySave?.cancel()
            persistMenuCategories()
        }
    }

    private var pendingSave: DispatchWorkItem?
    private var pendingMenuCategorySave: DispatchWorkItem?
    private var didRegisterTerminationFlush = false
    private var isApplyingSnapshot = false

    private static func loadSnapshot(from key: String) -> ShortcutSettingsSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ShortcutSettingsSnapshot.self, from: data)
    }
}

struct ShortcutCommandPreference: Codable {
    var isPaletteEnabled: Bool
    var isDirectEnabled: Bool
    var paletteKey: CustomShortcutKey?
    var directKey: CustomShortcutKey?
    var suppressesDefaultDirectKey: Bool?
    var showsInMenu: Bool?
    var showsInCheatSheet: Bool?

    static let `default` = ShortcutCommandPreference(
        isPaletteEnabled: true,
        isDirectEnabled: false,
        paletteKey: nil,
        directKey: nil,
        suppressesDefaultDirectKey: nil,
        showsInMenu: nil,
        showsInCheatSheet: nil
    )

    static let customDefault = ShortcutCommandPreference(
        isPaletteEnabled: true,
        isDirectEnabled: false,
        paletteKey: nil,
        directKey: nil,
        suppressesDefaultDirectKey: nil,
        showsInMenu: nil,
        showsInCheatSheet: nil
    )
}

struct ShortcutSettingsSnapshot: Codable {
    var preferences: [ShortcutCommand: ShortcutCommandPreference]
    var customPreferences: [CustomSnapPreset.ID: ShortcutCommandPreference]?
    var isModalShortcutEnabled: Bool?
    var modalShortcutKey: CustomShortcutKey?

    enum CodingKeys: String, CodingKey {
        case preferences
        case customPreferences
        case isModalShortcutEnabled
        case modalShortcutKey
    }

    init(
        preferences: [ShortcutCommand: ShortcutCommandPreference],
        customPreferences: [CustomSnapPreset.ID: ShortcutCommandPreference]?,
        isModalShortcutEnabled: Bool?,
        modalShortcutKey: CustomShortcutKey?
    ) {
        self.preferences = preferences
        self.customPreferences = customPreferences
        self.isModalShortcutEnabled = isModalShortcutEnabled
        self.modalShortcutKey = modalShortcutKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preferences = try container.decode([ShortcutCommand: ShortcutCommandPreference].self, forKey: .preferences)
        isModalShortcutEnabled = try container.decodeIfPresent(Bool.self, forKey: .isModalShortcutEnabled)
        modalShortcutKey = try container.decodeIfPresent(CustomShortcutKey.self, forKey: .modalShortcutKey)

        if let customPreferenceMap = try? container.decode(
            [String: ShortcutCommandPreference].self,
            forKey: .customPreferences
        ) {
            customPreferences = Dictionary(
                uniqueKeysWithValues: customPreferenceMap.compactMap { key, value in
                    guard let id = UUID(uuidString: key) else { return nil }
                    return (id, value)
                }
            )
        } else {
            customPreferences = try container.decodeIfPresent(
                [CustomSnapPreset.ID: ShortcutCommandPreference].self,
                forKey: .customPreferences
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(preferences, forKey: .preferences)

        let customPreferenceMap = Dictionary(
            uniqueKeysWithValues: (customPreferences ?? [:]).map { key, value in
                (key.uuidString, value)
            }
        )
        try container.encode(customPreferenceMap, forKey: .customPreferences)
        try container.encodeIfPresent(isModalShortcutEnabled, forKey: .isModalShortcutEnabled)
        try container.encodeIfPresent(modalShortcutKey, forKey: .modalShortcutKey)
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
