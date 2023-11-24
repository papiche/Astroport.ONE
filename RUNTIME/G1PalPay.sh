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

echo "(✜‿‿✜) G1PalPay : Receiving & Relaying payments to emails found in comment"
echo "$ME RUNNING"

########################################################################
# PALPAY SERVICE
########################################################################
########################################################################
INDEX="$1"
[[ ! ${INDEX} ]] && INDEX="$HOME/.zen/game/players/.current/ipfs/moa/index.html"
[[ ! -s ${INDEX} ]] && echo "ERROR - Please provide path to source TW index.html" && exit 1
[[ ! -s ${INDEX} ]] && echo "ERROR - Fichier TW absent. ${INDEX}" && exit 1

PLAYER="$2"
[[ ! ${PLAYER} ]] && PLAYER="$(cat ~/.zen/game/players/.current/.player 2>/dev/null)"
[[ ! ${PLAYER} ]] && echo "ERROR - Please provide PLAYER" && exit 1

ASTRONAUTENS=$(ipfs key list -l | grep -w ${PLAYER} | cut -d ' ' -f1)
[[ ! ${ASTRONAUTENS} ]] && echo "ERROR - Clef IPNS ${PLAYER} introuvable!"  && exit 1

G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub)
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
echo "=========== ( ◕‿◕) (◕‿◕ ) =============="

# CHECK LAST 10 INCOMING PAYMENTS
~/.zen/Astroport.ONE/tools/timeout.sh -t 12 \
${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey history -n 10 -j > $HOME/.zen/game/players/${PLAYER}/G1PalPay/$PLAYER.history.json

[[ ! -s $HOME/.zen/game/players/${PLAYER}/G1PalPay/$PLAYER.history.json ]] \
&& echo "NO PAYMENT HISTORY" \
&& exit 1
##############################
##########################################################
############# CHECK FOR N1COMMANDs IN PAYMENT COMMENT
#################################################################

## TREAT ANY COMMENT STARTING WITH N1
cat $HOME/.zen/game/players/${PLAYER}/G1PalPay/$PLAYER.history.json | jq -rc .[] | grep 'N1' > ~/.zen/tmp/${MOATS}/myN1.json

while read NLINE; do
    ## COMMENT FORMAT = N1$CMD:$TH:$TRAIL
    IDATE=$(echo ${NLINE} | jq -r .date)
    IPUBKEY=$(echo ${NLINE} | jq -r .pubkey)

    COMMENT=$(echo ${NLINE} | jq -r .comment)
    CMD=$(echo ${COMMENT} | cut -d ':' -f 1 | cut -c -12 ) # Maximum 12 characters CMD

    [[ $(cat ~/.zen/game/players/${PLAYER}/.ndate) -ge $IDATE ]]  && echo "$CMD $IDATE from $IPUBKEY ALREADY TREATED - continue" && continue

    TH=$(echo ${COMMENT} | cut -d ':' -f 2)
    TRAIL=$(echo ${COMMENT} | cut -d ':' -f 3-)

    if [[ -s ${MY_PATH}/../ASTROBOT/${CMD}.sh ]]; then

        echo "RECEIVED CMD=${CMD} from ${IPUBKEY}"
        ${MY_PATH}/../ASTROBOT/${CMD}.sh ${INDEX} ${PLAYER} ${MOATS} ${IPUBKEY} ${TH} ${TRAIL}
        ## WELL DONE .
        [[ $? == 0 ]] && echo "${CMD} DONE" && echo "$IDATE" > ~/.zen/game/players/${PLAYER}/.ndate ## MEMORIZE LAST IDATE

    else

        echo "NOT A N1 COMMAND ${COMMENT}"

    fi

done < ~/.zen/tmp/${MOATS}/myN1.json

########################################################################################
############# CHECK FOR EMAILs IN PAYMENT COMMENT
## DEBUG ## cat $HOME/.zen/game/players/${PLAYER}/G1PalPay/$PLAYER.history.json | jq -r
#################################################################

# IF COMMENT CONTAINS EMAIL ADDRESSES
# SPREAD & TRANSFER AMOUNT TO NEXT (REMOVING IT FROM LIST)... Other G1PalPay will continue the transmission...
########################################################################
# this could lead in several account creation sharing % of incomes each time

cat $HOME/.zen/game/players/${PLAYER}/G1PalPay/$PLAYER.history.json | jq -rc .[] | grep '@' > ~/.zen/tmp/${MOATS}/myPalPay.json

## GET @ in JSON INLINE
while read LINE; do

    echo "MATCHING IN COMMENT"
    echo "${LINE}"
    JSON=${LINE}
    IDATE=$(echo $JSON | jq -r .date)
    IPUBKEY=$(echo $JSON | jq -r .pubkey)
    IAMOUNT=$(echo $JSON | jq -r .amount)
    IAMOUNTUD=$(echo $JSON | jq -r .amountUD)
    COMMENT=$(echo $JSON | jq -r .comment)

    echo ">>> TODO CHECK TX HAPPENS LAST 24H (WHAT IS IDATE=$IDATE FORMAT ??)"
    [[ $(cat ~/.zen/game/players/${PLAYER}/.atdate) -ge $IDATE ]]  && echo "PalPay $IDATE from $IPUBKEY ALREADY TREATED - continue" && continue

    ## GET EMAILS FROM COMMENT
    ICOMMENT=($(echo "$COMMENT" | grep -E -o "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b"))

    ## DIVIDE INCOMING AMOUNT TO SHARE
    echo "N=${#ICOMMENT[@]}"
    N=${#ICOMMENT[@]}
    SHARE=$(echo "scale=2; $IAMOUNT / $N" | bc)

    echo $IDATE $IPUBKEY $IAMOUNT [$IAMOUNTUD] $ICOMMENT % $SHARE %

    for EMAIL in "${ICOMMENT[@]}"; do

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
        && echo "SORRY ${EMAIL} MISSING ASTROG1" \
        && echo " BRO.  $PLAYER  VEUX VOUS OFFRIR ${SHARE} G1 \n Inscrivez-vous sur UPlanet https://qo-op.com/" > ~/.zen/tmp/palpay.bro \
        && ${MY_PATH}/../tools/mailjet.sh "${EMAIL}" ~/.zen/tmp/palpay.bro \
        && continue


        ## MAKE FRIENDS & SEND G1
        echo "NEW PalPay Friend $ASTROMAIL
        TW : $ASTROTW
        G1 : ${ASTROG1}
        ASTROIPFS : $ASTROIPFS
        RSS : $ASTROFEED"

        if [[ ${ASTROG1} != ${G1PUB} ]]; then

            ~/.zen/Astroport.ONE/tools/timeout.sh -t 12 \
            ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey pay -a ${SHARE} -p ${ASTROG1} -c "G1PalPay:$N:$IPUBKEY" -m > /dev/null 2>&1
            STAMP=$?

        else

            STAMP=0

        fi

        ## DONE STAMP IT
        [[ $STAMP == 0 ]] && echo "STAMP DONE" && echo "$IDATE" > ~/.zen/game/players/${PLAYER}/.atdate ## MEMORIZE LAST IDATE

    done

done < ~/.zen/tmp/${MOATS}/myPalPay.json

echo "=========== %%%%% (°▃▃°) %%%%%%% =============="

########################################################################################
## SEARCH FOR TODAY MODIFIED TIDDLERS WITH MULTIPLE EMAILS IN TAG
#################################################################
echo "# EXTRACT TODAY TIDDLERS"
tiddlywiki --load ${INDEX} \
                 --output ~/.zen/game/players/${PLAYER}/G1CopierYoutube/${G1PUB}/ \
                 --render '.' "today.${PLAYER}.tiddlers.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[days:created[-1]]'

## FILTER MY OWN EMAIL
# cat ~/.zen/game/players/${PLAYER}/G1CopierYoutube/${G1PUB}/today.${PLAYER}.tiddlers.json | jq -rc  # LOG

cat ~/.zen/game/players/${PLAYER}/G1CopierYoutube/${G1PUB}/today.${PLAYER}.tiddlers.json \
        | sed "s~${PLAYER}~ ~g" | jq -rc '.[] | select(.tags | contains("@"))' > ~/.zen/tmp/${MOATS}/@tags.json 2>/dev/null ## REMOVE PLAYER EMAIL IN INLINE JSON

[[ ! -s ~/.zen/tmp/${MOATS}/@tags.json ]] && echo "NO EXTRA @tags.json TIDDLERS TODAY" && exit 0

# LOG
cat ~/.zen/tmp/${MOATS}/@tags.json

echo "******************TIDDLERS with EMAIL in TAGS treatment"
#~ cat ~/.zen/game/players/${PLAYER}/G1CopierYoutube/${G1PUB}/${PLAYER}.tiddlers.json | sed "s~${PLAYER}~ ~g" | jq -rc '.[] | select(.tags | contains("@"))' > ~/.zen/tmp/${MOATS}/@tags.json

## EXTRACT NOT MY EMAIL
while read LINE; do

    echo "---------------------------------- PalPé mec"
    echo "${LINE}"
    echo "---------------------------------- PalPAY for Tiddler"
    TCREATED=$(echo ${LINE} | jq -r .created)
    TTITLE=$(echo ${LINE} | jq -r .title)
    TTAGS=$(echo ${LINE} | jq -r .tags)
    TOPIN=$(echo ${LINE} | jq -r .ipfs) ## Tiddler produced by "Astroport Desktop"
    [[ -z ${TOPIN} ]] && TOPIN=$(echo ${LINE} | jq -r ._canonical_uri) ## Tiddler is exported to IPFS

    echo "$TTITLE"

    ## Count emails found
    emails=($(echo "$TTAGS" | grep -E -o "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b"))
    nb=${#emails[@]}
    zen=$(echo "scale=2; $nb / 10" | bc) ## / divide by 10

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
        ~/.zen/Astroport.ONE/tools/timeout.sh -t 12 \
        ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey pay -a ${zen} -p ${ASTROG1} -c "${emails[@]} $TTITLE" -m > /dev/null 2>&1
                                                                                                                                                                        ## Filling comment with email list will make players resend to all ## MAY BE A BAD IDEA ###
        echo "OK PalPay : $MSG" > ~/.zen/tmp/${MOATS}/g1message
        ## PINNING IPFS MEDIA - PROOF OF COPY SYSTEM -
        [[ ! -z $TOPIN ]] && ipfs pin add $TOPIN &&  echo "PINNING $TOPIN" >> ~/.zen/tmp/${MOATS}/g1message

        ${MY_PATH}/../tools/mailjet.sh "${PLAYER}" ~/.zen/tmp/${MOATS}/g1message


    else

        echo "ERREUR PalPay : ${TTITLE} : IMPOSSIBLE DE TROUVER ${emails[@]}"  > ~/.zen/tmp/${MOATS}/g1message
        ${MY_PATH}/../tools/mailjet.sh "${PLAYER}" ~/.zen/tmp/${MOATS}/g1message
        echo "NO ACCOUNT FOUND"

    fi


done < ~/.zen/tmp/${MOATS}/@tags.json

echo "=========== ( ◕‿◕)  (◕‿◕ ) =============="

rm -Rf $HOME/.zen/tmp/${MOATS}

exit 0
