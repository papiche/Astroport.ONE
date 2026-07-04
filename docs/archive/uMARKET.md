# 🛒 uMARKET System - Marketplace Décentralisé UPlanet

## Vue d'Ensemble

Le système **uMARKET** est un marché décentralisé intégré à UPlanet qui permet aux utilisateurs de publier des annonces de vente/achat/échange via le tag `#market` dans des messages Nostr. Le système est actuellement **en refonte** pour s'intégrer pleinement avec les contrats ORE UMAP et profiter des évolutions du système d'identité décentralisée.

## État Actuel (À Refondre)

### Problèmes Identifiés

1. **Structure de données figée** : Stockage local dans des fichiers JSON au lieu d'utiliser les DIDs UMAP
2. **Pas d'intégration ORE** : Ne profite pas des contrats ORE pour la vérification et les récompenses
3. **Workflow non testé** : Implémentation figée, tests manquants
4. **Stockage décentralisé limité** : Dépendance aux fichiers locaux au lieu d'événements Nostr
5. **Pas de récompenses économiques** : Aucune intégration avec le système de récompenses Ẑen

### Architecture Actuelle (Obsolète)

```
Message Nostr avec #market
    ↓
NOSTR.UMAP.refresh.sh détecte le tag
    ↓
Télécharge images et crée JSON local
    ↓
_uMARKET.generate.sh compile les annonces
    ↓
Interface web statique
```

**Limitations** :

* Stockage local uniquement
* Pas de vérification via ORE
* Pas de récompenses économiques
* Pas d'identité décentralisée pour les annonceurs
* Pas d'intégration avec les contrats ORE UMAP

## Architecture Proposée (Refonte)

### Intégration avec ORE UMAP

Le nouveau système uMARKET s'appuiera sur :

1. **DIDs UMAP** : Chaque annonce est liée à un DID UMAP pour l'identité géographique
2. **Contrats ORE** : Les annonces peuvent être liées à des contrats ORE (ex: "vente de produits locaux certifiés")
3. **Événements Nostr** : Stockage décentralisé via événements Nostr (kind 30312/30313)
4. **Récompenses Ẑen** : Système de récompenses pour les annonceurs vérifiés
5. **Vérification ORE** : Vérification automatique de la conformité des annonces

### Nouveau Workflow Proposé

```
Message Nostr avec #market
    ↓
UPlanet_IA_Responder.sh détecte le tag
    ↓
Extraction des métadonnées (prix, catégorie, images)
    ↓
Création d'un événement Nostr (kind 30312 ou nouveau kind dédié)
    ↓
Publication sur le DID UMAP de la localisation
    ↓
Vérification ORE (optionnelle) pour annonces certifiées
    ↓
Intégration dans le document DID de l'UMAP
    ↓
Récompense Ẑen pour annonces vérifiées
    ↓
Interface web dynamique basée sur les événements Nostr
```

### Structure de Données Proposée

#### Événement Nostr pour Annonce (Kind 30312 ou nouveau kind)

```json
{
  "kind": 30312, // ORE Meeting Space (réutilisé pour annonces)
  "pubkey": "<UMAP_HEX>",
  "tags": [
    ["d", "market-ad-{lat}-{lon}-{timestamp}"],
    ["g", "{lat},{lon}"],
    ["t", "market"],
    ["t", "sale"], // ou "buy", "exchange", "service"
    ["price", "10"], // Prix en Ẑen
    ["category", "food"], // Catégorie
    ["ore-contract", "ORE-2025-001"], // Contrat ORE lié (optionnel)
    ["expires", "1735689600"] // Expiration (optionnel)
  ],
  "content": "{
    \"title\": \"Pommes bio du jardin\",
    \"description\": \"Pommes biologiques de mon jardin, 1 DU/kg\",
    \"images\": [\"ipfs://Qm...\"],
    \"seller_nprofile\": \"nostr:npub1...\",
    \"location\": {
      \"lat\": 48.85,
      \"lon\": 2.35
    },
    \"verified\": false,
    \"ore_verified\": false
  }"
}
```

#### Document DID UMAP avec Annonces

```json
{
  "@context": [
    "https://www.w3.org/ns/did/v1",
    "https://w3id.org/ore/v1",
    "https://w3id.org/umarket/v1"
  ],
  "id": "did:nostr:<umap_hex>",
  "type": "UMAPGeographicCell",
  "geographicMetadata": {
    "coordinates": {"lat": 48.85, "lon": 2.35}
  },
  "marketplace": {
    "active_ads": [
      {
        "event_id": "<nostr_event_id>",
        "type": "sale",
        "category": "food",
        "price": "10",
        "verified": false,
        "ore_verified": false
      }
    ],
    "total_ads": 5,
    "last_update": "2025-01-09T10:00:00Z"
  }
}
```

## Fonctionnalités Proposées

### 1. Publication d'Annonce

* **Tag `#market`** dans un message Nostr
* **Extraction automatique** des métadonnées (prix, catégorie, images)
* **Création d'événement Nostr** lié au DID UMAP
* **Vérification ORE optionnelle** pour annonces certifiées

### 2. Vérification et Certification

* **Vérification ORE** : Les annonces peuvent être liées à des contrats ORE
* **Certification automatique** : Annonces vérifiées via ORE Meeting Space
* **Badges de vérification** : Affichage dans l'interface web

### 3. Récompenses Économiques

* **Récompenses Ẑen** : Distribution automatique pour annonces vérifiées
* **Intégration avec UPLANET.official.sh** : Flux de récompenses
* **Portefeuille UMAP** : Les récompenses vont au portefeuille de l'UMAP

### 4. Interface Web Dynamique

* **Lecture depuis Nostr** : Interface basée sur les événements Nostr
* **Filtrage par UMAP** : Affichage des annonces par localisation
* **Recherche** : Par catégorie, prix, localisation
* **Vérification ORE** : Affichage des badges de vérification

### 5. Intégration avec ORE

* **Contrats ORE liés** : Annonces liées à des contrats ORE spécifiques
* **Vérification automatique** : Vérification de conformité via ORE Meeting Space
* **Récompenses conditionnelles** : Récompenses uniquement pour annonces vérifiées

## Événements Nostr Utilisés

### Kind 30312 (ORE Meeting Space) - Réutilisé pour Annonces

* **Tag `d`** : Identifiant unique de l'annonce
* **Tag `g`** : Coordonnées géographiques
* **Tag `t`** : Tags (`market`, `sale`, `buy`, `exchange`, `service`)
* **Tag `price`** : Prix en Ẑen
* **Tag `category`** : Catégorie de l'annonce
* **Tag `ore-contract`** : Contrat ORE lié (optionnel)
* **Tag `expires`** : Date d'expiration (optionnel)

### Kind 30313 (ORE Verification Meeting) - Vérification d'Annonce

* **Tag `a`** : Référence à l'annonce (kind 30312)
* **Tag `result`** : Résultat de la vérification (`verified`, `rejected`)
* **Content** : Détails de la vérification

### Kind 30800 (DID Document) - Métadonnées UMAP

* **Section `marketplace`** : Liste des annonces actives
* **Métadonnées** : Statistiques, dernières mises à jour

## Intégration avec ORE UMAP

### Avantages de l'Intégration

1. **Identité Décentralisée** : Utilisation des DIDs UMAP pour l'identité géographique
2. **Vérification ORE** : Vérification automatique via contrats ORE
3. **Récompenses Ẑen** : Système de récompenses intégré
4. **Stockage Décentralisé** : Événements Nostr au lieu de fichiers locaux
5. **Découverte** : Découverte via abonnements Nostr aux événements

### Flux de Vérification ORE

```
Annonce publiée (kind 30312)
    ↓
Lien avec contrat ORE (optionnel)
    ↓
Vérification via ORE Meeting Space (kind 30313)
    ↓
Résultat de vérification
    ↓
Récompense Ẑen si vérifiée
    ↓
Mise à jour du document DID UMAP
```

## Migration depuis l'Ancien Système

### Étapes de Migration

1. **Analyse des annonces existantes** : Inventaire des annonces locales
2. **Conversion en événements Nostr** : Création d'événements kind 30312
3. **Publication sur Nostr** : Publication des événements convertis
4. **Mise à jour des DIDs UMAP** : Intégration dans les documents DID
5. **Dépréciation de l'ancien système** : Arrêt des scripts locaux

## Documentation Technique

### Scripts à Refondre

* `_uMARKET.generate.sh` → Nouveau script basé sur événements Nostr
* `_uMARKET.aggregate.sh` → Utilisation d'abonnements Nostr
* `_uMARKET.test.sh` → Tests avec événements Nostr
* `NOSTR.UMAP.refresh.sh` → Détection et traitement des annonces

### Nouveaux Scripts à Créer

* `uMARKET_publish.sh` : Publication d'annonce via événement Nostr
* `uMARKET_verify.sh` : Vérification ORE d'une annonce
* `uMARKET_reward.sh` : Distribution de récompenses Ẑen
* `uMARKET_interface.sh` : Génération d'interface web depuis Nostr

## Références

* **ORE System** : [ORE\_SYSTEM.md](../explanation/ORE_SYSTEM.md)
* **DID Implementation** : [DID\_IMPLEMENTATION.md](https://github.com/papiche/Astroport.ONE/blob/master/DID_IMPLEMENTATION.md)
* **NIP-101** : [101.md](https://github.com/papiche/Astroport.ONE/blob/master/nostr-nips/101.md)
* **Ancien README** : [../tools/\_uMARKET.README.md](../../tools/_uMARKET.README.md)

## Statut

🔴 **À Refondre** : Le système actuel est figé et non testé. Une refonte complète est nécessaire pour s'intégrer avec les contrats ORE UMAP.

**Priorité** : Moyenne (après stabilisation des systèmes ORE et DID)
