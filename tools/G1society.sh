#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ G1society.sh
#~ Récupère l'historique des parts sociales distribuées
#~ Filtre les transactions entrantes depuis UPLANETNAME_G1 vers SOCIETY
#~ Calcul automatique des montants en Ğ1 et ẐEN
#~ Retourne un JSON formaté pour l'API
################################################################################

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/my.sh"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Nostr configuration
NOSTR_RELAYS="${NOSTR_RELAYS:-ws://127.0.0.1:7777 wss://relay.copylaradio.com}"
NOSTR_DID_CLIENT_SCRIPT="${MY_PATH}/nostr_did_client.py"
DID_EVENT_KIND=30800  # NIP-101 DID Documents (changed from 30311 to avoid NIP-53 conflict)
DID_TAG_IDENTIFIER="did"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

################################################################################
# Fonction pour récupérer seulement les données DID (mode --did)
################################################################################
fetch_did_data_only() {
    echo -e "${BLUE}🔍 Récupération des données DID uniquement...${NC}" >&2
    
    # Scanner les répertoires utilisateurs
    local emails=$(find ~/.zen/game/nostr -name ".secret.nostr" -exec dirname {} \; | xargs -I {} basename {} | sort -u)
    
    if [[ -z "$emails" ]]; then
        echo -e "${YELLOW}⚠️  Aucun utilisateur Nostr trouvé${NC}" >&2
        echo "[]"
        return 0
    fi
    
    local nostr_data="[]"
    local nostr_count=0
    
    # Vérifier si le script nostr_did_client.py existe
    if [[ ! -f "$NOSTR_DID_CLIENT_SCRIPT" ]]; then
        echo -e "${YELLOW}⚠️  Script nostr_did_client.py non trouvé${NC}" >&2
        echo "[]"
        return 0
    fi
    
    while IFS= read -r email; do
        if [[ -z "$email" || "$email" == "N/A" ]]; then
            continue
        fi
        
        echo -e "${CYAN}📧 Récupération DID Nostr pour: ${email}${NC}" >&2
        
        # Récupérer les clés Nostr de l'utilisateur
        local nostr_keys_file="$HOME/.zen/game/nostr/${email}/.secret.nostr"
        if [[ ! -f "$nostr_keys_file" ]]; then
            echo -e "${YELLOW}⚠️  Clés Nostr non trouvées pour ${email}${NC}" >&2
            continue
        fi
        
        # Extraire la clé publique Nostr
        local npub=""
        if source "$nostr_keys_file" 2>/dev/null && [[ -n "$NPUB" ]]; then
            npub="$NPUB"
        else
            echo -e "${YELLOW}⚠️  Impossible d'extraire NPUB pour ${email}${NC}" >&2
            continue
        fi
        
        # Récupérer le DID depuis Nostr
        local did_content=""
        for relay in $NOSTR_RELAYS; do
            echo -e "${BLUE}   Interrogation: ${relay}${NC}" >&2
            
            # Utiliser le script de récupération DID
            did_content=$(python3 "$NOSTR_DID_CLIENT_SCRIPT" fetch --author "$npub" --relay "$relay" --kind "$DID_EVENT_KIND" -q 2>/dev/null)
            
            if [[ -n "$did_content" ]] && [[ "$did_content" != "null" ]] && echo "$did_content" | jq empty 2>/dev/null; then
                echo -e "${GREEN}✅ DID trouvé sur ${relay}${NC}" >&2
                break
            fi
        done
        
        if [[ -z "$did_content" ]] || [[ "$did_content" == "null" ]]; then
            echo -e "${YELLOW}⚠️  Aucun DID trouvé sur Nostr pour ${email}${NC}" >&2
            continue
        fi
        
        # Extraire les informations pertinentes du DID
        local did_info=$(echo "$did_content" | jq -r --arg email "$email" '
        {
            email: $email,
            did_id: .id,
            contract_status: .metadata.contractStatus // "unknown",
            storage_quota: .metadata.storageQuota // "N/A",
            services: .metadata.services // "N/A",
            last_payment: .metadata.lastPayment // null,
            created: .metadata.created // null,
            updated: .metadata.updated // null,
            astroport_station: .metadata.astroportStation // null,
            multipass_wallet: .metadata.multipassWallet // null,
            zencard_wallet: .metadata.zencardWallet // null,
            wot_duniter_member: .metadata.wotDuniterMember // null
        }
        ')
        
        # Ajouter les informations Nostr aux données
        nostr_data=$(echo "$nostr_data" | jq --argjson did_info "$did_info" '. + [$did_info]')
        ((nostr_count++))
        
        echo -e "${GREEN}✅ Données Nostr récupérées pour ${email}${NC}" >&2
        
    done <<< "$emails"
    
    echo -e "${GREEN}📊 ${nostr_count} document(s) DID récupéré(s) depuis Nostr${NC}" >&2
    
    # Retourner les données Nostr
    echo "$nostr_data"
}

################################################################################
# Fonction pour récupérer les données Nostr des parts sociales
################################################################################
fetch_nostr_society_data() {
    local transfers_json="$1"
    
    echo -e "${BLUE}🔍 Récupération des données Nostr pour les parts sociales...${NC}" >&2
    
    # Extraire les emails des transferts ou scanner les répertoires utilisateurs
    local emails=""
    if [[ -n "$transfers_json" ]]; then
        emails=$(echo "$transfers_json" | jq -r '.transfers[]?.recipient // empty' | grep -v "N/A" | sort -u)
    fi
    
    # Si aucun email trouvé dans les transferts, utiliser le script séparé
    if [[ -z "$emails" ]]; then
        echo -e "${YELLOW}⚠️  Aucun email trouvé dans les transferts, utilisation du script DID séparé...${NC}" >&2
        # Utiliser le script nostr_did_client.py pour récupérer les données DID
        local did_result=$(fetch_did_data_only)
        echo "$did_result"
        return 0
    fi
    
    local nostr_data="[]"
    local nostr_count=0
    
    # Vérifier si le script nostr_did_client.py existe
    if [[ ! -f "$NOSTR_DID_CLIENT_SCRIPT" ]]; then
        echo -e "${YELLOW}⚠️  Script nostr_did_client.py non trouvé, impossible de récupérer les données Nostr${NC}" >&2
        return 0
    fi
    
    while IFS= read -r email; do
        if [[ -z "$email" || "$email" == "N/A" ]]; then
            continue
        fi
        
        echo -e "${CYAN}📧 Récupération DID Nostr pour: ${email}${NC}" >&2
        
        # Récupérer les clés Nostr de l'utilisateur
        local nostr_keys_file="$HOME/.zen/game/nostr/${email}/.secret.nostr"
        if [[ ! -f "$nostr_keys_file" ]]; then
            echo -e "${YELLOW}⚠️  Clés Nostr non trouvées pour ${email}${NC}" >&2
            continue
        fi
        
        # Extraire la clé publique Nostr
        local npub=""
        if source "$nostr_keys_file" 2>/dev/null && [[ -n "$NPUB" ]]; then
            npub="$NPUB"
        else
            echo -e "${YELLOW}⚠️  Impossible d'extraire NPUB pour ${email}${NC}" >&2
            continue
        fi
        
        # Récupérer le DID depuis Nostr
        local did_content=""
        for relay in $NOSTR_RELAYS; do
            echo -e "${BLUE}   Interrogation: ${relay}${NC}" >&2
            
            # Utiliser le script de récupération DID
                did_content=$(python3 "$NOSTR_DID_CLIENT_SCRIPT" fetch --author "$npub" --relay "$relay" --kind "$DID_EVENT_KIND" -q 2>/dev/null)
            
            if [[ -n "$did_content" ]] && [[ "$did_content" != "null" ]] && echo "$did_content" | jq empty 2>/dev/null; then
                echo -e "${GREEN}✅ DID trouvé sur ${relay}${NC}" >&2
                break
            fi
        done
        
        if [[ -z "$did_content" ]] || [[ "$did_content" == "null" ]]; then
            echo -e "${YELLOW}⚠️  Aucun DID trouvé sur Nostr pour ${email}${NC}" >&2
            continue
        fi
        
        # Extraire les informations pertinentes du DID
        local did_info=$(echo "$did_content" | jq -r --arg email "$email" '
        {
            email: $email,
            did_id: .id,
            contract_status: .metadata.contractStatus // "unknown",
            storage_quota: .metadata.storageQuota // "N/A",
            services: .metadata.services // "N/A",
            last_payment: .metadata.lastPayment // null,
            created: .metadata.created // null,
            updated: .metadata.updated // null,
            astroport_station: .metadata.astroportStation // null,
            multipass_wallet: .metadata.multipassWallet // null,
            zencard_wallet: .metadata.zencardWallet // null,
            wot_duniter_member: .metadata.wotDuniterMember // null
        }
        ')
        
        # Ajouter les informations Nostr aux données
        nostr_data=$(echo "$nostr_data" | jq --argjson did_info "$did_info" '. + [$did_info]')
        ((nostr_count++))
        
        echo -e "${GREEN}✅ Données Nostr récupérées pour ${email}${NC}" >&2
        
    done <<< "$emails"
    
    echo -e "${GREEN}📊 ${nostr_count} document(s) DID récupéré(s) depuis Nostr${NC}" >&2
    
    # Retourner les données Nostr
    echo "$nostr_data"
}

################################################################################
# Fonction pour vérifier et corriger les fichiers U.SOCIETY
################################################################################
check_and_fix_usociety_files() {
    local transfers_json="$1"
    local fix_mode="${2:-false}"  # true pour corriger, false pour juste vérifier
    
    echo -e "${BLUE}🔍 Vérification des fichiers U.SOCIETY...${NC}" >&2
    
    # Extraire les emails des transferts
    local emails=$(echo "$transfers_json" | jq -r '.transfers[]?.recipient // empty' | grep -v "N/A" | sort -u)
    
    if [[ -z "$emails" ]]; then
        echo -e "${YELLOW}⚠️  Aucun email trouvé dans les transferts${NC}" >&2
        return 0
    fi
    
    local fixed_count=0
    local missing_count=0
    local outdated_count=0
    
    while IFS= read -r email; do
        if [[ -z "$email" || "$email" == "N/A" ]]; then
            continue
        fi
        
        echo -e "${CYAN}📧 Vérification: ${email}${NC}" >&2
        
        # Vérifier si le dossier player existe
        local player_dir="$HOME/.zen/game/players/${email}"
        if [[ ! -d "$player_dir" ]]; then
            echo -e "${YELLOW}⚠️  Dossier player non trouvé: ${player_dir}${NC}" >&2
            continue
        fi
        
        # Vérifier si les fichiers U.SOCIETY existent
        local usociety_file="$player_dir/U.SOCIETY"
        local usociety_end_file="$player_dir/U.SOCIETY.end"
        local nostr_usociety="$HOME/.zen/game/nostr/${email}/U.SOCIETY"
        local nostr_usociety_end="$HOME/.zen/game/nostr/${email}/U.SOCIETY.end"
        
        # Trouver la date de transaction la plus récente pour cet email
        local latest_transaction_date=$(echo "$transfers_json" | jq -r --arg email "$email" '
            .transfers[] | 
            select(.recipient == $email) | 
            .date
        ' | sort -r | head -n 1)
        
        if [[ -z "$latest_transaction_date" || "$latest_transaction_date" == "null" ]]; then
            echo -e "${YELLOW}⚠️  Aucune date de transaction trouvée pour ${email}${NC}" >&2
            continue
        fi
        
        # Convertir la date de transaction en format YYYY-MM-DD
        local transaction_date=$(date -d "$latest_transaction_date" '+%Y-%m-%d' 2>/dev/null || echo "$latest_transaction_date")
        
        # Déterminer le type d'abonnement et calculer la date de fin
        local part_type=$(echo "$transfers_json" | jq -r --arg email "$email" '
            .transfers[] | 
            select(.recipient == $email) | 
            .part_type
        ' | head -n 1)
        
        local end_date=""
        case "$part_type" in
            "satellite")
                end_date=$(date -d "$transaction_date + 365 days" '+%Y-%m-%d')
                ;;
            "constellation")
                end_date=$(date -d "$transaction_date + 1095 days" '+%Y-%m-%d')  # 3 ans
                ;;
            *)
                end_date=$(date -d "$transaction_date + 365 days" '+%Y-%m-%d')  # Par défaut 1 an
                ;;
        esac
        
        if [[ -f "$usociety_file" ]]; then
            # Fichier existe, vérifier la date
            local current_date=$(cat "$usociety_file" 2>/dev/null)
            
            if [[ "$current_date" != "$transaction_date" ]]; then
                echo -e "${YELLOW}⚠️  Date U.SOCIETY obsolète: ${current_date} (transaction: ${transaction_date})${NC}" >&2
                ((outdated_count++))
                
                if [[ "$fix_mode" == "true" ]]; then
                    # Corriger la date
                    echo "$transaction_date" > "$usociety_file"
                    echo -e "${GREEN}✅ Date U.SOCIETY corrigée: ${transaction_date}${NC}" >&2
                    
                    # Mettre à jour le fichier U.SOCIETY.end
                    echo "$end_date" > "$usociety_end_file"
                    echo -e "${GREEN}✅ Date U.SOCIETY.end mise à jour: ${end_date}${NC}" >&2
                    
                    # Mettre à jour les liens symboliques dans nostr si il existe
                    if [[ -d "$HOME/.zen/game/nostr/${email}" ]]; then
                        ln -sf "$usociety_file" "$nostr_usociety"
                        ln -sf "$usociety_end_file" "$nostr_usociety_end"
                        echo -e "${GREEN}✅ Liens symboliques nostr mis à jour${NC}" >&2
                    fi
                    ((fixed_count++))
                fi
            else
                echo -e "${GREEN}✅ U.SOCIETY à jour: ${current_date}${NC}" >&2
                
                # Vérifier aussi U.SOCIETY.end
                if [[ -f "$usociety_end_file" ]]; then
                    local current_end_date=$(cat "$usociety_end_file" 2>/dev/null)
                    if [[ "$current_end_date" != "$end_date" ]]; then
                        echo -e "${YELLOW}⚠️  Date U.SOCIETY.end obsolète: ${current_end_date} (calculée: ${end_date})${NC}" >&2
                        if [[ "$fix_mode" == "true" ]]; then
                            echo "$end_date" > "$usociety_end_file"
                            echo -e "${GREEN}✅ Date U.SOCIETY.end corrigée: ${end_date}${NC}" >&2
                            if [[ -d "$HOME/.zen/game/nostr/${email}" ]]; then
                                ln -sf "$usociety_end_file" "$nostr_usociety_end"
                            fi
                            ((fixed_count++))
                        fi
                    else
                        echo -e "${GREEN}✅ U.SOCIETY.end à jour: ${current_end_date}${NC}" >&2
                    fi
                else
                    echo -e "${YELLOW}⚠️  Fichier U.SOCIETY.end manquant${NC}" >&2
                    if [[ "$fix_mode" == "true" ]]; then
                        echo "$end_date" > "$usociety_end_file"
                        echo -e "${GREEN}✅ Fichier U.SOCIETY.end créé: ${end_date}${NC}" >&2
                        if [[ -d "$HOME/.zen/game/nostr/${email}" ]]; then
                            ln -sf "$usociety_end_file" "$nostr_usociety_end"
                        fi
                        ((fixed_count++))
                    fi
                fi
            fi
        else
            # Fichier manquant
            echo -e "${RED}❌ Fichier U.SOCIETY manquant pour ${email}${NC}" >&2
            ((missing_count++))
            
            if [[ "$fix_mode" == "true" ]]; then
                # Créer les fichiers U.SOCIETY et U.SOCIETY.end
                echo "$transaction_date" > "$usociety_file"
                echo "$end_date" > "$usociety_end_file"
                echo -e "${GREEN}✅ Fichiers U.SOCIETY créés: ${transaction_date} → ${end_date}${NC}" >&2
                
                # Créer les liens symboliques dans nostr si le dossier existe
                if [[ -d "$HOME/.zen/game/nostr/${email}" ]]; then
                    ln -sf "$usociety_file" "$nostr_usociety"
                    ln -sf "$usociety_end_file" "$nostr_usociety_end"
                    echo -e "${GREEN}✅ Liens symboliques nostr créés${NC}" >&2
                fi
                ((fixed_count++))
            fi
        fi
    done <<< "$emails"
    
    # Résumé
    echo -e "\n${BLUE}📊 Résumé de la vérification U.SOCIETY:${NC}" >&2
    echo -e "  • Fichiers manquants: ${missing_count}" >&2
    echo -e "  • Fichiers obsolètes: ${outdated_count}" >&2
    echo -e "  • Fichiers corrigés: ${fixed_count}" >&2
    
    if [[ "$fix_mode" == "true" && $fixed_count -gt 0 ]]; then
        echo -e "${GREEN}🎉 Correction terminée! ${fixed_count} fichier(s) U.SOCIETY corrigé(s)${NC}" >&2
    elif [[ "$fix_mode" == "false" && $((missing_count + outdated_count)) -gt 0 ]]; then
        echo -e "${YELLOW}💡 Utilisez l'option --fix pour corriger les fichiers U.SOCIETY${NC}" >&2
    fi
    
    return 0
}

# Parse command line arguments
CHECK_USOCIETY=false
FIX_USOCIETY=false
JSON_ONLY=false
INCLUDE_NOSTR=false
DID_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check-usociety)
            CHECK_USOCIETY=true
            shift
            ;;
        --fix-usociety)
            FIX_USOCIETY=true
            shift
            ;;
        --json-only)
            JSON_ONLY=true
            shift
            ;;
        --nostr)
            INCLUDE_NOSTR=true
            shift
            ;;
        --did)
            DID_ONLY=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --check-usociety    Vérifier les fichiers U.SOCIETY"
            echo "  --fix-usociety      Corriger les fichiers U.SOCIETY manquants/obsolètes"
            echo "  --json-only         Afficher seulement le JSON (pas de vérification U.SOCIETY)"
            echo "  --nostr             Inclure les données DID depuis Nostr"
            echo "  --did               Retourner seulement les données DID (pas d'historique portefeuilles)"
            echo "  --help, -h          Afficher cette aide"
            echo ""
            echo "Exemples:"
            echo "  $0                           # Analyse normale avec JSON"
            echo "  $0 --check-usociety          # Vérifier les fichiers U.SOCIETY"
            echo "  $0 --fix-usociety            # Corriger les fichiers U.SOCIETY"
            echo "  $0 --json-only               # JSON seulement, pas de vérification"
            echo "  $0 --nostr                   # Inclure les données Nostr dans le JSON"
            echo "  $0 --did                     # Seulement les données DID, pas d'historique"
            exit 0
            ;;
        *)
            echo "Option inconnue: $1"
            echo "Utilisez --help pour voir les options disponibles"
            exit 1
            ;;
    esac
done

# Get SOCIETY wallet public key from environment
SOCIETY_G1PUB="${UPLANETNAME_SOCIETY:-}"
if [[ -z "$SOCIETY_G1PUB" ]]; then
    log "ERROR: UPLANETNAME_SOCIETY not set in environment"
    echo '{"error": "SOCIETY wallet not configured", "total_outgoing_g1": 0, "total_outgoing_zen": 0, "total_transfers": 0, "transfers": []}'
    exit 1
fi

# Get UPLANET G1 wallet public key
UPLANET_G1PUB="${UPLANETNAME_G1:-}"
if [[ -z "$UPLANET_G1PUB" ]]; then
    log "ERROR: UPLANETNAME_G1 not set in environment"
    echo '{"error": "UPLANET G1 wallet not configured", "total_outgoing_g1": 0, "total_outgoing_zen": 0, "total_transfers": 0, "transfers": []}'
    exit 1
fi

log "Starting SOCIETY transaction analysis"
log "SOCIETY wallet: $SOCIETY_G1PUB"
log "UPLANET G1 wallet: $UPLANET_G1PUB"

# Si mode --did, retourner seulement les données DID
if [[ "$DID_ONLY" == "true" ]]; then
    echo -e "${BLUE}🔍 Mode DID uniquement - Récupération des données DID...${NC}" >&2
    
    # Créer un JSON de base pour les données DID
    base_json='{
        "g1pub": "'"$SOCIETY_G1PUB"'",
        "total_outgoing_g1": 0,
        "total_outgoing_zen": 0,
        "total_transfers": 0,
        "transfers": [],
        "timestamp": "'"$(date -u +%Y-%m-%dT%H:%M:%S)"'"
    }'
    
    # Récupérer les données Nostr (utiliser la fonction intégrée)
    NOSTR_DATA=$(fetch_did_data_only)
    
    # Intégrer les données Nostr dans le résultat
    RESULT=$(echo "$base_json" | jq --argjson nostr_data "$NOSTR_DATA" '. + {nostr_did_data: $nostr_data}')
    
    # Output the result
    echo "$RESULT"
    
    log "DID analysis completed: $(echo "$NOSTR_DATA" | jq -r 'length // 0') DID(s) found"
    exit 0
fi

# Call G1history.sh to get transaction history
HISTORY_JSON=$(${MY_PATH}/G1history.sh "$SOCIETY_G1PUB" 2>/dev/null)

if [[ -z "$HISTORY_JSON" ]]; then
    log "ERROR: Failed to retrieve transaction history"
    echo '{"error": "Failed to retrieve history", "total_outgoing_g1": 0, "total_outgoing_zen": 0, "total_transfers": 0, "transfers": []}'
    exit 1
fi

# Validate JSON
if ! echo "$HISTORY_JSON" | jq empty 2>/dev/null; then
    log "ERROR: Invalid JSON from G1history.sh"
    echo '{"error": "Invalid history JSON", "total_outgoing_g1": 0, "total_outgoing_zen": 0, "total_transfers": 0, "transfers": []}'
    exit 1
fi

# Process history JSON with jq to filter and calculate
# Filter transactions where:
# 1. Amount is positive (incoming to SOCIETY)
# 2. Issuer matches UPLANET_G1PUB (first 8 chars of Issuers/Recipients before ':')
# 3. Reference contains "SOCIETY"
# Format attendu: "UPLANET:xxxxxxxx:SOCIETY:email@example.com:type:IPFSNODEID"
# Legacy format: "UPLANET:xxxxxxxx:SOCIETY:email@example.com:type"
RESULT=$(echo "$HISTORY_JSON" | jq -r --arg uplanet_g1 "$UPLANET_G1PUB" '
{
    g1pub: .pubkey,
    total_outgoing_g1: 0,
    total_outgoing_zen: 0,
    total_transfers: 0,
    transfers: [],
    timestamp: (now | strftime("%Y-%m-%dT%H:%M:%S"))
} as $init |

if .history then
    .history | map(
        # Parse amount
        (."Amounts Ğ1" | tonumber) as $amount_g1 |
        # Extract issuer pubkey (before ":")
        (."Issuers/Recipients" | split(":")[0]) as $issuer |
        # Get reference
        (."Reference" // "") as $reference |
        
        # Check if this is an incoming transfer from UPLANET_G1 with SOCIETY reference
        if ($amount_g1 > 0 and $issuer == $uplanet_g1 and ($reference | contains("SOCIETY"))) then
            {
                is_society_transfer: true,
                amount_g1: $amount_g1,
                # Standard rate: 1Ẑ = 0.1Ğ1 (or 10Ẑ = 1Ğ1)
                # This matches UPLANET.official.sh logic where 50Ẑ satellite = 5Ğ1 on blockchain
                amount_zen: (if $amount_g1 > 1 then (($amount_g1) * 10) else 0 end),
                date: ."Date",
                recipient: (
                    if ($reference | contains("SOCIETY:")) then
                        ($reference | split("SOCIETY:")[1] | split(":")[0])
                    else
                        "N/A"
                    end
                ),
                part_type: (
                    if ($reference | contains("constellation")) then
                        "constellation"
                    elif ($reference | contains("satellite")) then
                        "satellite"
                    elif ($reference | contains("Parts sociales")) then
                        "parts"
                    else
                        "other"
                    end
                ),
                ipfs_node: (
                    if ($reference | contains("SOCIETY:")) then
                        # Format: UPLANET:xxx:SOCIETY:email:type:IPFSNODEID
                        # Extract last field if exists (IPFSNODEID)
                        ($reference | split(":") | if length >= 6 then .[-1] else "N/A" end)
                    else
                        "N/A"
                    end
                ),
                comment: $reference
            }
        else
            {is_society_transfer: false}
        end
    ) |
    
    # Filter only society transfers
    map(select(.is_society_transfer == true)) |
    
    # Calculate totals and format result
    {
        g1pub: $init.g1pub,
        total_outgoing_g1: (map(.amount_g1) | add // 0 | . * 100 | round / 100),
        total_outgoing_zen: (map(.amount_zen) | add // 0 | . * 100 | round / 100),
        total_transfers: length,
        transfers: (
            map({
                date: .date,
                recipient: .recipient,
                amount_g1: (.amount_g1 | . * 100 | round / 100),
                amount_zen: (.amount_zen | . * 100 | round / 100),
                part_type: .part_type,
                ipfs_node: .ipfs_node,
                comment: (
                    if .part_type == "constellation" then
                        "Constellation - \(.comment)"
                    elif .part_type == "satellite" then
                        "Satellite - \(.comment)"
                    elif .part_type == "parts" then
                        "Parts sociales - \(.comment)"
                    else
                        .comment
                    end
                )
            }) | .[:50]
        ),
        timestamp: $init.timestamp
    }
else
    $init
end
')

# Récupérer les données Nostr si demandé
if [[ "$INCLUDE_NOSTR" == "true" ]]; then
    echo "" >&2
    # Utiliser la fonction intégrée pour récupérer les données DID
    NOSTR_DATA=$(fetch_did_data_only)
    
    # Intégrer les données Nostr dans le résultat
    RESULT=$(echo "$RESULT" | jq --argjson nostr_data "$NOSTR_DATA" '. + {nostr_did_data: $nostr_data}')
fi

# Output the result
echo "$RESULT"

log "SOCIETY analysis completed: $(echo "$RESULT" | jq -r '.total_transfers // 0') transfers found"

# Vérifier et corriger les fichiers U.SOCIETY si demandé
if [[ "$JSON_ONLY" == "false" ]]; then
    if [[ "$CHECK_USOCIETY" == "true" || "$FIX_USOCIETY" == "true" ]]; then
        echo "" >&2
        check_and_fix_usociety_files "$RESULT" "$FIX_USOCIETY"
    fi
fi

exit 0

