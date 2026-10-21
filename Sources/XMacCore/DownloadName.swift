import Foundation

public enum DownloadName {
    /// A single path component. Slashes, controls, leading dots, and bidi overrides are removed,
    /// so the name cannot pose as a path or read backwards in Finder.
    public static func sanitize(_ suggested: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:?%*|\"<>\\")
            .union(.newlines)
            .union(.controlCharacters)
            .union(CharacterSet(charactersIn: "\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}\u{2066}\u{2067}\u{2068}\u{2069}"))
        let scalars = suggested.unicodeScalars.filter { !forbidden.contains($0) }
        var name = String(String.UnicodeScalarView(scalars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        while name.first == "." {
            name.removeFirst()
        }
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name == "." || name == ".." {
            return "Download"
        }
        if name.count > 180 {
            let file = name as NSString
            let ext = file.pathExtension
            if !ext.isEmpty, ext.count < 16, name.count > ext.count + 1 {
                let stem = String(file.deletingPathExtension.prefix(180 - ext.count - 1))
                name = stem.isEmpty ? String(name.prefix(180)) : "\(stem).\(ext)"
            } else {
                name = String(name.prefix(180))
            }
            name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            while name.first == "." {
                name.removeFirst()
            }
            if name.isEmpty || name == "." || name == ".." {
                return "Download"
            }
        }
        return name
    }
}
