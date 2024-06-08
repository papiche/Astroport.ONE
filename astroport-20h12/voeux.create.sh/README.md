---
description: Gestion des Vœux
---

# VOEUX.create.sh

Les scripts `VOEUX.create.sh` et `VOEUX.refresh.sh` sont des composants essentiels de l'écosystème Astroport.ONE, permettant de gérer les vœux des joueurs. Voici une analyse détaillée de leurs fonctionnalités et de leur fonctionnement :

### VOEUX.create.sh

#### Fonctionnalités Principales

1. **Initialisation et Configuration** :
   * Le script commence par définir le chemin du script (`MY_PATH`) et le normalise pour obtenir un chemin absolu.
   * Il source un fichier de configuration commun (`my.sh`) pour utiliser des fonctions et des variables partagées.
2. **Création de la Clé Derivée pour le Vœu** :
   * Le script génère une clé dérivée pour le vœu en utilisant le titre du vœu, le joueur, et un sel.
   * Il utilise `keygen` pour créer une clé Duniter et une clé IPFS pour le vœu.
3. **Mise à Jour de la Base de Données des Vœux** :
   * Le script met à jour la base de données mondiale des vœux avec les informations du nouveau vœu.
   * Il génère des QR codes pour différents liens associés au vœu (par exemple, lien IPNS, lien G1).
4. **Création de Tiddlers** :
   * Le script crée des tiddlers spécifiques pour le vœu, incluant des informations comme le titre, le joueur, et les clés associées.

#### Étapes du Script

1.  **Définition des Variables et Chemins** :

    ```bash
    MY_PATH="`dirname \"$0\"`"
    MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
    . "${MY_PATH}/../tools/my.sh"
    ```
2.  **Création de la Clé Derivée** :

    ```bash
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/wish.dunikey "${SECRET1}${UPLANETNAME}" "${SECRET2}${UPLANETNAME}"
    WISHG1PUB=$(cat ~/.zen/tmp/${MOATS}/wish.dunikey | grep "pub:" | cut -d ' ' -f 2)
    ```
3.  **Mise à Jour de la Base de Données des Vœux** :

    ```bash
    mkdir -p ~/.zen/game/world/${VoeuName}/${WISHG1PUB}/
    echo ${VoeuName} > ~/.zen/game/world/${VoeuName}/${WISHG1PUB}/.pepper
    echo ${WISHG1PUB} > ~/.zen/game/world/${VoeuName}/${WISHG1PUB}/.wish
    ```
4.  **Création de QR Codes** :

    ```bash
    qrencode -s 12 -o "$HOME/.zen/game/world/${VoeuName}/${WISHG1PUB}/QR.WISHLINK.png" "$LIBRA/ipns/${VOEUNS}"
    ```

### VOEUX.refresh.sh

#### Fonctionnalités Principales

1. **Initialisation et Configuration** :
   * Le script commence par définir le chemin du script (`MY_PATH`) et le normalise pour obtenir un chemin absolu.
   * Il source un fichier de configuration commun (`my.sh`) pour utiliser des fonctions et des variables partagées.
2. **Extraction des Vœux depuis le TiddlyWiki du Joueur** :
   * Le script extrait les vœux du joueur depuis son TiddlyWiki en utilisant des filtres spécifiques.
   * Il vérifie si le joueur a suffisamment de G1 pour continuer à actualiser ses vœux.
3. **Mise à Jour des Vœux** :
   * Pour chaque vœu, le script vérifie et met à jour les informations associées, y compris les clés IPNS et les soldes des portefeuilles.
   * Il exécute des programmes spécifiques pour chaque type de vœu, si disponibles.
4. **Publication des Vœux** :
   * Le script publie les vœux mis à jour sur IPFS et met à jour les caches locaux et distants.

#### Étapes du Script

1.  **Définition des Variables et Chemins** :

    ```bash
    MY_PATH="`dirname \"$0\"`"
    MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
    . "${MY_PATH}/../tools/my.sh"
    ```
2.  **Extraction des Vœux** :

    ```bash
    tiddlywiki --load ${INDEX} --output ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu --render '.' "${PLAYER}.g1voeu.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[days:created[-360]tag[G1Voeu]]'
    ```
3.  **Mise à Jour des Vœux** :

    ```bash
    while read WISH do
        WISHNAME=$(cat ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${PLAYER}.g1voeu.json | jq .[] | jq -r 'select(.wish=="'${WISH}'") | .title')
        # Autres mises à jour...
    done < ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${PLAYER}.g1wishes.txt
    ```
4.  **Publication des Vœux** :

    ```bash
    WISHFLUX=$(ipfs add -qHwr ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${WISHNAME}/* | tail -n 1)
    ipfs --timeout 180s name publish -k $VOEUKEY /ipfs/$WISHFLUX
    ```

#### Conclusion

Les scripts `VOEUX.create.sh` et `VOEUX.refresh.sh` sont conçus pour gérer la création et la mise à jour des vœux des joueurs dans l'écosystème Astroport.ONE. Ils permettent de générer des clés dérivées, de mettre à jour les bases de données des vœux, de créer des tiddlers spécifiques, et de publier les vœux sur IPFS. Ces scripts assurent une gestion efficace et sécurisée des vœux, tout en maintenant la synchronisation avec les caches locaux et distants.
