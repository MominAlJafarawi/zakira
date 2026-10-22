import Foundation
import CryptoKit
import UniformTypeIdentifiers

/// AES-GCM encryption with keys kept in the Keychain (one key per purpose).
enum Vault {
    private static var keys: [String: SymmetricKey] = [:]

    /// nil when the Keychain cannot be read: then nothing is saved rather than saving it in the clear.
    static func key(_ account: String) -> SymmetricKey? {
        if let k = keys[account] { return k }
        switch SecureStore.read(account) {
        case .found(let data) where data.count == 32:
            keys[account] = SymmetricKey(data: data)
        case .notFound:
            let k = SymmetricKey(size: .bits256)
            let data = k.withUnsafeBytes { Data($0) }
            guard SecureStore.write(data, account: account) else { return nil }
            keys[account] = k
        default:
            DiagLog.write("encryption key unavailable (\(account))")
            return nil
        }
        return keys[account]
    }

    static func seal(_ plain: Data, account: String) -> Data? {
        guard let k = key(account), let box = try? AES.GCM.seal(plain, using: k) else { return nil }
        return box.combined
    }

    static func open(_ sealed: Data, account: String) -> Data? {
        guard let k = key(account), let box = try? AES.GCM.SealedBox(combined: sealed) else { return nil }
        return try? AES.GCM.open(box, using: k)
    }
}

/// Clipboard screenshots are stored encrypted, so other apps, backups or a copied folder cannot open them.
enum ShotCrypto {
    static let fileExtension = "zshot"
    static func seal(_ plain: Data) -> Data? { Vault.seal(plain, account: "shots-key") }
    static func open(_ sealed: Data) -> Data? { Vault.open(sealed, account: "shots-key") }
}

extension Shot {
    var isEncrypted: Bool { url.pathExtension == ShotCrypto.fileExtension }

    /// The image bytes (decrypted when needed).
    func imageData() -> Data? {
        guard let raw = try? Data(contentsOf: url) else { return nil }
        return isEncrypted ? ShotCrypto.open(raw) : raw
    }

    /// For "Open in Preview": encrypted shots get a short-lived private copy that is deleted after 2 minutes.
    func viewableURL() -> URL? {
        guard isEncrypted else { return url }
        guard let data = imageData() else { return nil }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Zakira-view", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let tmp = dir.appendingPathComponent("Screenshot \(Int(date.timeIntervalSince1970)).png")
        guard FileManager.default.createFile(atPath: tmp.path, contents: data, attributes: [.posixPermissions: 0o600]) else { return nil }
        DispatchQueue.main.asyncAfter(deadline: .now() + 120) { try? FileManager.default.removeItem(at: tmp) }
        return tmp
    }

    func dragProvider() -> NSItemProvider {
        if !isEncrypted, let p = NSItemProvider(contentsOf: url) { return p }
        guard let data = imageData() else { return NSItemProvider() }
        return NSItemProvider(item: data as NSData, typeIdentifier: UTType.png.identifier)
    }
}
