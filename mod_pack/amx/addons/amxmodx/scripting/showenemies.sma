#include <amxmodx>

// HUD channels used by our plugins (the game has 4):
//   1, 2 = headshot_pun   3 = showenemies   4 = wallhack

// Team scores, caught from the game's TeamScore message
new g_ScoreCT = 0;
new g_ScoreT = 0;

// This box is the top of the left HUD column (see headshot_pun.sma for the layout).
// amx_hudcol_y = top of the column, shared with headshot_pun. Change live in the console,
// e.g.  amx_hudcol_y 0.25
#define HUD_COL_X 0.005
new g_pY;

public plugin_init() {
    register_plugin("Enemy Alive & Score Auto-Correct", "2.4", "Author");

    g_pY = register_cvar("amx_hudcol_y", "0.20");
    register_cvar("amx_hudcol_lineh", "0.03"); // used by headshot_pun, registered here too

    register_event("DeathMsg", "trigger_calculation", "a");

    // Hook the engine's built-in score update event
    register_event("TeamScore", "event_team_score", "a");

    set_task(1.0, "refresh_hud", _, _, _, "b");
}

// This function catches the score from the server every time it changes
public event_team_score() {
    new team[32];
    read_data(1, team, 31); // Team name ("CT" or "TERRORIST")
    new score = read_data(2);

    if (equal(team, "CT")) {
        g_ScoreCT = score;
    } else if (equal(team, "TERRORIST")) {
        g_ScoreT = score;
    }
}

public trigger_calculation() {
    set_task(0.1, "refresh_hud");
}

public refresh_hud() {
    new alive_players[32], alive_count;
    get_players(alive_players, alive_count, "a");

    new numT = 0, numCT = 0;

    for (new j = 0; j < alive_count; j++) {
        if (get_user_team(alive_players[j]) == 1) numT++;
        else if (get_user_team(alive_players[j]) == 2) numCT++;
    }


    new Float:y = get_pcvar_float(g_pY);

    new all_players[32], count;
    get_players(all_players, count, "c"); // humans only, bots do not need a HUD

    for (new j = 0; j < count; j++) {
        new id = all_players[j];

        set_hudmessage(0, 255, 0, HUD_COL_X, y, 0, 0.0, 1.1, 0.0, 0.0, 3);

        if (get_user_team(id) == 1) {
            // Terrorist: T score, then alive CTs
            show_hudmessage(id, "Πόσες νίκις έχομι: %d^nΖωντανοί Μπαλαμοί: %d", g_ScoreT, numCT);
        } else if (get_user_team(id) == 2) {
            // CT: CT score, then alive Ts
            show_hudmessage(id, "Πόσες νίκις έχομι: %d^nΖωντανοί Γιούφτοι: %d", g_ScoreCT, numT);
        }
    }
}
