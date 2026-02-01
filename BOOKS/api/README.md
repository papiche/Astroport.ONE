# API (Legacy v1, port 1234 deprecated)

Auth et profils : UPassport (54321), NOSTR. Les scripts `/API` fournissent des fonctionnalités legacy : joueurs, zones, clés, QR codes.

#### 1. `PLAYER.sh`

Ce script gère les interactions avec les joueurs, en particulier les opérations liées aux TiddlyWikis (TW) des joueurs.

**Fonctionnalités Principales :**

* **Exportation de Tiddlers** : Permet d'exporter des tiddlers spécifiques tagués avec un certain mot-clé.
* **Gestion des @PASS** : (Commenté) Création de passes pour les joueurs.
* **Ajout de Médias** : (Commenté) Ajout de vidéos YouTube, PDF, ou images au TW du joueur.

**Exemple de Commande :**

```bash
GET /?player=PLAYER&moa=json&tag=FILTER
```

#### 2. `DRAGONS.sh`

Ce script est utilisé pour détecter les stations UPLANET en cours d'exécution et récupérer leurs coordonnées GPS.

**Fonctionnalités Principales :**

* **Détection des Stations** : Recherche des stations UPLANET en cours d'exécution et collecte leurs coordonnées GPS.
* **Retour des Données en JSON** : Retourne les données des stations détectées au format JSON.

**Exemple de Commande :**

```bash
GET /?dragons
```

#### 3. `ZONE.sh`

Recherche de joueurs dans une zone géographique (lat/lon), retour JSON.

**Exemple de Commande :**

```bash
GET /?zone=DEG&ulat=LAT&ulon=LON
```

#### 4. `UPLANET.sh`

Ce script est dédié aux applications OSM2IPFS et UPlanet Client App. Il gère les atterrissages UPLANET et la création de ZenCards et AstroIDs.

**Fonctionnalités Principales :**

* **Gestion des Atterrissages UPLANET** : Vérifie et enregistre les coordonnées géographiques des joueurs.
* **Création de ZenCards et AstroIDs** : Génère des ZenCards et des AstroIDs pour les joueurs.

**Exemple de Commande :**

```bash
GET /?uplanet=EMAIL&zlat=LAT&zlon=LON&g1pub=PASS
```

#### 5. `QRCODE.sh`

Ce script gère les opérations liées aux QR codes, y compris les redirections HTTP et les opérations multi-clés.

**Fonctionnalités Principales :**

* **Redirection HTTP** : Redirige les liens HTTP encodés dans les QR codes.
* **Opérations Multi-Clés** : Gère les opérations liées aux clés PGP, G1Milgram, et autres.

**Exemple de Commande :**

```bash
GET /?qrcode=URLENCODEDSTRING&logo=IMAGE
```

#### 6. `SALT.sh`

Ce script gère les opérations d'authentification par clé privée en utilisant les paramètres `salt` et `pepper`.

**Fonctionnalités Principales :**

* **Génération de Clés** : Génère des clés à partir des paramètres `salt` et `pepper`.
* **Messagerie** : Extrait les messages de Gchange+ pour un utilisateur donné.

**Exemple de Commande :**

```bash
GET /?salt=SALT&pepper=PEPPER&APPNAME=messaging
```

####
