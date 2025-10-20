#!/bin/bash
################################################################################
# Script pour récupérer seulement les données DID
################################################################################

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/my.sh"

# Nostr configuration
NOSTR_RELAYS="${NOSTR_RELAYS:-ws://127.0.0.1:7777 wss://relay.copylaradio.com}"
NOSTR_DID_CLIENT_SCRIPT="${MY_PATH}/nostr_did_client.py"
DID_EVENT_KIND=30311
DID_TAG_IDENTIFIER="did"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Récupération des données DID uniquement...${NC}" >&2

# Scanner les répertoires utilisateurs
emails=$(find ~/.zen/game/nostr -name ".secret.nostr" -exec dirname {} \; | xargs -I {} basename {} | sort -u)

if [[ -z "$emails" ]]; then
    echo -e "${YELLOW}⚠️  Aucun utilisateur Nostr trouvé${NC}" >&2
    echo "[]"
    exit 0
fi

nostr_data="[]"
nostr_count=0

# Vérifier si le script nostr_did_client.py existe
if [[ ! -f "$NOSTR_DID_CLIENT_SCRIPT" ]]; then
    echo -e "${YELLOW}⚠️  Script nostr_did_client.py non trouvé${NC}" >&2
    echo "[]"
    exit 0
fi

while IFS= read -r email; do
    if [[ -z "$email" || "$email" == "N/A" ]]; then
        continue
    fi
    
    echo -e "${CYAN}📧 Récupération DID Nostr pour: ${email}${NC}" >&2
    
    # Récupérer les clés Nostr de l'utilisateur
    nostr_keys_file="$HOME/.zen/game/nostr/${email}/.secret.nostr"
    if [[ ! -f "$nostr_keys_file" ]]; then
        echo -e "${YELLOW}⚠️  Clés Nostr non trouvées pour ${email}${NC}" >&2
        continue
    fi
    
    # Extraire la clé publique Nostr
    npub=""
    if source "$nostr_keys_file" 2>/dev/null && [[ -n "$NPUB" ]]; then
        npub="$NPUB"
    else
        echo -e "${YELLOW}⚠️  Impossible d'extraire NPUB pour ${email}${NC}" >&2
        continue
    fi
    
    # Récupérer le DID depuis Nostr
    did_content=""
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
    did_info=$(echo "$did_content" | jq -r --arg email "$email" '
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
