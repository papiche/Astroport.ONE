#!/bin/bash
########################################################################
# Version: 0.4
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

# Need TW index.html path + IPNS publication Key (available in IPFS keystore)
# Search for "tube" tagged tiddlers to get URL
# Download video, add to ipfs and import new tiddler
# Publish !!

## BEWARE, DO NOT MODIFY TW DURING THIS PROCESS !!
# TODO use crontab to run regularly

INDEX="$1"
[[ ! $INDEX ]] && echo "Please provide path to source TW index.html" && exit 1
[[ ! -f $INDEX ]] && echo "Fichier TW absent. $INDEX" && exit 1

WISHKEY="$2" ## IPNS KEY NAME - G1PUB - PLAYER ...
[[ ! $WISHKEY ]] && echo "Please provide IPFS publish key" && exit 1
TWNS=$(ipfs key list -l | grep -w $WISHKEY | cut -d ' ' -f1)

# Extract tag=tube from TW into ~/.zen/tmp/$WISHKEY/tube.json
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/$WISHKEY

rm -f ~/.zen/tmp/$WISHKEY/tube.json
tiddlywiki --verbose --load ${INDEX} --output ~/.zen/tmp/$WISHKEY --render '.' 'tube.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[tube]]'

## Extract URL from text field
for YURL in $(cat ~/.zen/tmp/$WISHKEY/tube.json | jq -r '.[].text' | grep 'http'); do
    echo "Detected $YURL"
    echo "Extracting video playlist"

    ### GETTING ALL VIDEO IDs (for playlist copy)
    yt-dlp --print "%(id)s" "${YURL}" >> ~/.zen/tmp/$WISHKEY/ytids.$MOATS

done # FINISH YURL loop

###################################################################
###################################################################
while read YID;
        do


        [[ -f ~/.zen/tmp/$WISHKEY/$YID.TW.json ]] && echo "Tiddler json already existing : ~/.zen/tmp/$WISHKEY/$YID.TW.json" && continue

        # SINGLE VIDEO YURL
        ZYURL="https://www.youtube.com/watch?v=$YID";
        echo "YOUTUBE : $ZYURL"

        TITLE="$(yt-dlp --print "%(title)s" "${ZYURL}")"
        TITLE=${TITLE//[^A-zÀ-ÿ0-9 ]/}
        [[ ! $TITLE ]] && continue

        echo ".... Downloading $TITLE.mp4"

        # https://github.com/yt-dlp/yt-dlp#format-selection-examples
        # SUBS ? --write-subs --write-auto-subs --sub-langs "fr, en, en-orig" --embed-subs
        # (bv*[height<=720][vcodec~='^((he|a)vc|h26[45])']+ba)
        # TODO : DELAY COPY OPERATION...  Astro can download quicker at 03:00 AM
        echo "yt-dlp -f \"(bv*[ext=mp4][height<=720]+ba/b[height<=720])\" --no-mtime --embed-thumbnail --add-metadata -o \"$HOME/.zen/tmp/$WISHKEY/$TITLE.%(ext)s\" ${ZYURL}"

        #############################################################################
        ## COPY FROM YOUTUBE (TODO DOUBLE COPY & MKV to MP4 OPTIMISATION)
        yt-dlp  -f "(bv*[ext=mp4][height<=720]+ba/b[height<=720])" \
                    -S "filesize:700M" --no-mtime --embed-thumbnail --add-metadata \
                    --write-subs --write-auto-subs --sub-langs "fr, en, en-orig" --embed-subs \
                    -o "$HOME/.zen/tmp/$WISHKEY/$TITLE.%(ext)s" ${ZYURL}
        ################################################################################
        ### ADAPT TO TW RYTHM (DELAY COPY?)
        echo
        ZFILE="$TITLE.mp4"
        echo "$ZFILE"

        ############################################################################
        ### CHECK RESULT CONVERT MKV TO MP4
        [[ ! -f "$HOME/.zen/tmp/$WISHKEY/$ZFILE"  ]] && ffmpeg -i "$HOME/.zen/tmp/$WISHKEY/$TITLE.mkv" -c:v libx264 -c:a aac "$HOME/.zen/tmp/$WISHKEY/$TITLE.mp4" # TRY TO CONVERT MKV TO MP4
        [[ ! -f "$HOME/.zen/tmp/$WISHKEY/$ZFILE"  ]] && echo "No FILE -- CONTINUE --" && continue
        echo

####################################################
        echo "FOUND : ~/.zen/tmp/$WISHKEY/$ZFILE"
        FILE_BSIZE=$(du -b "$HOME/.zen/tmp/$WISHKEY/$ZFILE" | awk '{print $1}')
        FILE_SIZE=$(echo "${FILE_BSIZE}" | awk '{ split( "B KB MB GB TB PB" , v ); s=1; while( $1>1024 ){ $1/=1024; s++ } printf "%.2f %s", $1, v[s] }')
        echo "FILE SIZE = $FILE_SIZE ($FILE_BSIZE octets)"

        echo "Adding to IPFS"
        ILINK=$(ipfs add -q "$HOME/.zen/tmp/$WISHKEY/$ZFILE" | tail -n 1)
        echo "/ipfs/$ILINK <=> $ZFILE"

        MIME=$(file --mime-type "$HOME/.zen/tmp/$WISHKEY/$ZFILE" | rev | cut -d ' ' -f 1 | rev)

        ## ADD TAGS
        SEC=$(yt-dlp --print "%(duration)s" "${ZYURL}")
        ## PREPARE VIDEO HTML5 CODE
        TEXT="<video controls width=360><source src='/ipfs/"${ILINK}"' type='"${MIME}"'></video><h1><a href='"${ZYURL}"'>"${TITLE}"</a></h1>"

        echo "Creating Youtube ${YID} tiddler"
        echo $TEXT

        echo '[
  {
    "title": "'$ZFILE'",
    "type": "'text/vnd.tiddlywiki'",
    "text": "'$TEXT'",
    "size": "'${FILE_BSIZE}'",
    "sec": "'${SEC}'",
    "ipfs": "'${ILINK}'",
    "youtubeid": "'${YID}'",
    "tags": "'ipfs youtube g1tube ${EXTRATAG} ${MIME}'"
  }
]
' > "$HOME/.zen/tmp/$WISHKEY/$YID.TW.json"


#################################################################
### ADDING $YID.TW.json to TWNS INDEX.html
#################################################################
        echo "=========================="
        echo "Adding $YID tiddler to TW /ipns/$TWNS "

        rm -f ~/.zen/tmp/$WISHKEY/newindex.html

        echo  ">>> Importing $HOME/.zen/tmp/$WISHKEY/$YID.TW.json"

        tiddlywiki --load $INDEX \
                        --import "$HOME/.zen/tmp/$WISHKEY/$YID.TW.json" "application/json" \
                        --deletetiddlers '[tag[tube]]' \
                        --output ~/.zen/tmp/$WISHKEY --render "$:/core/save/all" "newindex.html" "text/plain"

        if [[ -s ~/.zen/tmp/$WISHKEY/newindex.html ]]; then
            echo "Updating $INDEX"
            cp ~/.zen/tmp/$WISHKEY/newindex.html $INDEX
        else
            echo "Problem with tiddlywiki command. Missing ~/.zen/tmp/$WISHKEY/newindex.html"
            echo "XXXXXXXXXXXXXXXXXXXXXXX"
        fi

done  < ~/.zen/tmp/$WISHKEY/ytids.$MOATS # FINISH YID loop 1

## FINAL TW IPNS PUBLISHING
echo "ipfs name publish -k $WISHKEY ($INDEX)"
ILINK=$(ipfs add -q $INDEX | tail -n 1)
echo "/ipfs/$ILINK"
ipfs name publish -k $WISHKEY /ipfs/$ILINK

myIP=$(hostname -I | awk '{print $1}' | head -n 1)

echo "=========================="
echo "Nouveau TW"
echo "http://$myIP:8080/ipns/$TWNS"
# Removing tag=tube
# --deletetiddlers '[tag[tube]]'
