import Foundation
import Security

/// A deliberately device-local guest identity. Keychain survives a normal
/// app reinstall, unlike SwiftData and UserDefaults, so a guest can restore
/// their synced progress without being asked to create an account.
public struct GuestIdentityStore: Sendable {
    private let service: String
    private let account = "guest-user-id"

    public init(service: String = Bundle.main.bundleIdentifier ?? "com.knightspace.wordloop") {
        self.service = service
    }

    public func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let userID = String(data: data, encoding: .utf8),
              UUID(uuidString: userID) != nil else { return nil }
        return userID.lowercased()
    }

    public func save(_ userID: String) {
        guard UUID(uuidString: userID) != nil else { return }
        let data = Data(userID.lowercased().utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            var newItem = query
            attributes.forEach { newItem[$0.key] = $0.value }
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }
}
