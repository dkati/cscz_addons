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
  - `stats` – one green box top-left (channel 1), sent per human player: own team's round wins +
    enemies alive, then CT headshots/kills with %, then CT HE kills. Kills come from
    `get_user_frags()` so they match the scoreboard; team kills don't count as headshot/HE. Cvar
    `amx_hudcol_y` = top of the box (the key list follows below it). (Replaces the old
    `showenemies` + `headshot_pun`.)
  - `wallhack` – distance/direction to the last <5 enemies (center, channel 3, updated every 0.1 s)
  - `last_breath` – CT at <=10 HP (`amx_lastbreath_hp`, default 10) for >3 s can't die this round; big DHUD message
    "Α Λ Ι Μ Ο Ν Ο...εκδικηση στην αδικια" + sound `misc/alimono.wav` (cvars `amx_lastbreath_hp`,
    `amx_lastbreath_time`). On/off: cvar `amx_undead_on` (default 1).
  - `security_cams` – dead human players watch the map's fixed cameras (left/right click = next/prev
    camera; big DHUD title "1/6 Place" top center, re-sent every 0.1 s with a short hold),
    until respawn. On/off: cvar `amx_cams_on` (default 1); off = the game's normal spectator view.
    Cameras are made in-game with `amx_cam_add <place>`
    (also `amx_cam_list`, `amx_cam_del <n>`, `amx_cam_view <n>`), saved to
    `czero/security_cams/<map>.ini` (outside mod folders so reinstall never deletes them); copy that
    file into `mod_pack/czero_addon/security_cams/` to keep it. Overrides CZ's spectator mode by
    resetting `pev_iuser1` and hiding the dead player's buttons from the game. Whenever the cameras
    take the view, it sends an empty `StatusText` so the followed player's name from chase cam
    doesn't stay stuck in the middle of the screen. L (`cam_chase`)
    switches a dead player between the cameras and the game's free chase cam (OBS_CHASE_FREE) and
    back; the choice is remembered per player until reconnect. Yellow DHUD hint on the right:
    "Click: Change camera / L: Free chase camera" (cameras) or "L: Security cameras" (chase cam).
    Nothing on maps without cameras.
  - `hotkeys_hud` – sticky key list on the left, right below the stats box, for alive humans, small
    normal HUD text. It uses the stats box's position (`amx_hudcol_y`) and starts with as many empty
    lines as that player's stats box has (+1 gap), read from stats' public `stats_lines(id)` via
    `callfunc`; refreshed every 0.25 s so it follows the box. Each line is green when
    its script is on, red when off (no On/Off words): green lines in channel 2, red lines in channel 4,
    same position, empty lines as placeholders:
    "Pause Script (P)", "Camera Script (I) (click change camera)", "Undead Script (K)",
    "Lifesteal Script (amx_lifesteal_pct 3)" (shows the current value; green while > 0). A `%d` in
    `g_Keys` is replaced by that line's cvar value.
    It only reads the other scripts' on/off cvars; a new script gets a line in its `g_Label/g_Cvar/
    g_Keys` tables.
  - `lifesteal` – every player (bots too) heals `amx_lifesteal_pct` % (default 3; 0 = off, set it in the console) of the
    damage they really deal to enemies (victim's actual health loss, so no overkill), capped at max
    health, fractions carried over. No team/self damage. Humans see a green DHUD "+N" next to the (cvars `amx_lifesteal_x/y`, default 0.51)
    crosshair (0.5 s, then 0.5 s fade; hits within 0.15 s summed). No hotkey (J was
    dropped: setting the cvar to 0 already turns it off). Leaves last_breath alone: healing above 10 HP just ends
    its countdown. Nothing happens at full health. `amx_lifesteal_debug 1` explains every hit in the bottom-left text area and the console
    (damage, heal, or why there was no heal).
  - `sequentialkills` – disabled; its `misc/*kill.wav` sounds don't exist
- Extra keys are bound in `mod_pack/czero_addon/userconfig.cfg`: P = `pause_toggle`, I = `cams_toggle`,
  K = `undead_toggle`, J is unbound (was lifesteal_toggle; CZ's "cheer" before that), L = `cam_chase`; O is unused (`unbind "o"`, it used to be a "next camera" key,
  but clicks already do that). Every player can use all of them (no host/admin check). I and K turn
  a script on/off for everyone and show a big DHUD "Camera Script: On/Off (name)" / "Undead Script:
  On/Off (name)" to all. Turning undead off removes active protection. The on/off cvars keep their
  value across map changes. P (`pause_toggle`, in hotkeys_hud) announces "* name pressed Pause" and
  makes the host (player 1, the listen-server admin) run `amx_pause`, which needs admin rights.
  Plugins can't see keys that aren't game actions; bind them to a plugin command instead.
- HUD channels (only 4 exist, one color per message): 1 stats, 2 hotkeys_hud green lines,
  3 wallhack, 4 hotkeys_hud red lines. A message can't mix colors, so lines of two colors need two
  channels. Other text (last_breath, security_cams title and key hint, lifesteal "+N", on/off messages) uses DHUD
  (big text, fixed size, separate 8 slots, re-sent periodically because it can't be updated in place).
- CZ bots are a separate player class (CCSBot) with their own virtual functions: `RegisterHam(..., "player")`
  only hooks humans. To catch events on bots too (e.g. damage TO a bot), also call
  `RegisterHamFromEntity` on the first bot that joins (see lifesteal `hook_bots`).
- Always print prepared text with a format: `show_hudmessage(id, "%s", buf)`. Passing the buffer as
  the format eats `%` signs and breaks on names containing `%`.

## Sounds

- WAV, PCM 16-bit, mono, 22050 Hz, short; lowercase ASCII file names.
- A plugin must `precache_sound()` it in `plugin_precache` and play it with `client_cmd(0, "spk ...")`.
- Hostage voices: `czero/sound/hostage/<situation>/`. The mod replaces all of them with `nenene.wav`
  (made +6 dB louder with a soft limiter: average -13 -> -7.6 dBFS, peaks just under full scale)
  except `hpain`, `hgrenade`, `hflash`, `hsmoke` (those stay original).
- "Fire in the hole" = `sound/radio/ct_fireinhole.wav` (used by both teams).

## Text

- Radio menus and radio chat lines: `mod_pack/czero_addon/titles.txt` (UTF-8). A radio phrase appears
  twice: in the menu block (e.g. `RadioC`) and in its message block (e.g. `Enemy_spotted`); edit both.

## Maps

- Map names must keep their game-mode prefix (`de_`, `cs_`, `fy_`, ...): the client buy menu shows
  the defuse kit only on `de_` maps (`de_useonly` in `resource/UI/BuyEquipment_CT.res`). A `0_`
  prefix for sorting was tried and dropped for this reason. Favourites: `fy_$2000$`,
  `cs_apartments`, `fy_iceworld`, `cs_minitaly_fixed`, `cs_minitaly_dafto`, `de_truth`.
  When renaming a map, rename all its files (`.bsp .nav .res .txt _detail.txt overviews/*`,
  `security_cams/*.ini`) and fix names inside `.res` and overview `.txt` files.
- Every map needs a `.nav` for CZ bots, otherwise bots "learn" the map during play and it lags.
  Generate: load the map without bots and run `bot_add` (not `bot_nav_analyze`, which only works on
  an existing nav), wait until it saves `czero/maps/<map>.nav`, then copy it into the repo.
- A `.nav` is tied to the exact `.bsp` file size. Edit a `.bsp` only in place with the same size
  (e.g. entity text padded with spaces outside quotes), or regenerate the nav afterwards.
- `fy_$2000$` sky was changed from the missing `catalane` to `dust`.
- `cs_minitaly_dafto` is a remix of minitaly (the user preferred this over a generated map: it keeps
  minitaly's look). `scripts/mapgen/minitaly_remix.py` decompiles `cs_minitaly_fixed.bsp` (Unified
  SDK MapDecompiler in the `cs modding` folder) into `scripts/mapgen/build/remix/base.map`, applies
  the changes in `apply_changes()`, compiles with VHLT (`C:\Program Files\J.A.C.K\halflife`) and
  copies the `.bsp` into `mod_pack`. Run: `python -I scripts/mapgen/minitaly_remix.py`.
  - Changes so far: two-floor middle house carved out of the solid block between the west street
    and the T square (4 hostages, ground floor -4, upper floor 96), wooden bridge from its upper
    door across the T square to the east walkway (z 96), and a closed house front across the west
    street at y ≈ -1216. The original single hostage is removed.
  - Tools in the script: `carve_world(box, wall, floor, ceil)` cuts empty space out of any brushes
    (convex CSG subtraction), `add(box(...))` adds Valve-220 brushes, `stairs(...)`, `light(...)`.
  - Decompiler quirks handled in the script: the welcome `game_text` (`http://` read as a comment)
    and duplicate door origins. Decompiled brush points are ~1e6 away; use `brush_bounds()`.
  - Every rebuild changes the `.bsp` size, so its `.nav` must be regenerated in-game afterwards.
- Checking maps without the game: `scripts/mapgen/bsp_probe.py` (floor heights at points / as a
  grid) and `scripts/mapgen/bsp_topdown.py` (top-down floor image, `ZLO`/`ZCUT` height band).

## Spray logo

- The mod's spray ("Defend JulMaYa") is `mod_pack/COPY TO ROOT CZERO/tempdecal.wad` (64×64). The game
  only accepts it like the files it makes itself: one lump named `LOGO` with type `0x40` (decal). A
  `{NEW` / `0x43` (texture) lump looks right in texture tools but the game ignores it and sprays the
  default logo. (`czero_addon/tempdecal.wad` is the same file, overridden by the root copy.)
- `tempdecal.wad` is read-only on purpose so Options → Multiplayer → OK (which rebuilds the spray from
  `cl_logofile`, "lambda" by default) can't overwrite it. The installer keeps the read-only flag;
  git does not store it, so set it again (`attrib +R`) after a fresh clone.
- `custom.hpk` is the game's spray cache; keep it writable so the game can add the logo's entry.
- `logos/remapped.bmp` holds the same picture as a normal logo file.

## Images

- Menu background: `czero_addon/resource/background/800_<row>_<col>_loading.tga`, a 4×3 grid of
  256×256 tiles drawn at 1024×768 (`czero/resource/BackgroundLayout.txt`). Tiles the mod doesn't
  ship come from the game. The version text ("Version: 5.0.0") is in `800_1_d`.
- TGAs are RLE (type 10), 24/32-bit. No Pillow installed; use a small pure-Python TGA reader/writer
  and keep the original type, bit depth and trailer when writing back.
