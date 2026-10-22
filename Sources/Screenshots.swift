import AppKit
import ImageIO

/// Finds the latest screenshots (Cmd+Shift+3/4/5) through Spotlight, wherever they are saved.
/// Read only: it never moves or deletes a file.
@MainActor
final class ScreenshotWatcher {
    static let shared = ScreenshotWatcher()
    private let query = NSMetadataQuery()
    private let state = AppState.shared
    private var spotlightShots: [Shot] = []
    /// Screenshots found by watching the save folder directly (works without Spotlight).
    private var watchedShots: [Shot] = []
    private var folderSource: DispatchSourceFileSystemObject?
    private var watchedFolder: URL?
    private var cleanupTimer: Timer?

    /// Folder for screenshots that only went to the clipboard. Only the newest few are kept.
    static let folder: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Zakira/Clipboard Screenshots", isDirectory: true)
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        // Only this Mac user can open these folders.
        try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.deletingLastPathComponent().path)
        return dir
    }()

    func saveClipboardShot(_ png: Data) {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let url = Self.folder.appendingPathComponent("Clipboard Screenshot \(f.string(from: Date())).\(ShotCrypto.fileExtension)")
        guard let sealed = ShotCrypto.seal(png) else {
            DiagLog.write("clipboard shot not saved: encryption unavailable")
            return
        }
        guard FileManager.default.createFile(atPath: url.path, contents: sealed, attributes: [.posixPermissions: 0o600]) else {
            DiagLog.write("clipboard shot save failed")
            return
        }
        pruneFolder()
        publish()
    }

    private func folderShots() -> [Shot] {
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: Self.folder, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])) ?? []
        return urls.filter { ["png", ShotCrypto.fileExtension].contains($0.pathExtension.lowercased()) }.map { url in
            let d = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return Shot(url: url, date: d)
        }.sorted { $0.date > $1.date }
    }

    /// Clipboard screenshots older than a week, or beyond the newest 10, are deleted.
    /// Only files this app created are removed, never the user's own screenshots.
    static let keepDays: Double = 7

    func pruneFolder() {
        let cutoff = Date().addingTimeInterval(-Self.keepDays * 24 * 3600)
        var removed = 0
        for (i, shot) in folderShots().enumerated() where i >= AppState.maxItems || shot.date < cutoff {
            if (try? FileManager.default.removeItem(at: shot.url)) != nil { removed += 1 }
        }
        if removed > 0 { DiagLog.detail("cleanup: removed \(removed) old clipboard screenshots") }
    }

    /// Clipboard screenshots saved by older versions (plain PNG) are encrypted once, then the PNG is deleted.
    private func encryptOldFiles() {
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: Self.folder, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])) ?? []
        for url in urls where url.pathExtension.lowercased() == "png" {
            guard let data = try? Data(contentsOf: url), let sealed = ShotCrypto.seal(data) else { continue }
            let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
            let dest = url.deletingPathExtension().appendingPathExtension(ShotCrypto.fileExtension)
            guard fm.createFile(atPath: dest.path, contents: sealed, attributes: [.posixPermissions: 0o600, .creationDate: created]),
                  ShotCrypto.open((try? Data(contentsOf: dest)) ?? Data()) == data else { continue }
            try? fm.removeItem(at: url)
        }
    }

    func publish() {
        var seen = Set<URL>()
        var all = (watchedShots + spotlightShots + folderShots()).filter { seen.insert($0.url.standardizedFileURL).inserted }
        all.sort { $0.date > $1.date }
        let top = Array(all.prefix(AppState.maxItems))
        if top != state.shots { state.shots = top }
    }

    func start() {
        query.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1")
        query.searchScopes = [NSMetadataQueryLocalComputerScope]
        query.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemFSCreationDateKey, ascending: false)]
        let nc = NotificationCenter.default
        for name in [Notification.Name.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate] {
            nc.addObserver(forName: name, object: query, queue: .main) { _ in
                MainActor.assumeIsolated { ScreenshotWatcher.shared.refresh() }
            }
        }
        query.start()
        watchSaveFolder()
        encryptOldFiles()
        pruneFolder()
        publish()
        // Check again every 6 hours, so old ones are cleaned even if the Mac is never restarted.
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { _ in
            MainActor.assumeIsolated {
                ScreenshotWatcher.shared.watchSaveFolder()   // the user may have changed the location
                ScreenshotWatcher.shared.pruneFolder()
                ScreenshotWatcher.shared.publish()
            }
        }
    }

    /// Where macOS saves screenshots: the "location" setting, or the Desktop.
    static func saveFolder() -> URL {
        if let loc = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"), !loc.isEmpty {
            let url = URL(fileURLWithPath: (loc as NSString).expandingTildeInPath, isDirectory: true)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue { return url }
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
    }

    /// macOS marks every screenshot file with this attribute.
    static func isScreenshotFile(_ url: URL) -> Bool {
        getxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, 0) >= 0
    }

    func watchSaveFolder() {
        let folder = Self.saveFolder()
        if folder != watchedFolder {
            folderSource?.cancel()
            folderSource = nil
            watchedFolder = folder
            let fd = open(folder.path, O_EVTONLY)
            if fd >= 0 {
                let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
                src.setEventHandler {
                    MainActor.assumeIsolated { ScreenshotWatcher.shared.scanSaveFolder() }
                }
                src.setCancelHandler { close(fd) }
                src.resume()
                folderSource = src
            } else {
                DiagLog.write("cannot watch screenshot folder")
            }
        }
        scanSaveFolder()
    }

    func scanSaveFolder() {
        guard let folder = watchedFolder else { return }
        let keys: [URLResourceKey] = [.creationDateKey, .isRegularFileKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        let images: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "pdf"]
        let shots = urls
            .filter { images.contains($0.pathExtension.lowercased()) && Self.isScreenshotFile($0) }
            .map { Shot(url: $0, date: (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast) }
            .sorted { $0.date > $1.date }
        watchedShots = Array(shots.prefix(AppState.maxItems))
        publish()
    }

    private func refresh() {
        query.disableUpdates()
        defer { query.enableUpdates() }
        var result: [Shot] = []
        for i in 0..<query.resultCount {
            guard let item = query.result(at: i) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else { continue }
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let date = item.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date ?? .distantPast
            result.append(Shot(url: url, date: date))
            if result.count == AppState.maxItems { break }
        }
        spotlightShots = result
        publish()
    }
}

/// Small, cached thumbnails so the popover stays fast.
@MainActor
enum Thumbnails {
    private static var cache: [URL: NSImage] = [:]

    static func image(for shot: Shot) -> NSImage? {
        let url = shot.url
        if let img = cache[url] { return img }
        guard let data = shot.imageData(), let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 520,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        cache[url] = img
        return img
    }
}
