import AppKit
import Darwin
import Carbon.HIToolbox
import IOKit.hid

/// Listens to the keyboard (read only) and turns keystrokes into sentences.
/// It keeps a cursor, so arrow keys and edits in the middle of a sentence are followed,
/// and translates dead keys (e.g. ^ then e = ê) with the current keyboard layout.
/// In "high accuracy" mode it reads the final text straight from the field (Accessibility).
@MainActor
final class KeyCapture {
    static let shared = KeyCapture()

    private var tap: CFMachPort?
    private var chars: [Character] = []
    private var cursor = 0
    /// After Cmd+A the next key replaces everything.
    private var allSelected = false
    private var bufferApp: NSRunningApplication?
    private var idleTimer: Timer?
    private let state = AppState.shared
    /// id of the unsent text being typed now, so a later Enter can replace its draft
    private var draftID = UUID()
    private var deadKeyState: UInt32 = 0

    var isRunning: Bool { tap != nil }
    private var keyCount = 0
    private var lastStatus = ""

    private var buffer: String { String(chars) }

    /// Tests pin a known layout (e.g. "com.apple.keylayout.US") so they run on any Mac.
    static var layoutOverride: TISInputSource? = {
        guard let id = ProcessInfo.processInfo.environment["ZAKIRA_TEST_LAYOUT"] else { return nil }
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource] else { return nil }
        return list.first
    }()

    func start() -> Bool {
        if tap != nil { return true }
        let pre = CGPreflightListenEventAccess()
        let hid = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        let status = "start: preflight=\(pre) hid=\(hid.rawValue) path=\(Bundle.main.bundlePath)"
        if status != lastStatus { DiagLog.write(status); lastStatus = status }
        // Without the permission a tap can still be created but gets no keys, so check first.
        guard pre || hid == kIOHIDAccessTypeGranted else { return false }
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue)
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: keyTapCallback,
            userInfo: nil
        ) else { DiagLog.write("start: tapCreate FAILED"); return false }
        DiagLog.write("start: tap created OK")
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        tap = newTap
        return true
    }

    func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    func handle(_ type: CGEventType, _ event: CGEvent) {
        if type == .leftMouseDown || type == .rightMouseDown {
            // A click usually means a new field or a new place: keep what was typed as unsent.
            // The field still has focus at this moment, so high accuracy can read it first.
            commit(sent: false, readField: true)
            return
        }
        guard type == .keyDown else { return }
        keyCount += 1
        if keyCount == 1 || keyCount % 50 == 0 {
            DiagLog.detail("keys received=\(keyCount) paused=\(state.paused) secure=\(IsSecureEventInputEnabled()) front=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "-")")
        }

        let flags = event.flags
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        // The panel shortcut (the system hotkey normally catches it first; this is the fallback).
        if HotKey.shared.matches(keyCode: keyCode, flags: flags) {
            HotKey.shared.tapSaw()
            return
        }

        if state.paused || IsSecureEventInputEnabled() {
            discard()
            return
        }
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier == ProcessInfo.processInfo.processIdentifier { return }
        if state.isExcluded(front?.bundleIdentifier) {
            discard()
            return
        }
        if bufferApp?.processIdentifier != front?.processIdentifier {
            commit(sent: false)
            bufferApp = front
            if state.highAccuracy { FieldReader.enableWebAccessibility(for: front) }
        }

        if flags.contains(.maskCommand) {
            switch keyCode {
            case kVK_ANSI_V:
                if let pasted = NSPasteboard.general.string(forType: .string) { insert(pasted) }
            case kVK_ANSI_A:
                allSelected = true
            case kVK_ANSI_X:
                if allSelected { clearAll() }
            case kVK_Delete:
                // delete to the start of the line
                chars.removeSubrange(0..<cursor); cursor = 0
            case kVK_LeftArrow, kVK_UpArrow:
                cursor = 0
            case kVK_RightArrow, kVK_DownArrow:
                cursor = chars.count
            default:
                break
            }
            return
        }
        if flags.contains(.maskControl) { return }

        switch keyCode {
        case kVK_Return, kVK_ANSI_KeypadEnter:
            let newline = flags.contains(.maskShift) || flags.contains(.maskAlternate)
                || state.isLongForm(front?.bundleIdentifier)
            if newline {
                // Shift/Option + Enter in chats, or any Enter in Notes, Word, code editors…: a new line.
                insert("\n")
            } else {
                commit(sent: true, readField: true)
            }
            return
        case kVK_Tab:
            commit(sent: false, readField: true)
            return
        case kVK_Escape:
            discard()
            return
        case kVK_Delete:
            if allSelected { clearAll(); touch(); return }
            if flags.contains(.maskAlternate) {
                deleteWordBeforeCursor()
            } else if cursor > 0 {
                chars.remove(at: cursor - 1); cursor -= 1
            }
            touch()
            return
        case kVK_ForwardDelete:
            if allSelected { clearAll(); touch(); return }
            if cursor < chars.count { chars.remove(at: cursor) }
            touch()
            return
        case kVK_LeftArrow:
            allSelected = false
            if flags.contains(.maskAlternate) { cursor = wordStart(before: cursor) } else { cursor = max(0, cursor - 1) }
            return
        case kVK_RightArrow:
            allSelected = false
            if flags.contains(.maskAlternate) { cursor = wordEnd(after: cursor) } else { cursor = min(chars.count, cursor + 1) }
            return
        case kVK_Home, kVK_UpArrow, kVK_PageUp:
            allSelected = false
            cursor = 0
            return
        case kVK_End, kVK_DownArrow, kVK_PageDown:
            allSelected = false
            cursor = chars.count
            return
        default:
            break
        }

        let typed = translate(keyCode: keyCode, flags: flags) ?? fallbackChars(event)
        let clean = String(String.UnicodeScalarView(typed.unicodeScalars.filter { s in
            !(s.value < 0x20 || s.value == 0x7F || (0xF700...0xF8FF).contains(s.value))
        }))
        if clean.isEmpty { return }
        insert(clean)
    }

    // MARK: editing

    private func insert(_ s: String) {
        if allSelected { clearAll() }
        let new = Array(s)
        chars.insert(contentsOf: new, at: cursor)
        cursor += new.count
        if chars.count > 3000 {
            let extra = chars.count - 3000
            chars.removeFirst(extra)
            cursor = max(0, cursor - extra)
        }
        touch()
    }

    private func clearAll() {
        chars.removeAll(); cursor = 0; allSelected = false
    }

    private func deleteWordBeforeCursor() {
        let start = wordStart(before: cursor)
        chars.removeSubrange(start..<cursor)
        cursor = start
    }

    private func wordStart(before i: Int) -> Int {
        var j = i
        while j > 0, chars[j - 1].isWhitespace { j -= 1 }
        while j > 0, !chars[j - 1].isWhitespace { j -= 1 }
        return j
    }

    private func wordEnd(after i: Int) -> Int {
        var j = i
        while j < chars.count, chars[j].isWhitespace { j += 1 }
        while j < chars.count, !chars[j].isWhitespace { j += 1 }
        return j
    }

    // MARK: key translation

    /// Uses the active keyboard layout, keeping dead-key state between presses (^ + e = ê).
    private func translate(keyCode: Int, flags: CGEventFlags) -> String? {
        guard let source = Self.layoutOverride ?? TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        var mods: UInt32 = 0
        if flags.contains(.maskShift) { mods |= UInt32(shiftKey >> 8) }
        if flags.contains(.maskAlternate) { mods |= UInt32(optionKey >> 8) }
        if flags.contains(.maskAlphaShift) { mods |= UInt32(alphaLock >> 8) }
        var length = 0
        var buf = [UniChar](repeating: 0, count: 8)
        let status = layoutData.withUnsafeBytes { raw -> OSStatus in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return -1 }
            return UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDown), mods,
                                  UInt32(LMGetKbdType()), 0, &deadKeyState, buf.count, &length, &buf)
        }
        guard status == noErr else { return nil }
        return String(utf16CodeUnits: buf, count: length)
    }

    private func fallbackChars(_ event: CGEvent) -> String {
        NSEvent(cgEvent: event)?.characters ?? ""
    }

    // MARK: saving

    private func touch() {
        idleTimer?.invalidate()
        // After a pause, show what was typed so far as unsent; typing goes on in the same text.
        idleTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { _ in
            MainActor.assumeIsolated { KeyCapture.shared.snapshotDraft() }
        }
    }

    private func discard() {
        idleTimer?.invalidate()
        clearAll()
    }

    private func isWorthSaving(_ text: String) -> Bool {
        text.count >= 2 && text.contains(where: { $0.isLetter || $0.isNumber })
    }

    func snapshotDraft() {
        let text = currentText(readField: true)
        if isWorthSaving(text) {
            state.upsertDraft(id: draftID, text: text, app: bufferApp)
        } else {
            state.removeDraft(id: draftID)
        }
    }

    /// The text to save: from the field itself in high-accuracy mode (when readable),
    /// otherwise what was rebuilt from the keys.
    private func currentText(readField: Bool, sending: Bool = false) -> String {
        let typed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        // When sending, read the field even if no keys were seen (dictation, paste from a menu).
        guard readField, state.highAccuracy, !typed.isEmpty || sending,
              !state.isLongForm(bufferApp?.bundleIdentifier),
              let fieldText = FieldReader.focusedText() else { return typed }
        let t = fieldText.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? typed : String(t.prefix(3000))
    }

    /// sent = Enter was pressed; otherwise the text is kept in the "without Enter" list.
    func commit(sent: Bool, readField: Bool = false) {
        idleTimer?.invalidate()
        let text = currentText(readField: readField, sending: sent)
        let id = draftID
        clearAll()
        draftID = UUID()
        if sent {
            state.removeDraft(id: id)
            guard isWorthSaving(text) else { return }
            DiagLog.detail("sent text saved (length \(text.count))")
            state.addTyped(text, app: bufferApp)
        } else if isWorthSaving(text) {
            DiagLog.detail("unsent text saved (length \(text.count))")
            state.upsertDraft(id: id, text: text, app: bufferApp)
        } else {
            state.removeDraft(id: id)
        }
    }
}

/// High-accuracy mode: reads the text of the focused field through the Accessibility API.
@MainActor
enum FieldReader {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// The focused field's text, or nil (no permission, password field, or not a text field).
    static func focusedText() -> String? {
        guard isTrusted else { return nil }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.15)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let el = focused, CFGetTypeID(el) == AXUIElementGetTypeID() else { return nil }
        let element = el as! AXUIElement
        var role: CFTypeRef?
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
        if (subrole as? String) == (kAXSecureTextFieldSubrole as String) { return nil }
        let allowed: Set<String> = [kAXTextFieldRole as String, kAXTextAreaRole as String, kAXComboBoxRole as String, "AXSearchField"]
        guard let r = role as? String, allowed.contains(r) || (subrole as? String) == "AXSearchField" else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static var enabledPIDs: Set<pid_t> = []

    /// Chrome and Electron apps (Slack, WhatsApp, Discord…) only expose their text fields
    /// when an assistive app asks for it.
    static func enableWebAccessibility(for app: NSRunningApplication?) {
        guard isTrusted, let app, !enabledPIDs.contains(app.processIdentifier) else { return }
        enabledPIDs.insert(app.processIdentifier)
        let el = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(el, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }
}

private let keyTapCallback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        MainActor.assumeIsolated { KeyCapture.shared.reenable() }
    } else {
        MainActor.assumeIsolated { KeyCapture.shared.handle(type, event) }
    }
    return Unmanaged.passUnretained(event)
}

/// Watches the clipboard and keeps the last copied texts.
@MainActor
final class ClipboardWatcher {
    static let shared = ClipboardWatcher()
    private var lastCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    private let state = AppState.shared
    private let secretTypes: Set<String> = [
        "org.nspasteboard.ConcealedType",
        "org.nspasteboard.TransientType",
        "org.nspasteboard.AutoGeneratedType",
        "com.agilebits.onepassword",
    ]

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            MainActor.assumeIsolated { ClipboardWatcher.shared.check() }
        }
    }

    /// Last time macOS's own screenshot tool was running (it handles Cmd+Ctrl+Shift+3/4).
    private var lastCaptureToolSeen = Date.distantPast

    private func check() {
        if ScreenCaptureTool.isRunning() { lastCaptureToolSeen = Date() }
        let pb = NSPasteboard.general
        guard pb.changeCount != lastCount else { return }
        lastCount = pb.changeCount
        if pb.changeCount == state.ownChangeCount || state.paused { return }
        if (pb.types ?? []).contains(where: { secretTypes.contains($0.rawValue) }) { return }
        let front = NSWorkspace.shared.frontmostApplication
        if state.isExcluded(front?.bundleIdentifier) { return }
        if let raw = pb.string(forType: .string) {
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, text.count <= 20000 else { return }
            state.addCopied(text, app: front)
            return
        }
        guard let png = imagePNG(pb) else { return }
        let fromScreenshotTool = Date().timeIntervalSince(lastCaptureToolSeen) < 3
        DiagLog.detail("image copied: screenshot tool=\(fromScreenshotTool)")
        if fromScreenshotTool {
            ScreenshotWatcher.shared.saveClipboardShot(png)
        } else {
            state.addCopiedImage(png, app: front)
        }
    }

    /// The clipboard image as PNG, or nil (no image, a file, or larger than 15 MB).
    private func imagePNG(_ pb: NSPasteboard) -> Data? {
        let types = Set((pb.types ?? []).map(\.rawValue))
        if types.contains("public.file-url") { return nil }
        var png: Data?
        if let data = pb.data(forType: .png) {
            png = data
        } else if let tiff = pb.data(forType: .tiff), let rep = NSBitmapImageRep(data: tiff) {
            png = rep.representation(using: .png, properties: [:])
        }
        guard let png, png.count <= 15_000_000 else { return nil }
        return png
    }
}


/// Detects macOS's screenshot tool (screencaptureui / screencapture) by process name.
enum ScreenCaptureTool {
    static func isRunning() -> Bool {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return false }
        var pids = [pid_t](repeating: 0, count: Int(count) + 32)
        let n = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        var name = [CChar](repeating: 0, count: 256)
        for pid in pids.prefix(Int(max(n, 0))) where pid > 0 {
            if proc_name(pid, &name, UInt32(name.count)) > 0 {
                let s = String(cString: name)
                if s == "screencaptureui" || s == "screencapture" { return true }
            }
        }
        return false
    }
}
