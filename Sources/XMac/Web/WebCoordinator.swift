import AppKit
import WebKit
import XMacCore

/// Main window delegate. Routes loads, keeps one sign-in sheet, and forwards page state to the model.
@MainActor
final class WebCoordinator: WebRules, WKScriptMessageHandler {
    let model: WebModel
    private var popup: PopupController?

    init(model: WebModel) {
        self.model = model
        super.init()
    }

    func teardown() {
        popup?.close()
        popup = nil
    }

    // Public WKNavigationDelegate has no mouseDidMoveOver callback on this SDK.

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // The page script runs in the main frame only; a sub-frame speaking its dialect is an impostor.
        guard message.frameInfo.isMainFrame else { return }
        guard message.name == XMac.messageHandler else { return }
        guard let host = message.frameInfo.request.url?.host, URLClassifier.isXFamily(host: host) else { return }
        guard let event = PageEvent.parse(message.body) else { return }
        switch event {
        case .title(let title):
            Task { @MainActor in
                model.noteTitle(title)
            }
        case .notify(let title, let body, let tag):
            Task { @MainActor in
                NotificationBridge.shared.post(title: title, body: body, tag: tag)
            }
        }
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
                    Self.openOutside(safe)
                }
                return nil
            case .allow:
                if let host = url.host, URLClassifier.isXFamily(host: host) {
                    Task { @MainActor in
                        model.load(url, force: true)
                    }
                    return nil
                }
            }
        }
        let controller = popup ?? PopupController()
        popup = controller
        return controller.makeWebView(configuration: configuration, parent: webView.window) { [weak model] in
            Task { @MainActor in
                model?.reload()
            }
        }
    }

    func webViewDidClose(_ webView: WKWebView) {
        popup?.close()
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        Task { @MainActor in
            model.noteStarted()
            model.noteHover(nil)
        }
    }

    override func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        super.webView(webView, didFinish: navigation)
        Task { @MainActor in
            model.noteFinished()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            model.noteFailure(error)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            model.noteFailure(error)
        }
    }
}
