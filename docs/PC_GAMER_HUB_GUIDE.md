# 🎮 Transformez votre PC Gamer en Hub Économique Décentralisé

## Introduction : Votre Machine, Votre Revenu

Vous possédez un PC Gamer puissant qui dort la plupart du temps ? Transformez-le en **Hub Central** de l'écosystème UPlanet ẐEN et générez des revenus passifs tout en participant à la construction d'un Internet décentralisé.

Ce guide vous explique comment installer **Astroport.ONE** sur votre machine et la connecter à l'essaim local via **WireGuard VPN** pour devenir **Armateur** et **Capitaine** de votre propre constellation.

---

## 🏗️ Architecture : Le Rôle du Hub PC Gamer

```
┌─────────────────────────────────────────────────────────────┐
│                    VOTRE PC GAMER (HUB)                     │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   OLLAMA    │  │  COMFYUI    │  │ PERPLEXICA  │   IA     │
│  │  LLM Local  │  │ Image Gen   │  │  Recherche  │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              ASTROPORT.ONE                          │    │
│  │  • IPFS Node (stockage décentralisé)                │    │
│  │  • NextCloud (128Go/sociétaire)                     │    │
│  │  • TiddlyWiki (ZEN Cards)                           │    │
│  │  • NOSTR Relay (MULTIPASS)                          │    │
│  └─────────────────────────────────────────────────────┘    │
│                           │                                 │
│                    WireGuard VPN                            │
│                    (10.99.99.0/24)                          │
└───────────────────────────┬─────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
   ┌────▼────┐         ┌────▼────┐         ┌────▼────┐
   │Satellite│         │Satellite│         │Satellite│
   │  RPi 5  │         │  RPi 5  │         │  RPi 5  │
   └─────────┘         └─────────┘         └─────────┘
```

### Capacité d'un Hub PC Gamer

| Ressource | Capacité | Équivalent Immobilier |
|-----------|----------|----------------------|
| Sociétaires (ZEN Cards) | **24 max** | Copropriétaires |
| Locataires (MULTIPASS) | **250+ max** | Studios numériques |
| Stockage NextCloud | **128 Go × 24** | Appartements premium |
| Stockage uDRIVE | **10 Go × 250** | Studios décentralisés |

---

## 💰 Modèle Économique : Vos Revenus

### Investissement Initial

| Élément | Valeur |
|---------|--------|
| PC Gamer (occasion) | ~2000€ |
| Capital ẐEN initial | **2000 Ẑen** |

### Revenus Hebdomadaires

```
┌─────────────────────────────────────────────────────────────┐
│                  FLUX ÉCONOMIQUES HEBDO                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  MULTIPASS (250 locataires)                                 │
│  └── 250 × 1 Ẑ/semaine = 250 Ẑ HT                           │
│  └── TVA collectée : 50 Ẑ (20%)                             │
│                                                             │
│  ZEN Cards (24 sociétaires)                                 │
│  └── 24 × 4 Ẑ/semaine = 96 Ẑ HT                             │
│  └── TVA collectée : 19.2 Ẑ (20%)                           │
│                                                             │
│  TOTAL REVENUS BRUTS : 346 Ẑ/semaine                        │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  CHARGES                                                    │
│  └── PAF (Armateur) : -14 Ẑ/semaine                         │
│  └── Rémunération Capitaine : 28 Ẑ/semaine                  │
│  └── TVA à reverser : -69.2 Ẑ/semaine                       │
│                                                             │
│  SURPLUS COOPÉRATIF : ~234 Ẑ/semaine                        │
│  └── 1/3 Trésorerie : 78 Ẑ                                  │
│  └── 1/3 R&D : 78 Ẑ                                         │
│  └── 1/3 Actifs (Forêts/Jardins) : 78 Ẑ                     │
└─────────────────────────────────────────────────────────────┘
```

### Simulation Annuelle (Hub PC Gamer complet)

| Poste | Calcul | Montant |
|-------|--------|---------|
| Revenus locatifs bruts | 346 Ẑ × 52 sem | **17 992 Ẑ/an** |
| Rémunération Capitaine | 28 Ẑ × 52 sem | **1 456 Ẑ/an** |
| Conversion possible en € | ~12 000 Ẑ | **~12 000€/an** |

> **Parité fixe :** 1 Ẑen = 0.1 Ğ1 ≈ 1€

---

## 🔐 Installation : Connexion à l'Essaim via WireGuard

### Étape 1 : Installer Astroport.ONE

```bash
# Cloner le dépôt
git clone https://github.com/papinou/Astroport.ONE.git
cd Astroport.ONE

# Lancer l'installation
./install.sh
```

### Étape 2 : Configurer le Hub WireGuard

Votre PC Gamer devient le **HUB VPN** de l'essaim local.

```bash
# Installer WireGuard
sudo apt install wireguard qrencode curl

# Lancer le gestionnaire WireGuard
cd tools
./wireguard_control.sh
```

**Menu Principal :**
```
╔══════════════════════════════════════════════════════════════════════════════╗
║                          WIREGUARD LAN MANAGER                                ║
╚══════════════════════════════════════════════════════════════════════════════╝

1. 🚀 Initialiser serveur LAN     ← Première étape
2. 👥 Ajouter un client LAN
3. 🗑️  Supprimer un client
4. 📋 Liste des clients
5. 📖 Expliquer configuration client
6. 📱 Générer QR code client
7. 🔄 Redémarrer service
8. ❌ Quitter
```

**Option 1 : Initialiser le serveur**

Le script configure automatiquement :
- Génération des clés WireGuard
- Réseau VPN : `10.99.99.0/24`
- Port : `51820`
- Règles iptables pour le NAT

```
✅ Serveur configuré avec succès
Port: 51820
Réseau: 10.99.99.0/24
Clé publique serveur: <votre_clé_publique>
```

### Étape 3 : Ajouter des Satellites (RPi)

Chaque Raspberry Pi de l'essaim doit se connecter au Hub.

**Sur le Hub (votre PC) :**
```bash
./wireguard_control.sh → Option 2 (Ajouter un client)
# Nom : rpi-satellite-1
# Clé publique : <clé du satellite>
```

**Sur le Satellite (RPi) :**
```bash
cd Astroport.ONE/tools
./wg-client-setup.sh
```

Entrez les informations :
- Adresse du serveur : `<IP_publique_du_hub>`
- Port : `51820`
- Clé publique serveur : `<clé_affichée_par_le_hub>`
- IP VPN attribuée : `10.99.99.X/32`

### Étape 4 : Vérifier la Connexion

```bash
# Sur le Hub
sudo wg show

# Résultat attendu
interface: wg0
  public key: <clé_publique>
  private key: (hidden)
  listening port: 51820

peer: <clé_satellite_1>
  endpoint: <ip:port>
  allowed ips: 10.99.99.2/32
  latest handshake: X seconds ago
  transfer: X.XX MiB received, X.XX MiB sent

# Test de connectivité
ping 10.99.99.2
```

---

## 📱 Services pour les Membres

### MULTIPASS : Le Passeport Numérique (Locataire)

> **"Je paie 1 Ẑen/semaine et je gagne ma liberté numérique."**

| Service | Description |
|---------|-------------|
| Identité NOSTR | Clé publique souveraine |
| Stockage uDRIVE | 10 Go décentralisé sur IPFS |
| Terminal Astroport | Interface de gestion |
| Gains par création | 1 Like = 1 Ẑen sur Coracle |

**Coût :** 1 Ẑ/semaine HT + 0.2 Ẑ TVA = **1.2 Ẑ/semaine** (~5€/mois)

### ZEN Card : Parts Sociales (Copropriétaire)

> **"J'investis 50€, je deviens co-propriétaire avec 128 Go de cloud privé."**

| Service | Description |
|---------|-------------|
| Parts sociales | 50 Ẑen (copropriété) |
| NextCloud privé | 128 Go de stockage cloud |
| Astrobot | Identité numérique personnelle |
| Droit de vote | Participation aux décisions |
| Exemption loyer | 1 an inclus dans les parts |

**Coût après 1ère année :** 4 Ẑ/semaine HT + 0.8 Ẑ TVA = **4.8 Ẑ/semaine** (~20€/mois)

---

## 🤖 Services IA via l'Essaim

Votre Hub PC Gamer peut héberger des services IA accessibles à tout l'essaim :

### Ollama (LLM Local)
```bash
# Vérifier/établir la connexion
./IA/ollama.me.sh

# Tester l'API
./IA/ollama.me.sh TEST

# Découvrir les nœuds disponibles
./IA/ollama.me.sh DISCOVER
```

### ComfyUI (Génération d'Images)
```bash
# Connexion automatique
./IA/comfyui.me.sh

# Générer une image
./IA/comfyui.me.sh "A futuristic decentralized network visualization"
```

### Perplexica (Recherche IA)
```bash
./IA/perplexica.me.sh
```

**Architecture de connexion IA :**
```
1. Port local déjà ouvert ?  ────────────────────► OK
           │
           ▼ non
2. SSH scorpio IPv6 (port 22) ───────────────────► OK
           │
           ▼ échec
3. SSH scorpio IPv4 (port 2122 NAT) ─────────────► OK
           │
           ▼ échec
4. IPFS P2P swarm ZEN[0] ────────────────────────► OK
           │
           ▼ échec
5. Erreur : aucun service disponible
```

---

## 📊 Tableau de Bord Fiscal

Le système génère automatiquement vos justificatifs comptables :

### Export 1 : Registre des Recettes

| Date | Libellé | Montant Ẑen | Montant EUR | Justificatif |
|------|---------|-------------|-------------|--------------|
| 15/02/2025 | Rémunération Capitaine | 300 Ẑen | 300,00 € | [OpenCollective] |
| 28/03/2025 | PAF Armateur | 50 Ẑen | 50,00 € | [OpenCollective] |

### Export 2 : Relevé Compte Courant

| Date | Opération | Revenus | Charges | Solde Capital |
|------|-----------|---------|---------|---------------|
| 07/01/2025 | Paiement PAF | +100 Ẑ | -14 Ẑ | 2086 Ẑen |

---

## 🔗 Architecture Multi-Hubs

### Essaim IPFS : Plusieurs Hubs Possibles

Rien n'empêche plusieurs PC Gamers de rejoindre le **même essaim IPFS privé** en partageant la même `swarm.key` :

```
┌─────────────────────────────────────────────────────────────┐
│                    ESSAIM IPFS PRIVÉ                        │
│                   (même swarm.key)                          │
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │ PC Gamer │◄──►│ PC Gamer │◄──►│ PC Gamer │   HUBS      │
│  │  HUB A   │    │  HUB B   │    │  HUB C   │              │
│  └────┬─────┘    └────┬─────┘    └────┬─────┘              │
│       │               │               │                     │
│  ┌────┴────┐     ┌────┴────┐     ┌────┴────┐               │
│  │ RPi x8  │     │ RPi x8  │     │ RPi x8  │  SATELLITES   │
│  └─────────┘     └─────────┘     └─────────┘               │
│                                                             │
│  ► Réplication IPFS entre tous les nœuds                   │
│  ► Load balancing automatique des services IA              │
│  ► Redondance et haute disponibilité                       │
└─────────────────────────────────────────────────────────────┘
```

### Avantages Multi-Hubs

| Avantage | Description |
|----------|-------------|
| **Redondance** | Si un Hub tombe, les autres prennent le relais |
| **Load balancing** | Distribution de charge IA (Ollama, ComfyUI) |
| **Géo-distribution** | Hubs dans différentes zones géographiques |
| **Scalabilité** | Ajout de puissance GPU à volonté |

### Topologie WireGuard : Mesh ou Hub-and-Spoke

**Option 1 : Hub-and-Spoke (Simple)**
```
Chaque Hub gère ses propres satellites via WireGuard
Hub A (10.99.99.0/24) ─► Satellites A
Hub B (10.99.98.0/24) ─► Satellites B
```

**Option 2 : Full Mesh (Avancé)**
```
Tous les Hubs interconnectés en VPN mesh
Hub A ◄─────► Hub B ◄─────► Hub C
  │             │             │
  ▼             ▼             ▼
Satellites   Satellites   Satellites
```

### Coordination Multi-Hubs

Pour éviter les conflits, chaque Hub doit avoir :
- **Son propre sous-réseau WireGuard** (10.99.99.x, 10.99.98.x, etc.)
- **Sa propre plage d'IP MULTIPASS/ZEN Cards**
- **Coordination via IPFS pubsub** pour les services partagés

---

## ⏰ Synchronisation Solaire : Le Rendez-vous 20H12

### Principe : Chaque Station à son Heure Solaire

Toutes les stations Astroport se synchronisent quotidiennement à **20H12 heure SOLAIRE locale**. Ce n'est pas l'heure légale, mais l'heure réelle du soleil à votre position géographique.

```
┌─────────────────────────────────────────────────────────────────┐
│              SYNCHRONISATION SOLAIRE 20H12                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Paris (LON=2.35°)        Brest (LON=-4.48°)                   │
│   Solar 20h12 = 21:04      Solar 20h12 = 21:31                  │
│   (été UTC+2)              (été UTC+2)                          │
│                                                                  │
│   ┌──────┐                 ┌──────┐                             │
│   │ HUB  │◄── 27 min ───►│ HUB  │                              │
│   │Paris │    décalage    │Brest │                              │
│   └──────┘                 └──────┘                             │
│      │                        │                                  │
│   20h12 solaire            20h12 solaire                        │
│   = même position          = même position                      │
│     du soleil                du soleil                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Configuration GPS du Capitaine

Le Capitaine déclare sa position dans `~/.zen/GPS` :

```bash
# Fichier ~/.zen/GPS
LAT=48.8566    # Latitude (Paris)
LON=2.3522     # Longitude (Paris)
```

Le script `cron_VRFY.sh` calcule automatiquement l'heure légale correspondant à 20H12 solaire :

```bash
# Calibration automatique
./tools/cron_VRFY.sh ON

# Résultat :
# .... Calibrating to ~/.zen/GPS SOLAR 20H12
#      LAT=48.8566 LON=2.3522
#      Solar 20h12 = Legal time 21:04
# ✅ ASTROPORT is ON
#    - 20h12 cron: ENABLED (solar time: 4 21)
```

### Modes de Fonctionnement

| Mode | 20H12 Cron | IPFS | API | Usage |
|------|------------|------|-----|-------|
| **ON** | ✅ | 24/7 | ✅ | Hub permanent (PC Gamer) |
| **LOW** | ✅ | 1h/jour | ❌ | Capteurs ORE / Satellites économes |
| **OFF** | ❌ | ❌ | ❌ | Station inactive |

```bash
# Activer le mode complet (Hub)
./tools/cron_VRFY.sh ON

# Mode économe (Capteurs ORE sur batterie/solaire)
./tools/cron_VRFY.sh LOW

# Désactiver complètement
./tools/cron_VRFY.sh OFF
```

### Mode LOW : Capteurs ORE Environnementaux

Le mode **LOW** est conçu pour les **capteurs ORE** (Obligations Réelles Environnementales) qui surveillent des parcelles géographiques (UMAP) :

```
┌─────────────────────────────────────────────────────────────────┐
│                    CAPTEUR ORE (Mode LOW)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  🌳 Parcelle UMAP (0.01° × 0.01° ≈ 1.2 km²)                     │
│                                                                  │
│  ┌─────────────────┐                                            │
│  │  Raspberry Pi   │  ← Alimentation solaire/batterie           │
│  │  + Capteurs     │                                            │
│  │  • Température  │                                            │
│  │  • Humidité     │                                            │
│  │  • CO2          │                                            │
│  │  • Caméra       │                                            │
│  └────────┬────────┘                                            │
│           │                                                      │
│           ▼                                                      │
│  ┌─────────────────────────────────────────┐                    │
│  │ 20H12 Solaire (1h de sync/jour)         │                    │
│  │                                          │                    │
│  │ 1. Démarrage IPFS                       │                    │
│  │ 2. Publication mesures (Kind 30312)     │                    │
│  │ 3. Sync constellation                   │                    │
│  │ 4. Arrêt IPFS (économie énergie)        │                    │
│  └─────────────────────────────────────────┘                    │
│                                                                  │
│  ► Consommation : ~2W en veille, ~5W pendant sync              │
│  ► Autonomie : Panneau solaire 10W + batterie 12V              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Événements NOSTR publiés par les Capteurs ORE

| Kind | Type | Description |
|------|------|-------------|
| **30800** | DID Document | Identité de l'UMAP (NIP-101) |
| **30312** | ORE Meeting Space | Espace géographique pour vérifications |
| **30313** | ORE Verification | Réunion de vérification planifiée |
| **30009** | Badge Definition | Définition des badges ORE |
| **8** | Badge Award | Attribution de badge après vérification |

### Cycle de Vérification ORE

```
┌─────────────────────────────────────────────────────────────────┐
│              VÉRIFICATION ORE AUTOMATISÉE                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  CAPTEUR (Mode LOW)              HUB (Mode ON)                  │
│       │                               │                          │
│       │ 20H12: Publie mesures         │                          │
│       │ (température, humidité...)    │                          │
│       │──────────────────────────────►│                          │
│       │                               │                          │
│       │                    Analyse conformité ORE               │
│       │                    (couverture forestière, etc.)        │
│       │                               │                          │
│       │         Récompense Ẑen        │                          │
│       │◄──────────────────────────────│                          │
│       │ (UPLANETNAME_ASSETS → UMAP)   │                          │
│       │                               │                          │
│  Portefeuille UMAP                    │                          │
│  crédité automatiquement              │                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Avantage Économique ORE

| Critère | ORE Notarié | ORE UPlanet |
|---------|-------------|-------------|
| Coût initial | 6 500 - 19 000 € | < 1 € |
| Coût annuel | 1 000 - 3 000 € | ~ 0 € |
| Délai | 6-12 mois | 5 minutes |
| Vérification | Expertise coûteuse | Capteurs automatiques |

### Ce qui se passe à 20H12 Solaire

```
┌─────────────────────────────────────────────────────────────────┐
│                   20H12.PROCESS.SH                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. SYNCHRONISATION NOSTR                                        │
│     └── Relai des événements NOSTR vers l'essaim                │
│     └── Backup des profils MULTIPASS/ZEN Cards                  │
│                                                                  │
│  2. SYNCHRONISATION IPFS                                         │
│     └── Pin des contenus prioritaires                           │
│     └── Garbage collection des anciens pins                     │
│     └── Réplication inter-nœuds                                 │
│                                                                  │
│  3. ÉCONOMIE ẐEN                                                 │
│     └── Collecte des loyers (MULTIPASS, ZEN Cards)              │
│     └── Paiement PAF (Participation Aux Frais)                  │
│     └── Allocation coopérative 3×1/3                            │
│                                                                  │
│  4. CONSTELLATION                                                │
│     └── Découverte des nouveaux nœuds                           │
│     └── Mise à jour de la carte de l'essaim                     │
│     └── Synchronisation des services IA disponibles             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🛰️ Architecture Hub + 24 Satellites

### Le Hub : Centre de Coordination

Un **Hub PC Gamer** peut accueillir jusqu'à **24 Satellites** qui assurent :
- **Relai NOSTR** : Distribution des événements sociaux
- **Passerelle IPFS** : Accès aux contenus décentralisés
- **Services locaux** : MULTIPASS, ZEN Cards pour leur zone

```
┌─────────────────────────────────────────────────────────────────┐
│                         HUB PC GAMER                             │
│                    (NOSTR Relay + IPFS Gateway)                  │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Services IA (GPU)     │  Services Économiques          │    │
│  │  • Ollama (LLM)        │  • Collecte loyers             │    │
│  │  • ComfyUI (Images)    │  • Distribution PAF            │    │
│  │  • Perplexica (Search) │  • Allocation 3×1/3            │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                   │
│                    WireGuard VPN (10.99.99.0/24)                │
│                              │                                   │
├──────────────────────────────┴──────────────────────────────────┤
│                        24 SATELLITES                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐        │
│  │RPi #1  │ │RPi #2  │ │RPi #3  │ │RPi #4  │ │  ...   │        │
│  │10.99.  │ │10.99.  │ │10.99.  │ │10.99.  │ │10.99.  │        │
│  │99.2    │ │99.3    │ │99.4    │ │99.5    │ │99.X    │        │
│  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘        │
│      │          │          │          │          │              │
│   NOSTR      NOSTR      NOSTR      NOSTR      NOSTR            │
│   Relay      Relay      Relay      Relay      Relay            │
│      +          +          +          +          +              │
│   IPFS       IPFS       IPFS       IPFS       IPFS             │
│   Gateway   Gateway    Gateway    Gateway    Gateway            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Rôle des Satellites

| Fonction | Description |
|----------|-------------|
| **Relai NOSTR** | Reçoit et redistribue les événements NOSTR locaux |
| **Passerelle IPFS** | Sert de point d'accès IPFS pour sa zone géographique |
| **Stockage local** | uDRIVE (10Go) + NextCloud (128Go) pour ses membres |
| **Mode LOW** | Sync 1×/jour à 20H12 solaire pour économiser les ressources |

### Capacité Totale d'un Essaim

| Élément | Par Satellite | Hub + 24 Satellites |
|---------|---------------|---------------------|
| Sociétaires (ZEN Cards) | 10 | **24 + 240 = 264** |
| Locataires (MULTIPASS) | 50 | **250 + 1200 = 1450** |
| Stockage NextCloud | 1 To | **~25 To** |
| Stockage uDRIVE (IPFS) | 500 Go | **~12 To** |

---

## 🚀 Démarrage Rapide (15 minutes)

```bash
# 1. Cloner et installer Astroport.ONE
git clone https://github.com/papinou/Astroport.ONE.git
cd Astroport.ONE && ./install.sh

# 2. Initialiser le Hub WireGuard
cd tools && ./wireguard_control.sh
# → Option 1 : Initialiser serveur LAN

# 3. Noter la clé publique serveur affichée

# 4. Sur chaque Satellite (RPi) :
./wg-client-setup.sh auto <IP_HUB> 51820 <CLÉ_SERVEUR> 10.99.99.X

# 5. Retour sur le Hub : ajouter les clients
./wireguard_control.sh → Option 2

# 6. Vérifier les connexions
sudo wg show
ping 10.99.99.2
```

---

## 🔐 MULTIPASS : La Toile de Confiance Humaine

### Authentification Web3 basée sur la Ğ1

Le système **MULTIPASS** utilise la [Monnaie Libre Ğ1](https://monnaie-libre.fr) comme socle d'authentification. Chaque membre est vérifié par 5 personnes de confiance, créant une **toile de confiance humaine** (Web of Trust).

```
┌─────────────────────────────────────────────────────────────────┐
│                    TOILE DE CONFIANCE Ğ1                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│              ┌───────────┐                                       │
│         ┌────┤ Certifié  ├────┐                                  │
│         │    │  par 5+   │    │                                  │
│         ▼    └───────────┘    ▼                                  │
│    ┌─────────┐           ┌─────────┐                             │
│    │ Membre  │◄─────────►│ Membre  │                             │
│    │   Ğ1    │           │   Ğ1    │                             │
│    └────┬────┘           └────┬────┘                             │
│         │                     │                                  │
│         ▼                     ▼                                  │
│    ┌─────────┐           ┌─────────┐                             │
│    │MULTIPASS│           │MULTIPASS│     Identité NOSTR          │
│    │  npub   │           │  npub   │     + Wallet Ğ1             │
│    └─────────┘           └─────────┘                             │
│                                                                  │
│    ► Chaque humain = 1 identité vérifiée                        │
│    ► Pas de bots, pas de faux comptes                           │
│    ► Authentification NIP-42 sur les relais NOSTR               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Création d'un MULTIPASS

```bash
# Via l'API UPassport
POST /g1nostr
{
    "email": "user@example.com",
    "lat": "48.8566",
    "lon": "2.3522",
    "salt": "secret1",    # Optionnel
    "pepper": "secret2"   # Optionnel
}

# Résultat : Création simultanée de
# - Clé Ğ1 (wallet Duniter)
# - Clé NOSTR (npub/nsec)
# - DID Document (NIP-101)
# - Stockage uDRIVE (10 Go IPFS)
```

### Authentification NIP-42

Les applications Web3 utilisent l'authentification **NIP-42** pour vérifier l'identité :

```javascript
// Connexion utilisateur via extension NOSTR ou clé nsec
const pubkey = await connectNostr();

// L'API vérifie l'authentification
const response = await fetch(`${window.uSPOT}/api/test-nostr`, {
    method: 'POST',
    body: new FormData().append('npub', pubkey)
});

// Résultat
{
    "status": "success",
    "message": "NIP-42 authentication successful",
    "npub": "npub1...",
    "hex": "60c1133d...",
    "relay": "wss://relay.copylaradio.com"
}
```

### Applications Web3 sur la Toile de Confiance

| Application | Description | Authentification |
|-------------|-------------|------------------|
| **NostrTube** | Plateforme vidéo décentralisée | MULTIPASS + NIP-42 |
| **UPlanet ORE** | Certification environnementale | MULTIPASS + Oracle |
| **UMAP Chat** | Chat géolocalisé (NIP-28) | MULTIPASS + GPS |
| **ZEN Economy** | Transactions économiques | MULTIPASS + Ğ1 |
| **Flora Stats** | Observations botaniques | MULTIPASS + Badges |

### Synchronisation Constellation

Le Hub synchronise les événements NOSTR de tous les membres via `backfill_constellation.sh` :

```
┌─────────────────────────────────────────────────────────────────┐
│              RAPPORT DE SYNCHRONISATION CONSTELLATION            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  📊 Statistiques du dernier sync (20H12 solaire)                │
│                                                                  │
│  • Peers connectés : 45/50 (90%)                                │
│  • Événements collectés : 12,450                                │
│  • Événements importés : 3,200                                  │
│                                                                  │
│  📨 Types de messages synchronisés :                            │
│  • Profils (kind 0) : 150                                       │
│  • Notes (kind 1) : 2,500                                       │
│  • DMs (kind 4) : 450                                           │
│  • Vidéos (kind 21/22) : 85                                     │
│  • Commentaires (kind 1111) : 320                               │
│  • Tags (kind 1985) : 180                                       │
│  • DID Documents (kind 30800) : 45                              │
│  • Oracle Permits (kind 30500-30503) : 25                       │
│  • ORE Contracts (kind 30312-30313) : 12                        │
│  • Badge Awards (kind 8) : 35                                   │
│                                                                  │
│  ⏰ Temps de sync : 45s                                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Avantages de la Toile de Confiance

| Aspect | Web2 Classique | MULTIPASS + Ğ1 |
|--------|----------------|----------------|
| **Identité** | Email + mot de passe | Clé cryptographique + 5 certifications |
| **Vérification** | CAPTCHA, SMS | Rencontre humaine IRL |
| **Anti-Sybil** | ❌ Bots possibles | ✅ 1 humain = 1 compte |
| **Propriété** | Plateforme | Utilisateur (auto-hébergé) |
| **Censure** | ❌ Modération centralisée | ✅ Décentralisé (NOSTR) |
| **Données** | Vendues aux annonceurs | Chiffrées sur IPFS |
| **Économie** | Fiat (banques) | Ğ1 + ẐEN (crypto libre) |

### Intégration dans votre Hub

```bash
# Votre Hub PC Gamer héberge automatiquement :

1. NOSTR Relay (strfry)
   └── Authentification NIP-42 des membres
   └── Stockage des événements (profils, notes, vidéos...)

2. IPFS Gateway
   └── Stockage des fichiers (uDRIVE 10Go/membre)
   └── NextCloud (128Go/sociétaire)

3. UPassport API
   └── Création de MULTIPASS
   └── Vérification d'identité
   └── Gestion des DID (NIP-101)

4. Sync Constellation
   └── Synchronisation inter-nœuds à 20H12 solaire
   └── Rapport d'activité quotidien
   └── Découverte des nouveaux membres
```

### Exemple : Authentification pour Upload Vidéo

```javascript
// 1. Utilisateur connecte son MULTIPASS
const pubkey = await connectNostr();

// 2. Récupération des infos utilisateur
const email = await fetchUserEmailWithFallback(pubkey);
const gps = await fetch(`/api/myGPS?npub=${pubkey}`).then(r => r.json());

// 3. Upload avec authentification
const formData = new FormData();
formData.append('file', videoFile);
formData.append('npub', pubkey);

const result = await fetch('/api/fileupload', {
    method: 'POST',
    body: formData
});

// 4. Publication sur NOSTR (kind 21/22)
if (result.success) {
    formData.append('ipfs_cid', result.new_cid);
    formData.append('latitude', gps.coordinates.lat);
    formData.append('longitude', gps.coordinates.lon);
    formData.append('publish_nostr', 'true');
    
    await fetch('/webcam', { method: 'POST', body: formData });
}

// → Vidéo publiée avec identité vérifiée
// → Géolocalisée sur l'UMAP de l'utilisateur
// → Synchronisée sur tous les nœuds de la constellation
```

---

## 🎓 WoTx2 : Certification des Savoir-Faire

### Toiles de Confiance pour les Compétences

Le système **WoTx2** (Web of Trust eXtended 2) permet la certification décentralisée des compétences via des **maîtrises auto-proclamées** qui évoluent par validation des pairs.

```
┌─────────────────────────────────────────────────────────────────┐
│                    SYSTÈME WOTX2                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  CRÉATION LIBRE DE MAÎTRISES                                    │
│  └── N'importe qui peut créer une maîtrise                      │
│  └── Ex: "Maître Nageur", "Permaculture", "Arduino"...          │
│                                                                  │
│  PROGRESSION AUTOMATIQUE ILLIMITÉE                              │
│                                                                  │
│  ┌───────┐    ┌───────┐    ┌───────┐    ┌───────┐              │
│  │  X1   │───►│  X2   │───►│  X3   │───►│  Xn   │───► ...      │
│  │1 sign.│    │2 sign.│    │3 sign.│    │N sign.│              │
│  └───────┘    └───────┘    └───────┘    └───────┘              │
│                                                                  │
│  LABELS DYNAMIQUES                                              │
│  • X1-X4   : Apprenti                                           │
│  • X5-X10  : Expert                                             │
│  • X11-X50 : Maître                                             │
│  • X51-X100: Grand Maître                                       │
│  • X101+   : Maître Absolu                                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Workflow de Certification

```
┌─────────────────────────────────────────────────────────────────┐
│              CYCLE DE CERTIFICATION WOTX2                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. CRÉATION (Kind 30500)                                       │
│     └── Alice crée "PERMIT_JARDINAGE_X1"                        │
│     └── Publié sur NOSTR via son Hub                            │
│                                                                  │
│  2. DEMANDE (Kind 30501)                                        │
│     └── Bob demande à devenir apprenti                          │
│     └── Compétence réclamée : "Compostage"                      │
│     └── Publié directement via MULTIPASS                        │
│                                                                  │
│  3. ATTESTATION (Kind 30502)                                    │
│     └── Alice atteste Bob (1 signature)                         │
│     └── Compétences révélées : "Paillage", "Semis"              │
│     └── Publié directement via MULTIPASS                        │
│                                                                  │
│  4. VALIDATION (20H12 - ORACLE.refresh.sh)                      │
│     └── Seuil atteint → Credential 30503 émis                   │
│     └── Bob devient "Maître Certifié X1"                        │
│     └── PERMIT_JARDINAGE_X2 créé automatiquement                │
│                                                                  │
│  5. PROGRESSION                                                  │
│     └── Carol demande X2 (2 attestations requises)              │
│     └── Alice + Bob attestent Carol                             │
│     └── X3 créé automatiquement...                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Événements NOSTR pour WoTx2

| Kind | Type | Description |
|------|------|-------------|
| **30500** | Permit Definition | Définition d'une maîtrise |
| **30501** | Permit Request | Demande d'apprentissage |
| **30502** | Attestation | Validation par un maître |
| **30503** | Verifiable Credential | Certificat W3C émis |
| **22242** | NIP-42 Auth | Authentification pour API |

### Comparaison : Diplômes Traditionnels vs WoTx2

| Critère | Diplôme Classique | WoTx2 |
|---------|-------------------|-------|
| **Création** | Institution (État, École) | Libre (auto-proclamé) |
| **Validation** | Examen centralisé | Pairs décentralisés |
| **Coût** | 1000€ - 50 000€ | Gratuit |
| **Durée** | Années | Progression continue |
| **Reconnaissance** | Légale | Toile de confiance |
| **Évolution** | Statique | Dynamique (X1→X∞) |
| **Compétences** | Prédéfinies | Révélées progressivement |

### Intégration Hub + WoTx2

```bash
# Votre Hub héberge automatiquement :

1. Interface /wotx2
   └── Création de maîtrises auto-proclamées
   └── Gestion des demandes et attestations
   └── Visualisation de la progression

2. Interface /oracle  
   └── Vue d'ensemble des permits (officiels + auto-proclamés)
   └── Statistiques par permit

3. ORACLE.refresh.sh (20H12)
   └── Validation automatique des demandes
   └── Émission des credentials 30503
   └── Création des niveaux suivants (X2, X3...)
   └── Authentification NIP-42 automatique
```

### Exemple : Atelier Fablab

```
┌─────────────────────────────────────────────────────────────────┐
│              FABLAB LOCAL → WOTX2 INTÉGRÉ                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  🔧 PERMIT_IMPRESSION3D_X1                                      │
│     └── Créé par Maker expérimenté                              │
│     └── Compétences : Calibration, PLA, PETG                    │
│                                                                  │
│  ⚡ PERMIT_ELECTRONIQUE_X1                                       │
│     └── Créé par Arduino Master                                 │
│     └── Compétences : Soudure, Breadboard, I2C                  │
│                                                                  │
│  🌱 PERMIT_PERMACULTURE_X1                                       │
│     └── Créé par Jardinier                                      │
│     └── Compétences : Compost, Buttes, Associations             │
│                                                                  │
│  🎨 PERMIT_DECOUPE_LASER_X1                                      │
│     └── Créé par Technicien                                     │
│     └── Compétences : Vectorisation, Puissance, Matériaux       │
│                                                                  │
│  ► Chaque maîtrise progresse indépendamment                     │
│  ► Les compétences sont révélées par les attestations           │
│  ► Pas besoin d'organisme certificateur                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Synergie ORE + WoTx2

Le système WoTx2 peut certifier les compétences environnementales pour les contrats ORE :

```
PERMIT_OBSERVATEUR_FAUNE_X5 (Expert)
    │
    ├── Compétences validées :
    │   • Identification oiseaux
    │   • Protocole STOC
    │   • Relevés GPS
    │   • Photo-identification
    │   • Analyse données
    │
    └── Habilité à valider des contrats ORE
        sur les parcelles UMAP
```

---

## 📚 Ressources

- **Guide WireGuard complet :** `tools/wg-workflow-guide.md`
- **Économie ẐEN :** `RUNTIME/ZEN.ECONOMY.readme.md`
- **Système WoTx2 :** `docs/WOTX2_SYSTEM.md`
- **Système ORE :** `docs/ORE_SYSTEM.md`
- **Installation RPi Satellite :** https://pad.p2p.legal/s/RaspberryPi
- **Simulateur économique :** https://ipfs.copylaradio.com/ipns/copylaradio.com/economy.html
- **Monnaie Libre Ğ1 :** https://monnaie-libre.fr
- **Documentation NostrTube :** `docs/README.NostrTube.DEV.md`
- **NIP-101 (UPlanet Protocol) :** https://github.com/papiche/NIP-101

- **Guide WireGuard complet :** `tools/wg-workflow-guide.md`
- **Économie ẐEN :** `RUNTIME/ZEN.ECONOMY.readme.md`
- **Installation RPi Satellite :** https://pad.p2p.legal/s/RaspberryPi
- **Simulateur économique :** https://ipfs.copylaradio.com/ipns/copylaradio.com/economy.html
- **Monnaie Libre Ğ1 :** https://monnaie-libre.fr
- **Documentation NostrTube :** `docs/README.NostrTube.DEV.md`
- **NIP-101 (UPlanet Protocol) :** https://github.com/papiche/NIP-101

---

## 💡 Conclusion

En transformant votre PC Gamer en Hub Astroport.ONE, vous :

1. **Générez des revenus passifs** (~1000€/mois potentiel avec un essaim complet)
2. **Participez à l'économie circulaire** ẐEN
3. **Hébergez des services IA** accessibles à votre communauté
4. **Contribuez à un Internet décentralisé** respectueux de la vie privée
5. **Devenez copropriétaire** d'une infrastructure numérique réelle
6. **Certifiez les savoir-faire** via les toiles de confiance WoTx2
7. **Protégez l'environnement** avec les contrats ORE décentralisés

```
┌─────────────────────────────────────────────────────────────────┐
│                    ÉCOSYSTÈME COMPLET                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  🆔 MULTIPASS        → Identité humaine vérifiée (Ğ1 WoT)       │
│  🎓 WoTx2            → Certification des compétences            │
│  🌳 ORE              → Engagements environnementaux             │
│  💰 ẐEN Economy      → Économie circulaire automatisée          │
│  🤖 Services IA      → Ollama, ComfyUI, Perplexica              │
│  📡 NOSTR/IPFS       → Communication décentralisée              │
│  🛰️ Hub + Satellites → Infrastructure distribuée                │
│                                                                  │
│  ► Tout synchronisé à 20H12 solaire local                       │
│  ► Répliqué sur l'essaim IPFS                                   │
│  ► Gouverné par les toiles de confiance                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

> *"Le but est de vous libérer de la complexité pour que vous puissiez vous concentrer sur ce qui compte : bâtir un internet décentralisé et une économie régénératrice."*

---

## 🔬 À propos de UPlanet ẐEN

**UPlanet ẐEN** est une expérience menée par le **G1FabLab** ([https://g1sms.fr](https://g1sms.fr)), un laboratoire d'innovation qui explore les synergies entre :

- La **Monnaie Libre Ğ1** et son modèle de co-création monétaire
- Les **technologies décentralisées** (IPFS, NOSTR, WireGuard)
- L'**intelligence artificielle** locale et souveraine
- Les **Obligations Réelles Environnementales** (ORE)
- Les **toiles de confiance** pour la certification des compétences

### Philosophie G1FabLab

```
"Nous croyons que la souveraineté numérique commence
par l'infrastructure. Chaque PC Gamer transformé en Hub
est un pas vers un Internet plus libre, plus juste,
et plus respectueux de l'environnement."
```

### Rejoindre l'expérience

1. **Installer Astroport.ONE** sur votre machine
2. **Créer votre MULTIPASS** avec vos clés Ğ1
3. **Connecter des satellites** (Raspberry Pi) à votre Hub
4. **Participer à l'économie ẐEN** et aux toiles de confiance

---

**Version :** 1.0 | **Dernière mise à jour :** Décembre 2025  
**Projet :** UPlanet ẐEN - Une expérience G1FabLab  
**Contact :** support@qo-op.com  
**License :** AGPL-3.0

