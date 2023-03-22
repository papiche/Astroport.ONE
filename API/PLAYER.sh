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
        echo "- $PLAYER - $APPNAME : $WHAT $OBJ $VAL"

        ASTRONAUTENS=$(ipfs key list -l | grep -w $PLAYER | cut -d ' ' -f1)
        [[ ! $ASTRONAUTENS ]] && (echo "$HTTPCORS UNKNOWN PLAYER $PLAYER - EXIT" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 1

##############################################
# MOATUBE : /?player=PLAYER&moa=json&tag=FILTER
##############################################
        if [[ $APPNAME == "moa" ]]; then

                [[ ! $VAL ]] && VAL="G1CopierYoutube"
                echo "EXPORT MOATUBE $PLAYER $VAL"

                tiddlywiki --load ~/.zen/game/players/$PLAYER/ipfs/moa/index.html --output ~/.zen/tmp/ --render '.' "$PLAYER.moatube.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' "[tag[$VAL]]"

                if [[ ! $WHAT || $WHAT == "json" ]]; then

                    echo "$HTTPCORS" > ~/.zen/tmp/${MOATS}.$PLAYER.http
                    sed -i "s~text/html~application/json~g"  ~/.zen/tmp/${MOATS}.$PLAYER.http
                    cat ~/.zen/tmp/$PLAYER.moatube.json >> ~/.zen/tmp/${MOATS}.$PLAYER.http
                    cat ~/.zen/tmp/${MOATS}.$PLAYER.http | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &

                fi

                end=`date +%s`
                echo "(TW) MOA Operation time was "`expr $end - $start` seconds.
                exit 0
        fi

##############################################
# YOUTUBE : /?player=PLAYER&youtube=_URL_
##############################################
        if [[ $APPNAME == "youtube" ]]; then

                [[ ! $WHAT ]] && WHAT="https://www.youtube.com/watch?v=BCl2-0HBJ2c"
                echo "COPY YOUTUBE $PLAYER $WHAT"

                G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub)
                [[ ! $G1PUB ]] && espeak "NOT MY PLAYER " && echo "$PLAYER IS NOT MY PLAYER" && exit 1

                ## PREPARE tiddler
                echo '[
  {
    "created": "'${MOATS}'",
    "modified": "'${MOATS}'",
    "title": "'♥BOX'",
    "type": "'text/vnd.tiddlywiki'",
    "text": "'$WHAT'",
    "g1pub": "'${G1PUB}'",
    "tags": "'CopierYoutube ${PLAYER}'"
  }
]
' > "$HOME/.zen/tmp/CoeurBOX.json"

                rm -f ~/.zen/tmp/$PLAYER.html

                ## REMPLACE le Tiddler "CopierYoutube"
                tiddlywiki --load ~/.zen/game/players/$PLAYER/ipfs/moa/index.html \
                        --deletetiddlers '[tag[CopierYoutube]]' \
                        --output ~/.zen/tmp/ --render "$:/core/save/all" "one.html" "text/plain"

                [[ -s ~/.zen/tmp/one.html ]] && echo "tag[CopierYoutube] removed"

                tiddlywiki --load ~/.zen/tmp/one.html \
                        --import "$HOME/.zen/tmp/CoeurBOX.json" "application/json" \
                        --output ~/.zen/tmp/ --render "$:/core/save/all" "$PLAYER.html" "text/plain"

        [[ ! -s ~/.zen/tmp/$PLAYER.html ]] && echo "ERROR NO TW RESULTING" && exit  0
        echo "~/.zen/tmp/$PLAYER.html OK"
        ## ANY CHANGES ?
        ##############################################################
        DIFF=$(diff ~/.zen/tmp/$PLAYER.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html)
        if [[ $DIFF ]]; then
            echo "DIFFERENCE DETECTED !! "
            echo "Backup & Upgrade TW local copy..."
            cp ~/.zen/tmp/$PLAYER.html  ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
        else
            echo "SAME TW"
            exit 0
        fi
        ##############################################################

    ##################################################
    ##################################################
    ################## UPDATING PLAYER MOA
    [[ $DIFF ]] && cp   ~/.zen/game/players/$PLAYER/ipfs/moa/.chain \
                                    ~/.zen/game/players/$PLAYER/ipfs/moa/.chain.$(cat ~/.zen/game/players/$PLAYER/ipfs/moa/.moats)

    TW=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ipfs/moa/index.html | tail -n 1)
    ipfs name publish --allow-offline -t 24h --key=$PLAYER /ipfs/$TW

    [[ $DIFF ]] && echo $TW > ~/.zen/game/players/$PLAYER/ipfs/moa/.chain \
    && echo $MOATS > ~/.zen/game/players/$PLAYER/ipfs/moa/.moats

    echo "================================================"
    echo "$PLAYER : $myIPFS/ipns/$ASTRONAUTENS"
    echo " = /ipfs/$TW"
    echo "================================================"

    echo "$HTTPCORS" > ~/.zen/tmp/${MOATS}.$PLAYER.http
    echo "$myIPFS/ipns/$ASTRONAUTENS" >> ~/.zen/tmp/${MOATS}.$PLAYER.http
    cat ~/.zen/tmp/${MOATS}.$PLAYER.http | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &

#  ### REFRESH CHANNEL COPY

                end=`date +%s`
                echo "(TW) MOA Operation time was "`expr $end - $start` seconds.
                exit 0
        fi

 exit 1
