//
//  SleepPreventer.swift
//  Cyclope
//

import Combine
import Foundation
import IOKit
import IOKit.pwr_mgt
import IOKit.ps

enum SleepPreventionCustomDuration {
    static let minimumMinutes = 1
    static let maximumMinutes = 24 * 60
    static let defaultMinutes = 90

    static var validMinuteRange: ClosedRange<Int> {
        minimumMinutes...maximumMinutes
    }

    static var validationMessage: String {
        "Custom sleep prevention duration must be between \(minimumMinutes) and \(maximumMinutes) minutes."
    }
}

enum SleepSettingsDefaults {
    static let defaultDurationMinutes = 30
    static let batteryDisableThresholdPercent = 20
    static let batteryThresholdRange = 1...100
}

@MainActor
final class SleepPreventer: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var activationDate: Date?
    @Published private(set) var expirationDate: Date?
    @Published private(set) var customDurationMinutes: Int?
    @Published var selectedDuration: SleepDuration = .untilTurnedOff
    @Published private(set) var defaultDurationMinutes: Int?
    @Published private(set) var disableOnBatteryPower = false
    @Published private(set) var batteryDisableThresholdPercent: Int?
    var onExpiration: (() -> Void)?
    var onBatteryPolicyDisabled: (() -> Void)?

    private var idleSystemSleepAssertionID = IOPMAssertionID(0)
    private var idleDisplaySleepAssertionID = IOPMAssertionID(0)
    private var activity: NSObjectProtocol?
    private var expirationTimer: Timer?
    private var statusTimer: Timer?

    init() {
        restoreSettings()
    }

    var statusText: String {
        guard isActive else {
            return "Sleep prevention is off."
        }

        guard let expirationDate else {
            return "Preventing system and display sleep until turned off."
        }

        let remaining = max(0, Int(expirationDate.timeIntervalSinceNow.rounded()))
        let minutes = remaining / 60
        let seconds = remaining % 60
        return "Preventing system and display sleep for \(minutes)m \(seconds)s."
    }

    var menuRemainingTitle: String? {
        guard isActive else { return nil }
        guard let expirationDate else { return nil }

        let remainingSeconds = max(0, Int(ceil(expirationDate.timeIntervalSinceNow)))
        guard remainingSeconds >= 60 else {
            return String(localized: "Less than 1 min remaining")
        }

        let remainingMinutes = Int(ceil(Double(remainingSeconds) / 60.0))
        let hours = remainingMinutes / 60
        let minutes = remainingMinutes % 60

        if hours > 0, minutes > 0 {
            return String(localized: "\(hours)h \(minutes)m remaining")
        }

        if hours > 0 {
            return String(localized: "\(hours)h remaining")
        }

        return String(localized: "\(remainingMinutes)m remaining")
    }

    var durationDisplayTitle: String {
        if let customDurationMinutes {
            return "\(customDurationMinutes) min custom"
        }

        if isActive {
            return selectedDuration.title
        }

        return defaultDurationTitle
    }

    var defaultDurationTitle: String {
        guard let defaultDurationMinutes else { return "Never" }
        return "\(defaultDurationMinutes) min"
    }

    var batteryDisableThresholdTitle: String {
        guard let batteryDisableThresholdPercent else { return "Always" }
        return "\(batteryDisableThresholdPercent)%"
    }

    var remainingFraction: Double? {
        guard let activationDate, let expirationDate else { return nil }

        let total = expirationDate.timeIntervalSince(activationDate)
        guard total > 0 else { return nil }

        let remaining = expirationDate.timeIntervalSinceNow
        return min(1, max(0, remaining / total))
    }

    func setDefaultDuration(_ duration: SleepDuration) {
        setDefaultDurationMinutes(duration.interval.map { Int($0 / 60) })
    }

    func setDefaultDurationMinutes(_ minutes: Int?) {
        let minutes = minutes.map { clamped($0, to: SleepPreventionCustomDuration.validMinuteRange) }
        guard defaultDurationMinutes != minutes else { return }
        defaultDurationMinutes = minutes
        persistPreferences()
    }

    @discardableResult
    func setDisableOnBatteryPower(_ isEnabled: Bool) -> Bool {
        if disableOnBatteryPower != isEnabled {
            disableOnBatteryPower = isEnabled
            persistPreferences()
        }

        return enforceBatteryPolicyIfNeeded()
    }

    @discardableResult
    func setBatteryDisableThresholdPercent(_ percent: Int?) -> Bool {
        let percent = percent.map { clamped($0, to: SleepSettingsDefaults.batteryThresholdRange) }
        if batteryDisableThresholdPercent != percent {
            batteryDisableThresholdPercent = percent
            persistPreferences()
        }

        return enforceBatteryPolicyIfNeeded()
    }

    func applySettings(_ settings: SleepPreventionSettingsSnapshot, shouldPersist: Bool = false) {
        apply(settings, shouldPersist: shouldPersist)
    }

    func enableDefault() throws {
        if let defaultDurationMinutes {
            try enableCustom(minutes: defaultDurationMinutes)
        } else {
            try enable(.untilTurnedOff)
        }
    }

    func enable(_ duration: SleepDuration) throws {
        guard !shouldDisableForCurrentBatteryState() else {
            throw SleepPreventerError.disabledByBatteryPolicy
        }

        try enable(duration, customInterval: nil, customMinutes: nil)
    }

    func enableCustom(minutes: Int) throws {
        guard SleepPreventionCustomDuration.validMinuteRange.contains(minutes) else {
            throw SleepPreventerError.invalidCustomDuration
        }

        guard !shouldDisableForCurrentBatteryState() else {
            throw SleepPreventerError.disabledByBatteryPolicy
        }

        let interval = TimeInterval(minutes) * 60
        try enable(.untilTurnedOff, customInterval: interval, customMinutes: minutes)
    }

    private func enable(_ duration: SleepDuration, customInterval: TimeInterval?, customMinutes: Int?) throws {
        disable()

        let now = Date()
        let expirationDate = (customInterval ?? duration.interval).map { now.addingTimeInterval($0) }

        try startPreventingSleep(
            duration: duration,
            activationDate: now,
            expirationDate: expirationDate,
            customMinutes: customMinutes
        )
    }

    private func startPreventingSleep(
        duration: SleepDuration,
        activationDate: Date,
        expirationDate: Date?,
        customMinutes: Int?
    ) throws {
        do {
            idleSystemSleepAssertionID = try createPowerAssertion(
                type: kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                name: "Cyclope system sleep prevention" as CFString
            )
            idleDisplaySleepAssertionID = try createPowerAssertion(
                type: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                name: "Cyclope display sleep prevention" as CFString
            )
        } catch {
            releasePowerAssertions()
            throw error
        }

        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated],
            reason: "Cyclope sleep prevention is active"
        )

        selectedDuration = duration
        customDurationMinutes = customMinutes
        isActive = true
        self.activationDate = activationDate
        self.expirationDate = expirationDate

        if let expirationDate {
            let interval = max(0, expirationDate.timeIntervalSinceNow)
            expirationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                guard let preventer = self else { return }
                Task { @MainActor in
                    preventer.expire()
                }
            }
        }

        statusTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let preventer = self else { return }
            Task { @MainActor in
                if preventer.enforceBatteryPolicyIfNeeded() {
                    return
                }

                if let expirationDate = preventer.expirationDate, expirationDate <= Date() {
                    preventer.expire()
                    return
                }

                preventer.publishStatusRefresh()
            }
        }
    }

    private func expire() {
        guard isActive else { return }
        disable()
        onExpiration?()
    }

    func disable() {
        expirationTimer?.invalidate()
        expirationTimer = nil
        statusTimer?.invalidate()
        statusTimer = nil

        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }

        releasePowerAssertions()

        isActive = false
        activationDate = nil
        expirationDate = nil
        customDurationMinutes = nil
    }

    deinit {
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
        }

        if idleSystemSleepAssertionID != 0 {
            IOPMAssertionRelease(idleSystemSleepAssertionID)
        }

        if idleDisplaySleepAssertionID != 0 {
            IOPMAssertionRelease(idleDisplaySleepAssertionID)
        }
    }

    @discardableResult
    private func enforceBatteryPolicyIfNeeded() -> Bool {
        guard isActive, shouldDisableForCurrentBatteryState() else {
            return false
        }

        disable()
        onBatteryPolicyDisabled?()
        return true
    }

    private func createPowerAssertion(type: CFString, name: CFString) throws -> IOPMAssertionID {
        var assertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            name,
            &assertionID
        )

        guard result == kIOReturnSuccess else {
            throw SleepPreventerError.assertionFailed
        }

        return assertionID
    }

    private func releasePowerAssertions() {
        if idleSystemSleepAssertionID != 0 {
            IOPMAssertionRelease(idleSystemSleepAssertionID)
            idleSystemSleepAssertionID = 0
        }

        if idleDisplaySleepAssertionID != 0 {
            IOPMAssertionRelease(idleDisplaySleepAssertionID)
            idleDisplaySleepAssertionID = 0
        }
    }

    private func persistPreferences() {
        SettingsFileStore.saveSleepPreventionSettings(settingsSnapshot)
    }

    private func restoreSettings() {
        let storedSettings = SettingsFileStore.loadUserSettings()?.sleepPrevention ??
            SettingsFileStore.loadDefaultSettings()?.sleepPrevention ??
            .defaultSettings

        apply(storedSettings, shouldPersist: false)
    }

    private func apply(
        _ settings: SleepPreventionSettingsSnapshot,
        shouldPersist: Bool
    ) {
        defaultDurationMinutes = settings.defaultDurationMinutes.map {
            clamped($0, to: SleepPreventionCustomDuration.validMinuteRange)
        }
        disableOnBatteryPower = settings.disableOnBatteryPower
        batteryDisableThresholdPercent = settings.batteryDisableThresholdPercent.map {
            clamped($0, to: SleepSettingsDefaults.batteryThresholdRange)
        }

        if shouldPersist {
            persistPreferences()
        }
    }

    private var settingsSnapshot: SleepPreventionSettingsSnapshot {
        SleepPreventionSettingsSnapshot(
            defaultDurationMinutes: defaultDurationMinutes,
            disableOnBatteryPower: disableOnBatteryPower,
            batteryDisableThresholdPercent: batteryDisableThresholdPercent
        )
    }

    private func shouldDisableForCurrentBatteryState() -> Bool {
        guard disableOnBatteryPower else { return false }
        let powerState = currentPowerState()
        guard powerState.isOnBattery else { return false }

        guard let threshold = batteryDisableThresholdPercent else {
            return true
        }

        guard let batteryLevel = powerState.batteryLevel else {
            return false
        }

        return batteryLevel <= threshold
    }

    private func currentPowerState() -> PowerState {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return PowerState(isOnBattery: false, batteryLevel: nil)
        }

        let sourceType = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() as String?
        return PowerState(
            isOnBattery: sourceType == kIOPMBatteryPowerKey,
            batteryLevel: currentBatteryLevel(from: snapshot)
        )
    }

    private func currentBatteryLevel(from snapshot: CFTypeRef) -> Int? {
        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any] else {
                continue
            }

            if let isPresent = description[kIOPSIsPresentKey as String] as? Bool, !isPresent {
                continue
            }

            guard let currentCapacity = description[kIOPSCurrentCapacityKey as String] as? Int,
                  let maxCapacity = description[kIOPSMaxCapacityKey as String] as? Int,
                  maxCapacity > 0 else {
                continue
            }

            return Int((Double(currentCapacity) / Double(maxCapacity) * 100).rounded())
        }

        return nil
    }

    private func publishStatusRefresh() {
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }

    private func clamped(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private struct PowerState {
        var isOnBattery: Bool
        var batteryLevel: Int?
    }
}

enum SleepPreventerError: LocalizedError {
    case assertionFailed
    case invalidCustomDuration
    case disabledByBatteryPolicy

    var errorDescription: String? {
        switch self {
        case .assertionFailed:
            return "System sleep prevention could not be enabled."
        case .invalidCustomDuration:
            return SleepPreventionCustomDuration.validationMessage
        case .disabledByBatteryPolicy:
            return "Sleep prevention is disabled by the current battery settings."
        }
    }
}
