//
//  CyclopeMenuView.swift
//  Cyclope
//

import SwiftUI

struct CyclopeMenuView: View {
    @EnvironmentObject private var controller: CyclopeController

    var body: some View {
        ForEach(controller.shortcutSettings.displayedMenuCategories) { category in
            menuSection(for: category)
        }

        ApplicationMenuSection()
    }

    @ViewBuilder
    private func menuSection(for category: AppMenuCategory) -> some View {
        switch category {
        case .window:
            WindowSnappingMenuSection()
        case .sleep:
            SleepPreventionMenuSection()
        case .scrolling:
            ScrollDirectionMenuSection()
        }
    }
}
