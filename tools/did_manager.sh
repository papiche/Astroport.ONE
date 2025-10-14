#!/bin/bash
################################################################################
# Script: did_manager.sh
# Description: Gestionnaire centralisé des documents DID
# 
# Centralise toutes les opérations sur les documents DID pour éviter
# les conflits et assurer la cohérence dans l'écosystème UPlanet
################################################################################

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/my.sh"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

################################################################################
# Fonction principale de mise à jour DID
################################################################################
update_did_document() {
    local email="$1"
    local update_type="$2"  # LOCATAIRE, SOCIETAIRE_SATELLITE, SOCIETAIRE_CONSTELLATION, INFRASTRUCTURE, WOT_MEMBER
    local montant_zen="${3:-0}"
    local montant_g1="${4:-0}"
    local wot_g1pub="${5:-}"
    
    local did_file="$HOME/.zen/game/nostr/${email}/did.json"
    local did_wellknown="$HOME/.zen/game/nostr/${email}/APP/uDRIVE/.well-known/did.json"
    
    # Vérifier que le fichier DID existe
    if [[ ! -f "$did_file" ]]; then
        echo -e "${YELLOW}⚠️  Fichier DID non trouvé pour ${email}, passage ignoré${NC}"
        return 0
    fi
    
    echo -e "${CYAN}📝 Mise à jour DID: ${email} (${update_type})${NC}"
    
    # Afficher l'adresse IPNS de la station Astroport si disponible
    if [[ -n "$IPFSNODEID" ]]; then
        echo -e "${BLUE}🏭 Station Astroport IPNS: ${IPFSNODEID}${NC}"
    fi
    
    # Vérifier et afficher les adresses de portefeuilles disponibles
    local multipass_g1pub=$(cat "$HOME/.zen/game/nostr/${email}/G1PUBNOSTR" 2>/dev/null)
    local zencard_g1pub=$(cat "$HOME/.zen/game/players/${email}/.g1pub" 2>/dev/null)
    
    if [[ -n "$multipass_g1pub" ]]; then
        echo -e "${GREEN}💳 MULTIPASS détecté: ${multipass_g1pub:0:8}...${NC}"
    fi
    
    if [[ -n "$zencard_g1pub" ]]; then
        echo -e "${GREEN}🏦 ZEN Card détecté: ${zencard_g1pub:0:8}...${NC}"
    fi
    
    # Créer une sauvegarde avec timestamp
    local backup_file="${did_file}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$did_file" "$backup_file"
    echo -e "${GREEN}✅ Backup créé: $(basename "$backup_file")${NC}"
    
    # Préparer les métadonnées selon le type de mise à jour
    local quota=""
    local services=""
    local contract_status=""
    local wot_metadata=""
    
    case "$update_type" in
        "LOCATAIRE")
            quota="10GB"
            services="uDRIVE IPFS storage"
            contract_status="active_rental"
            ;;
        "SOCIETAIRE_SATELLITE")
            quota="128GB"
            services="uDRIVE + NextCloud private storage"
            contract_status="cooperative_member_satellite"
            ;;
        "SOCIETAIRE_CONSTELLATION")
            quota="128GB"
            services="uDRIVE + NextCloud + AI services"
            contract_status="cooperative_member_constellation"
            ;;
        "INFRASTRUCTURE")
            quota="N/A"
            services="Node infrastructure capital"
            contract_status="infrastructure_contributor"
            ;;
        "TREASURY_CONTRIBUTION")
            # Contribution au fonds trésorerie coopératif
            contract_status="cooperative_treasury_contributor"
            ;;
        "RND_CONTRIBUTION")
            # Contribution au fonds R&D coopératif
            contract_status="cooperative_rnd_contributor"
            ;;
        "ASSETS_CONTRIBUTION")
            # Contribution au fonds actifs coopératif
            contract_status="cooperative_assets_contributor"
            ;;
        "WOT_MEMBER")
            if [[ -n "$wot_g1pub" ]]; then
                wot_metadata="{
                    \"g1pub\": \"$wot_g1pub\",
                    \"cesiumLink\": \"$CESIUMIPFS/#/app/wot/$wot_g1pub/\",
                    \"verifiedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
                    \"description\": \"WoT Duniter member forge (external to UPlanet)\"
                }"
            fi
            ;;
        *)
            echo -e "${YELLOW}⚠️  Type de mise à jour non reconnu: ${update_type}${NC}"
            return 1
            ;;
    esac
    
    # Utiliser jq pour mettre à jour le DID de manière atomique
    local temp_did=$(mktemp)
    
    # Construction de la commande jq dynamique
    local jq_cmd=".metadata.updated = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
    
    if [[ -n "$contract_status" ]]; then
        jq_cmd="$jq_cmd | .metadata.contractStatus = \"$contract_status\""
    fi
    
    if [[ -n "$quota" ]]; then
        jq_cmd="$jq_cmd | .metadata.storageQuota = \"$quota\""
    fi
    
    if [[ -n "$services" ]]; then
        jq_cmd="$jq_cmd | .metadata.services = \"$services\""
    fi
    
    if [[ "$montant_zen" != "0" ]]; then
        jq_cmd="$jq_cmd | .metadata.lastPayment = {
            \"amount_zen\": \"$montant_zen\",
            \"amount_g1\": \"$montant_g1\",
            \"date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
            \"nodeId\": \"$IPFSNODEID\"
        }"
    fi
    
    if [[ -n "$wot_metadata" ]]; then
        jq_cmd="$jq_cmd | .metadata.wotDuniterMember = $wot_metadata"
    fi
    
    # Ajouter l'adresse IPNS de la station Astroport
    if [[ -n "$IPFSNODEID" ]]; then
        jq_cmd="$jq_cmd | .metadata.astroportStation = {
            \"ipns\": \"$IPFSNODEID\",
            \"description\": \"Astroport station IPNS address\",
            \"updatedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
        }"
    fi
    
    # Ajouter l'adresse MULTIPASS (Ẑ revenue) si disponible
    local multipass_g1pub=$(cat "$HOME/.zen/game/nostr/${email}/G1PUBNOSTR" 2>/dev/null)
    if [[ -n "$multipass_g1pub" ]]; then
        jq_cmd="$jq_cmd | .metadata.multipassWallet = {
            \"g1pub\": \"$multipass_g1pub\",
            \"type\": \"MULTIPASS\",
            \"description\": \"Ẑ revenue wallet for service operations\",
            \"updatedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
        }"
    fi
    
    # Ajouter l'adresse ZEN Card (Ẑ society) si disponible
    local zencard_g1pub=$(cat "$HOME/.zen/game/players/${email}/.g1pub" 2>/dev/null)
    if [[ -n "$zencard_g1pub" ]]; then
        jq_cmd="$jq_cmd | .metadata.zencardWallet = {
            \"g1pub\": \"$zencard_g1pub\",
            \"type\": \"ZEN_CARD\",
            \"description\": \"Ẑ society wallet for cooperative shares\",
            \"updatedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
        }"
    fi
    
    # Exécuter la mise à jour
    if jq "$jq_cmd" "$did_file" > "$temp_did" && [[ -s "$temp_did" ]]; then
        # Remplacer le fichier original
        mv "$temp_did" "$did_file"
        echo -e "${GREEN}✅ DID racine mis à jour: ${did_file}${NC}"
        
        # Synchroniser vers .well-known si le répertoire existe
        if [[ -d "$(dirname "$did_wellknown")" ]]; then
            cp "$did_file" "$did_wellknown"
            echo -e "${GREEN}✅ DID .well-known synchronisé: ${did_wellknown}${NC}"
        fi
        
        # Republier sur IPNS si possible
        republish_did_ipns "$email"
        
        # Gérer le fichier U.SOCIETY si nécessaire
        manage_usociety_file "$email" "$update_type" "$montant_zen"
        
        # Nettoyer les anciens backups (garder seulement les 5 derniers)
        cleanup_old_backups "$did_file"
        
        return 0
    else
        echo -e "${RED}❌ Erreur lors de la mise à jour du DID${NC}"
        rm -f "$temp_did"
        return 1
    fi
}

################################################################################
# Fonction de republication IPNS
################################################################################
republish_did_ipns() {
    local email="$1"
    local nostrns_file="$HOME/.zen/game/nostr/${email}/NOSTRNS"
    
    if [[ -f "$nostrns_file" ]]; then
        local nostrns=$(cat "$nostrns_file" | cut -d'/' -f3)
        local g1pubnostr=$(cat "$HOME/.zen/game/nostr/${email}/G1PUBNOSTR" 2>/dev/null)
        
        if [[ -n "$g1pubnostr" ]]; then
            echo -e "${CYAN}📡 Republication IPNS...${NC}"
            local nostripfs=$(ipfs add -rwq "$HOME/.zen/game/nostr/${email}/" | tail -n 1)
            ipfs name publish --key "${g1pubnostr}:NOSTR" "/ipfs/${nostripfs}" 2>&1 >/dev/null &
            echo -e "${GREEN}✅ Publication IPNS lancée en arrière-plan${NC}"
        fi
    fi
}

################################################################################
# Fonction de nettoyage des anciens backups
################################################################################
cleanup_old_backups() {
    local did_file="$1"
    local backup_dir=$(dirname "$did_file")
    local email=$(basename "$(dirname "$did_file")")
    
    # Garder seulement les 5 derniers backups
    ls -t "${backup_dir}/did.json.backup."* 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null
    
    echo -e "${CYAN}🧹 Nettoyage des anciens backups (gardé 5 derniers)${NC}"
}

################################################################################
# Fonction de validation du DID
################################################################################
validate_did_document() {
    local did_file="$1"
    
    if [[ ! -f "$did_file" ]]; then
        echo -e "${RED}❌ Fichier DID non trouvé: $did_file${NC}"
        return 1
    fi
    
    # Vérifier que le JSON est valide
    if ! jq empty "$did_file" 2>/dev/null; then
        echo -e "${RED}❌ DID JSON invalide: $did_file${NC}"
        return 1
    fi
    
    # Vérifier les champs obligatoires
    local required_fields=("id" "verificationMethod" "authentication")
    for field in "${required_fields[@]}"; do
        if ! jq -e ".$field" "$did_file" >/dev/null 2>&1; then
            echo -e "${RED}❌ Champ obligatoire manquant: $field${NC}"
            return 1
        fi
    done
    
    echo -e "${GREEN}✅ DID document valide: $did_file${NC}"
    return 0
}

################################################################################
# Fonction de gestion du fichier U.SOCIETY
################################################################################
manage_usociety_file() {
    local email="$1"
    local update_type="$2"  # SOCIETAIRE_SATELLITE, SOCIETAIRE_CONSTELLATION, INFRASTRUCTURE
    local montant_zen="${3:-0}"
    
    # Vérifier que le type nécessite la création d'un fichier U.SOCIETY
    case "$update_type" in
        "SOCIETAIRE_SATELLITE"|"SOCIETAIRE_CONSTELLATION"|"INFRASTRUCTURE")
            ;;
        *)
            # Pas de fichier U.SOCIETY pour les autres types
            return 0
            ;;
    esac
    
    echo -e "${CYAN}📝 Gestion fichier U.SOCIETY: ${email} (${update_type})${NC}"
    
    # Vérifier que le dossier player existe
    if [[ ! -d "$HOME/.zen/game/players/${email}" ]]; then
        echo -e "${YELLOW}⚠️  Dossier player non trouvé pour ${email}, création du fichier U.SOCIETY ignorée${NC}"
        return 0
    fi
    
    # Créer le fichier U.SOCIETY avec la date actuelle
    local society_date=$(date '+%Y-%m-%d')
    local usociety_file="$HOME/.zen/game/players/${email}/U.SOCIETY"
    local usociety_end_file="$HOME/.zen/game/players/${email}/U.SOCIETY.end"
    
    echo "$society_date" > "$usociety_file"
    echo -e "${GREEN}✅ Fichier U.SOCIETY créé: ${usociety_file}${NC}"
    
    # Calculer et créer la date de fin d'abonnement
    local end_date
    case "$update_type" in
        "SOCIETAIRE_SATELLITE")
            end_date=$(date -d "$society_date + 365 days" '+%Y-%m-%d')
            ;;
        "SOCIETAIRE_CONSTELLATION")
            end_date=$(date -d "$society_date + 1095 days" '+%Y-%m-%d')  # 3 ans
            ;;
        "INFRASTRUCTURE")
            end_date="9999-12-31"  # Permanent
            ;;
    esac
    
    echo "$end_date" > "$usociety_end_file"
    echo -e "${GREEN}✅ Fichier U.SOCIETY.end créé: ${usociety_end_file} (expire: ${end_date})${NC}"
    
    # Créer un lien symbolique dans le dossier nostr si il existe
    if [[ -d "$HOME/.zen/game/nostr/${email}" ]]; then
        ln -sf "$usociety_file" "$HOME/.zen/game/nostr/${email}/U.SOCIETY"
        ln -sf "$usociety_end_file" "$HOME/.zen/game/nostr/${email}/U.SOCIETY.end"
        echo -e "${GREEN}✅ Liens symboliques U.SOCIETY créés dans nostr/${NC}"
    fi
    
    # Déterminer le type d'abonnement et la durée
    local subscription_type=""
    local duration_days=""
    
    case "$update_type" in
        "SOCIETAIRE_SATELLITE")
            subscription_type="RPi Share (1 year)"
            duration_days=365
            ;;
        "SOCIETAIRE_CONSTELLATION")
            subscription_type="PC Share (3 years)"
            duration_days=1095
            ;;
        "INFRASTRUCTURE")
            subscription_type="Infrastructure Capital (permanent)"
            duration_days=999999  # Permanent
            ;;
    esac
    
    echo -e "${BLUE}📊 Détails U.SOCIETY:${NC}"
    echo -e "  • Type: ${subscription_type}"
    echo -e "  • Date début: ${society_date}"
    echo -e "  • Durée: ${duration_days} jours"
    echo -e "  • Montant: ${montant_zen} Ẑen"
    
    return 0
}

################################################################################
# Fonction de synchronisation entre les deux emplacements
################################################################################
sync_did_locations() {
    local email="$1"
    local did_file="$HOME/.zen/game/nostr/${email}/did.json"
    local did_wellknown="$HOME/.zen/game/nostr/${email}/APP/uDRIVE/.well-known/did.json"
    
    if [[ ! -f "$did_file" ]]; then
        echo -e "${RED}❌ Fichier DID principal non trouvé: $did_file${NC}"
        return 1
    fi
    
    # Créer le répertoire .well-known si nécessaire
    mkdir -p "$(dirname "$did_wellknown")"
    
    # Copier le DID principal vers .well-known
    cp "$did_file" "$did_wellknown"
    echo -e "${GREEN}✅ DID synchronisé vers .well-known${NC}"
    
    return 0
}

################################################################################
# Fonction d'affichage de l'adresse IPNS de la station Astroport
################################################################################
show_astroport_ipns() {
    if [[ -n "$IPFSNODEID" ]]; then
        echo -e "${BLUE}🏭 Station Astroport IPNS: ${IPFSNODEID}${NC}"
        echo -e "${CYAN}📡 Cette adresse IPNS identifie cette station Astroport dans l'écosystème UPlanet${NC}"
    else
        echo -e "${YELLOW}⚠️  Variable IPFSNODEID non définie${NC}"
        echo -e "${CYAN}💡 Assurez-vous que la variable IPFSNODEID est correctement configurée${NC}"
    fi
}

################################################################################
# Fonction d'affichage des adresses de portefeuilles
################################################################################
show_wallet_addresses() {
    local email="$1"
    
    if [[ -z "$email" ]]; then
        echo -e "${RED}❌ Usage: $0 show-wallets EMAIL${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🔍 Adresses de portefeuilles pour: ${email}${NC}"
    echo -e "${YELLOW}================================${NC}"
    
    # Vérifier MULTIPASS (Ẑ revenue)
    local multipass_g1pub=$(cat "$HOME/.zen/game/nostr/${email}/G1PUBNOSTR" 2>/dev/null)
    if [[ -n "$multipass_g1pub" ]]; then
        echo -e "${GREEN}💳 MULTIPASS (Ẑ revenue):${NC}"
        echo -e "   ${CYAN}G1PUB: ${multipass_g1pub}${NC}"
        echo -e "   ${CYAN}Type: Service operations wallet${NC}"
    else
        echo -e "${YELLOW}⚠️  MULTIPASS non trouvé${NC}"
    fi
    
    # Vérifier ZEN Card (Ẑ society)
    local zencard_g1pub=$(cat "$HOME/.zen/game/players/${email}/.g1pub" 2>/dev/null)
    if [[ -n "$zencard_g1pub" ]]; then
        echo -e "${GREEN}🏦 ZEN Card (Ẑ society):${NC}"
        echo -e "   ${CYAN}G1PUB: ${zencard_g1pub}${NC}"
        echo -e "   ${CYAN}Type: Cooperative shares wallet${NC}"
    else
        echo -e "${YELLOW}⚠️  ZEN Card non trouvé${NC}"
    fi
    
    # Vérifier l'adresse IPNS de la station
    if [[ -n "$IPFSNODEID" ]]; then
        echo -e "${GREEN}🏭 Station Astroport:${NC}"
        echo -e "   ${CYAN}IPNS: ${IPFSNODEID}${NC}"
        echo -e "   ${CYAN}Type: Station identification${NC}"
    else
        echo -e "${YELLOW}⚠️  Station Astroport non configurée${NC}"
    fi
}

################################################################################
# Fonction d'aide
################################################################################
show_help() {
    echo -e "${BLUE}did_manager.sh - Gestionnaire centralisé des documents DID${NC}"
    echo ""
    echo "Usage:"
    echo "  $0 update EMAIL TYPE [MONTANT_ZEN] [MONTANT_G1] [WOT_G1PUB]"
    echo "  $0 validate EMAIL"
    echo "  $0 sync EMAIL"
    echo "  $0 republish EMAIL"
    echo "  $0 usociety EMAIL TYPE [MONTANT_ZEN]"
    echo "  $0 astroport-ipns"
    echo "  $0 show-wallets EMAIL"
    echo ""
    echo "Types de mise à jour:"
    echo "  LOCATAIRE                    - Recharge MULTIPASS"
    echo "  SOCIETAIRE_SATELLITE        - Parts sociales satellite"
    echo "  SOCIETAIRE_CONSTELLATION    - Parts sociales constellation"
    echo "  INFRASTRUCTURE              - Apport capital infrastructure"
    echo "  TREASURY_CONTRIBUTION       - Contribution fonds trésorerie"
    echo "  RND_CONTRIBUTION            - Contribution fonds R&D"
    echo "  ASSETS_CONTRIBUTION         - Contribution fonds actifs"
    echo "  WOT_MEMBER                  - Identification WoT Duniter"
    echo ""
    echo "Exemples:"
    echo "  $0 update user@example.com LOCATAIRE 50 5.0"
    echo "  $0 update user@example.com WOT_MEMBER 0 0 5fTwfbYUtCeoaFLbyzaBYUcq46nBS26rciWJAkBugqpo"
    echo "  $0 validate user@example.com"
    echo "  $0 sync user@example.com"
    echo "  $0 usociety user@example.com SOCIETAIRE_SATELLITE 50"
    echo "  $0 astroport-ipns"
    echo "  $0 show-wallets user@example.com"
}

################################################################################
# Point d'entrée principal
################################################################################
main() {
    case "${1:-}" in
        "update")
            if [[ $# -lt 3 ]]; then
                echo -e "${RED}❌ Usage: $0 update EMAIL TYPE [MONTANT_ZEN] [MONTANT_G1] [WOT_G1PUB]${NC}"
                exit 1
            fi
            update_did_document "$2" "$3" "${4:-0}" "${5:-0}" "${6:-}"
            ;;
        "validate")
            if [[ $# -lt 2 ]]; then
                echo -e "${RED}❌ Usage: $0 validate EMAIL${NC}"
                exit 1
            fi
            validate_did_document "$HOME/.zen/game/nostr/$2/did.json"
            ;;
        "sync")
            if [[ $# -lt 2 ]]; then
                echo -e "${RED}❌ Usage: $0 sync EMAIL${NC}"
                exit 1
            fi
            sync_did_locations "$2"
            ;;
        "republish")
            if [[ $# -lt 2 ]]; then
                echo -e "${RED}❌ Usage: $0 republish EMAIL${NC}"
                exit 1
            fi
            republish_did_ipns "$2"
            ;;
        "usociety")
            if [[ $# -lt 3 ]]; then
                echo -e "${RED}❌ Usage: $0 usociety EMAIL TYPE [MONTANT_ZEN]${NC}"
                exit 1
            fi
            manage_usociety_file "$2" "$3" "${4:-0}"
            ;;
        "astroport-ipns")
            show_astroport_ipns
            ;;
        "show-wallets")
            if [[ $# -lt 2 ]]; then
                echo -e "${RED}❌ Usage: $0 show-wallets EMAIL${NC}"
                exit 1
            fi
            show_wallet_addresses "$2"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo -e "${RED}❌ Commande inconnue: ${1:-}${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Exécuter le script principal
main "$@"
