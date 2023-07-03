#!/bin/bash
########################################################################
# Version: 0.5
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# PAD COCODING : https://pad.p2p.legal/s/G1Kodi
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/../tools/my.sh"

echo "(✜‿‿✜) G1Kodi : Get Kodi database from ~/.kodi/userdata/Database/MyVideos116.db
export movie to RSS (ex : http://ipfs.localhost:8080/ipfs/QmSJYf4uTj3NmqovSFZpBZuUhSS8j9FXKKnAjUMuVE896k)"
echo "$ME RUNNING"

########################################################################
# KODI SERVICE
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
mkdir -p $HOME/.zen/tmp/${IPFSNODEID}/G1Kodi/${PLAYER}/
mkdir -p $HOME/.zen/game/players/${PLAYER}/G1Kodi/
mkdir -p $HOME/.zen/tmp/${MOATS}

echo "EXPORT Kodi Wish for ${PLAYER}"
m -f ~/.zen/game/players/${PLAYER}/G1Kodi/Kodi.json
tiddlywiki  --load ${INDEX} \
                    --output ~/.zen/game/players/${PLAYER}/G1Kodi \
                    --render '.' 'Kodi.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Kodi'

## Second export try
#~ if [[ ! -s ~/.zen/game/players/${PLAYER}/G1Kodi/Kodi.json ]] ; then
    #~ tiddlywiki  --load ${INDEX} \
                    #~ --output ~/.zen/game/players/${PLAYER}/G1Kodi \
                    #~ --render '.' 'Kodi.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1Kodi]]'

 #~ fi

[[ ! -s ~/.zen/game/players/${PLAYER}/G1Kodi/Kodi.json ]] && echo "AUCUN VOEU G1KODI - EXIT -" && exit 0


WISH=$(cat ~/.zen/game/players/${PLAYER}/G1Kodi/Kodi.json | jq -r '.[].wish')
WISHNS=$(cat ~/.zen/game/players/${PLAYER}/G1Kodi/Kodi.json | jq -r '.[].wishns')

echo ${myIPFS}${WISHNS}
echo "=========== ( ◕‿◕) (◕‿◕ ) =============="

## EXTRACT MOVIE FILES LIST
sqlite3 -csv ~/.kodi/userdata/Database/MyVideos116.db 'select c00, c01, c22 from movie' > ~/.zen/tmp/${PLAYER}.movie.csv
[[ ! -s ~/.zen/tmp/${PLAYER}.movie.csv ]] && echo "EMPTY KODI MOVIE DATABASE - EXIT -" && exit 0
#################################

## PREPARE RSS XML
echo '<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0">
<channel>
 <title>Astroport Kodi</title>
 <description>Astroport Kodi Movies RSS feed</description>
 <link>http://astroport.copylaradio.com</link>
 <copyright>2020 Astroport.com All rights reserved</copyright>
 <lastBuildDate>Mon, 6 Sep 2020 00:01:00 +0000</lastBuildDate>
 <pubDate>Sun, 6 Sep 2020 16:20:00 +0000</pubDate>
 <ttl>1800</ttl>' > $HOME/.zen/tmp/${MOATS}/movie.rss

while read LINE
do
    TITLE=$(echo $LINE | csvcut -c 1)
    DESC=$(echo $LINE | csvcut -c 2)
    SOURCE=$(echo $LINE | csvcut -c 3)

    echo "$TITLE"

    ## ADD MOVIE TO IPFS
    #~ <item>
    #~ <title>Delicatessen</title>
    #~ <description>La vie des étranges habitants d'un immeuble de banlieue qui se dresse dans un immense terrain vague et qui tous vont se fournir chez le boucher-charcutier, à l'enseigne « Delicatessen ».</description>
    #~ <link>http://ipfs.localhost:8080/ipfs/QmfVuhDo4kEk5eh5EULfZGxiWqrrCcHBehojgPF6kiq8r3/Delicatessen.mp4</link>
    #~ <pubDate>Sun, 6 Sep 2022 16:20:00 +0000</pubDate>
    #~ </item>


echo '
 <item>
  <title>'$TITLE'</title>
  <description>'$DESC'</description>
  <link>'$SOURCE'</link>
  <pubDate>Sun, 1 Sep 2020 20:12:00 +0000</pubDate>
 </item>
' >> $HOME/.zen/tmp/${MOATS}/movie.rss

done < ~/.zen/tmp/${PLAYER}.movie.csv

echo '</channel>
</rss>' >> $HOME/.zen/tmp/${MOATS}/movie.rss

IPRSS=$(ipfs add -q $HOME/.zen/tmp/${MOATS}/movie.rss)

ipfs name publish -k $WISH /ipfs/$IPRSS

echo "=========== ( ◕‿◕)  (◕‿◕ ) =============="

rm -Rf $HOME/.zen/tmp/${MOATS}

exit 0
