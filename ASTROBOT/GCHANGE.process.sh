#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# Extract last ads
# Thank you @kimamila for cesium & gchange
# ES backend http://www.elasticsearchtutorial.com/spatial-search-tutorial.html
## THIS INTERNET NEEDS A BACKUP !!! OR YOU BECOME INTERNET .
# https://web.archive.org/web/20210621185958/http://www.elasticsearchtutorial.com/spatial-search-tutorial.html
# Create tiddler informing ... TODO Add keyword ... Use tag="annonce" for tiddlers propagation

echo "TODO DEBUG. CONTINUE?"
read

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized

# Get Player Name
PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
[[ $PLAYER == "" ]] &&  echo "NO PLAYER - EXIT" && exit 1

mkdir -p ~/.zen/tmp/gchange

[[ ! -f ~/.zen/game/players/$PLAYER/secret.dunikey ]] && echo "Astronaute inconnu. Connectez-vous"
g1pub=$(cat ~/.zen/game/players/$PLAYER/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2)

CESIUM="https://g1.data.presles.fr"
GCHANGE="https://data.gchange.fr" # /user/profile/2L8vaYixCf97DMT8SistvQFeBj7vb6RQL7tvwyiv1XVH?&_source_exclude=avatar._content


tiddlywiki --load ~/.zen/game/players/$PLAYER/ipfs/moa/index.html --output ~/.zen/tmp/gchange --render '.' 'carte.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Carte'
tiddlywiki --load ~/.zen/game/players/$PLAYER/ipfs/moa/index.html --output ~/.zen/tmp/gchange --render '.' 'gchange.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Gchange'
tiddlywiki --load ~/.zen/game/players/$PLAYER/ipfs/moa/index.html --output ~/.zen/tmp/gchange --render '.' 'g1visa.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'G1Visa'
tiddlywiki --load ~/.zen/game/players/$PLAYER/ipfs/moa/index.html --output ~/.zen/tmp/gchange --render '.' 'MOA.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[moa]]'

GPS=$(cat ~/.zen/tmp/gchange/carte.json | jq -r .[].gps)
echo $GPS
DIST=$(cat ~/.zen/tmp/gchange/gchange.json | jq -r .[].distance)
echo $DIST
RECH=($(cat ~/.zen/tmp/gchange/gchange.json | jq -r .[].recherche))
echo "${RECH[@]}"
MOANFT=$(cat /home/fred/.zen/tmp/gchange/MOA.json | jq .[].text)
echo $MOANFT < xdg-open

LAT=$(echo $GPS | cut -d ',' -f 1)
echo $LAT
LON=$(echo $GPS | cut -d ',' -f 2)
echo $LON

# AJOUTER CHAMPS  à "Dessin de Moa"
# IPFSNODEADDRESS for IPFS layer optimization

RAD="$DIST"
[[ ! $RAD ]] && RAD="50km"

echo curl -sk -XPOST 'https://data.gchange.fr/market/record/_search?pretty&_source=title' -d '
   {
     "size": 200,
     "query": {
        "bool": {
            "filter": [{
                "geo_distance": {
                    "distance": "'$RAD'",
                    "geoPoint": {
                        "lat": '$LAT',
                        "lon": '$LON'
                    }
                }
            }]
        }
     }
   }'


if [[ "$LON" != "null" ]]; then
curl -sk -XPOST 'https://data.gchange.fr/market/record/_search?pretty&_source=title' -d '
   {
     "size": 200,
     "query": {
        "bool": {
            "filter": [{
                "geo_distance": {
                    "distance": "'$RAD'",
                    "geoPoint": {
                        "lat": '$LAT',
                        "lon": '$LON'
                    }
                }
            }]
        }
     }
   }' > /tmp/gchange.json || exit 1
else
    echo "Aucune coordonnées geoPoint pour $g1pub"
    # Message tiddlywiki TODO
    exit 1
fi
TIMEBEFORE=$(date -u --date="-$DELAY" +"%s")
TIMESTAMP=$(date -u +"%s")
TOTAL=$(cat /tmp/gchange.json | jq .hits.total)
echo 'tail -f ~/.zen/tmp/gchange.txt'
echo 'Annonces_Gchange' > ~/.zen/tmp/gchange.txt
echo "Portefeuille_[June_:heart:](https://demo.cesium.app/#/app/wot/$g1pub/)" >> ~/.zen/tmp/gchange.txt
echo "Carte_[$RAD](https://www.openstreetmap.org/#map=10/$LAT/$LON) " >> ~/.zen/tmp/gchange.txt
chunk=0
fullcount=0


for gID in $(cat /tmp/gchange.json | jq -r .hits.hits[]._id); do

    NEW=""

    [[ ! -f ~/.zen/tmp/gchange/$gID.json ]] &&
    NEW="true" \
    && curl -s --create-dirs -o ~/.zen/tmp/gchange/$gID.json -s https://data.gchange.fr/market/record/$gID?_source=category,title,description,issuer,time,creationTime,location,address,city,price,unit,currency,thumbnail._content_type,thumbnail._content,picturesCount,type,stock,fees,feesCurrency,geoPoint \
    && sleep $((1 + RANDOM % 3))

    type=$(cat ~/.zen/tmp/gchange/$gID.json | jq -r ._source.type)
    stock=$(cat ~/.zen/tmp/gchange/$gID.json | jq -r ._source.stock)
    [[ $stock == 0 ]] && continue

    # [[ $type == "need" ]] && continue
    creationTime=$(cat ~/.zen/tmp/gchange/$gID.json | jq -r ._source.creationTime)
    title=$(cat ~/.zen/tmp/gchange/$gID.json | jq -r ._source.title)

    currency=$(cat ~/.zen/tmp/gchange/$gID.json | jq -r ._source.currency)
    price=$(cat ~/.zen/tmp/gchange/$gID.json | jq -r ._source.price)

    categoryname=$(cat ~/.zen/tmp/gchange/$gID.json | jq -r ._source.category.name)

    [[ $price == null ]] && price="0"
    love="$price $currency"

    [[ $type == "offer" ]] && LINE="___OFFRE___[$title](https://data.gchange.fr/market/record/$gID/_share)_$love"
    [[ $type == "need" ]] && LINE="__DEMANDE__[$title](https://data.gchange.fr/market/record/$gID/_share)_$love"

    [[ $NEW == "true" ]] && echo "$LINE" >> ~/.zen/tmp/gchange.txt && chunk=$((chunk+1)) && echo $chunk

done
echo "$chunk_nouvelles_annonces_($TOTAL)" >> ~/.zen/tmp/gchange.txt

