//
//  SnapSettingsStore.swift
//  Cyclope
//

import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class SnapSettingsStore: ObservableObject {
    @Published var presets: [CustomSnapPreset] {
        didSet { save() }
    }
    @Published var selectedPresetID: CustomSnapPreset.ID? {
        didSet { save() }
    }
    @Published var defaultSnapPresentation: SnapMenuPresentation {
        didSet { save() }
    }
    @Published var customSnapPresentation: SnapMenuPresentation {
        didSet { save() }
    }
    @Published private(set) var snapActivationDwellDelay: TimeInterval {
        didSet { save() }
    }
    @Published var defaultCommandSnapActivations: [ShortcutCommand: SnapActivationPreference] {
        didSet { save() }
    }

    static let snapActivationDwellDelayMillisecondsRange: ClosedRange<Int> = 0...1000

    private let legacyDefaultsKey = "snapSettings"
    private var pendingSave: DispatchWorkItem?
    private var didRegisterTerminationFlush = false
    private var isApplyingSnapshot = false

    var selectedPreset: CustomSnapPreset? {
        guard let selectedPresetID else { return presets.first }
        return presets.first { $0.id == selectedPresetID } ?? presets.first
    }

    init() {
        let savedSelectedPresetID: CustomSnapPreset.ID?

        if let snapshot = SettingsFileStore.loadUserSettings()?.windowManager.snapSettings {
            presets = snapshot.presets
            defaultSnapPresentation = snapshot.defaultSnapPresentation ?? .expanded
            customSnapPresentation = snapshot.customSnapPresentation ?? .collapsed
            snapActivationDwellDelay = Self.normalizedSnapActivationDwellDelay(
                snapshot.snapActivationDwellDelay
            )
            defaultCommandSnapActivations = Self.normalizedDefaultCommandSnapActivations(
                snapshot.defaultCommandSnapActivations ?? [:]
            )
            savedSelectedPresetID = snapshot.selectedPresetID
        } else if let snapshot = Self.loadSnapshot(from: legacyDefaultsKey) {
            presets = snapshot.presets
            defaultSnapPresentation = snapshot.defaultSnapPresentation ?? .expanded
            customSnapPresentation = snapshot.customSnapPresentation ?? .collapsed
            snapActivationDwellDelay = Self.normalizedSnapActivationDwellDelay(
                snapshot.snapActivationDwellDelay
            )
            defaultCommandSnapActivations = Self.normalizedDefaultCommandSnapActivations(
                snapshot.defaultCommandSnapActivations ?? [:]
            )
            savedSelectedPresetID = snapshot.selectedPresetID
        } else if let snapshot = SettingsFileStore.loadDefaultSettings()?.windowManager.snapSettings {
            presets = snapshot.presets
            defaultSnapPresentation = snapshot.defaultSnapPresentation ?? .expanded
            customSnapPresentation = snapshot.customSnapPresentation ?? .collapsed
            snapActivationDwellDelay = Self.normalizedSnapActivationDwellDelay(
                snapshot.snapActivationDwellDelay
            )
            defaultCommandSnapActivations = Self.normalizedDefaultCommandSnapActivations(
                snapshot.defaultCommandSnapActivations ?? [:]
            )
            savedSelectedPresetID = snapshot.selectedPresetID
        } else {
            presets = CustomSnapPreset.defaults
            defaultSnapPresentation = .expanded
            customSnapPresentation = .collapsed
            snapActivationDwellDelay = SnapSettingsSnapshot.defaultSnapActivationDwellDelay
            defaultCommandSnapActivations = Self.defaultCommandSnapActivations()
            savedSelectedPresetID = nil
        }

        selectedPresetID = nil
        normalizeAllPresets()
        normalizeSnapActivationOverlaps()

        if let savedSelectedPresetID,
           presets.contains(where: { $0.id == savedSelectedPresetID }) {
            selectedPresetID = savedSelectedPresetID
        } else {
            selectedPresetID = presets.first?.id
        }
    }

    func select(_ preset: CustomSnapPreset) {
        selectedPresetID = preset.id
    }

    func select(_ presetID: CustomSnapPreset.ID) {
        guard presets.contains(where: { $0.id == presetID }) else { return }
        selectedPresetID = presetID
    }

    func preset(withID presetID: CustomSnapPreset.ID) -> CustomSnapPreset? {
        presets.first { $0.id == presetID }
    }

    @discardableResult
    func addPreset() -> CustomSnapPreset {
        let preset = CustomSnapPreset(
            name: "Command",
            layout: SnapLayout(columns: 16, rows: 10, startColumn: 0, startRow: 0, columnSpan: 8, rowSpan: 10)
        )
        presets.append(preset)
        selectedPresetID = preset.id
        return preset
    }

    @discardableResult
    func duplicateSelectedPreset() -> CustomSnapPreset? {
        guard var preset = selectedPreset else { return nil }
        preset.id = UUID()
        preset.name = "\(preset.name) Copy"
        presets.append(preset)
        selectedPresetID = preset.id
        return preset
    }

    @discardableResult
    func duplicatePreset(_ presetID: CustomSnapPreset.ID) -> CustomSnapPreset? {
        guard var preset = preset(withID: presetID) else { return nil }
        preset.id = UUID()
        preset.name = "\(preset.name) Copy"
        presets.append(preset)
        selectedPresetID = preset.id
        return preset
    }

    func deleteSelectedPreset() {
        guard let selectedPresetID else { return }
        deletePreset(selectedPresetID)
    }

    func deletePreset(_ presetID: CustomSnapPreset.ID) {
        guard let deletedIndex = presets.firstIndex(where: { $0.id == presetID }) else {
            return
        }

        presets.remove(at: deletedIndex)

        if selectedPresetID == presetID {
            guard !presets.isEmpty else {
                selectedPresetID = nil
                return
            }

            selectedPresetID = presets[min(deletedIndex, presets.count - 1)].id
        } else if let selectedPresetID,
                  !presets.contains(where: { $0.id == selectedPresetID }) {
            self.selectedPresetID = presets.first?.id
        }
    }

    func movePresets(fromOffsets source: IndexSet, toOffset destination: Int) {
        let sourceIndexes = source.sorted().filter { presets.indices.contains($0) }
        guard !sourceIndexes.isEmpty else { return }

        let movingPresets = sourceIndexes.map { presets[$0] }
        var reorderedPresets = presets

        for index in sourceIndexes.reversed() {
            reorderedPresets.remove(at: index)
        }

        let removedBeforeDestination = sourceIndexes.filter { $0 < destination }.count
        let adjustedDestination = max(
            0,
            min(destination - removedBeforeDestination, reorderedPresets.count)
        )

        reorderedPresets.insert(contentsOf: movingPresets, at: adjustedDestination)
        presets = reorderedPresets
    }

    func movePreset(_ presetID: CustomSnapPreset.ID, toNeighbor targetPresetID: CustomSnapPreset.ID) {
        guard let sourceIndex = presets.firstIndex(where: { $0.id == presetID }),
              let targetIndex = presets.firstIndex(where: { $0.id == targetPresetID }),
              sourceIndex != targetIndex else {
            return
        }

        let destination = targetIndex > sourceIndex ? targetIndex + 1 : targetIndex
        movePresets(fromOffsets: IndexSet(integer: sourceIndex), toOffset: destination)
    }

    func movePreset(_ presetID: CustomSnapPreset.ID, toInsertionIndex insertionIndex: Int) {
        guard let sourceIndex = presets.firstIndex(where: { $0.id == presetID }),
              insertionIndex != sourceIndex,
              insertionIndex != sourceIndex + 1 else {
            return
        }

        var reorderedPresets = presets
        let movingPreset = reorderedPresets.remove(at: sourceIndex)
        let adjustedInsertionIndex = sourceIndex < insertionIndex ? insertionIndex - 1 : insertionIndex
        let destination = max(0, min(adjustedInsertionIndex, reorderedPresets.count))
        reorderedPresets.insert(movingPreset, at: destination)
        presets = reorderedPresets
    }

    func restoreDefaultPresets() {
        presets = CustomSnapPreset.defaults
        selectedPresetID = presets.first?.id
    }

    func apply(_ snapshot: SnapSettingsSnapshot) {
        pendingSave?.cancel()
        pendingSave = nil
        isApplyingSnapshot = true
        defer { isApplyingSnapshot = false }

        presets = snapshot.presets
        defaultSnapPresentation = snapshot.defaultSnapPresentation ?? .expanded
        customSnapPresentation = snapshot.customSnapPresentation ?? .collapsed
        snapActivationDwellDelay = Self.normalizedSnapActivationDwellDelay(
            snapshot.snapActivationDwellDelay
        )
        defaultCommandSnapActivations = Self.normalizedDefaultCommandSnapActivations(
            snapshot.defaultCommandSnapActivations ?? [:]
        )

        normalizeAllPresets()
        normalizeSnapActivationOverlaps()

        if let selectedPresetID = snapshot.selectedPresetID,
           presets.contains(where: { $0.id == selectedPresetID }) {
            self.selectedPresetID = selectedPresetID
        } else {
            selectedPresetID = presets.first?.id
        }
    }

    func renameSelectedPreset(_ name: String) {
        guard let selectedPresetID else { return }
        renamePreset(selectedPresetID, to: name)
    }

    func renamePreset(_ presetID: CustomSnapPreset.ID, to name: String) {
        updatePreset(presetID) { preset in
            preset.name = name
        }
    }

    func normalizeSelectedPresetName() {
        guard let selectedPresetID,
              let index = presets.firstIndex(where: { $0.id == selectedPresetID }) else {
            return
        }

        var preset = presets[index]
        let trimmedName = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
        preset.name = trimmedName.isEmpty ? "Untitled" : trimmedName
        presets[index] = preset
    }

    func normalizePresetName(_ presetID: CustomSnapPreset.ID) {
        guard let index = presets.firstIndex(where: { $0.id == presetID }) else {
            return
        }

        var preset = presets[index]
        let trimmedName = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
        preset.name = trimmedName.isEmpty ? "Untitled" : trimmedName
        presets[index] = preset
    }

    func normalizeAllPresets() {
        var usedIDs = Set<CustomSnapPreset.ID>()

        presets = presets.map { preset in
            var preset = preset

            while usedIDs.contains(preset.id) {
                preset.id = UUID()
            }
            usedIDs.insert(preset.id)

            let trimmedName = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
            preset.name = trimmedName.isEmpty ? "Untitled" : trimmedName
            return preset
        }
    }

    func updateSelectedLayout(_ layout: SnapLayout) {
        guard let selectedPresetID else { return }
        updateLayout(layout, for: selectedPresetID)
    }

    func updateSelectedLayout(_ mutate: (inout SnapLayout) -> Void) {
        guard let selectedPresetID else { return }
        updateLayout(for: selectedPresetID, mutate)
    }

    func updateLayout(_ layout: SnapLayout, for presetID: CustomSnapPreset.ID) {
        updatePreset(presetID) { preset in
            preset.layout = layout
        }
    }

    func updateMode(_ mode: CustomSnapPresetMode, for presetID: CustomSnapPreset.ID) {
        updatePreset(presetID) { preset in
            preset.mode = mode
        }
    }

    func updatePosition(_ position: CustomSnapPosition, for presetID: CustomSnapPreset.ID) {
        updatePreset(presetID) { preset in
            preset.position = position
        }
    }

    func updateLayout(for presetID: CustomSnapPreset.ID, _ mutate: (inout SnapLayout) -> Void) {
        updatePreset(presetID) { preset in
            var layout = preset.layout
            mutate(&layout)
            preset.layout = layout
        }
    }

    @discardableResult
    func updateSnapActivationLayout(_ layout: SnapActivationLayout, for presetID: CustomSnapPreset.ID) -> Bool {
        guard !snapActivationLayoutConflicts(layout, excludingPresetID: presetID) else { return false }
        updatePreset(presetID) { preset in
            preset.snapActivationLayouts = [layout]
        }
        return true
    }

    @discardableResult
    func addSnapActivationLayout(_ layout: SnapActivationLayout, for presetID: CustomSnapPreset.ID) -> Bool {
        guard let preset = preset(withID: presetID),
              !preset.snapActivationLayouts.contains(where: { layout.intersects($0) }),
              !snapActivationLayoutConflicts(layout, excludingPresetID: presetID) else {
            return false
        }

        updatePreset(presetID) { preset in
            preset.snapActivationLayouts.append(layout)
            preset.isSnapActivationEnabled = true
        }
        return true
    }

    func removeSnapActivationLayout(_ layout: SnapActivationLayout, for presetID: CustomSnapPreset.ID) {
        updatePreset(presetID) { preset in
            preset.snapActivationLayouts.removeAll { $0 == layout }
            if preset.snapActivationLayouts.isEmpty {
                preset.isSnapActivationEnabled = false
            }
        }
    }

    @discardableResult
    func setSnapActivationEnabled(_ isEnabled: Bool, for presetID: CustomSnapPreset.ID) -> Bool {
        var didUpdate = false
        updatePreset(presetID) { preset in
            guard !isEnabled ||
                    (!preset.snapActivationLayouts.isEmpty &&
                        !snapActivationLayoutsConflict(preset.snapActivationLayouts, excludingPresetID: presetID)) else {
                return
            }

            preset.isSnapActivationEnabled = isEnabled
            didUpdate = true
        }
        return didUpdate
    }

    func snapActivationPreference(for command: ShortcutCommand) -> SnapActivationPreference? {
        defaultCommandSnapActivations[command] ?? Self.defaultCommandSnapActivation(for: command)
    }

    @discardableResult
    func updateSnapActivationLayout(_ layout: SnapActivationLayout, for command: ShortcutCommand) -> Bool {
        guard !snapActivationLayoutConflicts(layout, excludingCommand: command) else { return false }
        guard var preference = snapActivationPreference(for: command) else { return false }
        preference.layouts = [layout]
        defaultCommandSnapActivations[command] = preference
        return true
    }

    @discardableResult
    func addSnapActivationLayout(_ layout: SnapActivationLayout, for command: ShortcutCommand) -> Bool {
        guard var preference = snapActivationPreference(for: command),
              !preference.layouts.contains(where: { layout.intersects($0) }),
              !snapActivationLayoutConflicts(layout, excludingCommand: command) else {
            return false
        }

        preference.layouts.append(layout)
        preference.isEnabled = true
        defaultCommandSnapActivations[command] = preference
        return true
    }

    func removeSnapActivationLayout(_ layout: SnapActivationLayout, for command: ShortcutCommand) {
        guard var preference = snapActivationPreference(for: command) else { return }
        preference.layouts.removeAll { $0 == layout }
        if preference.layouts.isEmpty {
            preference.isEnabled = false
        }
        defaultCommandSnapActivations[command] = preference
    }

    @discardableResult
    func setSnapActivationEnabled(_ isEnabled: Bool, for command: ShortcutCommand) -> Bool {
        guard var preference = snapActivationPreference(for: command) else { return false }
        guard !isEnabled ||
                (!preference.layouts.isEmpty &&
                    !snapActivationLayoutsConflict(preference.layouts, excludingCommand: command)) else {
            return false
        }

        preference.isEnabled = isEnabled
        defaultCommandSnapActivations[command] = preference
        return true
    }

    func defaultSnapActivationLayout(for command: ShortcutCommand) -> SnapActivationLayout? {
        Self.defaultCommandSnapActivationLayout(for: command)
    }

    func bindingForSnapActivationDwellDelayMilliseconds() -> Binding<Int> {
        Binding(
            get: { self.snapActivationDwellDelayMilliseconds },
            set: { self.setSnapActivationDwellDelay(milliseconds: $0) }
        )
    }

    private var snapActivationDwellDelayMilliseconds: Int {
        Int((snapActivationDwellDelay * 1000).rounded())
    }

    private func setSnapActivationDwellDelay(milliseconds: Int) {
        let clampedMilliseconds = Self.clamped(milliseconds, to: Self.snapActivationDwellDelayMillisecondsRange)
        let delay = TimeInterval(clampedMilliseconds) / 1000
        guard snapActivationDwellDelay != delay else { return }
        snapActivationDwellDelay = delay
    }

    private func updatePreset(_ presetID: CustomSnapPreset.ID, _ mutate: (inout CustomSnapPreset) -> Void) {
        guard let index = presets.firstIndex(where: { $0.id == presetID }) else {
            return
        }

        var preset = presets[index]
        mutate(&preset)
        presets[index] = preset
    }

    // Coalesce rapid mutations (e.g. dragging in the grid editor, which mutates
    // presets on every mouse-move) into a single file write instead of
    // re-encoding settings.json on every change. The in-memory @Published values
    // still update immediately for the UI; only the persistence is deferred, and
    // a pending write is flushed synchronously on app termination.
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

    private func persist() {
        pendingSave = nil
        let snapshot = SnapSettingsSnapshot(
            presets: presets,
            selectedPresetID: selectedPresetID,
            defaultSnapPresentation: defaultSnapPresentation,
            customSnapPresentation: customSnapPresentation,
            snapActivationDwellDelay: snapActivationDwellDelay,
            defaultCommandSnapActivations: defaultCommandSnapActivations
        )

        SettingsFileStore.saveSnapSettings(snapshot)
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
        guard pendingSave != nil else { return }
        pendingSave?.cancel()
        persist()
    }

    private static func loadSnapshot(from key: String) -> SnapSettingsSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SnapSettingsSnapshot.self, from: data)
    }

    private static func normalizedSnapActivationDwellDelay(_ delay: TimeInterval?) -> TimeInterval {
        let delay = delay ?? SnapSettingsSnapshot.defaultSnapActivationDwellDelay
        let milliseconds = Int((delay * 1000).rounded())
        return TimeInterval(clamped(milliseconds, to: snapActivationDwellDelayMillisecondsRange)) / 1000
    }

    private static func clamped(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
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

    private static func legacyCommandSnapActivationLayout(for command: ShortcutCommand) -> SnapActivationLayout? {
        switch command {
        case .snapLeft:
            return SnapActivationLayout(startColumn: 0, startRow: 1, columnSpan: 1, rowSpan: 8)
        case .snapRight:
            return SnapActivationLayout(startColumn: 15, startRow: 1, columnSpan: 1, rowSpan: 8)
        case .snapTop:
            return SnapActivationLayout(startColumn: 1, startRow: 0, columnSpan: 4, rowSpan: 1)
        case .snapFullScreen:
            return SnapActivationLayout(startColumn: 6, startRow: 0, columnSpan: 4, rowSpan: 1)
        case .snapCenter:
            return SnapActivationLayout(startColumn: 11, startRow: 0, columnSpan: 4, rowSpan: 1)
        case .snapBottom:
            return SnapActivationLayout(startColumn: 1, startRow: 9, columnSpan: 14, rowSpan: 1)
        case .repeatLastSnap, .toggleSleepPrevention, .toggleNaturalScrolling, .toggleWheelMouseReverseScrolling:
            return nil
        }
    }

    private static func defaultCommandSnapActivations() -> [ShortcutCommand: SnapActivationPreference] {
        normalizedDefaultCommandSnapActivations([:])
    }

    private static func normalizedDefaultCommandSnapActivations(
        _ preferences: [ShortcutCommand: SnapActivationPreference]
    ) -> [ShortcutCommand: SnapActivationPreference] {
        var normalized: [ShortcutCommand: SnapActivationPreference] = [:]

        for command in ShortcutCommand.defaultCommands {
            guard let defaultPreference = defaultCommandSnapActivation(for: command) else { continue }
            var preference = preferences[command] ?? defaultPreference

            if let legacyLayout = legacyCommandSnapActivationLayout(for: command),
               preference.layouts == [legacyLayout] {
                preference.layouts = defaultPreference.layouts
            }

            normalized[command] = preference
        }

        return normalized
    }

    private func normalizeSnapActivationOverlaps() {
        var occupiedLayouts: [SnapActivationLayout] = []

        for command in ShortcutCommand.defaultCommands {
            guard var preference = defaultCommandSnapActivations[command] else { continue }

            if preference.isEnabled {
                preference.layouts = nonConflictingLayouts(from: preference.layouts, against: occupiedLayouts)
            }

            if preference.isEnabled && preference.layouts.isEmpty {
                preference = Self.defaultCommandSnapActivation(for: command) ?? preference
                preference.layouts = nonConflictingLayouts(from: preference.layouts, against: occupiedLayouts)
                if preference.layouts.isEmpty {
                    preference.isEnabled = false
                }
                defaultCommandSnapActivations[command] = preference
            }

            if preference.isEnabled {
                occupiedLayouts.append(contentsOf: preference.layouts)
            }
        }

        presets = presets.map { preset in
            var preset = preset

            if preset.isSnapActivationEnabled {
                preset.snapActivationLayouts = nonConflictingLayouts(
                    from: preset.snapActivationLayouts,
                    against: occupiedLayouts
                )
            }

            if preset.isSnapActivationEnabled && preset.snapActivationLayouts.isEmpty {
                preset.isSnapActivationEnabled = false
            }

            if preset.isSnapActivationEnabled {
                occupiedLayouts.append(contentsOf: preset.snapActivationLayouts)
            }

            return preset
        }
    }

    private func nonConflictingLayouts(
        from layouts: [SnapActivationLayout],
        against occupiedLayouts: [SnapActivationLayout]
    ) -> [SnapActivationLayout] {
        var accepted: [SnapActivationLayout] = []

        for layout in layouts where !accepted.contains(where: { layout.intersects($0) }) &&
            !occupiedLayouts.contains(where: { layout.intersects($0) }) {
            accepted.append(layout)
        }

        return accepted
    }

    private func snapActivationLayoutsConflict(
        _ layouts: [SnapActivationLayout],
        excludingCommand excludedCommand: ShortcutCommand? = nil,
        excludingPresetID excludedPresetID: CustomSnapPreset.ID? = nil
    ) -> Bool {
        for (index, layout) in layouts.enumerated() {
            if layouts.dropFirst(index + 1).contains(where: { layout.intersects($0) }) {
                return true
            }

            if snapActivationLayoutConflicts(
                layout,
                excludingCommand: excludedCommand,
                excludingPresetID: excludedPresetID
            ) {
                return true
            }
        }

        return false
    }

    private func snapActivationLayoutConflicts(
        _ layout: SnapActivationLayout,
        excludingCommand excludedCommand: ShortcutCommand? = nil,
        excludingPresetID excludedPresetID: CustomSnapPreset.ID? = nil
    ) -> Bool {
        for (command, preference) in defaultCommandSnapActivations {
            guard command != excludedCommand, preference.isEnabled else { continue }
            if preference.layouts.contains(where: { layout.intersects($0) }) {
                return true
            }
        }

        for preset in presets {
            guard preset.id != excludedPresetID, preset.isSnapActivationEnabled else { continue }
            if preset.snapActivationLayouts.contains(where: { layout.intersects($0) }) {
                return true
            }
        }

        return false
    }
}

struct SnapSettingsSnapshot: Codable {
    var presets: [CustomSnapPreset]
    var selectedPresetID: CustomSnapPreset.ID?
    var defaultSnapPresentation: SnapMenuPresentation?
    var customSnapPresentation: SnapMenuPresentation?
    var snapActivationDwellDelay: TimeInterval?
    var defaultCommandSnapActivations: [ShortcutCommand: SnapActivationPreference]?
}
