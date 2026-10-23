// Zakira self-tests. Run: ./test.sh
// They use ZAKIRA_DEMO, so the real Keychain and history are never touched.
import AppKit
import Carbon.HIToolbox

var failures = 0
var passes = 0
func expect(_ ok: Bool, _ name: String, _ detail: @autoclosure () -> String = "") {
    if ok { passes += 1 } else { failures += 1; print("✗ \(name) \(detail())") }
}

MainActor.assumeIsolated {
    _ = NSApplication.shared

    // MARK: sensitive data
    let drop = ["4111 1111 1111 1111", "my card 4111-1111-1111-1111 thanks", "5500005555555559",
                "482913", "482 913", "Your verification code is 482913", "كود التحقق 5521", "Dein Bestätigungscode: 7731",
                "Hunter2!xyz", "C0rrect-Horse-9"]
    for t in drop { expect(Sensitive.filter(t) == nil, "drops sensitive", t) }
    let keep = ["Order #48213 ships Friday", "call me 01012345678", "see you at 1530", "hello world",
                "https://github.com/MominAlJafarawi/zakira", "someone@example.com", "CamelCaseName",
                "تمام، بكرة الساعة 10 بنتواصل", "Meeting moved to 3 pm"]
    for t in keep { expect(Sensitive.filter(t) == t, "keeps normal text", t) }
    expect(Sensitive.filter("IBAN DE89 3704 0044 0532 0130 00 bitte") == "IBAN DE89 •••• •••• •••• 3000 bitte", "masks IBAN with spaces")
    expect(Sensitive.filter("DE89370400440532013000") == "DE89 •••• •••• •••• 3000", "masks compact IBAN")
    expect(Sensitive.filter("DE89370400440532013001") != "DE89 •••• •••• •••• 3001", "invalid IBAN is not masked as one")
    expect(Sensitive.luhn([4,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1]), "luhn valid")
    expect(!Sensitive.luhn([4,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2]), "luhn invalid")

    // MARK: typing engine
    let st = AppState.shared
    st.excluded = []
    st.longForm = []
    let kc = KeyCapture.shared
    @MainActor func key(_ code: Int, _ flags: CGEventFlags = []) {
        let e = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: true)!
        e.flags = flags
        kc.handle(.keyDown, e)
    }
    let map: [Character: Int] = [
        "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D, "e": kVK_ANSI_E, "f": kVK_ANSI_F,
        "g": kVK_ANSI_G, "h": kVK_ANSI_H, "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
        "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P, "q": kVK_ANSI_Q, "r": kVK_ANSI_R,
        "s": kVK_ANSI_S, "t": kVK_ANSI_T, "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
        "y": kVK_ANSI_Y, "z": kVK_ANSI_Z, " ": kVK_Space]
    @MainActor func type(_ s: String) { for ch in s { key(map[ch]!) } }
    let usLayout = KeyCapture.layoutOverride != nil
    if usLayout {
        type("helo"); key(kVK_LeftArrow); type("l"); key(kVK_Return)
        expect(st.typed.first?.text == "hello", "arrow edit", st.typed.first?.text ?? "")
        type("world"); key(kVK_LeftArrow, .maskCommand); type("hello "); key(kVK_Return)
        expect(st.typed.first?.text == "hello world", "insert at start")
        type("abc"); key(kVK_ANSI_A, .maskCommand); type("bed"); key(kVK_Return)
        expect(st.typed.first?.text == "bed", "select all + replace")
        type("hello world"); key(kVK_Delete, .maskAlternate); type("dear"); key(kVK_Return)
        expect(st.typed.first?.text == "hello dear", "option-delete word")
        type("cafe"); key(kVK_Delete); key(kVK_ANSI_E, .maskAlternate); key(kVK_ANSI_E); key(kVK_Return)
        expect(st.typed.first?.text == "café", "dead key é", st.typed.first?.text ?? "")
        type("hello"); key(kVK_Return, .maskShift); type("world"); key(kVK_Return)
        expect(st.typed.first?.text == "hello\nworld", "shift-enter is a new line")
        type("draft one"); kc.commit(sent: false)
        expect(st.drafts.first?.text == "draft one", "unsent goes to drafts")
        type("draft one"); key(kVK_Return)
        expect(!st.drafts.contains { $0.text == "draft one" } || st.typed.first?.text == "draft one", "sent text")
    } else {
        print("• typing tests skipped (US layout not available)")
    }

    // MARK: history limit and dedupe
    st.historyLimit = 10
    for i in 0..<15 { st.addCopied("item number \(i)", app: nil) }
    expect(st.copied.count == 10, "history keeps 10")
    st.addCopied("item number 14", app: nil)
    expect(st.copied.filter { $0.text == "item number 14" }.count == 1, "no duplicates")
    st.addCopied("4111 1111 1111 1111", app: nil)
    expect(!st.copied.contains { $0.text.contains("4111") }, "card never reaches copied list")

    // MARK: export / import
    let pins = [Entry(text: "مع التحية، أحمد", appName: "Notes", bundleID: nil, date: Date())]
    let file = PinTransfer.encrypt(pins, password: "correct horse")!
    expect(PinTransfer.decrypt(file, password: "correct horse")?.first?.text == pins[0].text, "export/import roundtrip")
    expect(PinTransfer.decrypt(file, password: "wrong") == nil, "wrong password rejected")
    expect(PinTransfer.decrypt(Data("junk".utf8), password: "x") == nil, "junk file rejected")

    // MARK: encryption (test Keychain service only)
    let secret = Data("screenshot bytes".utf8)
    if let sealed = ShotCrypto.seal(secret) {
        expect(sealed != secret && ShotCrypto.open(sealed) == secret, "screenshot encrypt/decrypt")
    } else {
        print("• encryption test skipped (no Keychain access here)")
    }
    SecureStore.deleteAll()

    // MARK: versions and old data
    expect(Updates.isNewer("3.0", than: "2.9.8"), "3.0 > 2.9.8")
    expect(!Updates.isNewer("2.9.8", than: "3.0"), "2.9.8 < 3.0")
    expect(!Updates.isNewer("3.0", than: "3.0.0"), "3.0 == 3.0.0")
    let old = #"[{"id":"9E2C1F3A-0000-4000-8000-000000000001","text":"hi","appName":"Notes","date":0}]"#
    expect((try? JSONDecoder().decode([Entry].self, from: Data(old.utf8)))?.first?.text == "hi", "pinned data from v2 still loads")

    // MARK: hotkey matching
    let hk = HotKey.shared
    expect(hk.matches(keyCode: kVK_ANSI_V, flags: [.maskControl, .maskCommand]) == (hk.keyCode == kVK_ANSI_V && hk.modifiers == (controlKey | cmdKey)), "hotkey matches default")
    expect(!hk.matches(keyCode: kVK_ANSI_V, flags: [.maskCommand]), "plain Cmd+V is not the hotkey")

    print("\(passes) passed, \(failures) failed")
    exit(failures == 0 ? 0 : 1)
}
