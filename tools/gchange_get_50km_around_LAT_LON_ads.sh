#!/bin/bash

LAT=$1
LON=$2

if [[ "${LON}" && "${LAT}" ]]; then
curl -sk -XPOST 'https://data.gchange.fr/market/record/_search?pretty&_source=title' -d '
   {
     "size": 100,
     "query": {
        "bool": {
                must: {
                    match_all: {}
                },
            "filter": [{
                "geo_distance": {
                    "distance": "50km",
                    "geoPoint": {
                        "lat": '${LAT}',
                        "lon": '${LON}'
                    }
                }
            }]
        }
     }
   }' | jq
else
    echo "Aucune coordonnées. Indiquez LAT LON à votre requete"
fi
