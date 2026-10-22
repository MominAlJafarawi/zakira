import SwiftUI
import AppKit

/// First-run guide: 5 short pages. It comes back after a restart until "ابدأ" is pressed.
struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var lang: Lang
    @AppStorage("onboardingPage") private var page = 0
    let openPrivacy: () -> Void
    let relaunch: () -> Void
    let finish: () -> Void

    private let pageCount = 5

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch page {
                case 0: welcome
                case 1: permission
                case 2: usage
                case 3: privacy
                default: ready
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 36)
            .padding(.top, 28)
            .id(page)
            .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal: .opacity))

            footer
        }
        .frame(width: 600, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.layoutDirection, lang.direction)
        .id(lang.choice)
    }

    // MARK: pages

    private var welcome: some View {
        VStack(spacing: 16) {
            AppBadge(size: 96)
            Text(T("أهلاً بك في ذاكرة الكتابة", "Welcome to Zakira"))
                .font(.system(size: 26, weight: .bold))
            Text(T("برنامج صغير بيضل فوق بشريط المنيو، وبيحفظلك آخر الأشياء اللي كتبتها ونسختها وصوّرتها، حتى ترجعلها بكبسة.", "A small menu bar app that remembers what you recently typed, copied and captured, so you can get it back with one click."))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Picker("", selection: $lang.choice) {
                Text("العربية").tag(AppLanguage.arabic)
                Text("English").tag(AppLanguage.english)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 200)
            HStack(spacing: 12) {
                FeatureChip(icon: "pencil.line", text: T("اللي كتبته", "What you typed"))
                FeatureChip(icon: "doc.on.clipboard", text: T("اللي نسخته", "What you copied"))
                FeatureChip(icon: "camera.viewfinder", text: T("لقطات الشاشة", "Screenshots"))
                FeatureChip(icon: "pin.fill", text: T("جمل مثبتة", "Pinned text"))
            }
            .padding(.top, 6)
            HStack(spacing: 4) {
                Text(T("صنع بواسطة", "Made by"))
                Link(Credits.author, destination: Credits.repo)
            }
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }
    }

    private var permission: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageTitle(icon: "keyboard.badge.ellipsis", title: T("خطوة وحدة: إذن الكيبورد", "One step: keyboard permission"),
                      subtitle: T("حتى يحفظ البرنامج اللي بتكتبه، ماك بيطلب إذن \"Input Monitoring\". البرنامج ما بيبعت أي شي للإنترنت.", "To remember what you type, macOS needs the \"Input Monitoring\" permission. Nothing is ever sent to the internet."))
            if state.captureActive {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 26)).foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("الإذن مفعّل، كل شي تمام", "Permission granted, all set")).font(.system(size: 15, weight: .semibold))
                        Text(T("اضغط التالي.", "Click Next.")).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.1)))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    StepRow(n: 1, text: T("اضغط \"فتح الإعدادات\" تحت.", "Click \"Open Settings\" below."))
                    StepRow(n: 2, text: T("لاقي Zakira بالقائمة وشغّل الزر جنبه. إذا مش موجود: اضغط + واختار Zakira من مجلد Applications.", "Find Zakira in the list and switch it on. If it is missing, click + and choose Zakira from Applications."))
                    StepRow(n: 3, text: T("إذا ماك سألك \"Quit & Reopen\" وافق، أو ارجع هون واضغط \"إعادة التشغيل\".", "If macOS asks to \"Quit & Reopen\", accept, or come back here and click \"Restart\"."))
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.045)))
                HStack(spacing: 10) {
                    Button(action: openPrivacy) {
                        Label(T("فتح الإعدادات", "Open Settings"), systemImage: "gearshape")
                    }
                    .buttonStyle(.borderedProminent)
                    Button(T("إعادة التشغيل", "Restart"), action: relaunch)
                        .buttonStyle(.bordered)
                }
                .controlSize(.large)
                Text(T("بدون هالإذن، النسخ واللقطات بيشتغلوا عادي، بس الكتابة ما بتنحفظ.", "Without it, copies and screenshots still work, but typed text is not saved."))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var usage: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(icon: "hand.tap", title: T("كيف بتستعمله", "How to use it"),
                      subtitle: T("كل شي بيصير من لوحة وحدة.", "Everything happens in one small panel."))
            UsageRow(icon: "brain", title: T("أيقونة المخ فوق", "The brain icon"), text: T("اضغط عليها جنب الساعة لتفتح اللوحة.", "Click it in the menu bar to open the panel."))
            UsageRow(keys: HotKey.shared.display, title: T("أو من أي مكان", "Or from anywhere"),
                     text: T("اضغط \(HotKey.shared.spoken) وبتنفتح اللوحة جنب الماوس. بتقدر تغيّره من الإعدادات.",
                             "Press \(HotKey.shared.spoken) to open the panel next to your pointer. You can change it in Settings."))
            UsageRow(icon: "cursorarrow.click", title: T("كبسة = نسخ", "Click = copy"), text: T("اضغط على أي سطر أو صورة، وبعدين الصق بـ Cmd + V.", "Click any line or image, then paste with Cmd + V."))
            UsageRow(icon: "return", title: T("بالإنتر وبدون إنتر", "Sent and unsent"), text: T("اللي بعتّه بإنتر لحال، والكلام اللي تركته بدون إرسال لحال.", "Text you sent with Enter is kept apart from text you left unsent."))
            UsageRow(icon: "pin", title: T("ثبّت المهم", "Pin what matters"), text: T("مرّق الماوس على أي سطر واضغط الدبوس، وما بينمحي.", "Hover over a line and click the pin to keep it."))
            UsageRow(keys: "↑ ↓  ↩", title: T("بالكيبورد", "Keyboard"), text: T("الأسهم للتنقل، Enter للنسخ، Esc للإغلاق.", "Arrows to move, Enter to copy, Esc to close."))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageTitle(icon: "lock.shield", title: T("خصوصيتك", "Your privacy"),
                      subtitle: T("كل شي بيضل على جهازك.", "Everything stays on your Mac."))
            UsageRow(icon: "wifi.slash", title: T("ما في إنترنت", "No internet"), text: T("البرنامج ما بيتصل بأي مكان، ولا بيبعت أي بيانات.", "The app never connects anywhere and sends no data."))
            UsageRow(icon: "memorychip", title: T("الكتابة بالذاكرة بس", "Typing stays in memory"), text: T("آخر الجمل والنسخ بتنمحي لما تسكّر البرنامج.", "Recent text and copies are gone when you quit the app."))
            UsageRow(icon: "key.fill", title: T("المثبّت مشفّر", "Pinned is encrypted"), text: T("الجمل المثبتة محفوظة بالـ Keychain تبع جهازك.", "Pinned text is stored in your Mac's Keychain."))
            UsageRow(icon: "eye.slash", title: T("الباسوردات محجوبة", "Passwords are skipped"), text: T("حقول الباسوورد ما بتتسجّل، وبتقدر تستثني برامج (متل البنك) من الإعدادات.", "Password fields are never recorded, and you can exclude apps (like banking) in Settings."))
            UsageRow(icon: "camera.viewfinder", title: T("اللقطات", "Screenshots"), text: T("بيعرض لقطاتك بس. لقطات الحافظة بتنمسح لحالها بعد أسبوع.", "Your screenshots are only shown. Clipboard screenshots are deleted after a week."))
            UsageRow(icon: "pause.circle", title: T("إيقاف مؤقت", "Pause"), text: T("زر تحت باللوحة بيوقف التسجيل وقت ما بدك.", "A button in the panel stops recording whenever you want."))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @State private var moveError: String?

    private var ready: some View {
        VStack(spacing: 16) {
            AppBadge(size: 80)
            Text(T("جاهز!", "All set!")).font(.system(size: 26, weight: .bold))
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(get: { state.launchAtLogin }, set: { state.setLaunchAtLogin($0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(T("شغّلني مع بداية الجهاز", "Open at login")).font(.system(size: 14, weight: .medium))
                        Text(T("ماك ممكن يطلعلك إشعار \"Background Items Added\"، هاد طبيعي.", "macOS may show \"Background Items Added\". That is normal."))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                if !AppMover.isInApplications {
                    Divider()
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(T("البرنامج مفتوح من برا مجلد التطبيقات (فلاش أو تنزيلات).", "Zakira is running from outside Applications (USB stick or Downloads)."))
                                .font(.system(size: 13, weight: .medium))
                            Text(T("انقله حتى يضل شغّال بعد ما تشيل الفلاش.", "Move it so it keeps working after you remove the stick."))
                                .font(.system(size: 11.5)).foregroundStyle(.secondary)
                            Button(T("انقلني لمجلد التطبيقات", "Move to Applications")) {
                                moveError = AppMover.moveAndRelaunch()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            if let moveError {
                                Text(moveError).font(.system(size: 11.5)).foregroundStyle(.red)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 420)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.045)))
            Text(T("بترجع لهالدليل أي وقت من ⚙️ ← دليل الاستخدام.", "You can reopen this guide any time from ⚙️ → User guide."))
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: footer

    private var footer: some View {
        HStack {
            if page > 0 {
                Button(T("السابق", "Back")) { go(page - 1) }
                    .buttonStyle(.bordered)
            } else {
                Button(T("تخطّي", "Skip")) { finish() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 7) {
                ForEach(0..<pageCount, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Color.accentColor : Color.primary.opacity(0.15))
                        .frame(width: i == page ? 20 : 7, height: 7)
                }
            }
            Spacer()
            if page < pageCount - 1 {
                Button(T("التالي", "Next")) { go(page + 1) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button(T("ابدأ", "Start")) { finish() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .controlSize(.large)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.primary.opacity(0.03))
    }

    private func go(_ p: Int) {
        withAnimation(.easeInOut(duration: 0.25)) { page = max(0, min(pageCount - 1, p)) }
    }
}

// MARK: - Building blocks

struct AppBadge: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.36, green: 0.42, blue: 0.98), Color(red: 0.62, green: 0.33, blue: 0.95)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "brain")
                .font(.system(size: size * 0.48, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: .purple.opacity(0.35), radius: size * 0.12, y: size * 0.05)
    }
}

struct FeatureChip: View {
    let icon: String
    let text: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Color.accentColor)
            Text(text).font(.system(size: 11.5))
        }
        .frame(width: 96, height: 70)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.08)))
    }
}

struct PageTitle: View {
    let icon: String
    let title: String
    let subtitle: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.accentColor.opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 21, weight: .bold))
                Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 4)
    }
}

struct StepRow: View {
    let n: Int
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))
            Text(text).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct UsageRow: View {
    var icon: String? = nil
    var keys: String? = nil
    let title: String
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let keys {
                    Text(keys)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .environment(\.layoutDirection, .leftToRight)
                } else if let icon {
                    Image(systemName: icon).font(.system(size: 15))
                }
            }
            .foregroundStyle(Color.accentColor)
            .frame(width: 58, height: 34)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.1)))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13.5, weight: .semibold))
                Text(text).font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
