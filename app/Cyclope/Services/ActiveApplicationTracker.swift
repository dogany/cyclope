//
//  ActiveApplicationTracker.swift
//  Cyclope
//

import AppKit
import Combine
import Foundation

@MainActor
final class ActiveApplicationTracker: ObservableObject {
    @Published private(set) var lastExternalApplicationName = "No target app"

    private let ownBundleIdentifier = Bundle.main.bundleIdentifier
    private let ignoredBundleIdentifiers: Set<String> = [
        "com.apple.ControlCenter",
        "com.apple.Dock",
        "com.apple.SystemEvents",
        "com.apple.SystemUIServer",
        "com.apple.loginwindow",
    ]
    private var activationObserver: NSObjectProtocol?
    private var lastExternalApplication: NSRunningApplication?

    init() {
        recordIfExternal(NSWorkspace.shared.frontmostApplication)

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard let tracker = self else { return }
            Task { @MainActor in
                tracker.recordIfExternal(application)
            }
        }
    }

    func targetApplication() -> NSRunningApplication? {
        if let frontmost = NSWorkspace.shared.frontmostApplication, isExternal(frontmost) {
            recordIfExternal(frontmost)
            return frontmost
        }

        if let windowOwner = frontmostExternalWindowOwner() {
            recordIfExternal(windowOwner)
            return windowOwner
        }

        return lastExternalApplication
    }

    private func recordIfExternal(_ application: NSRunningApplication?) {
        guard let application, isExternal(application) else { return }

        let applicationName = application.localizedName ?? "Target app"
        lastExternalApplication = application

        guard lastExternalApplicationName != applicationName else { return }
        lastExternalApplicationName = applicationName
    }

    private func isExternal(_ application: NSRunningApplication) -> Bool {
        guard application.activationPolicy == .regular,
              let bundleIdentifier = application.bundleIdentifier,
              bundleIdentifier != ownBundleIdentifier,
              !ignoredBundleIdentifiers.contains(bundleIdentifier) else {
            return false
        }

        return true
    }

    private func frontmostExternalWindowOwner() -> NSRunningApplication? {
        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        for window in windowInfo {
            if let layer = window[kCGWindowLayer as String] as? Int, layer != 0 {
                continue
            }

            guard let processIdentifier = window[kCGWindowOwnerPID as String] as? pid_t,
                  let application = NSRunningApplication(processIdentifier: processIdentifier),
                  isExternal(application) else {
                continue
            }

            return application
        }

        return nil
    }

    deinit {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
    }
}
