#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
## API: PLAYER - PUBLIC KEY AUTH
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"

start=`date +%s`

PORT=$1 THAT=$2 ANDcyberD0G!
=$3 THIS=$4  APPNAME=$5 WHAT=$6 OBJ=$7 VAL=$8 MOATS=$9 COOKIE=$10
echo "PORT=$1
THAT=$2
AND=$3
THIS=$4
APPNAME=$5
WHAT=$6
OBJ=$7
VAL=$8
MOATS=$9
COOKIE=$10"

### transfer variables according to script (TODO REMOVE THAT)
PORT=$1 PLAYER=$2 APPNAME=$3 OBJ=$5

HTTPCORS="HTTP/1.1 200 OK
Access-Control-Allow-Origin: ${myASTROPORT}
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET
Server: Astroport.ONE
Content-Type: text/html; charset=UTF-8

"
        [[ ! ${PLAYER} ]] && (echo "${HTTPCORS} BAD PLAYER - EXIT" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 1
        ASTRONAUTENS=$(ipfs key list -l | grep -w ${PLAYER} | cut -d ' ' -f1)
        [[ ! ${ASTRONAUTENS} ]] && (echo "${HTTPCORS} UNKNOWN PLAYER ${PLAYER} - EXIT" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 1

##############################################
# MOATUBE : /?player=PLAYER&moa=json&tag=FILTER
##############################################
        if [[ ${APPNAME} == "moa" ]]; then

                [[ ! ${WHAT} ]] && WHAT="G1CopierYoutube"
                echo "EXPORT MOATUBE ${PLAYER} ${WHAT}"

                tiddlywiki --load ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html --output ~/.zen/tmp/ --render '.' "${PLAYER}.moatube.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' "[tag[${WHAT}]]"

                if [[ ! ${THIS} || ${THIS} == "json" ]]; then

                    echo "${HTTPCORS}" > ~/.zen/tmp/${MOATS}.${PLAYER}.http
                    sed -i "s~text/html~application/json~g"  ~/.zen/tmp/${MOATS}.${PLAYER}.http
                    cat ~/.zen/tmp/${PLAYER}.moatube.json >> ~/.zen/tmp/${MOATS}.${PLAYER}.http
                    cat ~/.zen/tmp/${MOATS}.${PLAYER}.http | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &

                fi

                end=`date +%s`
                echo "(TW) MOA Operation time was "`expr $end - $start` seconds.
                exit 0
        fi

##############################################
# ATPASS : /?player=PLAYER&atpass=G1PUB&$VoeuName=ONELINE
##############################################
        #~ if [[ ${APPNAME} == "atpass" ]]; then

               #~ echo "CREATING @PASS"

                #~ end=`date +%s`
                #~ echo "(@PASS) creation time was "`expr $end - $start` seconds.
                #~ exit 0
        #~ fi

##############################################
# YOUTUBE : /?player=PLAYER&(youtube | pdf  | image) =_URL_
##############################################
        #~ if [[ ${APPNAME} == "youtube" || ${APPNAME} == "pdf" || ${APPNAME} == "image" ]]; then

                #~ APPNAME=$(echo ${APPNAME} | sed -r 's/\<./\U&/g' | sed 's/ //g') ## First letter Capital

                #~ [[ ! ${THIS} ]] && THIS="https://www.youtube.com/watch?v=BCl2-0HBJ2c"

                #~ echo ">>> COPY ${APPNAME} for ${PLAYER} from ${THIS}"

                #~ G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub)
                #~ [[ ! ${G1PUB} ]] && espeak "NOT MY PLAYER " && echo "${PLAYER} IS NOT MY PLAYER" && exit 1

                #~ echo "================================================"
                #~ echo "${PLAYER} : ${myIPFS}/ipns/${ASTRONAUTENS}"
                #~ echo " = /ipfs/${TW}"
                #~ echo "================================================"

                #~ ${MY_PATH}/../ajouter_media.sh "${THIS}" "${PLAYER}" "${APPNAME}" &

                #~ echo "${HTTPCORS}" > ~/.zen/tmp/${MOATS}.${PLAYER}.http
                #~ echo "${myIPFS}/ipns/${ASTRONAUTENS}" >> ~/.zen/tmp/${MOATS}.${PLAYER}.http
                #~ (
                #~ cat ~/.zen/tmp/${MOATS}.${PLAYER}.http | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
                #~ rm ~/.zen/tmp/${MOATS}.${PLAYER}.http
                #~ ) &

#~ #  ### REFRESH CHANNEL COPY

                #~ end=`date +%s`
                #~ echo "(TW) MOA Operation time was "`expr $end - $start` seconds.
                #~ exit 0

        #~ fi

 exit 1
