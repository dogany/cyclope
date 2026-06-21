import AppKit
import Carbon.HIToolbox
import Combine
import os

@MainActor
final class GlobalShortcutManager {
    private static let hotKeySignature: OSType = 0x43797073 // "Cyps"
    private static let availabilityCheckSignature: OSType = 0x43797043 // "CypC"
    private static let modalHotKeyID = UInt32(1)

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var hotKeyCommands: [UInt32: GlobalShortcut.Command] = [:]
    private var hotKeyEventHandlerRef: EventHandlerRef?
    private var hasPendingRegistrationUpdate = false
    private var lastDispatch: (command: GlobalShortcut.Command, timestamp: TimeInterval)?
    private var settings: ShortcutSettingsStore?
    private var snapSettings: SnapSettingsStore?
    private var handler: ((GlobalShortcut.Command) -> Void)?
    private var settingsCancellable: AnyCancellable?
    private var snapSettingsCancellable: AnyCancellable?
    private let logger = Logger(subsystem: "com.dogany.cyclope", category: "Shortcuts")

    func start(
        settings: ShortcutSettingsStore,
        snapSettings: SnapSettingsStore,
        handler: @escaping (GlobalShortcut.Command) -> Void
    ) {
        stop()
        self.settings = settings
        self.snapSettings = snapSettings
        self.handler = handler
        installHotKeyEventHandlerIfNeeded()
        updateHotKeyRegistrations()

        settingsCancellable = settings.objectWillChange.sink { [weak self] _ in
            self?.scheduleHotKeyRegistrationUpdate()
        }

        snapSettingsCancellable = snapSettings.objectWillChange.sink { [weak self] _ in
            self?.scheduleHotKeyRegistrationUpdate()
        }
    }

    func stop() {
        unregisterHotKeys()
        removeHotKeyEventHandler()
        settingsCancellable = nil
        snapSettingsCancellable = nil
        settings = nil
        snapSettings = nil
    }

    // Coalesce store-change bursts (e.g. a grid-edit drag mutating snapSettings on
    // every tick) into a single re-registration on the next runloop turn.
    private func scheduleHotKeyRegistrationUpdate() {
        guard !hasPendingRegistrationUpdate else { return }
        hasPendingRegistrationUpdate = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.hasPendingRegistrationUpdate = false
            self.updateHotKeyRegistrations()
        }
    }

    private func dispatch(_ command: GlobalShortcut.Command) {
        let now = ProcessInfo.processInfo.systemUptime
        if let lastDispatch,
           lastDispatch.command == command,
           now - lastDispatch.timestamp < 0.2 {
            return
        }

        lastDispatch = (command, now)
        handler?(command)
    }

    private func dispatchHotKey(id: UInt32) {
        guard let command = hotKeyCommands[id] else { return }
        dispatch(command)
    }

    private func installHotKeyEventHandlerIfNeeded() {
        guard hotKeyEventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr,
                      hotKeyID.signature == GlobalShortcutManager.hotKeySignature else {
                    return noErr
                }

                let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()
                let hotKeyIdentifier = hotKeyID.id
                Task { @MainActor in
                    manager.dispatchHotKey(id: hotKeyIdentifier)
                }

                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &hotKeyEventHandlerRef
        )
    }

    private func updateHotKeyRegistrations() {
        unregisterHotKeys()
        installHotKeyEventHandlerIfNeeded()

        guard let settings else {
            return
        }

        if settings.isModalShortcutEnabled {
            registerHotKey(
                settings.modalShortcutKey,
                id: Self.modalHotKeyID,
                command: .showCheatSheet
            )
        }

        var nextHotKeyID = Self.modalHotKeyID + 1

        for shortcutCommand in ShortcutCommand.allCases {
            for key in settings.directKeysToMatch(for: shortcutCommand) {
                registerHotKey(
                    key,
                    id: nextHotKeyID,
                    command: GlobalShortcut.command(for: shortcutCommand)
                )
                nextHotKeyID += 1
            }
        }

        if let snapSettings {
            for preset in snapSettings.presets {
                guard settings.isCustomDirectEnabled(preset.id),
                      let key = settings.customDirectKey(for: preset.id) else {
                    continue
                }

                registerHotKey(
                    key,
                    id: nextHotKeyID,
                    command: .customSnap(preset.id)
                )
                nextHotKeyID += 1
            }
        }
    }

    private func registerHotKey(
        _ key: CustomShortcutKey,
        id: UInt32,
        command: GlobalShortcut.Command
    ) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(
            signature: Self.hotKeySignature,
            id: id
        )

        let status = RegisterEventHotKey(
            UInt32(key.keyCode),
            Self.carbonModifiers(for: key),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let hotKeyRef else {
            logger.error("failed to register hotkey id=\(id, privacy: .public) command=\(String(describing: command), privacy: .public) keyCode=\(key.keyCode, privacy: .public) modifiers=\(Self.carbonModifiers(for: key), privacy: .public) status=\(status, privacy: .public)")
            return
        }
        hotKeyRefs[id] = hotKeyRef
        hotKeyCommands[id] = command
    }

    static func isHotKeyRegisterable(_ key: CustomShortcutKey) -> Bool {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(
            signature: Self.availabilityCheckSignature,
            id: UInt32.random(in: 1...UInt32.max)
        )

        let status = RegisterEventHotKey(
            UInt32(key.keyCode),
            Self.carbonModifiers(for: key),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }

        return status == noErr
    }

    static func knownSystemShortcutName(for key: CustomShortcutKey) -> String? {
        knownSystemShortcuts.first { knownShortcut in
            key.matches(
                CustomShortcutKey(
                    keyCode: knownShortcut.keyCode,
                    symbol: knownShortcut.symbol,
                    modifiers: knownShortcut.modifiers
                )
            )
        }?.name
    }

    static func globalShortcutUnavailableReason(for key: CustomShortcutKey) -> String? {
        if let name = knownSystemShortcutName(for: key) {
            return String(localized: "\(key.directSymbols) is commonly reserved by macOS for \(name).")
        }

        guard isHotKeyRegisterable(key) else {
            return String(localized: "\(key.directSymbols) is already registered by macOS or another app.")
        }

        return nil
    }

    private static func carbonModifiers(for key: CustomShortcutKey) -> UInt32 {
        (key.modifiers ?? []).reduce(UInt32(0)) { modifiers, shortcutModifier in
            modifiers | shortcutModifier.carbonHotKeyModifier
        }
    }

    private func unregisterHotKeys() {
        hotKeyRefs.values.forEach { UnregisterEventHotKey($0) }
        hotKeyRefs.removeAll()
        hotKeyCommands.removeAll()
    }

    private func removeHotKeyEventHandler() {
        if let hotKeyEventHandlerRef {
            RemoveEventHandler(hotKeyEventHandlerRef)
        }

        hotKeyEventHandlerRef = nil
    }

    deinit {
        MainActor.assumeIsolated {
            unregisterHotKeys()
            removeHotKeyEventHandler()
        }
    }

    private static let knownSystemShortcuts: [KnownSystemShortcut] = [
        KnownSystemShortcut(name: String(localized: "Spotlight"), keyCode: 49, symbol: "Space", modifiers: [.command]),
        KnownSystemShortcut(name: String(localized: "the application switcher"), keyCode: 48, symbol: "⇥", modifiers: [.command]),
        KnownSystemShortcut(name: String(localized: "Force Quit"), keyCode: 53, symbol: "Esc", modifiers: [.option, .command]),
        KnownSystemShortcut(name: String(localized: "Hide App"), keyCode: 4, symbol: "H", modifiers: [.command]),
        KnownSystemShortcut(name: String(localized: "Hide Others"), keyCode: 4, symbol: "H", modifiers: [.option, .command]),
        KnownSystemShortcut(name: String(localized: "Quit App"), keyCode: 12, symbol: "Q", modifiers: [.command]),
        KnownSystemShortcut(name: String(localized: "Close Window"), keyCode: 13, symbol: "W", modifiers: [.command]),
        KnownSystemShortcut(name: String(localized: "Minimize Window"), keyCode: 46, symbol: "M", modifiers: [.command]),
        KnownSystemShortcut(name: String(localized: "App Settings"), keyCode: 43, symbol: ",", modifiers: [.command])
    ]
}

private struct KnownSystemShortcut {
    let name: String
    let keyCode: Int
    let symbol: String
    let modifiers: [CustomShortcutModifier]
}

private extension CustomShortcutModifier {
    var carbonHotKeyModifier: UInt32 {
        switch self {
        case .control:
            return UInt32(controlKey)
        case .option:
            return UInt32(optionKey)
        case .shift:
            return UInt32(shiftKey)
        case .command:
            return UInt32(cmdKey)
        }
    }
}
