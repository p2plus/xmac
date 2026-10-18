import Foundation
import WebKit

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
        let filename = sanitizedFilename(suggestedFilename)
        let destination = uniqueDestination(in: directory, filename: filename)
        destinations[ObjectIdentifier(download)] = destination
        completionHandler(destination)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let url = destinations.removeValue(forKey: ObjectIdentifier(download)) else { return }
        Task { @MainActor in
            NotificationBridge.shared.post(
                title: "Download",
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
                title: "Download failed",
                body: body,
                tag: tag,
                fileURL: nil
            )
        }
    }

    private func sanitizedFilename(_ suggested: String) -> String {
        let trimmed = suggested.trimmingCharacters(in: .whitespacesAndNewlines)
        let forbidden = CharacterSet(charactersIn: "/:?%*|\"<>")
            .union(CharacterSet(charactersIn: "\\"))
            .union(.newlines)
        let scalars = trimmed.unicodeScalars.filter { !forbidden.contains($0) }
        var name = String(String.UnicodeScalarView(scalars))
        while name.first == "." {
            name.removeFirst()
        }
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name == "." || name == ".." {
            name = "Download"
        }
        if name.count > 180 {
            name = String(name.prefix(180)).trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty || name == "." || name == ".." {
                name = "Download"
            }
        }
        return name
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
