#!/bin/bash
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
TW="$1"
[[ ! -s $TW ]] && echo "no TW found $TW" && exit 1
TITLE="$2"
[[ -s $TITLE || $TITTLE == "" ]] && echo "need a $TITTLE" && exit 1

tiddlywiki --load $TW \
   --deletetiddlers "${TITLE}" \
   --output ~/.zen/tmp --render "$:/core/save/all" "${MOATS}.html" "text/plain"

[[ -s ~/.zen/tmp/${MOATS}.html ]] \
    && cp ~/.zen/tmp/${MOATS}.html ${TW} \
    && rm ~/.zen/tmp/${MOATS}.html \
    || { echo "ERROR - CANNOT IMPORT ${TIDDLER} in ${TW} - ERROR" && exit 1 }

exit 0
