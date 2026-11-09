# Antigravity-IDE-RTL — Persian RTL + Vazirmatn for Antigravity IDE 🚀

Right-to-left alignment and Persian fonts for **Antigravity IDE** (Google's VS Code-based agent IDE) on **Windows** — including the **AI agent chat panel**, the part other tools miss.

> One click: Persian fonts everywhere, Persian paragraphs right-aligned, icons and code left untouched.

---

## Quick start

1. **Download** this repository (Code → Download ZIP) and extract it anywhere.
2. **Double-click `Install-RTL.cmd`**
3. **Fully close Antigravity IDE** (check Task Manager — it keeps background processes) **and reopen it.**

That's it: Persian UI fonts + right-aligned Persian chat.

```
Antigravity-IDE-RTL/
├── Install-RTL.cmd        ← double-click me
├── Uninstall-RTL.cmd      ← removes everything again
├── install.ps1            ← the installer (-Uninstall / -PersistReboot / -FontStack)
├── fonts/Vazirmatn/       ← Vazirmatn bundled (SIL OFL) so it works offline
└── docs/HOW-IT-WORKS.md   ← the technical story
```

No administrator rights. Nothing to compile. Re-running is always safe (idempotent).

---

## What it does

| Area | Behaviour |
|---|---|
| **Fonts** | Vazirmatn (or your own stack) applied across the whole UI |
| **Agent chat** | Persian paragraphs, lists, headings and table cells are right-aligned; **English blocks stay LTR** |
| **Icons / buttons / toolbars** | never mirrored — icon fonts (`codicon`, `seti`) are explicitly protected |
| **Code editor & terminal** | stay monospace and left-to-right |
| **Persistence** | a Startup shortcut re-applies everything after each login and restarts Antigravity if it is already running with the old code |
| **Reversibility** | `Uninstall-RTL.cmd` restores `main.js` and removes every trace |

---

## Why does this need a "patch" at all?

Antigravity does not load VS Code extensions into its own UI, so an ordinary extension cannot style the app shell or the agent chat. Full breakdown in **[docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md)** — short version:

- the app ships an **unpacked ESM** `resources/app/out/main.js` (not `app.asar`), so asar-based patch scripts silently do nothing;
- it is **single-instance** — restarting hands off to the existing process, so a patch must force a real restart;
- the agent chat is a **cross-origin iframe** served from a local HTTP server; Electron session preloads alone never reach it, so this tool injects through `webFrameMain` into **every frame**;
- Windows only *registers* per-user fonts; without `AddFontResource` + `WM_FONTCHANGE` Chromium keeps falling back to Segoe UI, which makes a working patch look broken.

---

## Customising

```powershell
# use your own font stack (must be installed on the machine)
.\install.ps1 -FontStack "'IRANSans', 'Vazirmatn', sans-serif"
```

- **Extra fonts**: drop `.ttf` files into a `fonts-extra` folder next to `install.ps1`, or into `D:\Font\IRANSans` — both are picked up automatically.
- IRANSans is **not** bundled (its license is not redistributable). If you have it, the installer finds it and adds it to the stack.

---

## Verify / troubleshoot

```powershell
# did the patch actually load? one line per Electron frame:
Get-Content "$env:USERPROFILE\antigravity-ui.log" -Tail 5

# installer log
Get-Content "$env:LOCALAPPDATA\Antigravity-RTL\installer.log" -Tail 20
```

| Symptom | Fix |
|---|---|
| Nothing changed | Antigravity was still running → close it **completely** (Task Manager) and reopen |
| Chat has no Persian font | re-run `Install-RTL.cmd`, then fully restart the app |
| Text renders in Segoe UI | log off / log on once (fonts finish loading at login) or re-run the installer |
| After an Antigravity update | re-run `Install-RTL.cmd`, or let the Startup shortcut do it at next login |
| Buttons/icons look shuffled | you are on an old build that forced RTL globally — update to the current version |

---

## Requirements

- Windows 10/11
- Antigravity IDE in a standard location (`%LOCALAPPDATA%\Programs\Antigravity IDE`, `…\Antigravity`, or `Program Files\Antigravity IDE`)
- PowerShell 5.1 (built into Windows) — no admin, no Python, no Node
- Internet only for the optional font download (fonts are bundled, so offline works too)

---

## Credits

- In memory of **Saber Rastikerdar** 🕯️ — creator of Vazirmatn and many libre Persian fonts.
- [Vazirmatn](https://github.com/rastikerdar/vazirmatn) is licensed under the SIL Open Font License (see `fonts/Vazirmatn/OFL.txt`).

## License

MIT — see [LICENSE](LICENSE).
