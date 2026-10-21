import AppKit
import Combine
import Foundation
import XMacCore

@MainActor
final class XMacSettings: ObservableObject {
    static let shared = XMacSettings()

    private let defaults: UserDefaults

    @Published var restoreLastURL: Bool {
        didSet { defaults.set(restoreLastURL, forKey: Keys.restore) }
    }

    @Published var dockBadge: Bool {
        didSet {
            defaults.set(dockBadge, forKey: Keys.badge)
            if !dockBadge { NSApp.dockTile.badgeLabel = nil }
        }
    }

    @Published var nativeNotifications: Bool {
        didSet { defaults.set(nativeNotifications, forKey: Keys.notifications) }
    }

    @Published var showWelcome: Bool {
        didSet { defaults.set(showWelcome, forKey: Keys.welcome) }
    }

    @Published var pageZoom: Double {
        didSet { defaults.set(pageZoom, forKey: Keys.zoom) }
    }

    @Published var startRoute: AppRoute {
        didSet { defaults.set(startRoute.rawValue, forKey: Keys.start) }
    }

    /// Last page, already cleaned by `URLClassifier.persisted` before it is set.
    @Published var lastURLString: String? {
        didSet {
            guard lastURLString != oldValue else { return }
            if let lastURLString {
                defaults.set(lastURLString, forKey: Keys.lastURL)
            } else {
                defaults.removeObject(forKey: Keys.lastURL)
            }
        }
    }

    @Published var appearance: AppearanceChoice {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    @Published var chromeTheme: ChromeTheme {
        didSet { defaults.set(chromeTheme.rawValue, forKey: Keys.theme) }
    }

    @Published var navEdge: NavEdge {
        didSet { defaults.set(navEdge.rawValue, forKey: Keys.navEdge) }
    }

    @Published var pauseAutoplay: Bool {
        didSet {
            defaults.set(pauseAutoplay, forKey: Keys.autoplay)
            if ready, pauseAutoplay != oldValue { webViewGeneration += 1 }
        }
    }

    @Published var blockImages: Bool {
        didSet { defaults.set(blockImages, forKey: Keys.images) }
    }

    @Published var refreshSeconds: Int {
        didSet { defaults.set(refreshSeconds, forKey: Keys.refresh) }
    }

    /// Bumped when the web view has to be rebuilt (autoplay policy lives on the configuration).
    @Published var webViewGeneration = 0

    private var ready = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        restoreLastURL = defaults.object(forKey: Keys.restore) as? Bool ?? true
        dockBadge = defaults.object(forKey: Keys.badge) as? Bool ?? true
        nativeNotifications = defaults.object(forKey: Keys.notifications) as? Bool ?? true
        showWelcome = defaults.object(forKey: Keys.welcome) as? Bool ?? true
        let storedZoom = defaults.object(forKey: Keys.zoom) as? Double ?? 1
        pageZoom = min(1.6, max(0.7, storedZoom == 0 ? 1 : storedZoom))
        if let raw = defaults.string(forKey: Keys.start), let route = AppRoute(rawValue: raw), AppRoute.startPages.contains(route) {
            startRoute = route
        } else {
            startRoute = .home
        }
        let stored = defaults.string(forKey: Keys.lastURL)
        if let url = stored.flatMap(URL.init(string:)), let cleaned = URLClassifier.persisted(url) {
            lastURLString = cleaned.absoluteString
        } else {
            lastURLString = nil
        }
        appearance = AppearanceChoice.resolve(defaults.string(forKey: Keys.appearance))
        chromeTheme = ChromeTheme.resolve(defaults.string(forKey: Keys.theme))
        navEdge = NavEdge.resolve(defaults.string(forKey: Keys.navEdge))
        pauseAutoplay = defaults.object(forKey: Keys.autoplay) as? Bool ?? true
        blockImages = defaults.object(forKey: Keys.images) as? Bool ?? false
        let storedRefresh = defaults.object(forKey: Keys.refresh) as? Int ?? 0
        refreshSeconds = RefreshChoice.resolve(storedRefresh).rawValue
        ready = true
    }

    func applyAppearance() {
        NSApp.appearance = appearance.nsAppearance
    }

    func initialURL() -> URL {
        if restoreLastURL,
           let raw = lastURLString,
           let url = URL(string: raw),
           let safe = URLClassifier.persisted(url) {
            return safe
        }
        return startRoute.url
    }

    private enum Keys {
        static let restore = "xmac.restoreLastURL"
        static let badge = "xmac.dockBadge"
        static let notifications = "xmac.nativeNotifications"
        static let welcome = "xmac.showWelcome"
        static let zoom = "xmac.pageZoom"
        static let start = "xmac.startRoute"
        static let lastURL = "xmac.lastURL"
        static let appearance = "xmac.appearance"
        static let theme = "xmac.chromeTheme"
        static let navEdge = "xmac.navEdge"
        static let autoplay = "xmac.pauseAutoplay"
        static let images = "xmac.blockImages"
        static let refresh = "xmac.refreshSeconds"
    }
}
