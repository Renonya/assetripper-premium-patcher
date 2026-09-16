@echo off
title AssetRipper Premium Patcher
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Patcher.ps1" %*
echo.
pause
