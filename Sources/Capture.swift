import AppKit
import Carbon.HIToolbox
import IOKit.hid

/// Listens to the keyboard (read only) and turns keystrokes into sentences.
@MainActor
final class KeyCapture {
    static let shared = KeyCapture()

    private var tap: CFMachPort?
    private var buffer = ""
    private var bufferApp: NSRunningApplication?
    private var idleTimer: Timer?
    private let state = AppState.shared
    /// id of the unsent text being typed now, so a later Enter can replace its draft
    private var draftID = UUID()

    var isRunning: Bool { tap != nil }
    private var keyCount = 0
    private var lastStatus = ""

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
            commit(sent: false)
            return
        }
        guard type == .keyDown else { return }
        keyCount += 1
        if keyCount == 1 || keyCount % 50 == 0 {
            DiagLog.detail("keys received=\(keyCount) paused=\(state.paused) secure=\(IsSecureEventInputEnabled()) front=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "-")")
        }

        // Ctrl + Cmd + V or Ctrl + Option + V opens the panel next to the mouse (works even when paused).
        let hkFlags = event.flags
        if Int(event.getIntegerValueField(.keyboardEventKeycode)) == kVK_ANSI_V,
           hkFlags.contains(.maskControl), !hkFlags.contains(.maskShift),
           hkFlags.contains(.maskCommand) != hkFlags.contains(.maskAlternate) {
            HotKey.shared.fire(source: "tap")
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
        }

        let flags = event.flags
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        if flags.contains(.maskCommand) {
            if keyCode == kVK_ANSI_V, let pasted = NSPasteboard.general.string(forType: .string) {
                append(pasted)
            } else if keyCode == kVK_Delete {
                buffer = ""
            }
            return
        }
        if flags.contains(.maskControl) { return }

        switch keyCode {
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if flags.contains(.maskShift) || flags.contains(.maskAlternate) {
                // Shift/Option + Enter is a new line in chat apps, not sending.
                append("\n")
            } else {
                commit(sent: true)
            }
            return
        case kVK_Tab:
            commit(sent: false)
            return
        case kVK_Escape:
            discard()
            return
        case kVK_Delete:
            if flags.contains(.maskAlternate) {
                deleteLastWord()
            } else if !buffer.isEmpty {
                buffer.removeLast()
            }
            touch()
            return
        case kVK_ForwardDelete, kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow,
             kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown:
            return
        default:
            break
        }

        guard let chars = NSEvent(cgEvent: event)?.characters, !chars.isEmpty else { return }
        let clean = String(String.UnicodeScalarView(chars.unicodeScalars.filter { s in
            !(s.value < 0x20 || s.value == 0x7F || (0xF700...0xF8FF).contains(s.value))
        }))
        if clean.isEmpty { return }

        append(clean)
    }

    private func append(_ s: String) {
        buffer += s
        if buffer.count > 3000 { buffer = String(buffer.suffix(3000)) }
        touch()
    }

    private func deleteLastWord() {
        while let last = buffer.last, last.isWhitespace { buffer.removeLast() }
        while let last = buffer.last, !last.isWhitespace { buffer.removeLast() }
    }

    private func touch() {
        idleTimer?.invalidate()
        // After a pause, show what was typed so far as unsent; typing goes on in the same text.
        idleTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { _ in
            MainActor.assumeIsolated { KeyCapture.shared.snapshotDraft() }
        }
    }

    private func discard() {
        idleTimer?.invalidate()
        buffer = ""
    }

    private func isWorthSaving(_ text: String) -> Bool {
        text.count >= 2 && text.contains(where: { $0.isLetter || $0.isNumber })
    }

    func snapshotDraft() {
        let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if isWorthSaving(text) {
            state.upsertDraft(id: draftID, text: text, app: bufferApp)
        } else {
            state.removeDraft(id: draftID)
        }
    }

    /// sent = Enter was pressed; otherwise the text is kept in the "without Enter" list.
    func commit(sent: Bool) {
        idleTimer?.invalidate()
        let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = draftID
        buffer = ""
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

    private func check() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastCount else { return }
        lastCount = pb.changeCount
        if pb.changeCount == state.ownChangeCount || state.paused { return }
        if (pb.types ?? []).contains(where: { secretTypes.contains($0.rawValue) }) { return }
        let front = NSWorkspace.shared.frontmostApplication
        if state.isExcluded(front?.bundleIdentifier) { return }
        if saveClipboardScreenshot(pb) { return }
        guard let raw = pb.string(forType: .string) else { return }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 20000 else { return }
        state.addCopied(text, app: front)
    }

    /// Cmd+Ctrl+Shift+3/4 put the screenshot only on the clipboard (no file).
    /// A clipboard holding only an image (no text, link or file) is treated as such a screenshot
    /// and saved to the app's own folder so it shows in the Screenshots tab.
    private func saveClipboardScreenshot(_ pb: NSPasteboard) -> Bool {
        let types = Set((pb.types ?? []).map(\.rawValue))
        let imageTypes: Set<String> = ["public.png", "public.tiff", "Apple PNG pasteboard type", "NeXT TIFF v4.0 pasteboard type"]
        guard !types.isDisjoint(with: imageTypes) else { return false }
        let other: Set<String> = ["public.utf8-plain-text", "public.url", "public.file-url", "public.html", "public.rtf", "NSStringPboardType", "NSFilenamesPboardType"]
        guard types.isDisjoint(with: other) else { return false }
        let png: Data?
        if let data = pb.data(forType: .png) {
            png = data
        } else if let tiff = pb.data(forType: .tiff), let rep = NSBitmapImageRep(data: tiff) {
            png = rep.representation(using: .png, properties: [:])
        } else {
            png = nil
        }
        guard let png else { return false }
        ScreenshotWatcher.shared.saveClipboardShot(png)
        return true
    }
}
