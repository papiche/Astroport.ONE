#!/bin/bash
########################################################################
# Author: Fred (fred@g1sms.fr)
# Version: 0
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
### TAKE A G1Video tiddlers JSON Flux and make a m3u playlist
###############################################
# USE : $IPFSGW/ipns/$VOEUNS/$PLAYER.tiddlers.json > ~/Astroport/playlist.m3u
## && vlc ~/Astroport/playlist.m3u
###############################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
###############################################

VIDEOJSONTIDDLERSURL="$1"
IPFSGW="$2"

[[ ! $IPFSGW ]] \
&& IPFSGW=$(echo $VIDEOJSONTIDDLERSURL | grep -Eo '^http[s]?://[^/]+')     # URL="https://discuss.ipfs.io"


[[ $IPFSGW == "" ]] && [[ $(which ipfs) ]] && IPFSGW="http://ipfs.localhost:8080" \


[[ $IPFSGW == ""  ]] && IPFSGW="https://tube.copylaradio.com"


[[ ! $VIDEOJSONTIDDLERSURL ]] \
&& echo "Please provide WISHKEY URL : G1Video JSON Flux URL. TRY" \
&& echo "$MY_PATH/$ME $IPFSGW/ipns/k51qzi5uqu5dkb5rpiwbu1waex0ve41mi3k3935712z6nhrdesicg2te53glp1/fred@g1sms.fr.tiddlers.json > ~/Astroport/playlist.m3u" \
&& exit 1

JT=$(echo $VIDEOJSONTIDDLERSURL | rev | cut -d '/' -f 1 | rev)

## GET Ŋ1 JSON FLUX
mkdir -p ~/.zen/tmp
curl -s $VIDEOJSONTIDDLERSURL > ~/.zen/tmp/$JT

## REMOVING EMPTY /ipfs/
cat ~/.zen/tmp/$JT | jq -r 'del(.[] | select(.ipfs == "" or .ipfs == "/ipfs/"))' > ~/.zen/tmp/$JT.clean

echo "#EXTM3U"
cat ~/.zen/tmp/$JT.clean | jq -r '.[] | "#EXTINF:0," + .title + "\n#EXTVLCOPT:network-caching=1000" + "\n'$IPFSGW'" + .ipfs'
echo "#EXT-X-ENDLIST"

rm ~/.zen/tmp/$JT*
