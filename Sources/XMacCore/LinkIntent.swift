import Foundation

public enum LinkIntent {
    /// Turns an `https://x.com`, `twitter://`, or `xmac://` URL into a page this app can open.
    /// Returns nil for anything that is not X.
    public static func destination(for url: URL) -> URL? {
        destination(for: url, depth: 0)
    }

    /// `xmac://open?url=` may unwrap exactly one layer. More nesting is a crash attempt, not a link.
    private static func destination(for url: URL, depth: Int) -> URL? {
        switch url.scheme?.lowercased() ?? "" {
        case "http", "https":
            guard let host = url.host, URLClassifier.isXFamily(host: host) else { return nil }
            return URLClassifier.rewriteToX(url)
        case "twitter", "xmac":
            return parseAppURL(url, depth: depth)
        default:
            return nil
        }
    }

    private static func parseAppURL(_ url: URL, depth: Int) -> URL? {
        let scheme = url.scheme?.lowercased() ?? ""
        let host = (url.host ?? "").lowercased()
        let parts = url.path.split(separator: "/").map(String.init)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func query(_ name: String) -> String? {
            items.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
        }

        let command = host.isEmpty ? (parts.first ?? "") : host
        if scheme == "xmac", command == "open" {
            guard depth < 1,
                  let raw = query("url"), raw.count <= 2_000,
                  let inner = URL(string: raw) else { return nil }
            return destination(for: inner, depth: depth + 1)
        }

        switch command {
        case "", "home":
            return AppRoute.home.url
        case "explore":
            return AppRoute.explore.url
        case "notifications", "activity":
            return AppRoute.notifications.url
        case "mentions":
            return XMac.url("https://x.com/notifications/mentions")
        case "messages", "dm":
            return AppRoute.messages.url
        case "bookmarks":
            return AppRoute.bookmarks.url
        case "lists":
            return AppRoute.lists.url
        case "list":
            if let screen = screenName(query("screen_name") ?? ""), let slug = screenName(query("slug") ?? "", max: 50) {
                return XMac.url("https://x.com/\(screen)/lists/\(slug)")
            }
            return AppRoute.lists.url
        case "grok":
            return AppRoute.grok.url
        case "compose", "post", "tweet":
            return URLClassifier.composeURL(text: query("text") ?? query("message"), attachment: query("url"))
        case "search":
            return URLClassifier.searchURL(query: query("query") ?? query("q") ?? "")
        case "user", "user_profile":
            let raw = query("screen_name") ?? query("screenName") ?? parts.first(where: { $0 != "user" && $0 != "user_profile" })
            guard let screen = raw.flatMap({ screenName($0) }) else { return nil }
            return XMac.url("https://x.com/\(screen)")
        case "status":
            let raw = query("id") ?? parts.first
            guard let id = raw.flatMap(statusID) else { return nil }
            return XMac.url("https://x.com/i/status/\(id)")
        default:
            if let raw = query("screen_name"), let screen = screenName(raw) {
                return XMac.url("https://x.com/\(screen)")
            }
            return nil
        }
    }

    private static func screenName(_ raw: String, max: Int = 15) -> String? {
        var value = raw
        if value.hasPrefix("@") { value.removeFirst() }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard !value.isEmpty, value.count <= max, value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return value
    }

    private static func statusID(_ raw: String) -> String? {
        guard (5...25).contains(raw.count), raw.allSatisfy(\.isNumber) else { return nil }
        return raw
    }
}
