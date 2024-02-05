#!#/bin/bash

CESIUM="https://g1.data.le-sou.org"

[[ $1 == "" ]] \
    && ( echo "Entrez PubKey"; read DESTRIB ) \
    || DESTRIB="$1"

curl -sk ${CESIUM}/user/profile/${DESTRIB} -o /tmp/profile.json
LON=$(cat /tmp/profile.json | jq '._source.geoPoint.lon')
LAT=$(cat /tmp/profile.json | jq '._source.geoPoint.lat')

if [[ "$LON" != "null" ]]; then
curl -sk -XPOST 'https://data.gchange.fr/market/record/_search?pretty&_source=title' -d '
   {
     "size": 100,
     "query": {
        "bool": {
            "filter": [{
                "geo_distance": {
                    "distance": "100km",
                    "geoPoint": {
                        "lat": '$LAT',
                        "lon": '$LON'
                    }
                }
            }]
        }
     }
   }' | jq
else
    echo "Aucune coordonnées geoPoint pour $DESTRIB"
fi
