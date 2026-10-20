#!/bin/bash
# -----------------------------------------------------------------------------
# nostr_RESTORE_TW.sh
#
# This script restores a NOSTR account backup from IPFS.
# It supports both NEW format (.next.disco for migration to new relay/captain)
# and OLD format (.secret.disco for backward compatibility).
#
# For NEW relay/captain migration:
#   - Uses .next.disco (pre-generated during account deactivation)
#   - Creates MULTIPASS with new credentials on the new relay
#   - Imports all NOSTR events and restores uDRIVE
#
# For OLD format (backward compatibility):
#   - Uses .secret.disco (may not work on new relay)
#   - Attempts restoration with original credentials
#
# Usage: ./nostr_RESTORE_TW.sh <IPFS_CID | LIEN_PASSERELLE> [target_relay_url] [--email EMAIL] [--gateway URL]
#   --email   : compte à recréer si la sauvegarde ne le porte pas (anciennes archives)
#   --gateway : passerelle HTTP de l'ANCIENNE station (https://ipfs.ancien.domaine). CHANGEMENT DE CONSTELLATION
#               (autre UPLANETNAME = autre swarm IPFS privé) : l'IPFS d'ici ne joint pas l'ancienne station, l'archive,
#               le uDRIVE et le cloud chiffré se rapatrient alors par SA passerelle (CAR : même CID, blocs vérifiés,
#               l'index ucloud reste valable). Un lien « https://hote/ipfs/<CID> » (celui de l'e-mail de désactivation)
#               tient lieu de CID + passerelle. Sans option, si l'archive porte .gateway et que l'UPlanet a changé, elle
#               est utilisée pour le uDRIVE et le cloud.
#
# The IPFS_CID can point to either:
#   - A 7z AES-256 archive (secret fort reçu par email du joueur) — current format
#   - A password-protected ZIP (requires the player's .pass) — previous format
#   - An asymmetrically encrypted backup (.enc) using natools.py — legacy format
#     from older backups (requires either the player's old .secret.dunikey or
#     Captain's uplanet key)
#
# Numbered secret.june files (secret.june.000.IPFSNODEID, etc.) preserve
# the cumulative cooperative capital shares history across migrations.
#
# uCloud (FaceCloud encrypted personal cloud) is restored from
# ucloud_index.json + ucloud_keyring.json when present in the backup — the
# encrypted photos/files themselves stay retrievable on IPFS by the CIDs
# already listed in the index, nothing is re-uploaded. dav_token is NOT
# restored (tied to the OLD hex, WebDAV password shown only once) — the
# player re-enrolls via FaceCloud (POST /api/cloud/enroll) for a new one.
#
# The Qdrant face-recognition catalog (qdrant_faces.json, if present) is
# re-upserted into a FRESH collection faces_<NEW_HEX> — the old collection
# faces_<OLD_HEX> is tied to the identity being replaced and is left
# orphaned on the previous relay/captain.
#
# The Qdrant LifeOS personal memory (qdrant_lifeos.json, if present) is
# re-upserted the same way into memory_<NEW_HEX16> (first 16 chars of the
# new HEX, cf. Astroport.ONE/IA/memory_manager.py::_user_hex). Collective
# collections (uplanet_geo, station_skills) are never touched — they don't
# belong to a single MULTIPASS.
# -----------------------------------------------------------------------------

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
ME="${0##*/}"

. "${MY_PATH}/my.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}   NOSTR Account Restore Tool${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  $ME <IPFS_CID> [target_relay_url]"
    echo ""
    echo -e "${YELLOW}Arguments:${NC}"
    echo -e "  ${GREEN}IPFS_CID${NC}           CID of the backup file on IPFS"
    echo -e "  ${GREEN}target_relay_url${NC}   (Optional) WebSocket URL of target relay"
    echo -e "                      Default: ws://127.0.0.1:7777"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  $ME QmXxx...123"
    echo -e "  $ME QmXxx...123 wss://relay.example.com"
    echo ""
    exit 1
}


# ── Lecture d'un DISCO ───────────────────────────────────────────────────────
# Format actuel (make_NOSTRCARD.sh) : /?salt=<S>&nostr=<P>  — SANS email.
# Ancien format : /?<email>=<S>&nostr=<P>. Pose D_EMAIL (vide si absent), D_SALT, D_PEPPER.
parse_disco() {
    local c="$1"
    D_EMAIL=""; D_SALT=""; D_PEPPER=""
    if [[ "$c" =~ ^/\?salt=([^\&]+)\&nostr=(.+)$ ]]; then
        D_SALT="${BASH_REMATCH[1]}"; D_PEPPER="${BASH_REMATCH[2]}"
    elif [[ "$c" =~ ^/\?([^=]+@[^=]+)=([^\&]+)\&nostr=(.+)$ ]]; then
        D_EMAIL="${BASH_REMATCH[1]}"; D_SALT="${BASH_REMATCH[2]}"; D_PEPPER="${BASH_REMATCH[3]}"
    else
        return 1
    fi
}

# Check arguments
if [[ -z "$1" ]]; then
    echo -e "${RED}❌ Error: IPFS CID required${NC}"
    usage
fi

IPFS_CID="$1"; shift
TARGET_RELAY="ws://127.0.0.1:7777"
FORCE_EMAIL=""
GATEWAY=""
# Lien de passerelle (« https://hote/ipfs/<CID> ») : passerelle + CID
if [[ "$IPFS_CID" =~ ^(https?://[^/]+)/ipfs/(Qm[1-9A-HJ-NP-Za-km-z]{44}|bafy[a-z2-7]{50,})(/.*)?$ ]]; then
    GATEWAY="${BASH_REMATCH[1]}"
    IPFS_CID="${BASH_REMATCH[2]}"
fi
while [[ $# -gt 0 ]]; do
    case "$1" in
        --email) FORCE_EMAIL="$2"; shift 2 ;;
        --gateway) GATEWAY="${2%/}"; shift 2 ;;
        ws://*|wss://*) TARGET_RELAY="$1"; shift ;;
        *) echo -e "${RED}❌ Argument inconnu: $1${NC}"; usage ;;
    esac
done
RESTORE_DIR="$HOME/.zen/tmp/nostr_restore_$$"
NO_VERIFY=true  # Use no-verify for faster import (trusted backup)

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}                 ${CYAN}NOSTR Account Restore${NC}                           ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📦 Backup CID:${NC}    ${IPFS_CID}"
echo -e "${CYAN}🎯 Target Relay:${NC}  ${TARGET_RELAY}"
echo -e "${CYAN}📂 Restore Dir:${NC}   ${RESTORE_DIR}"
echo ""

# Create restore directory
mkdir -p "${RESTORE_DIR}"

# Step 1: Download backup from IPFS
echo -e "${YELLOW}Step 1/4:${NC} ${CYAN}Downloading backup from IPFS...${NC}"
BACKUP_FILE="${RESTORE_DIR}/backup.data"

if [[ -n "$GATEWAY" ]]; then
    # Autre constellation : jamais l'IPFS d'ici, la PASSERELLE de l'ancienne station (le contenu est chiffré AES-256 :
    # il s'authentifie lui-même à l'extraction)
    python3 "$HOME/.zen/UPassport/gateway_fetch_cli.py" file "$GATEWAY" "$IPFS_CID" "${BACKUP_FILE}"
    _DL_OK=$?
else
    ipfs get "${IPFS_CID}" -o "${BACKUP_FILE}" 2>/dev/null
    _DL_OK=$?
fi
if [[ $_DL_OK -eq 0 ]]; then
    echo -e "${GREEN}✅ Backup downloaded successfully${NC}"
else
    echo -e "${RED}❌ Failed to download backup from IPFS${NC}"
    rm -rf "${RESTORE_DIR}"
    exit 1
fi

# Step 2: Extract backup (ZIP or Asymmetrically Encrypted)
echo -e "${YELLOW}Step 2/4:${NC} ${CYAN}Decrypting and Extracting backup archive...${NC}"
cd "${RESTORE_DIR}"

# Archive 7z AES-256 (format actuel), ZIP (ancien) ou binaire natools (très ancien)
FILE_KIND=$(file "${BACKUP_FILE}" 2>/dev/null)
if echo "${FILE_KIND}" | grep -q "7-zip archive"; then
    echo -e "${CYAN}   Archive is an AES-256 7z${NC}"
    command -v 7z >/dev/null 2>&1 || { echo -e "${RED}❌ 7z introuvable (apt install p7zip-full)${NC}"; rm -rf "${RESTORE_DIR}"; exit 1; }
    echo -e "${CYAN}Secret de l'archive (reçu par email lors de la désactivation) :${NC}"
    read -s -p "> " arch_secret
    echo ""
    if 7z x -y -p"${arch_secret}" -o"${RESTORE_DIR}" "${BACKUP_FILE}" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Backup extracted successfully${NC}"
    else
        echo -e "${RED}❌ Failed to extract backup (wrong secret or corrupted file)${NC}"
        rm -rf "${RESTORE_DIR}"
        exit 1
    fi
    unset arch_secret
elif echo "${FILE_KIND}" | grep -q "Zip archive"; then
    echo -e "${CYAN}   Archive is a password-protected ZIP (ancien format, PASS à 4 chiffres)${NC}"
    echo -e "${CYAN}Code PASS du joueur :${NC}"
    read -s -p "> " zip_pass
    echo ""
    if unzip -q -P "${zip_pass}" "${BACKUP_FILE}" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Backup extracted successfully${NC}"
    else
        echo -e "${RED}❌ Failed to extract backup (wrong password or corrupted file)${NC}"
        rm -rf "${RESTORE_DIR}"
        exit 1
    fi
    unset zip_pass
else
    echo -e "${YELLOW}⚠️  File is not a ZIP. Attempting asymmetric decryption (natools.py)...${NC}"
    DECRYPTED_ZIP="${RESTORE_DIR}/backup_decrypted.zip"
    DECRYPTED=false

    # 1. Try Player's Key first
    echo -e "${CYAN}Do you have the Player's old .secret.dunikey to decrypt this backup? (y/N)${NC}"
    read -p "> " has_key
    if [[ "$has_key" =~ ^[Yy] ]]; then
        read -p "Absolute path to Player's .secret.dunikey: " player_key
        if [[ -f "$player_key" ]]; then
            echo "Decrypting with Player's key..."
            if ${MY_PATH}/../tools/natools.py decrypt -f pubsec -i "${BACKUP_FILE}" -k "${player_key}" -o "${DECRYPTED_ZIP}" 2>/dev/null; then
                echo -e "${GREEN}✅ Decrypted successfully with Player's key${NC}"
                BACKUP_FILE="${DECRYPTED_ZIP}"
                DECRYPTED=true
            else
                echo -e "${RED}❌ Failed to decrypt with Player's key${NC}"
            fi
        else
            echo -e "${RED}❌ File not found: $player_key${NC}"
        fi
    fi

    # 2. Try Captain's Fallback key
    if [[ "$DECRYPTED" == "false" ]]; then
        echo -e "${YELLOW}⚠️  Trying UPlanet fallback key (Captain)...${NC}"
        # Ensure uplanet.dunikey exists
        if [[ ! -s ~/.zen/game/uplanet.dunikey ]]; then
            ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.dunikey "${UPLANETNAME}" "${UPLANETNAME}"
            chmod 600 ~/.zen/game/uplanet.dunikey
        fi
        
        if ${MY_PATH}/../tools/natools.py decrypt -f pubsec -i "${BACKUP_FILE}" -k ~/.zen/game/uplanet.dunikey -o "${DECRYPTED_ZIP}" 2>/dev/null; then
            echo -e "${GREEN}✅ Decrypted with uplanet key (Captain fallback)${NC}"
            BACKUP_FILE="${DECRYPTED_ZIP}"
            DECRYPTED=true
        else
            echo -e "${RED}❌ Failed to decrypt with uplanet key${NC}"
        fi
    fi

    # Check decryption state
    if [[ "$DECRYPTED" == "false" ]]; then
        echo -e "${RED}❌ Could not decrypt the backup. Restoration aborted.${NC}"
        rm -rf "${RESTORE_DIR}"
        exit 1
    fi

    # Now extract the decrypted ZIP (password-protected with the player's .pass)
    echo -e "${CYAN}   Extracting decrypted ZIP...${NC}"
    if unzip -q "${BACKUP_FILE}" 2>/dev/null; then
        echo -e "${GREEN}✅ Backup extracted successfully${NC}"
    else
        echo -e "${YELLOW}⚠️  Backup appears to be password-protected${NC}"
        echo -e "${CYAN}Please enter the ZEN Card / MULTIPASS password (from the player's .pass file):${NC}"
        read -s -p "> " zip_pass
        echo ""
        if unzip -q -P "${zip_pass}" "${BACKUP_FILE}" 2>/dev/null; then
            echo -e "${GREEN}✅ Backup extracted successfully${NC}"
        else
            echo -e "${RED}❌ Failed to extract decrypted backup (wrong password or file corrupted).${NC}"
            rm -rf "${RESTORE_DIR}"
            exit 1
        fi
    fi
fi

# Find nostr_export.json
EXPORT_FILE=$(find "${RESTORE_DIR}" -name "nostr_export.json" | head -1)
if [[ ! -f "${EXPORT_FILE}" ]]; then
    echo -e "${RED}❌ nostr_export.json not found in backup${NC}"
    rm -rf "${RESTORE_DIR}"
    exit 1
fi

# Check for uDRIVE manifest
MANIFEST_FILE=$(find "${RESTORE_DIR}" -name "uDRIVE_manifest.json" | head -1)
if [[ -f "${MANIFEST_FILE}" ]]; then
    echo -e "${GREEN}✅ uDRIVE manifest found${NC}"
    TOTAL_SIZE=$(jq -r '.formatted_total_size' "${MANIFEST_FILE}" 2>/dev/null || echo "unknown")
    TOTAL_FILES=$(jq -r '.total_files' "${MANIFEST_FILE}" 2>/dev/null || echo "unknown")
    echo -e "${CYAN}   📊 uDRIVE contains: ${GREEN}${TOTAL_FILES}${CYAN} files (${GREEN}${TOTAL_SIZE}${CYAN})${NC}"
else
    echo -e "${YELLOW}⚠️  No uDRIVE manifest found (no uDRIVE data to restore)${NC}"
fi

# Check for uCloud (FaceCloud encrypted personal cloud) index/keyring
UCLOUD_INDEX_FILE=$(find "${RESTORE_DIR}" -name "ucloud_index.json" | head -1)
UCLOUD_KEYRING_FILE=$(find "${RESTORE_DIR}" -name "ucloud_keyring.json" | head -1)
UCLOUD_ENTRIES=0
if [[ -f "${UCLOUD_INDEX_FILE}" ]]; then
    UCLOUD_ENTRIES=$(jq -r '.entries | length' "${UCLOUD_INDEX_FILE}" 2>/dev/null || echo "0")
    echo -e "${GREEN}✅ uCloud (FaceCloud) index found${NC}"
    echo -e "${CYAN}   ☁️  uCloud contains: ${GREEN}${UCLOUD_ENTRIES}${CYAN} entrée(s) chiffrée(s)${NC}"
    if [[ ! -f "${UCLOUD_KEYRING_FILE}" ]]; then
        echo -e "${YELLOW}   ⚠️  ucloud_keyring.json missing — entries will be unreadable after restore${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No uCloud index found (no encrypted cloud data to restore)${NC}"
fi

# Check for Qdrant face-recognition catalog export
QDRANT_FACES_FILE=$(find "${RESTORE_DIR}" -name "qdrant_faces.json" | head -1)
QDRANT_COUNT=0
if [[ -f "${QDRANT_FACES_FILE}" ]]; then
    QDRANT_COUNT=$(jq 'length' "${QDRANT_FACES_FILE}" 2>/dev/null || echo "0")
    echo -e "${GREEN}✅ Qdrant face catalog found${NC}"
    echo -e "${CYAN}   🧑‍🤝‍🧑 Face catalog contains: ${GREEN}${QDRANT_COUNT}${CYAN} visage(s)${NC}"
else
    echo -e "${YELLOW}⚠️  No Qdrant face catalog found${NC}"
fi

# Check for Qdrant LifeOS personal memory export
QDRANT_LIFEOS_FILE=$(find "${RESTORE_DIR}" -name "qdrant_lifeos.json" | head -1)
QDRANT_LIFEOS_COUNT=0
if [[ -f "${QDRANT_LIFEOS_FILE}" ]]; then
    QDRANT_LIFEOS_COUNT=$(jq 'length' "${QDRANT_LIFEOS_FILE}" 2>/dev/null || echo "0")
    echo -e "${GREEN}✅ Qdrant LifeOS memory found${NC}"
    echo -e "${CYAN}   🧠 LifeOS memory contains: ${GREEN}${QDRANT_LIFEOS_COUNT}${CYAN} souvenir(s)${NC}"
else
    echo -e "${YELLOW}⚠️  No Qdrant LifeOS memory found${NC}"
fi

# Check for .next.disco (NEW format for restoration on new relay/captain)
NEXT_DISCO_FILE=$(find "${RESTORE_DIR}" -name ".next.disco" | head -1)
NEXT_HEX_FILE=$(find "${RESTORE_DIR}" -name ".next.hex" | head -1)
NEXT_SALT_FILE=$(find "${RESTORE_DIR}" -name ".next.salt" | head -1)
NEXT_PEPPER_FILE=$(find "${RESTORE_DIR}" -name ".next.pepper" | head -1)

# Check for .secret.disco (OLD format - for reference only)
OLD_DISCO_FILE=$(find "${RESTORE_DIR}" -name ".secret.disco" | head -1)

RESTORE_EMAIL=""
RESTORE_SALT=""
RESTORE_PEPPER=""
IS_NEW_RELAY_RESTORE=false

# Priority: Use .next.disco for new relay/captain restoration
if [[ -f "${NEXT_DISCO_FILE}" ]]; then
    echo -e "${GREEN}✅ Next .disco key found (for restoration on NEW relay/captain)${NC}"
    echo -e "${CYAN}   🔮 This backup is ready for migration to a new relay/captain${NC}"
    
    # Extract salt and pepper from .next.disco file
    DISCO_CONTENT=$(cat "${NEXT_DISCO_FILE}")
    echo -e "${CYAN}   📋 Next DISCO content: ${DISCO_CONTENT:0:20}...${NC}"

    if parse_disco "$DISCO_CONTENT"; then
        RESTORE_EMAIL="$D_EMAIL"; RESTORE_SALT="$D_SALT"; RESTORE_PEPPER="$D_PEPPER"
    elif [[ -s "${NEXT_SALT_FILE}" && -s "${NEXT_PEPPER_FILE}" ]]; then
        echo -e "${YELLOW}   ⚠️  DISCO illisible — repli sur .next.salt / .next.pepper${NC}"
        RESTORE_EMAIL=""; RESTORE_SALT=$(cat "${NEXT_SALT_FILE}"); RESTORE_PEPPER=$(cat "${NEXT_PEPPER_FILE}")
    else
        echo -e "${RED}❌ Invalid DISCO format in .next.disco${NC}"
        RESTORE_SALT=""; RESTORE_PEPPER=""
    fi

    if [[ -n "$RESTORE_SALT" && -n "$RESTORE_PEPPER" ]]; then
        IS_NEW_RELAY_RESTORE=true
        echo -e "${GREEN}   🔐 New Salt: ${RESTORE_SALT:0:6}...${NC}"
        if [[ -f "${NEXT_SALT_FILE}" ]] && [[ -f "${NEXT_PEPPER_FILE}" ]]; then
            if [[ "$RESTORE_SALT" == "$(cat "${NEXT_SALT_FILE}")" ]] && [[ "$RESTORE_PEPPER" == "$(cat "${NEXT_PEPPER_FILE}")" ]]; then
                echo -e "${GREEN}   ✅ Salt/Pepper verified against backup files${NC}"
            fi
        fi
        if [[ -f "${NEXT_HEX_FILE}" ]]; then
            NEXT_HEX=$(cat "${NEXT_HEX_FILE}")
            echo -e "${CYAN}   🔮 Next HEX (pre-generated): ${NEXT_HEX:0:20}...${NC}"
        fi
        echo -e "${YELLOW}   ⚠️  IMPORTANT: This is a NEW .disco for restoration on a NEW relay/captain${NC}"
        echo -e "${YELLOW}   ⚠️  The old .secret.disco will NOT work on a new relay${NC}"
    fi
elif [[ -f "${OLD_DISCO_FILE}" ]]; then
    # Fallback to old .secret.disco (for backward compatibility)
    echo -e "${YELLOW}⚠️  Old .secret.disco found (legacy format)${NC}"
    echo -e "${YELLOW}   ⚠️  This is the OLD .disco - it may not work on a new relay${NC}"
    echo -e "${CYAN}   🔑 Attempting restoration with old credentials...${NC}"
    
    DISCO_CONTENT=$(cat "${OLD_DISCO_FILE}")
    echo -e "${CYAN}   📋 Old DISCO content: ${DISCO_CONTENT:0:20}...${NC}"

    if parse_disco "$DISCO_CONTENT"; then
        RESTORE_EMAIL="$D_EMAIL"; RESTORE_SALT="$D_SALT"; RESTORE_PEPPER="$D_PEPPER"
        IS_NEW_RELAY_RESTORE=false
        echo -e "${YELLOW}   ⚠️  WARNING: Using old .disco - restoration may fail on new relay${NC}"
        echo -e "${YELLOW}   💡 For new relay/captain, use .next.disco from a recent backup${NC}"
    else
        echo -e "${RED}❌ Invalid DISCO format in .secret.disco${NC}"
        RESTORE_EMAIL=""; RESTORE_SALT=""; RESTORE_PEPPER=""
    fi
else
    echo -e "${YELLOW}⚠️  No .disco found (limited restoration)${NC}"
    echo -e "${CYAN}   💡 Full account restoration requires .next.disco or .secret.disco${NC}"
    RESTORE_EMAIL=""
    RESTORE_SALT=""
    RESTORE_PEPPER=""
fi

# Compte à recréer : --email, sinon .email de l'archive, sinon nom du dossier
# (<email>_nostr_backup_<date>), sinon l'email porté par un ancien DISCO.
if [[ -n "$RESTORE_SALT" && -n "$RESTORE_PEPPER" ]]; then
    BACKUP_EMAIL_FILE=$(find "${RESTORE_DIR}" -name ".email" | head -1)
    BACKUP_TOPDIR=$(basename "$(dirname "${EXPORT_FILE}")")
    if [[ -n "$FORCE_EMAIL" ]]; then
        RESTORE_EMAIL="$FORCE_EMAIL"
    elif [[ -s "${BACKUP_EMAIL_FILE}" ]]; then
        RESTORE_EMAIL=$(head -n 1 "${BACKUP_EMAIL_FILE}")
    elif [[ -z "$RESTORE_EMAIL" && "$BACKUP_TOPDIR" == *@*_nostr_backup_* ]]; then
        RESTORE_EMAIL="${BACKUP_TOPDIR%%_nostr_backup_*}"
    fi
    if [[ -z "$RESTORE_EMAIL" ]]; then
        echo -e "${RED}❌ Email du compte introuvable dans la sauvegarde — relancer avec --email <EMAIL>${NC}"
        rm -rf "${RESTORE_DIR}"
        exit 1
    fi
    echo -e "${GREEN}   📧 Compte à recréer: ${RESTORE_EMAIL}${NC}"
fi

# Check for ZEN Card files (current + numbered historical versions)
ZEN_SECRET_JUNE=$(find "${RESTORE_DIR}" -name "secret.june" -not -name "secret.june.*" | head -1)
ZEN_G1PUB=$(find "${RESTORE_DIR}" -name ".g1pub" | head -1)
# Find all numbered secret.june.NNN.* (cooperative shares history)
ZEN_JUNE_HISTORY=()
while IFS= read -r -d '' f; do
    ZEN_JUNE_HISTORY+=("$f")
done < <(find "${RESTORE_DIR}" -name "secret.june.[0-9]*" -print0 2>/dev/null | sort -z)

if [[ -f "${ZEN_SECRET_JUNE}" ]]; then
    echo -e "${GREEN}✅ ZEN Card secret.june found${NC}"
    echo -e "${CYAN}   💰 Capital history preserved${NC}"
    if [[ ${#ZEN_JUNE_HISTORY[@]} -gt 0 ]]; then
        echo -e "${GREEN}   📜 ${#ZEN_JUNE_HISTORY[@]} historical version(s) found (cooperative shares)${NC}"
        for f in "${ZEN_JUNE_HISTORY[@]}"; do
            echo -e "${CYAN}      $(basename "$f")${NC}"
        done
    fi
else
    echo -e "${YELLOW}⚠️  No ZEN Card secret.june found (no capital history)${NC}"
fi

# Contenu de la ZenCard (TiddlyWiki + chaîne de versions + historiques de paiements ; AUCUNE clé)
ZEN_CONTENT_FILE=$(find "${RESTORE_DIR}" -name "zencard_content.tgz" | head -1)
if [[ -f "${ZEN_CONTENT_FILE}" ]]; then
    echo -e "${GREEN}✅ ZEN Card TiddlyWiki content found${NC}"
else
    echo -e "${YELLOW}⚠️  No ZEN Card TiddlyWiki content in this archive (no ZEN Card, or archive made before it was saved)${NC}"
fi

if [[ -f "${ZEN_G1PUB}" ]]; then
    echo -e "${GREEN}✅ ZEN Card .g1pub found${NC}"
    echo -e "${CYAN}   🏦 G1 wallet access preserved${NC}"
else
    echo -e "${YELLOW}⚠️  No ZEN Card .g1pub found (no G1 wallet)${NC}"
fi

# Detect UPlanet change (different UPLANETNAME = different cooperative). L'archive ne porte que l'EMPREINTE de
# UPLANETNAME (.uplanetname_sha256) : le nom lui-même est le secret de la constellation d'origine. Les anciennes
# archives (.uplanetname en clair) sont comparées par empreinte aussi, sans jamais afficher le nom.
BACKUP_UPLANET_SHA_FILE=$(find "${RESTORE_DIR}" -name ".uplanetname_sha256" | head -1)
BACKUP_UPLANETNAME_FILE=$(find "${RESTORE_DIR}" -name ".uplanetname" | head -1)
LOCAL_UPLANET_SHA=$(echo -n "${UPLANETNAME}" | sha256sum | cut -d' ' -f1)
BACKUP_UPLANET_SHA=""
if [[ -f "${BACKUP_UPLANET_SHA_FILE}" ]]; then
    BACKUP_UPLANET_SHA=$(tr -d '[:space:]' < "${BACKUP_UPLANET_SHA_FILE}")
elif [[ -f "${BACKUP_UPLANETNAME_FILE}" ]]; then
    BACKUP_UPLANET_SHA=$(echo -n "$(cat "${BACKUP_UPLANETNAME_FILE}")" | sha256sum | cut -d' ' -f1)
fi
SAME_UPLANET=true
# Étiquette de l'UPlanet d'origine = 12 premiers caractères de l'empreinte (nom d'archive des parts, messages) :
# jamais le nom lui-même, secret de la constellation d'origine.
BACKUP_UPLANETNAME="${BACKUP_UPLANET_SHA:0:12}"
if [[ -n "${BACKUP_UPLANET_SHA}" ]]; then
    if [[ "${BACKUP_UPLANET_SHA}" != "${LOCAL_UPLANET_SHA}" ]]; then
        SAME_UPLANET=false
        echo -e "${YELLOW}⚠️  UPlanet change detected (empreinte ${BACKUP_UPLANET_SHA:0:12}… → ${LOCAL_UPLANET_SHA:0:12}…)${NC}"
        echo -e "${CYAN}   📜 ZEN Card history will be archived (new cooperative)${NC}"
        echo -e "${CYAN}   💰 No cashback restoration (different UPlanet)${NC}"
        if [[ -z "$GATEWAY" ]]; then
            ARCHIVE_GATEWAY_FILE=$(find "${RESTORE_DIR}" -name ".gateway" | head -1)
            [[ -s "${ARCHIVE_GATEWAY_FILE}" ]] && GATEWAY=$(tr -d '[:space:]' < "${ARCHIVE_GATEWAY_FILE}")
            if [[ -n "$GATEWAY" ]]; then
                echo -e "${CYAN}   🌐 uDRIVE et cloud chiffré : rapatriés par la passerelle de l'ancienne station (${GATEWAY})${NC}"
            else
                echo -e "${YELLOW}   ⚠️  Autre constellation et aucune passerelle connue : relancer avec --gateway https://<ancienne station> pour rapatrier uDRIVE et cloud${NC}"
            fi
        fi
    else
        echo -e "${GREEN}✅ Same UPlanet (cashback will be restored)${NC}"
    fi
else
    echo -e "${CYAN}   ℹ️  No UPlanet info in backup (legacy format, assuming same UPlanet)${NC}"
fi

# Step 3: Process and import events
echo -e "${YELLOW}Step 3/4:${NC} ${CYAN}Processing events for import...${NC}"

# Count events
TOTAL_EVENTS=$(jq -r 'length' "${EXPORT_FILE}" 2>/dev/null | head -1 || echo "0")
echo -e "${CYAN}   Found ${GREEN}${TOTAL_EVENTS}${CYAN} events in backup${NC}"

if [[ "${TOTAL_EVENTS}" -eq 0 ]]; then
    echo -e "${YELLOW}⚠️  No events to restore${NC}"
    rm -rf "${RESTORE_DIR}"
    exit 0
fi

# Create filtered file (remove "Hello NOSTR visitor." messages)
FILTERED_FILE="${RESTORE_DIR}/filtered.json"
echo -e "${CYAN}   Filtering out unwanted messages...${NC}"

jq -c '.[] | select(.content | test("Hello NOSTR visitor.") | not)' "${EXPORT_FILE}" > "${FILTERED_FILE}" 2>/dev/null

FILTERED_COUNT=$(wc -l < "${FILTERED_FILE}" 2>/dev/null || echo "0")
REMOVED_COUNT=$((TOTAL_EVENTS - FILTERED_COUNT))

if [[ ${REMOVED_COUNT} -gt 0 ]]; then
    echo -e "${CYAN}   Removed ${YELLOW}${REMOVED_COUNT}${CYAN} unwanted messages${NC}"
fi
echo -e "${CYAN}   Ready to import: ${GREEN}${FILTERED_COUNT}${CYAN} events${NC}"

# Step 4: Import to strfry
echo -e "${YELLOW}Step 4/4:${NC} ${CYAN}Importing events to strfry...${NC}"

if [[ ! -x "$HOME/.zen/strfry/strfry" ]]; then
    echo -e "${RED}❌ strfry not found or not executable${NC}"
    rm -rf "${RESTORE_DIR}"
    exit 1
fi

cd "$HOME/.zen/strfry"

# Import with or without verification
if [[ "$NO_VERIFY" == "true" ]]; then
    echo -e "${CYAN}   Using no-verify mode (trusted backup)...${NC}"
    if ./strfry import --no-verify < "${FILTERED_FILE}" 2>/dev/null; then
        echo -e "${GREEN}✅ Successfully imported ${FILTERED_COUNT} events${NC}"
    else
        echo -e "${RED}❌ Failed to import events${NC}"
        rm -rf "${RESTORE_DIR}"
        exit 1
    fi
else
    echo -e "${CYAN}   Using signature verification mode...${NC}"
    if ./strfry import < "${FILTERED_FILE}" 2>/dev/null; then
        echo -e "${GREEN}✅ Successfully imported ${FILTERED_COUNT} events (verified)${NC}"
    else
        echo -e "${RED}❌ Failed to import events${NC}"
        rm -rf "${RESTORE_DIR}"
        exit 1
    fi
fi

# Step 5: Full Account Restoration (if .disco available)
if [[ -n "$RESTORE_EMAIL" && -n "$RESTORE_SALT" && -n "$RESTORE_PEPPER" ]]; then
    echo ""
    echo -e "${YELLOW}Step 5/6:${NC} ${CYAN}Full account restoration...${NC}"
    
    # Check if make_NOSTRCARD.sh exists
    if [[ -f "${MY_PATH}/make_NOSTRCARD.sh" ]]; then
        if [[ "$IS_NEW_RELAY_RESTORE" == "true" ]]; then
            echo -e "${CYAN}   🔄 Recreating MULTIPASS with NEW credentials (for new relay/captain)...${NC}"
            echo -e "${GREEN}   ✅ Using pre-generated .next.disco for restoration on this new relay${NC}"
        else
            echo -e "${CYAN}   🔄 Recreating MULTIPASS with original credentials...${NC}"
            echo -e "${YELLOW}   ⚠️  Using old .secret.disco (may not work on new relay)${NC}"
        fi
        
        # Norme des clés : un NOUVEAU disco (.next.disco) donne une identité neuve en crédentiel isolé ;
        # l'ANCIEN disco doit retrouver le MÊME HEX, donc la formule NOSTR d'origine (.keyformula de l'archive).
        MULTIPASS_NOSTR_FORMULA=isolated
        if [[ "$IS_NEW_RELAY_RESTORE" != "true" ]]; then
            BACKUP_KF_FILE=$(find "${RESTORE_DIR}" -name ".keyformula" | head -1)
            if [[ -s "${BACKUP_KF_FILE}" ]] && grep -q "nostr=legacy" "${BACKUP_KF_FILE}"; then
                MULTIPASS_NOSTR_FORMULA=legacy
                echo -e "${YELLOW}   ⚠️  Compte historique : clé NOSTR en formule legacy, restaurée à l'identique${NC}"
            fi
        fi
        export MULTIPASS_NOSTR_FORMULA

        # Recreate MULTIPASS with salt/pepper
        if "${MY_PATH}/make_NOSTRCARD.sh" "${RESTORE_EMAIL}" "fr" "0.00" "0.00" "${RESTORE_SALT}" "${RESTORE_PEPPER}" 2>/dev/null; then
            echo -e "${GREEN}✅ MULTIPASS recreated successfully${NC}"
            
            # Now import NOSTR events to the recreated account
            echo -e "${CYAN}   📡 Importing NOSTR events to recreated account...${NC}"
            if [[ -f "${FILTERED_FILE}" ]]; then
                cd "$HOME/.zen/strfry"
                if ./strfry import --no-verify < "${FILTERED_FILE}" 2>/dev/null; then
                    echo -e "${GREEN}✅ NOSTR events imported to recreated account${NC}"
                else
                    echo -e "${YELLOW}⚠️  Failed to import events to recreated account${NC}"
                fi
                cd - > /dev/null 2>&1
            fi
            
            # Restore uDRIVE files if manifest exists
            if [[ -f "${MANIFEST_FILE}" ]]; then
                echo -e "${CYAN}   📁 Restoring uDRIVE files from manifest...${NC}"
                UDRIVE_DIR="${HOME}/.zen/game/nostr/${RESTORE_EMAIL}/APP/uDRIVE"
                mkdir -p "${UDRIVE_DIR}"
                
                # Extract final_cid from manifest
                if command -v jq >/dev/null 2>&1; then
                    FINAL_CID=$(jq -r '.final_cid' "${MANIFEST_FILE}" 2>/dev/null)
                    if [[ -n "$FINAL_CID" && "$FINAL_CID" != "null" ]]; then
                        echo -e "${CYAN}   📥 Downloading complete uDRIVE structure from IPFS...${NC}"
                        echo -e "${CYAN}   🔗 Final CID: ${FINAL_CID}${NC}"
                        
                        # Autre constellation : on rapatrie d'abord le DAG par la PASSERELLE de l'ancienne station
                        # (CAR, même CID, blocs vérifiés) ; `ipfs get` lit ensuite le dépôt LOCAL, sans réseau.
                        _UDRIVE_FETCH=0
                        if [[ -n "$GATEWAY" ]]; then
                            python3 "$HOME/.zen/UPassport/gateway_fetch_cli.py" dag "$GATEWAY" "${FINAL_CID}" >/dev/null || _UDRIVE_FETCH=1
                        fi
                        if [[ $_UDRIVE_FETCH -eq 0 ]] && ipfs get "${FINAL_CID}" -o "${UDRIVE_DIR}" 2>/dev/null; then
                            echo -e "${GREEN}✅ Complete uDRIVE structure restored from IPFS${NC}"
                            
                            if [[ -f "${UDRIVE_DIR}/generate_ipfs_structure.sh" ]]; then
                                echo -e "${GREEN}✅ generate_ipfs_structure.sh link verified${NC}"
                            else
                                echo -e "${YELLOW}⚠️  generate_ipfs_structure.sh not found in restored structure${NC}"
                                ln -s "${MY_PATH}/generate_ipfs_structure.sh" "${UDRIVE_DIR}/generate_ipfs_structure.sh"
                            fi
                            # Identité NEUVE (.next.disco) : le manifeste récupéré porte l'ANCIEN propriétaire
                            # (owner_hex_pubkey, station) et a écrasé celui que make_NOSTRCARD.sh venait de générer.
                            # Le générateur déduit le propriétaire du chemin et du fichier HEX du compte : on repart
                            # donc d'un manifeste vierge (sans manifest-1.json, qui le ramènerait) et on le régénère.
                            if [[ "$IS_NEW_RELAY_RESTORE" == "true" ]]; then
                                if ( cd "${UDRIVE_DIR}" && rm -f manifest.json manifest-1.json \
                                     && ./generate_ipfs_structure.sh . >/dev/null ); then
                                    echo -e "${GREEN}✅ uDRIVE manifest regenerated for the new identity${NC}"
                                else
                                    echo -e "${RED}❌ uDRIVE manifest regeneration failed — the manifest still names the OLD owner${NC}"
                                fi
                            fi
                        else
                            echo -e "${RED}❌ Failed to download uDRIVE structure from IPFS${NC}"
                        fi
                    else
                        echo -e "${YELLOW}⚠️  No final_cid found in manifest, skipping uDRIVE restoration${NC}"
                    fi
                else
                    echo -e "${YELLOW}⚠️  jq not found, skipping uDRIVE file restoration${NC}"
                fi
            fi

            # Restore uCloud (FaceCloud encrypted personal cloud) index/keyring.
            # Only these two files are needed: the encrypted blobs themselves stay
            # retrievable on IPFS by the CIDs already listed in index.json — nothing
            # is re-uploaded. dav_token is deliberately NOT restored (it's tied to
            # the OLD hex and the WebDAV password is only ever shown once) — the
            # player must re-enroll via FaceCloud (POST /api/cloud/enroll) to get
            # a fresh WebDAV password bound to their new identity.
            if [[ -f "${UCLOUD_INDEX_FILE}" ]]; then
                echo -e "${CYAN}   ☁️  Restoring uCloud (encrypted cloud) index/keyring...${NC}"
                RESTORE_UCLOUD_DIR="${HOME}/.zen/game/nostr/${RESTORE_EMAIL}/.ucloud"
                mkdir -p "${RESTORE_UCLOUD_DIR}"
                chmod 700 "${RESTORE_UCLOUD_DIR}"
                UCLOUD_BACKUP_PY="${HOME}/.zen/UPassport/ucloud_backup.py"
                if [[ -f "${UCLOUD_BACKUP_PY}" ]]; then
                    # Module partagé (UPassport/ucloud_backup.py) : fusion index +
                    # trousseau, ET sources WebDAV/CardDAV, état d'import,
                    # invitations en attente. Le catalogue de visages est
                    # restauré plus bas (collection au NOUVEAU hex).
                    python3 "${UCLOUD_BACKUP_PY}" restore "${RESTORE_EMAIL}" \
                        --bundle "$(dirname "${UCLOUD_INDEX_FILE}")" --no-qdrant \
                        && echo -e "${GREEN}   ✅ uCloud restored (${UCLOUD_ENTRIES} entrée(s), sources et invitations comprises)${NC}"
                    # Prise de garde : épingler TOUS les fichiers chiffrés sur
                    # CETTE station. Sans ça, ils ne vivent que tant que
                    # l'ancienne station les garde épinglés. En arrière-plan :
                    # des milliers de CID peuvent prendre du temps.
                    nohup python3 "${UCLOUD_BACKUP_PY}" pin "${RESTORE_EMAIL}" ${GATEWAY:+--gateway "$GATEWAY"} \
                        > "$HOME/.zen/tmp/ucloud_pin_${RESTORE_EMAIL}.log" 2>&1 &
                    echo -e "${CYAN}   📌 Épinglage des fichiers chiffrés lancé en arrière-plan${NC}"
                else
                    # Les JSON restaurés remplacent la base SQLite (ucloud.db) : elle est
                    # recréée et importée depuis eux au premier accès d'UPassport.
                    rm -f "${RESTORE_UCLOUD_DIR}/ucloud.db" "${RESTORE_UCLOUD_DIR}/ucloud.db-wal" "${RESTORE_UCLOUD_DIR}/ucloud.db-shm"
                    cp "${UCLOUD_INDEX_FILE}" "${RESTORE_UCLOUD_DIR}/index.json"
                    chmod 600 "${RESTORE_UCLOUD_DIR}/index.json"
                    if [[ -f "${UCLOUD_KEYRING_FILE}" ]]; then
                        cp "${UCLOUD_KEYRING_FILE}" "${RESTORE_UCLOUD_DIR}/keyring.json"
                        chmod 600 "${RESTORE_UCLOUD_DIR}/keyring.json"
                        echo -e "${GREEN}   ✅ uCloud restored (${UCLOUD_ENTRIES} entrée(s))${NC}"
                    else
                        echo -e "${YELLOW}   ⚠️  uCloud index restored WITHOUT keyring — entries unreadable until the keyring is recovered${NC}"
                    fi
                fi
                echo -e "${CYAN}   ℹ️  Re-enroll via FaceCloud for a new WebDAV/CardDAV password${NC}"
            fi

            # Restore Qdrant face-recognition catalog under a FRESH collection
            # named after the NEW hex — the old collection (faces_<OLD_HEX>) is
            # tied to the identity being replaced and stays orphaned there.
            # Point ids/vectors/payloads are re-upserted as-is: recognized
            # friends' pubkeys are independent of the owner's own hex, only the
            # collection NAME needs to change.
            if [[ -f "${QDRANT_FACES_FILE}" ]]; then
                echo -e "${CYAN}   🧑‍🤝‍🧑 Restoring Qdrant face catalog...${NC}"
                RESTORE_HEX_FILE="${HOME}/.zen/game/nostr/${RESTORE_EMAIL}/HEX"
                if [[ -f "${RESTORE_HEX_FILE}" ]]; then
                    QDRANT_RESTORE_HEX=$(cat "${RESTORE_HEX_FILE}")
                    QDRANT_URL="http://localhost:6333"
                    QDRANT_API_KEY=""
                    [[ -s "${HOME}/.zen/ai-company/.env" ]] && QDRANT_API_KEY=$(grep '^QDRANT_API_KEY=' "${HOME}/.zen/ai-company/.env" | cut -d= -f2-)
                    QDRANT_NEW_COLLECTION="faces_${QDRANT_RESTORE_HEX}"

                    curl -s -H "api-key: ${QDRANT_API_KEY}" -H "Content-Type: application/json" \
                        -X PUT "${QDRANT_URL}/collections/${QDRANT_NEW_COLLECTION}" \
                        -d '{"vectors":{"size":512,"distance":"Cosine"}}' >/dev/null 2>&1

                    # --data @file (jamais -d "$body" en argument) : un corps de
                    # plusieurs centaines de vecteurs dépasse ARG_MAX du shell
                    # ("Liste d'arguments trop longue") — constaté en test réel
                    # avec 77 points × 768 dims.
                    QDRANT_UPSERT_FILE=$(mktemp)
                    jq -c '{points: [.[] | {id, vector, payload}]}' "${QDRANT_FACES_FILE}" > "${QDRANT_UPSERT_FILE}" 2>/dev/null
                    if [[ -s "${QDRANT_UPSERT_FILE}" ]]; then
                        QDRANT_UPSERT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
                            -H "api-key: ${QDRANT_API_KEY}" -H "Content-Type: application/json" \
                            -X PUT "${QDRANT_URL}/collections/${QDRANT_NEW_COLLECTION}/points?wait=true" \
                            --data @"${QDRANT_UPSERT_FILE}" 2>/dev/null)
                        rm -f "${QDRANT_UPSERT_FILE}"
                        if [[ "${QDRANT_UPSERT_STATUS}" == "200" ]]; then
                            echo -e "${GREEN}   ✅ Qdrant face catalog restored (${QDRANT_COUNT} visage(s)) under ${QDRANT_NEW_COLLECTION}${NC}"
                        else
                            echo -e "${YELLOW}   ⚠️  Qdrant upsert failed (HTTP ${QDRANT_UPSERT_STATUS})${NC}"
                        fi
                    else
                        echo -e "${YELLOW}   ⚠️  Could not build Qdrant upsert payload${NC}"
                    fi
                else
                    echo -e "${YELLOW}   ⚠️  New HEX not found, skipping Qdrant restoration${NC}"
                fi
            fi

            # Restore Qdrant LifeOS personal memory under a FRESH collection
            # named after the NEW hex16 — same principle as the face catalog
            # above. Vector size is read from the backup itself (not
            # hardcoded) since OLLAMA_EMBED_DIM can differ across stations.
            if [[ -f "${QDRANT_LIFEOS_FILE}" ]]; then
                echo -e "${CYAN}   🧠 Restoring Qdrant LifeOS memory...${NC}"
                RESTORE_HEX_FILE="${HOME}/.zen/game/nostr/${RESTORE_EMAIL}/HEX"
                if [[ -f "${RESTORE_HEX_FILE}" ]]; then
                    LIFEOS_RESTORE_HEX=$(cat "${RESTORE_HEX_FILE}")
                    LIFEOS_RESTORE_HEX16="${LIFEOS_RESTORE_HEX:0:16}"
                    QDRANT_URL="http://localhost:6333"
                    QDRANT_API_KEY=""
                    [[ -s "${HOME}/.zen/ai-company/.env" ]] && QDRANT_API_KEY=$(grep '^QDRANT_API_KEY=' "${HOME}/.zen/ai-company/.env" | cut -d= -f2-)
                    LIFEOS_NEW_COLLECTION="memory_${LIFEOS_RESTORE_HEX16}"
                    LIFEOS_VECTOR_SIZE=$(jq '.[0].vector | length' "${QDRANT_LIFEOS_FILE}" 2>/dev/null)
                    [[ -z "${LIFEOS_VECTOR_SIZE}" || "${LIFEOS_VECTOR_SIZE}" == "null" ]] && LIFEOS_VECTOR_SIZE=768

                    curl -s -H "api-key: ${QDRANT_API_KEY}" -H "Content-Type: application/json" \
                        -X PUT "${QDRANT_URL}/collections/${LIFEOS_NEW_COLLECTION}" \
                        -d "{\"vectors\":{\"size\":${LIFEOS_VECTOR_SIZE},\"distance\":\"Cosine\"}}" >/dev/null 2>&1

                    # --data @file : voir le commentaire équivalent sur le
                    # catalogue de visages ci-dessus (ARG_MAX shell dépassé
                    # dès que le nombre de souvenirs × 768 dims grossit).
                    LIFEOS_UPSERT_FILE=$(mktemp)
                    jq -c '{points: [.[] | {id, vector, payload}]}' "${QDRANT_LIFEOS_FILE}" > "${LIFEOS_UPSERT_FILE}" 2>/dev/null
                    if [[ -s "${LIFEOS_UPSERT_FILE}" ]]; then
                        LIFEOS_UPSERT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
                            -H "api-key: ${QDRANT_API_KEY}" -H "Content-Type: application/json" \
                            -X PUT "${QDRANT_URL}/collections/${LIFEOS_NEW_COLLECTION}/points?wait=true" \
                            --data @"${LIFEOS_UPSERT_FILE}" 2>/dev/null)
                        rm -f "${LIFEOS_UPSERT_FILE}"
                        if [[ "${LIFEOS_UPSERT_STATUS}" == "200" ]]; then
                            echo -e "${GREEN}   ✅ LifeOS memory restored (${QDRANT_LIFEOS_COUNT} souvenir(s)) under ${LIFEOS_NEW_COLLECTION}${NC}"
                        else
                            echo -e "${YELLOW}   ⚠️  LifeOS Qdrant upsert failed (HTTP ${LIFEOS_UPSERT_STATUS})${NC}"
                        fi
                    else
                        echo -e "${YELLOW}   ⚠️  Could not build LifeOS Qdrant upsert payload${NC}"
                    fi
                else
                    echo -e "${YELLOW}   ⚠️  New HEX not found, skipping LifeOS Qdrant restoration${NC}"
                fi
            fi

            # Restore ZEN Card using VISA.new.sh with SALT/PEPPER from secret.june
            if [[ -f "${ZEN_SECRET_JUNE}" ]]; then
                echo -e "${CYAN}   🎮 Recreating ZEN Card with original credentials...${NC}"
                
                # Extract SALT and PEPPER from secret.june
                ZEN_SALT=$(grep '^SALT=' "${ZEN_SECRET_JUNE}" | cut -d'"' -f2)
                ZEN_PEPPER=$(grep '^PEPPER=' "${ZEN_SECRET_JUNE}" | cut -d'"' -f2)
                
                if [[ -n "$ZEN_SALT" && -n "$ZEN_PEPPER" ]]; then
                    echo -e "${CYAN}   🔑 SALT: ${ZEN_SALT:0:20}...${NC}"
                    echo -e "${CYAN}   🔑 PEPPER: ${ZEN_PEPPER:0:20}...${NC}"
                    
                    # Get GPS coordinates from MULTIPASS if available
                    MULTIPASS_GPS="${HOME}/.zen/game/nostr/${RESTORE_EMAIL}/GPS"
                    if [[ -f "${MULTIPASS_GPS}" ]]; then
                        source "${MULTIPASS_GPS}"
                    else
                        LAT="0.00"
                        LON="0.00"
                    fi
                    
                    # Get NPUB and HEX from MULTIPASS if available
                    MULTIPASS_NPUB="${HOME}/.zen/game/nostr/${RESTORE_EMAIL}/NPUB"
                    MULTIPASS_HEX="${HOME}/.zen/game/nostr/${RESTORE_EMAIL}/HEX"
                    
                    RESTORE_NPUB=""
                    RESTORE_HEX=""
                    if [[ -f "${MULTIPASS_NPUB}" ]]; then
                        RESTORE_NPUB=$(cat "${MULTIPASS_NPUB}")
                    fi
                    if [[ -f "${MULTIPASS_HEX}" ]]; then
                        RESTORE_HEX=$(cat "${MULTIPASS_HEX}")
                    fi
                    
                    # Recreate ZEN Card using VISA.new.sh
                    echo -e "${CYAN}   🔄 Creating ZEN Card with VISA.new.sh...${NC}"
                    if "${MY_PATH}/../RUNTIME/VISA.new.sh" \
                        "${ZEN_SALT}" \
                        "${ZEN_PEPPER}" \
                        "${RESTORE_EMAIL}" \
                        "UPlanet" \
                        "fr" \
                        "${LAT}" \
                        "${LON}" \
                        "${RESTORE_NPUB}" \
                        "${RESTORE_HEX}" 2>/dev/null; then
                        
                        echo -e "${GREEN}✅ ZEN Card recreated successfully with original credentials${NC}"

                        # TiddlyWiki : même clé de ZenCard sur TOUTES les UPlanets (clé CAPEX, crédentiel brut), donc le
                        # contenu se restaure tel quel, y compris dans une autre constellation. Le TiddlyWiki tout neuf
                        # créé à l'instant est mis de côté (~/.zen/tmp/zencard_fresh_…, purgé à 20h12), puis remplacé.
                        if [[ -f "${ZEN_CONTENT_FILE}" ]]; then
                            echo -e "${CYAN}   📓 Restoring the ZEN Card TiddlyWiki...${NC}"
                            ZC_UCLOUD_PY="${HOME}/.zen/UPassport/ucloud_backup.py"
                            if [[ -f "${ZC_UCLOUD_PY}" ]] && ZC_RES=$(python3 "${ZC_UCLOUD_PY}" zencard-import "${RESTORE_EMAIL}" "${ZEN_CONTENT_FILE}" ${UPLANET_DOMAIN:+--zone "${UPLANET_DOMAIN}"}); then
                                ZENCARD_CONTENT_RESTORED=true
                                echo -e "${GREEN}   ✅ ZEN Card TiddlyWiki restored ($(echo "${ZC_RES}" | tail -n 1 | jq -r '.files // "?"' 2>/dev/null) file(s))${NC}"
                                # tout lien *.copylaradio.com (domaine d'UPlanet ORIGIN) → OVH_ZONE de CETTE UPlanet Ẑen (UPLANET_DOMAIN, vide sur ORIGIN)
                                ZC_LINKS=$(echo "${ZC_RES}" | tail -n 1 | jq -r 'if .links_rewritten then "\(.links_rewritten.links) link(s) in \(.links_rewritten.files) file(s) → \(.links_rewritten.zone)" elif .links_error then "ERROR: \(.links_error)" else "" end' 2>/dev/null)
                                [[ -n "${ZC_LINKS}" ]] && echo -e "${CYAN}   🔗 TiddlyWiki links: ${ZC_LINKS}${NC}"
                            else
                                echo -e "${RED}   ❌ ZEN Card TiddlyWiki NOT restored — relancer : python3 ${ZC_UCLOUD_PY} zencard-import ${RESTORE_EMAIL} <zencard_content.tgz extrait de l'archive>${NC}"
                            fi
                        fi

                        # Restore secret.june history
                        ZEN_CARD_DIR="${HOME}/.zen/game/players/${RESTORE_EMAIL}"
                        if [[ "$SAME_UPLANET" == "false" ]]; then
                            MIGRATION_NUM=0
                            for f in "${ZEN_CARD_DIR}"/secret.june.[0-9]*; do
                                [[ -f "$f" ]] || continue
                                num_part=$(basename "$f" | sed -n 's/^secret\.june\.\([0-9]\{3\}\)\..*/\1/p')
                                [[ -n "$num_part" ]] && (( 10#$num_part >= MIGRATION_NUM )) && MIGRATION_NUM=$((10#$num_part + 1))
                            done
                            MIGRATION_TAG=$(printf "%03d" "${MIGRATION_NUM}")
                            if [[ -f "${ZEN_SECRET_JUNE}" ]]; then
                                cp "${ZEN_SECRET_JUNE}" "${ZEN_CARD_DIR}/secret.june.${MIGRATION_TAG}.${BACKUP_UPLANETNAME:-unknown}"
                                echo -e "${YELLOW}   📜 Previous secret.june archived as secret.june.${MIGRATION_TAG} (UPlanet change)${NC}"
                            fi
                        fi
                        # Copy all existing numbered versions from backup
                        if [[ ${#ZEN_JUNE_HISTORY[@]} -gt 0 ]]; then
                            for f in "${ZEN_JUNE_HISTORY[@]}"; do
                                cp "$f" "${ZEN_CARD_DIR}/$(basename "$f")"
                            done
                            echo -e "${GREEN}   📜 Restored ${#ZEN_JUNE_HISTORY[@]} historical secret.june version(s)${NC}"
                        fi
                    else
                        echo -e "${RED}❌ Failed to recreate ZEN Card with VISA.new.sh${NC}"
                    fi
                else
                    echo -e "${RED}❌ Invalid SALT/PEPPER in secret.june${NC}"
                fi
            elif [[ -f "${ZEN_G1PUB}" ]]; then
                echo -e "${YELLOW}⚠️  Only .g1pub found, copying to players directory${NC}"
                ZEN_CARD_DIR="${HOME}/.zen/game/players/${RESTORE_EMAIL}"
                mkdir -p "${ZEN_CARD_DIR}"
                cp "${ZEN_G1PUB}" "${ZEN_CARD_DIR}/.g1pub"
                echo -e "${GREEN}✅ ZEN Card .g1pub restored (G1 wallet access)${NC}"
                # Restore numbered secret.june history if available
                if [[ ${#ZEN_JUNE_HISTORY[@]} -gt 0 ]]; then
                    for f in "${ZEN_JUNE_HISTORY[@]}"; do
                        cp "$f" "${ZEN_CARD_DIR}/$(basename "$f")"
                    done
                    echo -e "${GREEN}   📜 Restored ${#ZEN_JUNE_HISTORY[@]} historical secret.june version(s)${NC}"
                fi
            fi
            
            ## CASHBACK RESTORATION: send back ẐEN from UPLANETNAME_G1
            CASHBACK_FILE=$(find "${RESTORE_DIR}" -name ".cashback_amount" | head -1)
            RESTORE_G1PUB=""
            if [[ -f "${HOME}/.zen/game/nostr/${RESTORE_EMAIL}/G1PUBNOSTR" ]]; then
                RESTORE_G1PUB=$(cat "${HOME}/.zen/game/nostr/${RESTORE_EMAIL}/G1PUBNOSTR")
            fi

            if [[ "$SAME_UPLANET" == "false" ]]; then
                echo -e "${YELLOW}   ℹ️  No cashback restoration (UPlanet changed: ${BACKUP_UPLANETNAME:-?}… → ${LOCAL_UPLANET_SHA:0:12}…)${NC}"
            elif [[ -f "${CASHBACK_FILE}" ]] && [[ -n "${RESTORE_G1PUB}" ]]; then
                CASHBACK_RAW=$(cat "${CASHBACK_FILE}" | sed 's/[^0-9.]//g')
                # DESTROY enregistre le solde AVANT d'avoir réussi le cashback. Ne rien
                # verser si les fonds sont encore sur l'ancien wallet (double crédit) :
                # après un cashback réussi il n'y reste que le dépôt existentiel (~1 Ğ1).
                OLD_CB_G1PUB=$(cat "$(find "${RESTORE_DIR}" -name ".cashback_g1pub" | head -1)" 2>/dev/null)
                OLD_CB_BAL=""
                [[ -n "$OLD_CB_G1PUB" ]] && OLD_CB_BAL=$(${MY_PATH}/../tools/G1check.sh "${OLD_CB_G1PUB}" --fresh 2>/dev/null | tail -n 1 | sed 's/[^0-9.]//g')
                if [[ -z "$OLD_CB_BAL" ]]; then
                    echo -e "${YELLOW}   ⚠️  Solde de l'ancien wallet illisible — cashback NON versé (vérifier à la main : ${OLD_CB_G1PUB:-inconnu})${NC}"
                    CASHBACK_RAW="0"
                elif [[ $(echo "${OLD_CB_BAL} > 1.5" | bc -l 2>/dev/null) == "1" ]]; then
                    echo -e "${YELLOW}   ⚠️  L'ancien wallet détient encore ${OLD_CB_BAL} Ğ1 : le cashback de DESTROY n'a pas eu lieu — rien n'est versé (fonds récupérables avec l'ancien .secret.disco)${NC}"
                    CASHBACK_RAW="0"
                fi
                if command -v bc >/dev/null 2>&1; then
                    CASHBACK_AMT=$(echo "scale=2; ${CASHBACK_RAW} - 1" | bc -l 2>/dev/null)
                    CASHBACK_HAS_VALUE=false
                    echo "${CASHBACK_AMT} > 0" | bc -l 2>/dev/null | grep -q "1" && CASHBACK_HAS_VALUE=true
                else
                    CASHBACK_AMT="${CASHBACK_RAW}"
                    CASHBACK_HAS_VALUE=false
                    [[ -n "${CASHBACK_AMT}" ]] && [[ "${CASHBACK_AMT}" != "0" ]] && [[ "${CASHBACK_AMT}" != "0.00" ]] && [[ "${CASHBACK_AMT}" != "1" ]] && [[ "${CASHBACK_AMT}" != "1.00" ]] && CASHBACK_HAS_VALUE=true
                fi

                if [[ "$CASHBACK_HAS_VALUE" == "true" ]]; then
                    echo -e "${CYAN}   💸 Restoring cashback: ${CASHBACK_AMT} Ğ1 (original ${CASHBACK_RAW} - 1 primo) → ${RESTORE_G1PUB:0:16}...${NC}"
                    if [[ ! -s ~/.zen/game/uplanet.G1.dunikey ]]; then
                        ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.G1.dunikey "${UPLANETNAME}.G1" "${UPLANETNAME}.G1"
                        chmod 600 ~/.zen/game/uplanet.G1.dunikey
                    fi
                    if ${MY_PATH}/../tools/PAYforSURE.sh ~/.zen/game/uplanet.G1.dunikey \
                            "${CASHBACK_AMT}" "${RESTORE_G1PUB}" \
                            "MULTIPASS:RESTORE:CASHBACK" 2>/dev/null; then
                        echo -e "${GREEN}   ✅ Cashback ${CASHBACK_AMT} Ğ1 sent to restored MULTIPASS${NC}"
                    else
                        echo -e "${YELLOW}   ⚠️  Cashback transfer failed (UPLANETNAME_G1 may lack funds)${NC}"
                    fi
                else
                    echo -e "${CYAN}   ℹ️  No cashback to restore (${CASHBACK_RAW} Ğ1 ≤ 1 Ğ1 primo)${NC}"
                fi
            else
                echo -e "${CYAN}   ℹ️  No cashback info in backup (pre-cashback format)${NC}"
            fi

            echo -e "${GREEN}✅ Complete account restoration finished${NC}"
        else
            echo -e "${RED}❌ Failed to recreate MULTIPASS${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  make_NOSTRCARD.sh not found, skipping full restoration${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Skipping full restoration (missing DISCO information)${NC}"
fi

# Cleanup
echo ""
echo -e "${CYAN}🧹 Cleaning up temporary files...${NC}"
rm -rf "${RESTORE_DIR}"

# Summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}                 ${GREEN}✅ Restore Completed Successfully${NC}                  ${BLUE}║${NC}"
echo -e "${BLUE}╠════════════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║${NC}  ${CYAN}Total events in backup:${NC}     ${GREEN}${TOTAL_EVENTS}${NC}                                  ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}  ${CYAN}Events imported:${NC}            ${GREEN}${FILTERED_COUNT}${NC}                                  ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}  ${CYAN}Filtered out:${NC}               ${YELLOW}${REMOVED_COUNT}${NC}                                  ${BLUE}║${NC}"

if [[ -f "${MANIFEST_FILE}" ]]; then
    echo -e "${BLUE}║${NC}  ${CYAN}uDRIVE files:${NC}              ${GREEN}${TOTAL_FILES}${NC} (${GREEN}${TOTAL_SIZE}${NC})                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}uDRIVE status:${NC}            ${YELLOW}Manifest available for recreation${NC}        ${BLUE}║${NC}"
fi

if [[ -f "${UCLOUD_INDEX_FILE}" ]]; then
    echo -e "${BLUE}║${NC}  ${CYAN}uCloud entries:${NC}            ${GREEN}${UCLOUD_ENTRIES}${NC}                                  ${BLUE}║${NC}"
fi

if [[ -f "${QDRANT_FACES_FILE}" ]]; then
    echo -e "${BLUE}║${NC}  ${CYAN}Face catalog:${NC}              ${GREEN}${QDRANT_COUNT}${NC}                                  ${BLUE}║${NC}"
fi

if [[ -f "${QDRANT_LIFEOS_FILE}" ]]; then
    echo -e "${BLUE}║${NC}  ${CYAN}LifeOS memory:${NC}             ${GREEN}${QDRANT_LIFEOS_COUNT}${NC}                                  ${BLUE}║${NC}"
fi

if [[ -f "${NEXT_DISCO_FILE}" ]]; then
    echo -e "${BLUE}║${NC}  ${CYAN}Next .disco:${NC}             ${GREEN}Available (NEW relay/captain ready)${NC}      ${BLUE}║${NC}"
elif [[ -f "${OLD_DISCO_FILE}" ]]; then
    echo -e "${BLUE}║${NC}  ${CYAN}Old .disco:${NC}              ${YELLOW}Available (legacy format)${NC}              ${BLUE}║${NC}"
fi

echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ -n "$RESTORE_EMAIL" && -n "$RESTORE_SALT" && -n "$RESTORE_PEPPER" ]]; then
    echo -e "${GREEN}💡 Complete Restoration Achieved:${NC}"
    if [[ "$IS_NEW_RELAY_RESTORE" == "true" ]]; then
        echo -e "   ${GREEN}✅ MULTIPASS recreated with NEW credentials (migration to new relay/captain)${NC}"
        echo -e "   ${CYAN}✅ Using pre-generated .next.disco for restoration on this new relay${NC}"
    else
        echo -e "   ${CYAN}✅ MULTIPASS recreated with original credentials${NC}"
        echo -e "   ${YELLOW}⚠️  Using old .secret.disco (may not work on new relay)${NC}"
    fi
    echo -e "   ${CYAN}✅ NOSTR events imported successfully${NC}"
    if [[ -f "${MANIFEST_FILE}" ]]; then
        echo -e "   ${CYAN}✅ uDRIVE files restored from IPFS${NC}"
    fi
    if [[ -f "${UCLOUD_INDEX_FILE}" ]]; then
        echo -e "   ${CYAN}✅ uCloud (${UCLOUD_ENTRIES} entrée(s)) restored — re-enroll via FaceCloud for a new WebDAV password${NC}"
    fi
    if [[ -f "${QDRANT_FACES_FILE}" ]]; then
        echo -e "   ${CYAN}✅ Face catalog (${QDRANT_COUNT} visage(s)) restored under the new collection${NC}"
    fi
    if [[ -f "${QDRANT_LIFEOS_FILE}" ]]; then
        echo -e "   ${CYAN}✅ LifeOS memory (${QDRANT_LIFEOS_COUNT} souvenir(s)) restored under the new collection${NC}"
    fi
    if [[ -f "${ZEN_SECRET_JUNE}" || -f "${ZEN_G1PUB}" ]]; then
        echo -e "   ${CYAN}✅ ZEN Card recreated with original credentials (capital owner history)${NC}"
    fi
    if [[ "${ZENCARD_CONTENT_RESTORED}" == "true" ]]; then
        echo -e "   ${CYAN}✅ ZEN Card TiddlyWiki restored (content, version chain, payment histories)${NC}"
    fi
    echo -e "   ${CYAN}✅ Account location:${NC} ~/.zen/game/nostr/${RESTORE_EMAIL}/"
    echo ""
    echo -e "${YELLOW}📋 For the User:${NC}"
    if [[ "$IS_NEW_RELAY_RESTORE" == "true" ]]; then
        echo -e "   ${GREEN}• Your MULTIPASS has been successfully migrated to this NEW relay/captain${NC}"
    else
        echo -e "   ${CYAN}• Your complete MULTIPASS has been restored on this Astroport.ONE station${NC}"
    fi
    echo -e "   ${CYAN}• All your NOSTR events, profile, and uDRIVE files are now available${NC}"
else
    echo -e "${GREEN}💡 Next steps for the Captain:${NC}"
    echo -e "   ${CYAN}1. Verify events:${NC} cd ~/.zen/strfry && ./strfry scan '{\"authors\": [\"<HEX>\"]}'"
    if [[ -f "${MANIFEST_FILE}" ]]; then
        echo -e "   ${CYAN}2. Recreate uDRIVE:${NC} Use uDRIVE_manifest.json to restore user's files"
    fi
    if [[ -f "${NEXT_DISCO_FILE}" ]]; then
        echo -e "   ${CYAN}4. Full restoration:${NC} Use .next.disco for complete account recreation on NEW relay"
    elif [[ -f "${OLD_DISCO_FILE}" ]]; then
        echo -e "   ${CYAN}4. Full restoration:${NC} Use .secret.disco for complete account recreation"
    fi
fi
echo ""

exit 0