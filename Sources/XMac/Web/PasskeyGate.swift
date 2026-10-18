import AuthenticationServices
import Foundation
import XMacCore

/// Asks macOS, once, for permission to let x.com use passkeys.
/// WebKit shows the passkey sheet after that. This type does not read the key.
@MainActor
enum PasskeyGate {
    private static var asked = false

    static func prepare(for url: URL?) {
        let manager = ASAuthorizationWebBrowserPublicKeyCredentialManager()
        let authorization = PasskeyAccess.Authorization(manager.authorizationStateForPlatformCredentials)
        guard PasskeyAccess.shouldRequest(url: url, authorization: authorization, alreadyAsked: asked) else { return }
        asked = true
        manager.requestAuthorizationForPublicKeyCredentials { _ in }
    }
}

private extension PasskeyAccess.Authorization {
    init(_ state: ASAuthorizationWebBrowserPublicKeyCredentialManager.AuthorizationState) {
        switch state {
        case .authorized:
            self = .authorized
        case .denied:
            self = .denied
        case .notDetermined:
            self = .notDetermined
        @unknown default:
            self = .notDetermined
        }
    }
}
