#!/bin/bash
################################################################################
# Script: Make_NOSTRCARD.sh
# Description: Crée un MULTIPASS - Identité décentralisée universelle
#
# Un MULTIPASS est une identité NOSTR complète comprenant :
# - Une paire de clés NOSTR (secrète/publique)
# - Un portefeuille cryptographique multi-blockchain (Bitcoin, Monero, G1)
# - Un espace de stockage IPNS personnel (uDRIVE)
# - Des QR codes d'accès sécurisés (SSSS)
# - Une intégration avec le réseau social décentralisé NOSTR
# - Une identité Duniter/G1 compatible
# - Un document DID (Decentralized Identifier) W3C
#
# L'identité est créée à partir d'une adresse email et protégée par :
# - Un sel (salt) et un poivre (pepper) cryptographiques
# - Un schéma de partage de secret (SSSS) distribué en 3 parts (2 sur 3 requis)
# - Un chiffrement asymétrique avec les nœuds du réseau
#
# Fonctionnalités :
# - Génération de profils NOSTR avec métadonnées
# - Publication automatique sur les relais NOSTR
# - Création d'un espace de stockage IPNS persistant (uDRIVE)
# - Génération de QR codes sécurisés (MULTIPASS SSSS)
# - Intégration avec les systèmes UPlanet et G1
# - Document DID conforme W3C pour interopérabilité
#
# Système PASS Codes (utilisable sur n'importe quel terminal UPlanet) :
# - PASS "0000" : Régénération du MULTIPASS (perte, vol, oubli)
# - PASS "1111" : Ouverture de l'interface Astro Base complète (messenger)
# - Par défaut : Interface simple de message NOSTR
#
# Sécurité :
# - Aucune donnée sensible n'est stockée en clair
# - Utilisation de standards cryptographiques robustes (Ed25519, ECDSA)
# - Destruction des traces temporaires après exécution
# - Clé SSSS pour authentification mobile sans stockage navigateur
#
# Usage: Voir la fonction usage() pour les détails d'utilisation
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"

usage() {
  echo "Usage: Make_NOSTRCARD.sh [OPTIONS] <EMAIL> [IMAGE|PASS] [LATITUDE] [LONGITUDE] [SALT] [PEPPER]"
  echo ""
  echo "  Generates a MULTIPASS (universal decentralized identity) with cryptographic keys,"
  echo "  NOSTR profile, uDRIVE storage, and DID document."
  echo ""
  echo "Arguments:"
  echo "  <EMAIL>        Email address to associate with the MULTIPASS."
  echo "                 Must be a valid email format."
  echo "  [IMAGE|PASS]   Optional: Path to an image file to use as profile picture,"
  echo "                 a two-letter language code (e.g., 'en', 'fr'), or a 4-digit"
  echo "                 PASS code for special authentication modes."
  echo "                 If omitted, defaults to 'fr'."
  echo "  [LATITUDE]     Optional: UMAP Latitude for location data."
  echo "  [LONGITUDE]    Optional: UMAP Longitude for location data."
  echo "  [SALT]         Optional: Salt for key generation. If omitted, a random salt is generated."
  echo "  [PEPPER]       Optional: Pepper for key generation. If omitted, a random pepper is generated."
  echo ""
  echo "Options:"
  echo "  -h, --help    Display this help message and exit."
  echo ""
  echo "Example:"
  echo "  make_NOSTRCARD.sh john.doe@example.com ./profile.png 48.85 2.35"
  echo "  make_NOSTRCARD.sh jane.doe@example.com en"
  exit 1
}

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  usage
fi

if [[ "$#" -lt 1 ]]; then
  echo "Error: Missing EMAIL parameter."
  usage
fi

PARAM="$1"
EMAIL="${PARAM,,}" ## lowercase
EMAIL="${EMAIL// }" # Remove all spaces
IMAGE="$2"
ZLAT=$(makecoord "$3")
ZLON=$(makecoord "$4")
### Accept DISCO seed
SALT="$5"
PEPPER="$6"

YOUSER=$(${MY_PATH}/../tools/clyuseryomail.sh ${EMAIL})
echo "🎫 MULTIPASS Creation for $EMAIL"

########################################################################
## _alert_captain : envoie un email d'alerte 48h à CAPTAINEMAIL
## Usage : _alert_captain "SUJET" "DETAILS"
########################################################################
_alert_captain() {
    local _SUBJECT="${1:-ERREUR INCONNUE}"
    local _BODY="${2:-}"
    local _MAILJET="${MY_PATH}/../tools/mailjet.sh"
    local _MOATS_LOCAL=${MOATS:-$(date -u +"%Y%m%d%H%M%S")}
    echo "🚨 CAPTAIN ALERT: ${_SUBJECT}"
    [[ -z "$CAPTAINEMAIL" ]] && echo "⚠️  CAPTAINEMAIL non défini — alerte non envoyée" && return
    [[ ! -x "$_MAILJET" ]] && echo "⚠️  mailjet.sh introuvable — alerte non envoyée" && return
    local _TMPHTML=$(mktemp /tmp/alert_${_MOATS_LOCAL}.XXXXXX.html)
    cat > "$_TMPHTML" <<EOALERT
<html><body style="font-family:monospace">
<h2>🚨 MULTIPASS CREATION ERROR</h2>
<table>
<tr><td><b>EMAIL</b></td><td>${EMAIL:-???}</td></tr>
<tr><td><b>Station</b></td><td>${IPFSNODEID:-unknown}</td></tr>
<tr><td><b>Time</b></td><td>$(date -u)</td></tr>
<tr><td><b>Error</b></td><td>${_SUBJECT}</td></tr>
</table>
<pre style="background:#fee;padding:1em">${_BODY}</pre>
<p>→ Vérifiez le daemon IPFS et les logs de la station.</p>
</body></html>
EOALERT
    "$_MAILJET" --expire 172800 \
        "${CAPTAINEMAIL}" \
        "$_TMPHTML" \
        "🚨 MULTIPASS ERROR [${IPFSNODEID:0:8}]: ${_SUBJECT}" \
        >/dev/null 2>&1 &
    rm -f "$_TMPHTML"
    echo "📧 Alerte envoyée à ${CAPTAINEMAIL} (48h)"
}

[[ -z ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}/

if [[ $EMAIL =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then

    ############################################## CHECK DID ON NOSTR (email already activated on another station?)
    # UPlanet does not allow the same email on 2 stations of the same UPlanet ẐEN
    if [[ -f "${MY_PATH}/nostr_did_client.py" ]]; then
        if python3 "${MY_PATH}/nostr_did_client.py" check-email "$EMAIL" -q 2>/dev/null; then
            echo "❌ REFUSED: ${EMAIL} already has a DID on NOSTR (email already activated on this UPlanet ẐEN)."
            echo "   Use the existing MULTIPASS or another email."
            exit 1
        fi
    fi

    ############################################## PREPARE SALT PEPPER
    # ARCHITECTURE MULTIPASS v1→v2 — SÉPARATION DES CLÉS :
    #
    # • ZEN Card  : SALT/PEPPER fournis par l'utilisateur (mémorisable, déterministe)
    #               → crée le portefeuille G1 de la ZEN Card via VISA.new.sh
    #               → PAS de limite SSSS (ne va pas dans le DISCO)
    #               → transmis par GAFAM.html / keygen-v2.html sans troncature
    #
    # • MULTIPASS : SALT/PEPPER TOUJOURS ALÉATOIRES (non-devinable, sécurité Nostr)
    #               → crée identité Nostr + twin G1 + IPNS + BTC + XMR + SSSS
    #               → DISCO encode CES valeurs aléatoires (≤127 bytes pour SSSS)
    #               → référence /ipns/${NOSTRNS} inscrite dans le TW ZEN Card ($moa)
    #
    # QR CODE WEIGHT : _MAX_RANDOM=24 chars → DISCO=62 bytes → QR léger sur MULTIPASS
    _MAX_RANDOM=24   # MULTIPASS random SALT/PEPPER → lightweight DISCO QR code

    ## ZEN Card SALT/PEPPER = user-provided (mémorisable, aucune limite de taille)
    ZENCARD_SALT="${SALT:-}"
    ZENCARD_PEPPER="${PEPPER:-}"
    [[ -n "$ZENCARD_SALT" ]]   && echo "🎴 ZEN Card SALT reçu (${#ZENCARD_SALT} chars) → portefeuille G1 déterministe"
    [[ -n "$ZENCARD_PEPPER" ]] && echo "🎴 ZEN Card PEPPER reçu (${#ZENCARD_PEPPER} chars) → portefeuille G1 déterministe"

    ## MULTIPASS DISCO = TOUJOURS ALÉATOIRE (sécurité de l'identité Nostr)
    SALT=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w${_MAX_RANDOM} | head -n1)
    PEPPER=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w${_MAX_RANDOM} | head -n1)
    echo "🔐 MULTIPASS DISCO aléatoire : ${_MAX_RANDOM} chars each — non-devinable"

    # Creating MULTIPASS DISCO for ${EMAIL}
    DISCO="/?salt=${SALT}&nostr=${PEPPER}"
    #~ echo "DISCO (${#DISCO} bytes) : $DISCO"

    ## ssss-split : Keep 2 needed over 3 (default level, DISCO always ≤ 127 bytes)
    echo "$DISCO" | ssss-split -t 2 -n 3 -q > ~/.zen/tmp/${MOATS}/${EMAIL}.ssss
    HEAD=$(cat ~/.zen/tmp/${MOATS}/${EMAIL}.ssss | head -n 1) && echo "$HEAD" > ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.head
    MIDDLE=$(cat ~/.zen/tmp/${MOATS}/${EMAIL}.ssss | head -n 2 | tail -n 1) && echo "$MIDDLE" > ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.mid
    TAIL=$(cat ~/.zen/tmp/${MOATS}/${EMAIL}.ssss | tail -n 1) && echo "$TAIL" > ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.tail
    # echo "TEST DECODING..."
    (echo "$HEAD
    $TAIL" | ssss-combine -t 2 -q) > /dev/null
    if [ ! $? -eq 0 ]; then
        _alert_captain "SSSS KEY DECODING FAILED" \
            "ssss-split/ssss-combine a échoué pour ${EMAIL}\nDISCO: [masqué]\nVérifiez l'installation du paquet 'ssss'."
        echo "${MY_PATH}/../templates/wallet.html"
        exit 1
    fi

    # 1. Generate a DISCO Nostr key pair
    NPRIV=$(${MY_PATH}/../tools/keygen -t nostr "${SALT}" "${PEPPER}" -s)
    NPUBLIC=$(${MY_PATH}/../tools/keygen -t nostr "${SALT}" "${PEPPER}")
    HEX=$(${MY_PATH}/../tools/nostr2hex.py "$NPUBLIC")

    #~ echo "Nostr Private Key: $NPRIV"
    echo "Nostr Public Key: $NPUBLIC = $HEX"

    # 2. Store the keys in secure files (private keys in hidden files)
    echo "$NPRIV" > ~/.zen/tmp/${MOATS}/${EMAIL}.nostr.priv
    echo "$NPUBLIC" > ~/.zen/tmp/${MOATS}/${EMAIL}.nostr.pub
    
    # Store NSEC/NPUB/HEX in .secret.nostr (hidden from IPFS, used by did_manager_nostr.sh)
    mkdir -p ${HOME}/.zen/game/nostr/${EMAIL}/
    cat > ${HOME}/.zen/game/nostr/${EMAIL}/.secret.nostr <<EOFNOSTR
NSEC=$NPRIV; NPUB=$NPUBLIC; HEX=$HEX
EOFNOSTR
    chmod 600 ${HOME}/.zen/game/nostr/${EMAIL}/.secret.nostr

    # Create an G1CARD : G1Wallet waiting for G1 to make key batch running
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/${EMAIL}.multipass.dunikey "${SALT}" "${PEPPER}"
    G1PUBNOSTR=$(cat ~/.zen/tmp/${MOATS}/${EMAIL}.multipass.dunikey  | grep 'pub:' | cut -d ' ' -f 2)
    # echo "G1NOSTR _WALLET: $G1PUBNOSTR"

    # Conversion SS58 pour Duniter v2s (stockage persistant, cache, liens, gcli)
    # G1PUBNOSTR_V1 conservé UNIQUEMENT pour les API Cesium+/GChange+ (indexées en v1)
    # natools.py v1.3.2+ accepte nativement SS58 → normalize_pubkey() interne
    G1PUBNOSTR_V1="$G1PUBNOSTR"
    if [[ -x "${MY_PATH}/g1pub_to_ss58.py" ]]; then
        _g1nostr_ss58=$(python3 "${MY_PATH}/g1pub_to_ss58.py" "$G1PUBNOSTR" 2>/dev/null)
        [[ -n "$_g1nostr_ss58" ]] && G1PUBNOSTR="$_g1nostr_ss58"
    fi
    echo "MULTIPASS G1PUBNOSTR SS58 : $G1PUBNOSTR"
    echo "MULTIPASS G1PUBNOSTR  V1  : $G1PUBNOSTR_V1"

    ############ CREATE LOCAL USER SPACE
    mkdir -p ${HOME}/.zen/game/nostr/${EMAIL}/
    [[ -s ${IMAGE} ]] && cp ${IMAGE} ${HOME}/.zen/game/nostr/${EMAIL}/picture.png 2>/dev/null
    [[ "${IMAGE}" =~ ^[a-z]{2}$ ]] && LANG="${IMAGE}" || LANG="fr" ## Contains IMAGE or Navigator language

    ##########################################################################
    ## Public metadata (safe for IPFS publishing)
    echo "${LANG}" > ${HOME}/.zen/game/nostr/${EMAIL}/LANG ## COPY LANG
    echo "$HEX" > ${HOME}/.zen/game/nostr/${EMAIL}/HEX ## COPY HEX
    echo "$NPUBLIC" > ${HOME}/.zen/game/nostr/${EMAIL}/NPUB ## COPY NPUB
    ##########################################################################
    ## Create Bitcoin Twin Address
    BITCOIN=$(${MY_PATH}/../tools/keygen -t bitcoin "${SALT}" "${PEPPER}" | tail -n 1 | rev | cut -f 1 -d ' '  | rev)
    echo "$BITCOIN" > ${HOME}/.zen/game/nostr/${EMAIL}/BITCOIN
    ## Create Monero Twin Address
    MONERO=$(${MY_PATH}/../tools/keygen -t monero "${SALT}" "${PEPPER}" | tail -n 1 | rev | cut -f 1 -d ' '  | rev)
    echo "$MONERO" > ${HOME}/.zen/game/nostr/${EMAIL}/MONERO

    ### CRYPTO ZONE
    ## ENCODE HEAD SSSS SECRET WITH G1PUBNOSTR PUBKEY (natools v1.3.2+ accepte SS58)
    # echo "${MY_PATH}/../tools/natools.py encrypt -p $G1PUBNOSTR -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.head -o ${HOME}/.zen/game/nostr/${EMAIL}/.ssss.head.player.enc"
    ${MY_PATH}/../tools/natools.py encrypt -p "$G1PUBNOSTR" -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.head -o ${HOME}/.zen/game/nostr/${EMAIL}/.ssss.head.player.enc >/dev/null

    ## DISCO MIDDLE ENCRYPT WITH CAPTAING1PUB (or UPLANETG1PUB for first captain bootstrap)
    # When no captain exists yet, CAPTAING1PUB is empty; use UPLANETG1PUB (station Services wallet) so the first MULTIPASS can be created.
    MID_ENC_KEY="${CAPTAING1PUB:-$UPLANETG1PUB}"
    if [[ -z "$MID_ENC_KEY" ]]; then
        echo "❌ REFUSED: No CAPTAING1PUB and UPLANETG1PUB not set. Run UPLANET.init.sh first."
        exit 1
    fi
    ${MY_PATH}/../tools/natools.py encrypt -p "$MID_ENC_KEY" -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.mid -o ${HOME}/.zen/game/nostr/${EMAIL}/.ssss.mid.captain.enc >/dev/null

    ## DISCO TAIL ENCRYPT WITH UPLANETG1PUB
    # echo "${MY_PATH}/../tools/natools.py encrypt -p $UPLANETG1PUB -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.tail -o ${HOME}/.zen/game/nostr/${EMAIL}/ssss.tail.uplanet.enc"
    ${MY_PATH}/../tools/natools.py encrypt -p "$UPLANETG1PUB" -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.tail -o ${HOME}/.zen/game/nostr/${EMAIL}/ssss.tail.uplanet.enc >/dev/null

    ## CREATE IPNS KEY (SIDE STORAGE)
    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/${MOATS}.nostr.ipns "${SALT}" "${PEPPER}"
    ipfs key rm "${G1PUBNOSTR}:NOSTR" > /dev/null 2>&1
    NOSTRNS=$(ipfs key import "${G1PUBNOSTR}:NOSTR" -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/${MOATS}.nostr.ipns)
    echo "${G1PUBNOSTR}:NOSTR ${EMAIL} STORAGE: /ipns/$NOSTRNS"
    echo "/ipns/$NOSTRNS" > "${HOME}/.zen/game/nostr/${EMAIL}/NOSTRNS"

    ############################################## CREATE ZEN CARD (VISA)
    ## MULTIPASS est créé — maintenant on crée la ZEN Card avec les clés user
    ## La ZEN Card (VISA/astronaute) est dérivée des SALT/PEPPER mémorisables de l'utilisateur.
    ## Le MULTIPASS NPUBLIC/HEX lui est transmis pour lier les deux identités.
    ##
    ## TODO: Support mnemonic DUBP (keygen -t duniter -m "word1 word2 ... word12")
    ##   Si ZENCARD_SALT contient ≥12 mots (espaces) et ZENCARD_PEPPER vide → mode mnemonic
    ##   Nécessite adaptation de VISA.new.sh pour accepter un dunikey pré-calculé
    ##   Référence : keygen flag -m, duniterpy.key.SigningKey.from_dubp_mnemonic()
    ##   Avantage : ZEN Card compatible avec Silkaj/Cesium wallet mnemonic (BIP39 DUBP)
    if [[ -n "$ZENCARD_SALT" && -n "$ZENCARD_PEPPER" ]]; then
        echo "🎴 ## Creating ZEN Card (VISA) with user SALT/PEPPER..."
        ZENCARDG1_CHECK=$(cat ~/.zen/game/players/${EMAIL}/.g1pub 2>/dev/null)
        if [[ -z "$ZENCARDG1_CHECK" ]]; then
            echo "🔑 Calling VISA.new.sh to create ZEN Card (NPUB=${NPUBLIC:0:16}...)"
            ## Signature VISA.new.sh : PPASS NPASS PLAYER TYPE LANG LAT LON NPUB HEX
            NOMAIL=1 ${MY_PATH}/../RUNTIME/VISA.new.sh \
                "${ZENCARD_SALT}" "${ZENCARD_PEPPER}" \
                "${EMAIL}" "UPlanet" "${LANG:-fr}" "${ZLAT:-0.00}" "${ZLON:-0.00}" \
                "${NPUBLIC}" "${HEX}"
            [[ $? -eq 0 ]] \
                && echo "✅ ZEN Card created for ${EMAIL}" \
                || { _alert_captain "ZEN Card CREATION FAILED" \
                    "VISA.new.sh a échoué pour ${EMAIL}\nZENCAR_SALT=${ZENCARD_SALT:0:8}...\nNPUB=${NPUBLIC}"; \
                    echo "⚠️  ZEN Card creation failed (VISA.new.sh)"; }
        else
            echo "♻️  ZEN Card ${ZENCARDG1_CHECK} already exists — skip creation"
        fi
    else
        echo "ℹ️  Pas de ZENCARD_SALT/PEPPER → ZEN Card non créée (MULTIPASS standalone)"
    fi

    ## Create uSPOT/scan QR Code
    ## /ipfs/QmNd3abeAoUH1nGzwnaLNafRgtvwTSBCZyKqT8eBnEPQK9/u.scan.qr.png~/ipfs/$uSPOT_QR_ipfs
    amzqr "${uSPOT}/scan" -l H -p ${MY_PATH}/../templates/img/cloud_border.png \
        -c -n uSPOT.QR.png -d ~/.zen/game/nostr/${EMAIL}/ &>/dev/null

    uSPOT_QR_ipfs=$(ipfs --timeout 20s add -q ~/.zen/game/nostr/${EMAIL}/uSPOT.QR.png)


    ## QR CODE accès NOSTR VAULTNSQR
    amzqr "${myIPFS}/ipns/$NOSTRNS/${EMAIL}/APP/uDRIVE" -l H -p ${MY_PATH}/../templates/img/no_stripfs.png \
        -c -n IPNS.QR.png -d ~/.zen/game/nostr/${EMAIL}/ &>/dev/null

    VAULTNSQR=$(ipfs --timeout 20s add -q ~/.zen/game/nostr/${EMAIL}/IPNS.QR.png)
    ## CHECK IPFS IS WORKING GOOD (sometimes stuck)
    if [[ ! $? -eq 0 ]]; then
        _alert_captain "IPFS DAEMON ERROR — VAULTNSQR" \
            "ipfs add a échoué pour IPNS.QR.png (${EMAIL})\nLe daemon IPFS est peut-être bloqué ou surchargé.\nCommande : ipfs --timeout 20s add -q ~/.zen/game/nostr/${EMAIL}/IPNS.QR.png"
        cat ~/.zen/UPassport/templates/wallet.html \
        | sed -e "s~_WALLET_~$(date -u) <br> ${EMAIL}~g" \
             -e "s~_AMOUNT_~IPFS DAEMON ERROR~g" \
            > ${MY_PATH}/tmp/${MOATS}.out.html
        echo "${MY_PATH}/tmp/${MOATS}.out.html"
        exit 1
    fi
    #~ ipfs pin rm /ipfs/${VAULTNSQR} 2>/dev/null

    ## Make PLAYER "SSSS.head:NOSTRNS" QR CODE (Terminal Compatible) - "M-$SSSS_HEAD_B58"
    SSSS_HEAD=$(cat ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.head)
    SSSS_HEAD_B58=$(${MY_PATH}/Mbase58.py encode "${SSSS_HEAD}:${NOSTRNS}")
    echo "M-$SSSS_HEAD_B58" > ~/.zen/game/nostr/${EMAIL}/.ssss.player.key
    amzqr "M-$SSSS_HEAD_B58" -l H -p ${MY_PATH}/../templates/img/key.png \
        -c -n ._SSSSQR.png -d ~/.zen/game/nostr/${EMAIL}/ &>/dev/null

    SSSSQR=$(ipfs --timeout 20s add -q ~/.zen/game/nostr/${EMAIL}/._SSSSQR.png)
    # ipfs pin rm /ipfs/${SSSSQR} 2>/dev/null ## We can keep it

    ## Create G1PUBNOSTR QR Code
    ## Use webcam picture ?
    [[ -s ${HOME}/.zen/game/nostr/${EMAIL}/picture.png ]] \
        && FDQR=${HOME}/.zen/game/nostr/${EMAIL}/picture.png \
        || FDQR=${MY_PATH}/../templates/img/nature_cloud_face.png

    [[ $UPLANETNAME != "0000000000000000000000000000000000000000000000000000000000000000" ]] && Z=":ZEN" || Z="" ## Add :ZEN only for UPlanet ẐEN
    amzqr "${G1PUBNOSTR}${Z}" -l H -p "$FDQR" -c -n MULTIPASS.QR.o.png -d ~/.zen/game/nostr/${EMAIL}/ &>/dev/null

    ## Add white margins around the QR code image (for a flashable coracle profile picture)
    convert ~/.zen/game/nostr/${EMAIL}/MULTIPASS.QR.o.png -bordercolor white -border 90x90 ~/.zen/game/nostr/${EMAIL}/MULTIPASS.QR.png

    echo "${G1PUBNOSTR}" > ${HOME}/.zen/game/nostr/${EMAIL}/G1PUBNOSTR  ## SS58 (Duniter v2s)

    ## MOVE webcam picture
    mv ${HOME}/.zen/game/nostr/${EMAIL}/picture.png ${HOME}/.zen/game/nostr/${EMAIL}/scan_${MOATS}.png 2>/dev/null
    G1PUBNOSTRQR="$(ipfs --timeout 30s add -wq ${HOME}/.zen/game/nostr/${EMAIL}/MULTIPASS.QR.png | tail -n 1)/MULTIPASS.QR.png"
    # ipfs pin rm /ipfs/${G1PUBNOSTRQR}
    echo "${G1PUBNOSTRQR}" > ${HOME}/.zen/game/nostr/${EMAIL}/MULTIPASS.QR.png.cid

    ## Create NOSTR Profile Viewer QR Code
    amzqr "${myIPFS}/ipns/copylaradio.com/nostr_profile_viewer.html?hex=${HEX}" -l H -p ${MY_PATH}/../images/lamanostr.png \
        -c -n PROFILE.QR.png -d ~/.zen/game/nostr/${EMAIL}/ &>/dev/null

    PROFILEQR=$(ipfs --timeout 20s add -q ~/.zen/game/nostr/${EMAIL}/PROFILE.QR.png)
    # ipfs pin rm /ipfs/${PROFILEQR} 2>/dev/null

    ### PREPARE MULTIPASS PRINT CARD (uSPOT + SSSS QR codes)
    ${MY_PATH}/MULTIPASS.print.sh "${EMAIL}" &
    MULTIPASS_PRINT_PID=$!

    ## TODATE TIME STAMP
    echo "${TODATE}" > ${HOME}/.zen/game/nostr/${EMAIL}/TODATE
    ## ZLAT ZLON
    echo "_${ZLAT}_${ZLON}" > ${HOME}/.zen/game/nostr/${EMAIL}/ZUMAP # RUNTIME/NOSTR.UMAP.refresh.sh
    echo "LAT=${ZLAT}; LON=${ZLON};" > ${HOME}/.zen/game/nostr/${EMAIL}/GPS # IA/UPlanet_IA_Responder.sh

    ## Initialize station GPS if not set (first MULTIPASS becomes CAPTAIN GPS)
    if [[ ! -s ~/.zen/GPS ]]; then
        echo "LAT=${ZLAT}; LON=${ZLON}" > ~/.zen/GPS
        echo "📍 Station GPS initialized: LAT=${ZLAT}, LON=${ZLON}"
    fi

    ## Create a .secret.disco file with the DISCO seed (needed for UPlanet Captain) -
    # for Captain use # HARDER SECURITY # use encrypted RAM fs cycled every 20h12
    echo "$DISCO" > "${HOME}/.zen/game/nostr/${EMAIL}/.secret.disco"
    chmod 600 ${HOME}/.zen/game/nostr/${EMAIL}/.secret.disco

    ## Create initial DID document using did_manager_nostr.sh
    echo "📝 Creating initial DID document using did_manager_nostr.sh..."
    
    if [[ -f "${MY_PATH}/did_manager_nostr.sh" ]]; then
        # Set environment variables that did_manager_nostr.sh needs
        export IPFSNODEID="${IPFSNODEID:-}"
        
        # Check if DID already exists
        did_exists=false
        if [[ -f "${HOME}/.zen/game/nostr/${EMAIL}/did.json.cache" ]]; then
            echo "⚠️  DID already exists for ${EMAIL}, will update instead of creating new"
            did_exists=true
        fi
        
        # Create or update DID using did_manager_nostr.sh with MULTIPASS type (0 amount)
        if [[ "$did_exists" == "true" ]]; then
            echo "🔧 Updating existing DID with did_manager_nostr.sh..."
        else
            echo "🔧 Creating new DID with did_manager_nostr.sh..."
        fi
        
        if ${MY_PATH}/did_manager_nostr.sh update "${EMAIL}" "MULTIPASS" "0" "0"; then
            echo "✅ Initial DID document created by did_manager_nostr.sh with full UPlanet template"
        else
            _alert_captain "DID CREATION FAILED" \
                "did_manager_nostr.sh update a échoué pour ${EMAIL}\nHEX: ${HEX}\nNPUB: ${NPUBLIC}"
            echo "❌ Failed to create DID document using did_manager_nostr.sh"
            exit 1
        fi
    else
        _alert_captain "did_manager_nostr.sh INTROUVABLE" \
            "Script manquant: ${MY_PATH}/did_manager_nostr.sh\nInstallation Astroport.ONE incomplète ?"
        echo "❌ did_manager_nostr.sh not found at ${MY_PATH}/did_manager_nostr.sh"
        exit 1
    fi

    ## Create .well-known/index.hmlt filled with did.json for standard DID resolution (W3C compliant)
    echo "📁 Creating .well-known endpoint for DID resolution..."
    mkdir -p ${HOME}/.zen/game/nostr/${EMAIL}/APP/uDRIVE/Apps/.well-known
    
    # Create .well-known directory and inject IPFS URL into HTML viewer
    if [[ -f ${HOME}/.zen/game/nostr/${EMAIL}/did.json.cache ]]; then
        # Copy DID viewer template
        cp "${HOME}/.zen/Astroport.ONE/templates/NOSTR/did_viewer.html" ${HOME}/.zen/game/nostr/${EMAIL}/APP/uDRIVE/Apps/.well-known/index.html
        
        # Use IPFS direct link instead of embedding JSON
        # Add did.json.cache to IPFS to get its specific CID
        echo "📡 Adding did.json.cache to IPFS..."
        did_ipfs_cid=$(ipfs --timeout 30s add -q ${HOME}/.zen/game/nostr/${EMAIL}/did.json.cache)
        
        if [[ -n "$did_ipfs_cid" ]]; then
            # Replace the placeholder with IPFS direct link
            ipfs_url="/ipfs/${did_ipfs_cid}"
            sed -i "s|const _DID_JSON_URL_ = null;|const _DID_JSON_URL_ = '${ipfs_url}';|g" ${HOME}/.zen/game/nostr/${EMAIL}/APP/uDRIVE/Apps/.well-known/index.html
            echo -e "${GREEN}✅ Using IPFS CID for did.json.cache: ${did_ipfs_cid}${NC}"
        else
            echo -e "${YELLOW}⚠️  Failed to add did.json.cache to IPFS, using fallback method${NC}" >&2
            # Keep the original null value
        fi
        
        # Ensure did.json.cache is available in the IPFS directory
        echo -e "${GREEN}✅ DID cache file is ready for IPFS access${NC}"
        
        echo "✅ DID viewer created with IPFS link: ${myIPFS}/ipns/${NOSTRNS}/${EMAIL}/APP/uDRIVE/Apps/.well-known/index.html"
    else
        _alert_captain "DID CACHE INTROUVABLE" \
            "did.json.cache absent après création pour ${EMAIL}\nFichier attendu: ${HOME}/.zen/game/nostr/${EMAIL}/did.json.cache\nVérifiez did_manager_nostr.sh"
        echo "❌ DID cache not found after creation, cannot create .well-known endpoint"
        exit 1
    fi

    ##############################################################
    [[ "$Z" == ":ZEN" ]] && ZenECO="(1Ẑ = 1€)" || ZenECO="(1Ẑ = 0.1Ğ1)"
    ### PREPARE NOSTR ZINE
    if [[ ! -f "${MY_PATH}/../templates/NOSTR/zine/nostr.html" ]]; then
        echo "❌ Error: NOSTR zine template not found at ${MY_PATH}/../templates/NOSTR/zine/nostr.html"
        exit 1
    fi
    
    cat ${MY_PATH}/../templates/NOSTR/zine/nostr.html \
    | sed -e "s~npub1w25fyk90kknw499ku6q9j77sfx3888eyfr20kq2rj7f5gnm8qrfqd6uqu8~${NPUBLIC}~g" \
            -e "s~nsec13x0643lc3al5fk92auurh7ww0993syj566eh7ta8r2jpkprs44rs33cute~${NPRIV}~g" \
            -e "s~toto@yopmail.com~${EMAIL}~g" \
            -e "s~_YOUSER_~${YOUSER}~g" \
            -e "s~QmdmeZhD8ncBFptmD5VSJoszmu41edtT265Xq3HVh8PhZP~${SSSSQR}~g" \
            -e "s~Qma4ceUiYD2bAydL174qCSrsnQRoDC3p5WgRGKo9tEgRqH~${G1PUBNOSTRQR}~g" \
            -e "s~Qmeu1LHnTTHNB9vex5oUwu3VVbc7uQZxMb8bYXuX56YAx2~${VAULTNSQR}~g" \
            -e "s~/ipfs/QmNd3abeAoUH1nGzwnaLNafRgtvwTSBCZyKqT8eBnEPQK9/u.scan.qr.png~/ipfs/${uSPOT_QR_ipfs}~g" \
            -e "s~QmPV9NfaeYfZzYPaQGs9BZvMBY2t3n2SC8jodSH4zsWZak~${PROFILEQR}~g" \
            -e "s~_UPLANETNAME_G1_~${UPLANETNAME_G1}~g" \
            -e "s~_NSECTAIL_~${NPRIV: -33}~g" \
            -e "s~_LAT_~${ZLAT}~g" \
            -e "s~_LON_~${ZLON}~g" \
            -e "s~_UMAP_~_${ZLAT}_${ZLON}~g" \
            -e "s~_NOSTRVAULT_~/ipns/${NOSTRNS}~g" \
            -e "s~_WALLET_~${ZenECO}~g" \
            -e "s~_SALT_~${SALT}~g" \
            -e "s~_PEPPER_~${PEPPER}~g" \
            -e "s~_MYRELAY_~${myRELAY}~g" \
            -e "s~_uSPOT_~${uSPOT}~g" \
            -e "s~_CAPTAINEMAIL_~${CAPTAINEMAIL}~g" \
            -e "s~_G1PUBNOSTR_~${G1PUBNOSTR}~g" \
            -e "s~_UPLANET8_~UPlanet:${UPLANETG1PUB:0:8}~g" \
            -e "s~_HEX_~${HEX}~g" \
            -e "s~_DATE_~$(date -u)~g" \
            -e "s~http://127.0.0.1:8080~${myIPFS}~g" \
            -e "s~_CORACLEURL_~${myCORACLE:-https://ipfs.copylaradio.com/ipns/coracle.copylaradio.com}~g" \
        > ${HOME}/.zen/game/nostr/${EMAIL}/.nostr.zine.html

    if [[ "$Z" == ":ZEN" ]]; then
        ## Replace Cesium Access with uSPOT/check_balance?g1pub=email (html output)
        # Escape special characters in URLs for sed
        sed -i "s~${myIPFS}/ipfs/QmTnSdXe5nuAyYKWikU9vtRA84EDhwWc3michnevFFpR3g/#/wot/${G1PUBNOSTR}/~${uSPOT}/check_balance?g1pub=${EMAIL}~g" \
            "${HOME}/.zen/game/nostr/${EMAIL}/.nostr.zine.html"

    fi

    ### MULTIPASS FOLLOWS CAPTAIN AUTOMATICALLY
    # New MULTIPASS should follow the CAPTAIN to receive updates and guidance
    # Only if CAPTAIN exists (not first user)
    if [[ -n "$CAPTAINEMAIL" ]] && [[ "$CAPTAINEMAIL" != "$EMAIL" ]]; then
        if [[ -s ~/.zen/game/nostr/${CAPTAINEMAIL}/HEX ]]; then
            CAPTAINHEX=$(cat ~/.zen/game/nostr/${CAPTAINEMAIL}/HEX)
            echo "👥 MULTIPASS ${EMAIL} following CAPTAIN ${CAPTAINEMAIL} (${CAPTAINHEX})"
            ${MY_PATH}/../tools/nostr_follow.sh "$NPRIV" "$CAPTAINHEX" "$myRELAY" 2>/dev/null \
                && echo "✅ MULTIPASS now follows CAPTAIN" \
                || echo "⚠️  Failed to follow CAPTAIN (will retry later)"
        else
            echo "⚠️  CAPTAIN HEX not found at ~/.zen/game/nostr/${CAPTAINEMAIL}/HEX"
        fi

        ### CAPTAIN FOLLOWS NEW MULTIPASS AUTOMATICALLY
        # CAPTAIN should follow the new MULTIPASS to monitor and provide support
        if [[ -s ~/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr ]]; then
            # Extract NSEC value (between "NSEC=" and ";") from format: NSEC=nsec1...; NPUB=...
            CAPTAINNSEC=$(grep -oP 'NSEC=\K[^;]+' ~/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr)
            if [[ -n "$CAPTAINNSEC" ]]; then
                echo "👥 CAPTAIN ${CAPTAINEMAIL} following new MULTIPASS ${EMAIL} (${HEX})"
                ${MY_PATH}/../tools/nostr_follow.sh "$CAPTAINNSEC" "$HEX" "$myRELAY" 2>/dev/null \
                    && echo "✅ CAPTAIN now follows new MULTIPASS" \
                    || echo "⚠️  Failed to follow new MULTIPASS (will retry later)"
            else
                echo "⚠️  CAPTAIN NSEC not found in ~/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr"
            fi
        else
            echo "⚠️  CAPTAIN secret file not found at ~/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr"
        fi
    else
        # First user - no captain yet
        echo "ℹ️  First MULTIPASS created - no CAPTAIN to follow yet"
    fi

    ### SEND NOSTR MESSAGE WITH QR CODE LINK
    # DID is accessible via Nostr (source of truth) and IPFS/.well-known (cache)
    Mymessage="🎉 ẐEN wallet : ${G1PUBNOSTR}${Z}

𝄃𝄃𝄂𝄂𝄀𝄁𝄃𝄂𝄂𝄃 ${myIPFS}/ipfs/${G1PUBNOSTRQR}

🆔 DID: did:nostr:${HEX}
"

    # Prepare tags for the NOSTR message
    NOSTR_TAGS="[[\"p\",\"${HEX}\"],[\"i\",\"did:nostr:${HEX}\"]]"
    
    # Determine which relays to use
    if [[ "$myRELAY" != "wss://relay.copylaradio.com" ]]; then
        # Send to both relays for redundancy
        RELAY_LIST="${myRELAY},wss://relay.copylaradio.com"
        echo "📡 Publishing NOSTR message to ${myRELAY} and public relay (expires in 48h)"
    else
        # Send only to the configured relay (already the public one)
        RELAY_LIST="$myRELAY"
        echo "📡 Publishing NOSTR message to public relay (expires in 48h)"
    fi
    
    # Send message using nostr_send_note.py with keyfile
    ${MY_PATH}/../tools/nostr_send_note.py \
        --keyfile "${HOME}/.zen/game/nostr/${EMAIL}/.secret.nostr" \
        --content "$Mymessage" \
        --kind 1 \
        --tags "$NOSTR_TAGS" \
        --ephemeral 172800 \
        --relays "$RELAY_LIST" &>/dev/null \
        && echo "✅ NOSTR message published successfully" \
        || echo "⚠️  Failed to publish NOSTR message"


    ###############################################################################################
    ### Add /APP/uDRIVE
    #~ Réception : Quand un fichier .zip est téléversé via l'API (UPassport/54321.py),
    #~ il est immédiatement identifié et spécifiquement dirigé vers le répertoire uDRIVE/Apps/
    #~ Application dans un dossier : Apps/MonApp/index.html avec son icône Apps/MonApp/icon.png.
    #~ Application "flat" : Apps/index.MonApp.html avec son icône Apps/MonApp.png.
    mkdir -p ${HOME}/.zen/game/nostr/${EMAIL}/APP/uDRIVE/Apps/Cesium.v1
    echo '<meta http-equiv="refresh" content="0;url='${CESIUMIPFS}/#/wot/${G1PUBNOSTR}/'">' \
        > ${HOME}/.zen/game/nostr/${EMAIL}/APP/uDRIVE/Apps/Cesium.v1/index.html
    cp ${MY_PATH}/../images/cesium.png ${HOME}/.zen/game/nostr/${EMAIL}/APP/uDRIVE/Apps/Cesium.v1/icon.png
    ## Add you App !

    # README.${YOUSER}.md
    mkdir -p ${HOME}/.zen/game/nostr/${EMAIL}/APP/uDRIVE/Documents
    cat "${HOME}/.zen/workspace/UPlanet/UPlanet_Enter_Help.md" \
        > "${HOME}/.zen/game/nostr/${EMAIL}/APP/uDRIVE/Documents/README.${YOUSER}.md"


    ## Link generate_ipfs_structure.sh to uDRIVE
    cd ${HOME}/.zen/game/nostr/${EMAIL}/APP/uDRIVE/

    ln -s ${HOME}/.zen/Astroport.ONE/tools/generate_ipfs_structure.sh ./generate_ipfs_structure.sh
    ## RUN App
    UDRIVE=$(./generate_ipfs_structure.sh . 2>/dev/null)
    echo "<html><head><meta http-equiv=\"refresh\" content=\"0; url=/ipfs/$UDRIVE\"></head></html>" > index.html

    ###############################################################################################
    #~ ## Link generate_ipfs_RPG.sh to uWORLD --- ANOTHER DEMO APP
    #~ mkdir -p ${HOME}/.zen/game/nostr/${EMAIL}/APP/uWORLD/
    #~ cd -
    #~ cd ${HOME}/.zen/game/nostr/${EMAIL}/APP/uWORLD
    #~ ln -s ${HOME}/.zen/Astroport.ONE/tools/generate_ipfs_RPG.sh ./generate_ipfs_RPG.sh
    #~ ## RUN App
    #~ UWORLD=$(./generate_ipfs_RPG.sh . 2>/dev/null)
    #~ echo "<html><head><meta http-equiv=\"refresh\" content=\"0; url=/ipfs/$UWORLD\"></head></html>" > index.html
    #~ cd -
    ###############################################################################################
    ## ORIGIN or ẐEN's
    [[ ${UPLANETG1PUB:0:8} == "4ZqazktD" ]] && ORIGIN="ORIGIN" || ORIGIN="${UPLANETG1PUB:0:8}"
    ZENCARDG1=$(cat ~/.zen/game/players/${EMAIL}/.g1pub 2>/dev/null) ## Does ZenCard already existing

    ### IMPORT CESIUM+ / GCHANGE+ PROFILE (if exists) for NOSTR profile enrichment
    ## DEPRECATED: This section imports legacy Ğ1v1 profiles from Cesium+/GChange+ Elasticsearch.
    ## It will be removed after migration of simple Ğ1v1 wallets to UPlanet ORIGIN.
    ## When Duniter v2s is fully adopted, profiles will come from NOSTR (kind 0) only.
    CESIUM_NAME=""
    CESIUM_ABOUT=""
    CESIUM_AVATAR_CID=""
    CESIUM_CITY=""
    PROFILE_SOURCE=""

    ## 1. Try Cesium+ first (API v1 — clé base58 v1 obligatoire)
    CESIUM_JSON=$(curl -s --max-time 5 "${myCESIUM}/user/profile/${G1PUBNOSTR_V1}" 2>/dev/null)
    if [[ -n "$CESIUM_JSON" ]] && echo "$CESIUM_JSON" | jq -e '.found == true' &>/dev/null; then
        PROFILE_SOURCE="Cesium+"
    else
        ## 2. Fallback: try GChange+
        CESIUM_JSON=$(curl -s --max-time 5 "${myDATA}/user/profile/${G1PUBNOSTR_V1}" 2>/dev/null)
        if [[ -n "$CESIUM_JSON" ]] && echo "$CESIUM_JSON" | jq -e '.found == true' &>/dev/null; then
            PROFILE_SOURCE="GChange+"
            ## GChange+ may link to a different Cesium+ member pubkey
            GCHANGE_LINKED=$(echo "$CESIUM_JSON" | jq -r '._source.pubkey // empty' 2>/dev/null)
            if [[ -n "$GCHANGE_LINKED" && "$GCHANGE_LINKED" != "null" && "$GCHANGE_LINKED" != "$G1PUBNOSTR" ]]; then
                echo "   GChange+ linked to member: ${GCHANGE_LINKED}"
                ## Try to get richer profile from linked Cesium+ member
                LINKED_JSON=$(curl -s --max-time 5 "${myCESIUM}/user/profile/${GCHANGE_LINKED}" 2>/dev/null)
                if [[ -n "$LINKED_JSON" ]] && echo "$LINKED_JSON" | jq -e '.found == true' &>/dev/null; then
                    CESIUM_JSON="$LINKED_JSON"
                    PROFILE_SOURCE="Cesium+ (via GChange+ link)"
                fi
            fi
        fi
    fi

    ## Extract profile data if found
    if [[ -n "$PROFILE_SOURCE" ]]; then
        echo "✅ ${PROFILE_SOURCE} profile found for ${G1PUBNOSTR}"
        CESIUM_NAME=$(echo "$CESIUM_JSON" | jq -r '._source.title // empty' 2>/dev/null)
        CESIUM_ABOUT=$(echo "$CESIUM_JSON" | jq -r '._source.description // empty' 2>/dev/null)
        CESIUM_CITY=$(echo "$CESIUM_JSON" | jq -r '._source.city // empty' 2>/dev/null)
        ## Extract and publish avatar to IPFS if present
        CESIUM_AVATAR_B64=$(echo "$CESIUM_JSON" | jq -r '._source.avatar._content // empty' 2>/dev/null)
        if [[ -n "$CESIUM_AVATAR_B64" ]]; then
            echo "$CESIUM_AVATAR_B64" | base64 -d > ~/.zen/tmp/${MOATS}/cesium_avatar.png 2>/dev/null
            if [[ -s ~/.zen/tmp/${MOATS}/cesium_avatar.png ]] && file -b ~/.zen/tmp/${MOATS}/cesium_avatar.png | grep -qi "image"; then
                CESIUM_AVATAR_CID=$(ipfs --timeout 20s add -q ~/.zen/tmp/${MOATS}/cesium_avatar.png 2>/dev/null)
                echo "   Avatar ${PROFILE_SOURCE} → IPFS: ${CESIUM_AVATAR_CID}"
            fi
            rm -f ~/.zen/tmp/${MOATS}/cesium_avatar.png
        fi
    fi

    ## Build profile name and about (Cesium+ overrides defaults if available)
    PROFILE_NAME="${CESIUM_NAME:-[•͡˘㇁•͡˘] $YOUSER}"
    PROFILE_ABOUT="${CESIUM_ABOUT:-⏰ UPlanet Ẑen ${ORIGIN} // Welcome // ${myIPFS}/ipns/copylaradio.com // DID: did:nostr:${HEX}}"
    PROFILE_AVATAR="$myIPFS/ipfs/${G1PUBNOSTRQR}"
    [[ -n "$CESIUM_AVATAR_CID" ]] && PROFILE_AVATAR="$myIPFS/ipfs/${CESIUM_AVATAR_CID}"

    ### CREATE PROFILE in NOSTR RELAYS
    ## Derive SS58 v2 address from G1 v1 pubkey (G1PUBNOSTR_V1 = base58 v1 requis ici)
    G1V2ADDRESS=$(python3 "${MY_PATH}/g1pub_to_ss58.py" "$G1PUBNOSTR_V1" 2>/dev/null)
    [[ -z "$G1V2ADDRESS" ]] && G1V2ADDRESS="$G1PUBNOSTR"  # déjà SS58 si conversion préalable OK

    SETUP_ARGS=(
        "$NPRIV"
        "$PROFILE_NAME" "${G1PUBNOSTR}"
        "$PROFILE_ABOUT"
        "$PROFILE_AVATAR"
        "$myIPFS/ipfs/QmSMQCQDtcjzsNBec1EHLE78Q1S8UXGfjXmjt8P6o9B8UY/ComfyUI_00841_.jpg"
        "" "$myIPFS/ipns/${NOSTRNS}/${EMAIL}/APP/uDRIVE" "" "" "" ""
        "wss://relay.copylaradio.com" "$myRELAY"
        --g1v2 "$G1V2ADDRESS"
        --zencard "$ZENCARDG1"
        --email "$EMAIL"
        --ipns_vault "/ipns/${NOSTRNS}"
    )
    [[ -n "$CESIUM_CITY" ]] && SETUP_ARGS+=(--city "$CESIUM_CITY")

    ${MY_PATH}/../tools/nostr_setup_profile.py "${SETUP_ARGS[@]}" &>/dev/null \
        && echo "✅ Nostr Kind 0 profile published" \
        || { _alert_captain "nostr_setup_profile.py FAILED" \
            "Échec publication profil Nostr Kind 0 pour ${EMAIL}\nNPUB: ${NPUBLIC}\nRelay: ${myRELAY}\nVérifiez la connexion relay et pynostr."; \
            echo "⚠️  Nostr profile publication failed (non-fatal, will retry at next refresh)"; }

    ## CHECK DESTINATION WALLET NOT ALREADY CREDITED
    ## Note: ne bloque plus la création — la primo TX est maintenant différée et envoyée
    ## par UPLANET.official.sh (ensure_wallet_initialized) lors du premier virement réel.
    DEST_BALANCE=""
    if [[ -f "${MY_PATH}/G1check.sh" ]] && [[ -n "$G1PUBNOSTR" ]]; then
        DEST_BALANCE=$("${MY_PATH}/G1check.sh" "$G1PUBNOSTR" 2>/dev/null | tr -d '[:space:]')
    fi
    if [[ -n "$DEST_BALANCE" ]] && [[ "$DEST_BALANCE" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        if (( $(echo "${DEST_BALANCE} > 0" | bc -l 2>/dev/null || echo 0) )); then
            echo "ℹ️  Wallet ${G1PUBNOSTR} has existing balance ${DEST_BALANCE} Ğ1 (already initialized)."
            echo "${UPLANETNAME_G1}" > ~/.zen/game/nostr/${EMAIL}/G1PRIME 2>/dev/null
            echo "${UPLANETNAME_G1}" > ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal 2>/dev/null
        fi
    fi

    ## PRIMO TX DIFFÉRÉE — désactivée à la création
    ## La primo TX (1 Ğ1) sera envoyée par UPLANET.official.sh via ensure_wallet_initialized()
    ## uniquement lorsque des ẐEN réels sont reçus (via OC2UPlanet ou virement officiel).
    ## Cela évite de perdre des Ğ1 pour des MULTIPASS jamais activés (Duniter v2 bloqué ou wallet abandonné).
    ##
    ## Pour forcer l'initialisation manuelle :
    ##   ~/.zen/Astroport.ONE/UPLANET.official.sh -l ${EMAIL} -m 1
    echo "ℹ️  PRIMO TX différée — sera envoyée lors du premier virement ẐEN réel (UPLANET.official.sh)"

    ### IPNS PUBLICATION
    # Note: IPNS publication is handled by generate_ipfs_structure.sh (line 462)
    # The .well-known directory is created earlier (line 294) and will be included automatically
    # No need to publish here - generate_ipfs_structure.sh will update the IPNS with the complete structure


    ## Wait for MULTIPASS card to be generated (if still in background)
    if [[ -n "$MULTIPASS_PRINT_PID" ]]; then
        wait $MULTIPASS_PRINT_PID 2>/dev/null || true
        echo "✅ MULTIPASS card generation completed"
    fi
    
    ## Add MULTIPASS card to IPFS if it exists
    MULTIPASS_CARD_IPFS=""
    if [[ -f "${HOME}/.zen/game/nostr/${EMAIL}/.MULTIPASS.CARD.png" ]]; then
        echo "📤 Adding MULTIPASS card to IPFS..."
        MULTIPASS_CARD_IPFS=$(ipfs --timeout 30s add -q "${HOME}/.zen/game/nostr/${EMAIL}/.MULTIPASS.CARD.png" 2>/dev/null)
        if [[ -n "$MULTIPASS_CARD_IPFS" ]]; then
            echo "✅ MULTIPASS card added to IPFS: ${MULTIPASS_CARD_IPFS}"
        else
            echo "⚠️ Failed to add MULTIPASS card to IPFS"
        fi
    else
        echo "⚠️ MULTIPASS card not found: ${HOME}/.zen/game/nostr/${EMAIL}/.MULTIPASS.CARD.png"
    fi

    ## IPNS PUBLICATION - Publish entire ~/.zen/game/nostr/${EMAIL}/ directory to IPNS
    if [[ -n "$G1PUBNOSTR" ]] && [[ -d "${HOME}/.zen/game/nostr/${EMAIL}" ]]; then
        echo "📡 Publishing MULTIPASS directory to IPNS (${G1PUBNOSTR}:NOSTR)..."
        NOSTRIPFS=$(ipfs add -rwq ${HOME}/.zen/game/nostr/${EMAIL}/ | tail -n 1)
        if [[ -n "$NOSTRIPFS" ]]; then
            ipfs name publish --key "${G1PUBNOSTR}:NOSTR" "/ipfs/${NOSTRIPFS}" 2>&1 >/dev/null \
                && echo "✅ IPNS publication successful: /ipns/${NOSTRNS} -> /ipfs/${NOSTRIPFS}" \
                || echo "⚠️  IPNS publication failed (will retry later)"
        else
            echo "⚠️  Failed to add MULTIPASS directory to IPFS"
        fi
    else
        echo "⚠️  Cannot publish to IPNS: G1PUBNOSTR not set or MULTIPASS directory missing"
    fi
    
    echo "✅ IPFS publish process completed"

    ## CLEAN CACHE
    rm -Rf ~/.zen/tmp/${MOATS-null}
    
    ### UNCOMMENT for DEBUG
    #~ echo "SALT=$SALT PEPPER=$PEPPER \
    #~ NPUBLIC=${NPUBLIC} NPRIV=${NPRIV} EMAIL=${EMAIL} SSSSQR=${SSSSQR} \
    #~ G1PUBNOSTR=${G1PUBNOSTR} G1PUBNOSTRQR=${G1PUBNOSTRQR} VAULTNSQR=${VAULTNSQR} PROFILEQR=${PROFILEQR} NOSTRNS=${NOSTRNS} \
    #~ CAPTAINEMAIL=${CAPTAINEMAIL} MOAT=$MOATS"

    ## Send MULTIPASS by email (unless caller already handles it — set NOMAIL=1 to skip)
    if [[ -z "${NOMAIL}" ]]; then
        MULTIPASS_ZINE="${HOME}/.zen/game/nostr/${EMAIL}/.nostr.zine.html"
        MAILJET_SCRIPT="${MY_PATH}/../tools/mailjet.sh"
        if [[ -s "$MULTIPASS_ZINE" ]] && [[ -x "$MAILJET_SCRIPT" ]]; then
            "$MAILJET_SCRIPT" --expire 0s \
                "${EMAIL}" \
                "$MULTIPASS_ZINE" \
                "MULTIPASS[Ẑ] [UPlanet:${UPLANETG1PUB:0:8}:${ZLAT}:${ZLON}]" \
                >/dev/null 2>&1 &
            echo "📧 MULTIPASS envoyé par email à ${EMAIL}"
        fi
    fi

    echo "${HOME}/.zen/game/nostr/${EMAIL}/.nostr.zine.html"

    exit 0

else

    echo "BAD EMAIL PARAMETER"
    exit 1

fi
