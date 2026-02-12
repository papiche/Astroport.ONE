# Astroport 20H12

Astroport.ONE est une plateforme décentralisée sophistiquée qui combine IPFS, la blockchain Ğ1, et divers scripts pour gérer les nœuds, les joueurs, et les zones géographiques. Elle offre des fonctionnalités de mise à jour automatique, de surveillance, et de gestion des connexions sécurisées, tout en maintenant une infrastructure décentralisée robuste.

#### Processus Quotidien à 20h12

Le script `20h12.process.sh` est exécuté quotidiennement à 20h12 et effectue les tâches suivantes :

* Vérification et redémarrage du démon IPFS si nécessaire (ou arrêt en mode LOW).
* Nettoyage des répertoires temporaires tout en préservant les caches critiques.
* Mise à jour du code source et des outils (Astroport.ONE, UPlanet, NIP‑101, Silkaj, etc.).
* Exécution des rafraîchissements applicatifs : `PLAYER.refresh.sh`, `TW.refresh.sh`, `UPLANET.refresh.sh`, `NOSTR.UMAP.refresh.sh`, `NODE.refresh.sh`.
* Gestion des services système (astroport, g1billet, comfyui, DRAGON_p2p_ssh).
* Rafraîchissement des profils géographiques et Nostr (UMAP/SECTOR/REGION) à partir des caches `~/.zen/tmp/${IPFSNODEID}/UPLANET`.
* Envoi de notifications par email (rapport 20h12, consommation électrique, erreurs).

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
   * **Vœux** : VOEUX.create/refresh (données NOSTR).
5. **Zones géographiques** :
   * `TW.refresh.sh` et `PLAYER.refresh.sh` lient chaque MULTIPASS à une UMAP via le fichier `~/.zen/game/nostr/EMAIL/GPS`.
   * `UPLANET.refresh.sh` met à jour les tuiles UMAP locales (cache, IPFS, profils Nostr) sans utiliser IPNS.
   * `NOSTR.UMAP.refresh.sh` agrège le contenu Nostr (amis, likes, commons) par UMAP/SECTOR/REGION et publie des journaux (kind 3/30023, images, manifests).
   * `NODE.refresh.sh` met à jour la balise de station (`/ipns/$IPFSNODEID`), les listes `amisOfAmis.txt` et les caches Nostr (UNODE/UMAP/SECTOR/REGION).
6. **Sécurité et Accès** :
   * **Gestion des Clés SSH** : Le script `DRAGON_p2p_ssh.sh` gère les clés SSH pour permettre des connexions sécurisées entre les nœuds via IPFS.
7. **Surveillance et Notifications** :
   * **Surveillance des Transactions** : Le script `G1PalPay.sh` surveille les transactions sur la blockchain Ğ1 et exécute des commandes basées sur les commentaires des transactions.
   * **Notifications par Email** : Le script utilise `mailjet.sh` pour envoyer des notifications par email en cas d'erreurs ou d'événements importants.

#### Conclusion

