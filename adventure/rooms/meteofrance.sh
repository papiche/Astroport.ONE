#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
ts=$(date -u +%s%N | cut -b1-13)
################################################################################
# Capture la photographie satellite de la France
# https://fr.sat24.com/image?type=visual5HDComplete&region=fr
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

mkdir -p ~/.zen/adventure/meteo.anim.eu
rm -f ~/.zen/adventure/meteo.anim.eu/meteo.png
curl  -m 20 --output ~/.zen/adventure/meteo.anim.eu/meteo.png https://s.w-x.co/staticmaps/wu/wu/satir1200_cur/europ/animate.png

if [[ ! -f  ~/.zen/adventure/meteo.anim.eu/meteo.png ]]; then
    echo "Impossible de vous connecter au service meteo"
    exit 1
else
    echo "NEED HTML TEMPLATING"
    echo "Mise à jour archive points meteo : $ts"
    echo $ts > ~/.zen/adventure/meteo.anim.eu/.ts

    PSEUDO=$(cat ~/.zen/adventure/players/.current/.pseudo 2>/dev/null)
    OLDID=$(cat ~/.zen/adventure/.meteo.index 2>/dev/null)
    sed s/_OLDID_/$OLDID/g ${MY_PATH}/../templates/meteo_chain.html > /tmp/index.html
    sed -i s/_IPFSID_/$IPFSID/g /tmp/index.html
    sed -i s/_DATE_/$(date -u "+%Y-%m-%d#%H:%M:%S")/g /tmp/index.html
    sed s/_PSEUDO_/$PSEUDO/g /tmp/index.html > ~/.zen/adventure/index.html

    # Copy style css
    cp -R ${MY_PATH}/../templates/styles ~/.zen/adventure/players/.current/public/

    INDEXID=$(ipfs add -rHq ~/.zen/adventure/index.html | tail -n 1)
    echo $INDEXID > ~/.zen/adventure/.meteo.index
    echo "LAST VIDEO INDEX http://127.0.0.1:8080/ipfs/$INDEXID"
    IPFS=$(ipfs add -Rw ~/.zen/adventure/meteo.anim.eu/)
    echo $IPFS > ~/.zen/adventure/meteo.anim.eu/.chain



fi

