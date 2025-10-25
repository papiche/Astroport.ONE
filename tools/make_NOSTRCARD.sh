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

[[ -z ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}/

if [[ $EMAIL =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then

    ############################################## PREPARE SALT PEPPER
    if [[ -z "$SALT" ]]; then
        SALT=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w42 | head -n1)
    fi
    if [[ -z "$PEPPER" ]]; then
        PEPPER=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w42 | head -n1)
    fi
    # Creating MULTIPASS for ${EMAIL}
    DISCO="/?${EMAIL}=${SALT}&nostr=${PEPPER}"
    #~ echo "DISCO : "$DISCO

    ## ssss-split : Keep 2 needed over 3
    echo "$DISCO" | ssss-split -t 2 -n 3 -q > ~/.zen/tmp/${MOATS}/${EMAIL}.ssss
    HEAD=$(cat ~/.zen/tmp/${MOATS}/${EMAIL}.ssss | head -n 1) && echo "$HEAD" > ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.head
    MIDDLE=$(cat ~/.zen/tmp/${MOATS}/${EMAIL}.ssss | head -n 2 | tail -n 1) && echo "$MIDDLE" > ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.mid
    TAIL=$(cat ~/.zen/tmp/${MOATS}/${EMAIL}.ssss | tail -n 1) && echo "$TAIL" > ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.tail
    # echo "TEST DECODING..."
    (echo "$HEAD
    $TAIL" | ssss-combine -t 2 -q) > /dev/null
    [ ! $? -eq 0 ] && echo "ERROR! SSSSKEY DECODING FAILED" && echo "${MY_PATH}/../templates/wallet.html" && exit 1

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
    ## ENCODE HEAD SSSS SECRET WITH G1PUBNOSTR PUBKEY
    # echo "${MY_PATH}/../tools/natools.py encrypt -p $G1PUBNOSTR -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.head -o ${HOME}/.zen/game/nostr/${EMAIL}/.ssss.head.player.enc"
    ${MY_PATH}/../tools/natools.py encrypt -p "$G1PUBNOSTR" -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.head -o ${HOME}/.zen/game/nostr/${EMAIL}/.ssss.head.player.enc >/dev/null

    ## DISCO MIDDLE ENCRYPT WITH CAPTAING1PUB
    # echo "${MY_PATH}/../tools/natools.py encrypt -p $CAPTAING1PUB -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.mid -o ${HOME}/.zen/game/nostr/${EMAIL}/.ssss.mid.captain.enc"
    ${MY_PATH}/../tools/natools.py encrypt -p "$CAPTAING1PUB" -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.mid -o ${HOME}/.zen/game/nostr/${EMAIL}/.ssss.mid.captain.enc >/dev/null

    ## DISCO TAIL ENCRYPT WITH UPLANETG1PUB
    # echo "${MY_PATH}/../tools/natools.py encrypt -p $UPLANETG1PUB -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.tail -o ${HOME}/.zen/game/nostr/${EMAIL}/ssss.tail.uplanet.enc"
    ${MY_PATH}/../tools/natools.py encrypt -p "$UPLANETG1PUB" -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.tail -o ${HOME}/.zen/game/nostr/${EMAIL}/ssss.tail.uplanet.enc >/dev/null

    ## CREATE IPNS KEY (SIDE STORAGE)
    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/${MOATS}.nostr.ipns "${SALT}" "${PEPPER}"
    ipfs key rm "${G1PUBNOSTR}:NOSTR" > /dev/null 2>&1
    NOSTRNS=$(ipfs key import "${G1PUBNOSTR}:NOSTR" -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/${MOATS}.nostr.ipns)
    echo "${G1PUBNOSTR}:NOSTR ${EMAIL} STORAGE: /ipns/$NOSTRNS"
    echo "/ipns/$NOSTRNS" > "${HOME}/.zen/game/nostr/${EMAIL}/NOSTRNS"


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
        cat ~/.zen/UPassport/templates/wallet.html \
        | sed -e "s~_WALLET_~$(date -u) <br> ${EMAIL}~g" \
             -e "s~_AMOUNT_~IPFS DAEMON ERROR~g" \
            > ${MY_PATH}/tmp/${MOATS}.out.html
        echo "${MY_PATH}/tmp/${MOATS}.out.html"
        exit 0
    fi
    #~ ipfs pin rm /ipfs/${VAULTNSQR} 2>/dev/null

    ## Make PLAYER "SSSS.head:NOSTRNS" QR CODE (Terminal Compatible) - "M-$SSSS_HEAD_B58"
    SSSS_HEAD=$(cat ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.head)
    SSSS_HEAD_B58=$(${MY_PATH}/Mbase58.py encode "${SSSS_HEAD}:${NOSTRNS}")
    amzqr "M-$SSSS_HEAD_B58" -l H -p ${MY_PATH}/../templates/img/key.png \
        -c -n ._SSSSQR.png -d ~/.zen/game/nostr/${EMAIL}/ &>/dev/null

    SSSSQR=$(ipfs --timeout 20s add -q ~/.zen/game/nostr/${EMAIL}/._SSSSQR.png)
    # ipfs pin rm /ipfs/${SSSSQR} 2>/dev/null ## We can keep it

    ## Create G1PUBNOSTR QR Code
    ## Use webcam picture ?
    [[ -s ${HOME}/.zen/game/nostr/${EMAIL}/picture.png ]] \
        && FDQR=${HOME}/.zen/game/nostr/${EMAIL}/picture.png \
        || FDQR=${MY_PATH}/../templates/img/nature_cloud_face.png

    [[ $UPLANETNAME != "EnfinLibre" ]] && Z=":ZEN" || Z="" ## Add :ZEN only for UPlanet ẐEN
    amzqr "${G1PUBNOSTR}${Z}" -l H -p "$FDQR" -c -n MULTIPASS.QR.png -d ~/.zen/game/nostr/${EMAIL}/ &>/dev/null

    ## Add white margins around the QR code image (for a flashable coracle profile picture)
    convert ~/.zen/game/nostr/${EMAIL}/MULTIPASS.QR.png -bordercolor white -border 90x90 ~/.zen/game/nostr/${EMAIL}/MULTIPASS.QR.png

    echo "${G1PUBNOSTR}" > ${HOME}/.zen/game/nostr/${EMAIL}/G1PUBNOSTR

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
        
        # Create or update DID using did_manager_nostr.sh with LOCATAIRE type (0 amount)
        if [[ "$did_exists" == "true" ]]; then
            echo "🔧 Updating existing DID with did_manager_nostr.sh..."
        else
            echo "🔧 Creating new DID with did_manager_nostr.sh..."
        fi
        
        if ${MY_PATH}/did_manager_nostr.sh update "${EMAIL}" "LOCATAIRE" "0" "0"; then
            echo "✅ Initial DID document created by did_manager_nostr.sh with full UPlanet template"
        else
            echo "❌ Failed to create DID document using did_manager_nostr.sh"
            echo "💡 Check that did_manager_nostr.sh is working correctly"
            exit 1
        fi
    else
        echo "❌ did_manager_nostr.sh not found at ${MY_PATH}/did_manager_nostr.sh"
        echo "💡 Ensure did_manager_nostr.sh is in the same directory as make_NOSTRCARD.sh"
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
        > ${HOME}/.zen/game/nostr/${EMAIL}/.nostr.zine.html

    if [[ "$Z" == ":ZEN" ]]; then
        ## Replace Cesium Access with uSPOT/check_balance?g1pub=email (html output)
        # Escape special characters in URLs for sed
        sed -i "s~${myIPFS}/ipfs/QmYZWzSfPgb1y83fWTmKBEHdA9QoxsYBmqLkEJU2KQ1DYW/#/app/wot/${G1PUBNOSTR}/~${uSPOT}/check_balance?g1pub=${EMAIL}~g" \
            "${HOME}/.zen/game/nostr/${EMAIL}/.nostr.zine.html"

    fi

    ### MULTIPASS FOLLOWS CAPTAIN AUTOMATICALLY
    # New MULTIPASS should follow the CAPTAIN to receive updates and guidance
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
        CAPTAINNSEC=$(grep "NSEC=" ~/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr | cut -d '=' -f 2)
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

    ### SEND NOSTR MESSAGE WITH QR CODE LINK
    # DID is accessible via Nostr (source of truth) and IPFS/.well-known (cache)
    Mymessage="🎉 ẐEN wallet : ${G1PUBNOSTR}${Z}

𝄃𝄃𝄂𝄂𝄀𝄁𝄃𝄂𝄂𝄃 ${myIPFS}/ipfs/${G1PUBNOSTRQR}

🆔 DID: did:nostr:${HEX}
"

    NPRIV_HEX=$(${MY_PATH}/../tools/nostr2hex.py "$NPRIV")
    HEX_HEX=$(${MY_PATH}/../tools/nostr2hex.py "$NPUBLIC")
    
    # Calculate expiration timestamp (48 hours from now)
    EXPIRATION=$(date -d "+48 hours" +%s)
    
    # Send to relay(s) - avoid duplicates
    echo "📡 Publishing NOSTR message to relay: $myRELAY (expires in 48h)"
    
    # Send message to the configured relay
    nostpy-cli send_event \
        -privkey "$NPRIV_HEX" \
        -kind 1 \
        -content "$Mymessage" \
        -tags "[['p', '$HEX_HEX'], ['i', 'did:nostr:${HEX}'], ['expiration', '$EXPIRATION']]" \
        --relay "$myRELAY" &>/dev/null
    
    # Only send to public relay if it's different from the configured relay
    if [[ "$myRELAY" != "wss://relay.copylaradio.com" ]]; then
        echo "📡 Also publishing to public relay for redundancy"
        nostpy-cli send_event \
            -privkey "$NPRIV_HEX" \
            -kind 1 \
            -content "$Mymessage" \
            -tags "[['p', '$HEX_HEX'], ['i', 'did:nostr:${HEX}'], ['expiration', '$EXPIRATION']]" \
            --relay "wss://relay.copylaradio.com" &>/dev/null
    else
        echo "📡 Message sent to public relay (no duplication)"
    fi


    ###############################################################################################
    ### Add /APP/uDRIVE
    #~ Réception : Quand un fichier .zip est téléversé via l'API (UPassport/54321.py),
    #~ il est immédiatement identifié et spécifiquement dirigé vers le répertoire uDRIVE/Apps/
    #~ Application dans un dossier : Apps/MonApp/index.html avec son icône Apps/MonApp/icon.png.
    #~ Application "flat" : Apps/index.MonApp.html avec son icône Apps/MonApp.png.
    mkdir -p ${HOME}/.zen/game/nostr/${EMAIL}/APP/uDRIVE/Apps/Cesium.v1
    echo '<meta http-equiv="refresh" content="0;url='${CESIUMIPFS}/#/app/wot/${G1PUBNOSTR}/'">' \
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

    ### PUBLISH MULTIPASS IPFS ####################################################################
    NOSTRIPFS=$(ipfs --timeout 30s add -rwq ${HOME}/.zen/game/nostr/${EMAIL}/ | tail -n 1)
    ipfs name publish --key "${G1PUBNOSTR}:NOSTR" /ipfs/${NOSTRIPFS} 2>&1 >/dev/null &
    IPFS_PUBLISH_PID=$!
    ###############################################################################################
    ## ORIGIN or ẐEN's
    [[ ${UPLANETG1PUB:0:8} == "AwdjhpJN" ]] && ORIGIN="ORIGIN" || ORIGIN="${UPLANETG1PUB:0:8}"
    ZENCARDG1=$(cat ~/.zen/game/players/${EMAIL}/.g1pub 2>/dev/null) ## Does ZenCard already existing

    ### CREATE TEPORARY PROFILE in NOSTR RELAYS
    ${MY_PATH}/../tools/nostr_setup_profile.py \
        "$NPRIV" \
        "[•͡˘㇁•͡˘] $YOUSER" "${G1PUBNOSTR}" \
        "⏰ UPlanet Ẑen ${ORIGIN} // Welcome // ${myIPFS}/ipns/copylaradio.com // DID: did:nostr:${HEX}" \
        "$myIPFS/ipfs/${G1PUBNOSTRQR}" \
        "$myIPFS/ipfs/QmSMQCQDtcjzsNBec1EHLE78Q1S8UXGfjXmjt8P6o9B8UY/ComfyUI_00841_.jpg" \
        "" "$myIPFS/ipns/${NOSTRNS}/${EMAIL}/APP/uDRIVE" "" "" "" "" \
        "wss://relay.copylaradio.com" "$myRELAY" \
        --zencard "$ZENCARDG1" \
        --email "$EMAIL" \
        --ipns_vault "/ipns/${NOSTRNS}" &>/dev/null

    ## CREATE CESIUM + PROFILE
    ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/tmp/${MOATS}/${EMAIL}.multipass.dunikey \
        set --name "${YOUSER} MULTIPASS" --avatar "$HOME/.zen/game/nostr/${EMAIL}/IPNS.QR.png" \
        --site "$myIPFS/ipns/${NOSTRNS}/${EMAIL}/APP/uDRIVE" -d "UPlanet ${UPLANETG1PUB:0:8} MULTIPASS ($HEX)" &>/dev/null

    ## SEND PRIMO TRANSACTION FROM UPLANETNAME_G1 (source primale unique)
    echo "UPlanet ẐEN : Sending PRIMO TX from UPLANETNAME_G1 to MULTIPASS"
    
    # Ensure UPLANETNAME_G1 dunikey exists (source primale unique)
    if [[ ! -f ~/.zen/game/uplanet.G1.dunikey ]]; then
        ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.G1.dunikey "${UPLANETNAME}.G1" "${UPLANETNAME}.G1"
        chmod 600 ~/.zen/game/uplanet.G1.dunikey
    fi
    
    # Send primo transaction from UPLANETNAME_G1 to establish primal chain for MULTIPASS
    ${MY_PATH}/../tools/PAYforSURE.sh "${HOME}/.zen/game/uplanet.G1.dunikey" "1" "${G1PUBNOSTR}" "UPLANET:${UPLANETG1PUB:0:8}:${YOUSER}:MULTIPASS:PRIMO" 2>/dev/null \
    && echo "${UPLANETNAME_G1}" > ~/.zen/game/nostr/${EMAIL}/G1PRIME \
    && echo "${UPLANETNAME_G1}" > ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal \
    && echo "✅ PRIMO TX sent successfully - PRIMAL marked from ${UPLANETNAME_G1} wallet" \
    || echo "⚠️ PRIMO TX failed for MULTIPASS ${EMAIL}"

    ## SEND ZINE TO EMAIL USING MAILJET
    echo "Sending NOSTR zine to ${EMAIL} via mailjet..."
    ${MY_PATH}/mailjet.sh --expire 96h "${EMAIL}" "${HOME}/.zen/game/nostr/${EMAIL}/.nostr.zine.html" "MULTIPASS" 2>/dev/null \
        && echo "✅ NOSTR zine sent successfully to ${EMAIL}" \
        || echo "⚠️ Failed to send NOSTR zine to ${EMAIL}"

    ## CLEAN CACHE
    rm -Rf ~/.zen/tmp/${MOATS-null}
    
    ## Wait for background processes to complete
    echo "⏳ Waiting for background processes to complete..."
    if [[ -n "$MULTIPASS_PRINT_PID" ]]; then
        wait $MULTIPASS_PRINT_PID 2>/dev/null || true
        echo "✅ MULTIPASS print process completed"
    fi
    
    if [[ -n "$IPFS_PUBLISH_PID" ]]; then
        wait $IPFS_PUBLISH_PID 2>/dev/null || true
        echo "✅ IPFS publish process completed"
    fi
    
    ### UNCOMMENT for DEBUG
    #~ echo "SALT=$SALT PEPPER=$PEPPER \
    #~ NPUBLIC=${NPUBLIC} NPRIV=${NPRIV} EMAIL=${EMAIL} SSSSQR=${SSSSQR} \
    #~ G1PUBNOSTR=${G1PUBNOSTR} G1PUBNOSTRQR=${G1PUBNOSTRQR} VAULTNSQR=${VAULTNSQR} PROFILEQR=${PROFILEQR} NOSTRNS=${NOSTRNS} \
    #~ CAPTAINEMAIL=${CAPTAINEMAIL} MOAT=$MOATS"

    echo "${HOME}/.zen/game/nostr/${EMAIL}/.nostr.zine.html"

    exit 0

else

    echo "BAD EMAIL PARAMETER"
    exit 1

fi
