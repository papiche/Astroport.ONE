# G1PalPay.sh

Le script `G1PalPay.sh` est un outil puissant pour surveiller les transactions sur la blockchain Ğ1 et exécuter des actions basées sur les commentaires des transactions. Il permet d'automatiser des tâches telles que l'exécution de commandes spécifiques, la redistribution de fonds, et l'envoi de notifications, tout en maintenant une synchronisation avec les données de la blockchain et les tiddlers associé

#### Fonctionnalités Principales

1. **Initialisation et Configuration** :
   * Le script commence par définir le chemin du script (`MY_PATH`) et le normalise pour obtenir un chemin absolu.
   * Il source un fichier de configuration commun (`my.sh`) pour utiliser des fonctions et des variables partagées.
2. **Vérification des Paramètres** :
   * Le script vérifie si le fichier TiddlyWiki (TW) et le joueur (`PLAYER`) sont fournis en arguments. Si ce n'est pas le cas, il utilise des valeurs par défaut ou affiche un message d'erreur.
3. **Extraction des Transactions Récentes** :
   *   Le script utilise `jaklis.py` pour extraire les 30 dernières transactions du portefeuille Ğ1 du joueur et les enregistre dans un fichier JSON :

       ```bash
       ~/.zen/Astroport.ONE/tools/timeout.sh -t 12 \
       ${MY_PATH}/../tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey history -n 30 -j \
       > $HOME/.zen/game/players/${PLAYER}/G1PalPay/${PLAYER}.duniter.history.json
       ```
4. **Traitement des Transactions** :
   * Le script parcourt les transactions extraites et vérifie les commentaires pour détecter des commandes spécifiques (N1) ou des adresses email.
   * Pour chaque transaction, il extrait les informations pertinentes telles que la date, la clé publique de l'émetteur, le montant, et le commentaire.
5. **Exécution des Commandes N1** :
   *   Si le commentaire d'une transaction commence par `N1`, le script exécute le programme correspondant dans le répertoire `ASTROBOT` :

       ```bash
       if [[ -s ${MY_PATH}/../ASTROBOT/${CMD}.sh ]]; then
           ${MY_PATH}/../ASTROBOT/${CMD}.sh ${INDEX} ${PLAYER} ${MOATS} ${TXIPUBKEY} ${TH} ${TRAIL} ${TXIAMOUNT}
       fi
       ```
6. **Traitement des Adresses Email** :
   * Si le commentaire contient des adresses email, le script divise le montant de la transaction par le nombre d'adresses et envoie une partie à chaque adresse.
   *   Il utilise `PAYforSURE.sh` pour effectuer les paiements :

       ```bash
       ${MY_PATH}/../tools/PAYforSURE.sh "${HOME}/.zen/game/players/${PLAYER}/secret.dunikey" "${SHARE}" "${ASTROG1}" "UPLANET${UPLANETG1PUB:0:8}:PALPAY"
       ```
7. **Gestion des Tiddlers** :
   * Le script extrait les tiddlers modifiés au cours des dernières 24 heures et vérifie s'ils contiennent des adresses email dans les tags.
   * Il traite ces tiddlers pour envoyer des notifications ou effectuer des paiements en fonction des adresses email trouvées.

####
