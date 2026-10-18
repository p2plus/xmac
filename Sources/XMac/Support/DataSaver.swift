import Foundation
import WebKit

/// Keeps the WebKit disk footprint small. Cookies and local storage stay so the login survives.
enum CacheBudget {
    static let cacheTypes: Set<String> = [
        WKWebsiteDataTypeDiskCache,
        WKWebsiteDataTypeMemoryCache,
        WKWebsiteDataTypeFetchCache,
        WKWebsiteDataTypeOfflineWebApplicationCache,
        WKWebsiteDataTypeServiceWorkerRegistrations
    ]

    static func install() {
        URLCache.shared = URLCache(
            memoryCapacity: 2 * 1024 * 1024,
            diskCapacity: 8 * 1024 * 1024
        )
    }

    static func trim() async {
        await WKWebsiteDataStore.default().removeData(ofTypes: cacheTypes, modifiedSince: .distantPast)
        URLCache.shared.removeAllCachedResponses()
    }
}

enum ImageBlocker {
    static let identifier = "xmac-block-images"
    private static let rules = """
    [{"trigger":{"url-filter":".*","resource-type":["image"]},"action":{"type":"block"}}]
    """

    @MainActor
    static func apply(to webView: WKWebView, enabled: Bool) async {
        let controller = webView.configuration.userContentController
        guard let store = WKContentRuleListStore.default() else { return }
        if let existing = try? await store.contentRuleList(forIdentifier: identifier) {
            controller.remove(existing)
        }
        guard enabled else { return }
        guard let list = try? await store.compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: rules
        ) else { return }
        controller.add(list)
    }
}
