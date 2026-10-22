import Foundation

/// Keeps secrets out of the history.
/// - Card numbers, one-time codes and password-like text are never saved.
/// - IBANs are saved masked: DE89 •••• •••• •••• •••• 3000
enum Sensitive {
    /// Returns the text to save, or nil when it must not be saved at all.
    static func filter(_ text: String) -> String? {
        // Mask IBANs first, so their digits are not mistaken for a card number.
        let masked = maskIBANs(text)
        if containsCardNumber(masked) || isOneTimeCode(masked) || looksLikePassword(masked) { return nil }
        return masked
    }

    // MARK: cards

    /// 13–19 digits (spaces or dashes allowed between) that pass the Luhn check.
    static func containsCardNumber(_ text: String) -> Bool {
        var digits: [Int] = []
        var gap = 0
        func check() -> Bool { (13...19).contains(digits.count) && luhn(digits) }
        for ch in text {
            if let d = ch.wholeNumberValue, ch.isASCII {
                digits.append(d)
                gap = 0
            } else if (ch == " " || ch == "-") && !digits.isEmpty && gap == 0 {
                gap += 1
            } else {
                if check() { return true }
                // also look at every 13–19 window inside a longer run
                if digits.count > 19, windows(digits) { return true }
                digits.removeAll()
                gap = 0
            }
        }
        return check() || (digits.count > 19 && windows(digits))
    }

    private static func windows(_ d: [Int]) -> Bool {
        for len in 13...19 where d.count >= len {
            for start in 0...(d.count - len) where luhn(Array(d[start..<start + len])) && d[start] != 0 {
                return true
            }
        }
        return false
    }

    static func luhn(_ digits: [Int]) -> Bool {
        guard digits.count >= 13 else { return false }
        var sum = 0
        for (i, d) in digits.reversed().enumerated() {
            if i % 2 == 1 {
                let x = d * 2
                sum += x > 9 ? x - 9 : x
            } else {
                sum += d
            }
        }
        return sum % 10 == 0
    }

    // MARK: one-time codes

    private static let codeWords = ["code", "otp", "passcode", "verification", "pin", "tan",
                                    "كود", "رمز", "التحقق", "تحقق", "bestätigungscode", "sicherheitscode"]

    /// A text that is only a 4–8 digit code ("482913", "482 913"),
    /// or a message that mentions a code word together with such a number.
    static func isOneTimeCode(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let compact = t.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        if (4...8).contains(compact.count), compact.allSatisfy({ $0.isASCII && $0.isNumber }) { return true }
        let lower = t.lowercased()
        guard codeWords.contains(where: { lower.contains($0) }) else { return false }
        return t.range(of: #"(?<![0-9])[0-9]{4,8}(?![0-9])"#, options: .regularExpression) != nil
    }

    // MARK: passwords

    /// One word (no spaces), 8–64 characters, mixing at least 3 of: lower, upper, digits, symbols,
    /// and not a link, e-mail or file path.
    static func looksLikePassword(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (8...64).contains(t.count), !t.contains(where: { $0.isWhitespace }) else { return false }
        if t.contains("://") || t.hasPrefix("/") || t.hasPrefix("~") || t.hasPrefix("www.") { return false }
        if t.range(of: #"^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$"#, options: .regularExpression) != nil { return false }
        var lower = false, upper = false, digit = false, symbol = false
        for ch in t {
            if ch.isLowercase { lower = true }
            else if ch.isUppercase { upper = true }
            else if ch.isNumber { digit = true }
            else { symbol = true }
        }
        let classes = [lower, upper, digit, symbol].filter { $0 }.count
        return classes >= 3 && (digit || symbol)
    }

    // MARK: IBAN

    private static let ibanPattern = #"\b[A-Z]{2}[0-9]{2}(?:[ ]?[A-Z0-9]){11,30}\b"#

    static func maskIBANs(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: ibanPattern) else { return text }
        var result = text
        let ns = text as NSString
        for m in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed() {
            let raw = ns.substring(with: m.range)
            let compact = raw.replacingOccurrences(of: " ", with: "")
            guard isValidIBAN(compact) else { continue }
            let masked = String(compact.prefix(4)) + " •••• •••• •••• " + String(compact.suffix(4))
            result = (result as NSString).replacingCharacters(in: m.range, with: masked)
        }
        return result
    }

    static func isValidIBAN(_ iban: String) -> Bool {
        guard (15...34).contains(iban.count) else { return false }
        let rearranged = iban.dropFirst(4) + iban.prefix(4)
        var remainder = 0
        for ch in rearranged {
            let value: Int
            if let d = ch.wholeNumberValue { value = d }
            else if let a = ch.asciiValue, ch.isUppercase { value = Int(a) - 55 }
            else { return false }
            for digit in String(value) {
                remainder = (remainder * 10 + digit.wholeNumberValue!) % 97
            }
        }
        return remainder == 1
    }
}
