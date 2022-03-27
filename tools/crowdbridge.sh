#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
TS=$(date -u +%s%N | cut -b1-13)

# Fred MadeInZion, [20/03/2022 23:03]
# Script qui capture et transfert dans IPFS les vidéos de https://crowdbunker.com/

VWALLURL="https://api.crowdbunker.com/post/all"
curl -s $VWALLURL -H "Accept: application/json" > /tmp/crowd.json

for VUID in $(cat /tmp/crowd.json | jq -r '.posts | .[] | .video.id'); do
[[ "$VUID" == "null" ]] && echo "Not a Video" && continue
echo "Bunker BOX : $VUID"; read

URL="https://api.crowdbunker.com/post/$VUID/details"
echo "URL=$URL"; read
HLS=$(curl -s $URL -H "Accept: application/json" | jq -r .video.hlsManifest.url)
echo "HLS=$HLS"; read
MEDIASOURCE=$(echo $HLS | rev | cut -d '/' -f 2- | rev)
echo "MEDIASOURCE=$MEDIASOURCE"; read

mkdir -p /tmp/$VUID/media
curl -s $HLS -o /tmp/$VUID/crowdvideo.m3u8
cat /tmp/$VUID/crowdvideo.m3u8
read

FILE360=$(cat /tmp/$VUID/crowdvideo.m3u8 | grep 360 | tail -n 1 | cut -f 1 -d '.')
echo "FILE360=$MEDIASOURCE/$FILE360"; read
if [[ ! -f /tmp/$VUID/media/$FILE360 ]]; then
    curl -s $MEDIASOURCE/$FILE360.m3u8 -o /tmp/$VUID/$FILE360.m3u8
    curl $MEDIASOURCE/$FILE360 -o /tmp/$VUID/media/$FILE360
fi
IPFSVID=$(ipfs add -wrHq /tmp/$VUID/media/$FILE360 | tail -n 1)
echo "VIDEO http://localhost:8080/ipfs/$IPFSVID/$FILE360"

echo

AUDIOFILE=$(cat /tmp/$VUID/crowdvideo.m3u8 | grep '=AUDIO' | rev | cut -d '.' -f 2- | cut -d '"' -f 1 | rev)
echo "AUDIO=$MEDIASOURCE/$AUDIOFILE"; read
if [[ ! -f /tmp/$VUID/media/$AUDIOFILE ]]; then
    curl -s $MEDIASOURCE/$AUDIOFILE.m3u8 -o /tmp/$VUID/$AUDIOFILE.m3u8
    curl $MEDIASOURCE/$AUDIOFILE -o /tmp/$VUID/media/$AUDIOFILE
fi
IPFSAUD=$(ipfs add -wrHq /tmp/$VUID/media/$AUDIOFILE | tail -n 1)

echo "AUDIO http://localhost:8080/ipfs/$IPFSAUD/$AUDIOFILE"

echo "Adapting m3u8"


done
