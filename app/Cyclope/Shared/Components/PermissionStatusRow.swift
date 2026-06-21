//
//  PermissionStatusRow.swift
//  Cyclope
//

import SwiftUI

struct PermissionStatusRow: View {
    let title: String
    let detail: String
    let status: String
    let isGranted: Bool
    let openSettings: () -> Void

    var body: some View {
        SettingsRow(title, detail: detail) {
            HStack(spacing: 10) {
                PermissionStatusBadge(isGranted: isGranted)
                    .help(status)
                    .accessibilityLabel("Permission status")
                    .accessibilityValue(status)

                // A real Button (not a tap gesture on a non-interactive switch)
                // so opening System Settings works reliably from inside the
                // scrolling settings list.
                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Open permission settings in System Settings")
                .accessibilityLabel("Open permission settings in System Settings")
            }
        }
    }
}

private struct PermissionStatusBadge: View {
    let isGranted: Bool

    var body: some View {
        Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isGranted ? Color.green : Color.orange)
    }
}
