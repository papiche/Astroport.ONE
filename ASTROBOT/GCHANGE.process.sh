#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# Extract last ads
# Thank you @kimamila for cesium & gchange
# ES backend http://www.elasticsearchtutorial.com/spatial-search-tutorial.html

echo "REWRITING NEEDED"
exit 1

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized

# Get Player Name
PLAYER="$1"

mkdir -p ~/.zen/tmp/gchange

[[ ! -f ~/.zen/game/players/$PLAYER/secret.dunikey ]] && echo "Astronaute inconnu. Connectez-vous"
g1pub=$(cat ~/.zen/game/players/$PLAYER/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2)

CESIUM="https://g1.data.presles.fr"
GCHANGE="https://data.gchange.fr" # /user/profile/2L8vaYixCf97DMT8SistvQFeBj7vb6RQL7tvwyiv1XVH?&_source_exclude=avatar._content

#curl -sk ${CESIUM}/user/profile/${g1pub} -o ~/.zen/cache/cesium_profile.json
LON=$(cat ~/.zen/cache/cesium_profile.json | jq '._source.geoPoint.lon')
LAT=$(cat ~/.zen/cache/cesium_profile.json | jq '._source.geoPoint.lat')

curl -sk ${GCHANGE}/user/profile/${g1pub} -o ~/.zen/cache/GCHANGE_profile.json
LON=$(cat ~/.zen/cache/GCHANGE_profile.json | jq '._source.geoPoint.lon')
LAT=$(cat ~/.zen/cache/GCHANGE_profile.json | jq '._source.geoPoint.lat')

RAD="$1"
[[ ! $RAD ]] && RAD="50km"

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
    sbotc publish '{"type":"post","text":"Ajouter sa géolocalisation dans Cesium+ permet de publier les annonces autour de chez soi..."}'
    exit 1
fi
TIMEBEFORE=$(date -u --date="-$DELAY" +"%s")
TIMESTAMP=$(date -u +"%s")
TOTAL=$(cat /tmp/gchange.json | jq .hits.total)
echo 'tail -f ~/.zen/cache/gchange.txt'
echo 'Annonces_Gchange' > ~/.zen/cache/gchange.txt
echo "Portefeuille_[June_:heart:](https://demo.cesium.app/#/app/wot/$g1pub/)" >> ~/.zen/cache/gchange.txt
echo "Carte_[$RAD](https://www.openstreetmap.org/#map=10/$LAT/$LON) " >> ~/.zen/cache/gchange.txt
chunk=0
fullcount=0

DUNITERNODE=$($MY_PATH/tools/duniter_getnode.sh)
DUNITERURL="https://$DUNITERNODE"
LASTDU=$(curl -s ${DUNITERURL}/blockchain/with/ud | jq '.result.blocks[]' | tail -n 1);
[[ $LASTDU != "" ]] && LASTDU=$(curl -s ${DUNITERURL}/blockchain/block/${LASTDU} | jq '.dividend')
echo "DU = $LASTDU G1"

for gID in $(cat /tmp/gchange.json | jq -r .hits.hits[]._id); do
    
    NEW=""
    
    [[ ! -f ~/.zen/cache/gchange/$gID.json ]] && 
    NEW="true" \
    && curl -s --create-dirs -o ~/.zen/cache/gchange/$gID.json -s https://data.gchange.fr/market/record/$gID?_source=category,title,description,issuer,time,creationTime,location,address,city,price,unit,currency,thumbnail._content_type,thumbnail._content,picturesCount,type,stock,fees,feesCurrency,geoPoint \
    && sleep $((1 + RANDOM % 3))

    type=$(cat ~/.zen/cache/gchange/$gID.json | jq -r ._source.type)
    stock=$(cat ~/.zen/cache/gchange/$gID.json | jq -r ._source.stock)
    [[ $stock == 0 ]] && continue

    # [[ $type == "need" ]] && continue
    creationTime=$(cat ~/.zen/cache/gchange/$gID.json | jq -r ._source.creationTime)
    title=$(cat ~/.zen/cache/gchange/$gID.json | jq -r ._source.title)
    
    currency=$(cat ~/.zen/cache/gchange/$gID.json | jq -r ._source.currency)
    price=$(cat ~/.zen/cache/gchange/$gID.json | jq -r ._source.price)
    
    categoryname=$(cat ~/.zen/cache/gchange/$gID.json | jq -r ._source.category.name)

    [[ $price == null ]] && price="0"
    [[ $currency == "g1" ]] && love=$(bc -l <<< "scale=2; $price / $LASTDU * 100") || love="?.??"
    love="$love_LOVE"
    price=$(bc -l <<< "scale=2; $price / 100")

    fullcount=$((fullcount+1)) && echo "DEBUG : $fullcount - $type - $price $currency - $title " 
    [[ $price == "0" ]] && love="..." && price="A débattre "

    
    [[ $type == "offer" ]] && LINE="___OFFRE___[$title](https://data.gchange.fr/market/record/$gID/_share)_$love"
    [[ $type == "need" ]] && LINE="__DEMANDE__[$title](https://data.gchange.fr/market/record/$gID/_share)_$love"

    [[ $NEW == "true" ]] && echo "$LINE" >> ~/.zen/cache/gchange.txt && chunk=$((chunk+1)) && echo $chunk

done
echo "$chunk_nouvelles_annonces_($TOTAL)" >> ~/.zen/cache/gchange.txt

## TODO AUTOMATIC PUBLISHING \n and message size problem ??
if [[ $(cat ~/.zen/cache/gchange.txt | wc -c) -lt 8000 ]]; then
    export raw="$(cat ~/.zen/cache/gchange.txt)"
    annonces=$(node -p "JSON.stringify(process.env.raw)")
    sbotc publish '{"type":"post","text":'$annonces'}'
fi
# EXTRA COULD CREATE IT'S OWN MAP with https://github.com/zicmama/tile-stitch.git
# And magick to overlay... But best would be a local map proxy...
