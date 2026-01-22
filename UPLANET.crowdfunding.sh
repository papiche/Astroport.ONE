#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 1.0
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# UPLANET.crowdfunding.sh - Captain's Interface for Crowdfunding Management
#
# Complete management interface for crowdfunding projects:
# - Dashboard with all projects overview
# - Create, manage, and finalize crowdfunding campaigns
# - Register capital contributions and usage tokens
# - Monitor Bien wallets and NOSTR identities
# - Process contributions from crowdfunding.html (kind 7 reactions)
#
# This script is the administrative counterpart to the public crowdfunding.html
# interface. While contributors use the web UI, the captain uses this CLI.
#
# Usage:
#   ./UPLANET.crowdfunding.sh [command] [options]
#   ./UPLANET.crowdfunding.sh  # Interactive menu
#
# See --help for complete documentation.
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "${MY_PATH}/tools/my.sh"
# Load cooperative config from DID NOSTR (shared across swarm)
. "${MY_PATH}/tools/cooperative_config.sh" 2>/dev/null && coop_load_env_vars 2>/dev/null || true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Configuration
CROWDFUNDING_DIR="$HOME/.zen/game/crowdfunding"
CROWDFUNDING_TOOL="${MY_PATH}/tools/CROWDFUNDING.sh"
DID_MANAGER="${MY_PATH}/tools/did_manager_nostr.sh"
G1CHECK="${MY_PATH}/tools/G1check.sh"

# Ensure directories exist
mkdir -p "$CROWDFUNDING_DIR"

################################################################################
# Display Functions
################################################################################

# Show banner
show_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}🌳 UPLANET CROWDFUNDING${NC}  ${DIM}Captain's Management Interface${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${DIM}Gestion des projets de Biens Communs - Forêts Jardins - Infrastructure${NC}    ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Draw horizontal line
draw_line() {
    local char="${1:--}"
    local color="${2:-$DIM}"
    echo -e "${color}$(printf '%*s' 80 | tr ' ' "$char")${NC}"
}

# Show section header
show_section() {
    local title="$1"
    local icon="${2:-📋}"
    echo ""
    echo -e "${BOLD}${WHITE}$icon $title${NC}"
    draw_line "-"
}

################################################################################
# Wallet Information
################################################################################

# Get wallet balance
get_wallet_balance() {
    local pubkey="$1"
    local balance=$("${G1CHECK}" "$pubkey" 2>/dev/null)
    echo "${balance:-0}"
}

# Get ZEN balance
get_zen_balance() {
    local pubkey="$1"
    local balance=$("${G1CHECK}" "${pubkey}:ZEN" 2>/dev/null)
    echo "${balance:-0}"
}

# Show cooperative wallets status
show_wallets_status() {
    show_section "PORTEFEUILLES COOPÉRATIFS" "💰"
    
    # UPLANETNAME_G1
    if [[ -f "$HOME/.zen/tmp/UPLANETNAME_G1" ]]; then
        local g1_pub=$(cat "$HOME/.zen/tmp/UPLANETNAME_G1")
        local g1_balance=$(get_wallet_balance "$g1_pub")
        echo -e "${YELLOW}UPLANETNAME_G1${NC}    : ${g1_balance} Ğ1  ${DIM}(Donations Ğ1)${NC}"
    fi
    
    # ASSETS
    if [[ -f "$HOME/.zen/game/uplanet.ASSETS.dunikey" ]]; then
        local assets_pub=$(cat "$HOME/.zen/game/uplanet.ASSETS.dunikey" | grep "pub:" | cut -d ' ' -f 2)
        local assets_balance=$(get_wallet_balance "$assets_pub")
        local assets_zen=$(echo "scale=2; ($assets_balance - 1) * 10" | bc -l 2>/dev/null || echo "0")
        [[ $(echo "$assets_zen < 0" | bc -l) -eq 1 ]] && assets_zen="0"
        echo -e "${GREEN}ASSETS${NC}            : ${assets_balance} Ğ1 (~${assets_zen} Ẑen)  ${DIM}(Ẑen convertible €)${NC}"
    fi
    
    # CAPITAL
    if [[ -f "$HOME/.zen/game/uplanet.CAPITAL.dunikey" ]]; then
        local capital_pub=$(cat "$HOME/.zen/game/uplanet.CAPITAL.dunikey" | grep "pub:" | cut -d ' ' -f 2)
        local capital_balance=$(get_wallet_balance "$capital_pub")
        local capital_zen=$(echo "scale=2; ($capital_balance - 1) * 10" | bc -l 2>/dev/null || echo "0")
        [[ $(echo "$capital_zen < 0" | bc -l) -eq 1 ]] && capital_zen="0"
        echo -e "${MAGENTA}CAPITAL${NC}           : ${capital_balance} Ğ1 (~${capital_zen} Ẑen)  ${DIM}(Ẑen non-convertible)${NC}"
    fi
    
    # TREASURY
    if [[ -f "$HOME/.zen/tmp/UPLANETNAME_TREASURY" ]]; then
        local treasury_pub=$(cat "$HOME/.zen/tmp/UPLANETNAME_TREASURY")
        local treasury_balance=$(get_wallet_balance "$treasury_pub")
        echo -e "${BLUE}TREASURY${NC}          : ${treasury_balance} Ğ1  ${DIM}(Réserve)${NC}"
    fi
    
    echo ""
}

################################################################################
# Project Management
################################################################################

# List all projects with status
list_projects_detailed() {
    show_section "PROJETS CROWDFUNDING" "🌳"
    
    local count=0
    local active_count=0
    local total_zen_target=0
    local total_zen_collected=0
    
    if [[ -d "$CROWDFUNDING_DIR" ]]; then
        for project_file in "$CROWDFUNDING_DIR"/*/project.json; do
            if [[ -f "$project_file" ]]; then
                count=$((count + 1))
                local project_id=$(jq -r '.id' "$project_file")
                local name=$(jq -r '.name' "$project_file")
                local status=$(jq -r '.status' "$project_file")
                local lat=$(jq -r '.location.latitude' "$project_file")
                local lon=$(jq -r '.location.longitude' "$project_file")
                local zen_target=$(jq -r '.totals.zen_convertible_target // 0' "$project_file")
                local zen_collected=$(jq -r '.totals.zen_convertible_collected // 0' "$project_file")
                local g1_target=$(jq -r '.totals.g1_target // 0' "$project_file")
                local g1_collected=$(jq -r '.totals.g1_collected // 0' "$project_file")
                local bien_npub=$(jq -r '.bien_identity.npub // "N/A"' "$project_file")
                local bien_g1pub=$(jq -r '.bien_identity.g1pub // "N/A"' "$project_file")
                
                # Calculate progress
                local zen_pct=0
                [[ "$zen_target" != "0" ]] && zen_pct=$(echo "scale=0; $zen_collected * 100 / $zen_target" | bc -l 2>/dev/null || echo "0")
                
                total_zen_target=$(echo "$total_zen_target + $zen_target" | bc -l)
                total_zen_collected=$(echo "$total_zen_collected + $zen_collected" | bc -l)
                
                # Status color
                local status_color=""
                local status_icon=""
                case "$status" in
                    "draft") status_color="$DIM"; status_icon="📝" ;;
                    "vote_pending") status_color="$MAGENTA"; status_icon="🗳️"; active_count=$((active_count + 1)) ;;
                    "crowdfunding") status_color="$GREEN"; status_icon="🚀"; active_count=$((active_count + 1)) ;;
                    "funded") status_color="$CYAN"; status_icon="💰" ;;
                    "completed") status_color="$BLUE"; status_icon="✅" ;;
                    *) status_color="$NC"; status_icon="❓" ;;
                esac
                
                echo -e "${BOLD}[$count] ${WHITE}$name${NC}"
                echo -e "    ${DIM}ID:${NC} ${CYAN}$project_id${NC}"
                echo -e "    ${DIM}Status:${NC} ${status_color}$status_icon $status${NC}"
                echo -e "    ${DIM}Localisation:${NC} ($lat, $lon)"
                
                if [[ "$bien_npub" != "N/A" ]]; then
                    echo -e "    ${DIM}Bien NOSTR:${NC} ${MAGENTA}${bien_npub:0:20}...${NC}"
                    echo -e "    ${DIM}Bien Ğ1:${NC} ${GREEN}${bien_g1pub:0:8}...${NC}"
                    
                    # Check Bien wallet balance
                    if [[ "$bien_g1pub" != "N/A" ]]; then
                        local bien_balance=$(get_wallet_balance "$bien_g1pub")
                        local bien_zen=$(echo "scale=2; ($bien_balance - 1) * 10" | bc -l 2>/dev/null || echo "0")
                        [[ $(echo "$bien_zen < 0" | bc -l) -eq 1 ]] && bien_zen="0"
                        echo -e "    ${DIM}Solde Bien:${NC} ${YELLOW}${bien_balance} Ğ1 (~${bien_zen} Ẑen)${NC}"
                    fi
                fi
                
                if [[ "$zen_target" != "0" ]]; then
                    echo -e "    ${DIM}Ẑen:${NC} ${zen_collected}/${zen_target} (${zen_pct}%)"
                fi
                if [[ "$g1_target" != "0" ]]; then
                    echo -e "    ${DIM}Ğ1:${NC} ${g1_collected}/${g1_target}"
                fi
                echo ""
            fi
        done
    fi
    
    if [[ $count -eq 0 ]]; then
        echo -e "${DIM}  Aucun projet crowdfunding trouvé${NC}"
        echo ""
    else
        draw_line "="
        echo -e "${BOLD}Total: $count projets ($active_count actifs)${NC}"
        echo -e "${DIM}Objectif Ẑen total: $total_zen_target | Collecté: $total_zen_collected${NC}"
    fi
}

# Show project details
show_project_details() {
    local project_id="$1"
    
    if [[ -z "$project_id" ]]; then
        echo -e "${RED}❌ ID du projet requis${NC}"
        return 1
    fi
    
    # Call CROWDFUNDING.sh status
    "$CROWDFUNDING_TOOL" status "$project_id"
}

################################################################################
# Workflow Actions
################################################################################

# Create new project
action_create_project() {
    show_section "CRÉER UN NOUVEAU PROJET" "➕"
    
    echo -e "${CYAN}Ce workflow va créer un nouveau projet crowdfunding avec:${NC}"
    echo "  1. Identité NOSTR du Bien (npub/nsec)"
    echo "  2. Wallet Ğ1 du Bien (receveur de contributions)"
    echo "  3. Structure du projet (propriétaires, objectifs)"
    echo ""
    
    read -p "Latitude (ex: 43.60): " lat
    read -p "Longitude (ex: 1.44): " lon
    read -p "Nom du projet: " name
    read -p "Description: " description
    
    if [[ -z "$lat" || -z "$lon" || -z "$name" ]]; then
        echo -e "${RED}❌ Coordonnées et nom requis${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}Création du projet...${NC}"
    "$CROWDFUNDING_TOOL" create "$lat" "$lon" "$name" "$description"
    
    echo ""
    echo -e "${YELLOW}💡 Prochaines étapes:${NC}"
    echo "  1. Publier le profil NOSTR du Bien"
    echo "  2. Ajouter les propriétaires avec leur mode (commons/cash)"
    echo "  3. Lancer la campagne"
}

# Add owner to project
action_add_owner() {
    local project_id="$1"
    
    if [[ -z "$project_id" ]]; then
        read -p "ID du projet: " project_id
    fi
    
    show_section "AJOUTER UN PROPRIÉTAIRE" "👥"
    
    echo -e "${CYAN}Modes disponibles:${NC}"
    echo "  ${GREEN}commons${NC} - Donation aux Communs (Ẑen non-convertible €)"
    echo "           → Accès à tous les lieux UPlanet ẐEN"
    echo "  ${YELLOW}cash${NC}    - Vente en € (nécessite vote ASSETS si fonds insuffisants)"
    echo "           → Liquidité immédiate"
    echo ""
    
    read -p "Email du propriétaire: " email
    read -p "Mode (commons/cash): " mode
    read -p "Montant: " amount
    
    if [[ "$mode" == "cash" ]]; then
        echo ""
        echo -e "${YELLOW}⚠️  Mode CASH sélectionné${NC}"
        echo "  Si les fonds ASSETS sont insuffisants, un vote sera lancé."
        echo "  Si le vote échoue, une campagne crowdfunding sera créée."
    fi
    
    echo ""
    "$CROWDFUNDING_TOOL" add-owner "$project_id" "$email" "$mode" "$amount"
}

# Publish Bien profile
action_publish_profile() {
    local project_id="$1"
    
    if [[ -z "$project_id" ]]; then
        read -p "ID du projet: " project_id
    fi
    
    show_section "PUBLIER LE PROFIL NOSTR DU BIEN" "📡"
    
    echo -e "${CYAN}Cette action va:${NC}"
    echo "  1. Créer un profil NOSTR pour le Bien (kind 0)"
    echo "  2. Le rendre visible sur les relays"
    echo "  3. Permettre la réception de +ZEN via les réactions"
    echo ""
    
    "$CROWDFUNDING_TOOL" publish-profile "$project_id"
}

# Check vote status
action_vote_status() {
    local project_id="$1"
    
    if [[ -z "$project_id" ]]; then
        read -p "ID du projet: " project_id
    fi
    
    "$CROWDFUNDING_TOOL" vote-status "$project_id"
}

# Finalize project
action_finalize() {
    local project_id="$1"
    
    if [[ -z "$project_id" ]]; then
        read -p "ID du projet: " project_id
    fi
    
    show_section "FINALISER LE PROJET" "✅"
    
    echo -e "${YELLOW}⚠️  ATTENTION: Cette action va exécuter les transferts blockchain!${NC}"
    echo ""
    echo "Actions effectuées:"
    echo "  1. Transfert des Ẑen Commons vers CAPITAL"
    echo "  2. Transfert des fonds Cash vers les propriétaires"
    echo "  3. Mise à jour des DIDs"
    echo "  4. Publication du statut final sur NOSTR"
    echo ""
    
    read -p "Confirmer la finalisation ? (oui/non): " confirm
    
    if [[ "$confirm" == "oui" ]]; then
        "$CROWDFUNDING_TOOL" finalize "$project_id"
    else
        echo -e "${DIM}Finalisation annulée${NC}"
    fi
}

# Check Bien balance
action_bien_balance() {
    local project_id="$1"
    
    if [[ -z "$project_id" ]]; then
        read -p "ID du projet: " project_id
    fi
    
    "$CROWDFUNDING_TOOL" bien-balance "$project_id"
}

# Regenerate Bien keys
action_regenerate_keys() {
    local project_id="$1"
    
    if [[ -z "$project_id" ]]; then
        read -p "ID du projet: " project_id
    fi
    
    show_section "RÉGÉNÉRER LES CLÉS DU BIEN" "🔄"
    
    echo -e "${CYAN}Les clés du Bien sont déterministes.${NC}"
    echo "Cette action régénère les mêmes clés à partir des coordonnées."
    echo "Utile pour: récupération, synchronisation swarm, vérification."
    echo ""
    
    "$CROWDFUNDING_TOOL" regenerate-keys "$project_id"
}

################################################################################
# Interactive Menu
################################################################################

show_main_menu() {
    show_banner
    show_wallets_status
    
    echo -e "${BOLD}${WHITE}📋 MENU PRINCIPAL${NC}"
    draw_line "-"
    echo ""
    echo -e "  ${GREEN}1${NC}) 📊 Dashboard complet"
    echo -e "  ${GREEN}2${NC}) 🌳 Liste des projets"
    echo -e "  ${GREEN}3${NC}) ➕ Créer un nouveau projet"
    echo -e "  ${GREEN}4${NC}) 👁️  Voir détails d'un projet"
    echo ""
    echo -e "  ${CYAN}5${NC}) 📡 Publier profil NOSTR d'un Bien"
    echo -e "  ${CYAN}6${NC}) 👥 Ajouter un propriétaire"
    echo -e "  ${CYAN}7${NC}) 🗳️  Vérifier statut d'un vote"
    echo -e "  ${CYAN}8${NC}) 💰 Vérifier solde d'un Bien"
    echo ""
    echo -e "  ${YELLOW}9${NC}) ✅ Finaliser un projet"
    echo -e "  ${YELLOW}10${NC}) 🔄 Régénérer clés d'un Bien"
    echo ""
    echo -e "  ${MAGENTA}h${NC}) 📖 Aide complète"
    echo -e "  ${RED}q${NC}) 🚪 Quitter"
    echo ""
    draw_line "-"
    read -p "Votre choix: " choice
    
    case "$choice" in
        1) show_dashboard ;;
        2) list_projects_detailed ;;
        3) action_create_project ;;
        4) 
            read -p "ID du projet: " pid
            show_project_details "$pid"
            ;;
        5)
            read -p "ID du projet: " pid
            action_publish_profile "$pid"
            ;;
        6)
            read -p "ID du projet: " pid
            action_add_owner "$pid"
            ;;
        7)
            read -p "ID du projet: " pid
            action_vote_status "$pid"
            ;;
        8)
            read -p "ID du projet: " pid
            action_bien_balance "$pid"
            ;;
        9)
            read -p "ID du projet: " pid
            action_finalize "$pid"
            ;;
        10)
            read -p "ID du projet: " pid
            action_regenerate_keys "$pid"
            ;;
        h|H|help) show_help_complete ;;
        q|Q|quit|exit) exit 0 ;;
        *) 
            echo -e "${RED}❌ Choix invalide${NC}"
            ;;
    esac
    
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
    show_main_menu
}

# Full dashboard
show_dashboard() {
    show_banner
    show_wallets_status
    list_projects_detailed
}

################################################################################
# Help System
################################################################################

show_help_complete() {
    show_banner
    
    cat << 'EOF'

╔══════════════════════════════════════════════════════════════════════════════╗
║                        📖 GUIDE COMPLET DU CAPITAINE                          ║
╚══════════════════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────────────────────────────────────────┐
│  🎯 OBJECTIF                                                                 │
│                                                                              │
│  Gérer les projets de crowdfunding pour l'acquisition de Biens Communs:     │
│  forêts jardins, terrains, locaux, équipements, infrastructure...           │
│                                                                              │
│  Chaque "Bien" possède sa propre identité NOSTR et son wallet Ğ1,           │
│  permettant de recevoir directement les contributions +ZEN.                 │
└─────────────────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
🔄 WORKFLOW COMPLET - ÉTAPE PAR ÉTAPE
═══════════════════════════════════════════════════════════════════════════════

ÉTAPE 1: CRÉATION DU PROJET
───────────────────────────
  $ ./UPLANET.crowdfunding.sh create 43.60 1.44 "Forêt Enchantée" "Description"

  Ce qui se passe:
  ✓ Génération automatique de l'identité NOSTR du Bien (npub/nsec)
  ✓ Création du wallet Ğ1 du Bien
  ✓ Création du fichier projet avec métadonnées
  ✓ Les clés sont DÉTERMINISTES (régénérables sur n'importe quel nœud)

  Sortie attendue:
  - ID du projet: CF-YYYYMMDD-XXXXXXXX
  - NOSTR npub: npub1xxx...
  - Ğ1 wallet: GfCHe...

ÉTAPE 2: PUBLICATION DU PROFIL NOSTR
────────────────────────────────────
  $ ./UPLANET.crowdfunding.sh publish-profile CF-YYYYMMDD-XXXXXXXX

  Ce qui se passe:
  ✓ Création d'un profil kind 0 pour le Bien
  ✓ Publication sur les relays NOSTR
  ✓ Le Bien devient visible et peut recevoir des +ZEN

ÉTAPE 3: AJOUT DES PROPRIÉTAIRES
────────────────────────────────
  # Mode COMMONS (donation aux Communs)
  $ ./UPLANET.crowdfunding.sh add-owner CF-XXX alice@example.com commons 500
  
  # Mode CASH (vente en €)
  $ ./UPLANET.crowdfunding.sh add-owner CF-XXX bob@example.com cash 1000

  Modes:
  ┌──────────┬────────────────────────────────────────────────────────────┐
  │ COMMONS  │ Ẑen non-convertibles → CAPITAL                            │
  │          │ Avantage: accès à tous les lieux UPlanet ẐEN              │
  ├──────────┼────────────────────────────────────────────────────────────┤
  │ CASH     │ Paiement € depuis ASSETS (ou crowdfunding si insuffisant) │
  │          │ Déclenche un vote si ASSETS disponible                    │
  │          │ Déclenche crowdfunding si ASSETS insuffisant              │
  └──────────┴────────────────────────────────────────────────────────────┘

ÉTAPE 4: GESTION DES VOTES (si mode CASH avec ASSETS suffisant)
───────────────────────────────────────────────────────────────
  $ ./UPLANET.crowdfunding.sh vote-status CF-XXX

  Conditions d'approbation:
  ✓ Seuil Ẑen atteint (ASSETS_VOTE_THRESHOLD)
  ✓ Quorum de votants atteint (ASSETS_VOTE_QUORUM)
  
  Les sociétaires votent via crowdfunding.html ou réactions NOSTR kind 7
  avec le tag ["t", "vote-assets"]

ÉTAPE 5: RÉCEPTION DES CONTRIBUTIONS
────────────────────────────────────
  Les contributions arrivent de deux façons:

  1. Via crowdfunding.html (interface web)
     → L'utilisateur connecté envoie +ZEN (kind 7)
     → Tag ["p", BIEN_HEX] cible le Bien
     → Tag ["t", "crowdfunding"] identifie la contribution

  2. Via transfert Ğ1 direct
     → Vers le wallet du Bien
     → Commentaire: CF:{PROJECT_ID}

  Pour vérifier le solde reçu:
  $ ./UPLANET.crowdfunding.sh bien-balance CF-XXX

ÉTAPE 6: FINALISATION
─────────────────────
  $ ./UPLANET.crowdfunding.sh finalize CF-XXX

  Actions exécutées:
  ✓ Transfert des Ẑen Commons vers CAPITAL
  ✓ Transfert des fonds Cash vers les propriétaires
  ✓ Mise à jour des DIDs avec le statut final
  ✓ Publication du résultat sur NOSTR

═══════════════════════════════════════════════════════════════════════════════
💰 SYSTÈME DE PORTEFEUILLES
═══════════════════════════════════════════════════════════════════════════════

  ┌───────────────────┐
  │   CONTRIBUTIONS   │
  │ (crowdfunding.html│
  │  ou +ZEN NOSTR)   │
  └─────────┬─────────┘
            │
            ▼
  ┌───────────────────┐
  │  WALLET DU BIEN   │ ← Chaque projet a son propre wallet
  │   (bien.dunikey)  │
  └─────────┬─────────┘
            │
            │ À la finalisation:
            ▼
  ┌─────────────────────────────────────────────────────────────┐
  │                     RÉPARTITION                              │
  ├─────────────────────────────────────────────────────────────┤
  │  Mode COMMONS →  CAPITAL (Ẑen non-convertible)              │
  │  Mode CASH    →  Propriétaire (via ASSETS ou crowdfunding)  │
  └─────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
🔐 IDENTITÉ DU BIEN (BIEN IDENTITY)
═══════════════════════════════════════════════════════════════════════════════

  Chaque projet possède une identité dérivée de ses coordonnées:

  BIEN_SALT   = ${UPLANETNAME}${LAT}_${PROJECT_ID}
  BIEN_PEPPER = ${UPLANETNAME}${LON}_${PROJECT_ID}

  Avantages:
  ✓ DÉTERMINISTE: régénérable sur n'importe quel nœud du swarm
  ✓ UNIQUE: lié aux coordonnées UMAP et à l'ID du projet
  ✓ TRAÇABLE: toutes les contributions sont visibles sur blockchain

  Fichiers générés:
  ~/.zen/game/crowdfunding/{PROJECT_ID}/
  ├── project.json       # Métadonnées (inclut bien_identity)
  ├── bien.pubkeys       # Clés publiques
  ├── bien.dunikey       # Wallet Ğ1
  └── .bien.nostr        # Secret NOSTR

═══════════════════════════════════════════════════════════════════════════════
📋 COMMANDES CLI
═══════════════════════════════════════════════════════════════════════════════

  ./UPLANET.crowdfunding.sh                    # Menu interactif
  ./UPLANET.crowdfunding.sh dashboard          # Vue d'ensemble
  ./UPLANET.crowdfunding.sh list               # Liste des projets
  
  ./UPLANET.crowdfunding.sh create LAT LON "NOM" "DESC"
  ./UPLANET.crowdfunding.sh publish-profile PROJECT_ID
  ./UPLANET.crowdfunding.sh add-owner PROJECT_ID EMAIL MODE AMOUNT
  ./UPLANET.crowdfunding.sh status PROJECT_ID
  ./UPLANET.crowdfunding.sh vote-status PROJECT_ID
  ./UPLANET.crowdfunding.sh bien-balance PROJECT_ID
  ./UPLANET.crowdfunding.sh regenerate-keys PROJECT_ID
  ./UPLANET.crowdfunding.sh finalize PROJECT_ID
  
  ./UPLANET.crowdfunding.sh --help             # Cette aide

═══════════════════════════════════════════════════════════════════════════════
❓ DÉPANNAGE
═══════════════════════════════════════════════════════════════════════════════

  Q: Le Bien ne reçoit pas les +ZEN
  R: Vérifiez que le profil NOSTR est publié (publish-profile)
     Vérifiez que crowdfunding.html utilise bien le BIEN_HEX dans le tag ["p"]

  Q: Les clés du Bien sont différentes sur un autre nœud
  R: Utilisez regenerate-keys - les clés sont déterministes et seront identiques

  Q: Le vote n'avance pas
  R: Vérifiez les seuils (ASSETS_VOTE_THRESHOLD, ASSETS_VOTE_QUORUM)
     Les votes arrivent via kind 7 avec tag ["t", "vote-assets"]

  Q: Comment voir les contributions blockchain?
  R: Utilisez bien-balance pour voir le solde du wallet du Bien
     Ou consultez un explorateur Ğ1 avec l'adresse bien_identity.g1pub

EOF
}

# Short help
show_help_short() {
    echo ""
    echo -e "${BLUE}UPLANET.crowdfunding.sh - Gestion des projets Crowdfunding${NC}"
    echo ""
    echo "Usage:"
    echo "  $0                              # Menu interactif"
    echo "  $0 [command] [options]          # Commande directe"
    echo ""
    echo "Commandes:"
    echo "  dashboard                       Vue d'ensemble complète"
    echo "  list                            Liste des projets"
    echo "  create LAT LON NOM DESC         Créer un nouveau projet"
    echo "  publish-profile PROJECT_ID      Publier profil NOSTR du Bien"
    echo "  add-owner PROJECT_ID ...        Ajouter un propriétaire"
    echo "  status PROJECT_ID               Statut détaillé"
    echo "  vote-status PROJECT_ID          Statut du vote"
    echo "  bien-balance PROJECT_ID         Solde du wallet du Bien"
    echo "  regenerate-keys PROJECT_ID      Régénérer les clés"
    echo "  finalize PROJECT_ID             Finaliser le projet"
    echo ""
    echo "Options:"
    echo "  --help, -h                      Aide complète"
    echo ""
}

################################################################################
# Main Entry Point
################################################################################

case "$1" in
    "dashboard"|"dash")
        show_dashboard
        ;;
    "list"|"ls")
        list_projects_detailed
        ;;
    "create")
        if [[ -n "$2" && -n "$3" && -n "$4" ]]; then
            "$CROWDFUNDING_TOOL" create "$2" "$3" "$4" "$5"
        else
            action_create_project
        fi
        ;;
    "publish-profile")
        action_publish_profile "$2"
        ;;
    "add-owner")
        if [[ -n "$2" ]]; then
            "$CROWDFUNDING_TOOL" add-owner "$2" "$3" "$4" "$5" "$6"
        else
            action_add_owner
        fi
        ;;
    "status")
        show_project_details "$2"
        ;;
    "vote-status")
        action_vote_status "$2"
        ;;
    "bien-balance")
        action_bien_balance "$2"
        ;;
    "regenerate-keys")
        action_regenerate_keys "$2"
        ;;
    "finalize")
        action_finalize "$2"
        ;;
    "wallets")
        show_wallets_status
        ;;
    "help"|"-h"|"--help")
        show_help_complete
        ;;
    "")
        # No argument - show interactive menu
        show_main_menu
        ;;
    *)
        echo -e "${RED}❌ Commande inconnue: $1${NC}"
        show_help_short
        exit 1
        ;;
esac
