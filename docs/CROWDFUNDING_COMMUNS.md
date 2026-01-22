# 🌳 Système de Crowdfunding des Communs

## Vue d'ensemble

Le système de **Crowdfunding des Communs** permet de gérer l'acquisition collective de biens à transférer en gestion collective : terrains, forêts jardins, espaces de permaculture, locaux, équipements partagés, etc.

Le système gère **plusieurs propriétaires ayant des intentions différentes** :

### Deux modes de sortie pour les propriétaires

| Mode | Symbole | Destination | Convertible € | Avantages |
|------|---------|-------------|---------------|-----------|
| **COMMONS** | 🤝 | UPLANETNAME_CAPITAL | ❌ Non | Accès à tous les lieux UPlanet ẐEN |
| **CASH** | 💶 | Paiement € depuis ASSETS | ✅ Oui | Liquidité immédiate |

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CAS D'USAGE : BIEN COMMUN                                │
│                    2 propriétaires, 1 même armature                          │
└─────────────────────────────────────────────────────────────────────────────┘

     PROPRIÉTAIRE A                              PROPRIÉTAIRE B
     ─────────────                              ─────────────
     🤝 Mode COMMONS                            💶 Mode CASH
     Donation non-€                             Vente en €
           │                                          │
           ▼                                          ▼
   ┌───────────────┐                        ┌───────────────┐
   │ UPLANETNAME   │                        │   ASSETS      │
   │   CAPITAL     │                        │   (liquide)   │
   └───────────────┘                        └───────┬───────┘
           │                                        │
           │                                        │
           ▼                                        ▼
   ┌───────────────────────────────────────────────────────┐
   │   Si ASSETS insuffisant → CROWDFUNDING "Ẑ conv. €"   │
   │   Si UPLANETNAME_G1 < seuil → CAMPAGNE DON Ğ1        │
   └───────────────────────────────────────────────────────┘
```

---

## Types de biens éligibles

Le Crowdfunding des Communs peut financer :

| Catégorie | Exemples | Caractéristiques |
|-----------|----------|------------------|
| **🌳 Terrains naturels** | Forêts jardins, zones de permaculture, prairies | Usage collectif long terme |
| **🏠 Immobilier** | Locaux associatifs, ateliers partagés, habitats groupés | Infrastructure commune |
| **🔧 Équipements** | Machines-outils, véhicules, matériel agricole | Mutualisation des ressources |
| **💻 Numérique** | Serveurs, nœuds IPFS, stations Astroport | Infrastructure réseau |
| **🎨 Culturel** | Œuvres d'art, archives, patrimoine | Préservation collective |

---

## Architecture des Portefeuilles

### Portefeuilles impliqués

| Portefeuille | Fichier | Rôle dans le crowdfunding |
|--------------|---------|---------------------------|
| **UPLANETNAME_G1** | `~/.zen/tmp/UPLANETNAME_G1` | Source Ğ1 initiale, réappro si campagne |
| **UPLANETNAME_CAPITAL** | `uplanet.CAPITAL.dunikey` | Reçoit les donations Commons (non-convertible €) |
| **ASSETS** | `uplanet.ASSETS.dunikey` | Source pour paiements Cash (convertible €) |
| **CASH** | `uplanet.CASH.dunikey` | Réserve de trésorerie |

### Flux financiers

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         FLUX FINANCIERS                                      │
└─────────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────┐
                    │   CROWDFUNDING      │
                    │   Contributions     │
                    └──────────┬──────────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
          ▼                    ▼                    ▼
   ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
   │ Don Ğ1      │      │ Ẑen conv.€  │      │ Ẑen non-€   │
   │ (June)      │      │ (Liquidité) │      │ (Communs)   │
   └──────┬──────┘      └──────┬──────┘      └──────┬──────┘
          │                    │                    │
          ▼                    ▼                    ▼
   ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
   │ UPLANETNAME │      │   ASSETS    │      │   CAPITAL   │
   │     _G1     │      │             │      │             │
   └─────────────┘      └──────┬──────┘      └─────────────┘
                               │
                               ▼
                       ┌─────────────┐
                       │ PAIEMENT €  │
                       │ Propriétaire│
                       │   CASH      │
                       └─────────────┘
```

---

## 🔐 Identité du Bien (Bien Identity)

### Concept

Chaque projet crowdfunding ("Bien") possède **sa propre identité NOSTR et son propre wallet Ğ1**. Cela permet au Bien de :

1. **Recevoir des contributions +ZEN** directement via les réactions Nostr (kind 7)
2. **Publier des mises à jour** sur la campagne depuis son propre compte
3. **Avoir une traçabilité complète** des contributions sur la blockchain

### Dérivation des clés

Les clés du Bien sont **déterministes**, dérivées des coordonnées UMAP et de l'ID du projet :

```
BIEN_SALT   = ${UPLANETNAME}${LAT}_${PROJECT_ID}
BIEN_PEPPER = ${UPLANETNAME}${LON}_${PROJECT_ID}

Exemple:
  UPLANETNAME = "AstroGEMS"
  LAT = 43.60
  LON = 1.44
  PROJECT_ID = CF-20250122-A1B2

  BIEN_SALT   = "AstroGEMS43.60_CF-20250122-A1B2"
  BIEN_PEPPER = "AstroGEMS1.44_CF-20250122-A1B2"
```

### Clés générées

| Type | Outil | Usage |
|------|-------|-------|
| **NOSTR npub** | `keygen -t nostr SALT PEPPER` | Identité publique du Bien |
| **NOSTR nsec** | `keygen -t nostr SALT PEPPER -s` | Signature des publications |
| **NOSTR hex** | `nostr2hex.py NPUB` | Tag `["p", HEX]` pour réactions |
| **Ğ1 wallet** | `keygen -t duniter SALT PEPPER` | Réception des contributions |

### Fichiers générés

```
~/.zen/game/crowdfunding/{PROJECT_ID}/
├── project.json           # Métadonnées du projet (inclut bien_identity)
├── bien.pubkeys           # Clés publiques (NPUB, HEX, G1PUB)
├── bien.dunikey           # Wallet Ğ1 (chmod 600)
└── .bien.nostr            # Secret NOSTR (chmod 600)
```

### Commandes associées

```bash
# Les clés sont générées automatiquement à la création
./CROWDFUNDING.sh create 43.60 1.44 "Mon Projet" "Description"

# Publier le profil NOSTR du Bien
./CROWDFUNDING.sh publish-profile CF-20250122-XXXX

# Régénérer les clés (même résultat car déterministe)
./CROWDFUNDING.sh regenerate-keys CF-20250122-XXXX

# Vérifier le solde du wallet du Bien
./CROWDFUNDING.sh bien-balance CF-20250122-XXXX
```

### Réception des +ZEN

Les contributeurs envoient des +ZEN via les réactions Nostr (kind 7) en tagant le Bien :

```json
{
  "kind": 7,
  "content": "+50",
  "tags": [
    ["p", "BIEN_HEX_PUBKEY"],
    ["t", "crowdfunding"],
    ["t", "UPlanet"],
    ["project-id", "CF-20250122-XXXX"]
  ]
}
```

Le filtre `7.sh` détecte ces réactions et :
1. Valide le solde du contributeur
2. Exécute le transfert Ğ1 vers le wallet du Bien
3. Met à jour les totaux du projet

---

## Interface CLI

### Installation

```bash
chmod +x ~/.zen/Astroport.ONE/tools/CROWDFUNDING.sh
```

### Commandes disponibles

```bash
# Créer un nouveau projet (génère automatiquement l'identité du Bien)
./CROWDFUNDING.sh create LAT LON "NOM_PROJET" "DESCRIPTION"

# Publier le profil NOSTR du Bien
./CROWDFUNDING.sh publish-profile PROJECT_ID

# Régénérer les clés du Bien (résultat identique car déterministe)
./CROWDFUNDING.sh regenerate-keys PROJECT_ID

# Ajouter des propriétaires
./CROWDFUNDING.sh add-owner PROJECT_ID EMAIL commons 500  # Donation Ẑen
./CROWDFUNDING.sh add-owner PROJECT_ID EMAIL cash 1000    # Vente € (déclenche vote ASSETS)

# Voir le statut (inclut identité du Bien et solde)
./CROWDFUNDING.sh status PROJECT_ID

# Vérifier le solde du wallet du Bien
./CROWDFUNDING.sh bien-balance PROJECT_ID

# Enregistrer une contribution
./CROWDFUNDING.sh contribute PROJECT_ID EMAIL AMOUNT CURRENCY

# Voter pour utilisation des fonds ASSETS
./CROWDFUNDING.sh vote PROJECT_ID VOTER_PUBKEY AMOUNT
./CROWDFUNDING.sh vote-status PROJECT_ID

# Finaliser (exécuter les transferts)
./CROWDFUNDING.sh finalize PROJECT_ID

# Lister les projets
./CROWDFUNDING.sh list --active
./CROWDFUNDING.sh list --completed
./CROWDFUNDING.sh list --all

# Dashboard interactif
./CROWDFUNDING.sh dashboard
```

### Exemple complet

```bash
# 1. Créer le projet "Atelier Partagé"
./CROWDFUNDING.sh create 43.6047 1.4442 "Atelier Partagé" "Local de fabrication collaborative"
# Output: CF-20250122-A1B2C3D4
# → Génère automatiquement l'identité NOSTR et le wallet Ğ1 du Bien
# → Affiche: NOSTR npub, hex, et Ğ1 wallet

# 2. Publier le profil NOSTR du Bien
./CROWDFUNDING.sh publish-profile CF-20250122-A1B2C3D4
# → Le Bien devient visible sur NOSTR avec son profil
# → Peut recevoir des +ZEN via les réactions kind 7

# 3. Ajouter Alice (donation aux Communs)
./CROWDFUNDING.sh add-owner CF-20250122-A1B2C3D4 alice@example.com commons 500
# → 500 Ẑen iront vers UPLANETNAME_CAPITAL (non-convertible €)
# → Alice recevra accès à tous les lieux UPlanet ẐEN

# 4. Ajouter Bob (vente en €)
./CROWDFUNDING.sh add-owner CF-20250122-A1B2C3D4 bob@example.com cash 1000
# → Si ASSETS suffisant → Lance vote des sociétaires (status: vote_pending)
# → Si ASSETS insuffisant → Lance crowdfunding "Ẑ convertible €"
# → Si UPLANETNAME_G1 < 10000 Ğ1 → Lance campagne don Ğ1

# 5. Vérifier le statut du vote (si applicable)
./CROWDFUNDING.sh vote-status CF-20250122-A1B2C3D4
# → Affiche: progression du vote, quorum, seuil

# 6. Vérifier le statut complet
./CROWDFUNDING.sh status CF-20250122-A1B2C3D4
# → Affiche: identité du Bien, solde, propriétaires, campagnes

# 7. Vérifier les contributions reçues par le Bien
./CROWDFUNDING.sh bien-balance CF-20250122-A1B2C3D4
# → Affiche le solde du wallet Ğ1 du Bien

# 8. Après vote approuvé, finaliser
./CROWDFUNDING.sh finalize CF-20250122-A1B2C3D4
# → Exécute tous les transferts blockchain
```

---

## Interface Web

### Accès

```
https://[IPFS_GATEWAY]/ipns/copylaradio.com/crowdfunding.html
```

ou via l'application nostr.html :
```
Bouton 🌳 dans la barre supérieure → Crowdfunding des Communs
```

### Fonctionnalités

| Section | Description |
|---------|-------------|
| **Dashboard** | Vue d'ensemble des campagnes et stats |
| **Projets actifs** | Liste des crowdfundings en cours |
| **Créer projet** | Formulaire de création avec propriétaires |
| **Contribuer** | Modal avec QR code et adresse wallet |

---

## Structure des données

### Projet (JSON)

```json
{
    "id": "CF-20250122-A1B2C3D4",
    "name": "Atelier Partagé",
    "description": "Local de fabrication collaborative",
    "location": {
        "latitude": 43.6047,
        "longitude": 1.4442
    },
    "umap_id": "UMAP_43.60_1.44",
    "bien_identity": {
        "npub": "npub1xxx...xxx",
        "hex": "abc123...def",
        "g1pub": "GfCHe...xyz",
        "derivation": {
            "salt": "AstroGEMS43.6047_CF-20250122-A1B2C3D4",
            "pepper": "AstroGEMS1.4442_CF-20250122-A1B2C3D4"
        }
    },
    "bien_profile_published": true,
    "status": "crowdfunding",
    "owners": [
        {
            "email": "alice@example.com",
            "mode": "commons",
            "amount_zen": 500,
            "amount_eur": 0,
            "status": "pending"
        },
        {
            "email": "bob@example.com",
            "mode": "cash",
            "amount_zen": 0,
            "amount_eur": 1000,
            "status": "pending"
        }
    ],
    "vote": {
        "assets_vote_active": true,
        "assets_amount_zen": 1000,
        "vote_threshold": 100,
        "vote_quorum": 10,
        "votes_zen_total": 75,
        "voters_count": 8,
        "vote_status": "pending"
    },
    "totals": {
        "commons_zen": 500,
        "cash_eur": 1000,
        "zen_convertible_target": 1000,
        "zen_convertible_collected": 250,
        "g1_target": 150,
        "g1_collected": 45
    },
    "campaigns": {
        "zen_convertible_campaign_active": true,
        "g1_campaign_active": true
    },
    "contributions": [
        {
            "contributor_email": "charlie@example.com",
            "amount": 100,
            "currency": "ZEN",
            "timestamp": "2025-01-22T10:30:00Z"
        }
    ]
}
```

### Publication Nostr (kind 30023)

Les campagnes sont publiées sur Nostr pour visibilité :

```json
{
    "kind": 30023,
    "tags": [
        ["d", "crowdfunding-CF-20250120-A1B2C3D4"],
        ["title", "🌳 Crowdfunding: Atelier Partagé"],
        ["t", "crowdfunding"],
        ["t", "UPlanet"],
        ["t", "commons"],
        ["g", "43.6047,1.4442"],
        ["project-id", "CF-20250120-A1B2C3D4"]
    ],
    "content": "# 🌳 Atelier Partagé\n\n..."
}
```

---

## Système de Vote ASSETS

### Principe

L'utilisation des fonds ASSETS pour les rachats cash **n'est pas automatique**. Elle nécessite un **vote des sociétaires**.

Les sociétaires votent en envoyant des réactions Nostr (+Ẑen) avec le tag `vote-assets`.

### Conditions de validation

| Critère | Seuil par défaut | Description |
|---------|------------------|-------------|
| **Seuil Ẑen** | 100 Ẑen | Total des votes en Ẑen |
| **Quorum** | 10 votants | Nombre minimum de votants |

Le vote passe **uniquement** si les deux conditions sont remplies.

### Comment voter

Via l'interface web `crowdfunding.html` :
- Bouton 🗳️ "Voter (+Ẑen)" sur les projets en attente de vote
- Choisir le poids du vote (1, 5, 10, 20 Ẑen)

Via Nostr directement :
```json
{
    "kind": 7,
    "content": "+1",  // ou "+5", "+10", etc.
    "tags": [
        ["t", "vote-assets"],
        ["project-id", "CF-XXXXXXXX"],
        ["vote-type", "ASSETS_USAGE"]
    ]
}
```

Via CLI :
```bash
./CROWDFUNDING.sh vote CF-20250120-XXXX VOTER_PUBKEY 5
./CROWDFUNDING.sh vote-status CF-20250120-XXXX
```

### Flux de décision

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    FLUX DE VOTE ASSETS                                      │
└─────────────────────────────────────────────────────────────────────────────┘

  Propriétaire CASH ajouté
           │
           ▼
  ┌─────────────────┐
  │ ASSETS suffisant│──── NON ────► Crowdfunding "Ẑen conv. €"
  │   pour couvrir? │
  └────────┬────────┘
           │ OUI
           ▼
  ┌─────────────────┐
  │ 🗳️ VOTE LANCÉ   │
  │ Statut: pending │
  └────────┬────────┘
           │
           │ Sociétaires votent +Ẑen
           ▼
  ┌─────────────────────────────────┐
  │ Seuil Ẑen atteint?              │
  │ Quorum votants atteint?         │
  └────────────┬────────────────────┘
               │
       ┌───────┴───────┐
       │               │
    OUI + OUI       NON (un des deux)
       │               │
       ▼               ▼
  ┌────────────┐   ┌────────────────┐
  │ ✅ APPROUVÉ│   │ ⏳ EN ATTENTE  │
  │ → finalize │   │ (plus de votes)│
  └────────────┘   └────────────────┘
```

---

## Déclencheurs automatiques

### Vote ASSETS (nouveau)

**Condition :** `CASH_EUR_NEEDED > 0 AND ASSETS_BALANCE >= CASH_EUR_NEEDED`

```bash
# Si les fonds ASSETS peuvent couvrir les besoins cash
# Un vote est lancé au lieu d'utiliser automatiquement les fonds
jq ".vote = {
    \"assets_vote_active\": true,
    \"assets_amount_zen\": $zen_from_assets,
    \"vote_threshold\": $ASSETS_VOTE_THRESHOLD,
    \"vote_quorum\": $ASSETS_VOTE_QUORUM,
    \"vote_status\": \"pending\"
}" "$project_file"
```

### Campagne "Ẑen convertible €"

**Condition :** `ASSETS_BALANCE < CASH_EUR_NEEDED`

```bash
# Si ASSETS insuffisant → crowdfunding (pas de vote possible)
if [[ $(echo "$g1_for_cash > $assets_balance" | bc -l) -eq 1 ]]; then
    zen_shortfall=$(echo "scale=2; ($g1_for_cash - $assets_balance) * 10" | bc -l)
    # Lance campagne Ẑen convertible €
fi
```

### Campagne "Don Ğ1"

**Condition :** `UPLANETNAME_G1 < G1_LOW_THRESHOLD (100 Ğ1 par défaut)`

```bash
# Vérification automatique
G1_LOW_THRESHOLD=100
if [[ $(echo "$g1_balance < $G1_LOW_THRESHOLD" | bc -l) -eq 1 ]]; then
    # Lance campagne don Ğ1
fi
```

---

## Références blockchain

Format des commentaires de transaction :

| Type | Format | Exemple |
|------|--------|---------|
| **Contribution Ẑen** | `CF:{PROJECT_ID}:ZEN` | `CF:CF-20250120-A1B2:ZEN` |
| **Contribution Ğ1** | `CF:{PROJECT_ID}:G1` | `CF:CF-20250120-A1B2:G1` |
| **Commons out** | `UPLANET:{PUBKEY8}:COMMONS:{EMAIL}:{PROJECT_ID}:{IPFSNODEID}` | ... |
| **Cash out** | `UPLANET:{PUBKEY8}:CASHOUT:{EMAIL}:{PROJECT_ID}:{IPFSNODEID}` | ... |

---

## Intégration avec le système existant

### Lien avec UPLANET.official.sh

```bash
# Le crowdfunding utilise les mêmes mécanismes que UPLANET.official.sh
# pour les transferts finaux :

# Commons → CAPITAL (même logique que infrastructure)
./UPLANET.official.sh -i --add  # Ajoute au capital existant

# Cash → ASSETS → Propriétaire
./PAYforSURE.sh uplanet.ASSETS.dunikey MONTANT WALLET REFERENCE
```

### Mise à jour DID

Après finalisation, les DID des propriétaires sont mis à jour :

```bash
# Pour donation Commons
./did_manager_nostr.sh update EMAIL "COMMONS_CONTRIBUTION" MONTANT_ZEN MONTANT_G1

# Pour réception Cash
# (Pas de mise à jour DID spécifique, juste transaction blockchain)
```

---

## Conformité légale

### Modèle économique

Ce système respecte le modèle coopératif UPlanet :

1. **Donations Commons** : Non-convertibles €, créent des droits d'usage partagés
2. **Ventes Cash** : Nécessitent liquidité réelle, traçabilité blockchain
3. **Crowdfunding** : Financement participatif avec transparence totale

### Traçabilité

Toutes les transactions sont enregistrées :
- Sur la blockchain Ğ1 (Duniter)
- Sur Nostr (événements kind 30023)
- Dans les fichiers locaux (`~/.zen/game/crowdfunding/`)

---

## Liens utiles

- **CLI** : `Astroport.ONE/tools/CROWDFUNDING.sh`
- **Web** : `UPlanet/earth/crowdfunding.html`
- **Docs** : `Astroport.ONE/docs/CROWDFUNDING_COMMUNS.md`
- **Contract** : `Astroport.ONE/docs/UPlanet_CROWDFUNDING_CONTRACT.md`
- **321 DU** : `Astroport.ONE/321_DU.md` (système de vœux connexe)
- **UPLANET.official.sh** : `Astroport.ONE/UPLANET.official.sh`

---

*Documentation du système de Crowdfunding des Communs - UPlanet ẐEN*
