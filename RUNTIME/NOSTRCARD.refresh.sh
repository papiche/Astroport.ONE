#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ NOSTRCARD.refresh.sh
#~ Synchronize NOSTR Card identities, check payment cycles, and refresh IPNS data.
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
# Load cooperative config from DID NOSTR (shared across swarm)
. "${MY_PATH}/../tools/cooperative_config.sh" 2>/dev/null && coop_load_env_vars 2>/dev/null || true

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
#### AVOID MULTIPLE RUN (AVEC AUTO-NETTOYAGE)
LOCK_FILE="/tmp/nostrcard_refresh.lock"
exec 200>"$LOCK_FILE"

if ! flock -n 200; then
    echo "Verrou actif détecté. Vérification des processus fantômes..."
    # Récupère tous les PID qui maintiennent le verrou ouvert
    STALE_PIDS=$(lsof -t "$LOCK_FILE" 2>/dev/null || fuser "$LOCK_FILE" 2>/dev/null | tr -d ':')
    
    REAL_RUN=false
    for p in $STALE_PIDS; do
        # Vérifie si c'est vraiment le script principal qui tourne
        if [[ "$p" != "$$" ]] && ps -p "$p" -o cmd= 2>/dev/null | grep -q "[N]OSTRCARD.refresh.sh"; then
            REAL_RUN=true
            break
        fi
    done
    
    if [[ "$REAL_RUN" == false && -n "$STALE_PIDS" ]]; then
        echo "🧹 Processus orphelins détectés ($STALE_PIDS). Auto-nettoyage..."
        kill -9 $STALE_PIDS 2>/dev/null
        sleep 1
        # On retente d'acquérir le verrou après avoir fait le ménage
        flock -n 200 || { echo "Script déjà en cours"; exit 0; }
    else
        echo "Script déjà en cours (instance légitime en cours d'exécution)"; exit 0;
    fi
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

    # Initialize counters for summary
    DAILY_UPDATES=0
    FILE_UPDATES=0
    SKIPPED_PLAYERS=0
    PAYMENTS_PROCESSED=0
    PAYMENTS_FAILED=0
    PAYMENTS_ALREADY_DONE=0

# Génère une heure aléatoire de rafraîchissement (fallback pour nouveau compte isolé)
get_random_refresh_time() {
    local random_minutes=$(( (RANDOM % 1212) - 1 ))
    printf "%02d:%02d" $(( random_minutes / 60 )) $(( random_minutes % 60 ))
}

# Redistribue les .refresh_time pour répartir équitablement N joueurs sur la fenêtre 00:00-20:12.
# Tri alphabétique → slot stable même si l'ordre ls -t change entre deux runs.
rebalance_refresh_times() {
    local -a all_players=("$@")
    local n=${#all_players[@]}
    [[ $n -lt 2 ]] && return

    local window=1212  # minutes de 00:00 à 20:12
    local step=$(( window / n ))
    [[ $step -lt 1 ]] && step=1
    local half_step=$(( step / 2 ))
    [[ $half_step -lt 1 ]] && half_step=1

    # Tri alphabétique pour un index stable
    local -a sorted
    IFS=$'\n' sorted=($(printf '%s\n' "${all_players[@]}" | sort)); unset IFS

    local rebalanced=0
    for i in "${!sorted[@]}"; do
        local p="${sorted[$i]}"
        local pdir="$HOME/.zen/game/nostr/${p}"
        [[ ! -d "$pdir" ]] && continue

        local ideal=$(( i * step ))
        local new_time
        new_time=$(printf "%02d:%02d" $(( ideal / 60 )) $(( ideal % 60 )))

        local cur_time
        cur_time=$(cat "${pdir}/.refresh_time" 2>/dev/null || echo "")
        local cur_min=0
        if [[ "$cur_time" =~ ^([0-9]{2}):([0-9]{2})$ ]]; then
            cur_min=$(( 10#${BASH_REMATCH[1]} * 60 + 10#${BASH_REMATCH[2]} ))
        fi
        local diff=$(( ideal - cur_min ))
        [[ $diff -lt 0 ]] && diff=$(( -diff ))

        if [[ $diff -gt $half_step ]]; then
            echo "$new_time" > "${pdir}/.refresh_time"
            (( rebalanced++ ))
        fi
    done
    [[ $rebalanced -gt 0 ]] && log "INFO" "Refresh slots rebalanced: $rebalanced/$n players (step=${step}min)"
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

    # Initialiser le fichier TODAY (date de début de contrat), .account_created (= date inscription)
    [[ ! -s "${player_dir}/TODATE" ]] \
        && echo "$TODATE" > "${player_dir}/TODATE" \
        && echo "$TODATE" > "${player_dir}/.account_created"
    
    [[ ! -s "${player_dir}/.account_created" ]] \
        && cat "${player_dir}/TODATE" > "${player_dir}/.account_created"

    # Initialiser le fichier de dernière mise à jour IPNS
    date +%s > "${player_dir}/.last_ipns_update"

    # Initialiser le fichier de dernier paiement
    echo "" > "${player_dir}/.lastpayment"

    echo "Account ${PLAYER} initialized with refresh time: ${random_time}"
}


# Fonction pour vérifier si le rafraîchissement est nécessaire
should_refresh() {
    local player="$1"
    local player_dir="${HOME}/.zen/game/nostr/${player}"
    local current_time=$(date '+%H:%M')
    local refresh_time_file="${player_dir}/.refresh_time"
    local last_refresh_file="${player_dir}/.todate"
    local last_udrive_file="${player_dir}/.udrive"
    local last_ipns_update_file="${player_dir}/.last_ipns_update"

    UDRIVE=""
    REFRESH_REASON=""

    # Si le compte n'est pas initialisé, l'initialiser
    if [[ ! -d "$player_dir" ]] || [[ ! -s "$refresh_time_file" ]]; then
        initialize_account "${player}"
        return 1
    fi

    local refresh_time=$(cat "$refresh_time_file")
    local last_refresh=$(cat "$last_refresh_file")
    local last_udrive=$(cat "$last_udrive_file" 2>/dev/null)

    # Vérification 1 : Mise à jour quotidienne — une fois par jour APRÈS l'heure programmée.
    if [[ "$last_refresh" != "$TODATE" ]]; then
        local current_seconds=$((10#${current_time%%:*} * 3600 + 10#${current_time##*:} * 60))
        local refresh_seconds=$((10#${refresh_time%%:*} * 3600 + 10#${refresh_time##*:} * 60))
        if [[ $current_seconds -ge $refresh_seconds ]]; then
            REFRESH_REASON="daily_update"
            echo "Daily refresh needed for ${player} (scheduled time: ${refresh_time}, current: ${current_time})"
            return 0
        fi
    fi

    ##############################################
    ## uDRIVE APP UPDATE
    [[ ! -d "${player_dir}/APP/uDRIVE" ]] \
        && rm -Rf "${player_dir}/APP" \
        && mkdir -p "${player_dir}/APP/uDRIVE/"

    ## S'assurer que le script de génération est bien un lien symbolique local
    ## (ipfs get télécharge un fichier "dur", il faut le re-transformer en lien)
    rm -f "${player_dir}/APP/uDRIVE/generate_ipfs_structure.sh" 2>/dev/null
    cd "${player_dir}/APP/uDRIVE" && \
    ln -sf "${HOME}/.zen/Astroport.ONE/tools/generate_ipfs_structure.sh" "generate_ipfs_structure.sh" && \
    cd - 2>&1 >/dev/null

    ## Vérification rapide : le dossier uDRIVE a-t-il été modifié LOCALEMENT ?
    local udrive_dir_mtime=$(stat -c %Y "${player_dir}/APP/uDRIVE/" 2>/dev/null || echo 0)
    local udrive_cid_mtime=$(stat -c %Y "${last_udrive_file}" 2>/dev/null || echo 0)

    if [[ -n "$last_udrive" && $udrive_dir_mtime -le $udrive_cid_mtime ]]; then
        echo "UDRIVE CID: $last_udrive (no local changes)"
        return 1
    fi

    ## update uDRIVE APP (seulement si modification locale détectée)
    cd "${player_dir}/APP/uDRIVE/"
    log "DEBUG" "Starting uDRIVE generation for ${player}"
    local udrive_start=$(date +%s)
    UDRIVE=$(./generate_ipfs_structure.sh . 2>/dev/null)
    local udrive_end=$(date +%s)
    local udrive_duration=$((udrive_end - udrive_start))
    log "DEBUG" "uDRIVE generation completed in ${udrive_duration}s for ${player}"
    cd - 2>&1 >/dev/null

    if [[ -n "$UDRIVE" ]]; then
        if [[ "$UDRIVE" != "$last_udrive" ]]; then
            [[ -n "$last_udrive" ]] && ipfs --timeout 20s pin rm "$last_udrive" 2>/dev/null
            echo "$UDRIVE" > "${last_udrive_file}"
            REFRESH_REASON="udrive_update"
            return 0
        else
            echo "$UDRIVE" > "${last_udrive_file}"
            echo "UDRIVE CID: $last_udrive (unchanged)"
        fi
    else
        echo "UDRIVE CID: $last_udrive"
    fi

    return 1
}

[[ ${UPLANETG1PUB:0:8} == "4ZqazktD" ]] && ORIGIN="ORIGIN" || ORIGIN="${UPLANETG1PUB:0:8}"

########################################################################
# Get all emails from ~/.zen/game/nostr/
NOSTR=($(ls -t ~/.zen/game/nostr/ 2>/dev/null | grep "@" ))

# Filtre joueur unique : accepte $1 pour ne traiter qu'un seul joueur (utilisé par le dispatch parallèle)
[[ -n "$1" ]] && NOSTR=("$1")

# Répartition équitable des slots horaires dès le démarrage (uniquement en mode complet)
[[ -z "$1" ]] && rebalance_refresh_times "${NOSTR[@]}"

## Dispatch parallèle quand ASTRO_PARALLEL_REFRESH > 1 (appel complet, sans $1)
_PARALLEL="${ASTRO_PARALLEL_REFRESH:-1}"
if [[ -z "$1" && "$_PARALLEL" -gt 1 && "${#NOSTR[@]}" -gt 1 ]]; then
    printf '%s\n' "${NOSTR[@]}" | xargs -P "$_PARALLEL" -I{} bash "$0" {}
    exit $?
fi

## Helper: envoie un email MULTIPASS depuis un template avec substitutions dynamiques
_send_player_email() {
    local _tpl="$1" _subject="$2" _flag="${3:-}" _channel="${4:-milestones}"
    local _tmpf
    _tmpf=$(mktemp)
    sed -e "s~_PLAYER_~${PLAYER}~g" \
        -e "s~_TODATE_~${TODATE}~g" \
        -e "s~_ZEN_~${ZEN:-0}~g" \
        -e "s~_COINS_~${COINS:-0}~g" \
        -e "s~_BIRTHDATE_~${BIRTHDATE:-}~g" \
        -e "s~_NEXT_PAYMENT_DATE_~${NEXT_PAYMENT_DATE:-}~g" \
        -e "s~_USPOT_~${uSPOT}~g" \
        -e "s~_CAPTAINEMAIL_~${CAPTAINEMAIL}~g" \
        -e "s~_OC_URL_SATELLITE_~${OC_URL_SATELLITE}~g" \
        -e "s~_OC_URL_CONSTELLATION_~${OC_URL_CONSTELLATION}~g" \
        -e "s~_NCARD_~${NCARD}~g" \
        -e "s~_ZCARD_~${ZCARD}~g" \
        -e "s~_DOMAIN_~${DOMAIN:-}~g" \
        -e "s~_COOKIE_BASENAME_~${COOKIE_BASENAME:-}~g" \
        "${MY_PATH}/../templates/NOSTR/${_tpl}" > "$_tmpf"
    ${MY_PATH}/../tools/mailjet.sh \
        --channel "$_channel" \
        --template "${MY_PATH}/../templates/NOSTR/${_tpl}" \
        --expire 7d "${PLAYER}" "$_tmpf" "$_subject"
    rm -f "$_tmpf"
    [[ -n "$_flag" ]] && echo "${TODATE}" > "$_flag"
}

## RUNING FOR ALL LOCAL MULTIPASS (NOSTR Card)
for PLAYER in "${NOSTR[@]}"; do

    # ---------------------------------------------------------
    # IGNORER LES COMPTES ITINÉRANTS (ROAMING)
    if [[ -f ~/.zen/game/nostr/${PLAYER}/.roaming ]]; then
        log "INFO" "✈️ MULTIPASS visiteur ignoré (Roaming) : $PLAYER"
        continue
    fi

    # ---------------------------------------------------------
    # 1. Détection de corruption "Fantôme" (Fichiers de base absents)
    # ---------------------------------------------------------
    if [[ ! -f ~/.zen/game/nostr/${PLAYER}/HEX || ! -f ~/.zen/game/nostr/${PLAYER}/G1PUBNOSTR ]]; then
        BIRTHDATE=$(cat ~/.zen/game/nostr/${PLAYER}/.account_created 2>/dev/null)
        if [[ -n "$BIRTHDATE" ]]; then
            DIFF=$(( ($(date +%s) - $(date -d "$BIRTHDATE" +%s 2>/dev/null || date +%s)) / 86400 ))
            if [ $DIFF -gt 7 ]; then
                # Guard against RPi without RTC booting in 1970 before NTP sync
                if [[ $(date +%Y) -lt 2024 ]]; then
                    log "ERROR" "System clock unreliable (year=$(date +%Y)) — skipping deletion for $PLAYER"
                    continue
                fi
                if [[ -f ~/.zen/game/nostr/${PLAYER}/HEX ]]; then
                    HEX_TO_PURGE=$(cat ~/.zen/game/nostr/${PLAYER}/HEX)
                    log "INFO" "Purging local relay events for $PLAYER..."
                    cd ~/.zen/strfry && ./strfry scan '{"authors": ["'$HEX_TO_PURGE'"]}' | ./strfry delete 2>/dev/null
                    cd - > /dev/null
                fi
                log "CRITICAL" "TECHNICAL CORRUPTION: Ghost account detected. Purging: $PLAYER (Even if Captain)"
                rm -rf "${HOME}/.zen/game/nostr/${PLAYER}"
                rm -rf "${HOME}/.zen/game/players/${PLAYER}"
                continue
            fi
        fi
        log "INFO" "Ghost account $PLAYER detected but period of grace active (< 7 days)."
        continue
    fi

    # ---------------------------------------------------------
    log "INFO" ">>>>>>>>>>>>>>>>>>============================================ Processing MULTIPASS : $PLAYER "
    start=$(date +%s)
    HEX=$(cat ~/.zen/game/nostr/${PLAYER}/HEX 2>/dev/null)
    [[ -z "$HEX" ]] && log "ERROR" "Missing HEX for $PLAYER" && continue

    ## SWARM CACHE PUBLISHING
    if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/HEX ]]; then
        mkdir -p "${HOME}/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}"
        echo "$HEX" > "${HOME}/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/HEX"
    fi
    if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/GPS ]]; then
        mkdir -p "${HOME}/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}"
        cp "${HOME}/.zen/game/nostr/${PLAYER}/GPS" "${HOME}/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/GPS" 2>/dev/null
    fi

    ## LAT & LON
    source "${HOME}/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/GPS"

    if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/NPUB ]]; then
        mkdir -p "${HOME}/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}"
        cp "${HOME}/.zen/game/nostr/${PLAYER}/NPUB" "${HOME}/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/NPUB" 2>/dev/null
    fi

    G1PUBNOSTR=$(cat ~/.zen/game/nostr/${PLAYER}/G1PUBNOSTR)
    ## Add to node => swarm cache propagation (used by search_for_this_hex/email_in_uplanet.sh)
    if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/G1PUBNOSTR ]]; then
        echo "$G1PUBNOSTR" > ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/G1PUBNOSTR
    fi
    ## Publish NOSTRNS in swarm cache so upassport.sh can resolve any MULTIPASS from any swarm station
    ## upassport.sh::get_NOSTRNS_directory searches ~/.zen/tmp/*/TW/*/NOSTRNS as fallback
    if [[ ! -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/NOSTRNS ]]; then
        cp ${HOME}/.zen/game/nostr/${PLAYER}/NOSTRNS ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/NOSTRNS 2>/dev/null
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
    # Use makecoord to ensure proper formatting (e.g., 0.20 not .20)
    if [[ -n "$COINS" && "$COINS" != "null" ]]; then
        ZEN=$(makecoord $(echo "scale=2; ($COINS - 1) * 10" | bc))
        [[ -z "$ZEN" ]] && ZEN="0.00"
    else
        ZEN="0.00"
    fi
    # Valeurs par défaut pour éviter un crash bc si COINS/ZEN est vide ou "null"
    COINS=${COINS:-0}
    [[ "$COINS" == "null" ]] && COINS=0
    ZEN=${ZEN:-0}

    log "INFO" "${G1PUBNOSTR} AMOUNT (${COINS} G1) = ${ZEN} ZEN"
    log_metric "WALLET_BALANCE" "${COINS}" "${PLAYER}"

    # Check for balance threshold notifications
    if [[ $(echo "$COINS > 0" | bc -l) -eq 1 ]]; then
        # Check if this is a new high balance (first time above 10 G1)
        if [[ $(echo "$ZEN >= 100" | bc -l) -eq 1 && ! -s ~/.zen/game/nostr/${PLAYER}/.balance_10_notified ]]; then
            _send_player_email "multipass_balance_100zen.html" \
                "🎉 100 Ẑen franchis — votre contenu fait bouger l'essaim !" \
                "${HOME}/.zen/game/nostr/${PLAYER}/.balance_10_notified"
            log "INFO" "Balance celebration email sent to ${PLAYER} for reaching 100 Ẑen"
        fi
        
        # Check for low balance warning (below 2 G1)
        if [[ $(echo "$COINS < 2" | bc -l) -eq 1 && ! -s ~/.zen/game/nostr/${PLAYER}/.balance_low_warned ]]; then
            _send_player_email "multipass_low_balance.html" \
                "⚠️ Solde faible — votre MULTIPASS est en danger" \
                "${HOME}/.zen/game/nostr/${PLAYER}/.balance_low_warned" "alerts"
            log "INFO" "Low balance warning email sent to ${PLAYER}"
        fi
    fi

    BIRTHDATE=$(cat ~/.zen/game/nostr/${PLAYER}/TODATE 2>/dev/null)
    [[ ! -s ~/.zen/game/nostr/${PLAYER}/.account_created ]] \
        && echo $BIRTHDATE > ~/.zen/game/nostr/${PLAYER}/.account_created

    # Check for MULTIPASS anniversaries
    if [[ -n "$BIRTHDATE" ]]; then
        BIRTHDATE_SECONDS=$(date -d "$BIRTHDATE" +%s 2>/dev/null || date +%s)
        TODATE_SECONDS=$(date -d "$TODATE" +%s 2>/dev/null || date +%s)
        DAYS_OLD=$(( (TODATE_SECONDS - BIRTHDATE_SECONDS) / 86400 ))
        
        # 1 year anniversary
        if [[ $DAYS_OLD -eq 365 && ! -s ~/.zen/game/nostr/${PLAYER}/.anniversary_1year_notified ]]; then
            _send_player_email "multipass_anniversary_1year.html" \
                "🎂 1 an avec UPlanet — merci !" \
                "${HOME}/.zen/game/nostr/${PLAYER}/.anniversary_1year_notified"
            log "INFO" "1-year anniversary email sent to ${PLAYER}"
        fi
        
        # 6 months milestone
        if [[ $DAYS_OLD -eq 182 && ! -s ~/.zen/game/nostr/${PLAYER}/.milestone_6months_notified ]]; then
            _send_player_email "multipass_milestone_6months.html" \
                "🎯 6 mois avec UPlanet — mi-parcours !" \
                "${HOME}/.zen/game/nostr/${PLAYER}/.milestone_6months_notified"
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
        log "ERROR" "BAD DISCO DECODING for ${PLAYER}"
        BIRTHDATE=$(cat ~/.zen/game/nostr/${PLAYER}/.account_created 2>/dev/null)
        if [[ -n "$BIRTHDATE" ]]; then
            DIFF=$(( ($(date +%s) - $(date -d "$BIRTHDATE" +%s 2>/dev/null || date +%s)) / 86400 ))
            if [ $DIFF -gt 7 ]; then
                # Guard against RPi without RTC booting in 1970 before NTP sync
                if [[ $(date +%Y) -lt 2024 ]]; then
                    log "ERROR" "System clock unreliable (year=$(date +%Y)) — skipping deletion for $PLAYER"
                    continue
                fi
                log "CRITICAL" "TECHNICAL CORRUPTION: Keys unusable for $PLAYER. Forcing Hard Reset (rm -rf)."
                # --- PURGE RELAIS STRFRY ---
                if [[ -n "$HEX" ]]; then
                    cd ~/.zen/strfry
                    ./strfry scan '{"authors": ["'$HEX'"]}' | ./strfry delete 2>/dev/null
                    cd - > /dev/null
                fi
                # ---------------------------
                rm -rf "${HOME}/.zen/game/nostr/${PLAYER}"
                rm -rf "${HOME}/.zen/game/players/${PLAYER}"
                continue
            fi
        fi
        echo "ERROR : BAD DISCO DECODING" >> ~/.zen/game/nostr/${PLAYER}/ERROR
        continue
    fi
    ##################################################### DISCO DECODED
    ## NOW salt & pepper are valid, we can generate NSEC & NPUB
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
        && sed -i "s~_CORACLEURL_~${myCORACLE:-https://ipfs.copylaradio.com/ipns/coracle.copylaradio.com}~g" ~/.zen/game/nostr/${PLAYER}/.welcome.html \
        && ${MY_PATH}/../tools/mailjet.sh --channel milestones --template "${MY_PATH}/../templates/NOSTR/welcome.html" --expire 7d "${PLAYER}" "${HOME}/.zen/game/nostr/${PLAYER}/.welcome.html" "Welcome on UPlanet"
        log "INFO" "Welcome email sent to new MULTIPASS: ${PLAYER}"
        log_metric "WELCOME_EMAIL_SENT" "1" "${PLAYER}"
    fi

    ####################################################################
    ## ZINES QUOTIDIENS J1→J6 (période d'essai MULTIPASS, hors CAPTAIN)
    if [[ "${PLAYER}" != "${CAPTAINEMAIL}" ]] && [[ "${CAPTAING1PUB}" != "${G1PUBNOSTR}" ]]; then
        _ZINE_BIRTHDATE_SEC=$(date -d "${BIRTHDATE}" +%s 2>/dev/null || date +%s)
        _ZINE_TODAY_SEC=$(date -d "${TODATE}" +%s 2>/dev/null || date +%s)
        _ZINE_DAY=$(( (_ZINE_TODAY_SEC - _ZINE_BIRTHDATE_SEC) / 86400 ))

        ## Helper : prépare et envoie un Zine si le flag n'existe pas encore
        _send_zine() {
            local day="$1" tpl="$2" subject="$3"
            local flag="${HOME}/.zen/game/nostr/${PLAYER}/.zine_j${day}_sent"
            [[ -s "$flag" ]] && return 0
            local tmp_zine
            tmp_zine=$(mktemp)
            sed -e "s~_USPOT_~${uSPOT}~g" \
                -e "s~_MYIPFS_~${myIPFS}~g" \
                -e "s~_CORACLEURL_~${myCORACLE:-https://coracle.copylaradio.com}~g" \
                -e "s~_OC_URL_SATELLITE_~${OC_URL_SATELLITE}~g" \
                -e "s~_OC_URL_CONSTELLATION_~${OC_URL_CONSTELLATION}~g" \
                -e "s~_NCARD_~${NCARD}~g" \
                -e "s~_ZCARD_~${ZCARD}~g" \
                "${MY_PATH}/../templates/NOSTR/zine/${tpl}" > "$tmp_zine"
            ${MY_PATH}/../tools/mailjet.sh --channel zine --template "${MY_PATH}/../templates/NOSTR/zine/${tpl}" --expire 2d \
                "${PLAYER}" "$tmp_zine" "$subject"
            rm -f "$tmp_zine"
            echo "${TODATE}" > "$flag"
            log "INFO" "Zine J${day} envoyé à ${PLAYER} : ${subject}"
        }

        case $_ZINE_DAY in
            1) _send_zine 1 "zine_j1_coracle.html"    "🌐 J1 — Coracle, votre porte NOSTR" ;;
            2) _send_zine 2 "zine_j2_nextcloud.html"  "☁️ J2 — NextCloud, sortez du GAFAM" ;;
            3) _send_zine 3 "zine_j3_nostrtube.html"  "🎬 J3 — Nostr Tube & Vocals" ;;
            4) _send_zine 4 "zine_j4_wotx2.html"      "🕸️ J4 — WoTx2 & MineLife" ;;
            5) _send_zine 5 "zine_j5_zelkova.html"    "💎 J5 — Zelkova & TrocZen" ;;
            6) _send_zine 6 "zine_j6_ecosysteme.html" "🌐 J6 — L'écosystème complet" ;;
        esac

        unset -f _send_zine
        unset _ZINE_BIRTHDATE_SEC _ZINE_TODAY_SEC _ZINE_DAY
    fi
    ####################################################################

    ####################################################################
    ## EVERY 7 DAYS NOSTR CARD is PAYING CAPTAIN
    # Skip payment logic for CAPTAIN (no rental payment needed)
    if [[ "${PLAYER}" == "${CAPTAINEMAIL}" ]] || [[ "${CAPTAING1PUB}" == "${G1PUBNOSTR}" ]]; then
        echo "___ CAPTAIN WALLET ACCOUNT : $COINS G1"
        # Skip all payment logic for CAPTAIN
    elif [[ ! -s ~/.zen/game/players/${PLAYER}/U.SOCIETY ]]; then
        # Regular MULTIPASS payment logic (not CAPTAIN, not U.SOCIETY member)
        TODATE_SECONDS=$(date -d "$TODATE" +%s 2>/dev/null || date +%s)
        BIRTHDATE_SECONDS=$(date -d "$BIRTHDATE" +%s 2>/dev/null || echo "$TODATE_SECONDS")
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
                        ## Pay NCARD to CAPTAIN (TVA = 0 par défaut)
                        [[ -z $NCARD ]] && NCARD=1
                        Npaf=$(makecoord $(echo "$NCARD / 10" | bc -l))

                        # TODO unpatch ? : TVA à 0 par défaut
                        TVA_RATE=0
                        TVA_AMOUNT="0.00"
                        TVA_AMOUNT_G1=$(echo "scale=2; $TVA_AMOUNT / 10" | bc -l)

                        # Calculate total payment needed (= HT uniquement)
                        TOTAL_PAYMENT="$Npaf"
                        # Minimum balance required: 1 Ğ1 (0 ẐEN threshold) + payment amount
                        MIN_BALANCE=$(echo "scale=4; 1 + $TOTAL_PAYMENT" | bc -l)
                        
                        if [[ $(echo "$COINS >= $MIN_BALANCE" | bc -l) -eq 1 ]]; then
                            # Convert Ğ1 to ẐEN for display (1 Ğ1 = 10 ẐEN)
                            # Use makecoord to ensure proper formatting (e.g., 0.20 not .20)
                            Npaf_ZEN=$(makecoord $(echo "scale=2; $Npaf * 10" | bc -l))
                            TVA_ZEN=$(makecoord $(echo "scale=2; $TVA_AMOUNT * 10" | bc -l))
                            TOTAL_ZEN=$(makecoord $(echo "scale=2; $TOTAL_PAYMENT * 10" | bc -l))

                            log "INFO" "[7 DAYS CYCLE] $TODATE is NOSTR Card $NCARD ẐEN MULTIPASS PAYMENT ($COINS Ğ1 >= $MIN_BALANCE Ğ1 min) → $Npaf_ZEN ẐEN ($Npaf Ğ1) to CAPTAIN_DEDICATED — TVA=0"

                            # Ensure CAPTAIN_DEDICATED wallet exists (business wallet for rental collection)
                            if [[ ! -s ~/.zen/game/uplanet.captain.dunikey ]]; then
                                ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.captain.dunikey "${UPLANETNAME}.${CAPTAINEMAIL}" "${UPLANETNAME}.${CAPTAINEMAIL}"
                                chmod 600 ~/.zen/game/uplanet.captain.dunikey
                            fi

                            # Get CAPTAIN_DEDICATED wallet G1PUB (receives rental payments for cooperative distribution)
                            CAPTAIN_DEDICATED_G1PUB=$(cat ~/.zen/game/uplanet.captain.dunikey | grep "pub:" | cut -d ' ' -f 2)

                            # Ensure IMPOTS wallet exists before any payment
                            if [[ ! -s ~/.zen/game/uplanet.IMPOT.dunikey ]]; then
                                ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.IMPOT.dunikey "${UPLANETNAME}.IMPOT" "${UPLANETNAME}.IMPOT"
                                chmod 600 ~/.zen/game/uplanet.IMPOT.dunikey
                            fi

                            # Get IMPOTS wallet G1PUB
                            IMPOTS_G1PUB=$(cat ~/.zen/game/uplanet.IMPOT.dunikey |  grep "pub:" | cut -d ' ' -f 2)

                            # Main rental payment to CAPTAIN_DEDICATED (business wallet - HT amount only)
                            # This wallet collects rentals and serves as source for cooperative allocation
                            payment_result=$(${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/nostr/${PLAYER}/.secret.dunikey" "$Npaf" "${CAPTAIN_DEDICATED_G1PUB}" "UPLANET:${ORIGIN}:${IPFSNODEID: -12}:$YOUSER:NCARD:HT")
                            payment_success=$?

                            # TVA provision directly from MULTIPASS to IMPOTS (fiscally correct)
                            tva_success=1
                            if [[ $payment_success -eq 0 && $(echo "$TVA_AMOUNT > 0" | bc -l) -eq 1 && -n "$IMPOTS_G1PUB" ]]; then
                                tva_result=$(${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/nostr/${PLAYER}/.secret.dunikey" "$TVA_AMOUNT" "${IMPOTS_G1PUB}" "UPLANET:${ORIGIN}:${IPFSNODEID: -12}:$YOUSER:TVA")
                                tva_success=$?
                                if [[ $tva_success -eq 0 ]]; then
                                    log "INFO" "✅ TVA provision recorded directly from MULTIPASS for ${PLAYER} on $TODATE ($TVA_ZEN ẐEN = $TVA_AMOUNT Ğ1)"
                                    log_metric "TVA_PROVISION_SUCCESS" "$TVA_AMOUNT" "${PLAYER}"
                                else
                                    log "WARN" "❌ TVA provision failed for ${PLAYER} on $TODATE ($TVA_ZEN ẐEN = $TVA_AMOUNT Ğ1)"
                                    log_metric "TVA_PROVISION_FAILED" "$TVA_AMOUNT" "${PLAYER}"
                                fi
                            elif [[ $payment_success -ne 0 ]]; then
                                log "WARN" "⏭️ TVA provision skipped — main payment failed"
                            elif [[ -z "$IMPOTS_G1PUB" ]]; then
                                log "ERROR" "❌ IMPOTS wallet not found for TVA provision"
                            fi

                            # Check if payment succeeded (TVA always 0 now)
                            if [[ $payment_success -eq 0 ]]; then
                                # Record successful payment
                                echo "$TODATE" > "$last_payment_file"
                                log "INFO" "✅ Weekly payment recorded for ${PLAYER} on $TODATE ($Npaf_ZEN ẐEN = $Total_ZEN ẐEN)"
                                log_metric "PAYMENT_SUCCESS" "$Npaf" "${PLAYER}"
                                PAYMENTS_PROCESSED=$((PAYMENTS_PROCESSED + 1))

                                ####################################################################
                                ## PARRAIN 1% — versement si ZEN >= 100 et parrain enregistré
                                ZEN=${ZEN:-0}
                                REFERRER_FILE="${HOME}/.zen/game/nostr/${PLAYER}/REFERRER"
                                REFERRER_PAID_MARKER="${HOME}/.zen/game/nostr/${PLAYER}/.referrer_paid_${TODATE}"
                                if [[ -s "$REFERRER_FILE" && ! -f "$REFERRER_PAID_MARKER" && $(echo "$ZEN >= 100" | bc -l) -eq 1 ]]; then
                                    REFERRER=$(cat "$REFERRER_FILE")
                                    REFERRER_G1PUB=$(cat "${HOME}/.zen/game/nostr/${REFERRER}/G1PUBNOSTR" 2>/dev/null)
                                    if [[ -n "$REFERRER_G1PUB" ]]; then
                                        PARRAIN_AMOUNT=$(makecoord $(echo "scale=4; $Npaf * 0.01" | bc -l))
                                        # Vérifier que le solde restant le permet
                                        COINS_AFTER=$(echo "scale=4; $COINS - $Npaf" | bc -l)
                                        if [[ $(echo "$COINS_AFTER > $PARRAIN_AMOUNT" | bc -l) -eq 1 ]]; then
                                            parrain_result=$(${MY_PATH}/../tools/PAYforSURE.sh \
                                                "$HOME/.zen/game/nostr/${PLAYER}/.secret.dunikey" \
                                                "$PARRAIN_AMOUNT" "$REFERRER_G1PUB" \
                                                "UPLANET:${ORIGIN}:PARRAIN:${REFERRER}:1PCT")
                                            parrain_success=$?
                                            if [[ $parrain_success -eq 0 ]]; then
                                                touch "$REFERRER_PAID_MARKER"
                                                PARRAIN_ZEN=$(makecoord $(echo "scale=2; $PARRAIN_AMOUNT * 10" | bc -l))
                                                log "INFO" "🤝 Prime parrain versée : $PARRAIN_ZEN ẐEN ($PARRAIN_AMOUNT Ğ1) → ${REFERRER} pour ${PLAYER}"
                                                log_metric "PARRAIN_PAYMENT_SUCCESS" "$PARRAIN_AMOUNT" "${PLAYER}"
                                            else
                                                log "WARN" "⚠️ Prime parrain échouée pour ${PLAYER} → ${REFERRER}"
                                                log_metric "PARRAIN_PAYMENT_FAILED" "$PARRAIN_AMOUNT" "${PLAYER}"
                                            fi
                                        else
                                            log "DEBUG" "Prime parrain ignorée : solde insuffisant après paiement CAPTAIN"
                                        fi
                                    else
                                        log "WARN" "Parrain ${REFERRER} introuvable dans le réseau local (pas de G1PUBNOSTR)"
                                    fi
                                fi
                                ## FIN PARRAIN
                                ####################################################################

                                # Send success email notification
                                temp_email_file=$(mktemp)
                                cat > "$temp_email_file" <<OKHTML
<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8">
<style>
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;margin:0;padding:0;background:#e8f5e9;color:#1a2e1a}
.c{max-width:600px;margin:0 auto;background:white}
.h{background:linear-gradient(135deg,#2e7d32,#4caf50);color:white;padding:1.5rem;text-align:center}
.h .lbl{font-size:.8rem;opacity:.8;letter-spacing:2px;text-transform:uppercase;margin-bottom:.4rem}
.h h1{margin:0;font-size:1.3rem}
.ct{padding:1.5rem}
.card{background:#f8f9fa;border:1px solid #dee2e6;border-radius:8px;padding:1rem;margin:1rem 0;font-size:.9rem}
.card table{width:100%;border-collapse:collapse}
.card td{padding:.3rem .5rem;vertical-align:top}
.card td:first-child{font-weight:bold;color:#555;width:50%}
.tip{background:#e8f5e9;border-left:4px solid #2e7d32;border-radius:4px;padding:1rem;margin:1rem 0;font-size:.9rem}
p{line-height:1.6;margin:.4rem 0;font-size:.92rem}
small{color:#666;font-size:.8rem}
</style></head>
<body><div class="c">
<div class="h"><div class="lbl">✅ MULTIPASS actif</div><h1>Redevance hebdomadaire réglée</h1></div>
<div class="ct">
<div class="card"><table>
<tr><td>Montant prélevé</td><td><strong>${Npaf_ZEN} Ẑen</strong></td></tr>
<tr><td>Solde restant</td><td>${ZEN} Ẑen</td></tr>
<tr><td>Prochain paiement</td><td>${NEXT_PAYMENT_DATE}</td></tr>
</table></div>
<div class="tip">
<p>💡 Chaque like reçu sur vos posts Coracle = 1 Ẑen automatique dans votre portefeuille.</p>
</div>
<p style="text-align:center;margin-top:1.5rem"><small>UPlanet ORIGIN — support@qo-op.com</small></p>
</div></div></body></html>
OKHTML
                                ${MY_PATH}/../tools/mailjet.sh --channel milestones --template "$0" --expire 7d "${PLAYER}" "$temp_email_file" "✅ Redevance MULTIPASS réglée — $TODATE"
                                rm -f "$temp_email_file"
                                log "INFO" "Success email sent to ${PLAYER} for payment success"
                            else
                                # Payment failed - send error email
                                log "ERROR" "❌ MULTIPASS payment failed for ${PLAYER} on $TODATE ($Npaf_ZEN ẐEN = $Npaf Ğ1)"
                                log_metric "PAYMENT_FAILED" "$Npaf" "${PLAYER}"

                                # Send error email via mailjet
                                temp_email_file=$(mktemp)
                                cat > "$temp_email_file" <<ERRHTML
<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8">
<style>
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;margin:0;padding:0;background:#fff3e0;color:#1a1a2e}
.c{max-width:600px;margin:0 auto;background:white}
.h{background:linear-gradient(135deg,#e65c00,#f9a825);color:white;padding:1.5rem;text-align:center}
.h .lbl{font-size:.8rem;opacity:.8;letter-spacing:2px;text-transform:uppercase;margin-bottom:.4rem}
.h h1{margin:0;font-size:1.3rem}
.ct{padding:1.5rem}
.card{background:#f8f9fa;border:1px solid #dee2e6;border-radius:8px;padding:1rem;margin:1rem 0;font-size:.9rem}
.card table{width:100%;border-collapse:collapse}
.card td{padding:.3rem .5rem;vertical-align:top}
.card td:first-child{font-weight:bold;color:#555;width:50%}
.warn{background:#fff3e0;border-left:4px solid #e65c00;border-radius:4px;padding:1rem;margin:1rem 0;font-size:.9rem}
p{line-height:1.6;margin:.4rem 0;font-size:.92rem}
small{color:#666;font-size:.8rem}
</style></head>
<body><div class="c">
<div class="h"><div class="lbl">👑 Notification Capitaine</div><h1>⚠️ Échec paiement MULTIPASS</h1></div>
<div class="ct">
<div class="card"><table>
<tr><td>MULTIPASS</td><td><strong>${PLAYER}</strong></td></tr>
<tr><td>Date</td><td>${TODATE}</td></tr>
<tr><td>Ancienneté</td><td>${DIFF_DAYS} jours</td></tr>
<tr><td>Montant HT</td><td>${Npaf_ZEN} Ẑen</td></tr>
<tr><td>Montant TVA</td><td>${TVA_ZEN} Ẑen</td></tr>
<tr><td>Solde disponible</td><td>${ZEN} Ẑen</td></tr>
<tr><td>Paiement principal</td><td>$([ $payment_success -eq 0 ] && echo '✅ OK' || echo '❌ Échec')</td></tr>
<tr><td>Paiement TVA</td><td>$([ $tva_success -eq 0 ] && echo '✅ OK' || echo '❌ Échec')</td></tr>
</table></div>
<div class="warn">
<p>Le solde est insuffisant pour couvrir la redevance hebdomadaire (${Npaf_ZEN} + ${TVA_ZEN} Ẑen).</p>
<p>Si la situation n'est pas régularisée au prochain cycle (J+7), le MULTIPASS sera archivé automatiquement.</p>
<p><em>Les deux transactions (HT + TVA) doivent réussir pour la conformité fiscale coopérative.</em></p>
</div>
<p style="text-align:center;margin-top:1.5rem"><small>Astroport.ONE — support@qo-op.com</small></p>
</div></div></body></html>
ERRHTML
                                ${MY_PATH}/../tools/mailjet.sh --template "$0" --expire 7d "${CAPTAINEMAIL}" "$temp_email_file" "⚠️ Paiement MULTIPASS échoué — ${PLAYER} — $TODATE"
                                rm -f "$temp_email_file"
                                log "INFO" "Error email sent to ${CAPTAINEMAIL} for payment failure of ${PLAYER}"
                            fi
                        else
                            # Check if MULTIPASS is less than 7 days old (grace period)
                            if [[ $DIFF_DAYS -lt 7 ]]; then
                                log "INFO" "[7 DAYS CYCLE] NOSTR Card ($COINS G1) - Grace period for new MULTIPASS (${DIFF_DAYS} days old)"
                                continue
                            fi

                            # Validation OC obligatoire : le MULTIPASS est détruit si l'email
                            # n'est pas inscrit sur OpenCollective dans les 7 jours.
                            # G1PRIME est positionné par UPLANET.official.sh lors du traitement OC.
                            if [[ ! -s ~/.zen/game/nostr/${PLAYER}/G1PRIME ]] && \
                               [[ -z "$COINS" || "$COINS" == "0" || "$COINS" == "null" || \
                                  $(echo "${COINS:-0} <= 0" | bc -l 2>/dev/null) -eq 1 ]] && \
                               [[ $DIFF_DAYS -le 7 ]]; then
                                log "INFO" "[OC VALIDATION] MULTIPASS ${PLAYER} - inscription OpenCollective requise (J${DIFF_DAYS}/7)"
                                log "INFO" "             ➜ https://opencollective.com/monnaie-libre (même email)"
                                # Rappel J7 : dernier avertissement avant destruction au prochain cycle
                                if [[ $DIFF_DAYS -eq 7 && ! -s ~/.zen/game/nostr/${PLAYER}/.oc_reminder_sent ]]; then
                                    _send_player_email "multipass_oc_reminder_j7.html" \
                                        "⚠️ MULTIPASS : inscription OpenCollective requise — J7" \
                                        "${HOME}/.zen/game/nostr/${PLAYER}/.oc_reminder_sent"
                                    log "INFO" "OC reminder email sent to ${PLAYER} (J7 — dernier avertissement avant destruction)"
                                fi
                                continue
                            fi

                            log "WARN" "[7 DAYS CYCLE] NOSTR Card ($COINS G1) - insufficient funds! Need at least $MIN_BALANCE Ğ1. Destroying if not captain"
                            # Capitaine : immunisé contre l'insolvabilité, mais les autres sont supprimés
                            if [[ "${PLAYER}" != "${CAPTAINEMAIL}" ]]; then
                                log "INFO" "Triggering destruction for insolvent player: ${PLAYER}"
                                # Tentative de destruction propre (avec backup et cash back)
                                if ! ${MY_PATH}/../tools/nostr_DESTROY_TW.sh "${PLAYER}"; then
                                    log "ERROR" "Graceful destruction failed for ${PLAYER}. Forcing brutal removal."
                                    # Fallback : suppression physique si le script de destruction a planté
                                    rm -rf "${HOME}/.zen/game/nostr/${PLAYER}"
                                    rm -rf "${HOME}/.zen/game/players/${PLAYER}"
                                    ipfs key rm "${PLAYER}" 2>/dev/null
                                fi
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

        ## Helper: envoie un email U.SOCIETY depuis un template avec substitutions dynamiques
        _send_usociety_email() {
            local _tpl="$1" _subject="$2" _flag="${3:-}" _channel="${4:-usociety}"
            local _tmpf
            _tmpf=$(mktemp)
            sed -e "s~_OC_URL_SATELLITE_~${OC_URL_SATELLITE}~g" \
                -e "s~_OC_URL_CONSTELLATION_~${OC_URL_CONSTELLATION}~g" \
                -e "s~_NCARD_~${NCARD}~g" \
                -e "s~_ZCARD_~${ZCARD}~g" \
                -e "s~_DIFF_DAYS_~${DIFF_DAYS:-0}~g" \
                -e "s~_UENDDATE_~${UENDDATE:-}~g" \
                "${MY_PATH}/../templates/NOSTR/${_tpl}" > "$_tmpf"
            ${MY_PATH}/../tools/mailjet.sh \
                --channel "$_channel" \
                --template "${MY_PATH}/../templates/NOSTR/${_tpl}" \
                --expire 7d "${PLAYER}" "$_tmpf" "$_subject"
            rm -f "$_tmpf"
            [[ -n "$_flag" ]] && echo "${TODATE}" > "$_flag"
        }

        if [[ -z "$UDATE" ]]; then
            echo "### U SOCIETY FILE MISSING"
            echo "### REMOVING U SOCIETY STATUS"
            rm -f ~/.zen/game/players/${PLAYER}/U.SOCIETY
            rm -f ~/.zen/game/nostr/${PLAYER}/U.SOCIETY
            rm -f ~/.zen/game/players/${PLAYER}/U.SOCIETY.end
            rm -f ~/.zen/game/nostr/${PLAYER}/U.SOCIETY.end
        else
            echo "U SOCIETY REGISTRATION : $UDATE"

            ## Zine de bienvenue (envoyé une seule fois à la première détection)
            if [[ ! -s "${HOME}/.zen/game/nostr/${PLAYER}/.usociety_welcome_sent" ]]; then
                _welcome_tmp=$(mktemp)
                sed -e "s~_USPOT_~${uSPOT}~g" \
                    -e "s~_CORACLEURL_~${myCORACLE:-https://ipfs.copylaradio.com/ipns/coracle.copylaradio.com}~g" \
                    "${MY_PATH}/../templates/NOSTR/zine/zine_usociety_welcome.html" > "$_welcome_tmp"
                ${MY_PATH}/../tools/mailjet.sh \
                    --channel usociety \
                    --template "${MY_PATH}/../templates/NOSTR/zine/zine_usociety_welcome.html" \
                    --expire 7d "${PLAYER}" "$_welcome_tmp" "🌿 Bienvenue dans la coopérative UPlanet !"
                rm -f "$_welcome_tmp"
                echo "${TODATE}" > "${HOME}/.zen/game/nostr/${PLAYER}/.usociety_welcome_sent"
                log "INFO" "U.SOCIETY welcome Zine sent to ${PLAYER}"
            fi

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
                    
                    _send_usociety_email "usociety_expired.html" \
                        "🏛️ Votre parrainage U.SOCIETY a expiré"
                    log "INFO" "U.SOCIETY expiration email sent to ${PLAYER}"
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
                        if [[ $DIFF_DAYS -gt 20 && ! -s ~/.zen/game/nostr/${PLAYER}/.usociety_30day_warned ]]; then
                            _send_usociety_email "usociety_renewal.html" \
                                "🌿 Votre parrainage expire dans $DIFF_DAYS jours" \
                                "${HOME}/.zen/game/nostr/${PLAYER}/.usociety_30day_warned"
                            log "INFO" "U.SOCIETY 30-day warning email sent to ${PLAYER}"
                        fi
                        
                        # Send final warning if less than 7 days
                        if [[ $DIFF_DAYS -lt 7 && ! -s ~/.zen/game/nostr/${PLAYER}/.usociety_7day_warned ]]; then
                            _send_usociety_email "usociety_renewal_urgent.html" \
                                "🚨 URGENT — Parrainage expire dans $DIFF_DAYS jours" \
                                "${HOME}/.zen/game/nostr/${PLAYER}/.usociety_7day_warned"
                            log "INFO" "U.SOCIETY 7-day urgent warning email sent to ${PLAYER}"
                        fi
                    fi
                    fi
                fi
            fi
        fi
        unset -f _send_usociety_email
    fi

  ########################################################################

    ########################################################################
    echo ">>> CHECKING MULTIPASS ($COINS G1)"
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
        ## Use cached IPCity (Ville,Pays) for NOSTR profile city field
        [[ ! -s ~/.zen/IPCity ]] && my_IPCity > ~/.zen/IPCity
        city=$(cat ~/.zen/IPCity 2>/dev/null)
        [[ -z "$city" ]] && city="UPlanet ${ORIGIN}"
        description="💬 + ❤️ => Ẑen : ${uSPOT}/check_balance?g1pub=${PLAYER}"
        zavatar="/ipfs/"$(cat ${HOME}/.zen/game/nostr/${PLAYER}/MULTIPASS.QR.png.cid 2>/dev/null)
        ## ELSE ASTROPORT LOGO
        [[ $zavatar == "/ipfs/" ]] \
            && zavatar="/ipfs/QmbMndPqRHtrG2Wxtzv6eiShwj3XsKfverHEjXJicYMx8H/logo.png"

        ZENCARDG1=$(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null)
        G1PUBNOSTR=$(cat ${HOME}/.zen/game/nostr/${PLAYER}/G1PUBNOSTR)
        ## Derive SS58 addresses for Duniter v2s
        ## G1PUBNOSTR and ZENCARDG1 are already stored as SS58 by make_NOSTRCARD.sh/VISA.new.sh
        ## g1pub_to_ss58.py passes SS58 through unchanged (ensure_ss58); fallback guards against
        ## older versions of the script or unexpected errors.
        G1V2ADDRESS=""
        ZENCARDG1_V2=""
        if [[ -x "${MY_PATH}/../tools/g1pub_to_ss58.py" ]]; then
            G1V2ADDRESS=$(python3 "${MY_PATH}/../tools/g1pub_to_ss58.py" "$G1PUBNOSTR" 2>/dev/null)
            [[ -z "$G1V2ADDRESS" ]] && G1V2ADDRESS="$G1PUBNOSTR"
            [[ -n "$ZENCARDG1" ]] && ZENCARDG1_V2=$(python3 "${MY_PATH}/../tools/g1pub_to_ss58.py" "$ZENCARDG1" 2>/dev/null)
            [[ -n "$ZENCARDG1" && -z "$ZENCARDG1_V2" ]] && ZENCARDG1_V2="$ZENCARDG1"
        else
            G1V2ADDRESS="$G1PUBNOSTR"
            ZENCARDG1_V2="$ZENCARDG1"
        fi
        NODE_NOSTR_HEX=$(sed 's/.*HEX=\([^;]*\).*/\1/' ~/.zen/game/secret.nostr 2>/dev/null)
        ### SEND PROFILE TO NOSTR RELAYS
        SETUP_ARGS=(
            "$NSEC"
            "✌(◕‿-)✌ $title" "$G1PUBNOSTR"
            "$description"
            "$myIPFS/$zavatar"
            "$myIPFS/ipfs/QmX1TWhFZwVFBSPthw1Q3gW5rQc1Gc4qrSbKj4q1tXPicT/P2Pmesh.jpg"
            "" "$myIPFS${NOSTRNS}/${PLAYER}/APP/uDRIVE" "" "" "" ""
            "wss://relay.copylaradio.com" "$myRELAY"
            --city "$city"
            --ipfs_gw "$myIPFS"
            --zencard "$ZENCARDG1"
            --email "$PLAYER"
            --ipns_vault "${NOSTRNS}"
            --home_station "${IPFSNODEID}:${NODE_NOSTR_HEX}"
        )
        [[ -n "$G1V2ADDRESS" ]] && SETUP_ARGS+=(--g1v2 "$G1V2ADDRESS")
        [[ -n "$ZENCARDG1_V2" ]] && SETUP_ARGS+=(--zencard_v2 "$ZENCARDG1_V2")

        ${MY_PATH}/../tools/nostr_setup_profile.py \
            "${SETUP_ARGS[@]}" \
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
        if [[ -s ~/.zen/game/nostr/${PLAYER}/.secret.nostr ]]; then
            # Update email only during daily refresh to avoid excessive updates
            # But ensure it's done at least once per day
            if [[ "$REFRESH_REASON" == "daily_update" ]]; then
                _PLAYER_NSEC="${NSEC:-}"
                _PLAYER_NPUB="${NPUB:-}"
                NODE_NOSTR_HEX=$(sed 's/.*HEX=\([^;]*\).*/\1/' ~/.zen/game/secret.nostr 2>/dev/null)
                log "INFO" "Updating email+home_station in NOSTR profile for ${PLAYER} during daily refresh"
                ${MY_PATH}/../tools/nostr_update_profile.py \
                    "${PLAYER}" \
                    "wss://relay.copylaradio.com" "$myRELAY" \
                    --email "$PLAYER" \
                    --home_station "${IPFSNODEID}:${NODE_NOSTR_HEX}" \
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

        ######### RELAY LIST (kind 10002) — re-publish weekly ##############################
        ## Publié directement via nostr_node_intercom.py pour ne PAS écraser le kind 0
        ## (qui peut avoir été modifié par l'utilisateur via un client NOSTR externe).
        RELAY_SENTINEL="${HOME}/.zen/game/nostr/${PLAYER}/.relay_list_weekly"
        if [[ ! -f "$RELAY_SENTINEL" ]] || \
           [[ $(find "$RELAY_SENTINEL" -mtime +7 2>/dev/null | wc -l) -gt 0 ]]; then
            log "INFO" "⚙️  Weekly relay list (kind 10002) refresh for ${PLAYER}"
            _RELAY_NSEC=$(grep "^NSEC=" "${HOME}/.zen/game/nostr/${PLAYER}/.secret.nostr" 2>/dev/null | cut -d';' -f1 | cut -d= -f2)
            if [[ -n "$_RELAY_NSEC" ]]; then
                _RELAY_TAGS=$(python3 -c "import json; relays=['wss://relay.copylaradio.com','$myRELAY']; print(json.dumps([['r',r] for r in dict.fromkeys(relays)]))")
                python3 "${MY_PATH}/../tools/nostr_node_intercom.py" publish \
                    --nsec "$_RELAY_NSEC" \
                    --kind 10002 \
                    --tags "$_RELAY_TAGS" \
                    --content "" \
                    --relays "ws://localhost:7777" "wss://relay.copylaradio.com" \
                    2>/dev/null \
                    && log "INFO" "✅ kind 10002 re-publié pour ${PLAYER}" \
                    || log "WARN" "⚠️  kind 10002 publication échouée pour ${PLAYER}"
            else
                log "WARN" "⚠️  .secret.nostr absent — kind 10002 ignoré pour ${PLAYER}"
            fi
            touch "$RELAY_SENTINEL"
        fi

        ######### CAPTAIN FOLLOW (kind 3) — ensure & re-publish weekly ####################
        ## make_NOSTRCARD.sh publishes the CAPTAIN follow at creation time, but it may be
        ## lost (relay restart, network issue). Re-publish weekly via a sentinel file.
        ## Note: the relay write-policy plugin (filter/1.sh) automatically appends the
        ## geographic GeoKey to any kind 3 event → no explicit geokey follow needed here.
        FOLLOW_SENTINEL="${HOME}/.zen/game/nostr/${PLAYER}/.captain_follow_weekly"
        if [[ -n "$CAPTAINEMAIL" && "$CAPTAINEMAIL" != "$PLAYER" ]]; then
            CAPTAINHEX=$(cat "${HOME}/.zen/game/nostr/${CAPTAINEMAIL}/HEX" 2>/dev/null)
            if [[ -n "$CAPTAINHEX" ]]; then
                if [[ ! -f "$FOLLOW_SENTINEL" ]] || \
                   [[ $(find "$FOLLOW_SENTINEL" -mtime +7 2>/dev/null | wc -l) -gt 0 ]]; then
                    log "INFO" "👥 Ensuring ${PLAYER} follows CAPTAIN ${CAPTAINEMAIL}"
                    ${MY_PATH}/../tools/nostr_follow.sh \
                        "$NSEC" "$CAPTAINHEX" \
                        "$myRELAY" "wss://relay.copylaradio.com" 2>/dev/null \
                        && touch "$FOLLOW_SENTINEL" \
                        && log "INFO" "✅ Captain follow (kind 3) re-published for ${PLAYER}" \
                        || log "WARN" "⚠️  Failed to re-publish captain follow for ${PLAYER}"
                fi
            fi
        fi
        ########################################################################
        ## Create ZENCARD ONLY FOR UPlanet Zen #################################################
        ## CREATE UPlanet AstroID + ZenCard using EMAIL and GPS ##
        if [[ ! -d ~/.zen/game/players/${PLAYER} && -s ${HOME}/.zen/game/nostr/${PLAYER}/.secret.nostr ]]; then
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
    $(${MY_PATH}/../tools/search_for_this_email_in_nostr.sh ${PLAYER} | tail -n 1)
    echo "$source ORIGIN ($LAT $LON) : $HEX = $EMAIL"

        
    ########################################################################################

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
    echo "CONTROL UPLANET ZEN - NOSTR Card primal control"
    ${MY_PATH}/../tools/primal_wallet_control.sh \
        "${HOME}/.zen/game/nostr/${PLAYER}/.secret.dunikey" \
        "${G1PUBNOSTR}" \
        "${UPLANETNAME_G1}" \
        "${PLAYER}"

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

        ## DNSLink MULTIPASS subdomain : _dnslink.<YOUSER>.astroport.one → /ipns/$NOSTRNS
        OVH_TOOL="${MY_PATH}/../admin/system/ovh.me.sh"
        if [[ -x "$OVH_TOOL" ]]; then
            _nostrns_raw="${NOSTRNS#/ipns/}"
            "$OVH_TOOL" upsert "${YOUSER}" "/ipns/${_nostrns_raw}" 2>/dev/null || true
        fi

        # Record the last IPNS update time
        date +%s > ${HOME}/.zen/game/nostr/${PLAYER}/.last_ipns_update

        # Update .todate only for daily updates, not for new files
        if [[ "$REFRESH_REASON" == "daily_update" ]]; then
            echo "$TODATE" > ${HOME}/.zen/game/nostr/${PLAYER}/.todate
            echo "Daily refresh completed for ${PLAYER}"
            DAILY_UPDATES=$((DAILY_UPDATES + 1))

            # ── KIN Oracle — quotidien (newsletter Oracle personnalisée) ────────────
            # Envoyé UNE FOIS PAR JOUR par joueur local uniquement.
            # Élimine les doublons inter-machines de la constellation.
            _KIN_DAILY_FLAG="${HOME}/.zen/game/nostr/${PLAYER}/.kin_daily_${TODATE}"
            if [[ ! -f "$_KIN_DAILY_FLAG" && -x "${MY_PATH}/KIN.daily.sh" ]]; then
                log "INFO" "⚛ KIN Oracle quotidien → ${PLAYER}"
                "${MY_PATH}/KIN.daily.sh" --email "${PLAYER}" --force \
                    2>&1 | while IFS= read -r _kl; do log "DEBUG" "[KIN.daily] $_kl"; done
                touch "$_KIN_DAILY_FLAG"
            fi

            # ── KIN News — hebdomadaire (correspondances Oracle : quatuors, paires…) ─
            # Envoyé UNE FOIS PAR SEMAINE par joueur local.
            # --player filtre l'envoi au seul PLAYER ; les autres membres du group
            # reçoivent la notification de leur propre station.
            _KIN_WEEK="$(date -u +%Y)W$(date -u +%V)"
            _KIN_NEWS_FLAG="${HOME}/.zen/game/nostr/${PLAYER}/.kin_news_${_KIN_WEEK}"
            if [[ ! -f "$_KIN_NEWS_FLAG" && -x "${MY_PATH}/KIN.news.sh" ]]; then
                log "INFO" "🌀 KIN Correspondances hebdo → ${PLAYER}"
                "${MY_PATH}/KIN.news.sh" --player "${PLAYER}" --force \
                    2>&1 | while IFS= read -r _kl; do log "DEBUG" "[KIN.news] $_kl"; done
                touch "$_KIN_NEWS_FLAG"
            fi
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
        ########################################################################
        # Domain-specific scrapers (youtube.com.sh, leboncoin.fr.sh, etc.)
        # are handled for each user during their refresh cycle when uDRIVE sync occurs.
        # Cookie files are automatically detected as .DOMAIN.cookie files.
        # If a scraper doesn't exist for a domain, the user is notified by email.
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
                # Search in scrapers subdirectories first, then IA/ root (legacy)
                IA_DIR="${HOME}/.zen/Astroport.ONE/IA"
                DOMAIN_SCRIPT=""
                for _scraper_dir in "${IA_DIR}/scrapers"/*/; do
                    if [[ -f "${_scraper_dir}${DOMAIN}.sh" ]]; then
                        DOMAIN_SCRIPT="${_scraper_dir}${DOMAIN}.sh"
                        break
                    fi
                done
                [[ -z "$DOMAIN_SCRIPT" ]] && DOMAIN_SCRIPT="${IA_DIR}/${DOMAIN}.sh"
                
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
                    ) 200>&- &
                    DOMAIN_SYNC_PID=$!
                    
                    log "INFO" "${DOMAIN} scraper started for ${PLAYER} (PID: $DOMAIN_SYNC_PID, log: $DOMAIN_SYNC_LOG)"
                    log_metric "${DOMAIN}_SYNC_PID" "$DOMAIN_SYNC_PID" "${PLAYER}"
                    
                    # Mark as done for today
                    touch "$DOMAIN_SYNC_TODAY_FILE"
                    
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
                        # Send cookie domain notification via template
                        _send_player_email "multipass_cookie_unknown.html" \
                            "🍪 Cookie ${DOMAIN} — service non disponible" \
                            "$DOMAIN_NOTIF_FILE" "alerts"
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
unset -f _send_player_email

########################################################################
## NETTOYAGE DES COMPTES ROAMING EXPIRÉS (✈️)
## Les répertoires créés par 22242.sh pour les visiteurs sont éphémères.
## On supprime ceux dont aucun marker NIP-42 n'a été rafraîchi depuis 24h.
########################################################################
_ROAMING_TTL_MIN=1440  # 24h
for PLAYER in "${NOSTR[@]}"; do
    RDIR="$HOME/.zen/game/nostr/${PLAYER}"
    [[ ! -f "${RDIR}/.roaming" ]] && continue

    _ROAMING_AGE_H=$(( ($(date +%s) - $(stat -c %Y "${RDIR}/.roaming" 2>/dev/null || echo 0)) / 3600 ))
    log "INFO" "✈️ ROAMING CLEANUP: ${PLAYER} — inactif depuis ${_ROAMING_AGE_H}h → suppression"
    rm -rf "${RDIR}"
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
