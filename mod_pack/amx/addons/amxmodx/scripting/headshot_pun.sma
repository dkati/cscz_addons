#include <amxmodx>

// Kills are NOT counted by this plugin: they are read from the game with get_user_frags(),
// so they always match the scoreboard (team kills -1, suicides -1, bomb defuse/plant +3,
// frags kept when a player switches team).
// The plugin only counts what the scoreboard does not track: headshots and HE kills.

// Per-player counters (index 1 to 32)
new g_PlayerHeadshots[33]
new g_PlayerHEKills[33]

public plugin_init() {
    register_plugin("Dynamic Headshot & HE Stats", "4.0", "Author")

    register_event("DeathMsg", "event_deathmsg", "a")
    register_event("TextMsg", "event_game_restart", "a", "2=#Game_Commencing", "2=#Game_will_restart_in")

    // Refresh the HUD every second
    set_task(1.0, "refresh_hud", 1337, _, _, "b")
}

public client_disconnected(id) {
    g_PlayerHeadshots[id] = 0
    g_PlayerHEKills[id] = 0
}

public event_game_restart() {
    for (new i = 1; i <= 32; i++) {
        g_PlayerHeadshots[i] = 0
        g_PlayerHEKills[i] = 0
    }
}

public event_deathmsg() {
    new attacker = read_data(1)
    new victim = read_data(2)

    // Ignore world deaths and suicides
    if (attacker < 1 || attacker > 32 || attacker == victim) return

    // Ignore team kills (the scoreboard subtracts them)
    if (get_user_team(attacker) == get_user_team(victim)) return

    if (read_data(3) == 1) {
        g_PlayerHeadshots[attacker]++
    }

    new weapon[32]
    read_data(4, weapon, charsmax(weapon))
    if (equali(weapon, "grenade")) {
        g_PlayerHEKills[attacker]++
    }
    // The 1.0s task loop picks up the new stats (no refresh here, to avoid flashing).
}

// Headshots as a percentage of kills (rounded). Kills can be 0 or negative (team kills,
// suicides), and can be lower than headshots, so keep the result between 0 and 100.
hs_percent(headshots, kills) {
    if (kills <= 0) return 0
    new pct = (headshots * 100 + kills / 2) / kills
    return pct > 100 ? 100 : pct
}

public refresh_hud() {
    new players[32], num
    get_players(players, num, "e", "CT")

    new totalKills = 0, totalHS = 0, totalHE = 0
    for (new j = 0; j < num; j++) {
        new id = players[j]
        totalKills += get_user_frags(id)
        totalHS += g_PlayerHeadshots[id]
        totalHE += g_PlayerHEKills[id]
    }

    new name[32]

    // 1. Main dashboard (headshots / kills)
    if (totalKills > 0 || totalHS > 0) {
        new szMessage[512]
        new len = 0

        len += formatex(szMessage[len], charsmax(szMessage) - len, "== %d τιμπες συνολικά, %d κιλς (%d%%) ==^n", totalHS, totalKills, hs_percent(totalHS, totalKills))

        for (new j = 0; j < num; j++) {
            new id = players[j]
            new frags = get_user_frags(id)
            if (frags != 0 || g_PlayerHeadshots[id] > 0) {
                get_user_name(id, name, charsmax(name))
                len += formatex(szMessage[len], charsmax(szMessage) - len, "%s: %d τίμπες,%d κιλς (%d%%)^n", name, g_PlayerHeadshots[id], frags, hs_percent(g_PlayerHeadshots[id], frags))
            }
        }

        // Channel 1
        set_hudmessage(0, 255, 0, 0.005, 0.20, 0, 0.0, 1.1, 0.0, 0.0, 1)
        show_hudmessage(0, szMessage)
    }

    // 2. HE grenade dashboard
    if (totalHE > 0) {
        new szHEMessage[512]
        new lenHE = 0

        lenHE += formatex(szHEMessage[lenHE], charsmax(szHEMessage) - lenHE, "== Όρθιοι (%d/%d) ==^n", totalHE, totalKills)

        for (new j = 0; j < num; j++) {
            new id = players[j]
            if (g_PlayerHEKills[id] > 0) {
                get_user_name(id, name, charsmax(name))
                lenHE += formatex(szHEMessage[lenHE], charsmax(szHEMessage) - lenHE, "%s: %d/%d^n", name, g_PlayerHEKills[id], get_user_frags(id))
            }
        }

        // Channel 2
        set_hudmessage(255, 128, 0, 0.005, 0.50, 0, 0.0, 1.1, 0.0, 0.0, 2)
        show_hudmessage(0, szHEMessage)
    }
}
