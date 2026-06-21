//
//  SleepPreventionSettingsPanel.swift
//  Cyclope
//

import SwiftUI

struct SleepPreventionSettingsPanel: View {
    @EnvironmentObject private var controller: CyclopeController

    var body: some View {
        SettingsPanel {
            SettingsSection(String(localized: "Session Defaults")) {
                SleepNumericSettingRow(
                    title: String(localized: "Default Duration"),
                    inactiveTitle: String(localized: "Never"),
                    value: Binding(
                        get: { controller.sleepPreventer.defaultDurationMinutes },
                        set: { controller.setSleepPreventionDefaultDurationMinutes($0) }
                    ),
                    range: SleepPreventionCustomDuration.validMinuteRange,
                    fallbackValue: SleepSettingsDefaults.defaultDurationMinutes,
                    unit: String(localized: "minutes"),
                    accessibilityLabel: String(localized: "Default duration")
                )
            }

            SettingsSection(String(localized: "Battery Rules")) {
                SettingsRow(String(localized: "Disable on Battery")) {
                    Toggle("Disable on battery power", isOn: Binding(
                        get: { controller.sleepPreventer.disableOnBatteryPower },
                        set: { controller.setSleepDisableOnBatteryPower($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("Disable Sleep Prevention while running on battery power")
                    .accessibilityLabel("Disable on battery power")
                }

                SettingsDivider()

                SleepNumericSettingRow(
                    title: String(localized: "Battery Threshold"),
                    inactiveTitle: String(localized: "Always"),
                    value: Binding(
                        get: { controller.sleepPreventer.batteryDisableThresholdPercent },
                        set: { controller.setSleepBatteryDisableThresholdPercent($0) }
                    ),
                    range: SleepSettingsDefaults.batteryThresholdRange,
                    fallbackValue: SleepSettingsDefaults.batteryDisableThresholdPercent,
                    unit: "%",
                    accessibilityLabel: String(localized: "Battery threshold"),
                    isDisabled: !controller.sleepPreventer.disableOnBatteryPower
                )
            }

            SettingsSection(String(localized: "Global Shortcut")) {
                SettingsRow(String(localized: "Toggle Sleep Prevention")) {
                    ShortcutKeyCaptureButton(
                        keySymbols: controller.shortcutSettings.directKeySymbols(for: .toggleSleepPrevention),
                        hasShortcut: controller.shortcutSettings.hasDirectShortcut(for: .toggleSleepPrevention)
                    ) { key in
                        guard confirmGlobalShortcutOverwriteIfNeeded(
                            key,
                            target: .commandGlobal(.toggleSleepPrevention),
                            controller: controller
                        ) else {
                            return
                        }

                        controller.shortcutSettings.setDirectKey(key, for: .toggleSleepPrevention)
                    } onClear: {
                        controller.shortcutSettings.clearDirectKey(for: .toggleSleepPrevention)
                    }
                }
            }
        }
    }
}

private struct SleepNumericSettingRow: View {
    let title: String
    var detail: String?
    let inactiveTitle: String
    @Binding var value: Int?
    let range: ClosedRange<Int>
    let fallbackValue: Int
    let unit: String
    let accessibilityLabel: String
    var isDisabled = false

    private var numericValue: Binding<Int> {
        Binding {
            value ?? fallbackValue
        } set: { newValue in
            guard value != nil else { return }
            value = clamped(newValue)
        }
    }

    private var hasInput: Bool {
        value != nil
    }

    private var hasInputBinding: Binding<Bool> {
        Binding {
            value != nil
        } set: { shouldShowInput in
            if shouldShowInput {
                if value == nil {
                    value = clamped(fallbackValue)
                }
            } else {
                value = nil
            }
        }
    }

    private var displayTitle: String {
        hasInput ? title : "\(title): \(inactiveTitle)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isDisabled ? .secondary : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Spacer(minLength: 16)

                Toggle(accessibilityLabel, isOn: hasInputBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .disabled(isDisabled)
                    .accessibilityLabel(accessibilityLabel)
                    .accessibilityValue(hasInput ? String(localized: "Custom value") : inactiveTitle)
            }

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if hasInput {
                HStack(spacing: 6) {
                    Spacer(minLength: 0)

                    TextField(accessibilityLabel, value: numericValue, format: .number)
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 72)
                        .disabled(isDisabled)
                        .accessibilityLabel(accessibilityLabel)

                    Text(unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isDisabled ? .secondary : .primary)
                        .frame(width: unitWidth, alignment: .leading)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.16), value: hasInput)
    }

    private var unitWidth: CGFloat {
        unit == "%" ? 18 : 56
    }

    private func clamped(_ value: Int) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

#Preview {
    SleepPreventionSettingsPanel()
        .environmentObject(CyclopeController())
}
