---
description: Mise à Jour des Clés Géographiques
---

# UPLANET.refresh.sh

Le script `UPLANET.refresh.sh` est un composant essentiel de l'écosystème Astroport.ONE, permettant de maintenir à jour les informations géographiques des joueurs en utilisant IPFS et des scripts de gestion.

Il assure la synchronisation des données géographiques, la génération de clés dérivées pour les différentes zones géographiques, et la publication des données mises à jour sur IPFS. Ces fonctionnalités permettent de garantir que les informations géographiques des joueurs sont toujours à jour et accessibles dans l'écosystème décentralisé.

#### Fonctionnalités Principales

1. **Initialisation et Configuration** :
   * Le script commence par définir le chemin du script (`MY_PATH`) et le normalise pour obtenir un chemin absolu.
   * Il source un fichier de configuration commun (`my.sh`) pour utiliser des fonctions et des variables partagées.
2. **Extraction des Coordonnées Géographiques** :
   * Le script extrait les coordonnées géographiques des joueurs à partir de leurs TiddlyWiki (TW).
   * Il vérifie et met à jour les informations géographiques des joueurs, y compris les coordonnées de latitude et de longitude.
3. **Mise à Jour des Clés Géographiques** :
   * Le script génère des clés dérivées pour les différentes zones géographiques (UMAP, SECTOR, REGION) en utilisant les coordonnées géographiques.
   * Il met à jour les informations associées à ces clés dans les caches locaux et distants.
4. **Publication des Données Géographiques** :
   * Le script publie les données géographiques mises à jour sur IPFS et met à jour les caches locaux et distants.
   * Il génère des QR codes pour différents liens associés aux zones géographiques.

#### Étapes du Script

1.  **Définition des Variables et Chemins** :

    ```bash
    MY_PATH="`dirname \"$0\"`"
    MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
    . "${MY_PATH}/../tools/my.sh"
    ```
2.  **Extraction des Coordonnées Géographiques** :

    ```bash
    tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
    --output ~/.zen/tmp/${MOATS} \
    --render '.' 'GPS.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'GPS'
    ```
3.  **Mise à Jour des Clés Géographiques** :

    ```bash
    LAT=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].lat)
    LON=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].lon)
    LAT=$(makecoord ${LAT})
    LON=$(makecoord ${LON})
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/UMAP.priv "${UPLANETNAME}${LAT}${LON}" "${UPLANETNAME}${LAT}${LON}"
    UMAPG1PUB=$(cat ~/.zen/tmp/${MOATS}/UMAP.priv | grep "pub:" | cut -d ' ' -f 2)
    ```
4.  **Publication des Données Géographiques** :

    ```bash
    UMAPNS=$(ipfs key import ${UMAPG1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/UMAP.priv)
    ipfs --timeout 180s name publish -k ${UMAPG1PUB} /ipfs/${UMAPFLUX}
    ```

Les clés spatio-temporelles dans l'écosystème Astroport.ONE sont mises à jour quotidiennement en utilisant les données de la veille. Les scripts récupèrent les données existantes, les mettent à jour avec les nouvelles informations, génèrent de nouvelles clés dérivées, et publient les données mises à jour sur IPFS. Cela permet de maintenir une synchronisation continue et précise des informations géographiques et temporelles dans l'écosystème décentralisé.
