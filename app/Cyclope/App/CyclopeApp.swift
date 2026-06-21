import SwiftUI

@main
struct CyclopeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = CyclopeController()

    var body: some Scene {
        MenuBarExtra(isInserted: menuBarInsertedBinding) {
            CyclopeMenuView()
                .environmentObject(controller)
        } label: {
            Label {
                Text(controller.menuBarTitle)
            } icon: {
                Image(controller.menuBarIconImageName)
                    .renderingMode(.template)
            }
        }
        .menuBarExtraStyle(.menu)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    controller.showSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }

    private var menuBarInsertedBinding: Binding<Bool> {
        Binding(
            get: { controller.appPresenceMode.showsMenuBarIcon },
            set: { _ in }
        )
    }
}
