//
//  AppPresenceMode.swift
//  Cyclope
//

import AppKit
import Foundation

/// Where Cyclope is visible to the user: the menu bar or the Dock.
/// Hiding from both is intentionally not offered so the app always stays
/// reachable (the Dock icon opens Settings when there is no menu bar icon).
enum AppPresenceMode: String, CaseIterable, Identifiable {
    case menuBar
    case dock

    var id: Self { self }

    var title: String {
        switch self {
        case .menuBar:
            return String(localized: "Menu Bar")
        case .dock:
            return String(localized: "Dock")
        }
    }

    var showsMenuBarIcon: Bool {
        self == .menuBar
    }

    var showsDockIcon: Bool {
        self == .dock
    }

    var activationPolicy: NSApplication.ActivationPolicy {
        showsDockIcon ? .regular : .accessory
    }

    // MARK: - Persistence

    private static let defaultsKey = "appPresenceMode"
    static let `default`: AppPresenceMode = .menuBar

    static var persisted: AppPresenceMode {
        guard let rawValue = UserDefaults.standard.string(forKey: defaultsKey),
              let mode = AppPresenceMode(rawValue: rawValue) else {
            return .default
        }
        return mode
    }

    func persist() {
        UserDefaults.standard.set(rawValue, forKey: Self.defaultsKey)
    }
}
