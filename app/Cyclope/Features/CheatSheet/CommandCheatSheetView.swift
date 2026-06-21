//
//  CommandCheatSheetView.swift
//  Cyclope
//

import AppKit
import SwiftUI

enum CommandCheatSheetLayout {
    static let cardWidth: CGFloat = 580
    static let cardCornerRadius: CGFloat = 18
    static let contentMaxHeight: CGFloat = 408
    static let contentPadding: CGFloat = 18
    static let footerHeight: CGFloat = 44
    static let columnWidth: CGFloat = 248
    static let rowHeight: CGFloat = 46
    static let rowSpacing: CGFloat = 6
    static let columnSpacing: CGFloat = 8
    static let scrollerVerticalInset: CGFloat = 12
    static let shadowPadding: CGFloat = 40

    static var gridWidth: CGFloat {
        columnWidth * 2 + columnSpacing
    }

    static var cardFallbackHeight: CGFloat {
        contentMaxHeight + contentPadding * 2 + footerHeight
    }

    static var fallbackWindowSize: CGSize {
        CGSize(
            width: cardWidth + shadowPadding * 2,
            height: cardFallbackHeight + shadowPadding * 2
        )
    }
}

struct CommandCheatSheetView: View {
    @EnvironmentObject private var controller: CyclopeController
    @EnvironmentObject private var shortcutSettings: ShortcutSettingsStore
    @EnvironmentObject private var snapSettings: SnapSettingsStore

    let onCommand: (CheatSheetCommand) -> Void
    let onDismiss: () -> Void

    private let containerShape = RoundedRectangle(
        cornerRadius: CommandCheatSheetLayout.cardCornerRadius,
        style: .continuous
    )

    private let columns = [
        GridItem(.fixed(CommandCheatSheetLayout.columnWidth), spacing: CommandCheatSheetLayout.columnSpacing),
        GridItem(.fixed(CommandCheatSheetLayout.columnWidth), spacing: CommandCheatSheetLayout.columnSpacing),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                LazyVGrid(
                    columns: columns,
                    alignment: .leading,
                    spacing: CommandCheatSheetLayout.rowSpacing
                ) {
                    ForEach(CheatSheetCommand.commands(
                        using: shortcutSettings,
                        customPresets: snapSettings.presets
                    )) { command in
                        CommandCheatSheetButton(
                            command: command,
                            isDisabled: isDisabled(command),
                            action: { onCommand(command) }
                        )
                    }
                }
                .frame(width: CommandCheatSheetLayout.gridWidth)
                .padding(CommandCheatSheetLayout.contentPadding)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(CommandCheatSheetScrollViewConfigurator())
            }
            .scrollIndicators(.automatic)
            .frame(width: CommandCheatSheetLayout.cardWidth)
            .frame(maxHeight: CommandCheatSheetLayout.contentMaxHeight + CommandCheatSheetLayout.contentPadding * 2)

            Divider()
                .opacity(0.55)

            HStack(spacing: 8) {
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(String(localized: "Arrow keys move slightly. Command + Arrow snaps."))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(height: CommandCheatSheetLayout.footerHeight)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, CommandCheatSheetLayout.contentPadding)
        }
        .frame(width: CommandCheatSheetLayout.cardWidth)
        .frame(maxHeight: CommandCheatSheetLayout.cardFallbackHeight)
        .background(.regularMaterial, in: containerShape)
        .clipShape(containerShape)
        .overlay(
            containerShape
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 24, y: 12)
        .padding(CommandCheatSheetLayout.shadowPadding)
        .fixedSize()
    }

    private func isDisabled(_ command: CheatSheetCommand) -> Bool {
        command == .repeatLastSnap && controller.lastSnapAction == nil
    }
}

private struct CommandCheatSheetButton: View {
    @EnvironmentObject private var shortcutSettings: ShortcutSettingsStore

    let command: CheatSheetCommand
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(command.keySymbols(using: shortcutSettings))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: 86, height: 26)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
                    )

                CommandCheatSheetIcon(command: command)

                Text(command.title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .frame(width: CommandCheatSheetLayout.columnWidth, alignment: .leading)
            .frame(minHeight: CommandCheatSheetLayout.rowHeight)
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
    }
}

private struct CommandCheatSheetIcon: View {
    @EnvironmentObject private var snapSettings: SnapSettingsStore

    let command: CheatSheetCommand

    var body: some View {
        iconContent
            .frame(width: 24, height: 18)
            .frame(width: 36, height: 36)
    }

    @ViewBuilder
    private var iconContent: some View {
        switch command {
        case .customSnap(let presetID, _, _):
            if let preset = snapSettings.preset(withID: presetID) {
                SnapPresetIcon(preset: preset)
            } else {
                fallbackIcon
            }
        default:
            if let shortcutCommand = command.shortcutCommand {
                ShortcutCommandIcon(command: shortcutCommand)
            } else {
                fallbackIcon
            }
        }
    }

    private var fallbackIcon: some View {
        Image(systemName: command.systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.accentColor)
    }
}

private struct CommandCheatSheetScrollViewConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let scrollView = nsView.enclosingScrollView else { return }
            scrollView.hasVerticalScroller = true
            scrollView.autohidesScrollers = true
            scrollView.scrollerStyle = .overlay
            scrollView.scrollerInsets = NSEdgeInsets(
                top: CommandCheatSheetLayout.scrollerVerticalInset,
                left: 0,
                bottom: CommandCheatSheetLayout.scrollerVerticalInset,
                right: 0
            )
        }
    }
}

#Preview {
    let controller = CyclopeController()

    CommandCheatSheetView(
        onCommand: { _ in },
        onDismiss: {}
    )
    .environmentObject(controller)
    .environmentObject(controller.shortcutSettings)
    .environmentObject(controller.snapSettings)
    .padding()
}
