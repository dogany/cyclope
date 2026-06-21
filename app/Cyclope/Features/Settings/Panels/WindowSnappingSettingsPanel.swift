//
//  WindowSnappingSettingsPanel.swift
//  Cyclope
//

import SwiftUI

struct WindowSnappingSettingsPanel: View {
    @EnvironmentObject private var controller: CyclopeController

    var body: some View {
        SettingsPanel {
            WindowSnappingBehaviorSection(store: controller.snapSettings)
        }
    }
}

// MARK: - Behavior

private struct WindowSnappingBehaviorSection: View {
    @ObservedObject var store: SnapSettingsStore

    var body: some View {
        SettingsSection(String(localized: "Menu Layout")) {
            SettingsRow(
                String(localized: "Built-In Commands"),
                systemImage: "rectangle.split.2x1"
            ) {
                Picker("Default Snap", selection: $store.defaultSnapPresentation) {
                    ForEach(SnapMenuPresentation.allCases) { presentation in
                        Text(presentation.title).tag(presentation)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
            }

            SettingsDivider()

            SettingsRow(
                String(localized: "Custom Commands"),
                systemImage: "square.grid.3x3"
            ) {
                Picker("Custom Snap", selection: $store.customSnapPresentation) {
                    ForEach(SnapMenuPresentation.allCases) { presentation in
                        Text(presentation.title).tag(presentation)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
            }
        }
    }
}

#Preview {
    WindowSnappingSettingsPanel()
        .environmentObject(CyclopeController())
}
