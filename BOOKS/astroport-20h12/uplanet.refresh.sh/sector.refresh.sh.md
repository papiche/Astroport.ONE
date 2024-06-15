# SECTOR.refresh.sh

Le script `SECTOR.refresh.sh` permet de maintenir à jour les informations des secteurs géographiques en utilisant IPFS et des scripts de gestion. Il assure la rotation des clés spatio-temporelles, la synchronisation des données, et la copie des flux RSS des nouveaux tiddlers du secteur.  Voici une analyse détaillée de son fonctionnement :

#### Fonctionnalités Principales

1. **Initialisation et Configuration** :
   * Le script commence par définir le chemin du script (`MY_PATH`) et le normalise pour obtenir un chemin absolu.
   * Il source un fichier de configuration commun (`my.sh`) pour utiliser des fonctions et des variables partagées.
2. **Détermination des Secteurs** :
   * Le script identifie les secteurs géographiques à partir des coordonnées des UMAPs (Unités de Mesure de l'Activité Planétaire).
   * Il génère une liste unique de secteurs à partir des UMAPs disponibles.
3. **Génération et Gestion des Clés** :
   * Le script génère des clés Duniter et IPFS pour chaque secteur.
   * Il importe ces clés dans le keystore IPFS et les utilise pour publier les données du secteur.
4. **Récupération et Mise à Jour des Données** :
   * Le script récupère les données du secteur à partir de la clé IPNS de la veille.
   * Il met à jour les données du secteur avec les nouvelles informations collectées.
5. **Publication des Données** :
   * Le script publie les données mises à jour sur IPFS et met à jour les caches locaux et distants.
   * Il génère des QR codes et des images pour visualiser les informations du secteur.

#### Étapes du Script

1.  **Définition des Variables et Chemins** :

    ```bash
    MY_PATH="`dirname \"$0\"`"
    MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
    . "${MY_PATH}/../tools/my.sh"
    ```
2.  **Détermination des Secteurs** :

    ```bash
    for UMAP in ${UMAPS[@]}; do
        LAT=$(echo ${UMAP} | cut -d '_' -f 2)
        LON=$(echo ${UMAP} | cut -d '_' -f 3)
        SLAT="${LAT::-1}"
        SLON="${LON::-1}"
        MYSECTORS=("_${SLAT}_${SLON}" ${MYSECTORS[@]})
    done
    SECTORS=($(echo "${MYSECTORS[@]}" | tr ' ' '\n' | sort -u))
    ```
3.  **Génération et Gestion des Clés** :

    ```bash
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/${SECTOR}.dunikey "${UPLANETNAME}${SECTOR}" "${UPLANETNAME}${SECTOR}"
    G1PUB=$(cat ~/.zen/tmp/${MOATS}/${SECTOR}.dunikey | grep 'pub:' | cut -d ' ' -f 2)
    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/${SECTOR}.priv "${UPLANETNAME}${SECTOR}" "${UPLANETNAME}${SECTOR}"
    SECTORNS=$(ipfs key import ${G1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/${SECTOR}.priv)
    ```
4.  **Récupération et Mise à Jour des Données** :

    ```bash
    ipfs --timeout 180s get --progress=false -o ~/.zen/tmp/${MOATS}/${SECTOR}/ /ipns/${YESTERDATENS}/
    ```
5.  **Publication des Données** :

    ```bash
    IPFSPOP=$(ipfs add -rwq ~/.zen/tmp/${MOATS}/${SECTOR}/* | tail -n 1)
    ipfs --timeout 240s name publish -k ${TODATE}${G1PUB} /ipfs/${IPFSPOP}
    ```

#### Rotation des Clés Spatio-Temporelles

Le script gère la rotation des clés spatio-temporelles en générant de nouvelles clés pour chaque jour et en les publiant sur IPFS. Voici comment cela se fait :

1.  **Génération des Clés pour la Date du Jour et de la Veille** :

    ```bash
    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/tmp/${MOATS}/${TODATE}.priv "${TODATE}${UPLANETNAME}${SECTOR}" "${TODATE}${UPLANETNAME}${SECTOR}"
    TODATENS=$(ipfs key import ${TODATE}${G1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/${TODATE}.priv)
    ```
2.  **Récupération des Données de la Veille** :

    ```bash
    ipfs --timeout 180s get --progress=false -o ~/.zen/tmp/${MOATS}/${SECTOR}/ /ipns/${YESTERDATENS}/
    ```
3.  **Publication des Nouvelles Données** :

    ```bash
    IPFSPOP=$(ipfs add -rwq ~/.zen/tmp/${MOATS}/${SECTOR}/* | tail -n 1)
    ipfs --timeout 240s name publish -k ${TODATE}${G1PUB} /ipfs/${IPFSPOP}
    ```

#### Copie des Flux RSS des Nouveaux Tiddlers du Secteur

Le script copie les flux RSS des nouveaux tiddlers du secteur en les récupérant et en les ajoutant au TiddlyWiki du secteur. Voici comment cela se fait :

1.  **Récupération des Flux RSS** :

    ```bash
    RSSNODE=($(ls ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_${SLAT}_${SLON}/_*_*/RSS/*.rss.json 2>/dev/null))
    RSSWARM=($(ls ~/.zen/tmp/swarm/12D*/UPLANET/__/_*_*/_${SLAT}_${SLON}/_*_*/RSS/*.rss.json 2>/dev/null))
    combinedrss=("${RSSNODE[@]}" "${RSSWARM[@]}")
    RSSALL=($(echo "${combinedrss[@]}" | tr ' ' '\n' | sort -u))
    ```
2.  **Ajout des Tiddlers au TiddlyWiki du Secteur** :

    ```bash
    for RSS in ${RSSALL[@]}; do
        ${MY_PATH}/RSS2UPlanetSECTORTW.sh "${RSS}" "${SECTOR}" "${MOATS}" "${INDEX}"
    done
    ```

####
