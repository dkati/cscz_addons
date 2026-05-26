#include <amxmodx>

new g_KillCount[33]
new g_ComboTask[33] // Tracks the timer for each player

public plugin_init() {
    register_plugin("Multi-Kill Announcer (Extended Window)", "1.3", "Author")
    register_event("DeathMsg", "event_deathmsg", "a")
}

public plugin_precache() {
    precache_sound("misc/doublekill.wav")
    precache_sound("misc/triplekill.wav")
    precache_sound("misc/multikill.wav")
}

public event_deathmsg() {
    new attacker = read_data(1)
    new victim = read_data(2)

    if (attacker > 0 && attacker != victim) {
        new attacker_name[32]
        get_user_name(attacker, attacker_name, 31)

        // Increment the kill count
        g_KillCount[attacker]++
        
        // Remove the old timer if it exists, so we don't reset early
        if (task_exists(g_ComboTask[attacker])) {
            remove_task(g_ComboTask[attacker])
        }

        // Trigger sounds/messages based on count
        switch(g_KillCount[attacker]) {
            case 2: {
                client_cmd(0, "spk misc/doublekill")
                client_print(0, print_chat, "[%s]: Double Kill!", attacker_name)
            }
            case 3: {
                client_cmd(0, "spk misc/triplekill")
                client_print(0, print_chat, "[%s]: Triple Kill!", attacker_name)
            }
            case 4..10: {
                client_cmd(0, "spk misc/multikill")
                client_print(0, print_chat, "[%s]: M-M-M-MULTI KILL!", attacker_name)
            }
        }

        // Set a new 2-second timer. If this expires, the player's combo resets.
        // We use the player's ID + 100 to ensure the task ID is unique.
        g_ComboTask[attacker] = attacker + 100
        set_task(2.0, "reset_combo", g_ComboTask[attacker])
    }
}

public reset_combo(taskid) {
    // Convert the task ID back to the player index
    new id = taskid - 100
    g_KillCount[id] = 0
}