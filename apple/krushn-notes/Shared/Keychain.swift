import Foundation
import Security

enum Keychain {
    private static let service = "com.krushn.notes"
    private static let jwtKey = "jwt_token"

    static func saveToken(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: jwtKey,
            kSecValueData as String:   data,
            // Shared with widget via App Group keychain access group
            kSecAttrAccessGroup as String: "$(AppIdentifierPrefix)com.krushn.notes.shared"
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      jwtKey,
            kSecReturnData as String:       true,
            kSecMatchLimit as String:       kSecMatchLimitOne,
            kSecAttrAccessGroup as String:  "$(AppIdentifierPrefix)com.krushn.notes.shared"
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: jwtKey
        ]
        SecItemDelete(query as CFDictionary)
    }

    static var hasToken: Bool {
        loadToken() != nil
    }
}
