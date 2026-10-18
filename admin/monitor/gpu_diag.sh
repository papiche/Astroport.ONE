#!/bin/bash
########################################################################
# gpu_diag.sh — Diagnostic progressif du GPU (Xid 79 "fallen off the bus")
#
# CONTEXTE (session du 2026-10-18, RTX 3090, driver 580.178.04, kernel 7.0.0-38) :
#  - Le GPU tombe (Xid 79) à ~110-114 W / 38 °C / ~5 % de charge, juste après
#    le passage P8 -> P2 (210 -> 1695 MHz) au chargement d'un modèle Ollama.
#    Pas de surchauffe, pas de throttling, power limit 280 W, total machine < 200 W.
#  - Reproduit en direct : `question.py ... -m gemma3:12b --ctx 32768`
#    (la même question avec ctx par défaut passe). Le GPU avait déjà tenu 143 W.
#  - Hypothèses : pic transitoire PSU / câble PCIe, intégrité lien PCIe Gen4
#    (riser), bug driver 580 / kernel 7.0. Aggravant : OLLAMA_NUM_PARALLEL=2
#    (n_ctx 65536 => ~12 Go de KV alloués d'un coup).
#  - Déjà proposé : NUM_PARALLEL=1 (à appliquer dans ollama.service),
#    PCIe Gen3 (BIOS), -lgc 210,1400 / -pl 220.
#
# PRINCIPE : chaque étape écrit son nom dans $DIR/last_stage AVANT de
# s'exécuter. Après un crash + reboot, `gpu_diag.sh report` indique quelle
# étape a fait tomber le GPU. La télémétrie 1 s est dans $DIR/dmon.csv.
#
# Usage :
#   gpu_diag.sh baseline            # état, lien PCIe, historique Xid (inoffensif)
#   gpu_diag.sh limits [soft|off]   # soft = -lgc 210,1400 + -pl 220 ; off = reset (sudo)
#   gpu_diag.sh tools               # dcgmi diag -r 2, nvbandwidth (si installés)
#   gpu_diag.sh ollama [STAGE...]   # chargements Ollama par paliers "modele:ctx"
#   gpu_diag.sh burn [SECONDES]     # gpu-burn (si installé) — MONTÉE BRUTALE
#   gpu_diag.sh report              # étape en cours au dernier crash + Xid récents
#
# Ordre conseillé : baseline -> limits soft -> tools -> ollama -> burn,
# puis relancer ollama/burn avec `limits off` pour comparer.
########################################################################
DIR="$HOME/.zen/tmp/gpu_diag"
mkdir -p "$DIR"
QUESTION="Explique en deux phrases ce qu'est IPFS."
QPY="$HOME/.zen/Astroport.ONE/IA/question.py"

# stage = "modele:ctx" (ctx vide = défaut Ollama)
STAGES_DEFAULT=("gemma3:12b:" "gemma3:12b:4096" "gemma3:12b:8192" "gemma3:12b:16384" \
                "gemma3:12b:32768" "qwen2.5-coder:14b:8192" "qwen2.5-coder:14b:32768")

gpu_alive() { timeout 10 nvidia-smi -L >/dev/null 2>&1; }

mark() { echo "$(date '+%F %T') $*" | tee "$DIR/last_stage" >> "$DIR/history.log"; }

start_dmon() {
    nvidia-smi --query-gpu=timestamp,power.draw,temperature.gpu,utilization.gpu,memory.used,clocks.sm,pstate,pcie.link.gen.current,pcie.link.width.current,clocks_throttle_reasons.active \
        --format=csv,noheader,nounits -l 1 >> "$DIR/dmon.csv" 2>&1 &
    DMON_PID=$!
}
stop_dmon() { [[ -n "$DMON_PID" ]] && kill "$DMON_PID" 2>/dev/null; DMON_PID=""; }
peak_power() { awk -F, '{gsub(/ /,"",$2); if($2+0>m)m=$2+0}END{print m+0}' "$DIR/dmon.csv"; }

need_gpu() {
    gpu_alive || { echo "❌ GPU absent (nvidia-smi KO) — reboot nécessaire. Voir: $0 report"; exit 2; }
}

cmd_baseline() {
    need_gpu
    {
      echo "== $(date) =="; uname -r
      nvidia-smi --query-gpu=name,driver_version,vbios_version,memory.total,power.limit,power.default_limit,pcie.link.gen.max,pcie.link.gen.current,pcie.link.width.max,pcie.link.width.current --format=csv
      nvidia-smi -q -d PERFORMANCE,POWER | grep -Ei "slowdown|power cap|limit|draw" | head -20
      echo "-- PCIe (lspci)"
      lspci -vv -s "$(nvidia-smi --query-gpu=pci.bus_id --format=csv,noheader | sed 's/^0000://')" 2>/dev/null | grep -E "LnkCap:|LnkSta:|CESta|UESta"
      echo "-- Ollama env"; systemctl show ollama -p Environment
      echo "-- Xid / AER (journal, 7 jours)"
      journalctl -k --since "7 days ago" --no-pager 2>/dev/null | grep -Ei "Xid|fallen off|AER:.*(error|corrected)" | tail -20
    } | tee "$DIR/baseline_$(date +%F_%H%M).txt"
}

cmd_limits() {
    case "${1:-soft}" in
      soft) sudo nvidia-smi -pm 1; sudo nvidia-smi -lgc 210,1400; sudo nvidia-smi -pl 220 ;;
      off)  sudo nvidia-smi -rgc; sudo nvidia-smi -pl 280 ;;   # 280 = valeur actuelle de la station (défaut carte 350)
      *) echo "limits soft|off"; exit 1 ;;
    esac
    nvidia-smi --query-gpu=power.limit,clocks.max.sm --format=csv
}

cmd_tools() {
    need_gpu; start_dmon
    if command -v dcgmi >/dev/null; then
        mark "tools:dcgmi diag -r 2"
        dcgmi diag -r 2 2>&1 | tee "$DIR/dcgmi_r2.txt"
    else echo "ℹ️ dcgmi absent (apt install datacenter-gpu-manager)"; fi
    if command -v nvbandwidth >/dev/null; then
        mark "tools:nvbandwidth"
        nvbandwidth -t host_to_device_memcpy_ce device_to_host_memcpy_ce 2>&1 | tee "$DIR/nvbandwidth.txt"
    else echo "ℹ️ nvbandwidth absent (github.com/NVIDIA/nvbandwidth)"; fi
    stop_dmon; echo "pic: $(peak_power) W"
}

cmd_ollama() {
    need_gpu
    local stages=("$@"); [[ ${#stages[@]} -eq 0 ]] && stages=("${STAGES_DEFAULT[@]}")
    systemctl show ollama -p Environment | grep -o "NUM_PARALLEL=[0-9]*"
    start_dmon
    for st in "${stages[@]}"; do
        local ctx="${st##*:}" model="${st%:*}"
        # chaque étape repart d'un GPU au repos (P8) : c'est le cas qui plante
        ollama stop "$model" >/dev/null 2>&1
        echo "⏳ attente retour P8 (idle)..."; sleep 20
        mark "ollama model=$model ctx=${ctx:-default}"
        local args=(-m "$model"); [[ -n "$ctx" ]] && args+=(--ctx "$ctx" --max-tokens 128)
        timeout 300 python3 "$QPY" "$QUESTION" "${args[@]}" 2>&1 | tail -3
        if ! gpu_alive; then
            stop_dmon; echo "💥 GPU PERDU à l'étape $st — reboot, puis: $0 report"; exit 3
        fi
        echo "✅ $st ok — pic cumulé $(peak_power) W — VRAM $(nvidia-smi --query-gpu=memory.used --format=csv,noheader)"
        sleep 5
    done
    stop_dmon; echo "Toutes les étapes ollama OK."
}

cmd_burn() {
    need_gpu
    local b; b=$(command -v gpu_burn || command -v gpu-burn) || { echo "ℹ️ gpu-burn absent (github.com/wilicc/gpu-burn)"; exit 1; }
    start_dmon; mark "burn ${1:-60}s"
    "$b" "${1:-60}" 2>&1 | tail -8
    gpu_alive || { stop_dmon; echo "💥 GPU PERDU pendant gpu-burn"; exit 3; }
    stop_dmon; echo "✅ burn ok — pic $(peak_power) W"
}

cmd_report() {
    echo "== Dernière étape lancée :"; cat "$DIR/last_stage" 2>/dev/null || echo "(aucune)"
    echo "== Xid récents :"
    journalctl -k --since "2 days ago" --no-pager 2>/dev/null | grep -E "Xid|fallen off" | cut -c1-200 | tail -15
    echo "== Dernières secondes de télémétrie avant perte :"
    grep -vi "lost" "$DIR/dmon.csv" 2>/dev/null | tail -8 | cut -c12-
    echo "== gpu_watch (5 s) :"; grep -B3 GPU_LOST "$HOME/.zen/tmp/gpu_watch.csv" 2>/dev/null | head -6
    echo "== powerjoular :"; tail -3 /var/lib/powerjoular/power_24h.csv 2>/dev/null
}

case "$1" in
    baseline) cmd_baseline ;;
    limits)   shift; cmd_limits "$@" ;;
    tools)    cmd_tools ;;
    ollama)   shift; cmd_ollama "$@" ;;
    burn)     shift; cmd_burn "$@" ;;
    report)   cmd_report ;;
    *) sed -n '2,31p' "$0"; exit 1 ;;
esac
