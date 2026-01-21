#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 1.0
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# CROWDFUNDING.sh - Forest Garden Commons Acquisition System
#
# Handles the dual-mode acquisition of shared spaces (forest gardens, etc.)
# with multiple property owners having different intentions:
#
# MODE 1: COMMONS DONATION (Non-convertible Ẑen → UPLANETNAME_CAPITAL)
#         Owner donates property to commons, receives non-convertible Ẑen
#         Benefits: Access to all UPlanet ẐEN network locations
#
# MODE 2: CASH SALE (€ → from ASSETS, or crowdfunding if insufficient)
#         Owner sells property share for €, requires real liquidity
#         If ASSETS wallet insufficient → launch "Ẑ convertible €" crowdfunding
#
# BONUS: If UPLANETNAME_G1 is low, automatically attach Ğ1 donation campaign
#
# Usage:
#   ./CROWDFUNDING.sh create LAT LON "PROJECT_NAME" [DESCRIPTION]
#   ./CROWDFUNDING.sh add-owner PROJECT_ID EMAIL MODE AMOUNT [CURRENCY]
#   ./CROWDFUNDING.sh status PROJECT_ID
#   ./CROWDFUNDING.sh contribute PROJECT_ID CONTRIBUTOR_EMAIL AMOUNT CURRENCY
#   ./CROWDFUNDING.sh finalize PROJECT_ID
#   ./CROWDFUNDING.sh list [--active|--completed|--all]
#   ./CROWDFUNDING.sh dashboard
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "${MY_PATH}/my.sh"
# Load cooperative config from DID NOSTR (shared across swarm)
. "${MY_PATH}/cooperative_config.sh" 2>/dev/null && coop_load_env_vars 2>/dev/null || true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
CROWDFUNDING_DIR="$HOME/.zen/game/crowdfunding"
CROWDFUNDING_NOSTR_KIND=30900  # Custom kind for crowdfunding projects

# Minimum thresholds for automatic Ğ1 campaign attachment
G1_LOW_THRESHOLD="${G1_LOW_THRESHOLD:-10000}"  # If UPLANETNAME_G1 < 10000 Ğ1, attach G1 campaign (covers ~100k Ẑen capacity)

################################################################################
# Utility Functions
################################################################################

# Convert Ẑen to Ğ1 (10 Ẑen = 1 Ğ1)
zen_to_g1() {
    local zen_amount="$1"
    echo "scale=2; $zen_amount / 10" | bc -l
}

# Convert Ğ1 to Ẑen
g1_to_zen() {
    local g1_amount="$1"
    echo "scale=2; $g1_amount * 10" | bc -l
}

# Generate unique project ID
generate_project_id() {
    echo "CF-$(date +%Y%m%d)-$(openssl rand -hex 4 | tr 'a-f' 'A-F')"
}

# Check wallet balance using G1check.sh (cached, with retries)
check_wallet_balance() {
    local wallet_pubkey="$1"
    # G1check.sh handles caching (24h TTL), retries, and BMAS server selection
    local balance=$("${MY_PATH}/G1check.sh" "$wallet_pubkey" 2>/dev/null)
    
    if [[ -n "$balance" && "$balance" != "" ]]; then
        echo "$balance"
    else
        echo "0"
    fi
}

# Get ZEN balance using G1check.sh with :ZEN suffix
get_zen_balance() {
    local wallet_pubkey="$1"
    # G1check.sh with :ZEN suffix returns (G1-1)*10
    local zen=$("${MY_PATH}/G1check.sh" "${wallet_pubkey}:ZEN" 2>/dev/null)
    
    if [[ -n "$zen" && "$zen" != "" ]]; then
        echo "$zen"
    else
        echo "0"
    fi
}

# Get ASSETS wallet balance
get_assets_balance() {
    if [[ -f "$HOME/.zen/game/uplanet.ASSETS.dunikey" ]]; then
        local assets_pubkey=$(cat "$HOME/.zen/game/uplanet.ASSETS.dunikey" | grep "pub:" | cut -d ' ' -f 2)
        check_wallet_balance "$assets_pubkey"
    else
        echo "0"
    fi
}

# Get UPLANETNAME_G1 wallet balance
get_g1_wallet_balance() {
    if [[ -f "$HOME/.zen/tmp/UPLANETNAME_G1" ]]; then
        local g1_pubkey=$(cat "$HOME/.zen/tmp/UPLANETNAME_G1")
        check_wallet_balance "$g1_pubkey"
    else
        echo "0"
    fi
}

# Get CAPITAL wallet balance
get_capital_balance() {
    if [[ -f "$HOME/.zen/game/uplanet.CAPITAL.dunikey" ]]; then
        local capital_pubkey=$(cat "$HOME/.zen/game/uplanet.CAPITAL.dunikey" | grep "pub:" | cut -d ' ' -f 2)
        check_wallet_balance "$capital_pubkey"
    else
        echo "0"
    fi
}

################################################################################
# Project Management Functions
################################################################################

# Create a new crowdfunding project
create_project() {
    local lat="$1"
    local lon="$2"
    local project_name="$3"
    local description="${4:-Projet de forêt jardin collaborative}"
    
    if [[ -z "$lat" || -z "$lon" || -z "$project_name" ]]; then
        echo -e "${RED}❌ Usage: $0 create LAT LON \"PROJECT_NAME\" [DESCRIPTION]${NC}"
        return 1
    fi
    
    local project_id=$(generate_project_id)
    local project_dir="$CROWDFUNDING_DIR/$project_id"
    
    mkdir -p "$project_dir"
    
    # Initialize project JSON
    local created_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local created_ts=$(date +%s)
    
    cat > "$project_dir/project.json" << EOF
{
    "id": "$project_id",
    "name": "$project_name",
    "description": "$description",
    "location": {
        "latitude": $lat,
        "longitude": $lon
    },
    "status": "draft",
    "created_at": "$created_at",
    "created_ts": $created_ts,
    "owners": [],
    "contributions": [],
    "totals": {
        "commons_zen": 0,
        "cash_eur": 0,
        "g1_target": 0,
        "g1_collected": 0,
        "zen_convertible_target": 0,
        "zen_convertible_collected": 0
    },
    "campaigns": {
        "g1_campaign_active": false,
        "zen_convertible_campaign_active": false
    },
    "captain_email": "$CAPTAINEMAIL",
    "uplanet_g1pub": "$UPLANETG1PUB",
    "ipfsnodeid": "$IPFSNODEID"
}
EOF

    echo -e "${GREEN}✅ Projet créé avec succès !${NC}"
    echo -e "${CYAN}📋 ID du projet: ${project_id}${NC}"
    echo -e "${CYAN}📍 Localisation: (${lat}, ${lon})${NC}"
    echo -e "${CYAN}🏷️  Nom: ${project_name}${NC}"
    echo ""
    echo -e "${YELLOW}💡 Prochaines étapes:${NC}"
    echo -e "   1. Ajoutez les propriétaires: $0 add-owner $project_id EMAIL MODE AMOUNT"
    echo -e "   2. Vérifiez le statut: $0 status $project_id"
    echo -e "   3. Finalisez: $0 finalize $project_id"
    
    echo "$project_id"
}

# Add an owner to a project
add_owner() {
    local project_id="$1"
    local owner_email="$2"
    local mode="$3"          # "commons" or "cash"
    local amount="$4"        # Amount in Ẑen (commons) or € (cash)
    local currency="${5:-zen}"  # zen or eur
    
    if [[ -z "$project_id" || -z "$owner_email" || -z "$mode" || -z "$amount" ]]; then
        echo -e "${RED}❌ Usage: $0 add-owner PROJECT_ID EMAIL MODE AMOUNT [CURRENCY]${NC}"
        echo -e "${YELLOW}   MODE: commons | cash${NC}"
        echo -e "${YELLOW}   CURRENCY: zen | eur (default: zen)${NC}"
        return 1
    fi
    
    local project_dir="$CROWDFUNDING_DIR/$project_id"
    local project_file="$project_dir/project.json"
    
    if [[ ! -f "$project_file" ]]; then
        echo -e "${RED}❌ Projet non trouvé: $project_id${NC}"
        return 1
    fi
    
    # Validate mode
    if [[ "$mode" != "commons" && "$mode" != "cash" ]]; then
        echo -e "${RED}❌ Mode invalide: $mode (utilisez 'commons' ou 'cash')${NC}"
        return 1
    fi
    
    # Normalize currency for each mode
    local owner_amount_zen=0
    local owner_amount_eur=0
    
    if [[ "$mode" == "commons" ]]; then
        # Commons donations are always in Ẑen (non-convertible)
        owner_amount_zen="$amount"
        echo -e "${BLUE}🤝 Propriétaire COMMONS: $owner_email${NC}"
        echo -e "${CYAN}   Donation aux communs: $owner_amount_zen Ẑen (non-convertible €)${NC}"
        echo -e "${GREEN}   ✅ Recevra accès à tous les lieux UPlanet ẐEN${NC}"
    else
        # Cash sales are in € (requires liquidity)
        owner_amount_eur="$amount"
        echo -e "${BLUE}💶 Propriétaire CASH: $owner_email${NC}"
        echo -e "${CYAN}   Vente en €: ${owner_amount_eur}€${NC}"
        echo -e "${YELLOW}   ⚠️  Nécessite liquidité ASSETS ou crowdfunding${NC}"
    fi
    
    # Add owner to project
    local owner_json=$(cat << EOF
{
    "email": "$owner_email",
    "mode": "$mode",
    "amount_zen": $owner_amount_zen,
    "amount_eur": $owner_amount_eur,
    "status": "pending",
    "added_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)
    
    # Update project file
    local temp_file=$(mktemp)
    jq ".owners += [$owner_json]" "$project_file" > "$temp_file"
    
    # Update totals
    if [[ "$mode" == "commons" ]]; then
        jq ".totals.commons_zen += $owner_amount_zen" "$temp_file" > "${temp_file}.2"
        mv "${temp_file}.2" "$temp_file"
    else
        jq ".totals.cash_eur += $owner_amount_eur" "$temp_file" > "${temp_file}.2"
        mv "${temp_file}.2" "$temp_file"
    fi
    
    mv "$temp_file" "$project_file"
    
    # Check if we need to launch crowdfunding campaigns
    check_and_launch_campaigns "$project_id"
    
    echo -e "${GREEN}✅ Propriétaire ajouté !${NC}"
}

# Check wallet balances and launch campaigns if needed
check_and_launch_campaigns() {
    local project_id="$1"
    local project_dir="$CROWDFUNDING_DIR/$project_id"
    local project_file="$project_dir/project.json"
    
    # Get current balances
    local assets_balance=$(get_assets_balance)
    local g1_balance=$(get_g1_wallet_balance)
    
    # Get project totals
    local cash_eur_needed=$(jq -r '.totals.cash_eur' "$project_file")
    local commons_zen_needed=$(jq -r '.totals.commons_zen' "$project_file")
    
    # Convert € needed to Ẑen (1€ ≈ 1Ẑen for simplicity, adjust rate as needed)
    local zen_for_cash=$(echo "scale=2; $cash_eur_needed * 1" | bc -l)
    local g1_for_cash=$(zen_to_g1 "$zen_for_cash")
    
    echo ""
    echo -e "${CYAN}📊 Analyse des besoins de financement:${NC}"
    echo -e "   Commons (donation Ẑen): $commons_zen_needed Ẑen"
    echo -e "   Cash (vente €): ${cash_eur_needed}€ (~$zen_for_cash Ẑen / $g1_for_cash Ğ1)"
    echo ""
    echo -e "${CYAN}💰 Soldes actuels des portefeuilles:${NC}"
    echo -e "   ASSETS: $assets_balance Ğ1"
    echo -e "   UPLANETNAME_G1: $g1_balance Ğ1"
    echo ""
    
    # Check if ASSETS can cover cash sales
    local need_zen_crowdfunding=false
    local zen_shortfall=0
    
    if [[ $(echo "$g1_for_cash > $assets_balance" | bc -l) -eq 1 ]]; then
        zen_shortfall=$(echo "scale=2; ($g1_for_cash - $assets_balance) * 10" | bc -l)
        need_zen_crowdfunding=true
        
        echo -e "${YELLOW}⚠️  ASSETS insuffisant pour les ventes €${NC}"
        echo -e "${YELLOW}   Manque: $zen_shortfall Ẑen (convertible €)${NC}"
        
        # Update project with Ẑen convertible campaign
        jq ".campaigns.zen_convertible_campaign_active = true | .totals.zen_convertible_target = $zen_shortfall" "$project_file" > "${project_file}.tmp"
        mv "${project_file}.tmp" "$project_file"
    else
        echo -e "${GREEN}✅ ASSETS suffisant pour les ventes €${NC}"
    fi
    
    # Check if UPLANETNAME_G1 is low (needs Ğ1 donation campaign)
    local need_g1_campaign=false
    local total_g1_needed=$(echo "scale=2; $(zen_to_g1 $commons_zen_needed) + $g1_for_cash" | bc -l)
    
    if [[ $(echo "$g1_balance < $G1_LOW_THRESHOLD" | bc -l) -eq 1 ]]; then
        need_g1_campaign=true
        local g1_target=$(echo "scale=2; $total_g1_needed - $g1_balance + $G1_LOW_THRESHOLD" | bc -l)
        
        echo -e "${YELLOW}⚠️  UPLANETNAME_G1 bas (< $G1_LOW_THRESHOLD Ğ1)${NC}"
        echo -e "${YELLOW}   Lancement campagne Ğ1: cible $g1_target Ğ1${NC}"
        
        # Update project with Ğ1 campaign
        jq ".campaigns.g1_campaign_active = true | .totals.g1_target = $g1_target" "$project_file" > "${project_file}.tmp"
        mv "${project_file}.tmp" "$project_file"
    else
        echo -e "${GREEN}✅ UPLANETNAME_G1 suffisant${NC}"
    fi
    
    # Update project status
    if [[ "$need_zen_crowdfunding" == true || "$need_g1_campaign" == true ]]; then
        jq '.status = "crowdfunding"' "$project_file" > "${project_file}.tmp"
        mv "${project_file}.tmp" "$project_file"
        
        echo ""
        echo -e "${MAGENTA}🚀 CAMPAGNES DE CROWDFUNDING LANCÉES !${NC}"
        
        # Publish to Nostr
        publish_crowdfunding_to_nostr "$project_id"
    fi
}

# Publish crowdfunding campaign to Nostr
publish_crowdfunding_to_nostr() {
    local project_id="$1"
    local project_dir="$CROWDFUNDING_DIR/$project_id"
    local project_file="$project_dir/project.json"
    
    local project_name=$(jq -r '.name' "$project_file")
    local description=$(jq -r '.description' "$project_file")
    local lat=$(jq -r '.location.latitude' "$project_file")
    local lon=$(jq -r '.location.longitude' "$project_file")
    local zen_target=$(jq -r '.totals.zen_convertible_target' "$project_file")
    local g1_target=$(jq -r '.totals.g1_target' "$project_file")
    local zen_campaign=$(jq -r '.campaigns.zen_convertible_campaign_active' "$project_file")
    local g1_campaign=$(jq -r '.campaigns.g1_campaign_active' "$project_file")
    
    # Build content
    local content="# 🌳 $project_name

$description

## 📍 Localisation
Coordonnées: ($lat, $lon)

## 💰 Objectifs de Financement
"

    if [[ "$zen_campaign" == "true" && "$zen_target" != "0" ]]; then
        content+="
### 💶 Ẑen Convertible € (pour achats cash)
**Objectif:** $zen_target Ẑen
**Collecté:** 0 Ẑen
**Progression:** 0%

*Ces fonds permettent de racheter les parts des propriétaires souhaitant une sortie en €*
"
    fi
    
    if [[ "$g1_campaign" == "true" && "$g1_target" != "0" ]]; then
        content+="
### 🪙 Don de Ğ1 (June)
**Objectif:** $g1_target Ğ1
**Collecté:** 0 Ğ1
**Progression:** 0%

*Ces fonds alimentent le portefeuille coopératif UPLANETNAME_G1*
"
    fi
    
    content+="
## 🤝 Comment Contribuer

### En Ẑen (convertible €)
Envoyez vos Ẑen vers le portefeuille ASSETS avec le commentaire:
\`CF:$project_id:ZEN\`

### En Ğ1 (June)
Envoyez vos Ğ1 vers le portefeuille UPLANETNAME_G1 avec le commentaire:
\`CF:$project_id:G1\`

---
*Projet UPlanet ẐEN - Forêt Jardin Collaborative*
ID: $project_id
"

    # Publish as kind 30023 (long-form content) with crowdfunding tags
    if [[ -f "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr" ]]; then
        source "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
        
        python3 "${MY_PATH}/nostr_send_note.py" \
            --nsec "$NSEC" \
            --kind 30023 \
            --content "$content" \
            --tags "[[\"d\", \"crowdfunding-$project_id\"], [\"title\", \"🌳 Crowdfunding: $project_name\"], [\"t\", \"crowdfunding\"], [\"t\", \"UPlanet\"], [\"t\", \"commons\"], [\"t\", \"foret-jardin\"], [\"g\", \"$lat,$lon\"], [\"project-id\", \"$project_id\"]]" \
            2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✅ Campagne publiée sur Nostr !${NC}"
        fi
    fi
}

# Show project status
show_status() {
    local project_id="$1"
    local project_dir="$CROWDFUNDING_DIR/$project_id"
    local project_file="$project_dir/project.json"
    
    if [[ ! -f "$project_file" ]]; then
        echo -e "${RED}❌ Projet non trouvé: $project_id${NC}"
        return 1
    fi
    
    local project=$(cat "$project_file")
    
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║            🌳 CROWDFUNDING FORÊT JARDIN                          ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}📋 Projet: $(echo "$project" | jq -r '.name')${NC}"
    echo -e "${CYAN}🆔 ID: $project_id${NC}"
    echo -e "${CYAN}📍 Localisation: ($(echo "$project" | jq -r '.location.latitude'), $(echo "$project" | jq -r '.location.longitude'))${NC}"
    echo -e "${CYAN}📊 Statut: $(echo "$project" | jq -r '.status')${NC}"
    echo ""
    
    echo -e "${YELLOW}👥 PROPRIÉTAIRES:${NC}"
    echo "$project" | jq -r '.owners[] | "   • \(.email) [\(.mode)] - \(if .mode == "commons" then "\(.amount_zen) Ẑen (donation)" else "\(.amount_eur)€ (cash)" end) [\(.status)]"'
    echo ""
    
    echo -e "${YELLOW}💰 TOTAUX:${NC}"
    echo -e "   Commons (Ẑen non-conv.): $(echo "$project" | jq -r '.totals.commons_zen') Ẑen"
    echo -e "   Cash (€):                $(echo "$project" | jq -r '.totals.cash_eur')€"
    echo ""
    
    # Campaigns
    local zen_campaign=$(echo "$project" | jq -r '.campaigns.zen_convertible_campaign_active')
    local g1_campaign=$(echo "$project" | jq -r '.campaigns.g1_campaign_active')
    
    if [[ "$zen_campaign" == "true" || "$g1_campaign" == "true" ]]; then
        echo -e "${MAGENTA}🚀 CAMPAGNES ACTIVES:${NC}"
        
        if [[ "$zen_campaign" == "true" ]]; then
            local zen_target=$(echo "$project" | jq -r '.totals.zen_convertible_target')
            local zen_collected=$(echo "$project" | jq -r '.totals.zen_convertible_collected')
            local zen_pct=$(echo "scale=0; $zen_collected * 100 / $zen_target" | bc -l 2>/dev/null || echo "0")
            echo -e "   💶 Ẑen Convertible €:"
            echo -e "      Objectif: $zen_target Ẑen"
            echo -e "      Collecté: $zen_collected Ẑen ($zen_pct%)"
            draw_progress_bar "$zen_collected" "$zen_target"
        fi
        
        if [[ "$g1_campaign" == "true" ]]; then
            local g1_target=$(echo "$project" | jq -r '.totals.g1_target')
            local g1_collected=$(echo "$project" | jq -r '.totals.g1_collected')
            local g1_pct=$(echo "scale=0; $g1_collected * 100 / $g1_target" | bc -l 2>/dev/null || echo "0")
            echo -e "   🪙 Don Ğ1 (June):"
            echo -e "      Objectif: $g1_target Ğ1"
            echo -e "      Collecté: $g1_collected Ğ1 ($g1_pct%)"
            draw_progress_bar "$g1_collected" "$g1_target"
        fi
    fi
    
    echo ""
    echo -e "${CYAN}📝 Contributions:${NC}"
    local contrib_count=$(echo "$project" | jq '.contributions | length')
    if [[ "$contrib_count" == "0" ]]; then
        echo -e "   (aucune contribution pour le moment)"
    else
        echo "$project" | jq -r '.contributions[] | "   • \(.contributor_email): \(.amount) \(.currency) [\(.timestamp)]"'
    fi
    
    echo ""
}

# Draw ASCII progress bar
draw_progress_bar() {
    local current="$1"
    local target="$2"
    local width=40
    
    if [[ "$target" == "0" ]]; then
        target="1"  # Avoid division by zero
    fi
    
    local pct=$(echo "scale=2; $current / $target" | bc -l)
    local filled=$(echo "scale=0; $pct * $width" | bc -l | cut -d. -f1)
    [[ -z "$filled" ]] && filled=0
    [[ $filled -gt $width ]] && filled=$width
    local empty=$((width - filled))
    
    printf "      ["
    printf '%0.s█' $(seq 1 $filled 2>/dev/null) || true
    printf '%0.s░' $(seq 1 $empty 2>/dev/null) || true
    printf "]\n"
}

# Record a contribution
record_contribution() {
    local project_id="$1"
    local contributor_email="$2"
    local amount="$3"
    local currency="$4"  # ZEN or G1
    
    if [[ -z "$project_id" || -z "$contributor_email" || -z "$amount" || -z "$currency" ]]; then
        echo -e "${RED}❌ Usage: $0 contribute PROJECT_ID CONTRIBUTOR_EMAIL AMOUNT CURRENCY${NC}"
        echo -e "${YELLOW}   CURRENCY: ZEN | G1${NC}"
        return 1
    fi
    
    local project_dir="$CROWDFUNDING_DIR/$project_id"
    local project_file="$project_dir/project.json"
    
    if [[ ! -f "$project_file" ]]; then
        echo -e "${RED}❌ Projet non trouvé: $project_id${NC}"
        return 1
    fi
    
    # Add contribution
    local contrib_json=$(cat << EOF
{
    "contributor_email": "$contributor_email",
    "amount": $amount,
    "currency": "$currency",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)
    
    local temp_file=$(mktemp)
    jq ".contributions += [$contrib_json]" "$project_file" > "$temp_file"
    
    # Update collected amounts
    if [[ "$currency" == "ZEN" ]]; then
        jq ".totals.zen_convertible_collected += $amount" "$temp_file" > "${temp_file}.2"
        mv "${temp_file}.2" "$temp_file"
    elif [[ "$currency" == "G1" ]]; then
        jq ".totals.g1_collected += $amount" "$temp_file" > "${temp_file}.2"
        mv "${temp_file}.2" "$temp_file"
    fi
    
    mv "$temp_file" "$project_file"
    
    echo -e "${GREEN}✅ Contribution enregistrée !${NC}"
    echo -e "${CYAN}   $contributor_email: $amount $currency${NC}"
    
    # Check if goals are reached
    check_goals_reached "$project_id"
}

# Check if crowdfunding goals are reached
check_goals_reached() {
    local project_id="$1"
    local project_dir="$CROWDFUNDING_DIR/$project_id"
    local project_file="$project_dir/project.json"
    
    local zen_target=$(jq -r '.totals.zen_convertible_target' "$project_file")
    local zen_collected=$(jq -r '.totals.zen_convertible_collected' "$project_file")
    local g1_target=$(jq -r '.totals.g1_target' "$project_file")
    local g1_collected=$(jq -r '.totals.g1_collected' "$project_file")
    
    local zen_reached=true
    local g1_reached=true
    
    if [[ $(echo "$zen_collected < $zen_target" | bc -l) -eq 1 ]]; then
        zen_reached=false
    fi
    
    if [[ $(echo "$g1_collected < $g1_target" | bc -l) -eq 1 ]]; then
        g1_reached=false
    fi
    
    if [[ "$zen_reached" == "true" && "$g1_reached" == "true" ]]; then
        echo -e "${GREEN}🎉 OBJECTIFS ATTEINTS ! Le projet peut être finalisé.${NC}"
        jq '.status = "funded"' "$project_file" > "${project_file}.tmp"
        mv "${project_file}.tmp" "$project_file"
    fi
}

# Finalize project (execute transfers)
finalize_project() {
    local project_id="$1"
    local project_dir="$CROWDFUNDING_DIR/$project_id"
    local project_file="$project_dir/project.json"
    
    if [[ ! -f "$project_file" ]]; then
        echo -e "${RED}❌ Projet non trouvé: $project_id${NC}"
        return 1
    fi
    
    local status=$(jq -r '.status' "$project_file")
    
    if [[ "$status" != "funded" ]]; then
        echo -e "${YELLOW}⚠️  Le projet n'est pas encore entièrement financé (statut: $status)${NC}"
        read -p "Voulez-vous forcer la finalisation ? (oui/non): " confirm
        if [[ "$confirm" != "oui" ]]; then
            echo -e "${YELLOW}🚫 Finalisation annulée${NC}"
            return 0
        fi
    fi
    
    echo -e "${BLUE}🚀 Finalisation du projet $project_id...${NC}"
    echo ""
    
    # Process each owner
    local owners=$(jq -c '.owners[]' "$project_file")
    
    while read -r owner; do
        local email=$(echo "$owner" | jq -r '.email')
        local mode=$(echo "$owner" | jq -r '.mode')
        local amount_zen=$(echo "$owner" | jq -r '.amount_zen')
        local amount_eur=$(echo "$owner" | jq -r '.amount_eur')
        
        echo -e "${CYAN}👤 Traitement: $email (mode: $mode)${NC}"
        
        if [[ "$mode" == "commons" ]]; then
            # Commons donation → UPLANETNAME_CAPITAL
            echo -e "   → Transfert $amount_zen Ẑen vers UPLANETNAME_CAPITAL"
            
            # Get owner's ZenCard pubkey
            local zencard_pubkey=""
            if [[ -f "$HOME/.zen/game/players/${email}/.g1pub" ]]; then
                zencard_pubkey=$(cat "$HOME/.zen/game/players/${email}/.g1pub")
            fi
            
            if [[ -n "$zencard_pubkey" ]]; then
                # Transfer to CAPITAL using UPLANET.official.sh logic
                local capital_pubkey=""
                if [[ -f "$HOME/.zen/game/uplanet.CAPITAL.dunikey" ]]; then
                    capital_pubkey=$(cat "$HOME/.zen/game/uplanet.CAPITAL.dunikey" | grep "pub:" | cut -d ' ' -f 2)
                fi
                
                if [[ -n "$capital_pubkey" ]]; then
                    local g1_amount=$(zen_to_g1 "$amount_zen")
                    local reference="UPLANET:${UPLANETG1PUB:0:8}:COMMONS:${email}:${project_id}:${IPFSNODEID}"
                    
                    echo -e "   → Exécution: PAYforSURE.sh vers CAPITAL ($g1_amount Ğ1)"
                    "${MY_PATH}/PAYforSURE.sh" "$HOME/.zen/game/uplanet.G1.dunikey" "$g1_amount" "$capital_pubkey" "$reference"
                    
                    if [[ $? -eq 0 ]]; then
                        echo -e "${GREEN}   ✅ Donation Commons enregistrée${NC}"
                        # Update DID
                        "${MY_PATH}/did_manager_nostr.sh" update "$email" "COMMONS_CONTRIBUTION" "$amount_zen" "$g1_amount"
                    fi
                fi
            fi
            
        else
            # Cash sale → Pay from ASSETS
            echo -e "   → Paiement ${amount_eur}€ depuis ASSETS"
            
            local g1_amount=$(zen_to_g1 "$amount_eur")  # 1€ ≈ 1Ẑen ≈ 0.1Ğ1
            local reference="UPLANET:${UPLANETG1PUB:0:8}:CASHOUT:${email}:${project_id}:${IPFSNODEID}"
            
            # Get owner's wallet
            local owner_wallet=""
            if [[ -f "$HOME/.zen/game/players/${email}/.g1pub" ]]; then
                owner_wallet=$(cat "$HOME/.zen/game/players/${email}/.g1pub")
            elif [[ -f "$HOME/.zen/game/nostr/${email}/G1PUBNOSTR" ]]; then
                owner_wallet=$(cat "$HOME/.zen/game/nostr/${email}/G1PUBNOSTR")
            fi
            
            if [[ -n "$owner_wallet" ]]; then
                echo -e "   → Exécution: PAYforSURE.sh depuis ASSETS ($g1_amount Ğ1)"
                "${MY_PATH}/PAYforSURE.sh" "$HOME/.zen/game/uplanet.ASSETS.dunikey" "$g1_amount" "$owner_wallet" "$reference"
                
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}   ✅ Paiement Cash exécuté${NC}"
                fi
            fi
        fi
        
    done <<< "$owners"
    
    # Update project status
    jq '.status = "completed"' "$project_file" > "${project_file}.tmp"
    mv "${project_file}.tmp" "$project_file"
    
    echo ""
    echo -e "${GREEN}🎉 Projet finalisé avec succès !${NC}"
}

# List all projects
list_projects() {
    local filter="${1:---all}"
    
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              📋 LISTE DES PROJETS CROWDFUNDING                   ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [[ ! -d "$CROWDFUNDING_DIR" ]]; then
        echo -e "${YELLOW}   Aucun projet trouvé${NC}"
        return 0
    fi
    
    for project_dir in "$CROWDFUNDING_DIR"/*/; do
        if [[ -d "$project_dir" ]]; then
            local project_file="$project_dir/project.json"
            if [[ -f "$project_file" ]]; then
                local status=$(jq -r '.status' "$project_file")
                
                # Apply filter
                case "$filter" in
                    "--active")
                        [[ "$status" != "crowdfunding" && "$status" != "draft" ]] && continue
                        ;;
                    "--completed")
                        [[ "$status" != "completed" ]] && continue
                        ;;
                esac
                
                local id=$(jq -r '.id' "$project_file")
                local name=$(jq -r '.name' "$project_file")
                local commons=$(jq -r '.totals.commons_zen' "$project_file")
                local cash=$(jq -r '.totals.cash_eur' "$project_file")
                
                # Status icon
                local status_icon="📝"
                case "$status" in
                    "crowdfunding") status_icon="🚀" ;;
                    "funded") status_icon="💰" ;;
                    "completed") status_icon="✅" ;;
                esac
                
                echo -e "${CYAN}$status_icon $id${NC}"
                echo -e "   📍 $name"
                echo -e "   💰 Commons: ${commons}Ẑ | Cash: ${cash}€"
                echo -e "   📊 Statut: $status"
                echo ""
            fi
        fi
    done
}

# Interactive dashboard
show_dashboard() {
    clear
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          🌳 DASHBOARD CROWDFUNDING FORÊT JARDIN                  ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Wallet balances
    echo -e "${YELLOW}💰 SOLDES DES PORTEFEUILLES:${NC}"
    echo -e "   UPLANETNAME_G1: $(get_g1_wallet_balance) Ğ1"
    echo -e "   ASSETS:         $(get_assets_balance) Ğ1"
    echo -e "   CAPITAL:        $(get_capital_balance) Ğ1"
    echo ""
    
    # Active campaigns count
    local active_count=0
    local total_zen_target=0
    local total_g1_target=0
    
    if [[ -d "$CROWDFUNDING_DIR" ]]; then
        for project_file in "$CROWDFUNDING_DIR"/*/project.json; do
            if [[ -f "$project_file" ]]; then
                local status=$(jq -r '.status' "$project_file")
                if [[ "$status" == "crowdfunding" ]]; then
                    active_count=$((active_count + 1))
                    total_zen_target=$(echo "$total_zen_target + $(jq -r '.totals.zen_convertible_target' "$project_file")" | bc -l)
                    total_g1_target=$(echo "$total_g1_target + $(jq -r '.totals.g1_target' "$project_file")" | bc -l)
                fi
            fi
        done
    fi
    
    echo -e "${MAGENTA}🚀 CAMPAGNES ACTIVES: $active_count${NC}"
    if [[ $active_count -gt 0 ]]; then
        echo -e "   Objectif Ẑen total: $total_zen_target Ẑen"
        echo -e "   Objectif Ğ1 total:  $total_g1_target Ğ1"
    fi
    echo ""
    
    # Quick actions
    echo -e "${CYAN}📋 ACTIONS RAPIDES:${NC}"
    echo "   1. Créer un nouveau projet"
    echo "   2. Voir les projets actifs"
    echo "   3. Voir tous les projets"
    echo "   4. Quitter"
    echo ""
    read -p "Votre choix: " choice
    
    case "$choice" in
        1)
            read -p "Latitude: " lat
            read -p "Longitude: " lon
            read -p "Nom du projet: " name
            read -p "Description: " desc
            create_project "$lat" "$lon" "$name" "$desc"
            ;;
        2)
            list_projects "--active"
            ;;
        3)
            list_projects "--all"
            ;;
        4)
            exit 0
            ;;
    esac
}

# Show help
show_help() {
    echo ""
    echo -e "${BLUE}CROWDFUNDING.sh - Système d'acquisition de Forêts Jardins${NC}"
    echo ""
    echo "Usage:"
    echo "  $0 create LAT LON \"PROJECT_NAME\" [DESCRIPTION]"
    echo "  $0 add-owner PROJECT_ID EMAIL MODE AMOUNT [CURRENCY]"
    echo "  $0 status PROJECT_ID"
    echo "  $0 contribute PROJECT_ID CONTRIBUTOR_EMAIL AMOUNT CURRENCY"
    echo "  $0 finalize PROJECT_ID"
    echo "  $0 list [--active|--completed|--all]"
    echo "  $0 dashboard"
    echo ""
    echo "Modes de propriétaires:"
    echo "  commons  - Donation aux communs (Ẑen non-convertible €)"
    echo "  cash     - Vente en € (nécessite liquidité ASSETS ou crowdfunding)"
    echo ""
    echo "Exemple - Forêt avec 2 propriétaires:"
    echo "  $0 create 43.60 1.44 \"Forêt Enchantée\" \"Projet forêt jardin collaborative\""
    echo "  $0 add-owner CF-20250120-XXXX alice@example.com commons 500"
    echo "  $0 add-owner CF-20250120-XXXX bob@example.com cash 1000"
    echo "  $0 status CF-20250120-XXXX"
    echo ""
}

################################################################################
# Main Entry Point
################################################################################

mkdir -p "$CROWDFUNDING_DIR"

case "$1" in
    "create")
        create_project "$2" "$3" "$4" "$5"
        ;;
    "add-owner")
        add_owner "$2" "$3" "$4" "$5" "$6"
        ;;
    "status")
        show_status "$2"
        ;;
    "contribute")
        record_contribution "$2" "$3" "$4" "$5"
        ;;
    "finalize")
        finalize_project "$2"
        ;;
    "list")
        list_projects "$2"
        ;;
    "dashboard")
        show_dashboard
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        if [[ -z "$1" ]]; then
            show_dashboard
        else
            echo -e "${RED}❌ Commande inconnue: $1${NC}"
            show_help
            exit 1
        fi
        ;;
esac
