#!/bin/bash

# Vérifier si la variable "issuer" est fournie en argument
if [ -z "$1" ]; then
    echo "Veuillez fournir la variable 'issuer' en argument."
    exit 1
fi

# Stocker la variable "issuer" fournie en argument
issuer=$1

# Construire le JSON avec la variable "issuer"
json_data='{
    "size": 25,
    "_source": ["id", "kind", "level"],
    "query": {
        "bool": {
            "filter": [
                {"term": {"kind": "STAR"}}
            ],
            "must": [
                {
                    "term": {
                        "issuer": "'"$issuer"'"
                    }
                }
            ]
        }
    }
}'

# URL cible
url="https://data.gchange.fr/like/record/_search"

# Envoyer la requête POST avec curl
response=$(curl -X POST -H "Content-Type: application/json" -d "$json_data" "$url")

# Afficher la réponse
echo "$response"
