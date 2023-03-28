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
# Search for "G1DessinDeMoa" tagged tiddlers to get URL

INDEX="$1"
[[ ! $INDEX ]] && echo "ERROR - Please provide path to source TW index.html" && exit 1
[[ ! -f $INDEX ]] && echo "ERROR - Fichier TW absent. $INDEX" && exit 1

WISHKEY="$2" ## IPNS KEY NAME - G1PUB - PLAYER ...
[[ ! $WISHKEY ]] && echo "ERROR - Please provide IPFS publish key" && exit 1
TWNS=$(ipfs key list -l | grep -w $WISHKEY | cut -d ' ' -f1)
[[ ! $TWNS ]] && echo "ERROR - Clef IPNS $WISHKEY introuvable!"  && exit 1

# Extract tag=tube from TW into ~/.zen/tmp/$WISHKEY/DessinDeMoa.json
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

echo "TODO. Use 'moa' 'G1DessinDeMoa' Tiddlers to control Ŋ1 Network"
exit 0
