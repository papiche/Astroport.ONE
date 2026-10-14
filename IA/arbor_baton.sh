#!/bin/bash
################################################################################
# arbor_baton.sh — "Bâton de parole" ARBOR entre stations de la constellation.
#
# Portée (décision capitaine 2026-10-14) : gouverne UNIQUEMENT le cycle
# automatique quotidien (arbor_self_improve.py --mine-requests, cron
# 20h12.process.sh). Le déclenchement MANUEL (forge/explore/apply/forge-
# scraper) depuis l'UI capitaine reste toujours disponible sur CHAQUE station,
# bâton ou pas — ce script ne gate que l'automatisme en tâche de fond pour
# éviter que toutes les stations minent le même signal en double.
#
# État partagé (kind 30800, cf. cooperative_config.sh — lisible/écrivable par
# toute station qui connaît $UPLANETNAME, propagation via backfill_
# constellation.sh) :
#   ARBOR_BATON_HOLDER        NODEHEX de la station qui tient le bâton
#   ARBOR_BATON_SINCE         epoch — depuis quand
#   ARBOR_BATON_LAST_RUN      epoch — dernier mine-requests RÉUSSI du holder
#                             (= heartbeat de vivacité)
#   ARBOR_BATON_TIMEOUT_HOURS seuil de vacance (défaut 72h), configurable
#                             via ⚙️ NODE / ARBOR comme les autres seuils
#
# Vacance : si holder vide OU (now - max(since,last_run)) > timeout → le
# bâton est considéré abandonné. N'IMPORTE QUELLE station ÉLIGIBLE (cf.
# arbor_baton_eligibility.sh) peut alors se l'auto-attribuer à son prochain
# passage de cron — pas besoin d'un humain pour relancer le cycle après une
# panne/extinction prolongée du holder.
#
# Passation volontaire : SEUL le holder courant peut passer la main
# (capitaine-only côté HTTP, cf. node_admin.py::post_arbor_baton_handoff) —
# écrit directement le nouvel état (n'importe quelle station peut écrire la
# config coopérative partagée) PUIS envoie un DM NIP-44 de courtoisie au
# destinataire (canal "arbor_baton", bro_dm_daemon.sh) — ce DM n'est QUE une
# notification, l'état est déjà posé au moment de l'envoi.
#
# Usage :
#   arbor_baton.sh status                       → JSON, lecture seule
#   arbor_baton.sh check-and-claim               → exit 0 = go (lance mine-requests),
#                                                   exit 1 = skip (pas le tour de cette station)
#   arbor_baton.sh mark-run                      → à appeler après un mine-requests réussi
#   arbor_baton.sh handoff <target_hex>          → capitaine courant → cible
################################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
# shellcheck source=/dev/null
[[ -z "$UPLANETNAME" ]] && source "${MY_PATH}/../tools/my.sh" 2>/dev/null
# shellcheck source=/dev/null
source "${MY_PATH}/../tools/cooperative_config.sh" 2>/dev/null

ELIGIBILITY_SH="${MY_PATH}/arbor_baton_eligibility.sh"
INTERCOM="${MY_PATH}/../tools/nostr_node_intercom.py"
DEFAULT_TIMEOUT_HOURS=72

_own_hex() {
    local secret="$HOME/.zen/game/secret.nostr"
    [[ -f "$secret" ]] || { echo ""; return; }
    grep -o 'HEX=[0-9a-f]\{64\}' "$secret" | head -1 | cut -d= -f2
}

_own_nsec() {
    local secret="$HOME/.zen/game/secret.nostr"
    [[ -f "$secret" ]] || { echo ""; return; }
    grep -o 'NSEC=nsec1[a-z0-9]\+' "$secret" | head -1 | cut -d= -f2
}

_timeout_hours() {
    local v; v=$(coop_config_get "ARBOR_BATON_TIMEOUT_HOURS" 2>/dev/null)
    [[ "$v" =~ ^[0-9]+$ ]] && echo "$v" || echo "$DEFAULT_TIMEOUT_HOURS"
}

_local_eligible() {
    [[ -x "$ELIGIBILITY_SH" ]] || { echo "false"; return; }
    "$ELIGIBILITY_SH" status 2>/dev/null | jq -r '.eligible // false' 2>/dev/null
}

# JSON d'état courant, lecture seule — utilisé par status ET check-and-claim.
_state_json() {
    local holder since last_run timeout_h now vacant is_holder
    holder=$(coop_config_get "ARBOR_BATON_HOLDER" 2>/dev/null)
    since=$(coop_config_get "ARBOR_BATON_SINCE" 2>/dev/null)
    last_run=$(coop_config_get "ARBOR_BATON_LAST_RUN" 2>/dev/null)
    timeout_h=$(_timeout_hours)
    now=$(date +%s)
    [[ "$since" =~ ^[0-9]+$ ]] || since=0
    [[ "$last_run" =~ ^[0-9]+$ ]] || last_run=0
    local reference=$(( since > last_run ? since : last_run ))
    vacant="false"
    if [[ -z "$holder" ]] || [[ $(( now - reference )) -gt $(( timeout_h * 3600 )) ]]; then
        vacant="true"
    fi
    local own; own=$(_own_hex)
    is_holder="false"
    [[ -n "$own" && "$own" == "$holder" ]] && is_holder="true"
    jq -n \
        --arg holder "$holder" --argjson since "$since" --argjson last_run "$last_run" \
        --argjson timeout_h "$timeout_h" --argjson vacant "$vacant" --argjson is_holder "$is_holder" \
        --arg own "$own" \
        '{holder: $holder, since: $since, last_run: $last_run, timeout_hours: $timeout_h,
          vacant: $vacant, is_local_holder: $is_holder, local_hex: $own}'
}

cmd_status() {
    local state eligibility
    state=$(_state_json)
    eligibility=$("$ELIGIBILITY_SH" status 2>/dev/null)
    [[ -z "$eligibility" ]] && eligibility='{"eligible": false, "reason": "eligibility_script_unavailable"}'
    jq -n --argjson state "$state" --argjson elig "$eligibility" '$state + {local_eligibility: $elig}'
}

# Pour le cron 20h12 : exit 0 = cette station doit lancer mine-requests
# maintenant, exit 1 = ce n'est pas son tour (log explicite sur stderr).
cmd_check_and_claim() {
    local state own holder vacant eligible
    state=$(_state_json)
    own=$(echo "$state" | jq -r '.local_hex')
    holder=$(echo "$state" | jq -r '.holder')
    vacant=$(echo "$state" | jq -r '.vacant')

    if [[ -n "$own" && "$own" == "$holder" ]]; then
        echo "arbor_baton: cette station détient déjà le bâton — mine-requests autorisé." >&2
        return 0
    fi

    if [[ "$vacant" != "true" ]]; then
        echo "arbor_baton: bâton détenu par ${holder:0:12}… (non vacant) — skip." >&2
        return 1
    fi

    eligible=$(_local_eligible)
    if [[ "$eligible" != "true" ]]; then
        echo "arbor_baton: bâton vacant mais cette station n'est pas éligible — skip." >&2
        return 1
    fi

    echo "arbor_baton: bâton vacant, auto-attribution à cette station (${own:0:12}…)." >&2
    local now; now=$(date +%s)
    printf 'ARBOR_BATON_HOLDER\t%s\nARBOR_BATON_SINCE\t%s\n' "$own" "$now" | coop_config_set_batch
    return 0
}

cmd_mark_run() {
    local own holder
    own=$(_own_hex)
    holder=$(coop_config_get "ARBOR_BATON_HOLDER" 2>/dev/null)
    if [[ -z "$own" || "$own" != "$holder" ]]; then
        echo "arbor_baton: mark-run ignoré — cette station ne tient pas le bâton." >&2
        return 1
    fi
    printf 'ARBOR_BATON_LAST_RUN\t%s\n' "$(date +%s)" | coop_config_set_batch
}

# Vérifie que target_hex correspond à une station connue du swarm ET qu'elle
# s'est déclarée éligible (capacities.arbor_eligible côté SON 12345.json) —
# même principe de défense en profondeur que arbor_trigger::forge-scraper
# côté UPassport : jamais un hex arbitraire fourni sans vérification croisée.
_target_known_and_eligible() {
    local target="$1" f
    for f in "$HOME"/.zen/tmp/swarm/*/12345.json; do
        [[ -f "$f" ]] || continue
        if [[ "$(jq -r '.NODEHEX // empty' "$f" 2>/dev/null)" == "$target" ]]; then
            [[ "$(jq -r '.capacities.arbor_eligible // false' "$f" 2>/dev/null)" == "true" ]] && return 0
            return 1
        fi
    done
    return 1
}

cmd_handoff() {
    local target="$1"
    if [[ -z "$target" ]]; then
        echo '{"ok": false, "error": "target_hex manquant"}'
        return 1
    fi
    local own holder
    own=$(_own_hex)
    holder=$(coop_config_get "ARBOR_BATON_HOLDER" 2>/dev/null)
    if [[ -z "$own" || "$own" != "$holder" ]]; then
        jq -n --arg h "$holder" '{ok: false, error: "seule la station qui tient le bâton peut le passer", holder: $h}'
        return 1
    fi
    if ! _target_known_and_eligible "$target"; then
        jq -n '{ok: false, error: "station cible inconnue du swarm ou non éligible"}'
        return 1
    fi

    local now; now=$(date +%s)
    printf 'ARBOR_BATON_HOLDER\t%s\nARBOR_BATON_SINCE\t%s\n' "$target" "$now" | coop_config_set_batch
    if [[ $? -ne 0 ]]; then
        jq -n '{ok: false, error: "échec écriture configuration coopérative"}'
        return 1
    fi

    # DM de courtoisie — best-effort, l'état est déjà posé même si ça échoue
    # (station cible éteinte, relay injoignable...).
    local nsec; nsec=$(_own_nsec)
    if [[ -n "$nsec" && -x "$INTERCOM" ]]; then
        local payload; payload=$(jq -nc --arg from "$own" --argjson since "$now" \
            '{action: "offer", from_hex: $from, since: $since}')
        echo "$nsec" | python3 "$INTERCOM" send --nsec-stdin --to "$target" \
            --channel arbor_baton --payload "$payload" --ttl 86400 \
            --relays wss://relay.copylaradio.com &>/dev/null &
    fi

    jq -n --arg target "$target" --argjson since "$now" '{ok: true, holder: $target, since: $since}'
}

case "${1:-status}" in
    status)
        cmd_status
        ;;
    check-and-claim)
        cmd_check_and_claim
        ;;
    mark-run)
        cmd_mark_run
        ;;
    handoff)
        cmd_handoff "$2"
        ;;
    *)
        echo "Usage: $0 {status|check-and-claim|mark-run|handoff <target_hex>}" >&2
        exit 2
        ;;
esac
