#!/bin/bash
########################################################################
# Version: 0.4
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

# Need TW index.html path + IPNS publication Key (available in IPFS keystore)
# Search for "voeu" tagged tiddlers to get URL
# Use G1VOEUX.sh to create and add TW to PLAYER TW

INDEX="$1"
[[ ! $INDEX ]] && echo "Please provide path to source TW index.html" && exit 1
[[ ! -f $INDEX ]] && echo "Fichier TW absent. $INDEX" && exit 1

PLAYER="$2" ## IPNS KEY NAME - G1PUB - PLAYER ...
[[ ! $PLAYER ]] && echo "Please provide IPFS publish key" && exit 1
ASTRONAUTENS=$(ipfs key list -l | grep -w $PLAYER | cut -d ' ' -f1)

myIP=$(hostname -I | awk '{print $1}' | head -n 1)

## EXPORT FROM PLAYER TW "[tag[voeu]]"
rm -f ~/.zen/tmp/voeu.json
tiddlywiki --verbose --load ${INDEX} --output ~/.zen/tmp --render '.' 'voeu.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[voeu]]'

## Tous les tiddlers comportant le tag "voeu" lancent la création d'un G1VOEU ayant le titre du Voeu comme génrateur de clef TW (pepper).
for VOEU in $(cat ~/.zen/tmp/voeu.json | jq -r '.[].title')
do
    echo "Detected $VOEU"
    VOEU=$(echo "$VOEU" | sed -r 's/\<./\U&/g' | sed 's/ //g') # CapitalGluedWords

    echo "Creating G1$VOEU TW"
    ~/.zen/Astroport.ONE/G1VOEUX.sh "$VOEU" "$PLAYER" "$INDEX"


done
