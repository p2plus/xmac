import AppKit
import WebKit
import XMacCore

/// Delegate plumbing the main window and the sign-in sheet share.
/// A subclass decides what a new web view is and what a finished load means.
@MainActor
class WebRules: NSObject, WKNavigationDelegate, WKUIDelegate {
    /// An un-gestured open can slip past the page gate; the app still caps how fast it may lean on the browser.
    @MainActor private static var lastExternalOpen: Date?

    static func openOutside(_ url: URL) {
        let now = Date()
        if let last = lastExternalOpen, now.timeIntervalSince(last) < 2 { return }
        lastExternalOpen = now
        NSWorkspace.shared.open(url)
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
                Self.openOutside(safe)
            }
            decisionHandler(.cancel, preferences)
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = DownloadCenter.shared
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = DownloadCenter.shared
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        PasskeyGate.prepare(for: webView.url)
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
        WebChrome.mediaDecision(origin: origin)
    }

    func webView(
        _ webView: WKWebView,
        requestGeolocationPermissionFor origin: WKSecurityOrigin,
        initiatedBy frame: WKFrameInfo
    ) async -> WKPermissionDecision {
        WebChrome.locationDecision(origin: origin)
    }
}
