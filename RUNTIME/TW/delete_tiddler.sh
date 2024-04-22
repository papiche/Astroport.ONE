#!/bin/bash

# Generate a unique timestamp
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

# Check if TiddlyWiki file exists
TW="$1"
[[ ! -s $TW ]] && echo "No TiddlyWiki found at: $TW" && exit 1

# Check if Tiddler title is provided
TITLE="$2"
[[ -z $TITLE ]] && echo "Need a Tiddler title" && exit 1

# Delete the specified Tiddler from the TiddlyWiki
echo "Deleting Tiddler: $TITLE"
tiddlywiki --load $TW \
   --deletetiddlers "$TITLE" \
   --output ~/.zen/tmp --render "$:/core/save/all" "${MOATS}.html" "text/plain"

# Check if deletion was successful
if [[ -s ~/.zen/tmp/${MOATS}.html ]]; then
    echo "Tiddler deleted successfully."
    cp ~/.zen/tmp/${MOATS}.html ${TW}
    rm ~/.zen/tmp/${MOATS}.html
    echo "Updated TiddlyWiki: ${TW}"
else
    echo "ERROR: Cannot delete $TITLE from $TW"
    exit 1
fi

exit 0
