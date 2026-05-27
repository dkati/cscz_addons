#include <amxmodx>

// Variables to track CT team performance over the whole map
new g_CT_TotalHeadshots = 0
new g_CT_TotalKills = 0

// Arrays to track individual player performance (index 1 to 32)
new g_PlayerHeadshots[33]
new g_PlayerKills[33]

public plugin_init() {
    register_plugin("Dynamic Headshot Stats Map", "3.2", "Author")
    
    register_event("DeathMsg", "event_deathmsg", "a")
    
    // Listen for server restarts (e.g., sv_restart 1) to clear stats for a new match
    register_event("TextMsg", "event_game_restart", "a", "2=#Game_Commencing", "2=#Game_will_restart_in")
    
    // Refresh the HUD every second so it stays permanently on screen
    set_task(1.0, "refresh_hud", 1337, _, _, "b")
}

// If a player disconnects, clear their individual stats
public client_disconnected(id) {
    g_PlayerKills[id] = 0
    g_PlayerHeadshots[id] = 0
}

// If the admin restarts the game, reset all stats
public event_game_restart() {
    g_CT_TotalHeadshots = 0
    g_CT_TotalKills = 0
    
    for (new i = 1; i <= 32; i++) {
        g_PlayerKills[i] = 0
        g_PlayerHeadshots[i] = 0
    }
}

public event_deathmsg() {
    new attacker = read_data(1)
    new victim = read_data(2)
    new is_headshot = read_data(3) 

    // Make sure the attacker is a valid player index (1-32) and didn't kill themselves
    if (attacker > 0 && attacker <= 32 && attacker != victim) {
        
        // Check if the attacker is on the Counter-Terrorist team (2 = CT)
        if (get_user_team(attacker) == 2) {
            
            // Increment team and individual kills
            g_CT_TotalKills++ 
            g_PlayerKills[attacker]++
            
            // Increment team and individual headshots if applicable
            if (is_headshot == 1) {
                g_CT_TotalHeadshots++
                g_PlayerHeadshots[attacker]++
            }
            
            // Refresh HUD immediately on kill
            refresh_hud()
        }
    }
}

public refresh_hud() {
    // Only draw the HUD if the CT team has at least 1 kill
    if (g_CT_TotalKills > 0) {
        new szMessage[512]
        new len = 0
        
        // 1. Draw the header with the Team Totals
        len += formatex(szMessage[len], 511 - len, "== Τίμπες (%d/%d) ==^n", g_CT_TotalHeadshots, g_CT_TotalKills)
        
        // 2. Loop through all players to list their individual stats
        new name[32]
        for (new i = 1; i <= 32; i++) {
            // Only list players who are connected, on the CT team, and have at least 1 kill
            if (is_user_connected(i) && get_user_team(i) == 2 && g_PlayerKills[i] > 0) {
                get_user_name(i, name, 31)
                
                // CHANGED: Replaced g_PlayerKills[i] with g_CT_TotalKills 
                // This shows Personal Headshots / Total CT Kills
                len += formatex(szMessage[len], 511 - len, "%s: %d/%d^n", name, g_PlayerHeadshots[i], g_CT_TotalKills)
            }
        }
        
        // Display the HUD
        set_hudmessage(0, 255, 0, 0.005, 0.20, 0, 0.0, 1.1, 0.0, 0.0, 4)
        show_hudmessage(0, szMessage)
    }
}