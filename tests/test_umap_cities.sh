#!/bin/bash
################################################################################
# test_umap_cities.sh — Activate UMAPs on major French cities
#
# Creates UMAP identities for city centers, fetches G1+Leboncoin opportunities,
# and publishes results as kind 30023 blog articles on each UMAP's NOSTR identity.
#
# This populates the UPlanet base with real geographic content.
#
# Usage:
#   ./tests/test_umap_cities.sh              # All cities
#   ./tests/test_umap_cities.sh paris lyon   # Specific cities
#   ./tests/test_umap_cities.sh --dry-run    # Show what would be done
#   ./tests/test_umap_cities.sh --list       # List available cities
################################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

# Source environment (my.sh may fail on unset vars, so relax first)
[[ ! -s ~/.zen/Astroport.ONE/tools/my.sh ]] && echo "ERROR: Astroport.ONE is missing !!" >&2 && exit 1
source ~/.zen/Astroport.ONE/tools/my.sh

# Strict mode after sourcing my.sh
set -eo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

################################################################################
# FRENCH CITIES — UMAP coordinates (0.01° precision, city center)
################################################################################
# Format: "name:LAT:LON"
# Coordinates rounded to 0.01° (UMAP grid) to match the southwest corner
# of the 0.01° cell containing each city center.
CITIES=(
    "paris:48.85:2.34"
    "marseille:43.29:5.37"
    "lyon:45.76:4.83"
    "toulouse:43.60:1.44"
    "nice:43.70:7.26"
    "nantes:47.21:-1.55"
    "montpellier:43.61:3.87"
    "strasbourg:48.57:7.75"
    "bordeaux:44.83:-0.57"
    "lille:50.63:3.06"
    "rennes:48.11:-1.67"
    "grenoble:45.18:5.72"
    "rouen:49.44:1.09"
    "toulon:43.12:5.92"
    "clermont:45.77:3.08"
    "dijon:47.32:5.04"
    "angers:47.47:-0.55"
    "brest:48.39:-4.48"
    "perpignan:42.69:2.89"
    "pau:43.29:-0.37"
)

################################################################################
# Functions
################################################################################

list_cities() {
    echo -e "${CYAN}=== Available cities ===${NC}"
    for entry in "${CITIES[@]}"; do
        IFS=':' read -r name lat lon <<< "$entry"
        echo -e "  ${GREEN}${name}${NC}  →  ${lat}, ${lon}"
    done
}

log_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

log_ok() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_err() {
    echo -e "${RED}❌ $1${NC}"
}

# Create UMAP directory and HEX file (same as NODE.refresh.sh)
setup_umap_directory() {
    local lat=$1 lon=$2
    local umap_dir="$HOME/.zen/game/nostr/UMAP_${lat}_${lon}"

    # Generate NOSTR keys for this UMAP
    local npub
    npub=$("$HOME/.zen/Astroport.ONE/tools/keygen" -t nostr "${UPLANETNAME}${lat}" "${UPLANETNAME}${lon}")
    local hex
    hex=$("$HOME/.zen/Astroport.ONE/tools/nostr2hex.py" "$npub" 2>/dev/null)

    if [[ -z "$hex" ]]; then
        log_err "Failed to generate NOSTR keys for ${lat},${lon}"
        return 1
    fi

    mkdir -p "$umap_dir"
    echo "$hex" > "$umap_dir/HEX"
    echo "$hex"
}

# Fetch opportunities and publish as kind 30023
publish_umap_opportunities() {
    local name=$1 lat=$2 lon=$3 hex=$4
    local distance_km=${5:-20}

    local slat="${lat::-1}"
    local slon="${lon::-1}"
    local rlat
    rlat=$(echo "$lat" | cut -d '.' -f 1)
    local rlon
    rlon=$(echo "$lon" | cut -d '.' -f 1)

    # Create tmp path (same structure as NOSTR.UMAP.refresh.sh)
    local umappath="$HOME/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${rlat}_${rlon}/_${slat}_${slon}/_${lat}_${lon}"
    mkdir -p "$umappath"

    # Run SECTOR.sh (g1_opportunities + leboncoin)
    local opp_result=""
    local sector_script="$HOME/.zen/Astroport.ONE/ASTROBOT/SECTOR.sh"
    if [[ -f "$sector_script" ]]; then
        log_step "Fetching G1 + Leboncoin for ${name} (${lat}, ${lon}, ${distance_km}km)..."
        set +e
        opp_result=$(bash "$sector_script" "$lat" "$lon" "$distance_km" 2>/dev/null)
        set -e
    fi

    if [[ -z "$opp_result" ]]; then
        log_warn "${name}: no opportunities found (GChange + Leboncoin empty)"
        return 0
    fi

    # Save locally
    echo "$opp_result" > "${umappath}/g1_opportunities.md"
    log_ok "${name}: $(echo "$opp_result" | wc -l) lines of opportunities"

    # Publish as kind 30023 on UMAP NOSTR identity
    local umapnsec
    umapnsec=$("$HOME/.zen/Astroport.ONE/tools/keygen" -t nostr "${UPLANETNAME}${lat}" "${UPLANETNAME}${lon}" -s 2>/dev/null)
    if [[ -z "$umapnsec" ]]; then
        log_err "${name}: failed to generate NSEC"
        return 1
    fi

    local IA_PATH="$HOME/.zen/Astroport.ONE/IA"
    local title="Économie circulaire – ${name^} (${lat}, ${lon})"
    local d_tag="umap-opportunities-${lat}_${lon}-${TODATE}"
    local published_at
    published_at=$(date +%s)

    # Build content with markdown header
    local content
    content="# ${title}

*Publié le $(date '+%d/%m/%Y') — Zone UMAP ${lat}, ${lon} — Rayon ${distance_km}km*

---

${opp_result}

---
*Généré par [Astroport.ONE](https://github.com/papiche/Astroport.ONE) — Économie circulaire UPlanet*"

    ############################################################################
    # POST-PROCESSING PIPELINE (same as BRO #search)
    ############################################################################

    # 1. Generate summary (2-3 sentences)
    local article_summary=""
    log_step "${name}: generating summary..."
    article_summary=$("$IA_PATH/question.py" --json \
        "Write 2-3 sentences summarizing this article. Language: fr. START DIRECTLY with the summary, no introduction. Article: ${content}" \
        --pubkey "system" 2>/dev/null \
        | jq -r '.answer // .' 2>/dev/null) || true
    article_summary=$(echo "$article_summary" | tr -d '\n' | sed 's/\s\+/ /g' | sed 's/"/\\"/g' | head -c 500)
    [[ -z "$article_summary" ]] && article_summary="Opportunités d'économie circulaire pour ${name^} (${lat},${lon})"
    log_ok "${name}: summary OK"

    # 2. Generate intelligent tags
    local intelligent_tags=""
    log_step "${name}: generating tags..."
    intelligent_tags=$("$IA_PATH/question.py" --json \
        "Output 5-8 hashtags for this article. Format: tag1 tag2 tag3 (space-separated, no # symbol, no explanation). Article: ${content:0:1500}" \
        --pubkey "system" 2>/dev/null \
        | jq -r '.answer // .' 2>/dev/null) || true
    intelligent_tags=$(echo "$intelligent_tags" | sed 's/#//g; s/,//g' | tr -s ' ' | head -c 200)
    log_ok "${name}: tags: ${intelligent_tags}"

    # 3. Generate illustration (ComfyUI if available)
    local illustration_url=""
    if "$IA_PATH/comfyui.me.sh" >/dev/null 2>&1; then
        log_step "${name}: generating illustration..."
        local sd_prompt=""
        sd_prompt=$("$IA_PATH/question.py" --json \
            "Stable Diffusion prompt for: ${article_summary} --- OUTPUT ONLY: visual descriptors in English. NO text/words/emojis/brands. Focus: composition, colors, style, objects." \
            --pubkey "system" 2>/dev/null \
            | jq -r '.answer // .' 2>/dev/null) || true
        sd_prompt=$(echo "$sd_prompt" | sed 's/\s\+/ /g' | head -c 400)
        if [[ -n "$sd_prompt" ]]; then
            mkdir -p "${umappath}/Images"
            illustration_url=$("$IA_PATH/generate_image.sh" "$sd_prompt" "${umappath}/Images" 2>/dev/null) || true
            [[ -n "$illustration_url" ]] && log_ok "${name}: illustration OK"
        fi
    fi

    ############################################################################
    # BUILD NIP-23 TAGS & PUBLISH
    ############################################################################

    # Build intelligent tag array
    local tag_array=""
    for tag in $intelligent_tags; do
        [[ -n "$tag" ]] && tag_array="${tag_array}[\"t\", \"$tag\"],"
    done
    tag_array="${tag_array%,}"

    local standard_tags='["t","economie-circulaire"],["t","G1opportunities"],["t","UPlanet"],["t","UMAP"]'
    [[ -n "$name" ]] && standard_tags="${standard_tags},[\"t\",\"${name}\"]"
    local all_tags="$standard_tags"
    [[ -n "$tag_array" ]] && all_tags="${standard_tags},${tag_array}"

    # Build complete NIP-23 tags with jq
    local temp_json
    temp_json=$(mktemp)
    if [[ -n "$illustration_url" ]]; then
        jq -n --arg d "$d_tag" --arg title "$title" \
            --arg summary "$article_summary" --arg image "$illustration_url" \
            --arg pub "$published_at" --arg lat "$lat" --arg lon "$lon" \
            --arg g "${lat},${lon}" \
            --argjson extra "[${all_tags}]" \
            '[["d",$d],["title",$title],["summary",$summary],["published_at",$pub],["image",$image],["latitude",$lat],["longitude",$lon],["g",$g],["application","UPlanet"]] + $extra' \
            > "$temp_json"
    else
        jq -n --arg d "$d_tag" --arg title "$title" \
            --arg summary "$article_summary" \
            --arg pub "$published_at" --arg lat "$lat" --arg lon "$lon" \
            --arg g "${lat},${lon}" \
            --argjson extra "[${all_tags}]" \
            '[["d",$d],["title",$title],["summary",$summary],["published_at",$pub],["latitude",$lat],["longitude",$lon],["g",$g],["application","UPlanet"]] + $extra' \
            > "$temp_json"
    fi

    local article_tags
    article_tags=$(cat "$temp_json")
    rm -f "$temp_json"

    # Publish
    local temp_keyfile
    temp_keyfile=$(mktemp)
    echo "NSEC=$umapnsec;" > "$temp_keyfile"

    local send_result
    send_result=$(python3 "$HOME/.zen/Astroport.ONE/tools/nostr_send_note.py" \
        --keyfile "$temp_keyfile" \
        --content "$content" \
        --relays "$myRELAY" \
        --tags "$article_tags" \
        --kind 30023 \
        --json 2>&1) || true
    rm -f "$temp_keyfile"

    local event_id
    event_id=$(echo "$send_result" | jq -r '.event_id // empty' 2>/dev/null)
    if [[ -n "$event_id" ]]; then
        log_ok "${name}: published kind 30023 (event: ${event_id:0:16}...)"
    else
        log_err "${name}: publish failed — $send_result"
    fi
}

################################################################################
# Main
################################################################################

DRY_RUN=false
ALL_CITIES=false
SELECTED=()

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --dry-run|-n)
            DRY_RUN=true
            ;;
        --all|-a)
            ALL_CITIES=true
            ;;
        --list|-l)
            list_cities
            exit 0
            ;;
        --help|-h)
            echo "Usage: $0 [--dry-run] [--all] [--list] [city1 city2 ...]"
            echo ""
            echo "  --dry-run, -n   Show what would be done without publishing"
            echo "  --all, -a       Process all 20 cities"
            echo "  --list, -l      List available cities"
            echo "  city1 city2     Process only specified cities (case-insensitive)"
            echo ""
            echo "Without arguments: picks ONE random city (safe for cron / repeated runs)"
            echo ""
            echo "Examples:"
            echo "  $0                       # 1 random city"
            echo "  $0 --all                 # All 20 cities"
            echo "  $0 paris lyon toulouse   # Only these 3"
            echo "  $0 --dry-run paris       # Test without publishing"
            exit 0
            ;;
        *)
            SELECTED+=("$(echo "$arg" | tr '[:upper:]' '[:lower:]')")
            ;;
    esac
done

# Check dependencies
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  UPlanet UMAP Cities — G1 + Leboncoin Opportunities        ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check required tools
for tool in jq python3; do
    if ! command -v "$tool" &>/dev/null; then
        log_err "Missing dependency: $tool"
        exit 1
    fi
done

if [[ ! -f "$HOME/.zen/Astroport.ONE/tools/keygen" ]]; then
    log_err "keygen not found"
    exit 1
fi

if [[ ! -f "$HOME/.zen/Astroport.ONE/tools/nostr_send_note.py" ]]; then
    log_err "nostr_send_note.py not found"
    exit 1
fi

# Check Leboncoin cookie
LBC_COOKIE=""
if [[ -n "${CAPTAINEMAIL:-}" && -f "$HOME/.zen/game/nostr/${CAPTAINEMAIL}/.leboncoin.fr.cookie" ]]; then
    LBC_COOKIE="$HOME/.zen/game/nostr/${CAPTAINEMAIL}/.leboncoin.fr.cookie"
    log_ok "Leboncoin cookie found for ${CAPTAINEMAIL}"
else
    log_warn "No Leboncoin cookie — only GChange offers will be fetched"
fi

echo ""
log_step "UPLANETNAME: ${UPLANETNAME:0:16}..."
log_step "IPFSNODEID:  ${IPFSNODEID:0:16}..."
log_step "Relay:       ${myRELAY}"
log_step "Date:        ${TODATE}"
echo ""

# Filter cities
TARGETS=()
if [[ ${#SELECTED[@]} -gt 0 ]]; then
    # Specific cities requested
    for entry in "${CITIES[@]}"; do
        IFS=':' read -r name lat lon <<< "$entry"
        for sel in "${SELECTED[@]}"; do
            if [[ "$name" == "$sel" ]]; then
                TARGETS+=("$entry")
            fi
        done
    done
    if [[ ${#TARGETS[@]} -eq 0 ]]; then
        log_err "No matching cities found. Use --list to see available cities."
        exit 1
    fi
elif [[ "$ALL_CITIES" == true ]]; then
    # All cities
    TARGETS=("${CITIES[@]}")
else
    # Default: pick ONE random city
    RANDOM_INDEX=$((RANDOM % ${#CITIES[@]}))
    TARGETS=("${CITIES[$RANDOM_INDEX]}")
    IFS=':' read -r _rname _ _ <<< "${TARGETS[0]}"
    log_step "Random city selected: ${_rname^} (use --all for all cities)"
fi

echo -e "${CYAN}Processing ${#TARGETS[@]} cities...${NC}"
echo ""

SUCCESS=0
FAIL=0
SKIP=0

for entry in "${TARGETS[@]}"; do
    IFS=':' read -r name lat lon <<< "$entry"
    echo -e "${CYAN}━━━ ${name^} (${lat}, ${lon}) ━━━${NC}"

    if [[ "$DRY_RUN" == true ]]; then
        # Dry run: just show keys
        hex=$(setup_umap_directory "$lat" "$lon" 2>/dev/null) || true
        echo "  UMAP dir:  ~/.zen/game/nostr/UMAP_${lat}_${lon}/"
        echo "  HEX:       ${hex:0:16}..."
        echo "  Would run: ASTROBOT/SECTOR.sh $lat $lon 20"
        echo "  Would publish kind 30023 on relay $myRELAY"
        SKIP=$((SKIP + 1))
    else
        # Setup UMAP directory
        hex=$(setup_umap_directory "$lat" "$lon") || { FAIL=$((FAIL + 1)); continue; }
        log_ok "UMAP created: HEX=${hex:0:16}..."

        # Fetch and publish
        if publish_umap_opportunities "$name" "$lat" "$lon" "$hex" 100; then
            SUCCESS=$((SUCCESS + 1))
        else
            FAIL=$((FAIL + 1))
        fi
    fi
    echo ""
done

# Summary
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${CYAN}║  DRY RUN complete: ${#TARGETS[@]} cities would be processed          ║${NC}"
else
    printf "${CYAN}║  Done: ${GREEN}%d ok${CYAN} / ${RED}%d fail${CYAN} / ${#TARGETS[@]} total                            ║${NC}\n" "$SUCCESS" "$FAIL"
fi
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"

[[ "$DRY_RUN" == false && $FAIL -gt 0 ]] && exit 1
exit 0
