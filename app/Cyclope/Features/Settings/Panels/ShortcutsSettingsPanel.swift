//
//  ShortcutsSettingsPanel.swift
//  Cyclope
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum CommandSelection: Hashable {
    case general
    case shortcut(ShortcutCommand)
    case customSnap(CustomSnapPreset.ID)

    func title(using store: SnapSettingsStore) -> String {
        switch self {
        case .general:
            return String(localized: "Window Settings")
        case .shortcut(let command):
            return command.title
        case .customSnap(let presetID):
            return store.preset(withID: presetID)?.name ?? String(localized: "Custom Snap")
        }
    }
}

struct ShortcutCommandSidebar: View {
    @EnvironmentObject private var controller: CyclopeController
    @Binding var selection: CommandSelection
    @State private var isHorizontalExpanded = true
    @State private var draggingCustomPresetID: CustomSnapPreset.ID?
    @State private var customPresetDropInsertionIndex: Int?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Window Commands")
                    .font(.system(size: 12, weight: .semibold))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(height: 38)

            List {
                GeneralCommandSidebarRow(
                    isSelected: selection == .general
                ) {
                    selection = .general
                }
                .listRowInsets(sidebarRowInsets)
                .listRowBackground(Color.clear)
                .deleteDisabled(true)

                SidebarTopLevelRow(
                    title: String(localized: "Snap Commands"),
                    systemImage: isHorizontalExpanded ? "chevron.down" : "chevron.right",
                    isSelected: false,
                    trailingText: "\(horizontalCommandCount)"
                ) {
                    isHorizontalExpanded.toggle()
                }
                .listRowInsets(sidebarRowInsets)
                .listRowBackground(Color.clear)
                .deleteDisabled(true)

                if isHorizontalExpanded {
                    ForEach(ShortcutCommand.defaultCommands) { command in
                        ShortcutCommandSidebarRow(
                            command: command,
                            isSelected: selection == .shortcut(command)
                        ) {
                            selection = .shortcut(command)
                        }
                        .padding(.leading, SidebarCommandRowMetrics.childIndent)
                        .listRowInsets(sidebarRowInsets)
                        .listRowBackground(Color.clear)
                        .deleteDisabled(true)
                    }

                    SidebarCommandGroupDivider()
                        .padding(.leading, SidebarCommandRowMetrics.childIndent)
                        .listRowInsets(SidebarCommandRowMetrics.dividerInsets)
                        .listRowBackground(Color.clear)
                        .deleteDisabled(true)

                    if !controller.snapSettings.presets.isEmpty {
                        ForEach(Array(controller.snapSettings.presets.enumerated()), id: \.element.id) { index, preset in
                            CustomSnapCommandSidebarRow(
                                preset: preset,
                                isSelected: selection == .customSnap(preset.id)
                            ) {
                                controller.snapSettings.select(preset)
                                selection = .customSnap(preset.id)
                            } deleteAction: {
                                deleteCustomCommand(preset.id)
                            }
                            .padding(.leading, SidebarCommandRowMetrics.childIndent)
                            .overlay(alignment: .top) {
                                if customPresetDropInsertionIndex == index {
                                    CustomSnapCommandDropIndicator()
                                }
                            }
                            .overlay(alignment: .bottom) {
                                if customPresetDropInsertionIndex == controller.snapSettings.presets.count &&
                                    index == controller.snapSettings.presets.count - 1 {
                                    CustomSnapCommandDropIndicator()
                                }
                            }
                            .listRowInsets(sidebarRowInsets)
                            .listRowBackground(Color.clear)
                            .onDrag {
                                draggingCustomPresetID = preset.id
                                customPresetDropInsertionIndex = nil
                                return NSItemProvider(object: preset.id.uuidString as NSString)
                            } preview: {
                                CustomSnapCommandSidebarRow(
                                    preset: preset,
                                    isSelected: selection == .customSnap(preset.id),
                                    action: {},
                                    deleteAction: {}
                                )
                                .frame(width: SettingsVisualStyle.shortcutSidebarWidth - 54)
                            }
                            .onDrop(
                                of: [UTType.text],
                                delegate: CustomSnapCommandDropDelegate(
                                    targetIndex: index,
                                    rowHeight: SidebarCommandRowMetrics.height,
                                    draggingPresetID: $draggingCustomPresetID,
                                    dropInsertionIndex: $customPresetDropInsertionIndex,
                                    presetIDs: { controller.snapSettings.presets.map(\.id) },
                                    moveAction: moveCustomCommand
                                )
                            )
                        }
                        .onDelete(perform: deleteCustomCommands)
                    }

                    EmptyCustomSnapCommandSidebarRow {
                        addCustomCommand()
                    }
                    .padding(.leading, SidebarCommandRowMetrics.childIndent)
                    .listRowInsets(sidebarRowInsets)
                    .listRowBackground(Color.clear)
                    .deleteDisabled(true)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .frame(width: SettingsVisualStyle.shortcutSidebarWidth)
        .frame(maxHeight: .infinity)
        .background(Color.clear)
    }

    private var horizontalCommandCount: Int {
        ShortcutCommand.defaultCommands.count + controller.snapSettings.presets.count
    }

    private var sidebarRowInsets: EdgeInsets {
        SidebarCommandRowMetrics.rowInsets
    }

    private func addCustomCommand() {
        let preset = controller.snapSettings.addPreset()
        controller.shortcutSettings.enableCustomPaletteShortcut(for: preset.id)
        selection = .customSnap(preset.id)
    }

    private func deleteCustomCommands(at offsets: IndexSet) {
        let presets = controller.snapSettings.presets
        let presetIDs = offsets.compactMap { index in
            presets.indices.contains(index) ? presets[index].id : nil
        }

        guard !presetIDs.isEmpty else { return }

        for presetID in presetIDs {
            deleteCustomCommand(presetID, updateSelection: false)
        }

        selectAfterCustomDeletion()
    }

    private func deleteCustomCommand(_ presetID: CustomSnapPreset.ID, updateSelection: Bool = true) {
        guard controller.deleteSnapPreset(presetID), updateSelection else { return }
        selectAfterCustomDeletion()
    }

    private func moveCustomCommand(_ sourceID: CustomSnapPreset.ID, toInsertionIndex insertionIndex: Int) {
        controller.snapSettings.movePreset(sourceID, toInsertionIndex: insertionIndex)
    }

    private func selectAfterCustomDeletion() {
        if case .customSnap(let presetID) = selection,
           controller.snapSettings.preset(withID: presetID) != nil {
            return
        }

        if let selectedPresetID = controller.snapSettings.selectedPresetID,
           controller.snapSettings.preset(withID: selectedPresetID) != nil {
            selection = .customSnap(selectedPresetID)
        } else if let firstPreset = controller.snapSettings.presets.first {
            controller.snapSettings.select(firstPreset)
            selection = .customSnap(firstPreset.id)
        } else {
            selection = .shortcut(ShortcutCommand.defaultCommands.first ?? .snapLeft)
        }
    }
}

private enum SidebarCommandRowMetrics {
    static let contentHorizontalPadding: CGFloat = 16
    static let dividerHorizontalPadding: CGFloat = 16
    static let contentSpacing: CGFloat = 11
    static let childIndent: CGFloat = 14
    static let height: CGFloat = 52
    static let addCustomHeight: CGFloat = 44
    static let cornerRadius: CGFloat = 8

    static var rowInsets: EdgeInsets {
        EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
    }

    static var dividerInsets: EdgeInsets {
        EdgeInsets(top: 5, leading: dividerHorizontalPadding, bottom: 5, trailing: dividerHorizontalPadding)
    }

    static var rowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

private struct GeneralCommandSidebarRow: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        SidebarTopLevelRow(
            title: String(localized: "Window Settings"),
            systemImage: "gearshape",
            isSelected: isSelected,
            action: action
        )
    }
}

private struct SidebarTopLevelRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    var trailingText: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: SidebarCommandRowMetrics.contentSpacing) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 24, height: 18)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let trailingText {
                    Text(trailingText)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? .white.opacity(0.72) : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            isSelected ? Color.white.opacity(0.16) : Color.primary.opacity(0.08),
                            in: Capsule()
                        )
                }
            }
            .foregroundStyle(isSelected ? .white : .primary.opacity(0.88))
            .padding(.horizontal, SidebarCommandRowMetrics.contentHorizontalPadding)
            .frame(
                maxWidth: .infinity,
                minHeight: SidebarCommandRowMetrics.height,
                maxHeight: SidebarCommandRowMetrics.height,
                alignment: .leading
            )
            .background {
                if isSelected {
                    SidebarCommandRowMetrics.rowShape
                        .fill(Color.accentColor)
                }
            }
            .clipShape(SidebarCommandRowMetrics.rowShape)
            .contentShape(SidebarCommandRowMetrics.rowShape)
        }
        .buttonStyle(.plain)
    }
}

private struct ShortcutCommandSidebarRow: View {
    @EnvironmentObject private var controller: CyclopeController

    let command: ShortcutCommand
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        SidebarCommandRowButton(
            isSelected: isSelected,
            paletteSymbols: paletteShortcutSymbols,
            directSymbols: directShortcutSymbols,
            action: action
        ) {
            ShortcutCommandIcon(command: command, isSelected: isSelected)
                .frame(width: 24, height: 18)
        } title: {
            Text(command.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
        }
    }

    private var paletteShortcutSymbols: String {
        controller.shortcutSettings.paletteKeySymbols(for: command)
    }

    private var directShortcutSymbols: String {
        controller.shortcutSettings.directKeySymbols(for: command)
    }
}

private struct CustomSnapCommandSidebarRow: View {
    @EnvironmentObject private var controller: CyclopeController
    let preset: CustomSnapPreset
    let isSelected: Bool
    let action: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        SidebarCommandRowButton(
            isSelected: isSelected,
            paletteSymbols: paletteShortcutSymbols,
            directSymbols: directShortcutSymbols,
            action: action
        ) {
            SnapPresetIcon(preset: preset, isSelected: isSelected)
                .frame(width: 24, height: 18)
        } title: {
            CustomPresetSidebarNameEditor(
                preset: preset,
                isSelected: isSelected
            )
        }
        .sidebarRightClickDeleteMenu(
            onOpen: action,
            onDelete: deleteAction
        )
    }

    private var paletteShortcutSymbols: String {
        guard controller.shortcutSettings.isCustomPaletteEnabled(preset.id) else {
            return String(localized: "None")
        }

        return resolvedPaletteKey?.paletteSymbols ?? String(localized: "None")
    }

    private var directShortcutSymbols: String {
        controller.shortcutSettings.customDirectKey(for: preset.id)?.directSymbols ?? String(localized: "None")
    }

    private var resolvedPaletteKey: CustomShortcutKey? {
        controller.shortcutSettings.customPaletteKey(for: preset.id) ??
            defaultPaletteKey
    }

    private var defaultPaletteKey: CustomShortcutKey? {
        guard let index = controller.snapSettings.presets.firstIndex(where: { $0.id == preset.id }) else {
            return nil
        }

        return GlobalShortcut.defaultCustomShortcutKey(forIndex: index)
    }
}

private struct CustomSnapCommandDropIndicator: View {
    var body: some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }
}

private struct CustomSnapCommandDropDelegate: DropDelegate {
    let targetIndex: Int
    let rowHeight: CGFloat
    @Binding var draggingPresetID: CustomSnapPreset.ID?
    @Binding var dropInsertionIndex: Int?
    let presetIDs: () -> [CustomSnapPreset.ID]
    let moveAction: (CustomSnapPreset.ID, Int) -> Void

    func dropEntered(info: DropInfo) {
        updateDropInsertionIndex(using: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateDropInsertionIndex(using: info)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        guard dropInsertionIndex == insertionIndex(for: info) else { return }
        dropInsertionIndex = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggingPresetID else {
            dropInsertionIndex = nil
            return false
        }

        let insertionIndex = dropInsertionIndex ?? insertionIndex(for: info)
        self.draggingPresetID = nil
        dropInsertionIndex = nil

        guard let insertionIndex else { return false }
        moveAction(draggingPresetID, insertionIndex)
        return true
    }

    private func updateDropInsertionIndex(using info: DropInfo) {
        dropInsertionIndex = insertionIndex(for: info)
    }

    private func insertionIndex(for info: DropInfo) -> Int? {
        guard let draggingPresetID,
              let sourceIndex = presetIDs().firstIndex(of: draggingPresetID) else {
            return nil
        }

        let destination = targetIndex + (info.location.y > rowHeight / 2 ? 1 : 0)
        guard destination != sourceIndex,
              destination != sourceIndex + 1 else {
            return nil
        }

        return destination
    }
}

private struct SidebarCommandRowButton<Icon: View, Title: View>: View {
    let isSelected: Bool
    let paletteSymbols: String
    let directSymbols: String
    let action: () -> Void
    let icon: Icon
    let title: Title

    init(
        isSelected: Bool,
        paletteSymbols: String,
        directSymbols: String,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder title: () -> Title
    ) {
        self.isSelected = isSelected
        self.paletteSymbols = paletteSymbols
        self.directSymbols = directSymbols
        self.action = action
        self.icon = icon()
        self.title = title()
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: SidebarCommandRowMetrics.contentSpacing) {
                icon

                VStack(alignment: .leading, spacing: 4) {
                    title

                    ShortcutSidebarSummary(
                        paletteSymbols: paletteSymbols,
                        directSymbols: directSymbols,
                        isSelected: isSelected
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? .white : .primary.opacity(0.88))
            .padding(.horizontal, SidebarCommandRowMetrics.contentHorizontalPadding)
            .frame(
                maxWidth: .infinity,
                minHeight: SidebarCommandRowMetrics.height,
                maxHeight: SidebarCommandRowMetrics.height,
                alignment: .leading
            )
            .background {
                if isSelected {
                    SidebarCommandRowMetrics.rowShape
                        .fill(Color.accentColor)
                }
            }
            .clipShape(SidebarCommandRowMetrics.rowShape)
            .contentShape(
                SidebarCommandRowMetrics.rowShape
            )
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    func sidebarRightClickDeleteMenu(
        onOpen: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        overlay {
            SidebarRightClickDeleteMenu(
                onOpen: onOpen,
                onDelete: onDelete
            )
        }
    }
}

private struct SidebarRightClickDeleteMenu: NSViewRepresentable {
    let onOpen: () -> Void
    let onDelete: () -> Void

    func makeNSView(context: Context) -> SidebarRightClickDeleteMenuView {
        let view = SidebarRightClickDeleteMenuView()
        view.onOpen = onOpen
        view.onDelete = onDelete
        return view
    }

    func updateNSView(_ nsView: SidebarRightClickDeleteMenuView, context: Context) {
        nsView.onOpen = onOpen
        nsView.onDelete = onDelete
    }
}

private final class SidebarRightClickDeleteMenuView: NSView {
    var onOpen: (() -> Void)?
    var onDelete: (() -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point),
              let event = window?.currentEvent ?? NSApp.currentEvent,
              event.type == .rightMouseDown else {
            return nil
        }

        return self
    }

    override func rightMouseDown(with event: NSEvent) {
        onOpen?()

        let menu = NSMenu()
        let deleteItem = NSMenuItem(
            title: String(localized: "Delete"),
            action: #selector(deleteMenuItem(_:)),
            keyEquivalent: ""
        )
        deleteItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        deleteItem.target = self
        menu.addItem(deleteItem)

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func deleteMenuItem(_ sender: NSMenuItem) {
        onDelete?()
    }
}

private struct SidebarCommandGroupDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.13))
            .frame(maxWidth: .infinity)
            .frame(height: 1)
    }
}

private struct EmptyCustomSnapCommandSidebarRow: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: SidebarCommandRowMetrics.contentSpacing) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 24, height: 18)

                Text("Add Custom Command")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundStyle(isHovered ? Color.accentColor : Color.primary.opacity(0.82))
            .padding(.horizontal, SidebarCommandRowMetrics.contentHorizontalPadding)
            .frame(
                maxWidth: .infinity,
                minHeight: SidebarCommandRowMetrics.addCustomHeight,
                maxHeight: SidebarCommandRowMetrics.addCustomHeight,
                alignment: .leading
            )
            .background {
                SidebarCommandRowMetrics.rowShape
                    .fill(isHovered ? Color.accentColor.opacity(0.08) : Color.clear)
            }
            .overlay {
                SidebarCommandRowMetrics.rowShape
                    .stroke(isHovered ? Color.accentColor.opacity(0.62) : Color.primary.opacity(0.14), lineWidth: 1)
            }
            .clipShape(SidebarCommandRowMetrics.rowShape)
            .contentShape(SidebarCommandRowMetrics.rowShape)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

private struct ShortcutSidebarSummary: View {
    let paletteSymbols: String
    let directSymbols: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 4) {
            shortcutBadge(title: String(localized: "Modal"), value: paletteSymbols)
            shortcutBadge(title: String(localized: "Global"), value: directSymbols)
        }
    }

    private func shortcutBadge(title: String, value: String) -> some View {
        HStack(spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isSelected ? .white.opacity(0.70) : .secondary)

            Text(value)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected ? Color.white.opacity(0.16) : Color.primary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 4, style: .continuous)
        )
    }
}

struct CommandDetailPanel: View {
    @EnvironmentObject private var controller: CyclopeController
    @Binding var selection: CommandSelection

    var body: some View {
        switch selection {
        case .general:
            WindowManagerGeneralPanel()
        case .shortcut(let command):
            ShortcutCommandDetailPanel(command: command)
        case .customSnap(let presetID):
            if controller.snapSettings.preset(withID: presetID) != nil {
                CustomSnapCommandDetailPanel(presetID: presetID) {
                    deleteCustomSnapCommand(presetID)
                }
            } else {
                MissingCustomSnapCommandPanel {
                    let preset = controller.snapSettings.addPreset()
                    controller.shortcutSettings.enableCustomPaletteShortcut(for: preset.id)
                    selection = .customSnap(preset.id)
                }
            }
        }
    }

    private func deleteCustomSnapCommand(_ presetID: CustomSnapPreset.ID) {
        guard controller.confirmDeleteSnapPreset(presetID) else { return }

        if let selectedPresetID = controller.snapSettings.selectedPresetID {
            selection = .customSnap(selectedPresetID)
        } else {
            selection = .shortcut(ShortcutCommand.defaultCommands.first ?? .snapLeft)
        }
    }
}

private struct WindowManagerGeneralPanel: View {
    @EnvironmentObject private var controller: CyclopeController

    var body: some View {
        CommandDetailScrollView {
            CommandDetailSection(String(localized: "Command Modal")) {
                ModalShortcutCard(
                    isEnabled: controller.shortcutSettings.bindingForModalShortcutEnabled(),
                    keySymbols: controller.shortcutSettings.modalShortcutKey.paletteSymbols,
                    onShortcutCaptured: { key in
                        guard !targetAlreadyUsesGlobalShortcut(
                            key,
                            target: .modalShortcut,
                            controller: controller
                        ) else {
                            controller.shortcutSettings.setModalShortcutKey(key)
                            return
                        }

                        if let conflict = controller.shortcutSettings.globalShortcutConflict(
                            for: key,
                            excluding: .modalShortcut,
                            customPresets: controller.snapSettings.presets
                        ) {
                            showDuplicateModalShortcutAlert(key, existingAssignment: conflict, controller: controller)
                            return
                        }

                        guard confirmSystemGlobalShortcutAvailable(key) else { return }
                        controller.shortcutSettings.setModalShortcutKey(key)
                    },
                    onShortcutCleared: {
                        controller.shortcutSettings.resetModalShortcutKey()
                    }
                )
            }

            CommandDetailSection(String(localized: "Snap Preview")) {
                SnapActivationDelayCard(
                    delayMilliseconds: controller.snapSettings.bindingForSnapActivationDwellDelayMilliseconds(),
                    range: SnapSettingsStore.snapActivationDwellDelayMillisecondsRange
                )
            }
        }
    }
}

private struct CommandDetailScrollView<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content
                }
                .frame(maxWidth: 560, alignment: .leading)
                .padding(.horizontal, 36)
                .padding(.top, 24)
                .padding(.bottom, 34)
                .frame(minWidth: geometry.size.width, alignment: .center)
            }
            .scrollIndicators(.visible)
            .background(Color.clear)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

private struct CommandDetailSection<Content: View>: View {
    private let title: String?
    private let headerAccessory: AnyView?
    private let customHeader: AnyView?
    private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        headerAccessory = nil
        customHeader = nil
        self.content = content()
    }

    init<HeaderAccessory: View>(
        _ title: String,
        @ViewBuilder headerAccessory: () -> HeaderAccessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.headerAccessory = AnyView(headerAccessory())
        customHeader = nil
        self.content = content()
    }

    init<Header: View>(
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        title = nil
        headerAccessory = nil
        customHeader = AnyView(header())
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            header

            content
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.primary.opacity(0.11), lineWidth: 1)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var header: some View {
        if let customHeader {
            customHeader
        } else if let title {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                Spacer(minLength: 0)

                headerAccessory
            }
        }
    }
}

private struct ModalShortcutCard: View {
    @Binding var isEnabled: Bool
    let keySymbols: String
    let onShortcutCaptured: (CustomShortcutKey) -> Void
    let onShortcutCleared: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text("Enabled")
                    .font(.system(size: 13, weight: .semibold))

                Spacer(minLength: 0)

                Toggle("Modal Shortcut", isOn: $isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            Divider()

            CustomShortcutModeRow(
                title: String(localized: "Global Shortcut"),
                keySymbols: keySymbols,
                hasShortcut: true,
                onShortcutCaptured: onShortcutCaptured,
                onShortcutCleared: onShortcutCleared
            )
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
        }
    }
}

private struct SnapActivationDelayCard: View {
    @Binding var delayMilliseconds: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Edge Delay")
                    .font(.system(size: 13, weight: .medium))
            }

            Spacer(minLength: 12)

            HStack(spacing: 7) {
                TextField("Delay", value: $delayMilliseconds, format: .number)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .frame(width: 72)

                Text("ms")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Stepper("Edge Delay", value: $delayMilliseconds, in: range, step: 25)
                    .labelsHidden()
                    .controlSize(.small)
            }
        }
    }
}

struct ShortcutCommandDetailPanel: View {
    @EnvironmentObject private var controller: CyclopeController
    let command: ShortcutCommand

    var body: some View {
        CommandDetailScrollView {
            if command.usesPositionOnlyCenterPreview,
               let snapActivationPreference = controller.snapSettings.snapActivationPreference(for: command) {
                CenterPositionLayoutCard(
                    snapActivationLayouts: snapActivationPreference.layouts,
                    isSnapActivationEnabled: snapActivationPreference.isEnabled,
                    snapActivationOccupiedAreas: snapActivationOccupiedAreas(for: command),
                    addSnapActivationLayout: { layout in
                        controller.snapSettings.addSnapActivationLayout(layout, for: command)
                    },
                    removeSnapActivationLayout: { layout in
                        controller.snapSettings.removeSnapActivationLayout(layout, for: command)
                    },
                    setSnapActivationEnabled: { isEnabled in
                        controller.snapSettings.setSnapActivationEnabled(isEnabled, for: command)
                    }
                )
            } else if let layout = command.previewLayout,
               let snapActivationPreference = controller.snapSettings.snapActivationPreference(for: command) {
                CustomSnapLayoutEditorCard(
                    layout: layout,
                    snapActivationLayouts: snapActivationPreference.layouts,
                    isSnapActivationEnabled: snapActivationPreference.isEnabled,
                    snapActivationOccupiedAreas: snapActivationOccupiedAreas(for: command),
                    updateLayout: nil,
                    addSnapActivationLayout: { layout in
                        controller.snapSettings.addSnapActivationLayout(layout, for: command)
                    },
                    removeSnapActivationLayout: { layout in
                        controller.snapSettings.removeSnapActivationLayout(layout, for: command)
                    },
                    setSnapActivationEnabled: { isEnabled in
                        controller.snapSettings.setSnapActivationEnabled(isEnabled, for: command)
                    }
                )
            } else {
                ShortcutUtilityCard(command: command)
            }

            CommandDetailSection(String(localized: "Shortcut Keys")) {
                DefaultShortcutCommandCard(
                    paletteKeySymbols: controller.shortcutSettings.paletteKeySymbols(for: command),
                    directKeySymbols: controller.shortcutSettings.directKeySymbols(for: command),
                    hasPaletteShortcut: controller.shortcutSettings.hasPaletteShortcut(for: command),
                    hasDirectShortcut: controller.shortcutSettings.hasDirectShortcut(for: command),
                    onPaletteShortcutCaptured: { key in
                        if let conflict = controller.shortcutSettings.modalShortcutConflict(
                            for: key,
                            excluding: .commandModal(command),
                            customPresets: controller.snapSettings.presets
                        ) {
                            showDuplicateModalShortcutAlert(key, existingAssignment: conflict, controller: controller)
                            return
                        }

                        controller.shortcutSettings.setPaletteKey(key, for: command)
                    },
                    onPaletteShortcutCleared: {
                        controller.shortcutSettings.clearPaletteKey(for: command)
                    },
                    onDirectShortcutCaptured: { key in
                        guard confirmGlobalShortcutOverwriteIfNeeded(
                            key,
                            target: .commandGlobal(command),
                            controller: controller
                        ) else {
                            return
                        }

                        controller.shortcutSettings.setDirectKey(key, for: command)
                    },
                    onDirectShortcutCleared: {
                        controller.shortcutSettings.clearDirectKey(for: command)
                    }
                )
            }

            CommandDetailSection(String(localized: "Visibility")) {
                ShortcutDisplayCard(
                    hasMenuShortcut: true,
                    hasCheatSheetShortcut: true,
                    isShownInMenu: controller.shortcutSettings.bindingForMenuDisplay(command),
                    isShownInCheatSheet: controller.shortcutSettings.bindingForCheatSheetDisplay(command)
                )
            }
        }
    }

    private func snapActivationOccupiedAreas(for command: ShortcutCommand) -> [SnapActivationOccupiedArea] {
        defaultCommandSnapActivationOccupiedAreas(excluding: command.id, using: controller.snapSettings) +
            customSnapActivationOccupiedAreas(excluding: nil, using: controller.snapSettings)
    }
}

private struct DefaultShortcutCommandCard: View {
    let paletteKeySymbols: String
    let directKeySymbols: String
    let hasPaletteShortcut: Bool
    let hasDirectShortcut: Bool
    let onPaletteShortcutCaptured: (CustomShortcutKey) -> Void
    let onPaletteShortcutCleared: () -> Void
    let onDirectShortcutCaptured: (CustomShortcutKey) -> Void
    let onDirectShortcutCleared: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CustomShortcutModeRow(
                title: String(localized: "Modal Key"),
                keySymbols: paletteKeySymbols,
                hasShortcut: hasPaletteShortcut,
                onShortcutCaptured: onPaletteShortcutCaptured,
                onShortcutCleared: onPaletteShortcutCleared
            )

            Divider()

            CustomShortcutModeRow(
                title: String(localized: "Global Key"),
                keySymbols: directKeySymbols,
                hasShortcut: hasDirectShortcut,
                onShortcutCaptured: onDirectShortcutCaptured,
                onShortcutCleared: onDirectShortcutCleared
            )
        }
    }
}

private struct CustomSnapCommandDetailPanel: View {
    @EnvironmentObject private var controller: CyclopeController
    let presetID: CustomSnapPreset.ID
    let onDelete: () -> Void

    private var preset: CustomSnapPreset? {
        controller.snapSettings.preset(withID: presetID)
    }

    var body: some View {
        if let preset {
            CommandDetailScrollView {
                CustomSnapLayoutEditorCard(
                    layout: preset.layout,
                    layoutMode: preset.mode,
                    position: preset.position,
                    snapActivationLayouts: preset.snapActivationLayouts,
                    isSnapActivationEnabled: preset.isSnapActivationEnabled,
                    snapActivationOccupiedAreas: snapActivationOccupiedAreas(for: preset),
                    updateLayoutMode: updateLayoutMode,
                    updatePosition: updatePosition,
                    updateLayout: updateLayout,
                    addSnapActivationLayout: addSnapActivationLayout,
                    removeSnapActivationLayout: removeSnapActivationLayout,
                    setSnapActivationEnabled: setSnapActivationEnabled
                )
                CommandDetailSection(String(localized: "Shortcut Keys")) {
                    CustomSnapCommandCard(
                        paletteKeySymbols: customPaletteKeySymbols(for: preset),
                        directKeySymbols: customDirectKeySymbols(for: preset),
                        hasPaletteShortcut: hasPaletteShortcut(for: preset),
                        hasDirectShortcut: hasDirectShortcut(for: preset),
                        onPaletteShortcutCaptured: { key in
                            if let conflict = controller.shortcutSettings.modalShortcutConflict(
                                for: key,
                                excluding: .customModal(preset.id),
                                customPresets: controller.snapSettings.presets
                            ) {
                                showDuplicateModalShortcutAlert(key, existingAssignment: conflict, controller: controller)
                                return
                            }

                            controller.shortcutSettings.setCustomPaletteKey(key, for: preset.id)
                        },
                        onPaletteShortcutCleared: {
                            controller.shortcutSettings.clearCustomPaletteKey(for: preset.id)
                        },
                        onDirectShortcutCaptured: { key in
                            guard confirmGlobalShortcutOverwriteIfNeeded(
                                key,
                                target: .customGlobal(preset.id),
                                controller: controller
                            ) else {
                                return
                            }

                            controller.shortcutSettings.setCustomDirectKey(key, for: preset.id)
                        },
                        onDirectShortcutCleared: {
                            controller.shortcutSettings.clearCustomDirectKey(for: preset.id)
                        }
                    )
                }
                CommandDetailSection(String(localized: "Visibility")) {
                    ShortcutDisplayCard(
                        hasMenuShortcut: true,
                        hasCheatSheetShortcut: hasPaletteShortcut(for: preset),
                        isShownInMenu: controller.shortcutSettings.bindingForCustomMenuDisplay(preset.id),
                        isShownInCheatSheet: controller.shortcutSettings.bindingForCustomCheatSheetDisplay(preset.id)
                    )
                }
                CustomSnapDeleteCard(
                    onDelete: onDelete
                )
            }
        }
    }

    private func updateLayout(_ layout: SnapLayout) {
        controller.snapSettings.updateLayout(layout, for: presetID)
    }

    private func updateLayoutMode(_ mode: CustomSnapPresetMode) {
        controller.snapSettings.updateMode(mode, for: presetID)
    }

    private func updatePosition(_ position: CustomSnapPosition) {
        controller.snapSettings.updatePosition(position, for: presetID)
    }

    private func addSnapActivationLayout(_ layout: SnapActivationLayout) -> Bool {
        controller.snapSettings.addSnapActivationLayout(layout, for: presetID)
    }

    private func removeSnapActivationLayout(_ layout: SnapActivationLayout) {
        controller.snapSettings.removeSnapActivationLayout(layout, for: presetID)
    }

    private func setSnapActivationEnabled(_ isEnabled: Bool) {
        controller.snapSettings.setSnapActivationEnabled(isEnabled, for: presetID)
    }

    private func snapActivationOccupiedAreas(for preset: CustomSnapPreset) -> [SnapActivationOccupiedArea] {
        defaultCommandSnapActivationOccupiedAreas(excluding: nil, using: controller.snapSettings) +
            customSnapActivationOccupiedAreas(excluding: preset.id, using: controller.snapSettings)
    }

    private func customPaletteKeySymbols(for preset: CustomSnapPreset) -> String {
        guard controller.shortcutSettings.isCustomPaletteEnabled(preset.id) else {
            return String(localized: "None")
        }

        return resolvedCustomPaletteKey(for: preset)?.paletteSymbols ?? String(localized: "None")
    }

    private func customDirectKeySymbols(for preset: CustomSnapPreset) -> String {
        controller.shortcutSettings.customDirectKey(for: preset.id)?.directSymbols ?? String(localized: "None")
    }

    private func hasPaletteShortcut(for preset: CustomSnapPreset) -> Bool {
        controller.shortcutSettings.isCustomPaletteEnabled(preset.id) &&
            resolvedCustomPaletteKey(for: preset) != nil
    }

    private func hasDirectShortcut(for preset: CustomSnapPreset) -> Bool {
        controller.shortcutSettings.customDirectKey(for: preset.id) != nil
    }

    private func resolvedCustomPaletteKey(for preset: CustomSnapPreset) -> CustomShortcutKey? {
        controller.shortcutSettings.customPaletteKey(for: preset.id) ??
            defaultCustomShortcutKey(for: preset)
    }

    private func defaultCustomShortcutKey(for preset: CustomSnapPreset) -> CustomShortcutKey? {
        guard let index = controller.snapSettings.presets.firstIndex(where: { $0.id == preset.id }) else {
            return nil
        }

        return GlobalShortcut.defaultCustomShortcutKey(forIndex: index)
    }
}

private struct CustomSnapDeleteCard: View {
    let onDelete: () -> Void

    var body: some View {
        Button(action: onDelete) {
            Text("Delete Custom Command")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
        }
        .buttonStyle(SettingsActionButtonStyle(tint: .red))
        .help("Delete custom command")
        .accessibilityLabel("Delete custom command")
    }
}

private struct MissingCustomSnapCommandPanel: View {
    let addCommand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Command Not Found")
                .font(.system(size: 13, weight: .semibold))

            Button {
                addCommand()
            } label: {
                Label("Add Custom Command", systemImage: "plus")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(36)
        .background(Color.clear)
    }
}

private func defaultCommandSnapActivationOccupiedAreas(
    excluding excludedID: String?,
    using snapSettings: SnapSettingsStore
) -> [SnapActivationOccupiedArea] {
    ShortcutCommand.defaultCommands.flatMap { command in
        guard command.id != excludedID,
              let preference = snapSettings.snapActivationPreference(for: command),
              preference.isEnabled else {
            return [SnapActivationOccupiedArea]()
        }

        return preference.layouts.enumerated().map { index, layout in
            SnapActivationOccupiedArea(
                id: "\(command.id)-\(index)",
                title: command.title,
                layout: layout
            )
        }
    }
}

private func customSnapActivationOccupiedAreas(
    excluding excludedID: CustomSnapPreset.ID?,
    using snapSettings: SnapSettingsStore
) -> [SnapActivationOccupiedArea] {
    snapSettings.presets.flatMap { preset in
        guard preset.id != excludedID,
              preset.isSnapActivationEnabled else {
            return [SnapActivationOccupiedArea]()
        }

        return preset.snapActivationLayouts.enumerated().map { index, layout in
            SnapActivationOccupiedArea(
                id: "\(preset.id.uuidString)-\(index)",
                title: preset.name,
                layout: layout
            )
        }
    }
}

@MainActor
func confirmGlobalShortcutOverwriteIfNeeded(
    _ key: CustomShortcutKey,
    target: ShortcutAssignment,
    controller: CyclopeController
) -> Bool {
    guard !targetAlreadyUsesGlobalShortcut(key, target: target, controller: controller) else {
        return true
    }

    guard let existingAssignment = controller.shortcutSettings.globalShortcutConflict(
        for: key,
        excluding: target,
        customPresets: controller.snapSettings.presets
    ) else {
        return confirmSystemGlobalShortcutAvailable(key)
    }

    let alert = NSAlert()
    alert.messageText = String(localized: "Replace Global Shortcut?")
    alert.informativeText = String(localized: "\(key.directSymbols) is already used by \(shortcutAssignmentTitle(existingAssignment, controller: controller)). Replacing it will remove that shortcut from the existing command.")
    alert.alertStyle = .warning
    alert.addButton(withTitle: String(localized: "Replace"))
    alert.addButton(withTitle: String(localized: "Cancel"))

    guard alert.runModal() == .alertFirstButtonReturn else {
        return false
    }

    controller.shortcutSettings.removeGlobalShortcutAssignment(existingAssignment, matching: key)
    return true
}

@MainActor
private func confirmSystemGlobalShortcutAvailable(_ key: CustomShortcutKey) -> Bool {
    guard let reason = GlobalShortcutManager.globalShortcutUnavailableReason(for: key) else {
        return true
    }

    let alert = NSAlert()
    alert.messageText = String(localized: "Global Shortcut Unavailable")
    alert.informativeText = String(localized: "\(reason) Choose another shortcut.")
    alert.alertStyle = .warning
    alert.addButton(withTitle: String(localized: "OK"))
    alert.runModal()
    return false
}

@MainActor
private func targetAlreadyUsesGlobalShortcut(
    _ key: CustomShortcutKey,
    target: ShortcutAssignment,
    controller: CyclopeController
) -> Bool {
    switch target {
    case .modalShortcut:
        return controller.shortcutSettings.modalShortcutKey.matches(key)
    case .commandGlobal(let command):
        return controller.shortcutSettings.directKeyToMatch(for: command)?
            .matches(key, defaultModifiers: CustomShortcutModifier.defaultDirectModifiers) == true
    case .customGlobal(let presetID):
        return controller.shortcutSettings.customDirectKey(for: presetID)?
            .matches(key, defaultModifiers: CustomShortcutModifier.defaultDirectModifiers) == true
    case .commandModal, .customModal:
        return false
    }
}

@MainActor
private func showDuplicateModalShortcutAlert(
    _ key: CustomShortcutKey,
    existingAssignment: ShortcutAssignment,
    controller: CyclopeController
) {
    let alert = NSAlert()
    alert.messageText = String(localized: "Shortcut Already Used")
    alert.informativeText = String(localized: "\(key.paletteSymbols) is already used by \(shortcutAssignmentTitle(existingAssignment, controller: controller)). Choose another shortcut.")
    alert.alertStyle = .warning
    alert.addButton(withTitle: String(localized: "OK"))
    alert.runModal()
}

@MainActor
private func shortcutAssignmentTitle(
    _ assignment: ShortcutAssignment,
    controller: CyclopeController
) -> String {
    switch assignment {
    case .modalShortcut:
        return String(localized: "Modal Shortcut")
    case .commandModal(let command):
        return String(localized: "\(command.title) Modal Shortcut")
    case .commandGlobal(let command):
        return String(localized: "\(command.title) Global Shortcut")
    case .customModal(let presetID):
        let name = controller.snapSettings.preset(withID: presetID)?.name ?? String(localized: "Custom Command")
        return String(localized: "\(name) Modal Shortcut")
    case .customGlobal(let presetID):
        let name = controller.snapSettings.preset(withID: presetID)?.name ?? String(localized: "Custom Command")
        return String(localized: "\(name) Global Shortcut")
    }
}

private struct CustomSnapCommandCard: View {
    let paletteKeySymbols: String
    let directKeySymbols: String
    let hasPaletteShortcut: Bool
    let hasDirectShortcut: Bool
    let onPaletteShortcutCaptured: (CustomShortcutKey) -> Void
    let onPaletteShortcutCleared: () -> Void
    let onDirectShortcutCaptured: (CustomShortcutKey) -> Void
    let onDirectShortcutCleared: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CustomShortcutModeRow(
                title: String(localized: "Modal Key"),
                keySymbols: paletteKeySymbols,
                hasShortcut: hasPaletteShortcut,
                onShortcutCaptured: onPaletteShortcutCaptured,
                onShortcutCleared: onPaletteShortcutCleared
            )

            Divider()

            CustomShortcutModeRow(
                title: String(localized: "Global Key"),
                keySymbols: directKeySymbols,
                hasShortcut: hasDirectShortcut,
                onShortcutCaptured: onDirectShortcutCaptured,
                onShortcutCleared: onDirectShortcutCleared
            )
        }
    }
}

private struct ShortcutDisplayCard: View {
    let hasMenuShortcut: Bool
    let hasCheatSheetShortcut: Bool
    @Binding var isShownInMenu: Bool
    @Binding var isShownInCheatSheet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CustomShortcutDisplayRow(
                title: String(localized: "Menu"),
                isAvailable: hasMenuShortcut,
                isEnabled: $isShownInMenu
            )

            Divider()

            CustomShortcutDisplayRow(
                title: String(localized: "Command Modal"),
                isAvailable: hasCheatSheetShortcut,
                isEnabled: $isShownInCheatSheet
            )
        }
    }
}

private struct CustomShortcutDisplayRow: View {
    let title: String
    let isAvailable: Bool
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }

            Spacer(minLength: 0)

            Toggle(title, isOn: $isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(!isAvailable)
                .opacity(isAvailable ? 1 : 0.5)
        }
        .opacity(isAvailable ? 1 : 0.62)
    }
}

private struct CustomPresetSidebarNameEditor: View {
    @EnvironmentObject private var controller: CyclopeController
    let preset: CustomSnapPreset
    let isSelected: Bool

    @State private var draftName = ""
    @State private var isEditing = false

    private var currentName: String {
        controller.snapSettings.preset(withID: preset.id)?.name ?? preset.name
    }

    var body: some View {
        Group {
            if isSelected && isEditing {
                editor
            } else {
                display
            }
        }
        .onAppear {
            draftName = currentName
        }
        .onChange(of: preset.name) { _, newName in
            guard !isEditing else { return }
            draftName = newName
        }
        .onChange(of: isSelected) { wasSelected, isSelected in
            if isSelected {
                draftName = currentName
            } else if wasSelected, isEditing {
                commitEditing()
            }
        }
    }

    @ViewBuilder
    private var display: some View {
        if isSelected {
            displayText
                .contentShape(Rectangle())
                .onTapGesture {
                    beginEditing()
                }
        } else {
            displayText
        }
    }

    private var displayText: some View {
        Text(currentName)
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
    }

    private var editor: some View {
        SidebarNameTextField(
            text: $draftName,
            onCommit: commitEditing,
            onCancel: cancelEditing
        )
            .frame(width: editorWidth)
    }

    private var editorFont: Font {
        .system(size: 13, weight: .semibold)
    }

    private var editorWidth: CGFloat? {
        168
    }

    private func beginEditing() {
        draftName = currentName
        isEditing = true
    }

    private func commitEditing() {
        controller.snapSettings.renamePreset(preset.id, to: draftName)
        controller.snapSettings.normalizePresetName(preset.id)
        draftName = currentName
        isEditing = false
    }

    private func cancelEditing() {
        draftName = currentName
        isEditing = false
    }
}

private struct SidebarNameTextField: NSViewRepresentable {
    @Binding var text: String
    let onCommit: () -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> SidebarNameNSTextField {
        let textField = SidebarNameNSTextField()
        textField.delegate = context.coordinator
        textField.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        textField.focusRingType = .none
        textField.lineBreakMode = .byTruncatingTail
        textField.onWindowChanged = { [weak coordinator = context.coordinator] window in
            coordinator?.observe(window: window)
        }
        context.coordinator.textField = textField
        context.coordinator.startMouseMonitor()

        DispatchQueue.main.async {
            textField.window?.makeFirstResponder(textField)
            textField.currentEditor()?.selectAll(nil)
        }

        return textField
    }

    func updateNSView(_ textField: SidebarNameNSTextField, context: Context) {
        context.coordinator.parent = self
        context.coordinator.textField = textField

        if textField.stringValue != text {
            textField.stringValue = text
        }

        DispatchQueue.main.async {
            guard textField.window?.firstResponder !== textField.currentEditor() else { return }
            textField.window?.makeFirstResponder(textField)
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SidebarNameTextField
        weak var textField: NSTextField?
        private var didFinish = false
        private var mouseMonitor: Any?
        private var windowResignObserver: NSObjectProtocol?
        private weak var observedWindow: NSWindow?

        init(_ parent: SidebarNameTextField) {
            self.parent = parent
        }

        deinit {
            removeMouseMonitor()
            removeWindowObserver()
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            parent.text = textField.stringValue
            finish(commit: true)
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                parent.text = textView.string
                finish(commit: true)
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                finish(commit: false)
                return true
            default:
                return false
            }
        }

        func observe(window: NSWindow?) {
            guard observedWindow !== window else { return }
            removeWindowObserver()
            observedWindow = window

            guard let window else { return }
            windowResignObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.finish(commit: true)
            }
        }

        func startMouseMonitor() {
            guard mouseMonitor == nil else { return }
            mouseMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] event in
                self?.finishForMouseDownIfNeeded(event)
                return event
            }
        }

        private func finishForMouseDownIfNeeded(_ event: NSEvent) {
            guard let textField, !didFinish else { return }
            guard let window = textField.window, event.window === window else {
                finish(commit: true)
                return
            }

            let point = textField.convert(event.locationInWindow, from: nil)
            if !textField.bounds.contains(point) {
                finish(commit: true)
            }
        }

        private func finish(commit: Bool) {
            guard !didFinish else { return }
            didFinish = true

            if commit, let textField {
                parent.text = textField.stringValue
            }

            removeMouseMonitor()
            removeWindowObserver()

            if commit {
                parent.onCommit()
            } else {
                parent.onCancel()
            }
        }

        private func removeMouseMonitor() {
            if let mouseMonitor {
                NSEvent.removeMonitor(mouseMonitor)
                self.mouseMonitor = nil
            }
        }

        private func removeWindowObserver() {
            if let windowResignObserver {
                NotificationCenter.default.removeObserver(windowResignObserver)
                self.windowResignObserver = nil
            }
            observedWindow = nil
        }
    }
}

private final class SidebarNameNSTextField: NSTextField {
    var onWindowChanged: (NSWindow?) -> Void = { _ in }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChanged(window)
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        onWindowChanged(newWindow)
        super.viewWillMove(toWindow: newWindow)
    }
}

private struct CustomShortcutModeRow: View {
    let title: String
    let keySymbols: String
    let hasShortcut: Bool
    let onShortcutCaptured: (CustomShortcutKey) -> Void
    let onShortcutCleared: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }

            Spacer(minLength: 0)

            ShortcutKeyCaptureButton(
                keySymbols: keySymbols,
                hasShortcut: hasShortcut
            ) { key in
                onShortcutCaptured(key)
            } onClear: {
                onShortcutCleared()
            }
        }
    }
}

struct ShortcutKeyCaptureButton: View {
    let keySymbols: String
    let hasShortcut: Bool
    let onCapture: (CustomShortcutKey) -> Void
    let onClear: () -> Void

    @State private var isRecording = false
    @State private var keyMonitor: Any?

    var body: some View {
        Button {
            isRecording.toggle()
        } label: {
            Text(isRecording ? "Press key" : keySymbols)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 184)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(isRecording ? 0.22 : 0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .foregroundStyle(hasShortcut ? .primary : .secondary)
                .opacity(hasShortcut ? 1 : 0.62)
        }
        .buttonStyle(.plain)
        .overlay {
            ShortcutKeyCaptureView(
                isRecording: $isRecording,
                onCapture: onCapture,
                onClear: onClear
            )
            .allowsHitTesting(false)
            .opacity(0)
        }
        .onChange(of: isRecording) { _, isRecording in
            if isRecording {
                startKeyMonitor()
            } else {
                stopKeyMonitor()
            }
        }
        .onDisappear {
            stopKeyMonitor()
        }
    }

    private func startKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard isRecording else { return event }

            if event.keyCode == 53 {
                isRecording = false
                return nil
            }

            if CustomShortcutKey.isClearEvent(event) {
                isRecording = false
                onClear()
                return nil
            }

            guard let key = CustomShortcutKey(event: event) else {
                return nil
            }

            isRecording = false
            onCapture(key)
            return nil
        }
    }

    private func stopKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }
}

private struct ShortcutKeyCaptureView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (CustomShortcutKey) -> Void
    let onClear: () -> Void

    func makeNSView(context: Context) -> ShortcutKeyCaptureNSView {
        let view = ShortcutKeyCaptureNSView()
        view.onCapture = { key in
            onCapture(key)
            isRecording = false
        }
        view.onCancel = {
            isRecording = false
        }
        view.onClear = {
            isRecording = false
            onClear()
        }
        view.setRecording(isRecording)
        return view
    }

    func updateNSView(_ view: ShortcutKeyCaptureNSView, context: Context) {
        view.onCapture = { key in
            onCapture(key)
            isRecording = false
        }
        view.onCancel = {
            isRecording = false
        }
        view.onClear = {
            isRecording = false
            onClear()
        }
        view.setRecording(isRecording)

        guard isRecording else { return }
        DispatchQueue.main.async {
            guard view.isRecording else { return }
            view.window?.makeFirstResponder(view)
        }
    }
}

private final class ShortcutKeyCaptureNSView: NSView {
    var onCapture: (CustomShortcutKey) -> Void = { _ in }
    var onClear: () -> Void = {}
    var onCancel: () -> Void = {}
    private(set) var isRecording = false
    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private var appResignObserver: NSObjectProtocol?
    private var windowResignObserver: NSObjectProtocol?
    private weak var observedWindow: NSWindow?

    override var acceptsFirstResponder: Bool { true }

    deinit {
        removeRecordingObservers()
    }

    func setRecording(_ isRecording: Bool) {
        guard self.isRecording != isRecording else {
            if isRecording {
                updateWindowObserver()
            }
            return
        }

        self.isRecording = isRecording
        if isRecording {
            addRecordingObservers()
        } else {
            removeRecordingObservers()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if isRecording {
            updateWindowObserver()
     }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            cancelIfRecording()
        }
        removeWindowObserver()
        super.viewWillMove(toWindow: newWindow)
    }

    override func resignFirstResponder() -> Bool {
        let didResign = super.resignFirstResponder()
        cancelIfRecording()
        return didResign
    }

    override func keyDown(with event: NSEvent) {
        _ = capture(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording, event.type == .keyDown else {
            return super.performKeyEquivalent(with: event)
        }

        return capture(event)
    }

    private func capture(_ event: NSEvent) -> Bool {
        if event.keyCode == 53 {
            cancelIfRecording()
            return true
        }

        if CustomShortcutKey.isClearEvent(event) {
            setRecording(false)
            onClear()
            return true
        }

        guard let key = CustomShortcutKey(event: event) else {
            return true
        }

        setRecording(false)
        onCapture(key)
        return true
    }

    private func addRecordingObservers() {
        updateWindowObserver()
        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.isRecording else { return event }
                return self.capture(event) ? nil : event
            }
        }

        if mouseMonitor == nil {
            mouseMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] event in
                self?.cancelForMouseDownIfNeeded(event)
                return event
            }
        }

        if appResignObserver == nil {
            appResignObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: NSApp,
                queue: .main
            ) { [weak self] _ in
                self?.cancelIfRecording()
            }
        }
    }

    private func updateWindowObserver() {
        guard isRecording else {
            removeWindowObserver()
            return
        }

        guard observedWindow !== window else { return }
        removeWindowObserver()
        guard let window else { return }

        observedWindow = window
        windowResignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.cancelIfRecording()
        }
    }

    private func cancelForMouseDownIfNeeded(_ event: NSEvent) {
        guard isRecording else { return }
        guard let window, event.window === window else {
            cancelIfRecording()
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        if !bounds.contains(point) {
            cancelIfRecording()
        }
    }

    private func cancelIfRecording() {
        guard isRecording else { return }
        setRecording(false)
        onCancel()
    }

    private func removeRecordingObservers() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }

        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }

        if let appResignObserver {
            NotificationCenter.default.removeObserver(appResignObserver)
            self.appResignObserver = nil
        }

        removeWindowObserver()
    }

    private func removeWindowObserver() {
        if let windowResignObserver {
            NotificationCenter.default.removeObserver(windowResignObserver)
            self.windowResignObserver = nil
        }
        observedWindow = nil
    }
}

private struct CustomSnapLayoutEditorCard: View {
    let layout: SnapLayout
    var layoutMode: CustomSnapPresetMode = .sizeAndPosition
    var position: CustomSnapPosition = .center
    let snapActivationLayouts: [SnapActivationLayout]
    let isSnapActivationEnabled: Bool
    let snapActivationOccupiedAreas: [SnapActivationOccupiedArea]
    var updateLayoutMode: ((CustomSnapPresetMode) -> Void)? = nil
    var updatePosition: ((CustomSnapPosition) -> Void)? = nil
    let updateLayout: ((SnapLayout) -> Void)?
    let addSnapActivationLayout: (SnapActivationLayout) -> Bool
    let removeSnapActivationLayout: (SnapActivationLayout) -> Void
    let setSnapActivationEnabled: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if updateLayoutMode != nil {
                CommandDetailSection {
                    layoutModeControl
                } content: {
                    targetLayoutEditor
                }
            } else {
                CommandDetailSection(String(localized: "Target Layout")) {
                    targetLayoutEditor
                }
            }

            CommandDetailSection(String(localized: "Snap Zones")) {
                activationLayoutEditor
            }
        }
    }

    @ViewBuilder
    private var targetLayoutEditor: some View {
        switch layoutMode {
        case .sizeAndPosition:
            sizeAndPositionLayoutEditor
        case .positionOnly:
            positionOnlyLayoutEditor
        }
    }

    private var sizeAndPositionLayoutEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            gridControls

            SnapGridEditor(layout: layout) { newLayout in
                updateLayout?(newLayout)
            }
            .allowsHitTesting(updateLayout != nil)
            .frame(maxWidth: 430)
            .frame(height: 190)
            .frame(maxWidth: .infinity)
        }
    }

    private var positionOnlyLayoutEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            positionSummary

            SnapGridEditor(
                layout: position.layout,
                selectionStyle: .outlineWithCenterDot
            ) { newLayout in
                updatePosition?(CustomSnapPosition(layout: newLayout))
            }
            .allowsHitTesting(updatePosition != nil)
            .frame(maxWidth: 430)
            .frame(height: 190)
            .frame(maxWidth: .infinity)
        }
    }

    private var positionSummary: some View {
        HStack(alignment: .bottom, spacing: 12) {
            gridDimensionSummary(title: String(localized: "Position"), value: position.title)

            Spacer(minLength: 0)
        }
    }

    private var activationLayoutEditor: some View {
        SnapActivationLayoutEditor(
            snapActivationLayouts: snapActivationLayouts,
            isSnapActivationEnabled: isSnapActivationEnabled,
            snapActivationOccupiedAreas: snapActivationOccupiedAreas,
            addSnapActivationLayout: addSnapActivationLayout,
            removeSnapActivationLayout: removeSnapActivationLayout,
            setSnapActivationEnabled: setSnapActivationEnabled
        )
    }

    private var layoutModeControl: some View {
        Picker("", selection: layoutModeBinding) {
            ForEach(CustomSnapPresetMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel("Mode")
    }

    private var layoutModeBinding: Binding<CustomSnapPresetMode> {
        Binding(
            get: { layoutMode },
            set: { updateLayoutMode?($0) }
        )
    }

    private var gridControls: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if let updateLayout {
                gridDimensionControl(
                    title: String(localized: "Columns"),
                    value: layout.columns,
                    range: SnapLayout.columnRange
                ) { columns in
                    updateLayout(layout.scaled(toColumns: columns, rows: layout.rows))
                }

                gridDimensionControl(
                    title: String(localized: "Rows"),
                    value: layout.rows,
                    range: SnapLayout.rowRange
                ) { rows in
                    updateLayout(layout.scaled(toColumns: layout.columns, rows: rows))
                }
            } else {
                gridDimensionSummary(title: String(localized: "Columns"), value: "\(layout.columns)")
                gridDimensionSummary(title: String(localized: "Rows"), value: "\(layout.rows)")
            }

            Spacer(minLength: 0)

            selectedRatioSummary
        }
    }

    private func gridDimensionControl(
        title: String,
        value: Int,
        range: ClosedRange<Int>,
        update: @escaping (Int) -> Void
    ) -> some View {
        let binding = Binding(
            get: { value },
            set: { update(clamped($0, to: range)) }
        )

        return VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 7) {
                TextField(title, value: binding, format: .number)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .frame(width: 56)

                Stepper(title, value: binding, in: range)
                    .labelsHidden()
                    .controlSize(.small)
            }
        }
    }

    private var selectedRatioSummary: some View {
        VStack(alignment: .trailing, spacing: 5) {
            ratioSummaryRow(title: String(localized: "Width"), value: "\(layout.columnSpan) / \(layout.columns)")
            ratioSummaryRow(title: String(localized: "Height"), value: "\(layout.rowSpan) / \(layout.rows)")
        }
    }

    private func gridDimensionSummary(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .frame(height: 22)
        }
    }

    private func ratioSummaryRow(title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .monospacedDigit()
        }
    }

    private func clamped(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

private struct CenterPositionLayoutCard: View {
    let snapActivationLayouts: [SnapActivationLayout]
    let isSnapActivationEnabled: Bool
    let snapActivationOccupiedAreas: [SnapActivationOccupiedArea]
    let addSnapActivationLayout: (SnapActivationLayout) -> Bool
    let removeSnapActivationLayout: (SnapActivationLayout) -> Void
    let setSnapActivationEnabled: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CommandDetailSection(String(localized: "Target Position")) {
                targetLayoutPreview
            }

            CommandDetailSection(String(localized: "Snap Zones")) {
                SnapActivationLayoutEditor(
                    snapActivationLayouts: snapActivationLayouts,
                    isSnapActivationEnabled: isSnapActivationEnabled,
                    snapActivationOccupiedAreas: snapActivationOccupiedAreas,
                    addSnapActivationLayout: addSnapActivationLayout,
                    removeSnapActivationLayout: removeSnapActivationLayout,
                    setSnapActivationEnabled: setSnapActivationEnabled
                )
            }
        }
    }

    private var targetLayoutPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom, spacing: 18) {
                summaryMetric(title: String(localized: "Position"), value: String(localized: "Center"))

                Spacer(minLength: 0)
            }

            SnapGridEditor(
                layout: centerLayout,
                selectionStyle: .outlineWithCenterDot
            ) { _ in
            }
                .allowsHitTesting(false)
                .frame(maxWidth: 430)
                .frame(height: 190)
                .frame(maxWidth: .infinity)
        }
    }

    private var centerLayout: SnapLayout {
        SnapLayout(columns: 3, rows: 3, startColumn: 1, startRow: 1, columnSpan: 1, rowSpan: 1)
    }

    private func summaryMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .frame(height: 22)
        }
    }
}

private struct SnapActivationLayoutEditor: View {
    let snapActivationLayouts: [SnapActivationLayout]
    let isSnapActivationEnabled: Bool
    let snapActivationOccupiedAreas: [SnapActivationOccupiedArea]
    let addSnapActivationLayout: (SnapActivationLayout) -> Bool
    let removeSnapActivationLayout: (SnapActivationLayout) -> Void
    let setSnapActivationEnabled: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SnapActivationGridEditor(
                layouts: snapActivationLayouts,
                isEnabled: isSnapActivationEnabled,
                occupiedAreas: snapActivationOccupiedAreas
            ) { newLayout in
                if addSnapActivationLayout(newLayout) {
                    setSnapActivationEnabled(true)
                }
            } onDelete: { layout in
                removeSnapActivationLayout(layout)
            }
            .frame(maxWidth: 492)
            .frame(height: 252)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct ShortcutPreviewCard: View {
    let layout: SnapLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Target Layout")
                .font(.system(size: 13, weight: .semibold))

            SnapGridEditor(layout: previewLayout) { _ in
            }
            .allowsHitTesting(false)
            .frame(maxWidth: 430)
            .frame(height: 190)
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color.primary.opacity(0.11), lineWidth: 1)
        }
    }

    private var previewLayout: SnapLayout {
        layout.scaled(toColumns: 12, rows: 6)
    }
}

private struct ShortcutUtilityCard: View {
    let command: ShortcutCommand

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: command.systemImage)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(command.title)
                    .font(.system(size: 13, weight: .semibold))

                Text(command.groupTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color.primary.opacity(0.11), lineWidth: 1)
        }
    }
}

private func shortcutSymbols(from keys: String) -> String {
    keys.components(separatedBy: " + ")
        .map { part in
            switch part {
            case "Control":
                return "⌃"
            case "Option":
                return "⌥"
            case "Command":
                return "⌘"
            case "Left":
                return "←"
            case "Right":
                return "→"
            case "Up":
                return "↑"
            case "Down":
                return "↓"
            case "Return":
                return "↩"
            default:
                return part
            }
        }
        .joined(separator: " + ")
}

#Preview {
    let controller = CyclopeController()

    HStack(spacing: 0) {
        ShortcutCommandSidebar(selection: .constant(.shortcut(.snapLeft)))

        SettingsContentColumn(title: ShortcutCommand.snapLeft.title) {
            CommandDetailPanel(selection: .constant(.shortcut(.snapLeft)))
        }
    }
    .environmentObject(controller)
    .environmentObject(controller.updateService)
    .frame(width: 806, height: 720)
}
