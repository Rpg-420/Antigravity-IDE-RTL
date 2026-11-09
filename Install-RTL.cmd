@echo off
chcp 65001 >nul
echo Installing Persian Gravity (RTL + Vazirmatn) for Antigravity IDE...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
echo.
echo When it says DONE, close Antigravity IDE completely and reopen it.
pause
