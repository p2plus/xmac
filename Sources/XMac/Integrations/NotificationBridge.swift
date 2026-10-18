import AppKit
import Foundation
import UserNotifications
import XMacCore

final class NotificationBridge: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationBridge()

    @MainActor private static var recent: [String: Date] = [:]
    private static let dedupeWindow: TimeInterval = 8

    private override init() {
        super.init()
    }

    func start() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func post(title: String, body: String, tag: String, fileURL: URL? = nil) {
        guard !title.isEmpty || !body.isEmpty else { return }
        Task { @MainActor in
            NotificationBridge.deliver(title: title, body: body, tag: tag, fileURL: fileURL)
        }
    }

    @objc nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    @objc nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let path = response.notification.request.content.userInfo["file"] as? String
        Task { @MainActor in
            if let path, !path.isEmpty {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            } else {
                WindowRegistry.shared.open(AppRoute.notifications.url)
                NSApp.activate(ignoringOtherApps: true)
            }
            completionHandler()
        }
    }

    @MainActor
    private static func deliver(title: String, body: String, tag: String, fileURL: URL?) {
        guard XMacSettings.shared.nativeNotifications else { return }
        let now = Date()
        recent = recent.filter { now.timeIntervalSince($0.value) < dedupeWindow }
        let key = tag.isEmpty ? "\(title)|\(body)" : tag
        if recent[key] != nil { return }
        recent[key] = now

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let path = fileURL?.path {
            content.userInfo["file"] = path
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
