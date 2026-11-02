#!/bin/bash
########################################################################
# gpu_guard.sh — Détecte la disparition du GPU NVIDIA (Xid 79, "fallen off
# the bus") et redémarre la machine, avec garde-fous anti-boucle.
#
# Usage : gpu_guard.sh [--dry-run]     (appelé par le watchdog de _12345.sh)
#
# Détection : nvidia-smi échoue/timeout 2 fois (30 s d'écart), alors que le
#             GPU a déjà été vu fonctionnel (marqueur ~/.zen/log/gpu_expected).
# Garde-fous : uptime >= 5 min ; délai ENTRE reboots croissant (5 min, puis x2
#             par reboot des dernières 24 h : 5, 10, 20, 40, 80, 160 min, plafond 6 h).
#             On reboote TOUJOURS, plus lentement si le GPU retombe en boucle.
# Alerte    : mail au Capitaine à chaque disparition (max 1 / 30 min), envoyé
#             AVANT le reboot ; il dit si le reboot est immédiat ou différé.
# Historique : ~/.zen/log/gpu_guard.history (epoch des reboots déclenchés).
# Reboot via `sudo systemctl reboot -ff`, puis SysRq b si le noyau reste figé dans le pilote nvidia
# (systemctl et tee /proc/sysrq-trigger sont NOPASSWD, cf. install_sudoers.sh).
########################################################################
DRY=0; [[ "$1" == "--dry-run" ]] && DRY=1
LOGDIR="$HOME/.zen/log"; mkdir -p "$LOGDIR"
EXPECTED="$LOGDIR/gpu_expected"
HISTORY="$LOGDIR/gpu_guard.history"
MIN_UPTIME=300; MIN_GAP=300; MAX_GAP=21600; ALERT_GAP=1800

say() { echo "$(date '+%F %T') gpu_guard: $*" | tee -a "$LOGDIR/gpu_guard.log"; logger -t gpu_guard -p user.crit "$*"; }
gpu_ok() { timeout 10 nvidia-smi -L >/dev/null 2>&1; }

# alert_captain SUJET DÉTAIL — mail au Capitaine (rate-limité), synchrone (borné à 60 s)
alert_captain() {
    local lock="$LOGDIR/.gpu_alert_last" t
    [[ -e "$lock" && $(( $(date +%s) - $(stat -c %Y "$lock") )) -lt $ALERT_GAP ]] && return 0
    touch "$lock"
    # shellcheck disable=SC1090
    [[ -z "$CAPTAINEMAIL" ]] && . "$HOME/.zen/Astroport.ONE/tools/my.sh" >/dev/null 2>&1
    [[ -z "$CAPTAINEMAIL" ]] && { say "alerte Capitaine impossible : CAPTAINEMAIL inconnu"; return 1; }
    t=$(mktemp /tmp/gpu_alert_XXXXXX.html)
    {
        echo "<h2>🚨 GPU NVIDIA disparu — $(hostname)</h2>"
        echo "<p><strong>Date :</strong> $(date '+%F %T') — uptime ${up}s</p>"
        echo "<p><strong>Reboots GPU sur 24 h :</strong> ${n24:-?}</p>"
        printf '<p>%s</p>' "$2"
        echo "<pre style=\"background:#fff3cd;padding:1em;\">$(printf '%s' "$dmesg_hint" | sed 's/&/\&amp;/g;s/</\&lt;/g')</pre>"
        echo "<p>Si cela se répète : câble/alimentation PCIe, slot, température (<code>~/.zen/log/gpu_guard.log</code>).</p>"
    } > "$t"
    timeout 60 bash "$HOME/.zen/Astroport.ONE/tools/mailjet.sh" --template "$0" --expire 48h \
        "$CAPTAINEMAIL" "$t" "🚨 GPU disparu — $(hostname) : $1" >/dev/null 2>&1 \
        || say "envoi du mail au Capitaine échoué"
    rm -f "$t"
}

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
n24=$(awk -v t=$(( now - 86400 )) '$1>t' "$HISTORY" 2>/dev/null | wc -l)
# Délai exigé : 30 min x 2^n24 (n24 = reboots GPU des dernières 24 h), plafonné
gap=$(( MIN_GAP << (n24 > 6 ? 6 : n24) )); (( gap > MAX_GAP )) && gap=$MAX_GAP
if (( now - last < gap )); then
    wait_s=$(( gap - (now - last) ))
    say "REBOOT DIFFÉRÉ : dernier il y a $(( (now-last)/60 )) min, délai exigé $(( gap/60 )) min (${n24} sur 24 h) — prochain vers $(date -d "+${wait_s} sec" +%T)"
    alert_captain "reboot différé" "Le GPU est tombé de nouveau (${n24} reboots en 24 h). Reboot automatique différé à environ $(date -d "+${wait_s} sec" +%T) (délai croissant). Un arrêt complet avec coupure secteur est préférable."
    exit 1
fi
alert_captain "reboot en cours" "Le GPU a disparu : reboot forcé immédiat (${n24} reboots en 24 h, délai suivant : $(( (gap<<1 > MAX_GAP ? MAX_GAP : gap<<1)/60 )) min)."

echo "$now" >> "$HISTORY"
if (( DRY )); then say "[dry-run] reboot déclenché"; exit 0; fi
say "REBOOT FORCÉ (${n24} sur 24 h, délai appliqué $(( gap/60 )) min)"
sync
# Reboot FORCÉ (-ff = reboot(2) direct, sans arrêt des services) : avec un GPU mort, les
# processus bloqués dans le pilote nvidia (état D, drm_release) empêchent le reboot graceful
# d'aboutir (2026-10-28 : machine figée 50 min, remise sous tension à la main).
# Nécessite le même droit sudo NOPASSWD que `systemctl reboot` (install_sudoers.sh).
# 2026-11-01 : même le -ff reste bloqué (reboot(2) → device_shutdown → pilote nvidia, état D).
# Filet : si la machine tourne encore 45 s après, SysRq s (sync) u (remount ro) b (reboot immédiat,
# sans arrêt des périphériques). Droit sudo : /etc/sudoers.d/sysrq-trigger (install_sudoers.sh).
# 2026-11-02 : `sudo -n timeout 20 systemctl …` échouait (« a password is required ») car sudoers
# n'autorise que /usr/bin/systemctl, pas `timeout` : le timeout passe donc AVANT sudo.
# Si sudo refuse (code ≠ 0 immédiat), inutile d'attendre 45 s : SysRq tout de suite.
timeout 20 sudo -n /usr/bin/systemctl reboot --force --force &
_rb=$!
for _i in $(seq 1 45); do
    sleep 1
    if ! kill -0 "$_rb" 2>/dev/null; then
        wait "$_rb"; _rc=$?
        (( _rc != 0 )) && say "systemctl reboot -ff a échoué (code $_rc) : SysRq sans attendre"
        break
    fi
done
say "reboot -ff sans effet (ou refusé) : SysRq s,u,b"
# SysRq doit être actif (kernel.sysrq=1, posé par install_sudoers.sh) ; sinon on le dit.
[[ "$(cat /proc/sys/kernel/sysrq 2>/dev/null)" == "0" ]] && say "⚠️ kernel.sysrq=0 : SysRq ignoré — voir install_sudoers.sh"
for k in s u b; do echo $k | sudo -n /usr/bin/tee /proc/sysrq-trigger >/dev/null || say "❌ sudo tee sysrq-trigger refusé ($k)"; sleep 3; done
