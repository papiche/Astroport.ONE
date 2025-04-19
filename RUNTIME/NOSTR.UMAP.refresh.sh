#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# NIP-101 related : strfry processing "UPlanet message"
# Search in ~/.zen/game/nostr/UMAP*/HEX to seek for UPlanet GEO Key
MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"


for hexline in $(ls ~/.zen/game/nostr/UMAP_*_*/HEX);
do
    echo $hexline
    hex=$(cat $hexline)
    echo $hex
    lat=$(echo $hexline | cut -d '_' -f 2)
    lon=$(echo $hexline | rev | cut -d '_' -f 2 | rev)
    echo $lat $lon
done

$MY_PATH/../tools/




## Forget follows
nostpy-cli send_event \
    -privkey "$NPRIV_HEX" \
    -kind 3 \
    -content "" \
    -tags "[['p', '$PUBKEY']]" \
    --relay "$myRELAY"
