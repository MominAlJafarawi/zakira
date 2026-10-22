import AppKit
import Carbon.HIToolbox

/// Global shortcuts Ctrl + Cmd + V and Ctrl + Option + V (system hotkey API, needs no extra permission).
@MainActor
final class HotKey {
    static let shared = HotKey()
    var onPress: (() -> Void)?
    private var refs: [EventHotKeyRef?] = []

    private var lastFire = Date.distantPast

    /// Called by the system hotkey or by the keyboard listener; one press opens the panel once.
    func fire(source: String) {
        guard Date().timeIntervalSince(lastFire) > 0.35 else { return }
        lastFire = Date()
        DiagLog.detail("hotkey via \(source)")
        onPress?()
    }

    func register() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            MainActor.assumeIsolated { HotKey.shared.fire(source: "carbon") }
            return noErr
        }, 1, &spec, nil, nil)
        for (n, mods) in [(1, controlKey | optionKey), (2, controlKey | cmdKey)] {
            var r: EventHotKeyRef?
            let id = EventHotKeyID(signature: OSType(0x5A4B5259), id: UInt32(n)) // "ZKRY"
            let status = RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(mods), id, GetApplicationEventTarget(), 0, &r)
            refs.append(r)
            DiagLog.write("hotkey \(n == 1 ? "Ctrl+Option+V" : "Ctrl+Cmd+V") registered status=\(status)")
        }
    }
}
