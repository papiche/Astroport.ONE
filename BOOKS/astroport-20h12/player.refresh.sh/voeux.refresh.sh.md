# VOEUX.refresh.sh

Le script `VOEUX.refresh.sh` est conçu pour gérer et actualiser les vœux des joueurs dans l'écosystème Astroport. Voici une analyse détaillée de son fonctionnement :

#### Fonctionnalités Principales

1. **Initialisation et Vérifications** :
   * Le script commence par vérifier si le nom du joueur (`PLAYER`) est fourni en argument. Si ce n'est pas le cas, il affiche un message d'erreur et s'arrête.
   * Il récupère ensuite le pseudo du joueur (`PSEUDO`), la clé publique Ğ1 (`G1PUB`), et l'adresse IPNS de l'astronaute (`ASTRONAUTENS`).
2. **Vérification du Solde** :
   * Le script vérifie le solde du joueur en Ğ1 (`COINS`). Si le solde est insuffisant (moins de 2 Ğ1), il affiche un message d'erreur et s'arrête.
3. **Extraction des Vœux** :
   * Le script extrait les vœux du joueur à partir de son TiddlyWiki (TW). Il utilise TiddlyWiki pour charger le fichier `index.html` du joueur et exporter les vœux dans un fichier JSON.
4. **Traitement des Vœux** :
   * Pour chaque vœu, le script :
     * Récupère le nom du vœu (`WISHNAME`).
     * Vérifie si une clé IPNS existe pour ce vœu (`VOEUKEY`). Si la clé n'existe pas, il réinitialise les vœux de l'astronaute.
     * Exécute un programme spécifique au vœu si un script correspondant est trouvé dans le répertoire `ASTROBOT`.
5. **Mise à Jour des Tiddlers** :
   * Le script recherche les Tiddlers associés aux vœux dans les TW des amis du joueur et les importe dans le TW du joueur.
   * Il génère également des fichiers JSON pour les vœux et les publie sur IPFS.
6. **Publication et Notifications** :
   * Le script publie les vœux sur IPFS et envoie des notifications par email aux joueurs concernés.
   * Il met à jour les caches locaux et les flux RSS pour les vœux.

#### Exemple de Commande

Voici un exemple de commande pour exécuter le script `VOEUX.refresh.sh` :

```bash
./RUNTIME/VOEUX.refresh.sh "player_name" "20230608123456789" "/path/to/index.html"
```

####
