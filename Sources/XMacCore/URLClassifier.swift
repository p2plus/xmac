import Foundation

public enum NavigationPolicy: Equatable, Sendable {
    case allow
    case cancel
    case openExternally
}

public enum URLClassifier {
    private static let xDomains = ["x.com", "twitter.com", "twimg.com", "t.co", "pscp.tv"]
    private static let hostsRewrittenToX: Set<String> = [
        "twitter.com", "www.twitter.com", "mobile.twitter.com", "m.twitter.com",
        "www.x.com", "mobile.x.com", "m.x.com"
    ]
    private static let authHosts: Set<String> = [
        "accounts.google.com",
        "myaccount.google.com",
        "apis.google.com",
        "accounts.youtube.com",
        "appleid.apple.com",
        "idmsa.apple.com",
        "gsa.apple.com",
        "setup.icloud.com",
        "login.microsoftonline.com",
        "login.live.com",
        "challenges.cloudflare.com",
        "client-api.arkoselabs.com",
        "iframe.arkoselabs.com",
        "www.recaptcha.net",
        "recaptcha.net"
    ]

    public static func normalizedHost(_ host: String) -> String {
        host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    public static func isXFamily(host: String) -> Bool {
        let normalized = normalizedHost(host)
        return xDomains.contains { normalized == $0 || normalized.hasSuffix("." + $0) }
    }

    public static func isAuthHost(host: String, path: String = "") -> Bool {
        let normalized = normalizedHost(host)
        if authHosts.contains(normalized) { return true }
        if normalized == "www.google.com" || normalized == "google.com" {
            let lowered = path.lowercased()
            return lowered.contains("recaptcha")
                || lowered.contains("/o/oauth2")
                || lowered.contains("signin")
                || lowered.contains("/device")
        }
        return false
    }

    public static func shouldStayInApp(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        if scheme == "about" || scheme == "blob" { return true }
        guard scheme == "http" || scheme == "https", let host = url.host else { return false }
        return isXFamily(host: host) || isAuthHost(host: host, path: url.path)
    }

    public static func rewriteToX(_ url: URL) -> URL {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = parts.host else { return url }
        let normalized = normalizedHost(host)
        if hostsRewrittenToX.contains(normalized) {
            parts.host = "x.com"
            parts.scheme = "https"
            return parts.url ?? url
        }
        if isXFamily(host: normalized), parts.scheme?.lowercased() == "http" {
            parts.scheme = "https"
            return parts.url ?? url
        }
        return url
    }

    public static func policy(for url: URL, isMainFrame: Bool) -> NavigationPolicy {
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "about" || scheme == "blob" { return .allow }
        if scheme == "data" { return isMainFrame ? .cancel : .allow }
        if scheme == "javascript" || scheme == "file" { return .cancel }
        if scheme == "mailto" || scheme == "tel" || scheme == "sms" { return .openExternally }
        guard scheme == "http" || scheme == "https" else { return .cancel }
        if !isMainFrame { return .allow }
        if shouldStayInApp(url) { return .allow }
        return .openExternally
    }

    public static func badgeCount(from title: String) -> Int {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "(", let end = trimmed.firstIndex(of: ")") else { return 0 }
        let inside = trimmed[trimmed.index(after: trimmed.startIndex)..<end]
        let digits = inside.filter(\.isNumber)
        guard !digits.isEmpty, let value = Int(digits), value >= 0, value < 100_000 else { return 0 }
        return value
    }

    public static func searchURL(query: String) -> URL {
        var components = URLComponents(string: "https://x.com/search")!
        let trimmed = String(query.prefix(500))
        components.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "src", value: "typed_query")
        ]
        return components.url!
    }

    public static func composeURL(text: String? = nil, attachment: String? = nil) -> URL {
        var components = URLComponents(string: "https://x.com/compose/post")!
        var items: [URLQueryItem] = []
        if let text, !text.isEmpty {
            items.append(URLQueryItem(name: "text", value: String(text.prefix(2000))))
        }
        if let attachment, !attachment.isEmpty {
            items.append(URLQueryItem(name: "url", value: String(attachment.prefix(2000))))
        }
        if !items.isEmpty { components.queryItems = items }
        return components.url!
    }

    public static func navigationErrorMessage(_ error: Error) -> String? {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return nil }
        if ns.domain == "WebKitErrorDomain" && (ns.code == 102 || ns.code == 204) { return nil }
        switch (ns.domain, ns.code) {
        case (NSURLErrorDomain, NSURLErrorNotConnectedToInternet),
             (NSURLErrorDomain, NSURLErrorNetworkConnectionLost):
            return "No connection. Check the network and reload."
        case (NSURLErrorDomain, NSURLErrorTimedOut):
            return "Timed out. Reload the page."
        case (NSURLErrorDomain, NSURLErrorCannotFindHost),
             (NSURLErrorDomain, NSURLErrorCannotConnectToHost),
             (NSURLErrorDomain, NSURLErrorDNSLookupFailed):
            return "x.com can't be reached."
        default:
            return "The page didn't load."
        }
    }
}
