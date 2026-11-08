# Antigravity-IDE-RTL 🚀

Smart **RTL (right-to-left) alignment + Persian fonts (Vazirmatn / IRANSans)** injector for the **Antigravity IDE** (Google's VS Code-based agent IDE) on **Windows**.

One click → Persian font (IRANSans / Vazirmatn) across the whole UI **including the AI agent chat**, right-aligned Persian paragraphs, icons and the code editor untouched.

> Tested on: `Antigravity IDE` (unpacked `resources/app/out/main.js` ESM layout), Windows 11 — Nov 2026

---

## Why is this tricky?

Antigravity IDE is not a plain Electron app you can patch with a CSS snippet:

| Obstacle | What breaks naïve approaches |
|---|---|
| **Unpacked ESM main bundle** | No `app.asar`; patching scripts written for asar silently do nothing. The bundle is ESM (`"type": "module"`), so CJS-style injections (`typeof electron_1`) never run |
| **Top-level identifier clashes** | Appending `import fs from "fs"` to the main bundle crashes at startup: `Identifier 'fs' has already been declared` |
| **`insertCSS()` does not survive navigation** | VS Code-style apps navigate from a boot page to `vscode-file://` — the stylesheet silently vanishes |
| **The agent chat is not part of the main page** | It is served from a local HTTP server and embedded as an `<iframe>`; and webviews run in separate Electron `session`s |
| **`session.getAllSessions()` misses `defaultSession`** | Registering a session preload only there styles the IDE but *not* the chat |
| **Per-user fonts are not "loaded" by copying + registry** | Windows needs `AddFontResource` + `WM_FONTCHANGE` broadcast, otherwise Chromium silently falls back to Segoe UI / Tahoma and the patch "looks" broken |

This installer solves **all of the above**.

---

## What it does

1. **Loads Persian fonts into the live Windows session** — Vazirmatn is auto-downloaded (OFL); IRANSans used only if present locally via `AddFontResource` + `WM_FONTCHANGE` — plus copies + registers per-user.
2. **Writes a renderer preload** (`~/.antigravity-rtl-preload.js`) that injects the CSS at document start:
   - `font-family: 'Vazirmatn', 'IRANSans'` everywhere (⚠ protected: no naive `*` reset — see exclusions)
   - **Icon fonts restored**: `.codicon`, `[class*="codicon-"]`, `.seti-icon` stay `codicon`
   - **Editor & terminal stay monospace + LTR**: `.monaco-editor`, `.xterm`
   - **Persian paragraphs right-aligned**: `unicode-bidi: plaintext; text-align: start`
   - Re-applied by `setInterval` guard (survives chat re-renders)
3. **Patches `out/main.js` (v7)**: appends an ESM block that registers the preload on **every session** — `app.on("session-created")` + `defaultSession` + `getAllSessions()` — so the main UI, webviews, *and* the agent-chat iframe are all covered. Backs up to `main.js.bak`. Idempotent + self-cleaning (re-running replaces the old block).
4. **Updates editor `settings.json`** with the Persian font stack.
5. **Registers a Startup shortcut** (`AntigravityRTLAutoPatch.cmd`) so the patch self-heals after login.

Nothing here needs Administrator rights.

---

## Install

### One click

1. Nothing to prepare — the installer downloads **Vazirmatn** (OFL-licensed) from the official repo automatically. (Optional: if you have IRANSans locally at `D:\Font\IRANSans`, it is used as a bonus fallback.)
2. Double-click **`Install-RTL.cmd`** (or run `install_oneclick.ps1`).
3. **Fully close Antigravity IDE** (check Task Manager!) and reopen it.

Done. Persian UI + RTL chat.

### Re-apply after an Antigravity update

Run `Install-RTL.cmd` again. It detects a replaced/old patch, strips it, and re-applies v7.

### Uninstall

```powershell
Copy-Item "$env:LOCALAPPDATA\Programs\Antigravity IDE\resources\app\out\main.js.bak" `
           "$env:LOCALAPPDATA\Programs\Antigravity IDE\resources\app\out\main.js" -Force
Remove-Item "$env:USERPROFILE\.antigravity-rtl-preload.js", `
  "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\AntigravityRTLAutoPatch.cmd" -ErrorAction SilentlyContinue
```
Then restart the IDE.

---

## How to verify the patch is alive

```powershell
# main process injection log
Get-Content "$env:USERPROFILE\antigravity-ui.log" -Tail 10
# expect lines like: pg-preload registered on default / session-created
```

Still looking like Segoe UI? Nine times out of ten the **font is registered but not loaded** — log off/on (or re-run the installer) and it appears.

---

## Files

| File | Purpose |
|---|---|
| `install_oneclick.ps1` | Full installer (fonts + preload + main.js v7 patch + settings + startup) |
| `Install-RTL.cmd` | Double-clickable launcher for the installer |

---

## Credits

- Inspired by [Persian Gravity (Antigravity-RTL)](https://github.com/) — in memory of **Saber Rastikerdar**, creator of Vazirmatn.
- Fonts: [IRANSans](https://github.com/rastikerdar/) , [Vazirmatn](https://github.com/rastikerdar/vazirmatn) — check each font's license before redistribution.

## License

MIT
