#!/bin/bash
## Create gifanime ##  TODO Search for similarities BEFORE ADD
## "(✜‿‿✜) GIFANIME $PROBETIME (✜‿‿✜)"
# FORMAT MP4 max 720p
# PHI GIFANIM CREATION
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
path="$1"
file="$2"

length=${#path}
last_char=${path:length-1:1}
[[ $last_char != "/" ]] && path="$path/"; :
[[ ! -s "${path}${file}" ]] && echo "Nothing Found, please check \"${path}${file}\"" && exit 1

MIME=$(file --mime-type -b "${path}${file}")
HOP=0
#################################################################################################################
############# CONVERT NOT MP4
        [[ ! $MIME == "video/mp4"  ]] \
        && echo "MP4 CONVERSION PLEASE WAIT" 2>/dev/null \
        && ffmpeg -loglevel error -i "${path}${file}" -c:v libx264 -c:a aac "${path}${file}.mp4" \
        && [[ -s "${path}${file}.mp4" ]] && rm "${path}${file}" && file="${file}.mp4"  && extension="mp4" && MIME=$(file --mime-type -b "${path}${file}") && HOP=1

FILE_RES=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "${path}${file}" | cut -d "x" -f 2)
RES=${FILE_RES%?}0p

#################################################################################################################
############# VIDEO LINES MAX IS 720p
LINES=$(echo $RES | tr -dc '0-9')
[ $LINES -gt 720 ] \
&& echo "VIDEO RESIZING HALF PLEASE WAIT" 2>/dev/null \
&& ffmpeg -loglevel quiet -i "${path}${file}" -vf "scale=iw/2:ih/2" "${path}2${file}" \
&& [[ -s "${path}2${file}" ]] && rm "${path}${file}" && mv "${path}2${file}" "${path}${file}" \
&& FILE_RES=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "${path}${file}" | cut -d "x" -f 2) \
&& RES=${FILE_RES%?}0p && echo $RES && HOP=2
#################################################################################################################

FILE_BSIZE=$(du -b "${path}${file}" | awk '{print $1}')

DURATION=$(ffprobe -v error -i "${path}${file}" -show_entries format=duration -v quiet -of csv="p=0" | cut -d '.' -f 1)
DUREE=$(ffprobe -v error -i "${path}${file}" -show_entries format=duration -sexagesimal -v quiet -of csv="p=0"| cut -d '.' -f 1)

PROBETIME=$(echo "0.618 * $DURATION" | bc -l | cut -d '.' -f 1)
[[ ! $PROBETIME ]] && PROBETIME="1.0"

## How many seconds are encoded by MB ?
VTRATIO=$(echo "$DURATION / $FILE_BSIZE * 1024 * 1024" | bc -l | xargs printf "%.2f")

## CREATE SOME INDEX HOOKS
# ffmpeg -skip_frame nokey -i ${path}${file} -vsync 0 -r 30 -f image2 thumbnails-%02d.jpeg

rm -f ~/.zen/tmp/screen.gif
ffmpeg -loglevel quiet -ss $PROBETIME -t 1.6 -loglevel quiet -i "${path}${file}" ~/.zen/tmp/screen.gif
[ ! -s ~/.zen/tmp/screen.gif ] && cp $MY_PATH/../images/CAP_theorem.png ~/.zen/tmp/screen.gif
ANIMH=$(ipfs add -q ~/.zen/tmp/screen.gif)
ipfs pin rm $ANIMH
cp ~/.zen/tmp/screen.gif "${path}${file}.gif"

## -- cross "bash tail -n 1" variable setting in return --- BASH TRICK ;)
echo "export HOP=$HOP ANIMH=$ANIMH PROBETIME=$PROBETIME DURATION=$DURATION DUREE=$DUREE RES=$RES MIME=$MIME VTRATIO=$VTRATIO file=$file"
exit 0
