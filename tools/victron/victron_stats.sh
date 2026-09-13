#!/bin/bash
########################################################################
# victron_stats.sh
# Solar production stats from the Victron MPPT BLE monitor CSV
# (tools/victron/victron_monitor.py monitor --csv ...)
#
# Mirrors admin/monitor/power_monitor.sh's power-stats convention (same
# persistent-history pattern, consumed the same way by
# RUNTIME/ECONOMY.broadcast.sh), but reads `yield_today` (Wh) directly as
# reported by the Victron regulator instead of integrating instantaneous
# watts: the device already computes it internally and resets it at local
# midnight, so no numerical integration is needed here.
#
# Usage:
#   victron_stats.sh record-daily-history [csv_file] [history_file]
#       Enregistre le Wh produit aujourd'hui dans l'historique persistant.
#   victron_stats.sh solar-stats [history_file] [csv_file]
#       Agrégats JSON (puissance instantanée, Wh jour/mois/total, tension
#       batterie, état de charge) — utilisé par RUNTIME/ECONOMY.broadcast.sh
#   victron_stats.sh publish-cid [history_file] [pointer_file]
#       Épingle l'historique complet sur IPFS et écrit son CID dans un
#       fichier pointeur léger — cf. note "poids de la balise IPNS" ci-dessous.
########################################################################

set -euo pipefail

# Historique quotidien persistant (Wh/jour) — usage LOCAL uniquement, comme
# ~/.zen/game/power_history.json (jamais placé directement sous
# ~/.zen/tmp/$IPFSNODEID/ : ce dossier est ré-ajouté à IPFS en entier à
# chaque publication IPNS, donc tout fichier qui y grossit indéfiniment
# alourdit la balise publiée un peu plus chaque jour). La même remarque vaut
# pour tout log longue durée diffusé par une station Astroport.ONE : on ne
# publie jamais le fichier qui grossit lui-même, seulement son CID (voir
# publish_cid() plus bas), qui pointe vers un objet IPFS épinglé séparément.
VICTRON_HISTORY_FILE="${VICTRON_HISTORY_FILE:-$HOME/.zen/game/victron/victron_history.json}"
VICTRON_CSV="${VICTRON_CSV:-$HOME/.zen/game/victron/readings.csv}"

# IPFSNODEID (même convention de cache que tools/my.sh, sans le sourcer en
# entier) : seulement nécessaire pour le chemin par défaut du fichier
# pointeur (.ipfs), sous ~/.zen/tmp/$IPFSNODEID/ (publié sur /ipns/$IPFSNODEID).
if [[ -z "${IPFSNODEID:-}" ]]; then
    _IPFSID_CACHE="$HOME/.zen/tmp/ipfsnodeid.cache"
    if [[ -s "$_IPFSID_CACHE" ]]; then
        IPFSNODEID=$(cat "$_IPFSID_CACHE")
    else
        IPFSNODEID=$(jq -r '.Identity.PeerID // empty' "$HOME/.ipfs/config" 2>/dev/null)
    fi
fi
VICTRON_CID_POINTER="${VICTRON_CID_POINTER:-$HOME/.zen/tmp/${IPFSNODEID}/VICTRON/victron_history.json.ipfs}"

log_error() { echo "[victron_stats] $*" >&2; }
log_info()  { echo "[victron_stats] $*" >&2; }

record_daily_history() {
    local csv_file="${1:-$VICTRON_CSV}"
    local history_file="${2:-$VICTRON_HISTORY_FILE}"

    if [[ ! -s "$csv_file" ]]; then
        log_error "record_daily_history: CSV introuvable ou vide: $csv_file"
        return 1
    fi

    mkdir -p "$(dirname "$history_file")"
    [[ -s "$history_file" ]] || echo '{"since":null,"days":{}}' > "$history_file"

    local today
    today=$(date +%Y-%m-%d)

    local stats
    stats=$(python3 - "$csv_file" "$today" << 'PYEOF'
import csv, sys
csv_file, today = sys.argv[1], sys.argv[2]
max_yield = 0.0
power_sum = 0.0
n = 0
with open(csv_file, newline="") as f:
    for row in csv.DictReader(f):
        if not row.get("timestamp", "").startswith(today):
            continue
        n += 1
        try:
            max_yield = max(max_yield, float(row.get("yield_today") or 0))
        except ValueError:
            pass
        try:
            power_sum += float(row.get("solar_power") or 0)
        except ValueError:
            pass
avg_w = (power_sum / n) if n else 0.0
print(f"{max_yield:.2f}\t{avg_w:.2f}\t{n}")
PYEOF
    ) || true

    if [[ -z "$stats" ]]; then
        log_error "record_daily_history: erreur de lecture CSV"
        return 1
    fi

    local yield_wh avg_w samples
    IFS=$'\t' read -r yield_wh avg_w samples <<< "$stats"

    if [[ -z "${samples:-}" || "$samples" -lt 1 ]]; then
        log_error "record_daily_history: aucun échantillon pour $today — skip"
        return 1
    fi

    jq --arg day "$today" --argjson yield_wh "$yield_wh" --argjson avg_w "$avg_w" --argjson samples "$samples" \
       '.since = (.since // $day) |
        .days[$day] = {yield_wh: $yield_wh, avg_w: $avg_w, samples: $samples}' \
       "$history_file" > "${history_file}.tmp" 2>/dev/null \
        && mv "${history_file}.tmp" "$history_file" \
        || { log_error "record_daily_history: jq update failed"; rm -f "${history_file}.tmp"; return 1; }

    log_info "Production solaire enregistrée : $today = ${yield_wh} Wh (puissance moy. ${avg_w} W, $samples échantillons)"
}

solar_stats() {
    local history_file="${1:-$VICTRON_HISTORY_FILE}"
    local csv_file="${2:-$VICTRON_CSV}"

    local agg='{"since":null,"today_wh":0,"month_wh":0,"total_wh":0,"days_recorded":0}'
    if [[ -s "$history_file" ]]; then
        agg=$(jq -c --arg today "$(date +%Y-%m-%d)" --arg month "$(date +%Y-%m)" '
            {
                since: .since,
                today_wh: (.days[$today].yield_wh // 0),
                month_wh: ([.days | to_entries[] | select(.key | startswith($month)) | .value.yield_wh] | add // 0),
                total_wh: ([.days[] | .yield_wh] | add // 0),
                days_recorded: (.days | length)
            }' "$history_file" 2>/dev/null) || agg='{"since":null,"today_wh":0,"month_wh":0,"total_wh":0,"days_recorded":0}'
    fi

    local live='{"power_w":0,"battery_v":0,"charge_state":"unknown"}'
    if [[ -s "$csv_file" ]]; then
        live=$(python3 - "$csv_file" << 'PYEOF'
import csv, sys, json
last = None
with open(sys.argv[1], newline="") as f:
    for row in csv.DictReader(f):
        last = row

def num(row, key):
    try:
        return float(row.get(key) or 0)
    except (ValueError, AttributeError):
        return 0.0

if last:
    print(json.dumps({
        "power_w": num(last, "solar_power"),
        "battery_v": num(last, "battery_voltage"),
        "charge_state": last.get("charge_state") or "unknown",
    }))
else:
    print(json.dumps({"power_w": 0, "battery_v": 0, "charge_state": "unknown"}))
PYEOF
        ) || live='{"power_w":0,"battery_v":0,"charge_state":"unknown"}'
    fi

    jq -c -n --argjson agg "$agg" --argjson live "$live" '$agg + $live' 2>/dev/null \
        || echo '{"since":null,"today_wh":0,"month_wh":0,"total_wh":0,"days_recorded":0,"power_w":0,"battery_v":0,"charge_state":"unknown"}'
}

# Épingle l'historique complet sur IPFS et écrit son CID dans un petit
# fichier pointeur — celui-ci (quelques octets, un CID) est ce qu'on place
# sous ~/.zen/tmp/$IPFSNODEID/, pas le fichier qui grossit lui-même.
# Consulter l'historique depuis le swarm : lire le pointeur via
# /ipns/$IPFSNODEID/VICTRON/victron_history.json.ipfs, puis /ipfs/<CID>.
publish_cid() {
    local history_file="${1:-$VICTRON_HISTORY_FILE}"
    local pointer_file="${2:-$VICTRON_CID_POINTER}"

    if [[ ! -s "$history_file" ]]; then
        log_error "publish_cid: historique introuvable ou vide: $history_file"
        return 1
    fi
    if ! command -v ipfs >/dev/null 2>&1; then
        log_error "publish_cid: commande ipfs introuvable"
        return 1
    fi

    # CID de la version précédemment publiée (si connu) : `ipfs add` épingle
    # par défaut, et comme le contenu change chaque jour, chaque appel
    # ajoute un nouveau CID sans jamais libérer le précédent — sans ce
    # désépinglage, l'espace disque local utilisé croît indéfiniment (seul
    # le dernier pointeur importe, cf. note ci-dessus sur le "poids").
    local old_cid=""
    [[ -s "$pointer_file" ]] && old_cid=$(cat "$pointer_file")

    local cid
    cid=$(timeout 30s ipfs add -q "$history_file" 2>/dev/null | tail -1) || true
    if [[ -z "$cid" ]]; then
        log_error "publish_cid: échec de l'ajout IPFS"
        return 1
    fi

    mkdir -p "$(dirname "$pointer_file")"
    echo -n "$cid" > "$pointer_file"
    log_info "Historique solaire épinglé : $cid → $pointer_file"

    if [[ -n "$old_cid" && "$old_cid" != "$cid" ]]; then
        # Pas de -q sur `ipfs pin rm` (contrairement à `ipfs add -q`) : le
        # flag serait rejeté ("unknown option") et l'échec passerait
        # inaperçu derrière `2>/dev/null`.
        if ipfs pin rm "$old_cid" >/dev/null 2>&1; then
            log_info "Ancien CID désépinglé : $old_cid"
        else
            log_error "publish_cid: désépinglage de $old_cid échoué (non bloquant)"
        fi
    fi
}

case "${1:-}" in
    record-daily-history)
        shift
        record_daily_history "$@"
        ;;
    solar-stats)
        shift
        solar_stats "$@"
        ;;
    publish-cid)
        shift
        publish_cid "$@"
        ;;
    *)
        cat << EOF
Victron solar production stats — Astroport.ONE

Usage:
  victron_stats.sh record-daily-history [csv_file] [history_file]
      Enregistre le Wh produit aujourd'hui (max de yield_today) dans
      l'historique persistant local (défaut: $VICTRON_HISTORY_FILE)

  victron_stats.sh solar-stats [history_file] [csv_file]
      Agrégats JSON : puissance instantanée, tension batterie, état de
      charge, Wh jour/mois/total — consommé par RUNTIME/ECONOMY.broadcast.sh

  victron_stats.sh publish-cid [history_file] [pointer_file]
      Épingle l'historique sur IPFS, écrit son CID dans un fichier pointeur
      léger publié sous \$IPFSNODEID (défaut: $VICTRON_CID_POINTER)
EOF
        ;;
esac
