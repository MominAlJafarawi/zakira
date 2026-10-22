# Tester checklist · قائمة التجربة

Thank you for testing Zakira! It takes about 10 minutes. Please write ✅ or ❌ next to each step and send it back, with your Mac model and macOS version ( > About This Mac).

شكراً إنك عم تجرّب Zakira! بتاخد تقريباً 10 دقائق. حط ✅ أو ❌ جنب كل خطوة وابعتها، مع نوع جهازك ونسخة macOS ( ← About This Mac).

| # | Step | الخطوة | ✅/❌ |
|---|------|--------|------|
| 1 | Download the DMG from Releases, drag Zakira to Applications, open it. Did "Open Anyway" in Privacy & Security work? | نزّل الـ DMG، اسحب Zakira لـ Applications وافتحه. هل زبط "Open Anyway"؟ | |
| 2 | The guide opens. Turn on Input Monitoring as it explains. Does it show ✅? | بيفتح الدليل. فعّل Input Monitoring. هل بتطلع ✅؟ | |
| 3 | Type a message in any app and press Enter. Click the brain icon: is it under **Typed → Sent**? | اكتب رسالة واضغط Enter. هل بتظهر بـ **كتبتها ← بالإنتر**؟ | |
| 4 | Type something, then click somewhere else without Enter. Is it under **Unsent**? | اكتب شي واضغط بمكان تاني بدون Enter. هل بيظهر بـ **بدون إنتر**؟ | |
| 5 | Copy a text (Cmd+C). Is it under **Copied**? | انسخ نص. هل بيظهر بـ **نسختها**؟ | |
| 6 | Take a screenshot with Cmd+Shift+4. Is it under **Shots** right away? | صوّر بـ Cmd+Shift+4. هل بتظهر فوراً بـ **لقطات**؟ | |
| 7 | Take one with Ctrl+Cmd+Shift+4 (clipboard). Is it under **Shots** (not Copied)? | صوّر بـ Ctrl+Cmd+Shift+4. هل بتظهر بـ **لقطات** مش بـ نسختها؟ | |
| 8 | Press Ctrl+Cmd+V in any app. Does the panel open next to the mouse? | اضغط Ctrl+Cmd+V. هل بتفتح اللوحة جنب الماوس؟ | |
| 9 | Type a fake card number `4111 1111 1111 1111` and press Enter. It must **not** appear anywhere. | اكتب رقم البطاقة الوهمي `4111 1111 1111 1111` واضغط Enter. لازم **ما يظهر** أبداً. | |
| 10 | Switch the language in Settings (العربية / English). Does everything change? | بدّل اللغة من الإعدادات. هل كل شي بيتغيّر؟ | |

Anything strange? Turn on **Settings → Diagnostic mode**, repeat the step, then send `~/Library/Logs/Zakira.log` (it never contains what you typed).

في شي غريب؟ شغّل **الإعدادات ← وضع التشخيص**، عيد الخطوة، وابعت ملف `~/Library/Logs/Zakira.log` (ما فيه أي شي من كتابتك).
