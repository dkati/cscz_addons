#include <amxmodx>

#define MAX_LINES 10 
new g_Lines[MAX_LINES][64] 
new g_LineCount = 0 
new g_FinalMsg[512] 

// New variables to track the score
new g_TotalHeadshots = 0
new g_EnemyCount = 0

public plugin_init() {
    register_plugin("Dynamic Headshot Feed Permanent", "2.3", "Author")
    
    register_event("DeathMsg", "event_deathmsg", "a")
    register_logevent("event_round_start", 2, "1=Round_Start")
    
    set_task(1.0, "refresh_hud", 1337, _, _, "b")
}

public event_deathmsg() {
    new attacker = read_data(1)
    new victim = read_data(2)
    new is_headshot = read_data(3) 

    if (is_headshot == 1 && attacker > 0 && attacker != victim) {
        new attacker_name[32], victim_name[32]
        get_user_name(attacker, attacker_name, 31)
        get_user_name(victim, victim_name, 31)

        // 1. Increase the total headshot count
        g_TotalHeadshots++
        
        // 2. Find out how many people are on the victim's team (The Enemy Team)
        new victim_team = get_user_team(victim)
        new players[32]
        if (victim_team == 1) { // 1 = Terrorist
            get_players(players, g_EnemyCount, "e", "TERRORIST")
        } else if (victim_team == 2) { // 2 = Counter-Terrorist
            get_players(players, g_EnemyCount, "e", "CT")
        }

        // Shift messages up if we hit the limit
        if (g_LineCount >= MAX_LINES) {
            for (new i = 0; i < MAX_LINES - 1; i++) {
                copy(g_Lines[i], 63, g_Lines[i+1])
            }
            g_LineCount = MAX_LINES - 1
        }

        formatex(g_Lines[g_LineCount], 63, "(%s) ώπα %s", attacker_name, victim_name)
        g_LineCount++

        // Rebuild the global string
        g_FinalMsg[0] = '^0' 
        for (new i = 0; i < g_LineCount; i++) {
            add(g_FinalMsg, 511, g_Lines[i])
            add(g_FinalMsg, 511, "^n") 
        }
        
        refresh_hud()
    }
}

public refresh_hud() {
    if (g_LineCount > 0) {
        set_hudmessage(0, 255, 0, 0.005, 0.20, 0, 0.0, 1.1, 0.0, 0.0, 4)
        
        // Added the (%d/%d) variables to the header
        show_hudmessage(0, "== Τίμπες (%d/%d) ==^n%s", g_TotalHeadshots, g_EnemyCount, g_FinalMsg)
    }
}

public event_round_start() {
    g_LineCount = 0 
    g_FinalMsg[0] = '^0' 
    
    // Reset the counters when a new round starts
    g_TotalHeadshots = 0
    g_EnemyCount = 0
    
    set_hudmessage(0, 0, 0, 0.0, 0.0, 0, 0.0, 0.1, 0.0, 0.0, 4)
    show_hudmessage(0, "")
}