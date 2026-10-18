import SwiftUI
import XMacCore

struct NavBar: View {
    @EnvironmentObject private var model: WebModel
    @ObservedObject private var settings = XMacSettings.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchOpen = false

    private var vertical: Bool { settings.navEdge.isVertical }
    private var dark: Bool { colorScheme == .dark }
    private var theme: ChromeTheme { settings.chromeTheme }

    var body: some View {
        Group {
            if vertical {
                VStack(spacing: 8) {
                    navigationCluster
                    Divider()
                    routes
                    Spacer(minLength: 8)
                    searchControl
                    postButton
                    moreMenu
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 6)
                .frame(width: 56)
            } else {
                HStack(spacing: 8) {
                    navigationCluster
                    Divider().frame(height: 18)
                    routes
                    Spacer(minLength: 8)
                    searchControl
                    postButton
                    moreMenu
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
        }
        .foregroundStyle(ink)
        .background(barBackground)
        .overlay(alignment: hairlineEdge) {
            Rectangle()
                .fill(ink.opacity(theme == .standard ? 0.12 : 0.2))
                .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
        }
        .onChange(of: model.focusSearchTick) { _, tick in
            guard tick > 0, vertical else { return }
            searchOpen = true
        }
    }

    private var navigationCluster: some View {
        cluster {
            iconButton("chevron.left", help: "Back", enabled: model.canGoBack, command: .back)
            iconButton("chevron.right", help: "Forward", enabled: model.canGoForward, command: .forward)
            iconButton("arrow.clockwise", help: "Reload", command: .reload)
        }
    }

    private var routes: some View {
        cluster {
            ForEach(AppRoute.toolbar) { route in
                routeButton(route)
            }
        }
    }

    @ViewBuilder
    private func cluster<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if vertical {
            VStack(spacing: 4) { content() }
        } else {
            HStack(spacing: 2) { content() }
        }
    }

    private var searchControl: some View {
        Group {
            if vertical {
                Button {
                    searchOpen = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .frame(width: 28, height: 22)
                }
                .buttonStyle(.borderless)
                .help("Search")
                .popover(isPresented: $searchOpen, arrowEdge: settings.navEdge == .trailing ? .leading : .trailing) {
                    MacSearchField(text: $model.searchDraft, focusTick: model.focusSearchTick) {
                        model.submitSearch()
                        searchOpen = false
                    }
                    .frame(width: 240)
                    .padding(10)
                }
            } else {
                MacSearchField(text: $model.searchDraft, focusTick: model.focusSearchTick) {
                    model.submitSearch()
                }
                .frame(width: 220)
            }
        }
    }

    private var postButton: some View {
        Button {
            model.go(.compose)
        } label: {
            if vertical {
                Image(systemName: "square.and.pencil")
                    .frame(width: 28, height: 22)
            } else {
                Text("Post")
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(theme == .standard ? nil : Color(nsColor: theme.accent(dark: dark)))
        .help("New post")
    }

    private var moreMenu: some View {
        Menu {
            ForEach(AppRoute.more) { route in
                Button {
                    model.go(route)
                } label: {
                    Label(route.title, systemImage: route.symbol)
                }
            }
            Divider()
            Button("Open in Browser") { model.perform(.openInBrowser) }
            Button("Copy Link") { model.perform(.copyLink) }
            Divider()
            Button("Settings…") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .frame(width: 28, height: 22)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More")
    }

    private func iconButton(
        _ symbol: String,
        help: String,
        enabled: Bool = true,
        command: XMacCommand
    ) -> some View {
        Button {
            model.perform(command)
        } label: {
            Image(systemName: symbol)
                .frame(width: 28, height: 22)
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .help(help)
        .accessibilityLabel(help)
    }

    private func routeButton(_ route: AppRoute) -> some View {
        let active = model.activeRoute == route
        let symbol = active ? "\(route.symbol).fill" : route.symbol
        return Button {
            model.go(route)
        } label: {
            Image(systemName: symbol)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(active ? accent : ink)
                .frame(width: 28, height: 22)
                .overlay(alignment: .topTrailing) {
                    if route == .notifications, model.badgeCount > 0 {
                        Text(model.badgeCount > 99 ? "99+" : "\(model.badgeCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.red, in: Capsule())
                            .fixedSize()
                            .offset(x: 6, y: -6)
                    }
                }
        }
        .buttonStyle(.borderless)
        .help(route.title)
        .accessibilityLabel(route.title)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var accent: Color {
        theme == .standard ? Color.accentColor : Color(nsColor: theme.accent(dark: dark))
    }

    private var ink: Color {
        theme == .standard ? Color.primary : Color(nsColor: theme.ink(dark: dark))
    }

    @ViewBuilder
    private var barBackground: some View {
        if theme == .standard {
            Rectangle().fill(.bar)
        } else {
            Color(nsColor: theme.bar(dark: dark))
        }
    }

    private var hairlineEdge: Alignment {
        switch settings.navEdge {
        case .leading: .trailing
        case .trailing: .leading
        case .top: .bottom
        case .bottom: .top
        }
    }
}
