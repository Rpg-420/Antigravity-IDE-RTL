# ============================================================
#  Persian Gravity - One-Click RTL + Font Setup (v7)
#  Antigravity IDE (unpacked ESM layout) - Windows
#  Run with: PowerShell  (no admin needed)
#  Re-run any time (also after app updates) - it is idempotent.
# ============================================================
param([switch]$PersistReboot)
$ErrorActionPreference = "Continue"
$LogFile = "$env:LOCALAPPDATA\Antigravity-RTL\installer.log"
New-Item -Path (Split-Path $LogFile) -ItemType Directory -Force | Out-Null
function Log($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" | Out-File $LogFile -Append -Encoding utf8; Write-Host $m }

# ---------- 1. Fonts: download + install + LOAD into current session ----------
Log "1/5 Downloading Persian fonts (Vazirmatn)..."
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class PGLoad { [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern int AddFontResource(string lpFilename); [DllImport("user32.dll")] public static extern int SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam, uint fuFlags, uint uTimeout, out IntPtr lpdwResult); }'
$dst = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
New-Item -Path $dst -ItemType Directory -Force | Out-Null

# Zero: bundled fonts shipped inside this repo (offline fallback)
$BundledDir = Join-Path $PSScriptRoot "fonts\Vazirmatn"
if (Test-Path (Join-Path $BundledDir "Vazirmatn-Regular.ttf")) {
    Get-ChildItem $BundledDir -Filter "*.ttf" | ForEach-Object {
        $t = Join-Path $dst $_.Name
        Copy-Item $_.FullName $t -Force -ErrorAction SilentlyContinue
        [PGLoad]::AddFontResource($t) | Out-Null
        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -Name ($_.BaseName + " (TrueType)") -Value $_.Name -Force -ErrorAction SilentlyContinue | Out-Null
    }
    $res = [IntPtr]::Zero
    [PGLoad]::SendMessageTimeout([IntPtr]0xFFFF, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$res) | Out-Null
    Log "bundled Vazirmatn fonts installed."
}
# Primary: Vazirmatn (OFL). Skip download entirely when already installed.
$ok = Test-Path (Join-Path $dst "Vazirmatn-Regular.ttf")
if (-not $ok) {
    $zip = "$env:TEMP\vazirmatn.zip"
    $dir = "$env:TEMP\vazirmatn_extract"
    foreach ($url in @(
        "https://github.com/rastikerdar/vazirmatn/releases/download/v33.003/vazirmatn-v33.003.zip",
        "https://cdn.jsdelivr.net/gh/rastikerdar/vazirmatn@v33.003/fonts/ttf/Vazirmatn-Regular.ttf"
    )) {
        try {
            if ($url.EndsWith(".zip")) {
                Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -TimeoutSec 120
                if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
                Expand-Archive -Path $zip -DestinationPath $dir -Force
                Get-ChildItem $dir -Filter "*.ttf" -Recurse | ForEach-Object {
                    $t = Join-Path $dst $_.Name
                    if (Copy-FontSafe $_.FullName $t) {
                        [PGLoad]::AddFontResource($t) | Out-Null
                        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -Name ($_.BaseName + " (TrueType)") -Value $_.Name -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                }
                Remove-Item $zip, $dir -Recurse -Force -ErrorAction SilentlyContinue
            } else {
                $tmpT = "$env:TEMP\Vazirmatn-Regular.ttf"
                Invoke-WebRequest -Uri $url -OutFile $tmpT -UseBasicParsing -TimeoutSec 120
                $t = Join-Path $dst "Vazirmatn-Regular.ttf"
                if (Copy-FontSafe $tmpT $t) {
                    [PGLoad]::AddFontResource($t) | Out-Null
                    New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -Name "Vazirmatn (TrueType)" -Value "Vazirmatn-Regular.ttf" -Force -ErrorAction SilentlyContinue | Out-Null
                }
            }
            $ok = $true; break
        } catch { Log "font source failed: $url -> $($_.Exception.Message)" }
    }
}

# Optional bonus: IRANSans, only if the user already has it locally (not redistributable)
Get-ChildItem "D:\Font\IRANSans" -Filter "IRANSans*.ttf" -ErrorAction SilentlyContinue | ForEach-Object {
    $t = Join-Path $dst $_.Name
    if (Copy-FontSafe $_.FullName $t) {
        [PGLoad]::AddFontResource($t) | Out-Null
        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -Name ($_.BaseName + " (TrueType)") -Value $_.Name -Force -ErrorAction SilentlyContinue | Out-Null
    }
}

# Load EVERY Persian font already in the user font dir (covers offline re-runs)
Get-ChildItem $dst -Filter "Vazirmatn*.ttf" -ErrorAction SilentlyContinue | ForEach-Object { [PGLoad]::AddFontResource($_.FullName) | Out-Null }
$res = [IntPtr]::Zero
[PGLoad]::SendMessageTimeout([IntPtr]0xFFFF, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$res) | Out-Null
Log "fonts ready."

# ---------- 2. Preload file (the actual CSS injector) ----------
Log "2/5 Writing renderer preload..."
$fontStack = "'Vazirmatn', 'IRANSans', sans-serif"
$PreloadContent = @'
try {
  const origin = (location && location.origin) ? location.origin : '';
  const isChatFrame = /^https?:\/\/127\.0\.0\.1(:\d+)?$/.test(origin);
  const baseCss = "* { font-family: 'Vazirmatn', 'IRANSans', sans-serif !important; }\n.codicon, .codicon::before, [class*='codicon-'], .seti-icon, .monaco-workbench .icon { font-family: codicon !important; }\n.monaco-editor, .monaco-editor *, .xterm, .xterm * { font-family: Consolas, Menlo, monospace !important; direction: ltr !important; unicode-bidi: normal !important; text-align: left !important; }\np, li, h1, h2, h3, h4, h5, h6, textarea, label { unicode-bidi: plaintext !important; text-align: start !important; }\n";
  const chatCss = "p, li, h1, h2, h3, h4, h5, h6, td, th, dt, dd, blockquote, figcaption {\n  unicode-bidi: plaintext !important;\n}\npre, pre *, code, code *, kbd, samp, .monaco-editor, .monaco-editor * {\n  direction: ltr !important; text-align: left !important; unicode-bidi: isolate !important;\n  font-family: Consolas, Menlo, monospace !important;\n}\ntextarea, input, [contenteditable] { unicode-bidi: plaintext; }\n";

  function __pgEnsureTags() {
    try {
      let st = document.getElementById('pg-rtl-style');
      if (!st) { st = document.createElement('style'); st.id = 'pg-rtl-style'; (document.head || document.documentElement).appendChild(st); }
      if (st.textContent !== baseCss) st.textContent = baseCss;
      if (isChatFrame) {
        let cs = document.getElementById('pg-chat-rtl');
        if (!cs) { cs = document.createElement('style'); cs.id = 'pg-chat-rtl'; (document.head || document.documentElement).appendChild(cs); }
        if (cs.textContent !== chatCss) cs.textContent = chatCss;
      }
    } catch (e) {}
  }

  // Targeted: only Persian-bearing TEXT BLOCK elements get direction rtl.
  const SEL = 'p, li, h1, h2, h3, h4, h5, h6, td, th, dt, dd, blockquote, figcaption';
  function __pgScanChat() {
    if (!isChatFrame) return;
    try {
      const els = document.querySelectorAll(SEL);
      for (const el of els) {
        if (el.dataset && el.dataset.pgBidi === '1') continue;
        if (el.closest && el.closest('pre, code')) continue;
        const txt = el.textContent || '';
        if (!/[\u0600-\u06FF]/.test(txt)) continue;
        const latin = (txt.match(/[A-Za-z]/g) || []).length;
        const persian = (txt.match(/[\u0600-\u06FF]/g) || []).length;
        el.style.setProperty('unicode-bidi', 'plaintext', 'important');
        if (persian >= latin) {                      // Persian-dominant block -> right align
          el.style.setProperty('direction', 'rtl', 'important');
          el.style.setProperty('text-align', 'right', 'important');
        } else {                                      // mostly English -> keep LTR
          el.style.setProperty('direction', 'ltr', 'important');
          el.style.setProperty('text-align', 'left', 'important');
        }
        if (el.dataset) el.dataset.pgBidi = '1';
      }
    } catch (e) {}
  }

  __pgEnsureTags();
  __pgScanChat();
  document.addEventListener('DOMContentLoaded', function () { __pgEnsureTags(); __pgScanChat(); });

  if (isChatFrame) {
    let t = 0;
    const schedule = function () { if (t) return; t = setTimeout(function () { t = 0; __pgScanChat(); }, 400); };
    try { new MutationObserver(schedule).observe(document.documentElement, { childList: true, subtree: true }); } catch (e) {}
    setInterval(__pgEnsureTags, 3000);
  } else {
    setInterval(__pgEnsureTags, 5000);
  }
} catch (e) {}
'@

$PreloadPath = "$env:USERPROFILE\.antigravity-rtl-preload.js"
[IO.File]::WriteAllText($PreloadPath, $PreloadContent)   # UTF-8 without BOM
Log "preload written: $PreloadPath"

# ---------- 3. Patch main.js (session preload registration, v7) ----------
Log "3/5 Patching Antigravity main.js..."
$MainJs = "$env:LOCALAPPDATA\Programs\Antigravity IDE\resources\app\out\main.js"
if (-not (Test-Path $MainJs)) { Log "ERROR: $MainJs not found - install path changed?"; exit 1 }
$main = Get-Content $MainJs -Raw
$idx = $main.IndexOf("// Antigravity RTL")
if ($idx -ge 0) {
    # remove ALL previously appended injector blocks (everything from first marker to EOF)
    Copy-Item $MainJs "$MainJs.bak" -Force -ErrorAction SilentlyContinue
    $main = $main.Substring(0, $idx).TrimEnd()
    Set-Content -Path $MainJs -Value $main -Encoding UTF8
}
$main = Get-Content $MainJs -Raw
if ($main -notlike "*pg-inject-frames*") {
    $inject = @'

// Antigravity RTL & Vazirmatn Font Injector (Persian Gravity) v10 - frames covered
import { app as __pgApp, session as __pgSession } from "electron";
import __pgFsMod from "fs";
import __pgPathMod from "path";
const __pgPreloadPath = __pgPathMod.join(process.env.USERPROFILE, ".antigravity-rtl-preload.js");
const __pgLog = (msg) => { try { __pgFsMod.appendFileSync(__pgPathMod.join(process.env.USERPROFILE, "antigravity-ui.log"), new Date().toISOString() + " " + msg + String.fromCharCode(10)); } catch (e) {} };
const __pgJs = () => {
  try { return __pgFsMod.readFileSync(__pgPreloadPath, "utf8"); } catch (e) { return ""; }
};
const __pgInjectFrames = (c, tag) => {
  try {
    const code = __pgJs();
    if (!code) return;
    let count = 0;
    const walk = (fr) => {
      try {
        fr.executeJavaScript(code, true).then(() => {}).catch(() => {});
        count++;
      } catch (e) {}
      try { for (const child of (fr.frames || [])) walk(child); } catch (e) {}
    };
    walk(c.mainFrame);
    __pgLog("pg-inject-frames[" + c.id + "] " + tag + " frames=" + count);
  } catch (e) { __pgLog("pg-inject-frames err: " + e); }
};
const __pgRegister = (ses, tag) => {
  try {
    if (!ses || ses.__pgDone) return; ses.__pgDone = true;
    if (typeof ses.registerPreloadScript === "function") ses.registerPreloadScript({ type: "frame", id: "pg-rtl-" + Math.random().toString(36).slice(2), filePath: __pgPreloadPath });
    else if (typeof ses.setPreloads === "function") ses.setPreloads([...(ses.getPreloads ? ses.getPreloads() : []), __pgPreloadPath]);
    __pgLog("pg-preload registered on " + tag);
  } catch (e) { __pgLog("pg-preload err " + tag + ": " + e); }
};
__pgApp.on("session-created", (ses) => __pgRegister(ses, "session-created"));
__pgApp.on("web-contents-created", (_e, c) => {
  const run = (tag) => { __pgInjectFrames(c, tag); };
  c.on("dom-ready", () => run("dom-ready"));
  c.on("did-finish-load", () => run("did-finish-load"));
  c.on("did-frame-finish-load", () => run("did-frame-finish-load"));
  c.on("did-navigate", () => run("did-navigate"));
  c.on("did-navigate-in-page", () => run("did-navigate-in-page"));
});
__pgLog("pg-main-evaluated version=10");
__pgApp.whenReady().then(() => {
  try { __pgRegister(__pgSession.defaultSession, "default"); } catch (e) { __pgLog("default reg err: " + e); }
  try { (__pgSession.getAllSessions ? __pgSession.getAllSessions() : []).forEach((ses, idx) => __pgRegister(ses, "existing-" + idx)); } catch (e) { __pgLog("scan err: " + e); }
});
'@
    Add-Content -Path $MainJs -Value $inject
    Log "main.js patched (v10). backup: main.js.bak"
} else {
    Log "main.js already patched."
}

# ---------- 4. Editor settings ----------
Log "4/5 Editor settings..."
$SettingsPath = "$env:APPDATA\Antigravity IDE\User\settings.json"
New-Item -Path (Split-Path $SettingsPath) -ItemType Directory -Force | Out-Null
$existing = if (Test-Path $SettingsPath) { Get-Content $SettingsPath -Raw | ConvertFrom-Json } else { $null }
$fontLine = "Vazirmatn, IRANSans, Consolas, 'Courier New', monospace"
if ($existing) {
    $existing | Add-Member -NotePropertyName "editor.fontFamily" -NotePropertyValue $fontLine -Force
    $existing | ConvertTo-Json -Depth 10 | Out-File $SettingsPath -Encoding utf8
} else {
    @{ "editor.fontFamily" = $fontLine; "editor.renderWhitespace" = "boundary" } | ConvertTo-Json | Out-File $SettingsPath -Encoding utf8
}

# ---------- 5. Startup persistence ----------
Log "5/5 Startup persistence..."
$StartupDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
Copy-Item $PSCommandPath "$env:LOCALAPPDATA\Antigravity-RTL\install_rtl_persist.ps1" -Force
$cmd = "$StartupDir\AntigravityRTLAutoPatch.cmd"
@"
@echo off
start "" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%LOCALAPPDATA%\Antigravity-RTL\install_rtl_persist.ps1" -PersistReboot
"@ | Out-File $cmd -Encoding ascii
Log "startup shortcut ready: $cmd"

Log ""

if ($PersistReboot) {
    # after system reboot the single-instance app may be running with pre-patch code;
    # if it is running, kill it and relaunch so the patch is guaranteed loaded.
    $exe = "$env:LOCALAPPDATA\Programs\Antigravity IDE\Antigravity IDE.exe"
    $was = Get-Process "Antigravity IDE" -ErrorAction SilentlyContinue
    if (-not $was) { $was = @() }
    if ($was.Count -gt 0) {
        Log "persist: restarting running Antigravity to load patch..."
        Get-Process "Antigravity IDE" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 4
        Start-Process $exe
        Log "persist: Antigravity relaunched."
    }
}
if (-not $PersistReboot) { Log "DONE. Fully close Antigravity IDE (check Task Manager) and reopen it." }
