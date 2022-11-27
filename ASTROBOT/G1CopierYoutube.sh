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

## TODO USE API 1234 & new_file_in_astroport.sh FOR TW

# ASTROBOT FIRST PROCESS
# "Copier youtube" + (voeu) => CopierYoutube (G1Voeu G1CopierYoutube) = ASTROBOT copy Ŋ1 "(G1CopierYoutube)"
IPFSNODEID=$(ipfs id -f='<id>\n')

INDEX="$1"
[[ ! $INDEX ]] && echo "ERROR - Please provide path to source TW index.html" && exit 1
[[ ! -f $INDEX ]] && echo "ERROR - Fichier TW absent. $INDEX" && exit 1

WISHKEY="$2" ## IPNS KEY NAME - G1PUB - PLAYER ...
[[ ! $WISHKEY ]] && echo "ERROR - Please provide IPFS publish key" && exit 1
TWNS=$(ipfs key list -l | grep -w $WISHKEY | cut -d ' ' -f1)
[[ ! $TWNS ]] && echo "ERROR - Clef IPNS $WISHKEY introuvable!"  && exit 1

# Extract tag=tube from TW
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/$IPFSNODEID

###################################################################
## TODO BOUCLER SUR LES INDEX des G1Astronautes G1Ami
###################################################################
rm -f ~/.zen/tmp/CopierYoutube.json
tiddlywiki  --load ${INDEX} \
                    --output ~/.zen/tmp \
                    --render '.' 'CopierYoutube.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[CopierYoutube]]'

echo "cat ~/.zen/tmp/CopierYoutube.json | jq -r"

### MAKE CACHE REFRESH FUNCTION
#~ #############################
#~ ## Refresh _12345.sh IPNS Memories
#~ # ipfs name publish --key "MySwarm_$IPFSNODEID" --allow-offline /ipfs/$SWARMH
#~ MySwarm=$(ipfs key list -l | grep "MySwarm_$IPFSNODEID" | cut -d ' ' -f 1)
#~ if [[ $MySwarm ]]; then
#~ #############################
    #~ mkdir -p ~/.zen/tmp/$MySwarm && rm -Rf ~/.zen/tmp/$MySwarm/*.*

    #~ echo "## Getting Station MySwarm /ipns/$MySwarm"
    #~ ipfs --timeout 12s get -o ~/.zen/tmp/$MySwarm /ipns/$MySwarm

    #~ echo "## Rebuild  ~/.zen/tmp/$IPFSNODEID/yt-dlp.command & yt-dlp.cache"
    #~ cat ~/.zen/tmp/$MySwarm/*/yt-dlp.command  ~/.zen/tmp/$IPFSNODEID/yt-dlp.command | sort | uniq > ~/.zen/tmp/$IPFSNODEID/yt-dlp.command
    #~ cat ~/.zen/tmp/$MySwarm/*/yt-dlp.cache ~/.zen/tmp/$IPFSNODEID/yt-dlp.cache | sort | uniq > ~/.zen/tmp/$IPFSNODEID/yt-dlp.cache

#~ #############################
#~ fi

###################################################################
## TEXT TREATMENT
## For this TAG, specific extract URL from text field and copy all video from links into tid.json
for YURL in $(cat ~/.zen/tmp/CopierYoutube.json | jq -r '.[].text' | grep 'http'); do
    echo "Detected $YURL"
    echo "Extracting video playlist"

        ### yt-dlp.command
    [[ ! $(cat ~/.zen/tmp/$IPFSNODEID/yt-dlp.command 2>/dev/null | grep "$YURL") ]] \
    && echo "$WISHKEY&$YURL" >> ~/.zen/tmp/$IPFSNODEID/yt-dlp.command

    yt-dlp --print "%(id)s&%(webpage_url)s" "${YURL}" >> ~/.zen/tmp/$IPFSNODEID/yt-dlp.cache.$WISHKEY

done # FINISH YURL loop

## SORT UNIQ CACHE
cat ~/.zen/tmp/$IPFSNODEID/yt-dlp.cache.$WISHKEY | sort | uniq > ~/.zen/tmp/yt-dlp.cache
cp ~/.zen/tmp/yt-dlp.cache ~/.zen/tmp/$IPFSNODEID/yt-dlp.cache.$WISHKEY

###################################################################
[[ ! -s  ~/.zen/tmp/$IPFSNODEID/yt-dlp.cache.$WISHKEY ]] && echo "AUCUN YOUTUBEID pour CopierYoutube" && exit  0
###################################################################

###################################################################
# PROCESS YOUTUBEID VIDEO DOWNLOAD AND CREATE TIDDLER in TW
###################################################################
while read LINE;
        do

        YID=$(echo "$LINE" | cut -d '&' -f 2)
        [[ -s ~/.zen/tmp/$IPFSNODEID/$YID.TW.json ]] && echo "Tiddler json already existing : ~/.zen/tmp/$IPFSNODEID/$YID.TW.json" && continue ## TODO :: CHECK IF ALREADY YOURS OR NOT :: THEN ADD2TW / SEND MESSAGE ?

        # SINGLE VIDEO YURL
        ZYURL=$(echo "$LINE" | cut -d '&' -f 3-)
        echo "COPIE : $ZYURL"

        TITLE="$(yt-dlp --print "%(title)s" "${ZYURL}")"
        TITLE=${TITLE//[^A-zÀ-ÿ0-9 ]/}
        [[ ! $TITLE ]] && echo "NO TITLE" && continue

        echo ".... Downloading $TITLE.mp4"

        # https://github.com/yt-dlp/yt-dlp#format-selection-examples
        # SUBS ? --write-subs --write-auto-subs --sub-langs "fr, en, en-orig" --embed-subs
        # (bv*[height<=720][vcodec~='^((he|a)vc|h26[45])']+ba)
        # TODO : DELAY COPY OPERATION...  Astro can download quicker at 03:00 AM
        echo "yt-dlp -f \"(bv*[ext=mp4][height<=720]+ba/b[height<=720])\" --no-mtime --embed-thumbnail --add-metadata -o \"$HOME/.zen/tmp/yt-dlp/$TITLE.%(ext)s\" ${ZYURL}"

        #############################################################################
        ## COPY FROM YOUTUBE (TODO DOUBLE COPY & MKV to MP4 OPTIMISATION)
        ## EXTRA PARAM TO TRY
        # --cookies-from-browser browser (xdg-settings get default-web-browser) allow member copies
        # --dateafter DATE --download-archive myarchive.txt
        yt-dlp  -f "(bv*[ext=mp4][height<=720]+ba/b[height<=720])" \
                    --download-archive $HOME/.zen/.yt-dlp.list \
                    -S "filesize:700M" --no-mtime --embed-thumbnail --add-metadata \
                    --write-subs --write-auto-subs --sub-langs "fr, en, en-orig" --embed-subs \
                    -o "$HOME/.zen/tmp/yt-dlp/$TITLE.%(ext)s" ${ZYURL}
        ################################################################################
        ### ADAPT TO TW RYTHM (DELAY COPY?)
        echo
        ZFILE="$TITLE.mp4"
        echo "$ZFILE"

        ############################################################################
        ### CHECK RESULT CONVERT MKV TO MP4
        [[ ! -f "$HOME/.zen/tmp/yt-dlp/$ZFILE"  ]] && ffmpeg -loglevel quiet -i "$HOME/.zen/tmp/yt-dlp/$TITLE.mkv" -c:v libx264 -c:a aac "$HOME/.zen/tmp/yt-dlp/$TITLE.mp4" # TRY TO CONVERT MKV TO MP4
        [[ ! -f "$HOME/.zen/tmp/yt-dlp/$ZFILE"  ]] && echo "No FILE -- CONTINUE --" && continue
        echo

####################################################
        echo "FOUND : ~/.zen/tmp/yt-dlp/$ZFILE"
        FILE_BSIZE=$(du -b "$HOME/.zen/tmp/yt-dlp/$ZFILE" | awk '{print $1}')
        FILE_SIZE=$(echo "${FILE_BSIZE}" | awk '{ split( "B KB MB GB TB PB" , v ); s=1; while( $1>1024 ){ $1/=1024; s++ } printf "%.2f %s", $1, v[s] }')
        echo "FILE SIZE = $FILE_SIZE ($FILE_BSIZE octets)"

        echo "Adding to IPFS"
        ILINK=$(ipfs add -q "$HOME/.zen/tmp/yt-dlp/$ZFILE" | tail -n 1)
        echo "/ipfs/$ILINK <=> $ZFILE"

        MIME=$(file --mime-type -b "$HOME/.zen/tmp/yt-dlp/$ZFILE")

        ## ADD TAGS
        SEC=$(yt-dlp --print "%(duration)s" "${ZYURL}")
        CHANNEL=$(yt-dlp --print "%(channel)s" "${ZYURL}" | sed -r 's/\<./\U&/g' | sed 's/ //g') # CapitalGluedWords
        PLAYLIST=$(yt-dlp --print "%(playlist)s" "${ZYURL}" | sed -r 's/\<./\U&/g' | sed 's/ //g')
        EXTRATAG="$CHANNEL $PLAYLIST"
        ## PREPARE VIDEO HTML5 CODE
        TEXT="<video controls width=100%><source src='/ipfs/"${ILINK}"' type='"${MIME}"'></video><h1><a href='"${ZYURL}"'>"${TITLE}"</a></h1>"

        echo "Creating Youtube ${YID} tiddler : G1CopierYoutube !"
        echo $TEXT

        echo '[
  {
    "created": "'${MOATS}'",
    "modified": "'${MOATS}'",
    "title": "'$ZFILE'",
    "type": "'text/vnd.tiddlywiki'",
    "text": "'$TEXT'",
    "mime": "'$MIME'",
    "size": "'${FILE_BSIZE}'",
    "sec": "'${SEC}'",
    "ipfs": "'/ipfs/${ILINK}'",
    "youtubeid": "'${YID}'",
    "tags": "'ipfs G1CopierYoutube ${WISHKEY} ${EXTRATAG} ${MIME}'"
  }
]
' > "$HOME/.zen/tmp/$IPFSNODEID/$YID.TW.json"


#################################################################
### ADDING $YID.TW.json to TWNS INDEX.html
#################################################################
        echo "=========================="
        echo "Adding $YID tiddler to TW /ipns/$TWNS "

        rm -f ~/.zen/tmp/$IPFSNODEID/newindex.html

        echo  ">>> Importing $HOME/.zen/tmp/$IPFSNODEID/$YID.TW.json"

        tiddlywiki --load $INDEX \
                        --import "$HOME/.zen/tmp/$IPFSNODEID/$YID.TW.json" "application/json" \
                        --output ~/.zen/tmp/$IPFSNODEID --render "$:/core/save/all" "newindex.html" "text/plain"

# --deletetiddlers '[tag[CopierYoutube]]' ### REFRESH CHANNEL COPY

        if [[ -s ~/.zen/tmp/$IPFSNODEID/newindex.html ]]; then
            echo "$$$ Mise à jour $INDEX"
            cp ~/.zen/tmp/$IPFSNODEID/newindex.html $INDEX
        else
            echo "Problem with tiddlywiki command. Missing ~/.zen/tmp/$IPFSNODEID/newindex.html"
            echo "XXXXXXXXXXXXXXXXXXXXXXX"
        fi

done  < ~/.zen/tmp/$IPFSNODEID/yt-dlp.cache # FINISH YID loop 1
exit 0
