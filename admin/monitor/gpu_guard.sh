#!/bin/bash
########################################################################
# gpu_guard.sh — Détecte la disparition du GPU NVIDIA (Xid 79, "fallen off
# the bus") et redémarre la machine, avec garde-fous anti-boucle.
#
# Usage : gpu_guard.sh [--dry-run]     (appelé par le watchdog de _12345.sh)
#
# Détection : nvidia-smi échoue/timeout 2 fois (30 s d'écart), alors que le
#             GPU a déjà été vu fonctionnel (marqueur ~/.zen/log/gpu_expected).
# Garde-fous : uptime >= 10 min, >= 30 min entre deux reboots, max 2 reboots
#             par 24 h. Au-delà : pas de reboot, alerte dans le journal
#             (le GPU est alors probablement mort : intervention humaine).
# Historique : ~/.zen/log/gpu_guard.history (epoch des reboots déclenchés).
# Reboot via `sudo systemctl reboot -ff` (forcé : un reboot graceful se bloque sur un GPU mort ;
# systemctl est NOPASSWD, cf. install_sudoers.sh).
########################################################################
DRY=0; [[ "$1" == "--dry-run" ]] && DRY=1
LOGDIR="$HOME/.zen/log"; mkdir -p "$LOGDIR"
EXPECTED="$LOGDIR/gpu_expected"
HISTORY="$LOGDIR/gpu_guard.history"
MIN_UPTIME=600; MIN_GAP=1800; MAX_24H=2

say() { echo "$(date '+%F %T') gpu_guard: $*" | tee -a "$LOGDIR/gpu_guard.log"; logger -t gpu_guard -p user.crit "$*"; }
gpu_ok() { timeout 10 nvidia-smi -L >/dev/null 2>&1; }

command -v nvidia-smi >/dev/null || exit 0

if gpu_ok; then
    touch "$EXPECTED"
    # Reboot précédent récent + GPU revenu → trace de la récupération
    last=$(tail -1 "$HISTORY" 2>/dev/null)
    [[ -n "$last" && $(( $(date +%s) - last )) -lt 3600 && ! -e "$LOGDIR/.gpu_recovered_$last" ]] \
        && { say "GPU de retour après reboot de $(date -d @"$last" '+%F %T')"; touch "$LOGDIR/.gpu_recovered_$last"; }
    exit 0
fi

# GPU jamais vu sur cette machine → rien à garder
[[ -e "$EXPECTED" ]] || exit 0

# Confirmation : éviter un faux positif transitoire (driver occupé)
sleep 30
gpu_ok && exit 0

now=$(date +%s)
up=$(cut -d. -f1 /proc/uptime)
dmesg_hint=$(dmesg 2>/dev/null | grep -iE "NVRM: Xid.*(79|62)|fallen off the bus" | tail -1)
say "GPU DISPARU (uptime ${up}s) ${dmesg_hint}"

if (( up < MIN_UPTIME )); then
    say "reboot différé : uptime < ${MIN_UPTIME}s (démarrage en cours ?)"; exit 1
fi
last=$(tail -1 "$HISTORY" 2>/dev/null); last=${last:-0}
if (( now - last < MIN_GAP )); then
    say "PAS DE REBOOT : dernier reboot il y a $(( (now-last)/60 )) min (< $((MIN_GAP/60)))"; exit 1
fi
n24=$(awk -v t=$(( now - 86400 )) '$1>t' "$HISTORY" 2>/dev/null | wc -l)
if (( n24 >= MAX_24H )); then
    say "ABANDON : ${n24} reboots GPU en 24 h (max ${MAX_24H}) — GPU probablement défaillant, intervention requise"; exit 1
fi

echo "$now" >> "$HISTORY"
if (( DRY )); then say "[dry-run] reboot déclenché"; exit 0; fi
say "REBOOT FORCÉ (${n24}/${MAX_24H} sur 24 h)"
sync
# Reboot FORCÉ (-ff = reboot(2) direct, sans arrêt des services) : avec un GPU mort, les
# processus bloqués dans le pilote nvidia (état D, drm_release) empêchent le reboot graceful
# d'aboutir (2026-10-28 : machine figée 50 min, remise sous tension à la main).
# Nécessite le même droit sudo NOPASSWD que `systemctl reboot` (install_sudoers.sh).
sudo -n systemctl reboot --force --force || sudo -n systemctl reboot
