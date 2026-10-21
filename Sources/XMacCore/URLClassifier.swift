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
        "recaptcha.net",
        "oauth2.googleapis.com",
        "appleid.cdn-apple.com",
        "account.apple.com",
        "iforgot.apple.com",
        "account.live.com",
        "login.microsoft.com",
        "login.windows.net"
    ]

    /// Query names that can carry a session. They are stripped before anything is stored or handed to another app.
    private static let sensitiveQueryNames: Set<String> = [
        "code", "token", "access_token", "refresh_token", "id_token",
        "oauth_token", "oauth_verifier", "oauth_token_secret",
        "session", "session_token", "auth", "auth_token", "ticket",
        "sso", "nonce", "state", "code_challenge", "code_verifier",
        "password", "pwd", "secret", "api_key", "apikey"
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

    /// Address the web view may load. Host is rewritten and userinfo is removed. Query values stay, because a sign-in redirect needs them inside the app.
    public static func navigationTarget(_ url: URL) -> URL {
        let rewritten = rewriteToX(url)
        guard var parts = URLComponents(url: rewritten, resolvingAgainstBaseURL: false) else { return rewritten }
        parts.user = nil
        parts.password = nil
        return parts.url ?? rewritten
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

    /// Camera and microphone prompts are only for x.com itself.
    public static func mayCaptureMedia(host: String) -> Bool {
        !host.isEmpty && isXFamily(host: host)
    }

    /// The system file panel is only for an upload that started on x.com.
    public static func mayOfferFilePicker(host: String) -> Bool {
        !host.isEmpty && isXFamily(host: host)
    }

    /// Script dialogs are shown for x.com and the sign-in hosts. Other frames are dismissed.
    public static func mayPresentPageDialog(host: String, path: String = "") -> Bool {
        !host.isEmpty && (isXFamily(host: host) || isAuthHost(host: host, path: path))
    }

    /// This app does not read or forward the Mac's location.
    public static func mayReadLocation(host _: String) -> Bool {
        false
    }

    /// URL safe to put on the clipboard or open in another app. Query secrets are removed.
    public static func shareable(_ url: URL) -> URL? {
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "mailto" || scheme == "tel" || scheme == "sms" { return url }
        guard scheme == "http" || scheme == "https" else { return nil }
        return strippingSecrets(from: url, dropFragment: false)
    }

    /// URL safe to write down so the next launch can reopen an X page.
    /// Login and oauth pages are dropped so a half-finished sign-in is not restored.
    public static func persisted(_ url: URL) -> URL? {
        guard let host = url.host, isXFamily(host: host) else { return nil }
        let rewritten = rewriteToX(url)
        let path = URLComponents(url: rewritten, resolvingAgainstBaseURL: false)?.path.lowercased() ?? ""
        if path.contains("/oauth") || path.contains("/i/flow/") || path.contains("/login") || path.contains("/logout") {
            return nil
        }
        guard let cleaned = strippingSecrets(from: rewritten, dropFragment: true),
              cleaned.scheme?.lowercased() == "https" else { return nil }
        return cleaned
    }

    /// Why a load failed, or nil when it is not a real failure (cancel, frame swap).
    /// The app maps the case to localized text; this library has no strings.
    public enum NavigationFailure: Equatable, Hashable, Sendable {
        case offline
        case timedOut
        case unreachable
        case generic
    }

    public static func classify(_ error: Error) -> NavigationFailure? {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return nil }
        if ns.domain == "WebKitErrorDomain" && (ns.code == 102 || ns.code == 204) { return nil }
        switch (ns.domain, ns.code) {
        case (NSURLErrorDomain, NSURLErrorNotConnectedToInternet),
             (NSURLErrorDomain, NSURLErrorNetworkConnectionLost):
            return .offline
        case (NSURLErrorDomain, NSURLErrorTimedOut):
            return .timedOut
        case (NSURLErrorDomain, NSURLErrorCannotFindHost),
             (NSURLErrorDomain, NSURLErrorCannotConnectToHost),
             (NSURLErrorDomain, NSURLErrorDNSLookupFailed):
            return .unreachable
        default:
            return .generic
        }
    }

    private static func isSensitiveQueryName(_ name: String) -> Bool {
        let lowered = name.lowercased()
        if sensitiveQueryNames.contains(lowered) { return true }
        return lowered.contains("token") || lowered.contains("secret") || lowered.contains("password")
    }

    private static func strippingSecrets(from url: URL, dropFragment: Bool) -> URL? {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        parts.user = nil
        parts.password = nil
        if dropFragment { parts.fragment = nil }
        if let items = parts.queryItems {
            let kept = items.filter { !isSensitiveQueryName($0.name) }
            parts.queryItems = kept.isEmpty ? nil : kept
        }
        return parts.url
    }
}
