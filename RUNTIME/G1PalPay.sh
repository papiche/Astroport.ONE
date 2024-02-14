#!/bin/bash
########################################################################
# Version: 0.5
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# PAD COCODING : https://pad.p2p.legal/s/G1PalPay
# This script monitors G1 Blockchain
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/../tools/my.sh"

CESIUM=${myCESIUM}
GCHANGE=${myGCHANGE}

echo "$ME RUNNING"

########################################################################
# PALPAY SERVICE : MONITOR INCOMING TX & NEW TIDDLERS
########################################################################
########################################################################
INDEX="$1"  ## TW file
[[ ! ${INDEX} ]] && INDEX="$HOME/.zen/game/players/.current/ipfs/moa/index.html"
[[ ! -s ${INDEX} ]] && echo "ERROR - Please provide path to source TW index.html" && exit 1
[[ ! -s ${INDEX} ]] && echo "ERROR - Fichier TW absent. ${INDEX}" && exit 1

PLAYER="$2" ## PLAYER
[[ ! ${PLAYER} ]] && PLAYER="$(cat ~/.zen/game/players/.current/.player 2>/dev/null)"
[[ ! ${PLAYER} ]] && echo "ERROR - Please provide PLAYER" && exit 1

ASTRONAUTENS=$(ipfs key list -l | grep -w ${PLAYER} | cut -d ' ' -f1) ## TW /ipns/
[[ ! ${ASTRONAUTENS} ]] && echo "ERROR - Clef IPNS ${PLAYER} introuvable!"  && exit 1

G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub) ## PLAYER WALLET
[[ ! $G1PUB ]] && echo "ERROR - G1PUB ${PLAYER} VIDE"  && exit 1

# Extract tag=tube from TW
MOATS="$3"
[[ ! ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

###################################################################
## CREATE APP NODE PLAYER PUBLICATION DIRECTORY
###################################################################
mkdir -p $HOME/.zen/tmp/${IPFSNODEID}/G1PalPay/${PLAYER}/
mkdir -p $HOME/.zen/game/players/${PLAYER}/G1PalPay/
mkdir -p $HOME/.zen/tmp/${MOATS}
echo "=========== ( ◕‿◕) (◕‿◕ ) ============== ${PLAYER}
${INDEX}"
echo "(✜‿‿✜) G1PalPay : CHECK LAST 10 TX comment"

# CHECK LAST 10 INCOMING PAYMENTS
~/.zen/Astroport.ONE/tools/timeout.sh -t 12 \
${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey history -n 10 -j > $HOME/.zen/game/players/${PLAYER}/G1PalPay/${PLAYER}.duniter.history.json

[[ ! -s $HOME/.zen/game/players/${PLAYER}/G1PalPay/${PLAYER}.duniter.history.json ]] \
&& echo "NO PAYMENT HISTORY.......................... EXIT" \
&& exit 1
##############################
##########################################################
############# CHECK FOR N1COMMANDs IN PAYMENT COMMENT
# TODO check amout > 0
#################################################################
cat $HOME/.zen/game/players/${PLAYER}/G1PalPay/${PLAYER}.duniter.history.json  | jq -rc .[]
## TREAT ANY COMMENT STARTING WITH N1:
## EXTRACT /ASTROBOT/N1ProgramNames
ls ${MY_PATH}/../ASTROBOT/ | grep "N1" | cut -d "." -f 1 > ~/.zen/tmp/${MOATS}/N1PROG

while read prog; do
    cat $HOME/.zen/game/players/${PLAYER}/G1PalPay/${PLAYER}.duniter.history.json | jq -rc .[] | grep "$prog" >> ~/.zen/tmp/${MOATS}/myN1.json
done < ~/.zen/tmp/${MOATS}/N1PROG

# got N1 incoming TX
while read NLINE; do
    ## COMMENT FORMAT = N1$CMD:$TH:$TRAIL
    TXIDATE=$(echo ${NLINE} | jq -r .date)
    TXIPUBKEY=$(echo ${NLINE} | jq -r .pubkey)

    COMMENT=$(echo ${NLINE} | jq -r .comment)
    CMD=$(echo ${COMMENT} | cut -d ':' -f 1 | cut -c -12 ) # Maximum 12 characters CMD

    # Verify last recorded acting date (avoid running twice)
    [[ $(cat ~/.zen/game/players/${PLAYER}/.ndate) -ge $TXIDATE ]]  \
        && echo "$CMD $TXIDATE from $TXIPUBKEY ALREADY TREATED - continue" \
        && continue

    TH=$(echo ${COMMENT} | cut -d ':' -f 2)
    TRAIL=$(echo ${COMMENT} | cut -d ':' -f 3-)

    if [[ -s ${MY_PATH}/../ASTROBOT/${CMD}.sh ]]; then

        echo "RECEIVED CMD=${CMD} from ${TXIPUBKEY}"
        ${MY_PATH}/../ASTROBOT/${CMD}.sh ${INDEX} ${PLAYER} ${MOATS} ${TXIPUBKEY} ${TH} ${TRAIL}
        ## WELL DONE .
        [[ $? == 0 ]] && echo "${CMD} DONE" && echo "$TXIDATE" > ~/.zen/game/players/${PLAYER}/.ndate ## MEMORIZE LAST TXIDATE

    else

        echo "NOT A N1 COMMAND ${COMMENT}"

    fi

done < ~/.zen/tmp/${MOATS}/myN1.json

########################################################################################
############# CHECK FOR EMAILs IN PAYMENT COMMENT
## DEBUG ## cat $HOME/.zen/game/players/${PLAYER}/G1PalPay/${PLAYER}.duniter.history.json | jq -r
#################################################################
cat $HOME/.zen/game/players/${PLAYER}/G1PalPay/${PLAYER}.duniter.history.json | jq -rc .[] | grep '@' > ~/.zen/tmp/${MOATS}/myPalPay.json

# IF COMMENT CONTAINS EMAIL ADDRESSES
# SPREAD & TRANSFER AMOUNT TO NEXT (REMOVING IT FROM LIST)... Other G1PalPay will continue the transmission...
########################################################################
## GET @ in JSON INLINE
while read LINE; do

    echo "MATCHING IN COMMENT"
    echo "${LINE}"
    JSON=${LINE}
    TXIDATE=$(echo $JSON | jq -r .date)
    TXIPUBKEY=$(echo $JSON | jq -r .pubkey)
    TXIAMOUNT=$(echo $JSON | jq -r .amount)
    TXIAMOUNTUD=$(echo $JSON | jq -r .amountUD)
    COMMENT=$(echo $JSON | jq -r .comment)

    echo ">>> TODO CHECK TX HAPPENS LAST 24H (WHAT IS TXIDATE=$TXIDATE FORMAT ??)"
    [[ $(cat ~/.zen/game/players/${PLAYER}/.atdate) -ge $TXIDATE ]]  \
        && echo "PalPay $TXIDATE from $TXIPUBKEY ALREADY TREATED - continue" \
        && continue

    ## GET EMAILS FROM COMMENT
    TXIMAILS=($(echo "$COMMENT" | grep -E -o "\b[a-zA-Z0-9.%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b"))

    ## DIVIDE INCOMING AMOUNT TO SHARE
    echo "N=${#TXIMAILS[@]}"
    N=${#TXIMAILS[@]}
    SHARE=$(echo "scale=2; $TXIAMOUNT / $N" | bc)
    ## SHARE is received AMOUT divided by numbers of EMAILS in comment

    echo "$TXIDATE $TXIPUBKEY $TXIAMOUNT [$TXIAMOUNTUD] $TXIMAILS % $SHARE %"

    # let's loop over TXIMAILS
    for EMAIL in "${TXIMAILS[@]}"; do

        [[ ${EMAIL} == $PLAYER ]] && echo "ME MYSELF" && continue

        echo "EMAIL : ${EMAIL}"
        ASTROTW="" STAMP="" ASTROG1="" ASTROIPFS="" ASTROFEED="" # RESET VAR
        $($MY_PATH/../tools/search_for_this_email_in_players.sh ${EMAIL}) ## export ASTROTW and more
        echo "export ASTROPORT=${ASTROPORT} ASTROTW=${ASTROTW} ASTROG1=${ASTROG1} ASTROMAIL=${EMAIL} ASTROFEED=${FEEDNS}"
        [[ ${ASTROTW} == "" ]] && ASTROTW=${ASTRONAUTENS}

        if [[ ! ${ASTROTW} ]]; then

            echo "# PLAYER INCONNU $(date)"

        fi

        [[ ! ${ASTROG1} ]] \
        && echo "<html><body><h1>SORRY ${EMAIL} YOUR ACCOUNT IS MISSING</h1>" \
        && echo " BRO.  $PLAYER  WISH TO SEND YOU SOME ẐEN <br><br>(♥‿‿♥)... Join <a href='https://qo-op.com'>UPlanet</a> to receive it</body></html>" > ~/.zen/tmp/palpay.bro \
        && ${MY_PATH}/../tools/mailjet.sh "${EMAIL}" ~/.zen/tmp/palpay.bro "MISSING ACCOUNT" \
        && continue


        ## MAKE FRIENDS & SEND G1
        echo "NEW PalPay Friend $ASTROMAIL
        TW : $ASTROTW
        G1 : ${ASTROG1}
        ASTROIPFS : $ASTROIPFS
        RSS : $ASTROFEED"

        if [[ ${ASTROG1} != ${G1PUB} ]]; then

            ${MY_PATH}/../tools/PAY4SURE.sh "${HOME}/.zen/game/players/${PLAYER}/secret.dunikey" "${SHARE}" "${ASTROG1}" "G1PalPay:$N:$TXIPUBKEY"
            STAMP=$?

        else

            STAMP=0

        fi

        ## DONE STAMP IT
        [[ $STAMP == 0 ]] && echo "STAMP DONE" && echo "$TXIDATE" > ~/.zen/game/players/${PLAYER}/.atdate ## MEMORIZE LAST TXIDATE

    done

done < ~/.zen/tmp/${MOATS}/myPalPay.json

echo "=========== %%%%% (°▃▃°) %%%%%%% =============="

########################################################################################
## SEARCH FOR TODAY MODIFIED TIDDLERS WITH MULTIPLE EMAILS IN TAG
#  This can could happen in case Tiddler is copied OR PLAYER manualy adds an email tag to Tiddler to share with someone...
#################################################################
echo "# EXTRACT TODAY TIDDLERS"
tiddlywiki --load ${INDEX} \
                 --output ~/.zen/game/players/${PLAYER}/G1CopierYoutube/${G1PUB}/ \
                 --render '.' "today.${PLAYER}.tiddlers.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[days:created[-2]]'

## FILTER MY OWN EMAIL
# cat ~/.zen/game/players/${PLAYER}/G1CopierYoutube/${G1PUB}/today.${PLAYER}.tiddlers.json | jq -rc  # LOG

cat ~/.zen/game/players/${PLAYER}/G1CopierYoutube/${G1PUB}/today.${PLAYER}.tiddlers.json \
        | sed "s~${PLAYER}~ ~g" | jq -rc '.[] | select(.tags | contains("@"))' \
         > ~/.zen/tmp/${MOATS}/@tags.json 2>/dev/null ## Get tiddlers with not my email in it

[[ ! -s ~/.zen/tmp/${MOATS}/@tags.json ]] \
    && echo "NO EXTRA @tags.json TIDDLERS TODAY" \
    && exit 0

# LOG
cat ~/.zen/tmp/${MOATS}/@tags.json
echo "******************TIDDLERS with new EMAIL in TAGS treatment"
#~ cat ~/.zen/game/players/${PLAYER}/G1CopierYoutube/${G1PUB}/${PLAYER}.tiddlers.json | sed "s~${PLAYER}~ ~g" | jq -rc '.[] | select(.tags | contains("@"))' > ~/.zen/tmp/${MOATS}/@tags.json

################################
## detect NOT MY EMAIL in TODAY TIDDLERS
################################
while read LINE; do

    echo "---------------------------------- Sava PalPé mec"
    echo "${LINE}"
    echo "---------------------------------- PalPAY for Tiddler"
    TCREATED=$(echo ${LINE} | jq -r .created)
    TTITLE=$(echo ${LINE} | jq -r .title)
    TTAGS=$(echo ${LINE} | jq -r .tags)

    ## PREPARE PINNING -
    TOPIN=$(echo ${LINE} | jq -r .ipfs) ## Tiddler produced by "Astroport Desktop"
    [[ -z ${TOPIN} ]] && TOPIN=$(echo ${LINE} | jq -r ._canonical_uri) ## Tiddler is exported to IPFS
    [[ ! $(echo ${TOPIN} | grep '/ipfs') ]] \
        && echo "NOT COMPATIBLE ${TOPIN}" \
        && TOPIN=""

    echo "$TTITLE"

    ## Count emails found
    emails=($(echo "$TTAGS" | grep -E -o "\b[a-zA-Z0-9.%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b"))
    nb=${#emails[@]}
    zen=$(echo "scale=2; $nb / 10" | bc) ## / divide by 10 = 1 Zen each

    ## Get first zmail
    ZMAIL="${emails}"

    MSG="SEND + $zen ZEN TO BROs : ${emails[@]}"
    echo $MSG

    ASTROTW="" STAMP="" ASTROG1="" ASTROIPFS="" ASTROFEED=""
    #### SEARCH FOR PALPAY ACOUNTS : USING PALPAY RELAY - COULD BE DONE BY A LOOP ?? §§§
    $($MY_PATH/../tools/search_for_this_email_in_players.sh ${ZMAIL}) ## export ASTROTW and more
    echo "export ASTROPORT=${ASTROPORT} ASTROTW=${ASTROTW} ASTROG1=${ASTROG1} ASTROMAIL=${EMAIL} ASTROFEED=${FEEDNS}"
    [[ ${ASTROTW} == "" ]] && ASTROTW=${ASTRONAUTENS}

    if [[ ${ASTROG1} && ${ASTROG1} != ${G1PUB} ]]; then

        ## SEND zen ZEN (G1 dice JUNE) TO ALL ## MAKE ONE EACH AFTER ALL EMAIL CONSUMED ##
        #~ ~/.zen/Astroport.ONE/tools/timeout.sh -t 12 \
        #~ ${MY_PATH}/../tools/PAY4SURE.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey pay -a ${zen} -p ${ASTROG1} -c "${emails[@]} $TTITLE" -m > /dev/null 2>&1
                                                                                                                                                                        ## Filling comment with email list will make players resend to all ## MAY BE A BAD IDEA ###
        echo ${LINE} > ~/.zen/tmp/${MOATS}/line
        LINEH=$(ipfs add -q ~/.zen/tmp/${MOATS}/line)
        ${MY_PATH}/../tools/PAY4SURE.sh "${HOME}/.zen/game/players/${PLAYER}/secret.dunikey" "${zen}" "${ASTROG1}" "${emails[@]} /ipfs/$LINEH"

        echo "<html><body><h1>BRO ${PLAYER}</h1> : $MSG" > ~/.zen/tmp/${MOATS}/g1message
        ## PINNING IPFS MEDIA - PROOF OF COPY SYSTEM -
        [[ ! -z $TOPIN ]] \
            && ipfs pin add $TOPIN \
            &&  echo "<h2>PINNING $TOPIN</h2>(☼‿‿☼)" >> ~/.zen/tmp/${MOATS}/g1message
            ## lazy mode... NOT FINISHING HTML TAGGING... browser shoud display html page ;)

        ${MY_PATH}/../tools/mailjet.sh "${PLAYER}" ~/.zen/tmp/${MOATS}/g1message "PIN TIDDLER"

    else

        ## SEND MESSAGE TO INFORM ${ZMAIL} OF THIS EXISTING TIDDLER
        echo "<html><body>
        <h1>BRO. </h1>
        <br>
        <a href='${myIPFSGW}'/ipns/${ASTROTW}>${PLAYER}</a> HAS SHARED A TIDDLER WITH YOU.
        <br><b>${TTITLE}</b><br>(✜‿‿✜)
        ... Join <a href='https://qo-op.com'>UPlanet</a> open a TW !
        </body></html>" > ~/.zen/tmp/palpay.bro

       ${MY_PATH}/../tools/mailjet.sh "${ZMAIL}" ~/.zen/tmp/palpay.bro "TIDDLER TW SHARING"

    fi


done < ~/.zen/tmp/${MOATS}/@tags.json

echo "=========== ( ◕‿◕)  (◕‿◕ ) =============="

rm -Rf $HOME/.zen/tmp/${MOATS}

exit 0
