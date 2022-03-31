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

YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1) || echo " warning ipfs daemon not running"
isLAN=$(hostname -I | awk '{print $1}' | head -n 1 | cut -f3 -d '/' | grep -E "(^127\.)|(^192\.168\.)|(^fd42\:)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")

# Fred MadeInZion, [20/03/2022 23:03]
# Script qui capture et transfert dans IPFS les vidéos de https://crowdbunker.com/
IPFSGWESC="https:\/\/tube.copylaradio.com" && IPFSNGW="https://tube.copylaradio.com"
IPFSGWESC="http:\/\/localhost:8080" && IPFSNGW="http://localhost:8080"

[[ ! $isLAN ]] && IPFSGWESC="https:\/\/$(hostname)" && IPFSNGW="https://$(hostname)"

echo "IPFS GATEWAY $IPFSNGW"

## GET LATEST VIDEOS
VWALLURL="https://api.crowdbunker.com/post/all"
curl -s $VWALLURL -H "Accept: application/json" > /tmp/crowd.json

## LOOP THROUGH
for VUID in $(cat /tmp/crowd.json | jq -r '.posts | .[] | .video.id'); do
    [[ "$VUID" == "null" ]] && echo "MESSAGE... Bypassing..." && echo && continue
    echo "Bunker BOX : Adding $VUID"
    mkdir -p /tmp/$VUID/media

    URL="https://api.crowdbunker.com/post/$VUID/details"
    echo "WISHING TO EXPLORE $URL ?"; read TEST;  [[ "$TEST" != "" ]] && echo && continue
    curl -s $URL -H "Accept: application/json" -o /tmp/$VUID/$VUID.json

    # STREAMING LIVE ?
    ISLIVE=$(cat /tmp/$VUID/$VUID.json | jq -r .video.isLiveType)&& [[ "$ISLIVE" == "true" ]] && echo "LIVE... "
    LIVE=$(cat /tmp/$VUID/$VUID.json | jq -r .video.isLiveActive) && [[ "$LIVE" == "true" ]] && echo "STREAMING... Bypassing..." && echo && continue
    DURATION=$(cat /tmp/$VUID/$VUID.json | jq -r .video.duration) && [[ $DURATION == 0 ]] && echo "NOT STARTED YET" && echo && continue
    TITLE=$(cat /tmp/$VUID/$VUID.json | jq -r .video.title) && echo "$TITLE"
    echo "Extracting video.hlsManifest.url from /tmp/$VUID/$VUID.json"
    HLS=$(cat /tmp/$VUID/$VUID.json | jq -r .video.hlsManifest.url)
    MEDIASOURCE=$(echo $HLS | rev | cut -d '/' -f 2- | rev)
    echo "HLS=$HLS"

    echo "READY TO PROCESS ?... $DURATION s"; read TEST;  [[ "$TEST" != "" ]] && echo && continue
    curl -s $HLS -o /tmp/$VUID/$VUID.m3u8
    cat /tmp/$VUID/$VUID.m3u8

   echo ">>>>>>>>>>>>>>>> Downloading VIDEO"

    VIDEOHEAD=$(cat /tmp/$VUID/$VUID.m3u8 | grep -B1 360p | head -n 1)
    VIDEOSRC=$(cat /tmp/$VUID/$VUID.m3u8 | grep 360p | tail -n 1 | cut -f 1 -d '.')
    [[ "$VIDEOSRC" == "" ]] && VIDEOHEAD=$(cat /tmp/$VUID/$VUID.m3u8 | grep -B1 480p | head -n 1) && VIDEOSRC=$(cat /tmp/$VUID/$VUID.m3u8 | grep 480p | tail -n 1 | cut -f 1 -d '.') #New try with 480p
    [[ "$VIDEOSRC" == "" ]] && VIDEOHEAD=$(cat /tmp/$VUID/$VUID.m3u8 | grep -B1 240p | head -n 1) && VIDEOSRC=$(cat /tmp/$VUID/$VUID.m3u8 | grep 240p | tail -n 1 | cut -f 1 -d '.') #New try with 240p
    echo "VIDEOSRC=$MEDIASOURCE/$VIDEOSRC"
    [[ ! -f /tmp/$VUID/media/$VIDEOSRC.m3u8 ]] && curl -s $MEDIASOURCE/$VIDEOSRC.m3u8 -o /tmp/$VUID/$VIDEOSRC.m3u8
    [[ ! -f /tmp/$VUID/media/$VIDEOSRC ]] && curl $MEDIASOURCE/$VIDEOSRC -o /tmp/$VUID/media/$VIDEOSRC
    IPFSVID=$(ipfs add -wrHq /tmp/$VUID/media/$VIDEOSRC | tail -n 1) ## ADD VIDEO TO IPFS

    echo "VIDEO = $IPFSNGW/ipfs/$IPFSVID/$VIDEOSRC"

    echo ">>>>>>>>>>>>>>>> Downloading AUDIO"

    AUDIOLINE=$(cat /tmp/$VUID/$VUID.m3u8 | grep '=AUDIO')
    AUDIOFILE=$(echo $AUDIOLINE | rev | cut -d '.' -f 2- | cut -d '"' -f 1 | rev)
    echo "AUDIO=$MEDIASOURCE/$AUDIOFILE"
    [[ ! -f /tmp/$VUID/media/$AUDIOFILE.m3u8 ]] && curl -s $MEDIASOURCE/$AUDIOFILE.m3u8 -o /tmp/$VUID/$AUDIOFILE.m3u8
    [[ ! -f /tmp/$VUID/media/$AUDIOFILE ]] && curl $MEDIASOURCE/$AUDIOFILE -o /tmp/$VUID/media/$AUDIOFILE
    IPFSAUD=$(ipfs add -wrHq /tmp/$VUID/media/$AUDIOFILE | tail -n 1) ## ADD AUDIO TO IPFS

    echo "AUDIO = $IPFSNGW/ipfs/$IPFSAUD/$AUDIOFILE"

    echo ">>>>>>>>>>>>>>>> VIDEO & AUDIO M3U8 IPFS LINKING"

    #echo "s/$VIDEOSRC/$IPFSGWESC\/ipfs\/$IPFSVID\/$VIDEOSRC/g"
    sed -i "s/$VIDEOSRC/$IPFSGWESC\/ipfs\/$IPFSVID\/$VIDEOSRC/g" /tmp/$VUID/$VIDEOSRC.m3u8
    echo "cat /tmp/$VUID/$VIDEOSRC.m3u8"

    #echo "s/$AUDIOFILE/$IPFSGWESC\/ipfs\/$IPFSAUD\/$AUDIOFILE/g"
    sed -i "s/$AUDIOFILE/$IPFSGWESC\/ipfs\/$IPFSAUD\/$AUDIOFILE/g" /tmp/$VUID/$AUDIOFILE.m3u8
    echo "cat /tmp/$VUID/$AUDIOFILE.m3u8"

    echo "Adding M3U8 to IPFS"
    IPFSVIDM3U8=$(ipfs add -wrHq /tmp/$VUID/$VIDEOSRC.m3u8 | tail -n 1) ## ADD VIDEO.m3u8 TO IPFS
    IPFSAUDM3U8=$(ipfs add -wrHq /tmp/$VUID/$AUDIOFILE.m3u8 | tail -n 1) ## ADD AUDIO.m3u8 TO IPFS

    echo ">>>>>>>>>>>>>>>> CREATING MAIN M3U8"
    echo "#EXTM3U
#EXT-X-VERSION:6
#EXT-X-INDEPENDENT-SEGMENTS

$AUDIOLINE

$VIDEOHEAD
$IPFSNGW/ipfs/$IPFSVIDM3U8/$VIDEOSRC.m3u8

" > /tmp/$VUID/$VUID.m3u8

    sed -i "s/$AUDIOFILE.m3u8/$IPFSGWESC\/ipfs\/$IPFSAUDM3U8\/$AUDIOFILE.m3u8/g" /tmp/$VUID/$VUID.m3u8

    echo "FINAL IPFS"
    IPFSM3U8=$(ipfs add -wrHq /tmp/$VUID/$VUID.m3u8 | tail -n 1)
    VMAIN="$IPFSNGW/ipfs/$IPFSM3U8/$VUID.m3u8"
    echo $VMAIN

    echo ">>>>>>>>>>>>>>>> UPDATING HLS in json"
    cat /tmp/$VUID/$VUID.json | jq ".video.hlsManifest.url = \"$VMAIN\"" > /tmp/$VUID/z_$VUID.json

##########################################################################
    echo ">>>>>>>>>>>>>>>> JOIN MP4 & PUBLISH INDEX"
    # CONVERT TO MP4
#    echo "ffmpeg -i /tmp/$VUID/media/$VIDEOSRC -i /tmp/$VUID/media/$AUDIOFILE -shortest /tmp/$VUID/media/output.mp4"
#    [[ ! -f /tmp/$VUID/media/output.mp4 ]] && ffmpeg -i /tmp/$VUID/media/$VIDEOSRC -i /tmp/$VUID/media/$AUDIOFILE -shortest /tmp/$VUID/media/output.mp4
#    IPFSID=$(ipfs add -wrHq /tmp/$VUID/media/output.mp4 | tail -n 1)

    mkdir -p /tmp/$VUID/public

#    sed "s/_IPFSID_/$IPFSGWESC\/ipfs\/$IPFSID/g" ${MY_PATH}/../templates/video_bunker.html > /tmp/$VUID/public/index.html
    sed "s-_HLS_-$VMAIN-g" ${MY_PATH}/../templates/videojs.html > /tmp/$VUID/public/index.html
    sed -i s/_DATE_/$(date -u "+%Y-%m-%d#%H:%M:%S")/g /tmp/$VUID/public/index.html
    sed -i "s/_PSEUDO_/$TITLE/g"  /tmp/$VUID/public/index.html

    # COPY style AND js
    cp -R ${MY_PATH}/../templates/styles /tmp/$VUID/public/
    cp -R ${MY_PATH}/../templates/js /tmp/$VUID/public/

    echo "ipfs add -rH /tmp/$VUID/public/* "
    IPFSROOT=$(ipfs add -rwHq  /tmp/$VUID/public/* | tail -n 1)
    # Change CSS path to
    sed -i "s/_IPFSROOT_/$IPFSGWESC\/ipfs\/$IPFSROOT/g" /tmp/$VUID/public/index.html
    IPFSROOT=$(ipfs add -rwHq  /tmp/$VUID/public/* | tail -n 1)

    echo "MP4 VIDEO INDEX $IPFSNGW/ipfs/$IPFSROOT"
##########################################################################
    echo $VMAIN
    echo "CONTINUE ?"; read

done
