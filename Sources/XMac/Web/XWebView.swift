import AppKit
import SwiftUI
import WebKit
import XMacCore

struct XWebView: NSViewRepresentable {
    @EnvironmentObject private var model: WebModel

    func makeCoordinator() -> WebCoordinator {
        WebCoordinator(model: model)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        // Only click-started windows open; un-gestured window.open stays blocked,
        // so an embedded script cannot keep firing the default browser.
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.preferences.isFraudulentWebsiteWarningEnabled = true
        configuration.preferences.isElementFullscreenEnabled = true
        configuration.preferences.tabFocusesLinks = true
        configuration.preferences.inactiveSchedulingPolicy = .throttle
        configuration.upgradeKnownHostsToHTTPS = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: XMac.messageHandler)
        configuration.userContentController = contentController
        configuration.mediaTypesRequiringUserActionForPlayback =
            XMacSettings.shared.pauseAutoplay ? .all : []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.customUserAgent = XMac.userAgent
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        webView.isInspectable = ProcessInfo.processInfo.environment["XMAC_INSPECT"] == "1"
        webView.appearance = XMacSettings.shared.appearance.nsAppearance
        webView.underPageBackgroundColor = XMacSettings.shared.chromeTheme.underPageColor(
            matching: webView.effectiveAppearance
        )
        model.attach(webView)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: WebCoordinator) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: XMac.messageHandler)
        coordinator.teardown()
        Task { @MainActor in
            coordinator.model.detach()
        }
    }
}
