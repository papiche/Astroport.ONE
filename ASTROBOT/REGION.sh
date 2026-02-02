#!/bin/bash
################################################################################
# ASTROBOT REGION – G1 value opportunities per region (1° zone)
# Triggered by REGION key in NOSTR.UMAP.refresh.sh.
# Fetches Ğchange offers around region center and uses question.py (Ollama)
# to identify value-creation opportunities.
################################################################################

set -euo pipefail

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
IA_PATH="${MY_PATH}/../IA"
REGION_ID="${1:-}"

if [[ -z "$REGION_ID" ]]; then
    echo "Usage: $0 _<rlat>_<rlon>" >&2
    exit 1
fi

# Parse region id: _43_1 -> rlat=43, rlon=1
rlat=$(echo "$REGION_ID" | cut -d'_' -f2)
rlon=$(echo "$REGION_ID" | cut -d'_' -f3)

# Region 1° zone center (e.g. 43 -> 43.5, 1 -> 1.5)
center_lat=$(awk "BEGIN { printf \"%.2f\", $rlat + 0.5 }" 2>/dev/null || echo "${rlat}.50")
center_lon=$(awk "BEGIN { printf \"%.2f\", $rlon + 0.5 }" 2>/dev/null || echo "${rlon}.50")

[[ ! -x "${IA_PATH}/g1_opportunities.py" ]] && [[ ! -f "${IA_PATH}/g1_opportunities.py" ]] && exit 0
[[ ! -f "${IA_PATH}/question.py" ]] && exit 0

# Ensure Ollama is reachable on localhost:11434
[[ -x "${IA_PATH}/ollama.me.sh" ]] && "${IA_PATH}/ollama.me.sh" 2>/dev/null || true

python3 "${IA_PATH}/g1_opportunities.py" \
    --lat "$center_lat" \
    --lon "$center_lon" \
    --distance-km 80 \
    --max 300 \
    --model "gemma3:12b" \
    2>/dev/null || true
