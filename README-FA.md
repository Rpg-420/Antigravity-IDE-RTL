# Antigravity-IDE-RTL 🚀

راست‌چین‌سازی هوشمند و فونت فارسی برای **Antigravity IDE** (محیط توسعه ایجنت-محور گوگل، بر پایه VS Code) روی **ویندوز**.

با یک کلیک: فونت فارسی (ایران‌سنس / وزیرمتن) در کل رابط کاربری **شامل چت ایجنت هوش مصنوعی**، تراز شدن پاراگراف‌های فارسی از راست، بدون دست‌خوردن آیکون‌ها و ادیتور کد.

> تست‌شده روی: `Antigravity IDE` (ساختار ESM باز‌شده در `resources/app/out/main.js`)، ویندوز ۱۱ — نوامبر ۲۰۲۶

---

## چرا این‌قدر پیچیده است؟

آنتي‌گراویتی یک اپ Electron ساده نیست که با یک تیکه CSS درست شود:

| مانع | نتیجه روی روش‌های ساده |
|---|---|
| **باندل اصلی ESM باز‌شده** | `app.asar` وجود ندارد؛ اسکریپت‌های نوشته‌شده برای asar بی‌صدا هیچ کاری نمی‌کنند. باندل ESM است (`"type": "module"`) پس تزریق به سبک CJS (`typeof electron_1`) هرگز اجرا نمی‌شود |
| **تصادم identifier در سطح بالا** | اضافه‌کردن `import fs from "fs"` به انتهای باندل → کرش موقع استارت: `Identifier 'fs' has already been declared` |
| **`insertCSS()` بعد از ناوبری از بین می‌رود** | اپ‌های VS Code-Like اول از صفحه boot به `vscode-file://` ناوبری می‌کنند — استایل بی‌صدا حذف می‌شود |
| **چت ایجنت بخشی از صفحه اصلی نیست** | از یک سرور HTTP محلی سرو می‌شود و به‌صورت `<iframe>` قرار می‌گیرد؛ و webviewها در `session`های جداگانه Electron اجرا می‌شوند |
| **`getAllSessions()` شامل `defaultSession` نیست** | ثبت preload فقط آنجا، ادیتور را فونت‌دار می‌کند ولی چت را نه |
| **کپی + رجیستری فونت کافی نیست** | ویندوز به `AddFontResource` + broadcast پیام `WM_FONTCHANGE` نیاز دارد؛ وگرنه Chromium بی‌صدا به Segoe UI / Tahoma برمی‌گردد و پچ «خراب» به نظر می‌رسد |

این نصب‌کننده همین‌ها را حل می‌کند.

---

## چه کاری انجام می‌دهد؟

1. **لود فونت فارسی در سشن جاری ویندوز** (ایران‌سنس از `D:\Font\IRANSans` و وزیرمتن اگر موجود باشد) با `AddFontResource` + `WM_FONTCHANGE`؛ به‌علاوه کپی و ثبت per-user.
2. **نوشتن یک renderer preload** (`~/.antigravity-rtl-preload.js`) که CSS را در اولین لحظهٔ ساخت سند تزریق می‌کند:
   - `font-family: 'IRANSans', 'Vazirmatn'` در کل UI
   - **آیکون‌ها محافظت شده**: `.codicon` و مشابه‌ها فونت خودشان را نگه می‌دارند
   - **ادیتور و ترمینال همچنان monospace و چپ‌چین**: `.monaco-editor` و `.xterm`
   - **پاراگراف‌های فارسی راست‌چین**: `unicode-bidi: plaintext; text-align: start`
   - گارد `setInterval` برای بازگشت استایل بعد از re-renderهای چت
3. **پچ `out/main.js` (نسخه v7)**: یک بلاک ESM به انتهای باندل اضافه می‌شود که preload را روی **همه sessionها** ثبت می‌کند — `app.on("session-created")` + `defaultSession` + `getAllSessions()` — تا صفحه اصلی، webviewها *و* iframe چت پوشش داده شوند. بکاپ در `main.js.bak`. اجرای دوباره 安全 است (بلاک قبلی پاک و نسخه جدید جایگزین می‌شود).
4. **به‌روزرسانی `settings.json`** با استک فونت فارسی.
5. **میان‌بر استارت‌آپ** (`AntigravityRTLAutoPatch.cmd`) برای خودترمیمی بعد از هر لاگین.

هیچ‌کدام نیاز به دسترسی Administrator ندارد.

---

## نصب

### یک‌کلیکی

1. فونت‌ها را در `D:\Font\IRANSans` بگذارید (یا مسیر را در اسکریپت عوض کنید).
2. روی **`Install-RTL.cmd`** دابل‌کلیک کنید (یا `install_oneclick.ps1` را اجرا کنید).
3. **آنتي‌گراویتی را کامل ببندید** (Task Manager را چک کنید!) و دوباره باز کنید.

تمام. کل UI فارسی و چت راست‌چین.

### بعد از آپدیت خود آنتي‌گراویتی

دوباره `Install-RTL.cmd` را اجرا کنید — پچ قبلی را تشخیص می‌دهد، پاک می‌کند و v7 را دوباره اعمال می‌کند.

### حذف

```powershell
Copy-Item "$env:LOCALAPPDATA\Programs\Antigravity IDE\resources\app\out\main.js.bak" `
           "$env:LOCALAPPDATA\Programs\Antigravity IDE\resources\app\out\main.js" -Force
Remove-Item "$env:USERPROFILE\.antigravity-rtl-preload.js", `
  "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\AntigravityRTLAutoPatch.cmd" -ErrorAction SilentlyContinue
```
سپس IDE را ری‌استارت کنید.

---

## بررسی سلامت پچ

```powershell
Get-Content "$env:USERPROFILE\antigravity-ui.log" -Tail 10
# خط‌هایی مثل این باید ببینید: pg-preload registered on default / session-created
```

اگر هنوز فونت Segoe UI می‌بینید، در ۹۰٪ موارد **فونت ثبت شده ولی در سشن لود نشده** — یک بار لاگ‌آف/لاگین کنید یا نصب‌کننده را دوباره اجرا کنید.

---

## فایل‌ها

| فایل | کاربرد |
|---|---|
| `install_oneclick.ps1` | نصب‌کننده کامل (فونت + preload + پچ v7 + تنظیمات + استارت‌آپ) |
| `Install-RTL.cmd` | لانچر دابل‌کلیکی |

---

## قدردانی

- الهام‌گرفته از پروژه Persian Gravity (Antigravity-RTL) — به یاد **صابر راستی‌کردار**، خالق وزیرمتن 🕯️
- فونت‌ها: [IRANSans] و [Vazirmatn](https://github.com/rastikerdar/vazirmatn) — قبل از بازنشر، لایسنس هر فونت را رعایت کنید.

## لایسنس

MIT
