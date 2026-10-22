import AppKit
import SwiftUI
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let state = AppState.shared
    private let ui = UIState()
    private var previousApp: NSRunningApplication?
    private var keyMonitor: Any?
    private var permissionTimer: Timer?
    private var mouseAnchor: NSWindow?
    private var guideWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        updateIcon()

        let actions = Actions(
            copy: { [weak self] entry in self?.copy(entry) },
            copyShot: { [weak self] shot in self?.copyShot(shot) },
            openPrivacy: { [weak self] in self?.openPrivacySettings() },
            relaunch: { [weak self] in self?.relaunch() },
            showGuide: { [weak self] in self?.showGuide() },
            quit: { NSApp.terminate(nil) }
        )
        let root = ContentView(actions: actions)
            .environmentObject(state)
            .environmentObject(ui)
            .environmentObject(Lang.shared)
        Lang.shared.onChange = { [weak self] in
            self?.updateIcon()
            self?.guideWindow?.title = T("ذاكرة الكتابة", "Zakira")
        }
        popover.contentViewController = NSHostingController(rootView: root)
        popover.contentSize = NSSize(width: 380, height: 540)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        state.onPauseChanged = { [weak self] in self?.updateIcon() }

        // Switching to another app closes the sentence being typed.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { KeyCapture.shared.commit(sent: false) }
        }

        DiagLog.wipeOldActivityLogs()
        DiagLog.write("launch v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
        ClipboardWatcher.shared.start()
        ScreenshotWatcher.shared.start()
        Updates.shared.start()
        HotKey.shared.onPress = { [weak self] in self?.toggleAtMouse() }
        HotKey.shared.register()
        startCapture()
        LoginItem.refreshPathIfNeeded()
        if !UserDefaults.standard.bool(forKey: "onboardingDone") || !AppMover.isInApplications {
            showGuide()
        }
    }

    // MARK: guide

    private func showGuide() {
        popover.performClose(nil)
        if let guideWindow {
            guideWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = OnboardingView(
            openPrivacy: { [weak self] in self?.openPrivacySettings() },
            relaunch: { [weak self] in self?.relaunch() },
            finish: { [weak self] in
                UserDefaults.standard.set(true, forKey: "onboardingDone")
                UserDefaults.standard.set(0, forKey: "onboardingPage")
                self?.guideWindow?.close()
            }
        ).environmentObject(state).environmentObject(Lang.shared)
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 520),
                         styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        w.title = T("ذاكرة الكتابة", "Zakira")
        w.titlebarAppearsTransparent = true
        w.isReleasedWhenClosed = false
        w.contentViewController = NSHostingController(rootView: view)
        w.center()
        guideWindow = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: capture permission

    private func startCapture() {
        state.captureActive = KeyCapture.shared.start()
        if !state.captureActive {
            let r = CGRequestListenEventAccess()
            DiagLog.write("requested access, result=\(r)")
        }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            MainActor.assumeIsolated {
                let s = AppState.shared
                if !s.captureActive {
                    s.captureActive = KeyCapture.shared.start()
                }
            }
        }
    }

    private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
        popover.performClose(nil)
    }

    private func relaunch() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        let url = Bundle.main.bundleURL
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            NSApp.terminate(nil)
        }
        NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
    }

    // MARK: status item & popover

    private func updateIcon() {
        let name = state.paused ? "pause.circle" : "brain"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: T("ذاكرة الكتابة", "Zakira"))
        img?.isTemplate = true
        statusItem.button?.image = img
        statusItem.button?.toolTip = state.paused ? T("ذاكرة الكتابة (متوقف)", "Zakira (paused)") : T("ذاكرة الكتابة", "Zakira")
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = statusItem.button else { return }
        present(relativeTo: button, edge: .minY)
    }

    /// Ctrl+Option+V: open the panel right next to the mouse pointer.
    private func toggleAtMouse() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        let p = NSEvent.mouseLocation
        let anchor = mouseAnchor ?? {
            let w = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = false
            w.ignoresMouseEvents = true
            w.level = .popUpMenu
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            mouseAnchor = w
            return w
        }()
        anchor.setFrame(NSRect(x: p.x - 1, y: p.y - 1, width: 2, height: 2), display: false)
        anchor.orderFrontRegardless()
        guard let view = anchor.contentView else { return }
        // Open below the pointer, or above it when the pointer is low on the screen.
        let screen = NSScreen.screens.first { NSMouseInRect(p, $0.frame, false) } ?? NSScreen.main
        let lowOnScreen = p.y - (screen?.visibleFrame.minY ?? 0) < 560
        present(relativeTo: view, edge: lowOnScreen ? .maxY : .minY)
        DiagLog.detail("hotkey pressed: panel shown=\(popover.isShown) at mouse")
    }

    private func present(relativeTo view: NSView, edge: NSRectEdge) {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier { previousApp = front }
        ui.reset()
        ScreenshotWatcher.shared.publish()
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: edge)
        // Keep the panel out of screen sharing and recordings (Zoom, Teams, QuickTime).
        popover.contentViewController?.view.window?.sharingType = .none
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
        installKeyMonitor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HistoryStore.save()
    }

    func popoverDidClose(_ notification: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        mouseAnchor?.orderOut(nil)
        previousApp?.activate()
    }

    private func installKeyMonitor() {
        if keyMonitor != nil { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return MainActor.assumeIsolated { self.handleKey(event) }
        }
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        let code = Int(event.keyCode)
        if HotKey.shared.isRecording {
            if code == kVK_Escape { HotKey.shared.isRecording = false } else { _ = HotKey.shared.record(event) }
            return nil
        }
        if event.modifierFlags.contains(.command) {
            switch code {
            case kVK_ANSI_1: ui.tab = .typed; return nil
            case kVK_ANSI_2: ui.tab = .copied; return nil
            case kVK_ANSI_3: ui.tab = .pinned; return nil
            case kVK_ANSI_4: ui.tab = .shots; return nil
            case kVK_ANSI_Comma: ui.showSettings.toggle(); return nil
            default: return event
            }
        }
        if code == kVK_Escape {
            if ui.showSettings { ui.showSettings = false } else { popover.performClose(nil) }
            return nil
        }
        if ui.showSettings { return event }
        if ui.tab == .shots {
            switch code {
            case kVK_DownArrow: if !state.shots.isEmpty { ui.selected = min(ui.selected + 1, state.shots.count - 1) }; return nil
            case kVK_UpArrow: ui.selected = max(ui.selected - 1, 0); return nil
            case kVK_Return, kVK_ANSI_KeypadEnter:
                if state.shots.indices.contains(ui.selected) { copyShot(state.shots[ui.selected]) }
                return nil
            default: return event
            }
        }
        let items = ui.visibleItems(state)
        switch code {
        case kVK_DownArrow:
            if !items.isEmpty { ui.selected = min(ui.selected + 1, items.count - 1) }
            return nil
        case kVK_UpArrow:
            ui.selected = max(ui.selected - 1, 0)
            return nil
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if items.indices.contains(ui.selected) { copy(items[ui.selected]) }
            return nil
        default:
            return event
        }
    }

    private func copyShot(_ shot: Shot) {
        state.copyImage(shot)
        withAnimation(motion(.easeOut(duration: 0.15))) { ui.flashURL = shot.url }
        announce(T("تم النسخ", "Copied"))
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            self.popover.performClose(nil)
            self.ui.flashURL = nil
        }
    }

    private func copy(_ entry: Entry) {
        if let data = entry.image, let img = NSImage(data: data) {
            state.copyImageObject(img)
        } else {
            state.copyToPasteboard(entry.text)
        }
        withAnimation(motion(.easeOut(duration: 0.15))) { ui.flashID = entry.id }
        announce(T("تم النسخ", "Copied"))
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 550_000_000)
            self.popover.performClose(nil)
            self.ui.flashID = nil
        }
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
