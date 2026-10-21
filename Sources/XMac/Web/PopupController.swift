import AppKit
import WebKit
import XMacCore

/// Sign-in window. Uses the configuration WebKit hands over, so the session is the same store as the main view.
@MainActor
final class PopupController: WebRules, NSWindowDelegate {
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

    override func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        super.webView(webView, didFinish: navigation)
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
}
