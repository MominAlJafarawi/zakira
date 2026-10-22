import AppKit

/// Start with the Mac: a small LaunchAgent file in the user's Library (works for unsigned apps).
enum LoginItem {
    static let label = "com.momen.zakira"
    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool { FileManager.default.fileExists(atPath: plistURL.path) }

    @discardableResult
    static func set(_ on: Bool) -> Bool {
        let fm = FileManager.default
        if !on {
            try? fm.removeItem(at: plistURL)
            return !isEnabled
        }
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", "-a", Bundle.main.bundlePath],
            "RunAtLoad": true,
        ]
        do {
            try fm.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL)
            return true
        } catch {
            DiagLog.write("login item failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Keep the saved path right if the app was moved.
    static func refreshPathIfNeeded() {
        guard isEnabled,
              let dict = NSDictionary(contentsOf: plistURL) as? [String: Any],
              let args = dict["ProgramArguments"] as? [String],
              args.last != Bundle.main.bundlePath else { return }
        set(true)
    }
}

/// Moves the app into /Applications when it is opened from a USB stick, a disk image or Downloads.
enum AppMover {
    static let target = URL(fileURLWithPath: "/Applications/Zakira.app")

    static var isInApplications: Bool {
        let path = Bundle.main.bundlePath
        return path.hasPrefix("/Applications/") ||
            path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path + "/")
    }

    /// Returns an error message, or nil when the app was copied and relaunched.
    @MainActor
    static func moveAndRelaunch() -> String? {
        let fm = FileManager.default
        let source = Bundle.main.bundleURL
        do {
            if fm.fileExists(atPath: target.path) {
                // An older copy goes to the Trash, so nothing is lost for good.
                try fm.trashItem(at: target, resultingItemURL: nil)
            }
            try fm.copyItem(at: source, to: target)
        } catch {
            DiagLog.write("move to Applications failed: \(error.localizedDescription)")
            return T("ما قدرت أنقل البرنامج لحالي. اسحب Zakira بإيدك لمجلد Applications وافتحه من هناك.", "I couldn't move the app myself. Drag Zakira into the Applications folder and open it from there.")
        }
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: target, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
        return nil
    }
}
