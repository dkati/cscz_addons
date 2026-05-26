#include <amxmodx>

// This is your array of puns. 
// The "%s" will automatically be replaced by the dead person's name.
new const g_Puns[][] = {
    "%s να με φας την καλτσα",
    "Νταξει %s?",
    "%s καριολη",
    "Ρουφα %s!",
    "%s... παρταρχιδιαμου",
	"ΕΕΕ Μηηηηη βε %s",
	"Νταυτο μπουλι %s",
	
}

public plugin_init() {
    register_plugin("Kill Pun Center Message", "1.0", "Author")
    
    // Hook into the engine's Death event
    register_event("DeathMsg", "event_kill", "a")
}

public event_kill() {
    new attacker = read_data(1) // The person who got the kill
    new victim = read_data(2)   // The person who died
    
    // 1. Ensure it's a valid kill (not falling off the map, not suicide)
    // 2. Ensure the attacker is actually connected to the server
    if (attacker > 0 && attacker != victim && is_user_connected(attacker)) {
        
        // We only want to show the message to human players (you and your friends)
        if (!is_user_bot(attacker)) {
            
            new victim_name[32]
            get_user_name(victim, victim_name, charsmax(victim_name))
            
            // Pick a random pun from the array
            new rand = random(sizeof(g_Puns))
            
            // print_center is the exact same UI element as the "Press BUY menu" text
            client_print(attacker, print_center, g_Puns[rand], victim_name)
        }
    }
}