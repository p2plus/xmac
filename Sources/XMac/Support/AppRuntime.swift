import AppKit
import Foundation
import XMacCore

enum XMacCommand {
    case route(AppRoute)
    case back, forward, reload
    case find, findNext, findPrevious
    case searchFocus
    case zoomIn, zoomOut, zoomReset
    case openInBrowser, copyLink
    case clearSession
}

@MainActor
final class CommandBus {
    static let shared = CommandBus()
    weak var target: WebModel?

    func send(_ command: XMacCommand) {
        target?.perform(command)
    }
}

@MainActor
final class WindowRegistry {
    static let shared = WindowRegistry()

    private struct Entry {
        weak var model: WebModel?
    }

    private var entries: [Entry] = []
    private var pending: URL?

    func register(_ model: WebModel) {
        entries.removeAll { $0.model == nil || $0.model === model }
        entries.append(Entry(model: model))
    }

    func unregister(_ model: WebModel) {
        entries.removeAll { $0.model == nil || $0.model === model }
    }

    func preferred() -> WebModel? {
        let live = entries.compactMap(\.model)
        return live.last { $0.webView?.window?.isKeyWindow == true } ?? live.last
    }

    func open(_ url: URL) {
        NSApp.activate(ignoringOtherApps: true)
        guard let model = preferred() else {
            pending = url
            return
        }
        model.load(url, force: true)
        model.webView?.window?.makeKeyAndOrderFront(nil)
    }

    func takePending() -> URL? {
        defer { pending = nil }
        return pending
    }
}
