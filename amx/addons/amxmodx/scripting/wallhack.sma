#include <amxmodx>
#include <cstrike>
#include <fakemeta>

// We need a variable to hold the HUD synchronization object
new g_HudSync;

public plugin_init() {
    register_plugin("Last 5 Text Tracker (Greek)", "1.2", "YourName");
    
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

        // Get Viewer's coordinates
        new viewerOrigin[3];
        get_user_origin(viewer, viewerOrigin, 0); 

        // Convert Integer Origin to Float for vector math
        new Float:fViewerOrig[3];
        IVecFVec(viewerOrigin, fViewerOrig);

        // Get Viewer's real-time view angles (where their camera is pointing)
        new Float:viewerAngles[3];
        pev(viewer, pev_v_angle, viewerAngles);

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

                // --- DIRECTIONAL MATH ---
                
                // 1. Get Target Float Origin
                new Float:fTargetOrig[3];
                IVecFVec(targetOrigin, fTargetOrig);

                // 2. Find vector from Viewer to Target
                new Float:vDiff[3];
                vDiff[0] = fTargetOrig[0] - fViewerOrig[0];
                vDiff[1] = fTargetOrig[1] - fViewerOrig[1];
                vDiff[2] = fTargetOrig[2] - fViewerOrig[2];

                // 3. Convert that vector into a directional angle
                new Float:targetAngles[3];
                engfunc(EngFunc_VecToAngles, vDiff, targetAngles);

                // 4. Calculate Relative Yaw (Left/Right/Front/Back)
                new Float:relYaw = targetAngles[1] - viewerAngles[1];
                
                // Normalize angle to keep it between -180 and 180 degrees
                while(relYaw > 180.0) relYaw -= 360.0;
                while(relYaw < -180.0) relYaw += 360.0;

                // 5. Determine Horizontal Text (Greek)
                new horiz[32];
                if (relYaw >= -45.0 && relYaw <= 45.0) copy(horiz, charsmax(horiz), "ΜΠΡΟΣΤΑ");
                else if (relYaw > 45.0 && relYaw < 135.0) copy(horiz, charsmax(horiz), "ΑΡΙΣΤΕΡΑ");
                else if (relYaw < -45.0 && relYaw > -135.0) copy(horiz, charsmax(horiz), "ΔΕΞΙΑ");
                else copy(horiz, charsmax(horiz), "ΠΙΣΩ");

                // 6. Determine Vertical Text (Greek)
                new zDiff = targetOrigin[2] - viewerOrigin[2];
                new vert[16]; 
                if (zDiff > 50) copy(vert, charsmax(vert), "ΠΑΝΩ-");
                else if (zDiff < -50) copy(vert, charsmax(vert), "ΚΑΤΩ-");
                else copy(vert, charsmax(vert), ""); // Level ground, keep empty

                // --- FORMATTING ---

                new name[32];
                get_user_name(target, name, charsmax(name));
                
                // Output looks like: "Player1: 15m [ΠΑΝΩ-ΑΡΙΣΤΕΡΑ]"
                len += formatex(hudMsg[len], charsmax(hudMsg)-len, "%s: %dm [%s%s]^n", name, distanceMeters, vert, horiz);
            }
        }

        // Show the smooth HUD message
        if (len > 0) {
            if (TargetTeam == CS_TEAM_T) {
                set_hudmessage(255, 50, 50, -1.0, 0.58, 0, 0.0, 0.6, 0.0, 0.0, -1);
            } else {
                set_hudmessage(50, 150, 255, -1.0, 0.58, 0, 0.0, 0.6, 0.0, 0.0, -1);
            }
            
            ShowSyncHudMsg(viewer, g_HudSync, hudMsg);
        }
    }
}