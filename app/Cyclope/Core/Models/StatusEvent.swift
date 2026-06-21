//
//  StatusEvent.swift
//  Cyclope
//

import Foundation

struct StatusEvent: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let date: Date
}
