import SwiftUI
import XMacCore

struct SettingsView: View {
    @ObservedObject private var settings = XMacSettings.shared
    @State private var confirmClear = false

    var body: some View {
        Form {
            Section("Start") {
                Picker("Start page", selection: $settings.startRoute) {
                    ForEach(AppRoute.startPages) { route in
                        Text(route.title).tag(route)
                    }
                }
                Toggle("Restore the last page", isOn: $settings.restoreLastURL)
            }

            Section("Notifications") {
                Toggle("Dock badge", isOn: $settings.dockBadge)
                Toggle("Show alerts from X", isOn: $settings.nativeNotifications)
            }

            Section {
                Picker("Appearance", selection: $settings.appearance) {
                    ForEach(AppearanceChoice.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
                Picker("Theme", selection: $settings.chromeTheme) {
                    ForEach(ChromeTheme.allCases) { theme in
                        Text("\(theme.title) — \(theme.blurb)").tag(theme)
                    }
                }
                Picker("Navigation", selection: $settings.navEdge) {
                    ForEach(NavEdge.allCases) { edge in
                        Text(edge.title).tag(edge)
                    }
                }
                LabeledContent("Zoom") {
                    HStack(spacing: 8) {
                        Slider(value: $settings.pageZoom, in: 0.7...1.6, step: 0.1)
                        Text("\(Int((settings.pageZoom * 100).rounded()))%")
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                    }
                }
                Button("Actual size") {
                    settings.pageZoom = 1
                }
            } header: {
                Text("Appearance")
            } footer: {
                Text("Light and dark paint this app. x.com follows along when that account is set to the device theme.")
            }

            Section {
                Toggle("Don't autoplay videos", isOn: $settings.pauseAutoplay)
                Toggle("Don't download images", isOn: $settings.blockImages)
                Picker("Refresh", selection: $settings.refreshSeconds) {
                    ForEach(RefreshChoice.allCases) { choice in
                        Text(choice.title).tag(choice.rawValue)
                    }
                }
            } header: {
                Text("Data")
            } footer: {
                Text("The disk cache is wiped on launch and every 15 minutes. Cookies stay, so you stay signed in. Blocking images drops photos and avatars until you turn it off. Refresh reloads the open page and skips the composer.")
            }

            Section {
                Text("Sign-in lives in this app's local WebKit store. No password is saved.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Sign out and delete data", role: .destructive) {
                    confirmClear = true
                }
            } header: {
                Text("Session")
            } footer: {
                Text("Unofficial client. Not affiliated with X Corp.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .preferredColorScheme(settings.appearance.colorScheme)
        .frame(width: 560, height: 640)
        .confirmationDialog(
            "Delete the sign-in stored in this app?",
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                CommandBus.shared.send(.clearSession)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Cookies and website data for X in this app are removed. The account on x.com stays.")
        }
    }
}
