# 🌳 Système de Crowdfunding Forêt Jardin

## Vue d'ensemble

Le système de Crowdfunding Forêt Jardin permet de gérer l'acquisition collective de terrains avec **plusieurs propriétaires ayant des intentions différentes** :

### Deux modes de sortie pour les propriétaires

| Mode | Symbole | Destination | Convertible € | Avantages |
|------|---------|-------------|---------------|-----------|
| **COMMONS** | 🤝 | UPLANETNAME_CAPITAL | ❌ Non | Accès à tous les lieux UPlanet ẐEN |
| **CASH** | 💶 | Paiement € depuis ASSETS | ✅ Oui | Liquidité immédiate |

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CAS D'USAGE : FORÊT JARDIN                               │
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

## Interface CLI

### Installation

```bash
chmod +x ~/.zen/Astroport.ONE/tools/CROWDFUNDING.sh
```

### Commandes disponibles

```bash
# Créer un nouveau projet
./CROWDFUNDING.sh create LAT LON "NOM_PROJET" "DESCRIPTION"

# Ajouter des propriétaires
./CROWDFUNDING.sh add-owner PROJECT_ID EMAIL commons 500  # Donation Ẑen
./CROWDFUNDING.sh add-owner PROJECT_ID EMAIL cash 1000    # Vente €

# Voir le statut
./CROWDFUNDING.sh status PROJECT_ID

# Enregistrer une contribution
./CROWDFUNDING.sh contribute PROJECT_ID EMAIL AMOUNT CURRENCY

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
# 1. Créer le projet "Forêt Enchantée"
./CROWDFUNDING.sh create 43.6047 1.4442 "Forêt Enchantée" "Forêt jardin collaborative"
# Output: CF-20250120-A1B2C3D4

# 2. Ajouter Alice (donation aux Communs)
./CROWDFUNDING.sh add-owner CF-20250120-A1B2C3D4 alice@example.com commons 500
# → 500 Ẑen iront vers UPLANETNAME_CAPITAL (non-convertible €)
# → Alice recevra accès à tous les lieux UPlanet ẐEN

# 3. Ajouter Bob (vente en €)
./CROWDFUNDING.sh add-owner CF-20250120-A1B2C3D4 bob@example.com cash 1000
# → Si ASSETS < 1000€ équivalent → Lance crowdfunding "Ẑ convertible €"
# → Si UPLANETNAME_G1 < 100 Ğ1 → Lance campagne don Ğ1

# 4. Vérifier le statut
./CROWDFUNDING.sh status CF-20250120-A1B2C3D4
```

---

## Interface Web

### Accès

```
https://[IPFS_GATEWAY]/ipns/copylaradio.com/crowdfunding.html
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
    "id": "CF-20250120-A1B2C3D4",
    "name": "Forêt Enchantée",
    "description": "Forêt jardin collaborative",
    "location": {
        "latitude": 43.6047,
        "longitude": 1.4442
    },
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
            "timestamp": "2025-01-20T10:30:00Z"
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
        ["title", "🌳 Crowdfunding: Forêt Enchantée"],
        ["t", "crowdfunding"],
        ["t", "UPlanet"],
        ["t", "commons"],
        ["t", "foret-jardin"],
        ["g", "43.6047,1.4442"],
        ["project-id", "CF-20250120-A1B2C3D4"]
    ],
    "content": "# 🌳 Forêt Enchantée\n\n..."
}
```

---

## Déclencheurs automatiques

### Campagne "Ẑen convertible €"

**Condition :** `ASSETS_BALANCE < CASH_EUR_NEEDED`

```bash
# Vérification automatique lors de add-owner
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
- **Docs** : `Astroport.ONE/docs/CROWDFUNDING_FORET_JARDIN.md`
- **321 DU** : `Astroport.ONE/321_DU.md` (système de vœux connexe)
- **UPLANET.official.sh** : `Astroport.ONE/UPLANET.official.sh`

---

*Documentation du système de Crowdfunding Forêt Jardin - UPlanet ẐEN*
