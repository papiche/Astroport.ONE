################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
## API: SALT & PEPPER
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"

HTTPCORS="HTTP/1.1 200 OK
Access-Control-Allow-Origin: ${myASTROPORT}
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET
Server: Astroport.ONE
Content-Type: text/html; charset=UTF-8

"

start=`date +%s`

PORT=$1 THAT=$2 AND=$3 THIS=$4  APPNAME=$5 WHAT=$6 OBJ=$7 VAL=$8 MOATS=$9

PORT=$1 PLAYER=$2 APPNAME=$3 WHAT=$4  OBJ=$5 VAL=$6

        echo "- $PLAYER - $APPNAME : $WHAT $OBJ $VAL"

        ASTRONAUTENS=$(ipfs key list -l | grep -w $PLAYER | cut -d ' ' -f1)
        [[ ! $ASTRONAUTENS ]] && (echo "$HTTPCORS UNKNOWN PLAYER $PLAYER - EXIT" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 1

##############################################
# PAY : /?player=PLAYER&pay=1&dest=G1PUB
##############################################
        if [[ $APPNAME == "pay" ]]; then
            echo "$HTTPCORS" > ~/.zen/tmp/$PLAYER.pay.$WHAT.http

            if [[ $WHAT =~ ^[0-9]+$ ]]; then

                echo "${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey pay -a ${WHAT} -p ${VAL} -c 'Bro' -m"
                ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey pay -a ${WHAT} -p ${VAL} -c 'Bro' -m 2>&1 >> ~/.zen/tmp/$PLAYER.pay.$WHAT.http

            fi

            if [[ "$WHAT" == "history" ]]; then
                sed -i "s~text/html~application/json~g"  ~/.zen/tmp/$PLAYER.pay.$WHAT.http
                ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey history -j >> ~/.zen/tmp/$PLAYER.pay.$WHAT.http
            fi

            if [[ "$WHAT" == "get" ]]; then
                sed -i "s~text/html~application/json~g"  ~/.zen/tmp/$PLAYER.pay.$WHAT.http
                ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey get >> ~/.zen/tmp/$PLAYER.pay.$WHAT.http
            fi

            if [[ "$WHAT" == "balance" ]]; then
                    ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey balance >> ~/.zen/tmp/$PLAYER.pay.$WHAT.http
            fi

            cat ~/.zen/tmp/$PLAYER.pay.$WHAT.http
            cat ~/.zen/tmp/$PLAYER.pay.$WHAT.http | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
            end=`date +%s`
            echo "(G_G ) G1BANK Operation time was "`expr $end - $start` seconds.
            exit 0
        fi

##############################################
# MOATUBE : /?player=PLAYER&moa=json&tag=FILTER
##############################################
        if [[ $APPNAME == "moa" ]]; then

                [[ ! $VAL ]] && VAL="G1CopierYoutube"
                echo "EXPORT MOATUBE $PLAYER $VAL"

                echo "$HTTPCORS" > ~/.zen/tmp/${MOATS}.$PLAYER.http
                sed -i "s~text/html~application/json~g"  ~/.zen/tmp/${MOATS}.$PLAYER.http

                tiddlywiki --load ~/.zen/game/players/$PLAYER/ipfs/moa/index.html --output ~/.zen/tmp/ --render '.' "$PLAYER.moatube.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' "[tag[$VAL]]"

                cat ~/.zen/tmp/$PLAYER.moatube.json >> ~/.zen/tmp/${MOATS}.$PLAYER.http
                cat ~/.zen/tmp/${MOATS}.$PLAYER.http | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
                end=`date +%s`
                echo "(TW) MOA Operation time was "`expr $end - $start` seconds.
                exit 0
        fi

 exit 1
