#!/bin/bash
# -----------------------------------------------------------------------------
# nostr_DESTROY_TW.sh
#
# This script deactivates MULTIPASS management on the relay it occupies
# and ensures NOSTR/IPFS data coherence for uDRIVE.
#
# This procedure allows the user to change RELAY and CAPTAIN.
#
# Key features:
# - Pre-generates next .disco for restoration on new relay/captain
# - Stores next HEX in DID document and NOSTR profile
# - Preserves ZEN Card capital shares (secret.june) - NOT emptied
# - Maintains minimum 1 G1 in ZEN Card for capital shares management
# - Exports uCloud (encrypted personal cloud) index.json + keyring.json —
#   the encrypted blobs themselves stay pinned on IPFS, only the path↔CID
#   mapping and the per-file AES keys need backing up to find/decrypt them
#   again after restoration (dav_token is NOT backed up: it's tied to the
#   OLD hex and the WebDAV password is only ever shown once — the restored
#   account re-enrolls via POST /api/cloud/enroll for a fresh one)
# - Exports the Qdrant face-recognition catalog (faces_<hex>, embeddings +
#   name/pubkey) — collection name is tied to the OLD hex, re-created fresh
#   under the NEW hex on restore
# - Exports Qdrant LifeOS personal memory (memory_<hex16>, souvenirs + pierres tombales) — same
#   principle, re-created under the NEW hex16 on restore. Collective
#   collections (uplanet_geo, station_skills) are never touched: they don't
#   belong to a single MULTIPASS
# - Exports complete backup as a 7z archive (AES-256, noms de fichiers chiffrés)
#   protégée par un secret FORT tiré au hasard, remis UNIQUEMENT dans l'email du
#   joueur. Le .pass (4 chiffres) ne protège plus rien : cassable en millisecondes.
#   Le CID n'est plus publié dans le profil NOSTR ni dans le DID.
#
# Usage: ./nostr_DESTROY_TW.sh [email] [reason]
# If no email is provided, the script will prompt the user to select one.
# reason: INSOLVENCY (default) | INTRUSION | INCOMPATIBLE_KEY
#   Selects the explanation shown in the deactivation emails — keep this in
#   sync with the actual triggering condition (NOSTRCARD.refresh.sh 7-day
#   insolvency check, primal_wallet_control.sh intrusion redirection failure,
#   or NOSTRCARD.refresh.sh dunikey/G1PUBNOSTR mismatch).
# -----------------------------------------------------------------------------
# Deactivate MULTIPASS - Enable Relay/Captain Migration

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/my.sh"

# Function to display usage information
usage() {
    echo "Usage: $ME [email]"
    echo "This script will prompt you to select a player email from the available options."
    exit 1
}

# Function to list available player emails and prompt user to select one
select_player_email() {
    echo "Available player emails:"
    player_emails=($(ls ~/.zen/game/nostr/*@*.*/HEX | rev | cut -d '/' -f 2 | rev))
    if [ ${#player_emails[@]} -eq 0 ]; then
        echo "No player emails found."
        exit 1
    fi

    for i in "${!player_emails[@]}"; do
        g1pub=$(cat ~/.zen/game/nostr/${player_emails[$i]}/G1PUBNOSTR)
        pcoins=$(cat ~/.zen/tmp/coucou/${g1pub}.COINS)
        pprime=$(cat ~/.zen/tmp/coucou/${g1pub}.primal 2>/dev/null)
        echo "$i) ${player_emails[$i]} (${pcoins} Ğ1) ${g1pub} -> ${pprime}" 
    done

    read -p "Select the number corresponding to the player email: " selection
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 0 ] || [ "$selection" -ge ${#player_emails[@]} ]; then
        echo "Invalid selection."
        exit 1
    fi

    player="${player_emails[$selection]}"
}

################### MULTIPASS G1 PUB ###########################
[[ -n "$1" ]] && player="$1"
[[ -z $player ]] && select_player_email
g1pubnostr=$(cat ~/.zen/game/nostr/${player}/G1PUBNOSTR)
[[ -z $g1pubnostr ]] && echo "BAD NOSTR MULTIPASS" && exit 1
hex=$(cat ~/.zen/game/nostr/${player}/HEX)

################### DEACTIVATION REASON (drives email wording) #################
REASON="${2:-INSOLVENCY}"
case "$REASON" in
    INTRUSION)
        REASON_TEXT_EN="This deactivation happened because unauthorized (non-primal) Ğ1 funds were detected in this wallet and could not be safely redirected."
        REASON_TEXT_FR="Cette désactivation est survenue parce que des fonds Ğ1 non autorisés (hors filiation primale) ont été détectés dans ce portefeuille et n'ont pas pu être redirigés en sécurité."
        ;;
    INCOMPATIBLE_KEY)
        REASON_TEXT_EN="This deactivation happened because this account's signing key no longer matched its G1 wallet (a historical account-creation inconsistency) — payments could no longer be signed."
        REASON_TEXT_FR="Cette désactivation est survenue parce que la clé de signature de ce compte ne correspondait plus à son portefeuille G1 (une incohérence historique de création de compte) — les paiements ne pouvaient plus être signés."
        ;;
    *)
        REASON_TEXT_EN="This deactivation happened because your wallet didn't have enough Ẑen for the weekly fee."
        REASON_TEXT_FR="Cette désactivation est survenue parce que votre wallet n'avait plus assez de Ẑen pour la redevance hebdomadaire."
        ;;
esac

################### OC SUBSCRIPTION SAFETY CHECK ###########################
# Un abonné OpenCollective actif ne doit JAMAIS être détruit pour insolvabilité.
# G1PRIME (posé une seule fois par UPLANET.official.sh lors de la primo-tx) ne
# reflète pas un abonnement repris APRÈS coup : on revérifie ici en direct sur
# les caches OC2UPlanet les plus frais (cf. OC2UPlanet/oc2uplanet.sh), en
# dernier filet avant une action irréversible — indépendamment du contrôle déjà
# fait en amont dans NOSTRCARD.refresh.sh.
OC_DATA_DIR="${HOME}/.zen/workspace/OC2UPlanet/data"
if [[ -d "$OC_DATA_DIR" ]] && command -v jq >/dev/null 2>&1; then
    _oc_active=0
    for _oc_f in "${OC_DATA_DIR}/current_month.credit.json" "${OC_DATA_DIR}/last_month.credit.json"; do
        [[ -s "$_oc_f" ]] || continue
        _oc_active=$(jq -rs --arg e "$player" \
            '[.[] | select(.fromAccount.emails[]? == $e)] | length' "$_oc_f" 2>/dev/null)
        [[ "${_oc_active:-0}" -gt 0 ]] && break
    done
    if [[ "${_oc_active:-0}" -gt 0 ]]; then
        echo "❌ ABORT: ${player} est un contributeur OpenCollective actif (ce mois ou le precedent)."
        echo "   Destruction annulee — verifier pourquoi l'appelant l'a declenchee malgre tout"
        echo "   (G1PRIME manquant ? sync OC2UPlanet en retard ? bug amont ?)"

        if [[ -n "${CAPTAINEMAIL:-}" ]] && [[ -x "${MY_PATH}/../tools/mailjet.sh" ]]; then
            _oc_alert_tmp=$(mktemp)
            cat > "$_oc_alert_tmp" <<OCALERTEOF
<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"></head>
<body style="font-family:sans-serif;background:#fff3e0;padding:1.5rem">
<div style="max-width:600px;margin:0 auto;background:#fff;border-radius:8px;overflow:hidden">
<div style="background:linear-gradient(135deg,#e65c00,#f9a825);color:#fff;padding:1.2rem;text-align:center">
<strong>🚨 Destruction MULTIPASS annulée</strong></div>
<div style="padding:1.2rem;color:#1a1a2e">
<p><strong>${player}</strong> a été identifié comme <strong>contributeur OpenCollective actif</strong>
(ce mois ou le précédent) au moment où sa destruction pour insolvabilité allait s'exécuter.</p>
<p>La destruction a été <strong>annulée automatiquement</strong> — aucune action n'a été effectuée sur ce compte.</p>
<p>À vérifier :</p>
<ul>
<li>Pourquoi le contrôle en amont (NOSTRCARD.refresh.sh) a-t-il déclenché la destruction malgré tout ?</li>
<li><code>G1PRIME</code> est-il absent pour ce joueur (~/.zen/game/nostr/${player}/G1PRIME) ?</li>
<li>La synchro OC2UPlanet est-elle à jour (~/.zen/workspace/OC2UPlanet/data/) ?</li>
</ul>
<p style="color:#666;font-size:.85rem">Astroport.ONE — nostr_DESTROY_TW.sh — $(date '+%Y-%m-%d %H:%M:%S')</p>
</div></div></body></html>
OCALERTEOF
            "${MY_PATH}/../tools/mailjet.sh" --template "$0" --expire 7d \
                "${CAPTAINEMAIL}" "$_oc_alert_tmp" \
                "🚨 Destruction annulée — ${player} est un contributeur OC actif"
            rm -f "$_oc_alert_tmp"
        fi
        exit 1
    fi
fi

##################### DISCO DECODING ########################
if [[ -s ~/.zen/game/nostr/${player}/.secret.disco ]]; then
    DISCO=$(cat ~/.zen/game/nostr/${player}/.secret.disco)
    IFS='=&' read -r s salt p pepper <<< "$DISCO"
else
    tmp_mid=$(mktemp)
    tmp_tail=$(mktemp)
    # Decrypt the middle part using CAPTAIN key
    ${MY_PATH}/../tools/natools.py decrypt -f pubsec -i "$HOME/.zen/game/nostr/${player}/.ssss.mid.captain.enc" \
            -k ~/.zen/game/players/.current/secret.dunikey -o "$tmp_mid"

    # Decrypt the tail part using UPLANET dunikey
    if [[ ! -s ~/.zen/game/uplanet.dunikey ]]; then
        ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.dunikey "${UPLANETNAME}" "${UPLANETNAME}"
        chmod 600 ~/.zen/game/uplanet.dunikey
    fi
    ${MY_PATH}/../tools/natools.py decrypt -f pubsec -i "$HOME/.zen/game/nostr/${player}/ssss.tail.uplanet.enc" \
            -k ~/.zen/game/uplanet.dunikey -o "$tmp_tail"

    # Combine decrypted shares
    DISCO=$(cat "$tmp_mid" "$tmp_tail" | ssss-combine -t 2 -q 2>&1 | tail -n 1)
    IFS='=&' read -r s salt p pepper <<< "$DISCO"

    if [[ -n $pepper ]]; then
        rm "$tmp_mid" "$tmp_tail"
    else
        cat "$tmp_mid" "$tmp_tail"
        echo "[ERROR] BAD DISCO RECONSTRUCTION... MULTIPASS salt pepper are lost..."
        echo "DELETE MANUALY : rm -rf $HOME/.zen/game/nostr/${player}"
        echo "${MY_PATH}/../RUNTIME/PLAYER.unplug.sh \"${HOME}/.zen/game/players/${player}/ipfs/moa/index.html\" \"${player}\" \"ALL\""
        exit 1
    fi
fi

if [[ -n ${salt} && -n ${pepper} ]]; then
    rm "$tmp_mid" "$tmp_tail" 2>/dev/null
    rm ~/.zen/game/nostr/${player}/ERROR 2>/dev/null
else
    echo "[ERROR] BAD DISCO DECODING for ${player}"
    # Si le compte est vieux de plus de 7 jours et corrompu -> Nettoyage RADICAL
    BIRTHDATE=$(cat ~/.zen/game/nostr/${player}/.account_created 2>/dev/null)
    if [[ -n "$BIRTHDATE" ]]; then
        DIFF=$(( ($(date +%s) - $(date -d "$BIRTHDATE" +%s)) / 86400 ))
        if [ $DIFF -gt 7 ]; then
            echo "[WARN] Broken account older than 7 days. Forcing hard removal: $player"
            rm -rf "${HOME}/.zen/game/nostr/${player}"
            rm -rf "${HOME}/.zen/game/players/${player}" # Nettoie aussi la ZenCard associée
        fi
    fi
    # Pas de boucle dans ce script (traite un seul joueur) : `exit 0` dans les
    # 2 cas (nettoyé ou grace period) pour éviter que l'appelant (ex:
    # NOSTRCARD.refresh.sh, qui bascule sur un rm -rf brutal si ce script
    # échoue) ne déclenche une destruction prématurée pendant la grace period.
    exit 0
fi

##################################################### DISCO DECODED
echo "Target email: $player"
youser=$($MY_PATH/../tools/clyuseryomail.sh "${player}")
# Norme des clés (my.sh) : la clé NOSTR de CE compte, avec sa propre formule (jamais un pepper brut deviné)
_nostr_cred=$(account_cred_file "${player}" nostr) \
    || { echo "[ERROR] clé NOSTR de ${player} irreconstructible (aucune formule ne reproduit son HEX) — destruction annulée" >&2; exit 1; }
secnostr=$(${MY_PATH}/../tools/keygen -t nostr -s -i "$_nostr_cred")
pubnostr=$(${MY_PATH}/../tools/keygen -t nostr -i "$_nostr_cred")
rm -f "$_nostr_cred"

OUTPUT_DIR="$HOME/.zen/game/nostr/${player}"

echo "Exporting NOSTR events..."
cd ~/.zen/strfry
# Export NOSTR events and format as proper JSON array
echo "[" > "${OUTPUT_DIR}/nostr_export.json"
./strfry scan '{"authors": ["'$hex'"]}' 2> /dev/null | sed 's/^/,/' | sed '1s/^,//' >> "${OUTPUT_DIR}/nostr_export.json"
echo "]" >> "${OUTPUT_DIR}/nostr_export.json"
cd - > /dev/null 2>&1

# Chaque événement est sur sa ligne, préfixée d'une virgule sauf le premier (',{…' ou '{…') : compter les deux,
# sinon un compte de 7 événements s'affichait « 1 ».
COUNT=$(grep -c '^,\?{' "${OUTPUT_DIR}/nostr_export.json" 2>/dev/null || echo "0")
echo "Exported ${COUNT} events to ${OUTPUT_DIR}/nostr_export.json"

## PREGENERATE NEXT .disco FOR RESTORATION (before creating instructions)
echo "🔮 Pre-generating next .disco for restoration on new relay/captain..."
# Generate new SALT and PEPPER for restoration
# Max 56 chars each: DISCO format "/?salt=<56>&nostr=<56>" = 14+112 = 126 bytes ≤ 127 (ssss default limit)
# Email excluded from DISCO (known from context) — consistent with make_NOSTRCARD.sh
NEW_SALT=$(head -c 200 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 56)
NEW_PEPPER=$(head -c 200 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 56)
NEW_DISCO="/?salt=${NEW_SALT}&nostr=${NEW_PEPPER}"

# Generate next HEX from new SALT/PEPPER
# Même formule que make_NOSTRCARD.sh pour un nouveau compte (crédentiel isolé de CETTE UPlanet) :
# valable pour une restauration dans la même UPlanet (autre UPlanet = autre sel = autre HEX).
_next_cred=$(uplanet_cred_file "${NEW_SALT}" "${NEW_PEPPER}" isolated)
NEXT_NPUB=$(${MY_PATH}/../tools/keygen -t nostr -i "$_next_cred" 2>/dev/null)
rm -f "$_next_cred"
NEXT_HEX=$(${MY_PATH}/../tools/nostr2hex.py "$NEXT_NPUB" 2>/dev/null)

if [[ -n "$NEXT_HEX" ]]; then
    echo "✅ Next restoration HEX pre-generated: ${NEXT_HEX:0:20}..."
    echo "   📝 New .disco will be: ${NEW_DISCO:0:50}..."
else
    echo "⚠️  Failed to generate next HEX, restoration will require new .disco creation"
    NEXT_HEX=""
    NEW_SALT=""
    NEW_PEPPER=""
    NEW_DISCO=""
fi

# Create a simple restore script inside the backup
cat > "${OUTPUT_DIR}/RESTORE_INSTRUCTIONS.sh" <<RESTORE_SCRIPT
#!/bin/bash
# NOSTR Account Restore Instructions
# Usage: ./RESTORE_INSTRUCTIONS.sh

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   NOSTR Account Restore Instructions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This cryptographically encrypted backup contains:"
echo "  • nostr_export.json - All your Nostr events"
echo "  • uDRIVE_manifest.json - Your uDRIVE file manifest"
echo "  • ucloud_index.json / ucloud_keyring.json - Your encrypted cloud"
echo "    (FaceCloud) index and decryption keys — the photos themselves"
echo "    stay on IPFS, these files are what finds and decrypts them"
echo "  • qdrant_faces.json - Your FaceCloud face-recognition catalog"
echo "    (embeddings + names/keys of recognized people)"
echo "  • qdrant_lifeos.json - Your LifeOS personal memory (BRO, embeddings +"
echo "    content, tombstones of forgotten memories)"
echo "  • .secret.disco - Your OLD secret key (for reference)"
echo "  • .next.disco - PRE-GENERATED new .disco for restoration"
echo "  • .next.hex - Next HEX address for new relay/captain"
echo "  • secret.june - ZEN Card transaction history (capital shares)"
echo "  • .g1pub - ZEN Card G1 wallet access"
echo "  • zencard_content.tgz - Your ZEN Card TiddlyWiki (your content and its version"
echo "    chain, payment histories — no key), restored by nostr_RESTORE_TW.sh"
echo ""
echo "🔐 ENCRYPTED"
echo "Your backup.7z is AES-256 encrypted. The secret was sent ONLY to your email"
echo "(it is NOT your PASS code)."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "RESTORATION METHODS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Method 1: Automated restore (RECOMMENDED)"
echo "  cd ~/.zen/Astroport.ONE"
echo "  ./tools/nostr_RESTORE_TW.sh <IPFS_CID_OF_BACKUP>"
echo "  (Script will prompt for the archive secret from your email)"
echo ""
echo "Method 2: Manual restoration with NEW .disco"
echo "  1. Extract backup.7z (secret from your deactivation email):"
echo "     7z x backup.7z"
echo "  2. Use .next.disco to create MULTIPASS on new relay:"
echo "     cat .next.disco"
echo "  3. Create MULTIPASS with same email + .next.disco:"
echo "     ./tools/make_NOSTRCARD.sh <EMAIL> <LANG> <LAT> <LON> <NEW_SALT> <NEW_PEPPER>"
echo "  4. Import events to new account:"
echo "     jq -c '.[]' nostr_export.json | ./strfry import --no-verify"
echo ""
echo "Method 3: uDRIVE restoration"
echo "  - Use uDRIVE_manifest.json to recreate your file structure"
echo "  - All files are still available via IPFS links in manifest"
echo ""
echo "Method 4: uCloud (FaceCloud encrypted cloud) restoration"
echo "  - Automated by nostr_RESTORE_TW.sh (copies ucloud_index.json and"
echo "    ucloud_keyring.json into ~/.zen/game/nostr/<EMAIL>/.ucloud/)"
echo "  - The encrypted photos/files themselves stay retrievable on IPFS"
echo "    by the CIDs listed in ucloud_index.json — nothing to re-upload"
echo "  - Re-enroll via FaceCloud (POST /api/cloud/enroll) afterwards to"
echo "    get a NEW WebDAV password — the old dav_token is not restored"
echo ""
echo "Method 5: Qdrant face catalog restoration"
echo "  - Automated by nostr_RESTORE_TW.sh (recreates collection"
echo "    faces_<NEW_HEX> and re-upserts every point from qdrant_faces.json)"
echo "  - The old collection faces_<OLD_HEX> is left untouched/orphaned"
echo ""
echo "Method 6: Qdrant LifeOS memory restoration"
echo "  - Automated by nostr_RESTORE_TW.sh (recreates collection"
echo "    memory_<NEW_HEX16> and re-upserts every point from qdrant_lifeos.json)"
echo "  - The old collection memory_<OLD_HEX16> is left untouched/orphaned"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ZEN Card Capital Shares:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Your ZEN Card capital shares are preserved in secret.june"
echo "This file contains the transaction history of capital shares"
echo "received from UPLANETNAME_SOCIETY."
echo ""
RESTORE_SCRIPT
chmod +x "${OUTPUT_DIR}/RESTORE_INSTRUCTIONS.sh"

# Create a README file with backup information
cat > "${OUTPUT_DIR}/README_BACKUP.txt" <<EOF
╔════════════════════════════════════════════════════════════════╗
║           NOSTR MULTIPASS BACKUP INFORMATION                   ║
╚════════════════════════════════════════════════════════════════╝

Backup Date: $(date '+%Y-%m-%d %H:%M:%S')
Account: ${player}
Public Key (HEX): ${hex}
G1 Wallet: ${g1pubnostr}
$(if [[ -n "$NEXT_HEX" ]]; then echo "Next HEX (for restoration): ${NEXT_HEX:0:20}..."; fi)

This encrypted backup contains:
  • nostr_export.json - ${COUNT} Nostr events
  • uDRIVE_manifest.json - Your uDRIVE file manifest (if exists)
  • ucloud_index.json / ucloud_keyring.json - Your FaceCloud encrypted
    cloud index and per-file decryption keys (if exists)
  • qdrant_faces.json - Your FaceCloud face-recognition catalog
    (embeddings + names/keys of recognized people, if exists)
  • qdrant_lifeos.json - Your LifeOS personal memory (BRO, embeddings +
    content, tombstones of forgotten memories, if exists)
  • .secret.disco - Your OLD secret key (for reference only)
  • .next.disco - PRE-GENERATED new .disco for restoration on new relay
  • .next.hex - Next HEX address (pre-calculated)
  • .next.salt / .next.pepper - New credentials for restoration
  • secret.june - ZEN Card transaction history (capital shares preserved)
  • .g1pub - ZEN Card G1 wallet access
  • zencard_content.tgz - Your ZEN Card TiddlyWiki (your content and its version
    chain, payment histories — no key), restored by nostr_RESTORE_TW.sh
  • .gateway / .uplanetname_sha256 - Previous station gateway (data repatriation
    when moving to ANOTHER constellation) and a fingerprint of its UPlanet
  • RESTORE_INSTRUCTIONS.sh - Quick restore guide

🔐 ENCRYPTED (AES-256):
This backup.7z is protected by a random secret sent ONLY to your email
(it is NOT your PASS code) — you need it to extract.

═══════════════════════════════════════════════════════════════

ACCOUNT MIGRATION TO NEW RELAY/CAPTAIN:

Your account has been deactivated on the previous relay.
This allows you to migrate to a NEW relay and NEW captain.

IMPORTANT: You MUST use the NEW .disco (.next.disco) for restoration
The old .disco will NOT work on a new relay.

The next HEX is pre-calculated and stored in:
  • This backup (.next.hex)
  • Your DID document (did:nostr:${hex})
  • Your NOSTR profile (about field)

═══════════════════════════════════════════════════════════════

RESTORE METHODS:

Method 1: Using Astroport restore tool (RECOMMENDED)
  $ cd ~/.zen/Astroport.ONE
  $ ./tools/nostr_RESTORE_TW.sh <IPFS_CID>
  (Script will prompt for the archive secret and use .next.disco)

Method 2: Manual recreation with NEW .disco
  $ cd ~/.zen/Astroport.ONE
  $ 7z x backup.7z   # asks for the secret from your deactivation email
  $ cat backup/.next.disco
  $ # Use the SALT and PEPPER from .next.salt and .next.pepper
  $ ./tools/make_NOSTRCARD.sh <EMAIL> <LANG> <LAT> <LON> <NEW_SALT> <NEW_PEPPER>
  $ cd ~/.zen/strfry
  $ jq -c '.[]' backup/nostr_export.json | ./strfry import --no-verify

Method 3: uDRIVE restoration
  Use uDRIVE_manifest.json to recreate your file structure
  All files are still available via IPFS links in manifest

Method 4: uCloud (FaceCloud) restoration — automated by nostr_RESTORE_TW.sh
  ucloud_index.json and ucloud_keyring.json are copied back into
  ~/.zen/game/nostr/<EMAIL>/.ucloud/ — the encrypted photos/files
  themselves stay retrievable on IPFS by the CIDs listed in the index,
  nothing to re-upload. Re-enroll via FaceCloud (POST /api/cloud/enroll)
  afterwards to get a NEW WebDAV password — the old dav_token is tied to
  the OLD hex and is not restored.

Method 5: Qdrant face catalog restoration — automated by nostr_RESTORE_TW.sh
  A fresh collection faces_<NEW_HEX> is created and every point from
  qdrant_faces.json (embedding + name/pubkey/timestamp/source_path/bbox)
  is re-upserted into it. The old collection faces_<OLD_HEX> is left
  orphaned on the previous relay/captain (not deleted, not migrated).

Method 6: Qdrant LifeOS memory restoration — automated by nostr_RESTORE_TW.sh
  A fresh collection memory_<NEW_HEX16> is created and every point from
  qdrant_lifeos.json (embedding + slot/content) is re-upserted into it.
  The old collection memory_<OLD_HEX16> is left orphaned on the previous
  relay/captain (not deleted, not migrated). Collective collections
  (uplanet_geo, station_skills) are never touched.

═══════════════════════════════════════════════════════════════

ZEN CARD CAPITAL SHARES:

Your ZEN Card capital shares are preserved in secret.june.
This file contains the complete transaction history of capital shares
received from UPLANETNAME_SOCIETY.

The ZEN Card wallet (.g1pub) maintains minimum 1 G1 for capital
shares management. It is NOT emptied during account deactivation.

For support: ${CAPTAINEMAIL}
UPlanet ORIGIN: https://qo-op.com

═══════════════════════════════════════════════════════════════
EOF

# Create minimal backup with only essential files
BACKUP_DIR="$HOME/.zen/tmp/${player}_nostr_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "${BACKUP_DIR}"
# L'email n'est PAS dans le DISCO (/?salt=..&nostr=..) : le consigner pour que
# nostr_RESTORE_TW.sh sache pour quel compte recréer le MULTIPASS.
echo "${player}" > "${BACKUP_DIR}/.email"

echo "Creating minimal backup with essential files only..."

# Copy nostr_export.json (already created)
if [[ -f "${OUTPUT_DIR}/nostr_export.json" ]]; then
    cp "${OUTPUT_DIR}/nostr_export.json" "${BACKUP_DIR}/"
    echo "✅ NOSTR events exported: ${COUNT} events"
else
    echo "⚠️  nostr_export.json not found"
fi

# Copy uDRIVE manifest.json if it exists
MANIFEST_FILE="${HOME}/.zen/game/nostr/${player}/APP/uDRIVE/manifest.json"
if [[ -f "${MANIFEST_FILE}" ]]; then
    cp "${MANIFEST_FILE}" "${BACKUP_DIR}/uDRIVE_manifest.json"
    echo "✅ uDRIVE manifest exported"
    
    # Show manifest summary
    TOTAL_SIZE=$(jq -r '.formatted_total_size' "${MANIFEST_FILE}" 2>/dev/null || echo "unknown")
    TOTAL_FILES=$(jq -r '.total_files' "${MANIFEST_FILE}" 2>/dev/null || echo "unknown")
    echo "   📊 uDRIVE contains: ${TOTAL_FILES} files (${TOTAL_SIZE})"
else
    echo "⚠️  uDRIVE manifest not found (no uDRIVE data to backup)"
fi

# uCloud (FaceCloud) : export par le module PARTAGÉ avec la sauvegarde
# quotidienne et la restauration (UPassport/ucloud_backup.py export) — mêmes
# noms de fichiers qu'avant (ucloud_index.json, ucloud_keyring.json,
# qdrant_faces.json, lus tels quels par nostr_RESTORE_TW.sh), plus ce qui
# manquait : sources WebDAV/CardDAV, état d'import (évite un réimport complet),
# invitations « Envoyer ses photos » en attente. Les fiches de contact (vCard)
# sont des fichiers du cloud : couvertes par l'index. dav_token jamais copié
# (lié à l'ANCIEN hex — réenrôlement via FaceCloud après restauration).
# Qdrant : utilisé par la branche de repli ci-dessous ET par l'export LifeOS qui suit.
QDRANT_URL="http://localhost:6333"
QDRANT_API_KEY=""
[[ -s "${HOME}/.zen/ai-company/.env" ]] && QDRANT_API_KEY=$(grep '^QDRANT_API_KEY=' "${HOME}/.zen/ai-company/.env" | cut -d= -f2-)
UCLOUD_BACKUP_PY="${HOME}/.zen/UPassport/ucloud_backup.py"
if [[ -f "${UCLOUD_BACKUP_PY}" ]] && UCLOUD_EXPORT=$(python3 "${UCLOUD_BACKUP_PY}" export "${player}" "${BACKUP_DIR}" | tail -n 1) \
        && [[ -n "${UCLOUD_EXPORT}" ]]; then
    echo "✅ uCloud (FaceCloud) exporté : ${UCLOUD_EXPORT}"
else
    echo "⚠️  ucloud_backup.py indisponible — export minimal (index/trousseau/visages)"
    # Copy uCloud (encrypted personal cloud) index.json + keyring.json — the
    # actual encrypted blobs stay pinned on IPFS (cloud_storage.py::ipfs_add_bytes
    # pins at PUT time), only these two files are needed to find and decrypt them
    # again. dav_token is deliberately NOT copied: it's tied to the OLD hex and
    # the WebDAV password is only ever shown once — restoration re-enrolls
    # (POST /api/cloud/enroll, FaceCloud) instead of reusing a stale token.
    UCLOUD_DIR="${HOME}/.zen/game/nostr/${player}/.ucloud"
    # L'index et le keyring vivent dans SQLite (ucloud.db) : exportés en JSON
    # historique (mêmes noms de fichiers) par UPassport/ucloud_export.py.
    UCLOUD_EXPORT_PY="${HOME}/.zen/UPassport/ucloud_export.py"
    if [[ -s "${UCLOUD_DIR}/ucloud.db" && -f "${UCLOUD_EXPORT_PY}" ]]; then
        if UCLOUD_EXPORT_OUT=$(python3 "${UCLOUD_EXPORT_PY}" "${player}" "${BACKUP_DIR}"); then
            echo "✅ uCloud exporté : ${UCLOUD_EXPORT_OUT}"
        else
            echo "⚠️  Export uCloud en échec — fichiers illisibles après restauration" >&2
        fi
    elif [[ -s "${UCLOUD_DIR}/index.json" ]]; then
        cp "${UCLOUD_DIR}/index.json" "${BACKUP_DIR}/ucloud_index.json"
        UCLOUD_ENTRIES=$(jq -r '.entries | length' "${UCLOUD_DIR}/index.json" 2>/dev/null || echo "0")
        echo "✅ uCloud index exported (${UCLOUD_ENTRIES} entrée(s))"
        if [[ -s "${UCLOUD_DIR}/keyring.json" ]]; then
            cp "${UCLOUD_DIR}/keyring.json" "${BACKUP_DIR}/ucloud_keyring.json"
            echo "✅ uCloud keyring exported"
        else
            echo "⚠️  uCloud keyring.json manquant — fichiers illisibles après restauration"
        fi
    else
        echo "ℹ️  Pas de cloud chiffré (uCloud) actif pour ${player}"
    fi

    # Export Qdrant face-recognition catalog (faces_<hex> — embeddings 512D +
    # payload name/pubkey/timestamp/source_path/bbox, cf.
    # Astroport.ONE/IA/bro/satellite_face_matcher.py). The collection name is
    # tied to the OLD hex and becomes orphaned after migration — a fresh
    # collection is recreated under the NEW hex on restore (nostr_RESTORE_TW.sh).
    QDRANT_COLLECTION="faces_${hex}"
    QDRANT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "api-key: ${QDRANT_API_KEY}" \
        "${QDRANT_URL}/collections/${QDRANT_COLLECTION}" 2>/dev/null)
    if [[ "${QDRANT_STATUS}" == "200" ]]; then
        QDRANT_POINTS=$(curl -s -H "api-key: ${QDRANT_API_KEY}" -H "Content-Type: application/json" \
            -X POST "${QDRANT_URL}/collections/${QDRANT_COLLECTION}/points/scroll" \
            -d '{"limit":10000,"with_payload":true,"with_vector":true}' 2>/dev/null \
            | jq -c '.result.points' 2>/dev/null)
        if [[ -n "${QDRANT_POINTS}" ]] && [[ "${QDRANT_POINTS}" != "null" ]]; then
            echo "${QDRANT_POINTS}" > "${BACKUP_DIR}/qdrant_faces.json"
            QDRANT_COUNT=$(echo "${QDRANT_POINTS}" | jq 'length' 2>/dev/null || echo "0")
            echo "✅ Qdrant face catalog exported (${QDRANT_COUNT} visage(s))"
        else
            echo "⚠️  Échec export catalogue Qdrant"
        fi
    else
        echo "ℹ️  Pas de catalogue de visages Qdrant pour ${player}"
    fi
fi

# Export Qdrant LifeOS personal memory (memory_<hex16> — mémoires par slot :
# BRO/persona/LOVE/etc., cf. Astroport.ONE/IA/memory_manager.py). Distinct des
# collections COLLECTIVES uplanet_geo/station_skills, volontairement JAMAIS
# touchées ici — elles n'appartiennent pas à un seul MULTIPASS. Même principe
# que faces_<hex> : collection nommée d'après l'ANCIEN hex16, recréée fraîche
# sous le NOUVEAU hex16 à la restauration.
HEX16="${hex:0:16}"
LIFEOS_COLLECTION="memory_${HEX16}"
LIFEOS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "api-key: ${QDRANT_API_KEY}" \
    "${QDRANT_URL}/collections/${LIFEOS_COLLECTION}" 2>/dev/null)
if [[ -s "${BACKUP_DIR}/qdrant_lifeos.json" ]]; then
    # Déjà exporté, paginé, par UPassport/ucloud_backup.py (le scroll ci-dessous
    # s'arrête à 10000 points et tronquerait une grosse mémoire).
    echo "✅ LifeOS memory exported par ucloud_backup.py ($(jq 'length' "${BACKUP_DIR}/qdrant_lifeos.json" 2>/dev/null) souvenir(s))"
elif [[ "${LIFEOS_STATUS}" == "200" ]]; then
    LIFEOS_POINTS=$(curl -s -H "api-key: ${QDRANT_API_KEY}" -H "Content-Type: application/json" \
        -X POST "${QDRANT_URL}/collections/${LIFEOS_COLLECTION}/points/scroll" \
        -d '{"limit":10000,"with_payload":true,"with_vector":true}' 2>/dev/null \
        | jq -c '.result.points' 2>/dev/null)
    if [[ -n "${LIFEOS_POINTS}" ]] && [[ "${LIFEOS_POINTS}" != "null" ]]; then
        echo "${LIFEOS_POINTS}" > "${BACKUP_DIR}/qdrant_lifeos.json"
        LIFEOS_COUNT=$(echo "${LIFEOS_POINTS}" | jq 'length' 2>/dev/null || echo "0")
        echo "✅ LifeOS memory exported (${LIFEOS_COUNT} souvenir(s))"
    else
        echo "⚠️  Échec export mémoire LifeOS"
    fi
else
    echo "ℹ️  Pas de mémoire LifeOS pour ${player}"
fi

# Copy .disco secret key if it exists
DISCO_FILE="${HOME}/.zen/game/nostr/${player}/.secret.disco"
if [[ -f "${DISCO_FILE}" ]]; then
    cp "${DISCO_FILE}" "${BACKUP_DIR}/.secret.disco"
    echo "✅ Secret .disco key exported"
else
    echo "⚠️  .secret.disco not found (no secret key to backup)"
fi

# Copy ZEN Card secret.june (cooperative shares history)
ZEN_SECRET_JUNE="${HOME}/.zen/game/players/${player}/secret.june"
if [[ -f "${ZEN_SECRET_JUNE}" ]]; then
    # Copy current secret.june to backup
    cp "${ZEN_SECRET_JUNE}" "${BACKUP_DIR}/secret.june"
    # Copy all existing numbered versions into backup
    for f in "${HOME}/.zen/game/players/${player}"/secret.june.[0-9]*; do
        [[ -f "$f" ]] && cp "$f" "${BACKUP_DIR}/"
    done
    # Count existing history
    HISTORY_COUNT=$(ls "${HOME}/.zen/game/players/${player}"/secret.june.[0-9]* 2>/dev/null | wc -l)
    echo "✅ ZEN Card secret.june exported (${HISTORY_COUNT} historical version(s))"
else
    echo "⚠️  ZEN Card secret.june not found (no transaction history to backup)"
fi

# Détection d'un CHANGEMENT d'UPlanet à la restauration : on ne consigne QUE l'empreinte de UPLANETNAME. Le nom lui-même
# est le secret de la constellation (clé du swarm IPFS privé) : le mettre dans une archive que le Capitaine d'UNE AUTRE
# constellation ouvrira le lui livrerait.
echo -n "${UPLANETNAME}" | sha256sum | cut -d' ' -f1 > "${BACKUP_DIR}/.uplanetname_sha256"
# Passerelle HTTP de CETTE station : si le compte part dans une autre constellation, son IPFS ne joindra jamais le
# nôtre — uDRIVE et ucloud se rapatrient par cette passerelle (nostr_RESTORE_TW.sh --gateway), tant que nous les gardons.
echo -n "${myIPFS}" > "${BACKUP_DIR}/.gateway"
# Formule de chaque clé du compte (nostr=… g1=… ipns=…) : une restauration à l'identique d'un compte
# historique doit retrouver le MÊME HEX (nostr_RESTORE_TW.sh la relit).
if [[ -s "${HOME}/.zen/game/nostr/${player}/.keyformula" ]]; then
    cp "${HOME}/.zen/game/nostr/${player}/.keyformula" "${BACKUP_DIR}/.keyformula"
else
    _kf="nostr=$(account_key_formula "${player}" nostr 2>/dev/null)"
    echo "${_kf}" > "${BACKUP_DIR}/.keyformula"
fi

# Copy ZEN Card .g1pub if it exists (for G1 wallet access)
ZEN_G1PUB="${HOME}/.zen/game/players/${player}/.g1pub"
if [[ -f "${ZEN_G1PUB}" ]]; then
    cp "${ZEN_G1PUB}" "${BACKUP_DIR}/.g1pub"
    echo "✅ ZEN Card .g1pub exported (G1 wallet access preserved)"
else
    echo "⚠️  ZEN Card .g1pub not found (no G1 wallet to backup)"
fi

# TiddlyWiki de la ZenCard (et la chaîne de ses versions, le flux, les historiques de paiements) : le CONTENU que la personne
# a écrit, sans aucune clé (UPassport/ucloud_backup.py zencard-export). PLAYER.unplug.sh, plus bas, supprime la ZenCard :
# c'est ICI ou jamais. Un export en échec ANNULE la destruction (rien n'est encore perdu) — sauf DESTROY_SKIP_ZENCARD=1,
# décision explicite de renoncer au contenu (ex. TiddlyWiki > 256 Mo à exporter à la main).
ZEN_PLAYER_DIR="${HOME}/.zen/game/players/${player}"
if [[ -d "${ZEN_PLAYER_DIR}" ]]; then
    ZC_OUT=""; ZC_RC=1
    if [[ -f "${UCLOUD_BACKUP_PY}" ]]; then
        ZC_OUT=$(python3 "${UCLOUD_BACKUP_PY}" zencard-export "${player}" "${BACKUP_DIR}"); ZC_RC=$?
    fi
    if [[ $ZC_RC -eq 0 ]]; then
        echo "✅ ZEN Card TiddlyWiki exporté : $(echo "${ZC_OUT}" | tail -n 1)"
    elif [[ "${DESTROY_SKIP_ZENCARD:-0}" == "1" ]]; then
        echo "⚠️  Contenu de la ZEN Card NON exporté (DESTROY_SKIP_ZENCARD=1) — il sera perdu" >&2
    else
        echo "❌ Export du contenu de la ZEN Card impossible — destruction annulée, rien n'a été perdu." >&2
        echo "   (DESTROY_SKIP_ZENCARD=1 pour y renoncer en connaissance de cause)" >&2
        rm -rf "${BACKUP_DIR}"
        exit 1
    fi
else
    echo "ℹ️  Pas de ZEN Card pour ${player} : aucun TiddlyWiki à sauvegarder"
fi

# Save next restoration info to backup directory (before ZIP creation)
if [[ -n "$NEXT_HEX" ]] && [[ -d "${BACKUP_DIR}" ]]; then
    echo "$NEW_DISCO" > "${BACKUP_DIR}/.next.disco"
    echo "$NEXT_HEX" > "${BACKUP_DIR}/.next.hex"
    echo "$NEW_SALT" > "${BACKUP_DIR}/.next.salt"
    echo "$NEW_PEPPER" > "${BACKUP_DIR}/.next.pepper"
    echo "✅ Next restoration credentials saved to backup"
fi

# Copy RESTORE_INSTRUCTIONS.sh
if [[ -f "${OUTPUT_DIR}/RESTORE_INSTRUCTIONS.sh" ]]; then
    cp "${OUTPUT_DIR}/RESTORE_INSTRUCTIONS.sh" "${BACKUP_DIR}/"
fi

# Copy README_BACKUP.txt
if [[ -f "${OUTPUT_DIR}/README_BACKUP.txt" ]]; then
    cp "${OUTPUT_DIR}/README_BACKUP.txt" "${BACKUP_DIR}/"
fi

# Save G1 balance for cashback restoration on new relay
echo "🔄 Recording G1 balance for cashback restoration..."
CASHBACK_AMOUNT=$(${MY_PATH}/../tools/G1check.sh ${g1pubnostr} --fresh 2>/dev/null | tail -n 1)
if [[ -z "${CASHBACK_AMOUNT}" ]] || [[ "${CASHBACK_AMOUNT}" == "null" ]]; then
    CASHBACK_AMOUNT="0"
fi
echo "${CASHBACK_AMOUNT}" > "${BACKUP_DIR}/.cashback_amount"
echo "${g1pubnostr}" > "${BACKUP_DIR}/.cashback_g1pub"
echo "✅ Cashback amount recorded: ${CASHBACK_AMOUNT} Ğ1"

# -----------------------------------------------------------------------------
# CREATE ARCHIVE : 7z AES-256, noms de fichiers chiffrés (-mhe=on)
# -----------------------------------------------------------------------------
# Le .pass n'est PAS utilisé : 4 chiffres (make_NOSTRCARD.sh) = 10 000 essais,
# cassable instantanément dès que le CID est connu. Un secret de 24 caractères
# tiré au hasard le remplace ; il n'est remis QUE dans l'email du joueur (jamais
# dans l'email du Capitaine, ni dans le profil NOSTR, ni dans le DID).
# Jamais d'archive en clair : sans 7z ou sans secret, on s'arrête AVANT toute
# destruction (le compte n'a encore rien perdu).
if ! command -v 7z >/dev/null 2>&1; then
    echo "❌ 7z introuvable (apt install p7zip-full) — aucune archive en clair n'est produite, destruction annulée" >&2
    exit 1
fi
BACKUP_SECRET=$(head -c 400 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 24)
if [[ ${#BACKUP_SECRET} -ne 24 ]]; then
    echo "❌ Génération du secret d'archive impossible — destruction annulée" >&2
    exit 1
fi

ZIP_FILE="${BACKUP_DIR}.7z"
echo "Creating archive: ${ZIP_FILE}"

cd "$(dirname "${BACKUP_DIR}")"
# 7z n'accepte le mot de passe qu'en argv (visible dans ps le temps de la commande)
if 7z a -t7z -mhe=on -mx=3 -p"${BACKUP_SECRET}" "${ZIP_FILE}" "$(basename "${BACKUP_DIR}")" >/dev/null; then
    echo "✅ Backup archive created successfully (AES-256)"
    cd - > /dev/null 2>&1

    # Add the encrypted archive directly to IPFS (no natools layer)
    echo "Adding backup to IPFS..."
    NOSTRIFS=$(ipfs add -q "${ZIP_FILE}" | tail -n 1)
    if [[ -n "${NOSTRIFS}" ]]; then
        ipfs pin rm ${NOSTRIFS} 2>/dev/null
        echo "✅ Backup added to IPFS: ${NOSTRIFS}"
        echo "   🔓 Extract: 7z x -p<SECRET> backup.7z (secret = email du joueur)"
    else
        echo "❌ Failed to add backup to IPFS — destruction annulée" >&2
        rm -f "${ZIP_FILE}"; rm -rf "${BACKUP_DIR}"
        exit 1
    fi

    # Clean up temporary files
    rm -f "${ZIP_FILE}"
    rm -rf "${BACKUP_DIR}"
else
    echo "❌ Failed to create backup archive" >&2
    cd - > /dev/null 2>&1
    rm -rf "${BACKUP_DIR}"
    exit 1
fi

echo "DELETING ${player} NOSTRCARD : $pubnostr"

## 0. UPDATE DID DOCUMENT - Mark as deactivated and include next HEX
echo "📝 Updating DID document to mark account as deactivated..."
if [[ -f "${MY_PATH}/did_manager_nostr.sh" ]]; then
    # Update DID to mark account as deactivated
    "${MY_PATH}/did_manager_nostr.sh" update "${player}" "ACCOUNT_DEACTIVATED" 0 0 2>/dev/null \
        && echo "✅ DID document updated - account marked as deactivated" \
        || echo "⚠️  Failed to update DID document (will continue with destruction)"
    
    # Add next HEX to DID metadata for restoration on new relay
    if [[ -n "$NEXT_HEX" ]]; then
        did_cache_file="${HOME}/.zen/game/nostr/${player}/did.json.cache"
        if [[ -f "$did_cache_file" ]] && command -v jq >/dev/null 2>&1; then
            # Add next restoration HEX to deactivation metadata
            jq ".metadata.deactivation.nextRestorationHex = \"${NEXT_HEX}\"" "$did_cache_file" > "${did_cache_file}.tmp" 2>/dev/null
            if [[ -s "${did_cache_file}.tmp" ]]; then
                mv "${did_cache_file}.tmp" "$did_cache_file"
                echo "   🔮 Next restoration HEX added to DID metadata: ${NEXT_HEX:0:20}..."
                
                # Republish DID with next HEX in metadata
                echo "   📡 Republishing DID with next HEX metadata..."
                "${MY_PATH}/did_manager_nostr.sh" sync "${player}" 2>/dev/null \
                    && echo "   ✅ DID republished with next HEX metadata" \
                    || echo "   ⚠️  Failed to republish DID (next HEX stored locally)"
            else
                rm -f "${did_cache_file}.tmp"
                echo "   ⚠️  Failed to add next HEX to DID metadata"
            fi
        else
            echo "   ⚠️  Cannot add next HEX to DID (file or jq not available)"
        fi
    fi
else
    echo "⚠️  did_manager_nostr.sh not found, skipping DID update"
fi

## 1. UPDATE NOSTR PROFILE - Mark as deactivated and include next HEX
echo "📝 Updating NOSTR profile to mark as deactivated..."
if [[ -f "${MY_PATH}/nostr_update_profile.py" ]]; then
    # Aucun lien vers la sauvegarde dans un profil PUBLIC : le CID n'est remis que
    # par email (joueur + Capitaine). Publié, il permettait de télécharger l'archive
    # et d'en attaquer le mot de passe hors ligne.
    if [[ -n "$NEXT_HEX" ]]; then
        ABOUT_MSG="Account deactivated | Next HEX: ${NEXT_HEX:0:16}..."
    else
        ABOUT_MSG="Account deactivated"
    fi

    "${MY_PATH}/nostr_update_profile.py" "${player}" "ws://127.0.0.1:7777" "wss://relay.copylaradio.com" \
        --about "${ABOUT_MSG}" \
        --name "[DEACTIVATED] ${youser}" 2>/dev/null \
        && echo "✅ NOSTR profile updated - marked as deactivated with next HEX" \
        || echo "⚠️  Failed to update NOSTR profile (will continue with destruction)"
else
    echo "⚠️  nostr_update_profile.py not found, skipping NOSTR profile update"
fi

## 1.5. DELETE ALL FOLLOWS (clear contact list)
echo "👥 Clearing follow list (kind 3)..."
# Create temp keyfile for nostr_send_note.py
TMP_KEYFILE=$(mktemp)
echo "NSEC=$secnostr;" > "$TMP_KEYFILE"

python3 $MY_PATH/nostr_send_note.py \
    --keyfile "$TMP_KEYFILE" \
    --kind 3 \
    --content "" \
    --tags "[]" \
    --relays "ws://127.0.0.1:7777" 2>/dev/null \
    && echo "✅ Follow list cleared (empty kind 3 published)" \
    || echo "⚠️  Failed to clear follow list (will continue with destruction)"

rm "$TMP_KEYFILE"

## 1.6. CAPTAIN UNFOLLOWS the destroyed MULTIPASS
# make_NOSTRCARD.sh fait suivre tout nouveau MULTIPASS par le Capitaine : le
# retirer ici, sinon sa liste kind 3 garde un follow vers une identité disparue.
# (ignoré si le MULTIPASS détruit est celui du Capitaine lui-même)
if [[ -n "${CAPTAINEMAIL:-}" && "$player" != "$CAPTAINEMAIL" && -s ~/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr ]]; then
    CAPTAINNSEC=$(grep -oP 'NSEC=\K[^;]+' ~/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr)
    if [[ -n "$CAPTAINNSEC" ]]; then
        echo "👥 CAPTAIN ${CAPTAINEMAIL} unfollowing ${player} (${hex})"
        NOSTR_NSEC="$CAPTAINNSEC" ${MY_PATH}/nostr_unfollow.sh - "$hex" "ws://127.0.0.1:7777" \
            && echo "✅ CAPTAIN no longer follows ${player}" \
            || echo "⚠️  Failed to remove CAPTAIN follow (will continue with destruction)"
        unset CAPTAINNSEC
    else
        echo "⚠️  CAPTAIN NSEC not found - follow not removed"
    fi
else
    echo "ℹ️  No CAPTAIN follow to remove (captain secret missing or player is captain)"
fi

## 2. CASH BACK
# resolve_player_dunikey (tools/my.sh) essaie PEPPER_UPLANET_SALT puis PEPPER
# seul, et ne garde que la formule qui reproduit g1pubnostr (le wallet
# réellement crédité) — sans ça, une dérivation avec la mauvaise formule
# produirait un dunikey pour un wallet vide, et le cashback échouerait
# silencieusement en laissant le vrai solde bloqué (cf. incident jpmgir@jpmgir.org).
DUNIKEY_MATCHED=false
if resolve_player_dunikey "${salt}" "${pepper}" "${g1pubnostr}" "$HOME/.zen/tmp/nostr.dunikey"; then
    DUNIKEY_MATCHED=true
else
    echo "⚠️  Impossible de reconstruire un dunikey correspondant à ${g1pubnostr} — cashback ignoré"
fi

# Get fresh balance from blockchain (not cache)
echo "🔄 Checking fresh G1 balance from blockchain..."
AMOUNT=$(${MY_PATH}/../tools/G1check.sh ${g1pubnostr} --fresh 2>/dev/null | tail -n 1)
if [[ -z "${AMOUNT}" ]] || [[ "${AMOUNT}" == "null" ]]; then
    AMOUNT="0"
fi

echo "💰 Current G1 balance: ${AMOUNT} Ğ1"

## EMPTY AMOUNT G1 to UPLANETNAME_G1 (central bank = source primale)
prime=${UPLANETNAME_G1}

# Convert amount to numeric for precise comparison using bc
AMOUNT_NUM=$(echo "${AMOUNT}" | sed 's/[^0-9.]//g')
CASHBACK_TRANSFERRED=false
if [[ "$DUNIKEY_MATCHED" == "true" ]] && [[ -n "${AMOUNT_NUM}" ]]; then
    # Use bc for precise numeric comparison
    if echo "${AMOUNT_NUM} > 0" | bc -l 2>/dev/null | grep -q "1"; then
        echo "💸 Transferring ${AMOUNT} Ğ1 to primal account: ${prime}"
        # AMOUNT vient de G1check.sh --fresh, qui retourne le total_balance brut
        # (cf. G1check.sh:117-118, convention ẐEN=(Ğ1-1)*10). PAYforSURE.sh compare
        # en interne au transferable_balance (total - 1 Ğ1 de dépôt existentiel) :
        # lui passer AMOUNT tel quel échoue systématiquement d'exactement 1 Ğ1
        # ("Solde insuffisant"). "ALL" lui fait recalculer et transférer son propre
        # solde transférable, sans ce décalage.
        if ${MY_PATH}/../tools/PAYforSURE.sh "${HOME}/.zen/tmp/nostr.dunikey" "ALL" "${prime}" "MULTIPASS:${youser}:PRIMAL:CASH-BACK" 2>/dev/null; then
            echo "✅ G1 balance transferred successfully"
            CASHBACK_TRANSFERRED=true
        else
            echo "⚠️  Failed to transfer G1 balance (will continue with destruction)"
        fi
    else
        echo "ℹ️  No G1 balance to transfer (${AMOUNT} Ğ1 - amount is zero or negative)"
    fi
else
    echo "ℹ️  No G1 balance to transfer (${AMOUNT} Ğ1)"
fi
rm -f ~/.zen/tmp/nostr.dunikey

# ── Texte de statut cashback pour les emails (montant en Ẑen, pas en Ğ1) ─────
# AMOUNT vient de G1check.sh --fresh = total_balance BRUT (cf. G1check.sh:117-118),
# incluant le 1 Ğ1 de dépôt existentiel non transférable. Depuis que PAYforSURE.sh
# est appelé en mode "ALL" (il recalcule et transfère son propre transferable_balance,
# cf. commentaire ci-dessus), le montant réellement mobilisé/mobilisable ne peut pas
# dépasser (AMOUNT - 1) — même formule que ZEN_BALANCE dans PAYforSURE.sh:324.
AMOUNT_ZEN_RAW=$(echo "scale=2; (${AMOUNT_NUM:-0} - 1) * 10" | bc -l)
[[ $(echo "${AMOUNT_ZEN_RAW} < 0" | bc -l 2>/dev/null) -eq 1 ]] && AMOUNT_ZEN_RAW="0"
AMOUNT_ZEN=$(makecoord "${AMOUNT_ZEN_RAW}")
[[ -z "$AMOUNT_ZEN" ]] && AMOUNT_ZEN="0.00"

if [[ "$DUNIKEY_MATCHED" != "true" ]]; then
    CASHBACK_TEXT_EN="Your remaining balance (<strong>${AMOUNT_ZEN} Ẑen</strong>) could NOT be cashed back automatically (signing key issue) — contact your Captain to recover it manually."
    CASHBACK_TEXT_FR="Votre solde restant (<strong>${AMOUNT_ZEN} Ẑen</strong>) n'a PAS pu être récupéré automatiquement (problème de clé de signature) — contactez votre Capitaine pour le récupérer manuellement."
elif [[ "$CASHBACK_TRANSFERRED" == "true" ]]; then
    CASHBACK_TEXT_EN="Your remaining balance of <strong>${AMOUNT_ZEN} Ẑen</strong> was cashed back to the UPlanet primal wallet. It will be restored automatically when you migrate or reactivate your account."
    CASHBACK_TEXT_FR="Votre solde restant de <strong>${AMOUNT_ZEN} Ẑen</strong> a été reversé au portefeuille primal UPlanet. Il vous sera restitué automatiquement lors de votre migration ou réactivation de compte."
elif echo "${AMOUNT_NUM:-0} > 0" | bc -l 2>/dev/null | grep -q "1"; then
    CASHBACK_TEXT_EN="Your remaining balance of <strong>${AMOUNT_ZEN} Ẑen</strong> could NOT be transferred (technical error) — it should still be on your wallet; contact your Captain."
    CASHBACK_TEXT_FR="Votre solde restant de <strong>${AMOUNT_ZEN} Ẑen</strong> n'a PAS pu être transféré (erreur technique) — il devrait toujours être sur votre portefeuille ; contactez votre Capitaine."
else
    CASHBACK_TEXT_EN="No Ẑen balance remained on this wallet at deactivation time."
    CASHBACK_TEXT_FR="Aucun solde Ẑen ne restait sur ce portefeuille au moment de la désactivation."
fi

## 2. REMOVE ZEN CARD (capital shares preserved in secret.june)
# Note: ZEN Card capital shares are archived in transaction history (secret.june)
# The ZEN Card wallet maintains minimum 1 G1 for capital shares management
# secret.june is preserved in backup - no need to empty remaining june
# The ZEN Card cannot be truly deleted as capital shares are in transaction history
if [[ -s "${HOME}/.zen/game/players/${player}/ipfs/moa/index.html" ]]; then
    echo "/PLAYER.unplug : TW + ZEN CARD (capital shares preserved in secret.june)"
    ${MY_PATH}/../RUNTIME/PLAYER.unplug.sh "${HOME}/.zen/game/players/${player}/ipfs/moa/index.html" "${player}" "ALL"
fi

## SEND EMAIL to CAPTAIN with backup information (SECURE - no sensitive data)
## (OC_URL_SATELLITE défini dans tools/my.sh)
EMAIL_TEMPLATE=$(cat "${MY_PATH}/../templates/NOSTR/wallet_deactivation.html" \
    | sed -e "s~_myIPFS_~${myIPFS}~g" \
          -e "s~_NOSTRIFS_~${NOSTRIFS}~g" \
          -e "s~_uSPOT_~${uSPOT}~g" \
          -e "s~_CORACLEURL_~${myCORACLE:-https://coracle.copylaradio.com}~g" \
          -e "s~_DEACTIVATION_DATE_~$(date '+%Y-%m-%d %H:%M:%S')~g" \
          -e "s~_OC_URL_SATELLITE_~${OC_URL_SATELLITE}~g" \
          -e "s~_REASON_TEXT_EN_~${REASON_TEXT_EN}~g" \
          -e "s~_REASON_TEXT_FR_~${REASON_TEXT_FR}~g" \
          -e "s~_CASHBACK_TEXT_EN_~${CASHBACK_TEXT_EN}~g" \
          -e "s~_CASHBACK_TEXT_FR_~${CASHBACK_TEXT_FR}~g")

# Send email to CAPTAIN (not to the user)
${MY_PATH}/../tools/mailjet.sh --template "${MY_PATH}/../templates/NOSTR/wallet_deactivation.html" --expire 3d \
    "${CAPTAINEMAIL}" \
    "${EMAIL_TEMPLATE}" \
    "CAPTAIN: ${youser} MULTIPASS Deactivated - Backup: ${NOSTRIFS}"

## SEND SIMPLIFIED EMAIL to the PLAYER too (no Captain-only technical instructions)
if [[ -s "${MY_PATH}/../templates/NOSTR/wallet_deactivation_player.html" ]]; then
    PLAYER_EMAIL_TEMPLATE=$(cat "${MY_PATH}/../templates/NOSTR/wallet_deactivation_player.html" \
        | sed -e "s~_myIPFS_~${myIPFS}~g" \
              -e "s~_NOSTRIFS_~${NOSTRIFS}~g" \
              -e "s~_DEST_~${player}~g" \
              -e "s~_BACKUP_SECRET_~${BACKUP_SECRET}~g" \
              -e "s~_uSPOT_~${uSPOT}~g" \
              -e "s~_DEACTIVATION_DATE_~$(date '+%Y-%m-%d %H:%M:%S')~g" \
              -e "s~_OC_URL_SATELLITE_~${OC_URL_SATELLITE}~g" \
              -e "s~_REASON_TEXT_EN_~${REASON_TEXT_EN}~g" \
              -e "s~_REASON_TEXT_FR_~${REASON_TEXT_FR}~g" \
              -e "s~_CASHBACK_TEXT_EN_~${CASHBACK_TEXT_EN}~g" \
              -e "s~_CASHBACK_TEXT_FR_~${CASHBACK_TEXT_FR}~g")

    ${MY_PATH}/../tools/mailjet.sh --template "${MY_PATH}/../templates/NOSTR/wallet_deactivation_player.html" --expire 3d \
        "${player}" \
        "${PLAYER_EMAIL_TEMPLATE}" \
        "💤 Votre MULTIPASS a été désactivé - Backup: ${NOSTRIFS}"
else
    echo "⚠️  wallet_deactivation_player.html not found, player not notified by email"
fi

# Remove OVH DNS Link
OVH_TOOL="${MY_PATH}/../admin/system/ovh.me.sh"
if [[ -x "$OVH_TOOL" ]]; then
    youser=$(${MY_PATH}/../tools/clyuseryomail.sh ${player})
    "$OVH_TOOL" delete "${youser}" 2>/dev/null || true
fi

unset BACKUP_SECRET PLAYER_EMAIL_TEMPLATE

## REMOVE NOSTR IPNS VAULT key
ipfs key rm "${g1pubnostr}:NOSTR" > /dev/null 2>&1

## Cleaning local cache
echo "🧹 Cleaning local cache and temporary files..."
if [[ -n "${g1pubnostr}" ]]; then
    rm -f ~/.zen/tmp/coucou/${g1pubnostr}.* 2>/dev/null
    echo "✅ Cleared G1 cache files for ${g1pubnostr}"
fi

if [[ -n "${player}" ]]; then
    rm -rf ~/.zen/game/nostr/${player} 2>/dev/null
    echo "✅ Removed NOSTR directory for ${player}"
fi

## Cleaning Node (& Swarm cache)
if [[ -n "${IPFSNODEID}" ]] && [[ -n "${player}" ]]; then
    rm -rf ~/.zen/tmp/${IPFSNODEID}/TW/${player} 2>/dev/null
    echo "✅ Cleared Node cache for ${player}"
fi

echo "✅ Account destruction completed successfully"

exit 0