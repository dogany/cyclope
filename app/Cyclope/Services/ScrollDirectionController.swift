//
//  ScrollDirectionController.swift
//  Cyclope
//

import Combine
import CoreGraphics
import Darwin
import Foundation
import os

@MainActor
final class ScrollDirectionController: ObservableObject {
    private static let naturalScrollingPreferenceKey = "com.apple.swipescrolldirection"
    private static let swipeScrollDirectionChangedNotificationName =
        Notification.Name("SwipeScrollDirectionDidChangeNotification")
    private static let preferencesApplication = kCFPreferencesAnyApplication
    private static let preferencesUser = kCFPreferencesCurrentUser
    private static let preferencesAnyHost = kCFPreferencesAnyHost
    private static let preferencesCurrentHost = kCFPreferencesCurrentHost
    private static let defaultNaturalScrolling = true
    private static let swipeScrollDirectionBridge = SwipeScrollDirectionBridge()

    @Published private(set) var isNaturalScrollingEnabled = defaultNaturalScrolling
    @Published private(set) var isWheelMouseReverseScrollingEnabled = false
    @Published private(set) var isWheelMouseScrollReversalActive = false

    private let wheelMouseScrollReverser = WheelMouseScrollReverser()
    private var shouldRunBackgroundServices = false
    private var preferenceObservers: [NSObjectProtocol] = []
    private var preferencePollTimer: Timer?

    init() {
        restoreSettings()
        refresh()
        configureNaturalScrollingPreferenceObservers()
    }

    func startBackgroundServices() {
        shouldRunBackgroundServices = true
        applyWheelMouseScrollReversalState()
    }

    func stopBackgroundServices() {
        shouldRunBackgroundServices = false
        wheelMouseScrollReverser.stop()
    }

    func refresh() {
        let isNaturalScrollingEnabled = Self.readNaturalScrollingPreference()
        if self.isNaturalScrollingEnabled != isNaturalScrollingEnabled {
            self.isNaturalScrollingEnabled = isNaturalScrollingEnabled
        }

        applyWheelMouseScrollReversalState()
    }

    func toggleNaturalScrolling() {
        refresh()
        setNaturalScrollingEnabled(!isNaturalScrollingEnabled)
    }

    func setNaturalScrollingEnabled(_ isEnabled: Bool) {
        Self.writeNaturalScrollingPreference(isEnabled)
        Self.postNaturalScrollingPreferenceChanged()
        refresh()
    }

    func toggleWheelMouseReverseScrolling() {
        setWheelMouseReverseScrollingEnabled(!isWheelMouseReverseScrollingEnabled)
    }

    func setWheelMouseReverseScrollingEnabled(_ isEnabled: Bool) {
        guard isWheelMouseReverseScrollingEnabled != isEnabled else {
            applyWheelMouseScrollReversalState()
            return
        }

        isWheelMouseReverseScrollingEnabled = isEnabled
        persistSettings()
        applyWheelMouseScrollReversalState()
    }

    private func restoreSettings() {
        let settings = SettingsFileStore.loadUserSettings()?.scrollDirection ??
            SettingsFileStore.loadDefaultSettings()?.scrollDirection ??
            .defaultSettings

        isWheelMouseReverseScrollingEnabled = settings.reverseWheelMouseScrolling
    }

    private func persistSettings() {
        SettingsFileStore.saveScrollDirectionSettings(settingsSnapshot)
    }

    private var settingsSnapshot: ScrollDirectionSettingsSnapshot {
        ScrollDirectionSettingsSnapshot(
            reverseWheelMouseScrolling: isWheelMouseReverseScrollingEnabled
        )
    }

    private func applyWheelMouseScrollReversalState() {
        let isActive = wheelMouseScrollReverser.setReverseWheelMouseScrollingEnabled(
            shouldRunBackgroundServices && isWheelMouseReverseScrollingEnabled
        )
        if isWheelMouseScrollReversalActive != isActive {
            isWheelMouseScrollReversalActive = isActive
        }
    }

    private static func readNaturalScrollingPreference() -> Bool {
        if let value = swipeScrollDirectionBridge.read() {
            return value
        }

        return readNaturalScrollingPreferenceFallback()
    }

    private static func readNaturalScrollingPreferenceFallback() -> Bool {
        CFPreferencesSynchronize(preferencesApplication, preferencesUser, preferencesAnyHost)
        CFPreferencesSynchronize(preferencesApplication, preferencesUser, preferencesCurrentHost)
        UserDefaults.standard.synchronize()

        let values: [CFTypeRef?] = [
            CFPreferencesCopyValue(
                naturalScrollingPreferenceKey as CFString,
                preferencesApplication,
                preferencesUser,
                preferencesCurrentHost
            ),
            CFPreferencesCopyValue(
                naturalScrollingPreferenceKey as CFString,
                preferencesApplication,
                preferencesUser,
                preferencesAnyHost
            ),
            UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?[naturalScrollingPreferenceKey] as CFTypeRef?
        ]

        for value in values {
            if let boolValue = normalizedBoolean(value) {
                return boolValue
            }
        }

        return defaultNaturalScrolling
    }

    private static func writeNaturalScrollingPreference(_ isEnabled: Bool) {
        swipeScrollDirectionBridge.write(isEnabled)
        writeNaturalScrollingPreferenceFallback(isEnabled)
    }

    private static func writeNaturalScrollingPreferenceFallback(_ isEnabled: Bool) {
        let value = NSNumber(value: isEnabled)
        var globalDomain = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain) ?? [:]
        globalDomain[naturalScrollingPreferenceKey] = isEnabled
        UserDefaults.standard.setPersistentDomain(globalDomain, forName: UserDefaults.globalDomain)
        UserDefaults.standard.synchronize()

        for host in [preferencesAnyHost, preferencesCurrentHost] {
            CFPreferencesSetValue(
                naturalScrollingPreferenceKey as CFString,
                host == preferencesAnyHost ? value : nil,
                preferencesApplication,
                preferencesUser,
                host
            )
            CFPreferencesSynchronize(preferencesApplication, preferencesUser, host)
        }
    }

    private static func normalizedBoolean(_ value: CFTypeRef?) -> Bool? {
        if let boolValue = value as? Bool {
            return boolValue
        }

        if let numberValue = value as? NSNumber {
            return numberValue.boolValue
        }

        if let stringValue = value as? String {
            switch stringValue.lowercased() {
            case "1", "true", "yes":
                return true
            case "0", "false", "no":
                return false
            default:
                return nil
            }
        }

        return nil
    }

    private static func postNaturalScrollingPreferenceChanged() {
        DistributedNotificationCenter.default().post(
            name: Notification.Name(naturalScrollingPreferenceKey),
            object: nil
        )
        DistributedNotificationCenter.default().post(
            name: swipeScrollDirectionChangedNotificationName,
            object: nil
        )
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: UserDefaults.standard)
    }

    private func configureNaturalScrollingPreferenceObservers() {
        let timer = Timer(timeInterval: 1, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        preferencePollTimer = timer
        RunLoop.main.add(timer, forMode: .common)

        let distributedObservers = [
            Notification.Name(Self.naturalScrollingPreferenceKey),
            Self.swipeScrollDirectionChangedNotificationName
        ].map { notificationName in
            DistributedNotificationCenter.default().addObserver(
                forName: notificationName,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor [weak self] in
                    self?.refresh()
                }
            }
        }

        let defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }

        preferenceObservers.append(contentsOf: distributedObservers + [defaultsObserver])
    }

    deinit {
        preferencePollTimer?.invalidate()
        for observer in preferenceObservers {
            DistributedNotificationCenter.default().removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

private final class SwipeScrollDirectionBridge {
    private typealias Getter = @convention(c) () -> Bool
    private typealias Setter = @convention(c) (Bool) -> Void

    private let handle: UnsafeMutableRawPointer?
    private let getter: Getter?
    private let setter: Setter?

    init() {
        let frameworkPath = "/System/Library/PrivateFrameworks/PreferencePanesSupport.framework/PreferencePanesSupport"
        handle = dlopen(frameworkPath, RTLD_LAZY)

        if let handle,
           let getterSymbol = dlsym(handle, "swipeScrollDirection"),
           let setterSymbol = dlsym(handle, "setSwipeScrollDirection") {
            getter = unsafeBitCast(getterSymbol, to: Getter.self)
            setter = unsafeBitCast(setterSymbol, to: Setter.self)
        } else {
            getter = nil
            setter = nil
        }
    }

    func read() -> Bool? {
        getter?()
    }

    @discardableResult
    func write(_ isEnabled: Bool) -> Bool {
        guard let setter else { return false }

        setter(isEnabled)
        return true
    }

    deinit {
        if let handle {
            dlclose(handle)
        }
    }
}

private final class WheelMouseScrollReverser {
    private struct EventTapConfiguration {
        let location: CGEventTapLocation
        let name: String
    }

    private static let syntheticScrollEventMarker: Int64 = 0x4379636F7065

    private static let eventTapConfigurations = [
        EventTapConfiguration(location: .cgAnnotatedSessionEventTap, name: "annotated-session"),
        EventTapConfiguration(location: .cgSessionEventTap, name: "session"),
        EventTapConfiguration(location: .cghidEventTap, name: "hid")
    ]

    private static let scrollDeltaFields: [CGEventField] = [
        .scrollWheelEventDeltaAxis1,
        .scrollWheelEventDeltaAxis2,
        .scrollWheelEventDeltaAxis3,
        .scrollWheelEventFixedPtDeltaAxis1,
        .scrollWheelEventFixedPtDeltaAxis2,
        .scrollWheelEventFixedPtDeltaAxis3,
        .scrollWheelEventPointDeltaAxis1,
        .scrollWheelEventPointDeltaAxis2,
        .scrollWheelEventPointDeltaAxis3,
        .scrollWheelEventAcceleratedDeltaAxis1,
        .scrollWheelEventAcceleratedDeltaAxis2,
        .scrollWheelEventRawDeltaAxis1,
        .scrollWheelEventRawDeltaAxis2
    ]

    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private let logger = Logger(subsystem: "com.dogany.cyclope", category: "Scrolling")

    @discardableResult
    func setReverseWheelMouseScrollingEnabled(_ isEnabled: Bool) -> Bool {
        if isEnabled {
            return startEventTapIfNeeded()
        } else {
            stop()
            return false
        }
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
            self.eventTapSource = nil
        }

        eventTap = nil
    }

    private func startEventTapIfNeeded() -> Bool {
        guard eventTap == nil else { return true }

        let hasInputMonitoringPermission = CGPreflightListenEventAccess()
        if !hasInputMonitoringPermission {
            logger.notice("wheel mouse scroll event tap Input Monitoring preflight is not granted; attempting event tap creation")
        }

        let eventMask = CGEventMask(1) << CGEventType.scrollWheel.rawValue
        for configuration in Self.eventTapConfigurations {
            guard let eventTap = createEventTap(
                location: configuration.location,
                eventMask: eventMask
            ) else {
                logger.error("failed to create wheel mouse scroll event tap at \(configuration.name, privacy: .public) location")
                continue
            }

            install(eventTap)
            logger.info("created wheel mouse scroll event tap at \(configuration.name, privacy: .public) location")
            return true
        }

        if !hasInputMonitoringPermission {
            logger.error("failed to create wheel mouse scroll event tap: Input Monitoring permission is not granted or the app needs to be restarted after granting it")
            return false
        }

        logger.error("failed to create wheel mouse scroll event tap")
        return false
    }

    private func createEventTap(location: CGEventTapLocation, eventMask: CGEventMask) -> CFMachPort? {
        CGEvent.tapCreate(
            tap: location,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: wheelMouseScrollReverserEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
    }

    private func install(_ eventTap: CFMachPort) {
        self.eventTap = eventTap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        eventTapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    fileprivate func handleEventTapEvent(_ type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .scrollWheel:
            guard !isSyntheticScrollEvent(event) else {
                return Unmanaged.passUnretained(event)
            }

            let shouldReverse = shouldReverse(event)
            guard shouldReverse else {
                return Unmanaged.passUnretained(event)
            }

            if postReversedScrollEvent(from: event) {
                return nil
            } else if let reversedEvent = event.copy() {
                reverseScrollDeltaFields(in: reversedEvent)
                return Unmanaged.passRetained(reversedEvent)
            } else {
                reverseScrollDeltaFields(in: event)
                return Unmanaged.passUnretained(event)
            }
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func shouldReverse(_ event: CGEvent) -> Bool {
        let hasMomentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0
        guard !hasMomentum else { return false }

        let isMouseWheel = event.getIntegerValueField(.scrollWheelEventInstantMouser) != 0
        let isLineBasedScrolling = event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0
        return isMouseWheel || isLineBasedScrolling
    }

    private func isSyntheticScrollEvent(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == Self.syntheticScrollEventMarker
    }

    private func postReversedScrollEvent(from event: CGEvent) -> Bool {
        let pointAxis1 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        let pointAxis2 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
        let deltaAxis1 = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let deltaAxis2 = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        let usesPixelUnits = pointAxis1 != 0 || pointAxis2 != 0

        let wheel1 = clampedInt32(-(usesPixelUnits ? pointAxis1 : deltaAxis1))
        let wheel2 = clampedInt32(-(usesPixelUnits ? pointAxis2 : deltaAxis2))
        guard wheel1 != 0 || wheel2 != 0 else { return false }

        let source = CGEventSource(stateID: .combinedSessionState)
        guard let replacementEvent = CGEvent(
            scrollWheelEvent2Source: source,
            units: usesPixelUnits ? .pixel : .line,
            wheelCount: 2,
            wheel1: wheel1,
            wheel2: wheel2,
            wheel3: 0
        ) else {
            return false
        }

        replacementEvent.location = event.location
        replacementEvent.flags = event.flags
        replacementEvent.setIntegerValueField(.eventSourceUserData, value: Self.syntheticScrollEventMarker)
        replacementEvent.post(tap: .cgSessionEventTap)
        return true
    }

    private func clampedInt32(_ value: Int64) -> Int32 {
        Int32(max(Int64(Int32.min), min(Int64(Int32.max), value)))
    }

    private func reverseScrollDeltaFields(in event: CGEvent) {
        for field in Self.scrollDeltaFields {
            let value = event.getIntegerValueField(field)
            guard value != 0 else { continue }
            event.setIntegerValueField(field, value: -value)
        }
    }

    deinit {
        stop()
    }
}

private let wheelMouseScrollReverserEventTapCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon else {
        return Unmanaged.passUnretained(event)
    }

    let reverser = Unmanaged<WheelMouseScrollReverser>.fromOpaque(refcon).takeUnretainedValue()
    return reverser.handleEventTapEvent(type, event: event)
}
