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
    echo ""
    echo "Types de mise à jour:"
    echo "  LOCATAIRE                    - Recharge MULTIPASS"
    echo "  SOCIETAIRE_SATELLITE        - Parts sociales satellite"
    echo "  SOCIETAIRE_CONSTELLATION    - Parts sociales constellation"
    echo "  INFRASTRUCTURE              - Apport capital infrastructure"
    echo "  WOT_MEMBER                  - Identification WoT Duniter"
    echo ""
    echo "Exemples:"
    echo "  $0 update user@example.com LOCATAIRE 50 5.0"
    echo "  $0 update user@example.com WOT_MEMBER 0 0 5fTwfbYUtCeoaFLbyzaBYUcq46nBS26rciWJAkBugqpo"
    echo "  $0 validate user@example.com"
    echo "  $0 sync user@example.com"
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
