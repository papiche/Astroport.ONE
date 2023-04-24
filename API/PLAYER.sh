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

PORT=$1 THAT=$2 AND=$3 THIS=$4  APPNAME=$5 WHAT=$6 OBJ=$7 VAL=$8 MOATS=$9
### transfer variables according to script
PORT=$1 PLAYER=$2 APPNAME=$3 WHAT=$4 OBJ=$5 VAL=$6

HTTPCORS="HTTP/1.1 200 OK
Access-Control-Allow-Origin: ${myASTROPORT}
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET
Server: Astroport.ONE
Content-Type: text/html; charset=UTF-8

"
        echo "- ${PLAYER} - ${APPNAME} : ${WHAT} ${OBJ} ${VAL}"
        [[ ! ${PLAYER} ]] && (echo "${HTTPCORS} BAD PLAYER - EXIT" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 1
        ASTRONAUTENS=$(ipfs key list -l | grep -w ${PLAYER} | cut -d ' ' -f1)
        [[ ! ${ASTRONAUTENS} ]] && (echo "${HTTPCORS} UNKNOWN PLAYER ${PLAYER} - EXIT" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 1

##############################################
# MOATUBE : /?player=PLAYER&moa=json&tag=FILTER
##############################################
        if [[ ${APPNAME} == "moa" ]]; then

                [[ ! ${VAL} ]] && VAL="G1CopierYoutube"
                echo "EXPORT MOATUBE ${PLAYER} ${VAL}"

                tiddlywiki --load ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html --output ~/.zen/tmp/ --render '.' "${PLAYER}.moatube.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' "[tag[${VAL}]]"

                if [[ ! ${WHAT} || ${WHAT} == "json" ]]; then

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
# YOUTUBE : /?player=PLAYER&(youtube | pdf  | image) =_URL_
##############################################
        if [[ ${APPNAME} == "youtube" || ${APPNAME} == "pdf" || ${APPNAME} == "image" ]]; then

                APPNAME=$(echo ${APPNAME} | sed -r 's/\<./\U&/g' | sed 's/ //g') ## First letter Capital

                [[ ! ${WHAT} ]] && WHAT="https://www.youtube.com/watch?v=BCl2-0HBJ2c"

                echo ">>> COPY ${APPNAME} for ${PLAYER} from ${WHAT}"

                G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub)
                [[ ! ${G1PUB} ]] && espeak "NOT MY PLAYER " && echo "${PLAYER} IS NOT MY PLAYER" && exit 1

                echo "================================================"
                echo "${PLAYER} : ${myIPFS}/ipns/${ASTRONAUTENS}"
                echo " = /ipfs/${TW}"
                echo "================================================"

                ${MY_PATH}/../ajouter_media.sh "${WHAT}" "${PLAYER}" "${APPNAME}" &

                echo "${HTTPCORS}" > ~/.zen/tmp/${MOATS}.${PLAYER}.http
                echo "${myIPFS}/ipns/${ASTRONAUTENS}" >> ~/.zen/tmp/${MOATS}.${PLAYER}.http
                cat ~/.zen/tmp/${MOATS}.${PLAYER}.http | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &

#  ### REFRESH CHANNEL COPY

                end=`date +%s`
                echo "(TW) MOA Operation time was "`expr $end - $start` seconds.
                exit 0

        fi

 exit 1
