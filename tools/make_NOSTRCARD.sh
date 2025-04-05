################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
## INITIALIZE NOSTR CARD + G1 + IPNS App Storage
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"

PARAM="$1"
EMAIL="${PARAM,,}" ## lowercase
IMAGE="$2"


echo "Email detected: $EMAIL"
[[ -s "~/.zen/tmp/${MOATS}/${EMAIL}_index.html" ]] \
    && rm -Rf "${HOME}/.zen/game/nostr/${EMAIL-null}/" ## CLEANING OLD NOSTR

[[ -z ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}/

if [[ $EMAIL =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then

    ############################################## PREPARE SALT PEPPER
    SALT=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w42 | head -n1)
    PEPPER=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w42 | head -n1)
    # Creating a NOSTRCARD for ${EMAIL}
    DISCO="/?${EMAIL}=${SALT}&nostr=${PEPPER}"
    #~ echo "DISCO : "$DISCO

    ## ssss-split : Keep 2 needed over 3
    echo "$DISCO" | ssss-split -t 2 -n 3 -q > ~/.zen/tmp/${MOATS}/${EMAIL}.ssss
    HEAD=$(cat ~/.zen/tmp/${MOATS}/${EMAIL}.ssss | head -n 1) && echo "$HEAD" > ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.head
    MIDDLE=$(cat ~/.zen/tmp/${MOATS}/${EMAIL}.ssss | head -n 2 | tail -n 1) && echo "$MIDDLE" > ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.mid
    TAIL=$(cat ~/.zen/tmp/${MOATS}/${EMAIL}.ssss | tail -n 1) && echo "$TAIL" > ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.tail
    echo "TEST DECODING..."
    echo "$HEAD
    $TAIL" | ssss-combine -t 2 -q
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
    echo "G1NOSTR _WALLET: $G1PUBNOSTR"

    ############ CREATE LOCAL USER SPACE
    mkdir -p ${HOME}/.zen/game/nostr/${EMAIL}/
    [[ -s ${IMAGE} ]] && cp ${IMAGE} ${HOME}/.zen/game/nostr/${EMAIL}/picture.png
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
    echo "${MY_PATH}/../tools/natools.py encrypt -p $G1PUBNOSTR -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.head -o ${HOME}/.zen/game/nostr/${EMAIL}/ssss.head.player.enc"
    ${MY_PATH}/../tools/natools.py encrypt -p $G1PUBNOSTR -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.head -o ${HOME}/.zen/game/nostr/${EMAIL}/ssss.head.player.enc

    ## DISCO MIDDLE ENCRYPT WITH CAPTAING1PUB
    echo "${MY_PATH}/../tools/natools.py encrypt -p $CAPTAING1PUB -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.mid -o ${HOME}/.zen/game/nostr/${EMAIL}/ssss.mid.captain.enc"
    ${MY_PATH}/../tools/natools.py encrypt -p $CAPTAING1PUB -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.mid -o ${HOME}/.zen/game/nostr/${EMAIL}/ssss.mid.captain.enc

    ## DISCO TAIL ENCRYPT WITH UPLANETG1PUB
    echo "${MY_PATH}/../tools/natools.py encrypt -p $UPLANETG1PUB -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.tail -o ${HOME}/.zen/game/nostr/${EMAIL}/ssss.tail.uplanet.enc"
    ${MY_PATH}/../tools/natools.py encrypt -p $UPLANETG1PUB -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.tail -o ${HOME}/.zen/game/nostr/${EMAIL}/ssss.tail.uplanet.enc

    ## CREATE IPNS KEY (SIDE STORAGE)
    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/${MOATS}.nostr.ipns "${SALT}" "${PEPPER}"
    ipfs key rm "${G1PUBNOSTR}:NOSTR" > /dev/null 2>&1
    NOSTRNS=$(ipfs key import "${G1PUBNOSTR}:NOSTR" -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/${MOATS}.nostr.ipns)
    echo "${G1PUBNOSTR}:NOSTR ${EMAIL} STORAGE: /ipns/$NOSTRNS"
    echo "/ipns/$NOSTRNS" > ${HOME}/.zen/game/nostr/${EMAIL}/NOSTRNS

    ## QR CODE accès NOSTR VAULTNSQR
    amzqr "${myIPFS}/ipns/$NOSTRNS" -l H -p ${MY_PATH}/../templates/img/no_stripfs.png \
        -c -n IPNS.QR.png -d ~/.zen/game/nostr/${EMAIL}/ 2>/dev/null

    VAULTNSQR=$(ipfs --timeout 15s add -q ~/.zen/game/nostr/${EMAIL}/IPNS.QR.png)
    ## CHECK IPFS IS WORKING GOOD (sometimes stuck)
    if [[ ! $? -eq 0 ]]; then
        cat ~/.zen/UPassport/templates/wallet.html \
        | sed -e "s~_WALLET_~$(date -u) <br> ${EMAIL}~g" \
             -e "s~_AMOUNT_~IPFS DAEMON ERROR~g" \
            > ${MY_PATH}/tmp/${MOATS}.out.html
        echo "${MY_PATH}/tmp/${MOATS}.out.html"
        exit 0
    fi
    ipfs pin rm /ipfs/${VAULTNSQR} 2>/dev/null

    ## Make PLAYER "SSSS.head:NOSTRNS" QR CODE
    amzqr "$(cat ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.head):$NOSTRNS" -l H -p ${MY_PATH}/../templates/img/key.png \
        -c -n ${EMAIL}.QR.png -d ~/.zen/tmp/${MOATS}/ 2>/dev/null

    SSSSQR=$(ipfs --timeout 15s add -q ~/.zen/tmp/${MOATS}/${EMAIL}.QR.png)
    ipfs pin rm /ipfs/${SSSSQR} 2>/dev/null

    ## Create G1PUBNOSTR QR Code
    ## Use webcam picture ?
    [[ -s ${HOME}/.zen/game/nostr/${EMAIL}/picture.png ]] \
        && FDQR=${HOME}/.zen/game/nostr/${EMAIL}/picture.png \
        || FDQR=${MY_PATH}/../templates/img/nature_cloud_face.png

    amzqr "${G1PUBNOSTR}" -l H -p $FDQR -c -n G1PUBNOSTR.QR.png -d ~/.zen/game/nostr/${EMAIL}/ 2>/dev/null
    echo "${G1PUBNOSTR}" > ${HOME}/.zen/game/nostr/${EMAIL}/G1PUBNOSTR

    ## MOVE webcam picture
    mv ${HOME}/.zen/game/nostr/${EMAIL}/picture.png ${HOME}/.zen/game/nostr/${EMAIL}/scan_${MOATS}.png

    G1PUBNOSTRQR=$(ipfs --timeout 15s add -q ~/.zen/game/nostr/${EMAIL}/G1PUBNOSTR.QR.png)
    ipfs pin rm /ipfs/${G1PUBNOSTRQR}
    echo "${G1PUBNOSTRQR}" > ${HOME}/.zen/game/nostr/${EMAIL}/G1PUBNOSTR.QR.png.cid

    ##############################################################
    # INSERT NOSTR ORACOLO APP
    cat ${MY_PATH}/../templates/NOSTR/oracolo/index.html \
        | sed -e "s~npub1w25fyk90kknw499ku6q9j77sfx3888eyfr20kq2rj7f5gnm8qrfqd6uqu8~${NPUBLIC}~g" \
            -e "s~_MYRELAY_~${myRELAY}~g" \
            > ${HOME}/.zen/game/nostr/${EMAIL}/_index.BLOG.html

    ## TODATE TIME STAMP
    echo ${TODATE} > ${HOME}/.zen/game/nostr/${EMAIL}/TODATE

    ##############################################################
    ### PREPARE NOSTR ZINE
    cat ${MY_PATH}/../templates/NOSTR/zine/nostr.html \
    | sed -e "s~npub1w25fyk90kknw499ku6q9j77sfx3888eyfr20kq2rj7f5gnm8qrfqd6uqu8~${NPUBLIC}~g" \
            -e "s~nsec13x0643lc3al5fk92auurh7ww0993syj566eh7ta8r2jpkprs44rs33cute~${NPRIV}~g" \
            -e "s~toto@yopmail.com~${EMAIL}~g" \
            -e "s~QmdmeZhD8ncBFptmD5VSJoszmu41edtT265Xq3HVh8PhZP~${SSSSQR}~g" \
            -e "s~Qma4ceUiYD2bAydL174qCSrsnQRoDC3p5WgRGKo9tEgRqH~${G1PUBNOSTRQR}~g" \
            -e "s~Qmeu1LHnTTHNB9vex5oUwu3VVbc7uQZxMb8bYXuX56YAx2~${VAULTNSQR}~g" \
            -e "s~_NSECTAIL_~${NPRIV: -15}~g" \
            -e "s~_NOSTRVAULT_~/ipns/${NOSTRNS}~g" \
            -e "s~_MYRELAY_~${myRELAY}~g" \
            -e "s~_CAPTAINEMAIL_~${CAPTAINEMAIL}~g" \
            -e "s~_NOSTRG1PUB_~${G1PUBNOSTR}~g" \
            -e "s~_UPLANET8_~UPlanet:${UPLANETG1PUB:0:8}~g" \
            -e "s~_DATE_~$(date -u)~g" \
            -e "s~http://127.0.0.1:8080~${myIPFS}~g" \
        > ${HOME}/.zen/game/nostr/${EMAIL}/.nostr.zine.html

    NOSTRIPFS=$(ipfs --timeout 15s add -rwq ${HOME}/.zen/game/nostr/${EMAIL}/ | tail -n 1)
    ipfs name publish --key "${G1PUBNOSTR}:NOSTR" /ipfs/${NOSTRIPFS} 2>&1 >/dev/null &

    ### SEND PROFILE TO NOSTR RELAYS
    ${MY_PATH}/../tools/nostr_setup_profile.py \
        "$NPRIV" \
        "[•͡˘㇁•͡˘]" "${G1PUBNOSTR}" \
        "⏰ NOSTR Card ... 🪙 ..." \
        "$myIPFS/ipfs/${G1PUBNOSTRQR}" \
        "$myIPFS/ipfs/QmSMQCQDtcjzsNBec1EHLE78Q1S8UXGfjXmjt8P6o9B8UY/ComfyUI_00841_.jpg" \
        "" "$myIPFS/ipns/${NOSTRNS}" "" "" "" "" \
        "wss://relay.copylaradio.com" "$myRELAY"

    ## CLEAN CACHE
    rm -Rf ~/.zen/tmp/${MOATS-null}
    ### UNCOMMENT for DEBUG
    #~ echo "SALT=$SALT PEPPER=$PEPPER \
#~ NPUBLIC=${NPUBLIC} NPRIV=${NPRIV} EMAIL=${EMAIL} SSSSQR=${SSSSQR} \
#~ NOSTRG1PUB=${G1PUBNOSTR} G1PUBNOSTRQR=${G1PUBNOSTRQR} VAULTNSQR=${VAULTNSQR} NOSTRNS=${NOSTRNS} \
#~ CAPTAINEMAIL=${CAPTAINEMAIL} MOAT=$MOATS"

    echo "${HOME}/.zen/game/nostr/${EMAIL}/.nostr.zine.html"

    exit 0

else

    echo "BAD EMAIL PARAMETER"
    exit 1

fi
