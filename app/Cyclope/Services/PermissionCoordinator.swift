//
//  PermissionCoordinator.swift
//  Cyclope
//

import ApplicationServices
import AppKit
import Combine
import CoreGraphics
import Foundation

@MainActor
final class PermissionCoordinator: ObservableObject {
    @Published private(set) var isAccessibilityTrusted = AXIsProcessTrusted()
    @Published private(set) var isInputMonitoringTrusted = CGPreflightListenEventAccess()

    var isAccessibilityAccessGranted: Bool {
        isAccessibilityTrusted
    }

    var accessibilityStatusText: String {
        if isAccessibilityAccessGranted {
            return String(localized: "Allowed")
        }

        return String(
            format: String(localized: "Required for this build. If System Settings already shows allowed, restart %@."),
            applicationDisplayName
        )
    }

    var inputMonitoringStatusText: String {
        if isInputMonitoringTrusted {
            return String(localized: "Allowed")
        }

        return String(
            format: String(localized: "Required for wheel mouse scroll reversal. If System Settings already shows allowed, restart %@."),
            applicationDisplayName
        )
    }

    var missingPermissions: [PermissionKind] {
        PermissionKind.allCases.filter { !isGranted($0) }
    }

    var hasMissingPermissions: Bool {
        !missingPermissions.isEmpty
    }

    var setupStatusTitle: String {
        guard hasMissingPermissions else {
            return "All permissions allowed"
        }

        let count = missingPermissions.count
        return count == 1 ? "1 permission needed" : "\(count) permissions needed"
    }

    var setupStatusSystemImage: String {
        hasMissingPermissions ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
    }

    func isGranted(_ permission: PermissionKind) -> Bool {
        switch permission {
        case .accessibility:
            return isAccessibilityAccessGranted
        case .inputMonitoring:
            return isInputMonitoringTrusted
        }
    }

    func statusText(for permission: PermissionKind) -> String {
        switch permission {
        case .accessibility:
            return accessibilityStatusText
        case .inputMonitoring:
            return inputMonitoringStatusText
        }
    }

    func refresh() {
        let latestAccessibilityTrusted = AXIsProcessTrusted()
        let latestInputMonitoringTrusted = CGPreflightListenEventAccess()

        if isAccessibilityTrusted != latestAccessibilityTrusted {
            isAccessibilityTrusted = latestAccessibilityTrusted
        }

        if isInputMonitoringTrusted != latestInputMonitoringTrusted {
            isInputMonitoringTrusted = latestInputMonitoringTrusted
        }
    }

    func requestAccessibility() {
        promptForAccessibilityIfNeeded()
        openSystemSettings(for: .accessibility)
        refresh()
    }

    func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
        openSystemSettings(for: .inputMonitoring)
        refresh()
    }

    func openSystemSettings(for permission: PermissionKind) {
        switch permission {
        case .accessibility:
            promptForAccessibilityIfNeeded()
        case .inputMonitoring:
            _ = CGRequestListenEventAccess()
        }

        NSWorkspace.shared.open(permission.settingsURL)
        refresh()
    }

    private func promptForAccessibilityIfNeeded() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary

        _ = AXIsProcessTrustedWithOptions(options)
    }

    private var applicationDisplayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
            Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ??
            "Cyclope"
    }
}
