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

NOSTR=($(ls -t ~/.zen/game/nostr/  | grep "@" 2>/dev/null))

# Fonction pour détruire une NOSTRCARD
destroy_nostrcard() {
    local player="$1"
    local g1pubnostr="$2"
    echo "DESTROYING NOSTRCARD for ${player}..."
    ipfs key rm "${g1pubnostr}:NOSTR" > /dev/null 2>&1
    rm ~/.zen/tmp/coucou/${g1pubnostr}.*
    rm -Rf ~/.zen/game/nostr/${player}
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
    primal=$(cat ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal 2>/dev/null) ### CACHE READING

    #~ EMPTY WALLET ???
    if [[ $(echo "$COINS > 0" | bc -l) -eq 1 ]]; then
        echo "EMPTY NOSTR CARD.............."
        destroy_nostrcard "${PLAYER}" "${G1PUBNOSTR}"
        continue
    else
        ################################################################ PRIMAL TX CHECK
        echo "# RX from ${G1PUBNOSTR}.... checking primal transaction..."
        ### jaklis 1000 history window
        if [[ ! -s ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal ]]; then
            milletxzero=$(${MY_PATH}/../tools/jaklis/jaklis.py history -p ${G1PUBNOSTR} -n 1000 -j | jq '.[0]')
            g1prime=$(echo $milletxzero | jq -r .pubkey)
            ### CACHE PRIMAL TX SOURCE IN "COUCOU" BUCKET
            [[ ! -z ${g1prime} && ${g1prime} != "null" ]] && echo "${g1prime}" > ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal
        fi
        primal=$(cat ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal 2>/dev/null) ### CACHE READING
    fi

    ## ACTIVATED NOSTR CARD
    NOSTRNS=$(cat ~/.zen/game/nostr/${PLAYER}/NOSTRNS)
    echo "NOSTR VAULT IPNS : ${myIPFS}${NOSTRNS}"
    VAULTFS=$(ipfs --timeout 3s name resolve ${NOSTRNS})

    if [[ -z ${VAULTFS} ]]; then
        echo "VAULTFS KEY EMPTY !!!!!!! ${G1PUBNOSTR}:NOSTR"
        destroy_nostrcard "${PLAYER}" "${G1PUBNOSTR}"
        continue
    fi

    ## NOSTR CARD OPENING
    if [[ ! -z ${VAULTFS} ]]; then
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
    echo "DISCO = $DISCO"
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
        echo "BAD DISCO FORMAT"
        continue
    fi
    ##################################################### DISCO REVEALED
    ## s=/?email
    echo $s
    echo $salt $pepper

    ## CHECK PRIMAL
    if [[ ! -d ~/.zen/game/nostr/${PLAYER}/PRIMAL && ${primal} != "" && ${primal} != "null" ]]; then

        mkdir -p ~/.zen/game/nostr/${PLAYER}/PRIMAL
        ## SCAN CESIUM/GCHANGE PRIMAL STATUS
        ${MY_PATH}/../tools/GetGCAttributesFromG1PUB.sh ${primal}
        cp ~/.zen/tmp/coucou/${primal}* ~/.zen/game/nostr/${PLAYER}/PRIMAL/
        ## IS PRIMAL CESIUM+
        [[ -s ~/.zen/game/nostr/${PLAYER}/PRIMAL/${primal}.cesium.json ]] \
            && rm ~/.zen/game/nostr/${PLAYER}/_index.html ## REMOVE NOSTR ZINE (should habe been printed by MEMBER)
    fi

    ## UPASSPORT N1 SCAN primal
    if [[ ${primal} != "" && ${primal} != "null" ]]; then
        echo "CREATING UPASSPORT FOR PRIMAL=${primal}"
        ## APPEL /upassport API
        curl_output=$(curl -s -X POST \
        -F "parametre=${primal}" \
        http://127.0.0.1:54321/upassport)

        # Check if the curl command succeeded and returned a valid HTML response
        if [[ $? -eq 0 && "$curl_output" != *"error"* ]]; then
          echo "UPASSPORT API call successful, saving output."
          echo "$curl_output" > ~/.zen/game/nostr/${PLAYER}/_index.html
        else
          echo "ERROR: UPASSPORT API call failed or returned an error."
          echo "ERROR OUTPUT : $curl_output"
        fi
    fi

    ## CREATE IPNS NOSTRVAULT KEY  (SIDE STORAGE)
    [[ -z ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    mkdir -p ~/.zen/tmp/${MOATS}
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
