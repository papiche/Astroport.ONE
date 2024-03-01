#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2 (Corrigé)
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}
################################################################################
# Choisir la source de capture
# https://fr.sat24.com/image?type=visual5HDComplete&region=fr

MY_PATH="$(dirname "$0")"              # relative
MY_PATH="$(cd "$MY_PATH" && pwd)"  # absolutized and normalized
ME="${0##*/}"

## TEST IPFS
if ! command -v ipfs &> /dev/null; then
    echo "Missing IPFS. Please install... https://ipfs.tech"
    exit 1
fi

## PREPARE FILE SYSTEM CACHE
mkdir -p ~/.zen/adventure/meteo.anim.eu
rm -f ~/.zen/adventure/meteo.anim.eu/meteo.png

## SCRAPING meteo.png
curl -m 20 --output ~/.zen/adventure/meteo.anim.eu/meteo.png https://s.w-x.co/staticmaps/wu/wu/satir1200_cur/europ/animate.png

if [[ ! -f ~/.zen/adventure/meteo.anim.eu/meteo.png ]]; then
    echo "Impossible de se connecter au service meteo"
    exit 1
else
    echo "Mise à jour archive meteo : ${MOATS}"
    echo ${MOATS} > ~/.zen/adventure/meteo.anim.eu/.moats

    OLDID=$(cat ~/.zen/adventure/.meteo.index 2>/dev/null)

    ## PREPARE NEW index.html
    cp ${MY_PATH}/../../../templates/meteo_chain.html /tmp/index.html
    sed -i "s/_OLDID_/$OLDID/g" /tmp/index.html
    DATE_NOW=$(date -u "+%Y-%m-%d#%H:%M:%S")
    sed -i "s/_DATE_/$DATE_NOW/g" /tmp/index.html
    sed -i "s/_PSEUDO_/${USER}/g" /tmp/index.html

    ## Copy style css
    cp -r ${MY_PATH}/../../../templates/styles ~/.zen/adventure/

    ## Add to IPFS
    IPFS=$(ipfs add -q ~/.zen/adventure/meteo.anim.eu/meteo.png | tail -n 1)
    echo $IPFS > ~/.zen/adventure/meteo.anim.eu/.chain

    sed -i "s/_IPFSID_/$IPFS/g" /tmp/index.html
    mv /tmp/index.html ~/.zen/adventure/index.html

    INDEXID=$(ipfs add -rHq ~/.zen/adventure/ | tail -n 1)
    echo $INDEXID > ~/.zen/adventure/.meteo.index
    echo "METEO INDEX : http://127.0.0.1:8080/ipfs/$INDEXID"
fi
