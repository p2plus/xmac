import AppKit
import Combine
import Foundation
import WebKit
import XMacCore

/// Per-window session. Chrome observes this. The web view calls the `note*` methods.
@MainActor
final class WebModel: ObservableObject {
    @Published var title = "X"
    @Published var url: URL = XMac.home
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var progress = 0.0
    @Published var badgeCount = 0
    @Published var findPresented = false
    @Published var findQuery = ""
    @Published var findStatus = ""
    @Published var hoverURL = ""
    @Published var errorMessage: String?
    @Published var searchDraft = ""
    @Published var focusSearchTick = 0
    @Published var pageZoom = 1.0
    @Published var hasLoadedOnce = false

    weak var webView: WKWebView?
    private var observations: [NSKeyValueObservation] = []
    private var pendingURL: URL?
    private var didBootstrap = false
    private var refreshTask: Task<Void, Never>?
    private var policyGeneration = 0

    var activeRoute: AppRoute? { AppRoute.match(url) }

    func bootstrap() {
        WindowRegistry.shared.register(self)
        CommandBus.shared.target = self
        guard !didBootstrap else { return }
        didBootstrap = true
        pageZoom = XMacSettings.shared.pageZoom
        let initial = WindowRegistry.shared.takePending() ?? XMacSettings.shared.initialURL()
        load(initial, force: false)
    }

    func detach() {
        refreshTask?.cancel()
        refreshTask = nil
        policyGeneration += 1
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        webView = nil
        WindowRegistry.shared.unregister(self)
        if CommandBus.shared.target === self {
            CommandBus.shared.target = WindowRegistry.shared.preferred()
        }
    }

    func attach(_ webView: WKWebView) {
        self.webView = webView
        webView.pageZoom = pageZoom
        applyChromeColors()
        installObservations(on: webView)
        let generation = policyGeneration + 1
        policyGeneration = generation
        Task { await finishAttach(generation: generation) }
    }

    func applyLivePolicy(reload: Bool) {
        guard let webView else { return }
        applyChromeColors()
        let generation = policyGeneration + 1
        policyGeneration = generation
        let block = XMacSettings.shared.blockImages
        let scheme = XMacSettings.shared.appearance.cssScheme
        let pause = XMacSettings.shared.pauseAutoplay
        Task {
            await ImageBlocker.apply(to: webView, enabled: block)
            guard generation == policyGeneration, self.webView === webView else { return }
            installScripts(on: webView)
            let js = """
            window.__xmacNoAutoplay = \(pause ? "true" : "false");
            if (document.documentElement) {
              document.documentElement.style.colorScheme = "\(scheme)";
            }
            """
            _ = try? await webView.evaluateJavaScript(js)
            if reload { webView.reload() }
        }
    }

    func applyChromeColors() {
        guard let webView else { return }
        let settings = XMacSettings.shared
        webView.appearance = settings.appearance.nsAppearance
        webView.underPageBackgroundColor = settings.chromeTheme.underPageColor(
            matching: webView.effectiveAppearance
        )
    }

    func restartRefresh() {
        refreshTask?.cancel()
        let seconds = XMacSettings.shared.refreshSeconds
        guard seconds > 0 else {
            refreshTask = nil
            return
        }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    guard XMacSettings.shared.refreshSeconds == seconds else { return }
                    guard !self.isLoading else { return }
                    if self.url.path.hasPrefix("/compose") { return }
                    self.reload()
                }
            }
        }
    }

    private func finishAttach(generation: Int) async {
        guard generation == policyGeneration, let webView else { return }
        await ImageBlocker.apply(to: webView, enabled: XMacSettings.shared.blockImages)
        guard generation == policyGeneration, self.webView === webView else { return }
        installScripts(on: webView)
        let target = pendingURL ?? (didBootstrap ? url : nil)
        pendingURL = nil
        if let target, webView.url == nil {
            isLoading = true
            webView.load(URLRequest(url: target))
        }
        restartRefresh()
    }

    private func installScripts(on webView: WKWebView) {
        let settings = XMacSettings.shared
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(
            PageScript.userScript(
                pauseAutoplay: settings.pauseAutoplay,
                colorScheme: settings.appearance.cssScheme
            )
        )
    }

    func load(_ url: URL, force: Bool) {
        let target = URLClassifier.navigationTarget(url)
        self.url = URLClassifier.shareable(target) ?? target
        errorMessage = nil
        hoverURL = ""
        guard let webView else {
            pendingURL = target
            return
        }
        if !force, webView.url == target { return }
        isLoading = true
        webView.load(URLRequest(url: target))
    }

    func perform(_ command: XMacCommand) {
        switch command {
        case .home: go(.home)
        case .explore: go(.explore)
        case .notifications: go(.notifications)
        case .messages: go(.messages)
        case .bookmarks: go(.bookmarks)
        case .lists: go(.lists)
        case .grok: go(.grok)
        case .profile: go(.profile)
        case .back: webView?.goBack()
        case .forward: webView?.goForward()
        case .reload: reload()
        case .find: toggleFind()
        case .findNext:
            findPresented = true
            performFind(forward: true)
        case .findPrevious:
            findPresented = true
            performFind(forward: false)
        case .compose: go(.compose)
        case .searchFocus: focusSearchTick += 1
        case .zoomIn: setZoom(pageZoom + 0.1, persist: true)
        case .zoomOut: setZoom(pageZoom - 0.1, persist: true)
        case .zoomReset: setZoom(1, persist: true)
        case .openInBrowser: openInBrowser()
        case .copyLink: copyLink()
        case .clearSession:
            Task { await clearSession() }
        }
    }

    func go(_ route: AppRoute) {
        if route == .profile {
            clickProfile()
            return
        }
        load(route.url, force: true)
    }

    func submitSearch() {
        let query = searchDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        load(URLClassifier.searchURL(query: query), force: true)
    }

    func setZoom(_ value: Double, persist: Bool) {
        let clamped = min(1.6, max(0.7, (value * 10).rounded() / 10))
        pageZoom = clamped
        webView?.pageZoom = clamped
        if persist, XMacSettings.shared.pageZoom != clamped {
            XMacSettings.shared.pageZoom = clamped
        }
    }

    func noteTitle(_ newTitle: String) {
        let clean = SurfaceText.clip(newTitle, limit: 300)
        if !clean.isEmpty { title = clean }
        badgeCount = URLClassifier.badgeCount(from: clean)
        applyDockBadge()
    }

    func noteURL(_ newURL: URL) {
        let rewritten = URLClassifier.rewriteToX(newURL)
        url = URLClassifier.shareable(rewritten) ?? rewritten
        if let stored = URLClassifier.persisted(rewritten) {
            XMacSettings.shared.lastURLString = stored.absoluteString
        }
    }

    func noteStarted() {
        errorMessage = nil
        isLoading = true
    }

    func noteFinished() {
        hasLoadedOnce = true
        errorMessage = nil
    }

    func noteFailure(_ error: Error) {
        guard let message = URLClassifier.navigationErrorMessage(error) else { return }
        errorMessage = message
        isLoading = false
    }

    func noteHover(_ url: URL?) {
        guard let url else {
            hoverURL = ""
            return
        }
        let scheme = url.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" else {
            hoverURL = ""
            return
        }
        hoverURL = url.absoluteString
    }

    func reload() {
        errorMessage = nil
        guard let webView else {
            load(url, force: true)
            return
        }
        if webView.url == nil {
            load(url, force: true)
        } else if NSEvent.modifierFlags.contains(.option) {
            webView.reloadFromOrigin()
        } else {
            webView.reload()
        }
    }

    func toggleFind() {
        if findPresented {
            dismissFind()
        } else {
            findPresented = true
        }
    }

    func performFind(forward: Bool) {
        guard let webView, findPresented else { return }
        let configuration = WKFindConfiguration()
        configuration.backwards = !forward
        configuration.caseSensitive = false
        configuration.wraps = true
        let query = findQuery
        webView.find(query, configuration: configuration) { [weak self] result in
            Task { @MainActor in
                guard let self, self.findQuery == query else { return }
                if query.isEmpty || result.matchFound {
                    self.findStatus = ""
                } else {
                    self.findStatus = "No matches"
                }
            }
        }
    }

    func dismissFind() {
        findPresented = false
        findStatus = ""
        let configuration = WKFindConfiguration()
        webView?.find("", configuration: configuration) { _ in }
    }

    func openInBrowser() {
        guard let safe = URLClassifier.shareable(webView?.url ?? url) else { return }
        NSWorkspace.shared.open(safe)
    }

    func copyLink() {
        guard let safe = URLClassifier.shareable(webView?.url ?? url) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(safe.absoluteString, forType: .string)
    }

    func clearSession() async {
        let store = WKWebsiteDataStore.default()
        await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
        XMacSettings.shared.lastURLString = nil
        badgeCount = 0
        NSApp.dockTile.badgeLabel = nil
        hasLoadedOnce = false
        load(AppRoute.home.url, force: true)
    }

    func applyDockBadge() {
        guard XMacSettings.shared.dockBadge else {
            NSApp.dockTile.badgeLabel = nil
            return
        }
        if badgeCount > 99 {
            NSApp.dockTile.badgeLabel = "99+"
        } else if badgeCount > 0 {
            NSApp.dockTile.badgeLabel = "\(badgeCount)"
        } else {
            NSApp.dockTile.badgeLabel = nil
        }
    }

    private func clickProfile() {
        let script = """
        (function(){
          const link = document.querySelector('a[data-testid="AppTabBar_Profile_Link"]');
          if (!link) return false;
          link.click();
          return true;
        })()
        """
        guard let webView else {
            load(AppRoute.profile.url, force: true)
            return
        }
        Task {
            let result = try? await webView.evaluateJavaScript(script)
            if (result as? Bool) != true {
                load(AppRoute.profile.url, force: true)
            }
        }
    }

    private func installObservations(on webView: WKWebView) {
        observations.forEach { $0.invalidate() }
        observations = [
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] view, _ in
                Task { @MainActor in self?.canGoBack = view.canGoBack }
            },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] view, _ in
                Task { @MainActor in self?.canGoForward = view.canGoForward }
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] view, _ in
                Task { @MainActor in self?.isLoading = view.isLoading }
            },
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
                let value = view.estimatedProgress
                Task { @MainActor in self?.progress = value }
            },
            webView.observe(\.title, options: [.new]) { [weak self] view, _ in
                let title = view.title ?? ""
                Task { @MainActor in self?.noteTitle(title) }
            },
            webView.observe(\.url, options: [.new]) { [weak self] view, _ in
                guard let url = view.url else { return }
                Task { @MainActor in self?.noteURL(url) }
            }
        ]
    }
}
