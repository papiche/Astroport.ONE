#!/bin/bash
########################################################################
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# GET TIDDLERS JSON LIST - from week.rss.json made by SECTOR. refresh.sh
# Filter by Tid type and format markdown  output file
# CALLED BY "REGION.refresh.sh"
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

RSS=$1 ## filepath to RSS week file to extract Tiddlers

[[ ! -s ${RSS} ]] && echo "BAD RSS INPUT ${RSS}" && exit 1

#~ echo "======= RSS 2 WEEKnewsfile =======
#~ Analysing ${RSS}
#~ =================================================================="
cat ${RSS} | jq -r '.[] | select(.title | startswith("$:/") | not) | if .ipfs then "\n# [\(."title")](\(."ipfs"))\n\n\(.tags)\n \(.duree)"
                                        elif .ipfs_one then "\n# \(."title")\n\n\(.tags)\n\(.desc)\n\(.g1pub)"
                                        elif ._external_url then "\n# [\(."title")](\(._external_url))\n\n\(.tags)\n\(.mime) \(.type)"
                                        else "\n# \(."title")\n\n\(.tags)\n\(.text)" end | select(.tags | contains(["$:/isEmbedded", "$:/isIpfs"]) | not)'

exit 0
