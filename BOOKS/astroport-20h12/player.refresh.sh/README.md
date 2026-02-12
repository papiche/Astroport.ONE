---
description: >-
  Le script PLAYER.refresh.sh est conçu pour actualiser les données des joueurs
  dans l'écosystème Astroport.ONE.
---

# PLAYER.refresh.sh

Le script `PLAYER.refresh.sh` est essentiel pour maintenir la synchronisation et l'actualisation des données des joueurs sur la plateforme Astroport.ONE.&#x20;

Il orchestre maintenant surtout la partie **économique et coopérative** (MULTIPASS/ZEN Card, loyers U.SOCIETY, TVA, etc.) et délègue la gestion fine des TiddlyWiki à `TW.refresh.sh`. La couche d’adresse géographique et d’identité publique repose de plus en plus sur Nostr (profils, GPS, journaux UMAP).

#### Fonctionnalités Principales

1. **Initialisation et Préparation** :
   * Le script commence par définir le chemin du script et charger des fonctions utilitaires depuis `my.sh`.
   * Il identifie les joueurs locaux en lisant les fichiers dans le répertoire `~/.zen/game/players/`.
2. **Vérification et Nettoyage des Comptes** :
   * Pour chaque joueur, le script vérifie l'existence de la clé secrète `secret.dunikey`. Si elle est absente, le compte du joueur est supprimé.
3. **Gestion économique du MULTIPASS / ZEN Card** :
   * Vérifie les soldes Ğ1 des wallets MULTIPASS (`G1PUBNOSTR`) et ZENCARD (`.g1pub`) via `G1check.sh`.
   * Applique les règles coopératives:
     * ZEN Card à 1 Ğ1 (0 ẐEN) pour les membres, sinon nettoyage via `G1zencard_0zen.sh`.
     * Loyers hebdomadaires pour les non‑U.SOCIETY (paiements vers CAPTAIN + IMPOT via `PAYforSURE.sh` et TVA calculée).
4. **Gestion U.SOCIETY** :
   * Lit les fichiers `U.SOCIETY` et `U.SOCIETY.end` pour déterminer si un joueur est couvert par un contrat de société.
   * Exempte de loyer les membres actifs, marque ceux arrivés à échéance.
5. **Délégation TiddlyWiki & GPS** :
   * Pour chaque joueur valide, appelle `TW.refresh.sh` qui:
     * synchronise le TW via IPFS/IPNS,
     * force le GPS du TW à partir de `~/.zen/game/nostr/EMAIL/GPS`,
     * met à jour le cache `~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_RLAT_RLON/_SLAT_SLON/_LAT_LON/...`.
6. **Surveillance et notifications** :
   * En cas d’incohérence grave (TW invalide, absence de clés, TW déplacé sur un autre Astroport, etc.), appelle `PLAYER.unplug.sh` et peut envoyer des emails via `mailjet.sh`.

Les anciennes responsabilités directes de `PLAYER.refresh.sh` sur les clés IPNS et la géolocalisation ont été allégées :  
il pilote maintenant la **logique métier des joueurs** et laisse `TW.refresh.sh`, `UPLANET.refresh.sh` et `NOSTR.UMAP.refresh.sh` gérer respectivement le TW, les tuiles géographiques UPLANET et les journaux/identités Nostr associés.

