@echo off
title LapTrack starten
cd /d "%~dp0"
echo LapTrack wordt gestart...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0LapTrackServer.ps1"
pause
