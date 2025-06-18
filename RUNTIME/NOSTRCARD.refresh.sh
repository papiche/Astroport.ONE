#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ NOSTRCARD.refresh.sh
#~ Refresh NOSTR Card data & wallet
################################################################################
# Ce script gère le rafraîchissement des cartes NOSTR :
# 1. Vérifie et met à jour les données des cartes NOSTR
# 2. Gère les paiements des cartes NOSTR
# 3. Implémente le système de distribution des bénéfices
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


#### AVOID MULTIPLE RUN
countMErunning=$(pgrep -au $USER -f "$0" | wc -l)
if [[ $countMErunning -gt 2 ]]; then
    echo "$ME already running $countMErunning time"
    exit 0
fi

echo "## RUNNING NOSTRCARD.refresh.sh
                 _
 _ __   ___  ___| |_ _ __
| '_ \ / _ \/ __| __| '__|
| | | | (_) \__ \ |_| |
|_| |_|\___/|___/\__|_|


"

[[ -z ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}

# Fonction pour générer une heure aléatoire de rafraîchissement
get_random_refresh_time() {
    local player="$1"
    # Générer un nombre aléatoire de minutes entre 1 et 1440 (24h)
    local random_minutes=$(( (RANDOM % 1440) + 1 ))
    # Calculer l'heure et les minutes
    local random_hour=$(( random_minutes / 60 ))
    local random_minute=$(( random_minutes % 60 ))
    # Formater l'heure avec des zéros si nécessaire
    printf "%02d:%02d" $random_hour $random_minute
}

# Fonction pour initialiser un compte
initialize_account() {
    local player="$1"
    local player_dir="${HOME}/.zen/game/nostr/${PLAYER}"

    # Créer le répertoire s'il n'existe pas
    mkdir -p "$player_dir"

    # Initialiser l'heure de rafraîchissement
    local random_time=$(get_random_refresh_time "${PLAYER}")
    echo "$random_time" > "${player_dir}/.refresh_time"

    # Initialiser la date
    echo "$TODATE" > "${player_dir}/.todate"

    # Initialiser le fichier BIRTHDATE si nécessaire
    [[ ! -s "${player_dir}/TODATE" ]] && echo "$TODATE" > "${player_dir}/TODATE"

    echo "Account ${PLAYER} initialized with refresh time: ${random_time}"
}

# Fonction pour vérifier si le rafraîchissement est nécessaire
should_refresh() {
    local player="$1"
    local player_dir="${HOME}/.zen/game/nostr/${PLAYER}"
    local current_time=$(date '+%H:%M')
    local refresh_time_file="${player_dir}/.refresh_time"
    local last_refresh_file="${player_dir}/.todate"
    local last_udrive_file="${player_dir}/.udrive"
    local last_uworld_file="${player_dir}/.uworld"

    UDRIVE=""
    UWORLD=""

    # Si le compte n'est pas initialisé, l'initialiser
    if [[ ! -d "$player_dir" ]] || [[ ! -s "$refresh_time_file" ]]; then
        initialize_account "${PLAYER}"
        return 1
    fi

    local refresh_time=$(cat "$refresh_time_file")
    local last_refresh=$(cat "$last_refresh_file")
    local last_udrive=$(cat "$last_udrive_file")
    local last_uworld=$(cat "$last_uworld_file")

    # Si c'est un nouveau jour et que l'heure de rafraîchissement est passée ## 24 H spreading
    if [[ "$last_refresh" != "$TODATE" ]] && [[ "$current_time" > "$refresh_time" ]]; then
        return 0
    fi
    ##############################################
    ## ACTIVATE & CHECK APP STRUCTURE
    [[ ! -d ${player_dir}/APP/uDRIVE ]] \
        && rm -Rf ${player_dir}/APP \
        && mkdir -p ${player_dir}/APP/uDRIVE/

    ## Verify Link
    [[ ! -L "${player_dir}/APP/uDRIVE/generate_ipfs_structure.sh" ]] && \
        cd "${player_dir}/APP/uDRIVE" && \
        ln -s "${HOME}/.zen/Astroport.ONE/tools/generate_ipfs_structure.sh" "generate_ipfs_structure.sh"

    ## update uDRIVE APP
    cd ${player_dir}/APP/uDRIVE/
    # remove when generate_ipfs_structure.sh code is stable
    rm index.html _index.html manifest.json 2>/dev/null ## Reset uDRIVE index & manifest
    UDRIVE=$(./generate_ipfs_structure.sh .) ## UPDATE MULTIPASS IPFS DRIVE
    echo "UDRIVE UDPATE : $myIPFS/ipfs/$UDRIVE"
    echo "<html><head><meta http-equiv=\"refresh\" content=\"0; url=/ipfs/$UDRIVE\"></head></html>" > index.html
    cd - 2>&1 >/dev/null
    if [[ "$UDRIVE" != "$last_udrive" ]]; then
        if [[ -n "$last_udrive" ]]; then
            ipfs --timeout 20s pin rm "$last_udrive" 2>/dev/null
        fi
        if [[ -n "$UDRIVE" ]]; then
            echo "$UDRIVE" > "${last_udrive_file}"
        fi
        return 0
    fi

    ## uWORLD Link
    [[ ! -L "${player_dir}/APP/uWORLD/generate_ipfs_RPG.sh" ]] && \
        mkdir -p "${player_dir}/APP/uWORLD" && \
        cd ${player_dir}/APP/uWORLD/ && \
        ln -s "${HOME}/.zen/Astroport.ONE/tools/generate_ipfs_RPG.sh" "generate_ipfs_RPG.sh"

    ## update uWORLD APP
    cd ${player_dir}/APP/uWORLD/
    rm index.html _index.html manifest.json 2>/dev/null ## Reset uWORLD index & manifest
    UWORLD=$(./generate_ipfs_RPG.sh .) ## UPDATE MULTIPASS uWORLD
    echo "<html><head><meta http-equiv=\"refresh\" content=\"0; url=/ipfs/$UWORLD\"></head></html>" > index.html
    cd - 2>&1 >/dev/null

    if [[ "$UWORLD" != "$last_uworld" ]]; then
        [[ -n $last_uworld ]] \
            && ipfs --timeout 20s pin rm $last_uworld ## remove old pin
        [[ -n $UWORLD ]] \
            && echo $UWORLD > "${last_uworld_file}"
        return 0
    fi

    return 1
}

########################################################################
# NOSTR Card is evolving depending PRIMAL RX source.
# on UPLanet ORIGIN or UPlanet Zen.
########################################################################
NOSTR=($(ls -t ~/.zen/game/nostr/ 2>/dev/null | grep "@" ))

## RUNING FOR ALL LOCAL NOSTR CARDS
for PLAYER in "${NOSTR[@]}"; do
    HEX=$(cat ~/.zen/game/nostr/${PLAYER}/HEX)

    ## SWARM CACHE PUBLISHING
    if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/HEX ]]; then
        mkdir -p ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}
        echo "$HEX" > ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/HEX
    fi
    if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/GPS ]]; then
        mkdir -p ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}
        cp ${HOME}/.zen/game/nostr/${PLAYER}/GPS ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/GPS 2>/dev/null
    fi

    G1PUBNOSTR=$(cat ~/.zen/game/nostr/${PLAYER}/G1PUBNOSTR)
    COINS=$($MY_PATH/../tools/COINScheck.sh ${G1PUBNOSTR} | tail -n 1)

    if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/G1PUBNOSTR ]]; then
        echo "$G1PUBNOSTR" > ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/G1PUBNOSTR
    fi

    # Add validation for COINS value
    if [[ -n "$COINS" && "$COINS" != "null" ]]; then
        ZEN=$(echo "($COINS - 1) * 10" | bc | cut -d '.' -f 1)
    else
        ZEN=-10
        echo "WARNING: Empty or invalid wallet state for ${PLAYER}"
    fi

    echo "${G1PUBNOSTR} ______ AMOUNT = ${COINS} G1 -> ${ZEN} ZEN"

    refreshtime="$(cat ~/.zen/game/nostr/${PLAYER}/.todate) $(cat ~/.zen/game/nostr/${PLAYER}/.refresh_time)"
    echo "\m/_(>_<)_\m/ ($refreshtime) : ${PLAYER} $COINS G1 -> ${ZEN} ZEN : ${HEX} UDRIVE : $(cat ~/.zen/game/nostr/${PLAYER}/.udrive 2>/dev/null)"

    # Vérifier si le rafraîchissement est nécessaire
    should_refresh "${PLAYER}" || continue

    if [[ ! -s ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal && ${COINS} != "null" ]]; then
    ################################################################ PRIMAL RX CHECK
        echo "# RX from ${G1PUBNOSTR}.... checking primal transaction..."
        function get_primal_transaction() {
            local g1pub="$1"
            local attempts=0
            local success=false
            local result=""

            while [[ $attempts -lt 3 && $success == false ]]; do
                GVA=$(${MY_PATH}/../tools/duniter_getnode.sh | tail -n 1)
                if [[ ! -z $GVA ]]; then
                    sed -i '/^NODE=/d' ${MY_PATH}/../tools/jaklis/.env
                    echo "NODE=$GVA" >> ${MY_PATH}/../tools/jaklis/.env
                    echo "Trying primal check with GVA NODE: $GVA (attempt $((attempts + 1)))"

                    result=$(${MY_PATH}/../tools/jaklis/jaklis.py history -p ${g1pub} -n 1000 -j | jq '.[0]' 2>/dev/null)
                    g1prime=$(echo $result | jq -r .pubkey 2>/dev/null)

                    if [[ ! -z ${g1prime} && ${g1prime} != "null" ]]; then
                        success=true
                        break
                    fi
                fi

                attempts=$((attempts + 1))
                if [[ $attempts -lt 3 ]]; then
                    sleep 2
                fi
            done

            echo "$g1prime"
        }

        milletxzero=$(get_primal_transaction "${G1PUBNOSTR}")
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
        ${MY_PATH}/../tools/natools.py decrypt -f pubsec -i "$HOME/.zen/game/nostr/${PLAYER}/.ssss.mid.captain.enc" \
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
        rm "$tmp_mid" "$tmp_tail" 2>/dev/null
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

        # UPLANET ORIGIN : patch jaklis gva history error
        #~ [[ $UPLANETNAME == "EnfinLibre" && $(echo "$COINS > 0" | bc -l) -eq 1 ]] \
            #~ && echo "UPlanet Primal Correction" \
            #~ && [[ ! -s ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal ]] \
            #~ && echo "${UPLANETG1PUB}" > ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal \
            #~ || echo "NOSTR G1 CARD is EMPTY .............. !!! ${TODATE} / ${BIRTHDATE}"

        if [[ ${TODATE} != ${BIRTHDATE} ]]; then
            if [[ ${UPLANETNAME} == "EnfinLibre" ]]; then
                # UPlanet ORIGIN ... DAY2 => BRO WELCOME ...
                echo "UPlanet ORIGIN : Send Primo RX from UPlanet : MULTIPASS activation"
                YOUSER=$(${MY_PATH}/../tools/clyuseryomail.sh ${PLAYER})
                ${MY_PATH}/../tools/PAY4SURE.sh "${HOME}/.zen/game/uplanet.dunikey" "1" "${G1PUBNOSTR}" "UPLANET${UPLANETG1PUB:0:8}:MULTIPASS:${YOUSER}:${NPUB}" 2>/dev/null
                [[ $? -eq 0 ]] \
                    && echo "${UPLANETG1PUB}" > ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal
            else
                # UPlanet Zen : need Primo RX from UPlanet and WoT member
                echo "UPlanet Zen : ${CAPTAINEMAIL} or INVALID CARD"
                [[ "${PLAYER}" != "${CAPTAINEMAIL}" ]] \
                    && ${MY_PATH}/../tools/nostr_DESTROY_TW.sh "${PLAYER}"
            fi
        fi

        ## welcome EMAIL...
        [[ ! -s ~/.zen/game/nostr/${PLAYER}/.welcome.html ]] \
            && cp ${MY_PATH}/../templates/NOSTR/welcome.html ~/.zen/game/nostr/${PLAYER}/.welcome.html \
            && sed -i "s/http:\/\/127.0.0.1:8080/${myIPFS}/g" ~/.zen/game/nostr/${PLAYER}/.welcome.html \
            && ${MY_PATH}/../tools/mailjet.sh "${PLAYER}" "${HOME}/.zen/game/nostr/${PLAYER}/.welcome.html" "WELCOME /ipns/$YOUSER"

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
                    && ${MY_PATH}/../tools/PAY4SURE.sh "$HOME/.zen/tmp/${MOATS}/nostr.${PLAYER}.dunikey" "$Gpaf" "${CAPTAING1PUB}" "NOSTR:${UPLANETG1PUB:0:8}:PAF" 2>/dev/null
            else
                echo "[28 DAYS CYCLE] NOSTR Card ($COINS G1) !!"
                [[ "${PLAYER}" != "${CAPTAINEMAIL}" ]] \
                    && ${MY_PATH}/../tools/nostr_DESTROY_TW.sh "${PLAYER}"
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
    echo "IPNS VAULT : ${myIPFS}${NOSTRNS}"

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
                ## TODO CONVERT SEND NOSTR MULTIPASS MESSAGE
            else
                echo "## PRIMAL existing : $G1PRIME"
                ## SENDING MESSAGE TO N1 (P2P: peer to peer, P21 : peer to one, 12P : one to peer ) RELATIONS in manifest.json
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
                            MESSAGE="$G1PRIME est devenu membre de CopyLaRadio https://www.copylaradio.com --- UPlanet : $myIPFS/ipns/copylaradio.com"
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

    YOUSER=$(${MY_PATH}/../tools/clyuseryomail.sh ${PLAYER})

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
        [[ -z $title ]] && title="$YOUSER"
        city=$(cat ~/.zen/game/nostr/${PLAYER}/PRIMAL/${primal}.cesium.json 2>/dev/null | jq -r ._source.city)
        [[ -z $city ]] && city="UPlanet ${UPLANETG1PUB:0:8}"
        description=$(cat ~/.zen/game/nostr/${PLAYER}/PRIMAL/${primal}.cesium.json 2>/dev/null | jq -r ._source.description)
        [[ -z $description ]] && description="MULTIPASS"

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
            "✌(◕‿-)✌ $title" "$g1pubnostr$PoH" \
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
        echo "################################## PRIME : $G1PRIME"
        echo "## Nostr Card PROFILE EXISTING"
        #~ cat ~/.zen/game/nostr/${PLAYER}/nostr_setup_profile
        HEX=$(cat ~/.zen/game/nostr/${PLAYER}/HEX)
        ########################################################################
        ## auto ZENCARD ONLY FOR UPlanet Zen #################################################
        if [[ "$UPLANETG1PUB" != "AwdjhpJNqzQgmSrvpUk5Fd2GxBZMJVQkBQmXn4JQLr6z" ]]; then
            ## CREATE UPlanet AstroID + ZenCard using EMAIL and GPS ##
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
                echo "MULTIPASS : ZenCard ${PLAYER}" "UPlanet" "${LANG}" "${LAT}" "${LON}" "$NPUB" "$HEX"
                ${MY_PATH}/../RUNTIME/VISA.new.sh "${PPASS}" "${NPASS}" "${PLAYER}" "UPlanet" "${LANG}" "${LAT}" "${LON}" "$NPUB" "$HEX"

            else
                ################## FINAL STEP REACHED ###################
                ######## USER STATE = Email
                ### + NOSTR Card + Message (GPS 0?)
                ### + UPassport (G1/DU?)
                ### + Zen Card (Ẑ/€?)
                ### = PLAYER N1/N2 UPLANET ZEN
                #########################################################
                echo "MULTIPASS ZenCard existing : ~/.zen/game/players/${PLAYER}"
                ${MY_PATH}/../tools/search_for_this_email_in_players.sh ${PLAYER} | tail -n 1

            fi
        ############## UPLANET ORIGIN #############################################
        else
            $(${MY_PATH}/../tools/search_for_this_email_in_nostr.sh ${PLAYER} | tail -n 1)
            echo "UPlanet ORIGIN $source NOSTR Card... $LAT $LON $HEX $EMAIL"

        fi
    fi

    ########################################################################################
    echo "## CONTROL NOSTR WALLET PRIMAL RX"
    ########################################################################################
    echo "Checking NOSTR wallet for $PLAYER: $G1PUBNOSTR"
    # Get transaction history for this NOSTR wallet
    function get_wallet_history() {
        local g1pub="$1"
        local output_file="$2"
        local attempts=0
        local success=false

        while [[ $attempts -lt 3 && $success == false ]]; do
            GVA=$(${MY_PATH}/../tools/duniter_getnode.sh | tail -n 1)
            if [[ ! -z $GVA ]]; then
                sed -i '/^NODE=/d' ${MY_PATH}/../tools/jaklis/.env
                echo "NODE=$GVA" >> ${MY_PATH}/../tools/jaklis/.env
                echo "Trying history with GVA NODE: $GVA (attempt $((attempts + 1)))"

                ~/.zen/Astroport.ONE/tools/timeout.sh -t 12 \
                ${MY_PATH}/../tools/jaklis/jaklis.py history -p ${g1pub} -n 30 -j \
                    > ${output_file} 2>/dev/null

                if [[ -s ${output_file} ]]; then
                    success=true
                    break
                fi
            fi

            attempts=$((attempts + 1))
            if [[ $attempts -lt 3 ]]; then
                sleep 2
            fi
        done

        return $([[ $success == true ]])
    }

    # Get transaction history with retry mechanism
    get_wallet_history "${G1PUBNOSTR}" "$HOME/.zen/tmp/${MOATS}/${PLAYER}.duniter.history.json"

    # Convert JSON to inline format if history was retrieved successfully
    [[ -s $HOME/.zen/tmp/${MOATS}/${PLAYER}.duniter.history.json ]] \
        && cat $HOME/.zen/tmp/${MOATS}/${PLAYER}.duniter.history.json | jq -rc '.[]' \
             > ~/.zen/game/nostr/${PLAYER}/.g1.history.json

    if [[ -s $HOME/.zen/game/nostr/${PLAYER}/.g1.history.json ]]; then
    # Process each transaction
        while read LINE; do
            JSON=${LINE}
            TXIDATE=$(echo $JSON | jq -r .date)
            TXIPUBKEY=$(echo $JSON | jq -r .pubkey)
            TXIAMOUNT=$(echo $JSON | jq -r .amount)

            # Skip if transaction is too old
            lastTXdate=$(cat ~/.zen/game/nostr/${PLAYER}/.nostr.check 2>/dev/null)
            [[ -z lastTXdate ]] && lastTXdate=0 && echo 0 > ~/.zen/game/nostr/${PLAYER}/.nostr.check
            [[ $(cat ~/.zen/game/nostr/${PLAYER}/.nostr.check) -ge $TXIDATE ]] && continue

            # Skip outgoing transactions
            [[ $(echo "$TXIAMOUNT < 0" | bc) -eq 1 ]] \
                && echo "$TXIDATE" > ~/.zen/game/nostr/${PLAYER}/.nostr.check \
                && continue

            # Check primal transaction
            echo "# RX from ${TXIPUBKEY}.... checking primal transaction..."
            if [[ ! -s ~/.zen/tmp/coucou/${TXIPUBKEY}.primal ]]; then
                get_wallet_history "${TXIPUBKEY}" "$HOME/.zen/tmp/${MOATS}/${TXIPUBKEY}.primal.history.json"
                if [[ -s "$HOME/.zen/tmp/${MOATS}/${TXIPUBKEY}.primal.history.json" ]]; then
                    g1prime=$(cat "$HOME/.zen/tmp/${MOATS}/${TXIPUBKEY}.primal.history.json" | jq -r '.[0].pubkey')
                    [[ ! -z ${g1prime} ]] && echo "${g1prime}" > ~/.zen/tmp/coucou/${TXIPUBKEY}.primal
                fi
            fi

            TXIPRIMAL=$(cat ~/.zen/tmp/coucou/${TXIPUBKEY}.primal 2>/dev/null)
            ########################################################################
            ### CONTROL ALL WALLET ARE UPLANET ẐEN INITIALIZED (same .primal)
            # Verify if transaction is from a valid UPLANET ẐEN wallet
            if [[ ${UPLANETNAME} != "EnfinLibre" && ${UPLANETG1PUB} != "${TXIPRIMAL}" && ${TXIPRIMAL} != "" ]]; then
                echo "MULTIPASS WALLET INTRUSION ALERT for $PLAYER from $TXIPUBKEY ($TXIPRIMAL)"
                # Get DISCO from PLAYER
                if [[ ! -s ~/.zen/game/nostr/${PLAYER}/.secret.dunikey ]]; then
                    DISCO=$(cat ~/.zen/game/nostr/${PLAYER}/.secret.disco)
                    IFS='=&' read -r s salt p pepper <<< "$DISCO"
                    # Create secret.dunikey from DISCO
                    if [[ -n $salt && -n $pepper ]]; then
                        ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/nostr/${PLAYER}/.secret.dunikey "${salt}" "${pepper}"
                    fi
                fi
                [[ ! -s ~/.zen/game/nostr/${PLAYER}/.secret.dunikey ]] && continue
                # Refund the transaction
                ${MY_PATH}/../tools/PAY4SURE.sh "${HOME}/.zen/game/nostr/${PLAYER}/.secret.dunikey" "${TXIAMOUNT}" "${TXIPUBKEY}" "NOSTR:${G1PUBNOSTR}:INTRUSION" 2>/dev/null
                if [[ $? == 0 ]]; then
                    echo $TXIDATE > ~/.zen/game/nostr/${PLAYER}/.nostr.check
                    # Create alert message
                    # Use the multi language template
                    TEMPLATE="${MY_PATH}/../templates/NOSTR/wallet_alert.html"

                    # Replace placeholders in template
                    sed -e "s/{PLAYER}/$PLAYER/g" \
                        -e "s/{UPLANETG1PUB}/${UPLANETG1PUB:0:8}/g" \
                        -e "s/{TXIAMOUNT}/$TXIAMOUNT/g" \
                        -e "s/{CAPITAL_VALUE}/$ZEN/g" \
                        -e "s/{TXIPUBKEY}/$TXIPUBKEY/g" \
                        -e "s|{myIPFS}|$myIPFS|g" \
                        "$TEMPLATE" > ~/.zen/tmp/palpay.bro

                    # Send alert
                    ${MY_PATH}/../tools/mailjet.sh "${PLAYER}" ~/.zen/tmp/palpay.bro "MULTIPASS ALERT : $TXIPUBKEY"
                fi
            else
                echo "GOOD NOSTR WALLET primal TX by $TXIPRIMAL"
                echo "$TXIDATE" > ~/.zen/game/nostr/${PLAYER}/.nostr.check
            fi
        done < $HOME/.zen/game/nostr/${PLAYER}/.g1.history.json
    else
        echo "NO STR WALLET HISTORY FOR $PLAYER"
    fi

    ## ADD AMIS of AMIS -- friends of registered MULTIPASS can use our nostr relay
    fof_list=($($MY_PATH/../tools/nostr_get_N1.sh $HEX 2>/dev/null))
    printf "%s\n" "${fof_list[@]}" >> "${HOME}/.zen/strfry/amisOfAmis.txt"

    ## EXPORT NOSTR EVENTS TO JSON
    echo "Exporting NOSTR events for ${PLAYER}..."
    cd ${HOME}/.zen/strfry/
    ./strfry scan '{"authors": ["'$HEX'"]}' 2> /dev/null > "${HOME}/.zen/game/nostr/${PLAYER}/nostr_export.json"
    COUNT=$(wc -l < "${HOME}/.zen/game/nostr/${PLAYER}/nostr_export.json")
    echo "Exported ${COUNT} events to ${HOME}/.zen/game/nostr/${PLAYER}/nostr_export.json"
    cd - 2>&1 >/dev/null

    ## UPDATE IPNS NOSTRVAULT KEY
    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/nostr.ipns "${salt}" "${pepper}"
    ipfs key rm "${G1PUBNOSTR}:NOSTR" > /dev/null 2>&1
    NOSTRNS=$(ipfs key import "${G1PUBNOSTR}:NOSTR" -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/nostr.ipns)
    ## UPDATE IPNS RESOLVE
    NOSTRIPFS=$(ipfs add -rwq ${HOME}/.zen/game/nostr/${PLAYER}/ | tail -n 1)
    ipfs name publish --key "${G1PUBNOSTR}:NOSTR" /ipfs/${NOSTRIPFS}
    echo "${PLAYER} STORAGE: /ipns/$NOSTRNS = /ipfs/${NOSTRIPFS}"

    ## MEMORIZE TODATE PUBLISH (reduce publish if APP was modified or once a day)
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
