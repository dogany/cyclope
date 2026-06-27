//
//  CyclopeController.swift
//  Cyclope
//

import AppKit
import Combine
import Foundation
import os
import SwiftUI

@MainActor
final class CyclopeController: ObservableObject {
    private enum SnapTarget {
        case application(NSRunningApplication?)
        case settingsWindow(NSWindow)
    }

    @Published private(set) var lastSnapAction: SnapAction?
    @Published private(set) var statusHistory: [StatusEvent] = []
    @Published var statusMessage = "Ready" {
        didSet {
            recordStatus(statusMessage)
        }
    }
    @Published private(set) var appPresenceMode = AppPresenceMode.persisted

    let activeApplicationTracker = ActiveApplicationTracker()
    let launchAtLoginService = LaunchAtLoginService()
    let permissionCoordinator = PermissionCoordinator()
    let shortcutSettings = ShortcutSettingsStore()
    let snapSettings = SnapSettingsStore()
    let sleepPreventer = SleepPreventer()
    let scrollDirectionController = ScrollDirectionController()
    let updateService = UpdateService()

    private let shortcutManager = GlobalShortcutManager()
    private let dragSnapManager = WindowDragSnapManager()
    private let windowSnapper = WindowSnapper()
    private var cancellables = Set<AnyCancellable>()
    private var cheatSheetWindow: CommandCheatSheetPanel?
    private var cheatSheetTargetsSettingsWindow = false
    private var settingsWindow: NSWindow?
    private var settingsWindowWasSnapTargetActive = false
    private var didOfferStaleAccessibilityReauthorization = false
    private var settingsWindowObservers: [NSObjectProtocol] = []
    private var applicationActivationObserver: NSObjectProtocol?
    private var isObjectChangeForwardingScheduled = false
    private let ownBundleIdentifier = Bundle.main.bundleIdentifier
    private let logger = Logger(subsystem: "com.dogany.cyclope", category: "Controller")
    private let keyboardNudgeDistance: CGFloat = 20

    private let lastSnapDefaultsKey = "lastSnapAction"

    var menuBarTitle: String {
        if sleepPreventer.isActive {
            return String(localized: "Awake")
        }

        return "Cyclope"
    }

    var menuBarIconImageName: String {
        // The menu bar icon uses the default Cyclope mark, then switches to the
        // sleep-state mark while Sleep Prevention is active.
        sleepPreventer.isActive ? "CyclopeMenuBarIconActive" : "CyclopeMenuBarIcon"
    }

    init() {
        if let rawValue = UserDefaults.standard.string(forKey: lastSnapDefaultsKey) {
            lastSnapAction = SnapAction(rawValue: rawValue)
        }

        recordStatus(statusMessage)
        forwardObjectChanges()
        configureSleepPreventionExpiration()
        configureSettingsSnapTargetReset()

        if AppEnvironment.shouldRunBackgroundServices {
            configureDockReopenHandling()
            scrollDirectionController.startBackgroundServices()
            requestWheelMouseScrollPermissionsIfNeeded()

            shortcutManager.start(
                settings: shortcutSettings,
                snapSettings: snapSettings,
                handler: { [weak self] shortcut in
                    self?.handle(shortcut)
                }
            )

            dragSnapManager.start(
                snapSettings: snapSettings,
                shouldHandleOwnApplicationDrag: { [weak self] in
                    self?.isSettingsWindowSnapTargetActive == true
                },
                snapHandler: { [weak self] target, screen in
                    self?.snap(target, on: screen)
                }
            )
        }

        if shouldShowSettingsAtLaunch {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.showSettingsWindow()
                self.captureSettingsSnapshotIfRequested()
            }
        }

        if shouldShowCheatSheetAtLaunch {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.showCheatSheet()
                self.captureCheatSheetSnapshotIfRequested()
            }
        }
    }

    func snap(_ action: SnapAction) {
        performSnap(description: action.title) { target in
            try applySnap(action, to: target)
            remember(action)
        }
    }

    func snap(_ preset: CustomSnapPreset) {
        performSnap(description: preset.name) { target in
            if preset.isPositionOnly {
                try applyPositionOnlySnap(preset.position.layout, to: target)
            } else {
                try applySnap(preset.layout, to: target)
            }
        }
    }

    private func snap(_ target: WindowDragSnapTarget, on screen: NSScreen) {
        if let snapAction = target.snapAction {
            performSnap(description: target.title) { snapTarget in
                try applySnap(snapAction, to: snapTarget, on: screen)
                remember(snapAction)
            }
            return
        }

        performSnap(description: target.title) { snapTarget in
            if let position = target.position {
                try applyPositionOnlySnap(position.layout, to: snapTarget, on: screen)
            } else {
                try applySnap(target.layout, to: snapTarget, on: screen)
            }
        }
    }

    private func performSnap(description: String, action: (SnapTarget) throws -> Void) {
        permissionCoordinator.refresh()

        guard permissionCoordinator.isAccessibilityTrusted else {
            logger.error("snap blocked: accessibility permission missing")
            openPermissionSettings(.accessibility, reason: "Window snapping requires Accessibility permission.")
            return
        }

        do {
            try action(currentSnapTarget())
            statusMessage = "Snapped \(description)."
            didOfferStaleAccessibilityReauthorization = false
        } catch {
            statusMessage = error.localizedDescription
            logger.error("snap failed description=\(description, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            if case WindowSnapperError.accessibilityMessagingUnavailable = error {
                offerStaleAccessibilityReauthorization()
            }
        }
    }

    /// AXIsProcessTrusted() reports granted but Accessibility messaging is refused —
    /// a stale TCC grant. Point the user at the Accessibility pane to re-grant, but
    /// only once per episode so repeated snap attempts don't reopen System Settings.
    private func offerStaleAccessibilityReauthorization() {
        guard !didOfferStaleAccessibilityReauthorization else { return }
        didOfferStaleAccessibilityReauthorization = true
        permissionCoordinator.openSystemSettings(for: .accessibility)
    }

    func repeatLastSnap() {
        guard let lastSnapAction else {
            statusMessage = "No snap action has been used yet."
            return
        }

        snap(lastSnapAction)
    }

    /// Opens System Settings › Desktop & Dock so the user can disable macOS's
    /// built-in edge tiling, which competes with Cyclope's edge snapping. The
    /// App Sandbox forbids changing `com.apple.WindowManager` directly, so the
    /// user toggles it themselves.
    func openWindowTilingSettings() {
        let desktopSettings = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension")
        if let desktopSettings, NSWorkspace.shared.open(desktopSettings) {
            statusMessage = "Opening Desktop & Dock settings."
            return
        }

        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        statusMessage = "Opening System Settings."
    }

    func confirmRestoreDefaultSnapPresets() {
        let alert = NSAlert()
        alert.messageText = "Restore default snap presets?"
        alert.informativeText = "Custom snap presets will be replaced with the built-in defaults."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Restore")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        snapSettings.restoreDefaultPresets()
        shortcutSettings.removeCustomPreferences(excluding: Set(snapSettings.presets.map(\.id)))
        statusMessage = "Restored default snap presets."
    }

    func confirmRestoreDefaultSettings() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Reset to default?")
        alert.informativeText = String(localized: "All settings will be restored to their defaults. This can't be undone.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Reset"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        guard let settings = SettingsFileStore.restoreDefaultSettings(),
              let snapSettingsSnapshot = settings.windowManager.snapSettings,
              let shortcutSettingsSnapshot = settings.windowManager.shortcutSettings else {
            statusMessage = "Could not restore default settings."
            return
        }

        snapSettings.apply(snapSettingsSnapshot)
        shortcutSettings.apply(shortcutSettingsSnapshot, menuCategories: settings.windowManager.menuCategories)
        sleepPreventer.applySettings(settings.sleepPrevention)
        statusMessage = "Restored default settings."
    }

    func setLaunchAfterLoginEnabled(_ isEnabled: Bool) {
        do {
            try launchAtLoginService.setEnabled(isEnabled)
            if launchAtLoginService.requiresApproval {
                statusMessage = "Approve Open at Login in System Settings."
            } else {
                statusMessage = isEnabled ? "Open at Login enabled." : "Open at Login disabled."
            }
        } catch {
            launchAtLoginService.refresh()
            statusMessage = "Could not update Open at Login: \(error.localizedDescription)"
        }
    }

    func openLaunchAfterLoginSettings() {
        do {
            try launchAtLoginService.registerIfNeeded()
            if launchAtLoginService.requiresApproval {
                statusMessage = "Approve Open at Login in System Settings."
            }
        } catch {
            launchAtLoginService.refresh()
            statusMessage = "Could not register Open at Login: \(error.localizedDescription)"
        }

        launchAtLoginService.openSystemSettings()
    }

    func confirmDeleteSelectedSnapPreset() {
        guard let selectedPresetID = snapSettings.selectedPresetID else {
            statusMessage = "No custom snap command is selected."
            return
        }

        confirmDeleteSnapPreset(selectedPresetID)
    }

    @discardableResult
    func confirmDeleteSnapPreset(_ presetID: CustomSnapPreset.ID) -> Bool {
        guard let preset = snapSettings.preset(withID: presetID) else {
            statusMessage = "Custom snap command not found."
            return false
        }

        let alert = NSAlert()
        alert.messageText = String(localized: "Delete \(preset.name)?")
        alert.informativeText = String(localized: "This custom snap command will be removed.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Delete"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return false }

        return deleteSnapPreset(presetID)
    }

    @discardableResult
    func deleteSnapPreset(_ presetID: CustomSnapPreset.ID) -> Bool {
        guard let preset = snapSettings.preset(withID: presetID) else {
            statusMessage = "Custom snap command not found."
            return false
        }

        snapSettings.deletePreset(presetID)
        shortcutSettings.removeCustomPreference(for: presetID)
        statusMessage = "Deleted \(preset.name)."
        return true
    }

    func enableSleepPrevention(_ duration: SleepDuration) {
        do {
            try sleepPreventer.enable(duration)
            statusMessage = sleepPreventer.statusText
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func enableDefaultSleepPrevention() {
        do {
            try sleepPreventer.enableDefault()
            statusMessage = sleepPreventer.statusText
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func setSleepPreventionDuration(_ duration: SleepDuration) {
        sleepPreventer.setDefaultDuration(duration)
        statusMessage = "Default sleep duration set to \(sleepPreventer.defaultDurationTitle)."
    }

    func setSleepPreventionDefaultDurationMinutes(_ minutes: Int?) {
        sleepPreventer.setDefaultDurationMinutes(minutes)
        if let minutes {
            statusMessage = "Default sleep duration set to \(minutes) minutes."
        } else {
            statusMessage = "Default sleep duration set to Never."
        }
    }

    func setSleepDisableOnBatteryPower(_ isEnabled: Bool) {
        let wasDisabled = sleepPreventer.setDisableOnBatteryPower(isEnabled)
        if wasDisabled {
            statusMessage = "Sleep prevention disabled on battery power."
        } else {
            statusMessage = isEnabled ?
                "Sleep prevention will disable on battery power." :
                "Sleep prevention can stay active on battery power."
        }
    }

    func setSleepBatteryDisableThresholdPercent(_ percent: Int?) {
        let wasDisabled = sleepPreventer.setBatteryDisableThresholdPercent(percent)
        if wasDisabled {
            statusMessage = "Sleep prevention disabled on battery power."
        } else if let percent {
            statusMessage = "Battery sleep threshold set to \(percent)%."
        } else {
            statusMessage = "Battery sleep threshold set to Always."
        }
    }

    func promptCustomSleepPreventionDuration() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Deactivate after")
        alert.informativeText = customSleepPreventionPromptMessage
        alert.addButton(withTitle: sleepPreventer.isActive ? String(localized: "Update") : String(localized: "Start"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        input.placeholderString = String(localized: "Minutes")
        input.stringValue = String(sleepPreventer.customDurationMinutes ?? SleepPreventionCustomDuration.defaultMinutes)
        alert.accessoryView = input

        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        guard let minutes = Int(input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              SleepPreventionCustomDuration.validMinuteRange.contains(minutes) else {
            statusMessage = SleepPreventionCustomDuration.validationMessage
            return
        }

        do {
            try sleepPreventer.enableCustom(minutes: minutes)
            statusMessage = sleepPreventer.statusText
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private var customSleepPreventionPromptMessage: String {
        let minimum = SleepPreventionCustomDuration.minimumMinutes
        let maximum = SleepPreventionCustomDuration.maximumMinutes
        if sleepPreventer.isActive {
            return String(localized: "Enter a duration from \(minimum) to \(maximum) minutes. Updating the duration restarts sleep prevention.")
        }

        return String(localized: "Enter a duration from \(minimum) to \(maximum) minutes. Starting a custom duration activates sleep prevention immediately.")
    }

    func disableSleepPrevention() {
        sleepPreventer.disable()
        statusMessage = "Sleep prevention is off."
    }

    func toggleSleepPrevention() {
        if sleepPreventer.isActive {
            disableSleepPrevention()
        } else {
            enableDefaultSleepPrevention()
        }
    }

    func setWheelMouseReverseScrollingEnabled(_ isEnabled: Bool) {
        if isEnabled {
            requestWheelMouseScrollPermissionsIfNeeded(isEnabled: true)
        }

        scrollDirectionController.setWheelMouseReverseScrollingEnabled(isEnabled)
        updateWheelMouseReverseScrollingStatusMessage(isEnabled: isEnabled)
    }

    func toggleWheelMouseReverseScrolling() {
        setWheelMouseReverseScrollingEnabled(!scrollDirectionController.isWheelMouseReverseScrollingEnabled)
    }

    func openScrollDirectionSettings() {
        let mouseSettings = URL(string: "x-apple.systempreferences:com.apple.Mouse-Settings.extension")
        if let mouseSettings, NSWorkspace.shared.open(mouseSettings) {
            statusMessage = "Opening macOS Natural Scrolling settings."
            return
        }

        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        statusMessage = "Opening System Settings."
    }

    func setNaturalScrollingEnabled(_ isEnabled: Bool) {
        scrollDirectionController.setNaturalScrollingEnabled(isEnabled)
        statusMessage = scrollDirectionController.isNaturalScrollingEnabled ?
            "Natural Scrolling is on." :
            "Natural Scrolling is off."
    }

    func toggleNaturalScrolling() {
        scrollDirectionController.toggleNaturalScrolling()
        statusMessage = scrollDirectionController.isNaturalScrollingEnabled ?
            "Natural Scrolling is on." :
            "Natural Scrolling is off."
    }

    private func requestWheelMouseScrollPermissionsIfNeeded(
        isEnabled: Bool? = nil
    ) {
        guard isEnabled ?? scrollDirectionController.isWheelMouseReverseScrollingEnabled else { return }

        permissionCoordinator.refresh()
        if !permissionCoordinator.isInputMonitoringTrusted {
            permissionCoordinator.requestInputMonitoring()
            statusMessage = "Reverse Mouse Scrolling needs Input Monitoring permission. If it is already allowed, restart \(applicationDisplayName)."
            return
        }

        if !permissionCoordinator.isGranted(.accessibility) {
            permissionCoordinator.requestAccessibility()
            statusMessage = "Reverse Mouse Scrolling needs Accessibility permission. If it is already allowed, restart \(applicationDisplayName)."
        }
    }

    private func updateWheelMouseReverseScrollingStatusMessage(isEnabled: Bool) {
        permissionCoordinator.refresh()

        if isEnabled && !permissionCoordinator.isInputMonitoringTrusted {
            statusMessage = "Reverse Mouse Scrolling is on, but Input Monitoring permission is required. If it is already allowed, restart \(applicationDisplayName)."
            return
        }

        if isEnabled && !permissionCoordinator.isGranted(.accessibility) {
            statusMessage = "Reverse Mouse Scrolling is on, but Accessibility permission is required. If it is already allowed, restart \(applicationDisplayName)."
            return
        }

        if isEnabled && !scrollDirectionController.isWheelMouseScrollReversalActive {
            statusMessage = "Reverse Mouse Scrolling is on, but the scroll event tap could not start. If permissions were just changed, restart \(applicationDisplayName)."
            return
        }

        statusMessage = isEnabled ?
            "Reverse Mouse Scrolling is on. Trackpad scrolling is unchanged." :
            "Reverse Mouse Scrolling is off."
    }

    func copyShortcut(_ shortcut: GlobalShortcut) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("\(shortcut.title): \(shortcut.keys)", forType: .string)
        statusMessage = "Copied \(shortcut.title) shortcut."
    }

    func showSettingsWindow(category: SettingsCategory? = nil) {
        let window = settingsWindow ?? makeSettingsWindow(initialCategory: category ?? initialSettingsCategory)
        settingsWindow = window

        if let category, window.contentViewController != nil {
            window.contentViewController = makeSettingsContentController(initialCategory: category)
        }

        markSettingsWindowAsSnapTarget()
        refreshExternalSettingsState()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func setAppPresenceMode(_ mode: AppPresenceMode) {
        guard mode != appPresenceMode else { return }
        appPresenceMode = mode
        mode.persist()
        applyActivationPolicy()
    }

    private func applyActivationPolicy() {
        guard !AppEnvironment.isRunningForPreviews else { return }
        AppDelegate.applyApplicationIcon()
        NSApp.setActivationPolicy(appPresenceMode.activationPolicy)
    }

    private func configureDockReopenHandling() {
        NotificationCenter.default.publisher(for: AppDelegate.openSettingsNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.showSettingsWindow()
            }
            .store(in: &cancellables)

        installDockReopenHandler()
    }

    private func installDockReopenHandler(attempt: Int = 0) {
        guard let appDelegate = NSApp.delegate as? AppDelegate else {
            guard attempt < 20 else { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.installDockReopenHandler(attempt: attempt + 1)
            }
            return
        }

        appDelegate.onReopen = { [weak self] in
            self?.showSettingsWindow()
        }
    }

    func toggleCheatSheet() {
        if cheatSheetWindow?.isVisible == true {
            dismissCheatSheet()
        } else {
            showCheatSheet()
        }
    }

    func showCheatSheet() {
        cheatSheetTargetsSettingsWindow = shouldSnapSettingsWindowForCommands
        let window = cheatSheetWindow ?? makeCheatSheetWindow()
        cheatSheetWindow = window
        positionCheatSheetWindow(window)
        window.showWithoutActivatingApp()
    }

    func dismissCheatSheet() {
        cheatSheetTargetsSettingsWindow = false
        cheatSheetWindow?.orderOut(nil)
    }

    func performCheatSheetCommand(_ command: CheatSheetCommand) {
        switch command {
        case .snap(let action):
            snap(action)
        case .customSnap(let presetID, _, _):
            guard let preset = snapSettings.preset(withID: presetID) else {
                statusMessage = "Custom snap command not found."
                return
            }

            snap(preset)
        case .repeatLastSnap:
            repeatLastSnap()
        case .toggleSleepPrevention:
            toggleSleepPrevention()
        case .toggleNaturalScrolling:
            toggleNaturalScrolling()
        case .toggleWheelMouseReverseScrolling:
            toggleWheelMouseReverseScrolling()
        }
    }

    func nudgeActiveWindow(_ direction: WindowNudgeDirection) {
        permissionCoordinator.refresh()

        guard permissionCoordinator.isAccessibilityTrusted else {
            logger.error("nudge blocked: accessibility permission missing")
            openPermissionSettings(.accessibility, reason: "Window nudging requires Accessibility permission.")
            return
        }

        do {
            try applyNudge(direction, to: currentSnapTarget())
            statusMessage = "Moved \(direction.statusTitle)."
            didOfferStaleAccessibilityReauthorization = false
        } catch {
            statusMessage = error.localizedDescription
            logger.error("nudge failed direction=\(direction.statusTitle, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            if case WindowSnapperError.accessibilityMessagingUnavailable = error {
                offerStaleAccessibilityReauthorization()
            }
        }
    }

    func requestAccessibilityPermission() {
        permissionCoordinator.refresh()
        guard !permissionCoordinator.isGranted(.accessibility) else {
            statusMessage = "Accessibility permission is allowed."
            return
        }

        permissionCoordinator.requestAccessibility()
        statusMessage = "Opening Accessibility settings."
    }

    func requestInputMonitoringPermission() {
        permissionCoordinator.refresh()
        guard !permissionCoordinator.isInputMonitoringTrusted else {
            statusMessage = "Input Monitoring permission is allowed."
            return
        }

        permissionCoordinator.requestInputMonitoring()
        statusMessage = "Opening Input Monitoring settings."
    }

    func openNextMissingPermission() {
        permissionCoordinator.refresh()

        guard let permission = permissionCoordinator.missingPermissions.first else {
            statusMessage = "All permissions are allowed."
            return
        }

        requestPermission(permission)
    }

    func openPermissionSettings(_ permission: PermissionKind) {
        permissionCoordinator.openSystemSettings(for: permission)
        statusMessage = "Opening \(permission.title) settings."
    }

    func clearStatusHistory() {
        statusHistory.removeAll()
        recordStatus(statusMessage)
    }

    func requestPermission(_ permission: PermissionKind) {
        switch permission {
        case .accessibility:
            requestAccessibilityPermission()
        case .inputMonitoring:
            requestInputMonitoringPermission()
        }
    }

    private func openPermissionSettings(_ permission: PermissionKind, reason: String) {
        statusMessage = reason
        permissionCoordinator.openSystemSettings(for: permission)
    }

    private func applySnap(_ action: SnapAction, to target: SnapTarget) throws {
        switch target {
        case .application(let application):
            try windowSnapper.snap(action, targetApplication: application)
        case .settingsWindow(let window):
            try windowSnapper.snap(action, targetWindow: window)
        }
    }

    private func applySnap(_ action: SnapAction, to target: SnapTarget, on screen: NSScreen) throws {
        switch target {
        case .application(let application):
            try windowSnapper.snap(action, targetApplication: application, on: screen)
        case .settingsWindow(let window):
            try windowSnapper.snap(action, targetWindow: window, on: screen)
        }
    }

    private func applySnap(_ layout: SnapLayout, to target: SnapTarget) throws {
        switch target {
        case .application(let application):
            try windowSnapper.snap(layout, targetApplication: application)
        case .settingsWindow(let window):
            try windowSnapper.snap(layout, targetWindow: window)
        }
    }

    private func applySnap(_ layout: SnapLayout, to target: SnapTarget, on screen: NSScreen) throws {
        switch target {
        case .application(let application):
            try windowSnapper.snap(layout, targetApplication: application, on: screen)
        case .settingsWindow(let window):
            try windowSnapper.snap(layout, targetWindow: window, on: screen)
        }
    }

    private func applyPositionOnlySnap(_ layout: SnapLayout, to target: SnapTarget) throws {
        switch target {
        case .application(let application):
            try windowSnapper.snapPositionOnly(layout, targetApplication: application)
        case .settingsWindow(let window):
            try windowSnapper.snapPositionOnly(layout, targetWindow: window)
        }
    }

    private func applyPositionOnlySnap(_ layout: SnapLayout, to target: SnapTarget, on screen: NSScreen) throws {
        switch target {
        case .application(let application):
            try windowSnapper.snapPositionOnly(layout, targetApplication: application, on: screen)
        case .settingsWindow(let window):
            try windowSnapper.snapPositionOnly(layout, targetWindow: window, on: screen)
        }
    }

    private func applyNudge(_ direction: WindowNudgeDirection, to target: SnapTarget) throws {
        switch target {
        case .application(let application):
            try windowSnapper.nudge(direction, distance: keyboardNudgeDistance, targetApplication: application)
        case .settingsWindow(let window):
            try windowSnapper.nudge(direction, distance: keyboardNudgeDistance, targetWindow: window)
        }
    }

    private func currentSnapTarget() -> SnapTarget {
        if cheatSheetWindow?.isVisible == true {
            if cheatSheetTargetsSettingsWindow,
               let settingsWindow,
               settingsWindow.isVisible {
                return .settingsWindow(settingsWindow)
            }

            return .application(activeApplicationTracker.targetApplication())
        }

        if shouldSnapSettingsWindowForCommands,
           let settingsWindow {
            return .settingsWindow(settingsWindow)
        }

        return .application(activeApplicationTracker.targetApplication())
    }

    private var isSettingsWindowSnapTargetActive: Bool {
        guard let settingsWindow, settingsWindow.isVisible else { return false }
        guard cheatSheetWindow?.isVisible != true else { return false }
        return settingsWindow.isKeyWindow || settingsWindow.isMainWindow
    }

    private var shouldSnapSettingsWindowForCommands: Bool {
        guard let settingsWindow, settingsWindow.isVisible else { return false }
        if settingsWindow.isKeyWindow {
            return true
        }

        guard isOwnApplicationFrontmost else {
            return false
        }

        return settingsWindow.isMainWindow || settingsWindowWasSnapTargetActive
    }

    private var isOwnApplicationFrontmost: Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == ownBundleIdentifier
    }

    private func markSettingsWindowAsSnapTarget() {
        settingsWindowWasSnapTargetActive = true
        refreshExternalSettingsState()
    }

    private func refreshExternalSettingsState() {
        permissionCoordinator.refresh()
        launchAtLoginService.refresh()
        scrollDirectionController.refresh()
    }

    private func configureSettingsSnapTargetReset() {
        applicationActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleIdentifier = application?.bundleIdentifier
            MainActor.assumeIsolated {
                guard let self else { return }
                guard bundleIdentifier != self.ownBundleIdentifier else {
                    self.refreshExternalSettingsState()
                    return
                }

                self.settingsWindowWasSnapTargetActive = false
            }
        }
    }

    private func observeSettingsWindowForSnapTarget(_ window: NSWindow) {
        let notificationCenter = NotificationCenter.default

        settingsWindowObservers.append(
            notificationCenter.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.markSettingsWindowAsSnapTarget()
                }
            }
        )

        settingsWindowObservers.append(
            notificationCenter.addObserver(
                forName: NSWindow.didBecomeMainNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.markSettingsWindowAsSnapTarget()
                }
            }
        )

        settingsWindowObservers.append(
            notificationCenter.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.settingsWindowWasSnapTargetActive = false
                }
            }
        )
    }

    private func makeSettingsContentController(initialCategory: SettingsCategory) -> NSViewController {
        NSHostingController(
            rootView: SettingsView(initialSelection: initialCategory)
                .environmentObject(self)
                .environmentObject(permissionCoordinator)
                .environmentObject(launchAtLoginService)
                .environmentObject(updateService)
        )
    }

    private func makeSettingsWindow(initialCategory: SettingsCategory) -> NSWindow {
        let hostingController = makeSettingsContentController(initialCategory: initialCategory)
        let window = NSWindow(contentViewController: hostingController)
        let minSize = NSSize(width: 720, height: 540)

        window.title = "Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isExcludedFromWindowsMenu = true
        window.minSize = minSize
        window.contentMinSize = minSize
        window.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        window.setContentSize(NSSize(width: 876, height: 720))
        window.center()
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = false
        window.tabbingMode = .disallowed
        window.standardWindowButton(.zoomButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isEnabled = true
        window.setFrameAutosaveName("CyclopeSettingsWindowV2")
        observeSettingsWindowForSnapTarget(window)

        return window
    }

    private var shouldShowSettingsAtLaunch: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--show-settings") ||
            arguments.contains("--show-shortcuts-settings") ||
            arguments.contains("--show-custom-snap-settings") ||
            settingsSnapshotURL != nil
    }

    private var shouldShowCheatSheetAtLaunch: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--show-cheat-sheet") ||
            cheatSheetSnapshotURL != nil
    }

    private var applicationDisplayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
            Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ??
            "Cyclope"
    }

    private var initialSettingsCategory: SettingsCategory {
        let arguments = ProcessInfo.processInfo.arguments
        if let settingsSnapshotCategory {
            return settingsSnapshotCategory
        }

        if arguments.contains("--show-window-snapping-settings") {
            return .shortcuts
        }

        if arguments.contains("--show-custom-snap-settings") {
            return .shortcuts
        }

        if arguments.contains("--show-shortcuts-settings") {
            return .shortcuts
        }

        return .preferences
    }

    private var settingsSnapshotCategory: SettingsCategory? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--settings-category") else { return nil }
        let categoryIndex = arguments.index(after: index)
        guard arguments.indices.contains(categoryIndex) else { return nil }
        return SettingsCategory(rawValue: arguments[categoryIndex])
    }

    private var settingsSnapshotURL: URL? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--settings-snapshot") else { return nil }
        let pathIndex = arguments.index(after: index)
        guard arguments.indices.contains(pathIndex) else { return nil }
        return URL(fileURLWithPath: arguments[pathIndex])
    }

    private var cheatSheetSnapshotURL: URL? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--cheat-sheet-snapshot") else { return nil }
        let pathIndex = arguments.index(after: index)
        guard arguments.indices.contains(pathIndex) else { return nil }
        return URL(fileURLWithPath: arguments[pathIndex])
    }

    private func captureSettingsSnapshotIfRequested() {
        guard let settingsSnapshotURL else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.captureSettingsWindow(to: settingsSnapshotURL)
            NSApp.terminate(nil)
        }
    }

    private func captureSettingsWindow(to url: URL) {
        guard let contentView = settingsWindow?.contentView else { return }
        let bounds = contentView.bounds
        guard let representation = contentView.bitmapImageRepForCachingDisplay(in: bounds) else { return }

        contentView.cacheDisplay(in: bounds, to: representation)
        guard let data = representation.representation(using: .png, properties: [:]) else { return }

        try? data.write(to: url)
    }

    private func captureCheatSheetSnapshotIfRequested() {
        guard let cheatSheetSnapshotURL else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.captureCheatSheetWindow(to: cheatSheetSnapshotURL)
            NSApp.terminate(nil)
        }
    }

    private func captureCheatSheetWindow(to url: URL) {
        guard let contentView = cheatSheetWindow?.contentView else { return }
        let bounds = contentView.bounds
        guard let representation = contentView.bitmapImageRepForCachingDisplay(in: bounds) else { return }

        contentView.cacheDisplay(in: bounds, to: representation)
        guard let data = representation.representation(using: .png, properties: [:]) else { return }

        try? data.write(to: url)
    }

    private func makeCheatSheetWindow() -> CommandCheatSheetPanel {
        let hostingController = NSHostingController(
            rootView: CommandCheatSheetView(
                onCommand: { [weak self] command in
                    self?.performCheatSheetCommand(command)
                },
                onDismiss: { [weak self] in
                    self?.dismissCheatSheet()
                }
            )
            .environmentObject(self)
            .environmentObject(shortcutSettings)
            .environmentObject(snapSettings)
        )

        let window = CommandCheatSheetPanel(contentViewController: hostingController)
        window.onCommand = { [weak self] command in
            self?.performCheatSheetCommand(command)
        }
        window.onNudge = { [weak self] direction in
            self?.nudgeActiveWindow(direction)
        }
        window.onDismiss = { [weak self] in
            self?.dismissCheatSheet()
        }
        window.commandResolver = { [weak self] event in
            guard let self else { return nil }
            return CheatSheetCommand.command(
                for: event,
                settings: self.shortcutSettings,
                customPresets: self.snapSettings.presets
            )
        }
        return window
    }

    private func positionCheatSheetWindow(_ window: NSWindow) {
        let windowSize = fittedCheatSheetWindowSize(for: window)
        let screen = screenContainingMouse() ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1000, height: 700)
        let origin = NSPoint(
            x: visibleFrame.midX - windowSize.width / 2,
            y: visibleFrame.midY - windowSize.height / 2
        )

        window.setFrame(NSRect(origin: origin, size: windowSize), display: true)
    }

    private func fittedCheatSheetWindowSize(for window: NSWindow) -> NSSize {
        window.layoutIfNeeded()

        let fittingSize = window.contentViewController?.view.fittingSize ?? .zero
        guard fittingSize.width > 1, fittingSize.height > 1 else {
            return NSSize(
                width: CommandCheatSheetLayout.fallbackWindowSize.width,
                height: CommandCheatSheetLayout.fallbackWindowSize.height
            )
        }

        return fittingSize
    }

    private func screenContainingMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        }
    }

    private func configureSleepPreventionExpiration() {
        sleepPreventer.onExpiration = { [weak self] in
            self?.statusMessage = "Sleep prevention expired."
        }

        sleepPreventer.onBatteryPolicyDisabled = { [weak self] in
            self?.statusMessage = "Sleep prevention disabled on battery power."
        }
    }

    private func recordStatus(_ message: String) {
        let trimmedMessage = sanitizedStatusMessage(message)
        guard !trimmedMessage.isEmpty else { return }
        guard statusHistory.first?.message != trimmedMessage else { return }

        statusHistory.insert(StatusEvent(message: trimmedMessage, date: Date()), at: 0)
        if statusHistory.count > 8 {
            statusHistory.removeLast(statusHistory.count - 8)
        }
    }

    private func sanitizedStatusMessage(_ message: String) -> String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func forwardObjectChanges() {
        activeApplicationTracker.objectWillChange
            .sink { [weak self] _ in self?.scheduleObjectChangeForwarding() }
            .store(in: &cancellables)

        permissionCoordinator.objectWillChange
            .sink { [weak self] _ in self?.scheduleObjectChangeForwarding() }
            .store(in: &cancellables)

        launchAtLoginService.objectWillChange
            .sink { [weak self] _ in self?.scheduleObjectChangeForwarding() }
            .store(in: &cancellables)

        shortcutSettings.objectWillChange
            .sink { [weak self] _ in self?.scheduleObjectChangeForwarding() }
            .store(in: &cancellables)

        snapSettings.objectWillChange
            .sink { [weak self] _ in self?.scheduleObjectChangeForwarding() }
            .store(in: &cancellables)

        sleepPreventer.objectWillChange
            .sink { [weak self] _ in self?.scheduleObjectChangeForwarding() }
            .store(in: &cancellables)

        scrollDirectionController.objectWillChange
            .sink { [weak self] _ in self?.scheduleObjectChangeForwarding() }
            .store(in: &cancellables)
    }

    private func scheduleObjectChangeForwarding() {
        guard !isObjectChangeForwardingScheduled else { return }
        isObjectChangeForwardingScheduled = true

        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isObjectChangeForwardingScheduled = false
                self.objectWillChange.send()
            }
        }
    }

    private func handle(_ shortcut: GlobalShortcut.Command) {
        switch shortcut {
        case .snap(let action):
            snap(action)
        case .customSnap(let presetID):
            guard let preset = snapSettings.preset(withID: presetID) else {
                statusMessage = "Custom snap command not found."
                return
            }

            snap(preset)
        case .repeatLastSnap:
            repeatLastSnap()
        case .showCheatSheet:
            toggleCheatSheet()
        case .toggleSleepPrevention:
            toggleSleepPrevention()
        case .toggleNaturalScrolling:
            toggleNaturalScrolling()
        case .toggleWheelMouseReverseScrolling:
            toggleWheelMouseReverseScrolling()
        }
    }

    private func remember(_ action: SnapAction) {
        if lastSnapAction != action {
            lastSnapAction = action
        }
        UserDefaults.standard.set(action.rawValue, forKey: lastSnapDefaultsKey)
    }

    deinit {
        settingsWindowObservers.forEach(NotificationCenter.default.removeObserver)

        if let applicationActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(applicationActivationObserver)
        }
    }
}
