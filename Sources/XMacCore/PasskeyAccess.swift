import Foundation

/// When to ask macOS whether this app may use passkeys.
/// The private key stays in the system keychain. This decision never sees it.
public enum PasskeyAccess {
    public enum Authorization: Equatable, Sendable {
        case authorized
        case denied
        case notDetermined
    }

    /// One ask per launch, and only after an https page on x.com or twitter.com.
    public static func shouldRequest(
        url: URL?,
        authorization: Authorization,
        alreadyAsked: Bool
    ) -> Bool {
        guard !alreadyAsked, authorization == .notDetermined else { return false }
        guard let url else { return false }
        guard url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty else { return false }
        return URLClassifier.isXFamily(host: host)
    }
}
