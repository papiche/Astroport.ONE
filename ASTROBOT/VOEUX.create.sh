#!/bin/bash
########################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.5
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
[[ ! $PLAYER ]] && echo "Please provide IPNS publish key name" && exit 1
ASTRONAUTENS=$(ipfs key list -l | grep -w $PLAYER | cut -d ' ' -f1)

[[ ! $ASTRONAUTENS ]] && echo "$PLAYER IPNS INTROUVABLE" && exit 1

myIP=$(hostname -I | awk '{print $1}' | head -n 1)

## EXPORT [tag[voeu]]
echo "## EXTRACTION DE NOUVEAUX VOEUX pour $PLAYER TW"
echo "$INDEX  [tag[voeu]]  ?"
rm -f ~/.zen/tmp/voeu.json
tiddlywiki --load ${INDEX} --output ~/.zen/tmp --render '.' 'voeu.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[voeu]]'

[[ ! -s ~/.zen/tmp/voeu.json ]] && echo "AUCUN VOEU - EXIT -" && exit 0

## Tous les tiddlers comportant le tag "voeu" lancent la création d'un G1VOEU ayant le titre du Voeu comme génrateur de clef TW (pepper).
for VOEU in "$(cat ~/.zen/tmp/voeu.json | jq -r '.[].title')"
do
    [[ ! $VOEU ]] && echo "AUCUN VOEU" && continue
    echo "NOUVEAU $VOEU"
    VOEU=$(echo "$VOEU" | sed -r 's/\<./\U&/g' | sed 's/ //g') # CapitalGluedWords

    echo "CREATION G1Voeu G1$VOEU"
    ~/.zen/Astroport.ONE/ASTROBOT/G1Voeu.sh "$VOEU" "$PLAYER" "$INDEX"

done
exit 0
