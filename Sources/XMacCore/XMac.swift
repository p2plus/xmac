import Foundation

public enum XMac {
    public static let displayName = "X"
    public static let bundleIdentifier = "app.p2plus.xmac"
    public static let messageHandler = "xmac"
    public static let home = URL(string: "https://x.com/home")!
    /// Matches Safari 27 on this Mac so x.com serves the desktop site.
    public static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.0.1 Safari/605.1.15"

    public static func url(_ string: String) -> URL {
        URL(string: string)!
    }
}
