# REGION.refresh.sh

Le script `REGION.refresh.sh` est conçu pour actualiser les données des régions géographiques dans l'écosystème Astroport.ONE en agrégeant les flux RSS produits par les secteurs internes. Voici une analyse détaillée de son fonctionnement :

#### Fonctionnalités Principales

1. **Initialisation et Configuration** :
   * Le script commence par définir le chemin du script (`MY_PATH`) et le normalise pour obtenir un chemin absolu.
   * Il source un fichier de configuration commun (`my.sh`) pour utiliser des fonctions et des variables partagées.
2. **Détermination des Régions** :
   * Le script identifie les régions géographiques à partir des coordonnées des UMAPs (Unités de Mesure de l'Activité Planétaire).
   * Il génère une liste unique de régions à partir des UMAPs disponibles.
3. **Génération et Gestion des Clés** :
   * Le script génère des clés Duniter et IPFS pour chaque région.
   * Il importe ces clés dans le keystore IPFS et les utilise pour publier les données de la région.
4. **Récupération et Mise à Jour des Données** :
   * Le script récupère les données de la région à partir de la clé IPNS de la veille.
   * Il met à jour les données de la région avec les nouvelles informations collectées.
5. **Agrégation des Flux RSS** :
   * Le script collecte les flux RSS des secteurs internes et les agrège pour créer un flux RSS régional.
   * Il utilise des outils pour convertir les flux RSS en fichiers JSON et les fusionner.
6. **Publication des Données** :
   * Le script publie les données mises à jour sur IPFS et met à jour les caches locaux et distants.
   * Il génère des QR codes et des images pour visualiser les informations de la région.

#### Étapes du Script

1.  **Définition des Variables et Chemins** :

    ```bash
    MY_PATH="`dirname \"$0\"`"
    MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
    . "${MY_PATH}/../tools/my.sh"
    ```
2.  **Détermination des Régions** :

    ```bash
    for UMAP in ${UMAPS[@]}; do
        LAT=$(echo ${UMAP} | cut -d '_' -f 2)
        LON=$(echo ${UMAP} | cut -d '_' -f 3)
        RLAT="${LAT::-1}"
        RLON="${LON::-1}"
        MYREGIONS=("_${RLAT}_${RLON}" ${MYREGIONS[@]})
    done
    REGIONS=($(echo "${MYREGIONS[@]}" | tr ' ' '\n' | sort -u))
    ```
3.  **Génération et Gestion des Clés** :

    ```bash
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/REGION.priv "${UPLANETNAME}${REGION}" "${UPLANETNAME}${REGION}"
    REGIONG1PUB=$(cat ~/.zen/tmp/${MOATS}/REGION.priv | grep 'pub:' | cut -d ' ' -f 2)
    REGIONNS=$(ipfs key import ${REGIONG1PUB} -f pem-pkcs8-cleartext ~/.zen/tmp/${MOATS}/REGION.priv)
    ```
4.  **Récupération et Mise à Jour des Données** :

    ```bash
    ipfs --timeout 240s get --progress=false -o ~/.zen/tmp/${MOATS}/${REGION}/ /ipns/${YESTERDATEREGIONNS}/
    ```
5.  **Agrégation des Flux RSS** :

    ```bash
    RSSNODE=($(ls ~/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/_${RLAT}*_${RLON}*/_${RLAT}*_${RLON}*/_${RLAT}*_${RLON}*.week.rss.json 2>/dev/null))
    for RSS in ${RSSNODE[@]}; do
        [[ $(cat ${RSS}) != "[]" ]] && cp ${RSS} ~/.zen/tmp/${MOATS}/${REGION}/RSS/ && ${MY_PATH}/../tools/RSS2WEEKnewsfile.sh ${RSS} >> ~/.zen/tmp/${MOATS}/${REGION}/JOURNAL
    done
    ```
6.  **Publication des Données** :

    ```bash
    IPFSPOP=$(ipfs add -rwq ~/.zen/tmp/${MOATS}/${REGION}/* | tail -n 1)
    ipfs --timeout 180s name publish -k ${TODATE}${REGIONG1PUB} /ipfs/${IPFSPOP}
    ```

A VENIR

ollama
