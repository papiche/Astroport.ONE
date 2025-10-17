#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 1.0
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# G1zerozen.sh
# Nettoie les portefeuilles ZEN Card en remettant leur balance à 0 Ẑ (1Ğ1)
# Transfère le surplus vers UPLANETNAME_G1 (banque centrale)
# Vérifie l'appartenance à SOCIETY et corrige les fichiers U.SOCIETY/U.SOCIETY.end
# 
# Usage: G1zerozen.sh [OPTIONS]
#   --dry-run        Mode simulation (pas de transfert réel)
#   --force          Forcer les transferts sans confirmation
#   --email EMAIL    Traiter seulement un email spécifique
#   --list-only      Afficher seulement la liste des portefeuilles
#   --no-publish     Ne pas publier les clés G1
#
# Fonctionnalités:
#   - Vérifie que l'email figure dans l'historique SOCIETY (via G1society.sh)
#   - Corrige automatiquement les fichiers U.SOCIETY et U.SOCIETY.end manquants/obsolètes
#   - Calcule les dates de fin d'abonnement (satellite: 1 an, constellation: 3 ans)
#   - Crée/met à jour les liens symboliques nostr
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
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

# Variables globales
DRY_RUN=false
FORCE=false
TARGET_EMAIL=""
LIST_ONLY=false
PUBLISH_KEYS=true
UPLANET_G1="${UPLANETNAME_G1:-}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --email)
            TARGET_EMAIL="$2"
            shift 2
            ;;
        --list-only)
            LIST_ONLY=true
            shift
            ;;
        --no-publish)
            PUBLISH_KEYS=false
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run        Mode simulation (pas de transfert réel)"
            echo "  --force          Forcer les transferts sans confirmation"
            echo "  --email EMAIL    Traiter seulement un email spécifique"
            echo "  --list-only      Afficher seulement la liste des portefeuilles"
            echo "  --no-publish     Ne pas publier les clés G1"
            echo "  --help, -h       Afficher cette aide"
            echo ""
            echo "Fonctionnalités:"
            echo "  • Vérifie l'appartenance à SOCIETY via G1society.sh"
            echo "  • Corrige les fichiers U.SOCIETY et U.SOCIETY.end manquants/obsolètes"
            echo "  • Calcule automatiquement les dates de fin d'abonnement"
            echo "  • Nettoie les portefeuilles ZEN Card (surplus → UPLANET G1)"
            echo "  • Publie les clés G1 publiques sur IPFS"
            echo ""
            echo "Exemples:"
            echo "  $0 --list-only                    # Lister tous les portefeuilles"
            echo "  $0 --dry-run                      # Simulation de nettoyage"
            echo "  $0 --email user@example.com       # Nettoyer un portefeuille spécifique"
            echo "  $0 --force                        # Nettoyage automatique"
            exit 0
            ;;
        *)
            echo "Option inconnue: $1"
            echo "Utilisez --help pour voir les options disponibles"
            exit 1
            ;;
    esac
done

# Vérifier que UPLANETNAME_G1 est configuré
if [[ -z "$UPLANET_G1" ]]; then
    log "ERROR: UPLANETNAME_G1 not set in environment"
    echo '{"error": "UPLANETNAME_G1 not configured", "wallets": [], "total_surplus": 0}'
    exit 1
fi

log "Starting ZEN Card wallet cleanup"
log "UPLANET G1 wallet: $UPLANET_G1"
log "Mode: $([ "$DRY_RUN" == "true" ] && echo "DRY-RUN" || echo "LIVE")"

# Fonction pour vérifier le solde d'un portefeuille
check_wallet_balance() {
    local g1pub="$1"
    local script_path="$HOME/.zen/Astroport.ONE/tools/G1check.sh"
    
    if [[ ! -f "$script_path" ]]; then
        echo "error"
        return 1
    fi
    
    local result=$("$script_path" "$g1pub" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo "error"
        return 1
    fi
    echo "$result"
}

# Fonction pour convertir Ğ1 en ẐEN
convert_g1_to_zen() {
    local g1_balance="$1"
    # Nettoyer la balance (enlever les unités et espaces)
    local clean_balance=$(echo "$g1_balance" | sed 's/Ğ1//g' | sed 's/G1//g' | tr -d ' ')
    
    # Convertir en float et appliquer la formule: (balance - 1) * 10
    local zen_amount=$(echo "$clean_balance - 1" | bc -l | awk '{print ($1 * 10)}')
    
    # Retourner en format entier
    echo "${zen_amount%.*} Ẑ"
}

# Fonction pour calculer le surplus à transférer
calculate_surplus() {
    local balance="$1"
    # Nettoyer la balance
    local clean_balance=$(echo "$balance" | sed 's/Ğ1//g' | sed 's/G1//g' | tr -d ' ')
    
    # Calculer le surplus (balance - 1Ğ1)
    local surplus=$(echo "$clean_balance - 1" | bc -l)
    
    # Retourner le surplus (0 si négatif)
    if (( $(echo "$surplus > 0" | bc -l) )); then
        echo "$surplus"
    else
        echo "0"
    fi
}

# Fonction pour effectuer un transfert
transfer_surplus() {
    local from_g1pub="$1"
    local to_g1pub="$2"
    local amount="$3"
    local email="$4"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}🔍 [DRY-RUN] Transfert de ${amount}Ğ1 de ${from_g1pub:0:20}... vers ${to_g1pub:0:20}...${NC}"
        return 0
    fi
    
    # Utiliser PAYforSURE.sh pour effectuer le transfert
    local script_path="$HOME/.zen/Astroport.ONE/tools/PAYforSURE.sh"
    local reference="UPLANET:ZEROZEN:CLEANUP:${email}:surplus"
    
    # Trouver le fichier dunikey pour le portefeuille source
    local player_dir="$HOME/.zen/game/players/${email}"
    local dunikey_file="$player_dir/secret.dunikey"
    
    if [[ ! -f "$dunikey_file" ]]; then
        echo -e "${RED}❌ Fichier dunikey non trouvé: ${dunikey_file}${NC}"
        return 1
    fi
    
    log "Transferring ${amount}Ğ1 from ${from_g1pub:0:20}... to ${to_g1pub:0:20}..."
    
    if [[ ! -f "$script_path" ]]; then
        echo -e "${RED}❌ Script PAYforSURE.sh non trouvé: ${script_path}${NC}"
        return 1
    fi
    
    # PAYforSURE.sh usage: <keyfile> <amount> <g1pub> [comment] [moats]
    local result=$("$script_path" "$dunikey_file" "$amount" "$to_g1pub" "$reference" 2>&1)
    local return_code=$?
    
    if [[ $return_code -eq 0 ]]; then
        echo -e "${GREEN}✅ Transfert réussi: ${amount}Ğ1${NC}"
        return 0
    else
        echo -e "${RED}❌ Erreur transfert: ${result}${NC}"
        return 1
    fi
}

# Fonction pour publier la clé publique G1
publish_g1pub() {
    local email="$1"
    local g1pub="$2"
    local ipfs_node="${IPFSNODEID:-}"
    
    if [[ -z "$ipfs_node" ]]; then
        echo -e "${YELLOW}⚠️  IPFSNODEID non configuré, publication de clé ignorée${NC}"
        return 1
    fi
    
    # Créer le répertoire de destination
    local dest_dir="$HOME/.zen/tmp/${ipfs_node}/TW/${email}"
    local dest_file="${dest_dir}/_g1pub"
    
    # Créer le répertoire si nécessaire
    mkdir -p "$dest_dir"
    
    # Copier le fichier .g1pub vers _g1pub
    if [[ -f "$HOME/.zen/game/players/${email}/.g1pub" ]]; then
        cp "$HOME/.zen/game/players/${email}/.g1pub" "$dest_file"
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✅ Clé G1 publiée: ${dest_file}${NC}"
            return 0
        else
            echo -e "${RED}❌ Erreur lors de la publication de la clé G1${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  Fichier .g1pub source non trouvé pour ${email}${NC}"
        return 1
    fi
}

# Fonction pour vérifier si l'email est dans l'historique SOCIETY
check_society_membership() {
    local email="$1"
    local society_script="$HOME/.zen/Astroport.ONE/tools/G1society.sh"
    
    if [[ ! -f "$society_script" ]]; then
        echo -e "${YELLOW}⚠️  G1society.sh non trouvé, vérification SOCIETY ignorée${NC}"
        return 2  # Code 2 = script non trouvé (non bloquant)
    fi
    
    # Récupérer l'historique SOCIETY
    local society_json=$("$society_script" --json-only 2>/dev/null)
    
    if [[ $? -ne 0 || -z "$society_json" ]]; then
        echo -e "${YELLOW}⚠️  Impossible de récupérer l'historique SOCIETY${NC}"
        return 2  # Non bloquant
    fi
    
    # Vérifier si l'email figure dans les transferts
    local email_found=$(echo "$society_json" | jq -r --arg email "$email" '.transfers[]? | select(.recipient == $email) | .recipient' | head -n 1)
    
    if [[ -n "$email_found" && "$email_found" == "$email" ]]; then
        echo -e "${GREEN}✅ Sociétaire confirmé: ${email}${NC}"
        return 0  # Trouvé
    else
        echo -e "${YELLOW}⚠️  ${email} non trouvé dans l'historique SOCIETY${NC}"
        return 1  # Non trouvé
    fi
}

# Fonction pour corriger les fichiers U.SOCIETY
fix_usociety_files() {
    local email="$1"
    local society_script="$HOME/.zen/Astroport.ONE/tools/G1society.sh"
    
    if [[ ! -f "$society_script" ]]; then
        echo -e "${YELLOW}⚠️  G1society.sh non trouvé, correction U.SOCIETY ignorée${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🔧 Vérification et correction des fichiers U.SOCIETY pour ${email}...${NC}"
    
    # Récupérer l'historique SOCIETY avec l'email
    local society_json=$("$society_script" --json-only 2>/dev/null)
    
    if [[ $? -ne 0 || -z "$society_json" ]]; then
        echo -e "${YELLOW}⚠️  Impossible de récupérer l'historique SOCIETY pour correction${NC}"
        return 1
    fi
    
    # Extraire les informations de transaction pour cet email
    local transaction_date=$(echo "$society_json" | jq -r --arg email "$email" '
        .transfers[] | 
        select(.recipient == $email) | 
        .date
    ' | sort -r | head -n 1)
    
    if [[ -z "$transaction_date" || "$transaction_date" == "null" ]]; then
        echo -e "${YELLOW}⚠️  Aucune transaction SOCIETY trouvée pour ${email}${NC}"
        return 1
    fi
    
    # Convertir la date au format YYYY-MM-DD
    local start_date=$(date -d "$transaction_date" '+%Y-%m-%d' 2>/dev/null || echo "$transaction_date")
    
    # Déterminer le type d'abonnement
    local part_type=$(echo "$society_json" | jq -r --arg email "$email" '
        .transfers[] | 
        select(.recipient == $email) | 
        .part_type
    ' | head -n 1)
    
    # Calculer la date de fin
    local end_date=""
    case "$part_type" in
        "satellite")
            end_date=$(date -d "$start_date + 365 days" '+%Y-%m-%d')
            ;;
        "constellation")
            end_date=$(date -d "$start_date + 1095 days" '+%Y-%m-%d')  # 3 ans
            ;;
        *)
            end_date=$(date -d "$start_date + 365 days" '+%Y-%m-%d')  # Par défaut 1 an
            ;;
    esac
    
    # Chemins des fichiers
    local player_dir="$HOME/.zen/game/players/${email}"
    local usociety_file="$player_dir/U.SOCIETY"
    local usociety_end_file="$player_dir/U.SOCIETY.end"
    local nostr_usociety="$HOME/.zen/game/nostr/${email}/U.SOCIETY"
    local nostr_usociety_end="$HOME/.zen/game/nostr/${email}/U.SOCIETY.end"
    
    local fixed=false
    
    # Vérifier et créer/corriger U.SOCIETY
    if [[ ! -f "$usociety_file" ]]; then
        echo "$start_date" > "$usociety_file"
        echo -e "${GREEN}✅ Fichier U.SOCIETY créé: ${start_date}${NC}"
        fixed=true
    else
        local current_date=$(cat "$usociety_file" 2>/dev/null)
        if [[ "$current_date" != "$start_date" ]]; then
            echo "$start_date" > "$usociety_file"
            echo -e "${GREEN}✅ Fichier U.SOCIETY corrigé: ${start_date} (était: ${current_date})${NC}"
            fixed=true
        else
            echo -e "${GREEN}✅ Fichier U.SOCIETY déjà correct: ${start_date}${NC}"
        fi
    fi
    
    # Vérifier et créer/corriger U.SOCIETY.end
    if [[ ! -f "$usociety_end_file" ]]; then
        echo "$end_date" > "$usociety_end_file"
        echo -e "${GREEN}✅ Fichier U.SOCIETY.end créé: ${end_date}${NC}"
        fixed=true
    else
        local current_end_date=$(cat "$usociety_end_file" 2>/dev/null)
        if [[ "$current_end_date" != "$end_date" ]]; then
            echo "$end_date" > "$usociety_end_file"
            echo -e "${GREEN}✅ Fichier U.SOCIETY.end corrigé: ${end_date} (était: ${current_end_date})${NC}"
            fixed=true
        else
            echo -e "${GREEN}✅ Fichier U.SOCIETY.end déjà correct: ${end_date}${NC}"
        fi
    fi
    
    # Créer/mettre à jour les liens symboliques dans nostr si le dossier existe
    if [[ -d "$HOME/.zen/game/nostr/${email}" ]]; then
        ln -sf "$usociety_file" "$nostr_usociety"
        ln -sf "$usociety_end_file" "$nostr_usociety_end"
        echo -e "${GREEN}✅ Liens symboliques nostr mis à jour${NC}"
    fi
    
    if [[ "$fixed" == "true" ]]; then
        echo -e "${CYAN}📊 Type: ${part_type}, Début: ${start_date}, Fin: ${end_date}${NC}"
    fi
    
    return 0
}

# Fonction pour traiter un portefeuille
process_wallet() {
    local email="$1"
    local player_dir="$HOME/.zen/game/players/${email}"
    
    # Vérifier si le dossier existe
    if [[ ! -d "$player_dir" ]]; then
        echo -e "${YELLOW}⚠️  Dossier player non trouvé: ${player_dir}${NC}"
        return 1
    fi
    
    # Vérifier si l'email est dans l'historique SOCIETY
    check_society_membership "$email"
    local society_status=$?
    
    if [[ $society_status -eq 1 ]]; then
        echo -e "${YELLOW}⚠️  ${email} n'est pas sociétaire, traitement ignoré${NC}"
        return 1
    elif [[ $society_status -eq 0 ]]; then
        # Corriger les fichiers U.SOCIETY si nécessaire
        fix_usociety_files "$email"
    fi
    
    # Chercher la clé publique G1
    local g1pub=""
    if [[ -f "$player_dir/secret.dunikey" ]]; then
        g1pub=$(cat "$player_dir/secret.dunikey" | grep "pub:" | cut -d ' ' -f 2)
    elif [[ -f "$player_dir/.g1pub" ]]; then
        g1pub=$(cat "$player_dir/.g1pub")
    fi
    
    if [[ -z "$g1pub" ]]; then
        echo -e "${YELLOW}⚠️  Clé G1 non trouvée pour ${email}${NC}"
        return 1
    fi
    
    # Vérifier le solde
    local balance=$(check_wallet_balance "$g1pub")
    if [[ "$balance" == "error" ]]; then
        echo -e "${RED}❌ Erreur lors de la vérification du solde pour ${email}${NC}"
        return 1
    fi
    
    # Calculer le surplus
    local surplus=$(calculate_surplus "$balance")
    local zen_balance=$(convert_g1_to_zen "$balance")
    
    # Afficher les informations
    echo -e "${CYAN}📧 ${email}${NC}"
    echo -e "   G1PUB: ${g1pub:0:20}..."
    echo -e "   Balance: ${balance} (${zen_balance})"
    echo -e "   Surplus: ${surplus}Ğ1"
    
    # Publier la clé G1 (toujours, même si pas de surplus)
    if [[ "$PUBLISH_KEYS" == "true" ]]; then
        echo -e "${BLUE}📤 Publication de la clé G1...${NC}"
        publish_g1pub "$email" "$g1pub"
    else
        echo -e "${YELLOW}⏭️  Publication des clés désactivée${NC}"
    fi
    
    # Si il y a un surplus, proposer le transfert
    if (( $(echo "$surplus > 0" | bc -l) )); then
        echo -e "${YELLOW}💰 Surplus détecté: ${surplus}Ğ1${NC}"
        
        if [[ "$LIST_ONLY" == "true" ]]; then
            echo -e "${BLUE}📋 [LIST-ONLY] Transfert suggéré vers ${UPLANET_G1:0:20}...${NC}"
        else
            # Demander confirmation si pas en mode force
            if [[ "$FORCE" != "true" ]]; then
                echo -n "Voulez-vous transférer ce surplus vers UPLANET G1? (y/N): "
                read -r response
                if [[ ! "$response" =~ ^[Yy]$ ]]; then
                    echo -e "${YELLOW}⏭️  Transfert ignoré${NC}"
                    return 0
                fi
            fi
            
            # Effectuer le transfert
            if transfer_surplus "$g1pub" "$UPLANET_G1" "$surplus" "$email"; then
                echo -e "${GREEN}✅ Portefeuille ${email} nettoyé${NC}"
            else
                echo -e "${RED}❌ Erreur lors du nettoyage de ${email}${NC}"
                return 1
            fi
        fi
    else
        echo -e "${GREEN}✅ Portefeuille ${email} déjà propre (1Ğ1)${NC}"
    fi
    
    return 0
}

# Fonction principale
main() {
    local total_surplus=0
    local processed_count=0
    local cleaned_count=0
    
    echo -e "${BLUE}🔍 Recherche des portefeuilles ZEN Card...${NC}"
    
    # Si un email spécifique est fourni
    if [[ -n "$TARGET_EMAIL" ]]; then
        echo -e "${CYAN}📧 Traitement de l'email spécifique: ${TARGET_EMAIL}${NC}"
        if process_wallet "$TARGET_EMAIL"; then
            ((processed_count++))
        fi
    else
        # Parcourir tous les dossiers players
        for player_dir in "$HOME/.zen/game/players"/*; do
            if [[ -d "$player_dir" ]]; then
                local email=$(basename "$player_dir")
                if [[ "$email" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
                    if process_wallet "$email"; then
                        ((processed_count++))
                    fi
                fi
            fi
        done
    fi
    
    # Résumé
    echo -e "\n${BLUE}📊 Résumé du nettoyage:${NC}"
    echo -e "  • Portefeuilles traités: ${processed_count}"
    echo -e "  • Mode: $([ "$DRY_RUN" == "true" ] && echo "SIMULATION" || echo "LIVE")"
    
    if [[ "$LIST_ONLY" == "true" ]]; then
        echo -e "  • Action: LISTE SEULEMENT"
    else
        echo -e "  • Action: NETTOYAGE"
    fi
}

# Exécuter la fonction principale
main "$@"

exit 0
