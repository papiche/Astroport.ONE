---
description: >-
  Le script PLAYER.refresh.sh est conçu pour actualiser les données des joueurs
  dans l'écosystème Astroport.ONE.
---

# PLAYER.refresh.sh

Le script `PLAYER.refresh.sh` est essentiel pour maintenir la synchronisation et l'actualisation des données des joueurs sur la plateforme Astroport.ONE.&#x20;

Il gère les clés IPFS/IPNS, vérifie et met à jour les tiddlers, surveille les transactions, et assure la publication et la sauvegarde des données. Ce script permet de garantir que les joueurs disposent toujours des informations les plus récentes et que leurs interactions sur la plateforme sont fluides et sécurisées.

#### Fonctionnalités Principales

1. **Initialisation et Préparation** :
   * Le script commence par définir le chemin du script et charger des fonctions utilitaires depuis `my.sh`.
   * Il identifie les joueurs locaux en lisant les fichiers dans le répertoire `~/.zen/game/players/`.
2. **Vérification et Nettoyage des Comptes** :
   * Pour chaque joueur, le script vérifie l'existence de la clé secrète `secret.dunikey`. Si elle est absente, le compte du joueur est supprimé.
3. **Mise à Jour des Données du Joueur** :
   * Le script crée ou met à jour les répertoires et fichiers nécessaires pour chaque joueur, y compris les données IPFS.
   * Il vérifie et importe les clés IPNS du joueur si elles sont manquantes.
4. **Téléchargement et Vérification des Tiddlers** :
   * Le script télécharge le TiddlyWiki (TW) du joueur depuis IPFS et vérifie la présence de tiddlers spécifiques comme `GPS`, `MadeInZion`, `AstroID`, et `Astroport`.
   * Si des tiddlers sont manquants ou incorrects, le joueur est déconnecté et une alerte est envoyée.
5. **Mise à Jour des Coordonnées Géographiques** :
   * Le script extrait les coordonnées GPS du tiddler `GPS` et les met à jour dans le cache du joueur.
   * Il génère des tiddlers supplémentaires comme `VISIO` et `CESIUM` en fonction de l'âge du compte du joueur.
6. **Gestion des Amis et des Vœux** :
   * Le script analyse les tiddlers tagués avec [`$:/moa`](usd-moa.md) pour gérer les amis du joueur et leurs tiddlers associés.
   * Il crée et actualise les vœux des joueurs en utilisant les scripts [`VOEUX.create.sh`](../voeux.create.sh/) et `VOEUX.refresh.sh`.
7. **Surveillance des Transactions** :
   * Le script exécute `G1PalPay.sh` pour surveiller les transactions sur la blockchain Ğ1 et exécuter des commandes basées sur les commentaires des transactions.
8. **Publication et Sauvegarde** :
   * Le script publie le TiddlyWiki mis à jour du joueur sur IPFS et met à jour les caches locaux.
   * Il envoie des notifications par email et publie des flux RSS pour les tiddlers modifiés.

