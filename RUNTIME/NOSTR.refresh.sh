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
## Scan ~/.zen/game/nostr/[EMAIL]
## Check "G1 NOSTR" RX - ACTIVATE "NOSTRCARD"
## CREATE nostr profile
## CONTACT N1 WoT
## REFRESH N1/N2
############################################
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
    echo "DESTROYING NOSTRCARD for ${player}..."
    ## PUBLISH null
    ipfs name publish -k "${g1pubnostr}:NOSTR" /ipfs/QmU4cnyaKWgMVCZVLiuQaqu6yGXahjzi4F1Vcnq2SXBBmT
    ## Remove IPNS key
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

    if [[ ! -s ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal ]]; then
    ################################################################ PRIMAL TX CHECK
        echo "# RX from ${G1PUBNOSTR}.... checking primal transaction..."
        milletxzero=$(${MY_PATH}/../tools/jaklis/jaklis.py history -p ${G1PUBNOSTR} -n 1000 -j | jq '.[0]')
        g1prime=$(echo $milletxzero | jq -r .pubkey)
        ### CACHE PRIMAL TX SOURCE IN "COUCOU" BUCKET
        [[ ! -z ${g1prime} && ${g1prime} != "null" ]] && echo "${g1prime}" > ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal
    fi

    primal=$(cat ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal 2>/dev/null) ### PRIMAL READING
    pcoins=$($MY_PATH/../tools/COINScheck.sh ${primal} | tail -n 1) ## PRIMAL COINS

    #~ EMPTY WALLET or without primal
    if [[ $(echo "$COINS > 0" | bc -l) -eq 0 || "$COINS" == "null" || "$primal" == "" ]]; then
        echo "EMPTY NOSTR CARD.............."
        destroy_nostrcard "${PLAYER}" "${G1PUBNOSTR}"
        continue
    fi

    echo "PRIMAL :$pcoins: $primal"
    ## ACTIVATED NOSTR CARD
    NOSTRNS=$(cat ~/.zen/game/nostr/${PLAYER}/NOSTRNS)
    echo "NOSTR VAULT IPNS : ${myIPFS}${NOSTRNS}"
    VAULTFS=$(ipfs --timeout 15s name resolve ${NOSTRNS})

    if [[ -z ${VAULTFS} ]]; then
        echo "VAULTFS KEY EMPTY !!!!!!! ${G1PUBNOSTR}:NOSTR"
        destroy_nostrcard "${PLAYER}" "${G1PUBNOSTR}"
        continue
    else
        echo "NOSTRVAULT updating : ${VAULTFS}"
        ipfs get ${VAULTFS} -o ~/.zen/game/nostr/
        ls ~/.zen/game/nostr/${PLAYER}
    fi

    ########################## DISCO DECRYPTION
    tmp_mid=$(mktemp)
    tmp_tail=$(mktemp)
    # Decrypt the middle part using CAPTAING1PUB key
    ${MY_PATH}/../tools/natools.py decrypt -f pubsec -i "$HOME/.zen/game/nostr/${PLAYER}/ssss.mid.captain.enc" \
            -k ~/.zen/game/players/.current/secret.dunikey -o "$tmp_mid"

    # Decrypt the tail part using UPLANETNAME
    cat ~/.zen/game/nostr/${PLAYER}/ssss.tail.uplanet.asc | gpg -d --batch --passphrase "$UPLANETNAME" > "$tmp_tail"

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
    echo $s

    ## CHECK PRIMAL
    if [[ ! -d ~/.zen/game/nostr/${PLAYER}/PRIMAL && ${primal} != "" && ${primal} != "null" ]]; then

        mkdir -p ~/.zen/game/nostr/${PLAYER}/PRIMAL
        ## SCAN CESIUM/GCHANGE PRIMAL STATUS
        ${MY_PATH}/../tools/GetGCAttributesFromG1PUB.sh ${primal}
        #######################################################################
        ## COPY PRIMAL DUNITER/CESIUM METADATA
        cp ~/.zen/tmp/coucou/${primal}* ~/.zen/game/nostr/${PLAYER}/PRIMAL/
        ## IS PRIMAL CESIUM+
        [[ -s ~/.zen/game/nostr/${PLAYER}/PRIMAL/${primal}.cesium.json ]] \
            && rm ~/.zen/game/nostr/${PLAYER}/zine.html ## REMOVE NOSTR ZINE
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
                ${MY_PATH}/../tools/mailjet.sh "${PLAYER}" \
                    ~/.zen/game/nostr/${PLAYER}/PRIMAL/_upassport.html \
                    "UPassport / UPLanet ${UPLANETG1PUB:0:8} / ($CAPTAINEMAIL)"
            else
                ## UPassport is fac simile
                ${MY_PATH}/../tools/mailjet.sh "${PLAYER}" \
                    ~/.zen/game/nostr/${PLAYER}/PRIMAL/_upassport.html \
                    "PLEASE ACTIVATE UPASSPORT"
            fi
        fi
    fi

    echo "## CREATE NOSTR PROFILE"
    NSEC=$(${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/nostr.ipns "${salt}" "${pepper}" -s)

    if [[ ! -s ~/.zen/game/nostr/${PLAYER}/setup_nostr_profile ]]; then
        echo "## NOSTR PROFILE CREATION..."
        ls ~/.zen/game/nostr/${PLAYER}/PRIMAL/
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
        zavatar="/ipfs/$(cat ${HOME}/.zen/game/nostr/${PLAYER}/G1PUBNOSTR.QR.png.cid 2>/dev/null)"
        [[ $zavatar == "/ipfs/" ]] \
            && zavatar="/ipfs/QmbMndPqRHtrG2Wxtzv6eiShwj3XsKfverHEjXJicYMx8H/logo.png"

        ## DEBUG
        echo "$NSEC" \
            "$primal" "$title" "$description - $city" \
            "$myIPFS/ipfs/$zavatar" \
            "$myIPFS/ipfs/QmX1TWhFZwVFBSPthw1Q3gW5rQc1Gc4qrSbKj4q1tXPicT/P2Pmesh.jpg" \
            "" "" "" "" "" "" \
            "wss://relay.copylaradio.com" "wss://relay.g1sms.fr" "wss://relay.primal.net"

        ${MY_PATH}/../tools/setup_nostr_profile.py \
            "$NSEC" \
            "$primal" "$title" "$description - $city" \
            "$myIPFS/ipfs/$zavatar" \
            "$myIPFS/ipfs/QmX1TWhFZwVFBSPthw1Q3gW5rQc1Gc4qrSbKj4q1tXPicT/P2Pmesh.jpg" \
            "" "" "" "" "" "" \
            "wss://relay.copylaradio.com" "wss://relay.g1sms.fr" "wss://relay.primal.net" \
            > ~/.zen/game/nostr/${PLAYER}/setup_nostr_profile
        ## RECORD GPS
        echo "LAT=$LAT; LON=$LON;" > ~/.zen/game/nostr/${PLAYER}/GPS

        ## HEX
        cat ~/.zen/game/nostr/${PLAYER}/setup_nostr_profile
        cat ~/.zen/game/nostr/${PLAYER}/HEX

    else

        echo "## Nostr Card PROFILE ALREADY EXISTING"
        cat ~/.zen/game/nostr/${PLAYER}/setup_nostr_profile

        #~ if [[ ! -d ~/.zen/game/players/${PLAYER} ]];
            #~ ## CREATE UPlanet ZenCard with GPS
            #~ source ~/.zen/game/nostr/${PLAYER}/GPS
            #~ PPASS=$(${MY_PATH}/../tools/diceware.sh $(( $(${MY_PATH}/../tools/getcoins_from_gratitude_box.sh) + 3 )) | xargs)
            #~ NPASS=$(${MY_PATH}/../tools/diceware.sh $(( $(${MY_PATH}/../tools/getcoins_from_gratitude_box.sh) + 3 )) | xargs)

            #~ ## CREATE ASTRONAUTE TW ZENCARD
            #~ echo VISA.new.sh "${PPASS}" "${NPASS}" "${PLAYER}" "UPlanet" "fr" "${LAT}" "${LON}"
            #~ ${MY_PATH}/../RUNTIME/VISA.new.sh "${PPASS}" "${NPASS}" "${PLAYER}" "UPlanet" "fr" "${LAT}" "${LON}"

        #~ else
            #~ echo "ZENCARD EXISTING"
            #~ ls ~/.zen/game/players/${PLAYER}

        #~ fi
    fi


    ## CREATE IPNS NOSTRVAULT KEY  (SIDE STORAGE)
    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/nostr.ipns "${salt}" "${pepper}"
    ipfs key rm "${G1PUBNOSTR}:NOSTR" > /dev/null 2>&1
    NOSTRNS=$(ipfs key import "${G1PUBNOSTR}:NOSTR" -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/nostr.ipns)
    echo "${G1PUBNOSTR}:NOSTR ${EMAIL} STORAGE: /ipns/$NOSTRNS"
    ## UPDATE IPNS RESOLVE
    NOSTRIPFS=$(ipfs add -rwq ${HOME}/.zen/game/nostr/${EMAIL}/ | tail -n 1)
    ipfs name publish --key "${G1PUBNOSTR}:NOSTR" /ipfs/${NOSTRIPFS} 2>&1 >/dev/null &

    echo "___________________________________________________"
    sleep 1

done

echo "============================================ NOSTR.refresh DONE."

exit 0
