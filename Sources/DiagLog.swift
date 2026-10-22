import Foundation

/// Small diagnostic log (never contains typed text): ~/Library/Logs/Zakira.log
/// Capped at 512 KB: the older half is moved to Zakira.old.log, which replaces the previous one.
enum DiagLog {
    static let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Zakira.log")
    static let oldURL = url.deletingLastPathComponent().appendingPathComponent("Zakira.old.log")
    static let maxBytes = 512 * 1024

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
