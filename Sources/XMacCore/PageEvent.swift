import Foundation

public enum PageEvent: Equatable, Sendable {
    case title(String)
    case notify(title: String, body: String, tag: String)

    public static func parse(_ body: Any) -> PageEvent? {
        let fields: [String: Any]
        if let dictionary = body as? [String: Any] {
            fields = dictionary
        } else if let dictionary = body as? NSDictionary {
            var converted: [String: Any] = [:]
            for key in dictionary.allKeys {
                guard let name = key as? String else { continue }
                converted[name] = dictionary[name]
            }
            fields = converted
        } else {
            return nil
        }

        switch fields["type"] as? String {
        case "title":
            return .title(fields["title"] as? String ?? "")
        case "notify":
            let title = (fields["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let text = fields["body"] as? String ?? ""
            let tag = fields["tag"] as? String ?? ""
            if title.isEmpty && text.isEmpty { return nil }
            return .notify(title: title.isEmpty ? "X" : title, body: text, tag: tag)
        default:
            return nil
        }
    }
}
