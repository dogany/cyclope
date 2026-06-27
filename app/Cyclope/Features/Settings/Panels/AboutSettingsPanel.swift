//
//  AboutSettingsPanel.swift
//  Cyclope
//

import AppKit
import SwiftUI

struct AboutSettingsPanel: View {
    @EnvironmentObject private var updateService: UpdateService

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
            Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ??
            "Cyclope"
    }

    private var versionText: String {
        String(format: String(localized: "Version %@"), updateService.currentVersionTitle)
    }

    var body: some View {
        SettingsPanel {
            VStack(spacing: 14) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 112, height: 112)
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text(verbatim: appName)
                        .font(.system(size: 24, weight: .bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text(versionText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 3) {
                    Text(verbatim: "Copyright © 2026 Dogany.")
                    Text(verbatim: "All rights reserved.")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 48)
            .padding(.bottom, 36)
        }
    }
}

#Preview {
    AboutSettingsPanel()
        .environmentObject(UpdateService())
}
