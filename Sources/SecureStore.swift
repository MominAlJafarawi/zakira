import Foundation
import Security

/// Keeps pinned items encrypted in the user's Keychain instead of a plain settings file.
enum SecureStore {
    static let service = "com.momen.zakira"

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
