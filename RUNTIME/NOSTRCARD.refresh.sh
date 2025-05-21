#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh"

[[ -z ${IPFSNODEID} ]] && echo "ERROR ASTROPORT BROKEN" && exit 1
################################################################################
## Scan ~/.zen/game/nostr/[PLAYER]
## Check "G1 NOSTR" RX - ACTIVATE "NOSTRCARD"
## CREATE nostr profile
## CONTACT N1 WoT
## REFRESH N1/N2
############################################
start=`date +%s`

echo "## RUNNING NOSTRCARD.refresh.sh
                 _
 _ __   ___  ___| |_ _ __
| '_ \ / _ \/ __| __| '__|
| | | | (_) \__ \ |_| |
|_| |_|\___/|___/\__|_|


"

[[ -z ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}

# Fonction pour détruire une NOSTRCARD
destroy_nostrcard() {
    local player="$1"
    local g1pubnostr="$2"
    local secnostr="$3"
    local pubnostr="$4"
    echo "DELETING ${player} NOSTRCARD : $pubnostr"

    ## 1. REMOVE NOSTR PROFILE
    $MY_PATH/../tools/nostr_remove_profile.py "${secnostr}" "$myRELAY" "wss://relay.copylaradio.com"

    ## 2. REMOVE MULTIPASS
    if [[ -s "${HOME}/.zen/game/players/${player}/ipfs/moa/index.html" ]]; then
        echo "/PLAYER.unplug MULTIPASS"
        ${MY_PATH}/PLAYER.unplug.sh "${HOME}/.zen/game/players/${player}/ipfs/moa/index.html" "${player}" "ALL"
    fi

    ## SEND EMAIL with G1PUBNOSTR.QR
    ${MY_PATH}/../tools/mailjet.sh "${player}" "${HOME}/.zen/game/nostr/${player}/G1PUBNOSTR.QR.png" "... INVALID NOSTR Card ..."

    ## REMOVE NOSTR IPNS VAULT key
    ipfs name publish -k "${g1pubnostr}:NOSTR" $(cat "${HOME}/.zen/game/nostr/${player}/G1PUBNOSTR.QR.png.cid") ## "G1QR" CID
    ipfs key rm "${g1pubnostr}:NOSTR" > /dev/null 2>&1
    ## Cleaning local cache
    rm ~/.zen/tmp/coucou/${g1pubnostr-null}.*
    rm -Rf ~/.zen/game/nostr/${player-null}
    echo "NOSTRCARD for ${player} DELETED."

}

########################################################################
# NOSTR Card is evolving depending PRIMAL RX source.
# on UPLanet ORIGIN or UPlanet Zen.
########################################################################
NOSTR=($(ls -t ~/.zen/game/nostr/ 2>/dev/null | grep "@" ))

## RUNING FOR ALL LOCAL NOSTR CARDS
for PLAYER in "${NOSTR[@]}"; do
    HEX=$(cat ~/.zen/game/nostr/${PLAYER}/HEX)
    echo "\m/_(>_<)_\m/ ___________________ ${PLAYER} : ${HEX}"

    ## SWARM CACHE PUBLISHING
    if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/HEX ]]; then
        mkdir -p ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}
        echo "$HEX" > ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/HEX
    fi
    if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/GPS ]]; then
        mkdir -p ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}
        cp ${HOME}/.zen/game/nostr/${PLAYER}/GPS ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/GPS 2>/dev/null
    fi

    [[ $(cat ${HOME}/.zen/game/nostr/${PLAYER}/.todate 2>/dev/null) == ${TODATE} ]] \
        && [[ $(cat ${HOME}/.zen/game/nostr/${PLAYER}/TODATE) != ${TODATE} ]] \
            && echo "BIRTHDAY=$(cat ${HOME}/.zen/game/nostr/${PLAYER}/TODATE 2>/dev/null)" \
            && continue # already published today & not 1st day

    G1PUBNOSTR=$(cat ~/.zen/game/nostr/${PLAYER}/G1PUBNOSTR)
    COINS=$($MY_PATH/../tools/COINScheck.sh ${G1PUBNOSTR} | tail -n 1)
    ZEN=$(echo "($COINS - 1) * 10" | bc | cut -d '.' -f 1)
    echo "${G1PUBNOSTR} ______ AMOUNT = ${COINS} G1 -> ${ZEN} ZEN"

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

    ############################################################################
    ###################### DISCO DECRYPTION - with Captain + UPlanet parts
    if [[ ! -s ~/.zen/game/nostr/${PLAYER}/.secret.disco ]]; then
        tmp_mid=$(mktemp)
        tmp_tail=$(mktemp)
        # Decrypt the middle part using CAPTAIN key
        ${MY_PATH}/../tools/natools.py decrypt -f pubsec -i "$HOME/.zen/game/nostr/${PLAYER}/ssss.mid.captain.enc" \
                -k ~/.zen/game/players/.current/secret.dunikey -o "$tmp_mid"

        # Decrypt the tail part using UPLANET dunikey
        ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.dunikey "${UPLANETNAME}" "${UPLANETNAME}"
        ${MY_PATH}/../tools/natools.py decrypt -f pubsec -i "$HOME/.zen/game/nostr/${PLAYER}/ssss.tail.uplanet.enc" \
                -k ~/.zen/game/uplanet.dunikey -o "$tmp_tail"

        ## Keep UPlanet Dunikey
        chmod 600 ~/.zen/game/uplanet.dunikey

        # Combine decrypted shares
        DISCO=$(cat "$tmp_mid" "$tmp_tail" | ssss-combine -t 2 -q 2>&1 | tail -n 1)
    else
        DISCO=$(cat ~/.zen/game/nostr/${PLAYER}/.secret.disco)
    fi
    #~ echo "DISCO = $DISCO" ## DEBUG
    IFS='=&' read -r s salt p pepper <<< "$DISCO"

    if [[ -n $pepper ]]; then
        rm "$tmp_mid" "$tmp_tail"
        rm ~/.zen/game/nostr/${PLAYER}/ERROR 2>/dev/null
    else
        echo "ERROR : BAD DISCO DECODING" >> ~/.zen/game/nostr/${PLAYER}/ERROR
        continue
    fi
    ##################################################### DISCO DECODED
    BIRTHDATE=$(cat ~/.zen/game/nostr/${PLAYER}/TODATE)
    ## s=/?email
    NSEC=$(${MY_PATH}/../tools/keygen -t nostr "${salt}" "${pepper}" -s)
    NPUB=$(${MY_PATH}/../tools/keygen -t nostr "${salt}" "${pepper}")
    echo $s

    ## CACHING SECRET & DISCO to NOSTR Card (.file = no ipfs !!)
    [[ ! -s ~/.zen/game/nostr/${PLAYER}/.secret.nostr ]] \
        && echo "NSEC=$NSEC; NPUB=$NPUB; HEX=$HEX;" > ~/.zen/game/nostr/${PLAYER}/.secret.nostr \
        && echo "$DISCO" > ~/.zen/game/nostr/${PLAYER}/.secret.disco \
        && chmod 600 ~/.zen/game/nostr/${PLAYER}/.secret*

    mkdir -p ~/.zen/tmp/${MOATS}
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/nostr.${PLAYER}.dunikey "${salt}" "${pepper}"
    ########################################################################
    #~ EMPTY WALLET or without PRIMAL or COIN ? (NOT TODATE)
    ############################################################ BLOCKING
    ########################################################################
    if [[ $(echo "$COINS > 0" | bc -l) -eq 0 || "$COINS" == "null" || "$primal" == "" ]]; then

        # Patch jaklis gva history error
        [[ $(echo "$COINS > 0" | bc -l) -eq 1 ]] \
            && echo "UPlanet Primal Correction" \
            && [[ ! -s ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal ]] \
            && echo "${UPLANETG1PUB}" > ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal \
            || echo "NOSTR G1 CARD is EMPTY .............. !!! ${TODATE} / ${BIRTHDATE}"

        if [[ ${TODATE} != ${BIRTHDATE} ]]; then
            if [[ ${UPLANETNAME} != "EnfinLibre" ]]; then
                # UPlanet Zen : need Primo RX from UPlanet or WoT member
                echo "UPlanet Zen : INVALID CARD"
                [[ "${PLAYER}" != "${CAPTAINEMAIL}" ]] \
                    && destroy_nostrcard "${PLAYER}" "${G1PUBNOSTR}" "${NSEC}" "${NPUB}"
            else
                # UPlanet ORIGIN ... DAY2 => BRO WELCOME ...
                echo "UPlanet ORIGIN : Activate Welcome BRO: ZenCard + Zine "
                YOU=$(${MY_PATH}/../tools/clyuseryomail.sh ${PLAYER})
                ${MY_PATH}/../tools/PAY4SURE.sh "${HOME}/.zen/game/uplanet.dunikey" "1" "${G1PUBNOSTR}" "UPLANET${UPLANETG1PUB:0:8}:NOSTR:${YOU}:${NPUB}"
                echo "${UPLANETG1PUB}" > ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal
            fi
        fi

        ## welcome EMAIL...
        [[ ! -s ~/.zen/game/nostr/${PLAYER}/.welcome ]] && [[ "$primal" == "" ]] \
            && ${MY_PATH}/../tools/mailjet.sh "${PLAYER}" "${MY_PATH}/../templates/NOSTR/welcome.html" "WELCOME PLAYER" \
            && cp  "${MY_PATH}/../templates/NOSTR/welcome.html" ~/.zen/game/nostr/${PLAYER}/.welcome

        rm -Rf ~/.zen/tmp/${MOATS}
        continue
    fi

    ####################################################################
    ## EVERY 28 DAYS NOSTR CARD is PAYING CAPTAIN
    TODATE_SECONDS=$(date -d "$TODATE" +%s)
    BIRTHDATE_SECONDS=$(date -d "$BIRTHDATE" +%s)
    # Calculate the difference in days
    DIFF_DAYS=$(( (TODATE_SECONDS - BIRTHDATE_SECONDS) / 86400 ))
    # Check if the difference is a multiple of 28 // ROMAN calendar is fake !!
    if [[ ${CAPTAING1PUB} != ${G1PUBNOSTR} ]]; then
        if [ $((DIFF_DAYS % 28)) -eq 0 ]; then
            if [[ $(echo "$COINS > 1" | bc -l) -eq 1 ]]; then
                ## Pay NCARD to CAPTAIN
                [[ -z $NCARD ]] && NCARD=4
                Gpaf=$(makecoord $(echo "$NCARD / 10" | bc -l))
                echo "[28 DAYS CYCLE] $TODATE is MULTIPASS NOSTR Card $NCARD ẐEN PAYMENT ($COINS G1) !!"
                [[ "${PLAYER}" != "${CAPTAINEMAIL}" ]] \
                    && ${MY_PATH}/../tools/PAY4SURE.sh "$HOME/.zen/tmp/${MOATS}/nostr.${PLAYER}.dunikey" "$Gpaf" "${CAPTAING1PUB}" "NOSTR:${UPLANETG1PUB:0:8}:PAF"
            else
                echo "[28 DAYS CYCLE] NOSTR Card ($COINS G1) !!"
                [[ "${PLAYER}" != "${CAPTAINEMAIL}" ]] \
                    && destroy_nostrcard "${PLAYER}" "${G1PUBNOSTR}" "${NSEC}" "${NPUB}"
                continue
            fi
        fi
    else
        echo "CAPTAIN ACCOUNT $COINS G1"
    fi
    ########################################################################
    echo ">>> NOSTR PRIMAL :$pcoins: $primal"
    ## ACTIVATED NOSTR CARD
    NOSTRNS=$(cat ~/.zen/game/nostr/${PLAYER}/NOSTRNS)
    echo "IPNS VAULT : ${myIPFS}${NOSTRNS} ... test resolve ..."
    VAULTFS=$(ipfs --timeout 15s name resolve ${NOSTRNS})
    echo "VAULTFS : ${myIPFS}${VAULTFS}" ## Not USED

    ## FILL UP NOSTRCard/PRIMAL
    if [[ ! -d ~/.zen/game/nostr/${PLAYER}/PRIMAL && ${primal} != "" && ${primal} != "null" ]]; then
        mkdir -p ~/.zen/game/nostr/${PLAYER}/PRIMAL
        ## ONLY FOR UPlanet Zen (Get Cesium+ Profile)
        if [[ ${primal} != ${UPLANETG1PUB} ]]; then
            ## SCAN CESIUM/GCHANGE PRIMAL STATUS
            ${MY_PATH}/../tools/GetGCAttributesFromG1PUB.sh ${primal}
            #######################################################################
            ## COPY PRIMAL DUNITER/CESIUM METADATA (from "coucou" cache)
            cp ~/.zen/tmp/coucou/${primal}* ~/.zen/game/nostr/${PLAYER}/PRIMAL/
            echo ${primal} > ~/.zen/game/nostr/${PLAYER}/G1PRIME # G1PRIME
        fi
    fi

    ## PRIMAL RX SOURCE ?!
    G1PRIME=$(cat ~/.zen/game/nostr/${PLAYER}/G1PRIME 2>/dev/null)
    [[ -z $G1PRIME ]] && G1PRIME=$UPLANETG1PUB ## MISSING DAY 1 PRIMAL : UPLANET ORIGIN

    ########################################################################
    ## STATION OFFICIAL UPASSPORT = UPassport + 1 G1 RX (from WoT member)
    if [[ ! -s ~/.zen/game/passport/${primal} ]]; then
        ## PRIMAL EXISTS ?
        if [[ ${primal} != "" && ${primal} != "null" ]]; then
            ## MAKE /upassport API make /PRIMAL/_upassport.html
            if [[ ! -s ~/.zen/game/nostr/${PLAYER}/PRIMAL/_upassport.html ]]; then
                echo "CREATING UPASSPORT FOR PRIMAL=${primal}"
                curl -s -X POST -F "parametre=${primal}" http://127.0.0.1:54321/upassport \
                    > ~/.zen/game/nostr/${PLAYER}/PRIMAL/_index.html
                [[ ! $? -eq 0 ]] \
                    && rm ~/.zen/game/nostr/${PLAYER}/PRIMAL/_index.html 2>/dev/null
                ################################################
                ## PRIMAL IS MEMBER : COPY UPassport /N1
                if [[ -d ~/.zen/UPassport/pdf/${primal}/N1 ]]; then
                    cp -Rf ~/.zen/UPassport/pdf/${primal}/N1 \
                        ~/.zen/game/nostr/${PLAYER}/PRIMAL/
                    cp ~/.zen/UPassport/pdf/${primal}/*.* \
                        ~/.zen/game/nostr/${PLAYER}/PRIMAL/
                fi
                ## INFORM UPASSPORT TRY DONE (N1 or not, then Uplanet Wallet Amount)
                mv ~/.zen/game/nostr/${PLAYER}/PRIMAL/_index.html \
                    ~/.zen/game/nostr/${PLAYER}/PRIMAL/_upassport.html
                ###############################################
                ## SENDING TO CESIUM PROFILE
                $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/tmp/${MOATS}/nostr.${PLAYER}.dunikey -n ${myCESIUM} send -d "${G1PRIME}" -t "NOSTR UPassport" -m "NOSTR App : $myIPFS/ipns/${NOSTRNS}"

            else
                echo "## PRIMAL existing : $G1PRIME"
                ## SENDING MESSAGE TO N1 (P2P,P21,12P) RELATIONS in manifest.json
                json_file="$HOME/.zen/game/nostr/${PLAYER}/PRIMAL/N1/manifest.json"
                if [[ -s "$json_file" ]]; then
                    echo ">>> UPassport N1"
                    # Parcourir chaque clé (p2p, certin, certout) et extraire les valeurs
                    jq -r '.[][] | select(. != null) | capture("(?<G1PUB>[^.]+)\\.(?<PSEUDO>[^.]+)\\.(?<KEY>[^.]+)") | "\(.G1PUB) \(.PSEUDO) \(.KEY)"' "$json_file" | while read -r G1PUB PSEUDO KEY; do
                        # Vérifier si le message existe déjà
                        if [[ ! -s ~/.zen/game/nostr/${PLAYER}/PRIMAL/$G1PUB.txt ]]; then
                            # Définir le message en fonction de la clé
                            if [[ "$KEY" == "certin" ]]; then
                                $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/tmp/${MOATS}/nostr.${PLAYER}.dunikey -n ${myCESIUM} send -d "$G1PRIME" -t " ¯\_༼qO͡〰op༽_/¯ 12P ?" -m "BRO Certification <=> $G1PUB"
                                sleep 1
                            elif [[ "$KEY" == "certout" ]]; then
                                $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/tmp/${MOATS}/nostr.${PLAYER}.dunikey -n ${myCESIUM} send -d "$G1PUB" -t " ¯\_༼qO͡〰op༽_/¯ P21 ?" -m "BRO Certification <=> $G1PRIME"
                                sleep 1
                            fi
                            MESSAGE="$G1PRIME est devenu membre de CopyLaRadio https://www.copylaradio.com --- UPlanet /SCAN : https://qo-op.com"
                            $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/tmp/${MOATS}/nostr.${PLAYER}.dunikey -n ${myCESIUM} send -d "$G1PUB" -t " ¯\_༼qO͡〰op༽_/¯ " -m "$MESSAGE"
                            echo "$MESSAGE" > ~/.zen/game/nostr/${PLAYER}/PRIMAL/$G1PUB.txt
                            sleep 2
                        fi
                    done
                fi

            fi
        fi
    else
        #### UPASSPORT DU : Cooperative Real Member
        #### - double PRIMO TX from G1 creator -
        echo "## OFFICIAL PDF UPASSPORT : ${primal} is STATION co OWNER !!"
    fi

    ########################################################################
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

        ## PRIMAL can be UPLANETG1PUB or REGULAR wallet key = NO PoH !
        if [[ -d  ~/.zen/game/nostr/${PLAYER}/PRIMAL/N1 ]]; then
            PoH=":$primal"
        else
            PoH=""
        fi
        g1pubnostr=$(cat ${HOME}/.zen/game/nostr/${PLAYER}/G1PUBNOSTR)
        ### SEND PROFILE TO NOSTR RELAYS
        ${MY_PATH}/../tools/nostr_setup_profile.py \
            "$NSEC" \
            "$title" "$g1pubnostr$PoH" \
            "$description - $city" \
            "$myIPFS/$zavatar" \
            "$myIPFS/ipfs/QmX1TWhFZwVFBSPthw1Q3gW5rQc1Gc4qrSbKj4q1tXPicT/P2Pmesh.jpg" \
            "" "$myIPFS${NOSTRNS}" "" "" "" "" \
            "wss://relay.copylaradio.com" "$myRELAY" \
            --ipfs_gw "$myIPFS" \
            --ipns_vault "/ipns/${NOSTRNS}" \
            > ~/.zen/game/nostr/${PLAYER}/nostr_setup_profile

        ## DOES COMMAND SUCCEED ?
        [[ ! $? -eq 0 ]] \
            && rm ~/.zen/game/nostr/${PLAYER}/nostr_setup_profile 2>/dev/null

        ## RECORD GPS (for ZenCard activation)
        [[ -n $LAT && -n $LON ]] && echo "LAT=$LAT; LON=$LON;" > ~/.zen/game/nostr/${PLAYER}/GPS

    else
        echo "########################################## STEP 2"
        echo "## Nostr Card PROFILE EXISTING"
        #~ cat ~/.zen/game/nostr/${PLAYER}/nostr_setup_profile
        HEX=$(cat ~/.zen/game/nostr/${PLAYER}/HEX)
        ## Zen Card ONLY FOR UPlanet Zen
        if [[ "$UPLANETG1PUB" != "AwdjhpJNqzQgmSrvpUk5Fd2GxBZMJVQkBQmXn4JQLr6z" ]]; then
            ## CREATE UPlanet AstroID + ZenCard using EMAIL and GPS ###########
            if [[ ! -d ~/.zen/game/players/${PLAYER} ]]; then
                echo "## MULTIPASS ZenCard creation "
                source ~/.zen/game/nostr/${PLAYER}/GPS
                PPASS=$(${MY_PATH}/../tools/diceware.sh $(( $(${MY_PATH}/../tools/getcoins_from_gratitude_box.sh) + 1 )) | xargs)
                NPASS=$(${MY_PATH}/../tools/diceware.sh $(( $(${MY_PATH}/../tools/getcoins_from_gratitude_box.sh) + 1 )) | xargs)

                ## GET LANG FROM NOSTR CARD
                LANG=$(cat ${HOME}/.zen/game/nostr/${PLAYER}/LANG 2>/dev/null)
                [[ -z $LANG ]] && LANG="fr"
                #####################################
                ## CREATE ASTRONAUTE TW ZEN CARD
                #####################################
                echo "MULTIPASS : ZenCard ${PLAYER}" "UPlanet" "${LANG}" "${LAT}" "${LON}"
                ${MY_PATH}/../RUNTIME/VISA.new.sh "${PPASS}" "${NPASS}" "${PLAYER}" "UPlanet" "${LANG}" "${LAT}" "${LON}" "$NPUB" "$HEX"

            else
                ################## FINAL STEP REACHED ###################
                ######## USER STATE = Email
                ### + NOSTR Card + Message (GPS 0?)
                ### + UPassport (G1/DU?)
                ### + Zen Card (Ẑ/€?)
                ### = PLAYER N1/N2 UPLANET
                #########################################################
                echo "MULTIPASS ZenCard existing : ~/.zen/game/players/${PLAYER}"
                ${MY_PATH}/../tools/search_for_this_email_in_players.sh ${PLAYER} | tail -n 1

            fi
        else
            $(${MY_PATH}/../tools/search_for_this_email_in_nostr.sh ${PLAYER} | tail -n 1)
            echo "UPlanet ORIGIN $source NOSTR Card... $LAT $LON $HEX $EMAIL"

        fi
    fi

    ########################################################################
    ####################################### IPFS NAME PUBLISH
    ########################################################################
    ## UPDATE IPNS NOSTRVAULT KEY
    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/nostr.ipns "${salt}" "${pepper}"
    ipfs key rm "${G1PUBNOSTR}:NOSTR" > /dev/null 2>&1
    NOSTRNS=$(ipfs key import "${G1PUBNOSTR}:NOSTR" -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/nostr.ipns)
    ## UPDATE IPNS RESOLVE
    NOSTRIPFS=$(ipfs add -rwq ${HOME}/.zen/game/nostr/${PLAYER}/ | tail -n 1)
    ipfs name publish --key "${G1PUBNOSTR}:NOSTR" /ipfs/${NOSTRIPFS}
    echo "${PLAYER} STORAGE: /ipns/$NOSTRNS = /ipfs/${NOSTRIPFS}"

    ## MEMORIZE TODATE PUBLISH (reduce publish to once a day)
    echo "$TODATE" > ${HOME}/.zen/game/nostr/${PLAYER}/.todate

    echo "___________________________________________________"
    sleep 1

done

end=`date +%s`
dur=`expr $end - $start`
hours=$((dur / 3600)); minutes=$(( (dur % 3600) / 60 )); seconds=$((dur % 60))
echo "DURATION ${hours} hours ${minutes} minutes ${seconds} seconds"
echo "============================================ NOSTR.refresh DONE."
rm -Rf ~/.zen/tmp/${MOATS}

exit 0
