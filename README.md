# Astroport.ONE : Votre Portail Décentralisé vers une Nouvelle Frontière Numérique

**Bienvenue sur Astroport.ONE !** Imaginez un monde numérique où vous avez le contrôle, où les données sont sécurisées, les paiements fluides et la communauté prospère au-delà des frontières. Astroport.ONE construit cet avenir, et vous êtes invité à en faire partie.

**Qu'est-ce qu'Astroport.ONE ?**

Astroport.ONE est une plateforme révolutionnaire conçue pour autonomiser les individus et les communautés à l'ère du Web3. C'est plus qu'un simple logiciel ; c'est une boîte à outils pour créer votre propre ambassade numérique décentralisée - une **Station** - où vous pouvez gérer votre identité numérique, participer à une économie décentralisée en utilisant la cryptomonnaie Ğ1 (June), et contribuer à un réseau mondial de stations interconnectées.

**Voyez Astroport.ONE comme :**

*   **Votre Havre de Données Personnel :** Stockez et gérez vos données en toute sécurité grâce au système de fichiers interplanétaire (IPFS), garantissant ainsi qu'elles résistent à la censure et qu'elles sont toujours accessibles.
*   **Un Système de Paiement Sans Commission :** Utilisez la cryptomonnaie Ğ1 (June) pour des transactions pair-à-pair sans intermédiaires ni frais, favorisant une économie juste et équitable.
*   **Un Constructeur de Communauté Numérique :** Connectez-vous avec d'autres Stations Astroport.ONE et utilisateurs à travers le monde, partageant des informations, des ressources, et construisant des réseaux basés sur la confiance.
*   **Un "Guide de Construction" pour le Web Décentralisé :** Tirez parti de nos outils et logiciels open-source pour créer et déployer vos propres applications et services Web3.

**Fonctionnalités Principales en un Coup d'Œil :**

*   **ZenCard & AstroID :** Système de paiement simple et sécurisé basé sur QRCode (**ZenCard**) et une solution d'identité numérique robuste (**AstroID**).
*   **Stockage Décentralisé avec IPFS :** Utilisation d'IPFS pour un stockage de données distribué, résilient et résistant à la censure.
*   **Intégration de la Cryptomonnaie Ğ1 (June) :** Permet des transactions sans commission et une participation à une économie alternative dynamique.
*   **Système de Vœux :** Financez collaborativement des idées, des projets et des initiatives communautaires grâce à des dons en Ğ1, encourageant l'action collective.
*   **Réseau de Stations & Carte :** Chaque installation Astroport.ONE devient une **Station**, contribuant à une carte et un réseau mondiaux, facilitant la découverte et la connexion.
*   **AstroBots :** Contrats intelligents en BASH déclenchés par des "G1Tag", permettant des contrats intelligents et des applications décentralisées.

**À Qui s'Adresse Astroport.ONE ?**

*   **Aux individus recherchant la souveraineté numérique :** Reprenez le contrôle de vos données et de votre présence en ligne.
*   **Aux communautés construisant des solutions décentralisées :** Créez et gérez des ressources partagées et des projets collaboratifs.
*   **Aux développeurs et innovateurs :** Explorez le potentiel du Web3 et construisez des applications décentralisées sur une plateforme robuste.
*   **Aux utilisateurs de la cryptomonnaie Ğ1 (June) :** Améliorez votre expérience Ğ1 avec des paiements sécurisés et un écosystème florissant.
*   **À toute personne intéressée par un monde numérique plus libre, plus sûr et plus interconnecté.**

**Démarrez avec Astroport.ONE :**

**Installation (Linux - Debian/Ubuntu/Mint) :**

Configurer votre Station Astroport.ONE est facile grâce à notre script d'installation automatisé :


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
