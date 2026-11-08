# ============================================================
#  Persian Gravity - One-Click RTL + Font Setup (v7)
#  Antigravity IDE (unpacked ESM layout) - Windows
#  Run with: PowerShell  (no admin needed)
#  Re-run any time (also after app updates) - it is idempotent.
# ============================================================
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
# Primary: Vazirmatn (OFL licensed, redistributable) - downloaded from official repo
$zip = "$env:TEMP\vazirmatn.zip"
$dir = "$env:TEMP\vazirmatn_extract"
$ok = Test-Path (Join-Path $dst "Vazirmatn-Regular.ttf")
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
                Copy-Item $_.FullName $t -Force -ErrorAction SilentlyContinue
                [PGLoad]::AddFontResource($t) | Out-Null
                New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -Name ($_.BaseName + " (TrueType)") -Value $_.Name -Force -ErrorAction SilentlyContinue | Out-Null
            }
            Remove-Item $zip, $dir -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            $t = Join-Path $dst "Vazirmatn-Regular.ttf"
            Invoke-WebRequest -Uri $url -OutFile $t -UseBasicParsing -TimeoutSec 120
            [PGLoad]::AddFontResource($t) | Out-Null
            New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -Name "Vazirmatn (TrueType)" -Value "Vazirmatn-Regular.ttf" -Force -ErrorAction SilentlyContinue | Out-Null
        }
        $ok = $true; break
    } catch { Log "font source failed: $url -> $($_.Exception.Message)" }
}
if (-not $ok) { Log "WARNING: Vazirmatn download failed - trying any Vazirmatn already on disk" }

# Optional bonus: IRANSans, only if the user already has it locally (not redistributable)
Get-ChildItem "D:\Font\IRANSans" -Filter "IRANSans*.ttf" -ErrorAction SilentlyContinue | ForEach-Object {
    $t = Join-Path $dst $_.Name
    Copy-Item $_.FullName $t -Force -ErrorAction SilentlyContinue
    [PGLoad]::AddFontResource($t) | Out-Null
    New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -Name ($_.BaseName + " (TrueType)") -Value $_.Name -Force -ErrorAction SilentlyContinue | Out-Null
}

# Load EVERY Persian font already in the user font dir (covers offline re-runs)
Get-ChildItem $dst -Filter "Vazirmatn*.ttf" -ErrorAction SilentlyContinue | ForEach-Object { [PGLoad]::AddFontResource($_.FullName) | Out-Null }
$res = [IntPtr]::Zero
[PGLoad]::SendMessageTimeout([IntPtr]0xFFFF, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$res) | Out-Null
Log "fonts ready."

# ---------- 2. Preload file (the actual CSS injector) ----------
Log "2/5 Writing renderer preload..."
$fontStack = "'Vazirmatn', 'IRANSans', sans-serif"
$css = @"
* { font-family: $fontStack !important; }
.codicon, .codicon::before, [class*='codicon-'], .seti-icon, .monaco-workbench .icon { font-family: codicon !important; }
.monaco-editor, .monaco-editor *, .xterm, .xterm * { font-family: Consolas, Menlo, monospace !important; direction: ltr !important; unicode-bidi: normal !important; text-align: left !important; }
p, li, h1, h2, h3, h4, h5, h6, textarea, label, div, span { unicode-bidi: plaintext !important; text-align: start !important; }
"@
$preload = @"
try {
  const css = [$(($css -split "`n" | ForEach-Object { "    " + $_.Replace("'", "\'") + "," }) -join "`n")].join(String.fromCharCode(10));
  function __pgAdd() {
    try {
      if (document.getElementById('pg-rtl-style')) return;
      const st = document.createElement('style');
      st.id = 'pg-rtl-style';
      st.textContent = css;
      (document.head || document.documentElement).appendChild(st);
    } catch (e) {}
  }
  __pgAdd();
  document.addEventListener('DOMContentLoaded', __pgAdd);
  setInterval(__pgAdd, 3000);
} catch (e) {}
"@
$PreloadPath = "$env:USERPROFILE\.antigravity-rtl-preload.js"
$preload | Out-File $PreloadPath -Encoding utf8
Log "preload written: $PreloadPath"

# ---------- 3. Patch main.js (session preload registration, v7) ----------
Log "3/5 Patching Antigravity main.js..."
$MainJs = "$env:LOCALAPPDATA\Programs\Antigravity IDE\resources\app\out\main.js"
if (-not (Test-Path $MainJs)) { Log "ERROR: $MainJs not found - install path changed?"; exit 1 }
$main = Get-Content $MainJs -Raw
if ($main -like "*__pgPreloadPath*") {
    # older v5/v6 patch present -> strip and re-apply v7 (keeps app code from the marker on)
    $idx = $main.IndexOf("// Antigravity RTL & Vazirmatn Font Injector")
    if ($idx -ge 0) { $main = $main.Substring(0, $idx).TrimEnd() }
    Copy-Item $MainJs "$MainJs.bak" -Force -ErrorAction SilentlyContinue
}
if ($main -notlike "*__pgPreloadPath*") {
    $inject = @'

// Antigravity RTL & Vazirmatn Font Injector (Persian Gravity) v7 - all sessions
import { app as __pgApp, session as __pgSession } from "electron";
import __pgFsMod from "fs";
import __pgPathMod from "path";
const __pgPreloadPath = __pgPathMod.join(process.env.USERPROFILE, ".antigravity-rtl-preload.js");
const __pgLog = (msg) => { try { __pgFsMod.appendFileSync(__pgPathMod.join(process.env.USERPROFILE, "antigravity-ui.log"), new Date().toISOString() + " " + msg + String.fromCharCode(10)); } catch (e) {} };
const __pgRegister = (ses, tag) => {
  try {
    if (!ses || ses.__pgDone) return; ses.__pgDone = true;
    if (typeof ses.registerPreloadScript === "function") ses.registerPreloadScript({ type: "frame", id: "pg-rtl-" + Math.random().toString(36).slice(2), filePath: __pgPreloadPath });
    else if (typeof ses.setPreloads === "function") ses.setPreloads([...(ses.getPreloads ? ses.getPreloads() : []), __pgPreloadPath]);
    __pgLog("pg-preload registered on " + tag);
  } catch (e) { __pgLog("pg-preload err " + tag + ": " + e); }
};
__pgApp.on("session-created", (ses) => __pgRegister(ses, "session-created"));
__pgApp.whenReady().then(() => {
  try { __pgRegister(__pgSession.defaultSession, "default"); } catch (e) { __pgLog("default reg err: " + e); }
  try { (__pgSession.getAllSessions ? __pgSession.getAllSessions() : []).forEach((ses, idx) => __pgRegister(ses, "existing-" + idx)); } catch (e) { __pgLog("scan err: " + e); }
});
'@
    Add-Content -Path $MainJs -Value $inject
    Log "main.js patched (v7). backup: main.js.bak"
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
start "" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%LOCALAPPDATA%\Antigravity-RTL\install_rtl_persist.ps1"
"@ | Out-File $cmd -Encoding ascii
Log "startup shortcut ready: $cmd"

Log ""
Log "DONE. Fully close Antigravity IDE (check Task Manager) and reopen it."
