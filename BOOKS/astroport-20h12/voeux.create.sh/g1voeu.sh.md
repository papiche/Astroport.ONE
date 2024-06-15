# G1Voeu.sh

Le script `G1Voeu.sh` permet de créer et de publier un vœu sur la blockchain Ğ1 pour un joueur spécifique. Il génère une clé dérivée pour le vœu, met à jour le TiddlyWiki du joueur avec les informations du vœu, et publie le TiddlyWiki mis à jour sur IPFS.&#x20;

#### Fonctionnalités Principales

1. **Initialisation et Configuration** :
   * Le script commence par définir le chemin du script (`MY_PATH`) et le normalise pour obtenir un chemin absolu.
   * Il source un fichier de configuration commun (`my.sh`) pour utiliser des fonctions et des variables partagées.
2. **Paramètres et Variables** :
   * Le script prend trois paramètres principaux : le titre du vœu (`TITRE`), le joueur (`PLAYER`), et le chemin vers l'index TiddlyWiki (`INDEX`).
   * Si le joueur ou l'index ne sont pas fournis, le script tente de les récupérer à partir des fichiers de configuration locaux.
3. **Création de la Clé Derivée pour le Vœu** :
   * Le script utilise une clé dérivée pour le vœu, générée à partir du titre du vœu, du joueur, et d'un sel (SALT).
   * Il utilise l'outil `keygen` pour générer cette clé dérivée et obtenir la clé publique Ğ1 associée (`WISHG1PUB`).
4. **Mise à Jour du TiddlyWiki** :
   * Le script met à jour le TiddlyWiki du joueur avec les informations du vœu.
   * Il crée un tiddler spécifique pour le vœu et l'ajoute au TiddlyWiki.
5. **Publication sur IPFS** :
   * Le script publie le TiddlyWiki mis à jour sur IPFS et met à jour les caches locaux et distants.
   * Il génère des QR codes et des images pour visualiser les informations du vœu.

#### Étapes du Script

1.  **Définition des Variables et Chemins** :

    ```bash
    MY_PATH="`dirname \"$0\"`"
    MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
    . "${MY_PATH}/../tools/my.sh"
    ```
2.  **Paramètres et Variables** :

    ```bash
    TITRE="$1"
    PLAYER="$2"
    INDEX="$3"
    [[ ${PLAYER} == "" ]] && PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
    [[ ${PLAYER} == "" ]] && echo "Second paramètre PLAYER manquant" && exit 1
    PSEUDO=$(cat ~/.zen/game/players/${PLAYER}/.pseudo 2>/dev/null)
    [[ $G1PUB == "" ]] && G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null)
    [[ $G1PUB == "" ]] && echo "Troisième paramètre G1PUB manquant" && exit 1
    [[ ! $INDEX ]] && INDEX="$HOME/.zen/game/players/${PLAYER}/ipfs/moa/index.html"
    ```
3.  **Création de la Clé Derivée pour le Vœu** :

    ```bash
    source ~/.zen/game/players/${PLAYER}/secret.june
    [[ ${PEPPER} ]] && echo "Using PLAYER PEPPER AS WISH SALT" && SECRET1="${PEPPER}"
    SECRET2="${VoeuName} ${PLAYER} ${SALT}"
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/tmp/${MOATS}/wish.dunikey "${SECRET1}${UPLANETNAME}" "${SECRET2}${UPLANETNAME}"
    WISHG1PUB=$(cat ~/.zen/tmp/${MOATS}/wish.dunikey | grep 'pub:' | cut -d ' ' -f 2)
    ```
4.  **Mise à Jour du TiddlyWiki** :

    ```bash
    tiddlywiki --load ${INDEX} --output ~/.zen/tmp/${MOATS} --render '.' 'G1Voeu.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1Voeu]]'
    ```
5.  **Publication sur IPFS** :

    ```bash
    TW=$(ipfs add -Hq ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html | tail -n 1)
    ipfs --timeout 720s name publish --key=${PLAYER} /ipfs/${TW}
    ```

####
