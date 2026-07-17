#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ PLAYER.refresh.sh
#~ Refresh PLAYER data & wallet (Cooperative ZEN Card Management)
################################################################################
# Ce script gère le rafraîchissement des données des joueurs :
# 1. Vérifie et met à jour les données des joueurs
# 2. Gère les paiements des cartes ZEN (coopérative)
# 3. Vérifie le solde 1Ğ1 des ZEN Card (0 ẐEN normal)
# 4. Gère la logique U.SOCIETY pour les paiements de loyer
# 5. Délègue la gestion TiddlyWiki à TW.refresh.sh
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh"
# Load cooperative config from DID NOSTR (shared across swarm)
. "${MY_PATH}/../tools/cooperative_config.sh" 2>/dev/null && coop_load_env_vars 2>/dev/null || true
## Protection contre les exécutions concurrentes (cron + manuel simultanés)
exec 200>"/tmp/player_refresh.lock"
flock -n 200 || { echo "PLAYER.refresh.sh déjà en cours — exit"; exit 0; }
################################################################################
## Publish All PLAYER TW,
# Run TAG subprocess: tube, voeu
############################################
echo "## RUNNING PLAYER.refresh

        _..._
      .'     '.      _
     /    .-°°-\   _/ \\ Ẑen
   .-|   /:.   |  |   |
   |  \  |:.   /.-'-./
   | .-'-;:__.'    =/
   .'=  A=|STRO _.='
  /   _.  |    ;
 ;-.-'|    \   |
/   | \    _\  _\\
"

PLAYERONE="$1"
# [[ $isLAN ]] && PLAYERONE=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
[[ ! ${PLAYERONE} ]] && PLAYERONE=($(ls -t ~/.zen/game/players/  | grep "@" 2>/dev/null))

echo "FOUND ${#PLAYERONE[@]} ASTRONAUTS : ${PLAYERONE[@]}"

## Dispatch parallèle quand ASTRO_PARALLEL_REFRESH > 1 (appel complet, sans $1)
_PARALLEL="${ASTRO_PARALLEL_REFRESH:-1}"
if [[ -z "$1" && "$_PARALLEL" -gt 1 && "${#PLAYERONE[@]}" -gt 1 ]]; then
    printf '%s\n' "${PLAYERONE[@]}" | xargs -P "$_PARALLEL" -I{} bash "$0" {}
    exit $?
fi

CURRENT=$(readlink ~/.zen/game/players/.current | rev | cut -d '/' -f 1 | rev) ## ALSO in CAPTAINEMAIL

echo "RENEWING LOCAL UPLANET REPOSITORY (CAPTAIN=${CURRENT})
 ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_*.?_*.?/_*.??_*.??"


## RUNING FOR ALL LOCAL PLAYERS
for PLAYER in ${PLAYERONE[@]}; do
    [[ ! -d ~/.zen/game/players/${PLAYER:-undefined} ]] && echo "BAD ${PLAYERONE}" && continue
    [[ ! $(echo "${PLAYER}" | grep '@') ]] && continue

    start=`date +%s`
    # CLEAN LOST ACCOUNT
    [[ ! -s ~/.zen/game/players/${PLAYER}/secret.dunikey ]] \
        && rm -Rf ~/.zen/game/players/${PLAYER} \
        && echo "WARNING - ERASE ${PLAYER} - BADLY PLUGGED" \
        && continue

    YOUSER=$($MY_PATH/../tools/clyuseryomail.sh "${PLAYER}")
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    mkdir -p ~/.zen/tmp/${MOATS}
    echo "##### ${YOUSER} ################################ ~/.zen/tmp/${MOATS}"
    echo "##################################################################"
    echo ">>>>> PLAYER : ${PLAYER} >>>>>>>>>>>>> REFRESHING TW ?! "
    echo "################################################ $(date)"
    PSEUDO=$(cat ~/.zen/game/players/${PLAYER}/.pseudo 2>/dev/null)
    ASTRONS=$(cat ~/.zen/game/players/${PLAYER}/.playerns 2>/dev/null)
    # Get PLAYER MULTIPASS + ZenCard wallets in parallel
    G1PUBNOSTR=$(cat ~/.zen/game/nostr/${PLAYER}/G1PUBNOSTR 2>/dev/null)
    ZENCARD_G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null)
    $MY_PATH/../tools/G1check.sh ${G1PUBNOSTR} > ~/.zen/tmp/${MOATS}/${PLAYER}.G1check 2>&1 &
    [[ -n "$ZENCARD_G1PUB" ]] && $MY_PATH/../tools/G1check.sh ${ZENCARD_G1PUB} > ~/.zen/tmp/${MOATS}/${PLAYER}.ZENCARD.G1check 2>&1 &
    wait
    cat ~/.zen/tmp/${MOATS}/${PLAYER}.G1check ###DEBUG MODE
    COINS=$(cat ~/.zen/tmp/${MOATS}/${PLAYER}.G1check | tail -n 1)
    ZEN=$(echo "scale=1; ($COINS - 1) * 10" | bc)
    echo "+++ MULTIPASS WALLET BALANCE _ $COINS (G1) _ / $ZEN ZEN /"

    ######################################################################################
    ######## COOPERATIVE ZEN CARD MANAGEMENT
    ######################################################################################
    ## Helper: prepare email template with OC URLs and cost amounts injected
    ## (NCARD, ZCARD, OC_URL_SATELLITE, OC_URL_CONSTELLATION définis dans tools/my.sh)
    _prepare_email_template() {
        local tpl="$1"
        local tmp_email=$(mktemp)
        sed -e "s~_OC_URL_SATELLITE_~${OC_URL_SATELLITE}~g" \
            -e "s~_OC_URL_CONSTELLATION_~${OC_URL_CONSTELLATION}~g" \
            -e "s~_NCARD_~${NCARD}~g" \
            -e "s~_ZCARD_~${ZCARD}~g" \
            -e "s~_DIFF_DAYS_~${DAYS_LEFT:-0}~g" \
            -e "s~_UENDDATE_~${USOCIETY_END:-}~g" \
            "$tpl" > "$tmp_email"
        echo "$tmp_email"
    }
    ## ── RESET BIRTHDATE à chaque itération (évite la contamination inter-joueurs) ──
    unset BIRTHDATE
    BIRTHDATE=$(cat ~/.zen/game/nostr/${PLAYER}/TODATE 2>/dev/null)
    [[ -z ${BIRTHDATE} ]] \
        && BIRTHDATE="$TODATE" \
        && echo "$TODATE" > ~/.zen/game/nostr/${PLAYER}/TODATE \
        && echo "$TODATE" > ~/.zen/game/nostr/${PLAYER}/.account_created ## INIT BIRTHDATE

    ## ── Calcul de l'âge du compte en jours (variable days) ─────────────────────
    ## Utilisé pour le dispatch des ZINEs gamifiés (Jour 0 à Jour 7)
    if [[ -n "${BIRTHDATE}" && -n "${TODATE}" ]]; then
        _BIRTH_SEC=$(date -d "${BIRTHDATE}" +%s 2>/dev/null || date +%s)
        _TODAY_SEC=$(date -d "${TODATE}" +%s 2>/dev/null || date +%s)
        days=$(( (_TODAY_SEC - _BIRTH_SEC) / 86400 ))
    else
        days=0
    fi
    echo "🗓️  Compte ${PLAYER} : ${days} jours (BIRTHDATE=${BIRTHDATE})"
    ####################################################################

    # Check ZEN Card balance (should be 1Ğ1 = 0 ẐEN for cooperative members)
    if [[ -n "$ZENCARD_G1PUB" ]]; then
        # Publish ZENCard _g1pub (used by tools/G1zencard_history.sh)
        [[ ! -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/_g1pub ]] \
            && echo "$ZENCARD_G1PUB" > ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/_g1pub

        echo "🔍 Checking ZEN Card balance for cooperative member..."
        ZENCARD_COINS=$(cat ~/.zen/tmp/${MOATS}/${PLAYER}.ZENCARD.G1check | tail -n 1)
        ZENCARD_ZEN=$(echo "scale=1; ($ZENCARD_COINS - 1) * 10" | bc)
        echo "ZEN Card balance: $ZENCARD_COINS Ğ1 ($ZENCARD_ZEN ẐEN)"

        ## DÉTECTION ET CORRECTION DES ZEN CARDS EXCÉDENTAIRES
        ## La ZEN Card doit rester à 1 Ğ1 (= 0 ẐEN excédent) après distribution 3x1/3.
        ## Si UPLANET.official.sh a alimenté la ZEN Card sans que la redistribution 3x1/3
        ## n'ait abouti, le solde résiduel est envoyé vers CASH (TREASURY) comme correction.
        if [[ -n "$ZENCARD_COINS" ]] && [[ $(echo "${ZENCARD_COINS:-0} > 1" | bc -l 2>/dev/null) -eq 1 ]]; then
            ZENCARD_EXCESS_G1=$(echo "scale=2; $ZENCARD_COINS - 1" | bc)
            ZENCARD_EXCESS_ZEN=$(echo "scale=1; $ZENCARD_EXCESS_G1 * 10" | bc)
            echo "⚠️  ZEN Card excess detected: ${ZENCARD_EXCESS_ZEN} ẐEN (${ZENCARD_EXCESS_G1} Ğ1) for ${PLAYER}"
            echo "💸 Sending ZEN Card excess to CASH (TREASURY)..."

            ZENCARD_DUNIKEY="$HOME/.zen/game/players/${PLAYER}/secret.dunikey"
            CASH_DUNIKEY="$HOME/.zen/game/uplanet.CASH.dunikey"

            if [[ -s "$ZENCARD_DUNIKEY" ]] && [[ -s "$CASH_DUNIKEY" ]]; then
                CASH_G1PUB=$(grep "pub:" "$CASH_DUNIKEY" | cut -d ' ' -f 2)
                if [[ -n "$CASH_G1PUB" ]]; then
                    ${MY_PATH}/../tools/PAYforSURE.sh \
                        "$ZENCARD_DUNIKEY" \
                        "$ZENCARD_EXCESS_G1" \
                        "$CASH_G1PUB" \
                        "UPLANET:${UPLANETG1PUB:0:8}:TREASURY:${PLAYER}:ZENCARD_EXCESS:${IPFSNODEID}"
                    _drain_exit=$?
                    if [[ $_drain_exit -eq 0 ]]; then
                        echo "✅ ZEN Card excess drained: ${ZENCARD_EXCESS_G1} Ğ1 (${ZENCARD_EXCESS_ZEN} ẐEN) → CASH/TREASURY"
                    else
                        echo "❌ Failed to drain ZEN Card excess to CASH/TREASURY (exit: $_drain_exit)"
                    fi
                else
                    echo "⚠️  CASH wallet G1PUB not found — ZEN Card excess NOT drained"
                fi
            elif [[ ! -s "$ZENCARD_DUNIKEY" ]]; then
                echo "⚠️  ZEN Card dunikey not found (${ZENCARD_DUNIKEY}) — excess NOT drained"
            else
                echo "⚠️  CASH dunikey not found (${CASH_DUNIKEY}) — ZEN Card excess NOT drained"
            fi
        fi
    fi

    # U.SOCIETY logic for rent payments
    _USOCIETY_ACTIVE=false
    if [[ -s ~/.zen/game/players/${PLAYER}/U.SOCIETY ]]; then
        ## U SOCIETY MEMBER - Check if U.SOCIETY.end exists and is not reached
        UDATE=$(cat ~/.zen/game/players/${PLAYER}/U.SOCIETY)
        echo "U SOCIETY REGISTRATION : $UDATE"
        
        # Check if U.SOCIETY.end exists
        if [[ -s ~/.zen/game/players/${PLAYER}/U.SOCIETY.end ]]; then
            USOCIETY_END=$(cat ~/.zen/game/players/${PLAYER}/U.SOCIETY.end)

            # U.SOCIETY.end format is YYYY-MM-DD (écrit par tools/G1society.sh) : comparer
            # en secondes epoch directement, pas en chaîne (l'ancienne comparaison de
            # chaînes "$CURRENT_DATE" < "$USOCIETY_END" supposait à tort un format
            # YYYYMMDDHHMMSSNNNN et était TOUJOURS fausse, ce qui faisait passer tous
            # les membres U.SOCIETY actifs pour expirés dès le premier cycle).
            CURRENT_SECONDS=$(date -u +%s)
            END_SECONDS=$(date -d "$USOCIETY_END" +%s 2>/dev/null || echo "$CURRENT_SECONDS")
            DAYS_LEFT=$(( (END_SECONDS - CURRENT_SECONDS) / 86400 ))

            if [[ $END_SECONDS -gt $CURRENT_SECONDS ]]; then
                _USOCIETY_ACTIVE=true
                echo "✅ U.SOCIETY membership active until $USOCIETY_END ($DAYS_LEFT days left)"

                ## RENEWAL REMINDERS (30 days, 7 days before expiration)
                REMINDER_FILE="${HOME}/.zen/game/players/${PLAYER}/.usociety_reminder"
                LAST_REMINDER=$(cat "$REMINDER_FILE" 2>/dev/null || echo "0")

                if [[ $DAYS_LEFT -le 30 && $DAYS_LEFT -gt 7 && "$LAST_REMINDER" != "30" ]]; then
                    echo "📬 Sending 30-day renewal reminder to ${PLAYER}"
                    _tpl=$(_prepare_email_template "${MY_PATH}/../templates/NOSTR/usociety_renewal.html")
                    ${MY_PATH}/../tools/mailjet.sh --channel usociety --template "${MY_PATH}/../templates/NOSTR/usociety_renewal.html" --expire 7d "${PLAYER}" $_tpl \
                        "Votre parrainage expire dans ${DAYS_LEFT} jours"
                    rm -f "$_tpl"
                    echo "30" > "$REMINDER_FILE"
                elif [[ $DAYS_LEFT -le 7 && $DAYS_LEFT -gt 0 && "$LAST_REMINDER" != "7" ]]; then
                    echo "📬 Sending 7-day URGENT renewal reminder to ${PLAYER}"
                    _tpl=$(_prepare_email_template "${MY_PATH}/../templates/NOSTR/usociety_renewal_urgent.html")
                    ${MY_PATH}/../tools/mailjet.sh --channel usociety --template "${MY_PATH}/../templates/NOSTR/usociety_renewal_urgent.html" --expire 3d "${PLAYER}" $_tpl \
                        "URGENT : Parrainage expire dans ${DAYS_LEFT} jours !"
                    rm -f "$_tpl"
                    echo "7" > "$REMINDER_FILE"
                fi
            else
                echo "⚠️  U.SOCIETY membership expired on $USOCIETY_END - Rent payment required"
                # Send expiration notice (once per week max)
                EXPIRED_NOTICE="${HOME}/.zen/game/players/${PLAYER}/.usociety_expired_notice"
                LAST_NOTICE=$(cat "$EXPIRED_NOTICE" 2>/dev/null || echo "0")
                NOTICE_AGE=$(( CURRENT_SECONDS - LAST_NOTICE ))
                if [[ $NOTICE_AGE -gt 604800 ]]; then  # 7 days in seconds
                    echo "📬 Sending expiration notice to ${PLAYER} (balance: $ZEN ẐEN)"
                    _tpl=$(_prepare_email_template "${MY_PATH}/../templates/NOSTR/usociety_expired.html")
                    ${MY_PATH}/../tools/mailjet.sh --channel usociety --template "${MY_PATH}/../templates/NOSTR/usociety_expired.html" --expire 7d "${PLAYER}" $_tpl \
                        "Parrainage expire ! Solde : ${ZEN} ẐEN"
                    rm -f "$_tpl"
                    echo "$CURRENT_SECONDS" > "$EXPIRED_NOTICE"
                fi
                # Clean reminder file for next cycle
                rm -f "${HOME}/.zen/game/players/${PLAYER}/.usociety_reminder"
                # Fall through to rent payment logic
            fi
        else
            _USOCIETY_ACTIVE=true
            echo "✅ U.SOCIETY membership active (no end date) - No rent payment required"
        fi
    fi
    if [[ "$_USOCIETY_ACTIVE" != "true" ]]; then
        ## NON-U.SOCIETY OR EXPIRED U.SOCIETY - EVERY 7 DAYS PAY CAPTAIN VIA MULTIPASS
        echo "🏠 Non-U.SOCIETY or expired U.SOCIETY member - Weekly rent payment required via MULTIPASS"
        TODATE_SECONDS=$(date -d "$TODATE" +%s 2>/dev/null || date +%s)
        BIRTHDATE_SECONDS=$(date -d "$BIRTHDATE" +%s 2>/dev/null || echo "$TODATE_SECONDS")
        # Calculate the difference in days
        DIFF_DAYS=$(( (TODATE_SECONDS - BIRTHDATE_SECONDS) / 86400 ))
        DAYS_UNTIL_NEXT_PAYMENT=$(( 7 - (DIFF_DAYS % 7) ))
        echo "Next payment in $DAYS_UNTIL_NEXT_PAYMENT days"

        # Grace period CAPITAINE : jamais UNPLUG (U.SOCIETY permanent, même à 0Ğ1)
        if [[ "${PLAYER}" == "${CAPTAINEMAIL}" ]]; then
            echo "👑 CAPTAIN ${PLAYER} — ZEN Card protégée (pas d'UNPLUG)"
            DIFF_DAYS=999  # Force skip du cycle de paiement
        fi

        Npaf=$(makecoord $(echo "$NCARD / 10" | bc -l))
        Gpaf=$(makecoord $(echo "$ZCARD / 10" | bc -l))
        # Valeur par défaut pour éviter un crash bc si COINS est vide
        COINS=${COINS:-0}
        Gpaf=${Gpaf:-0}
        Npaf=${Npaf:-0}
        # Check if the difference is a multiple of 7
        if [ $((DIFF_DAYS % 7)) -eq 0 ]; then
            if [[ $(echo "$COINS > $Gpaf + $Npaf" | bc -l) -eq 1 && ${PLAYER} != ${CAPTAINEMAIL} ]]; then
                ## Pay ZCARD to CAPTAIN with TVA provision
                echo "[7 DAYS CYCLE] $TODATE MULTIPASS is paying ZENCARD access $ZCARD Ẑ to CAPTAIN and $NCARD ẐEN to own MULTIPASS."

                # Calculate TVA provision (20% of ZENCard payment)
                [[ -z $TVA_RATE ]] && TVA_RATE=0
                TVA_AMOUNT=$(echo "scale=4; $Gpaf * $TVA_RATE / 100" | bc -l)
                TVA_AMOUNT=$(makecoord $TVA_AMOUNT)
                # Conversion Ğ1 -> Ẑen (1 Ğ1 = 10 Ẑen) pour affichage email
                Gpaf_ZEN=$(makecoord $(echo "scale=1; $Gpaf * 10" | bc -l))
                TVA_ZEN=$(makecoord $(echo "scale=1; $TVA_AMOUNT * 10" | bc -l))

                echo "[7 DAYS CYCLE] ZENCard payment - Direct TVA split: $Gpaf ẐEN to CAPTAIN + $TVA_AMOUNT ẐEN to IMPOTS"

                # Ensure IMPOTS wallet exists before any payment
                if [[ ! -s ~/.zen/game/uplanet.IMPOT.dunikey ]]; then
                    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.IMPOT.dunikey "${UPLANETNAME}.IMPOT" "${UPLANETNAME}.IMPOT"
                    chmod 600 ~/.zen/game/uplanet.IMPOT.dunikey
                fi

                # Get IMPOTS wallet G1PUB
                IMPOTS_G1PUB=$(cat $HOME/.zen/game/uplanet.IMPOT.dunikey 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)

                # Ensure CAPTAIN_DEDICATED wallet exists (business wallet for rental collection)
                if [[ ! -s ~/.zen/game/uplanet.captain.dunikey ]]; then
                    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.captain.dunikey "${UPLANETNAME}.${CAPTAINEMAIL}" "${UPLANETNAME}.${CAPTAINEMAIL}"
                    chmod 600 ~/.zen/game/uplanet.captain.dunikey
                fi
                CAPTAIN_DEDICATED_G1PUB=$(cat ~/.zen/game/uplanet.captain.dunikey | grep "pub:" | cut -d ' ' -f 2)

                # Main ZENCard payment to CAPTAIN_DEDICATED (HT amount — cooperative wallet)
                payment_result=$(${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/nostr/${PLAYER}/.secret.dunikey" "$Gpaf" "${CAPTAIN_DEDICATED_G1PUB}" "UPLANET:${UPLANETG1PUB:0:8}:${YOUSER}:ZCARD:HT" 2>/dev/null)
                payment_success=$?

                # TVA provision directly from PLAYER to IMPOTS (fiscally correct)
                tva_success=0
                if [[ $payment_success -eq 0 && $(echo "$TVA_AMOUNT > 0" | bc -l) -eq 1 && -n "$IMPOTS_G1PUB" ]]; then
                    tva_result=$(${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/nostr/${PLAYER}/.secret.dunikey" "$TVA_AMOUNT" "${IMPOTS_G1PUB}" "UPLANET:${UPLANETG1PUB:0:8}:${YOUSER}:TVA" 2>/dev/null)
                    tva_success=$?
                    if [[ $tva_success -eq 0 ]]; then
                        echo "✅ TVA provision recorded directly from ZENCard for ${PLAYER} on $TODATE ($TVA_AMOUNT ẐEN)"
                    else
                        echo "❌ TVA provision failed for ${PLAYER} on $TODATE ($TVA_AMOUNT ẐEN)"
                    fi
                    else
                        echo "❌ IMPOTS wallet not found for TVA provision"
                fi

                # Check if both payments succeeded
                if [[ $payment_success -eq 0 && ($tva_success -eq 0 || $(echo "$TVA_AMOUNT == 0" | bc -l) -eq 1) ]]; then
                    TOTAL_ZEN=$(echo "scale=1; ($Gpaf + $TVA_AMOUNT) * 10" | bc -l)
                    echo "✅ Weekly ZENCard payment recorded for ${PLAYER} on $TODATE ($Gpaf_ZEN ẐEN HT + $TVA_ZEN ẐEN TVA = $TOTAL_ZEN ẐEN TTC) - Fiscally compliant split"
                else
                    # Payment failed - send error email
                    if [[ $payment_success -ne 0 ]]; then
                        echo "❌ Main ZENCard payment failed for ${PLAYER} on $TODATE ($Gpaf_ZEN ẐEN = $Gpaf Ğ1)"
                    fi
                    if [[ $tva_success -ne 0 && $(echo "$TVA_AMOUNT > 0" | bc -l) -eq 1 ]]; then
                        echo "❌ TVA provision failed for ${PLAYER} on $TODATE ($TVA_AMOUNT ẐEN)"
                    fi

                    # Send error email via mailjet
                    _pay_ok="$([ $payment_success -eq 0 ] && echo "✅ OK" || echo "❌ Échec")"
                    _tva_ok="$([ $tva_success -eq 0 ] && echo "✅ OK" || echo "❌ Échec")"
                    _tmpf=$(mktemp)
                    sed -e "s~_PLAYER_~${PLAYER}~g" \
                        -e "s~_TODATE_~${TODATE}~g" \
                        -e "s~_GPAF_ZEN_~${Gpaf_ZEN:-0}~g" \
                        -e "s~_TVA_AMOUNT_~${TVA_ZEN:-0}~g" \
                        -e "s~_PAYMENT_OK_~${_pay_ok}~g" \
                        -e "s~_TVA_OK_~${_tva_ok}~g" \
                        -e "s~_COINS_~${COINS:-0}~g" \
                        -e "s~_ZEN_~${ZEN:-0}~g" \
                        "${MY_PATH}/../templates/NOSTR/zencard_payment_error.html" > "$_tmpf"
                    ${MY_PATH}/../tools/mailjet.sh --channel alerts --template "${MY_PATH}/../templates/NOSTR/zencard_payment_error.html" \
                        --expire 48h "${PLAYER}" "$_tmpf" "❌ Erreur paiement ZEN Card — $TODATE"
                    rm -f "$_tmpf"
                    echo "Error email sent to ${PLAYER} for payment failure"
                fi
            else
                # Grace period : primo TX différée — ZEN Card non encore activée
                # Si G1PRIME absent sur le MULTIPASS ET solde == 0, l'utilisateur n'a pas encore
                # reçu de virement officiel. On lui donne 7 jours supplémentaires.
                MULTIPASS_G1PRIME="${HOME}/.zen/game/nostr/${PLAYER}/G1PRIME"
                ZENCARD_COINS_CHECK="${COINS:-0}"
                if [[ ! -s "$MULTIPASS_G1PRIME" ]] && \
                   [[ -z "$ZENCARD_COINS_CHECK" || "$ZENCARD_COINS_CHECK" == "0" || \
                      $(echo "${ZENCARD_COINS_CHECK:-0} <= 1" | bc -l 2>/dev/null) -eq 1 ]]; then
                    echo "⏳ [GRACE PERIOD] ZEN Card ${PLAYER} — primo TX différée, wallet en attente d'activation (${DIFF_DAYS} jours)"
                    echo "   Pour activer : UPLANET.official.sh -s ${PLAYER} -t satellite -m 50"
                elif [[ "${PLAYER}" != "${CAPTAINEMAIL}" ]]; then
                    echo "[7 DAYS CYCLE] ZENCARD ($COINS G1 / $ZEN ZEN) UNPLUG !!"
                    _tpl=$(_prepare_email_template "${MY_PATH}/../templates/NOSTR/zencard_insufficient.html")
                    $MY_PATH/../tools/mailjet.sh --channel alerts --template "${MY_PATH}/../templates/NOSTR/zencard_insufficient.html" --expire 7d "${PLAYER}" $_tpl \
                        "Solde insuffisant (${ZEN} ZEN) - ZEN Card desactivee"
                    rm -f "$_tpl"
                    ${MY_PATH}/PLAYER.unplug.sh ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html ${PLAYER} "ALL"
                fi
            fi
        fi
    fi



    ########################
    ## SEND TODAY ZINE
    #### Captain gets captain-specific ZINE, others get regular day ZINE
    IS_CAPTAIN=false
    [[ "${PLAYER}" == "${CAPTAINEMAIL}" ]] && IS_CAPTAIN=true
    [[ "${CURRENT}" == "${PLAYER}" && -z "${CAPTAINEMAIL}" ]] && IS_CAPTAIN=true

    ## Detect ORIGIN mode
    ORIGIN_KEY="0000000000000000000000000000000000000000000000000000000000000000"
    IS_ORIGIN=false
    [[ "${UPLANETNAME}" == "${ORIGIN_KEY}" || -z "${UPLANETNAME}" ]] && IS_ORIGIN=true

    if [[ "$IS_CAPTAIN" == "true" ]]; then
        ## ORIGIN captain: try origin-specific variant first
        if [[ "$IS_ORIGIN" == "true" ]]; then
            TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day${days}/captain.origin.${lang}.html"
            [[ ! -s ${TODAYZINE} ]] && TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day${days}/captain.origin.html"
        fi
        ## Captain ZINE: try captain-specific, then day_/captain.html, then regular
        [[ ! -s ${TODAYZINE} ]] && TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day${days}/captain.${lang}.html"
        [[ ! -s ${TODAYZINE} ]] && TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day${days}/captain.html"
        [[ ! -s ${TODAYZINE} ]] && TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day_/captain.html"
        echo "CAPTAIN ZINE ($([[ $IS_ORIGIN == true ]] && echo 'ORIGIN' || echo 'ZEN')): ${TODAYZINE}"
    elif [[ "$_USOCIETY_ACTIVE" == "true" ]]; then
        ## ── U.SOCIETY / Membres DRAGON ─────────────────────────────────────────
        ## Pas de loyer hebdomadaire. ZINE coopératif avec missions et gouvernance.
        TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day${days}/usociety.html"
        [[ ! -s ${TODAYZINE} ]] && TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day${days}/index.${lang}.html"
        [[ ! -s ${TODAYZINE} ]] && TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day${days}/index.html"
        [[ ! -s ${TODAYZINE} ]] && TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day_/usociety.html"
        [[ ! -s ${TODAYZINE} ]] && TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day_/multipass.html"
        echo "U.SOCIETY/DRAGON ZINE: ${TODAYZINE}"
    elif [[ "$IS_ORIGIN" == "true" ]]; then
        ## ── ORIGIN / Parcours Initiatique MULTIPASS ────────────────────────────
        ## Académie : gamification jour 0 → jour 7 → invitation DRAGON
        TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day${days}/multipass.html"
        [[ ! -s ${TODAYZINE} ]] && TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day${days}/index.${lang}.html"
        [[ ! -s ${TODAYZINE} ]] && TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day${days}/index.html"
        [[ ! -s ${TODAYZINE} ]] && TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day_/multipass.html"
        echo "ORIGIN MULTIPASS ZINE: ${TODAYZINE}"
    else
        ## ── ZENCard abonné (réseau ẐEN, sans U.SOCIETY) ─────────────────────────
        ## Service 128Go + NextCloud + Désenvoutement smartphone. Loyer 4+1 Zen/sem.
        TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day${days}/zencard.html"
        [[ ! -s ${TODAYZINE} ]] && TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day${days}/index.${lang}.html"
        [[ ! -s ${TODAYZINE} ]] && TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day${days}/index.html"
        [[ ! -s ${TODAYZINE} ]] && TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day_/zencard.html"
        [[ ! -s ${TODAYZINE} ]] && TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day_/multipass.html"
        echo "ZENCARD ZINE: ${TODAYZINE}"
    fi

    ## ── Logique d'envoi ────────────────────────────────────────────────────────
    ## • Jours 0-7    : onboarding géré par NOSTRCARD.refresh.sh (Zines J1-J6)
    ## • Jours 7+     : bulletin hebdomadaire Capitaine, U.SOCIETY et MULTIPASS
    ##                  (multiples de 7 : jours 14, 21, 28...)
    _SEND_ZINE=false
    if [[ "$IS_CAPTAIN" == "true" && $(( days % 7 )) -eq 0 ]]; then
        _SEND_ZINE=true   ## Bulletin hebdo Capitaine (jours 14, 21, 28...)
        ## En bulletin hebdo, utiliser day_/captain.html en priorité
        TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day_/captain.html"
    elif [[ "$_USOCIETY_ACTIVE" == "true" && $(( days % 7 )) -eq 0 ]]; then
        _SEND_ZINE=true   ## Bulletin hebdo U.SOCIETY/DRAGON
        TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day_/usociety.html"
        [[ ! -s ${TODAYZINE} ]] && TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day_/multipass.html"
    elif [[ $(( days % 14 )) -eq 0 ]]; then
        ## Bulletin bimensuel MULTIPASS (jours 14, 28, 42...)
        ## Rappel de l'Appel du DRAGON et de l'état du wallet — maintient l'engagement
        _SEND_ZINE=true
        TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day_/multipass.html"
    fi

    if [[ -s ${TODAYZINE} && "$_SEND_ZINE" == "true" ]]; then
        echo "SENDING TODAYZINE DAY ${days} + mailjet TW import "

        ## Derive variables available in TW.refresh context
        [[ -z "$UPLANETG1PUB" ]] && UPLANETG1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${UPLANETNAME}" "${UPLANETNAME}" 2>/dev/null)
        [[ -z "$PAF" ]] && PAF=$(grep "^PAF=" ~/.zen/.env 2>/dev/null | cut -d'=' -f2 || echo "14")

        ## ── Bulletin Capitaine : LifeOS + vrais chiffres → narration IA ──────────
        ## Best-effort intégral : jq/python absents ou economy_health.json manquant
        ## (station jamais passée par ECONOMY.broadcast.sh) → replis génériques,
        ## jamais un bulletin cassé ou vide (voir templates/UPlanetZINE/day_/captain.html).
        AI_NARRATIVE="Consultez votre dashboard economy.html pour le détail de la semaine."
        HEALTH_LABEL="niveau non disponible"
        WEEKS_RUNWAY="?"
        MULTIPASS_USED="?"; MULTIPASS_CAPACITY="?"
        ZENCARD_RENTERS="?"; ZENCARD_CAPACITY="?"
        if [[ "$IS_CAPTAIN" == "true" ]]; then
            ECONOMY_SNAPSHOT="$HOME/.zen/tmp/${IPFSNODEID}/economy_health.json"
            if [[ -s "$ECONOMY_SNAPSHOT" ]] && command -v jq >/dev/null 2>&1; then
                _status=$(jq -r '.health.status // ""' "$ECONOMY_SNAPSHOT" 2>/dev/null)
                case "$_status" in
                    healthy)           HEALTH_LABEL="Niveau 0 — Abondance" ;;
                    assets_solidarity) HEALTH_LABEL="Niveau 1 — Solidarité Actifs" ;;
                    rnd_solidarity)    HEALTH_LABEL="Niveau 2 — Solidarité R et D" ;;
                    volunteer)         HEALTH_LABEL="Niveau 3 — Bénévolat Actif" ;;
                esac
                WEEKS_RUNWAY=$(jq -r '.health.weeks_runway // "?"' "$ECONOMY_SNAPSHOT" 2>/dev/null)
                MULTIPASS_USED=$(jq -r '.capacity.multipass.used // "?"' "$ECONOMY_SNAPSHOT" 2>/dev/null)
                MULTIPASS_CAPACITY=$(jq -r '.capacity.multipass.total // "?"' "$ECONOMY_SNAPSHOT" 2>/dev/null)
                ZENCARD_RENTERS=$(jq -r '.capacity.zencard.renters // "?"' "$ECONOMY_SNAPSHOT" 2>/dev/null)
                ZENCARD_CAPACITY=$(jq -r '.capacity.zencard.total // "?"' "$ECONOMY_SNAPSHOT" 2>/dev/null)
            fi

            NARRATIVE_SCRIPT="${MY_PATH}/../IA/captain_bulletin_narrative.py"
            if [[ -f "$NARRATIVE_SCRIPT" ]]; then
                _generated=$(python3 "$NARRATIVE_SCRIPT" --email "${PLAYER}" --ipfsnodeid "${IPFSNODEID}" 2>/dev/null)
                [[ -n "$_generated" ]] && AI_NARRATIVE="$_generated"
            fi
        fi

        cat ${TODAYZINE} \
            | sed -e "s~_MOATS_~${MOATS}~g" \
                -e "s~_PLAYER_~${PLAYER}~g" \
                -e "s~_G1PUB_~${G1PUB}~g" \
                -e "s~_ASTRONAUTENS_~${ASTRONAUTENS}~g" \
                -e "s~_UPLANET8_~UPlanet:${UPLANETG1PUB:0:8}~g" \
                -e "s~_PAF_~${PAF}~g" \
                -e "s~_IPFSNODEID_~${IPFSNODEID}~g" \
                -e "s~_EARTHCID_~/ipns/copylaradio.com~g" \
                -e "s~_USPOT_~${uSPOT}~g" \
                -e "s~_RELAY_~${myRELAY}~g" \
                -e "s~_SECTOR_~${SECTOR}~g" \
                -e "s~_SLAT_~${SLAT}~g" \
                -e "s~_SLON_~${SLON}~g" \
                -e "s~_SALT_~[PROTECTED]~g" \
                -e "s~_PEPPER_~[PROTECTED]~g" \
                -e "s~_AI_NARRATIVE_~${AI_NARRATIVE}~g" \
                -e "s~_HEALTH_LABEL_~${HEALTH_LABEL}~g" \
                -e "s~_WEEKS_RUNWAY_~${WEEKS_RUNWAY}~g" \
                -e "s~_MULTIPASS_USED_~${MULTIPASS_USED}~g" \
                -e "s~_MULTIPASS_CAPACITY_~${MULTIPASS_CAPACITY}~g" \
                -e "s~_ZENCARD_RENTERS_~${ZENCARD_RENTERS}~g" \
                -e "s~_ZENCARD_CAPACITY_~${ZENCARD_CAPACITY}~g" \
                > ~/.zen/tmp/${MOATS}/UPlanetZine.html

        ${MY_PATH}/../tools/mailjet.sh --channel zine --template "${TODAYZINE}" --expire 48h "${PLAYER}" $HOME/.zen/tmp/${MOATS}/UPlanetZine.html \
                                        "ZINE #${days}" "${HOME}/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html"

    else
        echo "NO ZINE FOR DAY ${days}"
    fi

    echo "## >>>>>>>>>>>>>>>> ACTIVATING TW REFRESH (only for CAPTAIN & USOCIETY members)"
    if [[ "$_USOCIETY_ACTIVE" == "true" || "$IS_CAPTAIN" == "true" ]]; then
        # Delegate TiddlyWiki management to TW.refresh.sh
        if ! ${MY_PATH}/TW.refresh.sh "${PLAYER}" "${MOATS}" ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html; then
            echo "❌ TW.refresh.sh failed for ${PLAYER} - continuing with next player"
            continue
        fi
    else
        echo "TW is not refreshed for 128GB rental (NCARD+ZCARD)"
    fi
    #####################################################################
    ## PLAYER REFRESH COMPLETED
    echo "✅ Player refresh completed for ${PLAYER}"

    ## CLEANING CACHE
    rm -Rf ~/.zen/tmp/${MOATS}
    echo

    end=`date +%s`
    dur=`expr $end - $start`
    echo "${PLAYER} refreshing took $dur seconds (${MOATS})"

done
echo "============================================ PLAYER.refresh DONE."


exit 0