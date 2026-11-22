<#
  CS:CZ Greek Mod - updater (OTA)

  Checks GitHub for the newest version of the mod (latest commit on the main branch of
  https://github.com/dkati/cscz_addons), and if the game doesn't have it yet: downloads that
  version as a zip, unpacks it to a temp folder and runs that version's installer
  (scripts\cscz-mod.ps1 -Action Install). Afterwards the installed commit is saved in
  Half-Life\_cscz_mod_backup\commit.txt, so the next run knows whether there is anything new.

  Works on a PC without the mod too: then it simply installs it.
  update.bat downloads the newest copy of this script from GitHub every time, so changes to the
  updater reach everyone automatically.

    -GameDir <path>   Half-Life folder (default: the normal Steam folder)
    -Force            reinstall even if already up to date (and install on a never-started game)
    -ZipFile <path>   (testing) install from a local zip instead of downloading
    -Commit <text>    (testing) commit name to record for -ZipFile
#>
param(
    [string]$GameDir = 'C:\Program Files (x86)\Steam\steamapps\common\Half-Life',
    [switch]$Force,
    [switch]$NoPause,
    [string]$ZipFile = '',
    [string]$Commit = ''
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'          # Invoke-WebRequest is very slow with the progress bar
$Repo = 'dkati/cscz_addons'
$Branch = 'main'
$StateDirName = '_cscz_mod_backup'

function Write-Info($msg) { Write-Host $msg }
function Write-Good($msg) { Write-Host $msg -ForegroundColor Green }
function Write-Bad($msg)  { Write-Host $msg -ForegroundColor Red }

function Test-CanWrite {
    $probe = Join-Path $GameDir ('.cscz_write_test_' + [guid]::NewGuid().ToString('N'))
    try { [IO.File]::WriteAllText($probe, 'x'); [IO.File]::Delete($probe); return $true }
    catch [UnauthorizedAccessException] { return $false }
}

$exitCode = 0
$tmp = $null
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    if (-not [IO.File]::Exists((Join-Path $GameDir 'hl.exe'))) {
        if ($NoPause) { throw "Half-Life folder not found: $GameDir (use -GameDir)" }
        Write-Bad "Half-Life not found at: $GameDir"
        $GameDir = (Read-Host 'Paste the path of your Half-Life folder (the one containing hl.exe)').Trim('" ')
        if (-not [IO.File]::Exists((Join-Path $GameDir 'hl.exe'))) { throw "hl.exe not found in: $GameDir" }
    }
    $GameDir = [IO.Path]::GetFullPath($GameDir).TrimEnd('\')
    Write-Info "Game folder: $GameDir"

    if (Get-Process -Name 'hl' -ErrorAction SilentlyContinue) {
        Write-Bad 'Counter-Strike is running. Close the game first and try again.'
        $exitCode = 1
        return
    }

    # Ask for admin rights up front if needed (the installer runs inside this process).
    if (-not (Test-CanWrite)) {
        Write-Info 'Administrator rights are needed to write to the game folder. Asking Windows...'
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-GameDir', "`"$GameDir`"")
        if ($Force) { $argList += '-Force' }
        if ($ZipFile) { $argList += @('-ZipFile', "`"$ZipFile`"", '-Commit', "`"$Commit`"") }
        Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
        $NoPause = $true
        return
    }

    # --- which version is newest, which one is installed
    if ($ZipFile) {
        $sha = if ($Commit) { $Commit } else { 'local' }
        $label = "$sha (local zip)"
    } else {
        Write-Info 'Checking GitHub for the newest version...'
        $r = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/commits/$Branch" `
                               -Headers @{ 'User-Agent' = 'cscz-mod-updater' }
        $sha = $r.sha
        $title = ($r.commit.message -split "`n")[0].Trim()
        $date = ([datetime]$r.commit.committer.date).ToString('yyyy-MM-dd')
        $label = "$($sha.Substring(0, 7)) $date $title"
    }
    $commitFile = Join-Path (Join-Path $GameDir $StateDirName) 'commit.txt'
    $installed = if ([IO.File]::Exists($commitFile)) { [IO.File]::ReadAllText($commitFile).Trim() } else { '' }
    $installedSha = ($installed -split ' ')[0]
    Write-Info ("Newest version:    " + $label)
    Write-Info ("Installed version: " + $(if ($installed) { $installed } else { '(none / unknown)' }))

    if (-not $Force -and $installedSha -and $sha.StartsWith($installedSha)) {
        Write-Good 'The mod is already up to date. Nothing to do.'
        return
    }

    # --- download + unpack
    $tmp = Join-Path $env:TEMP ('cscz_update_' + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($tmp)
    $zip = Join-Path $tmp 'mod.zip'
    if ($ZipFile) {
        Copy-Item -LiteralPath $ZipFile -Destination $zip
    } else {
        Write-Info 'Downloading the new version (about 100 MB, this can take a while)...'
        Invoke-WebRequest -UseBasicParsing -Uri "https://codeload.github.com/$Repo/zip/$sha" -OutFile $zip
    }
    Write-Info ('Downloaded {0:N0} MB. Unpacking...' -f ((Get-Item -LiteralPath $zip).Length / 1MB))
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $unpacked = Join-Path $tmp 'files'
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $unpacked)
    $root = @(Get-ChildItem -LiteralPath $unpacked -Directory)[0].FullName     # cscz_addons-<commit>
    $installer = Join-Path $root 'scripts\cscz-mod.ps1'
    if (-not [IO.File]::Exists($installer)) { throw "The download has no installer (scripts\cscz-mod.ps1)." }

    # --- install with that version's own installer
    Write-Info ''
    $installArgs = @{ Action = 'Install'; GameDir = $GameDir; NoPause = $true }
    if ($Force) { $installArgs['Force'] = $true }
    & $installer @installArgs
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        Write-Bad "The install did not complete (installer exit code $code). The old version is still recorded."
        $exitCode = $code
        return
    }
    [IO.File]::WriteAllText($commitFile, $label)
    Write-Good "Updated to: $label"
}
catch {
    Write-Bad "ERROR: $($_.Exception.Message)"
    $exitCode = 1
}
finally {
    if ($tmp -and [IO.Directory]::Exists($tmp)) {
        try { [IO.Directory]::Delete($tmp, $true) } catch { }
    }
    if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
}
exit $exitCode
