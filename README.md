from ingame UI: Only 'addons' enabled

## Install / uninstall

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
