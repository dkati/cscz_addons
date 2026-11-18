#include <amxmodx>

// Variables to track CT team performance over the whole map
new g_CT_TotalHeadshots = 0
new g_CT_TotalKills = 0
new g_CT_HEKills = 0 

// Arrays to track individual player performance (index 1 to 32)
new g_PlayerHeadshots[33]
new g_PlayerKills[33]
new g_PlayerHEKills[33] 

public plugin_init() {
    register_plugin("Dynamic Headshot & HE Stats", "3.6", "Author")
    
    register_event("DeathMsg", "event_deathmsg", "a")
    register_event("TextMsg", "event_game_restart", "a", "2=#Game_Commencing", "2=#Game_will_restart_in")
    
    // Refresh the HUD every second 
    set_task(1.0, "refresh_hud", 1337, _, _, "b")
}

public client_disconnected(id) {
    g_PlayerKills[id] = 0
    g_PlayerHeadshots[id] = 0
    g_PlayerHEKills[id] = 0
}

public event_game_restart() {
    g_CT_TotalHeadshots = 0
    g_CT_TotalKills = 0
    g_CT_HEKills = 0
    
    for (new i = 1; i <= 32; i++) {
        g_PlayerKills[i] = 0
        g_PlayerHeadshots[i] = 0
        g_PlayerHEKills[i] = 0
    }
}

public event_deathmsg() {
    new attacker = read_data(1)
    new victim = read_data(2)
    new is_headshot = read_data(3) 
    
    new weapon[32]
    read_data(4, weapon, 31)

    if (attacker > 0 && attacker <= 32 && attacker != victim) {
        if (get_user_team(attacker) == 2) {
            
            g_CT_TotalKills++ 
            g_PlayerKills[attacker]++
            
            if (is_headshot == 1) {
                g_CT_TotalHeadshots++
                g_PlayerHeadshots[attacker]++
            }
            
            if (equali(weapon, "grenade")) {
                g_CT_HEKills++
                g_PlayerHEKills[attacker]++
            }
            
            // Note: refresh_hud() was removed from here to prevent the double-trigger flashing.
            // The 1.0s task loop will automatically pick up the new stats and display them smoothly.
        }
    }
}

public refresh_hud() {
    new name[32]
    
    // 1. Draw the Main Dashboard (Headshots)
    if (g_CT_TotalKills > 0) {
        new szMessage[512]
        new len = 0
        
        len += formatex(szMessage[len], 511 - len, "== %d τιμπες συνολικά, %d κιλς ==^n", g_CT_TotalHeadshots, g_CT_TotalKills)
        
        for (new i = 1; i <= 32; i++) {
            if (is_user_connected(i) && get_user_team(i) == 2 && g_PlayerKills[i] > 0) {
                get_user_name(i, name, 31)
                // CHANGED: Replaced g_CT_TotalKills with g_PlayerKills[i]
                len += formatex(szMessage[len], 511 - len, "%s: %d τίμπες,%d κιλς^n", name, g_PlayerHeadshots[i], g_PlayerKills[i])
            }
        }
        
        // EXPLICITLY SET TO CHANNEL 1 (The '1' at the very end of set_hudmessage)
        // Increased holdtime to 1.1s so it overlaps perfectly with the 1.0s task
        set_hudmessage(0, 255, 0, 0.005, 0.20, 0, 0.0, 1.1, 0.0, 0.0, 1)
        show_hudmessage(0, szMessage)
    }

    // 2. Draw the HE Grenade Dashboard
    if (g_CT_HEKills > 0) {
        new szHEMessage[512]
        new lenHE = 0
        
        lenHE += formatex(szHEMessage[lenHE], 511 - lenHE, "== Όρθιοι (%d/%d) ==^n", g_CT_HEKills, g_CT_TotalKills)
        
        for (new i = 1; i <= 32; i++) {
            if (is_user_connected(i) && get_user_team(i) == 2 && g_PlayerHEKills[i] > 0) {
                get_user_name(i, name, 31)
                // CHANGED: Replaced g_CT_TotalKills with g_PlayerKills[i]
                lenHE += formatex(szHEMessage[lenHE], 511 - lenHE, "%s: %d/%d^n", name, g_PlayerHEKills[i], g_PlayerKills[i])
            }
        }

        // EXPLICITLY SET TO CHANNEL 2 (The '2' at the very end of set_hudmessage)
        set_hudmessage(255, 128, 0, 0.005, 0.50, 0, 0.0, 1.1, 0.0, 0.0, 2)
        show_hudmessage(0, szHEMessage)
    }
}