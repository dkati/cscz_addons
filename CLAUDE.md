# CS:CZ Greek Mod

A mod pack for Counter-Strike: Condition Zero (GoldSrc) played with friends and bots on a listen
server. Greek text, sounds and taunts, custom maps, AMX Mod X plugins. The repo is the source of
truth; the game is changed only through the installer.

- Game folder: `C:\Program Files (x86)\Steam\steamapps\common\Half-Life`
- Modding tools: `C:\Users\Administrator\Desktop\cs modding` (map decompiler, Crowbar, texture tools;
  the `compile` folder is empty, so there are no map compile tools)

## Layout

```
mod_pack/                 everything that goes into the game
  czero_addon/          -> czero/            maps, models, sounds, sprites, resource, titles.txt
  cstrike_addon/        -> cstrike/
  czero_downloads/      -> czero_downloads/
  amx/addons/           -> czero/addons/     Metamod + AMX Mod X
  amx/liblist.gam       -> czero/liblist.gam (loads Metamod)
  COPY TO ROOT/         -> Half-Life/
  COPY TO ROOT VALVE/   -> valve/
  COPY TO ROOT CZERO/   -> czero/            applied last, wins over czero_addon duplicates
install.bat / uninstall.bat
scripts/cscz-mod.ps1      the installer (mapping table $Mappings at the top)
```

## Installer (scripts/cscz-mod.ps1)

- Install backs up every game file it replaces to `Half-Life\_cscz_mod_backup\` and records added
  files/folders in a manifest; uninstall deletes what was added and restores the originals.
- Re-running install uninstalls first, so mod edits (including newly overridden stock files) are
  always applied against the original game files. Never hardcode file lists.
- `config.cfg` (player keys, sensitivity, name) is never copied or touched. Mod settings belong in
  `mod_pack/czero_addon/userconfig.cfg`.
- Skipped repo junk: `*.ztmp`, `custom_DELETE*`, `tempdecal_moveToCzeroRoot.wad`.
- Check changes with `install.bat -DryRun` (changes nothing). Test installer changes on a fake game
  folder (copies of only the affected files + `hl.exe`) and compare hashes after uninstall,
  never on the real game first.
- After any mod change the user runs `install.bat` themself.

## How we work

- The user changes maps only through the in-game menu (Create Server), never via console or AMX.
  Do not add AMX plugins or commands to guard map changes.
- Do not touch AMX plugins unless asked.
- Commit only when the user asks.
- The old C# installer was deleted on purpose; do not recreate it.
- Things that can only be checked in-game (HUD layout, sounds, map behaviour) are not verified until
  the user tries them; say so.

## AMX Mod X plugins

- Sources: `mod_pack/amx/addons/amxmodx/scripting/*.sma` (UTF-8, CRLF, Greek strings).
- Compile from that folder: `./amxxpc.exe name.sma -ocompiled/name.amxx`, then copy the `.amxx` to
  `../plugins/`. Keep `plugins/` and `scripting/compiled/` identical. Enable in `configs/plugins.ini`.
- Custom plugins:
  - `kill_puns` – random Greek taunt to a human killer (center text)
  - `headshot_pun` – CT headshots/kills with % and HE kills; kills come from `get_user_frags()` so
    they match the scoreboard; team kills don't count as headshot/HE
  - `showenemies` – own team's round wins + enemies alive
  - `wallhack` – distance/direction to the last <5 enemies (center)
  - `last_breath` – CT at <=5 HP for >3 s can't die this round; big DHUD message
    "Α Λ Ι Μ Ο Ν Ο...εκδικηση στην αδικια" + sound `misc/alimono.wav` (cvars `amx_lastbreath_hp`,
    `amx_lastbreath_time`)
  - `sequentialkills` – disabled; its `misc/*kill.wav` sounds don't exist
- HUD channels (only 4 exist): 1–2 headshot_pun, 3 showenemies, 4 wallhack. DHUD (big text) is separate.
- Left HUD column, top to bottom: showenemies, headshots box, HE box (HE box moves down as the
  headshots box grows). Cvars `amx_hudcol_y` (top), `amx_hudcol_lineh` (line height).
- Always print prepared text with a format: `show_hudmessage(id, "%s", buf)`. Passing the buffer as
  the format eats `%` signs and breaks on names containing `%`.

## Sounds

- WAV, PCM 16-bit, mono, 22050 Hz, short; lowercase ASCII file names.
- A plugin must `precache_sound()` it in `plugin_precache` and play it with `client_cmd(0, "spk ...")`.
- Hostage voices: `czero/sound/hostage/<situation>/`. The mod replaces all of them with `nenene.wav`
  except `hpain`, `hgrenade`, `hflash`, `hsmoke` (those stay original).
- "Fire in the hole" = `sound/radio/ct_fireinhole.wav` (used by both teams).

## Text

- Radio menus and radio chat lines: `mod_pack/czero_addon/titles.txt` (UTF-8). A radio phrase appears
  twice: in the menu block (e.g. `RadioC`) and in its message block (e.g. `Enemy_spotted`); edit both.

## Maps

- Favourites are renamed with a `0_` prefix so they sort to the top of the Create Server list:
  `0_$2000$`, `0_apartments`, `0_iceworld`, `0_minitaly_fixed`, `0_truth`. When renaming a map,
  rename all its files (`.bsp .nav .res .txt _detail.txt overviews/*`) and fix names inside `.res`
  and overview `.txt` files. Game mode comes from map entities, not the name prefix.
- `a______________.bsp` is a fake divider map (deliberately invalid data, the engine refuses it).
- Every map needs a `.nav` for CZ bots, otherwise bots "learn" the map during play and it lags.
  Generate: load the map without bots and run `bot_add` (not `bot_nav_analyze`, which only works on
  an existing nav), wait until it saves `czero/maps/<map>.nav`, then copy it into the repo.
- A `.nav` is tied to the exact `.bsp` file size. Edit a `.bsp` only in place with the same size
  (e.g. entity text padded with spaces outside quotes), or regenerate the nav afterwards.
- `0_$2000$` sky was changed from the missing `catalane` to `dust`.

## Images

- Menu background: `czero_addon/resource/background/800_<row>_<col>_loading.tga`, a 4×3 grid of
  256×256 tiles drawn at 1024×768 (`czero/resource/BackgroundLayout.txt`). Tiles the mod doesn't
  ship come from the game. The version text ("Version: 5.0.0") is in `800_1_d`.
- TGAs are RLE (type 10), 24/32-bit. No Pillow installed; use a small pure-Python TGA reader/writer
  and keep the original type, bit depth and trailer when writing back.
