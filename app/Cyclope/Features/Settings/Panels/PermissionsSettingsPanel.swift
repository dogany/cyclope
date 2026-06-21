//
//  PermissionsSettingsPanel.swift
//  Cyclope
//

import SwiftUI

struct PermissionsSettingsPanel: View {
    @EnvironmentObject private var controller: CyclopeController
    @EnvironmentObject private var permissionCoordinator: PermissionCoordinator

    var body: some View {
        SettingsPanel {
            SettingsSection(String(localized: "Required Permissions")) {
                PermissionStatusRow(
                    title: String(localized: "Accessibility"),
                    detail: String(localized: "Window control and global shortcuts."),
                    status: permissionCoordinator.accessibilityStatusText,
                    isGranted: permissionCoordinator.isGranted(.accessibility),
                    openSettings: {
                        controller.openPermissionSettings(.accessibility)
                    }
                )

                PermissionStatusRow(
                    title: String(localized: "Input Monitoring"),
                    detail: String(localized: "Wheel mouse scroll reversal."),
                    status: permissionCoordinator.inputMonitoringStatusText,
                    isGranted: permissionCoordinator.isInputMonitoringTrusted,
                    openSettings: {
                        controller.openPermissionSettings(.inputMonitoring)
                    }
                )
            }

            SettingsSection(String(localized: "Recommended")) {
                SettingsRow(
                    String(localized: "macOS Edge Tiling"),
                    detail: String(localized: "Competes with Cyclope's edge snapping; turn it off in Desktop & Dock.")
                ) {
                    Button {
                        controller.openWindowTilingSettings()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Open Desktop & Dock in System Settings")
                    .accessibilityLabel("Open Desktop & Dock in System Settings")
                }
            }
        }
    }
}

#Preview {
    let controller = CyclopeController()

    PermissionsSettingsPanel()
        .environmentObject(controller)
        .environmentObject(controller.permissionCoordinator)
}
