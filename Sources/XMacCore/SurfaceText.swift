import Foundation

public enum SurfaceText {
    /// Text that will be shown outside the page: notifications and script dialogs.
    /// Control characters and bidi overrides are removed so a page cannot spoof the prompt.
    public static func clip(_ raw: String, limit: Int) -> String {
        precondition(limit > 0)
        let scalars = raw.unicodeScalars.filter(isAllowed)
        var text = String(String.UnicodeScalarView(scalars))
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count > limit {
            text = String(text.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    public static func notification(title: String, body: String, tag: String) -> (title: String, body: String, tag: String)? {
        let cleanTitle = clip(title, limit: 120)
        let cleanBody = clip(body, limit: 280)
        let cleanTag = clip(tag, limit: 80)
        if cleanTitle.isEmpty && cleanBody.isEmpty { return nil }
        return (cleanTitle.isEmpty ? "X" : cleanTitle, cleanBody, cleanTag)
    }

    private static func isAllowed(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        if value == 0x09 || value == 0x0A || value == 0x0D { return true }
        if value < 0x20 || value == 0x7F { return false }
        if (0x202A...0x202E).contains(value) { return false }
        if (0x2066...0x2069).contains(value) { return false }
        return true
    }
}
