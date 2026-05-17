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
│                    TON PC GAMER                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  SSD 1 (500 Go)              SSD 2 (1 To)                       │
│  ┌─────────────┐             ┌─────────────┐                    │
│  │   WINDOWS   │             │ LINUX MINT  │                    │
│  │             │             │             │                    │
│  │ • Jeux anti-│             │ • Astroport │                    │
│  │   cheat     │             │ • Steam     │                    │
│  │ • Game Pass │             │ • IA locale │                    │
│  │             │             │ • Revenus   │                    │
│  └─────────────┘             └─────────────┘                    │
│                                                                 │
│  Au démarrage : Tu choisis Windows OU Linux Mint                │
│                                                                 │
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
│                    TON PC GAMER (HUB)                       │
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

| Service | Capacité | C'est comme... |
|---------|----------|----------------|
| **ZEN Card** | 24 personnes | Une copropriété de stockage et services |
| **MULTIPASS** | 250+ personnes | Des comptes utilisateurs |
| **Stockage cloud** | 128 Go × 24 | Google Drive, mais c'est TOI qui contrôle |
| **Stockage décentralisé** | 10 Go × 250 | Dropbox P2P |

---

## 💰 Combien tu peux gagner ? (Le math)

### Investissement de départ

| Élément | Valeur | Comparaison gaming |
|---------|--------|-------------------|
| PC Gamer (occasion) | ~2000€ | Le prix d'une RTX 4090 |
| Capital ẐEN initial | **2000 Ẑen** | Comme acheter des V-Bucks, mais utiles |

### Revenus Hebdomadaires (mode facile)

```
┌─────────────────────────────────────────────────────────────┐
│                  💸 TES REVENUS HEBDO                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  MULTIPASS (250 membres gratuits qui paient un peu)         │
│  └── 250 × 1 Ẑ/semaine = 250 Ẑ                              │
│  └── C'est comme 250 abos Twitch Tier 1                     │
│                                                             │
│  ZEN Cards (24 membres premium)                             │
│  └── 24 × 4 Ẑ/semaine = 96 Ẑ                                │
│  └── C'est comme 24 abos Twitch Tier 3                      │
│                                                             │
│  TOTAL : ~346 Ẑ/semaine ≈ 86€/semaine                       │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  CHARGES (automatiques, tu fais rien)                       │
│  └── Frais réseau : -14 Ẑ/semaine                           │
│  └── Ta rémunération auto : +28 Ẑ/semaine                   │
│  └── Taxes : ~70 Ẑ/semaine                                  │
│                                                             │
│  CE QUI RESTE : ~234 Ẑ/semaine pour la communauté           │
│  └── 1/3 Trésorerie (économies)                             │
│  └── 1/3 R&D (améliorer le système)                         │
│  └── 1/3 Projets écolos (forêts, jardins)                   │
└─────────────────────────────────────────────────────────────┘
```

### Simulation Annuelle (si ton Hub est full)

| Poste | Calcul | En €uros |
|-------|--------|----------|
| Revenus bruts | 346 Ẑ × 52 sem | **~18 000€/an** |
| Ta part (Capitaine) | 28 Ẑ × 52 sem | **~1 500€/an** |
| Revenus additionnels possibles | Services IA, etc. | **Variable** |

> **Le taux :** 1 Ẑen ≈ 1€ (c'est simple à calculer)

---

## 🎮 Option Gaming : WireGuard + SteamLink

### Pourquoi WireGuard ?

WireGuard VPN est destiné aux gamers qui souhaitent **partager leur bibliothèque Steam** avec les autres membres de l'essaim via **SteamLink**.

```
┌─────────────────────────────────────────────────────────────────┐
│                    STEAMLINK VIA WIREGUARD                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  🎮 PC GAMER (HUB)                                              │
│  └── Steam avec jeux installés                                  │
│  └── WireGuard Server (10.99.99.1)                              │
│  └── SteamLink Host                                             │
│                                                                 │
│         WireGuard VPN (latence < 5ms)                           │
│              │                                                  │
│    ┌─────────┴─────────┬─────────────────┐                      │
│    ▼                   ▼                 ▼                      │
│  📱 Client 1         📱 Client 2       📱 Client 3              │
│  (10.99.99.2)        (10.99.99.3)      (10.99.99.4)             │
│  SteamLink App       SteamLink App     SteamLink App            │
│  └── Joue aux        └── Joue aux      └── Joue aux             │
│      jeux du Hub         jeux du Hub       jeux du Hub          │
│                                                                 │
│  ► Partage de bibliothèque Steam entre membres                  │
│  ► Streaming jeux en réseau local virtuel                       │
│  ► Latence minimale via WireGuard                               │
│                                                                 │
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

### MULTIPASS : Le Pass Gratuit (enfin presque)

> **"Je paie 1€/semaine et j'ai mon identité numérique + stockage."**

| Service | C'est comme... |
|---------|----------------|
| Identité NOSTR | Ton compte Discord, mais tu le contrôles |
| Stockage 10 Go | Dropbox décentralisé |
| Réseau social | Twitter sans Elon |
| Gains par création | Tu postes → tu gagnes des Ẑen |

**Coût :** ~5€/mois (moins cher que Spotify)

### ZEN Card : Le Pass Premium

> **"Je paie 50€ une fois, je deviens copropriétaire du Hub."**

| Service | C'est comme... |
|---------|----------------|
| Copropriété | T'as des parts dans le Hub |
| 128 Go cloud | Google Drive privé |
| Astrobot | Ton assistant IA personnel |
| Droit de vote | Tu décides des règles |
| 1 an gratuit | Pas de loyer la première année |

**Coût après 1 an :** ~20€/mois (moins cher que Netflix + Spotify)

---

## 🤖 Les IA qui tournent sur ton GPU

Ton GPU RTX ne sert pas qu'à jouer ! Il sert à faire tourner des IA locales sur les Satellites :

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
./IA/generate_image.sh "A dragon in cyberpunk style"
```

### Perplexica = Moteur de recherche IA
```bash
./IA/perplexica.me.sh
./IA/perplexica_search.sh "Best Open Source NOSTR Clients"
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

## 🍪 Système de Cookies : Synchronise tes comptes automatiquement

### C'est quoi ce système ?

Tu connais les cookies de ton navigateur ? Ces petits fichiers qui te gardent connecté sur YouTube, Twitch, etc. ?

**Astroport peut les utiliser pour toi** pour synchroniser automatiquement tes données depuis ces services vers ton uDRIVE ! C'est comme un bot qui fait le travail à ta place, chaque jour.

```
┌─────────────────────────────────────────────────────────────────┐
│              SYSTÈME DE COOKIES AUTOMATISÉ                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  TOI                          TON HUB ASTROPORT                 │
│    │                                │                           │
│    │ 1. Exporte tes cookies        │                            │
│    │    (extension navigateur)      │                           │
│    │                                │                           │
│    │ 2. Upload sur /cookie ────────►│                           │
│    │                                │                           │
│    │                         3. Stockage sécurisé               │
│    │                            ~/.youtube.com.cookie           │
│    │                                │                           │
│    │                         4. 20H12 → Scraper auto            │
│    │                            (NOSTRCARD.refresh.sh)          │
│    │                                │                           │
│    │◄───────────────────────────────│                           │
│    │ 5. Tes vidéos likées          │                            │
│    │    dans uDRIVE/Videos/        │                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Comment ça marche ?

1. **Tu exportes tes cookies** avec une extension navigateur ("Get cookies.txt LOCALLY")
2. **Tu les uploades** sur l'interface `/cookie` de ton Hub
3. **Chaque jour à 20H12**, le script `NOSTRCARD.refresh.sh` exécute automatiquement le scraper
4. **Tes données arrivent** dans ton uDRIVE (vidéos, annonces, etc.)

### Services supportés

| Service | Cookie | Scraper | Ce que ça fait |
|---------|--------|---------|----------------|
| **YouTube** | `.youtube.com.cookie` | `youtube.com.sh` | Sync tes vidéos likées → uDRIVE/Videos |
| **Leboncoin** | `.leboncoin.fr.cookie` | `leboncoin.fr.sh` | Scrape tes recherches favorites |
| **Ton service** | `.example.com.cookie` | `example.com.sh` | **Tu peux l'ajouter !** |

### Exemple : YouTube Sync

Quand tu uploades un cookie YouTube, voilà ce qui se passe chaque jour :

```
┌─────────────────────────────────────────────────────────────────┐
│              YOUTUBE SYNC (youtube.com.sh)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  20H12 SOLAIRE : NOSTRCARD.refresh.sh se réveille               │
│                                                                 │
│  1. DÉTECTION                                                   │
│     └── Scan des cookies : ~/.zen/game/nostr/EMAIL/.*.cookie    │
│     └── Cookie YouTube trouvé ? → Lance youtube.com.sh          │
│                                                                 │
│  2. RÉCUPÉRATION (via yt-dlp + cookie)                          │
│     └── Connexion à YouTube avec tes cookies                    │
│     └── Liste tes vidéos likées (max 3/jour)                    │
│     └── Filtre celles déjà téléchargées                         │
│                                                                 │
│  3. TÉLÉCHARGEMENT                                              │
│     └── Download en MP4 (meilleure qualité)                     │
│     └── Extraction des métadonnées                              │
│                                                                 │
│  4. UPLOAD IPFS                                                 │
│     └── /api/fileupload → CID IPFS                              │
│     └── Stockage dans uDRIVE/Videos/                            │
│                                                                 │
│  5. PUBLICATION NOSTR (NIP-71)                                  │
│     └── publish_nostr_video.sh                                  │
│     └── Kind 21/22 (vidéo longue/courte)                        │
│     └── Visible sur NostrTube !                                 │
│                                                                 │
│  6. NOTIFICATION                                                │
│     └── Email : "🎵 YouTube Sync - 3 nouvelles vidéos"          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Upload de cookies (simple)

```bash
# Via l'interface web (recommandé)
# → Va sur http://ton-hub:54321/cookie
# → Upload ton fichier cookies

# Ou via l'API (avec ton NPUB)
curl -X POST 'http://ton-hub:54321/api/fileupload' \
  -F 'file=@youtube_cookies.txt' \
  -F 'npub=npub1...'
```

### 🛠️ Créer ton propre scraper (pour les devs)

Tu veux synchroniser un autre service ? **Le système est extensible !**

**Convention de nommage :**

| Élément | Format | Exemple |
|---------|--------|---------|
| **Cookie** | `.DOMAINE.cookie` | `.youtube.com.cookie` |
| **Scraper bash** | `DOMAINE.sh` | `youtube.com.sh` |
| **Scraper Python** | `scraper_DOMAINE.py` | `scraper_leboncoin.py` |

**Étape 1 : Crée le script bash**

```bash
# Astroport.ONE/IA/monservice.com.sh
#!/bin/bash
# Scraper pour monservice.com
# Appelé automatiquement quand .monservice.com.cookie existe

PLAYER="$1"           # Email du MULTIPASS
COOKIE_FILE="$2"      # Chemin vers le cookie (optionnel)

# Ton code de scraping ici...
# Utilise $COOKIE_FILE pour t'authentifier
# Sauvegarde dans uDRIVE du $PLAYER
```

**Étape 2 : (Optionnel) Backend Python pour logique complexe**

```python
# Astroport.ONE/IA/scraper_monservice.py
import sys
from http.cookiejar import MozillaCookieJar

cookie_file = sys.argv[1]
# Ta logique de scraping...
```

**Étape 3 : Upload un cookie et c'est automatique !**

```
Le système détecte automatiquement :
• Cookie uploadé : .monservice.com.cookie
• Scraper trouvé : monservice.com.sh
• Exécution : 20H12 chaque jour par NOSTRCARD.refresh.sh
```

### Workflow de contribution

```
┌─────────────────────────────────────────────────────────────────┐
│              DEMANDER UN NOUVEAU SCRAPER                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Toi → Upload cookie example.com                             │
│                                                                  │
│  2. Système → "🍪 Cookie: example.com - MISSING ASTROBOT"       │
│              (email de notification)                             │
│                                                                  │
│  3. Toi → Décris ton besoin au Capitaine du Hub                 │
│                                                                  │
│  4. Capitaine/Dev → Code le scraper (ou délègue)                │
│                                                                  │
│  5. Codebase → example.com.sh ajouté au repo                    │
│                                                                  │
│  6. Tout le monde → En profite ! (Open Source)                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 🔒 Sécurité des cookies

```
┌─────────────────────────────────────────────────────────────────┐
│              🔒 TES COOKIES SONT PROTÉGÉS                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ✅ Fichiers cachés (préfixe .)                                 │
│  ✅ Permissions 600 (lecture/écriture propriétaire uniquement)  │
│  ✅ JAMAIS publiés sur IPFS (restent privés)                    │
│  ✅ Stockés dans ton répertoire personnel                       │
│  ✅ Authentification NIP-42 requise pour upload                 │
│                                                                  │
│  ⚠️ Bonnes pratiques :                                          │
│  • Renouvelle tes cookies régulièrement                         │
│  • Exporte uniquement les cookies nécessaires (1 domaine/fichier)│
│  • Ne partage jamais tes fichiers cookies                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### En résumé : Pourquoi c'est cool ?

| Sans cookies | Avec cookies |
|--------------|--------------|
| Tu dois télécharger manuellement | Sync automatique chaque jour |
| Tes vidéos restent sur YouTube | Tes vidéos sont dans TON cloud |
| Dépendant de YouTube | Backup décentralisé sur IPFS |
| Pas de preuve de propriété | Publié sur NOSTR (NIP-71) |

> *"C'est comme un bot Discord qui farm pour toi, mais pour tes vidéos YouTube."*

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
│  ┌──────────┐    ┌──────────┐    ┌──────────┐               │
│  │ PC Gamer │◄──►│ PC Gamer │◄──►│ PC Gamer │   HUBS        │
│  │  HUB A   │    │  HUB B   │    │  HUB C   │               │
│  └────┬─────┘    └────┬─────┘    └────┬─────┘               │
│       │               │               │                     │
│  ┌────┴────┐     ┌────┴────┐     ┌────┴────┐                │
│  │ RPi x8  │     │ RPi x8  │     │ RPi x8  │  SATELLITES    │
│  └─────────┘     └─────────┘     └─────────┘                │
│                                                             │
│  ► Réplication IPFS entre tous les nœuds                    │
│  ► Load balancing automatique des services IA               │
│  ► Redondance et haute disponibilité                        │
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

## 🛰️ Architecture Hub + 24 Satellites

### Le Hub : Centre de Coordination

Un **Hub PC Gamer** peut accueillir jusqu'à **24 Satellites** qui assurent :
- **Relai NOSTR** : Distribution des événements sociaux
- **Passerelle IPFS** : Accès aux contenus décentralisés
- **Services locaux** : MULTIPASS, ZEN Cards pour leur zone

> **Important :** Les satellites se connectent via **IPFS P2P** (pas de WireGuard requis). WireGuard est uniquement pour le partage de jeux via SteamLink.

```
┌─────────────────────────────────────────────────────────────────┐
│                         HUB PC GAMER                            │
│                    (NOSTR Relay + IPFS Gateway)                 │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Services IA (GPU)     │  Services Économiques          │    │
│  │  • Ollama (LLM)        │  • Collecte loyers             │    │
│  │  • ComfyUI (Images)    │  • Distribution PAF            │    │
│  │  • Perplexica (Search) │  • Allocation 3×1/3            │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                  │
│               IPFS P2P (swarm.key privé)                        │
│               + NOSTR Relay constellation                       │
│                              │                                  │
├──────────────────────────────┴──────────────────────────────────┤
│                        24 SATELLITES                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐         │
│  │RPi #1  │ │RPi #2  │ │RPi #3  │ │RPi #4  │ │  ...   │         │
│  │Mode LOW│ │Mode LOW│ │Mode LOW│ │Mode LOW│ │Mode LOW│         │
│  │ORE/IoT │ │ORE/IoT │ │ORE/IoT │ │ORE/IoT │ │ORE/IoT │         │
│  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘         │
│      │          │          │          │          │              │
│   NOSTR      NOSTR      NOSTR      NOSTR      NOSTR             │
│   Relay      Relay      Relay      Relay      Relay             │
│      +          +          +          +          +              │
│   IPFS       IPFS       IPFS       IPFS       IPFS              │
│   Gateway   Gateway    Gateway    Gateway    Gateway            │
│                                                                 │
│  ► Connexion : IPFS P2P (pas de WireGuard)                      │
│  ► Sync : 20H12 solaire (mode LOW = 1h/jour)                    │
│  ► Usage : Capteurs ORE, relais NOSTR, passerelles IPFS         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Rôle des Satellites

| Fonction | Description |
|----------|-------------|
| **Relai NOSTR** | Reçoit et redistribue les événements NOSTR locaux |
| **Passerelle IPFS** | Sert de point d'accès IPFS pour sa zone géographique |
| **Stockage local** | uDRIVE (10Go) + NextCloud (128Go) pour ses membres |

### Capacité Totale d'un Essaim

| Élément | Par Satellite | Hub + 24 Satellites |
|---------|---------------|---------------------|
| Stockage NextCloud | 2 To | **~50 To** |
| Stockage uDRIVE (IPFS) | 2 To | **~50 To** |

---

## 🔐 MULTIPASS : Ton identité numérique (sans les GAFAM)

### Comment ça marche ?

Imagine Discord + un wallet crypto + une carte d'identité numérique. C'est ça le MULTIPASS.

La différence avec un compte Google/Facebook : **c'est TOI qui contrôles tes données**, pas une entreprise.

```
┌─────────────────────────────────────────────────────────────────┐
│                    COMMENT ÇA MARCHE                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Toi ────► Crée ton MULTIPASS ────► Tes potes te certifient     │
│                                                                 │
│  C'est comme le système de "vouching" dans certains jeux :      │
│  5 personnes de confiance doivent confirmer que t'es un humain  │
│                                                                 │
│    ┌─────────┐           ┌─────────┐                            │
│    │   Toi   │◄─────────►│ Ton pote│                            │
│    │  MULTI  │  certifie │  MULTI  │                            │
│    │  PASS   │◄─────────►│  PASS   │                            │
│    └─────────┘           └─────────┘                            │
│                                                                 │
│    ► 1 humain = 1 compte (pas de multi-compte)                  │
│    ► Pas de bots (contrairement à Discord/Twitter)              │
│    ► Tes données restent sur ton PC                             │
│                                                                 │
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
   └── Synchronisation N² inter-nœuds 
   └── Découverte des nouveaux membres
   └── Rapport d'activité
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
│                    SYSTÈME DE RANGS WOTX2                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  N'importe qui peut créer une "guilde" de compétences           │
│  Ex: "Arduino", "Impression 3D", "Jardinage", etc.              │
│                                                                 │
│  PROGRESSION (comme les rangs LoL/Valorant)                     │
│                                                                 │
│  ┌───────┐    ┌───────┐    ┌───────┐    ┌───────┐               │
│  │  X1   │───►│  X2   │───►│  X3   │───►│  Xn   │───► ∞         │
│  │Bronze │    │Silver │    │ Gold  │    │Diamond│               │
│  │1 vote │    │2 votes│    │3 votes│    │N votes│               │
│  └───────┘    └───────┘    └───────┘    └───────┘               │
│                                                                 │
│  TITRES DÉBLOQUÉS                                               │
│  • X1-X4   : Apprenti (Bronze/Silver)                           │
│  • X5-X10  : Expert (Gold/Platinum)                             │
│  • X11-X50 : Maître (Diamond/Master)                            │
│  • X51-X100: Grand Maître (Grandmaster)                         │
│  • X101+   : Légende (Challenger)                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Workflow de Certification

```
┌─────────────────────────────────────────────────────────────────┐
│              CYCLE DE CERTIFICATION WOTX2                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. CRÉATION (Kind 30500)                                       │
│     └── Alice crée "PERMIT_JARDINAGE_X1"                        │
│     └── Publié sur NOSTR via son Hub                            │
│                                                                 │
│  2. DEMANDE (Kind 30501)                                        │
│     └── Bob demande à devenir apprenti                          │
│     └── Compétence réclamée : "Compostage"                      │
│     └── Publié directement via MULTIPASS                        │
│                                                                 │
│  3. ATTESTATION (Kind 30502)                                    │
│     └── Alice atteste Bob (1 signature)                         │
│     └── Compétences révélées : "Paillage", "Semis"              │
│     └── Publié directement via MULTIPASS                        │
│                                                                 │
│  4. VALIDATION (20H12 - ORACLE.refresh.sh)                      │
│     └── Seuil atteint → Credential 30503 émis                   │
│     └── Bob devient "Maître Certifié X1"                        │
│     └── PERMIT_JARDINAGE_X2 créé automatiquement                │
│                                                                 │
│  5. PROGRESSION                                                 │
│     └── Carol demande X2 (2 attestations requises)              │
│     └── Alice + Bob attestent Carol                             │
│     └── X3 créé automatiquement...                              │
│                                                                 │
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
│              FABLAB LOCAL → WOTX2 INTÉGRÉ                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  🔧 PERMIT_IMPRESSION3D_X1                                      │
│     └── Créé par Maker expérimenté                              │
│     └── Compétences : Calibration, PLA, PETG                    │
│                                                                 │
│  ⚡ PERMIT_ELECTRONIQUE_X1                                       │
│     └── Créé par Arduino Master                                 │
│     └── Compétences : Soudure, Breadboard, I2C                  │
│                                                                 │
│  🌱 PERMIT_PERMACULTURE_X1                                      │
│     └── Créé par Jardinier                                      │
│     └── Compétences : Compost, Buttes, Associations             │
│                                                                 │
│  🎨 PERMIT_DECOUPE_LASER_X1                                     │
│     └── Créé par Technicien                                     │
│     └── Compétences : Vectorisation, Puissance, Matériaux       │
│                                                                 │
│  ► Chaque maîtrise progresse indépendamment                     │
│  ► Les compétences sont révélées par les attestations           │
│  ► Pas besoin d'organisme certificateur                         │
│                                                                 │
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

https://github.com/papiche/Astroport.ONE/blob/master/docs/contrib/0RE_WoTx2_Le_Cadastre_%C3%89cologique_D%C3%A9centralis%C3%A9.pdf

---

## 🌐 Datacenter vs Astroport : Pourquoi c'est révolutionnaire

### Le problème avec les datacenters centralisés

```
┌─────────────────────────────────────────────────────────────────┐
│              INTERNET CENTRALISÉ (GAFAM)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│                    ┌─────────────┐                              │
│                    │  DATACENTER │                              │
│                    │   GOOGLE    │                              │
│                    │   (ou AWS)  │                              │
│                    └──────┬──────┘                              │
│                           │                                     │
│    ┌──────────────────────┼──────────────────────┐              │
│    │           │          │          │           │              │
│    ▼           ▼          ▼          ▼           ▼              │
│   👤          👤         👤         👤          👤              │
│  User 1     User 2     User 3     User 4      User 5            │
│                                                                 │
│  PROBLÈMES :                                                    │
│  ❌ Point unique de défaillance (datacenter en panne = RIP)     │
│  ❌ Censure facile (1 décision = millions d'utilisateurs coupés)│
│  ❌ Données vendues aux annonceurs                              │
│  ❌ Coûts énormes (climatisation, sécurité, personnel)          │
│  ❌ Latence pour les utilisateurs éloignés                      │
│  ❌ Tu paies POUR le service (pas AVEC le service)              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### La solution Astroport : Réseau N² (chacun parle à chacun)

```
┌─────────────────────────────────────────────────────────────────┐
│              INTERNET DÉCENTRALISÉ (ASTROPORT)                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│     Hub A ◄────────────► Hub B ◄────────────► Hub C             │
│       │ ╲                  │                  ╱ │               │
│       │   ╲                │                ╱   │               │
│       │     ╲              │              ╱     │               │
│       │       ╲            │            ╱       │               │
│       │         Hub D ◄────┴────► Hub E         │               │
│       │           │                 │           │               │
│       └───────────┴────────┬────────┴───────────┘               │
│                            │                                    │
│            Sync N² à 20H12 solaire                              │
│            (chaque nœud sync avec tous)                         │
│                                                                 │
│  AVANTAGES :                                                    │
│  ✅ Aucun point unique de défaillance                           │
│  ✅ Censure impossible (faudrait éteindre TOUS les Hubs)        │
│  ✅ Données chiffrées et réparties                              │
│  ✅ Coûts répartis sur les utilisateurs                         │
│  ✅ Latence optimale (Hub le plus proche)                       │
│  ✅ Tu es PAYÉ pour participer                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Comment fonctionne la Sync N² (backfill_constellation.sh)

```
┌─────────────────────────────────────────────────────────────────┐
│              SYNCHRONISATION CONSTELLATION                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  20H12 SOLAIRE : Chaque Hub découvre ses voisins IPFS           │
│                                                                 │
│  1. DÉCOUVERTE (discover_constellation_peers)                   │
│     └── Scan ~/.zen/tmp/swarm/*/12345.json                      │
│     └── Extraction des myRELAY de chaque nœud                   │
│     └── Création tunnels P2P IPFS si nécessaire                 │
│                                                                 │
│  2. BACKFILL WebSocket                                          │
│     └── Connexion à chaque relay NOSTR découvert                │
│     └── Requête des événements depuis timestamp                 │
│     └── Filtrage par HEX pubkeys de la constellation            │
│                                                                 │
│  3. IMPORT strfry                                               │
│     └── Filtrage des doublons et messages supprimés             │
│     └── Import dans la base locale (--no-verify)                │
│     └── ~10 000 événements/batch en parallèle                   │
│                                                                 │
│  KINDS SYNCHRONISÉS :                                           │
│  • 0 (profils), 1 (notes), 3 (contacts), 4 (DMs)                │
│  • 21/22 (vidéos), 1063 (fichiers), 1111 (commentaires)         │
│  • 30800 (DID), 30312-30313 (ORE), 30500-30503 (Oracle)         │
│  • 8, 30008, 30009 (badges NIP-58), ... Extensible ...          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Comparaison des coûts : Datacenter vs Astroport

| Élément | Datacenter Google | Astroport (100 Hubs) |
|---------|-------------------|----------------------|
| **Infrastructure** | ~1 milliard € | ~200 000 € (PC existants) |
| **Électricité/an** | ~50 millions € | ~50 000 € (répartis) |
| **Climatisation** | ~10 millions € | 0 € (PC domestiques) |
| **Personnel technique** | ~5 millions €/an | 0 € (automatisé) |
| **Sécurité physique** | ~2 millions €/an | 0 € (chez les gens) |
| **Bande passante** | ~10 millions €/an | ~100 000 € (répartis) |
| **TOTAL annuel** | ~80 millions € | ~150 000 € |
| **Ratio** | **1x** | **÷ 500** |

### Pourquoi N² est supérieur

```
┌─────────────────────────────────────────────────────────────────┐
│              RÉSILIENCE DU RÉSEAU N²                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Avec N nœuds, il existe N×(N-1)/2 connexions possibles         │
│                                                                 │
│  Exemple avec 10 Hubs :                                         │
│  └── Connexions possibles : 10×9/2 = 45 chemins                 │
│  └── Si 1 Hub tombe : 9×8/2 = 36 chemins (80% de résilience)    │
│  └── Si 5 Hubs tombent : 5×4/2 = 10 chemins (réseau toujours OK)│
│                                                                 │
│  Avec 100 Hubs :                                                │
│  └── Connexions possibles : 100×99/2 = 4 950 chemins            │
│  └── Même avec 50% des Hubs down : 1 225 chemins                │
│  └── Le réseau reste TOUJOURS fonctionnel                       │
│                                                                 │
│  DATACENTER : 1 point de défaillance = 0% disponibilité         │
│  ASTROPORT : Faudrait éteindre 99% des Hubs pour arrêter        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Avantages sécurité

| Menace | Datacenter | Astroport |
|--------|------------|-----------|
| **Panne serveur** | Service down pour tous | 1 Hub down, les autres continuent |
| **Cyberattaque** | 1 cible = jackpot | 1000 cibles = impossible |
| **Censure gouvernementale** | 1 ordre = service coupé | Faudrait couper Internet mondial |
| **Catastrophe naturelle** | Datacenter détruit = game over | Quelques Hubs down, le reste OK |
| **Espionnage** | Données en clair au même endroit | Données chiffrées et réparties |
| **Fuite de données** | Millions de comptes compromis | Chaque Hub isolé |

### Avantages écologiques

```
┌─────────────────────────────────────────────────────────────────┐
│              EMPREINTE CARBONE                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  DATACENTER GOOGLE (1 million d'utilisateurs)                   │
│  └── Serveurs : 10 000+ machines dédiées                        │
│  └── Climatisation : 24/7 (40% de l'énergie)                    │
│  └── PUE (Power Usage Effectiveness) : ~1.2                     │
│  └── Consommation : ~50 GWh/an                                  │
│  └── Émissions : ~25 000 tonnes CO2/an                          │
│                                                                 │
│  ASTROPORT (1 million d'utilisateurs = 4000 Hubs)               │
│  └── PC existants : 0 nouvelle production                       │
│  └── Climatisation : 0 (les PC chauffent les maisons l'hiver)   │
│  └── Utilisation : Machines qui dormaient 80% du temps          │
│  └── Consommation : ~8 GWh/an (machines mutualisées)            │
│  └── Émissions : ~4 000 tonnes CO2/an                           │
│                                                                 │
│  ÉCONOMIE : ~21 000 tonnes CO2/an (÷6)                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Le vrai coût de "gratuit" (Google vs Astroport)

```
┌─────────────────────────────────────────────────────────────────┐
│  QUAND C'EST GRATUIT, C'EST TOI LE PRODUIT                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Google "gratuit" :                                             │
│  └── Tes emails analysés pour la pub                            │
│  └── Ta position GPS vendue aux annonceurs                      │
│  └── Ton historique de recherche = profil comportemental        │
│  └── Tes photos analysées par IA (reconnaissance faciale)       │
│  └── Valeur générée par utilisateur : ~300€/an                  │
│                                                                 │
│  Astroport MULTIPASS à 1€/semaine :                                │
│  └── Tes données chiffrées et illisibles                        │
│  └── Ta position : connue uniquement si tu le veux              │
│  └── Ton historique : stocké localement sur TON Hub             │
│  └── Tes photos : sur TON IPFS, pas analysées                   │
│  └── Valeur que TU gardes : ~300€/an de vie privée              │
│                                                                 │
│  CALCUL : Tu paies 48€/an au lieu de "donner" 300€/an           │
│           → Tu ÉCONOMISES 250€/an en vie privée réelle          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Résumé : Web3 Astroport vs Web2 GAFAM

| Critère | Web2 (GAFAM) | Web3 (Astroport) |
|---------|--------------|------------------|
| **Architecture** | Centralisée (1 point) | Décentralisée N² |
| **Propriété données** | Entreprise | Utilisateur |
| **Résilience** | Point unique de défaillance | Aucun SPOF |
| **Censure** | 1 décision = coupé | Techniquement impossible |
| **Coût infrastructure** | Milliards € | Réparti sur les Hubs |
| **Impact écologique** | Énorme (datacenters) | Mutualisé (PC existants) |
| **Modèle économique** | Tu es le produit | Tu es payé |
| **Vie privée** | Vendue aux annonceurs | Chiffrée E2E |
| **Scalabilité** | Coûteuse (plus de serveurs) | Gratuite (plus de Hubs = plus de N²) |

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
│                    CE QUE TU OBTIENS                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  🆔 MULTIPASS        → Ton identité numérique (pas de fake)     │
│  💰 ẐEN Economy      → Revenus automatiques                     │
│  🤖 Services IA      → ChatGPT/Stable Diffusion chez toi        │
│  📡 NOSTR/IPFS       → Réseau social sans censure               │
│  🛰️ Hub + Satellites → Ton propre mini-datacenter               │
│  +                                                              │
│  🎓 WoTx2            → Badges de compétences vérifiés           │
│  🌳 ORE              → Contrat environnemental réel             |│                                                                 │
│  ► Tout tourne automatiquement pendant que tu joues             │
│  ► Tes données restent CHEZ TOI                                 │
│  ► Tu fais partie d'une vraie communauté                        │
│                                                                 │
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

# 3. Lance l'assistant d'embarquement
~/.zen/Astroport.ONE/uplanet_onboarding.sh
# → Option 'q' pour configuration RAPIDE (recommandé)
# → Ou option 'a' pour embarquement complet guidé

# 4. Utilise le Dashboard Capitaine pour gérer ta station
~/.zen/Astroport.ONE/captain.sh
# → Tableau de bord économique
# → Gestion configuration coopérative
# → Monitoring de l'essaim
```

#### Configuration Rapide (Option `q`)

L'assistant d'embarquement propose une **configuration rapide** qui :
- ✅ Applique les paramètres économiques recommandés
- ✅ Détecte et valorise automatiquement ta machine
- ✅ Initialise les portefeuilles coopératifs
- ✅ Crée ton compte Capitaine (MULTIPASS + ZEN Card)

**Temps estimé : 5 minutes** au lieu de 30 min en mode manuel.

#### Dashboard Capitaine

Après l'embarquement, utilise `captain.sh` pour :
- 📊 Voir les soldes de tous les portefeuilles
- 🌐 Surveiller l'état de l'essaim
- ⚙️ Configurer les paramètres coopératifs (partagés via DID NOSTR)
- 🔐 Gérer les clés API (chiffrées automatiquement)
- 📢 Communiquer avec les utilisateurs via NOSTR

### Besoin d'aide ?

- **Email :** support@qo-op.com
- **Forum :** https://forum.monnaie-libre.fr

---

**Version :** 1.0 | **Dernière mise à jour :** Décembre 2025  
**Projet :** UPlanet ẐEN - Une expérience G1FabLab  
**License :** AGPL-3.0 (Open Source, tu peux modifier le code)
