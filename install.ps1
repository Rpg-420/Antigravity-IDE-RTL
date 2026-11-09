# =====================================================================
#  Persian Gravity — RTL + Persian fonts for Antigravity IDE (Windows)
#  https://github.com/Rpg-420/Antigravity-IDE-RTL
#
#  Usage:
#     .\install_oneclick.ps1                 Install / update the patch
#     .\install_oneclick.ps1 -Uninstall      Remove everything it added
#     .\install_oneclick.ps1 -PersistReboot  (used by the Startup shortcut)
#     .\install_oneclick.ps1 -FontStack "'MyFont', 'Vazirmatn'"
#
#  No administrator rights required. Idempotent: run it as often as you like
#  (also after every Antigravity update).
# =====================================================================
param(
    [switch]$Uninstall,
    [switch]$PersistReboot,
    [string]$FontStack = "'Vazirmatn', 'IRANSans', sans-serif"
)

$ErrorActionPreference = "Continue"
$Root       = $env:LOCALAPPDATA + "\Antigravity-RTL"
$LogFile    = "$Root\installer.log"
$PreloadPath = $env:USERPROFILE + "\.antigravity-rtl-preload.js"
$StartupCmd  = $env:APPDATA + "\Microsoft\Windows\Start Menu\Programs\Startup\AntigravityRTLAutoPatch.cmd"
New-Item -Path $Root -ItemType Directory -Force | Out-Null

function Log($m) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" | Out-File $LogFile -Append -Encoding utf8
    Write-Host $m
}
function Find-AppRoot {
    $cands = @(
        "$env:LOCALAPPDATA\Programs\Antigravity IDE",
        "$env:LOCALAPPDATA\Programs\Antigravity",
        "$env:LOCALAPPDATA\Programs\antigravity",
        "$env:ProgramFiles\Antigravity IDE",
        ((Get-Item "env:ProgramFiles(x86)" -ErrorAction SilentlyContinue).Value + "\Antigravity IDE")
    )
    foreach ($c in $cands) { if (Test-Path "$c\resources\app\out\main.js") { return $c } }
    return $null
}

Log "==================================================="
Log " Persian Gravity — Antigravity IDE RTL + fonts"
Log "==================================================="

# ---------------------------------------------------------------- uninstall
if ($Uninstall) {
    Log "UNINSTALL requested."
    $appRoot = Find-AppRoot
    if ($appRoot) {
        $main = "$appRoot\resources\app\out\main.js"
        if (Test-Path "$main.bak") {
            $bak = Get-Content "$main.bak" -Raw
            if ($bak -match "__pgPreloadPath|pg-inject-frames") {
                Log "NOTE: main.js.bak also looks patched; rebuilding a clean main.js instead."
                $idx = (Get-Content $main -Raw).IndexOf("// Antigravity RTL")
                if ($idx -ge 0) { Set-Content -Path $main -Value (Get-Content $main -Raw).Substring(0, $idx).TrimEnd() -Encoding UTF8 }
            } else {
                Copy-Item "$main.bak" $main -Force
                Log "main.js restored from backup."
            }
        } else {
            # no backup: strip the appended block, everything from the first marker on
            $cur = Get-Content $main -Raw
            $idx = $cur.IndexOf("// Antigravity RTL")
            if ($idx -ge 0) { Set-Content -Path $main -Value $cur.Substring(0, $idx).TrimEnd() -Encoding UTF8; Log "Injector block removed from main.js." }
        }
    }
    Remove-Item $PreloadPath -Force -ErrorAction SilentlyContinue
    Remove-Item $StartupCmd -Force -ErrorAction SilentlyContinue
    Remove-Item "$Root\install_rtl_persist.ps1" -Force -ErrorAction SilentlyContinue
    Log "preload + startup shortcut removed. (Fonts left in place; delete them from Settings > Fonts if you want.)"
    Log "Fully close Antigravity IDE and reopen it. Done."
    exit 0
}

# ------------------------------------------------------------------- 1 fonts
Log "1/5 Persian fonts ..."
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class PGLoad {
    [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern int AddFontResource(string lpFilename);
    [DllImport("user32.dll")] public static extern int SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam, uint fuFlags, uint uTimeout, out IntPtr lpdwResult);
}
'@
$dst = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
New-Item -Path $dst -ItemType Directory -Force | Out-Null
$RegPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"

function Copy-FontSafe($src, $dstFile) {
    # fonts already loaded by the OS are locked; treat "present" as success
    try {
        if ((Test-Path $dstFile) -and ((Get-Item $dstFile).Length -eq (Get-Item $src).Length)) { return $true }
        Copy-Item $src $dstFile -Force -ErrorAction Stop
        return $true
    } catch {
        if (Test-Path $dstFile) { return $true }
        Log "  font copy skipped: $(Split-Path $dstFile -Leaf)"
        return $false
    }
}
function Install-FontDir($dir) {
    if (-not (Test-Path $dir)) { return 0 }
    $n = 0
    Get-ChildItem $dir -Filter "*.ttf" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $t = Join-Path $dst $_.Name
        if (Copy-FontSafe $_.FullName $t) {
            [PGLoad]::AddFontResource($t) | Out-Null
            New-ItemProperty -Path $RegPath -Name ($_.BaseName + " (TrueType)") -Value $_.Name -Force -ErrorAction SilentlyContinue | Out-Null
            $n++
        }
    }
    return $n
}

# a) fonts bundled with this repo (offline capable)
$installed = Install-FontDir (Join-Path $PSScriptRoot "fonts")
# b) optional extra families the user keeps next to the script
if (Test-Path (Join-Path $PSScriptRoot "fonts-extra")) { $installed += Install-FontDir (Join-Path $PSScriptRoot "fonts-extra") }
# c) common local drop folders (IRANSans etc. — not redistributable, so never bundled)
foreach ($extra in @("$PSScriptRoot\..\Font\IRANSans", "D:\Font\IRANSans")) { $installed += Install-FontDir $extra }

# d) download Vazirmatn if we still have nothing
if (-not (Test-Path (Join-Path $dst "Vazirmatn-Regular.ttf"))) {
    Log "  downloading Vazirmatn (OFL)..."
    $zip = "$env:TEMP\vazirmatn.zip"; $ex = "$env:TEMP\vazirmatn_ex"
    foreach ($url in @(
        "https://github.com/rastikerdar/vazirmatn/releases/download/v33.003/vazirmatn-v33.003.zip",
        "https://cdn.jsdelivr.net/gh/rastikerdar/vazirmatn@v33.003/fonts/ttf/Vazirmatn-Regular.ttf"
    )) {
        try {
            if ($url.EndsWith(".zip")) {
                Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -TimeoutSec 120
                if (Test-Path $ex) { Remove-Item $ex -Recurse -Force }
                Expand-Archive -Path $zip -DestinationPath $ex -Force
                $installed += Install-FontDir $ex
                Remove-Item $zip, $ex -Recurse -Force -ErrorAction SilentlyContinue
            } else {
                $tmp = "$env:TEMP\Vazirmatn-Regular.ttf"
                Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -TimeoutSec 120
                $t = Join-Path $dst "Vazirmatn-Regular.ttf"
                if (Copy-FontSafe $tmp $t) {
                    [PGLoad]::AddFontResource($t) | Out-Null
                    New-ItemProperty -Path $RegPath -Name "Vazirmatn (TrueType)" -Value "Vazirmatn-Regular.ttf" -Force -ErrorAction SilentlyContinue | Out-Null
                    $installed++
                }
            }
            break
        } catch { Log "  font source failed: $url" }
    }
}
# make sure every Persian font already on disk is loaded in this session
Get-ChildItem $dst -Filter "*.ttf" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match "Vazir|IRANSans|Sahel|Samim|Shabnam|Gandom" } |
    ForEach-Object { [PGLoad]::AddFontResource($_.FullName) | Out-Null }
$res = [IntPtr]::Zero
[PGLoad]::SendMessageTimeout([IntPtr]0xFFFF, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$res) | Out-Null
Log "  fonts handled (files touched this run: $installed)."

# ----------------------------------------------------------------- 2 preload
Log "2/5 Writing renderer preload ..."
$baseCssLine = "* { font-family: $FontStack !important; }"
$PreloadContent = @'
/*  Persian Gravity — renderer preload (v12)
    Injected into every Electron frame (main window + chat iframe) by the
    main-process patch. Fonts everywhere, icons and code untouched, and only
    Persian-dominant text blocks get right-to-left direction. */
try {
  const origin = (location && location.origin) ? location.origin : '';
  const isChatFrame = /^https?:\/\/127\.0\.0\.1(:\d+)?$/.test(origin);
  const baseCss = "__BASE_CSS__\n" +
    ".codicon, .codicon::before, [class*='codicon-'], .seti-icon, .monaco-workbench .icon { font-family: codicon !important; }\n" +
    ".monaco-editor, .monaco-editor *, .xterm, .xterm * { font-family: Consolas, Menlo, monospace !important; direction: ltr !important; unicode-bidi: normal !important; text-align: left !important; }\n" +
    "p, li, h1, h2, h3, h4, h5, h6, textarea, label { unicode-bidi: plaintext !important; text-align: start !important; }\n";
  const chatCss =
    "p, li, h1, h2, h3, h4, h5, h6, td, th, dt, dd, blockquote, figcaption { unicode-bidi: plaintext !important; }\n" +
    "pre, pre *, code, code *, kbd, samp, .monaco-editor, .monaco-editor * { direction: ltr !important; text-align: left !important; unicode-bidi: isolate !important; font-family: Consolas, Menlo, monospace !important; }\n" +
    "textarea, input, [contenteditable] { unicode-bidi: plaintext; }\n";

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

  /* Only Persian-dominant TEXT BLOCKS are flipped; buttons, icons, toolbars
     and the overall layout are never touched. */
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
        if (persian >= latin) {
          el.style.setProperty('direction', 'rtl', 'important');
          el.style.setProperty('text-align', 'right', 'important');
        } else {
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
$PreloadContent = $PreloadContent.Replace('__BASE_CSS__', $baseCssLine)
[IO.File]::WriteAllText($PreloadPath, $PreloadContent)   # UTF-8 without BOM
Log "  preload written: $PreloadPath"

# ---------------------------------------------------------------- 3 main.js
Log "3/5 Patching Antigravity main.js ..."
$appRoot = Find-AppRoot
if (-not $appRoot) {
    Log "ERROR: Antigravity IDE not found in the usual install locations."
    Log "       If you installed it elsewhere, open install_oneclick.ps1 and add your path to Find-AppRoot."
    exit 1
}
$MainJs = "$appRoot\resources\app\out\main.js"
$main = Get-Content $MainJs -Raw
$idx = $main.IndexOf("// Antigravity RTL")
if ($idx -ge 0) {
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
const __pgJs = () => { try { return __pgFsMod.readFileSync(__pgPreloadPath, "utf8"); } catch (e) { return ""; } };
const __pgInjectFrames = (c, tag) => {
  try {
    const code = __pgJs();
    if (!code) return;
    let count = 0;
    const walk = (fr) => {
      try { fr.executeJavaScript(code, true).then(() => {}).catch(() => {}); count++; } catch (e) {}
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
  const run = (tag) => __pgInjectFrames(c, tag);
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
    Log "  main.js patched (v10). backup: main.js.bak"
} else {
    Log "  main.js already patched."
}

# -------------------------------------------------------------- 4 settings
Log "4/5 Editor settings ..."
$uiRoot = "$env:APPDATA\Antigravity IDE\User"
if (-not (Test-Path $uiRoot)) { $uiRoot = "$env:APPDATA\antigravity\User" }
New-Item -Path $uiRoot -ItemType Directory -Force | Out-Null
$settingsPath = "$uiRoot\settings.json"
$fontLine = ($FontStack -replace "'", "") + ", Consolas, 'Courier New', monospace"
try {
    $json = if (Test-Path $settingsPath) { Get-Content $settingsPath -Raw | ConvertFrom-Json } else { $null }
    if ($json) {
        $json | Add-Member -NotePropertyName "editor.fontFamily" -NotePropertyValue $fontLine -Force
        $json | ConvertTo-Json -Depth 10 | Out-File $settingsPath -Encoding utf8
    } else {
        @{ "editor.fontFamily" = $fontLine; "editor.renderWhitespace" = "boundary" } | ConvertTo-Json | Out-File $settingsPath -Encoding utf8
    }
    Log "  settings.json updated."
} catch { Log "  settings.json update skipped: $($_.Exception.Message)" }

# ------------------------------------------------------------ 5 persistence
Log "5/5 Startup persistence ..."
Copy-Item $PSCommandPath "$Root\install_rtl_persist.ps1" -Force -ErrorAction SilentlyContinue
@'
@echo off
start "" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%LOCALAPPDATA%\Antigravity-RTL\install_rtl_persist.ps1" -PersistReboot
'@ | Out-File $StartupCmd -Encoding ascii
Log "  startup shortcut ready."

if ($PersistReboot) {
    # started at logon: guarantee the running app actually has the patch loaded
    $exe = "$appRoot\Antigravity IDE.exe"
    $running = @(Get-Process "Antigravity IDE" -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0 -and (Test-Path $exe)) {
        Log "  restarting the running Antigravity so the patch is loaded ..."
        $running | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 4
        Start-Process $exe
        Log "  Antigravity relaunched."
    }
    Log "persist pass done."
} else {
    Log ""
    Log "DONE. Now fully close Antigravity IDE (check Task Manager) and reopen it."
    Log "Verify any time with:  Get-Content `"$env:USERPROFILE\antigravity-ui.log`" -Tail 5"
}
