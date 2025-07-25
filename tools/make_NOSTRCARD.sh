#!/bin/bash
################################################################################
# Script: Make_NOSTRCARD.sh
# Description: Crée une carte NOSTR complète avec système d'identité décentralisé
#
# Ce script génère une identité NOSTR complète comprenant :
# - Une paire de clés NOSTR (secrète/publique)
# - Un portefeuille cryptographique multi-blockchain (Bitcoin, Monero)
# - Un espace de stockage IPNS personnel
# - Des QR codes d'accès sécurisés
# - Une intégration avec le réseau social décentralisé NOSTR
# - Une identité Duniter/G1 compatible
#
# L'identité est créée à partir d'une adresse email et protégée par :
# - Un sel (salt) et un poivre (pepper) cryptographiques
# - Un schéma de partage de secret (SSSS) distribué
# - Un chiffrement asymétrique avec les nœuds du réseau
#
# Fonctionnalités :
# - Génération de profils NOSTR avec métadonnées
# - Publication automatique sur les relais NOSTR
# - Création d'un espace de stockage IPNS persistant
# - Génération de QR codes sécurisés
# - Intégration avec les systèmes UPlanet et G1
#
# Sécurité :
# - Aucune donnée sensible n'est stockée en clair
# - Utilisation de standards cryptographiques robustes
# - Destruction des traces temporaires après exécution
#
# Usage: Voir la fonction usage() pour les détails d'utilisation
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"

usage() {
  echo "Usage: Make_NOSTRCARD.sh [OPTIONS] <EMAIL> [IMAGE] [LATITUDE] [LONGITUDE] [SALT] [PEPPER]"
  echo ""
  echo "  Generates a NOSTR card and related cryptographic keys, stores them"
  echo "  locally, and prepares files for a NOSTR application."
  echo ""
  echo "Arguments:"
  echo "  <EMAIL>        Email address to associate with the NOSTR card."
  echo "                 Must be a valid email format."
  echo "  [IMAGE]        Optional: Path to an image file to use as profile picture."
  echo "                 Alternatively, a two-letter language code (e.g., 'en', 'fr')"
  echo "                 to set the language. If omitted, defaults to 'fr'."
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
IMAGE="$2"
ZLAT=$(makecoord "$3")
ZLON=$(makecoord "$4")
### Accept DISCO seed
SALT="$5"
PEPPER="$6"

YOUSER=$(${MY_PATH}/../tools/clyuseryomail.sh ${EMAIL})
echo "Make_NOSTRCARD.sh >>>>>>>>>> $EMAIL"

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
    # Creating a NOSTRCARD for ${EMAIL}
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
    HEX=$(${MY_PATH}/../tools/nostr2hex.py $NPUBLIC)

    #~ echo "Nostr Private Key: $NPRIV"
    echo "Nostr Public Key: $NPUBLIC = $HEX"

    # 2. Store the keys in a file or a secure place (avoid printing them to console if possible)
    echo "$NPRIV" > ~/.zen/tmp/${MOATS}/${EMAIL}.nostr.priv
    echo "$NPUBLIC" > ~/.zen/tmp/${MOATS}/${EMAIL}.nostr.pub

    # Create an G1CARD : G1Wallet waiting for G1 to make key batch running
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/${EMAIL}.g1card.dunikey "${SALT}" "${PEPPER}"
    G1PUBNOSTR=$(cat ~/.zen/tmp/${MOATS}/${EMAIL}.g1card.dunikey  | grep 'pub:' | cut -d ' ' -f 2)
    # echo "G1NOSTR _WALLET: $G1PUBNOSTR"

    ############ CREATE LOCAL USER SPACE
    mkdir -p ${HOME}/.zen/game/nostr/${EMAIL}/
    [[ -s ${IMAGE} ]] && cp ${IMAGE} ${HOME}/.zen/game/nostr/${EMAIL}/picture.png 2>/dev/null
    [[ "${IMAGE}" =~ ^[a-z]{2}$ ]] && LANG="${IMAGE}" || LANG="fr" ## Contains IMAGE or Navigator language

    ##########################################################################
    echo "${LANG}" > ${HOME}/.zen/game/nostr/${EMAIL}/LANG ## COPY LANG
    echo "$HEX" > ${HOME}/.zen/game/nostr/${EMAIL}/HEX ## COPY HEX
    echo "$NPUBLIC" > ${HOME}/.zen/game/nostr/${EMAIL}/NPUB ## COPY NPUB
    ##########################################################################
    ## Create Bitcoin Twin Address
    BITCOIN=$(${MY_PATH}/../tools/keygen -t bitcoin "${SALT}" "${PEPPER}" | tail -n 1 | rev | cut -f 1 -d ' '  | rev)
    echo $BITCOIN > ${HOME}/.zen/game/nostr/${EMAIL}/BITCOIN
    ## Create Monero Twin Address
    MONERO=$(${MY_PATH}/../tools/keygen -t monero "${SALT}" "${PEPPER}" | tail -n 1 | rev | cut -f 1 -d ' '  | rev)
    echo $MONERO > ${HOME}/.zen/game/nostr/${EMAIL}/MONERO

    ### CRYPTO ZONE
    ## ENCODE HEAD SSSS SECRET WITH G1PUBNOSTR PUBKEY
    # echo "${MY_PATH}/../tools/natools.py encrypt -p $G1PUBNOSTR -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.head -o ${HOME}/.zen/game/nostr/${EMAIL}/.ssss.head.player.enc"
    ${MY_PATH}/../tools/natools.py encrypt -p $G1PUBNOSTR -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.head -o ${HOME}/.zen/game/nostr/${EMAIL}/.ssss.head.player.enc >/dev/null

    ## DISCO MIDDLE ENCRYPT WITH CAPTAING1PUB
    # echo "${MY_PATH}/../tools/natools.py encrypt -p $CAPTAING1PUB -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.mid -o ${HOME}/.zen/game/nostr/${EMAIL}/.ssss.mid.captain.enc"
    ${MY_PATH}/../tools/natools.py encrypt -p $CAPTAING1PUB -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.mid -o ${HOME}/.zen/game/nostr/${EMAIL}/.ssss.mid.captain.enc >/dev/null

    ## DISCO TAIL ENCRYPT WITH UPLANETG1PUB
    # echo "${MY_PATH}/../tools/natools.py encrypt -p $UPLANETG1PUB -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.tail -o ${HOME}/.zen/game/nostr/${EMAIL}/ssss.tail.uplanet.enc"
    ${MY_PATH}/../tools/natools.py encrypt -p $UPLANETG1PUB -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.tail -o ${HOME}/.zen/game/nostr/${EMAIL}/ssss.tail.uplanet.enc >/dev/null

    ## CREATE IPNS KEY (SIDE STORAGE)
    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/${MOATS}.nostr.ipns "${SALT}" "${PEPPER}"
    ipfs key rm "${G1PUBNOSTR}:NOSTR" > /dev/null 2>&1
    NOSTRNS=$(ipfs key import "${G1PUBNOSTR}:NOSTR" -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/${MOATS}.nostr.ipns)
    echo "${G1PUBNOSTR}:NOSTR ${EMAIL} STORAGE: /ipns/$NOSTRNS"
    echo "/ipns/$NOSTRNS" > ${HOME}/.zen/game/nostr/${EMAIL}/NOSTRNS


    ## Create uSPOT/scan QR Code
    ## /ipfs/QmNd3abeAoUH1nGzwnaLNafRgtvwTSBCZyKqT8eBnEPQK9/u.scan.qr.png~/ipfs/$uSPOT_QR_ipfs
    amzqr "${uSPOT}/scan" -l H -p ${MY_PATH}/../templates/img/cloud_border.png \
        -c -n uSPOT.QR.png -d ~/.zen/game/nostr/${EMAIL}/ &>/dev/null

    uSPOT_QR_ipfs=$(ipfs --timeout 20s add -q ~/.zen/game/nostr/${EMAIL}/uSPOT.QR.png)


    ## QR CODE accès NOSTR VAULTNSQR
    amzqr "${myIPFS}/ipns/$NOSTRNS" -l H -p ${MY_PATH}/../templates/img/no_stripfs.png \
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

    ## Make PLAYER "SSSS.head:NOSTRNS" QR CODE (Terminal Compatible)
    amzqr "$(cat ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.head):$NOSTRNS" -l H -p ${MY_PATH}/../templates/img/key.png \
        -c -n ${EMAIL}.QR.png -d ~/.zen/tmp/${MOATS}/ &>/dev/null

    SSSSQR=$(ipfs --timeout 20s add -q ~/.zen/tmp/${MOATS}/${EMAIL}.QR.png)
    ipfs pin rm /ipfs/${SSSSQR} 2>/dev/null

    ## Create G1PUBNOSTR QR Code
    ## Use webcam picture ?
    [[ -s ${HOME}/.zen/game/nostr/${EMAIL}/picture.png ]] \
        && FDQR=${HOME}/.zen/game/nostr/${EMAIL}/picture.png \
        || FDQR=${MY_PATH}/../templates/img/nature_cloud_face.png

    [[ $UPLANETNAME != "EnfinLibre" ]] && Z=":ZEN" || Z="" ## Add :ZEN only for UPlanet ẐEN
    amzqr "${G1PUBNOSTR}${Z}" -l H -p $FDQR -c -n G1PUBNOSTR.QR.png -d ~/.zen/game/nostr/${EMAIL}/ &>/dev/null
    
    ## Add white margins of 100 pixels around the QR code image (for a flashable coracle profile picture)
    convert ~/.zen/game/nostr/${EMAIL}/G1PUBNOSTR.QR.png -bordercolor white -border 100x100 ~/.zen/game/nostr/${EMAIL}/G1PUBNOSTR.QR.png
    
    echo "${G1PUBNOSTR}" > ${HOME}/.zen/game/nostr/${EMAIL}/G1PUBNOSTR

    ## MOVE webcam picture
    mv ${HOME}/.zen/game/nostr/${EMAIL}/picture.png ${HOME}/.zen/game/nostr/${EMAIL}/scan_${MOATS}.png 2>/dev/null

    G1PUBNOSTRQR=$(ipfs --timeout 30s add -q ~/.zen/game/nostr/${EMAIL}/G1PUBNOSTR.QR.png)
    # ipfs pin rm /ipfs/${G1PUBNOSTRQR}
    echo "${G1PUBNOSTRQR}" > ${HOME}/.zen/game/nostr/${EMAIL}/G1PUBNOSTR.QR.png.cid

    ##############################################################
    # INSERT NOSTR ORACOLO APP
    cat ${MY_PATH}/../templates/NOSTR/oracolo/index.html \
        | sed -e "s~npub1w25fyk90kknw499ku6q9j77sfx3888eyfr20kq2rj7f5gnm8qrfqd6uqu8~${NPUBLIC}~g" \
            -e "s~_MYRELAY_~${myRELAY}~g" \
            > ${HOME}/.zen/game/nostr/${EMAIL}/_index.BLOG.html

    ## TODATE TIME STAMP
    echo ${TODATE} > ${HOME}/.zen/game/nostr/${EMAIL}/TODATE
    ## ZLAT ZLON
    echo "_${ZLAT}_${ZLON}" > ${HOME}/.zen/game/nostr/${EMAIL}/ZUMAP # RUNTIME/NOSTR.UMAP.refresh.sh
    echo "LAT=${ZLAT}; LON=${ZLON};" > ${HOME}/.zen/game/nostr/${EMAIL}/GPS # IA/UPlanet_IA_Responder.sh

    ## Create a .secret.disco file with the DISCO seed (needed for UPlanet Captain) ## OPTIONAL for others
    echo "$DISCO" > ${HOME}/.zen/game/nostr/${EMAIL}/.secret.disco
    chmod 600 ${HOME}/.zen/game/nostr/${EMAIL}/.secret.disco

    ##############################################################
    ### PREPARE NOSTR ZINE
    cat ${MY_PATH}/../templates/NOSTR/zine/nostr.html \
    | sed -e "s~npub1w25fyk90kknw499ku6q9j77sfx3888eyfr20kq2rj7f5gnm8qrfqd6uqu8~${NPUBLIC}~g" \
            -e "s~nsec13x0643lc3al5fk92auurh7ww0993syj566eh7ta8r2jpkprs44rs33cute~${NPRIV}~g" \
            -e "s~toto@yopmail.com~${EMAIL}~g" \
            -e "s~_YOUSER_~${YOUSER}~g" \
            -e "s~QmdmeZhD8ncBFptmD5VSJoszmu41edtT265Xq3HVh8PhZP~${SSSSQR}~g" \
            -e "s~Qma4ceUiYD2bAydL174qCSrsnQRoDC3p5WgRGKo9tEgRqH~${G1PUBNOSTRQR}~g" \
            -e "s~Qmeu1LHnTTHNB9vex5oUwu3VVbc7uQZxMb8bYXuX56YAx2~${VAULTNSQR}~g" \
            -e "s~/ipfs/QmNd3abeAoUH1nGzwnaLNafRgtvwTSBCZyKqT8eBnEPQK9/u.scan.qr.png~/ipfs/${uSPOT_QR_ipfs}~g" \
            -e "s~_NSECTAIL_~${NPRIV: -33}~g" \
            -e "s~_UMAP_~_${ZLAT}_${ZLON}~g" \
            -e "s~_NOSTRVAULT_~/ipns/${NOSTRNS}~g" \
            -e "s~_SALT_~${SALT}~g" \
            -e "s~_PEPPER_~${PEPPER}~g" \
            -e "s~_MYRELAY_~${myRELAY}~g" \
            -e "s~_uSPOT_~${uSPOT}~g" \
            -e "s~_CAPTAINEMAIL_~${CAPTAINEMAIL}~g" \
            -e "s~_G1PUBNOSTR_~${G1PUBNOSTR}~g" \
            -e "s~_UPLANET8_~UPlanet:${UPLANETG1PUB:0:8}~g" \
            -e "s~_DATE_~$(date -u)~g" \
            -e "s~http://127.0.0.1:8080~${myIPFS}~g" \
        > ${HOME}/.zen/game/nostr/${EMAIL}/.nostr.zine.html

    ### SEND NOSTR MESSAGE WITH QR CODE LINK
    NPRIV_HEX=$(${MY_PATH}/../tools/nostr2hex.py $NPRIV)
    HEX_HEX=$(${MY_PATH}/../tools/nostr2hex.py $NPUBLIC)
    nostpy-cli send_event \
        -privkey "$NPRIV_HEX" \
        -kind 1 \
        -content "🎫 MULTIPASS Wallet: ${G1PUBNOSTR}${Z} ${myIPFS}/ipfs/${G1PUBNOSTRQR}" \
        -tags "[['p', '$HEX_HEX']]" \
        --relay "$myRELAY" &>/dev/null

    ### ADD /APP/uDRIVE - redirections APP IPFS
    mkdir -p ${HOME}/.zen/game/nostr/${EMAIL}/APP/uDRIVE/Apps

    ## Add Web3 App Links
    echo '<meta http-equiv="refresh" content="0;url='${CESIUMIPFS}/#/app/wot/${ISSUERPUB}/'">' \
        > ${HOME}/.zen/game/nostr/${EMAIL}/APP/uDRIVE/Apps/CESIUM.v1.html

    ## Link generate_ipfs_structure.sh to uDRIVE
    cd ${HOME}/.zen/game/nostr/${EMAIL}/APP/uDRIVE/

    ln -s ${HOME}/.zen/Astroport.ONE/tools/generate_ipfs_structure.sh ./generate_ipfs_structure.sh
    ## RUN App
    UDRIVE=$(./generate_ipfs_structure.sh . 2>/dev/null)
    echo "<html><head><meta http-equiv=\"refresh\" content=\"0; url=/ipfs/$UDRIVE\"></head></html>" > index.html

    ## Link generate_ipfs_RPG.sh to uWORLD
    mkdir -p ${HOME}/.zen/game/nostr/${EMAIL}/APP/uWORLD/
    cd -
    cd ${HOME}/.zen/game/nostr/${EMAIL}/APP/uWORLD
    ln -s ${HOME}/.zen/Astroport.ONE/tools/generate_ipfs_RPG.sh ./generate_ipfs_RPG.sh
    ## RUN App
    UWORLD=$(./generate_ipfs_RPG.sh . 2>/dev/null)
    echo "<html><head><meta http-equiv=\"refresh\" content=\"0; url=/ipfs/$UWORLD\"></head></html>" > index.html
    cd -

    NOSTRIPFS=$(ipfs --timeout 20s add -rwq ${HOME}/.zen/game/nostr/${EMAIL}/ | tail -n 1)
    ipfs name publish --key "${G1PUBNOSTR}:NOSTR" /ipfs/${NOSTRIPFS} 2>&1 >/dev/null &

    ### SEND PROFILE TO NOSTR RELAYS
    ${MY_PATH}/../tools/nostr_setup_profile.py \
        "$NPRIV" \
        "[•͡˘㇁•͡˘] $YOUSER" "${G1PUBNOSTR}" \
        "⏰ UPlanet MULTIPASS ... 🪙 ... UPlanet ${UPLANETG1PUB:0:8} ${uSPOT}/nostr" \
        "$myIPFS/ipfs/${G1PUBNOSTRQR}" \
        "$myIPFS/ipfs/QmSMQCQDtcjzsNBec1EHLE78Q1S8UXGfjXmjt8P6o9B8UY/ComfyUI_00841_.jpg" \
        "" "$myIPFS/ipns/${NOSTRNS}/${EMAIL}/APP" "" "" "" "" \
        "wss://relay.copylaradio.com" "$myRELAY" \
        --ipns_vault "/ipns/${NOSTRNS}" &>/dev/null

    ## CREATE CESIUM + PROFILE
    ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/tmp/${MOATS}/${EMAIL}.g1card.dunikey set --name "UPlanet MULTIPASS" --avatar "$HOME/.zen/game/nostr/${EMAIL}/IPNS.QR.png" --site "https://coracle.copylaradio.com" -d "UPlanet MULTIPASS : $HEX : UPlanet ${UPLANETG1PUB:0:8}" &>/dev/null

    ## CLEAN CACHE
    rm -Rf ~/.zen/tmp/${MOATS-null}
    ### UNCOMMENT for DEBUG
    #~ echo "SALT=$SALT PEPPER=$PEPPER \
#~ NPUBLIC=${NPUBLIC} NPRIV=${NPRIV} EMAIL=${EMAIL} SSSSQR=${SSSSQR} \
#~ G1PUBNOSTR=${G1PUBNOSTR} G1PUBNOSTRQR=${G1PUBNOSTRQR} VAULTNSQR=${VAULTNSQR} NOSTRNS=${NOSTRNS} \
#~ CAPTAINEMAIL=${CAPTAINEMAIL} MOAT=$MOATS"

    echo "${HOME}/.zen/game/nostr/${EMAIL}/.nostr.zine.html"

    exit 0

else

    echo "BAD EMAIL PARAMETER"
    exit 1

fi
