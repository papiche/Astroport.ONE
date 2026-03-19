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
    G1PUBNOSTR=$(cat ~/.zen/game/nostr/${PLAYER}/G1PUBNOSTR 2>/dev/null)
    ASTRONS=$(cat ~/.zen/game/players/${PLAYER}/.playerns 2>/dev/null)
    # Get PLAYER MULTIPASS wallet amount
    $MY_PATH/../tools/G1check.sh ${G1PUBNOSTR} > ~/.zen/tmp/${MOATS}/${PLAYER}.G1check
    cat ~/.zen/tmp/${MOATS}/${PLAYER}.G1check ###DEBUG MODE
    COINS=$(cat ~/.zen/tmp/${MOATS}/${PLAYER}.G1check | tail -n 1)
    ZEN=$(echo "scale=1; ($COINS - 1) * 10" | bc)
    echo "+++ MULTIPASS WALLET BALANCE _ $COINS (G1) _ / $ZEN ZEN /"

    ######################################################################################
    ######## COOPERATIVE ZEN CARD MANAGEMENT
    ######################################################################################
    ## Load OC URLs from cooperative config (or defaults)
    [[ -z "$OC_URL_SATELLITE" ]] && OC_URL_SATELLITE="https://opencollective.com/monnaie-libre/contribute/parrainage-infrastructure-extension-128-go-98386"
    [[ -z "$OC_URL_CONSTELLATION" ]] && OC_URL_CONSTELLATION="https://opencollective.com/monnaie-libre/contribute/parrainage-infrastructure-module-gpu-1-24-98385"
    ## Helper: prepare email template with OC URLs injected
    _prepare_email_template() {
        local tpl="$1"
        local tmp_email=$(mktemp)
        sed -e "s~_OC_URL_SATELLITE_~${OC_URL_SATELLITE}~g" \
            -e "s~_OC_URL_CONSTELLATION_~${OC_URL_CONSTELLATION}~g" \
            "$tpl" > "$tmp_email"
        echo "$tmp_email"
    }
    [[ -z ${BIRTHDATE} ]] && BIRTHDATE=$(cat ~/.zen/game/nostr/${PLAYER}/TODATE 2>/dev/null)
    [[ -z ${BIRTHDATE} ]] \
        && BIRTHDATE="$TODATE" \
        && echo "$TODATE" > ~/.zen/game/nostr/${PLAYER}/TODATE \
        && echo "$TODATE" > ~/.zen/game/nostr/${PLAYER}/.birthdate ## INIT BIRTHDATE
    ####################################################################

    # Check ZEN Card balance (should be 1Ğ1 = 0 ẐEN for cooperative members)
    ZENCARD_G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null)
    if [[ -n "$ZENCARD_G1PUB" ]]; then
        # Publish ZENCard _g1pub (used by tools/G1zencard_history.sh)
        [[ ! -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/_g1pub ]] \
            && echo "$ZENCARD_G1PUB" > ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/_g1pub

        echo "🔍 Checking ZEN Card balance for cooperative member..."
        $MY_PATH/../tools/G1check.sh ${ZENCARD_G1PUB} > ~/.zen/tmp/${MOATS}/${PLAYER}.ZENCARD.G1check
        ZENCARD_COINS=$(cat ~/.zen/tmp/${MOATS}/${PLAYER}.ZENCARD.G1check | tail -n 1)
        ZENCARD_ZEN=$(echo "scale=1; ($ZENCARD_COINS - 1) * 10" | bc)
        echo "ZEN Card balance: $ZENCARD_COINS Ğ1 ($ZENCARD_ZEN ẐEN)"
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
            CURRENT_DATE=$(date -u +%Y%m%d%H%M%S%4N)
            
            # Compare dates and calculate days remaining (U.SOCIETY.end format: YYYYMMDDHHMMSSNNNN)
            CURRENT_SECONDS=$(date -u +%s)
            END_DATE_FMT="${USOCIETY_END:0:4}-${USOCIETY_END:4:2}-${USOCIETY_END:6:2}"
            END_SECONDS=$(date -d "$END_DATE_FMT" +%s 2>/dev/null || echo "$CURRENT_SECONDS")
            DAYS_LEFT=$(( (END_SECONDS - CURRENT_SECONDS) / 86400 ))

            if [[ "$CURRENT_DATE" < "$USOCIETY_END" ]]; then
                _USOCIETY_ACTIVE=true
                echo "✅ U.SOCIETY membership active until $USOCIETY_END ($DAYS_LEFT days left)"

                ## RENEWAL REMINDERS (30 days, 7 days before expiration)
                REMINDER_FILE="${HOME}/.zen/game/players/${PLAYER}/.usociety_reminder"
                LAST_REMINDER=$(cat "$REMINDER_FILE" 2>/dev/null || echo "0")

                if [[ $DAYS_LEFT -le 30 && $DAYS_LEFT -gt 7 && "$LAST_REMINDER" != "30" ]]; then
                    echo "📬 Sending 30-day renewal reminder to ${PLAYER}"
                    _tpl=$(_prepare_email_template "${MY_PATH}/../templates/NOSTR/usociety_renewal.html")
                    ${MY_PATH}/../tools/mailjet.sh --expire 7d "${PLAYER}" "$_tpl" \
                        "Votre parrainage expire dans ${DAYS_LEFT} jours"
                    rm -f "$_tpl"
                    echo "30" > "$REMINDER_FILE"
                elif [[ $DAYS_LEFT -le 7 && $DAYS_LEFT -gt 0 && "$LAST_REMINDER" != "7" ]]; then
                    echo "📬 Sending 7-day URGENT renewal reminder to ${PLAYER}"
                    _tpl=$(_prepare_email_template "${MY_PATH}/../templates/NOSTR/usociety_renewal_urgent.html")
                    ${MY_PATH}/../tools/mailjet.sh --expire 3d "${PLAYER}" "$_tpl" \
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
                    ${MY_PATH}/../tools/mailjet.sh --expire 7d "${PLAYER}" "$_tpl" \
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
        TODATE_SECONDS=$(date -d "$TODATE" +%s)
        BIRTHDATE_SECONDS=$(date -d "$BIRTHDATE" +%s)
        # Calculate the difference in days
        DIFF_DAYS=$(( (TODATE_SECONDS - BIRTHDATE_SECONDS) / 86400 ))
        DAYS_UNTIL_NEXT_PAYMENT=$(( 7 - (DIFF_DAYS % 7) ))
        echo "Next payment in $DAYS_UNTIL_NEXT_PAYMENT days"

        # Grace period CAPITAINE : jamais UNPLUG (U.SOCIETY permanent, même à 0Ğ1)
        if [[ "${PLAYER}" == "${CAPTAINEMAIL}" ]]; then
            echo "👑 CAPTAIN ${PLAYER} — ZEN Card protégée (pas d'UNPLUG)"
            DIFF_DAYS=999  # Force skip du cycle de paiement
        fi

        [[ -z $NCARD ]] && NCARD=1
        Npaf=$(makecoord $(echo "$NCARD / 10" | bc -l))
        [[ -z $ZCARD ]] && ZCARD=4
        Gpaf=$(makecoord $(echo "$ZCARD / 10" | bc -l))
        # Check if the difference is a multiple of 7
        if [ $((DIFF_DAYS % 7)) -eq 0 ]; then
            if [[ $(echo "$COINS > $Gpaf + $Npaf" | bc -l) -eq 1 && ${PLAYER} != ${CAPTAINEMAIL} ]]; then
                ## Pay ZCARD to CAPTAIN with TVA provision
                echo "[7 DAYS CYCLE] $TODATE MULTIPASS is paying ZENCARD access $ZCARD Ẑ to CAPTAIN and $NCARD ẐEN to own MULTIPASS."

                # Calculate TVA provision (20% of ZENCard payment)
                [[ -z $TVA_RATE ]] && TVA_RATE=0
                TVA_AMOUNT=$(echo "scale=4; $Gpaf * $TVA_RATE / 100" | bc -l)
                TVA_AMOUNT=$(makecoord $TVA_AMOUNT)
                
                # Convert Ğ1 to ẐEN for display (1 Ğ1 = 10 ẐEN)
                Gpaf_ZEN=$(echo "scale=1; $Gpaf * 10" | bc -l)
                TVA_ZEN=$(echo "scale=1; $TVA_AMOUNT * 10" | bc -l)

                echo "[7 DAYS CYCLE] ZENCard payment - Direct TVA split: $Gpaf_ZEN ẐEN ($Gpaf Ğ1) to CAPTAIN + $TVA_ZEN ẐEN ($TVA_AMOUNT Ğ1) to IMPOTS"

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
                        echo "✅ TVA provision recorded directly from ZENCard for ${PLAYER} on $TODATE ($TVA_ZEN ẐEN = $TVA_AMOUNT Ğ1)"
                    else
                        echo "❌ TVA provision failed for ${PLAYER} on $TODATE ($TVA_ZEN ẐEN = $TVA_AMOUNT Ğ1)"
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
                    error_message="<html><head><meta charset='UTF-8'>
<style>
    body { font-family: 'Courier New', monospace; }
    .error { color: red; font-weight: bold; }
    .details { background-color: #f5f5f5; padding: 10px; margin: 10px 0; }
</style></head><body>
<h2 class='error'>❌ ZENCard Payment Error</h2>
<div class='details'>
<p><strong>Player:</strong> ${PLAYER}</p>
<p><strong>Date:</strong> $TODATE</p>
<p><strong>Amount HT:</strong> $Gpaf ẐEN</p>
<p><strong>TVA Amount:</strong> $TVA_AMOUNT ẐEN</p>
<p><strong>Payment Status:</strong> Main: $([ $payment_success -eq 0 ] && echo "✅" || echo "❌") | TVA: $([ $tva_success -eq 0 ] && echo "✅" || echo "❌")</p>
<p><strong>Balance:</strong> $COINS G1 ($ZEN ẐEN)</p>
</div>
<p>Both payments must succeed for fiscal compliance.</p>
</body></html>"

                    ${MY_PATH}/../tools/mailjet.sh --expire 48h "${PLAYER}" <(echo "$error_message") "ZENCard Payment Error - $TODATE"
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
                    $MY_PATH/../tools/mailjet.sh --expire 7d "${PLAYER}" "$_tpl" \
                        "Solde insuffisant (${ZEN} ZEN) - ZEN Card desactivee"
                    rm -f "$_tpl"
                    ${MY_PATH}/PLAYER.unplug.sh ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html ${PLAYER} "ALL"
                fi
            fi
        fi
    fi


    #~ ## ZENCARD ARE ACTIVATED WITH 1 G1
    echo "## >>>>>>>>>>>>>>>> DELEGATING TW REFRESH TO TW.refresh.sh"
    
    # Delegate TiddlyWiki management to TW.refresh.sh
    if ! ${MY_PATH}/TW.refresh.sh "${PLAYER}" "${MOATS}" ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html; then
        echo "❌ TW.refresh.sh failed for ${PLAYER} - continuing with next player"
        continue
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