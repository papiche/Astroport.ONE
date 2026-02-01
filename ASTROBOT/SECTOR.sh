#!/bin/bash
################################################################################
# ASTROBOT SECTOR – G1 value opportunities per sector
# Triggered by SECTOR key in NOSTR.UMAP.refresh.sh.
# Fetches Ğchange offers around sector center and uses question.py (Ollama)
# to identify value-creation opportunities.
################################################################################

set -euo pipefail

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
IA_PATH="${MY_PATH}/../IA"
SECTOR_ID="${1:-}"

if [[ -z "$SECTOR_ID" ]]; then
    echo "Usage: $0 _<slat>_<slon>" >&2
    exit 1
fi

# Parse sector id: _43.6_1.4 -> slat=43.6, slon=1.4
slat=$(echo "$SECTOR_ID" | cut -d'_' -f2)
slon=$(echo "$SECTOR_ID" | cut -d'_' -f3)

# Sector 0.1° zone center (e.g. 43.6 -> 43.65, 1.4 -> 1.45)
center_lat=$(awk "BEGIN { printf \"%.2f\", $slat + 0.05 }" 2>/dev/null || echo "${slat}")
center_lon=$(awk "BEGIN { printf \"%.2f\", $slon + 0.05 }" 2>/dev/null || echo "${slon}")

[[ ! -x "${IA_PATH}/g1_opportunities.py" ]] && [[ ! -f "${IA_PATH}/g1_opportunities.py" ]] && exit 0
[[ ! -f "${IA_PATH}/question.py" ]] && exit 0

# Ensure Ollama is reachable on localhost:11434 (local, SSH tunnel, or P2P)
[[ -x "${IA_PATH}/ollama.me.sh" ]] && "${IA_PATH}/ollama.me.sh" 2>/dev/null || true

python3 "${IA_PATH}/g1_opportunities.py" \
    --lat "$center_lat" \
    --lon "$center_lon" \
    --distance-km 50 \
    --max 200 \
    --model "gemma3:12b" \
    2>/dev/null || true
