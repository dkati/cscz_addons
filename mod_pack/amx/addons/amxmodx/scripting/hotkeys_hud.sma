#include <amxmodx>

// Sticky key list for alive human players, on the right side of the screen:
//
//   Pause Script (P)
//   Camera Script (I) (click change camera)
//   Undead Script (K)
//
// Each script keeps its own on/off state in a cvar; this plugin only reads them.
// To add a script: add a line to LINES below (cvar name, "" = always on).
//
// Each line is green when its script is on and red when it is off.
//
// Placed on the left, right below the stats box (stats.amxx): it uses the same position as the
// stats box and starts with as many empty lines as that box has (+1 gap), so it always follows it,
// however tall the box gets. The stats plugin reports its line count per player (stats_lines).
// Move both together with amx_hudcol_y.
//
// Normal (small) HUD text, like the stats box. A channel can show only one color, so the list uses
// two channels at the same spot: channel 2 holds the green lines, channel 4 the red lines, each
// with an empty line where the other color's line goes. (Channel 1 = stats, 3 = wallhack.)

#define REFRESH 0.25
#define HOLD    0.35
#define HUD_COL_X 0.005      // same left edge as the stats box
#define CH_ON   2
#define CH_OFF  4
#define LINES   3

new const g_Label[LINES][] = { "Pause Script",  "Camera Script",                 "Undead Script" }
new const g_Cvar[LINES][]  = { "",              "amx_cams_on",                   "amx_undead_on" }
new const g_Keys[LINES][]  = { "(P)",           "(I) (click change camera)",         "(K)" }

new g_pCvar[LINES]
new g_pColY

public plugin_init() {
    register_plugin("Hotkeys HUD", "1.3", "Author")
    g_pColY = register_cvar("amx_hudcol_y", "0.20")   // shared with stats.sma
    set_task(REFRESH, "refresh", _, _, _, "b")
}

// The other plugins have registered their cvars by now.
public plugin_cfg() {
    for (new i = 0; i < LINES; i++) {
        g_pCvar[i] = g_Cvar[i][0] ? get_cvar_pointer(g_Cvar[i]) : 0
    }
}

// Number of lines in the stats box this player sees (0 if the stats plugin isn't running).
stats_lines(id) {
    if (callfunc_begin("stats_lines", "stats.amxx") != 1) return 0
    callfunc_push_int(id)
    return callfunc_end()
}

public refresh() {
    new players[32], num
    get_players(players, num, "ach")   // alive humans
    if (!num) return

    new on_text[256], off_text[256], lon = 0, loff = 0, n_on = 0, n_off = 0
    for (new i = 0; i < LINES; i++) {
        new bool:on = !g_Cvar[i][0] || (g_pCvar[i] && get_pcvar_num(g_pCvar[i]) != 0)
        new line[96]
        formatex(line, charsmax(line), "%s %s", g_Label[i], g_Keys[i])
        // the line goes into its color's message; the other message gets an empty line
        lon  += formatex(on_text[lon],   charsmax(on_text) - lon,   "%s^n", on ? line : " ")
        loff += formatex(off_text[loff], charsmax(off_text) - loff, "%s^n", on ? " " : line)
        if (on) n_on++; else n_off++
    }

    new Float:y = get_pcvar_float(g_pColY)
    for (new j = 0; j < num; j++) {
        new id = players[j]
        // empty lines to skip over the stats box, plus one gap line if the box isn't empty
        new pad[128], plen = 0, skip = stats_lines(id)
        if (skip > 0) skip++
        for (new k = 0; k < skip && plen < charsmax(pad) - 2; k++) plen += formatex(pad[plen], charsmax(pad) - plen, " ^n")
        if (n_on) {
            set_hudmessage(0, 220, 0, HUD_COL_X, y, 0, 0.0, HOLD, 0.0, 0.0, CH_ON)
            show_hudmessage(id, "%s%s", pad, on_text)
        }
        if (n_off) {
            set_hudmessage(230, 40, 40, HUD_COL_X, y, 0, 0.0, HOLD, 0.0, 0.0, CH_OFF)
            show_hudmessage(id, "%s%s", pad, off_text)
        }
    }
}
