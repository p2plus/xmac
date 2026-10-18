import Foundation

public enum AppRoute: String, CaseIterable, Identifiable, Hashable, Sendable {
    case home
    case explore
    case notifications
    case messages
    case bookmarks
    case lists
    case grok
    case profile
    case compose

    public var id: String { rawValue }

    public static let toolbar: [AppRoute] = [.home, .explore, .notifications, .messages, .bookmarks, .grok]
    public static let startPages: [AppRoute] = [.home, .explore, .notifications, .messages, .bookmarks]
    public static let more: [AppRoute] = [.lists, .profile]

    public var title: String {
        switch self {
        case .home: "Home"
        case .explore: "Explore"
        case .notifications: "Notifications"
        case .messages: "Messages"
        case .bookmarks: "Bookmarks"
        case .lists: "Lists"
        case .grok: "Grok"
        case .profile: "Profile"
        case .compose: "Post"
        }
    }

    public var symbol: String {
        switch self {
        case .home: "house"
        case .explore: "magnifyingglass"
        case .notifications: "bell"
        case .messages: "envelope"
        case .bookmarks: "bookmark"
        case .lists: "list.bullet"
        case .grok: "sparkles"
        case .profile: "person.crop.circle"
        case .compose: "square.and.pencil"
        }
    }

    public var url: URL {
        switch self {
        case .home: XMac.url("https://x.com/home")
        case .explore: XMac.url("https://x.com/explore")
        case .notifications: XMac.url("https://x.com/notifications")
        case .messages: XMac.url("https://x.com/messages")
        case .bookmarks: XMac.url("https://x.com/i/bookmarks")
        case .lists: XMac.url("https://x.com/i/lists")
        case .grok: XMac.url("https://x.com/i/grok")
        case .profile: XMac.url("https://x.com/settings/profile")
        case .compose: XMac.url("https://x.com/compose/post")
        }
    }

    public static func match(_ url: URL) -> AppRoute? {
        guard let host = url.host, URLClassifier.isXFamily(host: host) else { return nil }
        let path = url.path
        if path.hasPrefix("/i/bookmarks") { return .bookmarks }
        if path.hasPrefix("/i/lists") || path.hasPrefix("/lists") || path.contains("/lists/") { return .lists }
        if path.hasPrefix("/i/grok") || path == "/grok" || path.hasPrefix("/grok/") { return .grok }
        if path.hasPrefix("/compose") || path.hasPrefix("/intent/post") { return .compose }
        if path.hasPrefix("/settings/profile") { return .profile }
        if path.hasPrefix("/notifications") { return .notifications }
        if path.hasPrefix("/messages") { return .messages }
        if path.hasPrefix("/explore") || path.hasPrefix("/search") { return .explore }
        if path.isEmpty || path == "/" || path.hasPrefix("/home") { return .home }
        return nil
    }
}
