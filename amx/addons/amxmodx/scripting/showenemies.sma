#include <amxmodx>
#include <amxmisc>

public plugin_init() {
    register_plugin("Enemy Alive Counter", "1.0", "Author");
    set_task(1.0, "display_enemy_count", _, _, _, "b");
}

public display_enemy_count() {
    new players[32], numCT, numT, i;
    
    get_players(players, i, "a"); 
    
    for (new j = 0; j < i; j++) {
        if (get_user_team(players[j]) == 1) numT++;
        else if (get_user_team(players[j]) == 2) numCT++;
    }
    
    new all_players[32], count;
    get_players(all_players, count);
    
    for (new j = 0; j < count; j++) {
        new id = all_players[j];
        
        // Settings: Red, Green, Blue, X, Y, Effects, FxTime, HoldTime, FadeIn, FadeOut, Channel
        // Changed Y to 0.15 (higher), Color to (0, 255, 0) (Green), and Fades to 0.0 (Solid)
        set_hudmessage(0, 255, 0, 0.01, 0.15, 0, 0.0, 1.0, 0.0, 0.0, -1);
        
        if (get_user_team(id) == 1) { 
            show_hudmessage(id, "Ζωντανοί Μπαλαμοί: %d", numCT);
        } else if (get_user_team(id) == 2) { 
            show_hudmessage(id, "Ζωντανοί Γιούφτοι: %d", numT);
        }
    }
}