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

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

################################################################################
# Fonction pour vérifier et corriger les fichiers U.SOCIETY
################################################################################
check_and_fix_usociety_files() {
    local transfers_json="$1"
    local fix_mode="${2:-false}"  # true pour corriger, false pour juste vérifier
    
    echo -e "${BLUE}🔍 Vérification des fichiers U.SOCIETY...${NC}"
    
    # Extraire les emails des transferts
    local emails=$(echo "$transfers_json" | jq -r '.transfers[]?.recipient // empty' | grep -v "N/A" | sort -u)
    
    if [[ -z "$emails" ]]; then
        echo -e "${YELLOW}⚠️  Aucun email trouvé dans les transferts${NC}"
        return 0
    fi
    
    local fixed_count=0
    local missing_count=0
    local outdated_count=0
    
    while IFS= read -r email; do
        if [[ -z "$email" || "$email" == "N/A" ]]; then
            continue
        fi
        
        echo -e "${CYAN}📧 Vérification: ${email}${NC}"
        
        # Vérifier si le dossier player existe
        local player_dir="$HOME/.zen/game/players/${email}"
        if [[ ! -d "$player_dir" ]]; then
            echo -e "${YELLOW}⚠️  Dossier player non trouvé: ${player_dir}${NC}"
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
            echo -e "${YELLOW}⚠️  Aucune date de transaction trouvée pour ${email}${NC}"
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
                echo -e "${YELLOW}⚠️  Date U.SOCIETY obsolète: ${current_date} (transaction: ${transaction_date})${NC}"
                ((outdated_count++))
                
                if [[ "$fix_mode" == "true" ]]; then
                    # Corriger la date
                    echo "$transaction_date" > "$usociety_file"
                    echo -e "${GREEN}✅ Date U.SOCIETY corrigée: ${transaction_date}${NC}"
                    
                    # Mettre à jour le fichier U.SOCIETY.end
                    echo "$end_date" > "$usociety_end_file"
                    echo -e "${GREEN}✅ Date U.SOCIETY.end mise à jour: ${end_date}${NC}"
                    
                    # Mettre à jour les liens symboliques dans nostr si il existe
                    if [[ -d "$HOME/.zen/game/nostr/${email}" ]]; then
                        ln -sf "$usociety_file" "$nostr_usociety"
                        ln -sf "$usociety_end_file" "$nostr_usociety_end"
                        echo -e "${GREEN}✅ Liens symboliques nostr mis à jour${NC}"
                    fi
                    ((fixed_count++))
                fi
            else
                echo -e "${GREEN}✅ U.SOCIETY à jour: ${current_date}${NC}"
                
                # Vérifier aussi U.SOCIETY.end
                if [[ -f "$usociety_end_file" ]]; then
                    local current_end_date=$(cat "$usociety_end_file" 2>/dev/null)
                    if [[ "$current_end_date" != "$end_date" ]]; then
                        echo -e "${YELLOW}⚠️  Date U.SOCIETY.end obsolète: ${current_end_date} (calculée: ${end_date})${NC}"
                        if [[ "$fix_mode" == "true" ]]; then
                            echo "$end_date" > "$usociety_end_file"
                            echo -e "${GREEN}✅ Date U.SOCIETY.end corrigée: ${end_date}${NC}"
                            if [[ -d "$HOME/.zen/game/nostr/${email}" ]]; then
                                ln -sf "$usociety_end_file" "$nostr_usociety_end"
                            fi
                            ((fixed_count++))
                        fi
                    else
                        echo -e "${GREEN}✅ U.SOCIETY.end à jour: ${current_end_date}${NC}"
                    fi
                else
                    echo -e "${YELLOW}⚠️  Fichier U.SOCIETY.end manquant${NC}"
                    if [[ "$fix_mode" == "true" ]]; then
                        echo "$end_date" > "$usociety_end_file"
                        echo -e "${GREEN}✅ Fichier U.SOCIETY.end créé: ${end_date}${NC}"
                        if [[ -d "$HOME/.zen/game/nostr/${email}" ]]; then
                            ln -sf "$usociety_end_file" "$nostr_usociety_end"
                        fi
                        ((fixed_count++))
                    fi
                fi
            fi
        else
            # Fichier manquant
            echo -e "${RED}❌ Fichier U.SOCIETY manquant pour ${email}${NC}"
            ((missing_count++))
            
            if [[ "$fix_mode" == "true" ]]; then
                # Créer les fichiers U.SOCIETY et U.SOCIETY.end
                echo "$transaction_date" > "$usociety_file"
                echo "$end_date" > "$usociety_end_file"
                echo -e "${GREEN}✅ Fichiers U.SOCIETY créés: ${transaction_date} → ${end_date}${NC}"
                
                # Créer les liens symboliques dans nostr si le dossier existe
                if [[ -d "$HOME/.zen/game/nostr/${email}" ]]; then
                    ln -sf "$usociety_file" "$nostr_usociety"
                    ln -sf "$usociety_end_file" "$nostr_usociety_end"
                    echo -e "${GREEN}✅ Liens symboliques nostr créés${NC}"
                fi
                ((fixed_count++))
            fi
        fi
    done <<< "$emails"
    
    # Résumé
    echo -e "\n${BLUE}📊 Résumé de la vérification U.SOCIETY:${NC}"
    echo -e "  • Fichiers manquants: ${missing_count}"
    echo -e "  • Fichiers obsolètes: ${outdated_count}"
    echo -e "  • Fichiers corrigés: ${fixed_count}"
    
    if [[ "$fix_mode" == "true" && $fixed_count -gt 0 ]]; then
        echo -e "${GREEN}🎉 Correction terminée! ${fixed_count} fichier(s) U.SOCIETY corrigé(s)${NC}"
    elif [[ "$fix_mode" == "false" && $((missing_count + outdated_count)) -gt 0 ]]; then
        echo -e "${YELLOW}💡 Utilisez l'option --fix pour corriger les fichiers U.SOCIETY${NC}"
    fi
    
    return 0
}

# Parse command line arguments
CHECK_USOCIETY=false
FIX_USOCIETY=false
JSON_ONLY=false

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
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --check-usociety    Vérifier les fichiers U.SOCIETY"
            echo "  --fix-usociety      Corriger les fichiers U.SOCIETY manquants/obsolètes"
            echo "  --json-only         Afficher seulement le JSON (pas de vérification U.SOCIETY)"
            echo "  --help, -h          Afficher cette aide"
            echo ""
            echo "Exemples:"
            echo "  $0                           # Analyse normale avec JSON"
            echo "  $0 --check-usociety          # Vérifier les fichiers U.SOCIETY"
            echo "  $0 --fix-usociety            # Corriger les fichiers U.SOCIETY"
            echo "  $0 --json-only               # JSON seulement, pas de vérification"
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

# Output the result
echo "$RESULT"

log "SOCIETY analysis completed: $(echo "$RESULT" | jq -r '.total_transfers // 0') transfers found"

# Vérifier et corriger les fichiers U.SOCIETY si demandé
if [[ "$JSON_ONLY" == "false" ]]; then
    if [[ "$CHECK_USOCIETY" == "true" || "$FIX_USOCIETY" == "true" ]]; then
        echo ""
        check_and_fix_usociety_files "$RESULT" "$FIX_USOCIETY"
    fi
fi

exit 0

