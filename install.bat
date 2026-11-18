@echo off
rem Double-click to install the CS:CZ mod. Extra arguments are passed through (e.g. -DryRun).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\cscz-mod.ps1" -Action Install %*
