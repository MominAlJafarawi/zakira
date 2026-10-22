import Foundation

/// Diagnostic log: ~/Library/Logs/Zakira.log. It never contains typed or copied text.
/// - write(): technical events and errors only (permission state, failures).
/// - detail(): activity details (which app, how long a text was). Only written while
///   "Diagnostic mode" is on, which switches itself off after 24 hours.
/// Capped at 512 KB: the older half is moved to Zakira.old.log, which replaces the previous one.
enum DiagLog {
    static let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Zakira.log")
    static let oldURL = url.deletingLastPathComponent().appendingPathComponent("Zakira.old.log")
    static let maxBytes = 512 * 1024
    static let diagnosticHours: Double = 24

    static var diagnosticUntil: Date? {
        get { UserDefaults.standard.object(forKey: "diagnosticUntil") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "diagnosticUntil") }
    }

    static var diagnosticOn: Bool {
        guard let until = diagnosticUntil else { return false }
        return until > Date()
    }

    static func setDiagnostic(_ on: Bool) {
        diagnosticUntil = on ? Date().addingTimeInterval(diagnosticHours * 3600) : nil
        write(on ? "diagnostic mode on for \(Int(diagnosticHours))h" : "diagnostic mode off")
    }

    static func detail(_ msg: String) {
        guard diagnosticOn else { return }
        write(msg)
    }

    /// Older versions logged app names; remove those logs once.
    static func wipeOldActivityLogs() {
        guard !UserDefaults.standard.bool(forKey: "logsWipedV3") else { return }
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: oldURL)
        UserDefaults.standard.set(true, forKey: "logsWipedV3")
    }

    static func write(_ msg: String) {
        let fm = FileManager.default
        if let size = (try? fm.attributesOfItem(atPath: url.path))?[.size] as? Int, size > maxBytes {
            try? fm.removeItem(at: oldURL)
            try? fm.moveItem(at: url, to: oldURL)
        }
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(msg)\n"
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close()
        } else {
            fm.createFile(atPath: url.path, contents: line.data(using: .utf8), attributes: [.posixPermissions: 0o600])
        }
    }
}
