#!/bin/bash
########################################################################
# Version: 0.5
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# PAD COCODING : https://pad.p2p.legal/s/G1PalPay
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/../tools/my.sh"

        CESIUM="https://g1.data.le-sou.org"
        GCHANGE="https://data.gchange.fr"

echo "(✜‿‿✜) G1PalPay : Receiving & Relaying payments to emails found in comment"
echo "$ME RUNNING"

########################################################################
# PALPAY SERVICE
########################################################################
# CHECK TODAY INCOMING PAYMENT
# IF COMMENT CONTAINS EMAIL ADDRESSES
# THEN CREATE VISA+TW AND SEND PAIMENT REMOVING FIRST FROM LIST
########################################################################
# this couls lead in several account creation sharing % of incomes each time
########################################################################

INDEX="$1"
[[ ! ${INDEX} ]] && INDEX="$HOME/.zen/game/players/.current/ipfs/moa/index.html"
[[ ! -s ${INDEX} ]] && echo "ERROR - Please provide path to source TW index.html" && exit 1
[[ ! -s ${INDEX} ]] && echo "ERROR - Fichier TW absent. ${INDEX}" && exit 1

PLAYER="$2"
[[ ! ${PLAYER} ]] && PLAYER="$(cat ~/.zen/game/players/.current/.player 2>/dev/null)"
[[ ! ${PLAYER} ]] && echo "ERROR - Please provide IPFS publish key" && exit 1

ASTONAUTENS=$(ipfs key list -l | grep -w ${PLAYER} | cut -d ' ' -f1)
[[ ! $ASTONAUTENS ]] && echo "ERROR - Clef IPNS ${PLAYER} introuvable!"  && exit 1

G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub)

# Extract tag=tube from TW
MOATS="$3"
[[ ! $MOATS ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

###################################################################
## CREATE APP NODE PLAYER PUBLICATION DIRECTORY
###################################################################
mkdir -p $HOME/.zen/tmp/${IPFSNODEID}/G1PalPay/${PLAYER}/
mkdir -p $HOME/.zen/game/players/${PLAYER}/G1PalPay/
mkdir -p $HOME/.zen/tmp/${MOATS}

~/.zen/Astroport.ONE/tools/timeout.sh -t 12 \
${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey history -n 10 -j > $HOME/.zen/game/players/${PLAYER}/G1PalPay/$PLAYER.history.json

[[ ! -s $HOME/.zen/game/players/${PLAYER}/G1PalPay/$PLAYER.history.json ]] \
&& echo "NO PAYMENT HISTORY" \
&& exit 1

## DEBUG ## cat $HOME/.zen/game/players/${PLAYER}/G1PalPay/$PLAYER.history.json | jq -r
cat $HOME/.zen/game/players/${PLAYER}/G1PalPay/$PLAYER.history.json | jq -rc .[] | grep '@' > ~/.zen/tmp/${MOATS}/myPalPay.json

## GET @ in JSON INLINE
while read LINE; do

    echo "MATCHING IN COMMENT"
    JSON=$LINE
    IDATE=$(echo $JSON | jq -r .date)
    IPUBKEY=$(echo $JSON | jq -r .pubkey)
    IAMOUNT=$(echo $JSON | jq -r .amount)
    IAMOUNTUD=$(echo $JSON | jq -r .amountUD)
    COMMENT=$(echo $JSON | jq -r .comment)

    [[ $(cat ~/.zen/game/players/${PLAYER}/.idate) -ge $IDATE ]]  && echo "DONE OLD EVENT"&& continue

    ICOMMENT=($COMMENT)
    ## IF MULTIPLE WORDS OR EMAILS : DIVIDE INCOMING AMOUNT TO SHARE
    echo "N=${#ICOMMENT[@]}"
    N=${#ICOMMENT[@]}
    SHARE=$(echo "$IAMOUNT/$N" | bc -l | cut -d '.' -f 1) ## INTEGER ROUNDED VALUE

    echo $IDATE $IPUBKEY $IAMOUNT [$IAMOUNTUD] $ICOMMENT % $SHARE %

    for EMAIL in "${ICOMMENT[@]}"; do

        if [[ "${EMAIL}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]; then
            echo "VALID EMAIL : ${EMAIL}"
            ASTROTW="" STAMP="" ASTROG1="" ASTROIPFS="" ASTROFEED=""

            $($MY_PATH/../tools/search_for_this_email_in_players.sh ${EMAIL}) ## export ASTROTW and more

            if [[ ! ${ASTROTW} ]]; then

                echo "# NEW VISA $(date)"
                SALT="" && PEPPER=""
                echo "VISA.new : \"$SALT\" \"$PEPPER\" \"${EMAIL}\" \"$PSEUDO\" \"${URL}\""
                ## $(${MY_PATH}/../tools/VISA.new.sh "$SALT" "$PEPPER" "${EMAIL}" "$PSEUDO" "${URL}" | tail -n 1) # export ASTROTW=/ipns/$ASTRONAUTENS ASTROG1=$G1PUB ASTROMAIL=$EMAIL ASTROFEED=$FEEDNS

                ## CREATE new PLAYER IN myASTROTUBE
                echo "${myASTROTUBE}/?salt=0&pepper=0&g1pub=_URL_&email=${EMAIL}"
                curl -so ~/.zen/tmp/${MOATS}/astro.port "${myASTROTUBE}/?salt=0&pepper=0&g1pub=_URL_&email=${EMAIL}"

                TELETUBE=$(cat ~/.zen/tmp/${MOATS}/astro.port | grep "(◕‿‿◕)" | cut -d ':' -f 2 | cut -d '/' -f 3)
                TELEPORT=$(cat ~/.zen/tmp/${MOATS}/astro.port | grep "(◕‿‿◕)" | cut -d ':' -f 3 | cut -d '"' -f 1)
                sleep 12

                curl -so ~/.zen/tmp/${MOATS}/astro.rep "http://$TELETUBE:$TELEPORT"
                $(cat ~/.zen/tmp/${MOATS}/astro.rep | tail -n 1) ## SOURCE LAST LINE (SEE SALT PEPPER EMAIL API RETURN)

                ######################################################

                ${MY_PATH}/../tools/mailjet.sh "${EMAIL}" "BRO. $PLAYER  VOUS OFFRE CE TW : $(myIpfsGw)/$ASTROTW" ## WELCOME NEW PLAYER


            fi

            ## MAKE FRIENDS & SEND G1
            echo "Hello PalPay Friend $ASTROMAIL
            TW : $ASTROTW
            G1 : $ASTROG1
            ASTROIPFS : $ASTROIPFS
            RSS : $ASTROFEED"

            [[ ! $ASTROG1 ]] \
            && echo "MISSING ASTROG1" \
            && continue

            if [[ ${ASTROG1} != ${G1PUB} ]]; then
                ~/.zen/Astroport.ONE/tools/timeout.sh -t 12 \
                ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey pay -a ${SHARE} -p ${ASTROG1} -c "PalPay:$N:$IPUBKEY" -m 2>&1
                STAMP=$?
            else
                STAMP=0
            fi
            ## COULD SEND STARS ??

        else
                echo "BAD EMAIL : ${EMAIL}"
                continue
        fi

        ## DONE STAMP IT
        [[ $STAMP == 0 ]] && echo "$IDATE" > ~/.zen/game/players/${PLAYER}/.idate

    done

done < ~/.zen/tmp/${MOATS}/myPalPay.json


### NEXT #####
### INNER TIDDLERS TREATMENT
## SEARCH FOR NEW TIDDLERS WITH MULTIPLE EMAILS IN TAG
## SEND 1 JUNE DIVIDED INTO ALL

rm -Rf $HOME/.zen/tmp/${MOATS}

exit 0
