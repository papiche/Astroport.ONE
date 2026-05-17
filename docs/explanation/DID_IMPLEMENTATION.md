# Implémentation de l'Identité et des Autorisations Décentralisées dans l'écosystème UPlanet

## 1. Vue d'ensemble : Au-delà des standards, une souveraineté numérique incarnée

Ce document détaille notre approche de l'identité numérique décentralisée (DID) et des autorisations contrôlées par l'utilisateur (UCAN) au sein de l'écosystème UPlanet et Astroport.ONE.

Nous ne nous contentons pas de suivre les spécifications W3C ; nous les utilisons comme un tremplin pour construire un système de **souveraineté numérique** complet. Notre objectif est de transformer le concept d'identité numérique en une véritable **propriété numérique**, où chaque individu contrôle non seulement qui il est, mais aussi ce qu'il possède et les droits qu'il délègue.

### 🌱 Extension Environnementale : DIDs pour la Protection de la Terre

L'écosystème DID UPlanet s'étend au-delà de l'identité humaine pour inclure l'**identité environnementale** via le système ORE (Obligations Réelles Environnementales). Chaque cellule géographique UMAP (0.01° x 0.01°) peut obtenir son propre DID, créant un **cadastre écologique vivant et programmable**.

**Intégration ORE-DID :**
- **UMAP DIDs** : `did:nostr:{umap_hex}` pour chaque cellule géographique
- **Contrats Environnementaux** : Obligations ORE attachées aux DIDs UMAP
- **Vérification en Temps Réel** : Salles VDO.ninja liées aux DIDs pour la vérification
- **Récompenses Économiques** : Ẑen distribués depuis le portefeuille ASSETS coopératif

Pour plus de détails, voir [`ORE_SYSTEM.md`](./docs/ORE_SYSTEM.md).

### 🔐 Extension Oracle : Permis de Compétence WoT

Le système Oracle étend le Web of Trust (WoT) de l'**identité** vers la **compétence**. Basé sur le modèle du "permis de conduire" décrit dans l'[article CopyLaRadio](https://www.copylaradio.com/blog/blog-1/post/reinventer-la-societe-avec-la-monnaie-libre-et-la-web-of-trust-148#), il permet la certification décentralisée de compétences via des attestations multi-signatures.

**Intégration Oracle-DID :**
- **Permit Credentials** : Verifiable Credentials (VCs) émis après validation par pairs
- **Multi-Signature** : Validation par N experts certifiés (3-24 attestations selon le permit)
- **NOSTR Events** : Publication des demandes, attestations et credentials (kinds 30500-30503)
- **Récompenses Économiques** : Ẑen distribués depuis le portefeuille RnD coopératif
- **Types de Permis** : ORE Verifier, Driver's License, WoT Dragon, Medical, Artisan, etc.

Pour plus de détails, voir [`ORACLE_SYSTEM.md`](./docs/ORACLE_SYSTEM.md).

Le script `make_NOSTRCARD.sh` génère des documents DID conformes aux standards [W3C DID Core v1.1](https://www.w3.org/TR/did-core-1.1/) et [W3C DID Resolution v1.0](https://www.w3.org/TR/did-resolution/), mais va bien au-delà en créant un écosystème complet de **ZEN Cards** (identité) et de **MULTIPASS** (autorisations).

## Architecture des Scripts de Gestion

L'écosystème UPlanet repose sur une architecture de scripts spécialisés qui gèrent le cycle de vie complet des identités et des autorisations :

### Scripts de Création
- **`make_NOSTRCARD.sh`** : Fabrique les MULTIPASS avec documents DID complets
- **`VISA.new.sh`** : Fabrique les ZEN Card pour les sociétaires

### Scripts de Gestion Opérationnelle  
- **`NOSTRCARD.refresh.sh`** : Gère le cycle de vie des MULTIPASS (paiements, mises à jour, résumés d'activité)
- **`PLAYER.refresh.sh`** : Gère le cycle de vie des ZEN Card (paiements, services, intégrations)

### Scripts de Transaction Coopérative
- **`UPLANET.official.sh`** : Enregistre les transactions coopératives et met à jour les DID
- **`ZEN.ECONOMY.sh`** : Contrôle les virements automatiques de l'économie Ẑen
- **`ZEN.COOPERATIVE.3x1-3.sh`** : Gère la répartition coopérative des fonds

### Script de Gestion Centralisée des DID (Nostr-Native)
- **`did_manager_nostr.sh`** : Gestionnaire centralisé des documents DID avec Nostr comme source de vérité
- **`nostr_publish_did.py`** : Publie les DIDs sur les relais Nostr (kind 30800 - NIP-101)
- **`nostr_did_client.py`** : Client unifié pour lecture/fetch des DIDs depuis Nostr
- **`nostr_did_recall.sh`** : Script de migration des DIDs existants vers Nostr

### Scripts d'Extension Environnementale (ORE)
- **`ore_system.py`** : Système complet de gestion des Obligations Réelles Environnementales
- **`ore_complete_test.sh`** : Tests et démonstrations du système ORE intégré
- **`NOSTR.UMAP.refresh.sh`** : Intégration ORE dans le traitement des cellules UMAP
- **`UPLANET.official.sh`** : Virements ORE depuis le portefeuille ASSETS coopératif

### Scripts du Système Oracle (Permits & Licenses)
- **`oracle_system.py`** (UPassport API) : Système de gestion des permis multi-signatures basé sur le WoT 
- **`oracle.WoT_PERMIT.init.sh`** : Initialisation de la Web of Trust pour nouveaux permis (Bootstrap "Block 0")
- **`oracle_test_permit_system.sh`** : Suite de tests complète du système Oracle
- **`UPLANET.official.sh`** : Virements PERMIT depuis le portefeuille RnD coopératif
- **Interface Web `/oracle`** : Interface moderne pour demander et attester des permis (NIP-42)

## 2. Les deux piliers de notre architecture

### 2.1. DID : La Fondation de la Propriété Numérique

Un identifiant décentralisé (DID) est la pierre angulaire de toute interaction dans UPlanet. Il représente une racine de confiance cryptographique, contrôlée exclusivement par l'utilisateur.

**Caractéristiques du DID :**
- **Décentralisé**: Aucune autorité centrale requise
- **Cryptographiquement vérifiable**: Sécurisé par cryptographie à clés publiques/privées
- **Persistant**: Indépendant de tout registre centralisé
- **Interopérable**: Fonctionne à travers différents systèmes et plateformes

**Notre Méthode : `did:nostr:{HEX_PUBLIC_KEY}`**

Nous lions l'identité décentralisée à la clé publique NOSTR, elle-même dérivée de la même seed que la clé Ğ1 (clés jumelles Ed25519). C'est un choix fondamental : l'identité n'est pas une simple donnée, elle est directement ancrée dans l'écosystème économique et social de la monnaie libre.

**Architecture Nostr-Native (Source de Vérité)**

Les documents DID sont publiés comme **événements Nostr kind 30800** (Parameterized Replaceable Events - DID Documents - NIP-101), garantissant:

- **Distribution automatique** sur tous les relais Nostr
- **Mise à jour atomique** (chaque nouvelle version remplace l'ancienne)
- **Résilience** : réplication sur multiples relais
- **Censorship-resistance** : aucun point de contrôle central
- **Cache local** pour performance (`.zen/game/nostr/${EMAIL}/did.json.cache`)

La **ZEN Card** est la manifestation concrète de ce DID. Elle n'est pas juste un "compte", mais un **titre de propriété** sur un espace numérique (stockage, services) au sein d'un Astroport.

### 2.2. UCAN : La Gestion des Droits de Location et d'Accès (MULTIPASS)

Le standard UCAN (User-Controlled Authorization Network) décrit un système de permissions délégables. Notre **MULTIPASS** est l'implémentation vivante de ce concept, transformé en un mécanisme de "location" de services et de délégation de droits.

**Des "Capacités" transformées en Droits d'Usage :**
- La **ZEN Card** (le propriétaire / DID) peut émettre des **MULTIPASS** (les "locations" / UCANs)
- Un MULTIPASS est un jeton de capacité qui accorde des droits spécifiques à un autre utilisateur ou à une application
- Par exemple, le propriétaire d'une ZEN Card peut "louer" 10Go de son espace disque pour 1Ẑ/semaine à un autre utilisateur via un MULTIPASS
- Cela correspond exactement au principe de délégation de UCAN : le propriétaire n'a pas besoin de partager sa clé privée (son titre de propriété). Il crée et signe une "capacité" (un bail numérique) qui peut être vérifiée de manière indépendante.

**Une Confiance Décentralisée et Vérifiable :**
- La validité d'un MULTIPASS (UCAN) est vérifiable en suivant la chaîne cryptographique jusqu'à la ZEN Card (DID) qui l'a émis
- Ce système permet des interactions de confiance sans autorité centrale
- Un service peut vérifier qu'un utilisateur a bien le droit d'accéder à une ressource en inspectant simplement son MULTIPASS, sans avoir besoin de contacter le propriétaire originel

## 3. Relation de Confiance Décentralisée à 3 Tiers

Inspirée de l'[article sur CopyLaRadio](https://www.copylaradio.com/blog/blog-1/post/relation-de-confiance-decentralisee-a-3-tiers-avec-la-g1-149), notre architecture repose sur un partage de secret à 3 niveaux utilisant le schéma de Shamir (SSSS 3/2).

### 3.1. Le Partage de Secret de Shamir (SSSS 3/2)

**Problème** : Une clé privée, même bien protégée, reste vulnérable à la perte, au vol ou à la compromission.

**Solution** : La méthode de partage de secret de Shamir (SSSS) permet de diviser une clé privée en **trois fragments**, dont **deux suffisent** pour la reconstituer.

### 3.2. Distribution des Fragments : Un Équilibre entre Sécurité et Accessibilité

#### **Part 1 : L'Utilisateur (Souveraineté totale)**
- L'utilisateur conserve une part de sa clé dans son **SSSS QR Code** (imprimé, laminé)
- Cette part est encodée en Base58 dans le format : `M-{base58_secret}:{IPNS_vault}`
- Le QR code permet une récupération mobile sans stockage browser
- **Fichier** : `~/.zen/game/nostr/{EMAIL}/._SSSSQR.png`
- **Chiffrement** : Part chiffrée avec G1PUBNOSTR dans `.ssss.head.player.enc`

#### **Part 2 : Le Relai Applicatif (Capitaine - Service sécurisé)**
- Un relai applicatif (le Capitaine de l'Astroport) détient une autre part
- Assure une **authentification sans stocker la clé complète**
- Permet la récupération en cas de perte du QR code
- **Fichier** : `~/.zen/game/nostr/{EMAIL}/.ssss.mid.captain.enc`
- **Chiffrement** : Part chiffrée avec CAPTAING1PUB

#### **Part 3 : Le Réseau Coopératif (UPlanet - Redondance et Sauvegarde)**
- Une dernière part est stockée dans le réseau UPlanet
- Garantit une **récupération d'urgence** via l'essaim d'Astroports
- Permet la continuité du service même si un Astroport est hors ligne
- **Fichier** : `~/.zen/game/nostr/{EMAIL}/ssss.tail.uplanet.enc`
- **Chiffrement** : Part chiffrée avec UPLANETG1PUB

### 3.3. Clés Jumelles Ed25519 : Interopérabilité Facilitée

Puisque la Ğ1 repose sur des **clés Ed25519**, nous exploitons cette compatibilité pour générer des **clés jumelles** à partir d'une même **seed (DISCO)** :

```
DISCO = /?{EMAIL}={SALT}&nostr={PEPPER}
```

À partir de cette seed unique, nous dérivons :
- **Clé Ğ1/Duniter** : Pour les transactions en monnaie libre
- **Clé NOSTR** : Pour l'identité sociale décentralisée  
- **Clé Bitcoin** : Pour l'interopérabilité blockchain
- **Clé Monero** : Pour les transactions privées
- **Clé IPFS** : Pour le stockage décentralisé (IPNS)

Cette approche évite d'avoir à gérer plusieurs clés et renforce la synergie entre la **toile de confiance Ğ1** et d'autres systèmes décentralisés.

### 3.4. Système de Transactions : Primo et WoT

#### Primo-Transaction : Preuve de Propriété et d'Authenticité

Une **primo-transaction** est effectuée pour activer le compte ẐEN à 0 avec un virement de 1 Ğ1 depuis 🏛️ Réserve Ğ1 (UPLANETNAME_G1). 

**Caractéristiques** :
- **Montant** : 1 Ğ1 (activation initiale)
- **Source** : UPLANETNAME_G1 (réserve centrale UPlanet)
- **Destination** : G1PUBNOSTR (portefeuille MULTIPASS)
- **Commentaire** : `UPLANET:${UPLANETG1PUB:0:8}:${YOUSER}:MULTIPASS:PRIMAL`
- **Cache** : `~/.zen/tmp/coucou/${G1PUBNOSTR}.primal` (permanent)

#### Transaction WoT (.2nd) : Identification par Membre Forgeron

La **transaction .2nd** (0.01 Ğ1) permet à un **membre forgeron Duniter** (externe à UPlanet) d'identifier et valider un MULTIPASS. Cette transaction doit être la **deuxième transaction reçue** pour être considérée comme valide.

**Caractéristiques** :
- **Montant** : 0.01 Ğ1 (montant symbolique)
- **Position** : Exactement la 2ème transaction reçue (WoT Dragon Identification)
- **Source** : Membre forgeron Duniter (externe à UPlanet)
- **Destination** : G1PUBNOSTR (portefeuille MULTIPASS ou NODE)
- **Cache** : `~/.zen/tmp/coucou/${wallet}.2nd` (permanent)
- **Effet** : Mise à jour automatique du DID avec `metadata.wotDuniterMember`

**Processus d'identification WoT** :
1. **Détection** : [`primal_wallet_control.sh`](tools/primal_wallet_control.sh) surveille les transactions entrantes
2. **Validation** : Vérifie que c'est exactement la 2ème transaction reçue ET que le montant est 0.01 Ğ1
3. **Mise à jour DID** : Ajoute la G1PUB du membre forgeron dans le document DID
4. **Cache permanent** : Enregistre la G1PUB dans `~/.zen/tmp/coucou/${wallet}.2nd`
5. **Publication** : Le DID mis à jour est republié sur IPNS

**Sécurité et avantages** :
- La primo-transaction et la transaction .2nd permettent de **vérifier l'authenticité** sans exposer les clés privées
- La blockchain Ğ1 devient le **registre de confiance** pour valider les identités UPlanet
- L'identification WoT crée un **lien vérifiable** avec la Web of Trust Duniter
- Les deux transactions sont **immuables** sur la blockchain (cache permanent valide)

## 4. Détails d'Implémentation Technique

### 4.1. Méthode DID : `did:nostr:`

Nous utilisons une méthode DID personnalisée `did:nostr:` basée sur la clé publique hexadécimale du protocole NOSTR :

```
did:nostr:{HEX_PUBLIC_KEY}
```

Exemple: `did:nostr:a1b2c3d4e5f6...`

Ce choix est stratégique pour plusieurs raisons énoncées dans l'article de CopyLaRadio :
- **Légèreté et Agilité** : Évite la complexité et les coûts d'ancrage sur une blockchain spécifique
- **Persistance** : IPNS dissocie l'identifiant de sa localisation
- **Interopérabilité** : Compatible avec l'écosystème NOSTR existant

### 4.2. Structure du Document DID : Un Acte de Propriété Numérique

Le document DID généré est plus qu'une simple carte de visite. Il agit comme un **acte de propriété** qui liste :

#### 1. **Informations d'Identité**
- Identifiant DID principal (`did:nostr:{HEX}`)
- Identifiants alternatifs (`alsoKnownAs`):
  - Adresse email (`mailto:{EMAIL}`)
  - Identifiant G1/Duniter (`did:g1:{G1PUBNOSTR}`)
  - Localisation IPNS (`ipns://{NOSTRNS}`)

Ces identifiants alternatifs permettent de **relier l'identité DID aux différentes facettes de l'utilisateur** dans l'écosystème décentralisé.

#### 2. **Méthodes de Vérification (Clés Jumelles)**
Quatre clés cryptographiques dérivées de la même seed pour différents usages :

- **Clé NOSTR** : Clé Ed25519 pour l'authentification protocole NOSTR
- **Clé G1/Duniter** : Clé Ed25519 pour la blockchain Duniter/G1
- **Clé Bitcoin** : Clé ECDSA Secp256k1 pour les transactions Bitcoin
- **Clé Monero** : Clé cryptographique spécifique Monero
- **Autre** : Clé cryptographique crée avec la même seed.

Ces clés jumelles permettent une **interopérabilité extensible** : une seule identité, utilisable sur plusieurs plateformes.

#### 3. **Authentification & Autorisation (Fondation UCAN)**
- `authentication`: Clés pouvant authentifier en tant que ce DID
- `assertionMethod`: Clés pouvant créer des credentials vérifiables (future extension UCAN)
- `keyAgreement`: Clés pour la communication chiffrée

Ces sections définissent **qui contrôle quoi** et constituent la base technique pour les délégations UCAN via MULTIPASS.

#### 4. **Points de Service (Service Endpoints)**
Services décentralisés associés à cette identité - la "propriété numérique" :

- **NOSTR Relay** : Point d'accès au réseau social décentralisé
- **uDRIVE** : Plateforme de stockage et d'applications cloud personnelle
- **uSPOT** : API pour QR Code, portefeuille et credentials UPlanet

Ces endpoints sont les **"terres numériques"** de l'utilisateur, accessibles et vérifiables via son DID.

#### 5. **Métadonnées Enrichies**
Informations contextuelles sur l'identité et les capacités :
- **Timestamps** : Création/mise à jour automatiques
- **Affiliation UPlanet** : Astroport d'origine et station IPNS
- **Coordonnées géographiques** : Position UMAP et secteur
- **Préférence linguistique** : Langue d'interface utilisateur
- **Identifiant utilisateur** : YOUSER unique dans l'écosystème
- **Station Astroport** : Adresse IPNS de la station d'origine
- **Portefeuilles associés** : MULTIPASS (Ẑ revenue) et ZEN Card (Ẑ society)
- **Statut contractuel** : Niveau de service et contributions coopératives
- **Identification WoT** : Validation par membre forgeron Duniter externe

#### 6. **Extension Environnementale (ORE)**
Pour les DIDs UMAP avec obligations environnementales :
- **Coordonnées géographiques** : Latitude/longitude précises (0.01° x 0.01°)
- **Obligations environnementales** : Contrats ORE attachés au DID
- **Statut de conformité** : Vérification automatique via satellite/IoT
- **Salle de vérification** : Endpoint VDO.ninja pour vérification en temps réel
- **Récompenses économiques** : Historique des Ẑen distribués depuis ASSETS
- **Métadonnées ORE** : Détails des contrats et obligations environnementales

#### 7. **Contextes JSON-LD et API Astroport (u)**

Les documents DID et les Verifiable Credentials référencent des contextes JSON-LD servis par l’API Astroport (domaine **u** de la constellation, par défaut `https://u.(station.)copylaradio.com`) :

- **Document DID** (ex. `dashboard.DID.manager.sh`) : le `@context` inclut `https://u.copylaradio.com/ns/v1`, qui définit les termes UPlanet (CooperativeWallet, IPFSGateway, CooperativeDID, etc.). Ce contexte est servi en **GET** `https://u.copylaradio.com/ns/v1` (ou `/ns/v1/`) par `UPassport/54321.py` (`Content-Type: application/ld+json`).

- **Verifiable Credential** (Oracle / WoTx2, kind 30503) : le `@context` inclut `https://u.copylaradio.com/credentials/v1`, qui définit les termes UPlanet (UPlanetLicense, license, licenseName, holderNpub, attestationsCount, status). Ce contexte est servi en **GET** `https://u.copylaradio.com/credentials/v1` (ou `/credentials/v1/`) par `UPassport/54321.py` (`Content-Type: application/ld+json`).

Chaque constellation et ses stations exposent par défaut les passerelles IPFS, le relais Nostr et l’API u (ipfs, relay, u sur host.domain.tld).

## 5. Flux Opérationnel : De la Création à l'Utilisation

### 5.1. Génération de l'Identité (make_NOSTRCARD.sh)

Lorsqu'un utilisateur crée son MULTIPASS, le script génère l'ensemble de l'écosystème :

1. **Génération de la seed maîtresse (DISCO)**
   ```bash
   DISCO="/?${EMAIL}=${SALT}&nostr=${PEPPER}"
   ```

2. **Dérivation des clés jumelles** à partir de DISCO
   - Clé Ğ1 (G1PUBNOSTR)
   - Clé NOSTR (NPUBLIC/NPRIV)
   - Clés Bitcoin et Monero
   - Clé IPNS pour le stockage uDRIVE

3. **Création du partage de secret SSSS (3/2)**
   ```bash
   echo "$DISCO" | ssss-split -t 2 -n 3 -q > ${EMAIL}.ssss
   ```
   - Part 1 : Chiffrée avec G1PUBNOSTR (utilisateur)
   - Part 2 : Chiffrée avec CAPTAING1PUB (relai)
   - Part 3 : Chiffrée avec UPLANETG1PUB (réseau)

4. **Génération du document DID** (`did.json`)
   - Identifiant : `did:nostr:{HEX}`
   - Méthodes de vérification : toutes les clés jumelles
   - Service endpoints : NOSTR, IPNS, uDRIVE, uSPOT

5. **Primo-transaction sur la blockchain Ğ1**
   - Marque l'identité comme appartenant à l'écosystème UPlanet
   - Crée la preuve de propriété on-chain

6. **Publication Nostr**
   - Le document DID est publié immédiatement sur les relais Nostr (kind 30800 - NIP-101)
   - Accessible via la source de vérité distribuée

7. **Publication IPNS**
   - Le document DID et tout l'espace uDRIVE sont publiés sur IPNS
   - Accessibles via le nom IPNS persistant

### 5.2. Emplacements des Fichiers

Lors de l'exécution de `make_NOSTRCARD.sh` pour une adresse email, les fichiers suivants sont créés :

```
~/.zen/game/nostr/{EMAIL}/
├── did.json.cache                          # Cache local du DID (Nostr est la source de vérité)
├── .secret.nostr                           # NSEC/NPUB/HEX (600 perms) - Clés Nostr privées
├── .secret.disco                           # Seed DISCO chiffrée (600 perms)
├── NPUB                                    # Clé publique NOSTR (format npub)
├── HEX                                     # Clé publique NOSTR (format hex)
├── G1PUBNOSTR                              # Clé publique G1
├── BITCOIN                                 # Adresse Bitcoin
├── MONERO                                  # Adresse Monero
├── NOSTRNS                                 # Identifiant de clé IPNS
├── ._SSSSQR.png                            # QR Code SSSS (Part 1)
├── .ssss.head.player.enc                   # Part 1 chiffrée (utilisateur)
├── .ssss.mid.captain.enc                   # Part 2 chiffrée (capitaine)
├── ssss.tail.uplanet.enc                   # Part 3 chiffrée (UPlanet)
├── MULTIPASS.QR.png                        # QR Code portefeuille G1
├── IPNS.QR.png                             # QR Code accès uDRIVE
├── PROFILE.QR.png                          # QR Code profil NOSTR
└── APP/
    └── uDRIVE/
        ├── .well-known/
        │   └── did.json                    # Endpoint DID standard W3C (copie du cache)
        ├── Apps/
        │   └── Cesium.v1/                  # Application portefeuille G1
        └── Documents/
            └── README.{YOUSER}.md          # Documentation d'accueil
```

**Architecture Nostr-Native:**
- **Source de vérité:** Relais Nostr (événements kind 30800 avec tag `["d", "did"]` - NIP-101)
- **Cache local:** `did.json.cache` (synchronisé depuis Nostr)
- **Endpoint public:** `.well-known/did.json` (copie du cache, accessible via IPFS/IPNS)
- **Clés privées:** `.secret.nostr` (format: `NSEC=...; NPUB=...; HEX=...`)
- **Historique:** Les anciennes versions sont automatiquement remplacées sur Nostr (Replaceable Events)

### 5.3. Résolution du DID (Architecture Nostr-Native)

Le document DID est accessible via **trois canaux** pour une résilience maximale :

#### 1. Source de Vérité : Relais Nostr (kind 30800 - NIP-101)
```bash
# Requête avec did_manager_nostr.sh
./did_manager_nostr.sh fetch user@example.com
```

**But** : Accès direct à la source de vérité distribuée sur les relais Nostr.

**Avantages** :
- ✅ **Source de vérité** : Version la plus à jour
- ✅ **Distribué** : Répliqué sur tous les relais
- ✅ **Automatique** : Les mises à jour remplacent l'ancienne version
- ✅ **Vérifiable** : Signature cryptographique du propriétaire

#### 2. Chemin Standard W3C .well-known (Cache Public via IPFS)
```
{myIPFS}/ipns/{NOSTRNS}/{EMAIL}/APP/uDRIVE/Apps/.well-known/did.json
```

**But** : Suit la convention W3C `.well-known` pour la résolution DID, compatible avec les résolveurs DID standards.

**Exemple** :
```
http://127.0.0.1:8080/ipns/k51qzi5uqu5dgy..../user@example.com/APP/uDRIVE/Apps/.well-known/did.json
https://ipfs.copylaradio.com/ipns/k51qzi5uqu5dgy..../user@example.com/APP/uDRIVE/Apps/.well-known/did.json
```

**Note** : Ce fichier est une copie du cache local, synchronisé lors des mises à jour.

#### 3. Cache Local (Performance)
```bash
~/.zen/game/nostr/${EMAIL}/did.json.cache
```

**But** : Cache local pour accès rapide sans interroger Nostr à chaque fois.

**Mise à jour** : Synchronisé automatiquement lors des `update` ou manuellement via `sync`.

#### 4. Stratégie de Résolution Multi-Niveaux

```
1. Lecture : Cache local (instantané)
   ↓ (si absent ou expiré)
2. Lecture : Relais Nostr (1-2s)
   ↓ (mise à jour cache)
3. Lecture : IPFS/IPNS (fallback)

Écriture : Toujours vers Nostr → Cache → IPFS
```

**Avantages de l'architecture Nostr-Native:**
- ✅ **Performance** : Cache local pour 95% des lectures
- ✅ **Résilience** : Multiples relais Nostr + IPFS fallback
- ✅ **Cohérence** : Source de vérité unique (Nostr)
- ✅ **Censorship-resistant** : Distribution sur relais décentralisés
- ✅ **Standards W3C** : Compatible via `.well-known`

#### 5. Exemples de Résolution DID Conformes W3C v1.1

**Résolution via HTTP (Standard W3C)** :
```bash
# Résolution directe via HTTP
curl -H "Accept: application/did+ld+json" \
     "https://ipfs.copylaradio.com/ipns/k51qzi5uqu5dgy..../user@example.com/did.json.cache"

# Résolution avec métadonnées de résolution
curl -H "Accept: application/did+ld+json" \
     "https://ipfs.copylaradio.com/ipns/k51qzi5uqu5dgy..../user@example.com/did.json.cache" \
     | jq '.didResolutionMetadata'
```

**Résolution via Nostr (Source de Vérité)** :
```bash
# Résolution depuis les relais Nostr
python3 nostr_did_client.py fetch did:nostr:a1b2c3d4e5f6...

# Résolution avec validation cryptographique
python3 nostr_did_client.py validate did:nostr:a1b2c3d4e5f6...
```

**Résolution Programmatique** :
```javascript
// Résolution DID conforme W3C v1.1
const resolver = new DIDResolver({
  methods: ['nostr'],
  nostr: {
    relays: ['wss://relay.copylaradio.com', 'ws://127.0.0.1:7777']
  }
});

const didDocument = await resolver.resolve('did:nostr:a1b2c3d4e5f6...');
console.log(didDocument.didDocument);
console.log(didDocument.didResolutionMetadata);
```

**Métadonnées de Résolution W3C v1.1** :
```json
{
  "didResolutionMetadata": {
    "contentType": "application/did+ld+json",
    "retrieved": "2025-10-11T14:30:00Z",
    "nextUpdate": "2025-10-11T15:30:00Z",
    "source": "nostr_relay",
    "relay": "wss://relay.copylaradio.com",
    "eventId": "abc123...",
    "verificationStatus": "verified"
  },
  "didDocumentMetadata": {
    "created": "2025-10-11T14:30:00Z",
    "updated": "2025-10-11T14:30:00Z",
    "deactivated": false,
    "versionId": "1",
    "nextVersionId": "2"
  }
}
```

### 5.4. Mise à Jour Dynamique du DID

Le document DID est **automatiquement mis à jour** lors des transactions UPlanet pour refléter les propriétés et capacités acquises. Cette mise à jour est effectuée par plusieurs scripts spécialisés :

#### Scripts de Mise à Jour Automatique (Nostr-Native)
- **`UPLANET.official.sh`** : Met à jour les DID lors des transactions coopératives
- **`did_manager_nostr.sh`** : Gestionnaire centralisé avec Nostr comme source de vérité
  - `update` : Mise à jour complète des métadonnées + publication Nostr automatique
  - `fetch` : Récupération du DID depuis les relais Nostr
  - `sync` : Synchronisation Nostr → cache local
  - `validate` : Validation de la structure DID
  - `show-wallets` : Affichage des portefeuilles MULTIPASS et ZEN Card
  - `usociety` : Gestion des fichiers U.SOCIETY pour sociétaires
- **`nostr_publish_did.py`** : Publication directe sur relais Nostr (kind 30800 - NIP-101)

**Déclencheurs de mise à jour** :
- ✅ Transaction **MULTIPASS** : Recharge MULTIPASS (10GB uDRIVE)
- ✅ Transaction **SOCIÉTAIRE Satellite** : Parts sociales (128GB + NextCloud)
- ✅ Transaction **SOCIÉTAIRE Constellation** : Parts sociales (128GB + NextCloud + IA)
- ✅ Transaction **INFRASTRUCTURE** : Apport capital machine
- ✅ Transaction **WoT Duniter** (`.2nd`) : Identification par membre forgeron externe (0.01 Ğ1)
- ✅ Contribution **TREASURY** : Participation au fonds trésorerie coopératif (1/3)
- ✅ Contribution **R&D** : Participation au fonds recherche & développement (1/3)
- ✅ Contribution **ASSETS** : Participation au fonds actifs coopératif (1/3)

**Métadonnées enrichies du DID** :

```json
{
  "metadata": {
    "contractStatus": "cooperative_member_satellite",
    "tokenTypes": ["ZENCARD", "ZENCOIN"],
    "storageQuota": "128GB",
    "services": "uDRIVE + NextCloud private storage",
    "lastPayment": {
      "amount_zen": "50",
      "amount_g1": "5.00",
      "date": "2025-10-11T14:30:00Z",
      "nodeId": "12D3KooWABC..."
    },
    "astroportStation": {
      "ipns": "k51qzi5uqu5dgy...",
      "description": "Astroport station IPNS address",
      "updatedAt": "2025-10-11T14:30:00Z"
    },
    "multipassWallet": {
      "g1pub": "5fTwfbYUtCeoaFLbyzaBYUcq46nBS26rciWJAkBugqpo",
      "type": "MULTIPASS",
      "description": "Ẑ revenue wallet for service operations",
      "updatedAt": "2025-10-11T14:30:00Z"
    },
    "zencardWallet": {
      "g1pub": "7gTwfbYUtCeoaFLbyzaBYUcq46nBS26rciWJAkBugqpo",
      "type": "ZEN_CARD",
      "description": "Ẑ society wallet for cooperative shares",
      "updatedAt": "2025-10-11T14:30:00Z"
    },
    "cooperativeContributions": {
      "treasury": {
        "total_zen": "16.67",
        "total_g1": "1.67",
        "lastContribution": "2025-10-11T14:30:00Z",
        "status": "cooperative_treasury_contributor"
      },
      "rnd": {
        "total_zen": "16.67", 
        "total_g1": "1.67",
        "lastContribution": "2025-10-11T14:30:00Z",
        "status": "cooperative_rnd_contributor"
      },
      "assets": {
        "total_zen": "16.66",
        "total_g1": "1.66", 
        "lastContribution": "2025-10-11T14:30:00Z",
        "status": "cooperative_assets_contributor"
      }
    },
    "wotDuniterMember": {
      "g1pub": "5fTwfbYUtCeoaFLbyzaBYUcq46nBS26rciWJAkBugqpo",
      "historyLink": "$uSPOT/check_zencard?email=user@example.com",
      "verifiedAt": "2025-10-11T14:35:00Z",
      "description": "WoT Duniter member forge (external to UPlanet)"
    },
    "updated": "2025-10-11T14:35:00Z"
  }
}
```

**Types de Jetons (`tokenTypes`)** :
Le champ `tokenTypes` distingue les différents types de jetons possédés par l'utilisateur :
- **`ZENCOIN`** : Jetons d'usage (MULTIPASS) - Recharges de services hebdomadaires
- **`ZENCARD`** : Jetons de propriété (Parts de Capital) - Parts sociales coopératives

Un utilisateur peut posséder les deux types simultanément. Par exemple, un sociétaire qui recharge son MULTIPASS aura `["ZENCARD", "ZENCOIN"]` dans `tokenTypes`.

**Préservation du Statut de Sociétaire** :
Lors d'une mise à jour MULTIPASS (recharge ZENCOIN), le système préserve automatiquement :
- Le `contractStatus` de sociétaire (cooperative_member_satellite, cooperative_member_constellation, infrastructure_contributor)
- Le quota supérieur des sociétaires (128GB au lieu de 10GB)
- Les services étendus (NextCloud, AI services)

Cela permet à un sociétaire de recharger son MULTIPASS sans perdre son statut de propriétaire coopératif.

**Processus de mise à jour (Nostr-Native)** :
1. **Récupération** : Fetch du DID actuel depuis Nostr (ou cache)
2. **Préservation** : Vérification et préservation du statut de sociétaire si présent
3. **Modification** : Mise à jour des métadonnées via `jq` (sans casser la structure JSON)
4. **Types de jetons** : Ajout du type de jeton approprié dans `tokenTypes` (ZENCOIN ou ZENCARD)
5. **Validation** : Vérification de la structure W3C DID
6. **Publication Nostr** : Publication kind 30800 (remplace automatiquement l'ancienne version - NIP-101)
7. **Mise à jour cache** : Copie dans `did.json.cache`
8. **Synchronisation IPFS** : Copie vers `.well-known/did.json` et republication IPNS (arrière-plan)

**Note** : La publication initiale du DID se fait immédiatement lors de la création du MULTIPASS via `make_NOSTRCARD.sh`. Les mises à jour ultérieures sont gérées par `did_manager_nostr.sh` lors des transactions UPlanet.

**Commandes `did_manager_nostr.sh`** :
```bash
# Mise à jour complète (publie automatiquement sur Nostr)
./did_manager_nostr.sh update user@example.com MULTIPASS 50 5.0

# Récupération depuis Nostr
./did_manager_nostr.sh fetch user@example.com

# Synchronisation cache ← Nostr
./did_manager_nostr.sh sync user@example.com
```

**Exemple de cycle de vie (Nostr-Native)** :

```
1. CRÉATION (make_NOSTRCARD.sh)
   → DID créé localement avec status: "new_multipass"
   → Cache: ~/.zen/game/nostr/${EMAIL}/did.json.cache
   → Clés: ~/.zen/game/nostr/${EMAIL}/.secret.nostr (NSEC/NPUB/HEX)
   → Quota: "10GB" (MULTIPASS gratuit 7 jours)
   → Primo-transaction: 1Ğ1 UPLANETNAME_G1 → G1PUBNOSTR
   → Publication Nostr: DID publié immédiatement (kind 30800 - NIP-101)

2. WoT IDENTIFICATION (primal_wallet_control.sh)
   → Transaction 0.01Ğ1 depuis membre forgeron Duniter (2ème TX)
   → DID mis à jour via did_manager_nostr.sh
   → Publication automatique sur Nostr (kind 30800, d=did - NIP-101)
   → Ajout metadata.wotDuniterMember avec G1PUB du forgeron
   → Lien vers profil Cesium+ du membre WoT
   → Cache permanent: ~/.zen/tmp/coucou/${wallet}.2nd

3. UPGRADE SOCIÉTAIRE (UPLANET.official.sh)
   → Transaction 50Ẑ
   → DID mis à jour automatiquement (did_manager_nostr.sh)
   → Publication sur Nostr (remplace version précédente)
   → Status: "cooperative_member_satellite"
   → Quota: "128GB"
   → Services: "uDRIVE + NextCloud"

4. CONSULTATION
   → SOURCE: Relais Nostr (kind 30800 - NIP-101) - Source de vérité
   → CACHE: ~/.zen/game/nostr/${EMAIL}/did.json.cache - Performance
   → PUBLIC: {myIPFS}/ipns/{NOSTRNS}/{EMAIL}/.well-known/did.json - Compatibilité W3C
   → Métadonnées reflètent les capacités actuelles
   → Services vérifient les droits via le DID
   → Identification WoT visible et vérifiable
```

**Architecture Nostr garantit:**
- ✅ **Distribution** : DID répliqué sur tous les relais Nostr
- ✅ **Mise à jour atomique** : Chaque update remplace l'ancienne version
- ✅ **Résilience** : Aucun point de défaillance unique
- ✅ **Performance** : Cache local pour accès rapide
- ✅ **Compatibilité** : Endpoint W3C via IPFS/IPNS

## 6. Extension UCAN : De la Propriété à la Délégation

### 6.1. Le Concept UCAN (User-Controlled Authorization Network)

UCAN est un standard pour les autorisations décentralisées qui permet de **déléguer des capacités** sans partager de secrets. Dans notre écosystème, le MULTIPASS est l'implémentation concrète de ce concept.

**Principes fondamentaux :**
- Les **capacités** (capabilities) sont des jetons qui accordent des droits spécifiques
- Ces capacités peuvent être **déléguées** à d'autres utilisateurs ou applications
- La **chaîne de délégation** est vérifiable cryptographiquement
- Aucune autorité centrale n'est nécessaire pour valider les autorisations

### 6.2. MULTIPASS : L'UCAN Incarné

Le MULTIPASS transforme le concept abstrait d'UCAN en un système économique concret de "location" de services :

#### Gestion Automatique des MULTIPASS
Le script `NOSTRCARD.refresh.sh` gère automatiquement :
- **Cycle de paiement** : Paiements hebdomadaires avec distribution temporelle
- **Mise à jour des données** : Synchronisation des capacités et services
- **Résumés d'activité** : Génération automatique de résumés d'amis (quotidien, hebdomadaire, mensuel, annuel)
- **Expansion N²** : Pour les sociétaires U.SOCIETY, extension aux amis d'amis
- **Synchronisation YouTube** : Intégration des préférences utilisateur
- **Gestion fiscale** : Séparation automatique HT/TVA pour conformité

#### Gestion Automatique des ZEN Card
Le script `PLAYER.refresh.sh` gère automatiquement :
- **Paiements ZEN Card** : Cycle de paiement pour l'accès aux services
- **Intégration uDRIVE** : Mise à jour des applications cloud
- **Synchronisation NOSTR (MULTIPASS)** : Données identité
- **Réseau social** : Gestion des amis et relations
- **Services géolocalisés** : Intégration UMAP et secteurs


### 6.2. Gestion des Machines comme Propriété en Commun

L'article de CopyLaRadio sur le [partage 3x1/3](https://www.copylaradio.com/blog/blog-1/post/relation-de-confiance-decentralisee-a-3-tiers-avec-la-g1-149) décrit comment gérer les machines comme une **propriété mise en commun**. Notre implémentation UCAN/MULTIPASS matérialise cette vision :

#### Modèle de Co-Propriété Tripartite

```
┌─────────────────────────────────────────────────────────────────┐
│ Machine / Service (ex: Serveur PeerTube)                       │
├─────────────────────────────────────────────────────────────────┤
│ Propriété partagée en 3 parts SSSS (2/3 requis)                │
│                                                                 │
│ Part 1: Utilisateur Principal (DID Owner)                      │
│   - Contrôle opérationnel quotidien                            │
│   - Peut émettre MULTIPASS pour location                       │
│   - Clé: .ssss.head.player.enc                                 │
│                                                                 │
│ Part 2: Capitaine Astroport (Service Provider)                 │
│   - Maintenance technique                                      │
│   - Peut intervenir en cas de problème                         │
│   - Clé: .ssss.mid.captain.enc                                 │
│                                                                 │
│ Part 3: Réseau UPlanet (Backup & Recovery)                     │
│   - Sauvegarde distribuée                                      │
│   - Récupération d'urgence                                     │
│   - Clé: .ssss.tail.uplanet.enc                                │
└─────────────────────────────────────────────────────────────────┘
```

#### Avantages du Modèle

✅ **Sécurité Distribuée** : Aucun point de défaillance unique
✅ **Contrôle Souverain** : L'utilisateur garde un pouvoir total sur sa relation de confiance
✅ **Interopérabilité** : Intégration fluide entre Ğ1 et services décentralisés
✅ **Réversibilité** : Une relation de confiance peut être rompue facilement
✅ **Potentiel Économique** : Location, sous-location, revenus passifs

## 7. Intégration avec NOSTR

Le DID est intégré dans l'écosystème NOSTR de plusieurs manières :

### 7.1. Description de Profil
L'identifiant DID est inclus dans la description du profil NOSTR :
```
⏰ UPlanet Ẑen ORIGIN // DID: did:nostr:{HEX}
```

### 7.2. Événements NOSTR
Les événements NOSTR incluent le DID comme tag :
```json
{
  "tags": [
    ["p", "{HEX_PUBLIC_KEY}"],
    ["i", "did:nostr:{HEX}"]
  ]
}
```

Ce tag `i` (identifier) permet aux clients NOSTR de découvrir automatiquement le DID associé à une clé publique.

### 7.3. Message de Bienvenue
Le message NOSTR initial inclut :
- Identifiant DID (`did:nostr:{HEX}`)
- Lien direct vers le document DID (`{myIPFS}/ipns/{NOSTRNS}/{EMAIL}/did.json`)
- QR codes pour le portefeuille et l'accès à l'identité
- Primo-transaction sur la blockchain Ğ1

### 7.4. Événements NOSTR pour ORE (Extension Environnementale)
Les DIDs UMAP avec obligations environnementales publient des événements NOSTR spécialisés :

#### Kind 30312 : ORE Meeting Space
```json
{
  "kind": 30312,
  "content": "UPlanet ORE Environmental Space - Persistent geographic area for environmental obligations tracking",
  "tags": [
    ["d", "ore-space-{lat}-{lon}"],
    ["room", "UMAP_ORE_{lat}_{lon}"],
    ["summary", "UPlanet ORE Environmental Space"],
    ["status", "open"],
    ["service", "{VDONINJA}/?room={umap_hex:0:8}&effects&record"],
    ["t", "ORE"],
    ["t", "UPlanet"],
    ["t", "Environment"],
    ["t", "UMAP"],
    ["g", "{lat},{lon}"],
    ["p", "{UPLANETNAME_G1:0:8}"]
  ]
}
```

#### Kind 30313 : ORE Verification Meeting
```json
{
  "kind": 30313,
  "content": "ORE Environmental Verification Meeting",
  "tags": [
    ["d", "ore-verification-{lat}-{lon}-{timestamp}"],
    ["a", "30312:{umap_hex:0:8}:ore-space-{lat}-{lon}"],
    ["title", "ORE Environmental Verification"],
    ["status", "planned/live/ended"],
    ["starts", "{unix_timestamp}"],
    ["t", "ORE"],
    ["t", "Verification"],
    ["t", "UPlanet"],
    ["t", "Environment"],
    ["g", "{lat},{lon}"]
  ]
}
```

Ces événements permettent :
- **Découverte automatique** des espaces environnementaux ORE
- **Vérification en temps réel** via VDO.ninja
- **Traçabilité complète** des obligations environnementales
- **Intégration économique** avec le système Ẑen

## Exemple de Document DID

Le document DID complet est généré lors de la création du MULTIPASS. Voir l'implémentation dans le code source :

📄 **Code source** : [`make_NOSTRCARD.sh` (lignes 246-345)](../tools/make_NOSTRCARD.sh#L246-L345)

Le document généré contient :
- **Contexte W3C** : Références aux standards DID, Ed25519 et X25519
- **Identifiant principal** : `did:nostr:{HEX}` (clé publique NOSTR en hexadécimal)
- **Alias** : Email, `did:g1:{G1PUB}`, IPNS
- **Méthodes de vérification** : Clés NOSTR, G1, Bitcoin, Monero (twin keys)
- **Authentification** : Méthodes Ed25519 pour NOSTR et G1
- **Services** : Endpoints pour relais NOSTR, IPNS, uDRIVE, uSPOT, Cesium+
- **Métadonnées** : Date de création, coordonnées UMAP, langue, UPlanet d'origine

Le document est stocké à deux emplacements pour compatibilité maximale :
1. **Accès Direct** : `~/.zen/game/nostr/{EMAIL}/did.json`
2. **Standard W3C** : `~/.zen/game/nostr/{EMAIL}/APP/uDRIVE/Apps/.well-known/did.json`

## Usage

The DID document is automatically generated when creating a NOSTR card:

```bash
./make_NOSTRCARD.sh user@example.com picture.png 48.85 2.35
```

No additional parameters are needed. The script will:
1. Generate all cryptographic keys
2. Create the DID document
3. Publish it to IPNS
4. Include it in the NOSTR profile
5. Send it in the welcome message

## Test de Conformité DID

### Script de Test de Conformité

Le script `test_did_conformity.sh` permet de vérifier la conformité des documents DID avec les standards W3C v1.1 et la compatibilité France Connect.

#### Utilisation de Base

```bash
# Test de conformité pour un utilisateur
./test_did_conformity.sh user@example.com

# Test avec vérification France Connect
./test_did_conformity.sh --france-connect user@example.com

# Test de tous les utilisateurs
./test_did_conformity.sh --check-all

# Test avec sortie JSON
./test_did_conformity.sh --format json user@example.com
```

#### Options Avancées

```bash
# Test uniquement la source Nostr
./test_did_conformity.sh --nostr-only user@example.com

# Test uniquement la source IPFS
./test_did_conformity.sh --ipfs-only user@example.com

# Test uniquement le cache local
./test_did_conformity.sh --local-only user@example.com

# Mode verbeux
./test_did_conformity.sh --verbose user@example.com
```

#### Vérifications Effectuées

1. **Structure JSON** : Validité du JSON et conformité W3C DID Core v1.1
2. **Résolution DID** : Vérification des sources Nostr, IPFS et cache local
3. **Métadonnées UPlanet** : Complétude des métadonnées spécifiques UPlanet
4. **France Connect** : Conformité aux exigences France Connect (optionnel)
5. **Clés Jumelles** : Vérification des clés cryptographiques multiples
6. **Services** : Validation des endpoints de service

#### Exemple de Sortie

```bash
$ ./test_did_conformity.sh user@example.com

ℹ️  Test de conformité DID pour: user@example.com
ℹ️  Vérification de la structure JSON et conformité W3C v1.1...
✅ Structure JSON valide et conforme W3C v1.1
ℹ️  Vérification de la résolution DID...
✅ Source Nostr accessible
✅ Cache local trouvé: /home/user/.zen/game/nostr/user@example.com/did.json.cache
✅ Résolution DID fonctionnelle
ℹ️  Vérification des métadonnées UPlanet...
✅ Métadonnées UPlanet complètes

ℹ️  Résumé des tests:
  - json_structure:VALID
  - did_resolution:OK
  - uplanet_metadata:OK
```

#### Intégration dans les Tests Automatisés

```bash
#!/bin/bash
# Script de test automatisé pour l'écosystème UPlanet

# Test de conformité DID
if ./test_did_conformity.sh --check-all --format json > did_test_results.json; then
    echo "✅ Tous les DIDs sont conformes"
else
    echo "❌ Certains DIDs ne sont pas conformes"
    cat did_test_results.json | jq '.errors'
    exit 1
fi

# Test spécifique France Connect
if ./test_did_conformity.sh --france-connect --check-all; then
    echo "✅ Conformité France Connect validée"
else
    echo "❌ Problèmes de conformité France Connect"
    exit 1
fi
```

## Benefits

### For Users
- **Single Identity**: One DID covers multiple blockchains and protocols
- **Verifiable**: Cryptographically provable identity
- **Portable**: Can be used across different platforms
- **Privacy-Preserving**: No centralized registry

### For Developers
- **Standard-Compliant**: Follows W3C specifications
- **Interoperable**: Works with other DID-compatible systems
- **Extensible**: Easy to add new verification methods or services
- **Discoverable**: Standard `.well-known` endpoint

Absolument. Voici mes réflexions, structurées de manière à pouvoir être ajoutées directement à votre document pour l'enrichir. Elles se concentrent sur les implications stratégiques et philosophiques de vos choix techniques.

---

## 8. Architecture Opérationnelle : Scripts et Automatisation

### 8.1. Cycle de Vie Automatisé

L'écosystème UPlanet fonctionne grâce à une architecture de scripts qui automatisent complètement le cycle de vie des identités et des autorisations :

#### Création Initiale
1. **`make_NOSTRCARD.sh`** → Génère MULTIPASS avec DID complet
2. **`VISA.new.sh`** → Génère ZEN Card pour les sociétaires
3. **`did_manager.sh`** → Gère les métadonnées enrichies

#### Gestion Opérationnelle Continue
1. **`NOSTRCARD.refresh.sh`** → Gère les MULTIPASS (paiements, résumés, N²)
2. **`PLAYER.refresh.sh`** → Gère les ZEN Card (services, intégrations)
3. **`UPLANET.official.sh`** → Enregistre les transactions coopératives
4. **`ZEN.ECONOMY.sh`** → Contrôle les virements automatiques
5. **`ZEN.COOPERATIVE.3x1-3.sh`** → Répartit les fonds coopératifs

### 8.2. Métadonnées Enrichies et Traçabilité

Le système `did_manager_nostr.sh` enrichit automatiquement les documents DID et les publie sur Nostr avec :
- **Station Astroport** : Adresse IPNS de la station d'origine
- **Portefeuilles MULTIPASS** : Clés G1 pour les revenus Ẑen
- **Portefeuilles ZEN Card** : Clés G1 pour les parts coopératives
- **Identification WoT** : Validation par membres forgerons externes
- **Contributions coopératives** : Traçabilité complète des fonds
- **Publication Nostr** : Événement kind 30800 (Parameterized Replaceable Event - NIP-101)
- **Signature cryptographique** : Vérifiable par la clé NSEC du propriétaire

## 9. Réflexions Philosophiques : UPlanet, une Nation d'Esprit

Cette implémentation va bien au-delà d'une simple conformité technique avec les standards du W3C. Elle représente une approche pragmatique et philosophique de l'identité numérique souveraine, en parfaite adéquation avec les principes de l'écosystème UPlanet / Astroport.ONE.

### 9.1. Le DID comme Titre de Propriété Numérique

Le DID n'est pas juste une carte d'identité ; **c'est l'acte notarié de l'existence numérique d'un individu**.

Dans notre écosystème, la clé privée racine (protégée par le partage de secret SSSS 3/2) est la preuve de propriété de ce DID. Toutes les autres interactions (délégations, autorisations, "locations" via MULTIPASS) découlent de cette propriété initiale.

Ce socle d'identité auto-souveraine et cryptographiquement vérifiable assure un système de confiance décentralisé fiable et fonctionnel. Le document `did.json` liste non seulement qui vous êtes, mais aussi **ce que vous possédez** :
- Votre espace de stockage (uDRIVE)
- Vos services (PeerTube, NextCloud, etc.)
- Vos clés sur différentes blockchains
- Vos points de service NOSTR et IPFS

C'est un **cadastre numérique décentralisé**.

### 9.2. Le Choix Stratégique de `did:nostr` et IPNS

La combinaison de Nostr pour l'identifiant et d'IPNS pour la résolution est particulièrement judicieuse, comme l'explique l'[article de CopyLaRadio](https://www.copylaradio.com/blog/blog-1/post/relation-de-confiance-decentralisee-a-3-tiers-avec-la-g1-149) :

**Légèreté et Agilité (`did:nostr`)** : En basant le DID sur une simple clé publique Nostr, nous évitons la complexité et les coûts potentiels liés à l'ancrage sur une blockchain spécifique (comme Ethereum ou Bitcoin) pour chaque mise à jour. L'identité reste agile et indépendante de toute logique de consensus d'une blockchain particulière.

**Persistance et Résilience (IPNS)** : Utiliser IPNS pour héberger le `did.json` est une décision stratégique. Cela dissocie l'identifiant de sa localisation. L'utilisateur peut changer de fournisseur de stockage, de serveur ou même passer en mode hors-ligne, son `did:nostr` pointera toujours vers le bon document grâce au pointeur mutable d'IPNS. C'est la garantie de la **persistance de l'identité** au-delà de la durée de vie de n'importe quel service centralisé.

### 9.3. UCAN : De l'Identité aux Autorisations

Le DID se concentre sur l'**identité** (qui vous êtes). Le MULTIPASS, implémentation d'UCAN, gère les **autorisations** (ce que vous pouvez faire).

Cette architecture à deux niveaux crée un système complet :
- Le `did:nostr` devient l'**émetteur (`issuer`)** des autorisations
- La **MULTIPASS** (clés SSSS) est l'outil qui **signe** ces autorisations

Le `did.json` ne sert pas seulement à prouver qui vous êtes, **il devient l'autorité racine** qui certifie la validité de chaque MULTIPASS qui sont émis. C'est ce qui permet de "prêter des clés en faisant confiance au capitaine du relais", ce qui permet à votre DID un reconnaissance sur tous les terminaux Astroport d'une même UPlanet.

### 9.4. Un Pont entre les Mondes : Interopérabilité Pragmatique

L'inclusion de multiples méthodes de vérification (`G1/Duniter`, `Bitcoin`, `Monero`, `NOSTR`) dans un seul document DID est une approche pragmatique et puissante. Plutôt que de créer un système isolé, nous construisons un **pont d'identité**.

Le DID UPlanet accessible sur IPFS devient un véritable **agrégateur d'identité souveraine**. Elle est à la fois simple pour les membres de l'écosystème et compatible avec les outils standards du web décentralisé.

### 9.5. La Confiance à 3 Tiers : Un Modèle Social

Le partage de secret SSSS à 3 niveaux n'est pas qu'une solution technique de sécurité, **c'est un modèle social** :

1. **L'Utilisateur** (Part 1) : Souveraineté individuelle, contrôle personnel
2. **Le Capitaine** (Part 2) : Solidarité locale, entraide communautaire
3. **Le Réseau** (Part 3) : Mutualisation globale, résilience collective

Ce modèle incarne la vision de la **monnaie libre** : l'équilibre entre l'individu, la communauté et le réseau. Chaque niveau apporte une dimension différente de la confiance :
- **Confiance en soi** (je garde ma part)
- **Confiance interpersonnelle** (je fais confiance au Capitaine de mon Astroport)
- **Confiance systémique** (je fais confiance au réseau UPlanet distribué)

### 9.6. Vers une Économie de la Location Décentralisée

Le standard **DID** fournit une grammaire et une syntaxe communes pour l'identité décentralisée. L'écosystème **UPlanet** utilise cette grammaire pour écrire une histoire bien plus riche : celle de la **propriété numérique souveraine** transformée en modèle économique.

- La **ZEN Card** n'est pas qu'un identifiant, c'est un **titre de propriété**
- Le **MULTIPASS** n'est pas qu'une autorisation, c'est un **contrat de location dynamique**
- Le flux de **ẐEN** n'est pas qu'une monnaie, c'est **l'énergie économique** qui anime ces relations de propriété

### 9.7. Extension Environnementale : DIDs pour la Terre

L'innovation la plus révolutionnaire de l'écosystème UPlanet est l'extension des DIDs au-delà de l'identité humaine vers l'**identité environnementale**. Chaque cellule géographique UMAP (0.01° x 0.01°) peut obtenir son propre DID, créant un **cadastre écologique vivant et programmable**.

#### DIDs UMAP : L'Identité de la Terre
- **Chaque parcelle** de terre obtient une identité numérique unique
- **Obligations environnementales** attachées aux DIDs UMAP
- **Vérification en temps réel** via VDO.ninja et satellites
- **Récompenses économiques** automatiques pour la conformité

#### Économie de la Protection Environnementale
- **La terre devient un actif numérique** avec son propre DID
- **Protection environnementale** transformée en source de revenus
- **Ẑen distribués** depuis les réserves coopératives ASSETS
- **Économie circulaire** : Les Ẑen ORE sont fongibles avec tous les autres Ẑen

Cette extension représente une **révolution conceptuelle** : la terre n'est plus juste un bien, elle devient un **acteur économique** avec sa propre identité numérique et ses propres droits économiques.

En intégrant ces concepts, UPlanet démontre comment les standards techniques peuvent être le fondement d'une véritable organisation sociale et économique décentralisée, une **"nation d'esprit"** où :
- Le code est la loi
- Chaque utilisateur est un propriétaire
- Chaque service est une propriété louable
- Chaque transaction crée de la valeur partagée

### 9.7. Réinventer la Société avec la Monnaie Libre

Comme le conclut l'[article de CopyLaRadio](https://www.copylaradio.com/blog/blog-1/post/relation-de-confiance-decentralisee-a-3-tiers-avec-la-g1-149), cette architecture "fournit une **solution robuste et évolutive** pour renforcer la sécurité et la confiance dans l'écosystème Ğ1."

Nous construisons plus qu'un système technique : nous construisons les **fondations d'une nouvelle forme d'organisation sociale**, où la confiance n'est plus déléguée à des institutions centralisées, mais distribuée entre les individus, leurs communautés et le réseau global.

C'est la promesse d'UPlanet : un espace où la souveraineté numérique n'est pas un privilège, mais un **droit fondamental**, accessible à tous via un simple email et protégé par la cryptographie moderne.


## Security Considerations

1. **Key Management**: Private keys are never included in the DID document
2. **Access Control**: The `.secret.disco` file remains encrypted and protected
3. **SSSS Protection**: Secret sharing ensures key recovery without single point of failure
4. **Multiple Keys**: Different keys for different crypto applications (PGP, SSH, ...)

## Future Enhancements

Potential improvements:
- Add support for DID rotation/updates
- Implement DID delegation mechanisms
- Add verifiable credentials support
- Create DID resolution service
- Implement cross-chain identity linking

## Standards Compliance

This implementation follows:
- [W3C DID Core v1.0](https://www.w3.org/TR/did-core/)
- [W3C DID Specification Registries](https://www.w3.org/TR/did-spec-registries/)
- [Ed25519 Signature 2020](https://w3c-ccg.github.io/lds-ed25519-2020/)
- [NOSTR Protocol (NIP-01)](https://github.com/nostr-protocol/nips/blob/master/01.md)

## 10. Conformité France Connect : Pont entre Souveraineté et Légalité

### 10.1. Positionnement Stratégique

L'intégration de la conformité France Connect dans l'écosystème UPlanet représente un **pont stratégique** entre la souveraineté numérique décentralisée et la reconnaissance légale française. Cette approche permet aux utilisateurs français de bénéficier des deux mondes :

- **Souveraineté UPlanet** : Contrôle total de l'identité, propriété numérique, économie coopérative
- **Légalité Française** : Reconnaissance officielle, accès aux services publics, conformité RGPD

### 10.2. Architecture France Connect Intégrée

#### Métadonnées France Connect dans le DID

Le document DID UPlanet inclut une section `franceConnect` qui s'active **uniquement pour les ZEN Card avec KYC vérifié** :

**Pour les utilisateurs NON vérifiés (MULTIPASS uniquement) :**
```json
{
  "metadata": {
    "franceConnect": {
      "compliance": "disabled",
      "identityProvider": "UPlanet",
      "verificationLevel": "basic",
      "kycStatus": "pending",
      "wotVerification": "required",
      "supportedServices": [],
      "dataSharing": {
        "consentRequired": true,
        "scope": "none",
        "retentionPeriod": "none"
      }
    }
  }
}
```

**Pour les utilisateurs KYC vérifiés (ZEN Card + transaction WoT 0.01Ğ1) :**
```json
{
  "metadata": {
    "franceConnect": {
      "compliance": "enabled",
      "identityProvider": "UPlanet",
      "verificationLevel": "enhanced",
      "kycStatus": "verified",
      "wotVerification": "completed",
      "supportedServices": [
        "france-identite",
        "ameli",
        "impots", 
        "caf",
        "pole-emploi"
      ],
      "dataSharing": {
        "consentRequired": true,
        "scope": "minimal",
        "retentionPeriod": "1_year"
      },
      "lastVerification": "2025-10-11T14:30:00Z",
      "certificationLevel": "level_2"
    }
  }
}
```

#### Niveaux de Vérification

1. **Level 0** : MULTIPASS sans KYC - Aucun accès France Connect
2. **Level 1** : ZEN Card sans KYC - Accès limité aux services France Connect
3. **Level 2** : ZEN Card + KYC WoT - Accès complet avec validation cryptographique UPlanet

#### Processus de KYC WoT

La conformité France Connect est activée uniquement après :

1. **Création ZEN Card** : L'utilisateur devient sociétaire
2. **Transaction WoT** : Un membre forgeron Duniter externe envoie 0.01Ğ1
3. **Vérification** : Le fichier `~/.zen/tmp/coucou/${zencard_g1pub}.2nd` est créé
4. **Activation** : France Connect passe de `disabled` à `enabled`

### 10.3. Intégration Technique

#### Scripts Modifiés

**`make_NOSTRCARD.sh`** :
- Génération des métadonnées France Connect en mode `disabled` par défaut
- Statut initial : `kycStatus: "pending"`, `wotVerification: "required"`
- Aucun service France Connect accessible sans KYC WoT

**`did_manager_nostr.sh`** :
- Nouvelle fonction `validate_france_connect()`
- Vérification automatique du KYC WoT via fichier `.2nd`
- Activation conditionnelle : `enabled` si KYC vérifié, `disabled` sinon
- Métadonnées dynamiques selon le statut de vérification

**`UPLANET.official.sh`** :
- Validation France Connect **uniquement pour les SOCIÉTAIRES avec KYC WoT**
- Pas de validation pour MULTIPASS (MULTIPASS uniquement)
- Pas de validation pour INFRASTRUCTURE (apport capital)
- Vérification du fichier `~/.zen/tmp/coucou/${zencard_g1pub}.2nd`

#### Commandes France Connect

```bash
# Validation de la conformité France Connect (KYC requis)
./did_manager_nostr.sh validate-france-connect user@example.com

# Mise à jour avec validation automatique (SOCIÉTAIRE uniquement)
./did_manager_nostr.sh update user@example.com SOCIETAIRE_SATELLITE 50 5.0

# Vérification du statut KYC
ls ~/.zen/tmp/coucou/${zencard_g1pub}.2nd
```

### 10.4. Services France Connect Supportés

#### Services Administratifs
- **France Identité** : Justificatifs d'identité sécurisés
- **Ameli** : Assurance maladie et remboursements
- **Impots.gouv.fr** : Déclarations fiscales
- **CAF** : Allocations familiales et sociales
- **Pôle Emploi** : Services d'emploi et formation

#### Flux d'Authentification

**Pour les utilisateurs KYC vérifiés (ZEN Card + WoT) :**
```
Utilisateur UPlanet → France Connect → Service Public
     ↓                    ↓              ↓
  DID UPlanet      Validation FC    Service Administratif
     ↓                    ↓              ↓
  Blockchain Ğ1    Signature État    Accès Sécurisé
```

**Pour les utilisateurs sans KYC (MULTIPASS uniquement) :**
```
Utilisateur UPlanet → Accès Refusé
     ↓                    ↓
  DID UPlanet      France Connect
     ↓                    ↓
  Blockchain Ğ1    KYC Required
```

### 10.5. Avantages de l'Intégration

#### Pour les Utilisateurs Français avec KYC
- ✅ **Double Souveraineté** : UPlanet + France Connect
- ✅ **Accès Simplifié** : Un seul identifiant pour tout
- ✅ **Conformité Légale** : Respect du cadre français
- ✅ **Économie Intégrée** : Monnaie libre + services publics

#### Pour les Utilisateurs sans KYC
- ✅ **Souveraineté UPlanet** : Contrôle total de l'identité
- ✅ **Économie Coopérative** : Services UPlanet complets
- ❌ **Services Publics** : Accès limité (KYC requis)

#### Pour l'Écosystème UPlanet
- ✅ **Légitimité Française** : Reconnaissance officielle
- ✅ **Adoption Facilitée** : Pont avec l'existant
- ✅ **Différenciation** : Unique en son genre
- ✅ **Évolutivité** : Modèle réplicable

### 10.6. Sécurité et Conformité

#### Protection des Données
- **Consentement Explicite** : `consentRequired: true`
- **Minimisation** : `scope: "minimal"`
- **Rétention Limitée** : `retentionPeriod: "1_year"`
- **Chiffrement End-to-End** : Cryptographie Ed25519

#### Conformité RGPD
- **Droit à l'Oubli** : Suppression automatique après 1 an
- **Portabilité** : Export des données via DID
- **Transparence** : Métadonnées complètes dans le DID
- **Contrôle Utilisateur** : Gestion via MULTIPASS

### 10.7. Cas d'Usage Concrets

#### Scénario 1 : Déclaration d'Impôts (KYC requis)
```
1. Utilisateur ZEN Card avec KYC WoT se connecte via UPlanet DID
2. France Connect valide l'identité (KYC vérifié)
3. Service Impots.gouv.fr accède aux données
4. Déclaration pré-remplie automatiquement
5. Signature électronique via clé UPlanet
```

#### Scénario 2 : Demande CAF (KYC requis)
```
1. Authentification UPlanet + France Connect (KYC vérifié)
2. Vérification automatique des revenus Ğ1
3. Calcul des droits via blockchain
4. Demande automatique des allocations
5. Paiement en Ğ1 ou euros
```

#### Scénario 3 : Utilisateur MULTIPASS sans KYC
```
1. Utilisateur MULTIPASS tente d'accéder à France Connect
2. Accès refusé - KYC requis
3. Redirection vers processus de création ZEN Card
4. Information sur la nécessité du KYC WoT
```

#### Scénario 4 : Authentification Multi-Niveaux
```
1. Utilisateur UPlanet avec KYC WoT
2. Authentification via DID UPlanet (niveau 1)
3. Validation France Connect (niveau 2)
4. Accès aux services publics avec double vérification
5. Traçabilité complète des accès
```

#### Scénario 5 : Portabilité des Données
```
1. Utilisateur change d'Astroport
2. DID reste valide (identité persistante)
3. Métadonnées mises à jour automatiquement
4. Services France Connect continuent de fonctionner
5. Aucune perte de données ou de droits
```

#### Scénario 6 : Récupération d'Urgence
```
1. Utilisateur perd accès à son compte
2. Récupération via SSSS 3/2 (2 parts sur 3)
3. Validation de l'identité via WoT
4. Restauration des droits France Connect
5. Continuité des services publics
```

### 10.8. Évolution Future

#### Phase 1 : Conformité de Base (Actuelle)
- Métadonnées France Connect conditionnelles dans le DID
- Validation automatique basée sur le KYC WoT
- Activation uniquement pour ZEN Card avec KYC vérifié
- Intégration avec services existants

#### Phase 2 : Certification Complète
- Certification officielle France Connect pour utilisateurs KYC
- Intégration directe avec l'API France Connect
- Services publics natifs UPlanet pour sociétaires vérifiés
- Processus de KYC automatisé via WoT

#### Phase 3 : Écosystème Hybride
- Services publics décentralisés pour utilisateurs KYC
- Monnaie libre intégrée aux administrations
- Gouvernance numérique participative
- Écosystème multi-niveaux (MULTIPASS/ZEN Card/France Connect)

## 11. Références

### Standards et Spécifications

- [W3C DID Core v1.1](https://www.w3.org/TR/did-core-1.1/) - Spécification des identifiants décentralisés (version 1.1)
- [W3C DID Resolution v1.0](https://www.w3.org/TR/did-resolution/) - Spécification de résolution des identifiants décentralisés
- [W3C DID Specification Registries](https://www.w3.org/TR/did-spec-registries/) - Registre des méthodes DID
- [Ed25519 Signature 2020](https://w3c-ccg.github.io/lds-ed25519-2020/) - Signatures cryptographiques Ed25519
- [UCAN Specification](https://ucan.xyz/) - User-Controlled Authorization Networks
- [France Connect Documentation](https://franceconnect.gouv.fr/) - Plateforme d'authentification française
- [France Identité](https://france-identite.gouv.fr/) - Justificatifs d'identité sécurisés

### Protocoles et Technologies

- [NOSTR Protocol (NIP-01)](https://github.com/nostr-protocol/nips/blob/master/01.md) - Protocole de communication décentralisé
- [IPFS/IPNS Documentation](https://docs.ipfs.tech/) - Système de fichiers interplanétaire
- [Duniter/G1 Documentation](https://duniter.org/) - Blockchain de la monnaie libre
- [Shamir Secret Sharing](https://en.wikipedia.org/wiki/Shamir%27s_Secret_Sharing) - Partage de secret cryptographique

### Articles et Réflexions

- [Relation de Confiance Décentralisée à 3 Tiers avec la Ğ1](https://www.copylaradio.com/blog/blog-1/post/relation-de-confiance-decentralisee-a-3-tiers-avec-la-g1-149) - Article fondateur sur CopyLaRadio
- [MULTIPASS System Documentation](./MULTIPASS_SYSTEM.md) - Documentation complète du système MULTIPASS
- [MULTIPASS Quick Reference](../templates/MULTIPASS_QUICK_REFERENCE.md) - Guide rapide utilisateur
- [ORE System Documentation](./docs/ORE_SYSTEM.md) - Système d'Obligations Réelles Environnementales avec DIDs UMAP

### Outils et Implémentations

#### Scripts de Création et Gestion (Nostr-Native)
- `make_NOSTRCARD.sh` - Script de génération de MULTIPASS et DID
- `VISA.new.sh` - Script de génération de ZEN Card
- `did_manager_nostr.sh` - Gestionnaire centralisé avec Nostr comme source de vérité
- `nostr_publish_did.py` - Publication des DIDs sur relais Nostr (kind 30800 - NIP-101)
- `nostr_did_client.py` - Client unifié pour lecture/fetch des DIDs depuis Nostr
- `nostr_did_recall.sh` - Migration des DIDs existants vers Nostr

#### Scripts de Gestion Opérationnelle
- `NOSTRCARD.refresh.sh` - Gestionnaire du cycle de vie des MULTIPASS
- `PLAYER.refresh.sh` - Gestionnaire du cycle de vie des ZEN Card
- `UPLANET.official.sh` - Enregistrement des transactions coopératives

#### Scripts Économiques
- `ZEN.ECONOMY.sh` - Contrôle des virements automatiques Ẑen
- `ZEN.COOPERATIVE.3x1-3.sh` - Répartition coopérative des fonds

#### Outils d'Authentification
- `upassport.sh` - Script d'authentification et de résolution SSSS
- `54321.py` - API backend UPassport
- `scan_new.html` - Terminal de scan MULTIPASS

#### Outils de Test et Validation
- `test_did_conformity.sh` - Script de test de conformité DID W3C v1.1
- `nostr_did_client.py` - Client de test et validation Nostr

---

**Créé** : Octobre 2025  
**Dernière mise à jour** : Octobre 2025  
**Mainteneur** : Équipe UPlanet / Astroport.ONE  
**Licence** : AGPL-3.0  
**Contact** : support@qo-op.com

---

**🎫 Bienvenue dans l'ère de la souveraineté numérique !**

*"Dans UPlanet, votre identité vous appartient. Votre propriété numérique vous appartient. Vos données vous appartiennent. C'est plus qu'une promesse technique, c'est une promesse de liberté."*

