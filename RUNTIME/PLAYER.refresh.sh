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
    ZEN=$(echo "($COINS - 1) * 10" | bc | cut -d '.' -f 1)
    echo "+++ MULTIPASS WALLET BALANCE _ $COINS (G1) _ / $ZEN ZEN /"

    ######################################################################################
    ######## COOPERATIVE ZEN CARD MANAGEMENT
    ######################################################################################
    [[ -z ${BIRTHDATE} ]] && BIRTHDATE=$(cat ~/.zen/game/nostr/${PLAYER}/TODATE 2>/dev/null)
    [[ -z ${BIRTHDATE} ]] \
        && BIRTHDATE="$TODATE" \
        && echo "$TODATE" > ~/.zen/game/nostr/${PLAYER}/TODATE \
        && echo "$TODATE" > ~/.zen/game/nostr/${PLAYER}/.birthdate ## INIT BIRTHDATE
    ####################################################################

    # Check ZEN Card balance (should be 1Ğ1 = 0 ẐEN for cooperative members)
    ZENCARD_G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null)
    if [[ -n "$ZENCARD_G1PUB" ]]; then
        echo "🔍 Checking ZEN Card balance for cooperative member..."
        $MY_PATH/../tools/G1check.sh ${ZENCARD_G1PUB} > ~/.zen/tmp/${MOATS}/${PLAYER}.ZENCARD.G1check
        ZENCARD_COINS=$(cat ~/.zen/tmp/${MOATS}/${PLAYER}.ZENCARD.G1check | tail -n 1)
        ZENCARD_ZEN=$(echo "($ZENCARD_COINS - 1) * 10" | bc | cut -d '.' -f 1)
        echo "ZEN Card balance: $ZENCARD_COINS Ğ1 ($ZENCARD_ZEN ẐEN)"
        
        # If ZEN Card has surplus (not 1Ğ1), clean it up
        if [[ $(echo "$ZENCARD_COINS > 1" | bc -l) -eq 1 ]]; then
            echo "🧹 ZEN Card has surplus, cleaning up with G1zencard_0zen.sh..."
            ${MY_PATH}/../tools/G1zencard_0zen.sh --email "${PLAYER}" --force
        fi
    fi

    # U.SOCIETY logic for rent payments
    if [[ -s ~/.zen/game/players/${PLAYER}/U.SOCIETY ]]; then
        ## U SOCIETY MEMBER - Check if U.SOCIETY.end exists and is not reached
        UDATE=$(cat ~/.zen/game/players/${PLAYER}/U.SOCIETY)
        echo "U SOCIETY REGISTRATION : $UDATE"
        
        # Check if U.SOCIETY.end exists
        if [[ -s ~/.zen/game/players/${PLAYER}/U.SOCIETY.end ]]; then
            USOCIETY_END=$(cat ~/.zen/game/players/${PLAYER}/U.SOCIETY.end)
            CURRENT_DATE=$(date -u +%Y%m%d%H%M%S%4N)
            
            # Compare dates (U.SOCIETY.end format: YYYYMMDDHHMMSSNNNN)
            if [[ "$CURRENT_DATE" < "$USOCIETY_END" ]]; then
                echo "✅ U.SOCIETY membership active until $USOCIETY_END - No rent payment required"
            else
                echo "⚠️  U.SOCIETY membership expired on $USOCIETY_END - Rent payment required"
                # Fall through to rent payment logic
            fi
        else
            echo "✅ U.SOCIETY membership active (no end date) - No rent payment required"
        fi
    else
        ## NON-U.SOCIETY MEMBER - EVERY 7 DAYS PAY CAPTAIN
        echo "🏠 Non-U.SOCIETY member - Weekly rent payment required"
        TODATE_SECONDS=$(date -d "$TODATE" +%s)
        BIRTHDATE_SECONDS=$(date -d "$BIRTHDATE" +%s)
        # Calculate the difference in days
        DIFF_DAYS=$(( (TODATE_SECONDS - BIRTHDATE_SECONDS) / 86400 ))
        DAYS_UNTIL_NEXT_PAYMENT=$(( 7 - (DIFF_DAYS % 7) ))
        echo "Next payment in $DAYS_UNTIL_NEXT_PAYMENT days"

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
                [[ -z $TVA_RATE ]] && TVA_RATE=20
                TVA_AMOUNT=$(echo "scale=4; $Gpaf * $TVA_RATE / 100" | bc -l)
                TVA_AMOUNT=$(makecoord $TVA_AMOUNT)

                echo "[7 DAYS CYCLE] ZENCard payment - Direct TVA split: $Gpaf ẐEN to CAPTAIN + $TVA_AMOUNT ẐEN to IMPOTS"

                # Ensure IMPOTS wallet exists before any payment
                    if [[ ! -s ~/.zen/game/uplanet.IMPOT.dunikey ]]; then
                        ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.IMPOT.dunikey "${UPLANETNAME}.IMPOT" "${UPLANETNAME}.IMPOT"
                        chmod 600 ~/.zen/game/uplanet.IMPOT.dunikey
                    fi

                    # Get IMPOTS wallet G1PUB
                IMPOTS_G1PUB=$(cat $HOME/.zen/game/uplanet.IMPOT.dunikey 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)

                # Main ZENCard payment to CAPTAIN (HT amount only)
                payment_result=$(${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/nostr/${PLAYER}/.secret.dunikey" "$Gpaf" "${CAPTAING1PUB}" "UPLANET:${UPLANETG1PUB:0:8}:${YOUSER}:ZCARD:HT" 2>/dev/null)
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
                    echo "✅ Weekly ZENCard payment recorded for ${PLAYER} on $TODATE ($Gpaf ẐEN HT + $TVA_AMOUNT ẐEN TVA) - Fiscally compliant split"
                else
                    # Payment failed - send error email
                    if [[ $payment_success -ne 0 ]]; then
                        echo "❌ Main ZENCard payment failed for ${PLAYER} on $TODATE ($Gpaf ẐEN)"
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

                    ${MY_PATH}/../tools/mailjet.sh "${PLAYER}" <(echo "$error_message") "ZENCard Payment Error - $TODATE"
                    echo "Error email sent to ${PLAYER} for payment failure"
                fi
            else
                echo "[7 DAYS CYCLE] ZENCARD ($COINS G1) UNPLUG !!"
                $MY_PATH/../tools/mailjet.sh "${PLAYER}" "$COINS Ğ1" "MULTIPASS is missing Ẑen for paying ZEN Card..."
                if [[ ${PLAYER} != ${CAPTAINEMAIL} ]]; then
                    ${MY_PATH}/PLAYER.unplug.sh ~/.zen/game/players/${PLAYER}/ipfs/moa/index.hEtml ${PLAYER} "ALL"
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