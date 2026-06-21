// Hello nice to meet you
//  AppDelegate.swift
//  Cyclope
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let openSettingsNotification = Notification.Name("CyclopeOpenSettingsRequested")

    /// Invoked when the Dock icon is clicked. Used to open Settings so the app
    /// stays reachable when the menu bar icon is off.
    var onReopen: (() -> Void)?

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard AppEnvironment.shouldRunBackgroundServices else { return }
        terminateDuplicateInstances()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppEnvironment.isRunningForPreviews else { return }
        Self.applyApplicationIcon()
        NSApp.setActivationPolicy(AppPresenceMode.persisted.activationPolicy)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        requestOpenSettings()
        return true
    }

    private func terminateDuplicateInstances() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }

        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        let duplicateApplications = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != currentProcessIdentifier }

        duplicateApplications.forEach { application in
            application.terminate()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if !application.isTerminated {
                    application.forceTerminate()
                }
            }
        }
    }

    private func requestOpenSettings() {
        guard let onReopen else {
            NotificationCenter.default.post(name: Self.openSettingsNotification, object: self)
            return
        }

        onReopen()
    }

    static func applyApplicationIcon() {
        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL) else {
            return
        }

        NSApp.applicationIconImage = icon
    }
}
