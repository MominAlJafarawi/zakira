import SwiftUI
import AppKit

struct Actions {
    var copy: (Entry) -> Void
    var copyShot: (Shot) -> Void
    var openPrivacy: () -> Void
    var relaunch: () -> Void
    var showGuide: () -> Void
    var quit: () -> Void
}

// MARK: - Root

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var ui: UIState
    @EnvironmentObject var lang: Lang
    let actions: Actions

    var body: some View {
        VStack(spacing: 0) {
            Header()
            if ui.showSettings {
                SettingsPane(actions: actions)
            } else {
                VStack(spacing: 10) {
                    if ui.tab != .shots {
                        SearchField(text: $ui.search)
                    }
                    TabBar()
                    if ui.tab == .typed || ui.tab == .drafts {
                        TypedSwitch()
                    }
                    if !state.captureActive {
                        PermissionBanner(actions: actions)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
                EntryList(actions: actions)
            }
            Footer(actions: actions)
        }
        .frame(width: 380, height: 540)
        .environment(\.layoutDirection, lang.direction)
        .id(lang.choice)
    }
}

// MARK: - Header

struct Header: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var ui: UIState

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.36, green: 0.42, blue: 0.98), Color(red: 0.62, green: 0.33, blue: 0.95)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "brain")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)
            .shadow(color: .purple.opacity(0.3), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 1) {
                Text(ui.showSettings ? T("الإعدادات", "Settings") : T("ذاكرة الكتابة", "Zakira"))
                    .font(.system(size: 15, weight: .bold))
                Text(ui.showSettings ? T("تحكّم بالبرنامج", "Preferences") : T("آخر ما كتبته ونسخته", "What you typed and copied"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if state.paused {
                Label(T("متوقف مؤقتاً", "Paused"), systemImage: "pause.fill")
                    .font(.system(size: 10.5, weight: .semibold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange.opacity(0.18)))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }
}

// MARK: - Search

struct SearchField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
            TextField(T("بحث…", "Search…"), text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($focused)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.primary.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .strokeBorder(focused ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1))
    }
}

// MARK: - Tabs

struct TabBar: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var ui: UIState
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Tab.bar, id: \.self) { tab in
                let active = ui.tab == tab || (tab == .typed && ui.tab == .drafts)
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { ui.tab = tab }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon).font(.system(size: 11, weight: .semibold))
                        Text(tab.title).font(.system(size: 12, weight: active ? .semibold : .regular))
                        let count = tab == .typed ? state.typed.count + state.drafts.count : state.count(for: tab)
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Capsule().fill(active ? Color.white.opacity(0.25) : Color.primary.opacity(0.08)))
                        }
                    }
                    .foregroundStyle(active ? Color.white : Color.primary.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background {
                        if active {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor)
                                .matchedGeometryEffect(id: "pill", in: ns)
                                .shadow(color: Color.accentColor.opacity(0.35), radius: 4, y: 2)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
    }
}

// MARK: - Typed: with Enter / without Enter

struct TypedSwitch: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var ui: UIState

    var body: some View {
        HStack(spacing: 6) {
            chip(.typed, label: T("↩ بالإنتر", "↩ Sent"), count: state.typed.count)
            chip(.drafts, label: T("بدون إنتر", "Unsent"), count: state.drafts.count)
            Spacer()
        }
    }

    private func chip(_ tab: Tab, label: String, count: Int) -> some View {
        let active = ui.tab == tab
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { ui.tab = tab }
        } label: {
            HStack(spacing: 4) {
                Text(label).font(.system(size: 11.5, weight: active ? .semibold : .regular))
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(active ? Color.accentColor : .secondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(active ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05)))
            .overlay(Capsule().strokeBorder(active ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1))
            .foregroundStyle(active ? Color.accentColor : Color.primary.opacity(0.75))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Permission

struct PermissionBanner: View {
    let actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "keyboard.badge.ellipsis")
                    .foregroundStyle(.orange)
                    .font(.system(size: 16))
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("محتاج إذن مراقبة الإدخال", "Input Monitoring permission needed"))
                        .font(.system(size: 12, weight: .semibold))
                    Text(T("فعّل البرنامج من الإعدادات ← الخصوصية ← Input Monitoring، بعدين اضغط إعادة التشغيل. النسخ (Cmd+C) شغّال من هلّق.", "Turn Zakira on in Settings → Privacy → Input Monitoring, then click Restart. Copying (Cmd+C) already works."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 8) {
                Button(T("فتح الإعدادات", "Open Settings"), action: actions.openPrivacy)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                Button(T("إعادة التشغيل", "Restart"), action: actions.relaunch)
                    .buttonStyle(.bordered)
            }
            .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.orange.opacity(0.1)))
    }
}

// MARK: - List

struct EntryList: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var ui: UIState
    let actions: Actions

    var body: some View {
        let items = ui.visibleItems(state)
        Group {
            if ui.tab == .shots ? state.shots.isEmpty : items.isEmpty {
                EmptyState(tab: ui.tab, searching: !ui.search.isEmpty)
            } else if ui.tab == .shots {
                ShotList(actions: actions)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, entry in
                                EntryCard(entry: entry,
                                          tab: ui.tab,
                                          selected: index == ui.selected,
                                          flashed: ui.flashID == entry.id,
                                          pinned: state.isPinned(entry),
                                          onCopy: { actions.copy(entry) },
                                          onPin: { withAnimation(.easeOut(duration: 0.2)) { state.togglePin(entry) } },
                                          onDelete: { withAnimation(.easeOut(duration: 0.2)) { state.delete(entry, from: ui.tab) } })
                                    .id(entry.id)
                                    .transition(.asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity),
                                                            removal: .opacity))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                    }
                    .onChange(of: ui.selected) { _, newValue in
                        if items.indices.contains(newValue) {
                            withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(items[newValue].id, anchor: .center) }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}

struct EntryCard: View {
    let entry: Entry
    let tab: Tab
    let selected: Bool
    let flashed: Bool
    let pinned: Bool
    let onCopy: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AppIcon(bundleID: entry.bundleID)
                .frame(width: 22, height: 22)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 5) {
                Text(entry.text)
                    .font(.system(size: 13.5))
                    .lineSpacing(2)
                    .lineLimit(hovering ? 8 : 2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    HStack(spacing: 4) {
                        if pinned && tab != .pinned {
                            Image(systemName: "pin.fill").font(.system(size: 8)).foregroundStyle(.orange)
                        }
                        Text(entry.appName)
                        Text("·")
                        Text(relative(entry.date))
                    }
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
        }
        .environment(\.layoutDirection, entry.isRTL ? .rightToLeft : .leftToRight)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(hovering || selected ? 0.085 : 0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(selected ? Color.accentColor.opacity(0.7) : Color.primary.opacity(0.06), lineWidth: selected ? 1.5 : 0.5)
        )
        .overlay(alignment: .topTrailing) {
            if hovering && !flashed {
                HStack(spacing: 2) {
                    IconButton(symbol: tab == .pinned ? "pin.slash" : (pinned ? "pin.fill" : "pin"),
                               tint: pinned ? .orange : .secondary,
                               help: pinned ? T("إلغاء التثبيت", "Unpin") : T("تثبيت", "Pin"),
                               action: onPin)
                    IconButton(symbol: "trash", tint: .red, help: T("حذف", "Delete"), action: onDelete)
                }
                .padding(3)
                .background(Capsule().fill(.regularMaterial))
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
                .padding(6)
                .transition(.opacity)
            }
        }
        .overlay {
            if flashed {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.green.opacity(0.14))
                    .overlay(
                        Label(T("تم النسخ", "Copied"), systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.green)
                    )
                    .transition(.opacity)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture(perform: onCopy)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
        .help(T("اضغط للنسخ", "Click to copy"))
    }

    private func relative(_ date: Date) -> String { relativeTime(date) }
}

struct IconButton: View {
    let symbol: String
    let tint: Color
    let help: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 24, height: 22)
                .background(Circle().fill(Color.primary.opacity(hover ? 0.1 : 0)))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(help)
    }
}

struct AppIcon: View {
    let bundleID: String?
    @MainActor static var cache: [String: NSImage] = [:]

    var body: some View {
        if let img = icon {
            Image(nsImage: img).resizable().interpolation(.high)
        } else {
            Image(systemName: "app.dashed").resizable().foregroundStyle(.secondary)
        }
    }

    private var icon: NSImage? {
        guard let id = bundleID else { return nil }
        if let cached = Self.cache[id] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        let img = NSWorkspace.shared.icon(forFile: url.path)
        Self.cache[id] = img
        return img
    }
}

struct EmptyState: View {
    let tab: Tab
    let searching: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.1)).frame(width: 64, height: 64)
                Image(systemName: searching ? "magnifyingglass" : tab.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            Text(title).font(.system(size: 14, weight: .semibold))
            Text(hint)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 20)
    }

    private var title: String {
        if searching { return T("ما في نتائج", "No results") }
        switch tab {
        case .typed: return T("لسّا ما كتبت شي", "Nothing typed yet")
        case .copied: return T("ما في شي منسوخ", "Nothing copied yet")
        case .pinned: return T("ما في جمل مثبتة", "No pinned text")
        case .shots: return T("ما في لقطات", "No screenshots")
        case .drafts: return T("ما في كلام بدون إنتر", "No unsent text")
        }
    }

    private var hint: String {
        if searching { return T("جرّب كلمة تانية.", "Try another word.") }
        switch tab {
        case .typed: return T("اكتب بأي برنامج واضغط Enter، وبتظهر الجملة هون.", "Type in any app and press Enter. It shows up here.")
        case .copied: return T("انسخ أي نص بـ Cmd+C وبيظهر هون.", "Copy any text with Cmd+C and it shows up here.")
        case .pinned: return T("مرّق الماوس على أي جملة واضغط الدبوس لتثبيتها.", "Hover over any line and click the pin to keep it.")
        case .shots: return T("اعمل Cmd+Shift+4 وبتظهر اللقطة هون بعد ثواني.", "Take a screenshot (Cmd+Shift+4) and it appears here.")
        case .drafts: return T("الكلام اللي بتكتبه وما بتبعته بإنتر (بتضغط بمكان تاني أو بتوقف) بيظهر هون.", "Text you type but don't send with Enter (you click away or stop) shows up here.")
        }
    }
}

// MARK: - Footer

struct Footer: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var ui: UIState
    let actions: Actions

    var body: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.6)
            HStack(spacing: 6) {
                Button {
                    withAnimation { state.paused.toggle() }
                } label: {
                    Label(state.paused ? T("تشغيل", "Resume") : T("إيقاف مؤقت", "Pause"),
                          systemImage: state.paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 11.5, weight: .medium))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(state.paused ? Color.green.opacity(0.18) : Color.primary.opacity(0.07)))
                        .foregroundStyle(state.paused ? Color.green : Color.primary)
                }
                .buttonStyle(.plain)

                Spacer()

                if !ui.showSettings {
                    HStack(spacing: 8) {
                        Text(T("تنقّل \u{2066}↑↓\u{2069}", "\u{2066}↑↓\u{2069} move"))
                        Text(T("نسخ \u{2066}↩\u{2069}", "\u{2066}↩\u{2069} copy"))
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                }

                Spacer()

                IconButton(symbol: ui.showSettings ? "xmark" : "gearshape", tint: .secondary,
                           help: T("الإعدادات", "Settings")) {
                    withAnimation(.easeOut(duration: 0.2)) { ui.showSettings.toggle() }
                }
                IconButton(symbol: "power", tint: .secondary, help: T("إنهاء البرنامج", "Quit Zakira"), action: actions.quit)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Settings

struct SettingsPane: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var lang: Lang
    @State private var diagnostic = DiagLog.diagnosticOn
    let actions: Actions
    @State private var confirmClear = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SettingsSection(title: T("عام", "General")) {
                    HStack {
                        Image(systemName: "power").foregroundStyle(.secondary)
                        Text(T("التشغيل مع بداية الماك", "Open at login")).font(.system(size: 12.5))
                        Spacer()
                        Toggle("", isOn: Binding(get: { state.launchAtLogin }, set: { state.setLaunchAtLogin($0) }))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }

                    ShortcutRow()

                    HStack {
                        Image(systemName: "scope").foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(T("دقة عالية", "High accuracy")).font(.system(size: 12.5))
                            Text(T("بيقرأ النص النهائي من الخانة نفسها، فالتعديلات والتصحيح التلقائي والإملاء الصوتي بتطلع صح. بيحتاج إذن Accessibility.",
                                   "Reads the final text from the field itself, so edits, autocorrect and dictation come out right. Needs the Accessibility permission."))
                                .font(.system(size: 10.5)).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(get: { state.highAccuracy }, set: { on in
                            state.highAccuracy = on
                            if on && !FieldReader.isTrusted { FieldReader.requestPermission() }
                        }))
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    }
                    if state.highAccuracy && !FieldReader.isTrusted {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text(T("فعّل Zakira بـ Accessibility حتى تشتغل الدقة العالية.", "Turn Zakira on under Accessibility for high accuracy."))
                                .font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Button(T("فتح", "Open")) {
                                if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(u) }
                            }.controlSize(.small)
                        }
                    }

                    HStack {
                        Image(systemName: state.captureActive ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(state.captureActive ? .green : .orange)
                        Text(state.captureActive ? T("تسجيل الكتابة شغّال", "Typing capture is on") : T("إذن مراقبة الإدخال غير مفعّل", "Input Monitoring is off"))
                            .font(.system(size: 12.5))
                        Spacer()
                        if !state.captureActive {
                            Button(T("فتح", "Open"), action: actions.openPrivacy).controlSize(.small)
                        }
                    }
                }

                Button(action: actions.showGuide) {
                    Label(T("دليل الاستخدام", "User guide"), systemImage: "book.pages")
                        .font(.system(size: 12.5, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)

                SettingsSection(title: T("الدعم", "Support")) {
                    HStack {
                        Image(systemName: "stethoscope").foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(T("وضع التشخيص", "Diagnostic mode")).font(.system(size: 12.5))
                            Text(T("بيسجّل تفاصيل أكتر لحل المشاكل (بدون نصوص)، وبينطفي لحاله بعد 24 ساعة.",
                                   "Logs more detail to fix problems (never your text). Turns off by itself after 24 hours."))
                                .font(.system(size: 10.5)).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(get: { diagnostic }, set: { DiagLog.setDiagnostic($0); diagnostic = DiagLog.diagnosticOn }))
                            .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    }
                    Button(T("إظهار ملف السجل", "Show log file")) {
                        NSWorkspace.shared.activateFileViewerSelecting([DiagLog.url])
                    }
                    .controlSize(.small)
                }

                SettingsSection(title: T("اللغة", "Language")) {
                    Picker("", selection: $lang.choice) {
                        Text(T("تلقائي (لغة الماك)", "Automatic (Mac language)")).tag(AppLanguage.system)
                        Text("العربية").tag(AppLanguage.arabic)
                        Text("English").tag(AppLanguage.english)
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }

                SettingsSection(title: T("برامج ما بيسجّل منها", "Never record from")) {
                    AppListEditor(apps: $state.excluded, emptyText: T("ما في برامج مستثناة", "No excluded apps"))
                    Text(T("لإضافة برنامج البنك مثلاً: افتحه أولاً، بعدين اختاره من القائمة.", "To add an app (e.g. your bank), open it first, then pick it from the list."))
                        .font(.system(size: 10.5)).foregroundStyle(.secondary)
                }

                SettingsSection(title: T("برامج الكتابة الطويلة", "Long-form apps")) {
                    Text(T("بهالبرامج Enter بيعمل سطر جديد، مش إرسال. النص كله بينحفظ بقسم \"بدون إنتر\" لما تطلع منها.",
                           "In these apps Enter is a new line, not a send. The whole text is saved under \"Unsent\" when you leave."))
                        .font(.system(size: 10.5)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    AppListEditor(apps: $state.longForm, emptyText: T("ما في برامج", "No apps"))
                }

                SettingsSection(title: T("الخصوصية", "Privacy")) {
                    Text(T("آخر الجمل والنسخ محفوظة بالذاكرة بس، وبتنمحي لما تسكّر البرنامج. الجمل المثبتة بتنحفظ مشفّرة على جهازك. لقطات الحافظة بتنمسح لحالها بعد أسبوع. ما في أي شي بيطلع على الإنترنت، وحقول الباسوورد ماك بيحجبها تلقائياً.", "Recent text and copies live in memory only and are gone when you quit. Pinned text is stored encrypted on your Mac. Clipboard screenshots are deleted after a week. Nothing ever leaves your Mac, and macOS blocks password fields automatically."))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(role: .destructive) {
                        confirmClear = true
                    } label: {
                        Label(T("مسح آخر الجمل والنسخ", "Clear recent history"), systemImage: "trash")
                            .font(.system(size: 12))
                    }
                    .controlSize(.small)
                    .confirmationDialog(T("أكيد بدك تمسح السجل؟ الجمل المثبتة ما بتنمسح.", "Clear the history? Pinned text is kept."), isPresented: $confirmClear) {
                        Button(T("مسح", "Clear"), role: .destructive) { withAnimation { state.clearHistory() } }
                        Button(T("إلغاء", "Cancel"), role: .cancel) {}
                    }
                }

                HStack(spacing: 4) {
                    Text(T("صنع بواسطة", "Made by"))
                    Link(Credits.author, destination: Credits.repo)
                    Text("· v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .frame(maxHeight: .infinity)
    }

}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 10) { content }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.045)))
        }
    }
}


// MARK: - Screenshots

struct ShotList: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var ui: UIState
    let actions: Actions

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Array(state.shots.enumerated()), id: \.element.id) { index, shot in
                        ShotCard(shot: shot,
                                 selected: index == ui.selected,
                                 flashed: ui.flashURL == shot.url,
                                 onCopy: { actions.copyShot(shot) })
                            .id(shot.url)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
            }
            .onChange(of: ui.selected) { _, i in
                if state.shots.indices.contains(i) {
                    withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(state.shots[i].url, anchor: .center) }
                }
            }
        }
    }
}

struct ShotCard: View {
    let shot: Shot
    let selected: Bool
    let flashed: Bool
    let onCopy: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                if let img = Thumbnails.image(for: shot) {
                    Image(nsImage: img)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                        .padding(5)
                } else {
                    Image(systemName: "photo").font(.system(size: 26)).foregroundStyle(.secondary)
                }
            }
            .frame(height: 112)
            .frame(maxWidth: .infinity)

            TimelineView(.periodic(from: .now, by: 30)) { _ in
                HStack(spacing: 4) {
                    Image(systemName: "camera.viewfinder")
                    Text(relativeTime(shot.date))
                }
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.primary.opacity(hovering || selected ? 0.085 : 0.045)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(selected ? Color.accentColor.opacity(0.7) : Color.primary.opacity(0.06), lineWidth: selected ? 1.5 : 0.5))
        .overlay(alignment: .topTrailing) {
            if hovering && !flashed {
                HStack(spacing: 2) {
                    IconButton(symbol: "eye", tint: .secondary, help: T("فتح بـ Preview", "Open in Preview")) {
                        if let u = shot.viewableURL() { NSWorkspace.shared.open(u) }
                    }
                    if !shot.isEncrypted {
                        IconButton(symbol: "folder", tint: .secondary, help: T("إظهار بالـ Finder", "Show in Finder")) {
                            NSWorkspace.shared.activateFileViewerSelecting([shot.url])
                        }
                    }
                }
                .padding(3)
                .background(Capsule().fill(.regularMaterial))
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
                .padding(8)
                .transition(.opacity)
            }
        }
        .overlay {
            if flashed {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.green.opacity(0.18))
                    .overlay(Label(T("تم النسخ", "Copied"), systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(.regularMaterial)))
                    .transition(.opacity)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture(perform: onCopy)
        .onDrag { shot.dragProvider() }
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
        .help(T("اضغط للنسخ، أو اسحبها لأي برنامج", "Click to copy, or drag into any app"))
    }
}



// MARK: - Settings building blocks

/// A list of apps with remove buttons and an "add a running app" menu.
struct AppListEditor: View {
    @Binding var apps: [ExcludedApp]
    let emptyText: String

    var body: some View {
        if apps.isEmpty {
            Text(emptyText).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        ForEach(apps) { app in
            HStack(spacing: 8) {
                AppIcon(bundleID: app.bundleID).frame(width: 18, height: 18)
                    .accessibilityHidden(true)
                Text(app.name).font(.system(size: 12.5))
                Spacer()
                IconButton(symbol: "minus.circle.fill", tint: .red, help: T("إزالة", "Remove") + " " + app.name) {
                    withAnimation { apps.removeAll { $0.bundleID == app.bundleID } }
                }
            }
        }
        Menu {
            ForEach(runningApps(), id: \.bundleID) { app in
                Button(app.name) { withAnimation { apps.append(app) } }
            }
        } label: {
            Label(T("إضافة برنامج مفتوح", "Add a running app"), systemImage: "plus.circle.fill")
                .font(.system(size: 12, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func runningApps() -> [ExcludedApp] {
        let mine = Bundle.main.bundleIdentifier
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> ExcludedApp? in
                guard let id = app.bundleIdentifier, id != mine, !apps.contains(where: { $0.bundleID == id }),
                      seen.insert(id).inserted else { return nil }
                return ExcludedApp(bundleID: id, name: app.localizedName ?? id)
            }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}

/// Shows the panel shortcut and lets the user record a new one.
struct ShortcutRow: View {
    @ObservedObject var hotkey = HotKey.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "keyboard").foregroundStyle(.secondary)
                Text(T("فتح اللوحة جنب الماوس", "Open panel at pointer")).font(.system(size: 12.5))
                Spacer()
                Button {
                    hotkey.isRecording.toggle()
                } label: {
                    Text(hotkey.isRecording ? T("اضغط الاختصار…", "Press keys…") : hotkey.display)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6)
                            .fill(hotkey.isRecording ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(hotkey.isRecording ? Color.accentColor : .clear, lineWidth: 1))
                        .environment(\.layoutDirection, .leftToRight)
                }
                .buttonStyle(.plain)
                .help(T("اضغط لتغيير الاختصار", "Click to change the shortcut"))
                .accessibilityLabel(T("الاختصار", "Shortcut") + " " + hotkey.spoken)
            }
            if hotkey.isRecording {
                HStack {
                    Text(T("اضغط الأزرار الجديدة مع Cmd أو Ctrl أو Option. Esc للإلغاء.",
                           "Press the new keys with Cmd, Ctrl or Option. Esc to cancel."))
                        .font(.system(size: 10.5)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button(T("افتراضي", "Default")) { hotkey.isRecording = false; hotkey.reset() }
                        .controlSize(.small)
                }
            }
        }
    }
}
