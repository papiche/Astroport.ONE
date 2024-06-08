# Intro

Les scripts fournis sont interconnectés et font partie d'un écosystème appelé Astroport.ONE, qui utilise IPFS (InterPlanetary File System) et la blockchain Ğ1 pour diverses opérations.&#x20;

Voici une description des relations entre les scripts :

#### 1. `20h12.process.sh`

Ce script est exécuté quotidiennement à 20h12 et orchestre plusieurs tâches importantes :

* **Vérification et redémarrage du démon IPFS** : Assure que le démon IPFS est actif et redémarre si nécessaire.
* **Nettoyage des répertoires temporaires** : Nettoie les répertoires temporaires tout en conservant certains dossiers importants.
* **Mise à jour du code source** : Met à jour le code source d'Astroport.ONE et de G1BILLET via Git.
* **Exécution des scripts de mise à jour** : Exécute des scripts pour mettre à jour les joueurs, les nœuds, et les zones géographiques.
* **Surveillance des transactions** : Utilise `G1PalPay.sh` pour surveiller les transactions sur la blockchain Ğ1.
* **Notifications par email** : Utilise `mailjet.sh` pour envoyer des notifications par email en cas d'erreurs ou d'événements importants.

#### 2. `PLAYER.refresh.sh`

Ce script gère les joueurs et leurs données :

* **Mise à jour des données des joueurs** : Rafraîchit les données des joueurs, y compris les portefeuilles et les tiddlers (petits morceaux de contenu).
* **Gestion des clés IPFS** : Vérifie et importe les clés IPFS des joueurs.
* **Surveillance des transactions** : Utilise `G1PalPay.sh` pour surveiller les transactions et exécuter des commandes basées sur les commentaires des transactions.

#### 3. `NODE.refresh.sh`

Ce script gère les nœuds IPFS :

* **Mise à jour des données des nœuds** : Rafraîchit les données des nœuds et publie des balises de station.
* **Nettoyage des répertoires temporaires** : Nettoie les répertoires temporaires des nœuds.

#### 4. `VOEUX.refresh.sh`

Ce script gère les vœux des joueurs :

* **Extraction des vœux** : Extrait les vœux des joueurs à partir de leurs tiddlers.
* **Mise à jour des vœux** : Rafraîchit les vœux et exécute des programmes spécifiques basés sur les vœux.

#### 5. `REGION.refresh.sh`

Ce script gère les régions géographiques :

* **Mise à jour des régions** : Rafraîchit les données des régions en collectant des informations à partir des secteurs.
* **Publication des données** : Publie les données des régions sur IPFS.

#### 6. `ZEN.UMAP.memory.sh`

Ce script gère la mémoire des cartes UMAP :

* **Récupération des données** : Récupère les données de mémoire des secteurs à partir de l'historique des transactions.

#### 7. `G1PalPay.sh`

Ce script surveille les transactions sur la blockchain Ğ1 :

* **Surveillance des paiements entrants** : Vérifie les paiements entrants et exécute des commandes basées sur les commentaires des transactions.
* **Redistribution des fonds** : Redistribue les fonds aux destinataires spécifiés dans les commentaires des transactions.

#### 8. `DRAGON_p2p_ssh.sh`

Ce script gère les connexions SSH sur IPFS :

* **Ouverture et fermeture des connexions SSH** : Ouvre et ferme les connexions SSH sur IPFS pour le support et la maintenance.

#### 9. `G1Voeu.sh`

Ce script crée des vœux pour les joueurs :

* **Création de tiddlers de vœux** : Crée des tiddlers de vœux pour les joueurs et les publie sur IPFS.

#### Relations entre les scripts

* **Coordination** : `20h12.process.sh` coordonne l'exécution de plusieurs autres scripts (`PLAYER.refresh.sh`, `NODE.refresh.sh`, `VOEUX.refresh.sh`, etc.) pour assurer la mise à jour et la maintenance de l'écosystème.
* **Dépendances** : Les scripts comme `PLAYER.refresh.sh` et `VOEUX.refresh.sh` dépendent de `G1PalPay.sh` pour surveiller les transactions et exécuter des commandes basées sur les paiements.
* **Publication et mise à jour** : Les scripts `NODE.refresh.sh` et `REGION.refresh.sh` publient et mettent à jour les données sur IPFS, assurant que les informations sont synchronisées et accessibles.
* **Gestion des clés et des connexions** : `DRAGON_p2p_ssh.sh` et `G1Voeu.sh` gèrent les clés IPFS et les connexions SSH, assurant la sécurité et la connectivité de l'écosystème.

ces scripts travaillent ensemble pour maintenir et mettre à jour l'écosystème Astroport.ONE, en utilisant IPFS et la blockchain Ğ1 pour gérer les données, les transactions, et les connexions sécurisées.
