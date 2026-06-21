//
//  SnapPreferences.swift
//  Cyclope
//

import Foundation

enum SnapMenuPresentation: String, CaseIterable, Codable, Identifiable {
    case collapsed
    case expanded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .collapsed:
            return String(localized: "Collapsed")
        case .expanded:
            return String(localized: "Expanded")
        }
    }
}
