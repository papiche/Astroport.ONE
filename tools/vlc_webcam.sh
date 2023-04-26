#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/my.sh"

PLAYER="$1"

[[ ${PLAYER} == "" ]] && PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
[[ ${PLAYER} == "" ]] && espeak "ERROR PLAYER - EXIT" && exit 1
PSEUDO=$(cat ~/.zen/game/players/${PLAYER}/.pseudo 2>/dev/null)
[[ $G1PUB == "" ]] && G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null)
[[ $G1PUB == "" ]] && espeak "ERROR G1PUB - EXIT" && exit 1

ASTRONAUTENS=$(ipfs key list -l | grep -w ${PLAYER} | cut -d ' ' -f1)

[[ ! $ASTRONAUTENS ]] && echo "${PLAYER} CLEF IPNS INTROUVABLE - EXIT -" && exit 1

YOU=$(myIpfsApi)
LIBRA=$(myIpfsGw)

mkdir -p ~/.zen/game/players/${PLAYER}/vlog

screencapture(){
vlc \
-i screen://\
--sout "#transcode{vcodec=h264,vb=800,fps=5,scale=1,acodec=none}:duplicate{dst=std{access=file,mux=mp4,dst='${HOME}/Screencapture $(date +%Y-%m-%d) at $(date +%H.%M.%S).mp4'}}"
deskid="$!"

}

if [[ -f ~/.zen/soundrecord.config ]]; then
    source ~/.zen/soundrecord.config
else
    RECDEVICE=$(pactl list short sources | grep input | cut -f 2)
fi

mkdir -p ~/.zen/tmp/

espeak "Hello"
if [[ ! -s ~/.zen/game/players/${PLAYER}/ipfs/G1SSB/_g1.pubkey ]]; then
    espeak "Getting player latest TW. please wait."
    ## GETTING LAST TW via IPFS or HTTP GW
    [[ $YOU ]] && echo "$myIPFS/ipns/${ASTRONAUTENS} ($YOU)" && ipfs --timeout 12s cat  /ipns/${ASTRONAUTENS} > ~/.zen/tmp/vlc_webcam.html
    [[ ! -s ~/.zen/tmp/vlc_webcam.html ]] && echo "$LIBRA/ipns/${ASTRONAUTENS}" && curl -m 12 -so ~/.zen/tmp/vlc_webcam.html "$LIBRA/ipns/${ASTRONAUTENS}"
    [[ ! -s ~/.zen/tmp/vlc_webcam.html ]] && espeak "WARNING. impossible to find your TW online"
    [[ ! -s ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html ]] &&  espeak "FATAL ERROR. No local copy found !" && exit 1
    [[ -s ~/.zen/tmp/vlc_webcam.html ]] && cp -f ~/.zen/tmp/vlc_webcam.html ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html && espeak "OK DONE"
fi
espeak "Start Video recording. Press ENTER to stop !"
# Find "input-slave" :: pactl list short sources

# RECTIME=12
# ${MY_PATH}/displaytimer.sh 12 &
# timeout $RECTIME cvlc v4l2:///dev/video0:width=640:height=480 --input-slave=pulse://alsa_input.usb-HD_Web_Camera_HD_Web_Camera_Ucamera001-02.analog-mono --sout "#transcode{acodec=mpga,ab=128,channels=2,samplerate=44100,threads=4,audio-sync=1}:standard{access=file,mux=mp4,dst=\"$HOME/.zen/tmp/MyVid.mp4\"}"

cvlc v4l2:///dev/video0:width=640:height=480 --input-slave=pulse://$RECDEVICE --sout "#transcode{acodec=mpga,ab=128,channels=2,samplerate=44100,threads=4,audio-sync=1}:standard{access=file,mux=mp4,dst=\"$HOME/.zen/tmp/MyVid.mp4\"}" &
processid="$!"


echo "Press ENTER to stop video recording"
[[ $(echo $DISPLAY | cut -d ':' -f 1) == "" ]] && zenity --warning --width 360 --text "(◕‿‿◕) STOP... " || read
kill -15 $processid

# cvlc v4l2:///dev/video0:width=640:height=480 --input-slave=pulse://alsa_input.usb-HD_Web_Camera_HD_Web_Camera_Ucamera001-02.analog-mono --sout '#transcode{acodec=mpga,ab=128,channels=2,samplerate=44100,threads=4,audio-sync=1}:standard{access=file,mux=mp4,dst='~/.zen/tmp/MyVid.mp4'}' --run-time=$RECTIME --stop-time=$RECTIME cvlc://quit
## RECOMMANCER ?

espeak "video transcoding" #-acodec aac
# Ecran vert : ffmpeg -i input.mp4 -i greenscreen.mp4 -filter_complex '[1:v]colorkey=color=00FF00:similarity=0.85:blend=0.0[ckout];[0:v][ckout]overlay[out]' -map '[out]' output.mp4

rm -f ~/.zen/tmp/output.mp4
ffmpeg -loglevel quiet -i ~/.zen/tmp/MyVid.mp4 -vcodec libx264 -loglevel quiet ~/.zen/tmp/output.mp4

## Create short gif
rm -f ~/.zen/tmp/screen.gif
ffmpeg -loglevel quiet -ss 1.0 -t 1.6 -loglevel quiet -i ~/.zen/tmp/output.mp4 ~/.zen/tmp/screen.gif
ANIMH=$(ipfs add -q ~/.zen/tmp/screen.gif)

# Conversion HLS
ffmpeg -loglevel quiet -i ~/.zen/tmp/output.mp4 -codec: copy -start_number 0 -hls_time 10 -hls_list_size 0 -f hls ~/.zen/tmp/output.m3u8

## ADDING TO IPFS
[[ ! -s ~/.zen/tmp/output.mp4 ]] && espeak "Sorry no video file found" && exit 1
IPFSID=$(ipfs add -wHq ~/.zen/tmp/output.mp4 | tail -n 1)
echo "NEW VIDEO FILE /ipfs/$IPFSID/output.mp4"

echo "FOUND : ~/.zen/tmp/output.mp4"
        FILE_BSIZE=$(du -b "$HOME/.zen/tmp/output.mp4" | awk '{print $1}')
        FILE_SIZE=$(echo "${FILE_BSIZE}" | awk '{ split( "B KB MB GB TB PB" , v ); s=1; while( $1>1024 ){ $1/=1024; s++ } printf "%.2f %s", $1, v[s] }')
        espeak "FILE SIZE = $FILE_SIZE"
espeak "OK"

mkdir -p ~/.zen/game/players/${PLAYER}/vlog

## Creating new video chain index.html
OLDID=$(cat ~/.zen/game/players/${PLAYER}/.vlog.index 2>/dev/null)
if [[ $OLDID ]]; then
    sed s/_OLDID_/$OLDID/g ${MY_PATH}/../templates/video_chain.html > ~/.zen/game/players/${PLAYER}/vlog/${MOATS}.index.html
    sed -i s/_IPFSID_/$IPFSID/g ~/.zen/game/players/${PLAYER}/vlog/${MOATS}.index.html
else
    sed s/_IPFSID_/$IPFSID/g ${MY_PATH}/../templates/video_first.html > ~/.zen/game/players/${PLAYER}/vlog/${MOATS}.index.html
fi
sed -i "s~_DATE_~$(date -u "+%Y-%m-%d#%H:%M:%S")~g" ~/.zen/game/players/${PLAYER}/vlog/${MOATS}.index.html
sed -i "s~_PLAYER_~${PLAYER}~g" ~/.zen/game/players/${PLAYER}/vlog/${MOATS}.index.html
sed -i "s~_ANIMH_~${ANIMH}~g" ~/.zen/game/players/${PLAYER}/vlog/${MOATS}.index.html

mv ~/.zen/game/players/${PLAYER}/vlog/${MOATS}.index.html ~/.zen/game/players/${PLAYER}/vlog/index.html

IPFSROOT=$(ipfs add -rHq ~/.zen/game/players/${PLAYER}/vlog | tail -n 1)
echo $IPFSROOT > ~/.zen/game/players/${PLAYER}/.vlog.index

echo "NEW VIDEO $myIPFS/ipfs/$IPFSROOT"

###########################
## AJOUT VIDEO ASTROPORT TW
###########################

MEDIAID=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/Astroport/${PLAYER}/video/vlog/
MEDIAKEY="VLOG_${PLAYER}_${MEDIAID}"
cp ~/.zen/tmp/output.mp4 ~/Astroport/${PLAYER}/video/vlog/${PLAYER}_$MEDIAID.mp4

REAL=$(file --mime-type -b "$HOME/Astroport/${PLAYER}/video/vlog/${PLAYER}_$MEDIAID.mp4")

## TW not displaying direct ipfs video link (only image, pdf, ...) so insert <video> html tag
TEXT="<video controls width=100% poster='/ipfs/"${ANIMH}"'><source src='/ipfs/"${IPFSID}"/output.mp4' type='"${REAL}"'></video><h1><a href='/ipfs/"${IPFSROOT}"'>VLOG ("${MEDIAID}") Story</a></h1><br>
<\$button class='tc-tiddlylink'><\$list filter='[tag[G1Vlog]]'><\$action-navigate \$to=<<currentTiddler>> \$scroll=no/></\$list>Afficher tous les G1Vlog</\$button>"

echo "## Creation json tiddler"
echo '[
  {
    "created": "'${MOATS}'",
    "title": "'VLOG_${MEDIAID} ${PSEUDO}'",
    "text": "'${TEXT}'",
    "type": "'text/vnd.tiddlywiki'",
    "mediakey": "'${MEDIAKEY}'",
    "mime": "'${REAL}'",
    "story": "'/ipfs/${IPFSROOT}'",
    "size": "'${FILE_BSIZE}'",
    "ipfs": "'/ipfs/${IPFSID}/output.mp4'",
    "gifanime": "'/ipfs/${ANIMH}'",
    "player": "'${PLAYER}'",
    "tags": "'${PLAYER} G1Vlog vlog ipfs'",
    "modified": "'${MOATS}'"
  }
]
' > ~/.zen/game/players/${PLAYER}/vlog/${MEDIAKEY}.dragdrop.json

# LOG
cat ~/.zen/game/players/${PLAYER}/vlog/${MEDIAKEY}.dragdrop.json | jq
cp ~/.zen/game/players/${PLAYER}/vlog/${MEDIAKEY}.dragdrop.json ~/Astroport/${PLAYER}/video/vlog/

## Adding tiddler to PLAYER TW
ASTRONAUTENS=$(ipfs key list -l | grep -w "${PLAYER}" | cut -d ' ' -f 1)

rm -f ~/.zen/tmp/newindex.html

echo "Nouveau TID dans TW ${PSEUDO} : $myIPFS/ipns/$ASTRONAUTENS"
tiddlywiki --load ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html \
                   --import ~/.zen/game/players/${PLAYER}/vlog/${MEDIAKEY}.dragdrop.json "application/json" \
                   --output ~/.zen/tmp --render "$:/core/save/all" "newindex.html" "text/plain"

if [[ -s ~/.zen/tmp/newindex.html ]]; then
espeak "Updating your TW"
echo "PLAYER TW Update..."
    echo "Mise à jour ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html"
    DIFF=$(diff ~/.zen/tmp/newindex.html ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html)
    cp -f ~/.zen/tmp/newindex.html ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

    [[ $DIFF ]] && cp   ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain \
                                    ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain.$(cat ~/.zen/game/players/${PLAYER}/ipfs/moa/.moats)

    TW=$(ipfs add -Hq ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html | tail -n 1)
    ipfs name publish --allow-offline -t 24h --key=${PLAYER} /ipfs/$TW

    [[ $DIFF ]] && echo $TW > ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain
    echo $MOATS > ~/.zen/game/players/${PLAYER}/ipfs/moa/.moats

    espeak "Hip Hip Hip Hurray"

    xdg-open "$myIPFS/ipns/$ASTRONAUTENS/#:[days:created[-1]tag[G1Vlog]]"

    echo "================================================"
    echo "${PLAYER} : $myIPFS/ipns/$ASTRONAUTENS/#:[days:created[-1]tag[G1Vlog]]"
    echo "================================================"
    echo
else
    espeak "Shit hit the fan baby. Sorry something went wrong."
    echo "Une erreur est survenue lors de l'ajout du tiddler VLOG à votre TW"
fi

echo "${PSEUDO} TW VLOG : $myIPFS/ipns/$ASTRONAUTENS/#VLOG_${MEDIAID}"

# ~/.zen/astrXbian/zen/new_file_in_astroport.sh "$HOME/Astroport/${PLAYER}/video/${MEDIAID}/" "output.mp4"  "$G1PUB"

# https://stackoverflow.com/questions/49846400/raspberry-pi-use-vlc-to-stream-webcam-logitech-c920-h264-video-without-tran
# record to MKV cvlc v4l2:///dev/video0:chroma=h264 :input-slave=alsa://hw:1,0 --sout '#transcode{acodec=mpga,ab=128,channels=2,samplerate=44100,threads=4,audio-sync=1}:standard{access=file,mux=mkv,dst='~/.zen/tmp/Webcam_Record/MyVid.mkv'}'
# record to MP4 cvlc v4l2:///dev/video0:chroma=h264 :input-slave=alsa://hw:1,0 --sout '#transcode{acodec=mpga,ab=128,channels=2,samplerate=44100,threads=4,audio-sync=1}:standard{access=file,mux=mp4,dst='~/.zen/tmp/Webcam_Record/MyVid.mp4'}'
# record + stream cvlc v4l2:///dev/video0:chroma=h264 :input-slave=alsa://hw:1,0 --sout '#transcode{acodec=mpga,ab=128,channels=2,samplerate=44100,threads=4,audio-sync=1}:duplicate{dst=standard{access=file,mux=mp4,dst='~/.zen/tmp/Webcam_Record/MyVid.mp4'},dst=standard{access=http,mux=ts,mime=video/ts,dst=:8099}}'
