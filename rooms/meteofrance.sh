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

mkdir -p ~/..zen/game/meteo.anim.eu
rm -f ~/..zen/game/meteo.anim.eu/meteo.png
curl  -m 20 --output ~/..zen/game/meteo.anim.eu/meteo.png https://s.w-x.co/staticmaps/wu/wu/satir1200_cur/europ/animate.png

if [[ ! -f  ~/..zen/game/meteo.anim.eu/meteo.png ]]; then
    echo "Impossible de vous connecter au service meteo"
    exit 1
else
    echo "NEED HTML TEMPLATING"
    echo "Mise à jour archive points meteo : $ts"
    echo $ts > ~/..zen/game/meteo.anim.eu/.ts

    IPFS=$(ipfs add -Rw ~/..zen/game/meteo.anim.eu/)
    echo $IPFS > ~/..zen/game/meteo.anim.eu/.chain



fi

