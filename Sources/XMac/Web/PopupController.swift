import AppKit
import WebKit
import XMacCore

/// Sign-in window. Uses the configuration WebKit hands over, so the session is the same store as the main view.
@MainActor
final class PopupController: NSObject, WKNavigationDelegate, WKUIDelegate, NSWindowDelegate {
    private let depth: Int
    private var panel: NSPanel?
    private var webView: WKWebView?
    private var children: [PopupController] = []
    private var onReachedX: () -> Void = {}

    init(depth: Int = 0) {
        self.depth = depth
        super.init()
    }

    func makeWebView(
        configuration: WKWebViewConfiguration,
        parent: NSWindow?,
        onReachedX: @escaping () -> Void
    ) -> WKWebView {
        close()
        self.onReachedX = onReachedX

        let webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 640, height: 800),
            configuration: configuration
        )
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.customUserAgent = XMac.userAgent
        webView.isInspectable = ProcessInfo.processInfo.environment["XMAC_INSPECT"] == "1"

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        panel.title = String(localized: "Sign in", comment: "Authentication window title")
        panel.contentView = webView
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = false
        panel.level = .normal
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.minSize = NSSize(width: 420, height: 520)
        panel.delegate = self
        if let parent {
            let size = panel.frame.size
            let parentFrame = parent.frame
            panel.setFrameOrigin(NSPoint(
                x: parentFrame.midX - size.width / 2,
                y: parentFrame.midY - size.height / 2
            ))
        } else {
            panel.center()
        }
        panel.makeKeyAndOrderFront(nil)

        self.panel = panel
        self.webView = webView
        return webView
    }

    func close() {
        let kids = children
        children = []
        kids.forEach { $0.close() }
        guard panel != nil || webView != nil else { return }
        let panel = self.panel
        let webView = self.webView
        self.panel = nil
        self.webView = nil
        onReachedX = {}
        webView?.navigationDelegate = nil
        webView?.uiDelegate = nil
        panel?.delegate = nil
        panel?.orderOut(nil)
        panel?.contentView = nil
    }

    func windowWillClose(_ notification: Notification) {
        close()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow, preferences)
            return
        }
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        switch URLClassifier.policy(for: url, isMainFrame: isMainFrame) {
        case .allow:
            decisionHandler(.allow, preferences)
        case .cancel:
            decisionHandler(.cancel, preferences)
        case .openExternally:
            if let safe = URLClassifier.shareable(url) {
                NSWorkspace.shared.open(safe)
            }
            decisionHandler(.cancel, preferences)
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if navigationResponse.canShowMIMEType {
            decisionHandler(.allow)
        } else {
            decisionHandler(.download)
        }
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = DownloadCenter.shared
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = DownloadCenter.shared
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        PasskeyGate.prepare(for: webView.url)
        guard let url = webView.url, let host = url.host, URLClassifier.isXFamily(host: host) else { return }
        let path = url.path.lowercased()
        if path.contains("login") || path.contains("oauth") || path.contains("flow") { return }
        let reached = onReachedX
        close()
        reached()
    }

    func webViewDidClose(_ webView: WKWebView) {
        close()
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            switch URLClassifier.policy(for: url, isMainFrame: true) {
            case .cancel:
                return nil
            case .openExternally:
                if let safe = URLClassifier.shareable(url) {
                    NSWorkspace.shared.open(safe)
                }
                return nil
            case .allow:
                break
            }
        }
        guard depth < 2 else { return nil }
        let child = PopupController(depth: depth + 1)
        children.append(child)
        return child.makeWebView(configuration: configuration, parent: panel) { [weak self] in
            guard let self else { return }
            let reached = self.onReachedX
            self.close()
            reached()
        }
    }

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        WebChrome.openPanel(on: webView, parameters: parameters, frame: frame, completion: completionHandler)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        WebChrome.alert(on: webView.window, frame: frame, message: message, completion: completionHandler)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        WebChrome.confirm(on: webView.window, frame: frame, message: message, completion: completionHandler)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        WebChrome.prompt(
            on: webView.window,
            frame: frame,
            prompt: prompt,
            defaultText: defaultText,
            completion: completionHandler
        )
    }

    func webView(
        _ webView: WKWebView,
        decideMediaCapturePermissionsFor origin: WKSecurityOrigin,
        initiatedBy frame: WKFrameInfo,
        type: WKMediaCaptureType
    ) async -> WKPermissionDecision {
        _ = frame
        _ = type
        return WebChrome.mediaDecision(origin: origin)
    }

    func webView(
        _ webView: WKWebView,
        requestGeolocationPermissionFor origin: WKSecurityOrigin,
        initiatedBy frame: WKFrameInfo
    ) async -> WKPermissionDecision {
        _ = frame
        return WebChrome.locationDecision(origin: origin)
    }
}
