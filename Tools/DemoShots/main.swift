// Renders the README screenshots with made-up demo text (no real user data).
// Run: Tools/make-screenshots.sh
import AppKit
import SwiftUI

let outDir = CommandLine.arguments[1]
let tmpDir = CommandLine.arguments[2]

func png(_ rep: NSBitmapImageRep, _ path: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

/// Fake "screenshots" for the Screenshots tab: simple drawn mockups.
func makeFakeShot(_ i: Int, _ path: String) {
    let w: CGFloat = 1200, h: CGFloat = 760
    let img = NSImage(size: NSSize(width: w, height: h))
    img.lockFocus()
    let palettes: [[NSColor]] = [
        [.systemIndigo, .systemPurple], [.systemTeal, .systemBlue], [.systemOrange, .systemPink],
        [.systemGreen, .systemTeal], [.systemPink, .systemPurple], [.systemBlue, .systemIndigo]]
    let p = palettes[i % palettes.count]
    NSColor(white: 0.97, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: w, height: h).fill()
    // window bar
    NSColor(white: 0.9, alpha: 1).setFill(); NSRect(x: 0, y: h - 56, width: w, height: 56).fill()
    for (k, c) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
        c.setFill(); NSBezierPath(ovalIn: NSRect(x: 24 + CGFloat(k) * 30, y: h - 38, width: 18, height: 18)).fill()
    }
    // hero card
    let card = NSBezierPath(roundedRect: NSRect(x: 60, y: h - 300, width: w - 120, height: 200), xRadius: 24, yRadius: 24)
    NSGradient(colors: p)!.draw(in: card, angle: -20)
    // bars
    for k in 0..<8 {
        let bh = CGFloat(60 + (k * 37 + i * 53) % 260)
        let r = NSBezierPath(roundedRect: NSRect(x: 80 + CGFloat(k) * 130, y: 70, width: 80, height: bh), xRadius: 12, yRadius: 12)
        p[k % 2].withAlphaComponent(0.75).setFill(); r.fill()
    }
    // text lines
    NSColor(white: 0.8, alpha: 1).setFill()
    for k in 0..<3 { NSBezierPath(roundedRect: NSRect(x: 60, y: h - 360 - CGFloat(k) * 28, width: CGFloat(700 - k * 160), height: 14), xRadius: 7, yRadius: 7).fill() }
    img.unlockFocus()
    png(NSBitmapImageRep(data: img.tiffRepresentation!)!, path)
}

/// Puts a rendered panel on a soft brand background, with rounded corners and a shadow.
func compose(_ panel: NSBitmapImageRep, dark: Bool, path: String) {
    let pw = CGFloat(panel.pixelsWide), ph = CGFloat(panel.pixelsHigh)
    let pad: CGFloat = 70
    let W = pw + pad * 2, H = ph + pad * 2
    let out = NSImage(size: NSSize(width: W, height: H))
    out.lockFocus()
    let bg = dark ? [NSColor(red: 0.10, green: 0.10, blue: 0.20, alpha: 1), NSColor(red: 0.22, green: 0.13, blue: 0.35, alpha: 1)]
                  : [NSColor(red: 0.86, green: 0.88, blue: 1.0, alpha: 1), NSColor(red: 0.95, green: 0.87, blue: 1.0, alpha: 1)]
    NSGradient(colors: bg)!.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -45)
    let rect = NSRect(x: pad, y: pad, width: pw, height: ph)
    let clip = NSBezierPath(roundedRect: rect, xRadius: 26, yRadius: 26)
    NSGraphicsContext.current?.saveGraphicsState()
    let sh = NSShadow(); sh.shadowBlurRadius = 40; sh.shadowOffset = NSSize(width: 0, height: -14)
    sh.shadowColor = NSColor.black.withAlphaComponent(dark ? 0.6 : 0.25); sh.set()
    (dark ? NSColor(white: 0.12, alpha: 1) : NSColor.white).setFill(); clip.fill()
    NSGraphicsContext.current?.restoreGraphicsState()
    NSGraphicsContext.current?.saveGraphicsState()
    clip.addClip()
    NSImage(cgImage: panel.cgImage!, size: rect.size).draw(in: rect)
    NSGraphicsContext.current?.restoreGraphicsState()
    out.unlockFocus()
    let rep = NSBitmapImageRep(data: out.tiffRepresentation!)!
    png(rep, path)
}

@MainActor
func render<V: View>(_ view: V, size: NSSize, dark: Bool) -> NSBitmapImageRep {
    let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
    NSApp.appearance = appearance
    let host = NSHostingView(rootView: view
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.colorScheme, dark ? .dark : .light))
    host.appearance = appearance
    host.frame = NSRect(origin: .zero, size: size)
    let win = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
    win.contentView = host
    win.backingScaleFactor == 2 ? () : ()
    RunLoop.main.run(until: Date().addingTimeInterval(0.6))
    // render at 2x for crisp README images
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    host.cacheDisplay(in: host.bounds, to: rep)
    return rep
}

MainActor.assumeIsolated {
    _ = NSApplication.shared
    let st = AppState.shared
    st.captureActive = true
    let lang = Lang.shared
    let now = Date()
    func e(_ t: String, _ app: String, _ id: String, _ ago: Double) -> Entry {
        Entry(text: t, appName: app, bundleID: id, date: now.addingTimeInterval(-ago))
    }
    for i in 0..<4 { makeFakeShot(i, "\(tmpDir)/shot\(i).png") }
    let shots = (0..<4).map { Shot(url: URL(fileURLWithPath: "\(tmpDir)/shot\($0).png"), date: now.addingTimeInterval(Double(-$0 * 700 - 20))) }

    let actions = Actions(copy: { _ in }, copyShot: { _ in }, openPrivacy: {}, relaunch: {}, showGuide: {}, quit: {})

    @MainActor func setEnglish() {
        lang.choice = .english
        st.typed = [
            e("Meeting moved to 3 pm, see you there!", "Messages", "com.apple.MobileSMS", 30),
            e("Thanks for the quick reply. I'll send the files tonight.", "Mail", "com.apple.mail", 260),
            e("best hiking trails near lake como", "Safari", "com.apple.Safari", 900),
            e("Remember to bring the charger", "Notes", "com.apple.Notes", 2400),
        ]
        st.drafts = [e("Hey, quick question about the invoice…", "Mail", "com.apple.mail", 120)]
        st.copied = [
            e("https://github.com/MomenJafarawi/zakira", "Safari", "com.apple.Safari", 60),
            e("Order #48213 ships on Friday", "Mail", "com.apple.mail", 1500),
        ]
        st.pinned = [e("Kind regards,\nAlex", "Notes", "com.apple.Notes", 86000)]
        st.shots = shots
    }
    @MainActor func setArabic() {
        lang.choice = .arabic
        st.typed = [
            e("تمام، بكرة الساعة ١٠ بنتواصل", "Messages", "com.apple.MobileSMS", 30),
            e("شكراً على الرد السريع، ببعتلك الملفات الليلة", "Mail", "com.apple.mail", 260),
            e("أفضل مطاعم قريبة مني", "Safari", "com.apple.Safari", 900),
            e("لا تنسى تجيب الشاحن", "Notes", "com.apple.Notes", 2400),
        ]
        st.drafts = [e("مرحبا، عندي سؤال صغير عن الفاتورة…", "Mail", "com.apple.mail", 120)]
        st.copied = [
            e("https://github.com/MomenJafarawi/zakira", "Safari", "com.apple.Safari", 60),
            e("الطلب رقم 48213 بيوصل يوم الجمعة", "Mail", "com.apple.mail", 1500),
        ]
        st.pinned = [e("مع التحية،\nأحمد", "Notes", "com.apple.Notes", 86000)]
        st.shots = shots
    }

    let panelSize = NSSize(width: 380, height: 540)
    @MainActor func panel(_ name: String, tab: Tab, dark: Bool, settings: Bool = false, selected: Int = 0) {
        let ui = UIState(); ui.tab = tab; ui.selected = selected; ui.showSettings = settings
        let v = ContentView(actions: actions).environmentObject(st).environmentObject(ui).environmentObject(lang)
        compose(render(v, size: panelSize, dark: dark), dark: dark, path: "\(outDir)/\(name).png")
    }
    @MainActor func guide(_ name: String, page: Int, dark: Bool) {
        UserDefaults.standard.set(page, forKey: "onboardingPage")
        let v = OnboardingView(openPrivacy: {}, relaunch: {}, finish: {}).environmentObject(st).environmentObject(lang)
        compose(render(v, size: NSSize(width: 600, height: 520), dark: dark), dark: dark, path: "\(outDir)/\(name).png")
    }

    setEnglish()
    panel("panel-en-light", tab: .typed, dark: false, selected: 1)
    panel("panel-en-dark", tab: .typed, dark: true)
    panel("shots-en", tab: .shots, dark: false)
    panel("settings-en", tab: .typed, dark: false, settings: true)
    guide("guide-en", page: 2, dark: false)

    setArabic()
    panel("panel-ar-dark", tab: .typed, dark: true, selected: 1)
    panel("copied-ar-light", tab: .copied, dark: false)
    guide("guide-ar", page: 0, dark: true)
}
