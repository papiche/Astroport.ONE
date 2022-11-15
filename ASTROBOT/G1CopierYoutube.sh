#!/bin/bash
########################################################################
# Version: 0.4
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
echo "-----"
echo "$ME RUNNING"
# Need TW index.html path + IPNS publication Key (available in IPFS keystore)
# Search for "tube" tagged tiddlers to get URL
# Download video, add to ipfs and import new tiddler
# Publish !!

# ASTROBOT FIRST PROCESS
# "Copier youtube" + (voeu) => CopierYoutube (G1Voeu G1CopierYoutube) = ASTROBOT copy Ŋ1 "(G1CopierYoutube)"


INDEX="$1"
[[ ! $INDEX ]] && echo "ERROR - Please provide path to source TW index.html" && exit 1
[[ ! -f $INDEX ]] && echo "ERROR - Fichier TW absent. $INDEX" && exit 1

WISHKEY="$2" ## IPNS KEY NAME - G1PUB - PLAYER ...
[[ ! $WISHKEY ]] && echo "ERROR - Please provide IPFS publish key" && exit 1
TWNS=$(ipfs key list -l | grep -w $WISHKEY | cut -d ' ' -f1)
[[ ! $TWNS ]] && echo "ERROR - Clef IPNS $WISHKEY introuvable!"  && exit 1

# Extract tag=tube from TW into ~/.zen/tmp/$WISHKEY/CopierYoutube.json
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/$WISHKEY

###################################################################
## TODO BOUCLER SUR LES INDEX des G1Astronautes G1Ami
###################################################################
rm -f ~/.zen/tmp/$WISHKEY/CopierYoutube.json
tiddlywiki  --load ${INDEX} \
                    --output ~/.zen/tmp/$WISHKEY \
                    --render '.' 'CopierYoutube.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[CopierYoutube]]'

echo "cat ~/.zen/tmp/$WISHKEY/CopierYoutube.json"

###################################################################
## TEXT TREATMENT
## For this TAG, specific extract URL from text field and copy all video from links into tid.json
for YURL in $(cat ~/.zen/tmp/$WISHKEY/CopierYoutube.json | jq -r '.[].text' | grep 'http'); do
    echo "Detected $YURL"
    echo "Extracting video playlist"

    ### GETTING ALL VIDEO IDs (for playlist copy)
    yt-dlp --print "%(id)s" "${YURL}" >> ~/.zen/tmp/$WISHKEY/ytids.$MOATS

done # FINISH YURL loop

echo "cat ~/.zen/tmp/$WISHKEY/ytids.$MOATS"

###################################################################
[[ ! -s  ~/.zen/tmp/$WISHKEY/ytids.$MOATS ]] && echo "AUCUN YOUTUBEID pour CopierYoutube" && exit  0
###################################################################

###################################################################
# PROCESS YOUTUBEID VIDEO DOWNLOAD AND CREATE TIDDLER in TW
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
        [[ ! -f "$HOME/.zen/tmp/$WISHKEY/$ZFILE"  ]] && ffmpeg -loglevel quiet -i "$HOME/.zen/tmp/$WISHKEY/$TITLE.mkv" -c:v libx264 -c:a aac "$HOME/.zen/tmp/$WISHKEY/$TITLE.mp4" # TRY TO CONVERT MKV TO MP4
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

        MIME=$(file --mime-type -b "$HOME/.zen/tmp/$WISHKEY/$ZFILE")

        ## ADD TAGS
        SEC=$(yt-dlp --print "%(duration)s" "${ZYURL}")
        CHANNEL=$(yt-dlp --print "%(channel)s" "${ZYURL}" | sed -r 's/\<./\U&/g' | sed 's/ //g') # CapitalGluedWords
        PLAYLIST=$(yt-dlp --print "%(playlist)s" "${ZYURL}" | sed -r 's/\<./\U&/g' | sed 's/ //g')
        EXTRATAG="$CHANNEL $PLAYLIST"
        ## PREPARE VIDEO HTML5 CODE
        TEXT="<video controls preload='none' width=100%><source src='/ipfs/"${ILINK}"' type='"${MIME}"'></video><h1><a href='"${ZYURL}"'>"${TITLE}"</a></h1>"

        echo "Creating Youtube ${YID} tiddler : G1CopierYoutube !"
        echo $TEXT

        echo '[
  {
    "created": "'${MOATS}'",
    "title": "'$ZFILE'",
    "type": "'text/vnd.tiddlywiki'",
    "text": "'$TEXT'",
    "mime": "'$MIME'",
    "size": "'${FILE_BSIZE}'",
    "sec": "'${SEC}'",
    "ipfs": "'/ipfs/${ILINK}'",
    "youtubeid": "'${YID}'",
    "tags": "'ipfs G1CopierYoutube ${PLAYER} ${EXTRATAG} ${MIME}'"
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
                        --deletetiddlers '[tag[CopierYoutube]]' \
                        --output ~/.zen/tmp/$WISHKEY --render "$:/core/save/all" "newindex.html" "text/plain"

        if [[ -s ~/.zen/tmp/$WISHKEY/newindex.html ]]; then
            echo "$$$ Mise à jour $INDEX"
            cp ~/.zen/tmp/$WISHKEY/newindex.html $INDEX
        else
            echo "Problem with tiddlywiki command. Missing ~/.zen/tmp/$WISHKEY/newindex.html"
            echo "XXXXXXXXXXXXXXXXXXXXXXX"
        fi

done  < ~/.zen/tmp/$WISHKEY/ytids.$MOATS # FINISH YID loop 1
exit 0
