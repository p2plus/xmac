import AppKit
import WebKit
import XMacCore

@MainActor
final class WebCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    let model: WebModel
    weak var webView: WKWebView?
    private var popup: PopupController?

    init(model: WebModel) {
        self.model = model
        super.init()
    }

    func teardown() {
        popup?.close()
        popup = nil
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

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        Task { @MainActor in
            model.noteStarted()
            model.noteHover(nil)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
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

    // Public WKNavigationDelegate has no mouseDidMoveOver callback on this SDK.

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
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
                    NSWorkspace.shared.open(safe)
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
