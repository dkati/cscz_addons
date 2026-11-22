<#
  CS:CZ Greek Mod - installer / uninstaller

  Install   : copies the mod into the game. Any game file that would be overwritten is
              backed up first, and every file/folder the mod adds is recorded.
  Uninstall : deletes what the mod added and puts the backed-up originals back.
              Works from the backup alone - it does not need this repo.
  Status    : shows whether the mod is installed.

  Re-running Install while the mod is installed first uninstalls the old version, so
  edits to the mod (including newly overridden stock files, or files you removed
  from the repo) are always applied against the original game files.

  Player settings (config.cfg) are never touched.

  Install refuses to run on a game that has never been started (no czero\config.cfg yet):
  on the first start Steam can still finish setting the game up and put its original files
  back over the mod's (e.g. the radio texts and the menu background). Start the game once,
  quit, then install. -Force installs anyway.
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Install', 'Uninstall', 'Status')]
    [string]$Action,

    [string]$GameDir = 'C:\Program Files (x86)\Steam\steamapps\common\Half-Life',

    # Show what would happen without changing anything.
    [switch]$DryRun,

    # Do not wait for Enter at the end (for running from a terminal).
    [switch]$NoPause,

    # Install even if the game has never been started.
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'mod_pack'

# ---------------------------------------------------------------------------
# What goes where. Paths are relative to mod_pack and to the Half-Life folder.
# If two sources provide the same destination file, the LATER line wins.
# ---------------------------------------------------------------------------
$Mappings = @(
    @{ From = 'czero_addon';        To = 'czero' }
    @{ From = 'cstrike_addon';      To = 'cstrike' }
    @{ From = 'czero_downloads';    To = 'czero_downloads' }
    @{ From = 'amx\addons';         To = 'czero\addons' }
    @{ From = 'amx\liblist.gam';    To = 'czero\liblist.gam' }
    @{ From = 'COPY TO ROOT';       To = '' }
    @{ From = 'COPY TO ROOT VALVE'; To = 'valve' }
    @{ From = 'COPY TO ROOT CZERO'; To = 'czero' }
)

# File names that are never copied (leftovers / temp files in the repo).
$ExcludeNames = @(
    '*.ztmp'
    'custom_DELETE*'
    'tempdecal_moveToCzeroRoot.wad'
)

# Game files the installer marks read-only after copying (a download or git checkout does not keep
# the flag). tempdecal.wad = the spray: read-only so Options > Multiplayer > OK can't replace it.
$ReadOnlyDest = @(
    'czero\tempdecal.wad'
)

# Game files that are never overwritten: the player's own settings.
$ProtectedDest = @(
    'czero\config.cfg'
    'cstrike\config.cfg'
    'valve\config.cfg'
)

$StateDirName = '_cscz_mod_backup'

# ---------------------------------------------------------------------------

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Info($msg)  { Write-Host $msg }
function Write-Good($msg)  { Write-Host $msg -ForegroundColor Green }
function Write-Bad($msg)   { Write-Host $msg -ForegroundColor Red }

function Get-StateDir    { Join-Path $GameDir $StateDirName }
function Get-Manifest    { Join-Path (Get-StateDir) 'manifest.txt' }
function Get-BackupRoot  { Join-Path (Get-StateDir) 'originals' }

function Join-Rel([string]$a, [string]$b) {
    if ([string]::IsNullOrEmpty($a)) { return $b }
    if ([string]::IsNullOrEmpty($b)) { return $a }
    return "$a\$b"
}

function Get-RelToGame([string]$full) {
    $root = $GameDir.TrimEnd('\') + '\'
    if (-not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside the game folder: $full"
    }
    return $full.Substring($root.Length)
}

function Clear-ReadOnly([string]$path) {
    if ([IO.File]::Exists($path)) {
        $attr = [IO.File]::GetAttributes($path)
        if ($attr -band [IO.FileAttributes]::ReadOnly) {
            [IO.File]::SetAttributes($path, $attr -bxor [IO.FileAttributes]::ReadOnly)
        }
    }
}

function Copy-FileForce([string]$src, [string]$dst) {
    $dir = [IO.Path]::GetDirectoryName($dst)
    if (-not [IO.Directory]::Exists($dir)) { [void][IO.Directory]::CreateDirectory($dir) }
    Clear-ReadOnly $dst
    [IO.File]::Copy($src, $dst, $true)
}

function Test-Excluded([string]$name, [string]$destRel) {
    foreach ($p in $ExcludeNames) { if ($name -like $p) { return $true } }
    foreach ($p in $ProtectedDest) { if ($destRel -ieq $p) { return $true } }
    return $false
}

# Returns the list of files to install: objects with Src (full path) and Dest (relative to game).
function Get-Plan {
    $plan = [ordered]@{}
    foreach ($m in $Mappings) {
        $src = Join-Path $RepoRoot $m.From
        $items = New-Object System.Collections.Generic.List[object]
        if ([IO.File]::Exists($src)) {
            $items.Add([pscustomobject]@{ Src = $src; Dest = $m.To })
        }
        elseif ([IO.Directory]::Exists($src)) {
            foreach ($f in [IO.Directory]::EnumerateFiles($src, '*', [IO.SearchOption]::AllDirectories)) {
                $items.Add([pscustomobject]@{ Src = $f; Dest = (Join-Rel $m.To $f.Substring($src.Length).TrimStart('\')) })
            }
        }
        else {
            Write-Warning "Source not found, skipping: $($m.From)"
            continue
        }
        foreach ($item in $items) {
            if (Test-Excluded ([IO.Path]::GetFileName($item.Src)) $item.Dest) { continue }
            $plan[$item.Dest.ToLowerInvariant()] = $item
        }
    }
    return @($plan.Values)
}

function Read-ManifestEntries {
    $path = Get-Manifest
    if (-not [IO.File]::Exists($path)) { return @() }
    foreach ($line in [IO.File]::ReadAllLines($path, $Utf8NoBom)) {
        if ($line -match '^([ARD])\t(.+)$') {
            [pscustomobject]@{ Kind = $Matches[1]; Rel = $Matches[2] }
        }
    }
}

function Test-GameRunning {
    $p = Get-Process -Name 'hl', 'hlds' -ErrorAction SilentlyContinue
    if ($p) {
        Write-Bad 'Counter-Strike is running. Close the game first and try again.'
        return $true
    }
    return $false
}

function Test-CanWrite {
    $probe = Join-Path $GameDir ('.cscz_write_test_' + [guid]::NewGuid().ToString('N'))
    try { [IO.File]::WriteAllText($probe, 'x'); [IO.File]::Delete($probe); return $true }
    catch [UnauthorizedAccessException] { return $false }
}

# ---------------------------------------------------------------------------

function Invoke-Uninstall {
    $entries = @(Read-ManifestEntries)
    if (-not [IO.Directory]::Exists((Get-StateDir))) {
        Write-Info 'The mod is not installed (no backup folder found). Nothing to do.'
        return
    }

    $added    = @($entries | Where-Object Kind -eq 'A')
    $replaced = @($entries | Where-Object Kind -eq 'R')
    $dirs     = @($entries | Where-Object Kind -eq 'D')

    Write-Info ("Removing {0} added files and {1} added folders, restoring {2} original game files..." -f `
        $added.Count, $dirs.Count, $replaced.Count)
    if ($DryRun) { Write-Info '(dry run - nothing changed)'; return }

    foreach ($e in $added) {
        $p = Join-Path $GameDir $e.Rel
        if ([IO.File]::Exists($p)) { Clear-ReadOnly $p; [IO.File]::Delete($p) }
    }

    # Folders the mod created, deepest first. They did not exist before the install, so
    # anything inside them (AMX logs, downloaded files, ...) belongs to the mod.
    foreach ($e in ($dirs | Sort-Object { $_.Rel.Length } -Descending)) {
        if ([string]::IsNullOrWhiteSpace($e.Rel)) { continue }
        $p = Join-Path $GameDir $e.Rel
        if ([IO.Directory]::Exists($p)) { [IO.Directory]::Delete($p, $true) }
    }

    $missing = 0
    foreach ($e in $replaced) {
        $bak = Join-Path (Get-BackupRoot) $e.Rel
        if ([IO.File]::Exists($bak)) { Copy-FileForce $bak (Join-Path $GameDir $e.Rel) }
        else { $missing++; Write-Warning "Backup missing, could not restore: $($e.Rel)" }
    }

    if ($missing -gt 0) {
        Write-Bad "$missing original files could not be restored. The backup folder was kept:"
        Write-Bad "  $(Get-StateDir)"
        Write-Bad 'In Steam you can use Properties > Installed Files > Verify integrity to repair them.'
        return
    }

    [IO.Directory]::Delete((Get-StateDir), $true)
    Write-Good 'Mod uninstalled. The game is back to how it was before the install.'
}

# --- changelog (CHANGELOG.md next to mod_pack: "## <version>" headings, "- " bullets, newest first)

function Get-ChangelogPath { Join-Path (Split-Path -Parent $RepoRoot) 'CHANGELOG.md' }
function Get-VersionFile   { Join-Path (Get-StateDir) 'version.txt' }

function Read-Changelog {
    $path = Get-ChangelogPath
    $out = New-Object System.Collections.Generic.List[object]
    if (-not [IO.File]::Exists($path)) { return $out }
    $cur = $null
    foreach ($line in [IO.File]::ReadAllLines($path, $Utf8NoBom)) {
        if ($line -match '^##\s+v?(\d+(\.\d+){1,3})\s*$') {
            $cur = [pscustomobject]@{ Version = $Matches[1]; Lines = New-Object System.Collections.Generic.List[string] }
            $out.Add($cur)
        } elseif ($cur -and $line.Trim()) {
            $cur.Lines.Add($line.TrimEnd())
        }
    }
    return $out
}

function Read-InstalledVersion {
    $f = Get-VersionFile
    if ([IO.File]::Exists($f)) { return [IO.File]::ReadAllText($f).Trim() }
    return ''
}

# After an install: show every version of the current big release (same major number, e.g. all
# 5.x.x), plus anything newer than the previously installed version if that was an older release.
# Versions newer than the previous install are marked "(new)". Then remember the new version.
function Show-Changelog([string]$previous) {
    $log = @(Read-Changelog)
    if ($log.Count -eq 0) { return }
    $newest = $log[0].Version
    $major = ([version]$newest).Major
    $prev = $null
    if ($previous) { try { $prev = [version]$previous } catch { $prev = $null } }

    $show = @($log | Where-Object {
        $v = [version]$_.Version
        $v.Major -eq $major -or ($prev -and $v -gt $prev)
    })
    Write-Info ''
    if ($prev -and $previous -ne $newest) { Write-Good "Changes in version $major (you had $previous, now $newest):" }
    else { Write-Good "Changes in version $major (now $newest):" }
    foreach ($entry in $show) {
        $isNew = $prev -and ([version]$entry.Version -gt $prev)
        Write-Host ("  v" + $entry.Version + $(if ($isNew) { '  (new)' } else { '' })) -ForegroundColor Yellow
        foreach ($l in $entry.Lines) { Write-Info ("    " + $l) }
    }
    [IO.File]::WriteAllText((Get-VersionFile), $newest)
}

function Test-GameStartedOnce {
    # The game writes czero\config.cfg the first time it runs.
    return [IO.File]::Exists((Join-Path $GameDir 'czero\config.cfg'))
}

function Invoke-Install {
    if (-not $Force -and -not (Test-GameStartedOnce)) {
        Write-Bad 'Condition Zero has never been started on this PC (czero\config.cfg is missing).'
        Write-Bad 'On the first start Steam can still finish setting the game up and put its original'
        Write-Bad 'files back over the mod''s (for example the radio texts and the menu background).'
        Write-Info ''
        Write-Info 'Please: start Condition Zero once, wait for the main menu, quit, then run install.bat (or update.bat) again.'
        Write-Info '(To install anyway: install.bat -Force)'
        $script:exitCode = 2
        return
    }
    $previousVersion = Read-InstalledVersion     # read before the uninstall below removes it
    if ([IO.Directory]::Exists((Get-StateDir))) {
        Write-Info 'The mod is already installed - removing the installed version first...'
        Invoke-Uninstall
        if ([IO.Directory]::Exists((Get-StateDir)) -and -not $DryRun) {
            Write-Bad 'Uninstall did not finish cleanly, so the install was stopped.'
            return
        }
        Write-Info ''
    }

    $plan = Get-Plan
    # Files the currently installed mod added will be gone after the uninstall above, so they
    # count as new (this matters for -DryRun, where the uninstall did not really happen).
    $modAdded = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($e in @(Read-ManifestEntries)) { if ($e.Kind -eq 'A') { [void]$modAdded.Add($e.Rel) } }
    $existing = @($plan | Where-Object {
        -not $modAdded.Contains($_.Dest) -and [IO.File]::Exists((Join-Path $GameDir $_.Dest))
    })
    Write-Info ("Installing {0} files: {1} new, {2} replace game files (originals are backed up)." -f `
        $plan.Count, ($plan.Count - $existing.Count), $existing.Count)

    if ($DryRun) {
        Write-Info ''
        Write-Info 'Game files that would be replaced:'
        $existing | ForEach-Object { Write-Info "  $($_.Dest)" }
        Write-Info ''
        Write-Info 'Never touched:'
        $ProtectedDest | ForEach-Object { Write-Info "  $_" }
        Write-Info '(dry run - nothing changed)'
        return
    }

    [void][IO.Directory]::CreateDirectory((Get-BackupRoot))
    $writer = New-Object IO.StreamWriter((Get-Manifest), $false, $Utf8NoBom)
    $writer.AutoFlush = $true   # so an interrupted install can still be uninstalled
    try {
        $writer.WriteLine("# CS:CZ mod install $(Get-Date -Format s) from $RepoRoot")
        foreach ($item in $plan) {
            $dst = Join-Path $GameDir $item.Dest
            $dir = [IO.Path]::GetDirectoryName($dst)

            # Record the top-most folder that we are about to create.
            $top = $null
            $d = $dir
            while (-not [IO.Directory]::Exists($d)) { $top = $d; $d = [IO.Path]::GetDirectoryName($d) }
            if ($top) {
                $writer.WriteLine("D`t" + (Get-RelToGame $top))
                [void][IO.Directory]::CreateDirectory($dir)
            }

            if ([IO.File]::Exists($dst)) {
                Copy-FileForce $dst (Join-Path (Get-BackupRoot) $item.Dest)
                $writer.WriteLine("R`t" + $item.Dest)
            }
            else {
                $writer.WriteLine("A`t" + $item.Dest)
            }
            Copy-FileForce $item.Src $dst
            if ($ReadOnlyDest -contains $item.Dest) {
                [IO.File]::SetAttributes($dst, [IO.File]::GetAttributes($dst) -bor [IO.FileAttributes]::ReadOnly)
            }
        }
    }
    finally { $writer.Dispose() }

    Write-Good 'Mod installed.'
    Write-Info "Backup of the replaced game files: $(Get-StateDir)"
    Show-Changelog $previousVersion
}

function Show-Status {
    if (-not [IO.Directory]::Exists((Get-StateDir))) { Write-Info 'Mod is NOT installed.'; return }
    $entries = @(Read-ManifestEntries)
    $header = [IO.File]::ReadAllLines((Get-Manifest), $Utf8NoBom) | Select-Object -First 1
    Write-Info 'Mod is installed.'
    Write-Info "  $header"
    $ver = Read-InstalledVersion
    if ($ver) { Write-Info "  Version: $ver" }
    $commitFile = Join-Path (Get-StateDir) 'commit.txt'
    if ([IO.File]::Exists($commitFile)) { Write-Info ("  GitHub version: " + [IO.File]::ReadAllText($commitFile).Trim()) }
    Write-Info ("  {0} added files, {1} replaced game files backed up" -f `
        @($entries | Where-Object Kind -eq 'A').Count, @($entries | Where-Object Kind -eq 'R').Count)
}

# ---------------------------------------------------------------------------

$exitCode = 0
try {
    if (-not [IO.File]::Exists((Join-Path $GameDir 'hl.exe'))) {
        if ($NoPause) { throw "Half-Life folder not found: $GameDir (use -GameDir)" }
        Write-Bad "Half-Life not found at: $GameDir"
        $GameDir = (Read-Host 'Paste the path of your Half-Life folder (the one containing hl.exe)').Trim('" ')
        if (-not [IO.File]::Exists((Join-Path $GameDir 'hl.exe'))) { throw "hl.exe not found in: $GameDir" }
    }
    $GameDir = [IO.Path]::GetFullPath($GameDir).TrimEnd('\')
    Write-Info "Game folder: $GameDir"
    Write-Info ''

    if ($Action -eq 'Status') { Show-Status }
    elseif (-not $DryRun -and (Test-GameRunning)) { $exitCode = 1 }
    elseif (-not $DryRun -and -not (Test-CanWrite)) {
        Write-Info 'Administrator rights are needed to write to the game folder. Asking Windows...'
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"",
                     '-Action', $Action, '-GameDir', "`"$GameDir`"")
        Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
        $NoPause = $true
    }
    elseif ($Action -eq 'Install') { Invoke-Install }
    else { Invoke-Uninstall }
}
catch {
    Write-Bad "ERROR: $($_.Exception.Message)"
    $exitCode = 1
}

if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
exit $exitCode
