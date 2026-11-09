# How Persian Gravity works (and why it needs all of this)

This is a field log of every obstacle found while making Antigravity IDE render Persian
correctly. Each section lists **the obstacle**, **why naïve approaches fail**, and **what
this tool does instead**.

---

## 1. There is no `app.asar`

Antigravity installs unpacked:

```
%LOCALAPPDATA%\Programs\Antigravity IDE\resources\app\
├── package.json          ← "type": "module", "main": "./out/main.js"
└── out\main.js           ← ~12 MB ESM bundle
```

Most "patch the UI" scripts out there extract/patch/repack `app.asar`. On this layout they
print *"file not found"* and exit `0` — silently doing nothing. **We patch `out/main.js`
directly**, no asar tooling, no Node, no npx.

## 2. The main bundle is ESM

Because `"type": "module"`, the classic CommonJS injection guard

```js
if (typeof electron_1 !== "undefined" && electron_1.app) { ... }   // never true here
```

compiles but **never runs** — the app still starts, so nothing looks broken and the patch is
invisible. We append a real ESM block ending with:

```js
import { app as __pgApp, session as __pgSession } from "electron";
```

Import declarations are hoisted, so appending them at the **end** of the file is legal and runs.

## 3. Identifier collisions crash the app

The bundle already binds many top-level names. Appending `import fs from "fs"` produces:

```
Uncaught Exception: SyntaxError: Identifier 'fs' has already been declared
```

So every symbol we add is uniquely prefixed (`__pgFsMod`, `__pgPathMod`, `__pgApp`,
`__pgSession`) and every re-run must **remove the previous block** (everything from our
marker comment to EOF) before appending — otherwise the second run duplicates imports and
the app dies at startup.

## 4. `insertCSS()` does not survive navigation

VS Code-style apps first load a boot document and then navigate to `vscode-file://…`. A
stylesheet added with `webContents.insertCSS()` on `dom-ready` is discarded by that
navigation — the promise resolves, the log says "ok", and nothing is styled. **Therefore we
use a session preload** (`session.registerPreloadScript({ type: "frame", … })`, with
`setPreloads` fallback), which the renderer executes at document start on every frame.

## 5. Session preloads miss `defaultSession` and out-of-process iframes

* `session.getAllSessions()` **does not include** `defaultSession`; registering only from
  `getAllSessions()` styled the editor but not the chat.
* The agent chat is **not part of the main page**: it is served from
  `http://127.0.0.1:<port>/c/<uuid>?extensionView=true` and embedded as an iframe of the
  workbench. That frame is an OOPIF and did not receive the preload either.

Final design: register the preload on `session-created`, on `defaultSession`, and on every
session in `getAllSessions()` — **plus** walk the live frame tree from the main process:

```js
contents.on("did-frame-finish-load", () => injectAllFrames(contents));
function injectAllFrames(c) {
  (function walk(frame) {
    frame.executeJavaScript(preloadSource, true).catch(() => {});
    for (const child of frame.frames || []) walk(child);
  })(c.mainFrame);
}
```

`webFrameMain.executeJavaScript` reaches OOPIFs that preloads alone never touch.

## 6. Windows registers per-user fonts but does not load them

Copying a `.ttf` into `%LOCALAPPDATA%\Microsoft\Windows\Fonts` and writing the
`HKCU\…\Fonts` registry value makes GDI aware of the font — but Chromium (DirectWrite)
keeps falling back to **Segoe UI** (and Tahoma for Arabic script) until the font is actually
loaded into the session:

```csharp
[DllImport("gdi32.dll")]  AddFontResource(path);
[DllImport("user32.dll")] SendMessageTimeout(HWND_BROADCAST, WM_FONTCHANGE, …);
```

Without this step, a 100 % correct CSS patch looks completely broken. This is the single most
confusing failure mode in the whole project.

## 7. The app is single-instance

`Start-Process` on a running Antigravity just focuses the existing process: the old
in-memory `main.js` stays in charge, so a freshly written patch is never loaded. A taskkill
can also fail with *"the operation attempted is not supported"* on the main PID. Consequences:

* the installer tells the user to close the app **completely** (Task Manager);
* the Startup/persist pass, when it detects a running app, kills and relaunches it.

## 8. Styling rules: what must NOT be touched

* `* { font-family: … !important }` also hits **icon fonts** — every toolbar/tab icon turns
  into a blank box. Icon families must be restored explicitly:
  `.codicon, .codicon::before, [class*='codicon-'], .seti-icon { font-family: codicon !important }`.
* The editor (`.monaco-editor`) and terminal (`.xterm`) must stay monospace **and** LTR.
* Forcing `direction: rtl` on containers mirrors the whole layout — buttons and icons end up
  shuffled. Correct approach (current): only **Persian-dominant text blocks**
  (`p, li, h1-h6, td, th, blockquote, …`) are flipped, decided by counting Persian vs Latin
  letters:

  ```js
  if (persian >= latin) { el.style.setProperty('direction', 'rtl', 'important'); }
  else                  { el.style.setProperty('direction', 'ltr', 'important'); }
  ```

* Inline `style … !important` is used because the chat's own CSS loads **after** our
  injected stylesheet and wins ties (it sets `unicode-bidi: isolate` on paragraphs).
* The DOM scan runs **only inside the chat frame** and is throttled (400 ms); running it on
  the whole workbench DOM with a `MutationObserver` freezes the renderer
  ("CodeWindow: detected unresponsive").

## 9. Persistence across reboots and updates

An Antigravity update replaces `main.js`. A Startup shortcut
(`…\Startup\AntigravityRTLAutoPatch.cmd`) runs the installer with `-PersistReboot` at every
login: it re-applies the patch, then restarts Antigravity if it was already running. Font
downloads are skipped when fonts are already installed, so the login pass takes ~20 s and
works offline.

---

## Verification

```powershell
# main-process injection log (one line per frame, per load)
Get-Content "$env:USERPROFILE\antigravity-ui.log" -Tail 10

# expected on a healthy start:
#   pg-main-evaluated version=10
#   pg-preload registered on session-created / default
#   pg-inject-frames[1] did-frame-finish-load frames=3
```

Inside any frame you can confirm live state through Electron's DevTools protocol
(`--remote-debugging-port=9222`):

```js
document.getElementById('pg-rtl-style')      // base font layer
document.getElementById('pg-chat-rtl')       // chat-only layer (127.0.0.1 frames)
getComputedStyle(document.body).fontFamily   // "Vazirmatn, IRANSans, sans-serif"
```

Note: to test font availability, use **canvas** `measureText`, not DOM elements — the
injected `* !important` rule forces every element to the same family and hides the fallback.
