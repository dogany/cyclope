//
//  SettingsView.swift
//  Cyclope
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum SettingsVisualStyle {
    static let topChromeClearance: CGFloat = 28
    static let shortcutSidebarWidth: CGFloat = 360
    static let paneBackground = Color(nsColor: .controlBackgroundColor).opacity(0.48)
    static let paneStroke = Color.primary.opacity(0.11)
    static let selectedCategoryBackground = Color.accentColor.opacity(0.16)
    static let settingsGroupBackground = Color(nsColor: .controlBackgroundColor).opacity(0.72)
    static let settingsGroupStroke = Color.primary.opacity(0.11)
    static let restoreDefaultsForeground = Color.blue.opacity(0.96)
    static let actionButtonHoverTintOpacity = 0.06
    static let actionButtonPressedTintOpacity = 0.12
}

struct SettingsView: View {
    @EnvironmentObject private var controller: CyclopeController
    @State private var selection: SettingsCategory = .preferences
    @State private var commandSelection: CommandSelection = .general

    init(initialSelection: SettingsCategory = .preferences) {
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        HStack(spacing: 0) {
            SettingsCategoryBar(selection: $selection)

            SettingsWorkspace {
                switch selection {
                case .preferences:
                    SettingsRoundedPane {
                        SettingsContentColumn(title: String(localized: "Preferences")) {
                            PreferencesSettingsPanel()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .shortcuts:
                    HStack(spacing: 10) {
                        SettingsRoundedPane {
                            ShortcutCommandSidebar(selection: $commandSelection)
                        }
                        .frame(width: SettingsVisualStyle.shortcutSidebarWidth)

                        SettingsRoundedPane {
                            SettingsContentColumn(title: commandSelection.title(using: controller.snapSettings)) {
                                CommandDetailPanel(selection: $commandSelection)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                case .sleep:
                    SettingsRoundedPane {
                        SettingsContentColumn(title: String(localized: "Sleep Prevention")) {
                            SleepPreventionSettingsPanel()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .scrolling:
                    SettingsRoundedPane {
                        SettingsContentColumn(title: String(localized: "Scroll Direction")) {
                            ScrollDirectionSettingsPanel()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .permissions:
                    SettingsRoundedPane {
                        SettingsContentColumn(title: String(localized: "Permissions")) {
                            PermissionsSettingsPanel()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background {
            SettingsGlassBackground()
        }
        .ignoresSafeArea(.container, edges: .top)
        .resizableSettingsWindow(minSize: NSSize(width: 720, height: 540))
        .onAppear {
            selectInitialCommandIfRequested()
        }
    }

    private func selectInitialCommandIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--show-custom-snap-settings"),
              let presetID = controller.snapSettings.selectedPresetID else {
            return
        }

        commandSelection = .customSnap(presetID)
    }
}

private struct SettingsWorkspace<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .settingsWindowDragArea()
            }
            .padding(.trailing, 10)
            .frame(height: SettingsVisualStyle.topChromeClearance, alignment: .center)

            content
                .padding(.top, 10)
                .padding(.trailing, 10)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct SettingsRoundedPane<Content: View>: View {
    private let content: Content
    private let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            SettingsVisualStyle.paneBackground

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipShape(shape)
            .overlay {
                shape
                    .stroke(SettingsVisualStyle.paneStroke, lineWidth: 1)
            }
    }
}

private struct SettingsGlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.state = .active
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
    }
}

private struct SettingsWindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> SettingsWindowDragAreaView {
        SettingsWindowDragAreaView()
    }

    func updateNSView(_ view: SettingsWindowDragAreaView, context: Context) {}
}

private final class SettingsWindowDragAreaView: NSView {
    override var isOpaque: Bool { false }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

private extension View {
    func settingsWindowDragArea() -> some View {
        overlay {
            SettingsWindowDragArea()
        }
    }
}

private struct SettingsCategoryBar: View {
    @Binding var selection: SettingsCategory

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: SettingsVisualStyle.topChromeClearance)
                .settingsWindowDragArea()

            VStack(spacing: 8) {
                ForEach(SettingsCategory.allCases) { category in
                    SettingsCategoryBarButton(
                        category: category,
                        isSelected: selection == category
                    ) {
                        selection = category
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .frame(width: 82)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct SettingsCategoryBarButton: View {
    let category: SettingsCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 24, height: 22)

                Text(category.title)
                    .font(.system(size: 10, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .frame(width: 56)
            }
            .foregroundStyle(isSelected ? Color.accentColor : .primary.opacity(0.78))
            .frame(width: 66, height: 64)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(SettingsVisualStyle.selectedCategoryBackground)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.primary.opacity(0.11), lineWidth: 1)
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .help(category.title)
        .accessibilityLabel(category.title)
    }
}

struct SettingsContentColumn<Content: View>: View {
    let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            SettingsTopBar(title: title)

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

struct SettingsTopBar: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.leading, 22)
        .padding(.trailing, 18)
        .frame(height: 38)
        .background(Color.clear)
        .settingsWindowDragArea()
    }
}

private struct PreferencesSettingsPanel: View {
    @EnvironmentObject private var controller: CyclopeController
    @EnvironmentObject private var launchAtLoginService: LaunchAtLoginService
    @EnvironmentObject private var updateService: UpdateService

    private var launchAtLoginBinding: Binding<Bool> {
        Binding {
            launchAtLoginService.isEnabled || launchAtLoginService.requiresApproval
        } set: { isEnabled in
            controller.setLaunchAfterLoginEnabled(isEnabled)
        }
    }

    private var appPresenceBinding: Binding<AppPresenceMode> {
        Binding {
            controller.appPresenceMode
        } set: { mode in
            controller.setAppPresenceMode(mode)
        }
    }

    var body: some View {
        SettingsPanel {
            SettingsSection(String(localized: "Startup & Visibility")) {
                SettingsRow(String(localized: "Open at Login")) {
                    HStack(spacing: 10) {
                        Button {
                            controller.openLaunchAfterLoginSettings()
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Open Login Items in System Settings")
                        .accessibilityLabel("Open System Settings")

                        Toggle("Open at Login", isOn: launchAtLoginBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .disabled(!launchAtLoginService.isAvailable)
                            .help("Open at Login")
                            .accessibilityLabel("Open at Login")
                    }
                }

                SettingsDivider()

                SettingsRow(String(localized: "App Presence")) {
                    Picker("Appears In", selection: appPresenceBinding) {
                        ForEach(AppPresenceMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .fixedSize()
                    .help("Choose where Cyclope appears")
                    .accessibilityLabel("Appears In")
                }
            }

            SettingsSection(
                String(localized: "Menu Sections"),
                footer: String(localized: "Drag sections to change their order. Turn off sections you do not want in the menu.")
            ) {
                MenuCategorySettingsCard()
            }

            SettingsSection(String(localized: "Updates")) {
                SettingsRow(String(localized: "Current Version")) {
                    Text(updateService.currentVersionTitle)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                SettingsDivider()

                SettingsRow(String(localized: "Software Update")) {
                    Button {
                        updateService.checkForUpdates()
                    } label: {
                        Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .controlSize(.small)
                    .disabled(!updateService.canCheckForUpdates)
                    .help("Check for updates")
                    .accessibilityLabel("Check for updates")
                }
            }

            RestoreDefaultSettingsButton {
                controller.confirmRestoreDefaultSettings()
            }
        }
    }
}

private struct MenuCategorySettingsCard: View {
    @EnvironmentObject private var controller: CyclopeController
    private let rowHeight: CGFloat = 42
    @State private var draggingCategory: AppMenuCategory?
    @State private var dropInsertionIndex: Int?

    var body: some View {
        List {
            ForEach(Array(controller.shortcutSettings.menuCategories.enumerated()), id: \.element.id) { index, setting in
                MenuCategorySettingsRow(
                    setting: setting,
                    showsDivider: setting.category != controller.shortcutSettings.menuCategories.last?.category,
                    showsTopDropIndicator: dropInsertionIndex == index,
                    showsBottomDropIndicator: dropInsertionIndex == controller.shortcutSettings.menuCategories.count &&
                        index == controller.shortcutSettings.menuCategories.count - 1,
                    isEnabled: controller.shortcutSettings.bindingForMenuCategoryDisplay(setting.category)
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .onDrag {
                    draggingCategory = setting.category
                    dropInsertionIndex = nil
                    return NSItemProvider(object: setting.category.rawValue as NSString)
                } preview: {
                    MenuCategoryDragPreview(setting: setting)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: MenuCategoryDropDelegate(
                        targetIndex: index,
                        rowHeight: rowHeight,
                        draggingCategory: $draggingCategory,
                        dropInsertionIndex: $dropInsertionIndex,
                        categories: { controller.shortcutSettings.menuCategories.map(\.category) },
                        moveAction: controller.shortcutSettings.moveMenuCategory
                    )
                )
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(height: CGFloat(controller.shortcutSettings.menuCategories.count) * rowHeight)
    }
}

private struct MenuCategorySettingsRow: View {
    let setting: MenuCategorySettingsSnapshot
    let showsDivider: Bool
    let showsTopDropIndicator: Bool
    let showsBottomDropIndicator: Bool
    @Binding var isEnabled: Bool

    var body: some View {
        ZStack(alignment: .top) {
            rowContent

            if showsTopDropIndicator {
                MenuCategoryDropIndicator()
            }
        }
        .overlay(alignment: .bottom) {
            if showsBottomDropIndicator {
                MenuCategoryDropIndicator()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var rowContent: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 16)
                    .help("Drag to reorder")
                    .accessibilityHidden(true)

                Text(setting.category.title)
                    .font(.system(size: 13, weight: .semibold))

                Spacer(minLength: 16)

                Toggle(setting.category.title, isOn: $isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help(setting.category.title)
                    .accessibilityLabel(setting.category.title)
            }
            .padding(.horizontal, 14)
            .frame(height: 41)

            if showsDivider {
                if showsBottomDropIndicator {
                    Color.clear.frame(height: 1)
                } else {
                    Divider()
                        .padding(.leading, 14)
                }
            }
        }
    }
}

private struct MenuCategoryDropIndicator: View {
    var body: some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }
}

private struct MenuCategoryDragPreview: View {
    let setting: MenuCategorySettingsSnapshot

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 16)

            Text(setting.category.title)
                .font(.system(size: 13, weight: .semibold))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(width: 220, height: 38)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(SettingsVisualStyle.settingsGroupStroke, lineWidth: 1)
        }
    }
}

private struct MenuCategoryDropDelegate: DropDelegate {
    let targetIndex: Int
    let rowHeight: CGFloat
    @Binding var draggingCategory: AppMenuCategory?
    @Binding var dropInsertionIndex: Int?
    let categories: () -> [AppMenuCategory]
    let moveAction: (AppMenuCategory, Int) -> Void

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
        guard let draggingCategory else {
            dropInsertionIndex = nil
            return false
        }

        let insertionIndex = dropInsertionIndex ?? insertionIndex(for: info)
        self.draggingCategory = nil
        dropInsertionIndex = nil

        guard let insertionIndex else { return false }
        moveAction(draggingCategory, insertionIndex)
        return true
    }

    private func updateDropInsertionIndex(using info: DropInfo) {
        dropInsertionIndex = insertionIndex(for: info)
    }

    private func insertionIndex(for info: DropInfo) -> Int? {
        guard let draggingCategory,
              let sourceIndex = categories().firstIndex(of: draggingCategory) else {
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

private struct RestoreDefaultSettingsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Reset to default")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SettingsVisualStyle.restoreDefaultsForeground)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
        }
        .buttonStyle(SettingsActionButtonStyle(tint: SettingsVisualStyle.restoreDefaultsForeground))
        .help("Reset settings")
        .accessibilityLabel("Reset settings")
    }
}

struct SettingsActionButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> Body {
        Body(configuration: configuration, tint: tint)
    }

    struct Body: View {
        let configuration: ButtonStyleConfiguration
        let tint: Color
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .background {
                    ZStack {
                        SettingsVisualStyle.settingsGroupBackground

                        if configuration.isPressed {
                            tint.opacity(SettingsVisualStyle.actionButtonPressedTintOpacity)
                        } else if isHovered {
                            tint.opacity(SettingsVisualStyle.actionButtonHoverTintOpacity)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(SettingsVisualStyle.settingsGroupStroke, lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .onHover { isHovered = $0 }
                .animation(.easeOut(duration: 0.12), value: isHovered)
        }
    }
}

enum SettingsCategory: String, CaseIterable, Identifiable {
    case preferences
    case shortcuts
    case sleep
    case scrolling
    case permissions

    var id: Self { self }

    var title: String {
        switch self {
        case .preferences:
            return String(localized: "Preferences")
        case .shortcuts:
            return String(localized: "Window")
        case .sleep:
            return String(localized: "Sleep")
        case .scrolling:
            return String(localized: "Scrolling")
        case .permissions:
            return String(localized: "Permissions")
        }
    }

    var systemImage: String {
        switch self {
        case .preferences:
            return "gearshape"
        case .shortcuts:
            return "macwindow"
        case .sleep:
            return "moon.zzz"
        case .scrolling:
            return "arrow.up.arrow.down"
        case .permissions:
            return "lock.shield"
        }
    }
}

struct SettingsPanel<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                content
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(.horizontal, 36)
            .padding(.top, 24)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.visible)
        .background(Color.clear)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let footer: String?
    private let headerAccessory: AnyView?
    private let groupBackground: Color
    private let groupStroke: Color
    private let content: Content

    init(
        _ title: String,
        footer: String? = nil,
        headerAccessory: AnyView? = nil,
        groupBackground: Color = SettingsVisualStyle.settingsGroupBackground,
        groupStroke: Color = SettingsVisualStyle.settingsGroupStroke,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.headerAccessory = headerAccessory
        self.groupBackground = groupBackground
        self.groupStroke = groupStroke
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                Spacer(minLength: 0)

                headerAccessory
            }
            .padding(.horizontal, 2)

            SettingsGroup(
                background: groupBackground,
                stroke: groupStroke
            ) {
                content
            }

            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }
        }
    }
}

struct SettingsGroup<Content: View>: View {
    private let background: Color
    private let stroke: Color
    private let content: Content

    init(
        background: Color = SettingsVisualStyle.settingsGroupBackground,
        stroke: Color = SettingsVisualStyle.settingsGroupStroke,
        @ViewBuilder content: () -> Content
    ) {
        self.background = background
        self.stroke = stroke
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(stroke, lineWidth: 1)
        }
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 14)
    }
}

struct SettingsRow<Accessory: View>: View {
    let title: String
    let detail: String?
    let systemImage: String?
    private let accessory: Accessory

    init(
        _ title: String,
        detail: String? = nil,
        systemImage: String? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: detail == nil ? .center : .top, spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                    .padding(.top, detail == nil ? 0 : 1)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 16)

            accessory
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

extension SettingsRow where Accessory == EmptyView {
    init(
        _ title: String,
        detail: String? = nil,
        systemImage: String? = nil
    ) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.accessory = EmptyView()
    }
}

#Preview {
    let controller = CyclopeController()

    SettingsView()
        .environmentObject(controller)
        .environmentObject(controller.permissionCoordinator)
        .environmentObject(controller.launchAtLoginService)
        .environmentObject(controller.updateService)
}
