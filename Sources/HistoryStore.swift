import Foundation

/// Optional: keeps typed, unsent and copied text after a restart, encrypted with a Keychain key.
/// Off by default. Items older than the chosen number of days are dropped on load.
/// Copied images are never written to disk.
@MainActor
enum HistoryStore {
    struct Saved: Codable {
        var typed: [Entry]
        var drafts: [Entry]
        var copied: [Entry]
    }

    static var loading = false
    private static var pending: DispatchWorkItem?

    static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Zakira/history.zhist")
    }

    static func scheduleSave() {
        guard !loading, AppState.shared.keepAfterRestart else { return }
        pending?.cancel()
        let work = DispatchWorkItem { MainActor.assumeIsolated { HistoryStore.save() } }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    static func save() {
        let st = AppState.shared
        guard st.keepAfterRestart else { return }
        let textOnly = { (list: [Entry]) in list.filter { !$0.isImage } }
        let saved = Saved(typed: textOnly(st.typed), drafts: textOnly(st.drafts), copied: textOnly(st.copied))
        guard let json = try? JSONEncoder().encode(saved), let sealed = Vault.seal(json, account: "history-key") else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        FileManager.default.createFile(atPath: url.path, contents: sealed, attributes: [.posixPermissions: 0o600])
    }

    static func load(maxAgeDays: Int) -> Saved? {
        guard let sealed = try? Data(contentsOf: url),
              let json = Vault.open(sealed, account: "history-key"),
              var saved = try? JSONDecoder().decode(Saved.self, from: json) else { return nil }
        let cutoff = Date().addingTimeInterval(-Double(maxAgeDays) * 24 * 3600)
        saved.typed.removeAll { $0.date < cutoff }
        saved.drafts.removeAll { $0.date < cutoff }
        saved.copied.removeAll { $0.date < cutoff }
        return saved
    }

    static func delete() {
        pending?.cancel()
        try? FileManager.default.removeItem(at: url)
    }
}
