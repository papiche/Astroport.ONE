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
# https://media.meteonews.net/sat/EURwest_1273x892_c1/sat_20220308_1500.jpg

mkdir -p ~/..zen/game/meteofrance
rm -f ~/..zen/game/meteofrance/meteo.jpg
curl  -m 20 --output ~/..zen/game/meteofrance/meteo.jpg https://media.meteonews.net/sat/EURwest_1273x892_c1/sat_20220308_1500.jpg

if [[ ! -f  ~/..zen/game/meteofrance/meteo.jpg ]]; then
    echo "Impossible de vous connecter à https://fr.sat24.com/"
    exit 1
else
    echo "MIse à jour de votre archive meteo : $ts"
    echo $ts > ~/..zen/game/meteofrance/.ts


    IPFS=$(ipfs add -Rw ~/..zen/game/meteofrance/)
    echo $IPFS > ~/..zen/game/meteofrance/.chain

fi

