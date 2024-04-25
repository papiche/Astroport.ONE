#!/bin/bash

# Generate a unique timestamp
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

# Check if TiddlyWiki file exists
TW="$1"
[[ ! -s $TW ]] \
    && echo "Missing TiddlyWiki index.html \$1: $TW" \
    && exit 1

# Check if Tiddler JSON file exists
TIDDLER="$2"
[[ ! -s $TIDDLER || $TIDDLER == "" ]] \
    && echo "Missing Tiddler JSON file \$2: $TIDDLER" \
    && exit 1

# Add created and modified fields to the Tiddler JSON file
echo "Putting ${TIDDLER} in ${TW}"
jq '.[] + {created: $MOATS, modified: $MOATS}' --arg MOATS "$MOATS" "$TIDDLER" > "${TIDDLER}.tmp"

# Run TiddlyWiki import command
echo "Running TiddlyWiki import..."
tiddlywiki --load "${TW}" \
    --import "${TIDDLER}.tmp" 'application/json' \
    --output /tmp \
    --render '$:/core/save/all' "${MOATS}.html" 'text/plain'

# Check if import was successful
if [[ -s /tmp/${MOATS}.html ]]; then
    echo "Import successful."
    cp /tmp/${MOATS}.html ${TW}
    rm /tmp/${MOATS}.html
    rm "${TIDDLER}.tmp"
    echo "Updated TiddlyWiki:
    ${TW}"
    exit 0
else
    echo "ERROR"
    exit 1
fi
