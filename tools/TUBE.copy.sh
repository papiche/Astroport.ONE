#!/bin/bash
########################################################################
# Version: 0.3
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

WISHKEY="$2"
[[ ! $WISHKEY ]] && echo "Please provide IPFS publish key" && exit 1
WNS=$(ipfs key list -l | grep -w $WISHKEY | cut -d ' ' -f1)

# Extract tag=tube from TW
rm -f ~/.zen/tmp/tiddlers.json
tiddlywiki --verbose --load ${INDEX} --output ~/.zen/tmp --render '.' 'tiddlers.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[tube]]'

## Extract URL from text field
for yurl in $(cat ~/.zen/tmp/tiddlers.json | jq -r '.[].text' | grep 'http'); do
        echo "Detected $yurl"
        echo "Start Downloading"

        mkdir -p ~/.zen/tmp/tube

        # https://github.com/yt-dlp/yt-dlp#format-selection-examples
        # SUBS ? --write-subs --write-auto-subs --sub-langs "en, en-orig" --embed-subs
        # TODO : DELAY COPY OPERATION...  Astro can download quicker at 03:00 AM
        echo "yt-dlp -f \"bv*[ext=mp4][height<=480]+ba/b[height<=480] / wv*+ba/w\" --no-mtime --embed-thumbnail --add-metadata -o \"$HOME/.zen/tmp/tube/%(title)s.%(ext)s\" ${yurl}"
        yt-dlp -f "bv*[ext=mp4][height<=480]+ba/b[height<=480] / wv*+ba/w" --no-mtime --embed-thumbnail --add-metadata -o "$HOME/.zen/tmp/tube/%(title)s.%(ext)s" ${yurl}


        # Get last writen file... TODO: Could we do better ?
        ZFILE=$(ls -t ~/.zen/tmp/tube/*.mp4 | head -n 1)
        ZFILE="$(yt-dlp --print title ${yurl}).mp4"
        [[ ! -f ~/.zen/tmp/tube/$ZFILE  ]] && echo "No FILE -- EXIT --" && exit 1

        echo "~/.zen/tmp/tube/$ZFILE downloaded"

        echo "Adding to IPFS"
        ILINK=$(ipfs add -q "$HOME/.zen/tmp/tube/$ZFILE" | tail -n 1)
        echo "/ipfs/$ILINK ready"

        MIME=$(file --mime-type "$HOME/.zen/tmp/tube/$ZFILE" | rev | cut -d ' ' -f 1 | rev)

        TEXT="<video controls width=360><source src='/ipfs/"${ILINK}"' type='"${MIME}"'></video><h1>"${ZFILE}"</h1>"

        echo "Creating Youtube tiddler"
        echo $TEXT

        echo '[
  {
    "title": "'$ZFILE'",
    "type": "'text/vnd.tiddlywiki'",
    "text": "'$TEXT'",
    "ipfs": "'${ILINK}'",
    "tags": "'ipfs youtube ${MIME}'"
  }
]
' > "$HOME/.zen/tmp/tube/$ZFILE.TW.json"

        echo "=========================="
        echo "Adding tiddler to TW"

        rm -f ~/.zen/tmp/newindex.html

        echo  "importing $HOME/.zen/tmp/tube/$ZFILE.TW.json"

        tiddlywiki --load $INDEX \
                        --import "$HOME/.zen/tmp/tube/$ZFILE.TW.json" "application/json" \
                        --deletetiddlers '[tag[tube]]' \
                        --output ~/.zen/tmp --render "$:/core/save/all" "newindex.html" "text/plain"

        if [[ -s ~/.zen/tmp/newindex.html ]]; then

            echo "Updating $INDEX"
            cp ~/.zen/tmp/newindex.html $INDEX

            echo "ipfs name publish -k $WISHKEY"
            ILINK=$(ipfs add -q $INDEX | tail -n 1)
            ipfs name publish -k $WISHKEY /ipfs/$ILINK
            echo "/ipfs/$ILINK"

        else

            echo "Problem with tiddlywiki command. Missing ~/.zen/tmp/newindex.html"
            echo "XXXXXXXXXXXXXXXXXXXXXXX"

        fi
done

myIP=$(hostname -I | awk '{print $1}' | head -n 1)

echo "=========================="
echo "Nouveau TW"
echo "http://$myIP:8080/ipns/$WNS"
# Removing tag=tube
# --deletetiddlers '[tag[tube]]'
