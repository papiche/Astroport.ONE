---
description: EN TRAVAUX
---

# tools/Connect\_PLAYER\_To\_Gchange.sh

Le script `tools/Connect_PLAYER_To_Gchange.sh` détermine la classe d'un joueur en fonction de sa présence dans Cesium+ et Gchange. Il extrait les données du joueur à partir de ces plateformes, analyse les informations pour déterminer la classe, et met à jour les données du joueur dans le TiddlyWiki.&#x20;

Voici une analyse détaillée de son fonctionnement :

#### Fonctionnalités Principales

1. **Initialisation et Configuration** :
   * Le script commence par définir le chemin du script (`MY_PATH`) et le normalise pour obtenir un chemin absolu.
   * Il source un fichier de configuration commun (`my.sh`) pour utiliser des fonctions et des variables partagées.
2. **Extraction des Données du Joueur** :
   * Le script récupère les informations du joueur à partir de son TiddlyWiki (TW) et de ses profils Cesium+ et Gchange.
   * Il utilise des requêtes HTTP pour interroger les API de Cesium+ et Gchange et obtenir les données du joueur.
3. **Détermination de la Classe du Joueur** :
   * Le script analyse les données récupérées pour déterminer la classe du joueur. Les critères peuvent inclure :
     * La présence d'un profil Cesium+ valide.
     * La présence d'un profil Gchange valide.
     * Le nombre de certifications reçues et émises.
     * La participation active dans la communauté (transactions, publications, etc.).
4. **Mise à Jour des Données du Joueur** :
   * Le script met à jour les informations du joueur dans le TiddlyWiki en fonction de la classe déterminée.
   * Il peut également mettre à jour les caches locaux et distants avec les nouvelles informations.

#### Étapes du Script

1.  **Définition des Variables et Chemins** :

    ```bash
    MY_PATH="`dirname \"$0\"`"
    MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
    . "${MY_PATH}/../tools/my.sh"
    ```
2.  **Extraction des Données du Joueur** :

    ```bash
    PLAYER="$1"
    G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null)
    CESIUMPLUS_URL="https://g1.data.le-sou.org,https://g1.data.e-is.pro,https://g1.data.adn.life,https://g1.data.presles.fr"
    GCHANGE_URL="https://data.gchange.fr"
    ```
3.  **Requêtes HTTP pour Récupérer les Données** :

    ```bash
    for cesiumplus_url in $(echo $CESIUMPLUS_URL | tr "," "\n"); do
        response=$(curl -s "${cesiumplus_url}/user/profile/_search?scroll=2m" -d '{"query":{"bool":{"must":[{"term":{"pubkey":"'"${G1PUB}"'"}}]}}}')
        if [[ $response != "" ]]; then
            break
        fi
    done

    gchange_response=$(curl -s "${GCHANGE_URL}/user/profile/_search?scroll=2m" -d '{"query":{"bool":{"must":[{"term":{"pubkey":"'"${G1PUB}"'"}}]}}}')
    ```
4.  **Analyse des Données et Détermination de la Classe** :

    ```bash
    if [[ $response != "" ]]; then
        class="Cesium+"
    fi

    if [[ $gchange_response != "" ]]; then
        class="Gchange"
    fi

    if [[ $response != "" && $gchange_response != "" ]]; then
        class="Cesium+ & Gchange"
    fi
    ```
5.  **Mise à Jour des Données du Joueur** :

    ```bash
    tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
    --output ~/.zen/tmp/${MOATS} \
    --render '.' 'PLAYER.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[PLAYER]]'

    echo "Class: $class" >> ~/.zen/tmp/${MOATS}/PLAYER.json
    ```

#### EVOLUTION...

Voici un exemple de réécriture du script `Connect_PLAYER_To_Gchange.sh` pour déterminer la classe du joueur en fonction de sa présence dans Cesium+ et Gchange :

```bash
#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "${MY_PATH}/my.sh"

PLAYER="$1"
if [[ -z "$PLAYER" ]]; then
    echo "Please provide PLAYER"
    exit 1
fi

G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null)
if [[ -z "$G1PUB" ]]; then
    echo "G1PUB not found for player $PLAYER"
    exit 1
fi

CESIUMPLUS_URL="https://g1.data.le-sou.org,https://g1.data.e-is.pro,https://g1.data.adn.life,https://g1.data.presles.fr"
GCHANGE_URL="https://data.gchange.fr"

# Function to fetch data from Cesium+
fetch_cesiumplus_data() {
    local url="$1"
    local query='{
        "query": {
            "bool": {
                "should": [
                    {"exists": {"field": "geoPoint"}},
                    {"bool": {"must": [
                        {"exists": {"field": "title"}},
                        {"exists": {"field": "uid"}}
                    ]}}
                ]
            }
        },
        "size": 10000,
        "_source": ["title", "geoPoint", "avatar._content_type"]
    }'
    curl -s -X POST -H "Content-Type: application/json" -d "$query" "$url/user/profile/_search?scroll=2m"
}

# Fetch data from Cesium+
cesiumplus_data=""
for url in $(echo $CESIUMPLUS_URL | tr "," "\n"); do
    response=$(fetch_cesiumplus_data "$url")
    if [[ -n "$response" ]]; then
        cesiumplus_data="$response"
        break
    fi
done

# Fetch data from Gchange
gchange_data=$(curl -s -X POST -H "Content-Type: application/json" -d "$query" "$GCHANGE_URL/user/profile/_search?scroll=2m")

# Determine player class
class=""
if [[ -n "$cesiumplus_data" ]]; then
    class="Cesium+"
fi

if [[ -n "$gchange_data" ]]; then
    class="Gchange"
fi

if [[ -n "$cesiumplus_data" && -n "$gchange_data" ]]; then
    class="Cesium+ & Gchange"
fi

# Update player data in TiddlyWiki
tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
    --output ~/.zen/tmp/${MOATS} \
    --render '.' 'PLAYER.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[PLAYER]]'

echo "Class: $class" >> ~/.zen/tmp/${MOATS}/PLAYER.json

# Import updated data back into TiddlyWiki
tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
    --import ~/.zen/tmp/${MOATS}/PLAYER.json 'application/json' \
    --output ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER} \
    --render "$:/core/save/all" "newindex.html" "text/plain"

if [[ -s ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html ]]; then
    cp ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html
    rm ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/newindex.html
else
    echo "ERROR - CANNOT IMPORT PLAYER.json - ERROR"
fi

echo "Player $PLAYER class updated to $class"
```

#### Explications

1. **Initialisation et Configuration** :
   * Le script commence par définir le chemin du script (`MY_PATH`) et le normalise pour obtenir un chemin absolu.
   * Il source un fichier de configuration commun (`my.sh`) pour utiliser des fonctions et des variables partagées.
2. **Extraction des Données du Joueur** :
   * Le script récupère les informations du joueur à partir de son TiddlyWiki (TW) et de ses profils Cesium+ et Gchange.
   * Il utilise des requêtes HTTP pour interroger les API de Cesium+ et Gchange et obtenir les données du joueur.
3. **Détermination de la Classe du Joueur** :
   * Le script analyse les données récupérées pour déterminer la classe du joueur. Les critères peuvent inclure :
     * La présence d'un profil Cesium+ valide.
     * La présence d'un profil Gchange valide.
4. **Mise à Jour des Données du Joueur** :
   * Le script met à jour les informations du joueur dans le TiddlyWiki en fonction de la classe déterminée.
   * Il importe les données mises à jour dans le TiddlyWiki.
