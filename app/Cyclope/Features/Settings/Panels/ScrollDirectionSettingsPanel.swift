//
//  ScrollDirectionSettingsPanel.swift
//  Cyclope
//

import SwiftUI

struct ScrollDirectionSettingsPanel: View {
    @EnvironmentObject private var controller: CyclopeController

    var body: some View {
        SettingsPanel {
            SettingsSection(
                String(localized: "Scroll Direction"),
                footer: String(localized: "Natural Scrolling follows the macOS setting for trackpads and Magic Mouse. Reverse Mouse Scrolling is handled by Cyclope and affects physical mouse wheel events only.")
            ) {
                SettingsRow(
                    String(localized: "Natural Scrolling"),
                    detail: String(localized: "Uses macOS Natural Scrolling for trackpads and Magic Mouse")
                ) {
                    Toggle("Natural Scrolling", isOn: Binding(
                        get: { controller.scrollDirectionController.isNaturalScrollingEnabled },
                        set: { controller.setNaturalScrollingEnabled($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("Uses macOS Natural Scrolling for trackpads and Magic Mouse")
                    .accessibilityLabel("Natural Scrolling")
                }

                SettingsDivider()

                SettingsRow(
                    String(localized: "Reverse Mouse Scrolling"),
                    detail: String(localized: "Reverse a physical mouse wheel without changing Natural Scrolling")
                ) {
                    Toggle("Reverse Mouse Scrolling", isOn: Binding(
                        get: { controller.scrollDirectionController.isWheelMouseReverseScrollingEnabled },
                        set: { controller.setWheelMouseReverseScrollingEnabled($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("Reverse physical wheel mouse scrolling only")
                    .accessibilityLabel("Reverse Mouse Scrolling")
                }
            }

            SettingsSection(String(localized: "Global Shortcut")) {
                globalShortcutRow(for: .toggleNaturalScrolling)
                SettingsDivider()
                globalShortcutRow(for: .toggleWheelMouseReverseScrolling)
            }
        }
        .onAppear {
            controller.scrollDirectionController.refresh()
        }
    }

    private func globalShortcutRow(for command: ShortcutCommand) -> some View {
        SettingsRow(command.title) {
            ShortcutKeyCaptureButton(
                keySymbols: controller.shortcutSettings.directKeySymbols(for: command),
                hasShortcut: controller.shortcutSettings.hasDirectShortcut(for: command)
            ) { key in
                guard confirmGlobalShortcutOverwriteIfNeeded(
                    key,
                    target: .commandGlobal(command),
                    controller: controller
                ) else {
                    return
                }

                controller.shortcutSettings.setDirectKey(key, for: command)
            } onClear: {
                controller.shortcutSettings.clearDirectKey(for: command)
            }
        }
    }
}

#Preview {
    ScrollDirectionSettingsPanel()
        .environmentObject(CyclopeController())
}
