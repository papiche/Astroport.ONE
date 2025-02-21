# Bienvenue à Astroport.ONE : Votre Portail Vers un Internet Décentralisé

Astroport.ONE n'est pas juste un logiciel ; c'est une plateforme complète et robuste, conçue pour propulser vos données et vos transactions dans l'ère de la décentralisation. Nous combinons la puissance du peer-to-peer et la pérennité d'IPFS avec la sécurité et la transparence de la blockchain Ğ1, offrant une solution sans équivalent pour un stockage de données souverain et des paiements sans intermédiaires.

## Découvrez Astroport.ONE : Plus Qu'un Simple Logiciel

Astroport.ONE représente une refonte fondamentale de la gestion de données. En intégrant le Système de Fichiers Interplanétaire (IPFS) et une architecture de Master Boot Record (MBR) pour Tiddlywiki, nous offrons une organisation de l'information d'une précision inégalée. Notre système UPlanet découpe l'espace numérique en segments de 0.01°, assurant que chaque donnée (Tiddler) est enregistrée localement avec une signature unique et vérifiable.

Imaginez Astroport.ONE comme votre station spatiale personnelle dans un univers numérique en expansion. Chaque station est une porte d'entrée, une ambassade numérique dans un monde de données interconnectées et sécurisées.

## Fonctionnalités Essentielles : La Puissance d'Astroport.ONE

*   **ZenCard et AstroID : Vos Clés d'Accès**

    *   **ZenCard** : Un système de paiement innovant basé sur la simplicité et la sécurité des QR Codes.
    *   **AstroID** : Votre identité numérique, inviolable et sous votre contrôle total.

*   **Stockage Décentralisé et Organisé**

    *   **IPFS au Cœur** : Bénéficiez d'un stockage distribué, résistant à la censure et aux pannes centralisées.
    *   **MBR et Table d'Allocation** : Une organisation des données Tiddlywiki optimisée pour la performance et la fiabilité.

*   **Vœux : Les Mots-Clés qui Animent AstroBot**

    *   **Système de Vœux** :  Plus que de simples souhaits, les "Vœux" sont des mots-clés que *vous* définissez dans votre TiddlyWiki pour déclencher **AstroBot**, le cœur automatisé d'Astroport.ONE. Ces mots-clés activent des programmes en BASH, des contrats intelligents rudimentaires, qui permettent d'automatiser des actions, de synchroniser des données, ou de réaliser des tâches spécifiques au sein de votre station. Bien que les Vœux puissent être soutenus par des dons en monnaie libre Ğ1, leur fonction première est d'orchestrer l'automatisation via AstroBOT, et non le financement collaboratif.

*   **Synchronisation et Communication P2P**

    *   **Stations Astroport.ONE** : Votre station communique et se synchronise avec un réseau d'ambassades numériques, assurant une cohérence et une disponibilité maximales des données.
    *   **AstroBot : L'Intelligence au Service de Vos Données** : Un système de contrats intelligents en BASH, réagissant aux événements du réseau Ğ1 et aux "Vœux" pour automatiser et optimiser votre expérience.
    *   **G1PalPay.sh : Le Moniteur de Transactions Ğ1** : Un script crucial qui surveille en temps réel la blockchain Ğ1. Il permet à Astroport.ONE de réagir aux transactions, d'exécuter des commandes basées sur les commentaires de transaction, et de gérer les flux financiers au sein de l'écosystème.

## Installation

### Prérequis

- **Système d'exploitation** : Linux Mint, Ubuntu, Debian

### Script d'Installation

```bash
bash <(curl -sL https://install.astroport.com)
```

### Processus en Cours d'Exécution

Après l'installation, vous devriez trouver les processus suivants en cours d'exécution :

```
/usr/local/bin/ipfs daemon --enable-pubsub-experiment --enable-namesys-pubsub
/bin/bash /home/fred/.zen/G1BILLET/G1BILLETS.sh daemon
/bin/bash /home/fred/.zen/Astroport.ONE/12345.sh
/bin/bash /home/fred/.zen/Astroport.ONE/_12345.sh
```

## Utilisation

### Création d'un Joueur

Pour créer un joueur, définissez les paramètres suivants : email, salt, pepper, lat, lon et PASS.

```bash
~/.zen/Astroport.ONE/command.sh
```

### API BASH

Une fois votre station Astroport démarrée, les ports suivants sont activés :

- **Port 1234** : Publie l'API v1 (/45780, /45781 et /45782 en sont les ports de réponse)
- **Port 12345** : Publie la carte des stations.
- **Port 33101** : Comande la création G1BILLETS (:33102 permet leur récupération)
- **Ports 8080, 4001 et 5001** : Ports de la passerelle IPFS.
- **Port 54321** : Publie l'API v2 ([UPassport](https://github.com/papiche/UPassport/)).

### Exemples d'Utilisation de l'API

#### Créer un Joueur

```http
GET /?salt=${SALT}&pepper=${PEPPER}&g1pub=${URLENCODEDURL}&email=${PLAYER}
```

#### Lire la Messagerie de la Base GChange

```http
GET /?salt=${SALT}&pepper=${PEPPER}&messaging=on
```

#### Déclencher un Paiement de Ğ1

```http
GET /?salt=${SALT}&pepper=${PEPPER}&pay=1&g1pub=DsEx1pS33vzYZg4MroyBV9hCw98j1gtHEhwiZ5tK7ech
```

### Utilisation de l'API UPLANET

L'API `UPLANET.sh` est dédiée aux applications OSM2IPFS et UPlanet Client App. Elle gère les atterrissages UPLANET et la création de ZenCards et AstroIDs.

#### Paramètres Requis

- `uplanet` : Email du joueur.
- `zlat` : Latitude avec 2 décimales.
- `zlon` : Longitude avec 2 décimales.
- `g1pub` : (Facultatif) Langue origine (fr, en, ...)

#### Exemple de Requête

```http
GET /?uplanet=player@example.com&zlat=48.85&zlon=2.35&g1pub=fr
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `uplanet` | `email`  | **Requis**. Email du joueur       |
| `zlat`    | `decimal`| **Requis**. Latitude avec 2 décimales |
| `zlon`    | `decimal`| **Requis**. Longitude avec 2 décimales |
| `g1pub`   | `string` | **Facultatif**. Langue origine (fr, en, ...) |

## DOCUMENTATION

https://astroport-1.gitbook.io/astroport.one/

## Contribution

Ce projet est [une sélection](https://github.com/papiche/Astroport.solo) de certains des logiciels libres et open source les plus précieux.

Les contributions sont les bienvenues sur [opencollective.com/monnaie-libre](https://opencollective.com/monnaie-libre#category-BUDGET).

## Stargazers over time

[![Stargazers over time](https://starchart.cc/papiche/Astroport.ONE.svg)](https://starchart.cc/papiche/Astroport.ONE)

## Crédits

Merci à tous ceux qui ont contribué à rendre ce logiciel disponible pour tous. Connaissez-vous [Ğ1](https://monnaie-libre.fr) ?

La meilleure crypto-monnaie dont vous puissiez rêver.
