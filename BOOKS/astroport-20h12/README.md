# Astroport 20H12

Astroport.ONE est une plateforme décentralisée sophistiquée qui combine IPFS, la blockchain Ğ1, et divers scripts pour gérer les nœuds, les joueurs, et les zones géographiques. Elle offre des fonctionnalités de mise à jour automatique, de surveillance, et de gestion des connexions sécurisées, tout en maintenant une infrastructure décentralisée robuste.

#### Processus Quotidien à 20h12

Le script `20h12.process.sh` est exécuté quotidiennement à 20h12 et effectue les tâches suivantes :

* Vérification et redémarrage du démon IPFS si nécessaire.
* Nettoyage des répertoires temporaires.
* Mise à jour du code source et des outils.
* Exécution des scripts de mise à jour pour les joueurs, les nœuds, et les zones géographiques.
* Gestion des clés SSH et des connexions sécurisées.
* Surveillance des transactions et exécution des commandes associées.
* Envoi de notifications par email et messagerie Cesium+

#### Fonctionnalités Principales

1. **Gestion des Nœuds IPFS** :
   * **Vérification et Redémarrage** : Le script vérifie si le démon IPFS est actif et le redémarre si nécessaire. Il s'assure également que le port 5001 est à l'écoute pour les connexions IPFS.
   * **Mise à Jour des Nœuds Bootstrap** : Les nœuds bootstrap sont mis à jour pour maintenir la connectivité et la synchronisation du réseau.
2. **Nettoyage et Gestion des Fichiers Temporaires** :
   * **Nettoyage des Répertoires Temporaires** : Les répertoires temporaires sont nettoyés tout en conservant certains dossiers importants comme `swarm`, `coucou`, et `flashmem`.
3. **Mise à Jour des Composants** :
   * **Mise à Jour du Code Source** : Le script met à jour le code source d'Astroport.ONE et de G1BILLET via Git.
   * **Mise à Jour de `yt-dlp`** : Le script met à jour l'outil `yt-dlp` pour le téléchargement de vidéos.
4. **Gestion des Joueurs et des Tâches** :
   * **Analyse et Exécution des Tâches des Joueurs** : Le script `PLAYER.refresh.sh` analyse les tâches des joueurs et exécute les scripts associés.
   * **Gestion des Vœux** : Les scripts `VOEUX.create.sh` et `VOEUX.refresh.sh` gèrent les vœux des joueurs, créant et actualisant les vœux basés sur des tiddlers (petits morceaux de contenu).
5. **Gestion des Zones Géographiques** :
   * **Mise à Jour des Clés Géographiques** : Les scripts `UPLANET.refresh.sh`, `SECTOR.refresh.sh`, et `REGION.refresh.sh` mettent à jour les informations géographiques et les clés associées pour les secteurs et les régions.
6. **Sécurité et Accès** :
   * **Gestion des Clés SSH** : Le script `DRAGON_p2p_ssh.sh` gère les clés SSH pour permettre des connexions sécurisées entre les nœuds via IPFS.
7. **Surveillance et Notifications** :
   * **Surveillance des Transactions** : Le script `G1PalPay.sh` surveille les transactions sur la blockchain Ğ1 et exécute des commandes basées sur les commentaires des transactions.
   * **Notifications par Email** : Le script utilise `mailjet.sh` pour envoyer des notifications par email en cas d'erreurs ou d'événements importants.

#### Conclusion

