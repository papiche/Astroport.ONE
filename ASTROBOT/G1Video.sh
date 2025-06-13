#!/bin/bash
########################################################################
# Version: 0.5
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# Activé par le voeu 'Video'
# G1Video.sh : Assure la transcription audio / texte pour enrichir les tiddlers portant le tag "G1Video"
########################################################################
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/../tools/my.sh"

echo "
      _             _            _             _           _
    _( )          _( )         _( )          _( )        _( )
  _( )  )_      _( )  )_     _( )  )_      _( )  )_    _( )  )_
 (____(___)    (____(___)   (____(___)    (____(___)  (____(___)"
echo "$ME RUNNING"

########################################################################
########################################################################
INDEX="$1"
[[ ! ${INDEX} ]] && INDEX="$HOME/.zen/game/players/.current/ipfs/moa/index.html"
[[ ! -s ${INDEX} ]] && echo "ERROR - Please provide path to source TW index.html" && exit 1
[[ ! -s ${INDEX} ]] && echo "ERROR - Fichier TW absent. ${INDEX}" && exit 1
ORIGININDEX=${INDEX}

PLAYER="$2"
[[ ! ${PLAYER} ]] && PLAYER="$(cat ~/.zen/game/players/.current/.player 2>/dev/null)"
[[ ! ${PLAYER} ]] && echo "ERROR - Please provide PLAYER" && exit 1

ASTRONAUTENS=$(ipfs key list -l | grep -w ${PLAYER} | head -n1 | cut -d ' ' -f1)
[[ ! ${ASTRONAUTENS} ]] && echo "ERROR - Clef IPNS ${PLAYER} introuvable!"  && exit 1

G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub)
[[ ! $G1PUB ]] && echo "ERROR - G1PUB ${PLAYER} VIDE"  && exit 1

MOATS="$3"
[[ ! ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

echo "${PLAYER} ${INDEX} ${ASTRONAUTENS} ${G1PUB} "
#~ ###################################################################
#~ ## CREATE APP NODE PLAYER PUBLICATION DIRECTORY
#~ ###################################################################
mkdir -p $HOME/.zen/tmp/${MOATS} && echo $HOME/.zen/tmp/${MOATS}
mkdir -p $HOME/.zen/game/players/${PLAYER}/G1Video/

echo "EXPORT Video Wish for ${PLAYER}"
rm -f ~/.zen/game/players/${PLAYER}/G1Video/Video.json
tiddlywiki  --load ${INDEX} \
    --output ~/.zen/game/players/${PLAYER}/G1Video \
    --render '.' 'Video.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1Voeu]tag[G1Video]]'

[[ $(cat ~/.zen/game/players/${PLAYER}/G1Video/Video.json ) == "[]" ]] \
    && echo "AUCUN VOEU G1Video - EXIT -" \
    && rm -Rf $HOME/.zen/game/players/${PLAYER}/G1Video \
    && exit 0

WISH=$(cat ~/.zen/game/players/${PLAYER}/G1Video/Video.json | jq -r '.[].wish')
WISHNS=$(cat ~/.zen/game/players/${PLAYER}/G1Video/Video.json | jq -r '.[].wishns')
echo "G1Video: $WISH ${myIPFS}$WISHNS"

## REFRESH TWmovies.json
rm -f ~/.zen/game/players/${PLAYER}/G1Video/TWmovies.json

tiddlywiki  --load ${INDEX} \
    --output ~/.zen/game/players/${PLAYER}/G1Video \
    --render '.' 'TWmovies.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1Video]!tag[G1Voeu]]'

[[ $(cat ~/.zen/game/players/${PLAYER}/G1Video/TWmovies.json) == "[]" ]] && echo "AUCUNE G1Video"

cat ~/.zen/game/players/${PLAYER}/G1Video/TWmovies.json
## Keeps Video without "transcription" field

## Get Video

## Extract audio

## adaptative whisper transcription

## choose model based on CPU / RAM / GPU

## Prepare Tiddler

## Refresh Tiddler


echo "
  @     @      @     @      @      @     @      @     @     @
 \|/   \|/    \|/   \|/    \|/    \|/   \|/    \|/   \|/   \|/"

#~ rm -Rf $HOME/.zen/tmp/${MOATS}

exit 0
