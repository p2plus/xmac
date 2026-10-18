import Foundation
import WebKit
import XMacCore

@MainActor
final class DownloadCenter: NSObject, WKDownloadDelegate {
    static let shared = DownloadCenter()

    private var destinations: [ObjectIdentifier: URL] = [:]

    private override init() {
        super.init()
    }

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        guard let directory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            completionHandler(nil)
            return
        }
        let filename = DownloadName.sanitize(suggestedFilename)
        let destination = uniqueDestination(in: directory, filename: filename)
        destinations[ObjectIdentifier(download)] = destination
        completionHandler(destination)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let url = destinations.removeValue(forKey: ObjectIdentifier(download)) else { return }
        Task { @MainActor in
            NotificationBridge.shared.post(
                title: String(localized: "Download", comment: "Notification title when a file finishes"),
                body: url.lastPathComponent,
                tag: url.path,
                fileURL: url
            )
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        destinations.removeValue(forKey: ObjectIdentifier(download))
        let body = error.localizedDescription
        let tag = UUID().uuidString
        Task { @MainActor in
            NotificationBridge.shared.post(
                title: String(localized: "Download failed", comment: "Notification title when a file fails"),
                body: body,
                tag: tag,
                fileURL: nil
            )
        }
    }

    private func uniqueDestination(in directory: URL, filename: String) -> URL {
        let primary = directory.appendingPathComponent(filename)
        if !FileManager.default.fileExists(atPath: primary.path) {
            return primary
        }
        let file = filename as NSString
        let ext = file.pathExtension
        let stem = file.deletingPathExtension
        var index = 2
        while index < 10_000 {
            let next = ext.isEmpty ? "\(stem)-\(index)" : "\(stem)-\(index).\(ext)"
            let url = directory.appendingPathComponent(next)
            if !FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            index += 1
        }
        let token = UUID().uuidString
        let fallback = ext.isEmpty ? "\(stem)-\(token)" : "\(stem)-\(token).\(ext)"
        return directory.appendingPathComponent(fallback)
    }
}
