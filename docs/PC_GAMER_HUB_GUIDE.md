# 🎮 Ton PC Gamer peut te Rapporter de l'Argent (même quand tu joues pas)

## TL;DR pour les Gamers Pressés

**Tu as un PC Gamer qui dort 80% du temps ?** Fais-le bosser pour toi :

- 💰 **Gagne ~1000€/mois** en hébergeant des services pour ta communauté
- 🎮 **Partage ta bibliothèque Steam** avec tes potes via SteamLink
- 🤖 **Lance des IA locales** (Ollama, Stable Diffusion) sur ton GPU
- 🌐 **Rejoins un réseau décentralisé** qui respecte ta vie privée

> **"Mais je suis sous Windows..."** → Pas de panique ! On t'explique pourquoi Linux Mint est ton ami (et comment faire la transition en douceur).

---

## 🐧 Pourquoi passer à Linux Mint ? (Spoiler : c'est pas si terrible)

### Les craintes légitimes d'un Gamer Windows

| Ta peur | La réalité en 2025 |
|---------|-------------------|
| "Mes jeux vont plus marcher" | **Steam Proton** fait tourner 95%+ des jeux Windows nativement |
| "C'est compliqué à installer" | **Linux Mint** s'installe en 20 min, plus simple que Windows |
| "Je vais galérer avec les drivers" | Les drivers Nvidia/AMD s'installent en **1 clic** |
| "Mon matos sera pas reconnu" | En 2025, Linux supporte **plus de hardware** que Windows 10 |
| "Y'a pas de support" | **Communauté énorme** + forums + Discord dédiés |

### Pourquoi Linux pour Astroport ?

```
Windows = Maison en location (Microsoft décide des règles)
Linux   = Maison dont tu es propriétaire (tu fais ce que tu veux)
```

**Astroport.ONE** a besoin de :
- ✅ Contrôle total sur ton système (impossible sous Windows)
- ✅ Services qui tournent 24/7 sans interruption de mises à jour forcées
- ✅ Accès direct au GPU pour l'IA (CUDA fonctionne mieux sous Linux)
- ✅ Sécurité renforcée (pas de virus, pas de bloatware)

### Option Dual-Boot : Le meilleur des deux mondes

Tu peux garder Windows pour certains jeux ET avoir Linux Mint pour Astroport :

```
┌─────────────────────────────────────────────────────────────────┐
│                    TON PC GAMER                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  SSD 1 (500 Go)              SSD 2 (1 To)                       │
│  ┌─────────────┐             ┌─────────────┐                    │
│  │   WINDOWS   │             │ LINUX MINT  │                    │
│  │             │             │             │                    │
│  │ • Jeux anti-│             │ • Astroport │                    │
│  │   cheat     │             │ • Steam     │                    │
│  │ • Game Pass │             │ • IA locale │                    │
│  │             │             │ • Revenus   │                    │
│  └─────────────┘             └─────────────┘                    │
│                                                                  │
│  Au démarrage : Tu choisis Windows OU Linux Mint                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Pourquoi Linux Mint spécifiquement ?

| Distro | Pour qui ? | Difficulté |
|--------|-----------|------------|
| **Linux Mint** 🏆 | Ex-Windows (interface familière) | ⭐ Très Facile |
| Pop!_OS | Gamers (drivers Nvidia inclus) | ⭐ Facile |
| Ubuntu | Tout le monde (le plus documenté) | ⭐ Facile |
| Nobara | Gamers avancés (optimisé gaming) | ⭐⭐ Moyen |

**Linux Mint** ressemble beaucoup à Windows :
- Menu Démarrer en bas à gauche ✓
- Barre des tâches familière ✓
- Explorateur de fichiers similaire ✓
- Clic droit = menu contextuel ✓

### Installation Linux Mint (20 minutes chrono)

```bash
# 1. Télécharge Linux Mint Cinnamon
#    https://linuxmint.com/download.php

# 2. Crée une clé USB bootable avec Rufus (Windows)
#    ou Balena Etcher

# 3. Boot sur la clé USB (F12 au démarrage)

# 4. Clique "Install Linux Mint"
#    → Choisis "Installer à côté de Windows" pour dual-boot
#    → OU "Effacer le disque" si tu veux tout Linux

# 5. Redémarre et c'est prêt !
```

### Tes jeux Steam sous Linux Mint

```bash
# 1. Installe Steam depuis le Software Manager

# 2. Active Steam Play (Proton) :
#    Steam → Paramètres → Compatibilité
#    → ☑️ Activer Steam Play pour tous les titres
#    → Choisir "Proton Experimental"

# 3. Installe tes jeux normalement !

# Vérifie la compatibilité sur : https://www.protondb.com
# 🟢 Native/Platinum = Parfait
# 🟡 Gold = Très bien
# 🟠 Silver = Jouable avec tweaks
```

---

## 🎯 Ce que tu vas obtenir

Ton PC Gamer devient un **Hub** qui génère des revenus pendant que tu joues (ou que tu dors) :

## 🏗️ Architecture : Le Rôle du Hub PC Gamer

```
┌─────────────────────────────────────────────────────────────┐
│                    TON PC GAMER (HUB)                        │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   OLLAMA    │  │  COMFYUI    │  │ PERPLEXICA  │   IA     │
│  │  ChatGPT    │  │  Stable     │  │  Moteur de  │  LOCAL   │
│  │  local !    │  │  Diffusion  │  │  recherche  │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              ASTROPORT.ONE                          │    │
│  │  • Stockage décentralisé (comme un cloud privé)     │    │
│  │  • NextCloud (128 Go par membre premium)            │    │
│  │  • Réseau social décentralisé (NOSTR)               │    │
│  │  • Économie automatisée (revenus passifs)           │    │
│  └─────────────────────────────────────────────────────┘    │
│                           │                                 │
│                    Réseau P2P                               │
│              (comme BitTorrent, mais légal)                 │
└───────────────────────────┬─────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
   ┌────▼────┐         ┌────▼────┐         ┌────▼────┐
   │ Pote 1  │         │ Pote 2  │         │ Pote 3  │
   │ (RPi)   │         │ (RPi)   │         │ (PC)    │
   └─────────┘         └─────────┘         └─────────┘
```

### Ce que ton Hub peut héberger

| Type de membre | Capacité | C'est comme... |
|----------------|----------|----------------|
| **ZEN Card** (proprios) | 24 max | Copropriétaires avec 128 Go chacun |
| **MULTIPASS** (locataires) | 250+ | Abonnés avec 10 Go ou 128 Go |

### Les deux types de membres

```
┌─────────────────────────────────────────────────────────────────┐
│  MULTIPASS = Jeton d'USAGE (locataire)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  📱 Formule Basic : 1 Ẑen/semaine (~4€/mois)                    │
│     └── 10 Go de stockage décentralisé (IPFS)                   │
│     └── Identité NOSTR + wallet ẐEN                             │
│     └── Accès aux services IA du Hub                            │
│                                                                 │
│  📱 Formule Pro : 5 Ẑen/semaine (~20€/mois)                     │
│     └── 128 Go de stockage NextCloud                            │
│     └── Tout le reste inclus                                    │
│                                                                 │
│  → Tu paies pour utiliser, comme un abonnement Netflix          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  ZEN CARD = Jeton de PROPRIÉTÉ (copropriétaire)                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  🏠 Sur HUB (PC Gamer) : 540€ pour 3 ans (180€/an)              │
│     └── Tu POSSÈDES une part de 128 Go du Hub                   │
│     └── Pas de loyer à payer (c'est chez toi !)                 │
│     └── Droit de vote sur les décisions                         │
│                                                                 │
│  🛰️ Sur Satellite (RPi) : 50€/an                                │
│     └── Même principe, sur un Raspberry Pi                      │
│                                                                 │
│  💰 Option sous-location :                                      │
│     └── Tu peux louer tes 128 Go en tranches de 10 Go           │
│     └── Exemple : 12 sous-locataires × 1 Ẑ/sem = 12 Ẑ/sem       │
│     └── Tu deviens toi-même un mini-bailleur !                  │
│                                                                 │
│  → C'est comme acheter un appart vs le louer                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 💰 Combien tu peux gagner ? (Le math)

### Les 3 rôles dans l'économie

```
┌─────────────────────────────────────────────────────────────────┐
│                    QUI FAIT QUOI ?                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  🚢 ARMATEUR = Toi (le proprio du PC)                           │
│     └── Tu gardes ton Astroport allumé 24/7                     │
│     └── Tu l'ouvres à la gestion coopérative CopyLaRadio        │
│     └── Tu reçois la PAF (Participation Aux Frais)              │
│        → Couvre : électricité + connexion internet + usure      │
│                                                                  │
│  👨‍✈️ CAPITAINE = Toi aussi (ou quelqu'un d'autre)                │
│     └── Gère le Hub au quotidien                                │
│     └── Accueille les nouveaux membres                          │
│     └── Reçoit une rémunération pour le travail                 │
│                                                                  │
│  🏠 ZEN CARD = Copropriétaires (24 max)                         │
│     └── Ont acheté une part du Hub (540€/3 ans)                 │
│     └── Utilisent leur 128 Go ou le sous-louent                 │
│     └── Votent sur les décisions                                │
│                                                                  │
│  📱 MULTIPASS = Locataires (250+)                               │
│     └── Paient un loyer hebdomadaire                            │
│     └── Utilisent les services du Hub                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Investissement de départ

| Élément | Valeur | Comparaison gaming |
|---------|--------|-------------------|
| PC Gamer (occasion) | ~2000€ | Le prix d'une RTX 4090 |
| Capital ẐEN initial | **2000 Ẑen** | Comme acheter des V-Bucks, mais utiles |

### Revenus Hebdomadaires (exemple avec Hub full)

```
┌─────────────────────────────────────────────────────────────────┐
│                  💸 TES REVENUS HEBDO                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  MULTIPASS Basic (200 locataires × 10 Go)                       │
│  └── 200 × 1 Ẑ/semaine = 200 Ẑ                                  │
│                                                                 │
│  MULTIPASS Pro (50 locataires × 128 Go)                         │
│  └── 50 × 5 Ẑ/semaine = 250 Ẑ                                   │
│                                                                 │
│  ZEN Cards (24 copropriétaires)                                 │
│  └── 24 × 540€/3ans ÷ 156 sem ≈ 83 Ẑ/semaine                    │
│  └── (Ils sont CHEZ EUX, pas de loyer hebdo !)                  │
│                                                                 │
│  TOTAL REVENUS HUB : ~533 Ẑ/semaine                             │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  TA PART (ARMATEUR + CAPITAINE)                                 │
│                                                                 │
│  PAF Armateur (tes frais réels)                                 │
│  └── Électricité + Internet + Usure ≈ 14 Ẑ/semaine              │
│                                                                 │
│  Rémunération Capitaine (ton "salaire")                         │
│  └── Gestion quotidienne ≈ 28 Ẑ/semaine                         │
│                                                                 │
│  → TA PART : ~42 Ẑ/semaine (~170€/mois)                         │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  SURPLUS COOPÉRATIF (géré par CopyLaRadio)                      │
│  └── 1/3 Trésorerie (économies du collectif)                    │
│  └── 1/3 R&D (améliorer Astroport)                              │
│  └── 1/3 Projets écolos (forêts, jardins)                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Simulation Annuelle (si ton Hub est full)

| Poste | Calcul | En €uros |
|-------|--------|----------|
| Revenus MULTIPASS | (200×1 + 50×5) Ẑ × 52 sem | **~23 400€/an** |
| Revenus ZEN Cards | 24 × 540€/3ans | **~4 320€/an** |
| **Total brut** | | **~27 720€/an** |
| Ta part (PAF + Capitaine) | 42 Ẑ × 52 sem | **~2 200€/an** |

> **Le taux :** 1 Ẑen ≈ 1€ (c'est simple à calculer)

### Résumé des tarifs

| Type | Formule | Prix | Ce qu'ils obtiennent |
|------|---------|------|---------------------|
| MULTIPASS | Basic | 1 Ẑ/sem | 10 Go + identité |
| MULTIPASS | Pro | 5 Ẑ/sem | 128 Go + identité |
| ZEN Card | Hub | 540€/3 ans | 128 Go en propriété |
| ZEN Card | Satellite | 50€/an | 128 Go en propriété |

---

## 🎮 Option Gaming : WireGuard + SteamLink

### Pourquoi WireGuard ?

WireGuard VPN est destiné aux gamers qui souhaitent **partager leur bibliothèque Steam** avec les autres membres de l'essaim via **SteamLink**.

```
┌─────────────────────────────────────────────────────────────────┐
│                    STEAMLINK VIA WIREGUARD                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  🎮 PC GAMER (HUB)                                              │
│  └── Steam avec jeux installés                                  │
│  └── WireGuard Server (10.99.99.1)                              │
│  └── SteamLink Host                                             │
│                                                                  │
│         WireGuard VPN (latence < 5ms)                           │
│              │                                                   │
│    ┌─────────┴─────────┬─────────────────┐                      │
│    ▼                   ▼                 ▼                      │
│  📱 Client 1         📱 Client 2       📱 Client 3              │
│  (10.99.99.2)        (10.99.99.3)      (10.99.99.4)             │
│  SteamLink App       SteamLink App     SteamLink App            │
│  └── Joue aux        └── Joue aux      └── Joue aux             │
│      jeux du Hub         jeux du Hub       jeux du Hub          │
│                                                                  │
│  ► Partage de bibliothèque Steam entre membres                  │
│  ► Streaming jeux en réseau local virtuel                       │
│  ► Latence minimale via WireGuard                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Qui a besoin de WireGuard ?

| Usage | WireGuard requis ? |
|-------|-------------------|
| Services Astroport (MULTIPASS, ZEN Cards) | ❌ Non (IPFS P2P) |
| Services IA (Ollama, ComfyUI, Perplexica) | ❌ Non (IPFS P2P / SSH) |
| Synchronisation 20H12 | ❌ Non (IPFS P2P) |
| Partage de jeux Steam via SteamLink | ✅ **Oui** |
| Remote Desktop vers le Hub | ✅ Optionnel |

### Configuration WireGuard (Gaming uniquement)

Votre PC Gamer devient le **HUB VPN** pour le streaming de jeux.

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
║                          WIREGUARD LAN MANAGER                               ║
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

### Étape 3 : Ajouter des Clients SteamLink

Chaque appareil qui veut jouer aux jeux du Hub doit se connecter au VPN.

**Sur le Hub (votre PC) :**
```bash
./wireguard_control.sh → Option 2 (Ajouter un client)
# Nom : salon-tv
# Clé publique : <clé du client>
```

**Sur le Client (TV, tablette, autre PC) :**
```bash
# Si Linux/Raspberry Pi
cd Astroport.ONE/tools
./wg-client-setup.sh

# Si Android/iOS : importer le QR code dans l'app WireGuard
```

Entrez les informations :
- Adresse du serveur : `<IP_publique_du_hub>`
- Port : `51820`
- Clé publique serveur : `<clé_affichée_par_le_hub>`
- IP VPN attribuée : `10.99.99.X/32`

### Étape 4 : Configurer SteamLink

```bash
# Sur le Hub : Activer le streaming distant dans Steam
# Steam → Paramètres → Remote Play → Activer

# Sur le client : Installer SteamLink
# L'app détecte automatiquement le Hub via le réseau WireGuard
```

### Étape 5 : Vérifier la Connexion

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

## 📱 Ce que tes membres obtiennent

### MULTIPASS : L'abonnement (jeton d'usage)

> **"Je paie un loyer et j'utilise les services du Hub."**

| Formule | Stockage | Coût | C'est comme... |
|---------|----------|------|----------------|
| **Basic** | 10 Go IPFS | 1 Ẑ/sem (~4€/mois) | Abonnement Spotify |
| **Pro** | 128 Go NextCloud | 5 Ẑ/sem (~20€/mois) | Abonnement Netflix |

**Ce que tu obtiens :**
- 🆔 Identité NOSTR (ton compte décentralisé)
- 💰 Wallet ẐEN (monnaie libre)
- 🤖 Accès aux IA du Hub (Ollama, ComfyUI...)
- 📱 Réseau social sans censure

### ZEN Card : La copropriété (jeton de propriété)

> **"J'achète ma part, je suis chez moi, je peux même sous-louer !"**

| Plateforme | Coût | Durée | Ce que tu possèdes |
|------------|------|-------|-------------------|
| **Hub (PC Gamer)** | 540€ | 3 ans | 128 Go en copropriété |
| **Satellite (RPi)** | 50€ | 1 an | 128 Go sur le satellite |

**Ce que tu obtiens :**
- 🏠 **Pas de loyer** → c'est CHEZ TOI
- 🗳️ **Droit de vote** → tu décides des règles
- 💰 **Option sous-location** → deviens mini-bailleur !

```
┌─────────────────────────────────────────────────────────────────┐
│  EXEMPLE DE SOUS-LOCATION (ZEN Card)                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Tu as acheté une ZEN Card (540€/3 ans = 180€/an)               │
│  Tu as 128 Go de stockage                                        │
│                                                                  │
│  Option 1 : Tu utilises tout pour toi                           │
│     └── 128 Go de cloud privé, pas de loyer                     │
│                                                                  │
│  Option 2 : Tu sous-loues                                        │
│     └── 128 Go ÷ 10 Go = 12 sous-locataires max                 │
│     └── 12 × 1 Ẑ/sem = 12 Ẑ/sem = ~624 Ẑ/an                     │
│     └── Ton investissement : 180€/an                            │
│     └── Tes revenus : ~624€/an                                  │
│     └── PROFIT : ~444€/an 🎉                                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🤖 Les IA qui tournent sur ton GPU

Ton GPU RTX ne sert pas qu'à jouer ! Tu peux faire tourner des IA locales :

### Ollama = ChatGPT chez toi
```bash
# Lance ton ChatGPT local
./IA/ollama.me.sh

# Teste si ça marche
./IA/ollama.me.sh TEST

# Résultat : Tu as un ChatGPT gratuit et privé !
```

### ComfyUI = Stable Diffusion (génération d'images)
```bash
# Connexion automatique
./IA/comfyui.me.sh

# Génère une image (comme Midjourney, mais gratuit)
./IA/comfyui.me.sh "A dragon in cyberpunk style"
```

### Perplexica = Moteur de recherche IA
```bash
./IA/perplexica.me.sh
# C'est comme Perplexity.ai mais sur ton PC
```

**Comment ça se connecte (automatiquement) :**
```
1. L'IA tourne sur ton PC ?  ──────────────────► Nice, on utilise ça
           │
           ▼ non
2. Un pote du réseau l'a ?  ───────────────────► On utilise son GPU
           │
           ▼ non
3. Serveur de demo dispo ?  ───────────────────► On utilise ça
           │
           ▼ non
4. Pas d'IA dispo ──────────────────────────────► Installe Ollama !
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

## ⏰ La Sync Quotidienne (20H12)

### C'est quoi ce truc de "20H12 solaire" ?

Tous les jours, tous les Hubs du réseau se synchronisent automatiquement. C'est comme un "daily reset" dans un MMO, sauf que l'heure dépend de où tu es sur la planète.

**Pourquoi ?** Pour que tout le monde sync au même moment du soleil (et pas juste "20h12 heure de Paris").

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

> **Important :** Les satellites se connectent via **IPFS P2P** (pas de WireGuard requis). WireGuard est uniquement pour le partage de jeux via SteamLink.

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
│               IPFS P2P (swarm.key privé)                        │
│               + NOSTR Relay constellation                        │
│                              │                                   │
├──────────────────────────────┴──────────────────────────────────┤
│                        24 SATELLITES                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐        │
│  │RPi #1  │ │RPi #2  │ │RPi #3  │ │RPi #4  │ │  ...   │        │
│  │Mode LOW│ │Mode LOW│ │Mode LOW│ │Mode LOW│ │Mode LOW│        │
│  │ORE/IoT │ │ORE/IoT │ │ORE/IoT │ │ORE/IoT │ │ORE/IoT │        │
│  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘        │
│      │          │          │          │          │              │
│   NOSTR      NOSTR      NOSTR      NOSTR      NOSTR            │
│   Relay      Relay      Relay      Relay      Relay            │
│      +          +          +          +          +              │
│   IPFS       IPFS       IPFS       IPFS       IPFS             │
│   Gateway   Gateway    Gateway    Gateway    Gateway            │
│                                                                  │
│  ► Connexion : IPFS P2P (pas de WireGuard)                     │
│  ► Sync : 20H12 solaire (mode LOW = 1h/jour)                   │
│  ► Usage : Capteurs ORE, relais NOSTR, passerelles IPFS        │
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

## 🚀 Installation Express (30 minutes avec Linux Mint)

### Prérequis

- ✅ Un PC Gamer avec GPU (Nvidia recommandé)
- ✅ Linux Mint installé (voir section "Passer à Linux Mint")
- ✅ Connexion Internet stable
- ✅ 100 Go d'espace disque libre

### Let's go !

```bash
# 1. Ouvre un terminal (Ctrl+Alt+T)

# 2. Installe les dépendances
sudo apt update && sudo apt install git curl jq -y

# 3. Clone Astroport.ONE
git clone https://github.com/papinou/Astroport.ONE.git
cd Astroport.ONE

# 4. Lance l'installation (ça prend ~10 min)
./install.sh

# 5. Configure ta position (pour la sync quotidienne)
# Trouve tes coordonnées sur Google Maps
echo "LAT=48.8566" > ~/.zen/GPS    # Remplace par ta latitude
echo "LON=2.3522" >> ~/.zen/GPS    # Remplace par ta longitude

# 6. Active ton Hub
cd tools && ./cron_VRFY.sh ON

# 7. Crée ton compte Capitaine
# Ouvre Firefox → http://localhost:54321/g1nostr
# Suis les instructions

# 8. C'est prêt ! 🎉
```

### (Optionnel) Partage tes jeux Steam avec WireGuard

```bash
# Si tu veux partager ta bibliothèque Steam via SteamLink
cd ~/Astroport.ONE/tools
./wireguard_control.sh
# → Choisis "1. Initialiser serveur LAN"
# → Note la clé publique affichée
# → Donne-la à tes potes pour qu'ils se connectent
```

---

## 🔐 MULTIPASS : Ton identité numérique (sans les GAFAM)

### Comment ça marche ?

Imagine Discord + un wallet crypto + une carte d'identité numérique. C'est ça le MULTIPASS.

La différence avec un compte Google/Facebook : **c'est TOI qui contrôles tes données**, pas une entreprise.

```
┌─────────────────────────────────────────────────────────────────┐
│                    COMMENT ÇA MARCHE                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Toi ────► Crée ton MULTIPASS ────► Tes potes te certifient     │
│                                                                  │
│  C'est comme le système de "vouching" dans certains jeux :      │
│  5 personnes de confiance doivent confirmer que t'es un humain  │
│                                                                  │
│    ┌─────────┐           ┌─────────┐                             │
│    │   Toi   │◄─────────►│ Ton pote│                             │
│    │  MULTI  │  certifie │  MULTI  │                             │
│    │  PASS   │◄─────────►│  PASS   │                             │
│    └─────────┘           └─────────┘                             │
│                                                                  │
│    ► 1 humain = 1 compte (pas de multi-compte)                  │
│    ► Pas de bots (contrairement à Discord/Twitter)              │
│    ► Tes données restent sur ton PC                             │
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
# - Clé ẐEN (wallet Duniter)
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
| **ZEN Economy** | Transactions économiques | MULTIPASS + ẐEN |
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

| Aspect | Web2 Classique | MULTIPASS + ẐEN |
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

## 🎓 WoTx2 : Des badges de compétences vérifiés

### C'est comme un système de rangs/badges, mais vérifiable

Tu connais les rangs dans les jeux compétitifs ? Bronze → Silver → Gold → Diamond...

**WoTx2** c'est pareil, mais pour des **vraies compétences** (code, bricolage, jardinage, etc.) et c'est vérifié par d'autres humains, pas un algorithme.

```
┌─────────────────────────────────────────────────────────────────┐
│                    SYSTÈME DE RANGS WOTX2                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  N'importe qui peut créer une "guilde" de compétences           │
│  Ex: "Arduino", "Impression 3D", "Jardinage", etc.              │
│                                                                  │
│  PROGRESSION (comme les rangs LoL/Valorant)                     │
│                                                                  │
│  ┌───────┐    ┌───────┐    ┌───────┐    ┌───────┐              │
│  │  X1   │───►│  X2   │───►│  X3   │───►│  Xn   │───► ∞        │
│  │Bronze │    │Silver │    │ Gold  │    │Diamond│              │
│  │1 vote │    │2 votes│    │3 votes│    │N votes│              │
│  └───────┘    └───────┘    └───────┘    └───────┘              │
│                                                                  │
│  TITRES DÉBLOQUÉS                                               │
│  • X1-X4   : Apprenti (Bronze/Silver)                           │
│  • X5-X10  : Expert (Gold/Platinum)                             │
│  • X11-X50 : Maître (Diamond/Master)                            │
│  • X51-X100: Grand Maître (Grandmaster)                         │
│  • X101+   : Légende (Challenger)                               │
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

### Pourquoi c'est mieux qu'un diplôme ?

| | Diplôme classique | WoTx2 |
|---|-------------------|-------|
| **Qui décide ?** | L'État/l'école | Tes pairs (les vrais experts) |
| **Combien ça coûte ?** | 1000€ - 50 000€ | Gratuit |
| **Combien de temps ?** | Des années | Tu progresses en continu |
| **C'est reconnu ?** | Par les RH (peut-être) | Par les gens qui font vraiment le taf |
| **Ça évolue ?** | Non, une fois obtenu c'est fini | Tu peux toujours monter de niveau |

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

## 📚 Pour aller plus loin

### Documentation technique
- **Guide WireGuard (SteamLink) :** `tools/wg-workflow-guide.md`
- **Économie ẐEN :** `RUNTIME/ZEN.ECONOMY.readme.md`
- **Système de badges WoTx2 :** `docs/WOTX2_SYSTEM.md`
- **Système écologique ORE :** `docs/ORE_SYSTEM.md`

### Liens utiles
- **Linux Mint :** https://linuxmint.com (téléchargement)
- **ProtonDB :** https://www.protondb.com (compatibilité jeux)
- **Installation RPi Satellite :** https://pad.p2p.legal/s/RaspberryPi
- **Simulateur économique :** https://ipfs.copylaradio.com/ipns/copylaradio.com/economy.html
- **Monnaie Libre Ğ1 :** https://monnaie-libre.fr
- **Protocole UPlanet (NIP-101) :** https://github.com/papiche/NIP-101

---

## 💡 En résumé : Pourquoi tu devrais le faire

En transformant ton PC Gamer en Hub Astroport.ONE, tu :

1. 💰 **Gagnes de l'argent passivement** (même en jouant)
2. 🎮 **Partages ta bibliothèque Steam** avec tes potes (SteamLink)
3. 🤖 **Lances des IA locales** sur ton GPU (Ollama, Stable Diffusion)
4. 🌐 **Rejoins un vrai réseau décentralisé** (pas du crypto-bullshit)
5. 🏠 **Deviens proprio** de ton infrastructure numérique
6. 🎓 **Certifies tes skills** reconnus par la communauté
7. 🌳 **Participes à des projets écolos** concrets

```
┌─────────────────────────────────────────────────────────────────┐
│                    CE QUE TU OBTIENS                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  🆔 MULTIPASS        → Ton identité numérique (pas de fake)     │
│  🎓 WoTx2            → Badges de compétences vérifiés           │
│  🌳 ORE              → Impact environnemental réel              │
│  💰 ẐEN Economy      → Revenus automatiques                     │
│  🤖 Services IA      → ChatGPT/Stable Diffusion chez toi        │
│  📡 NOSTR/IPFS       → Réseau social sans censure               │
│  🛰️ Hub + Satellites → Ton propre mini-datacenter               │
│                                                                  │
│  ► Tout tourne automatiquement pendant que tu joues             │
│  ► Tes données restent CHEZ TOI                                 │
│  ► Tu fais partie d'une vraie communauté                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

> *"Le but c'est que ton PC bosse pour toi, pas l'inverse. Et que tu fasses partie d'un truc plus grand que juste farm des skins."*

---

## 🔬 C'est quoi UPlanet ẐEN ?

**UPlanet ẐEN** est un projet expérimental du **G1FabLab** ([https://g1sms.fr](https://g1sms.fr)).

### En mode simple

```
C'est comme si Discord, Google Drive, ChatGPT et Patreon
avaient un bébé... mais décentralisé et sans les GAFAM.

Et TU es payé pour faire tourner le truc.
```

### Ce qu'on essaie de construire

- 🪙 Une **économie qui ne dépend pas des banques** (Monnaie Libre Ğ1)
- 🌐 Un **Internet qui appartient aux utilisateurs** (IPFS, NOSTR)
- 🤖 Des **IA qui restent sur ton ordi** (pas dans le cloud d'OpenAI)
- 🌳 Des **projets écolos** financés automatiquement
- 🎓 Des **certifications de compétences** validées par les pairs

### Comment rejoindre

```bash
# 1. Installe Linux Mint sur ton PC Gamer
#    (dual-boot si tu veux garder Windows)

# 2. Clone et installe Astroport.ONE
git clone https://github.com/papinou/Astroport.ONE.git
cd Astroport.ONE && ./install.sh

# 3. Crée ton MULTIPASS
#    → Va sur http://localhost:54321/g1nostr

# 4. Invite tes potes à rejoindre ton Hub

# 5. Profit (littéralement)
```

### Besoin d'aide ?

- **Discord/Matrix :** Rejoins la communauté G1FabLab
- **Email :** support@qo-op.com
- **Forum :** https://forum.monnaie-libre.fr

---

**Version :** 1.0 | **Dernière mise à jour :** Décembre 2025  
**Projet :** UPlanet ẐEN - Une expérience G1FabLab  
**License :** AGPL-3.0 (Open Source, tu peux modifier le code)

