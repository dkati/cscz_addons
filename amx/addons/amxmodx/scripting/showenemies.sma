#include <amxmodx>

// New variables to track the team scores
new g_ScoreCT = 0;
new g_ScoreT = 0;

public plugin_init() {
    register_plugin("Enemy Alive & Score Auto-Correct", "2.2", "Author");
    
    register_event("DeathMsg", "trigger_calculation", "a");
    
    // Hook the engine's built-in score update event
    register_event("TeamScore", "event_team_score", "a");
    
    set_task(1.0, "refresh_hud", _, _, _, "b");
}

// This function catches the score from the server every time it changes
public event_team_score() {
    new team[32];
    read_data(1, team, 31); // 1st piece of data is the Team Name ("CT" or "TERRORIST")
    new score = read_data(2); // 2nd piece of data is the integer score
    
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
    
    new all_players[32], count;
    get_players(all_players, count); 
    
    for (new j = 0; j < count; j++) {
        new id = all_players[j];
        
        set_hudmessage(0, 255, 0, 0.6, 0.005, 0, 0.0, 1.1, 0.0, 0.0, 3);
        
        if (get_user_team(id) == 1) { 
            // If you are Terrorist: Show T Score, then Alive CTs
            show_hudmessage(id, "Πόσες νίκις έχομι: %d^nΖωντανοί Μπαλαμοί: %d", g_ScoreT, numCT);
        } else if (get_user_team(id) == 2) { 
            // If you are CT: Show CT Score, then Alive Ts
            show_hudmessage(id, "Πόσες νίκις έχομι: %d^nΖωντανοί Γιούφτοι: %d", g_ScoreCT, numT);
        }
    }
}