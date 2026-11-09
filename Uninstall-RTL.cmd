@echo off
chcp 65001 >nul
echo Removing Persian Gravity (RTL patch + preload + startup shortcut)...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Uninstall
pause
