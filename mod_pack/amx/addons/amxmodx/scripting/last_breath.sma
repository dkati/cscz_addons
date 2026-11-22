#include <amxmodx>
#include <fun>

// A CT player who stays alive with low health (amx_lastbreath_hp or less) for longer than
// amx_lastbreath_time seconds cannot die for the rest of the round.
// The protection is removed at the start of every new round.
//
// Console settings (can be changed live):
//   amx_lastbreath_hp    10    health at or below which the timer starts
//   amx_lastbreath_time  3.0   seconds the player has to stay at that health
//
//   amx_undead_on        1     1 = on (the default; kept across map changes)
//
// On/off for everyone: K ("undead_toggle", bound in czero_addon/userconfig.cfg). Any player can
// do it; the message says who. Turning it off also removes the protection from players who
// already have it.

#define CHECK_INTERVAL 0.1

// Played to everyone together with the big message.
// File: czero/sound/misc/alimono.wav (in the repo: mod_pack/czero_addon/sound/misc/alimono.wav)
#define SOUND_FILE "misc/alimono.wav"

new Float:g_LowSince[33]   // game time when the player dropped to low health, 0.0 = not low
new bool:g_Protected[33]

new g_pHp, g_pTime
new g_pOn

public plugin_init() {
    register_plugin("Last Breath (CT)", "1.3", "Author")

    g_pHp = register_cvar("amx_lastbreath_hp", "10")
    g_pTime = register_cvar("amx_lastbreath_time", "3.0")
    g_pOn = register_cvar("amx_undead_on", "1")

    // New round (freeze time start)
    register_event("HLTV", "event_new_round", "a", "1=0", "2=0")

    register_clcmd("undead_toggle", "cmd_toggle")

    set_task(CHECK_INTERVAL, "check_players", _, _, _, "b")
}

// Precaching makes the server load the sound at map start and makes joining
// players download it if they do not have it.
public plugin_precache() {
    precache_sound(SOUND_FILE)
}

public client_disconnected(id) {
    reset_player(id)
}

public event_new_round() {
    for (new id = 1; id <= 32; id++) {
        if (g_Protected[id] && is_user_connected(id)) {
            set_user_godmode(id, 0)
        }
        reset_player(id)
    }
}

reset_player(id) {
    g_LowSince[id] = 0.0
    g_Protected[id] = false
}

public cmd_toggle(id) {
    if (id && !is_user_connected(id)) return PLUGIN_HANDLED   // any player (or the server console)

    new bool:on = get_pcvar_num(g_pOn) == 0
    set_pcvar_num(g_pOn, on ? 1 : 0)
    if (!on) {
        for (new i = 1; i <= 32; i++) {
            if (g_Protected[i] && is_user_connected(i)) set_user_godmode(i, 0)
            reset_player(i)
        }
    }

    if (on) set_dhudmessage(40, 255, 40, -1.0, 0.20, 0, 0.0, 3.0, 0.2, 0.5)
    else set_dhudmessage(255, 160, 0, -1.0, 0.20, 0, 0.0, 3.0, 0.2, 0.5)
    new who[32]
    if (id) get_user_name(id, who, charsmax(who)); else copy(who, charsmax(who), "server")
    show_dhudmessage(0, "Undead Script: %s (%s)", on ? "On" : "Off", who)
    return PLUGIN_HANDLED
}

public check_players() {
    if (get_pcvar_num(g_pOn) == 0) return
    new players[32], num
    get_players(players, num, "ae", "CT")   // alive CTs only

    new lowHp = get_pcvar_num(g_pHp)
    new Float:needed = get_pcvar_float(g_pTime)
    new Float:now = get_gametime()

    for (new i = 0; i < num; i++) {
        new id = players[i]
        if (g_Protected[id]) continue

        if (get_user_health(id) > lowHp) {
            g_LowSince[id] = 0.0
            continue
        }

        if (g_LowSince[id] == 0.0) {
            g_LowSince[id] = now
        }
        else if (now - g_LowSince[id] > needed) {
            g_Protected[id] = true
            set_user_godmode(id, 1)
            // Big "director" HUD text (larger font, separate from the 4 normal HUD channels),
            // centered, red, fades in and stays ~4 seconds. Shown to everyone.
            set_dhudmessage(255, 30, 30, -1.0, 0.30, 0, 0.0, 4.0, 0.3, 1.0)
            show_dhudmessage(0, "Α Λ Ι Μ Ο Ν Ο...εκδικηση στην αδικια")
            client_cmd(0, "spk ^"%s^"", SOUND_FILE)
        }
    }
}
