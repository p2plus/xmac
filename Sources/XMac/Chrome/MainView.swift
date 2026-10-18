import AppKit
import Combine
import SwiftUI
import WebKit
import XMacCore

struct MainRoot: View {
    @StateObject private var model = WebModel()
    @ObservedObject private var settings = XMacSettings.shared

    var body: some View {
        MainView()
            .environmentObject(model)
            .preferredColorScheme(settings.appearance.colorScheme)
            .onAppear {
                settings.applyAppearance()
                model.bootstrap()
            }
            .onChange(of: settings.pageZoom) { _, newValue in
                model.setZoom(newValue, persist: false)
            }
            .onChange(of: settings.appearance) { _, _ in
                settings.applyAppearance()
                model.applyLivePolicy(reload: true)
            }
            .onChange(of: settings.chromeTheme) { _, _ in
                model.applyChromeColors()
            }
            .onChange(of: settings.blockImages) { _, _ in
                model.applyLivePolicy(reload: true)
            }
            .onChange(of: settings.refreshSeconds) { _, _ in
                model.restartRefresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
                guard let window = note.object as? NSWindow, window === model.webView?.window else { return }
                CommandBus.shared.target = model
            }
    }
}

struct MainView: View {
    @EnvironmentObject private var model: WebModel
    @ObservedObject private var settings = XMacSettings.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        shell {
            VStack(spacing: 0) {
                if settings.showWelcome {
                    WelcomeBanner()
                }
                if model.findPresented {
                    FindBar()
                }
                ZStack(alignment: .bottomLeading) {
                    XWebView()
                        .id(settings.webViewGeneration)
                    if let message = model.errorMessage {
                        errorPane(message)
                    } else if !model.hasLoadedOnce {
                        launchCover
                    }
                    if !model.hoverURL.isEmpty {
                        hoverCapsule
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .overlay(alignment: .top) {
                if model.isLoading {
                    ProgressView(value: min(max(model.progress, 0.05), 1))
                        .progressViewStyle(.linear)
                        .tint(accent)
                        .controlSize(.mini)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .allowsHitTesting(false)
                }
            }
        }
        .background(canvas)
        .navigationTitle("")
        .frame(minWidth: 1000, minHeight: 680)
    }

    @ViewBuilder
    private func shell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        switch settings.navEdge {
        case .top:
            VStack(spacing: 0) {
                NavBar()
                content()
            }
        case .bottom:
            VStack(spacing: 0) {
                content()
                NavBar()
            }
        case .leading:
            HStack(spacing: 0) {
                NavBar()
                content()
            }
        case .trailing:
            HStack(spacing: 0) {
                content()
                NavBar()
            }
        }
    }

    private var dark: Bool { colorScheme == .dark }

    private var canvas: Color {
        settings.chromeTheme == .standard
            ? Color(nsColor: .windowBackgroundColor)
            : Color(nsColor: settings.chromeTheme.canvas(dark: dark))
    }

    private var accent: Color {
        settings.chromeTheme == .standard
            ? Color.accentColor
            : Color(nsColor: settings.chromeTheme.accent(dark: dark))
    }

    private func errorPane(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Page didn't load", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Reload") {
                model.perform(.reload)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(canvas)
    }

    private var launchCover: some View {
        canvas
            .overlay {
                VStack(spacing: 16) {
                    ZStack {
                        Capsule()
                            .frame(width: 7, height: 44)
                            .rotationEffect(.degrees(40))
                        Capsule()
                            .frame(width: 7, height: 44)
                            .rotationEffect(.degrees(-40))
                    }
                    .foregroundStyle(settings.chromeTheme == .standard ? AnyShapeStyle(.primary) : AnyShapeStyle(accent))
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var hoverCapsule: some View {
        Text(model.hoverURL)
            .font(.caption)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: 480, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(10)
            .allowsHitTesting(false)
    }
}

struct WelcomeBanner: View {
    @ObservedObject private var settings = XMacSettings.shared

    var body: some View {
        HStack(spacing: 12) {
            Text("Sign-in and the timeline are the real x.com page. Other links open in your browser.")
                .font(.callout)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Got it") {
                settings.showWelcome = false
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
