# Astroport.ONE

Bienvenue dans l'univers d'Astroport.ONE, une plateforme révolutionnaire qui combine la technologie blockchain avec le stockage interplanétaire pour offrir des solutions de paiement et de stockage de données sécurisées et sans commission.

## Introduction

**Astroport.ONE v1.0 : Stockage Décentralisé au-delà des Frontières**

Astroport.ONE n'est pas seulement un logiciel de stockage distribué ; c'est une réinvention de la gestion des données. En utilisant IPFS et en introduisant un master boot record (MBR) et une table d'allocation pour les données Tiddlywiki, Astroport.ONE organise les informations avec une précision sans précédent. Dans le système de format UPlanet, la planète est découpée en segments de 0,01°, garantissant des Tiddlers enregistrés localement avec des signatures uniques.

**Station Extra-Terrestre Astroport.ONE : Là où l'Innovation Rencontre la Tranquillité**

Découvrez la Station Extra-Terrestre Astroport.ONE, un havre pour les volontaires cherchant à vivre en paix et en harmonie dans un vaisseau spatial transformé en jardin. Participez à un nouveau "Jeu de Société" développé par et pour les Astronautes de MadeInZion.

## Fonctionnalités Principales

### ZenCard et AstroID

- **ZenCard** : Système de paiement basé sur QRCode.
- **AstroID** : Identité numérique sécurisée.

### Stockage Décentralisé

- **IPFS** : Utilisation d'IPFS pour le stockage distribué.
- **MBR et Table d'Allocation** : Organisation précise des données Tiddlywiki.

### Gestion des Vœux

- **Voeux** : Idées, plans, explications et erreurs financés collaborativement via des dons en monnaie libre Ğ1.

### Synchronisation et Communication

- **Stations Astroport.ONE** : Chaque station est une ambassade numérique qui communique et se synchronise avec ses pairs.
- **AstroBot** : Contrat intelligent en BASH déclenché par des "G1Tag".

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
