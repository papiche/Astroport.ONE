################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
## API: QRCODE - ANY/MULTI KEY OPERATIONS
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"

EMAIL="$1"
IMAGE="$2"

echo "Email detected: $EMAIL"
[[ -s "~/.zen/tmp/${MOATS}/${EMAIL}_index.html" ]] \
    && rm -Rf "${HOME}/.zen/game/nostr/${EMAIL}/" ## CLEANING OLD NOSTR

[[ -z ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}/

if [[ $EMAIL =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    ############################################## PREPARE SALT PEPPER
    SALT=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w42 | head -n1)
    PEPPER=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w42 | head -n1)
    # Creating a NOSTRCARD for ${EMAIL}
    DISCO="/?${EMAIL}=${SALT}&nostr=${PEPPER}"
    echo "DISCO : "$DISCO

    ## ssss-split : Keep 2 needed over 3
    echo "$DISCO" | ssss-split -t 2 -n 3 -q > ~/.zen/tmp/${MOATS}/${EMAIL}.ssss
    HEAD=$(cat ~/.zen/tmp/${MOATS}/${EMAIL}.ssss | head -n 1) && echo "$HEAD" > ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.head
    MIDDLE=$(cat ~/.zen/tmp/${MOATS}/${EMAIL}.ssss | head -n 2 | tail -n 1) && echo "$MIDDLE" > ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.mid
    TAIL=$(cat ~/.zen/tmp/${MOATS}/${EMAIL}.ssss | tail -n 1) && echo "$TAIL" > ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.tail
    echo "TEST DECODING..."
    echo "$HEAD
    $TAIL" | ssss-combine -t 2 -q
    [ ! $? -eq 0 ] && echo "ERROR! SSSSKEY DECODING FAILED" && echo "${MY_PATH}/templates/wallet.html" && exit 1

    # 1. Generate a DISCO Nostr key pair
    NPRIV=$(${MY_PATH}/tools/keygen -t nostr "${SALT}" "${PEPPER}" -s)
    NPUBLIC=$(${MY_PATH}/tools/keygen -t nostr "${SALT}" "${PEPPER}")
    echo "Nostr Private Key: $NPRIV"
    echo "Nostr Public Key: $NPUBLIC"

    # 2. Store the keys in a file or a secure place (avoid printing them to console if possible)
    echo "$NPRIV" > ~/.zen/tmp/${MOATS}/${EMAIL}.nostr.priv
    echo "$NPUBLIC" > ~/.zen/tmp/${MOATS}/${EMAIL}.nostr.pub

    # Create an G1CARD : G1Wallet waiting for G1 to make key batch running
    ${MY_PATH}/tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/${EMAIL}.g1card.dunikey "${SALT}" "${PEPPER}"
    G1PUBNOSTR=$(cat ~/.zen/tmp/${MOATS}/${EMAIL}.g1card.dunikey  | grep 'pub:' | cut -d ' ' -f 2)
    echo "G1NOSTR _WALLET: $G1PUBNOSTR"
    mkdir -p ${HOME}/.zen/game/nostr/${EMAIL}/
    [[ -s ${IMAGE} ]] && cp ${IMAGE} ${HOME}/.zen/game/nostr/${EMAIL}/picture.png

    ##########################################################################
    ### CRYPTO ZONE
    ## ENCODE HEAD SSSS SECRET WITH G1PUBNOSTR PUBKEY
    echo "${MY_PATH}/tools/natools.py encrypt -p $G1PUBNOSTR -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.head -o ${HOME}/.zen/game/nostr/${EMAIL}/ssss.nostr.enc"
    ${MY_PATH}/tools/natools.py encrypt -p $G1PUBNOSTR -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.head -o ${HOME}/.zen/game/nostr/${EMAIL}/ssss.head.nostr.enc

    ## DISCO MIDDLE ENCRYPT WITH CAPTAING1PUB
    echo "${MY_PATH}/tools/natools.py encrypt -p $CAPTAING1PUB -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.mid -o ${HOME}/.zen/game/nostr/${EMAIL}/ssss.mid.captain.enc"
    ${MY_PATH}/tools/natools.py encrypt -p $CAPTAING1PUB -i ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.mid -o ${HOME}/.zen/game/nostr/${EMAIL}/ssss.mid.captain.enc

    ## DISCO TAIL ENCRYPT WITH UPLANETNAME
    cat ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.tail | gpg --symmetric --armor --batch --passphrase "${UPLANETNAME}" -o ${HOME}/.zen/game/nostr/${EMAIL}/ssss.tail.uplanet.asc
    cat ${HOME}/.zen/game/nostr/${EMAIL}/ssss.tail.uplanet.asc | gpg -d --passphrase "${UPLANETNAME}" --batch > ~/.zen/tmp/${MOATS}/${G1PUBNOSTR}.ssss.test
    [[ $(diff -q ~/.zen/tmp/${MOATS}/${G1PUBNOSTR}.ssss.test ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.tail) != "" ]] && echo "ERROR: GPG ENCRYPTION FAILED !!!"
    rm ~/.zen/tmp/${MOATS}/${G1PUBNOSTR}.ssss.test

    ## CREATE IPNS KEY (SIDE STORAGE)
    ${MY_PATH}/tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/${MOATS}.nostr.ipns "${SALT}" "${PEPPER}"
    ipfs key rm "${G1PUBNOSTR}:NOSTR" > /dev/null 2>&1
    NOSTRNS=$(ipfs key import "${G1PUBNOSTR}:NOSTR" -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/${MOATS}.nostr.ipns)
    echo "${G1PUBNOSTR}:NOSTR ${EMAIL} STORAGE: /ipns/$NOSTRNS"
    echo "/ipns/$NOSTRNS" > ${HOME}/.zen/game/nostr/${EMAIL}/NOSTRNS

    amzqr "${ipfsNODE}/ipns/$NOSTRNS" -l H -p ${MY_PATH}/static/img/no_str.png -c -n ${G1PUBNOSTR}.IPNS.QR.png -d ~/.zen/tmp/${MOATS}/ 2>/dev/null
    convert ~/.zen/tmp/${MOATS}/${G1PUBNOSTR}.IPNS.QR.png \
        -gravity SouthWest \
        -pointsize 18 \
        -fill black \
        -annotate +2+2 "[APP] $NOSTRNS" \
        -annotate +1+3 "[APP] $NOSTRNS" \
        ${HOME}/.zen/game/nostr/${EMAIL}/IPNS.QR.png

    VAULTNSQR=$(ipfs add -q ${HOME}/.zen/game/nostr/${EMAIL}/IPNS.QR.png)
    ipfs pin rm /ipfs/${VAULTNSQR}

    ## HEAD SSSS CLEAR
    amzqr "$(cat ~/.zen/tmp/${MOATS}/${EMAIL}.ssss.head)" -l H -p ${MY_PATH}/static/img/key.png -c -n ${EMAIL}.QR.png -d ~/.zen/tmp/${MOATS}/ 2>/dev/null
    SSSSQR=$(ipfs add -q ~/.zen/tmp/${MOATS}/${EMAIL}.QR.png)
    ipfs pin rm /ipfs/${SSSSQR}

    ## Create G1PUBNOSTR QR Code
    amzqr "${G1PUBNOSTR}" -l H -p ${MY_PATH}/static/img/nature_cloud_face.png -c -n G1PUBNOSTR.QR.png -d ~/.zen/tmp/${MOATS}/ 2>/dev/null
    echo "${G1PUBNOSTR}" > ${HOME}/.zen/game/nostr/${EMAIL}/G1PUBNOSTR
    convert ~/.zen/tmp/${MOATS}/G1PUBNOSTR.QR.png \
            -gravity SouthWest \
            -pointsize 18 \
            -fill black \
            -annotate +2+2 "${G1PUBNOSTR}" \
            -annotate +1+3 "${G1PUBNOSTR}" \
            ${HOME}/.zen/game/nostr/${EMAIL}/G1PUBNOSTR.QR.png

    G1PUBNOSTRQR=$(ipfs add -q ${HOME}/.zen/game/nostr/${EMAIL}/G1PUBNOSTR.QR.png)
    ipfs pin rm /ipfs/${G1PUBNOSTRQR}

    NOSTRIPFS=$(ipfs add -rwq ${HOME}/.zen/game/nostr/${EMAIL}/ | tail -n 1)
    ipfs name publish --key "${G1PUBNOSTR}:NOSTR" /ipfs/${NOSTRIPFS} 2>&1 >/dev/null &

    echo "NPUBLIC=${NPUBLIC} NPRIV=${NPRIV} EMAIL=${EMAIL} SSSSQR=${SSSSQR} \
    NOSTRG1PUB=${G1PUBNOSTR} G1PUBNOSTRQR=${G1PUBNOSTRQR} VAULTNSQR=${VAULTNSQR} NOSTRNS=${NOSTRNS} \
    CAPTAINEMAIL=${CAPTAINEMAIL} MOAT=$MOATS"

    exit 0

else

    echo "BAD EMAIL PARAMETER"
    exit 1

fi
