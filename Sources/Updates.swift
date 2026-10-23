import AppKit

/// Updates: a button that opens the Releases page in the browser (the app itself does not connect),
/// plus an optional weekly check (off by default) that only asks GitHub for the latest version number.
@MainActor
final class Updates: ObservableObject {
    static let shared = Updates()
    static let releasesPage = URL(string: "https://github.com/MominAlJafarawi/zakira/releases/latest")!
    static let api = URL(string: "https://api.github.com/repos/MominAlJafarawi/zakira/releases/latest")!

    @Published var available: String?
    @Published var autoCheck = UserDefaults.standard.bool(forKey: "autoUpdateCheck") {
        didSet {
            UserDefaults.standard.set(autoCheck, forKey: "autoUpdateCheck")
            if autoCheck { checkIfDue(force: true) } else { available = nil }
        }
    }
    private var timer: Timer?

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    func openReleases() {
        NSWorkspace.shared.open(Self.releasesPage)
    }

    func start() {
        checkIfDue(force: false)
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { _ in
            MainActor.assumeIsolated { Updates.shared.checkIfDue(force: false) }
        }
    }

    func checkIfDue(force: Bool) {
        guard autoCheck else { return }
        let last = UserDefaults.standard.object(forKey: "lastUpdateCheck") as? Date ?? .distantPast
        guard force || Date().timeIntervalSince(last) > 7 * 24 * 3600 else { return }
        UserDefaults.standard.set(Date(), forKey: "lastUpdateCheck")
        // No cookies, no cache, no data about you: one plain request for the version number.
        let session = URLSession(configuration: .ephemeral)
        var req = URLRequest(url: Self.api, timeoutInterval: 15)
        req.setValue("Zakira", forHTTPHeaderField: "User-Agent")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        session.dataTask(with: req) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else { return }
            let latest = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    Updates.shared.available = Updates.isNewer(latest, than: Updates.currentVersion) ? latest : nil
                }
            }
        }.resume()
    }

    /// "3.0.1" > "2.9.5"
    nonisolated static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
