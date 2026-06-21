//
//  PermissionKind.swift
//  Cyclope
//

import Foundation

enum PermissionKind: CaseIterable {
    case accessibility
    case inputMonitoring

    var title: String {
        switch self {
        case .accessibility:
            return "Accessibility"
        case .inputMonitoring:
            return "Input Monitoring"
        }
    }

    var settingsURL: URL {
        switch self {
        case .accessibility:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        case .inputMonitoring:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        }
    }

    var systemImage: String {
        switch self {
        case .accessibility:
            return "hand.raised"
        case .inputMonitoring:
            return "keyboard"
        }
    }

    var requiredFor: String {
        switch self {
        case .accessibility:
            return "Window control and global shortcuts"
        case .inputMonitoring:
            return "Wheel mouse scroll reversal"
        }
    }
}
