import AppKit
import Carbon.HIToolbox

/// The global shortcut that opens the panel next to the pointer (default Ctrl + Cmd + V).
/// The system hotkey API catches it first and keeps it from reaching the front app.
/// The keyboard listener is only a fallback, used when the system hotkey did not fire.
@MainActor
final class HotKey: ObservableObject {
    static let shared = HotKey()
    var onPress: (() -> Void)?
    private var ref: EventHotKeyRef?
    private var handlerInstalled = false
    private var lastFire = Date.distantPast

    /// Carbon modifier mask (cmdKey, controlKey, optionKey, shiftKey) and virtual key code.
    @Published private(set) var keyCode: Int
    @Published private(set) var modifiers: Int
    @Published var isRecording = false

    static let defaultKey = kVK_ANSI_V
    static let defaultMods = controlKey | cmdKey

    private init() {
        let d = UserDefaults.standard
        keyCode = d.object(forKey: "hotkeyCode") as? Int ?? Self.defaultKey
        modifiers = d.object(forKey: "hotkeyMods") as? Int ?? Self.defaultMods
    }

    func fire(source: String) {
        guard Date().timeIntervalSince(lastFire) > 0.35 else { return }
        lastFire = Date()
        DiagLog.detail("hotkey via \(source)")
        onPress?()
    }

    /// The listener saw the shortcut. Give the system hotkey a moment; open only if it did not.
    func tapSaw() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            MainActor.assumeIsolated {
                if Date().timeIntervalSince(HotKey.shared.lastFire) > 0.4 { HotKey.shared.fire(source: "tap") }
            }
        }
    }

    func matches(keyCode code: Int, flags: CGEventFlags) -> Bool {
        guard code == keyCode, !isRecording else { return false }
        return flags.contains(.maskCommand) == (modifiers & cmdKey != 0)
            && flags.contains(.maskControl) == (modifiers & controlKey != 0)
            && flags.contains(.maskAlternate) == (modifiers & optionKey != 0)
            && flags.contains(.maskShift) == (modifiers & shiftKey != 0)
    }

    func register() {
        if !handlerInstalled {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                MainActor.assumeIsolated { HotKey.shared.fire(source: "system") }
                return noErr
            }, 1, &spec, nil, nil)
            handlerInstalled = true
        }
        if let ref { UnregisterEventHotKey(ref); self.ref = nil }
        let id = EventHotKeyID(signature: OSType(0x5A4B5259), id: 1) // "ZKRY"
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &ref)
        DiagLog.write("hotkey \(display) registered status=\(status)")
    }

    /// Records a new shortcut from a key event. Needs at least Cmd, Ctrl or Option.
    func record(_ event: NSEvent) -> Bool {
        let f = event.modifierFlags
        var mods = 0
        if f.contains(.command) { mods |= cmdKey }
        if f.contains(.control) { mods |= controlKey }
        if f.contains(.option) { mods |= optionKey }
        if f.contains(.shift) { mods |= shiftKey }
        guard mods & (cmdKey | controlKey | optionKey) != 0 else { return false }
        keyCode = Int(event.keyCode)
        modifiers = mods
        UserDefaults.standard.set(keyCode, forKey: "hotkeyCode")
        UserDefaults.standard.set(modifiers, forKey: "hotkeyMods")
        isRecording = false
        register()
        return true
    }

    func reset() {
        keyCode = Self.defaultKey
        modifiers = Self.defaultMods
        UserDefaults.standard.removeObject(forKey: "hotkeyCode")
        UserDefaults.standard.removeObject(forKey: "hotkeyMods")
        register()
    }

    /// e.g. "⌃ ⌘ V"
    var display: String {
        var parts: [String] = []
        if modifiers & controlKey != 0 { parts.append("⌃") }
        if modifiers & optionKey != 0 { parts.append("⌥") }
        if modifiers & shiftKey != 0 { parts.append("⇧") }
        if modifiers & cmdKey != 0 { parts.append("⌘") }
        parts.append(Self.keyName(keyCode))
        return parts.joined(separator: " ")
    }

    /// Spelled out for help texts, e.g. "Ctrl + Cmd + V".
    var spoken: String {
        var parts: [String] = []
        if modifiers & controlKey != 0 { parts.append("Ctrl") }
        if modifiers & optionKey != 0 { parts.append("Option") }
        if modifiers & shiftKey != 0 { parts.append("Shift") }
        if modifiers & cmdKey != 0 { parts.append("Cmd") }
        parts.append(Self.keyName(keyCode))
        return parts.joined(separator: " + ")
    }

    static func keyName(_ code: Int) -> String {
        let special: [Int: String] = [kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "Esc",
                                      kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓"]
        if let s = special[code] { return s }
        // Use the US layout name so the shortcut reads the same with Arabic or German keyboards.
        let us: [Int: String] = [
            kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E", kVK_ANSI_F: "F",
            kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
            kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R",
            kVK_ANSI_S: "S", kVK_ANSI_T: "T", kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
            kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z", kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
            kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8", kVK_ANSI_9: "9",
            kVK_ANSI_Period: ".", kVK_ANSI_Comma: ",", kVK_ANSI_Slash: "/", kVK_ANSI_Semicolon: ";",
            kVK_ANSI_Quote: "'", kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]", kVK_ANSI_Minus: "-",
            kVK_ANSI_Equal: "=", kVK_ANSI_Grave: "`", kVK_ANSI_Backslash: "\\",
        ]
        return us[code] ?? "#\(code)"
    }
}
