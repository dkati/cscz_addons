@echo off
rem Downloads the newest version of the CS:CZ mod from GitHub and installs it (also works on
rem a PC without the mod). Extra arguments are passed through, e.g. -Force or -GameDir "D:\Games\Half-Life".
rem The updater script itself is downloaded fresh from GitHub each time.
set "UPD=%TEMP%\cscz_update.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/dkati/cscz_addons/main/scripts/update.ps1' -OutFile $env:TEMP\cscz_update.ps1"
if errorlevel 1 (
    echo Could not download the updater from GitHub. Check the internet connection.
    pause
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%UPD%" %*
