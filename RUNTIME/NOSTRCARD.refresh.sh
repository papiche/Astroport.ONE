#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ NOSTRCARD.refresh.sh
#~ Refresh NOSTR Card data & wallet
################################################################################
# Ce script gère l'évolution des cartes NOSTR (MULTIPASS) selon leur état :
# 1. Vérifie et met à jour les données des cartes NOSTR
# 2. Gère les paiements des cartes NOSTR (cycles 7 jours)
# 3. Implémente le système de distribution des bénéfices
# 4. Évolue le compte selon le type de PRIMAL :
#    - PRIMAL = UPlanet wallet : Compte UPlanet ORIGIN (EnfinLibre)
#    - PRIMAL = Membre G1 : Compte UPlanet ZEN avec UPassport N1
# 5. Crée ZenCard pour les comptes UPlanet ZEN (primo transaction membre Ğ1)
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
gstart=`date +%s`


#### AVOID MULTIPLE RUN
LOCKFILE="/tmp/nostrcard_refresh.lock"
if [[ -f "$LOCKFILE" ]]; then
    PID=$(cat "$LOCKFILE" 2>/dev/null)
    if [[ -n "$PID" && -d "/proc/$PID" ]]; then
        echo "NOSTRCARD.refresh.sh already running (PID: $PID)"
        exit 0
    else
        # Remove stale lock file
        rm -f "$LOCKFILE"
    fi
fi
echo $$ > "$LOCKFILE"

echo "## RUNNING NOSTRCARD.refresh.sh
                 _
 _ __   ___  ___| |_ _ __
| '_ \ / _ \/ __| __| '__|
| | | | (_) \__ \ |_| |
|_| |_|\___/|___/\__|_|


"

[[ -z ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}

# Initialize counters for summary
DAILY_UPDATES=0
FILE_UPDATES=0
SKIPPED_PLAYERS=0
PAYMENTS_PROCESSED=0
PAYMENTS_FAILED=0
PAYMENTS_ALREADY_DONE=0

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

    # Initialiser le fichier de dernière mise à jour IPNS
    date +%s > "${player_dir}/.last_ipns_update"

    # Initialiser le fichier de dernier paiement
    echo "" > "${player_dir}/.lastpayment"

    echo "Account ${PLAYER} initialized with refresh time: ${random_time}"
}

function get_primal_transaction() {
    local g1pub="$1"
    local attempts=0
    local success=false
    local result=""
    local g1prime=""

    # Validate G1PUB format and convert to IPFS to ensure it's valid
    local g1pub_ipfs=$(${MY_PATH}/../tools/g1_to_ipfs.py ${g1pub} 2>/dev/null)
    if [[ -z $g1pub_ipfs ]]; then
        echo "ERROR: INVALID G1PUB: $g1pub" >&2
        return 1
    fi

    while [[ $attempts -lt 3 && $success == false ]]; do
        BMAS_NODE=$(${MY_PATH}/../tools/duniter_getnode.sh BMAS | tail -n 1)
        if [[ ! -z $BMAS_NODE ]]; then
            echo "Trying primal check with BMAS NODE: $BMAS_NODE (attempt $attempts)" >&2
            silkaj_output=$(silkaj --endpoint "$BMAS_NODE" --json money primal ${g1pub} 2>/dev/null)
            g1prime=$(echo "$silkaj_output" | jq -r '.primal_source_pubkey' 2>/dev/null)
            if [[ -n "${g1prime}" && "${g1prime}" != "null" ]]; then
                # Validate primal G1PUB as well
                local primal_ipfs=$(${MY_PATH}/../tools/g1_to_ipfs.py ${g1prime} 2>/dev/null)
                if [[ -n "${primal_ipfs}" ]]; then
                    success=true
                    break
                else
                    echo "Warning: Invalid ${g1pub} primal: $g1prime" >&2
                    g1prime=""
                fi
            fi
        fi

        attempts=$((attempts + 1))
        if [[ $attempts -lt 3 ]]; then
            sleep 2
        fi
    done

    echo "$g1prime"
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
    local last_ipns_update_file="${player_dir}/.last_ipns_update"

    UDRIVE=""
    UWORLD=""
    REFRESH_REASON=""

    # Si le compte n'est pas initialisé, l'initialiser
    if [[ ! -d "$player_dir" ]] || [[ ! -s "$refresh_time_file" ]]; then
        initialize_account "${PLAYER}"
        return 1
    fi

    local refresh_time=$(cat "$refresh_time_file")
    local last_refresh=$(cat "$last_refresh_file")
    local last_udrive=$(cat "$last_udrive_file" 2>/dev/null)
    local last_uworld=$(cat "$last_uworld_file" 2>/dev/null)
    local last_ipns_update=$(cat "$last_ipns_update_file" 2>/dev/null)

    # Vérification 1: Mise à jour quotidienne (une fois par jour à l'heure aléatoire)
    if [[ "$last_refresh" != "$TODATE" ]]; then
        # Convert current_time and refresh_time (HH:MM) to seconds since midnight
        current_seconds=$((10#${current_time%%:*} * 3600 + 10#${current_time##*:} * 60))
        refresh_seconds=$((10#${refresh_time%%:*} * 3600 + 10#${refresh_time##*:} * 60))
        # Check if we're in the hour following the refresh time (within 1 hour window)
        if [[ $current_seconds -gt $refresh_seconds && $current_seconds -le $((refresh_seconds + 3600)) ]]; then
            REFRESH_REASON="daily_update"
            echo "Daily refresh needed for ${PLAYER} (scheduled time: ${refresh_time})"
            return 0
        fi
    fi

    ##############################################
    ## MULTIPASS APP UPDATE
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
    UDRIVE=$(./generate_ipfs_structure.sh .) ## UPDATE MULTIPASS IPFS DRIVE
    echo "UDRIVE UDPATE : $myIPFS/ipfs/$UDRIVE"
    cd - 2>&1 >/dev/null
    
    if [[ "$UDRIVE" != "$last_udrive" ]]; then
        REFRESH_REASON="udrive_update"
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
    UWORLD=$(./generate_ipfs_RPG.sh .) ## UPDATE MULTIPASS uWORLD
    cd - 2>&1 >/dev/null

    if [[ "$UWORLD" != "$last_uworld" ]]; then
        REFRESH_REASON="uworld_update"
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
    echo "==============================="
    echo "PLAYER = $PLAYER"
    echo "==============================="
    start=$(date +%s)
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
    if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/NPUB ]]; then
        mkdir -p ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}
        cp ${HOME}/.zen/game/nostr/${PLAYER}/NPUB ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/NPUB 2>/dev/null
    fi

    G1PUBNOSTR=$(cat ~/.zen/game/nostr/${PLAYER}/G1PUBNOSTR)
    COINS=$(cat ~/.zen/tmp/coucou/${G1PUBNOSTR}.COINS 2>/dev/null)
    [[ -z $COINS ]] && COINS=$($MY_PATH/../tools/COINScheck.sh ${G1PUBNOSTR} | tail -n 1)

    ## Add to node => swarm cache propagation (used by search_for_this_hex/email_in_uplanet.sh)
    if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/G1PUBNOSTR ]]; then
        echo "$G1PUBNOSTR" > ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/G1PUBNOSTR
    fi

    # Add validation for COINS value
    if [[ -n "$COINS" && "$COINS" != "null" ]]; then
        ZEN=$(echo "($COINS - 1) * 10" | bc | cut -d '.' -f 1)
    else
        ZEN=-10
    fi

    echo "${G1PUBNOSTR} ______ AMOUNT = ${COINS} G1 -> ${ZEN} ZEN"


    if [[ ! -s ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal && ${COINS} != "null" ]]; then
    ################################################################ PRIMAL RX CHECK
        echo "# NEW MULTIPASS${G1PUBNOSTR}.... checking primal transaction..."
        g1prime=$(get_primal_transaction "${G1PUBNOSTR}" 2>/dev/null | tail -n 1)
        ### CACHE PRIMAL TX SOURCE IN "COUCOU" BUCKET
        if [[ $? -eq 0 && ! -z ${g1prime} && ${g1prime} != "null" ]]; then
            echo "${g1prime}" > ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal
        else
            echo "Failed to get primal transaction for ${G1PUBNOSTR}"
            g1prime=""
        fi
    fi

    primal=$(cat ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal 2>/dev/null) ### PRIMAL READING
    ## test &correction of primal format (g1_to_ipfs.py)
    g1primetest=$(${MY_PATH}/../tools/g1_to_ipfs.py ${primal} 2>/dev/null)
    if [[ -z $g1primetest ]]; then
        g1prime=$(get_primal_transaction "${G1PUBNOSTR}" 2>/dev/null | tail -n 1)
        echo "${g1prime}" > ~/.zen/tmp/coucou/${G1PUBNOSTR}.primal
        primal=${g1prime}
    fi

    ## READING PRIMAL COINS from "coucou" cache
    pcoins=$(cat ~/.zen/tmp/coucou/${primal}.COINS 2>/dev/null)
    # Vérification du format de pcoins (entier ou décimal)
    if [[ ! "$pcoins" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        pcoins=$($MY_PATH/../tools/COINScheck.sh ${primal} | tail -n 1) ## PRIMAL COINS
    fi

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

    if [[ -n ${salt} && -n ${pepper} ]]; then
        rm "$tmp_mid" "$tmp_tail" 2>/dev/null
        rm ~/.zen/game/nostr/${PLAYER}/ERROR 2>/dev/null
    else
        echo "ERROR : BAD DISCO DECODING" >> ~/.zen/game/nostr/${PLAYER}/ERROR
        continue
    fi
    ##################################################### DISCO DECODED
    ## NOW salt & pepper are valid, we can generate NSEC & NPUB
    BIRTHDATE=$(cat ~/.zen/game/nostr/${PLAYER}/TODATE)
    ## s=/?email
    NSEC=$(${MY_PATH}/../tools/keygen -t nostr "${salt}" "${pepper}" -s)
    NPUB=$(${MY_PATH}/../tools/keygen -t nostr "${salt}" "${pepper}")
    echo $s

    ## CACHING SECRET & DISCO to NOSTR Card (.file = no ipfs !!)
    [[ ! -s ~/.zen/game/nostr/${PLAYER}/.secret.nostr ]] \
        && echo "NSEC=$NSEC; NPUB=$NPUB; HEX=$HEX;" > ~/.zen/game/nostr/${PLAYER}/.secret.nostr \
        && chmod 600 ~/.zen/game/nostr/${PLAYER}/.secret*

    ## CREATE DUNITER KEY
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/nostr/${PLAYER}/.secret.dunikey "${salt}" "${pepper}"
    chmod 600 ~/.zen/game/nostr/${PLAYER}/.secret.dunikey

    ########################################################################
    #~ EMPTY WALLET or without PRIMAL or COIN ? (NOT TODATE)
    ############################################################ BLOCKING
    ########################################################################
    if [[ $(echo "$COINS > 0" | bc -l) -eq 0 || "$COINS" == "null" || "${primal}" == "" ]]; then
        ## 2nd day MULTIPASS must have received PRIMAL RX
        if [[ ${TODATE} != ${BIRTHDATE} ]]; then
            if [[ ${UPLANETNAME} == "EnfinLibre" ]]; then
                # on UPlanet ORIGIN : From UPlanet Wallet
                echo "UPlanet ORIGIN : Send Primo RX from UPlanet : MULTIPASS activation"
                YOUSER=$(${MY_PATH}/../tools/clyuseryomail.sh ${PLAYER})
                ${MY_PATH}/../tools/PAYforSURE.sh "${HOME}/.zen/game/uplanet.dunikey" "${G1LEVEL1}" "${G1PUBNOSTR}" "UPLANET${UPLANETG1PUB:0:8}:MULTIPASS:${YOUSER}:${NPUB}" 2>/dev/null
                [[ $? -eq 0 ]] \
                    && echo "${UPLANETG1PUB}" > ~/.zen/game/nostr/${PLAYER}/G1PRIME
            else
                # on UPlanet Ẑen : From WoT member (except for CAPTAIN)
                echo "UPlanet Zen : NO PRIMAL RX received from Ğ1 Member"
                [[ "${PLAYER}" != "${CAPTAINEMAIL}" ]] \
                    && ${MY_PATH}/../tools/nostr_DESTROY_TW.sh "${PLAYER}" \
                    || echo "CAPTAIN ${CAPTAINEMAIL} has no PRIMAL"
            fi
        else
            ## 1st Day send welcome EMAIL...
            [[ ! -s ~/.zen/game/nostr/${PLAYER}/.welcome.html ]] \
            && cp ${MY_PATH}/../templates/NOSTR/welcome.html ~/.zen/game/nostr/${PLAYER}/.welcome.html \
            && sed -i "s/http:\/\/127.0.0.1:8080/${myIPFS}/g" ~/.zen/game/nostr/${PLAYER}/.welcome.html \
            && ${MY_PATH}/../tools/mailjet.sh "${PLAYER}" "${HOME}/.zen/game/nostr/${PLAYER}/.welcome.html" "WELCOME /ipns/$YOUSER"
        fi

        rm -Rf ~/.zen/tmp/${MOATS}
        continue
    fi

    ####################################################################
    ## EVERY 7 DAYS NOSTR CARD is PAYING CAPTAIN
    TODATE_SECONDS=$(date -d "$TODATE" +%s)
    BIRTHDATE_SECONDS=$(date -d "$BIRTHDATE" +%s)
    # Calculate the difference in days
    DIFF_DAYS=$(( (TODATE_SECONDS - BIRTHDATE_SECONDS) / 86400 ))
    
    # Calculate next payment date (next multiple of 7 days from birthdate)
    NEXT_PAYMENT_DAYS=$(( ((DIFF_DAYS / 7) + 1) * 7 ))
    NEXT_PAYMENT_SECONDS=$(( BIRTHDATE_SECONDS + (NEXT_PAYMENT_DAYS * 86400) ))
    NEXT_PAYMENT_DATE=$(date -d "@$NEXT_PAYMENT_SECONDS" '+%Y-%m-%d')
    
    # Get player's refresh time for payment hour
    PLAYER_REFRESH_TIME=$(cat ~/.zen/game/nostr/${PLAYER}/.refresh_time 2>/dev/null)
    [[ -z "$PLAYER_REFRESH_TIME" ]] && PLAYER_REFRESH_TIME="00:00"
    
    echo "💰 Next weekly payment for ${PLAYER}: $NEXT_PAYMENT_DATE at $PLAYER_REFRESH_TIME (in $((NEXT_PAYMENT_DAYS - DIFF_DAYS)) days)"
    
    # Check if the difference is a multiple of 7 // Weekly cycle
    if [[ ${CAPTAING1PUB} != ${G1PUBNOSTR} ]]; then
        if [ $((DIFF_DAYS % 7)) -eq 0 ]; then
            # Check if payment was already made today
            last_payment_file="${HOME}/.zen/game/nostr/${PLAYER}/.lastpayment"
            if [[ ! -s "$last_payment_file" || "$(cat "$last_payment_file")" != "$TODATE" ]]; then
                if [[ $(echo "$COINS > 1" | bc -l) -eq 1 ]]; then
                    ## Pay NCARD to CAPTAIN
                    [[ -z $NCARD ]] && NCARD=1
                    Gpaf=$(makecoord $(echo "$NCARD / 10" | bc -l))
                    echo "[7 DAYS CYCLE] $TODATE is MULTIPASS NOSTR Card $NCARD ẐEN PAYMENT ($COINS G1) !!"
                    payment_result=$(${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/nostr/${PLAYER}/.secret.dunikey" "$Gpaf" "${CAPTAING1PUB}" "NOSTR:${UPLANETG1PUB:0:8}:PAF" 2>/dev/null)
                    if [[ $? -eq 0 ]]; then
                        # Record successful payment
                        echo "$TODATE" > "$last_payment_file"
                        echo "✅ Weekly payment recorded for ${PLAYER} on $TODATE"
                        PAYMENTS_PROCESSED=$((PAYMENTS_PROCESSED + 1))
                    else
                        echo "❌ Weekly payment failed for ${PLAYER} on $TODATE"
                        PAYMENTS_FAILED=$((PAYMENTS_FAILED + 1))
                    fi
                else
                    echo "[7 DAYS CYCLE] NOSTR Card ($COINS G1) - insufficient funds !!"
                    if [[ "${PLAYER}" != "${CAPTAINEMAIL}" ]]; then
                        ${MY_PATH}/../tools/nostr_DESTROY_TW.sh "${PLAYER}"
                    fi
                    continue
                fi
            else
                echo "[7 DAYS CYCLE] Weekly payment already processed for ${PLAYER} on $TODATE"
                PAYMENTS_ALREADY_DONE=$((PAYMENTS_ALREADY_DONE + 1))
            fi
        fi
    else
        echo "___ CAPTAIN WALLET ACCOUNT : $COINS G1"
    fi

    ########################################################################
    echo ">>> VALID MULTIPASS ($pcoins G1) : ${primal}"
    ########################################################################
    ## ACTIVATED NOSTR CARD
    NOSTRNS=$(cat ~/.zen/game/nostr/${PLAYER}/NOSTRNS)
    echo "IPNS VAULT : ${myIPFS}${NOSTRNS}"

    ## FILL UP NOSTRCard/PRIMAL
    if [[ ${primal} != "" && ${primal} != "null"  ]]; then
        if [[ ! -d ~/.zen/game/nostr/${PLAYER}/PRIMAL ]]; then
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
        [[ ! -s ~/.zen/game/nostr/${PLAYER}/G1PRIME ]] \
            && echo ${primal} > ~/.zen/game/nostr/${PLAYER}/G1PRIME # G1PRIME fixing
    fi

    ## PRIMAL RX SOURCE ?!
    G1PRIME=$(cat ~/.zen/game/nostr/${PLAYER}/G1PRIME 2>/dev/null)
    
    ## Validate and clean G1PRIME if it contains debug output
    if [[ -n "$G1PRIME" && ("$G1PRIME" =~ "Trying primal check" || "$G1PRIME" =~ "BMAS NODE") ]]; then
        echo "Cleaning corrupted G1PRIME file for ${PLAYER}"
        # Extract only the G1PUB part (last line should be the G1PUB)
        G1PRIME=$(echo "$G1PRIME" | tail -n 1 | tr -d ' ')
        echo "$G1PRIME" > ~/.zen/game/nostr/${PLAYER}/G1PRIME
    fi
    
    ## CHECKING PRIMAL IPFS conversion (correction)
    # Validate G1PUB format (should be base58 encoded, typically 44 characters)
    if [[ -n "$G1PRIME" && ${#G1PRIME} -eq 44 && "$G1PRIME" =~ ^[1-9A-HJ-NP-Za-km-z]+$ ]]; then
        G1PRIME_IPFS=$(${MY_PATH}/../tools/g1_to_ipfs.py ${G1PRIME} 2>/dev/null)
        if [[ -z $G1PRIME_IPFS ]]; then
            echo "G1PRIME BAD FORMAT: $G1PRIME" >> ~/.zen/game/nostr/${PLAYER}/ERROR
            echo "ERROR G1PRIME BAD FORMAT: $G1PRIME" && continue
        fi
    else
        echo "G1PRIME INVALID FORMAT: $G1PRIME" >> ~/.zen/game/nostr/${PLAYER}/ERROR
        echo "ERROR G1PRIME INVALID FORMAT: $G1PRIME" && continue
    fi

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
                ## SENDING CESIUM+ MESSAGE to G1PRIME
                $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/game/nostr/${PLAYER}/.secret.dunikey -n ${myCESIUM} send -d "${G1PRIME}" -t "NOSTR UPassport" -m "NOSTR App : $myIPFS${NOSTRNS}"
                ## TODO CONVERT SEND NOSTR MULTIPASS MESSAGE
            else
                echo "## /PRIMAL file structure existing : $G1PRIME"
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
                                $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/game/nostr/${PLAYER}/.secret.dunikey -n ${myCESIUM} send -d "$G1PRIME" -t " ¯\_༼qO͡〰op༽_/¯ 12P ?" -m "BRO Certification <=> $G1PUB"
                                sleep 1
                            elif [[ "$KEY" == "certout" ]]; then
                                $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/game/nostr/${PLAYER}/.secret.dunikey -n ${myCESIUM} send -d "$G1PUB" -t " ¯\_༼qO͡〰op༽_/¯ P21 ?" -m "BRO Certification <=> $G1PRIME"
                                sleep 1
                            fi
                            MESSAGE="$G1PRIME est inscrit sur UPlanet --- UPlanet : $myIPFS/ipns/copylaradio.com"
                            $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/game/nostr/${PLAYER}/.secret.dunikey -n ${myCESIUM} send -d "$G1PUB" -t " ¯\_༼qO͡〰op༽_/¯ " -m "$MESSAGE"
                            echo "$MESSAGE" > ~/.zen/game/nostr/${PLAYER}/PRIMAL/$G1PUB.txt
                            sleep 2
                        fi
                    done
                fi

            fi
        fi
    else
        #### UPASSPORT DU : Cooperative Real Member
        echo "## OFFICIAL PDF UPASSPORT : ${primal} is STATION co OWNER !!"
    fi

    YOUSER=$(${MY_PATH}/../tools/clyuseryomail.sh ${PLAYER})

    ########################################################################
    ######### NOSTR PROFILE SETTING
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

        ## Indicate "NOSTRG1PUB:primal" into nostr profile 
        if [[ -d ~/.zen/game/nostr/${PLAYER}/PRIMAL/N1 ]]; then
            # Member Wallet
            PoH=":${primal}"
        else
            # REGULAR Wallet
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
            --ipns_vault "${NOSTRNS}" \
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
        ## Create ZENCARD ONLY FOR UPlanet Zen #################################################
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
    echo "Checking MULTIPASS wallet for $PLAYER: $G1PUBNOSTR"

    # Use the generic primal wallet control function
    if [[ ${UPLANETNAME} != "EnfinLibre" ]]; then
        # Get DISCO from PLAYER to create dunikey if needed
        if [[ ! -s ~/.zen/game/nostr/${PLAYER}/.secret.dunikey ]]; then
            DISCO=$(cat ~/.zen/game/nostr/${PLAYER}/.secret.disco)
            IFS='=&' read -r s salt p pepper <<< "$DISCO"
            # Create secret.dunikey from DISCO
            if [[ -n $salt && -n $pepper ]]; then
                ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/nostr/${PLAYER}/.secret.dunikey "${salt}" "${pepper}"
            fi
        fi
        echo "## CONTROL MULTIPASS TRANSACTIONS..."
        # Call the generic primal wallet control function
        ${MY_PATH}/../tools/primal_wallet_control.sh \
            "${HOME}/.zen/game/nostr/${PLAYER}/.secret.dunikey" \
            "${G1PUBNOSTR}" \
            "${UPLANETG1PUB}" \
            "${PLAYER}"
    else
        echo "UPlanet ORIGIN - No primal control"
    fi

    ## ADD AMIS of AMIS -- friends of registered MULTIPASS can use our nostr relay
    fof_list=($($MY_PATH/../tools/nostr_get_N1.sh $HEX 2>/dev/null))
    if [[ ${#fof_list[@]} -gt 0 ]]; then
        echo "Adding ${#fof_list[@]} friends hex into amisOfAmis.txt"
        printf "%s\n" "${fof_list[@]}" >> "${HOME}/.zen/strfry/amisOfAmis.txt"
    fi

    refreshtime="$(cat ~/.zen/game/nostr/${PLAYER}/.todate) $(cat ~/.zen/game/nostr/${PLAYER}/.refresh_time)"
    echo "\m/_(>_<)_\m/ ($refreshtime)"
    echo "${PLAYER} $COINS G1 -> ${ZEN} ZEN : ${HEX}"
    echo "UDRIVE : $(cat ~/.zen/game/nostr/${PLAYER}/.udrive 2>/dev/null)"

    # Vérifier si le rafraîchissement est nécessaire
    should_refresh "${PLAYER}"
    refresh_needed=$?
    
    # Si pas de rafraîchissement nécessaire, continuer
    if [[ $refresh_needed -eq 1 ]]; then
        echo "No refresh needed for ${PLAYER} - skipping"
        SKIPPED_PLAYERS=$((SKIPPED_PLAYERS + 1))
        continue
    fi

    ########################################################################################
    ########################################################################################
    ## UPDATE IPNS NOSTRVAULT KEY - Only when refresh is needed
    if [[ $refresh_needed -eq 0 ]]; then
        echo "IPNS update triggered for ${PLAYER} - Reason: $REFRESH_REASON"
        echo "## $myIPFS$NOSTRNS"
        
        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/nostr.ipns "${salt}" "${pepper}"
        ipfs key rm "${G1PUBNOSTR}:NOSTR" > /dev/null 2>&1
        NOSTRNS=$(ipfs key import "${G1PUBNOSTR}:NOSTR" -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/nostr.ipns)
        ## UPDATE IPNS RESOLVE
        NOSTRIPFS=$(ipfs add -rwq ${HOME}/.zen/game/nostr/${PLAYER}/ | tail -n 1)
        ipfs name publish --key "${G1PUBNOSTR}:NOSTR" /ipfs/${NOSTRIPFS}
        
        # Record the last IPNS update time
        date +%s > ${HOME}/.zen/game/nostr/${PLAYER}/.last_ipns_update
        
        # Update .todate only for daily updates, not for new files
        if [[ "$REFRESH_REASON" == "daily_update" ]]; then
            echo "$TODATE" > ${HOME}/.zen/game/nostr/${PLAYER}/.todate
            echo "Daily refresh completed for ${PLAYER}"
            DAILY_UPDATES=$((DAILY_UPDATES + 1))
        elif [[ "$REFRESH_REASON" == "new_files" ]]; then
            echo "IPNS updated due to new files for ${PLAYER}"
            FILE_UPDATES=$((FILE_UPDATES + 1))
        elif [[ "$REFRESH_REASON" == "udrive_update" ]]; then
            echo "IPNS updated due to uDRIVE changes for ${PLAYER}"
            FILE_UPDATES=$((FILE_UPDATES + 1))
        elif [[ "$REFRESH_REASON" == "uworld_update" ]]; then
            echo "IPNS updated due to uWORLD changes for ${PLAYER}"
            FILE_UPDATES=$((FILE_UPDATES + 1))
        else
            echo "IPNS updated for ${PLAYER} (unknown reason: $REFRESH_REASON)"
            FILE_UPDATES=$((FILE_UPDATES + 1))
        fi
    else
        echo "IPNS update skipped for ${PLAYER} (no refresh needed)"
    fi
    echo "___________________________________________________ $TODATE"
    stop=$(date +%s)
    echo "## MULTIPASS refresh DONE in $((stop - start)) seconds"

done

end=`date +%s`
dur=`expr $end - $gstart`
hours=$((dur / 3600)); minutes=$(( (dur % 3600) / 60 )); seconds=$((dur % 60))
echo "DURATION ${hours} hours ${minutes} minutes ${seconds} seconds"

# Afficher un résumé concis
echo ""
echo "============================================ NOSTR REFRESH SUMMARY"
echo "📊 Players: ${#NOSTR[@]} total | $DAILY_UPDATES daily | $FILE_UPDATES files | $SKIPPED_PLAYERS skipped"
echo "💰 Payments: $PAYMENTS_PROCESSED processed | $PAYMENTS_FAILED failed | $PAYMENTS_ALREADY_DONE already done"
echo "============================================ NOSTR.refresh DONE."
rm -Rf ~/.zen/tmp/${MOATS}
rm -f "$LOCKFILE"

exit 0
