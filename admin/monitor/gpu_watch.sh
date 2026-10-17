#!/bin/bash
########################################################################
# gpu_watch.sh — Journalise puissance / température / charge du GPU NVIDIA
# toutes les N secondes, pour diagnostiquer les chutes de bus (Xid 79).
#
# Usage : gpu_watch.sh [INTERVAL_SECONDES=5]
# Log   : ~/.zen/tmp/gpu_watch.csv (rotation à 20 Mo)
#
# Chaque ligne est écrite puis flushée : la dernière ligne avant un crash
# montre l'état du GPU juste avant sa disparition.
########################################################################
INTERVAL="${1:-5}"
LOG="$HOME/.zen/tmp/gpu_watch.csv"
mkdir -p "$(dirname "$LOG")"

QUERY="timestamp,power.draw,power.limit,temperature.gpu,temperature.memory,utilization.gpu,memory.used,clocks.sm,clocks.max.sm,pcie.link.gen.current,pcie.link.width.current,clocks_throttle_reasons.active"
[[ -s "$LOG" ]] || echo "$QUERY" > "$LOG"

while true; do
    if [[ $(stat -c %s "$LOG" 2>/dev/null || echo 0) -gt 20971520 ]]; then
        mv -f "$LOG" "${LOG}.1"
        echo "$QUERY" > "$LOG"
    fi
    if out=$(timeout 8 nvidia-smi --query-gpu="$QUERY" --format=csv,noheader,nounits 2>&1); then
        echo "$out" >> "$LOG"
    else
        echo "$(date '+%Y/%m/%d %H:%M:%S.000'),GPU_LOST,$(echo "$out" | head -1 | tr ',' ';')" >> "$LOG"
    fi
    sleep "$INTERVAL"
done
