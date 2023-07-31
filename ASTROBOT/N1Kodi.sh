#!/bin/bash
########################################################################
# Version: 0.5
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# PAD COCODING : https://pad.p2p.legal/s/G1Kodi
# KODI SERVICE : Publish and Merge Friends Kodi Movies into RSS Stream
########################################################################
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/../tools/my.sh"

echo "$ME RUNNING"
########################################################################
## LOOK IN TW INDEX for THASH
## DECODE ipfs_one
## SEND MESSAGE TO SOURCEG1PUB
########################################################################
## THIS SCRIPT IS RUN WHEN A WALLET RECEIVED A TRANSACTION WITH COMMENT STARTING WITH N1Kodi:
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

IPUBKEY="$4"
[[ ! ${IPUBKEY} ]] && echo "ERROR - MISSING COMMAND ISSUER !"  && exit 1

TH="$5"
[[ ! ${TH} ]] && echo "ERROR - MISSING COMMAND TITLE HASH ADDRESS !"  && exit 1

echo "${PLAYER} : ${IPUBKEY} SEEKING FOR ${TH}
${ASTRONAUTENS} ${G1PUB} "

#~ ###################################################################
#~ ## CREATE APP NODE PLAYER PUBLICATION DIRECTORY
#~ ###################################################################
mkdir -p $HOME/.zen/tmp/${MOATS} && echo $HOME/.zen/tmp/${MOATS}

## EXTRACT TIDDLER
tiddlywiki  --load ${INDEX} \
                --output ~/.zen/.zen/tmp/${MOATS} \
                --render '.' 'TH.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[thash['${TH}']]'

if [[ $(cat ~/.zen/.zen/tmp/${MOATS}/TH.json) != "[]" ]]; then
# FOUND GETTING CYPHERED IPFS LINK
    TITLE=$(cat ~/.zen/.zen/tmp/${MOATS}/TH.json | jq -r '.[].title')

    IPFSONE=$(cat ~/.zen/.zen/tmp/${MOATS}/TH.json | jq -r '.[].ipfs_one')
    echo "${IPFSONE}" | base16 -d > ~/.zen/tmp/${MOATS}/source.one.enc

    ## DECRYPTING ipfs_one
    ~/.zen/Astroport.ONE/tools/natools.py decrypt -f pubsec \
                        -k ~/.zen/game/players/${PLAYER}/secret.dunikey \
                        -i ~/.zen/tmp/${MOATS}/source.one.enc -o $HOME/.zen/tmp/${MOATS}/source.one

    DECIPFS=$(cat $HOME/.zen/tmp/${MOATS}/source.one)
    echo "${TITLE} = ${DECIPFS}"

    ## TODO CREATE A TEMP IPNS KEY ?!

    ## SENDING GCHANGE & CESIUM+ MESSAGE
    $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey -n ${myDATA} send -d "${IPUBKEY}" -t "${TITLE}" -m "N1Kodi : https://${myTUBE}${DECIPFS}"

    $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey -n ${myCESIUM} send -d "${IPUBKEY}" -t "${TITLE}" -m "N1Kodi : https://${myTUBE}${DECIPFS}"

else

        echo "NO TIDDLER WITH ${TH}"
        exit 1
fi

exit 0
## TODO CREATE FROM FRIEND LOCAL KODI RSS
#~ echo '<?xml version="1.0" encoding="UTF-8" ?>
#~ <rss version="2.0">
#~ <channel>
 #~ <title>RSS ASTROPORT</title>
 #~ <description>Astroport Kodi RSS feed</description>
 #~ <link>https://www.copylaradio.com</link>
 #~ <copyright>2020 Astroport.com FOSS</copyright>
 #~ <lastBuildDate>Mon, 6 Sep 2020 00:01:00 +0000</lastBuildDate>
 #~ <pubDate>Sun, 6 Sep 2020 16:20:00 +0000</pubDate>
 #~ <ttl>1800</ttl>
#~ ' > ~/.zen/tmp/${MOATS}/movie.rss

#~ find ~/.zen/game/players/${PLAYER}/FRIENDS -mindepth 1 -maxdepth 1 -type d | rev | cut -f 1 -d '/' | rev > ~/.zen/tmp/${MOATS}/twfriends

#~ ## SCAN ALL "_APLAYER.tiddlers.json"
#~ for FILE in $(ls ${N1PATH}/*.tiddlers.json); do
    #~ APLAYER=$(echo "$FILE" | rev | cut -d '.' -f 3- | cut -d '_' -f 1 | rev )
    #~ [[ ${APLAYER} == ${PLAYER} ]] && echo "My Movie List" && continue

#~ ## EXTRACT all titles to do JQ LOOP
    #~ cat ${FILE} | jq -r .[].title > ~/.zen/tmp/${MOATS}/${APLAYER}.movie.id

    #~ while read TITLE; do

    #~ ## GET AG1PUB FROM FRIEND TW
#~ ## BUG !!!
    #~ TITRE=$(cat ${FILE} | jq -r .[].titre)
    #~ SUB=$(cat ${FILE} | jq -r .[].sub)
    #~ IPFSONE=$(cat ${FILE} | jq -r .[].ipfs_one)
    #~ echo "${IPFSONE}" | base16 -d > ~/.zen/tmp/${MOATS}/source.one.enc

    #~ ~/.zen/Astroport.ONE/tools/natools.py decrypt -f pubsec \
                        #~ -k ~/.zen/game/players/${PLAYER}/secret.dunikey \
                        #~ -i ~/.zen/tmp/${MOATS}/source.one.enc -o $HOME/.zen/tmp/${MOATS}/source.one

    #~ SOURCE=$(cat ${FILE} | jq -r .[].source)
    #~ IPFS_ME=$(cat ${FILE} | jq -r .[].ipfs_${player})

    #~ echo '
     #~ <item>
      #~ <title>'${TITRE}'</title>
      #~ <description>'${SUB}'</description>
      #~ <link>http://ipfs.localhost:8080/ipfs/QmQwYpoHX6Fw26nd3KFfLj71Uv34riT4F5X2RFy2rmHekW</link>
      #~ <pubDate>Sun, 6 Sep 2022 16:20:00 +0000</pubDate>
     #~ </item>' >> ~/.zen/tmp/${MOATS}/movie.rss

    #~ done < ~/.zen/tmp/${MOATS}/${APLAYER}.movie.id


#~ done

#~ ## EXTRACT and DECODE ipfs_AG1PUB from FRIENDS json's


#~ echo '
#~ </channel>
#~ </rss>
#~ ' >> ~/.zen/tmp/${MOATS}/movie.rss

#~ ## UPDATE LOCAL KODI WITH
#~ ## ./userdata/mediasources.xml
#~ ## ./userdata/sources.xml




