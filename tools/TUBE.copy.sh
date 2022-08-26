#!/bin/bash
########################################################################
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

# Need TW index.html path + IPNS publication Key (G1PUB format)
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

        rm -Rf ~/.zen/tmp/tube
        mkdir -p ~/.zen/tmp/tube

        yt-dlp -f "best[ext=mp4]+best[height<=480]+best[filesize<300M]" --no-mtime --embed-thumbnail --add-metadata -o "$HOME/.zen/tmp/tube/%(title)s.%(ext)s" ${yurl}
        FILE=$(ls -t ~/.zen/tmp/tube/ | tail -n 1)

        [[ ! -f ~/.zen/tmp/tube/$FILE  ]] && echo "No FILE -- EXIT --" && exit 1

        echo "~/.zen/tmp/tube/$FILE downloaded"

        echo "Adding to IPFS"
        ILINK=$(ipfs add -q "$HOME/.zen/tmp/tube/$FILE" | tail -n 1)
        echo "/ipfs/$ILINK ready"

        MIME=$(file --mime-type "$HOME/.zen/tmp/tube/$FILE" | cut -d ':' -f 2 | cut -d ' ' -f 2)

        TEXT="<video controls width=360><source src='/ipfs/"${ILINK}"' type='"${MIME}"'></video><h1>"${FILE}"</h1>"

        echo "Creating Youtube tiddler"

        echo '[
  {
    "title": "'$FILE'",
    "type": "'text/vnd.tiddlywiki'",
    "text": "'$TEXT'",
    "tags": "'ipfs youtube copylaradio ${MIME}'"
  }
]
' > ~/.zen/tmp/tube.json

        echo "=========================="
        echo "Adding tiddler to TW"

        rm -f ~/.zen/tmp/newindex.html

        tiddlywiki --verbose --load $INDEX \
                        --import ~/.zen/tmp/tube.json "application/json" \
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

echo "=========================="
echo "Nouveau TW"
echo "http://127.0.0.1:8080/ipns/$WNS"
# Removing tag=tube
# --deletetiddlers '[tag[tube]]'
