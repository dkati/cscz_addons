#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

// Life steal: a player (human or bot) heals by a percentage of the damage they deal to enemies.
//
//   amx_lifesteal_pct  3   percentage of the damage dealt that is healed; 0 = script off
//   amx_lifesteal_x    0.51  position of the "+N" (the crosshair is at 0.50 / 0.50)
//   amx_lifesteal_y    0.51
//   amx_lifesteal_debug 0  1 = explain every hit (damage, heal, or why no heal) in the
//                          bottom-left text area and in the console
//
// Only real damage counts: what the victim actually lost, so overkill (a 400-damage shot into a
// 20 HP enemy) heals for 20, not 400. No healing from team damage or from hurting yourself.
// Health never goes above the player's maximum (100). Fractions are kept, so small hits add up.
//
// The undead script (last_breath) is not touched: healing above 5 HP simply ends its countdown.
//
// Humans see the heal as a green "+3" next to the crosshair for about a second, fading out.
// (Big DHUD text: the 4 normal HUD channels are taken. Hits close together are shown as one sum.)

#define SHOW_DELAY  0.15     // collect hits for this long, then show one number
#define TASK_SHOW   6100

new g_pPct, g_pDebug, g_pX, g_pY
new Float:g_HealthBefore[33]
new Float:g_Carry[33]        // healing fractions not given yet
new g_Pending[33]            // healed HP not shown yet

public plugin_init() {
    register_plugin("Life Steal", "1.4", "Author")
    g_pPct = register_cvar("amx_lifesteal_pct", "3")
    g_pDebug = register_cvar("amx_lifesteal_debug", "0")
    g_pX = register_cvar("amx_lifesteal_x", "0.51")
    g_pY = register_cvar("amx_lifesteal_y", "0.51")
    RegisterHam(Ham_TakeDamage, "player", "fw_takedamage_pre", 0)
    RegisterHam(Ham_TakeDamage, "player", "fw_takedamage_post", 1)
}

// Condition Zero bots are a separate kind of player with their own damage handling, so the
// "player" hook above never sees damage done TO bots. Hook the bot type too, once, as soon as
// the first bot is in the game.
new bool:g_BotsHooked

public client_putinserver(id) {
    if (!g_BotsHooked && is_user_bot(id)) set_task(0.1, "hook_bots", id)
}

public hook_bots(id) {
    if (g_BotsHooked || !is_user_connected(id) || !pev_valid(id)) return
    RegisterHamFromEntity(Ham_TakeDamage, id, "fw_takedamage_pre", 0)
    RegisterHamFromEntity(Ham_TakeDamage, id, "fw_takedamage_post", 1)
    g_BotsHooked = true
}

public client_disconnected(id) {
    g_Carry[id] = 0.0
    g_Pending[id] = 0
    remove_task(id + TASK_SHOW)
}

public fw_takedamage_pre(victim, inflictor, attacker, Float:damage, bits) {
    pev(victim, pev_health, g_HealthBefore[victim])
    return HAM_IGNORED
}

public fw_takedamage_post(victim, inflictor, attacker, Float:damage, bits) {
    if (attacker < 1 || attacker > 32 || attacker == victim) return HAM_IGNORED
    if (!is_user_connected(attacker)) return HAM_IGNORED

    new Float:pct = get_pcvar_float(g_pPct)
    if (pct <= 0.0) { dbg(attacker, "no heal: script off (amx_lifesteal_pct 0)"); return HAM_IGNORED; }
    if (!is_user_alive(attacker)) { dbg(attacker, "no heal: you are dead"); return HAM_IGNORED; }
    if (get_user_team(attacker) == get_user_team(victim)) { dbg(attacker, "no heal: team damage"); return HAM_IGNORED; }

    // the damage that really landed
    new Float:after
    pev(victim, pev_health, after)
    if (after < 0.0) after = 0.0
    new Float:dealt = g_HealthBefore[victim] - after
    if (dealt <= 0.0) { dbg(attacker, "no heal: no damage landed (%.0f -> %.0f)", g_HealthBefore[victim], after); return HAM_IGNORED; }

    new Float:health, Float:maxhealth
    pev(attacker, pev_health, health)
    pev(attacker, pev_max_health, maxhealth)
    if (maxhealth <= 0.0) maxhealth = 100.0
    if (health >= maxhealth) { dbg(attacker, "dealt %.0f, no heal: you are at full health (%.0f)", dealt, health); return HAM_IGNORED; }

    g_Carry[attacker] += dealt * pct / 100.0
    new heal = floatround(g_Carry[attacker], floatround_floor)
    if (heal < 1) { dbg(attacker, "dealt %.0f, %.2f HP saved up (heals at 1)", dealt, g_Carry[attacker]); return HAM_IGNORED; }
    g_Carry[attacker] -= float(heal)
    if (health + float(heal) > maxhealth) heal = floatround(maxhealth - health, floatround_floor)
    if (heal < 1) return HAM_IGNORED

    set_pev(attacker, pev_health, health + float(heal))
    dbg(attacker, "dealt %.0f -> healed +%d (%.0f -> %.0f HP)", dealt, heal, health, health + float(heal))

    if (!is_user_bot(attacker)) {
        g_Pending[attacker] += heal
        if (!task_exists(attacker + TASK_SHOW)) set_task(SHOW_DELAY, "show_heal", attacker + TASK_SHOW)
    }
    return HAM_IGNORED
}

// amx_lifesteal_debug 1: explain every hit by a human in their chat.
dbg(id, const fmt[], any:...) {
    if (!get_pcvar_num(g_pDebug) || is_user_bot(id)) return
    new msg[160]
    vformat(msg, charsmax(msg), fmt, 3)
    client_print(id, print_chat, "[lifesteal] %s", msg)       // bottom-left text area
    client_print(id, print_console, "[lifesteal] %s", msg)    // console (~), easy to copy
}

// Green "+N" just right of and below the crosshair (amx_lifesteal_x/y): visible ~0.5 s, then fades out over 0.5 s.
public show_heal(taskid) {
    new id = taskid - TASK_SHOW
    if (!is_user_connected(id) || g_Pending[id] < 1) return
    set_dhudmessage(40, 255, 40, get_pcvar_float(g_pX), get_pcvar_float(g_pY), 0, 0.0, 0.5, 0.0, 0.5)
    show_dhudmessage(id, "+%d", g_Pending[id])
    g_Pending[id] = 0
}
