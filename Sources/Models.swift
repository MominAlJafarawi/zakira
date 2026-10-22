import AppKit
import ServiceManagement

struct Entry: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var appName: String
    var bundleID: String?
    var date: Date

    /// true when the first strong letter is Arabic/Hebrew, so the card is shown right-to-left
    var isRTL: Bool {
        for s in text.unicodeScalars {
            let v = s.value
            if (0x0590...0x08FF).contains(v) || (0xFB1D...0xFDFF).contains(v) || (0xFE70...0xFEFF).contains(v) { return true }
            if s.properties.isAlphabetic { return false }
        }
        return false
    }
}

struct ExcludedApp: Identifiable, Codable, Hashable {
    var id: String { bundleID }
    var bundleID: String
    var name: String
}

struct Shot: Identifiable, Equatable {
    var id: URL { url }
    var url: URL
    var date: Date
}

enum Tab: Int, CaseIterable {
    case typed, copied, pinned, shots, drafts

    /// Tabs shown in the top bar; "drafts" lives inside the typed tab.
    static let bar: [Tab] = [.typed, .copied, .pinned, .shots]

    var title: String {
        switch self {
        case .typed: return T("كتبتها", "Typed")
        case .copied: return T("نسختها", "Copied")
        case .pinned: return T("مثبتة", "Pinned")
        case .shots: return T("لقطات", "Shots")
        case .drafts: return T("بدون إنتر", "Unsent")
        }
    }

    var icon: String {
        switch self {
        case .typed: return "pencil.line"
        case .copied: return "doc.on.clipboard"
        case .pinned: return "pin.fill"
        case .shots: return "camera.viewfinder"
        case .drafts: return "text.cursor"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    static let maxItems = 10

    // History lives in memory only and is gone when the app quits.
    @Published var typed: [Entry] = []
    @Published var drafts: [Entry] = []
    @Published var copied: [Entry] = []
    @Published var shots: [Shot] = []

    // Pinned items are saved encrypted in the Keychain; settings in the normal preferences file.
    @Published var pinned: [Entry] = [] { didSet { savePinned() } }
    @Published var excluded: [ExcludedApp] = [] { didSet { save(excluded, key: "excluded") } }
    /// Apps where Enter means a new line (documents, notes, code): text is saved as unsent when you leave.
    @Published var longForm: [ExcludedApp] = [] { didSet { save(longForm, key: "longForm") } }
    /// Read the final text from the field (Accessibility permission).
    @Published var highAccuracy = UserDefaults.standard.bool(forKey: "highAccuracy") {
        didSet { UserDefaults.standard.set(highAccuracy, forKey: "highAccuracy") }
    }

    static let defaultLongForm: [ExcludedApp] = [
        ExcludedApp(bundleID: "com.apple.Notes", name: "Notes"),
        ExcludedApp(bundleID: "com.apple.TextEdit", name: "TextEdit"),
        ExcludedApp(bundleID: "com.apple.iWork.Pages", name: "Pages"),
        ExcludedApp(bundleID: "com.microsoft.Word", name: "Microsoft Word"),
        ExcludedApp(bundleID: "com.microsoft.VSCode", name: "Visual Studio Code"),
        ExcludedApp(bundleID: "com.apple.dt.Xcode", name: "Xcode"),
        ExcludedApp(bundleID: "com.sublimetext.4", name: "Sublime Text"),
        ExcludedApp(bundleID: "md.obsidian", name: "Obsidian"),
        ExcludedApp(bundleID: "notion.id", name: "Notion"),
    ]

    func isLongForm(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return longForm.contains { $0.bundleID == bundleID }
    }
    @Published var paused = false {
        didSet {
            UserDefaults.standard.set(paused, forKey: "paused")
            onPauseChanged?()
        }
    }

    @Published var captureActive = false
    @Published var launchAtLogin = LoginItem.isEnabled

    var onPauseChanged: (() -> Void)?
    /// pasteboard change made by this app, so it is not recorded as a new copy
    var ownChangeCount = -1

    static let defaultExcluded: [ExcludedApp] = [
        ExcludedApp(bundleID: "com.apple.Passwords", name: "Passwords"),
        ExcludedApp(bundleID: "com.apple.keychainaccess", name: "Keychain Access"),
        ExcludedApp(bundleID: "com.1password.1password", name: "1Password"),
        ExcludedApp(bundleID: "com.agilebits.onepassword7", name: "1Password 7"),
        ExcludedApp(bundleID: "com.bitwarden.desktop", name: "Bitwarden"),
    ] + terminalApps

    /// Terminals don't block the keyboard when sudo asks for the Mac password, so they are excluded by default.
    static let terminalApps: [ExcludedApp] = [
        ExcludedApp(bundleID: "com.apple.Terminal", name: "Terminal"),
        ExcludedApp(bundleID: "com.googlecode.iterm2", name: "iTerm"),
        ExcludedApp(bundleID: "dev.warp.Warp-Stable", name: "Warp"),
        ExcludedApp(bundleID: "com.mitchellh.ghostty", name: "Ghostty"),
    ]

    private init() {
        pinned = loadPinned()
        if UserDefaults.standard.object(forKey: "excluded") == nil {
            excluded = Self.defaultExcluded
        } else {
            excluded = load([ExcludedApp].self, key: "excluded") ?? Self.defaultExcluded
        }
        paused = UserDefaults.standard.bool(forKey: "paused")
        longForm = UserDefaults.standard.object(forKey: "longForm") == nil
            ? Self.defaultLongForm
            : (load([ExcludedApp].self, key: "longForm") ?? Self.defaultLongForm)
        if !UserDefaults.standard.bool(forKey: "terminalsExcluded") {
            for t in Self.terminalApps where !excluded.contains(where: { $0.bundleID == t.bundleID }) {
                excluded.append(t)
            }
            UserDefaults.standard.set(true, forKey: "terminalsExcluded")
        }
    }

    // MARK: persistence

    private var unreadableKeys: Set<String> = []
    /// true when the Keychain could not be read: then nothing is written, so saved items are never overwritten.
    private var pinnedLocked = false

    private func loadPinned() -> [Entry] {
        // Demo mode (README screenshots): never touch the real Keychain.
        if ProcessInfo.processInfo.environment["ZAKIRA_DEMO"] != nil { pinnedLocked = true; return [] }
        switch SecureStore.read("pinned") {
        case .found(let data):
            if let list = try? JSONDecoder().decode([Entry].self, from: data) {
                DiagLog.detail("pinned loaded from keychain count=\(list.count)")
                return list
            }
            pinnedLocked = true
            DiagLog.write("pinned in keychain unreadable, kept untouched")
            return []
        case .failed(let status):
            pinnedLocked = true
            DiagLog.write("keychain read failed status=\(status), pinned kept untouched")
            return []
        case .notFound:
            // First run with encryption: move plain-text pinned items into the Keychain.
            let sources: [UserDefaults?] = [UserDefaults.standard]
            for src in sources {
                guard let src, let data = src.data(forKey: "pinned"),
                      let list = try? JSONDecoder().decode([Entry].self, from: data) else { continue }
                if SecureStore.write(data, account: "pinned"),
                   case .found(let back) = SecureStore.read("pinned"), back == data {
                    src.removeObject(forKey: "pinned")
                    DiagLog.detail("migrated \(list.count) pinned items to keychain")
                    return list
                }
                pinnedLocked = true
                return list
            }
            return []
        }
    }

    private func savePinned() {
        guard !pinnedLocked, let data = try? JSONEncoder().encode(pinned) else {
            DiagLog.write("pinned save skipped locked=\(pinnedLocked)")
            return
        }
        let ok = SecureStore.write(data, account: "pinned")
        DiagLog.detail("pinned saved count=\(pinned.count) ok=\(ok)")
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        if let value = try? JSONDecoder().decode(type, from: data) { return value }
        // Never overwrite saved data that could not be read: keep a backup copy first.
        UserDefaults.standard.set(data, forKey: "\(key)_backup_\(Int(Date().timeIntervalSince1970))")
        unreadableKeys.insert(key)
        return nil
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: history

    func isExcluded(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return excluded.contains { $0.bundleID == bundleID }
    }

    func addTyped(_ text: String, app: NSRunningApplication?) {
        guard let safe = Sensitive.filter(text) else { return }
        insert(makeEntry(safe, app), into: &typed)
    }

    func upsertDraft(id: UUID, text: String, app: NSRunningApplication?) {
        guard let safe = Sensitive.filter(text) else {
            removeDraft(id: id)
            return
        }
        var e = makeEntry(safe, app)
        e.id = id
        drafts.removeAll { $0.id == id || $0.text == safe }
        drafts.insert(e, at: 0)
        if drafts.count > Self.maxItems { drafts.removeLast(drafts.count - Self.maxItems) }
    }

    func removeDraft(id: UUID) {
        drafts.removeAll { $0.id == id }
    }

    func addCopied(_ text: String, app: NSRunningApplication?) {
        guard let safe = Sensitive.filter(text) else { return }
        insert(makeEntry(safe, app), into: &copied)
    }

    private func makeEntry(_ text: String, _ app: NSRunningApplication?) -> Entry {
        Entry(text: text, appName: app?.localizedName ?? T("برنامج", "App"), bundleID: app?.bundleIdentifier, date: Date())
    }

    private func insert(_ entry: Entry, into list: inout [Entry]) {
        list.removeAll { $0.text == entry.text }
        list.insert(entry, at: 0)
        if list.count > Self.maxItems { list.removeLast(list.count - Self.maxItems) }
    }

    func isPinned(_ entry: Entry) -> Bool {
        pinned.contains { $0.text == entry.text }
    }

    func togglePin(_ entry: Entry) {
        if isPinned(entry) {
            pinned.removeAll { $0.text == entry.text }
        } else {
            var copy = entry
            copy.id = UUID()
            pinned.insert(copy, at: 0)
        }
    }

    func delete(_ entry: Entry, from tab: Tab) {
        switch tab {
        case .typed: typed.removeAll { $0.id == entry.id }
        case .copied: copied.removeAll { $0.id == entry.id }
        case .pinned: pinned.removeAll { $0.id == entry.id }
        case .shots: break
        case .drafts: drafts.removeAll { $0.id == entry.id }
        }
    }

    func items(for tab: Tab) -> [Entry] {
        switch tab {
        case .typed: return typed
        case .copied: return copied
        case .pinned: return pinned
        case .shots: return []
        case .drafts: return drafts
        }
    }

    func count(for tab: Tab) -> Int {
        tab == .shots ? shots.count : items(for: tab).count
    }

    func copyImage(_ shot: Shot) {
        let pb = NSPasteboard.general
        pb.clearContents()
        var objects: [NSPasteboardWriting] = []
        // Encrypted shots are copied as image data only, never as a file path.
        if !shot.isEncrypted { objects.append(shot.url as NSURL) }
        if let data = shot.imageData(), let img = NSImage(data: data) { objects.append(img) }
        pb.writeObjects(objects)
        ownChangeCount = pb.changeCount
    }

    func clearHistory() {
        typed.removeAll()
        drafts.removeAll()
        copied.removeAll()
    }

    func copyToPasteboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        ownChangeCount = pb.changeCount
    }

    func setLaunchAtLogin(_ on: Bool) {
        LoginItem.set(on)
        launchAtLogin = LoginItem.isEnabled
    }
}

@MainActor
final class UIState: ObservableObject {
    @Published var tab: Tab = .typed { didSet { selected = 0 } }
    @Published var search = "" { didSet { selected = 0 } }
    @Published var selected = 0
    @Published var showSettings = false
    @Published var flashID: UUID?
    @Published var flashURL: URL?

    func visibleItems(_ state: AppState) -> [Entry] {
        let all = state.items(for: tab)
        let q = search.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return all }
        return all.filter { $0.text.localizedCaseInsensitiveContains(q) || $0.appName.localizedCaseInsensitiveContains(q) }
    }

    func reset() {
        search = ""
        selected = 0
        showSettings = false
        flashID = nil
        flashURL = nil
    }
}
