#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <hamsandwich>

// Security cameras for dead players.
// When a human player dies, their view switches to the map's fixed cameras:
//   left click    = next camera, right click = previous camera
//   L (cam_chase) = switch between the cameras and the game's normal free chase camera, and back
//                   (each player's choice is remembered for their next death, until they reconnect)
// The screen shows "1/6 Place" in big text and a key hint on the right side:
//   cameras: "Click: Change camera / L: Free chase camera"    chase cam: "L: Security cameras"
// It ends when the player respawns.
//
// I (cams_toggle) turns the whole script on/off for everyone; any player can do it (the message
// says who). Off = dead players get the game's normal spectator view.
// State: cvar amx_cams_on (1 = on, the default; kept across map changes).
// Keys are bound in czero_addon/userconfig.cfg.
//
// Cameras are saved per map in  czero/security_cams/<map>.ini  (outside the mod's folders,
// so reinstalling the mod never deletes them). Copy that file into the repo to keep it:
//   mod_pack/czero_addon/security_cams/<map>.ini
//
// Admin commands (stand where the camera should be and look where it should look):
//   amx_cam_add <place name>   save a camera at your eye position and view direction
//   amx_cam_list               list this map's cameras
//   amx_cam_del <number>       delete a camera
//   amx_cam_view <number>      look through a camera while alive (0 = back to normal)

#define MAX_CAMS     16
#define CAM_MODEL    "models/rpgrocket.mdl"   // only needed so the view entity is sent to clients; invisible
#define CAM_DIR      "security_cams"
#define START_DELAY  1.0                      // seconds after death before the cameras start
#define TITLE_REFRESH 0.1                     // big camera title is re-sent this often...
#define TITLE_HOLD   0.15                     // ...and shown this long each time
#define HINT_X       0.88                     // key hint on the right side (left edge of the text)
#define HINT_Y       0.45
#define TASK_START   5100

new g_CamCount
new Float:g_CamOrigin[MAX_CAMS][3]
new Float:g_CamAngles[MAX_CAMS][3]
new g_CamName[MAX_CAMS][64]   // bytes; Greek letters take 2 each
new g_CamEnt[MAX_CAMS]

new g_Watching[33]      // 1-based camera index the player is watching, 0 = not watching
new g_LastButtons[33]
new bool:g_SawObserver[33] // the game's spectator mode has started this life
new bool:g_Chase[33]       // in the game's free chase cam instead of the cameras (L)
new bool:g_PrefChase[33]   // remembered L choice for the next death
new Float:g_LastSwitch[33] // time of the last camera switch (one click must not switch twice)
new g_File[128]
new g_pOn

public plugin_precache() {
    precache_model(CAM_MODEL)
}

public plugin_init() {
    register_plugin("Security Cameras", "1.9", "Author")

    g_pOn = register_cvar("amx_cams_on", "1")

    register_concmd("amx_cam_add", "cmd_add", ADMIN_CFG, "<place name> - save a camera here")
    register_concmd("amx_cam_list", "cmd_list", ADMIN_CFG, "- list this map's cameras")
    register_concmd("amx_cam_del", "cmd_del", ADMIN_CFG, "<number> - delete a camera")
    register_concmd("amx_cam_view", "cmd_view", ADMIN_CFG, "<number> - look through a camera (0 = off)")

    RegisterHam(Ham_Killed, "player", "fw_killed_post", 1)
    RegisterHam(Ham_Spawn, "player", "fw_spawn_post", 1)
    register_forward(FM_PlayerPreThink, "fw_prethink")
    register_clcmd("cams_toggle", "cmd_toggle")
    register_clcmd("cam_chase", "cmd_chase")
    // When the client thinks it is spectating, it sends clicks as commands instead of buttons:
    // "follownext 0" (left click) / "follownext 1" (right click), and "specmode" (jump).
    register_clcmd("follownext", "cmd_follownext")
    register_clcmd("specmode", "cmd_specmode")

    new map[64]
    get_mapname(map, charsmax(map))
    formatex(g_File, charsmax(g_File), "%s/%s.ini", CAM_DIR, map)
    load_cams()

    set_task(TITLE_REFRESH, "refresh_hud", _, _, _, "b")
}

// ---------------------------------------------------------------- cameras

create_cam_entity(i) {
    new ent = create_entity("info_target")
    if (!ent) return 0
    entity_set_string(ent, EV_SZ_classname, "security_cam")
    entity_set_model(ent, CAM_MODEL)
    entity_set_origin(ent, g_CamOrigin[i])
    entity_set_vector(ent, EV_VEC_angles, g_CamAngles[i])
    entity_set_int(ent, EV_INT_movetype, MOVETYPE_NONE)
    entity_set_int(ent, EV_INT_solid, SOLID_NOT)
    entity_set_int(ent, EV_INT_rendermode, kRenderTransTexture)
    entity_set_float(ent, EV_FL_renderamt, 0.0)
    return ent
}

load_cams() {
    new f = fopen(g_File, "rt")
    if (!f) return

    new line[160], sx[16], sy[16], sz[16], sp[16], syaw[16], name[64]
    while (!feof(f) && g_CamCount < MAX_CAMS) {
        fgets(f, line, charsmax(line))
        trim(line)
        if (!line[0] || line[0] == ';' || line[0] == '/') continue

        name[0] = 0
        parse(line, sx, charsmax(sx), sy, charsmax(sy), sz, charsmax(sz),
              sp, charsmax(sp), syaw, charsmax(syaw), name, charsmax(name))

        new i = g_CamCount
        g_CamOrigin[i][0] = str_to_float(sx)
        g_CamOrigin[i][1] = str_to_float(sy)
        g_CamOrigin[i][2] = str_to_float(sz)
        g_CamAngles[i][0] = str_to_float(sp)
        g_CamAngles[i][1] = str_to_float(syaw)
        g_CamAngles[i][2] = 0.0
        copy(g_CamName[i], charsmax(g_CamName[]), name)
        g_CamEnt[i] = create_cam_entity(i)
        g_CamCount++
    }
    fclose(f)
}

save_cams() {
    if (!dir_exists(CAM_DIR)) mkdir(CAM_DIR)

    new f = fopen(g_File, "wt")
    if (!f) return 0
    fputs(f, "; Security cameras: x y z pitch yaw ^"place name^" (made with amx_cam_add)^n")
    for (new i = 0; i < g_CamCount; i++) {
        fprintf(f, "%.1f %.1f %.1f %.1f %.1f ^"%s^"^n",
            g_CamOrigin[i][0], g_CamOrigin[i][1], g_CamOrigin[i][2],
            g_CamAngles[i][0], g_CamAngles[i][1], g_CamName[i])
    }
    fclose(f)
    return 1
}

// ---------------------------------------------------------------- admin commands

public cmd_add(id, level, cid) {
    if (!cmd_access(id, level, cid, 2)) return PLUGIN_HANDLED
    if (!id || !is_user_connected(id)) {
        console_print(id, "[CAM] Use this in game, standing where the camera should be.")
        return PLUGIN_HANDLED
    }
    if (g_CamCount >= MAX_CAMS) {
        console_print(id, "[CAM] This map already has %d cameras (maximum).", MAX_CAMS)
        return PLUGIN_HANDLED
    }

    new name[64]
    read_args(name, charsmax(name))
    remove_quotes(name)
    trim(name)
    replace_all(name, charsmax(name), "^"", "")
    replace_all(name, charsmax(name), "'", "")   // the console keeps single quotes literally
    trim(name)

    new Float:origin[3], Float:ofs[3], Float:angles[3]
    pev(id, pev_origin, origin)
    pev(id, pev_view_ofs, ofs)
    pev(id, pev_v_angle, angles)

    new i = g_CamCount
    for (new k = 0; k < 3; k++) g_CamOrigin[i][k] = origin[k] + ofs[k]
    g_CamAngles[i][0] = angles[0]
    g_CamAngles[i][1] = angles[1]
    g_CamAngles[i][2] = 0.0
    copy(g_CamName[i], charsmax(g_CamName[]), name)
    g_CamEnt[i] = create_cam_entity(i)
    g_CamCount++

    if (save_cams()) console_print(id, "[CAM] Saved camera %d/%d: %s  (%s)", g_CamCount, g_CamCount, name, g_File)
    else console_print(id, "[CAM] Camera added, but could not write %s", g_File)
    return PLUGIN_HANDLED
}

public cmd_list(id, level, cid) {
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
    console_print(id, "[CAM] %d camera(s) in %s", g_CamCount, g_File)
    for (new i = 0; i < g_CamCount; i++) {
        console_print(id, "  %d. %s  (%.0f %.0f %.0f)", i + 1, g_CamName[i],
            g_CamOrigin[i][0], g_CamOrigin[i][1], g_CamOrigin[i][2])
    }
    return PLUGIN_HANDLED
}

public cmd_del(id, level, cid) {
    if (!cmd_access(id, level, cid, 2)) return PLUGIN_HANDLED
    new arg[8]
    read_argv(1, arg, charsmax(arg))
    new n = str_to_num(arg)
    if (n < 1 || n > g_CamCount) {
        console_print(id, "[CAM] No camera %d. Use amx_cam_list.", n)
        return PLUGIN_HANDLED
    }

    new i = n - 1
    console_print(id, "[CAM] Deleted camera %d: %s", n, g_CamName[i])
    if (g_CamEnt[i]) remove_entity(g_CamEnt[i])
    for (new j = i; j < g_CamCount - 1; j++) {
        g_CamOrigin[j] = g_CamOrigin[j + 1]
        g_CamAngles[j] = g_CamAngles[j + 1]
        copy(g_CamName[j], charsmax(g_CamName[]), g_CamName[j + 1])
        g_CamEnt[j] = g_CamEnt[j + 1]
    }
    g_CamCount--
    save_cams()

    // Anyone watching a camera that no longer exists goes back to the first one (or stops).
    for (new p = 1; p <= 32; p++) {
        if (!g_Watching[p]) continue
        if (g_CamCount == 0) stop_watch(p)
        else { g_Watching[p] = 1; show_cam(p); }
    }
    return PLUGIN_HANDLED
}

public cmd_view(id, level, cid) {
    if (!cmd_access(id, level, cid, 2) || !id) return PLUGIN_HANDLED
    new arg[8]
    read_argv(1, arg, charsmax(arg))
    new n = str_to_num(arg)
    if (n < 1 || n > g_CamCount) {
        attach_view(id, id)
        console_print(id, "[CAM] Back to your own view.")
        return PLUGIN_HANDLED
    }
    attach_view(id, g_CamEnt[n - 1])
    console_print(id, "[CAM] Viewing camera %d: %s  (amx_cam_view 0 to return)", n, g_CamName[n - 1])
    return PLUGIN_HANDLED
}

// ---------------------------------------------------------------- watching

bool:cams_on() {
    return get_pcvar_num(g_pOn) != 0
}

public fw_killed_post(victim, attacker, shouldgib) {
    if (g_CamCount == 0 || !cams_on() || is_user_bot(victim) || !is_user_connected(victim)) return HAM_IGNORED
    remove_task(victim + TASK_START)
    set_task(START_DELAY, "start_watch", victim + TASK_START)
    return HAM_IGNORED
}

public start_watch(taskid) {
    new id = taskid - TASK_START
    if (!is_user_connected(id) || is_user_alive(id) || g_CamCount == 0 || !cams_on()) return
    g_Watching[id] = 1
    g_SawObserver[id] = pev(id, pev_iuser1) != 0
    g_LastButtons[id] = pev(id, pev_button)   // a click held from dying doesn't count
    g_Chase[id] = g_PrefChase[id]
    if (g_Chase[id]) {                        // last time this player chose the chase cam
        show_texts(id)
        return
    }
    // Turned on while the game's spectator mode was already running: switch it off.
    if (g_SawObserver[id]) {
        set_pev(id, pev_iuser1, 0)
        set_pev(id, pev_iuser2, 0)
    }
    show_cam(id)
}

public fw_spawn_post(id) {
    if (is_user_alive(id)) stop_watch(id)
    return HAM_IGNORED
}

public client_disconnected(id) {
    remove_task(id + TASK_START)
    g_Watching[id] = 0
    g_Chase[id] = false
    g_PrefChase[id] = false
}

stop_watch(id) {
    remove_task(id + TASK_START)
    if (g_Watching[id]) {
        g_Watching[id] = 0
        if (is_user_connected(id) && !g_Chase[id]) attach_view(id, id)
    }
    g_Chase[id] = false
}

show_cam(id) {
    attach_view(id, g_CamEnt[g_Watching[id] - 1])
    clear_status(id)
    show_texts(id)
}

// The game's status text (the name shown in the middle when you aim at someone, or of the player
// you follow in chase cam) stays on screen when the cameras take over. Send an empty one.
// The game only re-sends it when the name changes, so it stays cleared.
clear_status(id) {
    static msg
    if (!msg) msg = get_user_msgid("StatusText")
    if (!msg || !is_user_connected(id)) return
    message_begin(MSG_ONE, msg, _, id)
    write_byte(0)
    write_string("")
    message_end()
}

// Camera name in big "director" text at the top (cameras only), and a yellow key hint on the
// right side (cameras and chase cam).
show_texts(id) {
    if (!g_Chase[id]) {
        new i = g_Watching[id] - 1
        set_dhudmessage(255, 255, 255, -1.0, 0.10, 0, 0.0, TITLE_HOLD, 0.0, 0.0)
        show_dhudmessage(id, "%d/%d %s", i + 1, g_CamCount, g_CamName[i])
    }
    set_dhudmessage(255, 220, 80, HINT_X, HINT_Y, 0, 0.0, TITLE_HOLD, 0.0, 0.0)
    show_dhudmessage(id, "%s", g_Chase[id] ? "L: Security cameras" : "Click: Change camera^nL: Free chase camera")
}

// "cam_chase" (bound to L): switch between the cameras and the game's free chase cam.
public cmd_chase(id) {
    if (!g_Watching[id] || is_user_alive(id)) return PLUGIN_HANDLED
    if (g_Chase[id]) {
        // back to the cameras: switch the game's spectator mode off again
        g_Chase[id] = false
        if (pev(id, pev_iuser1) != 0) {
            g_SawObserver[id] = true
            set_pev(id, pev_iuser1, 0)
            set_pev(id, pev_iuser2, 0)
        }
        show_cam(id)
    } else {
        // to the chase cam: give the view back to the game; if its spectator mode had already
        // started, turn it back on in free chase mode (otherwise the game starts it by itself)
        g_Chase[id] = true
        attach_view(id, id)
        if (g_SawObserver[id]) {
            set_pev(id, pev_iuser1, OBS_CHASE_FREE)
            set_pev(id, pev_iuser2, find_chase_target(id))
        }
        show_texts(id)
    }
    g_PrefChase[id] = g_Chase[id]
    return PLUGIN_HANDLED
}

// "cams_toggle" (bound to I): any player turns the script on/off for everyone.
public cmd_toggle(id) {
    if (id && !is_user_connected(id)) return PLUGIN_HANDLED   // any player (or the server console)
    new bool:on = !cams_on()
    set_pcvar_num(g_pOn, on ? 1 : 0)

    for (new p = 1; p <= 32; p++) {
        if (!is_user_connected(p) || is_user_bot(p) || is_user_alive(p)) continue
        if (on) {
            if (g_CamCount > 0 && !g_Watching[p]) start_watch(p + TASK_START)
        } else if (g_Watching[p]) {
            to_spectator(p)
        }
    }

    if (on) set_dhudmessage(40, 255, 40, -1.0, 0.20, 0, 0.0, 3.0, 0.2, 0.5)
    else set_dhudmessage(255, 160, 0, -1.0, 0.20, 0, 0.0, 3.0, 0.2, 0.5)
    new who[32]
    if (id) get_user_name(id, who, charsmax(who)); else copy(who, charsmax(who), "server")
    show_dhudmessage(0, "Camera Script: %s (%s)", on ? "On" : "Off", who)
    return PLUGIN_HANDLED
}

// Stop the cameras and give the player back the game's spectator view (chase cam on a living
// player, teammates first), if the game had already started it.
to_spectator(id) {
    new bool:chasing = g_Chase[id]
    stop_watch(id)
    if (g_SawObserver[id] && !chasing) {
        set_pev(id, pev_iuser1, OBS_CHASE_FREE)
        set_pev(id, pev_iuser2, find_chase_target(id))
    }
}

// Big text cannot be replaced in place, only re-sent, so it is re-sent often with a short
// hold time: the text stays steady and an old camera name disappears quickly after a switch.
public refresh_hud() {
    for (new id = 1; id <= 32; id++) {
        if (g_Watching[id] && is_user_connected(id)) show_texts(id)
    }
}

find_chase_target(id) {
    new players[32], num, team = get_user_team(id)
    get_players(players, num, "a")
    for (new i = 0; i < num; i++) if (get_user_team(players[i]) == team) return players[i]
    return num > 0 ? players[0] : 0
}

// Next / previous camera. A click can arrive both as a button and as a spectator command, so a
// second switch within 0.15 s is ignored.
switch_cam(id, bool:previous) {
    new Float:now = get_gametime()
    if (now - g_LastSwitch[id] < 0.15) return
    g_LastSwitch[id] = now
    if (previous) g_Watching[id] = g_Watching[id] > 1 ? g_Watching[id] - 1 : g_CamCount
    else g_Watching[id] = (g_Watching[id] % g_CamCount) + 1
    show_cam(id)
}

bool:on_cameras(id) {
    return g_Watching[id] && !g_Chase[id] && is_user_connected(id) && !is_user_alive(id)
}

// Click while the client thinks it is spectating: switch the camera, and keep the game's own
// spectator mode from reacting.
public cmd_follownext(id) {
    if (!on_cameras(id)) return PLUGIN_CONTINUE
    new arg[4]
    read_argv(1, arg, charsmax(arg))
    switch_cam(id, str_to_num(arg) != 0)
    return PLUGIN_HANDLED
}

public cmd_specmode(id) {
    return on_cameras(id) ? PLUGIN_HANDLED : PLUGIN_CONTINUE
}

// Runs every frame for every player, before the game handles their buttons.
public fw_prethink(id) {
    if (!g_Watching[id]) return FMRES_IGNORED
    if (is_user_alive(id)) { stop_watch(id); return FMRES_IGNORED; }

    new buttons = pev(id, pev_button)
    new pressed = buttons & ~g_LastButtons[id]
    g_LastButtons[id] = buttons

    // Free chase cam (L): leave everything to the game's spectator mode.
    if (g_Chase[id]) {
        if (pev(id, pev_iuser1) != 0) g_SawObserver[id] = true
        return FMRES_IGNORED
    }

    // Clicks switch cameras too.
    if (pressed & IN_ATTACK) switch_cam(id, false)
    else if (pressed & IN_ATTACK2) switch_cam(id, true)

    // Hide the buttons from the game, so its spectator mode doesn't react to the clicks.
    set_pev(id, pev_button, 0)

    // The game puts dead players into its own spectator mode after a few seconds, which
    // takes over the view. Switch that off and put the camera back.
    if (pev(id, pev_iuser1) != 0) {
        g_SawObserver[id] = true
        set_pev(id, pev_iuser1, 0)
        set_pev(id, pev_iuser2, 0)
        attach_view(id, g_CamEnt[g_Watching[id] - 1])
        clear_status(id)
    }
    return FMRES_IGNORED
}
