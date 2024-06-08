# PLAYER.sh

Le script `PLAYER.sh` dans le répertoire `/API` de l'écosystème Astroport.ONE est conçu pour gérer les interactions avec les joueurs, en particulier les opérations liées aux TiddlyWikis (TW) des joueurs.

Il permet d'exporter des tiddlers spécifiques, de gérer les passes (fonctionnalité désactivée), et d'ajouter des médias au TiddlyWiki des joueurs (fonctionnalité désactivée). Le script utilise des requêtes HTTP pour communiquer avec les clients et renvoie les données sous forme de JSON.



&#x20;Voici une analyse détaillée de son fonctionnement :

#### Fonctionnalités Principales

1. **Initialisation et Configuration** :
   * Le script commence par définir le chemin du script (`MY_PATH`) et le normalise pour obtenir un chemin absolu.
   * Il source un fichier de configuration commun (`my.sh`) pour utiliser des fonctions et des variables partagées.
   * Il initialise les variables nécessaires à partir des arguments passés au script.
2. **Gestion des Requêtes HTTP** :
   * Le script prépare une réponse HTTP avec les en-têtes appropriés pour permettre les requêtes CORS (Cross-Origin Resource Sharing).
3. **Exportation de Tiddlers** :
   * Si le paramètre `APPNAME` est `moa`, le script exporte les tiddlers spécifiques tagués avec un certain mot-clé (`WHAT`).
   * Il utilise TiddlyWiki pour charger le fichier `index.html` du joueur et exporter les tiddlers dans un fichier JSON.
   * La réponse est envoyée au client sous forme de JSON.
4. **Gestion des @PASS** :
   * (Commenté) Le script contient une section pour la création de passes pour les joueurs, mais cette fonctionnalité est désactivée.
5. **Ajout de Médias** :
   * (Commenté) Le script contient une section pour l'ajout de vidéos YouTube, PDF, ou images au TW du joueur, mais cette fonctionnalité est désactivée.

#### Étapes du Script

1.  **Définition des Variables et Chemins** :

    ```bash
    MY_PATH="`dirname \"$0\"`"
    MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
    . "${MY_PATH}/../tools/my.sh"
    start=`date +%s`
    PORT=$1
    PLAYER=$2
    APPNAME=$3
    OBJ=$5
    HTTPCORS="HTTP/1.1 200 OK Access-Control-Allow-Origin: ${myASTROPORT} Access-Control-Allow-Credentials: true Access-Control-Allow-Methods: GET Server: Astroport.ONE Content-Type: text/html; charset=UTF-8 "
    ```
2.  **Vérification du Joueur** :

    * Le script vérifie si le joueur (`PLAYER`) est fourni et valide.
    * Il récupère l'adresse IPNS de l'astronaute (`ASTRONAUTENS`) associée au joueur.

    ```bash
    [[ ! ${PLAYER} ]] && (echo "${HTTPCORS} BAD PLAYER - EXIT" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 1
    ASTRONAUTENS=$(ipfs key list -l | grep -w ${PLAYER} | cut -d ' ' -f1)
    [[ ! ${ASTRONAUTENS} ]] && (echo "${HTTPCORS} UNKNOWN PLAYER ${PLAYER} - EXIT" | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &) && exit 1
    ```
3.  **Exportation de Tiddlers** :

    * Si `APPNAME` est `moa`, le script exporte les tiddlers tagués avec `WHAT` (par défaut `G1CopierYoutube`).
    * Il utilise TiddlyWiki pour charger le fichier `index.html` du joueur et exporter les tiddlers dans un fichier JSON.
    * La réponse est envoyée au client sous forme de JSON.

    ```bash
    if [[ ${APPNAME} == "moa" ]]; then
        [[ ! ${WHAT} ]] && WHAT="G1CopierYoutube"
        echo "EXPORT MOATUBE ${PLAYER} ${WHAT}"
        tiddlywiki --load ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html --output ~/.zen/tmp/ --render '.' "${PLAYER}.moatube.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' "[tag[${WHAT}]]"
        if [[ ! ${THIS} || ${THIS} == "json" ]]; then
            echo "${HTTPCORS}" > ~/.zen/tmp/${MOATS}.${PLAYER}.http
            sed -i "s~text/html~application/json~g" ~/.zen/tmp/${MOATS}.${PLAYER}.http
            cat ~/.zen/tmp/${PLAYER}.moatube.json >> ~/.zen/tmp/${MOATS}.${PLAYER}.http
            cat ~/.zen/tmp/${MOATS}.${PLAYER}.http | nc -l -p ${PORT} -q 1 > /dev/null 2>&1 &
        fi
        end=`date +%s`
        echo "(TW) MOA Operation time was "`expr $end - $start` seconds.
        exit 0
    fi
    ```
4.  **Gestion des @PASS** :

    * (Commenté) Le script contient une section pour la création de passes pour les joueurs, mais cette fonctionnalité est désactivée.

    ```bash
    #~ if [[ ${APPNAME} == "atpass" ]]; then
    #~ echo "CREATING @PASS"
    #~ end=`date +%s`
    #~ echo "(@PASS) creation time was "`expr $end - $start` seconds.
    #~ exit 0
    #~ fi
    ```
5.  **Ajout de Médias** :

    * (Commenté) Le script contient une section pour l'ajout de vidéos YouTube, PDF, ou images au TW du joueur, mais cette fonctionnalité est désactivée.

    ```bash
    #~ if [[ ${APPNAME} == "youtube" || ${APPNAME} == "pdf" || ${APPNAME} == "image" ]]; then
    #~ APPNAME=$(echo ${APPNAME} | sed -r 's/\<./\U&/g' | sed 's/ //g') ## First letter Capital
    #~ [[ ! ${THIS} ]] && THIS="https://www.youtube.com/watch?v=BCl2-0HBJ2c"
    #~ echo ">>> COPY ${APPNAME} for ${PLAYER} from ${THIS}"
    #~ G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub)
    #~ [[ ! ${G1PUB} ]] && espeak "NOT MY PLAYER " && echo "${PLAYER} IS NOT MY PLAYER" && exit 1
    #~ echo "================================================"
    #~ echo "${PLAYER} : ${myIPFS}/ipns/${ASTRONAUTENS}"
    #~ echo " = /ipfs/${TW}"
    #~ echo "================================================"
    #~ ${MY_PATH}/../ajouter_media.sh "${THIS}" "${PLAYER}" "${APPNAME}" &
    #~ echo "${HTTPCORS}" > ~/.zen/tmp/${MOATS}.${PLAYER}.http
    #~ echo "${myIPFS}/ipns/${ASTRONAUTENS}" >> ~/.zen/tmp/${MOATS}.${PLAYER}.http
    #~ (
    #~ cat ~/.zen/tmp/${MOATS}.${PLAYER}.http | nc -l -p ${PORT} -q 1 > /dev/null 2>&1
    #~ rm ~/.zen/tmp/${MOATS}.${PLAYER}.http
    #~ ) &
    #~ # ### REFRESH CHANNEL COPY
    #~ end=`date +%s`
    #~ echo "(TW) MOA Operation time was "`expr $end - $start` seconds.
    #~ exit 0
    #~ fi
    ```

####
