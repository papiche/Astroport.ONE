#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh"

[[ -z $IPFSNODEID ]] && echo "ERROR ASTROPORT BROKEN" && exit 1
################################################################################
## Scan ~/.zen/game/nostr/[PLAYER]
## Check "G1 NOSTR" RX - ACTIVATE "NOSTRCARD"
## CREATE nostr profile
## CONTACT N1 WoT
## REFRESH N1/N2
############################################
start=`date +%s`

echo "## RUNNING NOSTR.refresh.sh
                 _
 _ __   ___  ___| |_ _ __
| '_ \ / _ \/ __| __| '__|
| | | | (_) \__ \ |_| |
|_| |_|\___/|___/\__|_|


"

[[ -z ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}

NOSTR=($(ls -t ~/.zen/game/nostr/ 2>/dev/null | grep "@" ))

# Fonction pour détruire une NOSTRCARD
destroy_nostrcard() {
    local player="$1"
    local g1pubnostr="$2"
    local secnostr="$3"
    local pubnostr="$4"
    echo "DELETE ${player} NOSTRCARD : $pubnostr"
    ## REMOVE PROFILE
    $MY_PATH/../tools/nostr_remove_profile.py "${secnostr}" "$myRELAY" "wss://relay.copylaradio.com"
    ## REMOVE MULTIPASS
    if [[ -s "${HOME}/.zen/game/players/${player}/ipfs/moa/index.html" ]]; then
        echo "/PLAYER.unplug MULTIPASS"
        ${MY_PATH}/PLAYER.unplug.sh "${HOME}/.zen/game/players/${player}/ipfs/moa/index.html" "${player}" "ALL"
    fi

    ## SEND EMAIL with G1PUBNOSTR.QR
    ${MY_PATH}/../tools/mailjet.sh "${player}" "${HOME}/.zen/game/nostr/${player}/G1PUBNOSTR.QR.png" "NOSTR Card DELETED"

    ## REMOVE NOSTR IPNS VAULT key
    ipfs name publish -k "${g1pubnostr}:NOSTR" /ipfs/QmU4cnyaKWgMVCZVLiuQaqu6yGXahjzi4F1Vcnq2SXBBmT ## "null" CID
    ipfs key rm "${g1pubnostr}:NOSTR" > /dev/null 2>&1
    ## Cleaning local cache
    rm ~/.zen/tmp/coucou/${g1pubnostr-null}.*
    rm -Rf ~/.zen/game/nostr/${player-null}
    echo "NOSTRCARD for ${player} DELETED."

}

########################################################################

## RUNING FOR ALL LOCAL PLAYERS
for PLAYER in "${NOSTR[@]}"; do
    echo "\m/_(>_<)_\m/ _______________________________________ ${PLAYER} "

    G1PUBNOSTR=$(cat ~/.zen/game/nostr/${PLAYER}/G1PUBNOSTR)
    echo ${G1PUBNOSTR}

    COINS=$($MY_PATH/../tools/COINScheck.sh ${G1PUBNOSTR} | tail -n 1)
    echo "______ AMOUNT = ${COINS} G1"

    if [[ ! -s ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal && ${COINS} != "null" ]]; then
    ################################################################ PRIMAL RX CHECK
        echo "# RX from ${G1PUBNOSTR}.... checking primal transaction..."
        milletxzero=$(${MY_PATH}/../tools/jaklis/jaklis.py history -p ${G1PUBNOSTR} -n 1000 -j | jq '.[0]')
        g1prime=$(echo $milletxzero | jq -r .pubkey)
        ### CACHE PRIMAL TX SOURCE IN "COUCOU" BUCKET
        [[ ! -z ${g1prime} && ${g1prime} != "null" ]] \
            && echo "${g1prime}" > ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal
    fi

    primal=$(cat ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal 2>/dev/null) ### PRIMAL READING
    pcoins=$($MY_PATH/../tools/COINScheck.sh ${primal} | tail -n 1) ## PRIMAL COINS

    #################################################################
    ########################## DISCO DECRYPTION
    tmp_mid=$(mktemp)
    tmp_tail=$(mktemp)
    # Decrypt the middle part using CAPTAIN key
    ${MY_PATH}/../tools/natools.py decrypt -f pubsec -i "$HOME/.zen/game/nostr/${PLAYER}/ssss.mid.captain.enc" \
            -k ~/.zen/game/players/.current/secret.dunikey -o "$tmp_mid"

    # Decrypt the tail part using UPLANET key
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.dunikey "${UPLANETNAME}" "${UPLANETNAME}"
    ${MY_PATH}/../tools/natools.py decrypt -f pubsec -i "$HOME/.zen/game/nostr/${PLAYER}/ssss.tail.uplanet.enc" \
            -k ~/.zen/game/uplanet.dunikey -o "$tmp_tail"

    rm ~/.zen/game/uplanet.dunikey

    # Combine decrypted shares
    DISCO=$(cat "$tmp_mid" "$tmp_tail" | ssss-combine -t 2 -q 2>&1)
    #~ echo "DISCO = $DISCO"
    arr=(${DISCO//[=&]/ })
    s=$(urldecode ${arr[0]} | xargs)
    salt=$(urldecode ${arr[1]} | xargs)
    p=$(urldecode ${arr[2]} | xargs)
    pepper=$(urldecode ${arr[3]} | xargs)
    if [[ $s =~ ^/.*?$ ]]; then
        [[ ! -z $s ]] \
            && rm "$tmp_mid" "$tmp_tail" \
            || { echo "DISCO DECODING ERROR"; continue; };
    else
        echo "ERROR : BAD DISCO DECODING"
        continue
    fi
    ##################################################### DISCO DECODED
    ## s=/?email
    NSEC=$(${MY_PATH}/../tools/keygen -t nostr "${salt}" "${pepper}" -s)
    NPUB=$(${MY_PATH}/../tools/keygen -t nostr "${salt}" "${pepper}")
    echo $s

    #~ EMPTY WALLET or without PRIMAL
    if [[ $(echo "$COINS > 0" | bc -l) -eq 0 || "$COINS" == "null" || "$primal" == "" ]]; then
        echo "EMPTY NOSTR CARD.............."
        ## TODATE PRESERVATION
        [[ ${TODATE} != $(cat ~/.zen/game/nostr/${PLAYER}/TODATE) ]] \
            && destroy_nostrcard "${PLAYER}" "${G1PUBNOSTR}" "${NSEC}" "${NPUB}"
        continue
    fi

    echo ">>> NOSTR PRIMAL :$pcoins: $primal"
    ## ACTIVATED NOSTR CARD
    NOSTRNS=$(cat ~/.zen/game/nostr/${PLAYER}/NOSTRNS)
    echo "IPNS VAULT : ${myIPFS}${NOSTRNS}"
    VAULTFS=$(ipfs --timeout 15s name resolve ${NOSTRNS})

    ## FILL UP NOSTRCard/PRIMAL
    if [[ ! -d ~/.zen/game/nostr/${PLAYER}/PRIMAL && ${primal} != "" && ${primal} != "null" ]]; then

        mkdir -p ~/.zen/game/nostr/${PLAYER}/PRIMAL
        ## SCAN CESIUM/GCHANGE PRIMAL STATUS
        ${MY_PATH}/../tools/GetGCAttributesFromG1PUB.sh ${primal}
        #######################################################################
        ## COPY PRIMAL DUNITER/CESIUM METADATA (from "coucou" cache)
        cp ~/.zen/tmp/coucou/${primal}* ~/.zen/game/nostr/${PLAYER}/PRIMAL/
        echo ${primal} > ~/.zen/game/nostr/${PLAYER}/G1PRIME

    fi

    ## REAL UPASSPORT ?
    if [[ ! -s ~/.zen/game/passport/${primal} ]]; then
        ## PRIMAL EXISTS ?
        if [[ ${primal} != "" && ${primal} != "null" ]]; then
            ## MAKE /upassport API make /PRIMAL/_upassport.html
            if [[ ! -s ~/.zen/game/nostr/${PLAYER}/PRIMAL/_upassport.html ]]; then
                echo "CREATING UPASSPORT FOR PRIMAL=${primal}"
                curl -s -X POST -F "parametre=${primal}" http://127.0.0.1:54321/upassport \
                    > ~/.zen/game/nostr/${PLAYER}/PRIMAL/_upassport.html
                [[ ! $? -eq 0 ]] \
                    && rm ~/.zen/game/nostr/${PLAYER}/PRIMAL/_upassport.html 2>/dev/null
                ## GET UPassport /N1
                if [[ -d ~/.zen/UPassport/pdf/${primal}/N1 ]]; then
                    cp -Rf ~/.zen/UPassport/pdf/${primal}/N1 \
                        ~/.zen/game/nostr/${PLAYER}/PRIMAL/
                fi
            else
                echo "## PRIMAL UPassport already existing"
                ls ~/.zen/game/nostr/${PLAYER}/PRIMAL/
            fi
        fi
    else
        echo "## REAL UPASSPORT : ${primal} is STATION co OWNER !!"
    fi

    ######### NOSTR PROFILE ACTIVE : CREATING UPASSPORT
    if [[ ! -s ~/.zen/game/nostr/${PLAYER}/nostr_setup_profile ]]; then
        echo "######################################## STEP 1"
        echo "## NOSTR PROFILE PRIMAL LINKING"
        ls ~/.zen/game/nostr/${PLAYER}/PRIMAL/

        ## EXTACT PRIMAL CESIUM PROFILE
        zlat=$(cat ~/.zen/game/nostr/${PLAYER}/PRIMAL/${primal}.cesium.json 2>/dev/null | jq -r ._source.geoPoint.lat)
        LAT=$(makecoord $zlat)
        zlon=$(cat ~/.zen/game/nostr/${PLAYER}/PRIMAL/${primal}.cesium.json 2>/dev/null | jq -r ._source.geoPoint.lon)
        LON=$(makecoord $zlon)
        title=$(cat ~/.zen/game/nostr/${PLAYER}/PRIMAL/${primal}.cesium.json 2>/dev/null | jq -r ._source.title)
        [[ -z $title ]] && title="$PLAYER"
        city=$(cat ~/.zen/game/nostr/${PLAYER}/PRIMAL/${primal}.cesium.json 2>/dev/null | jq -r ._source.city)
        [[ -z $city ]] && city="UPlanet"
        description=$(cat ~/.zen/game/nostr/${PLAYER}/PRIMAL/${primal}.cesium.json 2>/dev/null | jq -r ._source.description)
        [[ -z $description ]] && description="Nostr Card"

        ## GET CESIUM AVATAR
        if [[ -s "$HOME/.zen/tmp/coucou/${G1PUB}.cesium.avatar.png" ]]; then
            zavatar="/ipfs/"$(ipfs --timeout 10s add -q "$HOME/.zen/tmp/coucou/${G1PUB}.cesium.avatar.png" 2>/dev/null)
        else
        ## OR NOSTR(+PICTURE) G1PUB QRCODE
            zavatar="/ipfs/"$(cat ${HOME}/.zen/game/nostr/${PLAYER}/G1PUBNOSTR.QR.png.cid 2>/dev/null)
        fi
        ## ELSE ASTROPORT LOGO
        [[ $zavatar == "/ipfs/" ]] \
            && zavatar="/ipfs/QmbMndPqRHtrG2Wxtzv6eiShwj3XsKfverHEjXJicYMx8H/logo.png"

        g1pubnostr=$(cat ${HOME}/.zen/game/nostr/${PLAYER}/G1PUBNOSTR)
        ### SEND PROFILE TO NOSTR RELAYS
        ${MY_PATH}/../tools/nostr_setup_profile.py \
            "$NSEC" \
            "$title" "$g1pubnostr:$primal" \
            "$description - $city" \
            "$myIPFS/ipfs/$zavatar" \
            "$myIPFS/ipfs/QmX1TWhFZwVFBSPthw1Q3gW5rQc1Gc4qrSbKj4q1tXPicT/P2Pmesh.jpg" \
            "" "$myIPFS/ipns/${NOSTRNS}" "" "" "" "" \
            "wss://relay.copylaradio.com" "$myRELAY" \
            --ipfs_gw "$myIPFS" \
            > ~/.zen/game/nostr/${PLAYER}/nostr_setup_profile

        ## DOES COMMAND SUCCEED ?
        [[ ! $? -eq 0 ]] \
            && rm ~/.zen/game/nostr/${PLAYER}/nostr_setup_profile 2>/dev/null

        ## RECORD GPS (for ZenCard activation)
        echo "LAT=$LAT; LON=$LON;" > ~/.zen/game/nostr/${PLAYER}/GPS

        ## HEX COMPARE
        #~ cat ~/.zen/game/nostr/${PLAYER}/nostr_setup_profile 2>/dev/null
        #~ cat ~/.zen/game/nostr/${PLAYER}/HEX 2>/dev/null

        ## ADD CORACLE to NOSTRVAULT
        echo "<meta http-equiv=\"refresh\" content=\"0; url='${CORACLEIPFS}'\" />CORACLE : ${PLAYER}" \
                > ~/.zen/game/nostr/${PLAYER}/coracle.html

    else
        echo "########################################## STEP 2"
        echo "## Nostr Card PROFILE EXISTING"
        cat ~/.zen/game/nostr/${PLAYER}/nostr_setup_profile
        HEX=$(cat ~/.zen/game/nostr/${PLAYER}/HEX)

        ## CREATE UPlanet AstroID + ZenCard using EMAIL and GPS ###########
        if [[ ! -d ~/.zen/game/players/${PLAYER} ]]; then
            echo "## MULTIPASS ZenCard creation "
            source ~/.zen/game/nostr/${PLAYER}/GPS
            PPASS=$(${MY_PATH}/../tools/diceware.sh $(( $(${MY_PATH}/../tools/getcoins_from_gratitude_box.sh) + 3 )) | xargs)
            NPASS=$(${MY_PATH}/../tools/diceware.sh $(( $(${MY_PATH}/../tools/getcoins_from_gratitude_box.sh) + 3 )) | xargs)

            ## CREATE ASTRONAUTE TW ZENCARD
            echo "${PLAYER}" "UPlanet" "fr" "${LAT}" "${LON}"
            ${MY_PATH}/../RUNTIME/VISA.new.sh "${PPASS}" "${NPASS}" "${PLAYER}" "UPlanet" "fr" "${LAT}" "${LON}" "$NPUB" "$HEX"

        else

            echo "MULTIPASS ZenCard existing : ~/.zen/game/players/${PLAYER}"
            $(${MY_PATH}/../tools/search_for_this_email_in_players.sh ${PLAYER} | tail -n 1)
            ## Inject new NOSTR EVENTS into TW


        fi
    fi


    ## UPDATE IPNS NOSTRVAULT KEY  (SIDE STORAGE)
    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/nostr.ipns "${salt}" "${pepper}"
    ipfs key rm "${G1PUBNOSTR}:NOSTR" > /dev/null 2>&1
    NOSTRNS=$(ipfs key import "${G1PUBNOSTR}:NOSTR" -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/nostr.ipns)
    echo "${G1PUBNOSTR}:NOSTR ${PLAYER} STORAGE: /ipns/$NOSTRNS"
    ## UPDATE IPNS RESOLVE
    NOSTRIPFS=$(ipfs add -rwq ${HOME}/.zen/game/nostr/${PLAYER}/ | tail -n 1)
    ipfs name publish --key "${G1PUBNOSTR}:NOSTR" /ipfs/${NOSTRIPFS} 2>&1 >/dev/null &
    ## TODO : REMOVE from 5001 API
    #~ ipfs key rm "${G1PUBNOSTR}:NOSTR" > /dev/null 2>&1

    echo "___________________________________________________"
    sleep 1

done

end=`date +%s`
dur=`expr $end - $start`
hours=$((dur / 3600)); minutes=$(( (dur % 3600) / 60 )); seconds=$((dur % 60))
echo "DURATION ${hours} hours ${minutes} minutes ${seconds} seconds"
echo "============================================ NOSTR.refresh DONE."

exit 0
