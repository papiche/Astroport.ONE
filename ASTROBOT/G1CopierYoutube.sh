#!/bin/bash
########################################################################
# Version: 0.4
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/../tools/my.sh"

echo "-----"
echo "$ME RUNNING"

# ASTROBOT FIRST SPECIFIC PROCESS
# "Copier youtube" + (voeu) => CopierYoutube (G1Voeu G1CopierYoutube) = ASTROBOT copy Ŋ1 "(G1CopierYoutube)"


INDEX="$1"
[[ ! ${INDEX} ]] && echo "ERROR - Please provide path to source TW index.html" && exit 1
[[ ! -s ${INDEX} ]] && echo "ERROR - Fichier TW absent. ${INDEX}" && exit 1

PLAYER="$2"
[[ ! $PLAYER ]] && echo "ERROR - Please provide IPFS publish key" && exit 1

ASTONAUTENS=$(ipfs key list -l | grep -w $PLAYER | cut -d ' ' -f1)
[[ ! $ASTONAUTENS ]] && echo "ERROR - Clef IPNS $PLAYER introuvable!"  && exit 1

G1PUB=$(cat ~/.zen/game/players/$PLAYER/.g1pub)

# Extract tag=tube from TW
MOATS="$3"
[[ ! $MOATS ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

###################################################################
## CREATE APP NODE PLAYER PUBLICATION DIRECTORY
###################################################################
mkdir -p $HOME/.zen/tmp/$IPFSNODEID/G1CopierYoutube/$PLAYER/
mkdir -p $HOME/.zen/game/players/$PLAYER/G1CopierYoutube/

###################################################################
## tag[CopierYoutube] EXTRACT ~/.zen/tmp/CopierYoutube.json FROM TW
###################################################################
rm -f ~/.zen/game/players/$PLAYER/G1CopierYoutube/CopierYoutube.json
tiddlywiki  --load ${INDEX} \
                    --output ~/.zen/game/players/$PLAYER/G1CopierYoutube \
                    --render '.' 'CopierYoutube.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[CopierYoutube]]'

echo "DEBUG : cat ~/.zen/game/players/$PLAYER/G1CopierYoutube/CopierYoutube.json | jq -r"

        BROWSER=$(xdg-settings get default-web-browser | cut -d '.' -f 1 | cut -d '-' -f 1) ## GET cookies-from-browser

###################################################################
## URL EXTRACTION & yt-dlp.cache.$PLAYER upgrade
for YURL in $(cat ~/.zen/game/players/$PLAYER/G1CopierYoutube/CopierYoutube.json | jq -r '.[].text' | grep 'http'); do
    echo "G1CopierYoutube : $YURL"
    echo "Extracting video playlist into yt-dlp.cache.$PLAYER"

    ### yt-dlp.command
    CMD=$(cat ~/.zen/game/players/$PLAYER/G1CopierYoutube/yt-dlp.command 2>/dev/null | grep "$YURL" | tail -n 1)
    if [[ ! $CMD ]]; then
        echo "$PLAYER&$YURL:$MOATS" >> ~/.zen/game/players/$PLAYER/G1CopierYoutube/yt-dlp.command
        echo "NOUVEAU CANAL $PLAYER&$YURL:$MOATS"
        lastrun=$MOATS
        duree=604800000
    else
        lastrun=$(echo "$CMD" | rev | cut -d ':' -f 1 | rev) && echo "$CMD"
        duree=$(expr ${MOATS} - $lastrun)
    fi
        # ONE WEEK NEW SCAN
        if [[ $duree -ge 604800000 || ! -s ~/.zen/game/players/$PLAYER/G1CopierYoutube/yt-dlp.cache.$PLAYER ]]; then
            yt-dlp --cookies-from-browser $BROWSER --print "%(id)s&%(webpage_url)s" "${YURL}" >> ~/.zen/game/players/$PLAYER/G1CopierYoutube/yt-dlp.cache.$PLAYER
            sed -i "s~$lastrun~$MOATS~g" ~/.zen/game/players/$PLAYER/G1CopierYoutube/yt-dlp.command # UPDATE LASTRUN
        fi

done # FINISH YURL loop

## CREATE SORT UNIQ SHUFFLED ~/.zen/tmp/$IPFSNODEID/yt-dlp.cache.$PLAYER (12345 ONLINE)
cat ~/.zen/game/players/$PLAYER/G1CopierYoutube/yt-dlp.cache.$PLAYER 2>/dev/null | sort | uniq | shuf > ~/.zen/tmp/$IPFSNODEID/yt-dlp.cache.$PLAYER

###################################################################
[[ ! -s  ~/.zen/tmp/$IPFSNODEID/yt-dlp.cache.$PLAYER ]] && echo "AUCUN YOUTUBEID pour CopierYoutube" && exit  0
###################################################################
boucle=0
###################################################################
# PROCESS YOUTUBEID VIDEO DOWNLOAD AND CREATE TIDDLER in TW
###################################################################
while read LINE;
        do

        YID="$(echo "$LINE" | cut -d '&' -f 1)"

###################################################################
## Search for $YID.TW.json TIDDLER in local & MySwarm cache
        echo "--- CACHE SEARCH FOR $YID ---" && TIDDLER=$(ls -t ~/.zen/game/players/*/G1CopierYoutube/$YID.TW.json 2>/dev/null | head -n 1)
        [[ ! $TIDDLER ]] && TIDDLER=$(ls -t ~/.zen/tmp/$IPFSNODEID/G1CopierYoutube/*/$YID.TW.json 2>/dev/null | head -n 1)
        [[ ! $TIDDLER ]] && TIDDLER=$(ls -t ~/.zen/tmp/swarm/*/G1CopierYoutube/*/$YID.TW.json 2>/dev/null | head -n 1)
        [[ $TIDDLER ]] && echo "Tiddler Found in CACHE  : $TIDDLER" || echo "EMPTY."
###################################################################

if [[ ! ${TIDDLER} ]]; then
###################################################################
# COPY VIDEO AND MAKE TIDDLER
###################################################################
        ZYURL=$(echo "$LINE" | cut -d '&' -f 2-)
        echo "COPIE : $ZYURL"

        [[ $boucle == 13 ]] && echo "MAXIMUM COPY REACHED FOR TODAY" && continue

        TITLE="$(yt-dlp --cookies-from-browser $BROWSER --print "%(title)s" "${ZYURL}"  | detox --inline)"
        [[ ! $TITLE ]] && echo "NO TITLE" && continue

        start=`date +%s`

        echo ".... Downloading $TITLE.mp4"
        # https://github.com/yt-dlp/yt-dlp#format-selection-examples
        # SUBS ? --write-subs --write-auto-subs --sub-langs "fr, en, en-orig" --embed-subs
        # (bv*[height<=720][vcodec~='^((he|a)vc|h26[45])']+ba)
        # TODO : DELAY COPY OPERATION...  Astro can download quicker at 03:00 AM
        echo "yt-dlp -f \"(bv*[ext=mp4][height<=720]+ba/b[height<=720])\" --no-mtime --embed-thumbnail --add-metadata -o \"$HOME/.zen/tmp/yt-dlp/$TITLE.%(ext)s\" ${ZYURL}"

        #############################################################################
        ## COPY FROM YOUTUBE (TODO DOUBLE COPY & MKV to MP4 OPTIMISATION)
        ## EXTRA PARAM TO TRY
        #  --write-subs --write-auto-subs --sub-langs "fr, en, en-orig" --embed-subs

        yt-dlp  -f "(bv*[ext=mp4][height<=720]+ba/b[height<=720])" \
                    --cookies-from-browser $BROWSER \
                    --download-archive $HOME/.zen/.yt-dlp.list \
                    -S res,ext:mp4:m4a --recode mp4 --no-mtime --embed-thumbnail --add-metadata \
                    -o "$HOME/.zen/tmp/yt-dlp/$TITLE.%(ext)s" ${ZYURL}

        ################################################################################
        ### ADAPT TO TW RYTHM (DELAY COPY?)
        echo
        ZFILE="$TITLE.mp4"

        ############################################################################
        ### CHECK RESULT CONVERT MKV TO MP4
        [[ -s "$HOME/.zen/tmp/yt-dlp/$TITLE.mkv"  ]] && ffmpeg -loglevel quiet -i "$HOME/.zen/tmp/yt-dlp/$TITLE.mkv" -c:v libx264 -c:a aac "$HOME/.zen/tmp/yt-dlp/$TITLE.mp4" # TRY TO CONVERT MKV TO MP4
        [[ ! -s "$HOME/.zen/tmp/yt-dlp/$ZFILE"  ]] && echo "No FILE -- CONTINUE --" && continue
        echo

####################################################
        echo "FOUND : ~/.zen/tmp/yt-dlp/$ZFILE"
        FILE_BSIZE=$(du -b "$HOME/.zen/tmp/yt-dlp/$ZFILE" | awk '{print $1}')
        FILE_SIZE=$(echo "${FILE_BSIZE}" | awk '{ split( "B KB MB GB TB PB" , v ); s=1; while( $1>1024 ){ $1/=1024; s++ } printf "%.2f %s", $1, v[s] }')
        echo "$boucle - $ZFILE - FILE SIZE = $FILE_SIZE ($FILE_BSIZE octets)"

        ## LIMIT TO 12 MAXIMUM COPY PER DAY PER PLAYER
        boucle=$((boucle+1))
        espeak "GOOD! Video Number $boucle = $FILE_SIZE" > /dev/null 2>&1


        ### CREATE GIF ANIM
        $(${MY_PATH}/../tools/make_video_gifanim_ipfs.sh "$HOME/.zen/tmp/yt-dlp" "$ZFILE" | tail -n 1) ## export ANIMH
        echo "/ipfs/$ANIMH"
        ## Create gifanime ##  TODO Search for similarities BEFORE ADD


        echo "Adding to IPFS"
        ILINK=$(ipfs add -q "$HOME/.zen/tmp/yt-dlp/$ZFILE" | tail -n 1)
        echo "/ipfs/$ILINK === $ZFILE"

        MIME=$(file --mime-type -b "$HOME/.zen/tmp/yt-dlp/$ZFILE")

        ## ADD TAGS
        SEC=$(yt-dlp --cookies-from-browser $BROWSER --print "%(duration)s" "${ZYURL}")
        CHANNEL=$(yt-dlp --cookies-from-browser $BROWSER --print "%(channel)s" "${ZYURL}" | sed -r 's/\<./\U&/g' | sed 's/ //g') # CapitalGluedWords
        PLAYLIST=$(yt-dlp --cookies-from-browser $BROWSER --print "%(playlist)s" "${ZYURL}" | sed -r 's/\<./\U&/g' | sed 's/ //g')
        EXTRATAG="$CHANNEL $PLAYLIST"
        ## PREPARE VIDEO HTML5 CODE
        TEXT="<video controls width=100% poster='/ipfs/"${ANIMH}"'><source src='/ipfs/"${ILINK}"' type='"${MIME}"'></video>
        <br>{{!!filesize}} - {{!!duration}} sec. - vtratio(dur) =  {{!!vtratio}} ({{!!dur}})<br>
        <h1><a href='"${ZYURL}"'>"${TITLE}"</a></h1>"

        end=`date +%s`
        dur=`expr $end - $start`

        echo "Creating Youtube ${YID} tiddler : G1CopierYoutube !"
        echo $TEXT

        echo '[
  {
    "created": "'${MOATS}'",
    "resolution": "'${RES}'",
    "duree": "'${DUREE}'",
    "duration": "'${DURATION}'",
    "giftime": "'${PROBETIME}'",
    "gifanime": "'/ipfs/${ANIMH}'",
    "modified": "'${MOATS}'",
    "title": "'$ZFILE'",
    "type": "'text/vnd.tiddlywiki'",
    "vtratio": "'${VTRATIO}'",
    "text": "'$TEXT'",
    "g1pub": "'${G1PUB}'",
    "mime": "'${MIME}'",
    "size": "'${FILE_BSIZE}'",
    "filesize": "'${FILE_SIZE}'",
    "sec": "'${SEC}'",
    "dur": "'${dur}'",
    "ipfs": "'/ipfs/${ILINK}'",
    "youtubeid": "'${YID}'",
    "tags": "'ipfs G1CopierYoutube ${PLAYER} ${EXTRATAG} ${MIME}'"
  }
]
' > "$HOME/.zen/tmp/$IPFSNODEID/G1CopierYoutube/$PLAYER/$YID.TW.json"

    TIDDLER="$HOME/.zen/tmp/$IPFSNODEID/G1CopierYoutube/$PLAYER/$YID.TW.json"

else
    ###################################################################
    echo '# TIDDLER WAS IN CACHE'
    ###################################################################
    ## TODO : ADD EMAIL TAG ( TIMESTAMP & ADD SIGNATURE over existing ones)
    continue
fi

cp -f "${TIDDLER}" "$HOME/.zen/game/players/$PLAYER/G1CopierYoutube/"


#################################################################
### ADDING $YID.TW.json to ASTONAUTENS INDEX.html
#################################################################
        echo "=========================="
        echo "Adding $YID tiddler to TW /ipns/$ASTONAUTENS "

        rm -f ~/.zen/tmp/$IPFSNODEID/newindex.html

        echo  ">>> Importing $HOME/.zen/game/players/$PLAYER/G1CopierYoutube/$YID.TW.json"

        tiddlywiki --load ${INDEX} \
                        --import "$HOME/.zen/game/players/$PLAYER/G1CopierYoutube/$YID.TW.json" "application/json" \
                        --output ~/.zen/tmp/$IPFSNODEID --render "$:/core/save/all" "newindex.html" "text/plain"

# --deletetiddlers '[tag[CopierYoutube]]' ### REFRESH CHANNEL COPY

        if [[ -s ~/.zen/tmp/$IPFSNODEID/newindex.html ]]; then

            ## COPY JSON TIDDLER TO PLAYER
            ln -s "$HOME/.zen/game/players/$PLAYER/G1CopierYoutube/$YID.TW.json" "$HOME/.zen/game/players/$PLAYER/G1CopierYoutube/$ZFILE.json"

            [[ $(diff ~/.zen/tmp/$IPFSNODEID/newindex.html ${INDEX} ) ]] && cp ~/.zen/tmp/$IPFSNODEID/newindex.html ${INDEX} && echo "===> Mise à jour ${INDEX}"

        else
            echo "Problem with tiddlywiki command. Missing ~/.zen/tmp/$IPFSNODEID/newindex.html"
            echo "XXXXXXXXXXXXXXXXXXXXXXX"
        fi

done  < ~/.zen/tmp/$IPFSNODEID/yt-dlp.cache.$PLAYER # FINISH YID loop 1


exit 0
