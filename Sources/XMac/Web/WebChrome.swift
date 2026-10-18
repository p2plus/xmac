import AppKit
import WebKit
import XMacCore

/// Native panels for the web view. Device access stays on x.com. Dialogs name the site that asked.
@MainActor
enum WebChrome {
    static func openPanel(
        on webView: WKWebView,
        parameters: WKOpenPanelParameters,
        frame: WKFrameInfo,
        completion: @escaping ([URL]?) -> Void
    ) {
        let host = frame.request.url?.host ?? ""
        guard URLClassifier.mayOfferFilePicker(host: host) else {
            completion(nil)
            return
        }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        panel.resolvesAliases = true
        panel.prompt = String(localized: "Upload", comment: "File panel button")
        let finish: (NSApplication.ModalResponse) -> Void = { response in
            completion(response == .OK ? panel.urls : nil)
        }
        if let window = webView.window {
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            finish(panel.runModal())
        }
    }

    static func alert(
        on window: NSWindow?,
        frame: WKFrameInfo,
        message: String,
        completion: @escaping () -> Void
    ) {
        guard allowedDialog(frame) else {
            completion()
            return
        }
        let alert = NSAlert()
        alert.messageText = siteName(frame)
        alert.informativeText = SurfaceText.clip(message, limit: 500)
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "OK", comment: "Dialog button"))
        present(alert, on: window) { _ in completion() }
    }

    static func confirm(
        on window: NSWindow?,
        frame: WKFrameInfo,
        message: String,
        completion: @escaping (Bool) -> Void
    ) {
        guard allowedDialog(frame) else {
            completion(false)
            return
        }
        let alert = NSAlert()
        alert.messageText = siteName(frame)
        alert.informativeText = SurfaceText.clip(message, limit: 500)
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "OK", comment: "Dialog button"))
        alert.addButton(withTitle: String(localized: "Cancel", comment: "Dialog button"))
        present(alert, on: window) { response in
            completion(response == .alertFirstButtonReturn)
        }
    }

    static func prompt(
        on window: NSWindow?,
        frame: WKFrameInfo,
        prompt: String,
        defaultText: String?,
        completion: @escaping (String?) -> Void
    ) {
        guard allowedDialog(frame) else {
            completion(nil)
            return
        }
        let alert = NSAlert()
        alert.messageText = siteName(frame)
        alert.informativeText = SurfaceText.clip(prompt, limit: 500)
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "OK", comment: "Dialog button"))
        alert.addButton(withTitle: String(localized: "Cancel", comment: "Dialog button"))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = SurfaceText.clip(defaultText ?? "", limit: 500)
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        present(alert, on: window) { response in
            completion(response == .alertFirstButtonReturn ? field.stringValue : nil)
        }
    }

    static func mediaDecision(origin: WKSecurityOrigin) -> WKPermissionDecision {
        URLClassifier.mayCaptureMedia(host: origin.host) ? .prompt : .deny
    }

    static func locationDecision(origin: WKSecurityOrigin) -> WKPermissionDecision {
        URLClassifier.mayReadLocation(host: origin.host) ? .prompt : .deny
    }

    private static func allowedDialog(_ frame: WKFrameInfo) -> Bool {
        let host = frame.request.url?.host ?? ""
        let path = frame.request.url?.path ?? ""
        return URLClassifier.mayPresentPageDialog(host: host, path: path)
    }

    private static func siteName(_ frame: WKFrameInfo) -> String {
        let host = frame.request.url?.host ?? ""
        return host.isEmpty ? String(localized: "This page says", comment: "Dialog title when the page has no host") : host
    }

    private static func present(
        _ alert: NSAlert,
        on window: NSWindow?,
        completion: @escaping (NSApplication.ModalResponse) -> Void
    ) {
        if let window {
            alert.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(alert.runModal())
        }
    }
}
