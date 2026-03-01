import Foundation
import Foundation
import AuthenticationServices
import SwiftUI
import OSLog

private let log = Logger(subsystem: "com.krushn.notes", category: "AuthManager")


// MARK: - AuthManager

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var userId: String = ""

    private init() {
        // Restore session on launch
        if let token = Keychain.loadToken(), !token.isEmpty {
            decodeToken(token)
        }
    }

    // MARK: - GitHub OAuth via ASWebAuthenticationSession

    func loginWithGitHub(presentationAnchor: ASPresentationAnchor) async {
        guard let authURL = URL(string: "\(APIClient.shared.baseURL)/auth/github") else { return }
        let callbackScheme = "krushnnotes"

        await withCheckedContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                guard let self else {
                    continuation.resume()
                    return
                }

                if let error {
                    log.error("Auth session error: \(error.localizedDescription)")
                    continuation.resume()
                    return
                }

                guard let callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let token = components.queryItems?.first(where: { $0.name == "token" })?.value
                else {
                    log.error("Invalid callback URL: \(String(describing: callbackURL))")
                    continuation.resume()
                    return
                }

                Task { @MainActor in
                    Keychain.saveToken(token)
                    self.decodeToken(token)
                    continuation.resume()
                }
            }

            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = PresentationContextProvider(anchor: callbackScheme == "krushnnotes" ? presentationAnchor : presentationAnchor)
            session.start()
        }
    }

    func logout() {
        Keychain.deleteToken()
        isAuthenticated = false
        userId = ""
        PusherManager.shared.disconnect()
    }

    // MARK: - JWT decode (payload only, no verification — server validates)

    private func decodeToken(_ token: String) {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return }

        var base64 = String(parts[1])
        // Base64url → Base64
        base64 = base64
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padLength = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: padLength)

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else { return }

        // Check expiry
        if let exp = json["exp"] as? TimeInterval {
            if Date(timeIntervalSince1970: exp) < .now {
                log.warning("JWT expired — clearing token")
                Keychain.deleteToken()
                return
            }
        }

        userId = sub
        isAuthenticated = true
        log.info("Authenticated as userId: \(sub)")
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

private final class PresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    let anchor: ASPresentationAnchor
    init(anchor: ASPresentationAnchor) { self.anchor = anchor }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor
    }
}
