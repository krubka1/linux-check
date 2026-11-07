@echo off
rem Runs Linux-Check.ps1 from this folder (no .exe needed). Read-only.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Linux-Check.ps1"
pause
