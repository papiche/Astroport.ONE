#!/bin/bash
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
TW="$1"
[[ ! -s $TW ]] && echo "no TW found $TW" && exit 1
TIDDLER="$2"
[[ ! -s $TIDDLER || $TIDDLER == "" ]] && echo "need a $TIDDLER json file" && exit 1

tiddlywiki --load ${TW} \
    --import ${TIDDLER} 'application/json' \
    --output ~/.zen/tmp \
    --render "$:/core/save/all" "${MOATS}.html" "text/plain"

[[ -s ~/.zen/tmp/${MOATS}.html ]] \
    && cp ~/.zen/tmp/${MOATS}.html ${TW} \
    && rm ~/.zen/tmp/${MOATS}.html \
    || { echo "ERROR - CANNOT IMPORT ${TIDDLER} in ${TW} - ERROR" && exit 1 }

exit 0
