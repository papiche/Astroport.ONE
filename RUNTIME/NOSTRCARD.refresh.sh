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
LOGFILE="$HOME/.zen/tmp/MULTIPASS.refresh.log"
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
    FRIENDS_SUMMARIES_PUBLISHED=0
    DAILY_SUMMARIES=0
    WEEKLY_SUMMARIES=0
    MONTHLY_SUMMARIES=0
    YEARLY_SUMMARIES=0
    USOCIETY_N2_EXPANSIONS=0
    YOUTUBE_SYNC_USERS=0

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
    log "INFO" ">>>>>>>>>>>>>>>>>>============================================ Processing MULTIPASS : $PLAYER "
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

    log "INFO" "${G1PUBNOSTR} AMOUNT (${COINS} G1) = ${ZEN} ZEN"
    log_metric "WALLET_BALANCE" "${COINS}" "${PLAYER}"

    # Check for balance threshold notifications
    if [[ $(echo "$COINS > 0" | bc -l) -eq 1 ]]; then
        # Check if this is a new high balance (first time above 10 G1)
        if [[ $(echo "$ZEN >= 100" | bc -l) -eq 1 && ! -s ~/.zen/game/nostr/${PLAYER}/.balance_10_notified ]]; then
            balance_celebration="<html><head><meta charset='UTF-8'>
<style>
    body { font-family: 'Courier New', monospace; }
    .celebration { color: #ff6f00; font-weight: bold; }
    .details { background-color: #fff3e0; padding: 15px; margin: 10px 0; border-left: 4px solid #ff6f00; }
    .amount { font-size: 1.5em; color: #e65100; }
</style></head><body>
<h2 class='celebration'>🎉 Félicitations ! Seuil de $ZEN ẐEN Atteint</h2>
<div class='details'>
<p><strong>Joueur:</strong> ${PLAYER}</p>
<p><strong>Date:</strong> $TODATE</p>
</div>
<p>Excellent travail ! Votre MULTIPASS a atteint un solde significatif. Cela signifie que votre contenu génère de la valeur !</p>
<p><strong>🚀 Prochaines étapes :</strong></p>
<ul>
<li>Continuez à créer du contenu de qualité</li>
<li>Demandez à vos amis de créer leur MULTIPASS</li>
<li>Devenez sociétaire (50€/an) pour des services illimités</li>
</ul>
<p><strong>💡 Rappel :</strong> Chaque like = 1 ẐEN automatique. Plus votre réseau grandit, plus vous gagnez !</p>
</body></html>"

            # Create temporary file for email content
            local temp_email_file=$(mktemp)
            echo "$balance_celebration" > "$temp_email_file"
            ${MY_PATH}/../tools/mailjet.sh --expire 72h "${PLAYER}" "$temp_email_file" "Seuil de 100 Ẑen Atteint - $TODATE"
            rm -f "$temp_email_file"
            echo "$TODATE" > ~/.zen/game/nostr/${PLAYER}/.balance_10_notified
            log "INFO" "Balance celebration email sent to ${PLAYER} for reaching 10 G1"
        fi
        
        # Check for low balance warning (below 2 G1)
        if [[ $(echo "$COINS < 2" | bc -l) -eq 1 && ! -s ~/.zen/game/nostr/${PLAYER}/.balance_low_warned ]]; then
            low_balance_warning="<html><head><meta charset='UTF-8'>
<style>
    body { font-family: 'Courier New', monospace; }
    .warning { color: #d32f2f; font-weight: bold; }
    .details { background-color: #ffebee; padding: 15px; margin: 10px 0; border-left: 4px solid #d32f2f; }
    .amount { font-size: 1.2em; color: #c62828; }
    .recharge { background-color: #e8f5e8; padding: 15px; margin: 10px 0; border-left: 4px solid #4caf50; }
</style></head><body>
<h2 class='warning'>⚠️ Solde Faible - Action Recommandée</h2>
<div class='details'>
<p><strong>Joueur:</strong> ${PLAYER}</p>
<p><strong>Solde actuel:</strong> <span class='amount'>$ZEN ẐEN</span></p>
<p><strong>Date:</strong> $TODATE</p>
<p><strong>Prochain paiement:</strong> $NEXT_PAYMENT_DATE</p>
</div>
<p>Votre solde est faible. Pour éviter l'interruption de service, voici quelques solutions :</p>
<p><strong>💡 Solutions :</strong></p>
<ul>
<li><strong>Créez plus de contenu</strong> - Chaque like = 1 ẐEN</li>
<li><strong>Invitez vos amis</strong> - Plus de réseau = plus de likes</li>
<li><strong>Rechargez votre MULTIPASS</strong> - Recharge ponctuelle ou automatique</li>
</ul>
<div class='recharge'>
<h3>🔄 Rechargez Maintenant</h3>
<p><strong>Options de recharge disponibles :</strong></p>
<ul>
<li>💰 <strong>Recharge ponctuelle :</strong> À partir de 5€</li>
<li>🔄 <strong>Recharge automatique :</strong> À partir de 20€/mois</li>
<li>🏛️ <strong>Devenez Sociétaire :</strong> 50€/an (plus de paiements hebdomadaires)</li>
</ul>
<p><strong>👉 Rechargez sur :</strong> <a href='https://opencollective.com/uplanet-zero/contribute/' target='_blank'>https://opencollective.com/uplanet-zero/contribute/</a></p>
</div>
<p><strong>🚨 Important :</strong> Si votre solde tombe à 0, votre MULTIPASS sera suspendu.</p>
</body></html>"

            # Create temporary file for email content
            local temp_email_file=$(mktemp)
            echo "$low_balance_warning" > "$temp_email_file"
            ${MY_PATH}/../tools/mailjet.sh --expire 72h "${PLAYER}" "$temp_email_file" "Solde Faible - $TODATE"
            rm -f "$temp_email_file"
            echo "$TODATE" > ~/.zen/game/nostr/${PLAYER}/.balance_low_warned
            log "INFO" "Low balance warning email sent to ${PLAYER}"
        fi
    fi

    BIRTHDATE=$(cat ~/.zen/game/nostr/${PLAYER}/TODATE 2>/dev/null)
    [[ ! -s ~/.zen/game/nostr/${PLAYER}/.birthdate ]] \
        && echo $BIRTHDATE > ~/.zen/game/nostr/${PLAYER}/.birthdate

    # Check for MULTIPASS anniversaries
    if [[ -n "$BIRTHDATE" ]]; then
        BIRTHDATE_SECONDS=$(date -d "$BIRTHDATE" +%s)
        TODATE_SECONDS=$(date -d "$TODATE" +%s)
        DAYS_OLD=$(( (TODATE_SECONDS - BIRTHDATE_SECONDS) / 86400 ))
        
        # 1 year anniversary
        if [[ $DAYS_OLD -eq 365 && ! -s ~/.zen/game/nostr/${PLAYER}/.anniversary_1year_notified ]]; then
            anniversary_1year="<html><head><meta charset='UTF-8'>
<style>
    body { font-family: 'Courier New', monospace; }
    .celebration { color: #4caf50; font-weight: bold; }
    .details { background-color: #e8f5e8; padding: 15px; margin: 10px 0; border-left: 4px solid #4caf50; }
    .milestone { background-color: #fff3e0; padding: 15px; margin: 10px 0; border-left: 4px solid #ff9800; }
</style></head><body>
<h2 class='celebration'>🎉 Félicitations ! 1 An avec UPlanet</h2>
<div class='details'>
<p><strong>MULTIPASS:</strong> ${PLAYER}</p>
<p><strong>Date de création:</strong> $BIRTHDATE</p>
<p><strong>Anniversaire:</strong> $TODATE</p>
<p><strong>Solde actuel:</strong> $ZEN ẐEN </p>
</div>
<div class='milestone'>
<h3>🏆 Votre Parcours UPlanet</h3>
<p>Depuis 1 an, vous faites partie de l'Internet de confiance !</p>
<ul>
<li>✅ Identité numérique décentralisée</li>
<li>✅ uDRIVE personnel</li>
<li>✅ IA personnelle</li>
<li>✅ Réseau social N²</li>
<li>✅ Économie transparente</li>
</ul>
</div>
<p><strong>🚀 Prochaines étapes :</strong></p>
<ul>
<li>Partagez votre expérience avec vos amis</li>
<li>Devenez Co-Bâtisseur (50€/an)</li>
<li>Participez à la gouvernance de la coopérative</li>
</ul>
<p><strong>💡 Merci</strong> de faire partie de cette révolution numérique !</p>
</body></html>"

            # Create temporary file for email content
            local temp_email_file=$(mktemp)
            echo "$anniversary_1year" > "$temp_email_file"
            ${MY_PATH}/../tools/mailjet.sh --expire 72h "${PLAYER}" "$temp_email_file" "🎉 1 An avec UPlanet - $TODATE"
            rm -f "$temp_email_file"
            echo "$TODATE" > ~/.zen/game/nostr/${PLAYER}/.anniversary_1year_notified
            log "INFO" "1-year anniversary email sent to ${PLAYER}"
        fi
        
        # 6 months milestone
        if [[ $DAYS_OLD -eq 182 && ! -s ~/.zen/game/nostr/${PLAYER}/.milestone_6months_notified ]]; then
            milestone_6months="<html><head><meta charset='UTF-8'>
<style>
    body { font-family: 'Courier New', monospace; }
    .milestone { color: #ff9800; font-weight: bold; }
    .details { background-color: #fff3e0; padding: 15px; margin: 10px 0; border-left: 4px solid #ff9800; }
</style></head><body>
<h2 class='milestone'>🎯 6 Mois avec UPlanet - Excellent Progrès !</h2>
<div class='details'>
<p><strong>MULTIPASS:</strong> ${PLAYER}</p>
<p><strong>Date de création:</strong> $BIRTHDATE</p>
<p><strong>Milestone:</strong> $TODATE</p>
<p><strong>Solde actuel:</strong> $ZEN ẐEN</p>
</div>
<p>Félicitations ! Vous utilisez UPlanet depuis 6 mois. Votre engagement dans l'Internet de confiance est remarquable !</p>
<p><strong>💡 Astuce :</strong> Plus vous partagez le MULTIPASS, plus votre réseau grandit et plus vous gagnez de ẐEN.</p>
<p><strong>🚀 Considérez :</strong> Devenir Co-Bâtisseur pour accéder aux services illimités et participer à la gouvernance.</p>
</body></html>"

            # Create temporary file for email content
            local temp_email_file=$(mktemp)
            echo "$milestone_6months" > "$temp_email_file"
            ${MY_PATH}/../tools/mailjet.sh --expire 72h "${PLAYER}" "$temp_email_file" "🎯 6 Mois avec UPlanet - $TODATE"
            rm -f "$temp_email_file"
            echo "$TODATE" > ~/.zen/game/nostr/${PLAYER}/.milestone_6months_notified
            log "INFO" "6-month milestone email sent to ${PLAYER}"
        fi
    fi

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
    # Send welcome message on 1st day (regardless of COINS amount)
    if [[ ${TODATE} == ${BIRTHDATE} ]]; then
        ## 1st Day send welcome EMAIL...
        if [[ ! -s ~/.zen/game/nostr/${PLAYER}/.welcome.html ]]; then
            cp ${MY_PATH}/../templates/NOSTR/welcome.html ~/.zen/game/nostr/${PLAYER}/.welcome.html \
            && sed -i "s/http:\/\/127.0.0.1:8080/${myIPFS}/g" ~/.zen/game/nostr/${PLAYER}/.welcome.html \
            && sed -i "s/_USPOT_/${uSPOT}/g" ~/.zen/game/nostr/${PLAYER}/.welcome.html \
            && ${MY_PATH}/../tools/mailjet.sh "${PLAYER}" "${HOME}/.zen/game/nostr/${PLAYER}/.welcome.html" "WELCOME $YOUSER"
            log "INFO" "Welcome email sent to new MULTIPASS: ${PLAYER}"
            log_metric "WELCOME_EMAIL_SENT" "1" "${PLAYER}"
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
                                
                                # Send success email notification
                                success_message="<html><head><meta charset='UTF-8'>
<style>
    body { font-family: 'Courier New', monospace; }
    .success { color: green; font-weight: bold; }
    .details { background-color: #f0f8f0; padding: 10px; margin: 10px 0; }
    .amount { font-size: 1.2em; color: #2e7d32; }
</style></head><body>
<h2 class='success'>✅ Paiement Hebdomadaire Réussi</h2>
<div class='details'>
<p><strong>Joueur:</strong> ${PLAYER}</p>
<p><strong>Date:</strong> $TODATE</p>
<p><strong>Montant HT:</strong> <span class='amount'>$Npaf ẐEN</span></p>
<p><strong>Montant TVA:</strong> <span class='amount'>$TVA_AMOUNT ẐEN</span></p>
<p><strong>Total payé:</strong> <span class='amount'>$TOTAL_PAYMENT ẐEN</span></p>
<p><strong>Solde restant:</strong> $ZEN ẐEN</p>
<p><strong>Prochain paiement:</strong> $NEXT_PAYMENT_DATE</p>
</div>
<p>Votre MULTIPASS est à jour ! Continuez à créer du contenu de qualité pour gagner plus de ẐEN.</p>
<p><strong>💡 Astuce:</strong> Chaque like sur vos posts = 1 ẐEN automatique dans votre portefeuille.</p>
</body></html>"

                                # Create temporary file for email content
                                local temp_email_file=$(mktemp)
                                echo "$success_message" > "$temp_email_file"
                                ${MY_PATH}/../tools/mailjet.sh --expire 72h "${PLAYER}" "$temp_email_file" "Paiement Réussi - $TODATE"
                                rm -f "$temp_email_file"
                                log "INFO" "Success email sent to ${PLAYER} for payment success"
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

                                # Create temporary file for email content
                                local temp_email_file=$(mktemp)
                                echo "$error_message" > "$temp_email_file"
                                ${MY_PATH}/../tools/mailjet.sh --expire 72h "${CAPTAINEMAIL}" "$temp_email_file" "MULTIPASS Payment Error - $TODATE"
                                rm -f "$temp_email_file"
                                log "INFO" "Error email sent to ${CAPTAINEMAIL} for payment failure of ${PLAYER}"
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
        UDATE=$(cat ~/.zen/game/players/${PLAYER}/U.SOCIETY 2>/dev/null)
        UENDDATE=$(cat ~/.zen/game/players/${PLAYER}/U.SOCIETY.end 2>/dev/null)
        
        if [[ -z "$UDATE" ]]; then
            echo "### U SOCIETY FILE MISSING"
            echo "### REMOVING U SOCIETY STATUS"
            rm -f ~/.zen/game/players/${PLAYER}/U.SOCIETY
            rm -f ~/.zen/game/nostr/${PLAYER}/U.SOCIETY
            rm -f ~/.zen/game/players/${PLAYER}/U.SOCIETY.end
            rm -f ~/.zen/game/nostr/${PLAYER}/U.SOCIETY.end
        else
            echo "U SOCIETY REGISTRATION : $UDATE"
            
            if [[ -n "$UENDDATE" ]]; then
                echo "U SOCIETY EXPIRATION : $UENDDATE"
                
                # Vérifier si l'abonnement a expiré
                TODATE_SECONDS=$(date --date="$TODATE" +%s)
                UENDDATE_SECONDS=$(date --date="$UENDDATE" +%s)
                
                if [[ $TODATE_SECONDS -gt $UENDDATE_SECONDS ]]; then
                    echo "### U SOCIETY SUBSCRIPTION EXPIRED"
                    echo "### ENDING U SOCIETY FREE MODE"
                    rm ~/.zen/game/players/${PLAYER}/U.SOCIETY
                    rm ~/.zen/game/nostr/${PLAYER}/U.SOCIETY
                    rm ~/.zen/game/players/${PLAYER}/U.SOCIETY.end
                    rm ~/.zen/game/nostr/${PLAYER}/U.SOCIETY.end
                    
                    # Send U.SOCIETY expiration email
                    usociety_expired="<html><head><meta charset='UTF-8'>
<style>
    body { font-family: 'Courier New', monospace; }
    .expired { color: #d32f2f; font-weight: bold; }
    .details { background-color: #ffebee; padding: 15px; margin: 10px 0; border-left: 4px solid #d32f2f; }
    .offer { background-color: #e8f5e8; padding: 15px; margin: 10px 0; border-left: 4px solid #4caf50; }
</style></head><body>
<h2 class='expired'>🏛️ Abonnement U.SOCIETY Expiré</h2>
<div class='details'>
<p><strong>Membre:</strong> ${PLAYER}</p>
<p><strong>Date d'expiration:</strong> $UENDDATE</p>
<p><strong>Date actuelle:</strong> $TODATE</p>
</div>
<p>Votre abonnement U.SOCIETY a expiré. Vous perdez l'accès aux services premium :</p>
<ul>
<li>❌ NextCloud (stockage privé)</li>
<li>❌ PeerTube (vidéos privées)</li>
<li>❌ Accès SSH aux relais</li>
<li>❌ Droit de vote sur les décisions</li>
</ul>
<div class='offer'>
<h3>🔄 Renouvelez Maintenant</h3>
<p><strong>Avantages du renouvellement :</strong></p>
<ul>
<li>✅ Tous les services premium restaurés</li>
<li>✅ Droit de vote maintenu</li>
<li>✅ Part de propriété des biens réels</li>
<li>✅ Plus de paiements hebdomadaires</li>
</ul>
<p><strong>Prix :</strong> 50€/an (Welcome Offer)</p>
</div>
<p><strong>💡 Note :</strong> Votre MULTIPASS de base reste actif.</p>
</body></html>"

                    # Create temporary file for email content
                    local temp_email_file=$(mktemp)
                    echo "$usociety_expired" > "$temp_email_file"
                    ${MY_PATH}/../tools/mailjet.sh --expire 72h "${CAPTAINEMAIL}" "$temp_email_file" "U.SOCIETY Expiré - Renouvellement Requis"
                    rm -f "$temp_email_file"
                    log "INFO" "U.SOCIETY expiration email sent to ${CAPTAINEMAIL} for ${PLAYER}"
                else
                    # Calculer les jours restants
                    DIFF_DAYS=$(( (UENDDATE_SECONDS - TODATE_SECONDS) / 86400 ))
                    echo "DAYS UNTIL EXPIRATION : $DIFF_DAYS"
                    
                    if [[ $DIFF_DAYS -gt 0 ]]; then
                        echo "OK VALID $DIFF_DAYS days left..."
                        
                        
                    # Alerte si expiration dans moins de 30 jours
                    if [[ $DIFF_DAYS -lt 30 ]]; then
                        echo "### U SOCIETY EXPIRATION WARNING: $DIFF_DAYS days remaining"
                        
                        # Send expiration warning email (only once per warning period)
                        if [[ $DIFF_DAYS -lt 30 && $DIFF_DAYS -gt 20 && ! -s ~/.zen/game/nostr/${PLAYER}/.usociety_30day_warned ]]; then
                            usociety_warning_30="<html><head><meta charset='UTF-8'>
<style>
    body { font-family: 'Courier New', monospace; }
    .warning { color: #ff9800; font-weight: bold; }
    .details { background-color: #fff3e0; padding: 15px; margin: 10px 0; border-left: 4px solid #ff9800; }
    .offer { background-color: #e8f5e8; padding: 15px; margin: 10px 0; border-left: 4px solid #4caf50; }
</style></head><body>
<h2 class='warning'>⚠️ U.SOCIETY Expire dans $DIFF_DAYS jours</h2>
<div class='details'>
<p><strong>Membre:</strong> ${PLAYER}</p>
<p><strong>Date d'expiration:</strong> $UENDDATE</p>
<p><strong>Jours restants:</strong> $DIFF_DAYS</p>
</div>
<p>Votre ZEN Card U.SOCIETY expire bientôt. Renouvelez maintenant pour éviter l'interruption des services premium.</p>
<div class='offer'>
<h3>🔄 Renouvellement Recommandé</h3>
<p><strong>Services qui expireront :</strong></p>
<ul>
<li>❌ NextCloud (stockage privé)</li>
<li>❌ PeerTube (vidéos privées)</li>
<li>❌ Accès SSH aux relais</li>
<li>❌ Droit de vote sur les décisions</li>
</ul>
<p><strong>Prix :</strong> 50€/an (Welcome Offer)</p>
</div>
<p><strong>💡 Note :</strong> Votre MULTIPASS de base restera actif même après expiration.</p>
</body></html>"

                            # Create temporary file for email content
                            local temp_email_file=$(mktemp)
                            echo "$usociety_warning_30" > "$temp_email_file"
                            ${MY_PATH}/../tools/mailjet.sh --expire 72h "${PLAYER}" "$temp_email_file" "U.SOCIETY Expire dans $DIFF_DAYS jours"
                            rm -f "$temp_email_file"
                            echo "$TODATE" > ~/.zen/game/nostr/${PLAYER}/.usociety_30day_warned
                            log "INFO" "U.SOCIETY 30-day warning email sent to ${PLAYER}"
                        fi
                        
                        # Send final warning if less than 7 days
                        if [[ $DIFF_DAYS -lt 7 && ! -s ~/.zen/game/nostr/${PLAYER}/.usociety_7day_warned ]]; then
                            usociety_warning_7="<html><head><meta charset='UTF-8'>
<style>
    body { font-family: 'Courier New', monospace; }
    .urgent { color: #d32f2f; font-weight: bold; }
    .details { background-color: #ffebee; padding: 15px; margin: 10px 0; border-left: 4px solid #d32f2f; }
    .offer { background-color: #e8f5e8; padding: 15px; margin: 10px 0; border-left: 4px solid #4caf50; }
</style></head><body>
<h2 class='urgent'>🚨 U.SOCIETY Expire dans $DIFF_DAYS jours - DERNIÈRE CHANCE</h2>
<div class='details'>
<p><strong>Membre:</strong> ${PLAYER}</p>
<p><strong>Date d'expiration:</strong> $UENDDATE</p>
<p><strong>Jours restants:</strong> $DIFF_DAYS</p>
</div>
<p><strong>URGENT :</strong> Votre abonnement U.SOCIETY expire dans $DIFF_DAYS jours !</p>
<div class='offer'>
<h3>🔄 Renouvelez IMMÉDIATEMENT</h3>
<p><strong>Prix :</strong> 50€/an (Welcome Offer)</p>
<p><strong>Avantages :</strong></p>
<ul>
<li>✅ NextCloud (stockage privé)</li>
<li>✅ PeerTube (vidéos privées)</li>
<li>✅ Accès SSH aux relais</li>
<li>✅ Droit de vote sur les décisions</li>
<li>✅ Plus de paiements hebdomadaires</li>
</ul>
</div>
<p><strong>⚠️ Après expiration :</strong> Vous perdrez l'accès aux services premium mais garderez votre MULTIPASS de base.</p>
</body></html>"

                            # Create temporary file for email content
                            local temp_email_file=$(mktemp)
                            echo "$usociety_warning_7" > "$temp_email_file"
                            ${MY_PATH}/../tools/mailjet.sh --expire 72h "${PLAYER}" "$temp_email_file" "URGENT: U.SOCIETY Expire dans $DIFF_DAYS jours"
                            rm -f "$temp_email_file"
                            echo "$TODATE" > ~/.zen/game/nostr/${PLAYER}/.usociety_7day_warned
                            log "INFO" "U.SOCIETY 7-day urgent warning email sent to ${PLAYER}"
                        fi
                    fi
                    fi
                fi
            else
                # Fallback: calculer la date d'expiration (1 an par défaut)
                echo "### U SOCIETY.end FILE MISSING - USING FALLBACK CALCULATION"
                TODATE_SECONDS=$(date --date="$TODATE" +%s)
                UDATE_SECONDS=$(date --date="$UDATE" +%s)
                DIFF_SECONDS=$((TODATE_SECONDS - UDATE_SECONDS))
                DIFF_DAYS=$((DIFF_SECONDS / 86400))
                
                if [[ $DIFF_DAYS == 365 ]]; then
                    echo "### ENDING U SOCIETY FREE MODE (FALLBACK)"
                    rm ~/.zen/game/players/${PLAYER}/U.SOCIETY
                    rm ~/.zen/game/nostr/${PLAYER}/U.SOCIETY
                    ${HOME}/.zen/Astroport.ONE/tools/mailjet.sh --expire 72h "${CAPTAINEMAIL}" "$HOME/.zen/game/passport/${PUBKEY}/.passport.html" "U.SOCIETY Fallback Expiration - ${PLAYER}"
                fi
            fi
        fi
    fi

  ########################################################################

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
        description="💬 + ❤️ => Ẑen : ${uSPOT}/check_balance?g1pub=${PLAYER}"
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
            --email "$PLAYER" \
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
    ## FRIENDS SUMMARY - Publish friends activity summary to MULTIPASS wall
    ## Daily (24h), Weekly (7 days), Monthly (28 days)
    ########################################################################################
    if [[ "$REFRESH_REASON" == "daily_update" ]]; then
        # Determine summary type based on days since birthdate
        local summary_type=""
        local summary_period=""
        local summary_title=""
        local summary_days=0
        
        # Calculate days since birthdate
        local birthdate_seconds=$(date -d "$BIRTHDATE" +%s)
        local today_seconds=$(date -d "$TODATE" +%s)
        local days_since_birth=$(( (today_seconds - birthdate_seconds) / 86400 ))
        
        # Determine summary type
        if [[ $((days_since_birth % 365)) -eq 0 && $days_since_birth -ge 365 ]]; then
            summary_type="Yearly"
            summary_period="365 days"
            summary_days=365
            summary_title="🗓️ Yearly Friends Activity Summary - $TODATE"
        elif [[ $((days_since_birth % 28)) -eq 0 && $days_since_birth -ge 28 ]]; then
            summary_type="Monthly"
            summary_period="28 days"
            summary_days=28
            summary_title="📅 Monthly Friends Activity Summary - $TODATE"
        elif [[ $((days_since_birth % 7)) -eq 0 && $days_since_birth -ge 7 ]]; then
            summary_type="Weekly"
            summary_period="7 days"
            summary_days=7
            summary_title="📊 Weekly Friends Activity Summary - $TODATE"
        else
            summary_type="Daily"
            summary_period="24 hours"
            summary_days=1
            summary_title="📝 Daily Friends Activity Summary - $TODATE"
        fi
        
        log "INFO" "📝 Generating $summary_type friends summary for ${PLAYER} (${summary_period})"
        
        # Get friends list for this MULTIPASS
        local friends_list=($(${MY_PATH}/../tools/nostr_get_N1.sh "$HEX" 2>/dev/null))
        
        # Personal N² journal for ALL MULTIPASS accounts (individual and personalized)
        log "INFO" "Creating personal N² journal for ${PLAYER} - individual and tailored to their network"
        
        # Get friends of friends (N²) for personalized journal
        local n2_friends=()
        for friend_hex in "${friends_list[@]}"; do
            local friend_friends=($(${MY_PATH}/../tools/nostr_get_N1.sh "$friend_hex" 2>/dev/null))
            n2_friends+=("${friend_friends[@]}")
        done
        
        # Remove duplicates and add to friends list
        local all_friends=("${friends_list[@]}" "${n2_friends[@]}")
        local unique_friends=($(printf '%s\n' "${all_friends[@]}" | sort -u))
        friends_list=("${unique_friends[@]}")
        
        log "INFO" "Personal N² journal: ${#friends_list[@]} total friends (N1 + N²) for ${PLAYER}'s individual network"
        USOCIETY_N2_EXPANSIONS=$((USOCIETY_N2_EXPANSIONS + 1))
        
        if [[ ${#friends_list[@]} -gt 0 ]]; then
            log "INFO" "Found ${#friends_list[@]} friends for ${PLAYER} - generating summary"
            
            # Create temporary directory for summary processing
            local summary_dir="${HOME}/.zen/tmp/${MOATS}/friends_summary_${PLAYER}"
            mkdir -p "$summary_dir"
            
            # Generate personal N² journal for this specific MULTIPASS
            local summary_file="${summary_dir}/personal_n2_journal_${PLAYER}.md"
            
            # Get nprofile for the MULTIPASS owner
            local player_nprofile=$(${MY_PATH}/../tools/nostr_hex2nprofile.sh "$HEX" 2>/dev/null)
            [[ -z "$player_nprofile" ]] && player_nprofile="$HEX"
            
            echo "# $summary_title" > "$summary_file"
            echo "**Date**: $TODATE" >> "$summary_file"
            echo "**MULTIPASS**: $PLAYER" >> "$summary_file"
            echo "**NProfile**: nostr:$player_nprofile" >> "$summary_file"
            echo "**Period**: $summary_period" >> "$summary_file"
            echo "**Type**: Personal N² Journal ($summary_type)" >> "$summary_file"
            echo "**Network**: ${#friends_list[@]} friends (N1 + N²)" >> "$summary_file"
            
            # Add GPS coordinates if available
            local player_gps_file="${HOME}/.zen/game/nostr/${PLAYER}/GPS"
            if [[ -f "$player_gps_file" ]]; then
                local player_lat=$(grep "^LAT=" "$player_gps_file" | tail -1 | cut -d'=' -f2 | tr -d ';' | xargs)
                local player_lon=$(grep "^LON=" "$player_gps_file" | tail -1 | cut -d'=' -f2 | tr -d ';' | xargs)
                if [[ -n "$player_lat" && -n "$player_lon" && "$player_lat" != "" && "$player_lon" != "" ]]; then
                    echo "**Location**: $player_lat, $player_lon" >> "$summary_file"
                    echo "**UMAP Zone**: ${player_lat}_${player_lon}" >> "$summary_file"
                fi
            fi
            
            echo "" >> "$summary_file"
            
            # For Weekly/Monthly/Yearly summaries, use published summaries instead of raw messages
            if [[ "$summary_type" == "Weekly" ]]; then
                log "INFO" "Using published daily summaries for $summary_type summary (more efficient)"

                # Get published daily summaries from this MULTIPASS wall
                local since_timestamp=$(date -d "${summary_days} days ago" +%s)

                cd ~/.zen/strfry
                local daily_summaries=$(./strfry scan "{
                    \"kinds\": [30023],
                    \"authors\": [\"$HEX\"],
                    \"since\": ${since_timestamp},
                    \"limit\": 100
                }" 2>/dev/null | jq -c 'select(.kind == 30023 and (.tags[] | select(.[0] == "t" and .[1] == "SummaryType:Daily"))) | {id: .id, content: .content, created_at: .created_at, tags: .tags}')
                cd - >/dev/null

                # Process daily summaries instead of raw messages
                local friends_messages="$daily_summaries"
            elif [[ "$summary_type" == "Monthly" ]]; then
                log "INFO" "Using published weekly summaries for $summary_type summary (most efficient)"

                # Get published weekly summaries from this MULTIPASS wall
                local since_timestamp=$(date -d "${summary_days} days ago" +%s)

                cd ~/.zen/strfry
                local weekly_summaries=$(./strfry scan "{
                    \"kinds\": [30023],
                    \"authors\": [\"$HEX\"],
                    \"since\": ${since_timestamp},
                    \"limit\": 100
                }" 2>/dev/null | jq -c 'select(.kind == 30023 and (.tags[] | select(.[0] == "t" and .[1] == "SummaryType:Weekly"))) | {id: .id, content: .content, created_at: .created_at, tags: .tags}')
                cd - >/dev/null

                # Process weekly summaries instead of raw messages
                local friends_messages="$weekly_summaries"
            elif [[ "$summary_type" == "Yearly" ]]; then
                log "INFO" "Using published monthly summaries for $summary_type summary (most efficient)"

                # Get published monthly summaries from this MULTIPASS wall
                local since_timestamp=$(date -d "${summary_days} days ago" +%s)

                cd ~/.zen/strfry
                local monthly_summaries=$(./strfry scan "{
                    \"kinds\": [30023],
                    \"authors\": [\"$HEX\"],
                    \"since\": ${since_timestamp},
                    \"limit\": 100
                }" 2>/dev/null | jq -c 'select(.kind == 30023 and (.tags[] | select(.[0] == "t" and .[1] == "SummaryType:Monthly"))) | {id: .id, content: .content, created_at: .created_at, tags: .tags}')
                cd - >/dev/null

                # Process monthly summaries instead of raw messages
                local friends_messages="$monthly_summaries"
            else
                # For Daily summaries, get raw messages from friends
                local since_timestamp=$(date -d "${summary_days} days ago" +%s)
                local friends_json=$(printf '"%s",' "${friends_list[@]}"); friends_json="[${friends_json%,}]"
                
                cd ~/.zen/strfry
                local friends_messages=$(./strfry scan "{
                    \"kinds\": [1],
                    \"authors\": ${friends_json},
                    \"since\": ${since_timestamp},
                    \"limit\": 500
                }" 2>/dev/null | jq -c 'select(.kind == 1) | {id: .id, content: .content, created_at: .created_at, author: .pubkey, tags: .tags}')
                cd - >/dev/null
            fi
            
            if [[ -n "$friends_messages" ]]; then
                local message_count=0
                echo "$friends_messages" | while read -r message; do
                    local content=$(echo "$message" | jq -r .content)
                    local created_at=$(echo "$message" | jq -r .created_at)
                    local date_str=$(date -d "@$created_at" '+%Y-%m-%d %H:%M')
                    
                    if [[ "$summary_type" == "Daily" ]]; then
                        # For daily summaries, process raw friend messages
                        local author_hex=$(echo "$message" | jq -r .author)
                        local author_nprofile=$(${MY_PATH}/../tools/nostr_hex2nprofile.sh "$author_hex" 2>/dev/null)
                        # Fallback to hex if nprofile generation fails
                        [[ -z "$author_nprofile" ]] && author_nprofile="$author_hex"
                        
                        # Extract metadata
                        local message_application=$(echo "$message" | jq -r '.tags[] | select(.[0] == "application") | .[1]' | head -n 1)
                        local message_latitude=$(echo "$message" | jq -r '.tags[] | select(.[0] == "latitude") | .[1]' | head -n 1)
                        local message_longitude=$(echo "$message" | jq -r '.tags[] | select(.[0] == "longitude") | .[1]' | head -n 1)
                        
                        echo "### 📝 $date_str" >> "$summary_file"
                        echo "**Author**: nostr:$author_nprofile" >> "$summary_file"
                        
                        # Add metadata if available
                        if [[ -n "$message_application" && "$message_application" != "null" ]]; then
                            echo "**App**: $message_application" >> "$summary_file"
                        fi
                        
                        if [[ -n "$message_latitude" && -n "$message_longitude" && "$message_latitude" != "null" && "$message_longitude" != "null" ]]; then
                            echo "**Location**: $message_latitude, $message_longitude" >> "$summary_file"
                        fi
                        
                        echo "" >> "$summary_file"
                        echo "$content" >> "$summary_file"
                        echo "" >> "$summary_file"
                elif [[ "$summary_type" == "Weekly" ]]; then
                    # For weekly summaries, process daily summaries
                    echo "### 📅 $date_str" >> "$summary_file"
                    echo "**Daily Summary**" >> "$summary_file"
                    echo "" >> "$summary_file"
                    echo "$content" >> "$summary_file"
                    echo "" >> "$summary_file"
                    echo "---" >> "$summary_file"
                    echo "" >> "$summary_file"
                elif [[ "$summary_type" == "Monthly" ]]; then
                    # For monthly summaries, process weekly summaries
                    echo "### 📊 $date_str" >> "$summary_file"
                    echo "**Weekly Summary**" >> "$summary_file"
                    echo "" >> "$summary_file"
                    echo "$content" >> "$summary_file"
                    echo "" >> "$summary_file"
                    echo "---" >> "$summary_file"
                    echo "" >> "$summary_file"
                else
                    # For yearly summaries, process monthly summaries
                    echo "### 🗓️ $date_str" >> "$summary_file"
                    echo "**Monthly Summary**" >> "$summary_file"
                    echo "" >> "$summary_file"
                    echo "$content" >> "$summary_file"
                    echo "" >> "$summary_file"
                    echo "---" >> "$summary_file"
                    echo "" >> "$summary_file"
                fi
                    
                    ((message_count++))
                done
                
            # Add AI summary if too many messages (threshold depends on summary type)
            local ai_threshold=5  # Reduced threshold for more personalized summaries
            if [[ "$summary_type" == "Weekly" ]]; then
                ai_threshold=5  # 5 daily summaries = 1 week
            elif [[ "$summary_type" == "Monthly" ]]; then
                ai_threshold=3   # 3 weekly summaries = 1 month
            elif [[ "$summary_type" == "Yearly" ]]; then
                ai_threshold=8   # 8 monthly summaries = 1 year
            fi
                
                # Personal N² journal for each MULTIPASS with lower threshold
                if [[ "$summary_type" == "Daily" ]]; then
                    ai_threshold=5  # Lower threshold for personalized N² journal
                    log "INFO" "Personal N² journal: AI threshold set to $ai_threshold for ${PLAYER}"
                fi
                
            if [[ $message_count -gt $ai_threshold ]]; then
                local source_type="messages"
                if [[ "$summary_type" == "Weekly" ]]; then
                    source_type="daily summaries"
                elif [[ "$summary_type" == "Monthly" ]]; then
                    source_type="weekly summaries"
                elif [[ "$summary_type" == "Yearly" ]]; then
                    source_type="monthly summaries"
                fi
                    
                    log "INFO" "Too many $source_type ($message_count), generating AI summary for ${PLAYER} ($summary_type)"
                    
                    local ai_prompt=""
                    if [[ "$summary_type" == "Daily" ]]; then
                        ai_prompt="[TEXT] $(cat "$summary_file") [/TEXT] --- \
# Create a RECONNECTION SUMMARY for ${PLAYER} (nostr:$player_nprofile) - what happened while they were away. \
# 1. Start with a brief executive summary: 'Welcome back! Here's what happened in your network over the last $summary_period.' \
# 2. Create a 'What You Missed' section highlighting the most important events, announcements, or discussions. \
# 3. Group messages by author and highlight key topics and trends that would interest ${PLAYER}. \
# 4. Add a 'Key Highlights' section with the most significant activities (new connections, important discussions, etc.). \
# 5. Include a 'Network Activity' section showing who was most active and what they shared. \
# 6. Add hashtags and emojis for readability and personality. \
# 7. Use Markdown formatting (headers, bold, lists, etc.) for better structure. \
# 8. IMPORTANT: Never omit an author, even if you summarize - each friend matters to ${PLAYER}. \
# 9. Use the same language as mostly used in the messages. \
# 10. Make it feel like a personal briefing about what happened in ${PLAYER}'s social network while they were away. \
# 11. Include insights about what's happening in ${PLAYER}'s extended network (N²). \
# 12. End with a 'Next Steps' or 'Follow-up' section suggesting what ${PLAYER} might want to check out."
                    elif [[ "$summary_type" == "Weekly" ]]; then
                        ai_prompt="[TEXT] $(cat "$summary_file") [/TEXT] --- \
# Create a WEEKLY RECONNECTION SUMMARY for ${PLAYER} - what happened in their network over the past week. \
# 1. Start with 'Weekly Overview: Here's what happened in your network this week.' \
# 2. Analyze daily summaries to identify key trends, patterns, and highlights. \
# 3. Create a 'Week in Review' section with major events and discussions. \
# 4. Group information by themes and time periods. \
# 5. Add hashtags and emojis for readability. \
# 6. Use Markdown formatting (headers, bold, lists, etc.) for better structure. \
# 7. Focus on evolution and changes over time. \
# 8. Create a narrative that shows the progression of activity. \
# 9. Include a 'Weekly Highlights' section with the most important developments. \
# 10. Use the same language as mostly used in the daily summaries."
                    elif [[ "$summary_type" == "Monthly" ]]; then
                        ai_prompt="[TEXT] $(cat "$summary_file") [/TEXT] --- \
# Create a MONTHLY RECONNECTION SUMMARY for ${PLAYER} - what happened in their network over the past month. \
# 1. Start with 'Monthly Overview: Here's what happened in your network this month.' \
# 2. Analyze weekly summaries to identify major trends, patterns, and highlights. \
# 3. Create a 'Month in Review' section with major events and discussions. \
# 4. Group information by themes and time periods. \
# 5. Add hashtags and emojis for readability. \
# 6. Use Markdown formatting (headers, bold, lists, etc.) for better structure. \
# 7. Focus on long-term evolution and major changes over time. \
# 8. Create a narrative that shows the monthly progression of activity. \
# 9. Highlight key milestones and significant events. \
# 10. Include a 'Monthly Highlights' section with the most important developments. \
# 11. Use the same language as mostly used in the weekly summaries."
                    else
                        ai_prompt="[TEXT] $(cat "$summary_file") [/TEXT] --- \
# Create a YEARLY RECONNECTION SUMMARY for ${PLAYER} - what happened in their network over the past year. \
# 1. Start with 'Yearly Overview: Here's what happened in your network this year.' \
# 2. Analyze monthly summaries to identify major trends, patterns, and highlights. \
# 3. Create a 'Year in Review' section with major events and discussions. \
# 4. Group information by themes and time periods. \
# 5. Add hashtags and emojis for readability. \
# 6. Use Markdown formatting (headers, bold, lists, etc.) for better structure. \
# 7. Focus on long-term evolution and major changes over time. \
# 8. Create a narrative that shows the yearly progression of activity. \
# 9. Highlight key milestones and significant events. \
# 10. Identify seasonal patterns and annual trends. \
# 11. Include a 'Yearly Highlights' section with the most important developments. \
# 12. Use the same language as mostly used in the monthly summaries."
                    fi
                    
                    local ai_summary=$(${MY_PATH}/../IA/question.py "$ai_prompt")
                    echo "$ai_summary" > "$summary_file"
                fi
                
                # Publish personal N² journal to MULTIPASS wall
                local summary_content=$(cat "$summary_file")
                local d_tag="personal-n2-journal-${PLAYER}-${summary_type,,}-${TODATE}"
                local published_at=$(date +%s)
                
                # Convert NSEC to HEX for nostpy-cli
                local NPRIV_HEX=$(${MY_PATH}/../tools/nostr2hex.py "$NSEC")
                
                # Build tags for personal N² journal
                local summary_tags="[['d', '$d_tag'], ['title', '$summary_title'], ['published_at', '$published_at'], ['t', 'PersonalN2Journal'], ['t', 'N2Network'], ['t', '$summary_type'], ['t', 'UPlanet'], ['t', 'SummaryType:$summary_type'], ['p', '$PLAYER']]"
                
                # Send as kind 30023 (article) to MULTIPASS wall
                nostpy-cli send_event \
                    -privkey "$NPRIV_HEX" \
                    -kind 30023 \
                    -content "$summary_content" \
                    -tags "$summary_tags" \
                    --relay "$myRELAY" \
                    >/dev/null 2>&1
                
                log "INFO" "✅ Personal N² journal published to ${PLAYER} wall ($message_count messages)"
                log_metric "PERSONAL_N2_JOURNAL_PUBLISHED" "$message_count" "${PLAYER}"
                FRIENDS_SUMMARIES_PUBLISHED=$((FRIENDS_SUMMARIES_PUBLISHED + 1))
                
                # Increment specific counter based on summary type
                if [[ "$summary_type" == "Daily" ]]; then
                    DAILY_SUMMARIES=$((DAILY_SUMMARIES + 1))
                elif [[ "$summary_type" == "Weekly" ]]; then
                    WEEKLY_SUMMARIES=$((WEEKLY_SUMMARIES + 1))
                elif [[ "$summary_type" == "Monthly" ]]; then
                    MONTHLY_SUMMARIES=$((MONTHLY_SUMMARIES + 1))
                elif [[ "$summary_type" == "Yearly" ]]; then
                    YEARLY_SUMMARIES=$((YEARLY_SUMMARIES + 1))
                fi
            else
                log "DEBUG" "No friends messages found for ${PLAYER} in the last 24h - personal N² journal empty"
            fi
            
            # Cleanup temporary directory
            rm -rf "$summary_dir"
        else
            log "DEBUG" "No friends found for ${PLAYER} - skipping personal N² journal"
        fi
    fi

    ########################################################################################
    ########################################################################
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

        ########################################################################
        ## YOUTUBE LIKES SYNC - Once per day PER USER at uDRIVE sync time
        ########################################################################
        # Check if YouTube sync should run for this user today (only once per day per user)
        YOUTUBE_SYNC_TODAY_FILE="$HOME/.zen/tmp/youtube_sync_${PLAYER}_${TODATE}.done"
        if [[ ! -f "$YOUTUBE_SYNC_TODAY_FILE" ]]; then
            # Check if user has YouTube cookie file
            if [[ -s ~/.zen/game/nostr/${PLAYER}/.cookie.txt ]]; then
                log "INFO" "🎵 Starting YouTube likes sync for user: ${PLAYER}"
                log_metric "YOUTUBE_SYNC_START" "1" "${PLAYER}"
                
                # Launch YouTube likes synchronization in background
                ${MY_PATH}/../IA/sync_youtube_likes.sh "${PLAYER}" --debug &
                YOUTUBE_SYNC_PID=$!
                
                log "INFO" "YouTube sync started for ${PLAYER} (PID: $YOUTUBE_SYNC_PID)"
                log_metric "YOUTUBE_SYNC_PID" "$YOUTUBE_SYNC_PID" "${PLAYER}"
                
                # Mark YouTube sync as done for this user today
                touch "$YOUTUBE_SYNC_TODAY_FILE"
                YOUTUBE_SYNC_USERS=$((YOUTUBE_SYNC_USERS + 1))
                log "INFO" "✅ YouTube sync scheduled for ${PLAYER}"
                log_metric "YOUTUBE_SYNC_SCHEDULED" "1" "${PLAYER}"
            else
                log "DEBUG" "No YouTube cookie file found for user: ${PLAYER} - Visit $uSPOT/cookie to upload your YouTube cookies"
            fi
        else
            log "DEBUG" "YouTube sync already completed today for ${PLAYER} - skipping"
        fi
    else
        echo "IPNS update skipped for ${PLAYER} (no refresh needed)"
    fi
    stop=$(date +%s)
    player_duration=$((stop - start))
    log "DEBUG" "MULTIPASS refresh DONE for ${PLAYER} in ${player_duration}s"
    log_metric "PLAYER_PROCESSING_TIME" "$player_duration" "${PLAYER}"

done

########################################################################
## YOUTUBE LIKES SYNC - Once per day PER USER at uDRIVE sync time
########################################################################
# YouTube sync handled for each user during their refresh cycle
# when uDRIVE sync occurs (daily_update or udrive_update refresh reasons)

end=`date +%s`
dur=`expr $end - $gstart`
hours=$((dur / 3600)); minutes=$(( (dur % 3600) / 60 )); seconds=$((dur % 60))

# Log comprehensive summary
log "INFO" "============================================ NOSTR REFRESH SUMMARY"
log "INFO" "📊 Players: ${#NOSTR[@]} total | $DAILY_UPDATES daily | $FILE_UPDATES files | $SKIPPED_PLAYERS skipped"
log "INFO" "💰 Payments: $PAYMENTS_PROCESSED processed | $PAYMENTS_FAILED failed | $PAYMENTS_ALREADY_DONE already done"
log "INFO" "👥 Personal N² Journals: $FRIENDS_SUMMARIES_PUBLISHED total ($DAILY_SUMMARIES daily | $WEEKLY_SUMMARIES weekly | $MONTHLY_SUMMARIES monthly | $YEARLY_SUMMARIES yearly)"
log "INFO" "🔗 N² Network Expansions: $USOCIETY_N2_EXPANSIONS"
log "INFO" "🎵 YouTube Sync: $YOUTUBE_SYNC_USERS users"
log "INFO" "⏱️  Duration: ${hours}h ${minutes}m ${seconds}s"
log "INFO" "============================================ NOSTR.refresh DONE."

# Log global metrics for monitoring
log_metric "TOTAL_PLAYERS" "${#NOSTR[@]}"
log_metric "DAILY_UPDATES" "$DAILY_UPDATES"
log_metric "FILE_UPDATES" "$FILE_UPDATES"
log_metric "SKIPPED_PLAYERS" "$SKIPPED_PLAYERS"
log_metric "PAYMENTS_PROCESSED" "$PAYMENTS_PROCESSED"
log_metric "PAYMENTS_FAILED" "$PAYMENTS_FAILED"
log_metric "PERSONAL_N2_JOURNALS_PUBLISHED" "$FRIENDS_SUMMARIES_PUBLISHED"
log_metric "DAILY_N2_JOURNALS" "$DAILY_SUMMARIES"
log_metric "WEEKLY_N2_JOURNALS" "$WEEKLY_SUMMARIES"
log_metric "MONTHLY_N2_JOURNALS" "$MONTHLY_SUMMARIES"
log_metric "YEARLY_N2_JOURNALS" "$YEARLY_SUMMARIES"
log_metric "N2_NETWORK_EXPANSIONS" "$USOCIETY_N2_EXPANSIONS"
log_metric "YOUTUBE_SYNC_USERS" "$YOUTUBE_SYNC_USERS"
log_metric "EXECUTION_TIME_SECONDS" "$dur"
rm -Rf ~/.zen/tmp/${MOATS}
rm -f "$LOCKFILE"

exit 0
