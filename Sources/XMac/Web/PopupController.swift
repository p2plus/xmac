import AppKit
import WebKit
import XMacCore

@MainActor
final class PopupController: NSObject, WKNavigationDelegate, WKUIDelegate, NSWindowDelegate {
    private var panel: NSPanel?
    private var webView: WKWebView?
    private var onReachedX: () -> Void = {}

    func makeWebView(
        configuration: WKWebViewConfiguration,
        parent: NSWindow?,
        onReachedX: @escaping () -> Void
    ) -> WKWebView {
        close()
        self.onReachedX = onReachedX

        let webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 520, height: 720),
            configuration: configuration
        )
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.customUserAgent = XMac.userAgent

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 720),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Sign in"
        panel.contentView = webView
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = false
        panel.level = .normal
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
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
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel, preferences)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
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
        nil
    }
}
