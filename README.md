from ingame UI: Only 'addons' enabled

## Update from GitHub (OTA)

`update.bat` is all a player needs: download it once from this repo and double-click it. It checks
the newest commit on `main`, and if the game doesn't have it yet, downloads that version (~100 MB),
installs it with its own installer and remembers the installed commit. Already up to date =
nothing is downloaded. It also does the very first install on a PC without the mod.
(`update.bat -Force` reinstalls anyway. To see the installed version, run
`powershell -ExecutionPolicy Bypass -File scripts\cscz-mod.ps1 -Action Status`.)

Every install shows what's new since the version you had, from `CHANGELOG.md`. When releasing a
version, add a `## <version>` section at the top of `CHANGELOG.md` with one `- ` bullet per change.
Players get a change only after it is committed and pushed to `main`.

## Install / uninstall

On a new PC: start Condition Zero once (wait for the main menu, then quit) before installing.
On its first start Steam may still put its own files back over the mod's. The installer refuses
to run on a game that was never started (`install.bat -Force` installs anyway). If after a Steam
update the radio texts or the menu background look original again, run `install.bat` again.

Close the game, then double-click:

- `install.bat` copies the mod into `C:\Program Files (x86)\Steam\steamapps\common\Half-Life`.
  Every game file it replaces is backed up first to `Half-Life\_cscz_mod_backup`.
- `uninstall.bat` removes everything the mod added and restores the original game files.

Your own settings (`config.cfg`: keys, sensitivity, name) are never touched.
Put settings the mod needs in `mod_pack/czero_addon/userconfig.cfg` instead.

After editing the mod, just run `install.bat` again. It uninstalls the old version and then
installs the current one, so new overrides of stock files get backed up automatically.

Other game folder: `install.bat -GameDir "D:\Games\Half-Life"`. Preview only: `install.bat -DryRun`.
Which `mod_pack` folder goes where is set in the `$Mappings` table at the top of `scripts/cscz-mod.ps1`.
