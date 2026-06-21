//
//  SnapAction.swift
//  Cyclope
//

import Foundation

enum SnapAction: String, CaseIterable, Identifiable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case fullScreen
    case center

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leftHalf:
            return "Left Half"
        case .rightHalf:
            return "Right Half"
        case .topHalf:
            return "Top Half"
        case .bottomHalf:
            return "Bottom Half"
        case .fullScreen:
            return "Full Screen"
        case .center:
            return "Center"
        }
    }

    var systemImage: String {
        switch self {
        case .leftHalf:
            return "rectangle.leftthird.inset.filled"
        case .rightHalf:
            return "rectangle.rightthird.inset.filled"
        case .topHalf:
            return "rectangle.topthird.inset.filled"
        case .bottomHalf:
            return "rectangle.bottomthird.inset.filled"
        case .fullScreen:
            return "arrow.up.left.and.arrow.down.right"
        case .center:
            return "dot.scope"
        }
    }

    var shortcutKeys: String {
        switch self {
        case .leftHalf:
            return "^ + Option + Command + Left"
        case .rightHalf:
            return "^ + Option + Command + Right"
        case .topHalf:
            return "^ + Option + Command + Up"
        case .bottomHalf:
            return "^ + Option + Command + Down"
        case .fullScreen:
            return "^ + Option + Command + Return"
        case .center:
            return "^ + Option + Command + C"
        }
    }
}
