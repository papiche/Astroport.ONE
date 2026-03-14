#!/bin/bash
################################################################################
# ASTROBOT SECTOR – G1 value opportunities per zone
# Triggered at UMAP or SECTOR level in NOSTR.UMAP.refresh.sh.
# Fetches Ğchange offers + Leboncoin donations around zone center
# and uses question.py (Ollama) to identify value-creation opportunities.
#
# Usage: $0 <lat> <lon> [distance_km]
#   lat/lon: zone center coordinates
#   distance_km: search radius (default: 50)
################################################################################

set -o pipefail

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
IA_PATH="${MY_PATH}/../IA"

center_lat="${1:-}"
center_lon="${2:-}"
distance_km="${3:-50}"

if [[ -z "$center_lat" || -z "$center_lon" ]]; then
    echo "Usage: $0 <lat> <lon> [distance_km]" >&2
    exit 1
fi

[[ ! -f "${IA_PATH}/g1_opportunities.py" ]] && exit 0
[[ ! -f "${IA_PATH}/question.py" ]] && exit 0

# Ensure Ollama is reachable on localhost:11434 (local, SSH tunnel, or P2P)
[[ -x "${IA_PATH}/ollama.me.sh" ]] && "${IA_PATH}/ollama.me.sh" >/dev/null 2>&1 || true

# Detect captain's Leboncoin cookie for donation scraping
COOKIE_ARGS=()
CAPTAINEMAIL="${CAPTAINEMAIL:-}"
if [[ -n "$CAPTAINEMAIL" ]]; then
    LBC_COOKIE="$HOME/.zen/game/nostr/${CAPTAINEMAIL}/.leboncoin.fr.cookie"
    [[ -f "$LBC_COOKIE" ]] && COOKIE_ARGS=("--cookie" "$LBC_COOKIE")
fi

python3 "${IA_PATH}/g1_opportunities.py" \
    --lat "$center_lat" \
    --lon "$center_lon" \
    --distance-km "$distance_km" \
    --max 200 \
    --model "gemma3:12b" \
    "${COOKIE_ARGS[@]}" \
    2>/dev/null || true
