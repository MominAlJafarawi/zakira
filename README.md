<div align="center">

<img src="docs/icon.png" width="128" alt="Zakira icon">

# Zakira · ذاكرة الكتابة

**Your Mac's short-term memory.** The last things you typed, copied and captured, one click away.

**ذاكرة قصيرة لجهازك:** آخر شي كتبته ونسخته وصوّرته، بكبسة وحدة.

[**⬇️ Download for macOS**](https://github.com/MomenJafarawi/zakira/releases/latest) · macOS 14+ · Apple Silicon & Intel · English / العربية

[English](#english) · [العربية](#العربية)

<img src="docs/screenshots/panel-en-light.png" width="380" alt="Zakira panel in English"> <img src="docs/screenshots/panel-ar-dark.png" width="380" alt="Zakira panel in Arabic">

</div>

---

## English

Ever closed a window and lost the message you just wrote? Copied something new and lost what was on the clipboard? Zakira lives in your menu bar and quietly keeps the last few things for you.

### Features

- ✍️ **Typed text**: the last 10 things you typed in any app, split into **Sent** (you pressed Enter) and **Unsent** (you clicked away or stopped typing). Shift+Enter is treated as a new line, not a send.
- 📋 **Copied text**: the last 10 texts you copied.
- 📸 **Screenshots**: the last 10 screenshots, from every method (Cmd+Shift+3/4/5 and the clipboard-only Ctrl+Cmd+Shift+3/4). Click to copy, or drag into any app.
- 📌 **Pinned**: keep important lines forever (stored encrypted in your Keychain).
- ⌨️ **Ctrl + Cmd + V** opens the panel right next to your mouse pointer, in any app.
- 🔍 Search, keyboard navigation (↑ ↓ ↩), light and dark mode.
- 🌐 Arabic and English, with right-to-left layout for Arabic.
- 🎓 A short guide on first launch.

<img src="docs/screenshots/shots-en.png" width="380" alt="Screenshots tab"> <img src="docs/screenshots/settings-en.png" width="380" alt="Settings">

### Install

1. Download `Zakira-x.y.dmg` from [Releases](https://github.com/MomenJafarawi/zakira/releases/latest).
2. Open it and drag **Zakira** onto **Applications**.
3. Open Zakira. If macOS says the developer cannot be verified, go to **System Settings → Privacy & Security** and click **Open Anyway**. Zakira is not signed with a paid Apple Developer ID, so this is needed once.
4. Follow the guide and turn on **Input Monitoring** for Zakira. Without it, copied text and screenshots still work, but typed text is not saved.

<img src="docs/screenshots/guide-en.png" width="560" alt="First-launch guide">

### Privacy

Zakira was built to keep your data on your Mac:

- **No network code at all.** It never connects to the internet.
- **Typed and copied text stays in memory** and is gone when you quit.
- **Pinned text** is stored encrypted in your macOS Keychain.
- **Password fields** are blocked by macOS (Secure Input), and copies from password managers are skipped.
- **Excluded apps**: Passwords, Keychain Access, 1Password and Bitwarden by default, and you can add any app (for example your bank).
- **Clipboard screenshots** are saved in a private folder (`~/Library/Application Support/Zakira`) and deleted after 7 days. Your own screenshot files are only displayed, never moved or deleted.
- **Pause** recording at any time.

### ⚠️ Responsible use

Zakira records keystrokes on the Mac it runs on. Use it **only on your own Mac**. Installing it on someone else's computer to watch what they type is unethical and illegal in most countries.

### Build from source

Requires the Xcode Command Line Tools (`xcode-select --install`). No Xcode project needed.

```bash
./build.sh        # builds a universal app and installs it to /Applications
./make-dmg.sh     # builds and packs dist/Zakira-<version>.dmg
Tools/make-screenshots.sh   # re-renders the README screenshots with demo text
```

If a code-signing identity named `Zakira Code Signing` exists in your Keychain, the build uses it. Otherwise it falls back to an ad-hoc signature.

---

## العربية

<div dir="rtl">

صار معك إنك سكّرت نافذة وراحت الرسالة اللي كتبتها؟ أو نسخت شي جديد وضاع اللي كان منسوخ قبله؟ **ذاكرة الكتابة** برنامج صغير بيضل فوق بشريط المنيو، وبيحفظلك آخر الأشياء بهدوء.

### الميزات

- ✍️ **اللي كتبته:** آخر 10 أشياء كتبتها بأي برنامج، مقسومين لقسمين: **بالإنتر** (بعتّها) و**بدون إنتر** (تركتها أو ضغطت بمكان تاني). و Shift+Enter بينحسب سطر جديد، مش إرسال.
- 📋 **اللي نسخته:** آخر 10 نصوص نسختها.
- 📸 **لقطات الشاشة:** آخر 10 لقطات، من كل الطرق (Cmd+Shift+3/4/5 واللقطات اللي بتروح للحافظة Ctrl+Cmd+Shift+3/4). كبسة بتنسخها، أو بتسحبها لأي برنامج.
- 📌 **المثبتة:** جمل مهمة بتضل دايماً، ومحفوظة مشفّرة بالـ Keychain.
- ⌨️ **Ctrl + Cmd + V** بيفتح اللوحة جنب الماوس، بأي برنامج.
- 🔍 بحث، وتنقّل بالكيبورد (↑ ↓ ↩)، ووضع فاتح وداكن.
- 🌐 عربي وإنجليزي، والعربي من اليمين لليسار.
- 🎓 دليل قصير أول ما تفتحه.

<img src="docs/screenshots/copied-ar-light.png" width="380" alt="تبويب النسخ"> <img src="docs/screenshots/guide-ar.png" width="380" alt="شاشة الترحيب">

### التثبيت

1. نزّل ملف `Zakira-x.y.dmg` من [Releases](https://github.com/MomenJafarawi/zakira/releases/latest).
2. افتحه واسحب **Zakira** على مجلد **Applications**.
3. افتح البرنامج. إذا ماك قال إنه "لا يمكن التحقق من المطوّر"، روح على **الإعدادات ← Privacy & Security** واضغط **Open Anyway**. هاد لأن البرنامج مش موقّع بحساب مطوّر مدفوع من Apple، ومرة وحدة بس.
4. اتبع الدليل وفعّل إذن **Input Monitoring**. بدونه، النسخ واللقطات بيشتغلوا عادي، بس الكتابة ما بتنحفظ.

### الخصوصية

- **ما في أي اتصال بالإنترنت** بالكود كله.
- **الكتابة والنسخ بالذاكرة بس**، وبتنمحي لما تسكّر البرنامج.
- **الجمل المثبتة** مشفّرة بالـ Keychain.
- **حقول الباسوورد** ماك بيحجبها، والمنسوخ من برامج الباسوردات بيتجاهله.
- **برامج مستثناة:** Passwords و Keychain Access و 1Password و Bitwarden، وبتقدر تضيف أي برنامج، متل البنك.
- **لقطات الحافظة** بمجلد خاص، وبتنمسح بعد 7 أيام. لقطاتك العادية بيعرضها بس، وما بيحذفها ولا بينقلها.
- **إيقاف مؤقت** وقت ما بدك.

### ⚠️ الاستعمال المسؤول

البرنامج بيسجّل الكتابة على الجهاز اللي بيشتغل عليه. استعمله **على جهازك الشخصي بس**. تثبيته على جهاز حدا تاني لمراقبة كتابته مش أخلاقي، وممنوع قانونياً بأغلب الدول.

</div>

---

## License

[MIT](LICENSE) © 2026 [Momen Jafarawi](https://github.com/MomenJafarawi)
