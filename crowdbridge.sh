#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
mkdir -p ~/.zen/bunkerbox  # BunkerBOX temp directory
# Fred MadeInZion, [20/03/2022 23:03]
# Script qui capture et transfert dans IPFS le flux des nouvelles vidéos de https://crowdbunker.com/

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
TS=$(date -u +%s%N | cut -b1-13)

YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1) || echo " warning ipfs daemon not running"
isLAN=$(hostname -I | awk '{print $1}' | head -n 1 | cut -f3 -d '/' | grep -E "(^127\.)|(^192\.168\.)|(^fd42\:)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")

IPFSGWESC="https:\/\/tube.copylaradio.com" && IPFSNGW="https://tube.copylaradio.com"
IPFSGWESC="http:\/\/127.0.0.1:8080" && IPFSNGW="http://127.0.0.1:8080"

[[ ! $isLAN ]] && IPFSGWESC="https:\/\/$(hostname)" && IPFSNGW="https://$(hostname)"
echo "IPFS GATEWAY $IPFSNGW"

## GET LATEST VIDEOS
VWALLURL="https://api.crowdbunker.com/post/all"
curl -s $VWALLURL -H "Accept: application/json" > ~/.zen/bunkerbox/crowd.json

## LOOP THROUGH
for VUID in $(cat ~/.zen/bunkerbox/crowd.json | jq -r '.posts | .[] | .video.id'); do
    start=`date +%s`
    [[ "$VUID" == "null" ]] && echo "MESSAGE... Bypassing..." && echo && continue
    echo "Bunker BOX : Adding $VUID"
    mkdir -p ~/.zen/bunkerbox/$VUID/media

    URL="https://api.crowdbunker.com/post/$VUID/details"
#    echo "WISHING TO EXPLORE $URL ?"; read TEST;  [[ "$TEST" != "" ]] && echo && continue
    curl -s $URL -H "Accept: application/json" -o ~/.zen/bunkerbox/$VUID/$VUID.json

    # STREAMING LIVE ?
    echo ">>> Extracting video caracteristics from ~/.zen/bunkerbox/$VUID/$VUID.json"
    ISLIVE=$(cat ~/.zen/bunkerbox/$VUID/$VUID.json | jq -r .video.isLiveType)&& [[ "$ISLIVE" == "true" ]] && echo "LIVE... "
    LIVE=$(cat ~/.zen/bunkerbox/$VUID/$VUID.json | jq -r .video.isLiveActive) && [[ "$LIVE" == "true" ]] && echo "STREAMING... Bypassing..." && echo && continue
    DURATION=$(cat ~/.zen/bunkerbox/$VUID/$VUID.json | jq -r .video.duration) && [[ $DURATION == 0 ]] && echo "NOT STARTED YET" && echo && continue
    TITLE=$(cat ~/.zen/bunkerbox/$VUID/$VUID.json | jq -r .video.title)
    CHANNEL=$(cat ~/.zen/bunkerbox/$VUID/$VUID.json | jq -r .channel.name)
    ORGUID=$(cat ~/.zen/bunkerbox/$VUID/$VUID.json | jq -r .organization.uid)
    ORGNAME=$(cat ~/.zen/bunkerbox/$VUID/$VUID.json | jq -r .organization.name)
    ORGBANNER=$(cat ~/.zen/bunkerbox/$VUID/$VUID.json | jq -r .organization.banner.url)

    HLS=$(cat ~/.zen/bunkerbox/$VUID/$VUID.json | jq -r .video.hlsManifest.url)
    MEDIASOURCE=$(echo $HLS | rev | cut -d '/' -f 2- | rev)
    echo "$TITLE ($DURATION s)"

    echo "READY TO PROCESS ?"; read TEST;  [[ "$TEST" != "" ]] && echo && continue
    echo "$HLS"
    curl -s $HLS -o ~/.zen/bunkerbox/$VUID/$VUID.m3u8
    # cat ~/.zen/bunkerbox/$VUID/$VUID.m3u8

    echo ">>>>>>>>>>>>>>>> Downloading VIDEO"
    # Choose 360p or 480p or 240p
    VSIZE=360 && VIDEOHEAD=$(cat ~/.zen/bunkerbox/$VUID/$VUID.m3u8 | grep -B1 ${VSIZE}p | head -n 1) && VIDEOSRC=$(cat ~/.zen/bunkerbox/$VUID/$VUID.m3u8 | grep ${VSIZE}p | tail -n 1 | cut -f 1 -d '.')
    [[ "$VIDEOSRC" == "" ]] && VSIZE=480 && VIDEOHEAD=$(cat ~/.zen/bunkerbox/$VUID/$VUID.m3u8 | grep -B1 ${VSIZE}p | head -n 1) && VIDEOSRC=$(cat ~/.zen/bunkerbox/$VUID/$VUID.m3u8 | grep ${VSIZE}p | tail -n 1 | cut -f 1 -d '.')
    [[ "$VIDEOSRC" == "" ]] && VSIZE=240 &&VIDEOHEAD=$(cat ~/.zen/bunkerbox/$VUID/$VUID.m3u8 | grep -B1 ${VSIZE}p | head -n 1) && VIDEOSRC=$(cat ~/.zen/bunkerbox/$VUID/$VUID.m3u8 | grep ${VSIZE}p | tail -n 1 | cut -f 1 -d '.')
    VTHUMB="$(cat ~/.zen/bunkerbox/$VUID/$VUID.json | jq -r --arg VSIZE "$VSIZE"  '.video.thumbnails[] | select(.height == $VSIZE) | .url')"

    echo ">>>>>>>>>>>>>>>> Downloading Video $VSIZE Thumbnail"
    curl -s $VTHUMB -o ~/.zen/bunkerbox/$VUID/media/$VUID.jpg
    [[ ! -f ~/.zen/bunkerbox/$VUID/media/$VUID.jpg ]] && cp ~/.zen/bunkerbox/$VUID/media/astroport.jpg ~/.zen/bunkerbox/$VUID/media/$VUID.jpg # CORRECT MISSING THUMB

    echo "VIDEOSRC=$MEDIASOURCE/$VIDEOSRC"
    # Downloading Video m3u8 and Video
    [[ ! -f ~/.zen/bunkerbox/$VUID/media/$VIDEOSRC.m3u8 ]] && curl -s $MEDIASOURCE/$VIDEOSRC.m3u8 -o ~/.zen/bunkerbox/$VUID/media/$VIDEOSRC.m3u8
    [[ ! -f ~/.zen/bunkerbox/$VUID/media/$VIDEOSRC ]] && curl $MEDIASOURCE/$VIDEOSRC -o ~/.zen/bunkerbox/$VUID/media/$VIDEOSRC

    echo ">>>>>>>>>>>>>>>> Downloading AUDIO"
    AUDIOLINE=$(cat ~/.zen/bunkerbox/$VUID/$VUID.m3u8 | grep '=AUDIO')
    AUDIOFILE=$(echo $AUDIOLINE | rev | cut -d '.' -f 2- | cut -d '"' -f 1 | rev)
    echo "AUDIO=$MEDIASOURCE/$AUDIOFILE"
    # Downloading Audio m3u8 and Audio
    [[ ! -f ~/.zen/bunkerbox/$VUID/media/$AUDIOFILE.m3u8 ]] && curl -s $MEDIASOURCE/$AUDIOFILE.m3u8 -o ~/.zen/bunkerbox/$VUID/media/$AUDIOFILE.m3u8
    [[ ! -f ~/.zen/bunkerbox/$VUID/media/$AUDIOFILE ]] && curl $MEDIASOURCE/$AUDIOFILE -o ~/.zen/bunkerbox/$VUID/media/$AUDIOFILE

    echo ">>>>>>>>>>>>>>>> CREATING $VSIZE M3U8"
    echo "#EXTM3U
#EXT-X-VERSION:6
#EXT-X-INDEPENDENT-SEGMENTS

$AUDIOLINE

$VIDEOHEAD
$VIDEOSRC.m3u8

" > ~/.zen/bunkerbox/$VUID/media/$VUID.m3u8
ls ~/.zen/bunkerbox/$VUID/media/
##########################################################################
echo "##########################################################################"
    echo ">>>>>>>>>>>>>>>> ADDING index.html"
    # COPY index, style, js AND data
    cp -R ${MY_PATH}/templates/styles ~/.zen/bunkerbox/$VUID/media/
    cp -R ${MY_PATH}/templates/js ~/.zen/bunkerbox/$VUID/media/
    cp ${MY_PATH}/templates/videojs.html ~/.zen/bunkerbox/$VUID/media/index.html
    cp ${MY_PATH}/images/astroport.jpg ~/.zen/bunkerbox/$VUID/media/

    # Add current reversed history
    if [[ -f ~/.zen/bunkerbox/history.json ]]; then
        echo '{
    "Videos":' > ~/.zen/bunkerbox/$VUID/media/$VUID.history.json
        cat ~/.zen/bunkerbox/history.json  | jq '.[] | reverse' >> ~/.zen/bunkerbox/$VUID/media/$VUID.history.json
        echo '}' >> ~/.zen/bunkerbox/$VUID/media/$VUID.history.json
    else
        cp ${MY_PATH}/templates/data/history.json ~/.zen/bunkerbox/history.json
    fi
    # Using relative links
    sed "s/_IPFSROOT_/./g" ${MY_PATH}/templates/videojs.html > ~/.zen/bunkerbox/$VUID/media/index.html
    sed -i "s/_VUID_/$VUID/g" ~/.zen/bunkerbox/$VUID/media/index.html
    sed -i s/_DATE_/$(date -u "+%Y-%m-%d#%H:%M:%S")/g ~/.zen/bunkerbox/$VUID/media/index.html
    sed -i "s~_TITLE_~$TITLE~g"  ~/.zen/bunkerbox/$VUID/media/index.html
    sed -i "s~_CHANNEL_~$CHANNEL~g"  ~/.zen/bunkerbox/$VUID/media/index.html

    echo ">>>>> ADDING TO IPFS : ipfs add -rwH ~/.zen/bunkerbox/$VUID/media/* "
    echo
    IPFSROOT=$(ipfs add -rwHq  ~/.zen/bunkerbox/$VUID/media/* | tail -n 1)
    INDEX="/ipfs/$IPFSROOT"


    VMAIN="/ipfs/$IPFSROOT/$VUID.m3u8"
    # UPDATING original JSON
    cat ~/.zen/bunkerbox/$VUID/$VUID.json | jq ".video.hlsManifest.url = \"$VMAIN\"" > ~/.zen/bunkerbox/$VUID/media/$VUID.json

    echo "M3U8 : $IPFSNGW$VMAIN"

    ## UPDATE GLOCAL HISTORY ?
    IsThere=$(cat ~/.zen/bunkerbox/history.json | jq .Videos[].link | grep $VUID)
    [[ ! $IsThere ]] && echo "Add $INDEX/$VUID.jpg to history.json" && cat ~/.zen/bunkerbox/history.json | jq '.Videos += [{"link": "<a href='"'_INDEX_'"'><img src='"'_INDEX_/_VUID_.jpg'"' height=80 >'"'_TITLE_'"'</a>"}]' > ~/.zen/bunkerbox/$VUID/media/$VUID.history.json
    sed -i "s~_INDEX_~$INDEX~g" ~/.zen/bunkerbox/$VUID/media/$VUID.history.json
    sed -i "s~_VUID_~$VUID~g" ~/.zen/bunkerbox/$VUID/media/$VUID.history.json
    sed -i "s~_TITLE_~$TITLE~g" ~/.zen/bunkerbox/$VUID/media/$VUID.history.json
    cp -f ~/.zen/bunkerbox/$VUID/media/history.json ~/.zen/bunkerbox/$VUID.history.json

##  (found ''' later) COULD BE DONE LIKE THAT
#    cat ~/.zen/bunkerbox/$VUID/media/$VUID.history.json | jq --arg INDEX "$INDEX" --arg TITLE "$TITLE"  '.Videos += [{"link": "<a href='''$INDEX''' >'''$TITLE'''</a>"}]' > ~/.zen/bunkerbox/history.json

    echo "HIST: $IPFSNGW/ipfs/$IPFSROOT"
    echo "JSON : $IPFSNGW/ipfs/$IPFSROOT/$VUID.json"
##########################################################################
#    cat ~/.zen/bunkerbox/$VUID/media/$VUID.json | jq -r .video.hlsManifest.url

    end=`date +%s`;  echo Duration `expr $end - $start` seconds.

done
