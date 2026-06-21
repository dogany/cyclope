//
//  LaunchAtLoginService.swift
//  Cyclope
//

import AppKit
import Combine
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginService: ObservableObject {
    @Published private(set) var status: SMAppService.Status = SMAppService.mainApp.status

    var isEnabled: Bool {
        status == .enabled
    }

    var requiresApproval: Bool {
        status == .requiresApproval
    }

    var isAvailable: Bool {
        status != .notFound
    }

    var statusText: String {
        switch status {
        case .enabled:
            return "Enabled"
        case .requiresApproval:
            return "Needs approval"
        case .notRegistered:
            return "Off"
        case .notFound:
            return "Unavailable"
        @unknown default:
            return "Unknown"
        }
    }

    func refresh() {
        let latestStatus = SMAppService.mainApp.status
        guard status != latestStatus else { return }
        status = latestStatus
    }

    func setEnabled(_ isEnabled: Bool) throws {
        refresh()

        if isEnabled {
            try registerIfNeeded()
        } else {
            guard status != .notRegistered else { return }
            try SMAppService.mainApp.unregister()
        }

        refresh()
    }

    func registerIfNeeded() throws {
        refresh()
        guard status != .enabled, status != .requiresApproval else { return }
        try SMAppService.mainApp.register()
        refresh()
    }

    func openSystemSettings() {
        let loginItemsURL = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
        if !NSWorkspace.shared.open(loginItemsURL) {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }
}
