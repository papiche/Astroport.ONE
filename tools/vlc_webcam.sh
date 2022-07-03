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

#echo "Voulez-vous enregistrer le bureau? ENTER sinon"
#read desktop
#[[ $desktop != "" ]] && screencapture
PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null) || ( espeak "no player. EXIT" && exit 1 )
PSEUDO=$(cat ~/.zen/game/players/.current/.pseudo 2>/dev/null) || ( espeak "no pseudo. EXIT" && exit 1 )
G1PUB=$(cat ~/.zen/game/players/.current/.g1pub 2>/dev/null) || ( espeak "no g1 pub" && exit 1 )
IPFSNODEID=$(cat ~/.zen/game/players/.current/.ipfsnodeid 2>/dev/null) || ( espeak "no ipfs node id" && exit 1 )

espeak "$PSEUDO"
sleep 1
espeak "Starting Video record. Press ENTER to stop."
# Find "input-slave" :: pactl list short sources

# RECTIME=12
# ${MY_PATH}/displaytimer.sh 12 &
# timeout $RECTIME cvlc v4l2:///dev/video0:width=640:height=480 --input-slave=pulse://alsa_input.usb-HD_Web_Camera_HD_Web_Camera_Ucamera001-02.analog-mono --sout "#transcode{acodec=mpga,ab=128,channels=2,samplerate=44100,threads=4,audio-sync=1}:standard{access=file,mux=mp4,dst=\"$HOME/.zen/tmp/MyVid.mp4\"}"

cvlc v4l2:///dev/video0:width=640:height=480 --input-slave=pulse://$RECDEVICE --sout "#transcode{acodec=mpga,ab=128,channels=2,samplerate=44100,threads=4,audio-sync=1}:standard{access=file,mux=mp4,dst=\"$HOME/.zen/tmp/MyVid.mp4\"}" &
processid="$!"
echo "Press ENTER to stop video recording"
read
kill -15 $processid

# cvlc v4l2:///dev/video0:width=640:height=480 --input-slave=pulse://alsa_input.usb-HD_Web_Camera_HD_Web_Camera_Ucamera001-02.analog-mono --sout '#transcode{acodec=mpga,ab=128,channels=2,samplerate=44100,threads=4,audio-sync=1}:standard{access=file,mux=mp4,dst='~/.zen/tmp/MyVid.mp4'}' --run-time=$RECTIME --stop-time=$RECTIME cvlc://quit
## RECOMMANCER ?

espeak "video transcoding" #-acodec aac
# Ecran vert : ffmpeg -i input.mp4 -i greenscreen.mp4 -filter_complex '[1:v]colorkey=color=00FF00:similarity=0.85:blend=0.0[ckout];[0:v][ckout]overlay[out]' -map '[out]' output.mp4

rm -f ~/.zen/tmp/output.mp4
ffmpeg -i ~/.zen/tmp/MyVid.mp4 -vcodec libx264 -loglevel quiet ~/.zen/tmp/output.mp4
# Conversion HLS
ffmpeg -i ~/.zen/tmp/output.mp4 -codec: copy -start_number 0 -hls_time 10 -hls_list_size 0 -f hls ~/.zen/tmp/output.m3u8
IPFSID=$(ipfs add -wrHq ~/.zen/tmp/output.mp4 | tail -n 1)
echo "NEW VIDEO FILE /ipfs/$IPFSID/output.mp4"

espeak "OK"

mkdir -p ~/.zen/game/players/.current/vlog

## Creating new video chain index.html
OLDID=$(cat ~/.zen/game/players/.current/.vlog.index 2>/dev/null)
if [[ $OLDID ]]; then
    sed s/_OLDID_/$OLDID/g ${MY_PATH}/../templates/video_chain.html > /tmp/index.html
    sed -i s/_IPFSID_/$IPFSID/g /tmp/index.html
else
    sed s/_IPFSID_/$IPFSID/g ${MY_PATH}/../templates/video_first.html > /tmp/index.html
fi
sed -i s/_DATE_/$(date -u "+%Y-%m-%d#%H:%M:%S")/g /tmp/index.html
sed s/_PSEUDO_/$PLAYER/g /tmp/index.html > ~/.zen/game/players/.current/vlog/index.html

# Copy style & js
cp -R ${MY_PATH}/../templates/styles ~/.zen/game/players/.current/vlog/
cp -R ${MY_PATH}/../templates/js ~/.zen/game/players/.current/vlog/

IPFSROOT=$(ipfs add -rHq ~/.zen/game/players/.current/vlog | tail -n 1)
echo $IPFSROOT > ~/.zen/game/players/.current/.vlog.index
# Change CSS path to
sed s/_IPFSROOT_/$IPFSROOT/g /tmp/index.html > ~/.zen/game/players/.current/vlog/index.html
IPFSROOT=$(ipfs add -rHq ~/.zen/game/players/.current/vlog | tail -n 1)


echo "NEW VIDEO http://127.0.0.1:8080/ipfs/$IPFSROOT"
## OUVERTURE VLOG CHAIN
xdg-open "http://127.0.0.1:8080/ipfs/$IPFSROOT"

## AJOUT VIDEO ASTROPORT

MEDIAID="$(date -u +%s%N | cut -b1-13)"
mkdir -p ~/astroport/video/${MEDIAID}/
MEDIAKEY="VIDEO_${MEDIAID}"
cp ~/.zen/tmp/output.mp4 ~/astroport/video/${MEDIAID}/

~/.zen/astrXbian/zen/new_file_in_astroport.sh "$HOME/astroport/video/${MEDIAID}/" "output.mp4"  "$G1PUB"

# https://stackoverflow.com/questions/49846400/raspberry-pi-use-vlc-to-stream-webcam-logitech-c920-h264-video-without-tran
# record to MKV cvlc v4l2:///dev/video0:chroma=h264 :input-slave=alsa://hw:1,0 --sout '#transcode{acodec=mpga,ab=128,channels=2,samplerate=44100,threads=4,audio-sync=1}:standard{access=file,mux=mkv,dst='~/.zen/tmp/Webcam_Record/MyVid.mkv'}'
# record to MP4 cvlc v4l2:///dev/video0:chroma=h264 :input-slave=alsa://hw:1,0 --sout '#transcode{acodec=mpga,ab=128,channels=2,samplerate=44100,threads=4,audio-sync=1}:standard{access=file,mux=mp4,dst='~/.zen/tmp/Webcam_Record/MyVid.mp4'}'
# record + stream cvlc v4l2:///dev/video0:chroma=h264 :input-slave=alsa://hw:1,0 --sout '#transcode{acodec=mpga,ab=128,channels=2,samplerate=44100,threads=4,audio-sync=1}:duplicate{dst=standard{access=file,mux=mp4,dst='~/.zen/tmp/Webcam_Record/MyVid.mp4'},dst=standard{access=http,mux=ts,mime=video/ts,dst=:8099}}'
