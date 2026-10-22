import Foundation
import Security

/// Keeps pinned items encrypted in the user's Keychain instead of a plain settings file.
enum SecureStore {
    /// Tests and README screenshots (ZAKIRA_DEMO) use their own Keychain service, never the real one.
    static let service = ProcessInfo.processInfo.environment["ZAKIRA_DEMO"] != nil ? "com.momen.zakira.test" : "com.momen.zakira"

    /// Removes every item of the current service (used by the tests to clean up).
    static func deleteAll() {
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service] as CFDictionary)
    }

    enum ReadResult {
        case found(Data)
        case notFound
        case failed(OSStatus)
    }

    static func read(_ account: String) -> ReadResult {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        if status == errSecSuccess, let data = out as? Data { return .found(data) }
        if status == errSecItemNotFound { return .notFound }
        return .failed(status)
    }

    @discardableResult
    static func write(_ data: Data, account: String) -> Bool {
        let base: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        let update = SecItemUpdate(base as CFDictionary, [kSecValueData: data] as CFDictionary)
        if update == errSecSuccess { return true }
        if update == errSecItemNotFound {
            var add = base
            add[kSecValueData] = data
            add[kSecAttrLabel] = "Zakira – pinned items"
            return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
        }
        DiagLog.write("keychain write failed status=\(update)")
        return false
    }
}
