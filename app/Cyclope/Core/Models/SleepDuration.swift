//
//  SleepDuration.swift
//  Cyclope
//

import Foundation

enum SleepDuration: String, CaseIterable, Identifiable {
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case twoHours
    case untilTurnedOff

    var id: String { rawValue }

    static let deactivationOptions: [SleepDuration] = [
        .fifteenMinutes,
        .thirtyMinutes,
        .oneHour,
        .twoHours
    ]

    var title: String {
        switch self {
        case .fifteenMinutes:
            return "15 min"
        case .thirtyMinutes:
            return "30 min"
        case .oneHour:
            return "1 hour"
        case .twoHours:
            return "2 hours"
        case .untilTurnedOff:
            return "Until off"
        }
    }

    var menuTitle: String {
        switch self {
        case .fifteenMinutes:
            return String(localized: "15 Minutes")
        case .thirtyMinutes:
            return String(localized: "30 Minutes")
        case .oneHour:
            return String(localized: "1 Hour")
        case .twoHours:
            return String(localized: "2 Hours")
        case .untilTurnedOff:
            return String(localized: "Never")
        }
    }

    var interval: TimeInterval? {
        switch self {
        case .fifteenMinutes:
            return 15 * 60
        case .thirtyMinutes:
            return 30 * 60
        case .oneHour:
            return 60 * 60
        case .twoHours:
            return 2 * 60 * 60
        case .untilTurnedOff:
            return nil
        }
    }
}
