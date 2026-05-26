#include <amxmodx>

// Global variables to remember the alive players
new g_AliveCT = 0;
new g_AliveT = 0;

public plugin_init() {
    register_plugin("Enemy Alive Counter Glued", "2.0", "Author");
    
    // Hook events so we ONLY calculate when someone dies or spawns
    register_event("DeathMsg", "trigger_calculation", "a");
    register_logevent("trigger_calculation", 2, "1=Round_Start");
    
    // This loop keeps the text permanently glued to the screen
    set_task(1.0, "refresh_hud", _, _, _, "b");
}

public trigger_calculation() {
    // We delay the count by 0.1 seconds because when a kill happens, 
    // the engine needs a fraction of a second to register the victim as "dead".
    set_task(0.1, "calculate_alive");
}

public calculate_alive() {
    new players[32], count;
    get_players(players, count, "a"); // "a" gets alive players only
    
    // Reset counters
    g_AliveCT = 0;
    g_AliveT = 0;
    
    // Count them
    for (new j = 0; j < count; j++) {
        if (get_user_team(players[j]) == 1) g_AliveT++;
        else if (get_user_team(players[j]) == 2) g_AliveCT++;
    }
    
    // Instantly redraw the HUD so the number drops the exact moment of the kill
    refresh_hud();
}

public refresh_hud() {
    new players[32], count;
    get_players(players, count); // Get ALL connected players to show them the text
    
    for (new j = 0; j < count; j++) {
        new id = players[j];
        
        // FIXED FLICKERING:
        // 1. HoldTime is 1.1s (overlaps the 1.0s task perfectly)
        // 2. Channel is 3 (Fixed channel so it smoothly overwrites itself)
        set_hudmessage(0, 255, 0, 0.005, 0.15, 0, 0.0, 1.1, 0.0, 0.0, 3);
        
        if (get_user_team(id) == 1) { 
            show_hudmessage(id, "Ζωντανοί Μπαλαμοί: %d", g_AliveCT);
        } else if (get_user_team(id) == 2) { 
            show_hudmessage(id, "Ζωντανοί Γιούφτοι: %d", g_AliveT);
        }
    }
}