import AppKit
import Foundation
import SwiftUI

/// Arabic / English. "system" follows the Mac's first preferred language.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, arabic, english
    var id: String { rawValue }
}

@MainActor
final class Lang: ObservableObject {
    static let shared = Lang()

    /// Read by T() from anywhere; updated whenever the choice changes.
    nonisolated(unsafe) static var arabic = false

    var onChange: (() -> Void)?

    @Published var choice: AppLanguage {
        didSet {
            UserDefaults.standard.set(choice.rawValue, forKey: "language")
            Lang.arabic = Self.resolve(choice)
            onChange?()
        }
    }

    private init() {
        let saved = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .system
        choice = saved
        Lang.arabic = Self.resolve(saved)
    }

    static func resolve(_ c: AppLanguage) -> Bool {
        switch c {
        case .arabic: return true
        case .english: return false
        case .system: return Locale.preferredLanguages.first?.hasPrefix("ar") ?? false
        }
    }

    var direction: LayoutDirection { Lang.arabic ? .rightToLeft : .leftToRight }
}

/// Pick the Arabic or English text for the current language.
func T(_ ar: String, _ en: String) -> String { Lang.arabic ? ar : en }

/// "2 minutes ago" / "قبل دقيقتين"
func relativeTime(_ date: Date) -> String {
    if Date().timeIntervalSince(date) < 45 { return T("الآن", "just now") }
    let f = RelativeDateTimeFormatter()
    f.locale = Locale(identifier: Lang.arabic ? "ar@numbers=latn" : "en")
    f.unitsStyle = .full
    return f.localizedString(for: date, relativeTo: Date())
}

enum Credits {
    static let author = "Momin AlJafarawi"
    static let repo = URL(string: "https://github.com/MominAlJafarawi/zakira")!
}


/// Animations are skipped when "Reduce motion" is on in System Settings → Accessibility.
@MainActor
func motion(_ animation: Animation? = .default) -> Animation? {
    NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : animation
}

/// Tells VoiceOver something happened (e.g. "Copied").
@MainActor
func announce(_ text: String) {
    NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                         userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])
}
