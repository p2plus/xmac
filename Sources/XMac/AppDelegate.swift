import AppKit
import XMacCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSWindow.allowsAutomaticWindowTabbing = false
        XMacSettings.shared.applyAppearance()
        CacheBudget.install()
        Task { await CacheBudget.trim() }
        Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { _ in
            Task { await CacheBudget.trim() }
        }
        NotificationBridge.shared.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let destinations = urls.compactMap(LinkIntent.destination(for:))
        Task { @MainActor in
            for destination in destinations {
                WindowRegistry.shared.open(destination)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
}
