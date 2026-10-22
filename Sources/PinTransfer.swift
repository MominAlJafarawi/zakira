import AppKit
import CryptoKit
import CommonCrypto
import UniformTypeIdentifiers

/// Moves pinned items to another Mac as a password-protected file (.zakirapins).
/// Format: "ZKP1" + 16-byte salt + AES-GCM box. Key = PBKDF2-SHA256(password, salt, 300 000 rounds).
enum PinTransfer {
    static let magic = Data("ZKP1".utf8)
    static let rounds: UInt32 = 300_000
    static let fileExtension = "zakirapins"

    static func deriveKey(_ password: String, salt: Data) -> SymmetricKey? {
        var out = Data(count: 32)
        let pw = Array(password.utf8)
        let status = out.withUnsafeMutableBytes { outPtr in
            salt.withUnsafeBytes { saltPtr in
                CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                                     pw.map { Int8(bitPattern: $0) }, pw.count,
                                     saltPtr.bindMemory(to: UInt8.self).baseAddress, salt.count,
                                     CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), rounds,
                                     outPtr.bindMemory(to: UInt8.self).baseAddress, 32)
            }
        }
        return status == kCCSuccess ? SymmetricKey(data: out) : nil
    }

    static func encrypt(_ entries: [Entry], password: String) -> Data? {
        var salt = Data(count: 16)
        guard salt.withUnsafeMutableBytes({ SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }) == errSecSuccess,
              let key = deriveKey(password, salt: salt),
              let json = try? JSONEncoder().encode(entries.filter { !$0.isImage }),
              let box = try? AES.GCM.seal(json, using: key),
              let combined = box.combined else { return nil }
        return magic + salt + combined
    }

    /// nil = wrong password or not a Zakira file.
    static func decrypt(_ data: Data, password: String) -> [Entry]? {
        guard data.count > 20, data.prefix(4) == magic else { return nil }
        let salt = data.subdata(in: 4..<20)
        guard let key = deriveKey(password, salt: salt),
              let box = try? AES.GCM.SealedBox(combined: data.subdata(in: 20..<data.count)),
              let json = try? AES.GCM.open(box, using: key) else { return nil }
        return try? JSONDecoder().decode([Entry].self, from: json)
    }

    // MARK: UI

    /// Asks for a password (twice when exporting). nil = cancelled.
    @MainActor
    static func askPassword(confirm: Bool) -> String? {
        let alert = NSAlert()
        alert.messageText = confirm ? T("كلمة سر للملف", "Password for the file") : T("كلمة سر الملف", "File password")
        alert.informativeText = confirm
            ? T("بتحتاجها لتفتح الملف على الجهاز التاني. إذا نسيتها ما في طريقة ترجّعها.",
                "You need it to open the file on the other Mac. It cannot be recovered if you forget it.")
            : T("اكتب كلمة السر اللي استعملتها وقت التصدير.", "Enter the password used when exporting.")
        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 260, height: confirm ? 58 : 24))
        stack.orientation = .vertical
        stack.spacing = 8
        let first = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        first.placeholderString = T("كلمة السر (8 أحرف على الأقل)", "Password (at least 8 characters)")
        let second = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        second.placeholderString = T("أعد كتابتها", "Repeat it")
        stack.addArrangedSubview(first)
        if confirm { stack.addArrangedSubview(second) }
        alert.accessoryView = stack
        alert.addButton(withTitle: T("تمام", "OK"))
        alert.addButton(withTitle: T("إلغاء", "Cancel"))
        alert.window.initialFirstResponder = first
        NSApp.activate(ignoringOtherApps: true)
        while alert.runModal() == .alertFirstButtonReturn {
            let pw = first.stringValue
            if confirm && pw.count < 8 {
                alert.informativeText = T("كلمة السر لازم تكون 8 أحرف على الأقل.", "The password must be at least 8 characters.")
            } else if confirm && pw != second.stringValue {
                alert.informativeText = T("الكلمتين مش متطابقتين.", "The passwords don't match.")
            } else {
                return pw
            }
        }
        return nil
    }

    @MainActor
    static func exportPinned() {
        let pinned = AppState.shared.pinned
        guard !pinned.isEmpty else { return info(T("ما في جمل مثبتة للتصدير.", "There is no pinned text to export.")) }
        guard let pw = askPassword(confirm: true) else { return }
        guard let data = encrypt(pinned, password: pw) else { return info(T("صار خطأ بالتشفير.", "Encryption failed.")) }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Zakira Pinned.\(fileExtension)"
        panel.allowedContentTypes = [UTType(filenameExtension: fileExtension) ?? .data]
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url)
            info(T("تم تصدير \(pinned.count) جملة مثبتة.", "Exported \(pinned.count) pinned items."))
        } catch {
            info(T("ما قدرت أحفظ الملف.", "Could not save the file."))
        }
    }

    @MainActor
    static func importPinned() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: fileExtension) ?? .data]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else { return }
        guard let pw = askPassword(confirm: false) else { return }
        guard let entries = decrypt(data, password: pw) else {
            return info(T("كلمة السر غلط، أو الملف مش من Zakira.", "Wrong password, or not a Zakira file."))
        }
        let st = AppState.shared
        var added = 0
        for var e in entries where !st.pinned.contains(where: { $0.text == e.text }) {
            e.id = UUID()
            st.pinned.append(e)
            added += 1
        }
        info(T("انضاف \(added) جملة مثبتة.", "Added \(added) pinned items."))
    }

    @MainActor
    private static func info(_ text: String) {
        let a = NSAlert()
        a.messageText = text
        a.addButton(withTitle: T("تمام", "OK"))
        a.runModal()
    }
}
