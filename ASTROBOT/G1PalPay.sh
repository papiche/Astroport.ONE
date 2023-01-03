#!/bin/bash
########################################################################
# Version: 0.4
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
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

## GET @ in
for LINE in $(cat $HOME/.zen/game/players/${PLAYER}/G1PalPay/$PLAYER.history.json | jq -rc .[] | grep 'Bro'); do

    echo "MATCHING IN COMMENT"
    JSON=$LINE
    IDATE=$(echo $JSON | jq -r .date)
    IPUBKEY=$(echo $JSON | jq -r .pubkey)
    IAMOUNT=$(echo $JSON | jq -r .amount)
    IAMOUNTUD=$(echo $JSON | jq -r .amountUD)
    ICOMMENT=$(echo $JSON | jq -r .comment)

    echo $IDATE $IPUBKEY $IAMOUNT [$IAMOUNTUD] $ICOMMENT

    for EMAIL in "${ICOMMENT[@]}";

        if [[ "${EMAIL}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]; then
            echo "VALID EMAIL : ${EMAIL}"

            $($MY_PATH/../tools/search_for_this_email_in_players.sh ${EMAIL}) ## export ASTROTW

            if [[ ! ${ASTROTW} ]]; then

                echo "# NEW VISA $(date)"
                SALT="" && PEPPER=""
                echo "VISA.new : \"$SALT\" \"$PEPPER\" \"${EMAIL}\" \"$PSEUDO\" \"${URL}\""
                #~ $(${MY_PATH}/../tools/VISA.new.sh "$SALT" "$PEPPER" "${EMAIL}" "$PSEUDO" "${URL}" | tail -n 1) # export ASTROTW=/ipns/$ASTRONAUTENS ASTROG1=$G1PUB ASTROMAIL=$EMAIL ASTROFEED=$FEEDNS

                ## CREATE new PLAYER IN myASTROTUBE
                curl -x ${myASTROTUBE}/?salt=0&pepper=0&g1pub=_URL_&email=${EMAIL} -o ~/.zen/tmp/${MOATS}/astro.port

                TELETUBE=$(cat ~/.zen/tmp/${MOATS}/astro.port | grep "(◕‿‿◕)" | cut -d ':' -f 2 | cut -d '/' -f 3)
                TELEPORT=$(cat ~/.zen/tmp/${MOATS}/astro.port | grep "(◕‿‿◕)" | cut -d ':' -f 3 | cut -d '"' -f 1)
                sleep 12

                curl -x http://$TELETUBE:$TELEPORT -o ~/.zen/tmp/${MOATS}/astro.rep
                $(cat ~/.zen/tmp/${MOATS}/astro.rep | tail -n 1)

                ######################################################

                ${MY_PATH}/../tools/mailjet.sh "${EMAIL}" "BRO. $PLAYER  VOUS A OFFERT UN TW : $(myIpfsGw)/$ASTROTW et " ## WELCOME NEW PLAYER


            fi

            ## MAKE FRIENDS & SEND G1
            echo "My PalPay Friend $ASTROMAIL
            TW : $ASTROTW
            G1 : $ASTROG1
            RSS : $ASTROFEED"

            ~/.zen/Astroport.ONE/tools/timeout.sh -t 12 \
            ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey history -n 10 -j > $HOME/.zen/game/players/${PLAYER}/G1PalPay/$PLAYER.history.json

        else
                echo "BAD EMAIL : ${EMAIL}"
                continue
        fi

    done

done



#~ ###################################################################
#~ ## tag[PalPay] EXTRACT ~/.zen/tmp/PalPay.json FROM TW
#~ ###################################################################
#~ rm -f ~/.zen/game/players/${PLAYER}/G1PalPay/PalPay.json
#~ tiddlywiki  --load ${INDEX} \
                    #~ --output ~/.zen/game/players/${PLAYER}/G1PalPay \
                    #~ --render '.' 'PalPay.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[PalPay]]'
#~ echo "DEBUG : cat ~/.zen/game/players/${PLAYER}/G1PalPay/PalPay.json | jq -r"
#~ ## GOT PalPay TIDDLER


        #~ echo "Creating Youtube ${YID} tiddler : G1PalPay !"
        #~ echo $TEXT

        #~ echo '[
  #~ {
    #~ "created": "'${MOATS}'",
    #~ "resolution": "'${RES}'",
    #~ "duree": "'${DUREE}'",
    #~ "duration": "'${DURATION}'",
    #~ "giftime": "'${PROBETIME}'",
    #~ "gifanime": "'/ipfs/${ANIMH}'",
    #~ "modified": "'${MOATS}'",
    #~ "title": "'$ZFILE'",
    #~ "type": "'text/vnd.tiddlywiki'",
    #~ "vtratio": "'${VTRATIO}'",
    #~ "text": "'$TEXT'",
    #~ "g1pub": "'${G1PUB}'",
    #~ "mime": "'${MIME}'",
    #~ "size": "'${FILE_BSIZE}'",
    #~ "filesize": "'${FILE_SIZE}'",
    #~ "sec": "'${SEC}'",
    #~ "dur": "'${dur}'",
    #~ "ipfs": "'/ipfs/${ILINK}'",
    #~ "youtubeid": "'${YID}'",
    #~ "tags": "'ipfs G1PalPay ${PLAYER} ${EXTRATAG} ${MIME}'"
  #~ }
#~ ]
#~ ' > "$HOME/.zen/tmp/${IPFSNODEID}/G1PalPay/${PLAYER}/$YID.TW.json"

    #~ TIDDLER="$HOME/.zen/tmp/${IPFSNODEID}/G1PalPay/${PLAYER}/$YID.TW.json"

#~ else
    #~ ###################################################################
    #~ echo '# TIDDLER WAS IN CACHE'
    #~ ###################################################################
    #~ ## TODO : ADD EMAIL TAG ( TIMESTAMP & ADD SIGNATURE over existing ones)

#~ fi

#~ cp -f "${TIDDLER}" "$HOME/.zen/game/players/${PLAYER}/G1PalPay/"


#~ #################################################################
#~ ### ADDING $YID.TW.json to ASTONAUTENS INDEX.html
#~ #################################################################
        #~ echo "=========================="
        #~ echo "Adding $YID tiddler to TW /ipns/$ASTONAUTENS "

        #~ rm -f ~/.zen/tmp/${IPFSNODEID}/newindex.html

        #~ echo  ">>> Importing $HOME/.zen/game/players/${PLAYER}/G1PalPay/$YID.TW.json"

        #~ tiddlywiki --load ${INDEX} \
                        #~ --import "$HOME/.zen/game/players/${PLAYER}/G1PalPay/$YID.TW.json" "application/json" \
                        #~ --output ~/.zen/tmp/${IPFSNODEID} --render "$:/core/save/all" "newindex.html" "text/plain"

#~ # --deletetiddlers '[tag[PalPay]]' ### REFRESH CHANNEL COPY

        #~ if [[ -s ~/.zen/tmp/${IPFSNODEID}/newindex.html ]]; then

            #~ ## COPY JSON TIDDLER TO PLAYER
            #~ ln -s "$HOME/.zen/game/players/${PLAYER}/G1PalPay/$YID.TW.json" "$HOME/.zen/game/players/${PLAYER}/G1PalPay/$ZFILE.json"

            #~ [[ $(diff ~/.zen/tmp/${IPFSNODEID}/newindex.html ${INDEX} ) ]] && cp ~/.zen/tmp/${IPFSNODEID}/newindex.html ${INDEX} && echo "===> Mise à jour ${INDEX}"

        #~ else
            #~ echo "Problem with tiddlywiki command. Missing ~/.zen/tmp/${IPFSNODEID}/newindex.html"
            #~ echo "XXXXXXXXXXXXXXXXXXXXXXX"
        #~ fi

rm -Rf $HOME/.zen/tmp/${MOATS}

exit 0
