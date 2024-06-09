#!/bin/bash
# This Bash script automates updating a TiddlyWiki instance with new or modified content items (Tiddlers). It performs the following steps:
# 1. Generates a unique timestamp to track updates.
# 2. Verifies the existence of both the main TiddlyWiki index file and individual Tiddler JSON files, exiting with an error if either is missing.
# 3. Incor CVs, adds 'created' and 'modified' fields from the unique timestamp to each Tiddler.
# 4. Imports the updated Tiddlers into the wiki using TiddlyWiki's import command, outputting a temporary HTML file for review.
# 5. Checks if the import was successful by verifying that the corresponding HTML file has been generated. On success:
#    - Moves the new HTML file to replace the old index file in its original location.
#    - Removes temporary files created during processing.
# If any step fails, it provides an error message and exits with a non-zero status code.

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
cat "$TIDDLER" | jq --arg MOATS "$MOATS" '.[] + {created: $MOATS, modified: $MOATS}' > "${TIDDLER}.tmp"
[ $? -ne 0 ] && cat "$TIDDLER" # DEBUG

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
