# Changelog

## 2026-11 — current
- **install.ps1** unified installer: `-Uninstall`, `-PersistReboot`, `-FontStack`
- RTL is applied **only to Persian-dominant text blocks**; buttons, icons and layout stay untouched
- Injection now reaches **every Electron frame** via `webFrameMain` (the agent chat is an
  out-of-process iframe served from a local HTTP server)
- Font handling made idempotent and offline-capable: bundled Vazirmatn, locked-file safe
  copy, `AddFontResource` + `WM_FONTCHANGE`, download skipped when already installed
- Login/Startup pass restarts a running Antigravity so the patch is guaranteed to load
- This repository ships only what the current version needs (legacy `install_oneclick.ps1` removed)
