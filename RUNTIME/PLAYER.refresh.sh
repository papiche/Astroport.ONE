#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ PLAYER.refresh.sh
#~ Refresh PLAYER data & wallet
################################################################################
# Ce script gère le rafraîchissement des données des joueurs :
# 1. Vérifie et met à jour les données des joueurs
# 2. Gère les paiements des cartes ZEN
# 3. Implémente le système de distribution des bénéfices
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
    G1PUB=$(cat ~/.zen/game/nostr/${PLAYER}/G1PUBNOSTR 2>/dev/null)
    ASTRONS=$(cat ~/.zen/game/players/${PLAYER}/.playerns 2>/dev/null)
    # Get PLAYER MULTIPASS wallet amount
    $MY_PATH/../tools/G1check.sh ${G1PUB} > ~/.zen/tmp/${MOATS}/${PLAYER}.G1check
    cat ~/.zen/tmp/${MOATS}/${PLAYER}.G1check ###DEBUG MODE
    COINS=$(cat ~/.zen/tmp/${MOATS}/${PLAYER}.G1check | tail -n 1)
    ZEN=$(echo "($COINS - 1) * 10" | bc | cut -d '.' -f 1)
    echo "+++ MULTIPASS WALLET BALANCE _ $COINS (G1) _ / $ZEN ZEN /"

    ######################################################################################
    ######## ZEN ECONOMY INTEGRATION - MULTIPASS used for ZEN Card service level payment
    ######################################################################################
    [[ -z ${BIRTHDATE} ]] && BIRTHDATE=$(cat ~/.zen/game/nostr/${PLAYER}/TODATE 2>/dev/null)
    [[ -z ${BIRTHDATE} ]] \
        && BIRTHDATE="$TODATE" \
        && echo "$TODATE" > ~/.zen/game/nostr/${PLAYER}/TODATE \
        && echo "$TODATE" > ~/.zen/game/nostr/${PLAYER}/.birthdate ## INIT BIRTHDATE
    ####################################################################

    if [[ -s ~/.zen/game/players/${PLAYER}/U.SOCIETY ]]; then
        ## U SOCIETY MEMBER
        UDATE=$(cat ~/.zen/game/players/${PLAYER}/U.SOCIETY)
        echo "U SOCIETY REGISTRATION : $UDATE"
    else
        ## EVERY 7 DAYS PAY CAPTAIN
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
                payment_result=$(${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/nostr/${PLAYER}/.secret.dunikey" "$Gpaf" "${CAPTAING1PUB}" "UPLANET${UPLANETG1PUB:0:8}:${YOUSER}:ZCARD:HT" 2>/dev/null)
                payment_success=$?

                # TVA provision directly from PLAYER to IMPOTS (fiscally correct)
                tva_success=0
                if [[ $payment_success -eq 0 && $(echo "$TVA_AMOUNT > 0" | bc -l) -eq 1 && -n "$IMPOTS_G1PUB" ]]; then
                    tva_result=$(${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/nostr/${PLAYER}/.secret.dunikey" "$TVA_AMOUNT" "${IMPOTS_G1PUB}" "UPLANET${UPLANETG1PUB:0:8}:${YOUSER}:TVA" 2>/dev/null)
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
    echo "## >>>>>>>>>>>>>>>> REFRESH ASTRONAUTE TW"
    ## REFRESH ASTRONAUTE TW
    ASTRONAUTENS=$(ipfs key list -l | grep -w ${PLAYER} | head -n1 | cut -d ' ' -f1)

    ############### CANNOT FIND PLAYER KEY ###########
    if [[ ! ${ASTRONAUTENS} ]]; then

        echo "${PLAYER} TW IS DISCONNECTED... RECREATING IPNS KEYS"
        ## TODO : EXTRACT & DECRYPT secret.june FROM TW
        ipfs key import ${PLAYER} -f pem-pkcs8-cleartext ~/.zen/game/players/${PLAYER}/secret.player

        ipfs key rm "${PLAYER}_feed" 2>/dev/null
        source ~/.zen/game/players/${PLAYER}/secret.june
        ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/feed.ipfskey "$SALT" "$PEPPER $G1PUB"
        FEEDNS=$(ipfs key import "${PLAYER}_feed" -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/feed.ipfskey)

        ## IF ASTRONS="" KEY WILL BE DELETED AFTER REFRESH
        ASTRONAUTENS=$ASTRONS && ASTRONS=""

    fi

    [[ ! ${ASTRONAUTENS} ]] && echo "ERROR BAD ${PLAYER} - CONTINUE" && continue

    echo ">>> $myIPFS/ipns/${ASTRONAUTENS}"

    ## ACTIVATE PLAYER TW IN STATION CACHE
    mkdir -p ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/

    ################### GET LATEST TW
    rm -f ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html
    echo "GETTING TW..."
    ####################################################################################################
    ipfs --timeout 480s get --progress=false -o ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html /ipns/${ASTRONAUTENS}
    ####################################################################################################
    ## PLAYER TW IS ONLINE ?
    if [ ! -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html ]; then

        NOWCHAIN=$(cat ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain)
        LASTCHAIN=$(cat ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain.* | tail -n 1)
        try=$(cat ~/.zen/game/players/${PLAYER}/ipfs/moa/.try 2>/dev/null) || try=3
        echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        echo "$myIPFS/ipns/${ASTRONAUTENS}'>TW REFRESH FAILED"
        echo ">> %%% WARNING TRY LEFT : $try %%%"
        echo "------------------------------------------------"
        echo " * <a href='${myIPFS}/ipfs/${LASTCHAIN}'>LAST</a>"
        echo " * <a href='${myIPFS}/ipfs/${NOWCHAIN}'>NOW</a>"
        echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

        ## SEND AN EMAIL ALERT TO PLAYER
        echo "<html><head><meta charset='UTF-8'>
<style>
    body {
        font-family: 'Courier New', monospace;
    }
    pre {
        white-space: pre-wrap;
    }
</style></head><body><a href='$myIPFS/ipns/${ASTRONAUTENS}'>TW LOADING TIMEOUT</a>" > ~/.zen/tmp/result
        echo "<br>------------------------------------------------" >> ~/.zen/tmp/result
        echo "<br>" >> ~/.zen/tmp/result
        echo "<br><a href='${myIPFS}/ipfs/${LASTCHAIN}'>[yesterday]</a>: /ipfs/${LASTCHAIN}" >> ~/.zen/tmp/result
        echo "<br><a href='${myIPFS}/ipfs/${NOWCHAIN}'>[today]</a>: /ipfs/${NOWCHAIN}" >> ~/.zen/tmp/result
        echo "<br>" >> ~/.zen/tmp/result
        echo "<br> %%% WARNING %%% $try TRY LEFT %%%" >> ~/.zen/tmp/result
        echo "<br>------------------------------------------------" >> ~/.zen/tmp/result
        echo "<br>ipfs name publish --key=${PLAYER} /ipfs/${NOWCHAIN}" >> ~/.zen/tmp/result
        echo "</body></html>" >> ~/.zen/tmp/result

        ### TO MANY ERROR LOADING TW
        [[ $try == 0 && "${CURRENT}" != "${PLAYER}" ]] \
            && echo "PLAYER ${PLAYER} UNPLUG" \
            && ${MY_PATH}/PLAYER.unplug.sh ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html ${PLAYER} "ALL" \
            && continue

        try=$((try-1))
        echo "$try" > ~/.zen/game/players/${PLAYER}/ipfs/moa/.try

        $MY_PATH/../tools/mailjet.sh "${PLAYER}" ~/.zen/tmp/result "${PLAYER} TW LOADING TIMEOUT $try"

        continue

    fi

    #############################################################
    ## FOUND TW
    err=""
    #############################################################
    ## CHECK "GPS" Tiddler
    tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
        --output ~/.zen/tmp/${MOATS} \
        --render '.' 'GPS.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'GPS'  ## GPS Tiddler
    [[ ! -s ~/.zen/tmp/${MOATS}/GPS.json || $(cat ~/.zen/tmp/${MOATS}/GPS.json) == "[]" ]] \
        && msg="${PLAYER} GPS : BAD TW (☓‿‿☓) " && err="(☓‿‿☓)"

    #############################################################
    ## CHECK MadeInZion
    tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
        --output ~/.zen/tmp/${MOATS} \
        --render '.' 'MadeInZion.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion' ## MadeInZion Tiddler

    [[ ! -s ~/.zen/tmp/${MOATS}/MadeInZion.json || $(cat ~/.zen/tmp/${MOATS}/MadeInZion.json) == "[]" ]] \
        && msg="${PLAYER} MadeInZion : BAD TW (☓‿‿☓) " && err="(☓‿‿☓)" && player="" \
        || player=$(cat ~/.zen/tmp/${MOATS}/MadeInZion.json | jq -r .[].player)

    lang=$(cat ~/.zen/tmp/${MOATS}/MadeInZion.json 2>/dev/null | jq -r .[].dao)
    [[ ${lang} == "null" ]] && lang="fr"
    #############################################################
    ## CHECK "AstroID" Tiddler
    tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
        --output ~/.zen/tmp/${MOATS} \
        --render '.' 'AstroID.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'AstroID' ## AstroID Tiddler
    [[ $(cat ~/.zen/tmp/${MOATS}/AstroID.json 2>/dev/null) == "[]" ]] && rm ~/.zen/tmp/${MOATS}/AstroID.json
    ########################################## used by Astroport :: Lasertag :: TW plugin ##
    ## CHECK "$:/config/NewTiddler/Tags" is SET to PLAYER for signature
    tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
        --output ~/.zen/tmp/${MOATS} \
        --render '.' 'TWsign.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '$:/config/NewTiddler/Tags' ## $:/config/NewTiddler/Tags Tiddler
    signature=$(cat ~/.zen/tmp/${MOATS}/TWsign.json | jq -r .[].text)
    echo "${player} SIGNATURE = $signature"

    #############################################################
    ## CHECK "Astroport" TIDDLER
    tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
        --output ~/.zen/tmp/${MOATS} \
        --render '.' 'Astroport.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Astroport'  ## Astroport Tiddler
    [[ ! -s ~/.zen/tmp/${MOATS}/Astroport.json || $(cat ~/.zen/tmp/${MOATS}/Astroport.json) == "[]" ]] \
        && msg="${PLAYER} Astroport : BAD TW (☓‿‿☓) " && err="(☓‿‿☓)"

    ############################################################ BAD TW SIGNATURE
    [[ ( ${player} != ${PLAYER} || ${PLAYER} != ${signature} || "${err}" == "(☓‿‿☓)" ) && ${PLAYER} != ${CURRENT} ]] \
        && echo "> (☓‿‿☓) BAD PLAYER=$player in TW (☓‿‿☓) $msg" \
        && ${MY_PATH}/PLAYER.unplug.sh "${HOME}/.zen/game/players/${PLAYER}/ipfs/moa/index.html" "${PLAYER}" "ALL" \
        && continue \
        || echo "${PLAYER} OFFICIAL TW - (⌐■_■) -"

    BIRTHDATE=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].birthdate)
    ASTROPORT=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].astroport) ## ZenStation IPNS address
    CURCHAIN=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].chain | rev | cut -f 1 -d '/' | rev) # Remove "/ipfs/" part
    [[ ${CURCHAIN} == "" ||  ${CURCHAIN} == "null" ]] \
        && CURCHAIN="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" # AVOID EMPTY

    ## SSHPUB is used to allow REMOTE TCP access through "ipfs p2p"
    SSHPUB="$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].sshpub)"
    ## NEEDS more than 10 ZEN to activate IPFS P2P SSH authorization
    if [[ ! -z "${SSHPUB}" ]]; then
        if [[ $(echo "$COINS > 2" | bc -l) -eq 1 ]]; then
            ## PUBLISH SSHPUB for DRAGON_p2p_ssh.sh
            [[ "${SSHPUB}" != "null" ]] \
                && echo "${SSHPUB}" > ${HOME}/.zen/game/players/${PLAYER}/ssh.pub \
                || rm -f ${HOME}/.zen/game/players/${PLAYER}/ssh.pub
        else
            ## REMOVE FROM ~/.ssh/authorized_keys
            rm -f ${HOME}/.zen/game/players/${PLAYER}/ssh.pub
            cat ~/.ssh/authorized_keys | grep -v "${SSHPUB}" > ~/.zen/tmp/${MOATS}/new_auth
            cat ~/.zen/tmp/${MOATS}/new_auth > ~/.ssh/authorized_keys
        fi
    fi

    SBIRTH=$(${MY_PATH}/../tools/MOATS2seconds.sh ${BIRTHDATE})
    SNOW=$(${MY_PATH}/../tools/MOATS2seconds.sh ${MOATS})
    DIFF_SECONDS=$(( SNOW - SBIRTH ))
    days=$((DIFF_SECONDS / 60 / 60 / 24))

################################################## ANOTHER ASTROPORT !!
    IPNSTAIL=$(echo ${ASTROPORT} | rev | cut -f 1 -d '/' | rev) # Remove "/ipns/" part
    ########### ASTROPORT is not IPFSNODEID => EJECT TW
    if [[ ${IPNSTAIL} != "" && "${CURRENT}" != "${PLAYER}" ]]; then
        if [[ ${IPNSTAIL} != ${IPFSNODEID} || ${IPNSTAIL} == "_ASTROPORT_" ]]; then
            echo "> PLAYER MOVED TO ${IPNSTAIL} : UNPLUG "
            ${MY_PATH}/PLAYER.unplug.sh "${HOME}/.zen/game/players/${PLAYER}/ipfs/moa/index.html" "${PLAYER}" "ONE" "TW moved to ${ASTROPORT}"
            echo ">>>> CIAO ${PLAYER}"
            continue
        fi
    fi

    ################ VERIFICATIONS DONE ######################
    echo "ASTROPORT ZenStation : ${ASTROPORT}"
    echo "CURCHAIN=${CURCHAIN}"
    echo "================================== TW $days days old"

    # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ######################################## LOW ZEN PLAYER UNPLUG !
    ## UNPLUG more than 28 days & less than 2 G1 account
    [[ "${CURRENT}" != "${PLAYER}" && $(echo "$days >= 28" | bc -l) -eq 1 && $(echo "$COINS <= 2" | bc -l) -eq 1 ]] \
        && echo "LOW ZEN PLAYER UNPLUG" \
        && ${MY_PATH}/PLAYER.unplug.sh "${HOME}/.zen/game/players/${PLAYER}/ipfs/moa/index.html" "${PLAYER}" "ALL" "UPLANET${UPLANETG1PUB:0:8}:EXIT" \
        && continue

############################################## +1 DAY REMOVE AstroID !!
    ## REMOVE AstroID
    [[ -s ~/.zen/tmp/${MOATS}/AstroID.json && $days -gt 1 ]] \
        && ${MY_PATH}/TW/delete_tiddler.sh "${HOME}/.zen/game/players/${PLAYER}/ipfs/moa/index.html" "AstroID" \
        && rm ~/.zen/tmp/${MOATS}/AstroID.json

####################################################################### RTFM DUMB FIREWALL
############################################################################################

    ######################################
    #### UPLANET GEO COORD EXTRACTION
    ## GET "GPS" TIDDLER - 0.00 0.00 (if empty: null)
    ZLAT=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].lat)
        [[ $ZLAT == "null" || $ZLAT == "" ]] && ZLAT="0.00"
    ZLON=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].lon)
        [[ $ZLON == "null" || $ZLON == "" ]] && ZLON="0.00"

    LAT=$(makecoord ${ZLAT})
    LON=$(makecoord ${ZLON})

    ### GET UMAP ENV
    $(${MY_PATH}/../tools/getUMAP_ENV.sh "${LAT}" "${LON}" | tail -n 1)
    echo "UMAPHEX=$UMAPHEX UMAPG1PUB=$UMAPG1PUB UMAPIPNS=$UMAPIPNS SECTORG1PUB=$SECTORG1PUB SECTORIPNS=$SECTORIPNS REGIONG1PUB=$REGIONG1PUB REGIONIPNS=$REGIONIPNS LAT=$LAT LON=$LON SLAT=$SLAT SLON=$SLON RLAT=$RLAT RLON=$RLON"

    UMAPNS=$(echo $UMAPIPNS | rev | cut -d '/' -f 1 | rev)
    #############################################
    # MAKE "GPS" TIDDLER
    cat ${MY_PATH}/../templates/data/GPS.json \
        | sed -e "s~_MOATS_~${MOATS}~g" \
        -e "s~_PLAYER_~${PLAYER}~g" \
        -e "s~_LAT_~${LAT}~g" \
        -e "s~_LON_~${LON}~g" \
        -e "s~_UMAPNS_~${UMAPNS}~g" \
        -e "s~_SECTORTW_~${SECTORIPNS}/TW~g" \
            > ~/.zen/tmp/${MOATS}/GPS.json

    ## UPDATE PLAYER CACHE
    echo "LAT=${LAT}; LON=${LON};" > ~/.zen/game/players/${PLAYER}/.umap
    cp ~/.zen/tmp/${MOATS}/GPS.json ~/.zen/game/players/${PLAYER}/

    ################# PERSONAL VDO.NINJA PHONEBOOTH
    if [[ "${days}" -gt "3" ]]; then
        YOUSER=$($MY_PATH/../tools/clyuseryomail.sh "${PLAYER}")
        _USER=$(echo $YOUSER | sed "s~\.~_~g")
        # MAKE "VISIO" TIDDLER
        cat ${MY_PATH}/../templates/data/VISIO.json \
            | sed -e "s~_IPFSNINJA_~${VDONINJA}~g" \
            -e "s~_MOATS_~${MOATS}~g" \
            -e "s~_PLAYER_~${PLAYER}~g" \
            -e "s~_PHONEBOOTH_~${_USER}~g" \
                > ~/.zen/tmp/${MOATS}/VISIO.json

    else
        echo "[]" > ~/.zen/tmp/${MOATS}/VISIO.json
    fi


    #####################################################################
    # MAKE "CESIUM" TIDDLER
    #~ if [[ "${days}" -gt "4" ]]; then
        #~ echo "Create CESIUM Tiddler"
        #~ cat ${MY_PATH}/../templates/data/CESIUM.json \
            #~ | sed -e "s~_G1PUB_~${G1PUB}~g" \
            #~ -e "s~_MOATS_~${MOATS}~g" \
            #~ -e "s~_CESIUMIPFS_~${CESIUMIPFS}~g" \
            #~ -e "s~_PLAYER_~${PLAYER}~g" \
                #~ > ~/.zen/tmp/${MOATS}/CESIUM.json

    #~ else
        #~ echo "[]" > ~/.zen/tmp/${MOATS}/CESIUM.json
    #~ fi
    #####################################################################
    ########## $:/moa picture ## CREATE EMAIL from email tiddler ########
    ## GET $:/moa Tagged Tiddlers ################################# START
    echo "GET $:/moa Tagged Tiddlers"
    ###################################################### [tag[$:/moa]] used for "DID" declaration
    tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
        --output ~/.zen/tmp/${MOATS} \
        --render '.' 'FRIENDS.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[$:/moa]]'  ## $:/moa EMAIL Tiddlers
    #####################################################################
    fplayers=($(cat ~/.zen/tmp/${MOATS}/FRIENDS.json | jq -rc .[].title))
    echo "${fplayers[@]}"
    UPLAYERSTIDS=()
    for fp in ${fplayers[@]}; do

        [[ ! "${fp}" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] && echo "BAD ${fp} FORMAT" && continue
        [[ "${fp}" == "${PLAYER}" ]] && echo "IT'S ME - CONTINUE" && continue

        FPLAYER=$(cat ~/.zen/tmp/${MOATS}/FRIENDS.json  | jq .[] | jq -r 'select(.title=="'${fp}'") | .player')
        [[ $FPLAYER == 'null' || $FPLAYER == '' ]] \
            && echo "FPLAYER null - NOGOOD${fp} -" \
            && continue
            # AUTO CORRECT : sed -i "s~${fp}~NOGOOD${fp}~g" ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \

        FTW=$(cat ~/.zen/tmp/${MOATS}/FRIENDS.json  | jq .[] | jq -r 'select(.title=="'${fp}'") | .tw')
        [[ ${FTW} == "/ipns/" || ${FTW} == "null" || ${FTW} == "" ]] && echo "WEIRD FTW ${FTW} - CONTINUE" && continue

        FG1PUB=$(cat ~/.zen/tmp/${MOATS}/FRIENDS.json  | jq .[] | jq -r 'select(.title=="'${fp}'") | .g1pub')
        [[ $FG1PUB == 'null' || $FG1PUB == '' ]] && echo "FG1PUB null - CONTINUE" && continue

        IHASH=$(cat ~/.zen/tmp/${MOATS}/FRIENDS.json  | jq .[] | jq -r 'select(.title=="'${fp}'") | .text' | sha256sum | cut -d ' ' -f 1)

        echo ":: coucou :: $FPLAYER :: (ᵔ◡◡ᵔ) ::"
        echo "TW: $FTW"
        echo "G1: $FG1PUB"
        echo "IHASH: $IHASH"
        UPLAYERSTIDS=("${UPLAYERSTIDS[@]}" "[[${FPLAYER^^}|${FPLAYER^^}]]")

        ## GET ORIGINH FROM LAST KNOWN TW STATE
        mkdir -p ~/.zen/game/players/${PLAYER}/FRIENDS/${FPLAYER}

        ## CHECK ALREADY IN ${FPLAYER^^} IHASH
        rm -f ~/.zen/tmp/${MOATS}/finside.json
        tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
        --output ~/.zen/tmp/${MOATS} \
        --render '.' 'finside.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' "${FPLAYER^^}"  ## ${FPLAYER^^} autoload Tiddlers

        INSIDEH=$(cat ~/.zen/tmp/${MOATS}/finside.json  | jq -rc '.[].ihash')
        echo "INSIDEH: $INSIDEH"

        if [[ -s ~/.zen/game/players/${PLAYER}/FRIENDS/${FPLAYER}/index.html ]]; then
            tiddlywiki --load ~/.zen/game/players/${PLAYER}/FRIENDS/${FPLAYER}/index.html \
                --output ~/.zen/tmp/${MOATS} \
                --render '.' "${FPLAYER}.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' "${FPLAYER}" ## GET ORIGIN

            ORIGINH=$(cat ~/.zen/tmp/${MOATS}/${FPLAYER}.json  | jq -r '.[].text' | sha256sum | cut -d ' ' -f 1)
            ## CAN USE IPFSH=$(cat ~/.zen/tmp/${MOATS}/${FPLAYER}.json  | jq -r '.[].text' | ipfs add -q)
            ## TODO MICROLEDGER TIDDLER...
            # we are monitoring email tiddler image change (G1BILLET background is made of).
            echo "ORIGINH: $ORIGINH"
        else
            ORIGINH="$INSIDEH"
        fi

        ( ## REFRESH LOCAL PLAYER CACHE with FRIEND ACTUAL TW (&) will be used TOMORROW
            ipfs --timeout 480s cat --progress="false" ${FTW} > ~/.zen/game/players/${PLAYER}/FRIENDS/${FPLAYER}/index.html
        ) &

        ## UPDATE IF IHASH CHANGED -> New drawing => Friend get informed
        if [[ -z $INSIDEH || $INSIDEH != $IHASH || $ORIGINH != $INSIDEH ]]; then
            cat ${MY_PATH}/../templates/data/_UPPERFPLAYER_.json \
                | sed -e "s~_UPPERFPLAYER_~${FPLAYER^^}~g" \
                -e "s~_FPLAYER_~${FPLAYER}~g" \
                -e "s~_MOATS_~${MOATS}~g" \
                -e "s~_IHASH_~${IHASH}~g" \
                -e "s~_FRIENDTW_~${FTW}~g" \
                -e "s~_PLAYER_~${PLAYER}~g" \
                    > ~/.zen/tmp/${MOATS}/${FPLAYER^^}.json

            echo "Insert New ${FPLAYER^^}.json"
            #~ cat ~/.zen/tmp/${MOATS}/${FPLAYER^^}.json | jq

            tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
                --import ${HOME}/.zen/tmp/${MOATS}/${FPLAYER^^}.json 'application/json' \
                --output ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER} \
                --render "$:/core/save/all" "newindex.html" "text/plain"
            [[ -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html ]] \
                && cp ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
                && rm ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html \
                || echo "ERROR - CANNOT IMPORT ${FPLAYER^^}.json - ERROR"

            if [[ $ORIGINH != $INSIDEH && $ORIGINH != "" ]]; then
                echo "ORIGINH Update"
                rm -f ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html
                tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
                    --import ${HOME}/.zen/tmp/${MOATS}/${FPLAYER}.json 'application/json' \
                    --output ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER} \
                    --render "$:/core/save/all" "newindex.html" "text/plain"
                [[ -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html ]] \
                    && cp ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
                    && rm ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html \
                    || echo "ERROR - CANNOT IMPORT ${FPLAYER}.json - ERROR"
            fi

        fi

    done
    ## GET $:/moa Tiddlers ####################################### END

    ################## PREPARE LIST TO INSERT IN SECTORTW_NEWS TID
    echo "${UPLAYERSTIDS[@]}"

    ######################################
    # (RE)MAKE "SECTORTW_NEWS" TIDDLER
    sed -E \
        -e "s~_SECTOR_~${SECTOR}~g" \
        -e "s~_MOATS_~${MOATS}~g" \
        -e "s~_UPLANET_~https://qo-op.com~g" \
        -e "s~_UPLAYERSTIDS_~${UPLAYERSTIDS[*]}~" \
        -e "s~_SECTORTW_~${SECTORIPNS}/TW~g" \
        ${MY_PATH}/../templates/data/SECTORTW_NEWS.json > ~/.zen/tmp/${MOATS}/SECTORTW_NEWS.json


    echo "SECTORTW_NEWS $SECTOR SECTORTW=${SECTORIPNS}/TW :: ~/.zen/tmp/${MOATS}/SECTORTW_NEWS.json"
    ${MY_PATH}/TW/delete_tiddler.sh \
        ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
        "${SECTOR}.NEWS"
    ${MY_PATH}/TW/import_tiddler.sh \
        ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
        ~/.zen/tmp/${MOATS}/SECTORTW_NEWS.json

    #############################################################
    # Connect_PLAYER_To_Gchange.sh : Sync FRIENDS TW - TODO : REWRITE
    ######################################### BETTER USE json FILE IN /ipns/$IPFSNODEID/COINS
    #~ echo "##################################################################"

    [[ -s ~/.zen/tmp/coucou/${G1PUB}.gchange.json ]]  \
        && echo "## Connect_PLAYER_To_Gchange.sh  (★★★★★)" \
        && ${MY_PATH}/../tools/Connect_PLAYER_To_Gchange.sh "${PLAYER}" \
        || echo "NO Gchange account found"

    ##############################################################
    # G1PalPay - 2 G1 mini -> Check for G1 TX incoming comments #
    ##############################################################
    if [[ $(echo "$COINS >= 2" | bc -l) -eq 1 ]]; then
        ##############################################################
        # G1PalPay.sh # WALLET TX/RX MONITORING
        ##############################################################
        echo "## RUNNING G1PalPay Wallet Monitoring "
        ${MY_PATH}/G1PalPay.sh ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html "${PLAYER}"

        ##############################################################
        # VOEUX.create.sh # TAG=voeu SUB KEY CREATION
        ##############################################################
        ${MY_PATH}/VOEUX.create.sh ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html "${PLAYER}" "${G1PUB}"

        ##############################################################
        # VOEUX.refresh.sh # "G1Voeu" SUB RSS MERGINGS
        ##############################################################
        ${MY_PATH}/VOEUX.refresh.sh "${PLAYER}" "${MOATS}" ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html

    else
        echo "> ZenCard not activated ($ZEN ZEN)"
    fi

    ##################################
    ## PATCH : RESTORE PLAYER GPS.json (protect cache erased by WISH treatment)
    cp -f ~/.zen/game/players/${PLAYER}/GPS.json ~/.zen/tmp/${MOATS}/
    ## WRITE TIDDLERS IN TW SECTORTW_NEWS.json
    tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
                --import ~/.zen/tmp/${MOATS}/SECTORTW_NEWS.json "application/json" \
                --import ~/.zen/tmp/${MOATS}/GPS.json "application/json" \
                --import ~/.zen/tmp/${MOATS}/VISIO.json "application/json" \
                --output ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER} --render "$:/core/save/all" "newindex.html" "text/plain"

    ## CHECK IT IS OK
    [[ -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html ]] \
        && cp ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
        && rm ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html \
        && echo "TW UPlanet tiddlers updated" \
        || echo "ERROR - CANNOT CREATE TW NEWINDEX - ERROR"
    ###########################

    ########################
    ## SEND TODAY ZINE
    #### UPlanetZINE/day${days}/index.${lang}.html
    TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day${days}/index.${lang}.html"
    [[ ! -s ${TODAYZINE} ]] && TODAYZINE="${MY_PATH}/../templates/UPlanetZINE/day${days}/index.html"
    if [[ -s ${TODAYZINE} && ${days} -gt 0 ]]; then
        echo "SENDING TODAYZINE DAY ${days} + mailjet TW import "
        cat ${TODAYZINE} \
            | sed -e "s~_MOATS_~${MOATS}~g" \
                -e "s~_PLAYER_~${PLAYER}~g" \
                -e "s~_G1PUB_~${G1PUB}~g" \
                -e "s~_ASTRONAUTENS_~${ASTRONAUTENS}~g" \
                -e "s~_ASTRODID_~${ipns2did:1}~g" \
                -e "s~0448~${PASS}~g" \
                -e "s~_UPLANET8_~UPlanet:${UPLANETG1PUB:0:8}~g" \
                -e "s~_SALT_~${SALT}~g" \
                -e "s~_PEPPER_~${PEPPER}~g" \
                -e "s~_IPFSNODEID_~${IPFSNODEID}~g" \
                -e "s~_EARTHCID_~/ipns/copylaradio.com~g" \
                -e "s~_SECTOR_~${SECTOR}~g" \
                -e "s~_SLAT_~${SLAT}~g" \
                -e "s~_SLON_~${SLON}~g" \
                -e "s~qo-op.com~${myHOST}~g" \
                > ~/.zen/tmp/${MOATS}/UPlanetZine.html

        ${MY_PATH}/../tools/mailjet.sh "${PLAYER}" $HOME/.zen/tmp/${MOATS}/UPlanetZine.html \
                                        "ZINE #${days}" "${HOME}/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html"

    else
        echo "NO ZINE FOR DAY ${days}"
    fi
    ####################
    ## TW NEWINDEX .... #####
    ##############################################################
    echo "LOCAL BACKUP + MICROLEDGER TW"
    cp ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

    [[ -s ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain ]] \
    && ZCHAIN=$(cat ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain) \
    && echo "# CHAIN : ${CURCHAIN} -> ${ZCHAIN}" \
    && [[ ${CURCHAIN} != "" && ${ZCHAIN} != "" ]]  \
    && sed -i "s~${CURCHAIN}~${ZCHAIN}~g" ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

    ##################################################
    ######## UPDATING ${PLAYER}/ipfs/moa/.chain
    echo ${MOATS} > ~/.zen/game/players/${PLAYER}/ipfs/moa/.moats
    cp ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain \
       ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain.$(cat ~/.zen/game/players/${PLAYER}/ipfs/moa/.moats)

    ## CLEAN .chain CACHE
    find  ~/.zen/game/players/${PLAYER}/ipfs/moa/ -mtime +30 -type f -exec rm -f '{}' \;

    ##########################################
    ## TW IPFS ADD & PUBLISH
    ##########################################
    if [[ ! -f ~/.zen/tmp/${MOATS}/AstroID.json ]]; then
        TW=$(ipfs add -Hq ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html | tail -n 1)
        ipfs --timeout 720s name publish --key=${PLAYER} /ipfs/${TW}

        ## LOCAL PLAYER CACHING
        echo ${TW} > ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain
        echo "================================================"
        echo " NEW TW ${PLAYER} : =  ${myIPFS}/ipfs/${TW}"
        echo "  $myIPFSGW/ipns/${ASTRONAUTENS}"
        echo "================================================"
        ipfs pin rm ${CURCHAIN}
    fi ## Avoid AstroID in TW history chain

    #########################################################
    ##### TW JSON RSS EXPORT
    ###################
    # REFRESH PLAYER_feed KEY
    echo "(☉_☉ ) (☉_☉ ) (☉_☉ ) RSS"

    #########################################################################################
    ## CREATING 30 DAYS JSON RSS STREAM
    # [days:created[-30]!is[system]!tag[G1Voeu]!externalTiddler[yes]!tag[load-external]]
    #########################################################################################
    tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
        --output ~/.zen/game/players/${PLAYER}/ipfs \
        --render '.' "${PLAYER}.rss.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[days:created[-30]!is[system]!tag[G1Voeu]!externalTiddler[yes]!tag[load-external]!tag[ToDelete]!tag[UPlanet]]'

    [[ ! -s ~/.zen/game/players/${PLAYER}/ipfs/${PLAYER}.rss.json ]] \
        && echo "NO ${PLAYER} RSS - BAD "

    echo "~/.zen/game/players/${PLAYER}/ipfs/${PLAYER}.rss.json"

    ########################################################
    #### PLAYER ACCOUNT HAVE NEW TIDDLER or NOT #########
    if [[ $(cat ~/.zen/game/players/${PLAYER}/ipfs/${PLAYER}.rss.json) == "[]" && "${CURRENT}" != "${PLAYER}" ]]; then
        echo "ALERT -- RSS IS EMPTY -- COINS=$COINS / ZEN=$ZEN -- $days DAYS"
        ## DEAD PLAYER ??
        if [[ ${days} -eq 27 ]]; then
            echo "<html><head><meta charset='UTF-8'>
            <style>
                body {
                    font-family: 'Courier New', monospace;
                }
                pre {
                    white-space: pre-wrap;
                }
            </style></head><body><h1>🔋WARNING</h1>" > ~/.zen/tmp/alert
            echo "<br><h3><a href=$(myIpfsGw)/ipfs/${CURCHAIN}> ${PLAYER} TW 🔌📺 </a></h3> 🌥 $ZEN ZEN 🌥 </body></html>" >> ~/.zen/tmp/alert

            ${MY_PATH}/../tools/mailjet.sh "${PLAYER}" ~/.zen/tmp/alert "TW ZEN ALERT"
            echo "<<<< PLAYER TW WARNING <<<< ${DIFF_SECONDS} > ${days} days"
        fi

    else

        ## PUBLISH RSS FEED
        mkdir -p ~/.zen/tmp/${MOATS}/${PLAYER}.rss

        cp ~/.zen/game/players/${PLAYER}/ipfs/${PLAYER}.rss.json \
            ~/.zen/tmp/${MOATS}/${PLAYER}.rss/rss.json
        cp ~/.zen/tmp/coucou/${G1PUB}.gchange.json ~/.zen/tmp/${MOATS}/${PLAYER}.rss/gchange.json 2>/dev/null
        cp ~/.zen/tmp/coucou/${G1PUB}.cesium.json ~/.zen/tmp/${MOATS}/${PLAYER}.rss/cesium.json 2>/dev/null
        # cp -f ${HOME}/.zen/game/players/${PLAYER}/G1*/*.json ~/.zen/tmp/${MOATS}/${PLAYER}.rss/ ## POPULATE WISH RESULTS

        ### PLAYER ALIVE PUBLISH RSS &
        FEEDNS=$(ipfs key list -l | grep -w "${PLAYER}_feed" | cut -d ' ' -f 1)
        [[ ! -z ${FEEDNS} ]] \
            && IRSS=$(ipfs add --pin=false -wq ~/.zen/tmp/${MOATS}/${PLAYER}.rss/*.json | tail -n 1) \
            && echo "Publishing ${PLAYER}_feed: /ipns/${FEEDNS} => /ipfs/${IRSS}" \
            && ipfs --timeout 300s name publish --key="${PLAYER}_feed" /ipfs/${IRSS} \
            || echo ">>>>> WARNING ${PLAYER}_feed IPNS KEY PUBLISHING CUT - WARNING"
    fi

    echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipfs/${IRSS}'\" />${PLAYER}" \
                > ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}.feed.html

    ######################################################
    ## Transfer NOSTR Card HEX : SHOW HEX - done in TW export
    #~ cat ~/.zen/game/nostr/${PLAYER}/HEX 2>/dev/null \
        #~ > ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}.hex

    ######################### REPLACE TW with REDIRECT to latest IPFS or IPNS (reduce 12345 cache size)
    [[ ! -z ${TW} ]] && TWLNK="/ipfs/${TW}" || TWLNK="/ipns/${ASTRONAUTENS}"
    echo "<meta http-equiv=\"refresh\" content=\"0; url='${TWLNK}'\" />${PLAYER}" \
                > ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html

    #################################################
    ################### COPY DATA TO UP LEVEL GRIDS
    #################################################
    ## SECTOR BANK COORD
    SLAT="${LAT::-1}"
    SLON="${LON::-1}"
    ## REGION
    RLAT=$(echo ${LAT} | cut -d '.' -f 1)
    RLON=$(echo ${LON} | cut -d '.' -f 1)

    echo "(⌐■_■) /UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}"
    ## IPFSNODEID 12345 CACHE UPLANET/__/_*_*/_*.?_*.?/_*.??_*.??
    mkdir -p ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/RSS/

    cp ~/.zen/game/players/${PLAYER}/ipfs/${PLAYER}.rss.json \
            ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/RSS/
    #### CREATE ALL JSON COMPILATION
    ${MY_PATH}/../tools/json_dir.all.sh \
        ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/RSS

    ## IPFS PLAYER TW #
    mkdir -p ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/TW/${PLAYER}
    # /ipfs/${TW} = /TW/${PLAYER}/index.html
    echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipfs/${TW}'\" />${TODATE}:${PLAYER}" \
            > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/TW/${PLAYER}/index.html
    # /ipns/${ASTRONAUTENS} = /TW/${PLAYER}/_index.html
    echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipns/${ASTRONAUTENS}'\" />${PLAYER}" \
            > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/TW/${PLAYER}/_index.html
    ## IPNS UMAP _index.html ##
    echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipns/${UMAPNS}'\" />${TODATE}:_${LAT}_${LON}" \
            > ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/_index.html

    ls -al ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON} 2>/dev/null
    echo "(☉_☉ ) (☉_☉ ) (☉_☉ )"

    #####################################################################
    ## DAY=1 : CONTROL ${G1LEVEL1} G1 SENT to PLAYER
    if [[ -s ~/.ipfs/swarm.key ]]; then
        if [[ $(echo "$COINS < ${G1LEVEL1}" | bc -l) -eq 1 ]]; then
            [[ ${days} -eq 1 && "${CURRENT}" != "${PLAYER}" && "${CURRENT}" != "" ]] \
                && echo "1 DAY. ZENCARD  PRIMAL RX .SOCIETY" \
                && ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/${MOATS}.key "${UPLANETNAME}.SOCIETY" "${UPLANETNAME}.SOCIETY" \
                && ${MY_PATH}/../tools/PAYforSURE.sh "${HOME}/.zen/tmp/${MOATS}/${MOATS}.key" "${G1LEVEL1}" "${G1PUB}" "UPLANET:${UPLANETG1PUB:0:8}:${YOUSER}:ZENCARD:INIT2" 2>/dev/null \
                && echo "UPLANET:${UPLANETG1PUB:0:8}:${YOUSER}:ZENCARD:INIT2" && echo "(⌐■_■) ~~~ OFFICIAL ~~ _${LAT}_${LON} ~~~ $ASTRONAUTENS" \
                && rm ~/.zen/tmp/${MOATS}/${MOATS}.key
        fi
    fi

        #####################################################################
            #####################################################################

    ## MAINTAIN R/RW TW STATE
    [[ ${ASTRONS} == "" ]] \
    && echo "${PLAYER} DISCONNECT" \
    && ipfs key rm ${PLAYER} \
    && ipfs key rm ${PLAYER}_feed \
    && ipfs key rm ${G1PUB}

    ## CLEANING CACHE
    rm -Rf ~/.zen/tmp/${MOATS}
    echo

    end=`date +%s`
    dur=`expr $end - $start`
    echo "${PLAYER} refreshing took $dur seconds (${MOATS})"

done
echo "============================================ PLAYER.refresh DONE."


exit 0
