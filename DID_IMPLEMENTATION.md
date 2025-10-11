# Implémentation de l'Identité et des Autorisations Décentralisées dans l'écosystème UPlanet

## 1. Vue d'ensemble : Au-delà des standards, une souveraineté numérique incarnée

Ce document détaille notre approche de l'identité numérique décentralisée (DID) et des autorisations contrôlées par l'utilisateur (UCAN) au sein de l'écosystème UPlanet et Astroport.ONE.

Nous ne nous contentons pas de suivre les spécifications W3C ; nous les utilisons comme un tremplin pour construire un système de **souveraineté numérique** complet. Notre objectif est de transformer le concept d'identité numérique en une véritable **propriété numérique**, où chaque individu contrôle non seulement qui il est, mais aussi ce qu'il possède et les droits qu'il délègue.

Le script `make_NOSTRCARD.sh` génère des documents DID conformes aux standards [W3C DID 1.0](https://www.w3.org/TR/did-1.0/), mais va bien au-delà en créant un écosystème complet de **ZEN Cards** (identité) et de **MULTIPASS** (autorisations).

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

### 3.4. Primo-Transaction : Preuve de Propriété et d'Authenticité

Une **primo-transaction** est effectué pour activer le compte ẐEN à 0 avec un virement de 1 Ğ1 depuis 🏛️ Réserve Ğ1 (UPLANETNAME_G1). Ensuite une transaction de 0.01 Ğ1 émise par le **compte forgeron** (incluant l'adresse de la ZenCard/MULTIPASS en commentaire). 
La combinaison de ces paiement dans l'historique du portefeuille joue le rôle de **preuve d'appartenance** en inscrivant sur la blockchain Ğ1 une signature qui relie l'identité de l'utilisateur à sa clé applicative.

**Sécurité et fonctionnalités** :
- La primo-transaction contient un **commentaire** qui identifie le MULTIPASS
- Ce mécanisme permet de **vérifier l'authenticité** sans exposer sa partie privée
- La blockchain Ğ1 devient le **registre de confiance** pour valider les identités UPlanet

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

#### 5. **Métadonnées**
Informations contextuelles sur l'identité :
- Timestamps de création/mise à jour
- Affiliation UPlanet (quel Astroport)
- Coordonnées géographiques (UMAP)
- Préférence linguistique
- Identifiant utilisateur (YOUSER)

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

6. **Publication IPNS**
   - Le document DID et tout l'espace uDRIVE sont publiés sur IPNS
   - Accessibles via le nom IPNS persistant

### 5.2. Emplacements des Fichiers

Lors de l'exécution de `make_NOSTRCARD.sh` pour une adresse email, les fichiers suivants sont créés :

```
~/.zen/game/nostr/{EMAIL}/
├── did.json                                # Document DID principal (mise à jour dynamique)
├── did.json.backup.*                       # Sauvegardes automatiques horodatées
├── NPUB                                    # Clé publique NOSTR (format npub)
├── HEX                                     # Clé publique NOSTR (format hex)
├── G1PUBNOSTR                              # Clé publique G1
├── BITCOIN                                 # Adresse Bitcoin
├── MONERO                                  # Adresse Monero
├── NOSTRNS                                 # Identifiant de clé IPNS
├── .secret.disco                           # Seed DISCO chiffrée (600 perms)
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
        │   └── did.json                    # Endpoint DID standard W3C (synchronisé)
        ├── Apps/
        │   └── Cesium.v1/                  # Application portefeuille G1
        └── Documents/
            └── README.{YOUSER}.md          # Documentation d'accueil
```

**Note** : Les deux fichiers `did.json` (racine et `.well-known`) sont synchronisés automatiquement lors des mises à jour. Les backups horodatés permettent de tracer l'historique des modifications.

### 5.3. Résolution du DID

Le document DID est accessible à **deux emplacements** pour une compatibilité maximale :

#### 1. Accès Direct à la Racine
```
{myIPFS}/ipns/{NOSTRNS}/{EMAIL}/did.json
```

**But** : Accès direct rapide au document DID à la racine du répertoire IPNS de l'utilisateur.

**Exemple** :
```
http://127.0.0.1:8080/ipns/k51qzi5uqu5dgy..../user@example.com/did.json
https://ipfs.copylaradio.com/ipns/k51qzi5uqu5dgy..../user@example.com/did.json
```

#### 2. Chemin Standard W3C .well-known
```
{myIPFS}/ipns/{NOSTRNS}/{EMAIL}/APP/uDRIVE/.well-known/did.json
```

**But** : Suit la convention W3C `.well-known` pour la résolution DID, compatible avec les résolveurs DID standards et les outils de découverte.

**Exemple** :
```
http://127.0.0.1:8080/ipns/k51qzi5uqu5dgy..../user@example.com/APP/uDRIVE/.well-known/did.json
https://ipfs.copylaradio.com/ipns/k51qzi5uqu5dgy..../user@example.com/APP/uDRIVE/.well-known/did.json
```

#### 3. Stratégie de Résolution

Les deux emplacements contiennent le **même document DID**. Cette double localisation garantit :
- ✅ **Compatibilité** avec les standards W3C (chemin `.well-known`)
- ✅ **Simplicité** pour l'accès direct (chemin racine)
- ✅ **Découvrabilité** par les résolveurs DID automatisés
- ✅ **Flexibilité** pour différents cas d'usage

La combinaison de Nostr pour l'identifiant et d'IPNS pour la résolution est particulièrement judicieuse :
- **Légèreté** : Pas besoin d'ancrage coûteux sur blockchain
- **Résilience** : L'identité persiste même si un service tombe
- **Mobilité** : L'utilisateur peut changer de fournisseur sans perdre son identité

### 5.4. Mise à Jour Dynamique du DID

Le document DID est **automatiquement mis à jour** lors des transactions UPlanet pour refléter les propriétés et capacités acquises. Cette mise à jour est effectuée par le script [`UPLANET.official.sh`](../UPLANET.official.sh) via la fonction `update_did_document()`.

**Déclencheurs de mise à jour** :
- ✅ Transaction **LOCATAIRE** : Recharge MULTIPASS (10GB uDRIVE)
- ✅ Transaction **SOCIÉTAIRE Satellite** : Parts sociales (128GB + NextCloud)
- ✅ Transaction **SOCIÉTAIRE Constellation** : Parts sociales (128GB + NextCloud + IA)
- ✅ Transaction **INFRASTRUCTURE** : Apport capital machine

**Métadonnées ajoutées au DID** :

```json
{
  "metadata": {
    "contractStatus": "cooperative_member_satellite",
    "storageQuota": "128GB",
    "services": "uDRIVE + NextCloud private storage",
    "lastPayment": {
      "amount_zen": "50",
      "amount_g1": "5.00",
      "date": "2025-10-11T14:30:00Z",
      "nodeId": "12D3KooWABC..."
    },
    "updated": "2025-10-11T14:30:00Z"
  }
}
```

**Processus de mise à jour** :
1. **Sauvegarde** : Création automatique d'un backup `did.json.backup.YYYYMMDD_HHMMSS`
2. **Modification** : Mise à jour des métadonnées via `jq` (sans casser la structure JSON)
3. **Synchronisation** : Copie vers `.well-known/did.json` pour conformité W3C
4. **Publication** : Republication automatique sur IPNS (arrière-plan)

**Exemple de cycle de vie** :

```
1. CRÉATION (make_NOSTRCARD.sh)
   → DID créé avec status: "active"
   → Quota: "10GB" (MULTIPASS gratuit 7 jours)

2. UPGRADE SOCIÉTAIRE (UPLANET.official.sh)
   → Transaction 50Ẑ
   → DID mis à jour automatiquement
   → Status: "cooperative_member_satellite"
   → Quota: "128GB"
   → Services: "uDRIVE + NextCloud"

3. CONSULTATION
   → {myIPFS}/ipns/{NOSTRNS}/{EMAIL}/did.json
   → Métadonnées reflètent les capacités actuelles
   → Services vérifient les droits via le DID
```

Cette approche garantit que le **DID reste toujours la source de vérité** pour les capacités et propriétés d'un utilisateur, sans nécessiter de base de données centralisée.

## 6. Extension UCAN : De la Propriété à la Délégation

### 6.1. Le Concept UCAN (User-Controlled Authorization Network)

UCAN est un standard pour les autorisations décentralisées qui permet de **déléguer des capacités** sans partager de secrets. Dans notre écosystème, le MULTIPASS est l'implémentation concrète de ce concept.

**Principes fondamentaux :**
- Les **capacités** (capabilities) sont des jetons qui accordent des droits spécifiques
- Ces capacités peuvent être **déléguées** à d'autres utilisateurs ou applications
- La **chaîne de délégation** est vérifiable cryptographiquement
- Aucune autorité centrale n'est nécessaire pour valider les autorisations

###6.2. MULTIPASS : L'UCAN Incarné

Le MULTIPASS transforme le concept abstrait d'UCAN en un système économique concret de "location" de services :


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
2. **Standard W3C** : `~/.zen/game/nostr/{EMAIL}/APP/uDRIVE/.well-known/did.json`

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

## 8. Réflexions Philosophiques : UPlanet, une Nation d'Esprit

Cette implémentation va bien au-delà d'une simple conformité technique avec les standards du W3C. Elle représente une approche pragmatique et philosophique de l'identité numérique souveraine, en parfaite adéquation avec les principes de l'écosystème UPlanet / Astroport.ONE.

### 8.1. Le DID comme Titre de Propriété Numérique

Le DID n'est pas juste une carte d'identité ; **c'est l'acte notarié de l'existence numérique d'un individu**.

Dans notre écosystème, la clé privée racine (protégée par le partage de secret SSSS 3/2) est la preuve de propriété de ce DID. Toutes les autres interactions (délégations, autorisations, "locations" via MULTIPASS) découlent de cette propriété initiale.

Ce socle d'identité auto-souveraine et cryptographiquement vérifiable assure un système de confiance décentralisé fiable et fonctionnel. Le document `did.json` liste non seulement qui vous êtes, mais aussi **ce que vous possédez** :
- Votre espace de stockage (uDRIVE)
- Vos services (PeerTube, NextCloud, etc.)
- Vos clés sur différentes blockchains
- Vos points de service NOSTR et IPFS

C'est un **cadastre numérique décentralisé**.

### 8.2. Le Choix Stratégique de `did:nostr` et IPNS

La combinaison de Nostr pour l'identifiant et d'IPNS pour la résolution est particulièrement judicieuse, comme l'explique l'[article de CopyLaRadio](https://www.copylaradio.com/blog/blog-1/post/relation-de-confiance-decentralisee-a-3-tiers-avec-la-g1-149) :

**Légèreté et Agilité (`did:nostr`)** : En basant le DID sur une simple clé publique Nostr, nous évitons la complexité et les coûts potentiels liés à l'ancrage sur une blockchain spécifique (comme Ethereum ou Bitcoin) pour chaque mise à jour. L'identité reste agile et indépendante de toute logique de consensus d'une blockchain particulière.

**Persistance et Résilience (IPNS)** : Utiliser IPNS pour héberger le `did.json` est une décision stratégique. Cela dissocie l'identifiant de sa localisation. L'utilisateur peut changer de fournisseur de stockage, de serveur ou même passer en mode hors-ligne, son `did:nostr` pointera toujours vers le bon document grâce au pointeur mutable d'IPNS. C'est la garantie de la **persistance de l'identité** au-delà de la durée de vie de n'importe quel service centralisé.

### 8.3. UCAN : De l'Identité aux Autorisations

Le DID se concentre sur l'**identité** (qui vous êtes). Le MULTIPASS, implémentation d'UCAN, gère les **autorisations** (ce que vous pouvez faire).

Cette architecture à deux niveaux crée un système complet :
- Le `did:nostr` devient l'**émetteur (`issuer`)** des autorisations
- La **MULTIPASS** (clés SSSS) est l'outil qui **signe** ces autorisations

Le `did.json` ne sert pas seulement à prouver qui vous êtes, **il devient l'autorité racine** qui certifie la validité de chaque MULTIPASS qui sont émis. C'est ce qui permet de "prêter des clés en faisant confiance au capitaine du relais", ce qui permet à votre DID un reconnaissance sur tous les terminaux Astroport d'une même UPlanet.

### 8.4. Un Pont entre les Mondes : Interopérabilité Pragmatique

L'inclusion de multiples méthodes de vérification (`G1/Duniter`, `Bitcoin`, `Monero`, `NOSTR`) dans un seul document DID est une approche pragmatique et puissante. Plutôt que de créer un système isolé, nous construisons un **pont d'identité**.

Le DID UPlanet accessible sur IPFS devient un véritable **agrégateur d'identité souveraine**. Elle est à la fois simple pour les membres de l'écosystème et compatible avec les outils standards du web décentralisé.

### 8.5. La Confiance à 3 Tiers : Un Modèle Social

Le partage de secret SSSS à 3 niveaux n'est pas qu'une solution technique de sécurité, **c'est un modèle social** :

1. **L'Utilisateur** (Part 1) : Souveraineté individuelle, contrôle personnel
2. **Le Capitaine** (Part 2) : Solidarité locale, entraide communautaire
3. **Le Réseau** (Part 3) : Mutualisation globale, résilience collective

Ce modèle incarne la vision de la **monnaie libre** : l'équilibre entre l'individu, la communauté et le réseau. Chaque niveau apporte une dimension différente de la confiance :
- **Confiance en soi** (je garde ma part)
- **Confiance interpersonnelle** (je fais confiance au Capitaine de mon Astroport)
- **Confiance systémique** (je fais confiance au réseau UPlanet distribué)

### 8.6. Vers une Économie de la Location Décentralisée

Le standard **DID** fournit une grammaire et une syntaxe communes pour l'identité décentralisée. L'écosystème **UPlanet** utilise cette grammaire pour écrire une histoire bien plus riche : celle de la **propriété numérique souveraine** transformée en modèle économique.

- La **ZEN Card** n'est pas qu'un identifiant, c'est un **titre de propriété**
- Le **MULTIPASS** n'est pas qu'une autorisation, c'est un **contrat de location dynamique**
- Le flux de **ẐEN** n'est pas qu'une monnaie, c'est **l'énergie économique** qui anime ces relations de propriété

En intégrant ces concepts, UPlanet démontre comment les standards techniques peuvent être le fondement d'une véritable organisation sociale et économique décentralisée, une **"nation d'esprit"** où :
- Le code est la loi
- Chaque utilisateur est un propriétaire
- Chaque service est une propriété louable
- Chaque transaction crée de la valeur partagée

### 8.7. Réinventer la Société avec la Monnaie Libre

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

## 9. Références

### Standards et Spécifications

- [W3C DID Core v1.0](https://www.w3.org/TR/did-core/) - Spécification des identifiants décentralisés
- [W3C DID Specification Registries](https://www.w3.org/TR/did-spec-registries/) - Registre des méthodes DID
- [Ed25519 Signature 2020](https://w3c-ccg.github.io/lds-ed25519-2020/) - Signatures cryptographiques Ed25519
- [UCAN Specification](https://ucan.xyz/) - User-Controlled Authorization Networks

### Protocoles et Technologies

- [NOSTR Protocol (NIP-01)](https://github.com/nostr-protocol/nips/blob/master/01.md) - Protocole de communication décentralisé
- [IPFS/IPNS Documentation](https://docs.ipfs.tech/) - Système de fichiers interplanétaire
- [Duniter/G1 Documentation](https://duniter.org/) - Blockchain de la monnaie libre
- [Shamir Secret Sharing](https://en.wikipedia.org/wiki/Shamir%27s_Secret_Sharing) - Partage de secret cryptographique

### Articles et Réflexions

- [Relation de Confiance Décentralisée à 3 Tiers avec la Ğ1](https://www.copylaradio.com/blog/blog-1/post/relation-de-confiance-decentralisee-a-3-tiers-avec-la-g1-149) - Article fondateur sur CopyLaRadio
- [MULTIPASS System Documentation](./MULTIPASS_SYSTEM.md) - Documentation complète du système MULTIPASS
- [MULTIPASS Quick Reference](../templates/MULTIPASS_QUICK_REFERENCE.md) - Guide rapide utilisateur

### Outils et Implémentations

- `make_NOSTRCARD.sh` - Script de génération de MULTIPASS et DID
- `upassport.sh` - Script d'authentification et de résolution SSSS
- `54321.py` - API backend UPassport
- `scan_new.html` - Terminal de scan MULTIPASS

---

**Créé** : Octobre 2025  
**Dernière mise à jour** : Octobre 2025  
**Mainteneur** : Équipe UPlanet / Astroport.ONE  
**Licence** : AGPL-3.0  
**Contact** : support@qo-op.com

---

**🎫 Bienvenue dans l'ère de la souveraineté numérique !**

*"Dans UPlanet, votre identité vous appartient. Votre propriété numérique vous appartient. Vos données vous appartiennent. C'est plus qu'une promesse technique, c'est une promesse de liberté."*

