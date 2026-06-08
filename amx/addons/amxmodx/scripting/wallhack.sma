#include <amxmodx>
#include <cstrike>

// We need a variable to hold the HUD synchronization object
new g_HudSync;

public plugin_init() {
    register_plugin("Last 5 Text Tracker", "1.0", "YourName");
    
    // Create the HUD Sync object to prevent text flickering
    g_HudSync = CreateHudSyncObj();
    
    // Update the distances every 0.5 seconds
    set_task(0.5, "Task_ShowESP", .flags="b"); 
}

public Task_ShowESP() {
    new players[32], pnum;
    get_players(players, pnum, "a"); 
    
    new t_count = 0, ct_count = 0;
    
    // Count alive players
    for (new i = 0; i < pnum; i++) {
        if (cs_get_user_team(players[i]) == CS_TEAM_T) t_count++;
        else if (cs_get_user_team(players[i]) == CS_TEAM_CT) ct_count++;
    }
    
    // Trigger the tracker if enemies are low
    if (t_count > 0 && t_count < 5) DrawTracker(CS_TEAM_T, CS_TEAM_CT, players, pnum);
    if (ct_count > 0 && ct_count < 5) DrawTracker(CS_TEAM_CT, CS_TEAM_T, players, pnum);
}

DrawTracker(TargetTeam, ViewingTeam, players[], pnum) {
    new hudMsg[256];
    new len;

    for (new j = 0; j < pnum; j++) {
        new viewer = players[j];
        if (cs_get_user_team(viewer) != ViewingTeam) continue;

        new viewerOrigin[3];
        get_user_origin(viewer, viewerOrigin, 0); 

        len = 0; 

        // Find the targets
        for (new i = 0; i < pnum; i++) {
            new target = players[i];
            
            if (cs_get_user_team(target) == TargetTeam) {
                new targetOrigin[3];
                get_user_origin(target, targetOrigin, 0); 
                
                // Calculate distance in meters
                new distanceUnits = get_distance(viewerOrigin, targetOrigin);
                new distanceMeters = distanceUnits / 39; 

                new name[32];
                get_user_name(target, name, charsmax(name));
                
                // Build the text list
                len += formatex(hudMsg[len], charsmax(hudMsg)-len, "%s: %dm^n", name, distanceMeters);
            }
        }

        // Show the smooth HUD message directly below the crosshair
        if (len > 0) {
            // Colors based on which team you are tracking (Red for T, Blue for CT)
            if (TargetTeam == CS_TEAM_T) {
                set_hudmessage(255, 50, 50, -1.0, 0.58, 0, 0.0, 0.6, 0.0, 0.0, -1);
            } else {
                set_hudmessage(50, 150, 255, -1.0, 0.58, 0, 0.0, 0.6, 0.0, 0.0, -1);
            }
            
            // Use ShowSyncHudMsg instead of show_hudmessage for smooth updates
            ShowSyncHudMsg(viewer, g_HudSync, hudMsg);
        }
    }
}