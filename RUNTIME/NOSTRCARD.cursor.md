# Décrire le script make_NOSTRCARD.sh
_Exported on 28/07/2025 at 21:05:27 UTC+2 from Cursor (1.2.4)_

---

**User**

@make_NOSTRCARD.sh décirs ce que fait ce script
Avec en détail les fichiers crées et leur signification

---

**Cursor**

Je vais analyser ce script qui crée une identité NOSTR complète avec un système cryptographique décentralisé.

## Description générale du script `make_NOSTRCARD.sh`

Ce script génère une **identité numérique décentralisée complète** basée sur le protocole NOSTR avec intégration multi-blockchain. Il crée un "passeport numérique" sécurisé à partir d'une simple adresse email.

## Fonctionnalités principales

1. **Génération d'identité NOSTR** : Clés publiques/privées pour le réseau social décentralisé
2. **Portefeuille multi-blockchain** : Bitcoin, Monero, G1/Duniter
3. **Stockage IPFS/IPNS** : Espace de stockage décentralisé personnel
4. **Sécurité cryptographique** : Partage de secret (SSSS), chiffrement asymétrique
5. **Interface utilisateur** : QR codes, profils, applications web

## Fichiers créés et leur signification

### 1. Fichiers temporaires (dans `~/.zen/tmp/${MOATS}/`)

```bash
# Partage de secret Shamir (SSSS)
${EMAIL}.ssss           # Secret partagé complet (3 parts, 2 nécessaires)
${EMAIL}.ssss.head      # Partie 1 du secret
${EMAIL}.ssss.mid       # Partie 2 du secret  
${EMAIL}.ssss.tail      # Partie 3 du secret

# Clés NOSTR
${EMAIL}.nostr.priv     # Clé privée NOSTR (nsec...)
${EMAIL}.nostr.pub      # Clé publique NOSTR (npub...)

# Clé G1/Duniter
${EMAIL}.g1card.dunikey # Portefeuille G1 (format Cesium)

# Clé IPFS
${MOATS}.nostr.ipns     # Clé IPNS pour stockage décentralisé

# QR Code temporaire
${EMAIL}.QR.png         # QR de récupération (SSSS + IPNS)
```

### 2. Fichiers persistants (dans `~/.zen/game/nostr/${EMAIL}/`)

#### **Identité et clés**
```bash
HEX                     # Clé publique NOSTR en format hexadécimal
NPUB                    # Clé publique NOSTR (npub1...)
G1PUBNOSTR             # Clé publique G1/Duniter
LANG                   # Langue de l'utilisateur (fr, en, etc.)
```

#### **Portefeuilles crypto**
```bash
BITCOIN                # Adresse Bitcoin dérivée
MONERO                 # Adresse Monero dérivée
```

#### **Stockage et accès**
```bash
NOSTRNS                # Adresse IPNS (/ipns/...)
.secret.disco          # Graine de dérivation (SALT+PEPPER) - SENSIBLE
```

#### **Métadonnées**
```bash
TODATE                 # Timestamp de création
ZUMAP                  # Coordonnées géographiques (_LAT_LON)
GPS                    # Coordonnées GPS (format JavaScript)
```

#### **QR Codes et images**
```bash
G1PUBNOSTR.QR.png      # QR code de la clé publique G1 (profil)
G1PUBNOSTR.QR.png.cid  # CID IPFS du QR code
IPNS.QR.png           # QR code d'accès au stockage IPNS
uSPOT.QR.png          # QR code d'accès au service uSPOT
scan_${MOATS}.png     # Photo de profil (si fournie)
```

#### **Secrets chiffrés (Sécurité distribuée)**
```bash
.ssss.head.player.enc     # Partie 1 du secret chiffrée avec la clé du joueur
.ssss.mid.captain.enc     # Partie 2 du secret chiffrée avec la clé du capitaine
ssss.tail.uplanet.enc     # Partie 3 du secret chiffrée avec la clé UPlanet
```

#### **Interface web**
```bash
.nostr.zine.html         # Page web personnelle avec toutes les infos
```

### 3. Applications décentralisées (dans `APP/`)

#### **uDRIVE** (Stockage décentralisé)
```bash
APP/uDRIVE/Apps/CESIUM.v1.html    # Lien vers portefeuille Cesium
APP/uDRIVE/generate_ipfs_structure.sh  # Générateur de structure IPFS
APP/uDRIVE/index.html             # Page d'accueil uDRIVE
```

#### **uWORLD** (Monde virtuel)
```bash
APP/uWORLD/generate_ipfs_RPG.sh   # Générateur de monde RPG
APP/uWORLD/index.html             # Point d'entrée uWORLD
```

## Sécurité cryptographique

### **Schéma de partage de secret (SSSS)**
Le secret principal (`DISCO`) est divisé en 3 parts :
- **Partie 1** : Chiffrée pour le joueur (récupération personnelle)
- **Partie 2** : Chiffrée pour le capitaine (réseau social)
- **Partie 3** : Chiffrée pour UPlanet (infrastructure)

**Avantage** : Il faut 2 des 3 parties pour reconstituer l'identité complète.

### **Dérivation déterministe**
Toutes les clés sont dérivées de `SALT + PEPPER + EMAIL` :
- Même graine → Même identité complète
- Récupération possible avec les paramètres

## Actions réseau

1. **Publication NOSTR** : Profil et message sur les relais
2. **Publication IPNS** : Contenu sur le réseau IPFS
3. **Enregistrement Cesium** : Profil G1/Duniter
4. **Création d'applications** : uDRIVE et uWORLD

## Sortie finale

Le script retourne le chemin vers `.nostr.zine.html` qui contient :
- Toutes les informations de l'identité
- Les QR codes d'accès
- Les liens vers les applications
- L'interface complète de gestion

Ce système crée une **identité numérique souveraine** complète, auto-hébergée et interopérable entre plusieurs blockchains et réseaux décentralisés.

```shellscript
# Partage de secret Shamir (SSSS)
${EMAIL}.ssss           # Secret partagé complet (3 parts, 2 nécessaires)
${EMAIL}.ssss.head      # Partie 1 du secret
${EMAIL}.ssss.mid       # Partie 2 du secret  
${EMAIL}.ssss.tail      # Partie 3 du secret

# Clés NOSTR
${EMAIL}.nostr.priv     # Clé privée NOSTR (nsec...)
${EMAIL}.nostr.pub      # Clé publique NOSTR (npub...)

# Clé G1/Duniter
${EMAIL}.g1card.dunikey # Portefeuille G1 (format Cesium)

# Clé IPFS
${MOATS}.nostr.ipns     # Clé IPNS pour stockage décentralisé

# QR Code temporaire
${EMAIL}.QR.png         # QR de récupération (SSSS + IPNS)
```

```shellscript
HEX                     # Clé publique NOSTR en format hexadécimal
NPUB                    # Clé publique NOSTR (npub1...)
G1PUBNOSTR             # Clé publique G1/Duniter
LANG                   # Langue de l'utilisateur (fr, en, etc.)
```

```shellscript
BITCOIN                # Adresse Bitcoin dérivée
MONERO                 # Adresse Monero dérivée
```

```shellscript
NOSTRNS                # Adresse IPNS (/ipns/...)
.secret.disco          # Graine de dérivation (SALT+PEPPER) - SENSIBLE
```

```shellscript
TODATE                 # Timestamp de création
ZUMAP                  # Coordonnées géographiques (_LAT_LON)
GPS                    # Coordonnées GPS (format JavaScript)
```

```shellscript
G1PUBNOSTR.QR.png      # QR code de la clé publique G1 (profil)
G1PUBNOSTR.QR.png.cid  # CID IPFS du QR code
IPNS.QR.png           # QR code d'accès au stockage IPNS
uSPOT.QR.png          # QR code d'accès au service uSPOT
scan_${MOATS}.png     # Photo de profil (si fournie)
```

```shellscript
.ssss.head.player.enc     # Partie 1 du secret chiffrée avec la clé du joueur
.ssss.mid.captain.enc     # Partie 2 du secret chiffrée avec la clé du capitaine
ssss.tail.uplanet.enc     # Partie 3 du secret chiffrée avec la clé UPlanet
```

```shellscript
.nostr.zine.html         # Page web personnelle avec toutes les infos
```

```shellscript
APP/uDRIVE/Apps/CESIUM.v1.html    # Lien vers portefeuille Cesium
APP/uDRIVE/generate_ipfs_structure.sh  # Générateur de structure IPFS
APP/uDRIVE/index.html             # Page d'accueil uDRIVE
```

```shellscript
APP/uWORLD/generate_ipfs_RPG.sh   # Générateur de monde RPG
APP/uWORLD/index.html             # Point d'entrée uWORLD
```

---

**User**

@https://ipfs.copylaradio.com/ipns/copylaradio.com/ est l'interface du réseau UPlanet qui déclenche make_NOSTRCARD.sh

L'utilisateur reçoit un MULTIPASS  .nostr.zine.html au format Zine (à imprimer) (modèle@nostr.html)

il contient les infos installer NOSTR connect à son navigateur, y recopier la nsec pour se connecter à https://coracle.copylaradio.com




---

**Cursor**

Merci pour ces informations contextuelles ! Cela clarifie parfaitement le flux utilisateur et l'écosystème UPlanet. Voici le processus complet :

## Flux utilisateur UPlanet → MULTIPASS

### 1. Point d'entrée : Interface UPlanet
L'utilisateur accède à [https://ipfs.copylaradio.com/ipns/copylaradio.com/](https://ipfs.copylaradio.com/ipns/copylaradio.com/) qui présente :
- L'interface UPlanet avec les outils essentiels
- Les extensions NOSTR recommandées (NOSTR Connect, nos2x-fox)
- Le guide de configuration Web3

### 2. Déclenchement de `make_NOSTRCARD.sh`
Depuis cette interface, l'utilisateur peut demander la création de son identité décentralisée, ce qui déclenche le script `make_NOSTRCARD.sh`.

### 3. Génération du MULTIPASS Zine
Le script génère le fichier `.nostr.zine.html` basé sur le template `nostr.html`, créant un **Zine imprimable** (format A4 paysage, 8 pages) contenant :

## Contenu du MULTIPASS Zine (8 pages)

### **Page 1 - Couverture**
- Identité email de l'utilisateur
- Lien vers le vault IPNS
- Bouton d'impression

### **Page 2 - Instructions MULTIPASS**
- **QR code uSPOT/scan** pour accès mobile
- **Instructions d'installation** :
  1. Installer NOSTR Connect (Firefox) ou nos2x-fox
  2. Copier la clé privée NSec
  3. Se connecter à [Coracle Ẑen](https://coracle.copylaradio.com)

### **Page 3 - ẐEN Wallet**
- **SALT et PEPPER** (graines cryptographiques)
- **QR code G1 Wallet** pour Cesium
- **Clé publique G1** (portefeuille Duniter)

### **Page 4 - UPlanet Géolocalisation**
- Lien vers le **wallet UPlanet** local
- **Coordonnées GPS** et zone géographique
- Informations du **Capitaine local**

### **Page 5 - APP/uDRIVE**
- **QR code d'accès** au stockage IPNS
- **Applications décentralisées** disponibles
- Date de création

### **Page 6 - Services ẐEN**
- **♥BOX** (réseau de confiance)
- **Offres MULTIPASS** et ZENCARD
- Liens vers [Open Collective](https://opencollective.com/uplanet-zero)

### **Page 7 - QR Code SCAN**
- **Grand QR code SSSS** pour récupération d'urgence
- Accès au système de scan UPlanet

### **Page 8 - Ğ1FabLab**
- Informations communautaires
- QR code Open Collective
- Gouvernance DU²

## Utilisation du MULTIPASS

### **Format Zine imprimable**
- **8 pages A4 paysage** optimisées pour l'impression
- **Pliage en livret** pour format de poche
- **QR codes haute résolution** pour lecture mobile/webcam

### **Processus d'activation**
1. **Imprimer le Zine** complet
2. **Scanner le QR uSPOT** (page 2) avec le smartphone
3. **Installer NOSTR Connect** dans Firefox
4. **Copier la NSec** (page 2) dans l'extension
5. **Se connecter à Coracle** pour accéder au réseau social NOSTR
6. **Scanner les autres QR codes** selon les besoins (wallet, stockage)

### **Sécurité distribuée**
- **Zine physique** = backup permanent des accès
- **QR codes SSSS** = récupération possible même si 1/3 des clés est perdu
- **Chiffrement distribué** entre joueur/capitaine/UPlanet

## Écosystème UPlanet

Le MULTIPASS constitue la **carte d'identité numérique souveraine** permettant d'accéder à :
- **Réseau social NOSTR** décentralisé
- **Portefeuilles crypto** (G1, Bitcoin, Monero)
- **Stockage IPFS/IPNS** personnel
- **Applications Web3** (uDRIVE, uWORLD)
- **Services géolocalisés** UPlanet
- **Économie locale** Ğ1

Ce système révolutionnaire transforme une simple **adresse email en identité numérique complète**, auto-hébergée et interopérable, accessible via un **support physique imprimable** !

---

**User**

@NOSTRCARD.refresh.sh scute les MULTIPASS 
décris ce que fait ce script
avec en détail les manupulation sur les fichiers, les actions et leur signification

---

**Cursor**

Je vais analyser ce script de gestion centrale des cartes MULTIPASS dans l'écosystème UPlanet.

## Description générale de `NOSTRCARD.refresh.sh`

Ce script est le **cœur du système de gestion des identités MULTIPASS**. Il s'exécute en continu pour surveiller, mettre à jour et faire évoluer les cartes NOSTR selon leur état et leurs transactions.

## Fonctionnalités principales

### 1. **Gestion des cycles de vie MULTIPASS**
- Surveillance des comptes NOSTR créés
- Évolution selon le type de PRIMAL (source des fonds)
- Gestion des paiements hebdomadaires automatiques
- Activation/désactivation selon les soldes

### 2. **Système de paiement cyclique (7 jours)**
- Vérification des cycles de paiement hebdomadaires
- Collecte automatique des frais de service
- Distribution des bénéfices au réseau

### 3. **Évolution des comptes**
- **PRIMAL = UPlanet wallet** → Compte UPlanet ORIGIN
- **PRIMAL = Membre G1** → Compte UPlanet ZEN avec UPassport N1
- Création automatique de ZenCard pour les comptes ZEN

## Analyse détaillée des actions

### **Phase 1 : Initialisation et scan**

#### **Fichiers manipulés en Phase 1 :**
```bash
# Protection anti-collision
/tmp/nostrcard_refresh.lock                    # Fichier de verrou PID

# Répertoires de travail
~/.zen/tmp/${MOATS}/                          # Dossier temporaire timestampé

# Fichiers de synchronisation par joueur
~/.zen/game/nostr/${PLAYER}/.refresh_time     # Heure de rafraîchissement aléatoire
~/.zen/game/nostr/${PLAYER}/.todate          # Dernière date de mise à jour
~/.zen/game/nostr/${PLAYER}/.last_ipns_update # Timestamp dernière publication IPNS
~/.zen/game/nostr/${PLAYER}/.lastpayment     # Date du dernier paiement
```

### **Phase 2 : Scan et évaluation des comptes**

```shellscript
# Protection anti-collision
/tmp/nostrcard_refresh.lock                    # Fichier de verrou PID

# Répertoires de travail
~/.zen/tmp/${MOATS}/                          # Dossier temporaire timestampé

# Fichiers de synchronisation par joueur
~/.zen/game/nostr/${PLAYER}/.refresh_time     # Heure de rafraîchissement aléatoire
~/.zen/game/nostr/${PLAYER}/.todate          # Dernière date de mise à jour
~/.zen/game/nostr/${PLAYER}/.last_ipns_update # Timestamp dernière publication IPNS
~/.zen/game/nostr/${PLAYER}/.lastpayment     # Date du dernier paiement
```

#### **Fichiers manipulés par joueur :**
```bash
# Identité NOSTR
~/.zen/game/nostr/${PLAYER}/HEX              # Clé publique hex
~/.zen/game/nostr/${PLAYER}/NPUB             # Clé publique NOSTR
~/.zen/game/nostr/${PLAYER}/G1PUBNOSTR       # Clé publique G1

# Cache pour propagation réseau
~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/HEX    # Cache hex pour swarm
~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/GPS    # Cache GPS pour swarm
~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/NPUB   # Cache NPUB pour swarm

# Applications décentralisées
~/.zen/game/nostr/${PLAYER}/APP/uDRIVE/      # Stockage décentralisé
~/.zen/game/nostr/${PLAYER}/APP/uWORLD/      # Monde virtuel RPG
~/.zen/game/nostr/${PLAYER}/.udrive          # CID uDRIVE actuel
~/.zen/game/nostr/${PLAYER}/.uworld          # CID uWORLD actuel
```

### **Phase 3 : Vérification des soldes et transactions PRIMAL**

```shellscript
# Identité NOSTR
~/.zen/game/nostr/${PLAYER}/HEX              # Clé publique hex
~/.zen/game/nostr/${PLAYER}/NPUB             # Clé publique NOSTR
~/.zen/game/nostr/${PLAYER}/G1PUBNOSTR       # Clé publique G1

# Cache pour propagation réseau
~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/HEX    # Cache hex pour swarm
~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/GPS    # Cache GPS pour swarm
~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/NPUB   # Cache NPUB pour swarm

# Applications décentralisées
~/.zen/game/nostr/${PLAYER}/APP/uDRIVE/      # Stockage décentralisé
~/.zen/game/nostr/${PLAYER}/APP/uWORLD/      # Monde virtuel RPG
~/.zen/game/nostr/${PLAYER}/.udrive          # CID uDRIVE actuel
~/.zen/game/nostr/${PLAYER}/.uworld          # CID uWORLD actuel
```

```shellscript
# Identité NOSTR
~/.zen/game/nostr/${PLAYER}/HEX              # Clé publique hex
~/.zen/game/nostr/${PLAYER}/NPUB             # Clé publique NOSTR
~/.zen/game/nostr/${PLAYER}/G1PUBNOSTR       # Clé publique G1

# Cache pour propagation réseau
~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/HEX    # Cache hex pour swarm
~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/GPS    # Cache GPS pour swarm
~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/NPUB   # Cache NPUB pour swarm

# Applications décentralisées
~/.zen/game/nostr/${PLAYER}/APP/uDRIVE/      # Stockage décentralisé
~/.zen/game/nostr/${PLAYER}/APP/uWORLD/      # Monde virtuel RPG
~/.zen/game/nostr/${PLAYER}/.udrive          # CID uDRIVE actuel
~/.zen/game/nostr/${PLAYER}/.uworld          # CID uWORLD actuel
```

#### **Fichiers de cache et vérification :**
```bash
# Cache des soldes et transactions
~/.zen/tmp/coucou/${G1PUBNOSTR}.COINS        # Solde G1 en cache
~/.zen/tmp/coucou/${G1PUBNOSTR}.primal       # Source PRIMAL en cache
~/.zen/tmp/coucou/${primal}.COINS            # Solde du portefeuille PRIMAL

# Propagation réseau
~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/G1PUBNOSTR  # Cache G1PUB pour swarm
```

### **Phase 4 : Déchiffrement SSSS et reconstruction de l'identité**

```shellscript
# Cache des soldes et transactions
~/.zen/tmp/coucou/${G1PUBNOSTR}.COINS        # Solde G1 en cache
~/.zen/tmp/coucou/${G1PUBNOSTR}.primal       # Source PRIMAL en cache
~/.zen/tmp/coucou/${primal}.COINS            # Solde du portefeuille PRIMAL

# Propagation réseau
~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/G1PUBNOSTR  # Cache G1PUB pour swarm
```

```shellscript
# Cache des soldes et transactions
~/.zen/tmp/coucou/${G1PUBNOSTR}.COINS        # Solde G1 en cache
~/.zen/tmp/coucou/${G1PUBNOSTR}.primal       # Source PRIMAL en cache
~/.zen/tmp/coucou/${primal}.COINS            # Solde du portefeuille PRIMAL

# Propagation réseau
~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/G1PUBNOSTR  # Cache G1PUB pour swarm
```

#### **Déchiffrement sécurisé SSSS :**
```bash
# Parties chiffrées du secret
~/.zen/game/nostr/${PLAYER}/.ssss.mid.captain.enc    # Partie 2 (Captain)
~/.zen/game/nostr/${PLAYER}/ssss.tail.uplanet.enc    # Partie 3 (UPlanet)

# Clés de déchiffrement
~/.zen/game/players/.current/secret.dunikey          # Clé du Captain
~/.zen/game/uplanet.dunikey                          # Clé UPlanet

# Secrets reconstitués
~/.zen/game/nostr/${PLAYER}/.secret.disco            # DISCO complet (SALT+PEPPER)
~/.zen/game/nostr/${PLAYER}/.secret.nostr            # Clés NOSTR dérivées
~/.zen/game/nostr/${PLAYER}/.secret.dunikey          # Clé Duniter dérivée

# Diagnostic
~/.zen/game/nostr/${PLAYER}/ERROR                    # Erreurs de déchiffrement
```

### **Phase 5 : Gestion des paiements cycliques (7 jours)**

```shellscript
# Parties chiffrées du secret
~/.zen/game/nostr/${PLAYER}/.ssss.mid.captain.enc    # Partie 2 (Captain)
~/.zen/game/nostr/${PLAYER}/ssss.tail.uplanet.enc    # Partie 3 (UPlanet)

# Clés de déchiffrement
~/.zen/game/players/.current/secret.dunikey          # Clé du Captain
~/.zen/game/uplanet.dunikey                          # Clé UPlanet

# Secrets reconstitués
~/.zen/game/nostr/${PLAYER}/.secret.disco            # DISCO complet (SALT+PEPPER)
~/.zen/game/nostr/${PLAYER}/.secret.nostr            # Clés NOSTR dérivées
~/.zen/game/nostr/${PLAYER}/.secret.dunikey          # Clé Duniter dérivée

# Diagnostic
~/.zen/game/nostr/${PLAYER}/ERROR                    # Erreurs de déchiffrement
```

```shellscript
# Parties chiffrées du secret
~/.zen/game/nostr/${PLAYER}/.ssss.mid.captain.enc    # Partie 2 (Captain)
~/.zen/game/nostr/${PLAYER}/ssss.tail.uplanet.enc    # Partie 3 (UPlanet)

# Clés de déchiffrement
~/.zen/game/players/.current/secret.dunikey          # Clé du Captain
~/.zen/game/uplanet.dunikey                          # Clé UPlanet

# Secrets reconstitués
~/.zen/game/nostr/${PLAYER}/.secret.disco            # DISCO complet (SALT+PEPPER)
~/.zen/game/nostr/${PLAYER}/.secret.nostr            # Clés NOSTR dérivées
~/.zen/game/nostr/${PLAYER}/.secret.dunikey          # Clé Duniter dérivée

# Diagnostic
~/.zen/game/nostr/${PLAYER}/ERROR                    # Erreurs de déchiffrement
```

#### **Système de paiement automatique :**
```bash
# Fichiers de suivi des paiements
~/.zen/game/nostr/${PLAYER}/.lastpayment     # Date du dernier paiement
~/.zen/game/nostr/${PLAYER}/TODATE           # Date de naissance du compte

# Statut spécial U.SOCIETY
~/.zen/game/players/${PLAYER}/U.SOCIETY      # Membre société coopérative
~/.zen/game/nostr/${PLAYER}/U.SOCIETY        # Copie du statut

# Actions de paiement
PAYforSURE.sh                               # Transaction G1 sécurisée
nostr_DESTROY_TW.sh                         # Destruction si fonds insuffisants
```

### **Phase 6 : Gestion des profils PRIMAL et UPassport**

```shellscript
# Fichiers de suivi des paiements
~/.zen/game/nostr/${PLAYER}/.lastpayment     # Date du dernier paiement
~/.zen/game/nostr/${PLAYER}/TODATE           # Date de naissance du compte

# Statut spécial U.SOCIETY
~/.zen/game/players/${PLAYER}/U.SOCIETY      # Membre société coopérative
~/.zen/game/nostr/${PLAYER}/U.SOCIETY        # Copie du statut

# Actions de paiement
PAYforSURE.sh                               # Transaction G1 sécurisée
nostr_DESTROY_TW.sh                         # Destruction si fonds insuffisants
```

```shellscript
# Fichiers de suivi des paiements
~/.zen/game/nostr/${PLAYER}/.lastpayment     # Date du dernier paiement
~/.zen/game/nostr/${PLAYER}/TODATE           # Date de naissance du compte

# Statut spécial U.SOCIETY
~/.zen/game/players/${PLAYER}/U.SOCIETY      # Membre société coopérative
~/.zen/game/nostr/${PLAYER}/U.SOCIETY        # Copie du statut

# Actions de paiement
PAYforSURE.sh                               # Transaction G1 sécurisée
nostr_DESTROY_TW.sh                         # Destruction si fonds insuffisants
```

#### **Gestion des profils PRIMAL :**
```bash
# Validation et métadonnées PRIMAL
~/.zen/game/nostr/${PLAYER}/G1PRIME           # Clé publique PRIMAL validée
~/.zen/game/nostr/${PLAYER}/PRIMAL/            # Dossier métadonnées PRIMAL

# UPassport (si membre G1)
~/.zen/game/nostr/${PLAYER}/PRIMAL/_upassport.html     # Interface UPassport
~/.zen/game/nostr/${PLAYER}/PRIMAL/N1/                 # Réseau de confiance N1
~/.zen/game/nostr/${PLAYER}/PRIMAL/N1/manifest.json    # Relations P2P/P21/12P

# Cache Cesium+
~/.zen/game/nostr/${PLAYER}/PRIMAL/${primal}.cesium.json  # Profil Cesium
~/.zen/game/nostr/${PLAYER}/PRIMAL/${G1PUB}.txt           # Messages envoyés

# UPassport officiel (si station)
~/.zen/game/passport/${primal}                # UPassport PDF officiel
```

### **Phase 7 : Création des profils NOSTR**

```shellscript
# Validation et métadonnées PRIMAL
~/.zen/game/nostr/${PLAYER}/G1PRIME           # Clé publique PRIMAL validée
~/.zen/game/nostr/${PLAYER}/PRIMAL/            # Dossier métadonnées PRIMAL

# UPassport (si membre G1)
~/.zen/game/nostr/${PLAYER}/PRIMAL/_upassport.html     # Interface UPassport
~/.zen/game/nostr/${PLAYER}/PRIMAL/N1/                 # Réseau de confiance N1
~/.zen/game/nostr/${PLAYER}/PRIMAL/N1/manifest.json    # Relations P2P/P21/12P

# Cache Cesium+
~/.zen/game/nostr/${PLAYER}/PRIMAL/${primal}.cesium.json  # Profil Cesium
~/.zen/game/nostr/${PLAYER}/PRIMAL/${G1PUB}.txt           # Messages envoyés

# UPassport officiel (si station)
~/.zen/game/passport/${primal}                # UPassport PDF officiel
```

```shellscript
# Validation et métadonnées PRIMAL
~/.zen/game/nostr/${PLAYER}/G1PRIME           # Clé publique PRIMAL validée
~/.zen/game/nostr/${PLAYER}/PRIMAL/            # Dossier métadonnées PRIMAL

# UPassport (si membre G1)
~/.zen/game/nostr/${PLAYER}/PRIMAL/_upassport.html     # Interface UPassport
~/.zen/game/nostr/${PLAYER}/PRIMAL/N1/                 # Réseau de confiance N1
~/.zen/game/nostr/${PLAYER}/PRIMAL/N1/manifest.json    # Relations P2P/P21/12P

# Cache Cesium+
~/.zen/game/nostr/${PLAYER}/PRIMAL/${primal}.cesium.json  # Profil Cesium
~/.zen/game/nostr/${PLAYER}/PRIMAL/${G1PUB}.txt           # Messages envoyés

# UPassport officiel (si station)
~/.zen/game/passport/${primal}                # UPassport PDF officiel
```

#### **Création des profils NOSTR :**
```bash
# Métadonnées extraites de Cesium+
~/.zen/game/nostr/${PLAYER}/PRIMAL/${primal}.cesium.json  # Profil source
~/.zen/tmp/coucou/${G1PUB}.cesium.avatar.png             # Avatar Cesium

# Profil NOSTR créé
~/.zen/game/nostr/${PLAYER}/nostr_setup_profile          # Confirmation création
~/.zen/game/nostr/${PLAYER}/GPS                          # Coordonnées GPS

# Publication sur relais
nostr_setup_profile.py                                   # Outil de publication
```

### **Phase 8 : Évolution des comptes (ZenCard vs ORIGIN)**

```shellscript
# Métadonnées extraites de Cesium+
~/.zen/game/nostr/${PLAYER}/PRIMAL/${primal}.cesium.json  # Profil source
~/.zen/tmp/coucou/${G1PUB}.cesium.avatar.png             # Avatar Cesium

# Profil NOSTR créé
~/.zen/game/nostr/${PLAYER}/nostr_setup_profile          # Confirmation création
~/.zen/game/nostr/${PLAYER}/GPS                          # Coordonnées GPS

# Publication sur relais
nostr_setup_profile.py                                   # Outil de publication
```

```shellscript
# Métadonnées extraites de Cesium+
~/.zen/game/nostr/${PLAYER}/PRIMAL/${primal}.cesium.json  # Profil source
~/.zen/tmp/coucou/${G1PUB}.cesium.avatar.png             # Avatar Cesium

# Profil NOSTR créé
~/.zen/game/nostr/${PLAYER}/nostr_setup_profile          # Confirmation création
~/.zen/game/nostr/${PLAYER}/GPS                          # Coordonnées GPS

# Publication sur relais
nostr_setup_profile.py                                   # Outil de publication
```

#### **Évolution des comptes :**
```bash
# ZenCard UPlanet ZEN (si pas ORIGIN)
~/.zen/game/players/${PLAYER}/                # Dossier ZenCard complet
VISA.new.sh                                   # Créateur de ZenCard

# Recherche et indexation
search_for_this_email_in_players.sh          # Index des ZenCards
search_for_this_email_in_nostr.sh            # Index des NOSTR Cards

# Contrôle des portefeuilles
primal_wallet_control.sh                     # Surveillance PRIMAL
```

### **Phase 9 : Mise à jour IPNS et finalisation**

```shellscript
# ZenCard UPlanet ZEN (si pas ORIGIN)
~/.zen/game/players/${PLAYER}/                # Dossier ZenCard complet
VISA.new.sh                                   # Créateur de ZenCard

# Recherche et indexation
search_for_this_email_in_players.sh          # Index des ZenCards
search_for_this_email_in_nostr.sh            # Index des NOSTR Cards

# Contrôle des portefeuilles
primal_wallet_control.sh                     # Surveillance PRIMAL
```

```shellscript
# ZenCard UPlanet ZEN (si pas ORIGIN)
~/.zen/game/players/${PLAYER}/                # Dossier ZenCard complet
VISA.new.sh                                   # Créateur de ZenCard

# Recherche et indexation
search_for_this_email_in_players.sh          # Index des ZenCards
search_for_this_email_in_nostr.sh            # Index des NOSTR Cards

# Contrôle des portefeuilles
primal_wallet_control.sh                     # Surveillance PRIMAL
```

#### **Mise à jour IPNS finale :**
```bash
# Publication IPNS
~/.zen/game/nostr/${PLAYER}/.secret.ipns      # Clé IPNS privée
ipfs add -rwq                                  # Ajout récursif IPFS
ipfs name publish                              # Publication IPNS

# Tracking des mises à jour
~/.zen/game/nostr/${PLAYER}/.last_ipns_update # Timestamp dernière publication
~/.zen/game/nostr/${PLAYER}/.todate           # Date de dernière mise à jour quotidienne

# Nettoyage
~/.zen/tmp/${MOATS}/                          # Suppression dossier temporaire
/tmp/nostrcard_refresh.lock                   # Suppression verrou
```

## Résumé des actions du script

### **🔄 Cycle de gestion automatique**

#### **Fréquence d'exécution**
- **Déclenchement** : Exécution continue (probablement via cron)
- **Rafraîchissement quotidien** : Chaque compte à une heure aléatoire
- **Paiements hebdomadaires** : Tous les 7 jours (cycles)
- **Mise à jour IPNS** : À chaque modification de contenu

#### **Évolution des comptes MULTIPASS**

| Type PRIMAL | Évolution | Caractéristiques |
|-------------|-----------|------------------|
| **UPlanet wallet** | → UPlanet ORIGIN | Services de base |
| **Membre G1** | → UPlanet ZEN + ZenCard | UPassport N1, économie complète |
| **Station DU** | → Coopérateur | Propriétaire infrastructure |

### **💰 Système économique cyclique**

#### **Paiements automatiques (7 jours)**
1. **Calcul** : `(jours_depuis_naissance % 7) == 0`
2. **Montant** : `NCARD ẐEN` (variable selon services)
3. **Destination** : Captain UPlanet local
4. **Vérification** : Solde > 1 G1 requis
5. **Destruction** : Si fonds insuffisants

#### **Distribution des bénéfices**
- **Captain** : Reçoit les paiements MULTIPASS
- **UPlanet** : Frais de transaction
- **Réseau** : Financement infrastructure décentralisée

### **🔐 Sécurité distribuée SSSS**

#### **Déchiffrement à 3 parties**
1. **Partie joueur** : Auto-déchiffrable (récupération personnelle)
2. **Partie Captain** : Déchiffrée avec clé Captain local
3. **Partie UPlanet** : Déchiffrée avec clé infrastructure

#### **Reconstruction de l'identité**
- **DISCO** = `/?email=${SALT}&nostr=${PEPPER}`
- **Toutes les clés dérivées** : NOSTR, G1, Bitcoin, Monero, IPFS
- **Seuil de sécurité** : 2 parties sur 3 nécessaires

### **📊 Surveillance et maintenance**

#### **Métriques collectées**
- Mises à jour quotidiennes effectuées
- Mises à jour de fichiers
- Paiements traités/échoués
- Comptes ignorés

#### **Actions correctives**
- Nettoyage des fichiers corrompus
- Validation format des clés G1
- Destruction des comptes impayés
- Notification par email (welcome, renouvellement)

Ce script constitue le **cœur intelligent** de l'écosystème UPlanet, gérant automatiquement l'évolution des identités numériques depuis leur création jusqu'à leur pleine intégration dans l'économie décentralisée. Il assure la **durabilité économique** du réseau tout en préservant la **souveraineté numérique** des utilisateurs.

```shellscript
# Publication IPNS
~/.zen/game/nostr/${PLAYER}/.secret.ipns      # Clé IPNS privée
ipfs add -rwq                                  # Ajout récursif IPFS
ipfs name publish                              # Publication IPNS

# Tracking des mises à jour
~/.zen/game/nostr/${PLAYER}/.last_ipns_update # Timestamp dernière publication
~/.zen/game/nostr/${PLAYER}/.todate           # Date de dernière mise à jour quotidienne

# Nettoyage
~/.zen/tmp/${MOATS}/                          # Suppression dossier temporaire
/tmp/nostrcard_refresh.lock                   # Suppression verrou
```

```shellscript
# Publication IPNS
~/.zen/game/nostr/${PLAYER}/.secret.ipns      # Clé IPNS privée
ipfs add -rwq                                  # Ajout récursif IPFS
ipfs name publish                              # Publication IPNS

# Tracking des mises à jour
~/.zen/game/nostr/${PLAYER}/.last_ipns_update # Timestamp dernière publication
~/.zen/game/nostr/${PLAYER}/.todate           # Date de dernière mise à jour quotidienne

# Nettoyage
~/.zen/tmp/${MOATS}/                          # Suppression dossier temporaire
/tmp/nostrcard_refresh.lock                   # Suppression verrou
```

