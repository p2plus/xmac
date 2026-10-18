import SwiftUI

@main
struct XMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "main") {
            MainRoot()
        }
        .defaultSize(width: 1180, height: 820)
        .windowToolbarStyle(.unifiedCompact)
        .commands { XMacCommands() }

        Settings {
            SettingsView()
        }
    }
}

struct XMacCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Post") { CommandBus.shared.send(.compose) }
                .keyboardShortcut("n", modifiers: .command)
            Button("New Window") { openWindow(id: "main") }
                .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        CommandGroup(after: .sidebar) {
            Button("Home") { CommandBus.shared.send(.home) }
                .keyboardShortcut("1", modifiers: .command)
            Button("Explore") { CommandBus.shared.send(.explore) }
                .keyboardShortcut("2", modifiers: .command)
            Button("Notifications") { CommandBus.shared.send(.notifications) }
                .keyboardShortcut("3", modifiers: .command)
            Button("Messages") { CommandBus.shared.send(.messages) }
                .keyboardShortcut("4", modifiers: .command)
            Button("Bookmarks") { CommandBus.shared.send(.bookmarks) }
                .keyboardShortcut("5", modifiers: .command)
            Button("Grok") { CommandBus.shared.send(.grok) }
                .keyboardShortcut("6", modifiers: .command)
            Button("Lists") { CommandBus.shared.send(.lists) }
                .keyboardShortcut("7", modifiers: .command)
            Button("Profile") { CommandBus.shared.send(.profile) }
                .keyboardShortcut("8", modifiers: .command)
            Divider()
            Button("Search") { CommandBus.shared.send(.searchFocus) }
                .keyboardShortcut("l", modifiers: .command)
        }
        CommandGroup(after: .pasteboard) {
            Button("Find on Page…") { CommandBus.shared.send(.find) }
                .keyboardShortcut("f", modifiers: .command)
            Button("Find Next") { CommandBus.shared.send(.findNext) }
                .keyboardShortcut("g", modifiers: .command)
            Button("Find Previous") { CommandBus.shared.send(.findPrevious) }
                .keyboardShortcut("g", modifiers: [.command, .shift])
        }
        CommandGroup(after: .toolbar) {
            Button("Zoom In") { CommandBus.shared.send(.zoomIn) }
                .keyboardShortcut("+", modifiers: .command)
            Button("Zoom Out") { CommandBus.shared.send(.zoomOut) }
                .keyboardShortcut("-", modifiers: .command)
            Button("Actual Size") { CommandBus.shared.send(.zoomReset) }
                .keyboardShortcut("0", modifiers: .command)
            Divider()
            Button("Back") { CommandBus.shared.send(.back) }
                .keyboardShortcut("[", modifiers: .command)
            Button("Forward") { CommandBus.shared.send(.forward) }
                .keyboardShortcut("]", modifiers: .command)
            Button("Reload") { CommandBus.shared.send(.reload) }
                .keyboardShortcut("r", modifiers: .command)
            Divider()
            Button("Open in Browser") { CommandBus.shared.send(.openInBrowser) }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            Button("Copy Link") { CommandBus.shared.send(.copyLink) }
                .keyboardShortcut("c", modifiers: [.command, .shift])
        }
    }
}
