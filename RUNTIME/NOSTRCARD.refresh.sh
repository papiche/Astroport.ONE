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
# 2. Gère les paiements des cartes NOSTR (cycles 7 jours) avec distribution temporelle
#    - Chaque carte a une heure de paiement aléatoire stockée dans .refresh_time
#    - Les paiements ne sont traités qu'après l'heure programmée pour éviter la simultanéité
# 3. Implémente le système de distribution des bénéfices
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh"

[[ -z ${IPFSNODEID} ]] && echo "ERROR ASTROPORT BROKEN" && exit 1

# =================== LOGGING SYSTEM ===================
LOGFILE="$HOME/.zen/tmp/nostr_MULTIPASS.refresh.log"
mkdir -p "$(dirname "$LOGFILE")"

# Logging function with timestamp and PID
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$$] [$level] $*" | tee -a "$LOGFILE"
}

# Log performance metrics
log_metric() {
    local metric="$1"
    local value="$2"
    local player="${3:-GLOBAL}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$$] [METRIC] [$player] $metric=$value" >> "$LOGFILE"
}

# Redirect stderr to log file for debugging
exec 2> >(while read line; do log "ERROR" "$line"; done)

log "INFO" "Starting NOSTRCARD.refresh.sh - PID: $$"
# ======================================================
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
    # Générer un nombre aléatoire de minutes entre 1 et 1212 (avant 20h12 - Astroport Refresh Time)
    local random_minutes=$(( (RANDOM % 1212) - 1 ))
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
    local random_time=$(get_random_refresh_time)
    echo "$random_time" > "${player_dir}/.refresh_time"

    # Initialiser le jour du dernier rafraîchissement
    echo "$TODATE" > "${player_dir}/.todate"

    # Initialiser le fichier TODAY (date de début de contrat), .birthdate (= date inscription)
    [[ ! -s "${player_dir}/TODATE" ]] \
        && echo "$TODATE" > "${player_dir}/TODATE" \
        && echo "$TODATE" > "${player_dir}/.birthdate"

    # Initialiser le fichier de dernière mise à jour IPNS
    date +%s > "${player_dir}/.last_ipns_update"

    # Initialiser le fichier de dernier paiement
    echo "" > "${player_dir}/.lastpayment"

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
    ## uDRIVE APP UPDATE
    [[ ! -d ${player_dir}/APP/uDRIVE ]] \
        && rm -Rf ${player_dir}/APP \
        && mkdir -p ${player_dir}/APP/uDRIVE/

    ## Verify Link
    [[ ! -e "${player_dir}/APP/uDRIVE/generate_ipfs_structure.sh" ]] && \
        cd "${player_dir}/APP/uDRIVE" && \
        ln -sf "${HOME}/.zen/Astroport.ONE/tools/generate_ipfs_structure.sh" "generate_ipfs_structure.sh"

    ## update uDRIVE APP
    cd ${player_dir}/APP/uDRIVE/
    UDRIVE=$(./generate_ipfs_structure.sh .)
    cd - 2>&1 >/dev/null

    if [[ -n "$UDRIVE" ]]; then
        if [[ "$UDRIVE" != "$last_udrive" ]]; then
            if [[ -n "$last_udrive" ]]; then
                ipfs --timeout 20s pin rm "$last_udrive" 2>/dev/null
            fi
            echo "$UDRIVE" > "${last_udrive_file}"
            REFRESH_REASON="udrive_update"
            return 0
        else
            echo "$UDRIVE" > "${last_udrive_file}"
            echo "UDRIVE CID: $last_udrive"
        fi
    else
        echo "UDRIVE CID: $last_udrive"
    fi

    # ########################################################### NEED EXTRA DEV
    # ## uWORLD Link
    # [[ ! -e "${player_dir}/APP/uWORLD/generate_ipfs_RPG.sh" ]] && \
    #     mkdir -p "${player_dir}/APP/uWORLD" && \
    #     cd ${player_dir}/APP/uWORLD/ && \
    #     ln -sf "${HOME}/.zen/Astroport.ONE/tools/generate_ipfs_RPG.sh" "generate_ipfs_RPG.sh"

    # ## update uWORLD APP
    # cd ${player_dir}/APP/uWORLD/
    # UWORLD=$(./generate_ipfs_RPG.sh .)
    # cd - 2>&1 >/dev/null

    # if [[ -n "$UWORLD" ]]; then
    #     if [[ "$UWORLD" != "$last_uworld"  ]]; then
    #        if [[ -n "$last_uworld" ]]; then
    #             ipfs --timeout 20s pin rm "$last_uworld" 2>/dev/null
    #         fi
    #         echo $UWORLD > "${last_uworld_file}"
    #         REFRESH_REASON="uworld_update"
    #         return 0
    #     else
    #         echo $UWORLD > "${last_uworld_file}"
    #         echo "UWORLD CID: $last_uworld"
    #     fi
    # else
    #     echo "UWORLD CID: $last_uworld"
    # fi
    return 1
}

[[ ${UPLANETG1PUB:0:8} == "AwdjhpJN" ]] && ORIGIN="ORIGIN" || ORIGIN="${UPLANETG1PUB:0:8}"

########################################################################
# Get all emails from ~/.zen/game/nostr/
NOSTR=($(ls -t ~/.zen/game/nostr/ 2>/dev/null | grep "@" ))

## RUNING FOR ALL LOCAL MULTIPASS (NOSTR Card)
for PLAYER in "${NOSTR[@]}"; do
    log "INFO" ">>>>>>>>>>>>>>>>>> Processing MULTIPASS : $PLAYER ============================================"
    start=$(date +%s)
    HEX=$(cat ~/.zen/game/nostr/${PLAYER}/HEX 2>/dev/null)
    [[ -z "$HEX" ]] && log "ERROR" "Missing HEX for $PLAYER" && continue

    ## SWARM CACHE PUBLISHING
    if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/HEX ]]; then
        mkdir -p ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}
        echo "$HEX" > ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/HEX
    fi
    if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/GPS ]]; then
        mkdir -p ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}
        cp ${HOME}/.zen/game/nostr/${PLAYER}/GPS ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/GPS 2>/dev/null
    fi

    ## LAT & LON
    source ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/GPS

    if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/NPUB ]]; then
        mkdir -p ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}
        cp ${HOME}/.zen/game/nostr/${PLAYER}/NPUB ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/NPUB 2>/dev/null
    fi

    G1PUBNOSTR=$(cat ~/.zen/game/nostr/${PLAYER}/G1PUBNOSTR)
    ## Add to node => swarm cache propagation (used by search_for_this_hex/email_in_uplanet.sh)
    if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/G1PUBNOSTR ]]; then
        echo "$G1PUBNOSTR" > ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/G1PUBNOSTR
    fi

    COINS=$(cat ~/.zen/tmp/coucou/${G1PUBNOSTR}.COINS 2>/dev/null)
    if [[ -z $COINS || "$COINS" == "null" ]]; then
        log "DEBUG" "Cache miss for $G1PUBNOSTR, refreshing with G1check.sh"
        COINS=$(${MY_PATH}/../tools/G1check.sh ${G1PUBNOSTR} 2>/dev/null | tail -n 1)
        log_metric "CACHE_MISS" "1" "${PLAYER}"
    else
        log_metric "CACHE_HIT" "1" "${PLAYER}"
    fi

    # Convert COINS value into ẐEN
    if [[ -n "$COINS" && "$COINS" != "null" ]]; then
        ZEN=$(echo "($COINS - 1) * 10" | bc | cut -d '.' -f 1)
    else
        ZEN=-10
    fi

    log "INFO" "${G1PUBNOSTR} AMOUNT = ${COINS} G1 -> ${ZEN} ZEN"
    log_metric "WALLET_BALANCE" "${COINS}" "${PLAYER}"

    BIRTHDATE=$(cat ~/.zen/game/nostr/${PLAYER}/TODATE 2>/dev/null)
    [[ ! -s ~/.zen/game/nostr/${PLAYER}/.birthdate ]] \
        && echo $BIRTHDATE > ~/.zen/game/nostr/${PLAYER}/.birthdate

    ################################################################# ~/.zen/game/uplanet.dunikey
    [[ ! -s ~/.zen/game/uplanet.dunikey ]] \
        && ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.dunikey "${UPLANETNAME}" "${UPLANETNAME}" \
        && chmod 600 ~/.zen/game/uplanet.dunikey
    ###################### DISCO DECRYPTION - with Captain + UPlanet parts
    if [[ ! -s ~/.zen/game/nostr/${PLAYER}/.secret.disco ]]; then
        tmp_mid=$(mktemp)
        tmp_tail=$(mktemp)
        # Decrypt the middle part using CAPTAIN key
        ${MY_PATH}/../tools/natools.py decrypt -f pubsec -i "$HOME/.zen/game/nostr/${PLAYER}/.ssss.mid.captain.enc" \
                -k ~/.zen/game/players/.current/secret.dunikey -o "$tmp_mid"

        # Decrypt the tail part using UPLANET dunikey
        ${MY_PATH}/../tools/natools.py decrypt -f pubsec -i "$HOME/.zen/game/nostr/${PLAYER}/ssss.tail.uplanet.enc" \
                -k ~/.zen/game/uplanet.dunikey -o "$tmp_tail"

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
    ## s=/?email
    echo $s

    ## CACHING SECRET & DISCO to nostr/${PLAYER}/.secret.nostr
    if [[ ! -s ~/.zen/game/nostr/${PLAYER}/.secret.nostr ]]; then
        NSEC=$(${MY_PATH}/../tools/keygen -t nostr "${salt}" "${pepper}" -s)
        NPUB=$(${MY_PATH}/../tools/keygen -t nostr "${salt}" "${pepper}")
        echo "NSEC=$NSEC; NPUB=$NPUB; HEX=$HEX;" > ~/.zen/game/nostr/${PLAYER}/.secret.nostr
        chmod 600 ~/.zen/game/nostr/${PLAYER}/.secret*
    else
        source ~/.zen/game/nostr/${PLAYER}/.secret.nostr
    fi

    ## CREATE nostr/${PLAYER}/.secret.dunikey
    if [[ ! -s ~/.zen/game/nostr/${PLAYER}/.secret.dunikey ]]; then
        ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/nostr/${PLAYER}/.secret.dunikey "${salt}" "${pepper}"
        chmod 600 ~/.zen/game/nostr/${PLAYER}/.secret.dunikey
    fi
    ########################################################################
    YOUSER=$(${MY_PATH}/../tools/clyuseryomail.sh ${PLAYER})
    ########################################################################
    # Send welcome message on 1st day
    if [[ $(echo "$COINS > 0" | bc -l) -eq 0 || "$COINS" == "null" ]]; then
        if [[ ${TODATE} == ${BIRTHDATE} ]]; then
            ## 1st Day send welcome EMAIL...
            if [[ ! -s ~/.zen/game/nostr/${PLAYER}/.welcome.html ]]; then
                cp ${MY_PATH}/../templates/NOSTR/welcome.html ~/.zen/game/nostr/${PLAYER}/.welcome.html \
                && sed -i "s/http:\/\/127.0.0.1:8080/${myIPFS}/g" ~/.zen/game/nostr/${PLAYER}/.welcome.html \
                && ${MY_PATH}/../tools/mailjet.sh "${PLAYER}" "${HOME}/.zen/game/nostr/${PLAYER}/.welcome.html" "WELCOME $YOUSER"
                log "INFO" "Welcome email sent to new MULTIPASS: ${PLAYER}"
                log_metric "WELCOME_EMAIL_SENT" "1" "${PLAYER}"
             fi
        fi
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

    log "INFO" "💰 Next weekly payment for ${PLAYER}: $NEXT_PAYMENT_DATE at $PLAYER_REFRESH_TIME (in $((NEXT_PAYMENT_DAYS - DIFF_DAYS)) days)"

    # Check if the difference is a multiple of 7 // Weekly cycle
    if [[ ! -s ~/.zen/game/players/${PLAYER}/U.SOCIETY ]]; then
        if [[ ${CAPTAING1PUB} != ${G1PUBNOSTR} ]]; then
            # First payment only after 7 days minimum (exclude J0 where DIFF_DAYS=0)
            if [ $DIFF_DAYS -ge 7 ] && [ $((DIFF_DAYS % 7)) -eq 0 ]; then
                # Check if payment was already made today
                last_payment_file="${HOME}/.zen/game/nostr/${PLAYER}/.lastpayment"
                if [[ ! -s "$last_payment_file" || "$(cat "$last_payment_file")" != "$TODATE" ]]; then
                    # Check if current time has passed the player's refresh time for payment
                    current_time=$(date '+%H:%M')
                    player_refresh_time=$(cat ~/.zen/game/nostr/${PLAYER}/.refresh_time 2>/dev/null)
                    [[ -z "$player_refresh_time" ]] && player_refresh_time="00:00"

                    # Convert times to seconds since midnight for comparison
                    current_seconds=$((10#${current_time%%:*} * 3600 + 10#${current_time##*:} * 60))
                    refresh_seconds=$((10#${player_refresh_time%%:*} * 3600 + 10#${player_refresh_time##*:} * 60))

                    # Only process payment if current time has passed the refresh time
                    if [[ $current_seconds -ge $refresh_seconds ]]; then
                        ## Pay NCARD to CAPTAIN with TVA provision
                        [[ -z $NCARD ]] && NCARD=1
                        Npaf=$(makecoord $(echo "$NCARD / 10" | bc -l))

                        # Calculate TVA provision (20% of rental payment)
                        [[ -z $TVA_RATE ]] && TVA_RATE=20
                        TVA_AMOUNT=$(echo "scale=4; $Npaf * $TVA_RATE / 100" | bc -l)
                        TVA_AMOUNT=$(makecoord $TVA_AMOUNT)
                        
                        # Calculate total payment needed (HT + TVA)
                        TOTAL_PAYMENT=$(echo "scale=4; $Npaf + $TVA_AMOUNT" | bc -l)
                        # Minimum balance required: 1 Ğ1 (0 ẐEN threshold) + payment amount
                        MIN_BALANCE=$(echo "scale=4; 1 + $TOTAL_PAYMENT" | bc -l)
                        
                        if [[ $(echo "$COINS >= $MIN_BALANCE" | bc -l) -eq 1 ]]; then

                            log "INFO" "[7 DAYS CYCLE] $TODATE is NOSTR Card $NCARD ẐEN MULTIPASS PAYMENT ($COINS G1 >= $MIN_BALANCE G1 min) - Direct TVA split: $Npaf ẐEN to CAPTAIN + $TVA_AMOUNT ẐEN to IMPOTS"

                            # Ensure IMPOTS wallet exists before any payment
                            if [[ ! -s ~/.zen/game/uplanet.IMPOT.dunikey ]]; then
                                ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.IMPOT.dunikey "${UPLANETNAME}.IMPOT" "${UPLANETNAME}.IMPOT"
                                chmod 600 ~/.zen/game/uplanet.IMPOT.dunikey
                            fi

                            # Get IMPOTS wallet G1PUB
                            IMPOTS_G1PUB=$(cat ~/.zen/game/uplanet.IMPOT.dunikey |  grep "pub:" | cut -d ' ' -f 2)

                            # Main rental payment to CAPTAIN (HT amount only)
                            payment_result=$(${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/nostr/${PLAYER}/.secret.dunikey" "$Npaf" "${CAPTAING1PUB}" "UPLANET:${ORIGIN}:${IPFSNODEID: -12}:$YOUSER:NCARD:HT" 2>/dev/null)
                            payment_success=$?

                            # TVA provision directly from MULTIPASS to IMPOTS (fiscally correct)
                            tva_success=0
                            if [[ $payment_success -eq 0 && $(echo "$TVA_AMOUNT > 0" | bc -l) -eq 1 && -n "$IMPOTS_G1PUB" ]]; then
                                tva_result=$(${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/nostr/${PLAYER}/.secret.dunikey" "$TVA_AMOUNT" "${IMPOTS_G1PUB}" "UPLANET:${ORIGIN}:${IPFSNODEID: -12}:$YOUSER:TVA" 2>/dev/null)
                                tva_success=$?
                                if [[ $tva_success -eq 0 ]]; then
                                    log "INFO" "✅ TVA provision recorded directly from MULTIPASS for ${PLAYER} on $TODATE ($TVA_AMOUNT ẐEN)"
                                    log_metric "TVA_PROVISION_SUCCESS" "$TVA_AMOUNT" "${PLAYER}"
                                else
                                    log "WARN" "❌ TVA provision failed for ${PLAYER} on $TODATE ($TVA_AMOUNT ẐEN)"
                                    log_metric "TVA_PROVISION_FAILED" "$TVA_AMOUNT" "${PLAYER}"
                                fi
                            else
                                log "ERROR" "❌ IMPOTS wallet not found for TVA provision"
                            fi

                            # Check if both payments succeeded
                            if [[ $payment_success -eq 0 && ($tva_success -eq 0 || $(echo "$TVA_AMOUNT == 0" | bc -l) -eq 1) ]]; then
                                # Record successful payment
                                echo "$TODATE" > "$last_payment_file"
                                log "INFO" "✅ Weekly payment recorded for ${PLAYER} on $TODATE ($Npaf ẐEN HT + $TVA_AMOUNT ẐEN TVA) - Fiscally compliant split"
                                log_metric "PAYMENT_SUCCESS" "$Npaf" "${PLAYER}"
                                PAYMENTS_PROCESSED=$((PAYMENTS_PROCESSED + 1))
                            else
                                # Payment failed - send error email
                                if [[ $payment_success -ne 0 ]]; then
                                    log "ERROR" "❌ Main MULTIPASS payment failed for ${PLAYER} on $TODATE ($Npaf ẐEN)"
                                    log_metric "PAYMENT_FAILED" "$Npaf" "${PLAYER}"
                                fi
                                if [[ $tva_success -ne 0 && $(echo "$TVA_AMOUNT > 0" | bc -l) -eq 1 ]]; then
                                    log "ERROR" "❌ TVA provision failed for ${PLAYER} on $TODATE ($TVA_AMOUNT ẐEN)"
                                    log_metric "TVA_PROVISION_FAILED" "$TVA_AMOUNT" "${PLAYER}"
                                fi

                                # Send error email via mailjet
                                error_message="<html><head><meta charset='UTF-8'>
<style>
    body { font-family: 'Courier New', monospace; }
    .error { color: red; font-weight: bold; }
    .details { background-color: #f5f5f5; padding: 10px; margin: 10px 0; }
</style></head><body>
<h2 class='error'>❌ MULTIPASS Payment Error</h2>
<div class='details'>
<p><strong>Player:</strong> ${PLAYER}</p>
<p><strong>Date:</strong> $TODATE</p>
<p><strong>Amount HT:</strong> $Npaf ẐEN</p>
<p><strong>TVA Amount:</strong> $TVA_AMOUNT ẐEN</p>
<p><strong>Payment Status:</strong> Main: $([ $payment_success -eq 0 ] && echo "✅" || echo "❌") | TVA: $([ $tva_success -eq 0 ] && echo "✅" || echo "❌")</p>
<p><strong>Balance:</strong> $COINS G1 ($ZEN ẐEN)</p>
</div>
<p>Both payments must succeed for fiscal compliance.</p>
</body></html>"

                                ${MY_PATH}/../tools/mailjet.sh "${PLAYER}" <(echo "$error_message") "MULTIPASS Payment Error - $TODATE"
                                log "INFO" "Error email sent to ${PLAYER} for payment failure"
                            fi
                        else
                            # Check if MULTIPASS is less than 7 days old (grace period)
                            if [[ $DIFF_DAYS -lt 7 ]]; then
                                log "INFO" "[7 DAYS CYCLE] NOSTR Card ($COINS G1) - Grace period for new MULTIPASS (${DIFF_DAYS} days old)"
                                continue
                            fi
                            
                            log "WARN" "[7 DAYS CYCLE] NOSTR Card ($COINS G1) - insufficient funds! Need at least $MIN_BALANCE Ğ1 (1 Ğ1 minimum + $TOTAL_PAYMENT Ğ1 payment). Destroying if not captain"
                            if [[ "${PLAYER}" != "${CAPTAINEMAIL}" ]]; then
                                ${MY_PATH}/../tools/nostr_DESTROY_TW.sh "${PLAYER}"
                            fi
                            continue
                        fi
                    else
                        log "DEBUG" "[7 DAYS CYCLE] Payment time not reached for ${PLAYER} (current: $current_time, scheduled: $player_refresh_time)"
                        PAYMENTS_ALREADY_DONE=$((PAYMENTS_ALREADY_DONE + 1))
                    fi
                else
                    log "DEBUG" "[7 DAYS CYCLE] Weekly payment already processed for ${PLAYER} on $TODATE"
                    PAYMENTS_ALREADY_DONE=$((PAYMENTS_ALREADY_DONE + 1))
                fi
            fi
        else
            echo "___ CAPTAIN WALLET ACCOUNT : $COINS G1"
        fi
    else
        echo "U SOCIETY MEMBER "
        UDATE=$(cat ~/.zen/game/players/${PLAYER}/U.SOCIETY)
        ## CHECK VALIDITY (less than a year ?)
        TODATE_SECONDS=$(date --date="$TODATE" +%s)
        UDATE_SECONDS=$(date --date="$UDATE" +%s)
        DIFF_SECONDS=$((TODATE_SECONDS - UDATE_SECONDS))
        DIFF_DAYS=$((DIFF_SECONDS / 86400))
        if [ $DIFF_DAYS -lt 365 ]; then
            echo "OK VALID $((365 - DIFF_DAYS)) days left..."
        else
            echo "GAME OVER since $((DIFF_DAYS - 365))"
        fi
        if [[ $DIFF_DAYS == 365 ]]; then
            echo "### ENDING U SOCIETY FREE MODE"
            rm ~/.zen/game/players/${PLAYER}/U.SOCIETY
            rm ~/.zen/game/nostr/${PLAYER}/U.SOCIETY
            ${HOME}/.zen/Astroport.ONE/tools/mailjet.sh "${PLAYER}" "$HOME/.zen/game/passport/${PUBKEY}/.passport.html" "PLEASE RENEW"
        fi
    fi

    ########################################################################
    echo ">>> CHECKING MULTIPASS ($pcoins G1)"
    ########################################################################
    ## ACTIVATED NOSTR CARD
    NOSTRNS=$(cat ~/.zen/game/nostr/${PLAYER}/NOSTRNS)
    echo "uDRIVE : ${myIPFS}${NOSTRNS}/${PLAYER}/APP/uDRIVE"

    ########################################################################
    ######### NOSTR PROFILE SETTING
    if [[ ! -s ~/.zen/game/nostr/${PLAYER}/nostr_setup_profile ]]; then
        echo "######################################## SETUP NOSTR PROFILE"

        ## SETUP PROFILE VARIABLES
        title="$YOUSER"
        city="UPlanet ${ORIGIN}"
        description="💬 ${uSPOT}/nostr + ❤️ = Ẑen : ${uSPOT}/check_balance?g1pub=${PLAYER}"
        zavatar="/ipfs/"$(cat ${HOME}/.zen/game/nostr/${PLAYER}/MULTIPASS.QR.png.cid 2>/dev/null)
        ## ELSE ASTROPORT LOGO
        [[ $zavatar == "/ipfs/" ]] \
            && zavatar="/ipfs/QmbMndPqRHtrG2Wxtzv6eiShwj3XsKfverHEjXJicYMx8H/logo.png"

        ZENCARDG1=$(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null)
        G1PUBNOSTR=$(cat ${HOME}/.zen/game/nostr/${PLAYER}/G1PUBNOSTR)
        ### SEND PROFILE TO NOSTR RELAYS
        ${MY_PATH}/../tools/nostr_setup_profile.py \
            "$NSEC" \
            "✌(◕‿-)✌ $title" "$G1PUBNOSTR" \
            "$description - $city" \
            "$myIPFS/$zavatar" \
            "$myIPFS/ipfs/QmX1TWhFZwVFBSPthw1Q3gW5rQc1Gc4qrSbKj4q1tXPicT/P2Pmesh.jpg" \
            "" "$myIPFS${NOSTRNS}/${PLAYER}/APP/uDRIVE" "" "" "" "" \
            "wss://relay.copylaradio.com" "$myRELAY" \
            --ipfs_gw "$myIPFS" \
            --zencard "$ZENCARDG1" \
            --ipns_vault "${NOSTRNS}" \
            > ~/.zen/game/nostr/${PLAYER}/nostr_setup_profile

        ## DOES COMMAND SUCCEED ?
        [[ ! $? -eq 0 ]] \
            && rm ~/.zen/game/nostr/${PLAYER}/nostr_setup_profile 2>/dev/null

    else
        # echo "## MULTIPASS nostr PROFILE EXISTING"
        #~ cat ~/.zen/game/nostr/${PLAYER}/nostr_setup_profile
        HEX=$(cat ~/.zen/game/nostr/${PLAYER}/HEX)
        ########################################################################
        ## Create ZENCARD ONLY FOR UPlanet Zen #################################################
        if [[ "$UPLANETG1PUB" != "AwdjhpJNqzQgmSrvpUk5Fd2GxBZMJVQkBQmXn4JQLr6z" ]]; then
            ## CREATE UPlanet AstroID + ZenCard using EMAIL and GPS ##
            if [[ ! -d ~/.zen/game/players/${PLAYER} ]]; then
                echo "## UPlanet ZEN : Zen Card creation "
                source ~/.zen/game/nostr/${PLAYER}/GPS
                PPASS=$(${MY_PATH}/../tools/diceware.sh $(( $(${MY_PATH}/../tools/getcoins_from_gratitude_box.sh) + 2 )) | xargs)
                NPASS=$(${MY_PATH}/../tools/diceware.sh $(( $(${MY_PATH}/../tools/getcoins_from_gratitude_box.sh) + 2 )) | xargs)

                ## GET LANG FROM NOSTR CARD
                LANG=$(cat ${HOME}/.zen/game/nostr/${PLAYER}/LANG 2>/dev/null)
                source ${HOME}/.zen/game/nostr/${PLAYER}/.secret.nostr 2>/dev/null
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
                echo "MULTIPASS & ZenCard existing : ~/.zen/game/players/${PLAYER}"
                ${MY_PATH}/../tools/search_for_this_email_in_players.sh ${PLAYER} | tail -n 1

            fi
        ############## UPLANET ORIGIN #############################################
        else
            $(${MY_PATH}/../tools/search_for_this_email_in_nostr.sh ${PLAYER} | tail -n 1)
            echo "$source ORIGIN ($LAT $LON) : $HEX = $EMAIL"

        fi
    fi

    ########################################################################################
    # Use the generic primal wallet control function
    echo "Checking MULTIPASS wallet for $PLAYER: $G1PUBNOSTR"
    # Get DISCO from MULTIPASS to create dunikey if needed
    if [[ ! -s ~/.zen/game/nostr/${PLAYER}/.secret.dunikey ]]; then
        DISCO=$(cat ~/.zen/game/nostr/${PLAYER}/.secret.disco)
        IFS='=&' read -r s salt p pepper <<< "$DISCO"
        # Create secret.dunikey from DISCO
        if [[ -n $salt && -n $pepper ]]; then
            ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/nostr/${PLAYER}/.secret.dunikey "${salt}" "${pepper}"
        fi
    fi
    echo "## CONTROL TRANSACTIONS PRIMAL CONFORMITY..."
    # Call the generic primal wallet control function (using UPLANETNAME_G1 as unique primal source)
    if [[ ${UPLANETNAME} != "EnfinLibre" ]]; then
        echo "CONTROL UPLANET ZEN - NOSTR Card primal control"
        ${MY_PATH}/../tools/primal_wallet_control.sh \
            "${HOME}/.zen/game/nostr/${PLAYER}/.secret.dunikey" \
            "${G1PUBNOSTR}" \
            "${UPLANETNAME_G1}" \
            "${PLAYER}"
    else
        echo "UPlanet ORIGIN - No Control -"
    fi

    ## ADD AMIS of AMIS -- friends of registered MULTIPASS can use our nostr relay
    fof_list=($($MY_PATH/../tools/nostr_get_N1.sh $HEX 2>/dev/null))
    if [[ ${#fof_list[@]} -gt 0 ]]; then
        echo "Adding ${#fof_list[@]} friends hex into amisOfAmis.txt"
        # Use sort -u to remove duplicates before appending
        printf "%s\n" "${fof_list[@]}" | sort -u >> "${HOME}/.zen/strfry/amisOfAmis.txt"
    fi

    refreshtime="$(cat ~/.zen/game/nostr/${PLAYER}/.todate) $(cat ~/.zen/game/nostr/${PLAYER}/.refresh_time)"
    echo "\m/_(>_<)_\m/  ----- last refresh $refreshtime ----- \m/_(>_<)_\m/"

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

        ## Keeping .secret.ipns (quicker ipfs processing)
        if [[ ! -s ~/.zen/game/nostr/${PLAYER}/.secret.ipns ]]; then
            ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/game/nostr/${PLAYER}/.secret.ipns "${salt}" "${pepper}"
            ipfs key rm "${G1PUBNOSTR}:NOSTR" > /dev/null 2>&1
            NOSTRNS=$(ipfs key import "${G1PUBNOSTR}:NOSTR" -f pem-pkcs8-cleartext ~/.zen/game/nostr/${PLAYER}/.secret.ipns)
            chmod 600 ~/.zen/game/nostr/${PLAYER}/.secret.ipns
        fi

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
    stop=$(date +%s)
    player_duration=$((stop - start))
    log "DEBUG" "MULTIPASS refresh DONE for ${PLAYER} in ${player_duration}s"
    log_metric "PLAYER_PROCESSING_TIME" "$player_duration" "${PLAYER}"

done

end=`date +%s`
dur=`expr $end - $gstart`
hours=$((dur / 3600)); minutes=$(( (dur % 3600) / 60 )); seconds=$((dur % 60))

# Log comprehensive summary
log "INFO" "============================================ NOSTR REFRESH SUMMARY"
log "INFO" "📊 Players: ${#NOSTR[@]} total | $DAILY_UPDATES daily | $FILE_UPDATES files | $SKIPPED_PLAYERS skipped"
log "INFO" "💰 Payments: $PAYMENTS_PROCESSED processed | $PAYMENTS_FAILED failed | $PAYMENTS_ALREADY_DONE already done"
log "INFO" "⏱️  Duration: ${hours}h ${minutes}m ${seconds}s"
log "INFO" "============================================ NOSTR.refresh DONE."

# Log global metrics for monitoring
log_metric "TOTAL_PLAYERS" "${#NOSTR[@]}"
log_metric "DAILY_UPDATES" "$DAILY_UPDATES"
log_metric "FILE_UPDATES" "$FILE_UPDATES"
log_metric "SKIPPED_PLAYERS" "$SKIPPED_PLAYERS"
log_metric "PAYMENTS_PROCESSED" "$PAYMENTS_PROCESSED"
log_metric "PAYMENTS_FAILED" "$PAYMENTS_FAILED"
log_metric "EXECUTION_TIME_SECONDS" "$dur"
rm -Rf ~/.zen/tmp/${MOATS}
rm -f "$LOCKFILE"

exit 0
