#include <amxmodx>

// Stats box: one green box at the top left (HUD channel 1), for every human player.
// Replaces the old showenemies + headshot_pun plugins.
//
//   Πόσες νίκις έχομι: 3                     <- own team's round wins
//   Ζωντανοί Γιούφτοι: 2                     <- enemies alive (only for players on a team)
//
//   == 12 τιμπες συνολικά, 30 κιλς (40%) ==  <- CT headshots / kills
//   Player1: 8 τίμπες,15 κιλς (53%)
//
//   == Όρθιοι (3/30) ==                      <- CT HE grenade kills
//   Player1: 3/15
//
// Kills are NOT counted by this plugin: they are read from the game with get_user_frags(),
// so they always match the scoreboard (team kills -1, suicides -1, bomb defuse/plant +3,
// frags kept when a player switches team). The plugin only counts what the scoreboard does not
// track: headshots and HE kills (team kills don't count).
//
// O ("data_toggle"): each player can hide the kill / headshot / HE part and the key list
// (hotkeys_hud); the box then shows "Press O to show data" under the team lines.
//
// Console setting (can be changed live):
//   amx_hudcol_y  0.20   top of the box (0.0 = top .. 1.0 = bottom); the key list (hotkeys_hud)
//                        follows right below it
//
// HUD channels: 1 = this, 2 + 4 = hotkeys_hud (green / red lines), 3 = wallhack.

#define HUD_COL_X     0.005
#define HUD_CHANNEL   1
#define TASK_REFRESH  1337

// Per-player counters (index 1 to 32)
new g_PlayerHeadshots[33]
new g_PlayerHEKills[33]

// Team scores, caught from the game's TeamScore message
new g_ScoreCT = 0
new g_ScoreT = 0

new g_pColY
new g_Lines[33]     // lines in the last box sent to each player (read by hotkeys_hud)
new bool:g_Hidden[33]   // player pressed O: kill stats (and the key list) hidden

public plugin_init() {
    register_plugin("Stats", "1.2", "Author")

    g_pColY = register_cvar("amx_hudcol_y", "0.20")

    register_event("DeathMsg", "event_deathmsg", "a")
    register_event("TeamScore", "event_team_score", "a")
    register_clcmd("data_toggle", "cmd_data_toggle")   // O, bound in czero_addon/userconfig.cfg
    register_event("TextMsg", "event_game_restart", "a", "2=#Game_Commencing", "2=#Game_will_restart_in")

    // Refresh the box every second (and shortly after every death)
    set_task(1.0, "refresh_hud", TASK_REFRESH, _, _, "b")
}

// Used by hotkeys_hud.amxx (via callfunc) to place the key list right below this box.
// "data_toggle" (bound to O): each player hides / shows their own kill stats and key list.
public cmd_data_toggle(id) {
    if (id < 1 || id > 32 || !is_user_connected(id)) return PLUGIN_HANDLED
    g_Hidden[id] = !g_Hidden[id]
    refresh_hud()
    return PLUGIN_HANDLED
}

// Used by hotkeys_hud.amxx (via callfunc): 1 = this player has hidden the data.
public stats_hidden(id) {
    return (id >= 1 && id <= 32 && g_Hidden[id]) ? 1 : 0
}

public stats_lines(id) {
    return (id >= 1 && id <= 32) ? g_Lines[id] : 0
}

public client_disconnected(id) {
    g_Lines[id] = 0
    g_Hidden[id] = false
    g_PlayerHeadshots[id] = 0
    g_PlayerHEKills[id] = 0
}

public event_game_restart() {
    for (new i = 1; i <= 32; i++) {
        g_PlayerHeadshots[i] = 0
        g_PlayerHEKills[i] = 0
    }
}

public event_team_score() {
    new team[32]
    read_data(1, team, charsmax(team))   // "CT" or "TERRORIST"
    new score = read_data(2)
    if (equal(team, "CT")) g_ScoreCT = score
    else if (equal(team, "TERRORIST")) g_ScoreT = score
}

public event_deathmsg() {
    new attacker = read_data(1)
    new victim = read_data(2)

    // update the enemies-alive count quickly
    remove_task(TASK_REFRESH + 1)
    set_task(0.1, "refresh_hud", TASK_REFRESH + 1)

    // Ignore world deaths, suicides and team kills (the scoreboard subtracts them)
    if (attacker < 1 || attacker > 32 || attacker == victim) return
    if (get_user_team(attacker) == get_user_team(victim)) return

    if (read_data(3) == 1) {
        g_PlayerHeadshots[attacker]++
    }

    new weapon[32]
    read_data(4, weapon, charsmax(weapon))
    if (equali(weapon, "grenade")) {
        g_PlayerHEKills[attacker]++
    }
}

// Headshots as a percentage of kills (rounded). Kills can be 0 or negative (team kills,
// suicides), and can be lower than headshots, so keep the result between 0 and 100.
hs_percent(headshots, kills) {
    if (kills <= 0) return 0
    new pct = (headshots * 100 + kills / 2) / kills
    return pct > 100 ? 100 : pct
}

// The headshot and HE part, the same for everyone. Returns its length.
build_kill_stats(msg[], maxlen) {
    new players[32], num
    get_players(players, num, "e", "CT")

    new totalKills = 0, totalHS = 0, totalHE = 0
    for (new j = 0; j < num; j++) {
        new id = players[j]
        totalKills += get_user_frags(id)
        totalHS += g_PlayerHeadshots[id]
        totalHE += g_PlayerHEKills[id]
    }

    new name[32], len = 0

    if (totalKills > 0 || totalHS > 0) {
        len += formatex(msg[len], maxlen - len, "== %d τιμπες συνολικά, %d κιλς (%d%%) ==^n", totalHS, totalKills, hs_percent(totalHS, totalKills))
        for (new j = 0; j < num; j++) {
            new id = players[j]
            new frags = get_user_frags(id)
            if (frags != 0 || g_PlayerHeadshots[id] > 0) {
                get_user_name(id, name, charsmax(name))
                len += formatex(msg[len], maxlen - len, "%s: %d τίμπες,%d κιλς (%d%%)^n", name, g_PlayerHeadshots[id], frags, hs_percent(g_PlayerHeadshots[id], frags))
            }
        }
    }

    if (totalHE > 0) {
        if (len > 0) len += formatex(msg[len], maxlen - len, "^n")
        len += formatex(msg[len], maxlen - len, "== Όρθιοι (%d/%d) ==^n", totalHE, totalKills)
        for (new j = 0; j < num; j++) {
            new id = players[j]
            if (g_PlayerHEKills[id] > 0) {
                get_user_name(id, name, charsmax(name))
                len += formatex(msg[len], maxlen - len, "%s: %d/%d^n", name, g_PlayerHEKills[id], get_user_frags(id))
            }
        }
    }
    return len
}

public refresh_hud() {
    // enemies alive per team
    new alive[32], alive_count, numT = 0, numCT = 0
    get_players(alive, alive_count, "a")
    for (new j = 0; j < alive_count; j++) {
        new team = get_user_team(alive[j])
        if (team == 1) numT++
        else if (team == 2) numCT++
    }

    new kills[400]
    new klen = build_kill_stats(kills, charsmax(kills))

    new Float:y = get_pcvar_float(g_pColY)
    new humans[32], count
    get_players(humans, count, "c")   // humans only, bots do not need a HUD

    for (new j = 0; j < count; j++) {
        new id = humans[j]
        new msg[512], len = 0
        new team = get_user_team(id)
        if (team == 1) {
            len += formatex(msg[len], charsmax(msg) - len, "Πόσες νίκις έχομι: %d^nΖωντανοί Μπαλαμοί: %d^n", g_ScoreT, numCT)
        } else if (team == 2) {
            len += formatex(msg[len], charsmax(msg) - len, "Πόσες νίκις έχομι: %d^nΖωντανοί Γιούφτοι: %d^n", g_ScoreCT, numT)
        }
        if (g_Hidden[id]) {
            if (len > 0) len += formatex(msg[len], charsmax(msg) - len, "^n")
            len += formatex(msg[len], charsmax(msg) - len, "Press O to show data^n")
        } else if (klen > 0) {
            if (len > 0) len += formatex(msg[len], charsmax(msg) - len, "^n")
            len += formatex(msg[len], charsmax(msg) - len, "%s", kills)
        }
        new lines = 0
        for (new k = 0; k < len; k++) if (msg[k] == '^n') lines++
        g_Lines[id] = lines
        if (len > 0) {
            set_hudmessage(0, 255, 0, HUD_COL_X, y, 0, 0.0, 1.1, 0.0, 0.0, HUD_CHANNEL)
            show_hudmessage(id, "%s", msg)
        }
    }
}
