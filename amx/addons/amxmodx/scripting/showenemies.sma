#include <amxmodx>
#include <amxmisc>

public plugin_init() {
    register_plugin("Enemy Alive Counter", "1.0", "Author");
    // Set a task to run every 1 second to update the counter
    set_task(1.0, "display_enemy_count", _, _, _, "b");
}

public display_enemy_count() {
    new players[32], numCT, numT, i;
    
    // Get all players
    get_players(players, i, "a"); // "a" flag gets all alive players
    
    // Count alive CTs and Ts
    for (new j = 0; j < i; j++) {
        if (get_user_team(players[j]) == 1) numT++;
        else if (get_user_team(players[j]) == 2) numCT++;
    }
    
    // Loop through all connected players to show the message
    new all_players[32], count;
    get_players(all_players, count);
    
    for (new j = 0; j < count; j++) {
        new id = all_players[j];
        new team = get_user_team(id);
        
        if (team == 1) { // If player is T, show how many CTs are alive
            set_hudmessage(255, 0, 0, 0.02, 0.20, 0, 6.0, 1.1, 0.1, 0.2, -1);
            show_hudmessage(id, "Enemies Alive (CT): %d", numCT);
        } else if (team == 2) { // If player is CT, show how many Ts are alive
            set_hudmessage(0, 0, 255, 0.02, 0.20, 0, 6.0, 1.1, 0.1, 0.2, -1);
            show_hudmessage(id, "Enemies Alive (T): %d", numT);
        }
    }
}