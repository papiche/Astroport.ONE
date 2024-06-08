# $:/moa

Les tiddlers tagués avec `$:/moa` dans le script `PLAYER.refresh.sh` sont utilisés pour gérer les amis du joueur et leurs tiddlers associés. Voici une analyse détaillée de ce processus :

#### Fonctionnement des Tiddlers Tagués avec `$:/moa`

1. **Extraction des Tiddlers** :
   *   Le script utilise la commande `tiddlywiki` pour charger le TiddlyWiki (TW) du joueur et extraire les tiddlers tagués avec `$:/moa`. Cette extraction est effectuée avec la commande suivante :

       ```bash
       tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
       --output ~/.zen/tmp/${MOATS} \
       --render '.' 'FRIENDS.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[$:/moa]]'
       ```
2. **Analyse des Tiddlers** :
   *   Les tiddlers extraits sont ensuite analysés pour identifier les amis du joueur. Le script lit les titres des tiddlers et vérifie s'ils correspondent à des adresses email valides :

       ```bash
       fplayers=($(cat ~/.zen/tmp/${MOATS}/FRIENDS.json | jq -rc .[].title))
       ```
3. **Gestion des Amis** :
   * Pour chaque ami identifié, le script effectue plusieurs vérifications et actions :
     * Vérifie le format de l'adresse email.
     * Vérifie si l'ami est déjà présent dans le système.
     * Extrait les informations supplémentaires comme le pseudo (`player`), l'adresse IPFS (`tw`), et la clé publique Ğ1 (`g1pub`).
4. **Mise à Jour des Tiddlers des Amis** :
   *   Si des tiddlers associés à des amis sont trouvés, ils sont importés dans le TW du joueur. Cela permet de maintenir les informations à jour et de synchroniser les données entre les amis :

       ```bash
       tiddlywiki --load ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/index.html \
       --import ~/.zen/tmp/${MOATS}/${FPLAYER^^}.json 'application/json' \
       --output ~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER} \
       --render "$:/core/save/all" "newindex.html" "text/plain"
       ```
5. **Création de Tiddlers Signés** :
   *   Les tiddlers des amis sont signés et ajoutés au TW du joueur. Cela permet de garantir l'authenticité des informations partagées :

       ```bash
       cat ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${WISHNAME}/_${APLAYER}.tiddlers.rss.json \
       | sed "s~${PLAYER}~~g" \
       | sed "s~${APLAYER}~${APLAYER} ${PLAYER}~g" \
       > ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${WISHNAME}/_${APLAYER}.tiddlers.signed.json
       ```

