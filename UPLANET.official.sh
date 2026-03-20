#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 1.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# UPLANET.official.sh
# Script de gestion des virements officiels UPlanet
# 
# Utilise PAYforSURE.sh pour effectuer les transactions sans attendre les pending
# Vérification différée : un script en arrière-plan vérifie les transactions après 1 heure
#
# Gère quatre types de virements :
# 1. MULTIPASS : UPLANETNAME_G1 -> UPLANETNAME -> MULTIPASS (recharge de service)
# 2. SOCIÉTAIRE : UPLANETNAME_G1 -> UPLANETNAME_SOCIETY -> ZEN Card -> 3x1/3
# 3. ORE : UPLANETNAME_ASSETS -> UMAP DID (récompenses environnementales depuis réserves coopératives)
# 4. PERMIT : UPLANETNAME_RnD -> PERMIT HOLDER (récompenses pour WoT Dragon et autres permis spéciaux)
#
# Format des références blockchain :
# - ZENCOIN : "UPLANET:${UPLANETG1PUB:0:8}:ZENCOIN:${email}"
# - CAPITAL : "UPLANET:${UPLANETG1PUB:0:8}:CAPITAL:${email}:${IPFSNODEID}"
# - SOCIETY : "UPLANET:${UPLANETG1PUB:0:8}:SOCIETY:${email}:${type}:${IPFSNODEID}"
# - TREASURY: "UPLANET:${UPLANETG1PUB:0:8}:TREASURY:${email}:${type}:${IPFSNODEID}"
# - RnD     : "UPLANET:${UPLANETG1PUB:0:8}:RnD:${email}:${type}:${IPFSNODEID}"
# - ASSETS  : "UPLANET:${UPLANETG1PUB:0:8}:ASSETS:${email}:${type}:${IPFSNODEID}"
# - ORE     : "UPLANET:${UPLANETG1PUB:0:8}:ORE:${umap_did}:${lat}:${lon}:${IPFSNODEID}" (depuis ASSETS)
# - PERMIT  : "UPLANET:${UPLANETG1PUB:0:8}:PERMIT:${permit_id}:${email}:${credential_id}:${IPFSNODEID}" (depuis G1)
#
# L'IPFSNODEID identifie le nœud/machine à l'origine de la transaction
#
# Conformité : Respecte la Constitution de l'Écosystème UPlanet ẐEN
# Sécurité : Utilise PAYforSURE.sh avec vérification différée (1 heure)
################################################################################

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/tools/my.sh"

# Initialisation : Chargement des paramètres coopératifs depuis le DID NOSTR (essaim partagé)
echo -e "\033[0;36m⚙️  Initialisation UPLANET.official.sh...\033[0m"
echo -e "\033[1;33m🔄 Récupération des paramètres coopératifs depuis le DID NOSTR (kind 30800)...\033[0m"
echo -e "\033[0;34m   • Lecture de la configuration locale (my.sh + .env)...\033[0m"
echo -e "\033[0;34m   • Connexion au relais NOSTR pour synchroniser l'essaim...\033[0m"
. "${MY_PATH}/tools/cooperative_config.sh" 2>/dev/null && {
    echo -e "\033[0;34m   • Module cooperative_config.sh chargé, application des variables...\033[0m"
    coop_load_env_vars 2>/dev/null \
        && echo -e "\033[0;32m✅ Paramètres coopératifs chargés depuis le DID NOSTR (essaim synchronisé)\033[0m" \
        || echo -e "\033[1;33m⚠️  Config coopérative NOSTR indisponible — valeurs locales utilisées.\033[0m"
} || echo -e "\033[1;33m⚠️  cooperative_config.sh introuvable — configuration locale uniquement.\033[0m"

# Affichage des paramètres importants récupérés
echo -e "\033[0;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\033[1;34m📋 Paramètres de la coopérative UPlanet\033[0m"
echo -e "\033[0;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\033[0;33m🌐 Réseau :\033[0m"
echo -e "   • Capitaine  : \033[0;32m${CAPTAINEMAIL:-❌ NON DÉFINI}\033[0m"
echo -e "   • IPFS Node  : \033[0;32m...${IPFSNODEID: -8}\033[0m"
echo -e "\033[0;33m🏛️  Portefeuilles coopératifs (format SS58 / Duniter v2) :\033[0m"
_CESIUM="${CESIUMIPFS:-https://cesium.copylaradio.com}"
_G1V2PY="${MY_PATH}/tools/g1pub_to_ss58.py"
_API="${uSPOT:-http://127.0.0.1:54321}"

# Fonction locale : affiche SS58 (v2) + lien Cesium WoT/TX + lien UPassport API d'audit
# Usage : _show_wallet "LABEL" "G1PUBKEY" "URL_API_AUDIT"
_show_wallet() {
    local label="$1" pubkey="$2" api_url="${3:-}"
    local ss58=""
    [[ -n "$pubkey" ]] && ss58=$(python3 "$_G1V2PY" "$pubkey" 2>/dev/null) || ss58="❌"
    printf "   \033[0;36m%-18s\033[0m : \033[0;35m%s\033[0m\n" "$label" "${ss58:-❌}"
    printf "   %-18s   🔗 Cesium : %s/#/wot/tx/%s/\n" "" "$_CESIUM" "${ss58}"
    [[ -n "$api_url" ]] && \
    printf "   %-18s   🔍 Audit  : %s\n" "" "${api_url}"
}
_show_wallet "BANQUE CENTRALE"   "${UPLANETNAME_G1:-$UPLANETG1PUB}" \
    "${_API}/check_balance?g1pub=${UPLANETNAME_G1:-$UPLANETG1PUB}&html"
_show_wallet "ẑen USAGE"         "${UPLANETG1PUB}" \
    "${_API}/check_revenue?html"
_show_wallet "ẐEN SOCIETY/AMAP"  "${UPLANETNAME_SOCIETY}" \
    "${_API}/check_society?html"
_show_wallet "TREASURY"          "${UPLANETNAME_TREASURY}" \
    "${_API}/check_balance?g1pub=${UPLANETNAME_TREASURY}&html"
_show_wallet "ASSETS"            "${UPLANETNAME_ASSETS}" \
    "${_API}/check_balance?g1pub=${UPLANETNAME_ASSETS}&html"
_show_wallet "RnD"               "${UPLANETNAME_RND}" \
    "${_API}/check_balance?g1pub=${UPLANETNAME_RND}&html"
_show_wallet "IMPOT (TVA)"       "${UPLANETNAME_IMPOT}" \
    "${_API}/check_impots?html"
_show_wallet "CAPITAL (NODE)"    "${UPLANETNAME_CAPITAL}" \
    "${_API}/check_balance?g1pub=${UPLANETNAME_CAPITAL}&html"
echo -e "   \033[0;33m💎 Capital machine : ${MACHINE_VALUE_ZEN:-non configuré} Ẑen\033[0m"
echo -e "\033[0;33m📊 Activité économique coopérative :\033[0m"
# 1. Banque Centrale Ğ1 (UPLANETNAME_G1) — réserve de valeur, capacité à capter des €
_bc_pubkey="${UPLANETNAME_G1:-$UPLANETG1PUB}"
_bc_ss58=$(python3 "${MY_PATH}/tools/g1pub_to_ss58.py" "${_bc_pubkey}" 2>/dev/null)
_bc_bal_json=""
if [[ -n "$_bc_ss58" ]]; then
    # G1wallet_v2.sh balance --json → {"rpc_transferable": <centimes>, "unit":"centimes_g1", ...}
    _bc_bal_json=$(timeout 8 "${MY_PATH}/tools/G1wallet_v2.sh" balance "$_bc_ss58" --json 2>/dev/null)
    if echo "$_bc_bal_json" | jq -e '.rpc_transferable' >/dev/null 2>&1; then
        _bc_centimes=$(echo "$_bc_bal_json" | jq -r '.rpc_transferable // 0')
        _bc_g1=$(echo "scale=2; ${_bc_centimes:-0} / 100" | bc -l 2>/dev/null)
    fi
fi
if [[ -z "$_bc_g1" ]]; then
    # Fallback G1balance.sh (API v1, centimes → Ğ1)
    _bc_bal_v1=$(timeout 8 "${MY_PATH}/tools/G1balance.sh" "${_bc_pubkey}" 2>/dev/null)
    _bc_centimes=$(echo "$_bc_bal_v1" | jq -r '.balances.blockchain // 0' 2>/dev/null)
    _bc_g1=$(echo "scale=2; ${_bc_centimes:-0} / 100" | bc -l 2>/dev/null)
fi
_bc_zen=$(echo "scale=1; ${_bc_g1:-0} * 10" | bc -l 2>/dev/null)
echo -e "   🏦 Banque Centrale Ğ1  : \033[0;32m${_bc_g1:-?} Ğ1 (capacité ≈ ${_bc_zen:-?} Ẑen à émettre)\033[0m"
# 2. ẑen MULTIPASS (jetons d'usage) — total émis via UPLANETG1PUB → MULTIPASS
_rev_json=$(timeout 15 "${MY_PATH}/tools/G1revenue.sh" 2>/dev/null)
_rev_zen=$(echo "$_rev_json" | jq -r '.total_revenue_zen // 0' 2>/dev/null)
_rev_nb=$(echo "$_rev_json"  | jq -r '.total_transactions // 0' 2>/dev/null)
echo -e "   🎫 ẑen MULTIPASS (usage): \033[0;32m${_rev_zen:-?} Ẑen émis (${_rev_nb:-?} transactions)\033[0m"
# 3. ẐEN SOCIETY/AMAP (jetons de propriété) — total mis en commun via UPLANETNAME_SOCIETY
_soc_json=$(timeout 15 "${MY_PATH}/tools/G1society.sh" --json-only 2>/dev/null)
_soc_zen=$(echo "$_soc_json" | jq -r '.total_outgoing_zen // 0' 2>/dev/null)
_soc_nb=$(echo "$_soc_json"  | jq -r '.total_transfers // 0' 2>/dev/null)
echo -e "   🤝 ẐEN AMAP (propriété) : \033[0;35m${_soc_zen:-?} Ẑen mis en commun (${_soc_nb:-?} contributeur(s))\033[0m"
echo -e "\033[0;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo ""

# Configuration des montants (définis dans my.sh et .env)
# Les valeurs par défaut sont définies dans my.sh (NCARD, etc.)
# Un fichier .env peut être créé à partir de env.template pour personnaliser

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

################################################################################
# Fonctions utilitaires
################################################################################

# Fonction pour afficher l'aide
show_help() {
    echo -e "${BLUE}UPLANET.official.sh - Gestion des virements officiels UPlanet${NC}"
    echo ""
    echo "Usage:"
    echo "  $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -l, --locataire EMAIL     Virement pour locataire (recharge MULTIPASS)"
    echo "  -s, --societaire EMAIL    Virement pour sociétaire (parts sociales)"
    echo "  -t, --type TYPE           Type de sociétaire: satellite|constellation|infrastructure"
    echo "  -f, --referrer EMAIL      Code parrain : le 1% de prime lui est versé (au lieu du Capitaine)"
    echo "  -i, --infrastructure      Apport capital infrastructure (CAPTAIN → CAPITAL)"
    echo "  -c, --captain EMAIL       Inscription capitaine (accès complet aux services)"
    echo "      --force               Mode force : écrase le capital existant"
    echo "      --add                 Mode ajout : cumule avec le capital existant"
    echo "  -p, --permit EMAIL ID     Virement PERMIT (récompense WoT Dragon/permit holder)"
    echo "  -m, --montant MONTANT     Montant en euros (optionnel, auto-calculé par défaut)"
    echo "  -h, --help                Affiche cette aide"
    echo ""
    echo "Exemples:"
    echo "  $0 -l user@example.com -m 20                  # Recharge MULTIPASS locataire"
    echo "  $0 -s user@example.com -t satellite           # Parts sociales satellite"
    echo "  $0 -s user@example.com -t satellite -f parrain@example.com  # Avec parrain"
    echo "  $0 -s user@example.com -t constellation       # Parts sociales constellation"
    echo "  $0 -i -m 500                                  # Apport capital infrastructure (500€)"
    echo "  $0 -i -m 200 --add                            # Ajoute 200€ au capital existant"
    echo "  $0 -i -m 500 --force                          # Réinitialise le capital à 500€"
    echo "  $0 -c support@qo-op.com                      # Inscription capitaine Astroport"
    echo "  $0 -o 43.60 1.44 -m 10                       # Récompense ORE UMAP depuis ASSETS (10Ẑen)"
    echo "  $0 -p dragon@example.com PERMIT_WOT_DRAGON  # Récompense WoT Dragon"
    echo ""
    echo "Types de sociétaires:"
    echo "  satellite     : ${ZENCARD_SATELLITE:-50}€/an (sans IA)"
    echo "  constellation : ${ZENCARD_CONSTELLATION:-540}€/3ans (avec IA)"
    echo "  infrastructure: 500€ (apport capital machine, vers UPLANETNAME_CAPITAL)"
    echo "                  Protection contre double enregistrement (--force/--add pour contourner)"
    echo ""
    echo -e "${CYAN}Configuration Coopérative (DID NOSTR):${NC}"
    echo "  Les paramètres fiscaux et coopératifs sont partagés via DID NOSTR (kind 30800)"
    echo "  Toutes les machines de l'essaim utilisent les mêmes valeurs."
    echo ""
    echo "  Voir/modifier la config:"
    echo "    source ~/.zen/Astroport.ONE/tools/cooperative_config.sh"
    echo "    coop_config_list                    # Liste toutes les clés"
    echo "    coop_config_set KEY VALUE           # Définit une valeur (auto-chiffre si sensible)"
    echo "    coop_config_refresh                 # Force la mise à jour depuis NOSTR"
}

# Fonction pour vérifier qu'il n'y a pas de transactions en cours avant de commencer
check_no_pending_transactions() {
    local wallet_pubkey="$1"
    
    echo -e "${YELLOW}🔍 Vérification rapide des transactions en cours: ${wallet_pubkey:0:8}...${NC}"
    
    # Use G1balance.sh wrapper for full JSON balance (includes pending)
    local balance_json=$("${MY_PATH}/tools/G1balance.sh" "$wallet_pubkey" 2>/dev/null)
    
    if [[ -n "$balance_json" ]] && echo "$balance_json" | jq -e '.balances' >/dev/null 2>&1; then
        # G1balance.sh returns JSON (montants en centimes, diviser par 100)
        local pending_centimes=$(echo "$balance_json" | jq -r '.balances.pending // 0' 2>/dev/null)
        local total_centimes=$(echo "$balance_json" | jq -r '.balances.total // 0' 2>/dev/null)
        
        # Valider les valeurs avant de les passer à bc
        [[ -z "$pending_centimes" || "$pending_centimes" == "null" ]] && pending_centimes="0"
        [[ -z "$total_centimes" || "$total_centimes" == "null" ]] && total_centimes="0"
        
        local pending=$(echo "scale=2; $pending_centimes / 100" | bc -l)
        local total=$(echo "scale=2; $total_centimes / 100" | bc -l)
        
        if [[ "$pending" == "0" || "$pending" == "null" || "$pending" == "0.00" ]]; then
            echo -e "${GREEN}✅ Aucune transaction en cours - Solde: ${total} Ğ1${NC}"
        else
            echo -e "${YELLOW}⚠️  Transactions en cours (Pending: ${pending} Ğ1) - Continuons quand même (vérification différée)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Impossible de récupérer le solde - Continuons quand même${NC}"
    fi
    
    return 0
}

# Fonction pour vérifier le solde d'un portefeuille avec gestion du pending
check_balance() {
    local wallet_pubkey="$1"
    local max_wait="${BLOCKCHAIN_TIMEOUT:-2400}"  # 40 minutes max par défaut
    local wait_time=0
    local interval="${VERIFICATION_INTERVAL:-60}"  # 60 secondes par défaut
    
    echo -e "${YELLOW}🔍 Vérification du solde du portefeuille: ${wallet_pubkey:0:8}...${NC}"
    
    # Récupérer le solde initial via G1balance.sh (includes pending info)
    local initial_balance_json=$("${MY_PATH}/tools/G1balance.sh" "$wallet_pubkey" 2>/dev/null)
    local initial_blockchain=0
    local initial_pending=0
    
    if [[ -n "$initial_balance_json" ]] && echo "$initial_balance_json" | jq -e '.balances' >/dev/null 2>&1; then
        # G1balance.sh returns montants en centimes, diviser par 100
        local initial_blockchain_centimes=$(echo "$initial_balance_json" | jq -r '.balances.blockchain // 0' 2>/dev/null)
        local initial_pending_centimes=$(echo "$initial_balance_json" | jq -r '.balances.pending // 0' 2>/dev/null)
        
        # Valider les valeurs avant de les passer à bc
        [[ -z "$initial_blockchain_centimes" || "$initial_blockchain_centimes" == "null" ]] && initial_blockchain_centimes="0"
        [[ -z "$initial_pending_centimes" || "$initial_pending_centimes" == "null" ]] && initial_pending_centimes="0"
        
        initial_blockchain=$(echo "scale=2; $initial_blockchain_centimes / 100" | bc -l)
        initial_pending=$(echo "scale=2; $initial_pending_centimes / 100" | bc -l)
        echo -e "${CYAN}📊 Solde initial - Blockchain: ${initial_blockchain} Ğ1, Pending: ${initial_pending} Ğ1${NC}"
    else
        echo -e "${RED}❌ Impossible de récupérer le solde initial${NC}"
        return 1
    fi
    
    while [[ $wait_time -lt $max_wait ]]; do
        local balance_json=$("${MY_PATH}/tools/G1balance.sh" "$wallet_pubkey" 2>/dev/null)
        
        if [[ -n "$balance_json" ]] && echo "$balance_json" | jq -e '.balances' >/dev/null 2>&1; then
            # G1balance.sh returns montants en centimes, diviser par 100
            local pending_centimes=$(echo "$balance_json" | jq -r '.balances.pending // 0' 2>/dev/null)
            local total_centimes=$(echo "$balance_json" | jq -r '.balances.total // 0' 2>/dev/null)
            local blockchain_centimes=$(echo "$balance_json" | jq -r '.balances.blockchain // 0' 2>/dev/null)
            
            # Valider les valeurs avant de les passer à bc
            [[ -z "$pending_centimes" || "$pending_centimes" == "null" ]] && pending_centimes="0"
            [[ -z "$total_centimes" || "$total_centimes" == "null" ]] && total_centimes="0"
            [[ -z "$blockchain_centimes" || "$blockchain_centimes" == "null" ]] && blockchain_centimes="0"
            
            local pending=$(echo "scale=2; $pending_centimes / 100" | bc -l)
            local total=$(echo "scale=2; $total_centimes / 100" | bc -l)
            local blockchain=$(echo "scale=2; $blockchain_centimes / 100" | bc -l)
            
            if [[ "$pending" == "0" || "$pending" == "null" || "$pending" == "0.00" ]]; then
                # Quand pending = 0, la transaction est confirmée
                # Le solde total devrait être stable
                echo -e "${GREEN}✅ Transaction confirmée - Solde: ${total} Ğ1${NC}"
                return 0
            else
                echo -e "${YELLOW}⏳ Transaction en cours... Pending: ${pending} Ğ1, Total: ${total} Ğ1 (attente: ${wait_time}s)${NC}"
            fi
        else
            echo -e "${YELLOW}⏳ Transaction en cours... Impossible de récupérer le solde (attente: ${wait_time}s)${NC}"
        fi
        
        sleep $interval
        wait_time=$((wait_time + interval))
    done
    
    echo -e "${RED}❌ Timeout: La transaction n'a pas été confirmée dans les 40 minutes${NC}"
    
    # Envoyer une alerte de timeout
    send_alert "BLOCKCHAIN_TIMEOUT" "$USER_EMAIL" "$TRANSACTION_TYPE" "$TRANSACTION_AMOUNT" "$CURRENT_STEP" "Transaction timeout after ${max_wait} seconds. Wallet: ${wallet_pubkey:0:8}..."
    
    return 1
}

# Fonction pour convertir Ẑen en Ğ1
# Taux standard : 1Ẑ = 0.1Ğ1 (ou 10Ẑ = 1Ğ1)
# Note : Cette fonction convertit pour les transactions blockchain
# L'historique déduit automatiquement 1Ğ1 de primo-transaction à la lecture
# Exemple : 50Ẑ à transférer = 5Ğ1 sur blockchain (sans 1Ğ1 primo qui est déjà déduit)
zen_to_g1() {
    local zen_amount="$1"
    
    # Valider que l'entrée est un nombre
    if [[ -z "$zen_amount" ]] || ! [[ "$zen_amount" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo "0"
        return 1
    fi
    
    echo "scale=2; $zen_amount / 10" | bc -l
}

# Note: Les mises à jour DID sont maintenant gérées directement par did_manager_nostr.sh
# qui publie sur Nostr et inclut automatiquement la création des fichiers U.SOCIETY pour les sociétaires

# Fonction pour envoyer une alerte par email au CAPTAINEMAIL
send_alert() {
    local alert_type="$1"
    local email="$2"
    local type="$3"
    local montant="$4"
    local step="$5"
    local error_details="$6"
    
    # Vérifier que CAPTAINEMAIL est défini
    if [[ -z "$CAPTAINEMAIL" ]]; then
        echo -e "${YELLOW}⚠️  CAPTAINEMAIL non défini, impossible d'envoyer l'alerte${NC}"
        return 1
    fi
    
    # Créer le fichier d'alerte HTML
    local alert_file="$HOME/.zen/tmp/uplanet_alert_$(date +%Y%m%d_%H%M%S).html"
    
    cat > "$alert_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>🚨 UPLANET Transaction Alert</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .alert { background-color: #ffebee; border-left: 5px solid #f44336; padding: 15px; margin: 10px 0; }
        .info { background-color: #e3f2fd; border-left: 5px solid #2196f3; padding: 15px; margin: 10px 0; }
        .details { background-color: #f5f5f5; padding: 10px; border-radius: 5px; font-family: monospace; }
        h1 { color: #f44336; }
        h2 { color: #1976d2; }
    </style>
</head>
<body>
    <h1>🚨 ALERTE TRANSACTION UPLANET</h1>
    
    <div class="alert">
        <h2>Échec de Transaction</h2>
        <p><strong>Type d'alerte:</strong> ${alert_type}</p>
        <p><strong>Date/Heure:</strong> $(date '+%Y-%m-%d %H:%M:%S UTC')</p>
    </div>
    
    <div class="info">
        <h2>Détails de la Transaction</h2>
        <p><strong>Email utilisateur:</strong> ${email}</p>
        <p><strong>Type de virement:</strong> ${type}</p>
        <p><strong>Montant:</strong> ${montant} Ẑen ($(zen_to_g1 "$montant") Ğ1)</p>
        <p><strong>Étape échouée:</strong> ${step}</p>
    </div>
    
    <div class="details">
        <h2>Détails de l'Erreur</h2>
        <pre>${error_details}</pre>
    </div>
    
    <div class="info">
        <h2>Actions Recommandées</h2>
        <ul>
            <li>Vérifier la connectivité blockchain</li>
            <li>Contrôler les soldes des portefeuilles intermédiaires</li>
            <li>Reprendre manuellement la transaction si nécessaire</li>
            <li>Contacter l'utilisateur: ${email}</li>
        </ul>
    </div>
    
    <hr>
    <p><small>Alerte générée automatiquement par UPLANET.official.sh</small></p>
</body>
</html>
EOF
    
    # Envoyer l'alerte via mailjet.sh
    echo -e "${YELLOW}📧 Envoi d'alerte à ${CAPTAINEMAIL}...${NC}"
    if "${MY_PATH}/tools/mailjet.sh" --expire 3d "$CAPTAINEMAIL" "$alert_file" "🚨 UPLANET Transaction Failed - ${alert_type}"; then
        echo -e "${GREEN}✅ Alerte envoyée avec succès à ${CAPTAINEMAIL}${NC}"
        # Garder le fichier d'alerte pour les logs
        mkdir -p "$HOME/.zen/tmp/alerts/"
        mv "$alert_file" "$HOME/.zen/tmp/alerts/"
        return 0
    else
        echo -e "${RED}❌ Échec de l'envoi d'alerte à ${CAPTAINEMAIL}${NC}"
        return 1
    fi
}

# Fonction pour effectuer un transfert avec PAYforSURE.sh (sans attendre les pending)
transfer_and_verify() {
    local dunikey_file="$1"
    local to_wallet="$2"
    local zen_amount="$3"
    local description="$4"
    local user_email="$5"
    local transaction_type="$6"
    local step_name="$7"
    
    # Convertir Ẑen en Ğ1 (1 Ẑen = 0.1 Ğ1)
    local g1_amount=$(zen_to_g1 "$zen_amount")
    
    echo -e "${BLUE}💰 Transfert: ${zen_amount} Ẑen (${g1_amount} Ğ1) vers ${to_wallet:0:8}${NC}"
    echo -e "${CYAN}📝 Description: ${description}${NC}"
    
    # Vérifier que PAYforSURE.sh existe
    if [[ ! -f "${MY_PATH}/tools/PAYforSURE.sh" ]]; then
        echo -e "${RED}❌ PAYforSURE.sh non trouvé dans ${MY_PATH}/tools/${NC}"
        send_alert "PAYFORSURE_ERROR" "$user_email" "$transaction_type" "$zen_amount" "$step_name" "PAYforSURE.sh non trouvé"
        return 1
    fi
    
    # Vérifier que le fichier dunikey existe
    if [[ -z "$dunikey_file" || ! -f "$dunikey_file" ]]; then
        echo -e "${RED}❌ Fichier dunikey manquant ou invalide: $dunikey_file${NC}"
        send_alert "DUNIKEY_ERROR" "$user_email" "$transaction_type" "$zen_amount" "$step_name" "Fichier dunikey manquant ou invalide: $dunikey_file"
        return 1
    fi
    
    # Récupérer la clé publique source pour la vérification différée
    local source_pubkey=$(cat "$dunikey_file" | grep 'pub:' | cut -d ' ' -f 2)
    if [[ -z "$source_pubkey" ]]; then
        echo -e "${RED}❌ Impossible de récupérer la clé publique depuis le fichier dunikey${NC}"
        send_alert "PUBKEY_ERROR" "$user_email" "$transaction_type" "$zen_amount" "$step_name" "Impossible de récupérer la clé publique depuis: $dunikey_file"
        return 1
    fi
    
    # Effectuer le transfert avec PAYforSURE.sh
    echo -e "${YELLOW}📤 Utilisation de PAYforSURE.sh pour le transfert...${NC}"
    "${MY_PATH}/tools/PAYforSURE.sh" "$dunikey_file" "$g1_amount" "$to_wallet" "$description"
    local transfer_exit_code=$?
    
    if [[ $transfer_exit_code -eq 0 ]]; then
        echo -e "${GREEN}✅ Transfert confirmé${NC}"
        return 0
    else
        echo -e "${RED}❌ Erreur lors du transfert (code: $transfer_exit_code)${NC}"
        send_alert "TRANSFER_ERROR" "$user_email" "$transaction_type" "$zen_amount" "$step_name" "Erreur PAYforSURE.sh: exit code $transfer_exit_code"
        return 1
    fi
}

# Fonction pour calculer le montant en Ẑen basé sur le type de sociétaire
calculate_societaire_amount() {
    local type="$1"
    
    case "$type" in
        "satellite")
            echo "${ZENCARD_SATELLITE:-50}"  # 50€ = 50 Ẑen (valeur par défaut)
            ;;
        "constellation")
            echo "${ZENCARD_CONSTELLATION:-540}" # 540€ = 540 Ẑen (valeur par défaut)
            ;;
        "infrastructure")
            echo "${MACHINE_VALUE_ZEN:-500}" # 500€ = 500 Ẑen (apport capital machine)
            ;;
        *)
            echo "0"
            ;;
    esac
}

################################################################################
# Fonction principale pour virement PERMIT (récompenses pour permits WoT Dragon)
################################################################################
virement_permit() {
    local email="$1"
    local permit_id="$2"
    local credential_id="${3:-}"
    local montant_euros="${4:-100}"  # 100 Ẑen par défaut pour WoT Dragon
    
    # Valider que le montant est un nombre valide
    if [[ -z "$montant_euros" ]] || ! [[ "$montant_euros" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo -e "${RED}❌ Montant invalide: '$montant_euros'${NC}"
        echo -e "${YELLOW}💡 Utilisez un nombre positif (ex: 100)${NC}"
        return 1
    fi
    
    local montant_g1=$(zen_to_g1 "$montant_euros")
    
    echo -e "${BLUE}🎫 Traitement virement PERMIT pour: ${email}${NC}"
    echo -e "${CYAN}💰 Montant: ${montant_euros} Ẑen = ${montant_g1} Ğ1${NC}"
    echo -e "${YELLOW}🏛️ Type: ${permit_id}${NC}"
    
    # Vérifier que le portefeuille RnD existe
    if [[ ! -f "$HOME/.zen/game/uplanet.RnD.dunikey" ]]; then
        echo -e "${RED}❌ Portefeuille UPLANETNAME_RnD non configuré${NC}"
        echo "💡 Exécutez ZEN.COOPERATIVE.3x1-3.sh pour créer les portefeuilles coopératifs"
        return 1
    fi
    
    # Récupérer la clé publique RnD de UPlanet
    local rnd_pubkey=$(cat "$HOME/.zen/game/uplanet.RnD.dunikey" | grep "pub:" | cut -d ' ' -f 2)
    if [[ -z "$rnd_pubkey" ]]; then
        echo -e "${RED}❌ Impossible de récupérer la clé publique RnD${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Portefeuille RnD trouvé: ${rnd_pubkey:0:8}...${NC}"
    
    # Récupérer la clé publique du MULTIPASS du bénéficiaire
    local multipass_pubkey=$(cat "$HOME/.zen/game/nostr/${email}/G1PUBNOSTR" 2>/dev/null)
    if [[ -z "$multipass_pubkey" ]]; then
        echo -e "${RED}❌ MULTIPASS non trouvé pour ${email}${NC}"
        echo "💡 Créez un MULTIPASS avec make_NOSTRCARD.sh"
        return 1
    fi
    
    # Vérifier qu'il n'y a pas de transactions en cours avant de commencer
    echo -e "${BLUE}🔍 Vérification préalable des transactions en cours...${NC}"
    if ! check_no_pending_transactions "$rnd_pubkey"; then
        echo -e "${RED}❌ Impossible de commencer le virement: des transactions sont en cours${NC}"
        echo -e "${YELLOW}💡 Attendez que les transactions en cours se terminent avant de relancer${NC}"
        return 1
    fi
    
    # Générer le credential_id si non fourni
    if [[ -z "$credential_id" ]]; then
        credential_id=$(date +%s | sha256sum | cut -c1-16)
    fi
    
    # Transfert direct: UPLANETNAME_RnD -> MULTIPASS (permit holder)
    echo -e "${BLUE}📤 Transfert UPLANETNAME_RnD → MULTIPASS (permit holder)${NC}"
    local permit_reference="UPLANET:${UPLANETG1PUB:0:8}:PERMIT:${permit_id}:${email}:${credential_id}:${IPFSNODEID}"
    
    if ! transfer_and_verify "$HOME/.zen/game/uplanet.RnD.dunikey" "$multipass_pubkey" "$montant_euros" "$permit_reference" "$email" "PERMIT" "RnD→MULTIPASS(PERMIT)"; then
        echo -e "${RED}❌ Échec du virement PERMIT${NC}"
        return 1
    fi
    
    echo -e "${GREEN}🎉 Virement PERMIT terminé avec succès!${NC}"
    echo -e "${CYAN}📊 Résumé:${NC}"
    echo -e "  • ${montant_euros} Ẑen (${montant_g1} Ğ1) transférés vers ${email}"
    echo -e "  • Permit: ${permit_id}"
    echo -e "  • Credential: ${credential_id}"
    echo -e "  • Récompense pour WoT permit holder"
    echo -e "  • Transaction confirmée sur la blockchain"
    
    # Mettre à jour le document DID avec le permit
    echo -e "${YELLOW}📝 Mise à jour du DID...${NC}"
    "${MY_PATH}/tools/did_manager_nostr.sh" update "$email" "PERMIT_ISSUED" "$montant_euros" "$montant_g1"
    
    return 0
}

################################################################################
# Fonction principale pour virement ORE (récompenses environnementales)
################################################################################
process_ore() {
    local lat="$1"
    local lon="$2"
    local montant_euros="${3:-10}"  # 10 Ẑen par défaut pour récompense ORE
    
    # Valider que le montant est un nombre valide
    if [[ -z "$montant_euros" ]] || ! [[ "$montant_euros" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo -e "${RED}❌ Montant invalide: '$montant_euros'${NC}"
        echo -e "${YELLOW}💡 Utilisez un nombre positif (ex: 10)${NC}"
        return 1
    fi
    
    local montant_g1=$(zen_to_g1 "$montant_euros")
    
    echo -e "${BLUE}🌱 Traitement virement ORE pour UMAP: (${lat}, ${lon})${NC}"
    echo -e "${CYAN}💰 Montant: ${montant_euros} Ẑen = ${montant_g1} Ğ1${NC}"
    echo -e "${YELLOW}🏛️ Source: Portefeuille ASSETS (réserves coopératives)${NC}"
    
    # Vérifier que le portefeuille ASSETS existe (créé par ZEN.COOPERATIVE.3x1-3.sh)
    if [[ ! -f "$HOME/.zen/game/uplanet.ASSETS.dunikey" ]]; then
        echo -e "${RED}❌ Portefeuille UPLANETNAME_ASSETS non configuré${NC}"
        echo "💡 Exécutez ZEN.COOPERATIVE.3x1-3.sh pour créer les portefeuilles coopératifs"
        return 1
    fi
    
    # Récupérer la clé publique ASSETS
    local assets_pubkey=$(cat "$HOME/.zen/game/uplanet.ASSETS.dunikey" | grep "pub:" | cut -d ' ' -f 2)
    if [[ -z "$assets_pubkey" ]]; then
        echo -e "${RED}❌ Impossible de lire la clé publique ASSETS${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Portefeuille ASSETS trouvé: ${assets_pubkey:0:8}...${NC}"
    
    # Générer le DID UMAP
    echo -e "${YELLOW}🔑 Génération du DID UMAP...${NC}"
    local umap_did_result=$(python3 "${MY_PATH}/tools/ore_system.py" "generate_did" "$lat" "$lon" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Échec de génération du DID UMAP${NC}"
        return 1
    fi
    
    # Extraire le DID et la clé publique UMAP
    local umap_did=$(echo "$umap_did_result" | grep "DID:" | cut -d ' ' -f 2)
    local umap_npub=$(echo "$umap_did_result" | grep "NPUB:" | cut -d ' ' -f 2)
    local umap_hex=$(echo "$umap_did_result" | grep "HEX:" | cut -d ' ' -f 2)
    local umap_g1pub=$(echo "$umap_did_result" | grep "G1PUB:" | cut -d ' ' -f 2)
    
    if [[ -z "$umap_did" || -z "$umap_g1pub" ]]; then
        echo -e "${RED}❌ Impossible d'extraire le DID UMAP ou la clé G1${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ DID UMAP généré: ${umap_did:0:20}...${NC}"
    echo -e "${GREEN}✅ Clé publique Duniter/Ğ1: ${umap_g1pub:0:8}...${NC}"
    echo -e "${CYAN}   Clé Nostr (hex): ${umap_hex:0:16}...${NC}"
    
    # Vérifier qu'il n'y a pas de transactions en cours avant de commencer
    echo -e "${BLUE}🔍 Vérification préalable des transactions en cours...${NC}"
    if ! check_no_pending_transactions "$assets_pubkey"; then
        echo -e "${RED}❌ Impossible de commencer le virement: des transactions sont en cours${NC}"
        echo -e "${YELLOW}💡 Attendez que les transactions en cours se terminent avant de relancer${NC}"
        return 1
    fi
    
    # Étape 1: UPLANETNAME_ASSETS -> UMAP DID
    echo -e "${BLUE}📤 Étape 1: Transfert UPLANETNAME_ASSETS → UMAP DID${NC}"
    local ore_reference="UPLANET:${UPLANETG1PUB:0:8}:ORE:${umap_hex:0:8}:${lat}:${lon}:${IPFSNODEID}"
    
    # Use G1 base58 public key for blockchain transaction (not hex key)
    if ! transfer_and_verify "$HOME/.zen/game/uplanet.ASSETS.dunikey" "$umap_g1pub" "$montant_euros" "$ore_reference" "ORE_UMAP_${lat}_${lon}" "ORE" "Étape 1: ASSETS→UMAP_DID"; then
        echo -e "${RED}❌ Échec de l'étape 1${NC}"
        return 1
    fi
    
    echo -e "${GREEN}🎉 Virement ORE terminé avec succès!${NC}"
    echo -e "${CYAN}📊 Résumé:${NC}"
    echo -e "  • ${montant_euros} Ẑen (${montant_g1} Ğ1) transférés depuis ASSETS vers UMAP DID"
    echo -e "  • UMAP: (${lat}, ${lon})"
    echo -e "  • DID: ${umap_did}"
    echo -e "  • Source: Portefeuille ASSETS (réserves coopératives)"
    echo -e "  • Récompense environnementale distribuée"
    echo -e "  • Toutes les transactions confirmées sur la blockchain"
    
    # Mettre à jour le document DID avec les récompenses ORE
    echo -e "${YELLOW}📝 Mise à jour du DID UMAP...${NC}"
    # Note: Le DID UMAP est géré par le système ORE, pas par did_manager_nostr.sh
    # qui gère les DIDs utilisateurs (MULTIPASS/ZenCard)
    
    return 0
}

################################################################################
# Fonction pour s'assurer qu'un portefeuille est initialisé (primo TX différée)
# La primo TX (1 Ğ1) n'est envoyée que lorsque des ẐEN sont effectivement reçus,
# évitant ainsi de perdre des Ğ1 pour des MULTIPASS/ZEN Card jamais activés.
#
# Duniter v2 : un wallet non initialisé (solde = 0) ne peut pas recevoir de tx.
# On envoie 1 Ğ1 depuis UPLANETNAME_G1 pour établir le lien primal.
################################################################################
ensure_wallet_initialized() {
    local pubkey="$1"
    local label="${2:-wallet}"   # Description pour les logs
    local email="${3:-}"         # Email associé (pour archivage G1PRIME)

    # Vérification rapide via cache primal
    if [[ -s "$HOME/.zen/tmp/coucou/${pubkey}.primal" ]]; then
        echo -e "${GREEN}✅ ${label} déjà initialisé (primal cache)${NC}"
        return 0
    fi

    # Vérifier le solde blockchain
    echo -e "${YELLOW}🔍 Vérification initialisation ${label}: ${pubkey:0:8}...${NC}"
    local balance
    balance=$("${MY_PATH}/tools/G1check.sh" "${pubkey}" 2>/dev/null | tail -n 1)

    if [[ -n "$balance" ]] && (( $(echo "${balance:-0} > 0" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "${GREEN}✅ ${label} déjà initialisé (solde: ${balance} Ğ1)${NC}"
        # Mettre le cache à jour
        echo "${UPLANETNAME_G1}" > "$HOME/.zen/tmp/coucou/${pubkey}.primal"
        return 0
    fi

    # Wallet non initialisé → envoyer la primo TX
    echo -e "${BLUE}📤 Primo TX: initialisation ${label} depuis UPLANETNAME_G1...${NC}"

    if [[ ! -f "$HOME/.zen/game/uplanet.G1.dunikey" ]]; then
        echo -e "${RED}❌ Fichier uplanet.G1.dunikey manquant — impossible d'initialiser ${label}${NC}"
        return 1
    fi

    local youser=""
    [[ -n "$email" ]] && youser=$("${MY_PATH}/tools/clyuseryomail.sh" "${email}" 2>/dev/null)
    local primo_comment="UPLANET:${UPLANETG1PUB:0:8}:${youser:-INIT}:${label}:PRIMAL"

    "${MY_PATH}/tools/PAYforSURE.sh" \
        "${HOME}/.zen/game/uplanet.G1.dunikey" \
        "1" \
        "${pubkey}" \
        "${primo_comment}" 2>/dev/null

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Primo TX envoyée: 1 Ğ1 → ${label} (${pubkey:0:8}...)${NC}"
        # Marquer comme initialisé
        echo "${UPLANETNAME_G1}" > "$HOME/.zen/tmp/coucou/${pubkey}.primal"
        [[ -n "$email" ]] && echo "${UPLANETNAME_G1}" > "$HOME/.zen/game/nostr/${email}/G1PRIME" 2>/dev/null
        return 0
    else
        echo -e "${RED}❌ Primo TX échouée pour ${label} — blocage Duniter v2 possible${NC}"
        return 1
    fi
}

################################################################################
# Fonction principale pour virement locataire
################################################################################
process_locataire() {
    local email="$1"
    local montant_euros="${2:-${NCARD:-50}}"
    
    # Valider que le montant est un nombre valide
    if [[ -z "$montant_euros" ]] || ! [[ "$montant_euros" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo -e "${RED}❌ Montant invalide: '$montant_euros'${NC}"
        echo -e "${YELLOW}💡 Utilisez un nombre positif (ex: 50)${NC}"
        return 1
    fi
    
    local montant_g1=$(zen_to_g1 "$montant_euros")
    
    echo -e "${BLUE}🏠 Traitement virement MULTIPASS pour: ${email}${NC}"
    echo -e "${CYAN}💰 Montant: ${montant_euros} Ẑen = ${montant_g1} Ğ1${NC}"
    
    # Vérifier que les portefeuilles existent
    if [[ ! -f "$HOME/.zen/tmp/UPLANETNAME_G1" ]]; then
        echo -e "${RED}❌ Portefeuille UPLANETNAME_G1 non configuré${NC}"
        echo "💡 Utilisez zen.sh → UPLANETNAME_G1 pour configurer"
        return 1
    fi
    
    if [[ ! -f "$HOME/.zen/tmp/UPLANETG1PUB" ]]; then
        echo -e "${RED}❌ Portefeuille UPLANETNAME non configuré${NC}"
        echo "💡 Utilisez zen.sh → UPLANETNAME pour configurer"
        return 1
    fi
    
    # Récupérer les clés publiques
    local g1_pubkey=$(cat "$HOME/.zen/tmp/UPLANETNAME_G1")
    local uplanet_pubkey=$(cat "$HOME/.zen/tmp/UPLANETG1PUB")

    # Résolution G1PUBNOSTR : local → cache node → swarm
    # _is_local=true  : compte hébergé ici → ensure_wallet + DID update possibles
    # _is_local=false : compte swarm     → TX blockchain seulement, DID mis à jour par la station d'origine
    local multipass_pubkey="" _is_local=false
    if [[ -f "$HOME/.zen/game/nostr/${email}/G1PUBNOSTR" ]]; then
        multipass_pubkey=$(cat "$HOME/.zen/game/nostr/${email}/G1PUBNOSTR" 2>/dev/null)
        _is_local=true
        echo -e "${GREEN}✅ MULTIPASS local${NC}"
    elif [[ -f "$HOME/.zen/tmp/${IPFSNODEID}/TW/${email}/G1PUBNOSTR" ]]; then
        multipass_pubkey=$(cat "$HOME/.zen/tmp/${IPFSNODEID}/TW/${email}/G1PUBNOSTR" 2>/dev/null)
        echo -e "${YELLOW}⚠️  MULTIPASS trouvé dans le cache node local (non local)${NC}"
    fi

    if [[ -z "$multipass_pubkey" ]]; then
        echo -e "${RED}❌ G1PUBNOSTR introuvable pour ${email} (local, cache, swarm)${NC}"
        echo -e "${CYAN}💡 Vérifiez que le MULTIPASS existe : ~/.zen/game/nostr/${email}/G1PUBNOSTR${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}🔑 Portefeuilles identifiés:${NC}"
    echo -e "  UPLANETNAME_G1: ${g1_pubkey:0:8}..."
    echo -e "  UPLANETNAME: ${uplanet_pubkey:0:8}..."
    echo -e "  MULTIPASS ${email}: ${multipass_pubkey:0:8}..."

    # Primo TX différée : uniquement pour les comptes locaux (nécessite G1PRIME local)
    if [[ "$_is_local" == "true" ]]; then
        if ! ensure_wallet_initialized "$multipass_pubkey" "MULTIPASS" "$email"; then
            echo -e "${RED}❌ Impossible d'initialiser le MULTIPASS — Duniter v2 indisponible ?${NC}"
            return 1
        fi
    else
        echo -e "${CYAN}ℹ️  Primo TX ignorée — MULTIPASS swarm, initialisation gérée par la station d'origine${NC}"
    fi

    # Vérifier qu'il n'y a pas de transactions en cours avant de commencer
    echo -e "${BLUE}🔍 Vérification préalable des transactions en cours...${NC}"
    if ! check_no_pending_transactions "$g1_pubkey"; then
        echo -e "${RED}❌ Impossible de commencer le virement: des transactions sont en cours${NC}"
        echo -e "${YELLOW}💡 Attendez que les transactions en cours se terminent avant de relancer${NC}"
        return 1
    fi
    
    # Étape 1: UPLANETNAME_G1 -> UPLANETNAME
    echo -e "${BLUE}📤 Étape 1: Transfert UPLANETNAME_G1 → UPLANETNAME${NC}"
    if ! transfer_and_verify "$HOME/.zen/game/uplanet.G1.dunikey" "$uplanet_pubkey" "$montant_euros" "UPLANET:${UPLANETG1PUB:0:8}:ZENCOIN:${email}" "$email" "MULTIPASS" "Étape 1: G1→UPLANET"; then
        echo -e "${RED}❌ Échec de l'étape 1${NC}"
        return 1
    fi
    
    # Étape 2: UPLANETNAME -> MULTIPASS
    echo -e "${BLUE}📤 Étape 2: Transfert UPLANETNAME → MULTIPASS ${email}${NC}"
    if ! transfer_and_verify "$HOME/.zen/game/uplanet.dunikey" "$multipass_pubkey" "$montant_euros" "UPLANET:${UPLANETG1PUB:0:8}:ZENCOIN:${email}" "$email" "MULTIPASS" "Étape 2: UPLANET→MULTIPASS"; then
        echo -e "${RED}❌ Échec de l'étape 2${NC}"
        return 1
    fi
    
    echo -e "${GREEN}🎉 Virement locataire terminé avec succès!${NC}"
    echo -e "${CYAN}📊 Résumé:${NC}"
    echo -e "  • ${montant_euros} Ẑen (${montant_g1} Ğ1) transférés vers MULTIPASS ${email}"
    echo -e "  • Recharge de service hebdomadaire effectuée"
    echo -e "  • Toutes les transactions confirmées sur la blockchain"
    
    # Mettre à jour le DID uniquement pour les comptes locaux
    # Pour les comptes swarm : DID mis à jour par la station d'origine via NOSTRCARD.refresh.sh
    if [[ "$_is_local" == "true" ]]; then
        "${MY_PATH}/tools/did_manager_nostr.sh" update "$email" "MULTIPASS" "$montant_euros" "$montant_g1"
    else
        echo -e "${CYAN}ℹ️  DID non mis à jour localement — MULTIPASS swarm, géré par la station d'origine${NC}"
    fi
    
    return 0
}

################################################################################
# Fonction pour apport capital infrastructure (immobilisations - Compte 21)
# Le capital va vers UPLANETNAME_CAPITAL (pas NODE) pour séparation comptable :
# - UPLANETNAME_CAPITAL : Immobilisations corporelles (valeur machine, amortissement)
# - NODE : Revenus locatifs Armateur (PAF, burn vers €)
#
# PROTECTION: Un seul enregistrement initial autorisé. Utilisez --force pour
# réinitialiser (écrase l'ancien) ou --add pour ajouter (cumule avec l'ancien).
################################################################################
process_infrastructure() {
    local email="$1"
    local montant_euros="${2:-$(calculate_societaire_amount "infrastructure")}"
    local force_mode="${3:-}"  # "--force" to overwrite, "--add" to accumulate
    
    # Valider que le montant est un nombre valide
    if [[ -z "$montant_euros" ]] || ! [[ "$montant_euros" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo -e "${RED}❌ Montant invalide: '$montant_euros'${NC}"
        echo -e "${YELLOW}💡 Utilisez un nombre positif (ex: 500)${NC}"
        return 1
    fi
    
    # ══════════════════════════════════════════════════════════════════════════
    # PROTECTION CONTRE DOUBLE ENREGISTREMENT
    # ══════════════════════════════════════════════════════════════════════════
    local env_file="$HOME/.zen/game/.env"
    local existing_machine_value=""
    local existing_capital_date=""
    local existing_depreciation_weeks=""
    
    if [[ -f "$env_file" ]]; then
        existing_machine_value=$(grep "^MACHINE_VALUE=" "$env_file" | cut -d'=' -f2)
        existing_capital_date=$(grep "^CAPITAL_DATE=" "$env_file" | cut -d'=' -f2)
        existing_depreciation_weeks=$(grep "^DEPRECIATION_WEEKS=" "$env_file" | cut -d'=' -f2)
    fi
    
    if [[ -n "$existing_machine_value" && "$existing_machine_value" != "0" ]]; then
        echo -e "${YELLOW}⚠️  CAPITAL INFRASTRUCTURE DÉJÀ ENREGISTRÉ !${NC}"
        echo -e "${CYAN}📊 Enregistrement existant :${NC}"
        echo -e "   • Valeur machine : ${existing_machine_value} Ẑen"
        echo -e "   • Date d'activation : ${existing_capital_date}"
        echo -e "   • Durée amortissement : ${existing_depreciation_weeks} semaines"
        
        # Calculate current depreciation status
        if [[ -n "$existing_capital_date" && -n "$existing_depreciation_weeks" ]]; then
            local cap_timestamp=$(date -d "$existing_capital_date" +%s 2>/dev/null || echo "0")
            local now_timestamp=$(date +%s)
            local weeks_elapsed=$(( (now_timestamp - cap_timestamp) / (7 * 24 * 60 * 60) ))
            local depreciation_pct=$(echo "scale=1; ($weeks_elapsed * 100) / $existing_depreciation_weeks" | bc -l 2>/dev/null || echo "0")
            [[ $(echo "$depreciation_pct > 100" | bc -l) -eq 1 ]] && depreciation_pct="100"
            local residual=$(echo "scale=2; $existing_machine_value * (1 - $weeks_elapsed / $existing_depreciation_weeks)" | bc -l 2>/dev/null || echo "0")
            [[ $(echo "$residual < 0" | bc -l) -eq 1 ]] && residual="0"
            echo -e "   • Semaines écoulées : ${weeks_elapsed}/${existing_depreciation_weeks}"
            echo -e "   • Amortissement : ${depreciation_pct}%"
            echo -e "   • Valeur résiduelle : ~${residual} Ẑen"
        fi
        echo ""
        
        if [[ "$force_mode" == "--force" ]]; then
            echo -e "${RED}🔄 MODE FORCE : L'ancien capital sera ÉCRASÉ et remplacé${NC}"
            echo -e "${YELLOW}⚠️  L'amortissement reprendra à zéro !${NC}"
        elif [[ "$force_mode" == "--add" ]]; then
            echo -e "${GREEN}➕ MODE ADD : Le nouveau capital sera AJOUTÉ à l'ancien${NC}"
            # Calculate new total
            local new_total=$(echo "scale=2; $existing_machine_value + $montant_euros" | bc -l)
            echo -e "${CYAN}   Nouvelle valeur totale : ${new_total} Ẑen${NC}"
            montant_euros="$new_total"
            # Keep original depreciation start date
            echo -e "${YELLOW}⚠️  La date d'amortissement reste inchangée (${existing_capital_date})${NC}"
        else
            echo -e "${RED}❌ Double enregistrement refusé pour préserver l'intégrité comptable${NC}"
            echo ""
            echo -e "${CYAN}💡 Options disponibles :${NC}"
            echo -e "   $0 -i --force    # Écrase l'ancien capital (réinitialise amortissement)"
            echo -e "   $0 -i --add      # Ajoute au capital existant (cumule valeur)"
            echo ""
            echo -e "${YELLOW}📋 Pour voir l'état actuel, utilisez : dashboard.sh${NC}"
            return 1
        fi
        echo ""
    fi
    
    local montant_g1=$(zen_to_g1 "$montant_euros")
    
    echo -e "${BLUE}⚙️ Traitement APPORT CAPITAL INFRASTRUCTURE pour: ${email}${NC}"
    echo -e "${CYAN}💰 Montant: ${montant_euros} Ẑen = ${montant_g1} Ğ1 → UPLANETNAME_CAPITAL${NC}"
    echo -e "${YELLOW}📊 Amortissement linéaire sur 3 ans (156 semaines)${NC}"
    
    # Vérifier que les portefeuilles existent
    if [[ ! -f "$HOME/.zen/tmp/UPLANETNAME_G1" ]]; then
        echo -e "${RED}❌ Portefeuille UPLANETNAME_G1 non configuré${NC}"
        echo "💡 Utilisez zen.sh → UPLANETNAME_G1 pour configurer"
        return 1
    fi
    
    # Récupérer les clés publiques
    local g1_pubkey=$(cat "$HOME/.zen/tmp/UPLANETNAME_G1")
    
    # Récupérer la clé ZEN Card du capitaine
    local zencard_pubkey=""
    local zencard_dunikey="$HOME/.zen/game/players/${email}/secret.dunikey"
    local zencard_g1pub="$HOME/.zen/game/players/${email}/.g1pub"
    
    if [[ -f "$zencard_dunikey" ]]; then
        zencard_pubkey=$(cat "$zencard_dunikey" | grep "pub:" | cut -d ' ' -f 2)
        echo -e "${GREEN}✅ ZEN Card trouvée: ${zencard_pubkey:0:8}...${NC}"
    elif [[ -f "$zencard_g1pub" ]]; then
        zencard_pubkey=$(cat "$zencard_g1pub")
        echo -e "${GREEN}✅ ZEN Card trouvée (g1pub): ${zencard_pubkey:0:8}...${NC}"
    else
        echo -e "${RED}❌ ZEN Card non trouvée pour ${email}${NC}"
        echo -e "${CYAN}💡 Vérifiez que le dossier ~/.zen/game/players/${email}/ existe${NC}"
        return 1
    fi
    
    # Récupérer/créer le portefeuille UPLANETNAME_CAPITAL
    local capital_pubkey=""
    if [[ -f "$HOME/.zen/game/uplanet.CAPITAL.dunikey" ]]; then
        capital_pubkey=$(cat "$HOME/.zen/game/uplanet.CAPITAL.dunikey" | grep "pub:" | cut -d ' ' -f 2)
        echo -e "${GREEN}✅ UPLANETNAME_CAPITAL trouvé: ${capital_pubkey:0:8}...${NC}"
    else
        # Create CAPITAL wallet if it doesn't exist
        echo -e "${YELLOW}📦 Création du portefeuille UPLANETNAME_CAPITAL...${NC}"
        "${MY_PATH}/tools/keygen" -t duniter -o "$HOME/.zen/game/uplanet.CAPITAL.dunikey" "${UPLANETNAME}.CAPITAL" "${UPLANETNAME}.CAPITAL"
        chmod 600 "$HOME/.zen/game/uplanet.CAPITAL.dunikey"
        capital_pubkey=$(cat "$HOME/.zen/game/uplanet.CAPITAL.dunikey" | grep "pub:" | cut -d ' ' -f 2)
        echo ${capital_pubkey} > $HOME/.zen/tmp/UPLANETNAME_CAPITAL
        echo -e "${GREEN}✅ UPLANETNAME_CAPITAL créé: ${capital_pubkey:0:8}...${NC}"
    fi
    
    echo -e "${YELLOW}🔑 Portefeuilles identifiés:${NC}"
    echo -e "  UPLANETNAME_G1: ${g1_pubkey:0:8}..."
    echo -e "  ZEN Card ${email}: ${zencard_pubkey:0:8}..."
    echo -e "  UPLANETNAME_CAPITAL (Immobilisations): ${capital_pubkey:0:8}..."
    
    # Vérifier qu'il n'y a pas de transactions en cours avant de commencer
    echo -e "${BLUE}🔍 Vérification préalable des transactions en cours...${NC}"
    if ! check_no_pending_transactions "$g1_pubkey"; then
        echo -e "${RED}❌ Impossible de commencer le virement: des transactions sont en cours${NC}"
        echo -e "${YELLOW}💡 Attendez que les transactions en cours se terminent avant de relancer${NC}"
        return 1
    fi
    
    # Étape 1: UPLANETNAME_G1 -> ZEN Card (traçabilité de l'apporteur)
    echo -e "${BLUE}📤 Étape 1: Transfert UPLANETNAME_G1 → ZEN Card ${email}${NC}"
    if ! transfer_and_verify "$HOME/.zen/game/uplanet.G1.dunikey" "$zencard_pubkey" "$montant_euros" "UPLANET:${UPLANETG1PUB:0:8}:CAPITAL:${email}:${IPFSNODEID}" "$email" "INFRASTRUCTURE" "Étape 1: G1→ZENCARD"; then
        echo -e "${RED}❌ Échec de l'étape 1${NC}"
        return 1
    fi
    
    # Étape 2: ZEN Card -> UPLANETNAME_CAPITAL (Immobilisations corporelles)
    echo -e "${BLUE}📤 Étape 2: Transfert ZEN Card → UPLANETNAME_CAPITAL (Immobilisations)${NC}"
    if ! transfer_and_verify "$zencard_dunikey" "$capital_pubkey" "$montant_euros" "UPLANET:${UPLANETG1PUB:0:8}:CAPITAL:${email}:${IPFSNODEID}" "$email" "INFRASTRUCTURE" "Étape 2: ZENCARD→CAPITAL"; then
        echo -e "${RED}❌ Échec de l'étape 2${NC}"
        return 1
    fi
    
    # Enregistrer la date de début d'amortissement et la valeur dans .env
    # Note: env_file already defined at start of function for double-registration check
    local capital_date=""
    
    # In --add mode, keep original date; otherwise use current date
    if [[ "$force_mode" == "--add" && -n "$existing_capital_date" ]]; then
        capital_date="$existing_capital_date"
        echo -e "${CYAN}📅 Conservation de la date d'amortissement originale : ${capital_date}${NC}"
    else
        capital_date=$(date +%Y%m%d%H%M%S)
    fi
    
    if [[ -f "$env_file" ]]; then
        # Update existing values or add new ones
        if grep -q "^MACHINE_VALUE=" "$env_file"; then
            sed -i "s/^MACHINE_VALUE=.*/MACHINE_VALUE=$montant_euros/" "$env_file"
        else
            echo "MACHINE_VALUE=$montant_euros" >> "$env_file"
        fi
        if grep -q "^CAPITAL_DATE=" "$env_file"; then
            sed -i "s/^CAPITAL_DATE=.*/CAPITAL_DATE=$capital_date/" "$env_file"
        else
            echo "CAPITAL_DATE=$capital_date" >> "$env_file"
        fi
        if grep -q "^DEPRECIATION_WEEKS=" "$env_file"; then
            sed -i "s/^DEPRECIATION_WEEKS=.*/DEPRECIATION_WEEKS=156/" "$env_file"
        else
            echo "DEPRECIATION_WEEKS=156" >> "$env_file"
        fi
    else
        # Create .env with capital info
        echo "## ASTROPORT MACHINE CAPITAL CONFIGURATION" >> "$env_file"
        echo "MACHINE_VALUE=$montant_euros" >> "$env_file"
        echo "CAPITAL_DATE=$capital_date" >> "$env_file"
        echo "DEPRECIATION_WEEKS=156" >> "$env_file"
    fi
    
    # Calculate weekly depreciation for display
    local weekly_depreciation=$(echo "scale=2; $montant_euros / 156" | bc -l)
    
    echo -e "${GREEN}🎉 Apport capital infrastructure terminé avec succès!${NC}"
    echo -e "${CYAN}📊 Résumé:${NC}"
    echo -e "  • ${montant_euros} Ẑen (${montant_g1} Ğ1) transférés vers UPLANETNAME_CAPITAL"
    echo -e "  • Compte 21 - Immobilisations corporelles"
    echo -e "  • Amortissement linéaire: ~${weekly_depreciation} Ẑen/semaine pendant 3 ans"
    echo -e "  • Les amortissements hebdo iront vers CASH (réserve de fonctionnement)"
    echo -e "  • NODE reste dédié aux revenus locatifs (PAF → BURN → €)"
    echo -e "  • ✅ Séparation comptable Capital/Revenus respectée"
    
    # Mettre à jour le document DID avec le statut contributeur infrastructure
    "${MY_PATH}/tools/did_manager_nostr.sh" update "$email" "INFRASTRUCTURE" "$montant_euros" "$montant_g1"
    
    return 0
}

################################################################################
# Fonction principale pour virement sociétaire
################################################################################
process_societaire() {
    local email="$1"
    local type="$2"
    local montant_euros="${3:-$(calculate_societaire_amount "$type")}"
    local referrer="${4:-}"   # Email du parrain (optionnel) : reçoit le 1% à la place du Capitaine
    
    # Valider que le montant est un nombre valide
    if [[ -z "$montant_euros" ]] || ! [[ "$montant_euros" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo -e "${RED}❌ Montant invalide: '$montant_euros'${NC}"
        echo -e "${YELLOW}💡 Utilisez un nombre positif (ex: 50 pour satellite, 540 pour constellation)${NC}"
        return 1
    fi
    
    # Cas spécial : apport capital infrastructure (pas de 3x1/3)
    if [[ "$type" == "infrastructure" ]]; then
        process_infrastructure "$email" "$montant_euros"
        return $?
    fi
    
    local montant_g1=$(zen_to_g1 "$montant_euros")
    
    echo -e "${BLUE}👑 Traitement virement SOCIÉTAIRE pour: ${email}${NC}"
    echo -e "${CYAN}💰 Type: ${type} - Montant: ${montant_euros} Ẑen = ${montant_g1} Ğ1${NC}"
    
    # Vérifier que les portefeuilles existent
    if [[ ! -f "$HOME/.zen/tmp/UPLANETNAME_G1" ]]; then
        echo -e "${RED}❌ Portefeuille UPLANETNAME_G1 non configuré${NC}"
        echo "💡 Utilisez zen.sh → UPLANETNAME_G1 pour configurer"
        return 1
    fi
    
    if [[ ! -f "$HOME/.zen/tmp/UPLANETNAME_SOCIETY" ]]; then
        echo -e "${RED}❌ Portefeuille UPLANETNAME_SOCIETY non configuré${NC}"
        echo "💡 Utilisez zen.sh → UPLANETNAME_SOCIETY pour configurer"
        return 1
    fi
    
    # Récupérer les clés publiques
    local g1_pubkey=$(cat "$HOME/.zen/tmp/UPLANETNAME_G1")
    local society_pubkey=$(cat "$HOME/.zen/tmp/UPLANETNAME_SOCIETY")
    
    # Récupérer la clé ZEN Card du sociétaire depuis son dossier player
    local zencard_pubkey=""
    local zencard_dunikey="$HOME/.zen/game/players/${email}/secret.dunikey"
    local zencard_g1pub="$HOME/.zen/game/players/${email}/.g1pub"
    
    if [[ -f "$zencard_dunikey" ]]; then
        zencard_pubkey=$(cat "$zencard_dunikey" | grep "pub:" | cut -d ' ' -f 2)
        echo -e "${GREEN}✅ ZEN Card trouvée: ${zencard_pubkey:0:8}...${NC}"
    elif [[ -f "$zencard_g1pub" ]]; then
        zencard_pubkey=$(cat "$zencard_g1pub")
        echo -e "${GREEN}✅ ZEN Card trouvée (g1pub): ${zencard_pubkey:0:8}...${NC}"
    else
        echo -e "${RED}❌ ZEN Card non trouvée pour ${email}${NC}"
        echo -e "${CYAN}💡 Vérifiez que le dossier ~/.zen/game/players/${email}/ existe${NC}"
        return 1
    fi
    
    # Récupérer le MULTIPASS (G1PUBNOSTR) du sociétaire pour le crédit usage 33%
    # Conforme ZEN.ECONOMY.v2.md : ZEN Card → 33% MULTIPASS contributeur (crédit usage)
    local multipass_pubkey=""
    local multipass_dunikey="$HOME/.zen/game/nostr/${email}/.secret.dunikey"
    if [[ -f "$HOME/.zen/game/nostr/${email}/G1PUBNOSTR" ]]; then
        multipass_pubkey=$(cat "$HOME/.zen/game/nostr/${email}/G1PUBNOSTR" 2>/dev/null)
        echo -e "${GREEN}✅ MULTIPASS trouvé: ${multipass_pubkey:0:8}...${NC}"
    else
        echo -e "${YELLOW}⚠️  MULTIPASS non trouvé pour ${email} (compte NOSTR absent — crédit usage 33% ignoré)${NC}"
    fi

    echo -e "${YELLOW}🔑 Portefeuilles identifiés:${NC}"
    echo -e "  UPLANETNAME_G1      : ${g1_pubkey:0:8}..."
    echo -e "  UPLANETNAME_SOCIETY : ${society_pubkey:0:8}..."
    echo -e "  ZEN Card ${email}   : ${zencard_pubkey:0:8}..."
    [[ -n "$multipass_pubkey" ]] && echo -e "  MULTIPASS ${email}  : ${multipass_pubkey:0:8}..."

    # Primo TX différée : initialiser ZEN Card et MULTIPASS si nécessaire
    if ! ensure_wallet_initialized "$zencard_pubkey" "ZENCARD" "$email"; then
        echo -e "${RED}❌ Impossible d'initialiser la ZEN Card — Duniter v2 indisponible ?${NC}"
        return 1
    fi
    if [[ -n "$multipass_pubkey" ]]; then
        ensure_wallet_initialized "$multipass_pubkey" "MULTIPASS" "$email" || true  # non-bloquant
    fi

    # Vérifier qu'il n'y a pas de transactions en cours avant de commencer
    echo -e "${BLUE}🔍 Vérification préalable des transactions en cours...${NC}"
    if ! check_no_pending_transactions "$g1_pubkey"; then
        echo -e "${RED}❌ Impossible de commencer le virement: des transactions sont en cours${NC}"
        echo -e "${YELLOW}💡 Attendez que les transactions en cours se terminent avant de relancer${NC}"
        return 1
    fi
    
    # Étape 1: UPLANETNAME_G1 -> UPLANETNAME_SOCIETY
    echo -e "${BLUE}📤 Étape 1: Transfert UPLANETNAME_G1 → UPLANETNAME_SOCIETY${NC}"
    if ! transfer_and_verify "$HOME/.zen/game/uplanet.G1.dunikey" "$society_pubkey" "$montant_euros" "UPLANET:${UPLANETG1PUB:0:8}:SOCIETY:${email}:${type}:${IPFSNODEID}" "$email" "SOCIETAIRE_${type^^}" "Étape 1: G1→SOCIETY"; then
        echo -e "${RED}❌ Échec de l'étape 1${NC}"
        return 1
    fi
    
    # Étape 2: UPLANETNAME_SOCIETY -> ZEN Card
    echo -e "${BLUE}📤 Étape 2: Transfert UPLANETNAME_SOCIETY → ZEN Card ${email}${NC}"
    if ! transfer_and_verify "$HOME/.zen/game/uplanet.SOCIETY.dunikey" "$zencard_pubkey" "$montant_euros" "UPLANET:${UPLANETG1PUB:0:8}:SOCIETY:${email}:${type}:${IPFSNODEID}" "$email" "SOCIETAIRE_${type^^}" "Étape 2: SOCIETY→ZENCARD"; then
        echo -e "${RED}❌ Échec de l'étape 2${NC}"
        return 1
    fi
    
    # Étape 3: Répartition 33/33/33/1 depuis ZEN Card
    echo -e "${BLUE}📤 Étape 3: Répartition 33%+33%+33%+1% depuis ZEN Card${NC}"

    # Calculer les montants de répartition (en Ẑen pour l'affichage, en Ğ1 pour les transferts)
    # 33% MULTIPASS sociétaire (crédit usage) + 33% RnD + 33% ASSETS + 1% Captain MULTIPASS = 100%
    local montant_zen=$montant_euros
    local part_assets_zen=$(echo "scale=2; $montant_zen * 33 / 100" | bc)
    local part_multipass_zen=$(echo "scale=2; $montant_zen * 33 / 100" | bc)
    local part_rnd_zen=$(echo "scale=2; $montant_zen * 33 / 100" | bc)
    local part_captain_zen=$(echo "scale=2; $montant_zen - $part_multipass_zen - $part_rnd_zen - $part_assets_zen" | bc)

    # Note: 1/3 revient au MULTIPASS du sociétaire (crédit usage, déjà récupéré ci-dessus)
    echo -e "${GREEN}✅ MULTIPASS sociétaire (1/3 crédit usage): ${multipass_pubkey:0:8}...${NC}"

    # Portefeuilles coopératifs R&D et ASSETS
    local rnd_pubkey=""
    local assets_pubkey=""

    # R&D
    if [[ -f "$HOME/.zen/game/uplanet.RnD.dunikey" ]]; then
        rnd_pubkey=$(cat "$HOME/.zen/game/uplanet.RnD.dunikey" | grep "pub:" | cut -d ' ' -f 2)
        echo -e "${GREEN}✅ R&D trouvé: ${rnd_pubkey:0:8}...${NC}"
    else
        echo -e "${RED}❌ Portefeuille R&D non trouvé: ~/.zen/game/uplanet.RnD.dunikey${NC}"
        echo -e "${CYAN}💡 Exécutez ZEN.COOPERATIVE.3x1-3.sh pour créer les portefeuilles coopératifs${NC}"
        return 1
    fi
    
    # Assets
    if [[ -f "$HOME/.zen/game/uplanet.ASSETS.dunikey" ]]; then
        assets_pubkey=$(cat "$HOME/.zen/game/uplanet.ASSETS.dunikey" | grep "pub:" | cut -d ' ' -f 2)
        echo -e "${GREEN}✅ Assets trouvé: ${assets_pubkey:0:8}...${NC}"
    else
        echo -e "${RED}❌ Portefeuille Assets non trouvé: ~/.zen/game/uplanet.ASSETS.dunikey${NC}"
        echo -e "${CYAN}💡 Exécutez ZEN.COOPERATIVE.3x1-3.sh pour créer les portefeuilles coopératifs${NC}"
        return 1
    fi
    
    # Transfert (1/3) → MULTIPASS du sociétaire (crédit usage retourné)
    # Conforme ZEN.ECONOMY.v2.md : "33% MULTIPASS contributeur (crédit usage)"
    if [[ -n "$multipass_pubkey" && -f "$multipass_dunikey" ]]; then
        echo -e "${CYAN}  📤 MULTIPASS sociétaire (1/3 crédit usage): ${part_multipass_zen} Ẑen → ${multipass_pubkey:0:8}...${NC}"
        if ! transfer_and_verify "$zencard_dunikey" "$multipass_pubkey" "$part_multipass_zen" "UPLANET:${UPLANETG1PUB:0:8}:ZENCOIN:${email}" "$email" "SOCIETAIRE_${type^^}" "Étape 3a: ZENCARD→MULTIPASS"; then
            echo -e "${RED}❌ Échec transfert MULTIPASS sociétaire${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}  ⚠️  Étape 3a IGNORÉE — MULTIPASS introuvable pour ${email} (crédit usage non émis)${NC}"
        # Redistribuer le 33% vers ASSETS en cas d'absence de MULTIPASS
        part_assets_zen=$(echo "scale=2; $part_assets_zen + $part_multipass_zen" | bc)
        echo -e "${CYAN}  ↩️  Transfert 33% redirigé vers ASSETS: ${part_assets_zen} Ẑen total${NC}"
    fi

    # Mettre à jour DID pour crédit MULTIPASS
    "${MY_PATH}/tools/did_manager_nostr.sh" update "$email" "MULTIPASS_CREDIT" "$part_multipass_zen" "$(zen_to_g1 "$part_multipass_zen")"
    
    # Transfert vers R&D (1/3)
    echo -e "${CYAN}  📤 R&D (1/3): ${part_rnd_zen} Ẑen${NC}"
    if ! transfer_and_verify "$zencard_dunikey" "$rnd_pubkey" "$part_rnd_zen" "UPLANET:${UPLANETG1PUB:0:8}:RnD:${email}:${type}:${IPFSNODEID}" "$email" "SOCIETAIRE_${type^^}" "Étape 3b: ZENCARD→RND"; then
        echo -e "${RED}❌ Échec transfert R&D${NC}"
        return 1
    fi
    
    # Mettre à jour DID pour contribution R&D
    "${MY_PATH}/tools/did_manager_nostr.sh" update "$email" "RND_CONTRIBUTION" "$part_rnd_zen" "$(zen_to_g1 "$part_rnd_zen")"
    
    # Transfert vers Assets (1/3)
    echo -e "${CYAN}  📤 Assets (1/3): ${part_assets_zen} Ẑen${NC}"
    if ! transfer_and_verify "$zencard_dunikey" "$assets_pubkey" "$part_assets_zen" "UPLANET:${UPLANETG1PUB:0:8}:ASSETS:${email}:${type}:${IPFSNODEID}" "$email" "SOCIETAIRE_${type^^}" "Étape 3c: ZENCARD→ASSETS"; then
        echo -e "${RED}❌ Échec transfert Assets${NC}"
        return 1
    fi
    
    # Mettre à jour DID pour contribution Assets
    "${MY_PATH}/tools/did_manager_nostr.sh" update "$email" "ASSETS_CONTRIBUTION" "$part_assets_zen" "$(zen_to_g1 "$part_assets_zen")"

    # Transfert 1% prime → Parrain (si défini et MULTIPASS trouvé) ou Capitaine
    # Cherche le parrain dans LOCAL, CACHE et SWARM via search_for_this_email_in_nostr.sh
    local bonus_target_pubkey="$CAPTAING1PUB"
    local bonus_target_label="Capitaine"
    local bonus_tx_type="CPT1pct"

    if [[ -n "$referrer" ]]; then
        echo -e "${CYAN}  🔍 Recherche du parrain: ${referrer}...${NC}"
        local referrer_search_result
        referrer_search_result=$("${MY_PATH}/tools/search_for_this_email_in_nostr.sh" "${referrer}" 2>/dev/null)
        if [[ -n "$referrer_search_result" ]]; then
            # Évaluation sécurisée : extrait uniquement G1PUBNOSTR depuis l'export
            local referrer_multipass
            referrer_multipass=$(echo "$referrer_search_result" | grep -oP 'G1PUBNOSTR=\K\S+')
            local referrer_source
            referrer_source=$(echo "$referrer_search_result" | grep -oP 'source=\K\S+')
            if [[ -n "$referrer_multipass" ]]; then
                bonus_target_pubkey="$referrer_multipass"
                bonus_target_label="Parrain ${referrer}"
                bonus_tx_type="REF1pct"
                echo -e "${GREEN}  🤝 Parrain trouvé (${referrer_source}): ${referrer} (${referrer_multipass:0:8}...)${NC}"
            else
                echo -e "${YELLOW}  ⚠️  G1PUBNOSTR introuvable pour '${referrer}' — prime reversée au Capitaine${NC}"
            fi
        else
            echo -e "${YELLOW}  ⚠️  Parrain '${referrer}' non trouvé (LOCAL/CACHE/SWARM) — prime reversée au Capitaine${NC}"
        fi
    fi

    if [[ -n "$bonus_target_pubkey" ]]; then
        echo -e "${CYAN}  📤 Prime 1% → ${bonus_target_label}: ${part_captain_zen} Ẑen${NC}"
        if transfer_and_verify "$zencard_dunikey" "$bonus_target_pubkey" "$part_captain_zen" "UPLANET:${UPLANETG1PUB:0:8}:${bonus_tx_type}:${email}:${type}:${IPFSNODEID}" "$email" "SOCIETAIRE_${type^^}" "Étape 3d: ZENCARD→${bonus_tx_type}"; then
            echo -e "${GREEN}  ✅ Prime 1%: ${part_captain_zen} Ẑen → ${bonus_target_label}${NC}"
        else
            echo -e "${YELLOW}  ⚠️  Prime 1% failed (non-critical)${NC}"
        fi
    fi

    echo -e "${GREEN}🎉 Virement sociétaire terminé avec succès!${NC}"
    echo -e "${CYAN}📊 Résumé:${NC}"
    echo -e "  • ${montant_euros} Ẑen transférés vers ZEN Card ${email}"
    echo -e "  • Droits d'usage attribués (type: ${type})"
    echo -e "  • Répartition 33/33/33/1 effectuée:"
    echo -e "    - MULTIPASS (crédit usage): ${part_multipass_zen} Ẑen"
    echo -e "    - R&D: ${part_rnd_zen} Ẑen"
    echo -e "    - Assets: ${part_assets_zen} Ẑen"
    echo -e "    - ${bonus_target_label} (1%): ${part_captain_zen} Ẑen"
    echo -e "  • Toutes les transactions confirmées sur la blockchain"
    
    # Mettre à jour le document DID avec le statut de sociétaire
    local contract_type="SOCIETAIRE_${type^^}"
    "${MY_PATH}/tools/did_manager_nostr.sh" update "$email" "$contract_type" "$montant_euros" "$montant_g1"
    
    # Validate France Connect compliance for ZEN Card holders (KYC verified)
    # Check if user has WoT verification (0.01Ğ1 transaction from Duniter forgeron)
    local wot_verified=false
    if [[ -f "$HOME/.zen/tmp/coucou/${zencard_pubkey}.2nd" ]]; then
        wot_verified=true
        echo -e "${GREEN}✅ WoT verification detected (KYC completed)${NC}"
    fi
    
    # Only validate France Connect for French users with KYC verification
    if [[ "$wot_verified" == "true" ]]; then
        local user_lang=$(cat "$HOME/.zen/game/nostr/${email}/LANG" 2>/dev/null || echo "fr")
        if [[ "$user_lang" == "fr" ]]; then
            echo -e "${CYAN}🇫🇷 Validating France Connect compliance for KYC-verified French user...${NC}"
            "${MY_PATH}/tools/did_manager_nostr.sh" validate-france-connect "$email"
        fi
    else
        echo -e "${YELLOW}⚠️  France Connect validation skipped - KYC verification required (WoT transaction)${NC}"
    fi
    
    return 0
}

################################################################################
# Fonction de dépannage pour récupération manuelle depuis SOCIETY
# Flux correct: SOCIETY → ZEN Card → 3x1/3 (TREASURY, RnD, ASSETS)
################################################################################
process_recovery() {
    echo -e "${YELLOW}🔧 MODE DÉPANNAGE - Récupération manuelle depuis SOCIETY${NC}"
    echo -e "${CYAN}📋 Flux: SOCIETY → ZEN Card → 3x1/3 (TREASURY, RnD, ASSETS)${NC}"
    echo ""
    
    # Vérifier que le portefeuille SOCIETY existe
    if [[ ! -f "$HOME/.zen/game/uplanet.SOCIETY.dunikey" ]]; then
        echo -e "${RED}❌ Portefeuille UPLANETNAME_SOCIETY non trouvé${NC}"
        echo -e "${CYAN}💡 Fichier attendu: ~/.zen/game/uplanet.SOCIETY.dunikey${NC}"
        return 1
    fi
    
    # Récupérer la clé publique SOCIETY
    local society_pubkey=$(cat "$HOME/.zen/game/uplanet.SOCIETY.dunikey" | grep "pub:" | cut -d ' ' -f 2)
    if [[ -z "$society_pubkey" ]]; then
        echo -e "${RED}❌ Impossible de lire la clé publique SOCIETY${NC}"
        return 1
    fi
    
    echo -e "${CYAN}🔑 Wallet SOCIETY: ${society_pubkey:0:8}...${NC}"
    echo ""
    
    # Afficher le solde du wallet SOCIETY via G1balance.sh
    echo -e "${YELLOW}📊 Récupération du solde SOCIETY...${NC}"
    local balance_json=$("${MY_PATH}/tools/G1balance.sh" "$society_pubkey" 2>/dev/null)
    
    if [[ -z "$balance_json" ]] || ! echo "$balance_json" | jq -e '.balances' >/dev/null 2>&1; then
        echo -e "${RED}❌ Impossible de récupérer le solde du wallet SOCIETY${NC}"
        return 1
    fi
    
    # Extraire les montants (en centimes, convertir en Ğ1)
    local blockchain_centimes=$(echo "$balance_json" | jq -r '.balances.blockchain // 0' 2>/dev/null)
    local pending_centimes=$(echo "$balance_json" | jq -r '.balances.pending // 0' 2>/dev/null)
    local total_centimes=$(echo "$balance_json" | jq -r '.balances.total // 0' 2>/dev/null)
    
    # Valider les valeurs
    [[ -z "$blockchain_centimes" || "$blockchain_centimes" == "null" ]] && blockchain_centimes="0"
    [[ -z "$pending_centimes" || "$pending_centimes" == "null" ]] && pending_centimes="0"
    [[ -z "$total_centimes" || "$total_centimes" == "null" ]] && total_centimes="0"
    
    local blockchain_g1=$(echo "scale=2; $blockchain_centimes / 100" | bc -l)
    local pending_g1=$(echo "scale=2; $pending_centimes / 100" | bc -l)
    local total_g1=$(echo "scale=2; $total_centimes / 100" | bc -l)
    
    # Convertir en Ẑen (1 Ğ1 = 10 Ẑen)
    local blockchain_zen=$(echo "scale=2; $blockchain_g1 * 10" | bc -l)
    local pending_zen=$(echo "scale=2; $pending_g1 * 10" | bc -l)
    local total_zen=$(echo "scale=2; $total_g1 * 10" | bc -l)
    
    echo -e "${GREEN}✅ Solde du wallet SOCIETY:${NC}"
    echo -e "  • Blockchain: ${blockchain_g1} Ğ1 (${blockchain_zen} Ẑen)"
    echo -e "  • Pending: ${pending_g1} Ğ1 (${pending_zen} Ẑen)"
    echo -e "  • Total: ${total_g1} Ğ1 (${total_zen} Ẑen)"
    echo ""
    
    # Vérifier qu'il y a des fonds disponibles
    if [[ $(echo "$blockchain_g1 <= 0" | bc -l) -eq 1 ]]; then
        echo -e "${YELLOW}⚠️  Aucun fonds disponible dans le wallet SOCIETY${NC}"
        return 0
    fi
    
    # Demander l'email du sociétaire
    read -p "Email du sociétaire: " email_ref
    if [[ -z "$email_ref" ]]; then
        echo -e "${RED}❌ Email requis${NC}"
        return 1
    fi
    
    # Récupérer la ZEN Card du sociétaire
    local zencard_pubkey=""
    local zencard_dunikey="$HOME/.zen/game/players/${email_ref}/secret.dunikey"
    local zencard_g1pub="$HOME/.zen/game/players/${email_ref}/.g1pub"
    
    if [[ -f "$zencard_dunikey" ]]; then
        zencard_pubkey=$(cat "$zencard_dunikey" | grep "pub:" | cut -d ' ' -f 2)
        echo -e "${GREEN}✅ ZEN Card trouvée: ${zencard_pubkey:0:8}...${NC}"
    elif [[ -f "$zencard_g1pub" ]]; then
        zencard_pubkey=$(cat "$zencard_g1pub")
        echo -e "${GREEN}✅ ZEN Card trouvée (g1pub): ${zencard_pubkey:0:8}...${NC}"
    else
        echo -e "${RED}❌ ZEN Card non trouvée pour ${email_ref}${NC}"
        echo -e "${CYAN}💡 Vérifiez que le dossier ~/.zen/game/players/${email_ref}/ existe${NC}"
        return 1
    fi
    
    # Récupérer le MULTIPASS du sociétaire (crédit usage, 1/3)
    local multipass_pubkey_ref=$(cat "$HOME/.zen/game/nostr/${email_ref}/G1PUBNOSTR" 2>/dev/null)
    if [[ -z "$multipass_pubkey_ref" ]]; then
        echo -e "${RED}❌ MULTIPASS non trouvé pour ${email_ref}${NC}"
        echo -e "${CYAN}💡 Créez un MULTIPASS avec make_NOSTRCARD.sh${NC}"
        return 1
    fi
    echo -e "${GREEN}✅ MULTIPASS trouvé: ${multipass_pubkey_ref:0:8}...${NC}"

    # Vérifier les portefeuilles coopératifs R&D et ASSETS
    local rnd_pubkey=""
    local assets_pubkey=""

    if [[ -f "$HOME/.zen/game/uplanet.RnD.dunikey" ]]; then
        rnd_pubkey=$(cat "$HOME/.zen/game/uplanet.RnD.dunikey" | grep "pub:" | cut -d ' ' -f 2)
        echo -e "${GREEN}✅ R&D trouvé: ${rnd_pubkey:0:8}...${NC}"
    else
        echo -e "${RED}❌ Wallet R&D non trouvé: ~/.zen/game/uplanet.RnD.dunikey${NC}"
        return 1
    fi
    
    if [[ -f "$HOME/.zen/game/uplanet.ASSETS.dunikey" ]]; then
        assets_pubkey=$(cat "$HOME/.zen/game/uplanet.ASSETS.dunikey" | grep "pub:" | cut -d ' ' -f 2)
        echo -e "${GREEN}✅ Assets trouvé: ${assets_pubkey:0:8}...${NC}"
    else
        echo -e "${RED}❌ Wallet ASSETS non trouvé: ~/.zen/game/uplanet.ASSETS.dunikey${NC}"
        return 1
    fi
    
    echo ""
    
    # Demander le montant à transférer
    echo -e "${YELLOW}💰 Montant disponible dans SOCIETY: ${blockchain_g1} Ğ1 (${blockchain_zen} Ẑen)${NC}"
    read -p "Montant à transférer en Ẑen (ou 'max' pour tout transférer): " amount_input
    
    local zen_amount=""
    if [[ "$amount_input" == "max" ]]; then
        zen_amount="$blockchain_zen"
        echo -e "${CYAN}💸 Transfert de tout le solde disponible: ${zen_amount} Ẑen${NC}"
    else
        # Valider que c'est un nombre
        if [[ ! "$amount_input" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            echo -e "${RED}❌ Montant invalide (nombre ou 'max' requis)${NC}"
            return 1
        fi
        zen_amount="$amount_input"
        
        # Vérifier que le montant ne dépasse pas le solde
        if [[ $(echo "$zen_amount > $blockchain_zen" | bc -l) -eq 1 ]]; then
            echo -e "${RED}❌ Montant demandé (${zen_amount} Ẑen) supérieur au solde (${blockchain_zen} Ẑen)${NC}"
            return 1
        fi
    fi
    
    local g1_amount=$(zen_to_g1 "$zen_amount")
    
    # Demander le type pour la référence
    read -p "Type de sociétaire (satellite/constellation): " type_ref
    type_ref="${type_ref:-satellite}"
    
    # Calculer les montants 33/33/33/1
    local part_captain_zen=$(echo "scale=2; $zen_amount * 1 / 100" | bc)
    local part_multipass_zen=$(echo "scale=2; $zen_amount * 33 / 100" | bc)
    local part_rnd_zen=$(echo "scale=2; $zen_amount * 33 / 100" | bc)
    local part_assets_zen=$(echo "scale=2; $zen_amount - $part_multipass_zen - $part_rnd_zen - $part_captain_zen" | bc)

    echo ""
    echo -e "${YELLOW}📋 Récapitulatif de l'opération:${NC}"
    echo -e "  • Étape 1: SOCIETY → ZEN Card ${email_ref}: ${zen_amount} Ẑen (${g1_amount} Ğ1)"
    echo -e "  • Étape 2: ZEN Card → 33/33/33/1:"
    echo -e "    - MULTIPASS (crédit usage): ${part_multipass_zen} Ẑen"
    echo -e "    - R&D: ${part_rnd_zen} Ẑen"
    echo -e "    - Assets: ${part_assets_zen} Ẑen"
    echo -e "    - Captain (1%): ${part_captain_zen} Ẑen"
    echo ""
    read -p "Confirmer le transfert? (oui/non): " confirm
    
    if [[ "$confirm" != "oui" ]]; then
        echo -e "${YELLOW}🚫 Transfert annulé${NC}"
        return 0
    fi
    
    # ÉTAPE 1: SOCIETY → ZEN Card
    echo ""
    echo -e "${BLUE}📤 Étape 1: Transfert SOCIETY → ZEN Card ${email_ref}${NC}"
    local reference_society="UPLANET:${UPLANETG1PUB:0:8}:SOCIETY:${email_ref}:${type_ref}:${IPFSNODEID}"
    
    if ! transfer_and_verify "$HOME/.zen/game/uplanet.SOCIETY.dunikey" "$zencard_pubkey" "$zen_amount" "$reference_society" "$email_ref" "RECOVERY_SOCIETY" "Recovery: SOCIETY→ZENCARD"; then
        echo -e "${RED}❌ Échec de l'étape 1 (SOCIETY → ZEN Card)${NC}"
        return 1
    fi
    
    # ÉTAPE 2: ZEN Card → 3x1/3
    echo -e "${BLUE}📤 Étape 2: Répartition 3x1/3 depuis ZEN Card${NC}"
    
    # Transfert (1/3) → MULTIPASS du sociétaire (crédit usage retourné)
    echo -e "${CYAN}  📤 MULTIPASS sociétaire (1/3 crédit usage): ${part_multipass_zen} Ẑen${NC}"
    if ! transfer_and_verify "$zencard_dunikey" "$multipass_pubkey_ref" "$part_multipass_zen" "UPLANET:${UPLANETG1PUB:0:8}:ZENCOIN:${email_ref}" "$email_ref" "RECOVERY_MULTIPASS" "Recovery: ZENCARD→MULTIPASS"; then
        echo -e "${RED}❌ Échec transfert MULTIPASS sociétaire${NC}"
        return 1
    fi

    # Mettre à jour DID pour crédit MULTIPASS
    "${MY_PATH}/tools/did_manager_nostr.sh" update "$email_ref" "MULTIPASS_CREDIT" "$part_multipass_zen" "$(zen_to_g1 "$part_multipass_zen")"
    
    # Transfert vers R&D (1/3)
    echo -e "${CYAN}  📤 R&D (1/3): ${part_rnd_zen} Ẑen${NC}"
    if ! transfer_and_verify "$zencard_dunikey" "$rnd_pubkey" "$part_rnd_zen" "UPLANET:${UPLANETG1PUB:0:8}:RnD:${email_ref}:${type_ref}:${IPFSNODEID}" "$email_ref" "RECOVERY_RND" "Recovery: ZENCARD→RND"; then
        echo -e "${RED}❌ Échec transfert R&D${NC}"
        return 1
    fi
    
    # Mettre à jour DID pour contribution R&D
    "${MY_PATH}/tools/did_manager_nostr.sh" update "$email_ref" "RND_CONTRIBUTION" "$part_rnd_zen" "$(zen_to_g1 "$part_rnd_zen")"
    
    # Transfert vers Assets (1/3)
    echo -e "${CYAN}  📤 Assets (1/3): ${part_assets_zen} Ẑen${NC}"
    if ! transfer_and_verify "$zencard_dunikey" "$assets_pubkey" "$part_assets_zen" "UPLANET:${UPLANETG1PUB:0:8}:ASSETS:${email_ref}:${type_ref}:${IPFSNODEID}" "$email_ref" "RECOVERY_ASSETS" "Recovery: ZENCARD→ASSETS"; then
        echo -e "${RED}❌ Échec transfert Assets${NC}"
        return 1
    fi
    
    # Mettre à jour DID pour contribution Assets
    "${MY_PATH}/tools/did_manager_nostr.sh" update "$email_ref" "ASSETS_CONTRIBUTION" "$part_assets_zen" "$(zen_to_g1 "$part_assets_zen")"
    
    # Transfert vers Captain MULTIPASS (1% prime de gestion)
    if [[ -n "$CAPTAING1PUB" ]]; then
        echo -e "${CYAN}  📤 Captain bonus (1%): ${part_captain_zen} Ẑen${NC}"
        if transfer_and_verify "$zencard_dunikey" "$CAPTAING1PUB" "$part_captain_zen" "UPLANET:${UPLANETG1PUB:0:8}:CPT1pct:${email_ref}:${type_ref}:${IPFSNODEID}" "$email_ref" "RECOVERY_CPT" "Recovery: ZENCARD→CAPTAIN"; then
            echo -e "${GREEN}  ✅ Captain bonus: ${part_captain_zen} Ẑen → MULTIPASS${NC}"
        else
            echo -e "${YELLOW}  ⚠️  Captain bonus failed (non-critical)${NC}"
        fi
    fi

    echo ""
    echo -e "${GREEN}🎉 Transfert de récupération terminé avec succès!${NC}"
    echo -e "${CYAN}📊 Résumé:${NC}"
    echo -e "  • ${zen_amount} Ẑen (${g1_amount} Ğ1) transférés de SOCIETY vers ZEN Card ${email_ref}"
    echo -e "  • Répartition 33/33/33/1 effectuée:"
    echo -e "    - MULTIPASS (crédit usage): ${part_multipass_zen} Ẑen"
    echo -e "    - R&D: ${part_rnd_zen} Ẑen"
    echo -e "    - Assets: ${part_assets_zen} Ẑen"
    echo -e "    - Captain (1%): ${part_captain_zen} Ẑen"
    echo -e "  • Toutes les transactions confirmées sur la blockchain"
    echo ""
    
    # Afficher le nouveau solde SOCIETY via G1balance.sh
    echo -e "${YELLOW}📊 Nouveau solde du wallet SOCIETY...${NC}"
    sleep 2
    local new_balance_json=$("${MY_PATH}/tools/G1balance.sh" "$society_pubkey" 2>/dev/null)
    if [[ -n "$new_balance_json" ]] && echo "$new_balance_json" | jq -e '.balances' >/dev/null 2>&1; then
        local new_blockchain_centimes=$(echo "$new_balance_json" | jq -r '.balances.blockchain // 0' 2>/dev/null)
        [[ -z "$new_blockchain_centimes" || "$new_blockchain_centimes" == "null" ]] && new_blockchain_centimes="0"
        local new_blockchain_g1=$(echo "scale=2; $new_blockchain_centimes / 100" | bc -l)
        local new_blockchain_zen=$(echo "scale=2; $new_blockchain_g1 * 10" | bc -l)
        echo -e "${GREEN}✅ Nouveau solde SOCIETY: ${new_blockchain_g1} Ğ1 (${new_blockchain_zen} Ẑen)${NC}"
    fi
    
    # Mettre à jour le document DID avec le statut de sociétaire
    local contract_type="SOCIETAIRE_${type_ref^^}"
    "${MY_PATH}/tools/did_manager_nostr.sh" update "$email_ref" "$contract_type" "$zen_amount" "$g1_amount"
    
    return 0
}

################################################################################
# Fonction de dépannage pour refaire un transfert ZEN Card → 3x1/3
# Cas d'usage: la deuxième étape a échoué partiellement
################################################################################
process_recovery_3x13() {
    echo -e "${YELLOW}🔧 MODE DÉPANNAGE - Transfert ZEN Card → 3x1/3${NC}"
    echo -e "${CYAN}📋 Permet de refaire un transfert depuis la ZEN Card d'un player vers TREASURY/RnD/ASSETS${NC}"
    echo ""
    
    # Demander l'email du player
    read -p "Email du sociétaire: " email_ref
    if [[ -z "$email_ref" ]]; then
        echo -e "${RED}❌ Email requis${NC}"
        return 1
    fi
    
    # Récupérer la ZEN Card du player
    local zencard_pubkey=""
    local zencard_dunikey="$HOME/.zen/game/players/${email_ref}/secret.dunikey"
    local zencard_g1pub="$HOME/.zen/game/players/${email_ref}/.g1pub"
    
    if [[ -f "$zencard_dunikey" ]]; then
        zencard_pubkey=$(cat "$zencard_dunikey" | grep "pub:" | cut -d ' ' -f 2)
        echo -e "${GREEN}✅ ZEN Card trouvée: ${zencard_pubkey:0:8}...${NC}"
    elif [[ -f "$zencard_g1pub" ]]; then
        zencard_pubkey=$(cat "$zencard_g1pub")
        echo -e "${YELLOW}⚠️  ZEN Card trouvée (g1pub uniquement): ${zencard_pubkey:0:8}...${NC}"
        echo -e "${YELLOW}⚠️  Le fichier secret.dunikey est nécessaire pour effectuer le transfert${NC}"
        return 1
    else
        echo -e "${RED}❌ ZEN Card non trouvée pour ${email_ref}${NC}"
        echo -e "${CYAN}💡 Vérifiez que le dossier ~/.zen/game/players/${email_ref}/ existe${NC}"
        return 1
    fi
    
    # Afficher le solde de la ZEN Card via G1balance.sh
    echo ""
    echo -e "${YELLOW}📊 Récupération du solde de la ZEN Card...${NC}"
    local balance_json=$("${MY_PATH}/tools/G1balance.sh" "$zencard_pubkey" 2>/dev/null)
    
    if [[ -z "$balance_json" ]] || ! echo "$balance_json" | jq -e '.balances' >/dev/null 2>&1; then
        echo -e "${RED}❌ Impossible de récupérer le solde de la ZEN Card${NC}"
        return 1
    fi
    
    # Extraire les montants (en centimes, convertir en Ğ1)
    local blockchain_centimes=$(echo "$balance_json" | jq -r '.balances.blockchain // 0' 2>/dev/null)
    local pending_centimes=$(echo "$balance_json" | jq -r '.balances.pending // 0' 2>/dev/null)
    local total_centimes=$(echo "$balance_json" | jq -r '.balances.total // 0' 2>/dev/null)
    
    # Valider les valeurs
    [[ -z "$blockchain_centimes" || "$blockchain_centimes" == "null" ]] && blockchain_centimes="0"
    [[ -z "$pending_centimes" || "$pending_centimes" == "null" ]] && pending_centimes="0"
    [[ -z "$total_centimes" || "$total_centimes" == "null" ]] && total_centimes="0"
    
    local blockchain_g1=$(echo "scale=2; $blockchain_centimes / 100" | bc -l)
    local pending_g1=$(echo "scale=2; $pending_centimes / 100" | bc -l)
    local total_g1=$(echo "scale=2; $total_centimes / 100" | bc -l)
    
    # Convertir en Ẑen (1 Ğ1 = 10 Ẑen)
    local blockchain_zen=$(echo "scale=2; $blockchain_g1 * 10" | bc -l)
    local pending_zen=$(echo "scale=2; $pending_g1 * 10" | bc -l)
    local total_zen=$(echo "scale=2; $total_g1 * 10" | bc -l)
    
    echo -e "${GREEN}✅ Solde de la ZEN Card ${email_ref}:${NC}"
    echo -e "  • Blockchain: ${blockchain_g1} Ğ1 (${blockchain_zen} Ẑen)"
    echo -e "  • Pending: ${pending_g1} Ğ1 (${pending_zen} Ẑen)"
    echo -e "  • Total: ${total_g1} Ğ1 (${total_zen} Ẑen)"
    echo ""
    
    # Vérifier qu'il y a des fonds disponibles
    if [[ $(echo "$blockchain_g1 <= 1.0" | bc -l) -eq 1 ]]; then
        echo -e "${YELLOW}⚠️  Solde insuffisant dans la ZEN Card (≤ 1Ğ1)${NC}"
        echo -e "${CYAN}💡 Il faut au moins > 1Ğ1 pour effectuer un transfert${NC}"
        return 0
    fi
    
    # Menu de sélection du wallet 3x1/3 destination
    echo -e "${BLUE}📋 Sélectionnez le portefeuille de destination:${NC}"
    echo "1. TREASURY (CASH)"
    echo "2. R&D"
    echo "3. ASSETS"
    echo "4. Annuler"
    echo ""
    read -p "Votre choix (1-4): " wallet_choice
    
    local dest_wallet=""
    local dest_name=""
    local dest_type=""
    local did_contribution_type=""
    
    case $wallet_choice in
        1)
            if [[ -f "$HOME/.zen/game/uplanet.CASH.dunikey" ]]; then
                dest_wallet=$(cat "$HOME/.zen/game/uplanet.CASH.dunikey" | grep "pub:" | cut -d ' ' -f 2)
                dest_name="TREASURY"
                dest_type="TREASURY"
                did_contribution_type="TREASURY_CONTRIBUTION"
                echo -e "${GREEN}✅ Treasury: ${dest_wallet:0:8}...${NC}"
            else
                echo -e "${RED}❌ Wallet TREASURY non trouvé: ~/.zen/game/uplanet.CASH.dunikey${NC}"
                return 1
            fi
            ;;
        2)
            if [[ -f "$HOME/.zen/game/uplanet.RnD.dunikey" ]]; then
                dest_wallet=$(cat "$HOME/.zen/game/uplanet.RnD.dunikey" | grep "pub:" | cut -d ' ' -f 2)
                dest_name="R&D"
                dest_type="RnD"
                did_contribution_type="RND_CONTRIBUTION"
                echo -e "${GREEN}✅ R&D: ${dest_wallet:0:8}...${NC}"
            else
                echo -e "${RED}❌ Wallet R&D non trouvé: ~/.zen/game/uplanet.RnD.dunikey${NC}"
                return 1
            fi
            ;;
        3)
            if [[ -f "$HOME/.zen/game/uplanet.ASSETS.dunikey" ]]; then
                dest_wallet=$(cat "$HOME/.zen/game/uplanet.ASSETS.dunikey" | grep "pub:" | cut -d ' ' -f 2)
                dest_name="ASSETS"
                dest_type="ASSETS"
                did_contribution_type="ASSETS_CONTRIBUTION"
                echo -e "${GREEN}✅ Assets: ${dest_wallet:0:8}...${NC}"
            else
                echo -e "${RED}❌ Wallet ASSETS non trouvé: ~/.zen/game/uplanet.ASSETS.dunikey${NC}"
                return 1
            fi
            ;;
        4)
            echo -e "${YELLOW}🚫 Opération annulée${NC}"
            return 0
            ;;
        *)
            echo -e "${RED}❌ Choix invalide${NC}"
            return 1
            ;;
    esac
    
    echo ""
    
    # Demander le montant à transférer
    echo -e "${YELLOW}💰 Montant disponible dans la ZEN Card: ${blockchain_g1} Ğ1 (${blockchain_zen} Ẑen)${NC}"
    read -p "Montant à transférer en Ẑen: " amount_input
    
    # Valider que c'est un nombre
    if [[ ! "$amount_input" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo -e "${RED}❌ Montant invalide (nombre requis)${NC}"
        return 1
    fi
    
    local zen_amount="$amount_input"
    
    # Vérifier que le montant ne dépasse pas le solde disponible
    if [[ $(echo "$zen_amount > $blockchain_zen" | bc -l) -eq 1 ]]; then
        echo -e "${RED}❌ Montant demandé (${zen_amount} Ẑen) supérieur au solde (${blockchain_zen} Ẑen)${NC}"
        return 1
    fi
    
    local g1_amount=$(zen_to_g1 "$zen_amount")
    
    # Demander le type pour la référence
    read -p "Type de sociétaire (satellite/constellation): " type_ref
    type_ref="${type_ref:-satellite}"
    
    echo ""
    echo -e "${YELLOW}📋 Récapitulatif de l'opération:${NC}"
    echo -e "  • Source: ZEN Card ${email_ref} (${zencard_pubkey:0:8}...)"
    echo -e "  • Destination: ${dest_name} (${dest_wallet:0:8}...)"
    echo -e "  • Montant: ${zen_amount} Ẑen (${g1_amount} Ğ1)"
    echo ""
    read -p "Confirmer le transfert? (oui/non): " confirm
    
    if [[ "$confirm" != "oui" ]]; then
        echo -e "${YELLOW}🚫 Transfert annulé${NC}"
        return 0
    fi
    
    # Effectuer le transfert
    echo ""
    echo -e "${BLUE}🚀 Lancement du transfert ZEN Card → ${dest_name}...${NC}"
    
    local reference="UPLANET:${UPLANETG1PUB:0:8}:${dest_type}:${email_ref}:${type_ref}:${IPFSNODEID}"
    
    if transfer_and_verify "$zencard_dunikey" "$dest_wallet" "$zen_amount" "$reference" "$email_ref" "RECOVERY_3x13_${dest_type}" "Recovery 3x1/3: ZENCARD→${dest_name}"; then
        echo ""
        echo -e "${GREEN}🎉 Transfert de récupération 3x1/3 terminé avec succès!${NC}"
        echo -e "${CYAN}📊 Résumé:${NC}"
        echo -e "  • ${zen_amount} Ẑen (${g1_amount} Ğ1) transférés de ZEN Card vers ${dest_name}"
        echo -e "  • Transaction confirmée sur la blockchain"
        echo ""
        
        # Mettre à jour DID pour contribution
        "${MY_PATH}/tools/did_manager_nostr.sh" update "$email_ref" "$did_contribution_type" "$zen_amount" "$g1_amount"
        
        # Afficher le nouveau solde de la ZEN Card via G1balance.sh
        echo -e "${YELLOW}📊 Nouveau solde de la ZEN Card...${NC}"
        sleep 2
        local new_balance_json=$("${MY_PATH}/tools/G1balance.sh" "$zencard_pubkey" 2>/dev/null)
        if [[ -n "$new_balance_json" ]] && echo "$new_balance_json" | jq -e '.balances' >/dev/null 2>&1; then
            local new_blockchain_centimes=$(echo "$new_balance_json" | jq -r '.balances.blockchain // 0' 2>/dev/null)
            [[ -z "$new_blockchain_centimes" || "$new_blockchain_centimes" == "null" ]] && new_blockchain_centimes="0"
            local new_blockchain_g1=$(echo "scale=2; $new_blockchain_centimes / 100" | bc -l)
            local new_blockchain_zen=$(echo "scale=2; $new_blockchain_g1 * 10" | bc -l)
            echo -e "${GREEN}✅ Nouveau solde ZEN Card: ${new_blockchain_g1} Ğ1 (${new_blockchain_zen} Ẑen)${NC}"
        fi
        
        return 0
    else
        echo -e "${RED}❌ Échec du transfert de récupération 3x1/3${NC}"
        return 1
    fi
}

################################################################################
# Sélection email joueur (local + swarm)
# ── Fonction utilitaire : affichage + saisie de sélection ────────────────
# Usage interne : _select_from_list "role" emails[] g1v2s[] sources[]
_select_from_list() {
    local role="$1"; shift
    local -a emails=("${!1}"); shift
    local -a g1v2s=("${!1}"); shift
    local -a sources=("${!1}"); shift

    if [[ ${#emails[@]} -eq 0 ]]; then
        read -p "Email du ${role} : " _selected_email >&2
        echo "$_selected_email"
        return
    fi
    echo -e "${CYAN}📋 ${role} disponibles :${NC}" >&2
    local i=1
    for idx in "${!emails[@]}"; do
        printf "  %2d. %-38s  %-52s  %s\n" \
            "$i" "${emails[$idx]}" "${g1v2s[$idx]:-?}" "${sources[$idx]}" >&2
        ((i++))
    done
    echo -e "   0. ✏️  Saisir un email manuellement" >&2
    echo "" >&2
    local sel
    read -p "Choisissez (0-${#emails[@]}) ou tapez un email : " sel >&2
    if [[ "$sel" =~ ^[1-9][0-9]*$ ]] && (( sel >= 1 && sel <= ${#emails[@]} )); then
        echo "${emails[$((sel-1))]}"
    elif [[ "$sel" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
        echo "$sel"
    else
        read -p "Email du ${role} : " _sel2 >&2; echo "$_sel2"
    fi
}

################################################################################
# select_multipass — liste les MULTIPASS locaux + swarm
# Sources : ~/.zen/game/nostr/*/G1PUBNOSTR  (local 🏠)
#           ~/.zen/tmp/swarm/*/TW/*/G1PUBNOSTR  (swarm 🌐)
# Affiche la clé SS58 v2 de chaque MULTIPASS
# Usage : email=$(select_multipass "Locataire")
################################################################################
select_multipass() {
    local role="${1:-locataire MULTIPASS}"
    local _g1v2py="${MY_PATH}/tools/g1pub_to_ss58.py"
    local -a emails=() g1v2s=() sources=()

    # ── Locaux ~/.zen/game/nostr/*/G1PUBNOSTR ────────────────────────────────
    if [[ -d "$HOME/.zen/game/nostr" ]]; then
        while IFS= read -r dir; do
            local em g1pub ss58
            em=$(basename "$dir")
            if [[ "$em" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
                g1pub=$(cat "$dir/G1PUBNOSTR" 2>/dev/null)
                ss58=""; [[ -n "$g1pub" && -f "$_g1v2py" ]] && \
                    ss58=$(python3 "$_g1v2py" "$g1pub" 2>/dev/null)
                emails+=("$em"); g1v2s+=("${ss58:-?}"); sources+=("🏠 local")
            fi
        done < <(find "$HOME/.zen/game/nostr" -mindepth 1 -maxdepth 1 -type d | sort)
    fi

    # ── Swarm ~/.zen/tmp/swarm/*/TW/*/G1PUBNOSTR ─────────────────────────────
    if [[ -d "$HOME/.zen/tmp/swarm" ]]; then
        while IFS= read -r g1file; do
            local em node_dir g1pub ss58 already
            em=$(basename "$(dirname "$g1file")")
            node_dir=$(basename "$(dirname "$(dirname "$g1file")")")
            if [[ "$em" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
                already=false
                for existing in "${emails[@]}"; do
                    [[ "$existing" == "$em" ]] && already=true && break
                done
                if [[ "$already" == "false" ]]; then
                    g1pub=$(cat "$g1file" 2>/dev/null)
                    ss58=""; [[ -n "$g1pub" && -f "$_g1v2py" ]] && \
                        ss58=$(python3 "$_g1v2py" "$g1pub" 2>/dev/null)
                    emails+=("$em"); g1v2s+=("${ss58:-?}"); sources+=("🌐 ${node_dir: -8}")
                fi
            fi
        done < <(find "$HOME/.zen/tmp/swarm" -mindepth 4 -maxdepth 4 \
                      -name "G1PUBNOSTR" -path "*/TW/*" 2>/dev/null | sort)
    fi

    _select_from_list "$role" emails[@] g1v2s[@] sources[@]
}

################################################################################
# select_zencard — liste les ZEN Card locales uniquement
# Source : ~/.zen/game/players/*/.g1pub  (local 🏠)
# Affiche la clé SS58 v2 de chaque ZEN Card
# Usage : email=$(select_zencard "Sociétaire")
################################################################################
select_zencard() {
    local role="${1:-sociétaire ZEN Card}"
    local _g1v2py="${MY_PATH}/tools/g1pub_to_ss58.py"
    local -a emails=() g1v2s=() sources=()

    # ── Locaux ~/.zen/game/players/*/.g1pub ──────────────────────────────────
    if [[ -d "$HOME/.zen/game/players" ]]; then
        while IFS= read -r dir; do
            local em g1pub ss58
            em=$(basename "$dir")
            if [[ "$em" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
                g1pub=$(cat "$dir/.g1pub" 2>/dev/null)
                ss58=""; [[ -n "$g1pub" && -f "$_g1v2py" ]] && \
                    ss58=$(python3 "$_g1v2py" "$g1pub" 2>/dev/null)
                emails+=("$em"); g1v2s+=("${ss58:-?}"); sources+=("🏠 local ZENCard")
            fi
        done < <(find "$HOME/.zen/game/players" -mindepth 1 -maxdepth 1 -type d | sort)
    fi

    _select_from_list "$role" emails[@] g1v2s[@] sources[@]
}

################################################################################
# Contrôle des portefeuilles relais (doivent transiter à 0 Ẑen)
# Les wallets UPLANETG1PUB (ẑen usage) et UPLANETNAME_SOCIETY (ẑen AMAP) sont
# des portefeuilles de transit : ils reçoivent et reversent aussitôt.
# Tout solde résiduel > 1 Ğ1 indique une transaction bloquée à corriger.
################################################################################
check_relay_wallets_interactive() {
    # Seuil = 100 centimes = 1 Ğ1 = réserve nécessaire pour pouvoir envoyer des TX
    # L'excédent = solde - 1 Ğ1 (= le montant réellement bloqué en transit)
    local _reserve_centimes=100   # 1 Ğ1 = réserve d'envoi obligatoire
    local _excess_found=false
    local _drain_uplanet_zen="" _drain_society_zen=""

    echo -e "${YELLOW}🔍 Contrôle des portefeuilles relais coopératifs...${NC}"
    echo -e "${CYAN}   La valeur économique = SOMME DES TX (G1revenue / G1society), pas le solde.${NC}"
    echo -e "${CYAN}   Réserve normale : 1 Ğ1 = 10 Ẑen (nécessaire pour envoyer des TX).${NC}"
    echo -e "${CYAN}   Excédent (> 1Ğ1) = transit bloqué → drainage proposé.${NC}"
    echo ""

    # ── UPLANETG1PUB : relais ẑen USAGE (MULTIPASS) ─────────────────────────
    local _bal_u _excess_u_centimes _excess_u_zen
    _bal_u=$(timeout 8 "${MY_PATH}/tools/G1balance.sh" "${UPLANETG1PUB}" 2>/dev/null \
             | jq -r '.balances.blockchain // 0' 2>/dev/null)
    _excess_u_centimes=$(echo "${_bal_u:-0} - ${_reserve_centimes}" | bc 2>/dev/null)
    _excess_u_zen=$(echo "scale=1; (${_excess_u_centimes:-0} / 100) * 10" | bc -l 2>/dev/null)
    if [[ $(echo "${_excess_u_centimes:-0} > 0" | bc -l 2>/dev/null) -eq 1 ]]; then
        echo -e "${RED}⚠️  ẑen USAGE (UPLANETG1PUB)       : ${_excess_u_zen} Ẑen en excès (+ 1Ğ1 réserve) — TRANSIT BLOQUÉ${NC}"
        _excess_found=true; _drain_uplanet_zen="$_excess_u_zen"
    else
        echo -e "${GREEN}✅ ẑen USAGE (UPLANETG1PUB)       : 1Ğ1 réserve OK — aucun excédent (transit vide)${NC}"
    fi

    # ── UPLANETNAME_SOCIETY : relais ẑen AMAP (parts sociales) ──────────────
    local _bal_s _excess_s_centimes _excess_s_zen
    _bal_s=$(timeout 8 "${MY_PATH}/tools/G1balance.sh" "${UPLANETNAME_SOCIETY}" 2>/dev/null \
             | jq -r '.balances.blockchain // 0' 2>/dev/null)
    _excess_s_centimes=$(echo "${_bal_s:-0} - ${_reserve_centimes}" | bc 2>/dev/null)
    _excess_s_zen=$(echo "scale=1; (${_excess_s_centimes:-0} / 100) * 10" | bc -l 2>/dev/null)
    if [[ $(echo "${_excess_s_centimes:-0} > 0" | bc -l 2>/dev/null) -eq 1 ]]; then
        echo -e "${RED}⚠️  ẑen AMAP  (UPLANETNAME_SOCIETY): ${_excess_s_zen} Ẑen en excès (+ 1Ğ1 réserve) — TRANSIT BLOQUÉ${NC}"
        _excess_found=true; _drain_society_zen="$_excess_s_zen"
    else
        echo -e "${GREEN}✅ ẑen AMAP  (UPLANETNAME_SOCIETY): 1Ğ1 réserve OK — aucun excédent (transit vide)${NC}"
    fi

    [[ "$_excess_found" == "false" ]] && echo "" && return 0

    # ── Proposition de drainage ──────────────────────────────────────────────
    echo ""
    echo -e "${YELLOW}💡 Des fonds sont bloqués dans les portefeuilles relais.${NC}"
    echo -e "${CYAN}Que souhaitez-vous faire ?${NC}"
    [[ -n "$_drain_uplanet_zen" ]] && \
        echo -e "  ${GREEN}1.${NC} Drainer ẑen USAGE (${_drain_uplanet_zen} Ẑen) → MULTIPASS d'un locataire"
    [[ -n "$_drain_society_zen" ]] && \
        echo -e "  ${GREEN}2.${NC} Drainer ẑen AMAP  (${_drain_society_zen} Ẑen) → 33/33/33/1% d'un sociétaire"
    echo -e "  ${GREEN}3.${NC} Ignorer et continuer"
    echo ""
    read -p "Choisissez (1/2/3) : " _drain_choice

    case "$_drain_choice" in
        1)
            if [[ -n "$_drain_uplanet_zen" ]]; then
                local _em
                _em=$(select_multipass "locataire MULTIPASS (usage)")
                if [[ -n "$_em" ]]; then
                    echo -e "${CYAN}💳 Drainage ẑen USAGE → MULTIPASS ${_em}: ${_drain_uplanet_zen} Ẑen${NC}"
                    process_locataire "$_em" "$_drain_uplanet_zen"
                fi
            else
                echo -e "${YELLOW}⚠️  Pas d'excédent ẑen USAGE détecté.${NC}"
            fi
            ;;
        2)
            if [[ -n "$_drain_society_zen" ]]; then
                local _em _tp
                _em=$(select_zencard "sociétaire AMAP (parts sociales)")
                if [[ -n "$_em" ]]; then
                    read -p "Type de sociétaire (satellite|constellation) [satellite] : " _tp
                    _tp="${_tp:-satellite}"
                    echo -e "${CYAN}🏛️  Drainage ẑen AMAP → 3×1/3+1% pour ${_em}: ${_drain_society_zen} Ẑen${NC}"
                    process_societaire "$_em" "$_tp" "$_drain_society_zen"
                fi
            else
                echo -e "${YELLOW}⚠️  Pas d'excédent ẑen AMAP détecté.${NC}"
            fi
            ;;
        *)
            echo -e "${YELLOW}⏩ Contrôle ignoré — les fonds restent en attente.${NC}"
            ;;
    esac
    echo ""
}

################################################################################
# Menu interactif
################################################################################
show_menu() {
    echo -e "${BLUE}🏛️  UPLANET.official.sh - Menu de gestion des virements officiels${NC}"
    echo ""
    echo "1. Virement MULTIPASS (recharge MULTIPASS)"
    echo "2. Virement SOCIÉTAIRE Satellite (50€/an)"
    echo "3. Virement SOCIÉTAIRE Constellation (540€/3ans)"
    echo "4. Apport CAPITAL INFRASTRUCTURE (CAPTAIN → NODE)"
    echo "5. Quitter"
    echo ""
    read -p "Choisissez une option (1-5): " choice
    
    case $choice in
        1)
            email=$(select_multipass "locataire (MULTIPASS)")
            if [[ -n "$email" ]]; then
                read -p "Montant en Ẑen (défaut: ${NCARD:-50}): " montant
                montant="${montant:-${NCARD:-50}}"
                
                # Valider que le montant est un nombre
                if [[ "$montant" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                    process_locataire "$email" "$montant"
                else
                    echo -e "${RED}❌ Montant invalide (nombre requis)${NC}"
                fi
            else
                echo -e "${RED}❌ Email requis${NC}"
            fi
            ;;
        2)
            email=$(select_zencard "sociétaire Satellite")
            if [[ -n "$email" ]]; then
                read -p "Montant en Ẑen (défaut: ${ZENCARD_SATELLITE:-50}): " montant
                montant="${montant:-${ZENCARD_SATELLITE:-50}}"
                
                # Valider que le montant est un nombre
                if [[ "$montant" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                    process_societaire "$email" "satellite" "$montant"
                else
                    echo -e "${RED}❌ Montant invalide (nombre requis)${NC}"
                fi
            else
                echo -e "${RED}❌ Email requis${NC}"
            fi
            ;;
        3)
            email=$(select_zencard "sociétaire Constellation")
            if [[ -n "$email" ]]; then
                read -p "Montant en Ẑen (défaut: ${ZENCARD_CONSTELLATION:-540}): " montant
                montant="${montant:-${ZENCARD_CONSTELLATION:-540}}"
                
                # Valider que le montant est un nombre
                if [[ "$montant" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                    process_societaire "$email" "constellation" "$montant"
                else
                    echo -e "${RED}❌ Montant invalide (nombre requis)${NC}"
                fi
            else
                echo -e "${RED}❌ Email requis${NC}"
            fi
            ;;
        4)
            if [[ -n "$CAPTAINEMAIL" ]]; then
                # Check if capital already exists
                local env_file="$HOME/.zen/game/.env"
                local existing_value=""
                if [[ -f "$env_file" ]]; then
                    existing_value=$(grep "^MACHINE_VALUE=" "$env_file" | cut -d'=' -f2)
                fi
                
                local infra_mode_menu=""
                if [[ -n "$existing_value" && "$existing_value" != "0" ]]; then
                    echo -e "${YELLOW}⚠️  Capital déjà enregistré: ${existing_value} Ẑen${NC}"
                    echo "1. Annuler"
                    echo "2. Écraser (--force) - Réinitialise l'amortissement"
                    echo "3. Ajouter (--add) - Cumule avec l'ancien"
                    read -p "Votre choix (1-3): " mode_choice
                    case $mode_choice in
                        2) infra_mode_menu="--force" ;;
                        3) infra_mode_menu="--add" ;;
                        *) echo -e "${YELLOW}🚫 Opération annulée${NC}"; return ;;
                    esac
                fi
                
                local machine_value="${MACHINE_VALUE_ZEN}"
                if [[ -z "$machine_value" ]]; then
                    read -p "Valeur de la machine en Ẑen (défaut: 500): " machine_value
                    machine_value="${machine_value:-500}"
                fi
                echo -e "${CYAN}💰 Apport capital pour: ${CAPTAINEMAIL} (${machine_value} Ẑen)${NC}"
                process_infrastructure "$CAPTAINEMAIL" "$machine_value" "$infra_mode_menu"
            else
                echo -e "${RED}❌ CAPTAINEMAIL non défini dans l'environnement${NC}"
                echo -e "${CYAN}💡 Configurez votre email de capitaine dans my.sh${NC}"
            fi
            ;;
        5)
            echo -e "${GREEN}👋 Au revoir!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Option invalide${NC}"
            ;;
    esac
}

################################################################################
# Point d'entrée principal
################################################################################
main() {
    # Vérifier que jq est disponible
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}❌ Erreur: jq n'est pas installé ou n'est pas dans le PATH${NC}"
        exit 1
    fi
    
    # Vérifier que bc est disponible
    if ! command -v bc &> /dev/null; then
        echo -e "${RED}❌ Erreur: bc n'est pas installé ou n'est pas dans le PATH${NC}"
        exit 1
    fi
    
    # Traitement des arguments en ligne de commande
    if [[ $# -gt 0 ]]; then
        # Parse arguments
        local email=""
        local type="satellite"
        local montant=""
        local mode=""
        local lat=""
        local lon=""
        local permit_id=""
        local infra_mode=""  # --force or --add for infrastructure
        local referrer=""    # Code parrain (email) : reçoit le 1% prime à la place du Capitaine
        
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -l|--locataire)
                    mode="locataire"
                    shift
                    if [[ -n "$1" && ! "$1" =~ ^- ]]; then
                        email="$1"
                        shift
                    fi
                    ;;
                -s|--societaire)
                    mode="societaire"
                    shift
                    if [[ -n "$1" && ! "$1" =~ ^- ]]; then
                        email="$1"
                        shift
                    fi
                    ;;
                -i|--infrastructure)
                    mode="infrastructure"
                    shift
                    ;;
                -c|--captain)
                    mode="captain"
                    shift
                    if [[ -n "$1" && ! "$1" =~ ^- ]]; then
                        email="$1"
                        shift
                    fi
                    ;;
                --force)
                    infra_mode="--force"
                    shift
                    ;;
                --add)
                    infra_mode="--add"
                    shift
                    ;;
                -o|--ore)
                    mode="ore"
                    shift
                    if [[ -n "$1" && ! "$1" =~ ^- ]]; then
                        lat="$1"
                        shift
                    fi
                    if [[ -n "$1" && ! "$1" =~ ^- ]]; then
                        lon="$1"
                        shift
                    fi
                    ;;
                -p|--permit)
                    mode="permit"
                    shift
                    if [[ -n "$1" && ! "$1" =~ ^- ]]; then
                        email="$1"
                        shift
                    fi
                    if [[ -n "$1" && ! "$1" =~ ^- ]]; then
                        permit_id="$1"
                        shift
                    fi
                    ;;
                -r|--recovery)
                    mode="recovery"
                    shift
                    ;;
                --recovery-3x13)
                    mode="recovery_3x13"
                    shift
                    ;;
                -t|--type)
                    shift
                    if [[ -n "$1" && ! "$1" =~ ^- ]]; then
                        type="$1"
                        shift
                    fi
                    ;;
                -m|--montant)
                    shift
                    if [[ -n "$1" && ! "$1" =~ ^- ]]; then
                        montant="$1"
                        shift
                    fi
                    ;;
                -f|--referrer)
                    shift
                    if [[ -n "$1" && ! "$1" =~ ^- ]]; then
                        referrer="$1"
                        shift
                    fi
                    ;;
                -h|--help)
                    show_help
                    exit 0
                    ;;
                *)
                    echo -e "${RED}❌ Option inconnue: $1${NC}"
                    show_help
                    exit 1
                    ;;
            esac
        done
        
        # Execute based on mode
        case "$mode" in
            "locataire")
                if [[ -n "$email" ]]; then
                    process_locataire "$email" "$montant"
                else
                    echo -e "${RED}❌ Email requis pour l'option --locataire${NC}"
                    exit 1
                fi
                ;;
            "societaire")
                if [[ -n "$email" ]]; then
                    [[ -n "$referrer" ]] && echo -e "${CYAN}🤝 Parrainage: ${referrer}${NC}"
                    process_societaire "$email" "$type" "$montant" "$referrer"
                else
                    echo -e "${RED}❌ Email requis pour l'option --societaire${NC}"
                    exit 1
                fi
                ;;
            "infrastructure")
                if [[ -n "$CAPTAINEMAIL" ]]; then
                    local machine_value="${montant:-${MACHINE_VALUE_ZEN:-500}}"
                    echo -e "${CYAN}💰 Apport capital infrastructure: ${CAPTAINEMAIL} (${machine_value} Ẑen)${NC}"
                    [[ -n "$infra_mode" ]] && echo -e "${YELLOW}📋 Mode: ${infra_mode}${NC}"
                    process_infrastructure "$CAPTAINEMAIL" "$machine_value" "$infra_mode"
                else
                    echo -e "${RED}❌ CAPTAINEMAIL non défini dans l'environnement${NC}"
                    echo -e "${CYAN}💡 Configurez votre email de capitaine dans my.sh${NC}"
                    exit 1
                fi
                ;;
            "captain")
                local captain_email="${email:-$CAPTAINEMAIL}"
                if [[ -n "$captain_email" ]]; then
                    echo -e "${CYAN}🚢 Inscription Capitaine Astroport: ${captain_email}${NC}"
                    # Vérifier que le compte existe
                    if [[ ! -d "$HOME/.zen/game/nostr/${captain_email}" ]]; then
                        echo -e "${RED}❌ Compte non trouvé: ${captain_email}${NC}"
                        echo -e "${CYAN}💡 Créez d'abord le compte avec make_NOSTRCARD.sh${NC}"
                        exit 1
                    fi
                    # Mettre à jour le DID avec le statut CAPTAIN
                    echo -e "${YELLOW}📝 Mise à jour du DID avec statut CAPTAIN...${NC}"
                    "${MY_PATH}/tools/did_manager_nostr.sh" update "$captain_email" "CAPTAIN" 0 0
                    if [[ $? -eq 0 ]]; then
                        echo -e "${GREEN}✅ Capitaine inscrit avec succès !${NC}"
                        echo -e "  • Email: ${captain_email}"
                        echo -e "  • Statut: astroport_captain"
                        echo -e "  • Quota: unlimited"
                        echo -e "  • Services: Full access (uDRIVE + NextCloud + AI + #BRO + video)"
                    else
                        echo -e "${RED}❌ Échec de l'inscription capitaine${NC}"
                        exit 1
                    fi
                else
                    echo -e "${RED}❌ Email requis pour l'option --captain${NC}"
                    echo -e "${CYAN}💡 Usage: $0 -c support@qo-op.com${NC}"
                    exit 1
                fi
                ;;
            "recovery")
                process_recovery
                ;;
            "recovery_3x13")
                process_recovery_3x13
                ;;
            "ore")
                if [[ -n "$lat" && -n "$lon" ]]; then
                    local ore_montant="${montant:-10}"
                    echo -e "${CYAN}🌱 Virement ORE pour UMAP depuis ASSETS: (${lat}, ${lon}) - ${ore_montant} Ẑen${NC}"
                    process_ore "$lat" "$lon" "$ore_montant"
                else
                    echo -e "${RED}❌ Latitude et longitude requises pour l'option --ore${NC}"
                    echo -e "${CYAN}💡 Usage: $0 -o 43.60 1.44 -m 10${NC}"
                    exit 1
                fi
                ;;
            "permit")
                if [[ -n "$email" && -n "$permit_id" ]]; then
                    local permit_montant="${montant:-100}"
                    echo -e "${CYAN}🎫 Virement PERMIT pour: ${email} (${permit_id}) - ${permit_montant} Ẑen${NC}"
                    virement_permit "$email" "$permit_id" "" "$permit_montant"
                else
                    echo -e "${RED}❌ Email et Permit ID requis pour l'option --permit${NC}"
                    echo -e "${CYAN}💡 Usage: $0 -p dragon@example.com PERMIT_WOT_DRAGON -m 100${NC}"
                    exit 1
                fi
                ;;
            *)
                echo -e "${RED}❌ Mode non spécifié${NC}"
                show_help
                exit 1
                ;;
        esac
    else
        # Mode interactif — contrôle préalable des portefeuilles relais
        check_relay_wallets_interactive
        show_menu
    fi
}

# Exécuter le script principal
main "$@"
