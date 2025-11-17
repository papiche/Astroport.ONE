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

# Validate NIP-23 compliance for kind 30023 events
validate_nip23_event() {
    local content="$1"
    local title="$2"
    local d_tag="$3"
    local tags="$4"
    
    # Check required elements
    if [[ -z "$content" ]]; then
        log "ERROR" "NIP-23 validation failed: content is empty"
        return 1
    fi
    
    if [[ -z "$title" ]]; then
        log "ERROR" "NIP-23 validation failed: title is empty"
        return 1
    fi
    
    if [[ -z "$d_tag" ]]; then
        log "ERROR" "NIP-23 validation failed: d tag is empty"
        return 1
    fi
    
    # Check content length (reasonable limit)
    if [[ ${#content} -gt 200000 ]]; then
        log "WARN" "NIP-23 validation: content very long (${#content} chars), may be rejected by some relays"
    fi
    
    # Check title length
    if [[ ${#title} -gt 200 ]]; then
        log "WARN" "NIP-23 validation: title very long (${#title} chars), may be truncated by clients"
    fi
    
    log "DEBUG" "NIP-23 validation passed: content=${#content} chars, title='$title', d='$d_tag'"
    return 0
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
    log "DEBUG" "Starting uDRIVE generation for ${PLAYER}"
    udrive_start=$(date +%s)
    UDRIVE=$(./generate_ipfs_structure.sh .)
    udrive_end=$(date +%s)
    udrive_duration=$((udrive_end - udrive_start))
    log "DEBUG" "uDRIVE generation completed in ${udrive_duration}s for ${PLAYER}"
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
            temp_email_file=$(mktemp)
            echo "$balance_celebration" > "$temp_email_file"
            ${MY_PATH}/../tools/mailjet.sh --expire 7d "${PLAYER}" "$temp_email_file" "Seuil de 100 Ẑen Atteint - $TODATE"
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
            temp_email_file=$(mktemp)
            echo "$low_balance_warning" > "$temp_email_file"
            ${MY_PATH}/../tools/mailjet.sh --expire 7d "${PLAYER}" "$temp_email_file" "Solde Faible - $TODATE"
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
            temp_email_file=$(mktemp)
            echo "$anniversary_1year" > "$temp_email_file"
            ${MY_PATH}/../tools/mailjet.sh --expire 7d "${PLAYER}" "$temp_email_file" "🎉 1 An avec UPlanet - $TODATE"
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
            temp_email_file=$(mktemp)
            echo "$milestone_6months" > "$temp_email_file"
            ${MY_PATH}/../tools/mailjet.sh --expire 7d "${PLAYER}" "$temp_email_file" "🎯 6 Mois avec UPlanet - $TODATE"
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
    ## 1st Day send welcome message...
    if [[ ! -s ~/.zen/game/nostr/${PLAYER}/.welcome.html ]]; then
        cp ${MY_PATH}/../templates/NOSTR/welcome.html ~/.zen/game/nostr/${PLAYER}/.welcome.html \
        && sed -i "s~http://127.0.0.1:8080~${myIPFS}~g" ~/.zen/game/nostr/${PLAYER}/.welcome.html \
        && sed -i "s~_USPOT_~${uSPOT}~g" ~/.zen/game/nostr/${PLAYER}/.welcome.html \
        && ${MY_PATH}/../tools/mailjet.sh "${PLAYER}" "${HOME}/.zen/game/nostr/${PLAYER}/.welcome.html" "Welcome on UPlanet"
        log "INFO" "Welcome email sent to new MULTIPASS: ${PLAYER}"
        log_metric "WELCOME_EMAIL_SENT" "1" "${PLAYER}"
    fi

    ####################################################################
    ## EVERY 7 DAYS NOSTR CARD is PAYING CAPTAIN
    # Skip payment logic for CAPTAIN (no rental payment needed)
    if [[ "${PLAYER}" == "${CAPTAINEMAIL}" ]] || [[ "${CAPTAING1PUB}" == "${G1PUBNOSTR}" ]]; then
        echo "___ CAPTAIN WALLET ACCOUNT : $COINS G1"
        # Skip all payment logic for CAPTAIN
    elif [[ ! -s ~/.zen/game/players/${PLAYER}/U.SOCIETY ]]; then
        # Regular MULTIPASS payment logic (not CAPTAIN, not U.SOCIETY member)
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
<p><strong>Montant HT:</strong> <span class='amount'>$(echo "$Npaf * 10" | awk '{print $1 * $3}') ẐEN</span></p>
<p><strong>Montant TVA:</strong> <span class='amount'>$(echo "$TVA_AMOUNT * 10" | awk '{print $1 * $3}') ẐEN</span></p>
<p><strong>Total payé:</strong> <span class='amount'>$(echo "$TOTAL_PAYMENT * 10" | awk '{print $1 * $3}') ẐEN</span></p>
<p><strong>Solde restant:</strong> $ZEN ẐEN</p>
<p><strong>Prochain paiement:</strong> $NEXT_PAYMENT_DATE</p>
</div>
<p>Votre MULTIPASS est à jour ! Continuez à créer du contenu de qualité pour gagner plus de ẐEN.</p>
<p><strong>💡 Astuce:</strong> Chaque like sur vos posts = 1 ẐEN automatique dans votre portefeuille.</p>
</body></html>"

                                # Create temporary file for email content
                                temp_email_file=$(mktemp)
                                echo "$success_message" > "$temp_email_file"
                                ${MY_PATH}/../tools/mailjet.sh --expire 7d "${PLAYER}" "$temp_email_file" "Paiement Réussi - $TODATE"
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
                                temp_email_file=$(mktemp)
                                echo "$error_message" > "$temp_email_file"
                                ${MY_PATH}/../tools/mailjet.sh --expire 7d "${PLAYER}" "$temp_email_file" "MULTIPASS Payment Error - $TODATE"
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
                    temp_email_file=$(mktemp)
                    echo "$usociety_expired" > "$temp_email_file"
                    ${MY_PATH}/../tools/mailjet.sh --expire 7d "${PLAYER}" "$temp_email_file" "U.SOCIETY Expiré - Renouvellement Requis"
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
                            temp_email_file=$(mktemp)
                            echo "$usociety_warning_30" > "$temp_email_file"
                            ${MY_PATH}/../tools/mailjet.sh --expire 7d "${PLAYER}" "$temp_email_file" "U.SOCIETY Expire dans $DIFF_DAYS jours"
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
                            temp_email_file=$(mktemp)
                            echo "$usociety_warning_7" > "$temp_email_file"
                            ${MY_PATH}/../tools/mailjet.sh --expire 7d "${PLAYER}" "$temp_email_file" "URGENT: U.SOCIETY Expire dans $DIFF_DAYS jours"
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
                    ${HOME}/.zen/Astroport.ONE/tools/mailjet.sh --expire 7d "${CAPTAINEMAIL}" "$HOME/.zen/game/passport/${PUBKEY}/.passport.html" "U.SOCIETY Fallback Expiration - ${PLAYER}"
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
        NPUB=$(cat ~/.zen/game/nostr/${PLAYER}/NPUB)

        # Update email in NOSTR profile during refresh (ensure email is always present)
        # This ensures the email is always available in the profile for frontend retrieval
        if [[ -s ~/.zen/game/nostr/${PLAYER}/.secret.nostr ]]; then
            # Update email only during daily refresh to avoid excessive updates
            # But ensure it's done at least once per day
            if [[ "$REFRESH_REASON" == "daily_update" ]]; then
                log "INFO" "Updating email in NOSTR profile for ${PLAYER} during daily refresh"
                ${MY_PATH}/../tools/nostr_update_profile.py \
                    "${PLAYER}" \
                    "wss://relay.copylaradio.com" "$myRELAY" \
                    --email "$PLAYER" \
                    2>&1 | while read line; do log "DEBUG" "$line"; done
                    
                    if [[ $? -eq 0 ]]; then
                        log "INFO" "✅ Email updated in NOSTR profile for ${PLAYER}"
                    else
                        log "WARN" "⚠️ Failed to update email in NOSTR profile for ${PLAYER}"
                    fi
                    
                    # Update DID document - Read from NOSTR relay (source of truth) instead of local cache
                    # This updates IPNS addresses, wallet info, and other metadata
                    # IMPORTANT: Preserve existing contract status (sociétaire, infrastructure, etc.)
                    if [[ -f "${MY_PATH}/../tools/did_manager_nostr.sh" ]] && [[ -f "${MY_PATH}/../tools/nostr_did_client.py" ]]; then
                        log "INFO" "Reading DID document from NOSTR relay (source of truth) for ${PLAYER}"
                        
                        # Get player's NPUB (already defined earlier in the loop)
                        if [[ -n "$NPUB" ]]; then
                            # Query NOSTR relay for DID document using nostr_did_client.py (specialized tool)
                            # This is more reliable than nostr_get_events.sh for DID documents
                            did_content=""
                            for relay in "ws://127.0.0.1:7777" "wss://relay.copylaradio.com"; do
                                log "DEBUG" "Querying DID from ${relay} for ${PLAYER}"
                                did_content=$(python3 "${MY_PATH}/../tools/nostr_did_client.py" fetch --author "$NPUB" --relay "$relay" --kind 30800 -q 2>/dev/null)
                                
                                if [[ -n "$did_content" ]] && [[ "$did_content" != "null" ]] && echo "$did_content" | jq empty 2>/dev/null; then
                                    log "INFO" "✅ DID found on ${relay} for ${PLAYER}"
                                    break
                                fi
                            done
                            
                            update_type="MULTIPASS"
                            current_status=""
                            did_end_date=""
                            
                            if [[ -n "$did_content" ]] && [[ "$did_content" != "null" ]] && command -v jq &>/dev/null; then
                                # Parse DID JSON content to extract contractStatus
                                current_status=$(echo "$did_content" | jq -r '.metadata.contractStatus // "active_rental"' 2>/dev/null)
                                
                                # Also extract end date from DID
                                did_end_date=$(echo "$did_content" | jq -r '.metadata.contractEndDate // .metadata.expirationDate // .metadata.societyEndDate // empty' 2>/dev/null)
                                
                                # Map contract status to update type to preserve it
                                case "$current_status" in
                                    "cooperative_member_satellite")
                                        update_type="SOCIETAIRE_SATELLITE"
                                        log "INFO" "Preserving sociétaire satellite status from NOSTR DID"
                                        ;;
                                    "cooperative_member_constellation")
                                        update_type="SOCIETAIRE_CONSTELLATION"
                                        log "INFO" "Preserving sociétaire constellation status from NOSTR DID"
                                        ;;
                                    "infrastructure_contributor")
                                        update_type="INFRASTRUCTURE"
                                        log "INFO" "Preserving infrastructure contributor status from NOSTR DID"
                                        ;;
                                    "cooperative_treasury_contributor"|"cooperative_rnd_contributor"|"cooperative_assets_contributor")
                                        log "INFO" "Preserving contribution status from NOSTR DID: ${current_status}"
                                        # Check services to determine if also sociétaire
                                        has_satellite=$(echo "$did_content" | jq -r '.metadata.services // ""' 2>/dev/null | grep -q "satellite" && echo "yes" || echo "no")
                                        has_constellation=$(echo "$did_content" | jq -r '.metadata.services // ""' 2>/dev/null | grep -q "constellation" && echo "yes" || echo "no")
                                        if [[ "$has_constellation" == "yes" ]]; then
                                            update_type="SOCIETAIRE_CONSTELLATION"
                                        elif [[ "$has_satellite" == "yes" ]]; then
                                            update_type="SOCIETAIRE_SATELLITE"
                                        fi
                                        ;;
                                    "active_rental"|""|"null")
                                        update_type="MULTIPASS"
                                        ;;
                                    *)
                                        log "INFO" "Unknown contract status from NOSTR DID: ${current_status}, using MULTIPASS"
                                        update_type="MULTIPASS"
                                        ;;
                                esac
                                
                                log "INFO" "DID found in NOSTR relay, updating with preserved status"
                            else
                                log "INFO" "No DID document found in NOSTR relay, creating new DID with default type"
                            fi
                            
                            # Update or create DID document
                            ${MY_PATH}/../tools/did_manager_nostr.sh update "${PLAYER}" "$update_type" "0" "0" \
                                2>&1 | while read line; do log "DEBUG" "$line"; done
                            
                            if [[ $? -eq 0 ]]; then
                                # Log the end date from U.SOCIETY.end file if it exists
                                end_date=""
                                usociety_end_file="${HOME}/.zen/game/nostr/${PLAYER}/U.SOCIETY.end"
                                
                                if [[ -f "$usociety_end_file" ]]; then
                                    end_date=$(cat "$usociety_end_file" 2>/dev/null)
                                    if [[ -n "$end_date" ]]; then
                                        log "INFO" "📅 Contract end date: ${end_date}"
                                    fi
                                fi
                                
                                # Use end date from NOSTR DID if available
                                if [[ -n "$did_end_date" ]] && [[ "$did_end_date" != "null" ]] && [[ "$did_end_date" != "" ]]; then
                                    if [[ -z "$end_date" ]] || [[ "$end_date" != "$did_end_date" ]]; then
                                        log "INFO" "📅 Contract end date (from NOSTR DID): ${did_end_date}"
                                    fi
                                fi
                                
                                if [[ -n "$current_status" ]]; then
                                    if [[ -n "$end_date" ]] || [[ -n "$did_end_date" ]]; then
                                        log "INFO" "✅ DID document updated for ${PLAYER} (status: ${current_status}, end date: ${end_date:-${did_end_date:-N/A}})"
                                    else
                                        log "INFO" "✅ DID document updated for ${PLAYER} (preserved status: ${current_status})"
                                    fi
                                else
                                    if [[ -n "$end_date" ]] || [[ -n "$did_end_date" ]]; then
                                        log "INFO" "✅ DID document updated for ${PLAYER} (type: ${update_type}, end date: ${end_date:-${did_end_date:-N/A}})"
                                    else
                                        log "INFO" "✅ DID document updated for ${PLAYER} (update type: ${update_type})"
                                    fi
                                fi
                            else
                                log "WARN" "⚠️ Failed to update DID document for ${PLAYER}"
                            fi
                        else
                            log "WARN" "⚠️ Player NPUB not found for ${PLAYER}, skipping DID update"
                        fi
                    else
                        log "WARN" "⚠️ did_manager_nostr.sh or nostr_did_client.py not found, skipping DID update"
                    fi
                fi
            fi
        fi
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
        summary_type=""
        summary_period=""
        summary_title=""
        summary_days=0
        
        # Calculate days since birthdate
        birthdate_seconds=$(date -d "$BIRTHDATE" +%s)
        today_seconds=$(date -d "$TODATE" +%s)
        days_since_birth=$(( (today_seconds - birthdate_seconds) / 86400 ))
        
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
        friends_list=($(${MY_PATH}/../tools/nostr_get_N1.sh "$HEX" 2>/dev/null))
        
        # Personal N² journal for ALL MULTIPASS accounts (individual and personalized)
        log "INFO" "Creating personal N² journal for ${PLAYER} - individual and tailored to their network"
        
        # Debug: Check if friends have any messages in the relay
        if [[ ${#friends_list[@]} -gt 0 ]]; then
            log "DEBUG" "Checking if friends have messages in relay..."
            friends_check_start=$(date +%s)
            for friend_hex in "${friends_list[@]:0:3}"; do  # Check first 3 friends only for debug
                friend_messages=$(${MY_PATH}/../tools/nostr_get_events.sh \
                    --kind 1 \
                    --author "$friend_hex" \
                    --limit 1 \
                    --output count 2>/dev/null)
                log "DEBUG" "Friend $friend_hex has $friend_messages messages in relay"
            done
            friends_check_end=$(date +%s)
            friends_check_duration=$((friends_check_end - friends_check_start))
            log "DEBUG" "Friends check completed in ${friends_check_duration}s for ${PLAYER}"
        fi
        
        # Get friends of friends (N²) for personalized journal
        log "DEBUG" "Starting N² friends generation for ${PLAYER}"
        n2_start=$(date +%s)
        n2_friends=()
        for friend_hex in "${friends_list[@]}"; do
            friend_friends=($(${MY_PATH}/../tools/nostr_get_N1.sh "$friend_hex" 2>/dev/null))
            n2_friends+=("${friend_friends[@]}")
        done
        n2_end=$(date +%s)
        n2_duration=$((n2_end - n2_start))
        log "DEBUG" "N² friends generation completed in ${n2_duration}s for ${PLAYER}"
        
        # Remove duplicates and add to friends list
        all_friends=("${friends_list[@]}" "${n2_friends[@]}")
        unique_friends=($(printf '%s\n' "${all_friends[@]}" | sort -u))
        friends_list=("${unique_friends[@]}")
        
        log "INFO" "Personal N² journal: ${#friends_list[@]} total friends (N1 + N²) for ${PLAYER}'s individual network"
        USOCIETY_N2_EXPANSIONS=$((USOCIETY_N2_EXPANSIONS + 1))
        
        if [[ ${#friends_list[@]} -gt 0 ]]; then
            log "INFO" "Found ${#friends_list[@]} friends for ${PLAYER} - generating summary"
            
            # Create temporary directory for summary processing
            summary_dir="${HOME}/.zen/tmp/${MOATS}/friends_summary_${PLAYER}"
            mkdir -p "$summary_dir"
            
            # Generate personal N² journal for this specific MULTIPASS
            summary_file="${summary_dir}/personal_n2_journal_${PLAYER}.md"
            
            # Get nprofile for the MULTIPASS owner
            player_nprofile=$(${MY_PATH}/../tools/nostr_hex2nprofile.sh "$HEX" 2>/dev/null)
            [[ -z "$player_nprofile" ]] && player_nprofile="$HEX"
            
            echo "# $summary_title" > "$summary_file"
            echo "**Date**: $TODATE" >> "$summary_file"
            echo "**MULTIPASS**: $PLAYER" >> "$summary_file"
            echo "**NProfile**: nostr:$player_nprofile" >> "$summary_file"
            echo "**Period**: $summary_period" >> "$summary_file"
            echo "**Type**: Personal N² Journal ($summary_type)" >> "$summary_file"
            echo "**Network**: ${#friends_list[@]} friends (N1 + N²)" >> "$summary_file"
            
            # Add GPS coordinates if available
            player_gps_file="${HOME}/.zen/game/nostr/${PLAYER}/GPS"
            if [[ -f "$player_gps_file" ]]; then
                player_lat=$(grep "^LAT=" "$player_gps_file" | tail -1 | cut -d'=' -f2 | tr -d ';' | xargs)
                player_lon=$(grep "^LON=" "$player_gps_file" | tail -1 | cut -d'=' -f2 | tr -d ';' | xargs)
                if [[ -n "$player_lat" && -n "$player_lon" && "$player_lat" != "" && "$player_lon" != "" ]]; then
                    echo "**Location**: $player_lat, $player_lon" >> "$summary_file"
                    echo "**UMAP Zone**: ${player_lat}_${player_lon}" >> "$summary_file"
                fi
            fi
            
            echo "" >> "$summary_file"
            
            # For Weekly/Monthly/Yearly summaries, use published summaries instead of raw messages
            if [[ "$summary_type" == "Weekly" ]]; then
                log "INFO" "Using published daily summaries for $summary_type summary (more efficient)"

                # Get published daily summaries from this MULTIPASS wall using nostr_get_events.sh
                since_timestamp=$(date -d "${summary_days} days ago" +%s)

                log "DEBUG" "Querying daily summaries using nostr_get_events.sh for ${PLAYER}"
                daily_summaries=$(${MY_PATH}/../tools/nostr_get_events.sh \
                    --kind 30023 \
                    --author "$HEX" \
                    --tag-t "SummaryType:Daily" \
                    --since "$since_timestamp" \
                    --limit 100 2>/dev/null | \
                    jq -c 'select(.kind == 30023) | {id: .id, content: .content, created_at: .created_at, tags: .tags}')

                # Process daily summaries instead of raw messages
                friends_messages="$daily_summaries"
                
                if [[ -n "$daily_summaries" ]]; then
                    summary_count=$(echo "$daily_summaries" | wc -l)
                    log "DEBUG" "Retrieved $summary_count daily summaries for ${PLAYER}"
                else
                    log "DEBUG" "No daily summaries found for ${PLAYER}"
                fi
            elif [[ "$summary_type" == "Monthly" ]]; then
                log "INFO" "Using published weekly summaries for $summary_type summary (most efficient)"

                # Get published weekly summaries from this MULTIPASS wall using nostr_get_events.sh
                since_timestamp=$(date -d "${summary_days} days ago" +%s)

                log "DEBUG" "Querying weekly summaries using nostr_get_events.sh for ${PLAYER}"
                weekly_summaries=$(${MY_PATH}/../tools/nostr_get_events.sh \
                    --kind 30023 \
                    --author "$HEX" \
                    --tag-t "SummaryType:Weekly" \
                    --since "$since_timestamp" \
                    --limit 100 2>/dev/null | \
                    jq -c 'select(.kind == 30023) | {id: .id, content: .content, created_at: .created_at, tags: .tags}')

                # Process weekly summaries instead of raw messages
                friends_messages="$weekly_summaries"
                
                if [[ -n "$weekly_summaries" ]]; then
                    summary_count=$(echo "$weekly_summaries" | wc -l)
                    log "DEBUG" "Retrieved $summary_count weekly summaries for ${PLAYER}"
                else
                    log "DEBUG" "No weekly summaries found for ${PLAYER}"
                fi
            elif [[ "$summary_type" == "Yearly" ]]; then
                log "INFO" "Using published monthly summaries for $summary_type summary (most efficient)"

                # Get published monthly summaries from this MULTIPASS wall using nostr_get_events.sh
                since_timestamp=$(date -d "${summary_days} days ago" +%s)

                log "DEBUG" "Querying monthly summaries using nostr_get_events.sh for ${PLAYER}"
                monthly_summaries=$(${MY_PATH}/../tools/nostr_get_events.sh \
                    --kind 30023 \
                    --author "$HEX" \
                    --tag-t "SummaryType:Monthly" \
                    --since "$since_timestamp" \
                    --limit 100 2>/dev/null | \
                    jq -c 'select(.kind == 30023) | {id: .id, content: .content, created_at: .created_at, tags: .tags}')

                # Process monthly summaries instead of raw messages
                friends_messages="$monthly_summaries"
                
                if [[ -n "$monthly_summaries" ]]; then
                    summary_count=$(echo "$monthly_summaries" | wc -l)
                    log "DEBUG" "Retrieved $summary_count monthly summaries for ${PLAYER}"
                else
                    log "DEBUG" "No monthly summaries found for ${PLAYER}"
                fi
            else
                # For Daily summaries, get raw messages from friends using nostr_get_events.sh
                since_timestamp=$(date -d "${summary_days} days ago" +%s)
                
                log "DEBUG" "Querying messages using nostr_get_events.sh for ${#friends_list[@]} friends since $(date -d "@$since_timestamp" '+%Y-%m-%d %H:%M')"
                
                log "DEBUG" "Starting nostr_get_events.sh queries for ${PLAYER}"
                query_start=$(date +%s)
                
                # Use nostr_get_events.sh with multiple authors (comma-separated or multiple --author)
                # Build comma-separated authors list for efficient query
                if [[ ${#friends_list[@]} -gt 0 ]]; then
                    friends_comma=$(IFS=','; echo "${friends_list[*]}")
                    
                    friends_messages=$(${MY_PATH}/../tools/nostr_get_events.sh \
                        --kind 1 \
                        --author "$friends_comma" \
                        --since "$since_timestamp" \
                        --limit 500 2>/dev/null | \
                        jq -c 'select(.kind == 1) | {id: .id, content: .content, created_at: .created_at, author: .pubkey, tags: .tags}')
                else
                    friends_messages=""
                fi
                
                query_end=$(date +%s)
                query_duration=$((query_end - query_start))
                log "DEBUG" "nostr_get_events.sh queries completed in ${query_duration}s for ${PLAYER}"
                
                # Debug: Check what we got
                if [[ -n "$friends_messages" ]]; then
                    message_count_debug=$(echo "$friends_messages" | grep -c '^{' || echo "0")
                    log "DEBUG" "Retrieved $message_count_debug messages from friends for ${PLAYER}"
                else
                    log "DEBUG" "No messages retrieved from friends for ${PLAYER} (friends: ${#friends_list[@]})"
                fi
            fi
            
            # Check if we have actual messages (not just empty string)
            if [[ -n "$friends_messages" && "$friends_messages" != "" ]]; then
                message_count=0
                # Use process substitution to avoid subshell issues
                while read -r message; do
                    # Skip empty lines
                    [[ -z "$message" || "$message" == "" ]] && continue
                    
                    content=$(echo "$message" | jq -r .content 2>/dev/null)
                    created_at=$(echo "$message" | jq -r .created_at 2>/dev/null)
                    
                    # Skip if jq failed to parse
                    [[ "$content" == "null" || "$created_at" == "null" ]] && continue
                    
                    date_str=$(date -d "@$created_at" '+%Y-%m-%d %H:%M' 2>/dev/null)
                    [[ -z "$date_str" ]] && date_str="Unknown date"
                    
                    if [[ "$summary_type" == "Daily" ]]; then
                        # For daily summaries, process raw friend messages
                        author_hex=$(echo "$message" | jq -r .author 2>/dev/null)
                        [[ "$author_hex" == "null" || -z "$author_hex" ]] && continue
                        
                        author_nprofile=$(${MY_PATH}/../tools/nostr_hex2nprofile.sh "$author_hex" 2>/dev/null)
                        # Fallback to hex if nprofile generation fails
                        [[ -z "$author_nprofile" ]] && author_nprofile="$author_hex"
                        
                        # Extract metadata
                        message_application=$(echo "$message" | jq -r '.tags[] | select(.[0] == "application") | .[1]' 2>/dev/null | head -n 1)
                        message_latitude=$(echo "$message" | jq -r '.tags[] | select(.[0] == "latitude") | .[1]' 2>/dev/null | head -n 1)
                        message_longitude=$(echo "$message" | jq -r '.tags[] | select(.[0] == "longitude") | .[1]' 2>/dev/null | head -n 1)
                        
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
                done < <(echo "$friends_messages")
                
            # Add AI summary if too many messages (threshold depends on summary type)
            ai_threshold=5  # Reduced threshold for more personalized summaries
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
                source_type="messages"
                if [[ "$summary_type" == "Weekly" ]]; then
                    source_type="daily summaries"
                elif [[ "$summary_type" == "Monthly" ]]; then
                    source_type="weekly summaries"
                elif [[ "$summary_type" == "Yearly" ]]; then
                    source_type="monthly summaries"
                fi
                    
                    log "INFO" "Too many $source_type ($message_count), generating AI summary for ${PLAYER} ($summary_type)"
                    
                    # Get user's preferred language from LANG file
                    USER_LANG=$(cat ${HOME}/.zen/game/nostr/${PLAYER}/LANG 2>/dev/null)
                    [[ -z "$USER_LANG" ]] && USER_LANG="en"
                    log "DEBUG" "User language preference: ${USER_LANG}"
                    
                    # Set language instruction based on user preference
                    case "$USER_LANG" in
                        "fr")
                            LANG_INSTRUCTION="Rédige EXCLUSIVEMENT en FRANÇAIS. Ne traduis pas, écris directement en français."
                            ;;
                        "es")
                            LANG_INSTRUCTION="Escribe EXCLUSIVAMENTE en ESPAÑOL. No traduzcas, escribe directamente en español."
                            ;;
                        "de")
                            LANG_INSTRUCTION="Schreibe AUSSCHLIESSLICH auf DEUTSCH. Übersetze nicht, schreibe direkt auf Deutsch."
                            ;;
                        "it")
                            LANG_INSTRUCTION="Scrivi ESCLUSIVAMENTE in ITALIANO. Non tradurre, scrivi direttamente in italiano."
                            ;;
                        "pt")
                            LANG_INSTRUCTION="Escreva EXCLUSIVAMENTE em PORTUGUÊS. Não traduza, escreva diretamente em português."
                            ;;
                        *)
                            LANG_INSTRUCTION="Write EXCLUSIVELY in ENGLISH. Do not translate, write directly in English."
                            ;;
                    esac
                    
                    ai_prompt=""
                    if [[ "$summary_type" == "Daily" ]]; then
                        ai_prompt="You are a personal AI assistant creating a reconnection summary for ${PLAYER}.

LANGUAGE REQUIREMENT: ${LANG_INSTRUCTION}

SOURCE CONTENT:
[TEXT]
$(cat "$summary_file")
[/TEXT]

TASK: Create a personalized daily N² network journal for ${PLAYER} (nostr:$player_nprofile)

STRUCTURE:
1. **Executive Summary** (2-3 lines): Brief overview of network activity in the last ${summary_period}
2. **What You Missed**: Most important events, announcements, discussions (grouped by theme)
3. **Active Contributors**: Who posted what, with key insights per author
4. **Key Highlights**: New connections, important discussions, trending topics
5. **Network Insights**: Patterns in your N² network (extended circle)
6. **Follow-up Suggestions**: What to check out next

STYLE GUIDELINES:
- Use emojis for visual appeal (but don't overdo it)
- Write in Markdown (headers, bold, lists, quotes)
- Be conversational and personal (write TO ${PLAYER}, not about them)
- Keep it concise but informative
- Never omit an author - each friend matters
- Focus on value: what would ${PLAYER} want to know?
- Add relevant hashtags for key topics

CRITICAL: ${LANG_INSTRUCTION}"
                    elif [[ "$summary_type" == "Weekly" ]]; then
                        ai_prompt="You are a personal AI assistant creating a weekly reconnection summary for ${PLAYER}.

LANGUAGE REQUIREMENT: ${LANG_INSTRUCTION}

SOURCE CONTENT:
[TEXT]
$(cat "$summary_file")
[/TEXT]

TASK: Synthesize the week's daily summaries into a weekly overview for ${PLAYER}

STRUCTURE:
1. **Weekly Overview** (3-4 lines): What defined this week in your network
2. **Week in Review**: Major events and discussions (grouped by theme/time)
3. **Trending Topics**: What themes emerged over the week
4. **Active Period Analysis**: When was your network most active
5. **Evolution & Changes**: How conversations evolved day-to-day
6. **Weekly Highlights**: Top 5 moments of the week

ANALYSIS FOCUS:
- Identify patterns and trends across daily summaries
- Show progression: how topics evolved over the week
- Highlight connections between different days
- Extract meta-insights about network behavior

STYLE GUIDELINES:
- Use emojis sparingly for section markers
- Create a narrative arc for the week
- Use Markdown for structure
- Be analytical yet accessible
- Focus on big picture, not individual messages

CRITICAL: ${LANG_INSTRUCTION}"
                    elif [[ "$summary_type" == "Monthly" ]]; then
                        ai_prompt="You are a personal AI assistant creating a monthly reconnection summary for ${PLAYER}.

LANGUAGE REQUIREMENT: ${LANG_INSTRUCTION}

SOURCE CONTENT:
[TEXT]
$(cat "$summary_file")
[/TEXT]

TASK: Synthesize the month's weekly summaries into a monthly overview for ${PLAYER}

STRUCTURE:
1. **Monthly Overview** (4-5 lines): The month at a glance in your network
2. **Month in Review**: Major developments week by week
3. **Trending Themes**: What dominated conversations this month
4. **Network Evolution**: How your community changed/grew
5. **Key Milestones**: Significant events that shaped the month
6. **Monthly Highlights**: Top moments and achievements

ANALYSIS FOCUS:
- Synthesize weekly patterns into monthly trends
- Identify long-term developments
- Show community evolution
- Extract strategic insights
- Connect disparate events into coherent narrative

STYLE GUIDELINES:
- Use emojis for major section markers
- Create a coherent month-long narrative
- Use Markdown for clear structure
- Be strategic and forward-looking
- Focus on impact and significance

CRITICAL: ${LANG_INSTRUCTION}"
                    else
                        ai_prompt="You are a personal AI assistant creating a yearly reconnection summary for ${PLAYER}.

LANGUAGE REQUIREMENT: ${LANG_INSTRUCTION}

SOURCE CONTENT:
[TEXT]
$(cat "$summary_file")
[/TEXT]

TASK: Synthesize the year's monthly summaries into a yearly overview for ${PLAYER}

STRUCTURE:
1. **Yearly Overview** (5-6 lines): The year that was in your network
2. **Year in Review**: Quarter-by-quarter analysis of major developments
3. **Annual Themes**: What defined your network this year
4. **Community Growth**: How your N² network evolved over 12 months
5. **Seasonal Patterns**: Identify recurring themes by season
6. **Key Achievements**: Major milestones and breakthroughs
7. **Looking Forward**: Emerging trends for next year

ANALYSIS FOCUS:
- Identify long-term trends and cycles
- Show annual evolution and growth
- Extract strategic insights from monthly data
- Recognize seasonal patterns
- Celebrate achievements and growth
- Provide forward-looking perspective

STYLE GUIDELINES:
- Use emojis for major section markers
- Create an epic year-long narrative
- Use Markdown with rich formatting
- Be reflective and visionary
- Focus on transformation and impact
- Make it memorable and inspiring

CRITICAL: ${LANG_INSTRUCTION}"
                    fi
                    
                    log "DEBUG" "Starting AI summary generation for ${PLAYER}"
                    ai_start=$(date +%s)
                    ai_summary=$(${MY_PATH}/../IA/question.py "$ai_prompt" --model "gemma3:12b")
                    ai_end=$(date +%s)
                    ai_duration=$((ai_end - ai_start))
                    log "DEBUG" "AI summary generation completed in ${ai_duration}s for ${PLAYER}"
                    echo "$ai_summary" > "$summary_file"
                fi
                
                # Publish personal N² journal to MULTIPASS wall
                summary_content=$(cat "$summary_file")
                d_tag="personal-n2-journal-${PLAYER}-${summary_type,,}-${TODATE}"
                published_at=$(date +%s)
                
                # Create summary for the article (first 200 characters)
                summary_text=$(echo "$summary_content" | head -c 200 | sed 's/"/\\"/g')
                if [[ ${#summary_content} -gt 200 ]]; then
                    summary_text="${summary_text}..."
                fi
                
                # Build NIP-23 compliant tags for personal N² journal using jq for proper JSON escaping
                # Same format as UPlanet_IA_Responder.sh for kind 30023
                # Required: d (unique identifier), title (article title)
                # Recommended: summary (article summary), published_at (publication timestamp), t (hashtags)
                ExtraTags=$(jq -c -n \
                    --arg d "$d_tag" \
                    --arg title "$summary_title" \
                    --arg summary "$summary_text" \
                    --arg published_at "$published_at" \
                    --arg type "$summary_type" \
                    '[["d", $d], ["title", $title], ["summary", $summary], ["published_at", $published_at], ["t", "PersonalN2Journal"], ["t", "N2Network"], ["t", $type], ["t", "UPlanet"], ["t", "SummaryType:" + $type]]')
                
                # Send as kind 30023 (article) to MULTIPASS wall
                # Validate NIP-23 compliance before publication
                if ! validate_nip23_event "$summary_content" "$summary_title" "$d_tag" "$ExtraTags"; then
                    log "ERROR" "NIP-23 validation failed for ${PLAYER}, skipping publication"
                    continue
                fi
                
                # Validate content length (NIP-23 recommends reasonable length)
                if [[ ${#summary_content} -gt 100000 ]]; then
                    log "WARN" "Content too long for kind 30023 (${#summary_content} chars), truncating to 100k"
                    summary_content=$(echo "$summary_content" | head -c 100000)
                fi
                
                # Log debug info before sending (same style as UPlanet_IA_Responder.sh)
                log "DEBUG" "Publishing N² journal to relay: $myRELAY"
                log "DEBUG" "Event tags (first 300 chars): $(echo "$ExtraTags" | head -c 300)..."
                log "DEBUG" "Content length: ${#summary_content} chars"
                
                # Prepare keyfile path for nostr_send_note.py (same method as UPlanet_IA_Responder.sh)
                KEYFILE_PATH="${HOME}/.zen/game/nostr/${PLAYER}/.secret.nostr"
                
                # For kind 30023, use only the specific blog tags (same as UPlanet_IA_Responder.sh line 1051)
                TAGS_JSON="$ExtraTags"
                
                # Send event using nostr_send_note.py (same method as UPlanet_IA_Responder.sh line 1068-1075)
                SEND_RESULT=$(python3 "${MY_PATH}/../tools/nostr_send_note.py" \
                    --keyfile "$KEYFILE_PATH" \
                    --content "$summary_content" \
                    --relays "$myRELAY" \
                    --tags "$TAGS_JSON" \
                    --kind 30023 \
                    --json 2>&1)
                SEND_EXIT_CODE=$?
                
                if [[ $SEND_EXIT_CODE -eq 0 ]]; then
                    # Parse JSON response
                    EVENT_ID=$(echo "$SEND_RESULT" | jq -r '.event_id // empty' 2>/dev/null)
                    RELAYS_SUCCESS=$(echo "$SEND_RESULT" | jq -r '.relays_success // 0' 2>/dev/null)
                    
                    if [[ -n "$EVENT_ID" && "$RELAYS_SUCCESS" -gt 0 ]]; then
                        log "INFO" "✅ Personal N² journal published to ${PLAYER} wall (ID: $EVENT_ID, $message_count messages)"
                        log_metric "PERSONAL_N2_JOURNAL_PUBLISHED" "$message_count" "${PLAYER}"
                        FRIENDS_SUMMARIES_PUBLISHED=$((FRIENDS_SUMMARIES_PUBLISHED + 1))
                    else
                        log "WARN" "⚠️ Personal N² journal may not have been published correctly for ${PLAYER}"
                        log "DEBUG" "Response: $SEND_RESULT"
                        log_metric "PERSONAL_N2_JOURNAL_FAILED" "1" "${PLAYER}"
                    fi
                else
                    log "ERROR" "❌ Failed to publish N² journal for ${PLAYER}. Exit code: $SEND_EXIT_CODE"
                    log "DEBUG" "Error output: $SEND_RESULT"
                    log "DEBUG" "Publication failed details:"
                    log "DEBUG" "  d_tag: $d_tag"
                    log "DEBUG" "  summary_type: $summary_type"
                    log "DEBUG" "  HEX: $HEX"
                    log "DEBUG" "  relay: $myRELAY"
                    log "DEBUG" "  tags: $TAGS_JSON"
                    log "DEBUG" "  keyfile: $KEYFILE_PATH"
                    log_metric "PERSONAL_N2_JOURNAL_FAILED" "1" "${PLAYER}"
                fi
                
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
        log "DEBUG" "Starting IPFS add for ${PLAYER}"
        ipfs_start=$(date +%s)
        NOSTRIPFS=$(ipfs add -rwq ${HOME}/.zen/game/nostr/${PLAYER}/ | tail -n 1)
        ipfs_end=$(date +%s)
        ipfs_duration=$((ipfs_end - ipfs_start))
        log "DEBUG" "IPFS add completed in ${ipfs_duration}s for ${PLAYER}"
        
        log "DEBUG" "Starting IPNS publish for ${PLAYER}"
        ipns_start=$(date +%s)
        ipfs name publish --key "${G1PUBNOSTR}:NOSTR" /ipfs/${NOSTRIPFS}
        ipns_end=$(date +%s)
        ipns_duration=$((ipns_end - ipns_start))
        log "DEBUG" "IPNS publish completed in ${ipns_duration}s for ${PLAYER}"

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
        ## AUTOMATED DOMAIN SCRAPERS - Once per day PER USER at uDRIVE sync time
        ## Detects all *.cookie files and runs corresponding domain.sh scripts
        ########################################################################
        PLAYER_DIR="$HOME/.zen/game/nostr/${PLAYER}"
        
        # Find all cookie files (hidden files starting with . and ending with .cookie)
        COOKIE_FILES=($(find "$PLAYER_DIR" -maxdepth 1 -type f -name ".*.cookie" 2>/dev/null))
        
        if [[ ${#COOKIE_FILES[@]} -gt 0 ]]; then
            log "INFO" "🍪 Found ${#COOKIE_FILES[@]} cookie file(s) for ${PLAYER}"
            
            for COOKIE_FILE in "${COOKIE_FILES[@]}"; do
                # Extract domain from cookie filename
                # Example: .youtube.com.cookie -> youtube.com
                COOKIE_BASENAME=$(basename "$COOKIE_FILE")
                DOMAIN="${COOKIE_BASENAME#.}"  # Remove leading dot
                DOMAIN="${DOMAIN%.cookie}"     # Remove .cookie extension
                
                log "INFO" "🔍 Processing cookie for domain: ${DOMAIN}"
                
                # Check if script was already run today for this domain
                DOMAIN_SYNC_TODAY_FILE="$HOME/.zen/tmp/${DOMAIN}_sync_${PLAYER}_${TODATE}.done"
                
                if [[ -f "$DOMAIN_SYNC_TODAY_FILE" ]]; then
                    log "DEBUG" "${DOMAIN} scraper already completed today for ${PLAYER} - skipping"
                    continue
                fi
                
                # Look for domain-specific script (e.g., youtube.com.sh, leboncoin.fr.sh)
                DOMAIN_SCRIPT="${MY_PATH}/../IA/${DOMAIN}.sh"
                
                if [[ -f "$DOMAIN_SCRIPT" && -x "$DOMAIN_SCRIPT" ]]; then
                    log "INFO" "🚀 Running scraper for ${DOMAIN}: ${DOMAIN_SCRIPT}"
                    
                    # Create dedicated log file to avoid broken pipe errors
                    DOMAIN_SYNC_LOG="$HOME/.zen/tmp/${DOMAIN}_sync_${PLAYER}.log"
                    mkdir -p "$(dirname "$DOMAIN_SYNC_LOG")"
                    
                    # Launch domain-specific script in background
                    (
                        "${DOMAIN_SCRIPT}" "${PLAYER}" "$COOKIE_FILE" > "$DOMAIN_SYNC_LOG" 2>&1
                        sync_exit_code=$?
                        if [[ $sync_exit_code -eq 0 ]]; then
                            log "INFO" "✅ ${DOMAIN} scraper completed successfully for ${PLAYER}"
                        else
                            log "WARN" "⚠️ ${DOMAIN} scraper completed with exit code $sync_exit_code for ${PLAYER}"
                        fi
                    ) &
                    DOMAIN_SYNC_PID=$!
                    
                    log "INFO" "${DOMAIN} scraper started for ${PLAYER} (PID: $DOMAIN_SYNC_PID, log: $DOMAIN_SYNC_LOG)"
                    log_metric "${DOMAIN}_SYNC_PID" "$DOMAIN_SYNC_PID" "${PLAYER}"
                    
                    # Mark as done for today
                    touch "$DOMAIN_SYNC_TODAY_FILE"
                    
                    # Increment counter for specific domains
                    if [[ "$DOMAIN" == "youtube.com" ]]; then
                        YOUTUBE_SYNC_USERS=$((YOUTUBE_SYNC_USERS + 1))
                    fi
                    
                    log_metric "${DOMAIN}_SYNC_SCHEDULED" "1" "${PLAYER}"
                    
                elif [[ -f "$DOMAIN_SCRIPT" && ! -x "$DOMAIN_SCRIPT" ]]; then
                    log "ERROR" "❌ Script found but not executable: ${DOMAIN_SCRIPT}"
                    log "ERROR" "   Run: chmod +x ${DOMAIN_SCRIPT}"
                else
                    # Script not found - notify user via email
                    log "INFO" "📧 No scraper found for ${DOMAIN}, notifying ${PLAYER}"
                    
                    # Check if notification already sent for this domain
                    DOMAIN_NOTIF_FILE="$PLAYER_DIR/.${DOMAIN}_notified"
                    
                    if [[ ! -f "$DOMAIN_NOTIF_FILE" ]]; then
                        # Create notification email
                        notification_email="<html><head><meta charset='UTF-8'>
<style>
    body { font-family: 'Courier New', monospace; }
    .info { color: #2196F3; font-weight: bold; }
    .details { background-color: #E3F2FD; padding: 15px; margin: 10px 0; border-left: 4px solid #2196F3; }
    .next-steps { background-color: #FFF3E0; padding: 15px; margin: 10px 0; border-left: 4px solid #FF9800; }
</style></head><body>
<h2 class='info'>🍪 Nouveau Cookie Détecté - Service Non Disponible</h2>
<div class='details'>
<p><strong>MULTIPASS:</strong> ${PLAYER}</p>
<p><strong>Domaine:</strong> ${DOMAIN}</p>
<p><strong>Fichier cookie:</strong> ${COOKIE_BASENAME}</p>
<p><strong>Date:</strong> $TODATE</p>
</div>
<p>Votre cookie pour <strong>${DOMAIN}</strong> a été détecté, mais aucun service automatisé n'est disponible pour ce domaine.</p>
<div class='next-steps'>
<h3>🚀 Créer un Service Personnalisé</h3>
<p>Vous pouvez demander la création d'un service automatisé pour ce domaine :</p>
<ul>
<li>📧 <strong>Contactez le Capitaine :</strong> ${CAPTAINEMAIL}</li>
<li>💬 <strong>Décrivez votre besoin :</strong> Quel type de données souhaitez-vous extraire de ${DOMAIN} ?</li>
<li>📝 <strong>Smart Contract :</strong> Un script personnalisé sera créé et ajouté au code officiel</li>
<li>🔄 <strong>Automatisation :</strong> Une fois validé, le service s'exécutera automatiquement chaque jour</li>
</ul>
</div>
<p><strong>💡 Services déjà disponibles :</strong></p>
<ul>
<li>✅ <strong>YouTube</strong> - Synchronisation automatique des likes</li>
<li>✅ <strong>Leboncoin</strong> - Recherche d'annonces géolocalisées</li>
</ul>
<p><strong>🔧 Extensibilité :</strong> Le système est conçu pour supporter facilement de nouveaux domaines !</p>
</body></html>"
                        
                        # Create temporary file for email content
                        temp_email_file=$(mktemp)
                        echo "$notification_email" > "$temp_email_file"
                        ${MY_PATH}/../tools/mailjet.sh --expire 7d "${PLAYER}" "$temp_email_file" "🍪 Cookie: ${DOMAIN} - MISSING ASTROBOT PROGRAM"
                        rm -f "$temp_email_file"
                        
                        # Mark notification as sent
                        echo "$TODATE" > "$DOMAIN_NOTIF_FILE"
                        
                        log "INFO" "✅ Notification email sent to ${PLAYER} for domain ${DOMAIN}"
                        log_metric "DOMAIN_NOTIFICATION_SENT" "1" "${PLAYER}"
                    else
                        log "DEBUG" "Notification already sent for domain ${DOMAIN} to ${PLAYER}"
                    fi
                fi
            done
        else
            log "DEBUG" "No cookie files found for ${PLAYER} - Visit $uSPOT/cookie to upload cookies"
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
## AUTOMATED DOMAIN SCRAPERS - Once per day PER USER at uDRIVE sync time
########################################################################
# Domain-specific scrapers (youtube.com.sh, leboncoin.fr.sh, etc.)
# are handled for each user during their refresh cycle when uDRIVE sync occurs.
# Cookie files are automatically detected as .DOMAIN.cookie files.
# If a scraper doesn't exist for a domain, the user is notified by email.

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
