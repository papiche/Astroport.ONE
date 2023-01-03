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

~/.zen/Astroport.ONE/tools/timeout.sh -t 12 \
${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey history -n 10 -j > $HOME/.zen/game/players/${PLAYER}/G1PalPay/$PLAYER.history.json

[[ ! -s $HOME/.zen/game/players/${PLAYER}/G1PalPay/$PLAYER.history.json ]] && echo "NO PAYMENT HISTORY" && exit 1

cat $HOME/.zen/game/players/${PLAYER}/G1PalPay/$PLAYER.history.json | jq -r

## GET @ in
PLINES=("$(cat $HOME/.zen/game/players/${PLAYER}/G1PalPay/$PLAYER.history.json | jq -r .[].comment | grep 'Financement du JEu')")

for LINE in "${PLINES[@]}"; do

    echo "MATCHING INCOMING COMMENT : $LINE"
    JSON=$(cat $HOME/.zen/game/players/${PLAYER}/G1PalPay/$PLAYER.history.json | jq .[] | jq -r 'select(.comment=="'"$LINE"'")')
    IDATE=$(echo $JSON | jq -r .date)
    IPUBKEY=$(echo $JSON | jq -r .pubkey)
    IAMOUNT=$(echo $JSON | jq -r .amount)
    IAMOUNTUD=$(echo $JSON | jq -r .amountUD)

    echo $IDATE $IPUBKEY $IAMOUNT [$IAMOUNTUD]

    EMAILS=("${LINE}")
    for EMAIL in "${EMAILS[@]}"; do

          if [[ "${EMAIL}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]; then
                echo "VALID EMAIL : ${EMAIL}"

                $($MY_PATH/../tools/search_for_this_email_in_players.sh ${EMAIL}) ## export FOUND

                if [[ ! ${FOUND} ]]; then

                    echo "# NEW VISA $(date)"
                    SALT="" && PEPPER=""
                    echo "VISA.new : \"$SALT\" \"$PEPPER\" \"${EMAIL}\" \"$PSEUDO\" \"${URL}\""
                    $(${MY_PATH}/../tools/VISA.new.sh "$SALT" "$PEPPER" "${EMAIL}" "$PSEUDO" "${URL}" | tail -n 1) # export ASTROTW=$ASTRONAUTENS ASTROG1=$G1PUB ASTROMAIL=$EMAIL ASTROFEED=$FEEDNS

                    ${MY_PATH}/../tools/mailjet.sh "${EMAIL}" "BRO. VOILA TO TW. $PLAYER" ## WELCOME NEW PLAYER


                fi

                ## MAKE FRIEND & SEND PROPORTIONNAL G1


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


exit 0
