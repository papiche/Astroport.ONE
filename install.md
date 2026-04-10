# 🚀 ASTROPORT.ONE - ZEN STATION
**Manuel de bord du Capitaine - Inventaire des systèmes**

Bienvenue à bord de l'Astroport.ONE ! Ce document détaille l'ensemble des logiciels, bibliothèques et outils qui viennent d'être installés et configurés sur votre nœud. 

Votre station est désormais équipée pour le Web décentralisé (Web3), l'hébergement de données, l'intelligence artificielle locale, la cryptographie, et la gestion multimédia avancée.

---

## 🌐 1. Cœur de Réseau & P2P (Web Décentralisé)
Votre nœud est prêt à interagir avec les réseaux décentralisés et les blockchains.
* **Kubo (IPFS) v0.40.0** : Le moteur principal pour héberger et partager des fichiers sur le réseau planétaire décentralisé IPFS (InterPlanetary File System). Installé dans `/usr/local/bin/ipfs`. Daemon accessible sur `http://localhost:8080`.
* **Wireguard (et wireguard-tools)** : Technologie de Réseau Privé Virtuel (VPN) ultra-rapide et sécurisée pour relier vos nœuds entre eux.
* **MiniUPnPc** : Permet d'ouvrir automatiquement les ports de votre routeur/box internet (UPnP) pour rendre votre nœud accessible de l'extérieur.

## 🔒 2. Sécurité, Réseau & Administration
Les boucliers et les capteurs de votre vaisseau.
* **Fail2ban** : Protège votre serveur contre les attaques par force brute en bannissant les adresses IP malveillantes.
* **UFW (Uncomplicated Firewall)** : Pare-feu activé automatiquement par `tools/firewall.sh ON`. Bloque les ports non autorisés.
* **OpenSSH Server & SSHFS** : Pour vous connecter à distance à votre machine et monter des systèmes de fichiers distants de manière sécurisée.
* **Nmap, DNSutils, Whois, Geoip-bin** : Outils de scan réseau, de résolution de noms de domaine et de géolocalisation des adresses IP.
* **Btop & Ncdu** : Moniteurs système esthétiques et puissants. `btop` surveille le CPU/RAM/Réseau en temps réel, et `ncdu` analyse l'espace disque.
* **Multitail** : Permet de lire plusieurs fichiers de logs en même temps dans votre terminal.
* **Parallel** : Exécute des tâches en parallèle pour maximiser l'utilisation de vos processeurs.

## 🐳 3. Docker & Infrastructure Conteneurs
Le moteur d'orchestration de tous les services de la station.
* **Docker CE + Docker Compose V2** : Installés depuis le dépôt officiel Docker. Tous les services Astroport tournent en conteneurs isolés.  
  Vérification : `docker ps` / `docker compose version`
* **Lazydocker** : Interface TUI (Terminal UI) interactive pour gérer vos conteneurs Docker sans taper de commandes. Lancez avec `lazydocker`.
* **Stack principale** (`~/.zen/Astroport.ONE/docker-compose.yml`) :
  * **Nginx Proxy Manager (NPM)** : Reverse proxy pour exposer vos services sur un domaine public avec certificats HTTPS automatiques. Admin : `http://localhost:81`
  * **Astroport API** : Le cœur de l'Astroport, interface de gestion de la station. Port : `12345`

## 🗺️ 4. Services Astroport (stack complète)
Les modules applicatifs de votre nœud communautaire.

* **UPassport** (`install/install_upassport.sh`) : Gestionnaire d'identité décentralisée et passeport numérique Web3. Interface : `http://localhost:54321`.  
  Créez votre MULTIPASS : `http://127.0.0.1:54321/g1`

* **strfry / NIP-101** (relay Nostr) : Relai NOSTR haute-performance conforme au protocole NIP-101. Filtrage avancé par plugins bash (`relay.writePolicy.plugin/`). Écoute sur `ws://localhost:7777`.

* **TiddlyWiki 5.2.3** : Wiki non-linéaire personnel, moteur des ZEN Cards et des widgets Astroport. Installé globalement via npm.  
  Commande : `tiddlywiki --version`

* **G1BILLET** (~/.zen/G1BILLET/) : Système d'impression de billets Ğ1 compatibles QR code (intégration imprimante Brother). Interface : `http://localhost:33101`.

* **g1cli / gcli** (`install/install_gcli.sh`) : Client CLI compilé pour Duniter v2s (ĞDev/ĞTest/Ğ1 Substrate), branche `nostr`. Permet des transactions en ligne de commande sur la blockchain Monnaie Libre.

## 🔗 5. Cryptographie & Économie Décentralisée (Python)
L'Astroport est un nœud financier et cryptographique complet.
* **Duniterpy** : Permet à votre nœud d'interagir avec la blockchain Duniter et la Monnaie Libre (Ğ1 - June).
* **Bitcoin & Monero** : Bibliothèques pour interagir avec les blockchains Bitcoin et Monero.
* **Pynostr & Bech32** : Outils pour se connecter au réseau social décentralisé et incensurable Nostr.
* **Substrate-interface** : Permet l'interaction avec l'écosystème Polkadot et les blockchains basées sur Substrate.
* **GnuPG, Pynacl, ECDSA, Secp256k1, JWCrypto** : Une suite complète d'outils de chiffrement, de signatures électroniques et de gestion de clés privées/publiques.
* **SSSS (Shamir's Secret Sharing)** : Découpe une clé secrète en N parts dont M suffisent à la reconstruire — utilisé pour la récupération des clés Capitaine.

## 🤖 6. Intelligence Artificielle, Scraping & Data
* **Ollama** : Moteur pour faire tourner des intelligences artificielles (LLM) directement en local sur votre machine, sans dépendre du cloud.
* **Pyppeteer & BeautifulSoup4** : Outils d'automatisation de navigateur (headless Chrome) et d'extraction de données (scraping) sur le web.
* **Httrack & Html2text** : Aspirateur de sites web pour les consulter ou les archiver hors-ligne, et conversion HTML → texte brut.
* **Readability-lxml** : Extraction du contenu principal d'une page web (supprime publicités et navigation) — utilisé par les pipelines IA.
* **Miller & Gawk** : Couteaux suisses ultra-puissants pour manipuler des données massives (CSV, JSON, texte).
* **Matplotlib** : Génération de graphiques et visualisation de données mathématiques.

## 🎬 7. Multimédia, Fichiers & Conversion
Une véritable station de traitement de médias.
* **FFmpeg & VLC** : Les références absolues pour lire, convertir et diffuser des flux vidéo et audio.
* **yt-dlp** (`install/youtube-dl.sh`) : Téléchargeur universel de vidéos (YouTube, Peertube, etc.), remplace `youtube-dl`. Lien symbolique `youtube-dl` créé automatiquement.
* **Deno** (`install/install_deno.sh`) : Runtime JavaScript/TypeScript alternatif à Node.js. Utilisé par yt-dlp comme moteur EJS pour l'extraction YouTube quand Node.js < v20.
* **Sox & MP3info** : Traitement professionnel de fichiers audio en ligne de commande.
* **ImageMagick** : Outil ultra-puissant pour redimensionner, convertir et manipuler des images en masse. Les restrictions PDF sont supprimées automatiquement lors de l'installation.
* **OCRmyPDF** : Ajoute une couche de texte (Reconnaissance Optique de Caractères) à des PDF scannés pour les rendre cherchables.
* **Pandoc & Markdown** : Le couteau suisse de la conversion de documents (passe du Markdown au PDF, HTML, Word, etc.).
* **Espeak** : Synthèse vocale, permet à votre terminal de "parler" en lisant du texte.
* **Qrencode & Amzqr** : Générateurs de QR Codes, avec `amzqr` qui permet de créer des QR codes animés (GIF) ou stylisés.
* **V4l-utils** : Outils pour contrôler vos webcams et flux vidéo matériels.
* **Detox** : Renomme automatiquement les fichiers pour remplacer les espaces et caractères spéciaux, garantissant leur compatibilité sur le web.

## 📊 8. Monitoring & Métrologie
* **Prometheus** : Base de données de séries temporelles pour collecter et stocker les métriques de la station.
* **Prometheus Node Exporter** (`install/install_prometheus.sh`) : Exporte les métriques système (CPU, RAM, disque, réseau) vers Prometheus.
* **PowerJoular** (`install/install_powerjoular.sh`) : Mesure la consommation électrique en temps réel par processus — indispensable pour calculer l'empreinte écologique de votre nœud.

## 🎨 9. Esthétique Terminal & ASCII Art
Parce qu'un vaisseau spatial doit avoir une interface qui en jette.
* **Cmatrix** : Fait défiler le code vert de "Matrix" dans votre terminal.
* **Figlet** : Génère de grands titres en ASCII art (comme le "EMBARQUEMENT CAPITAINE" au début de votre script).
* **Cowsay** : Fait parler une vache (ou d'autres personnages) en ASCII dans le terminal.
* **Fonts-hack-ttf** : Une police de caractères spécialement optimisée pour le code et la ligne de commande.
* **Robohash** : Génère un avatar de robot unique à partir de n'importe quel texte ou adresse IP (très utilisé dans le web3).

## 🛠 10. Environnements de Développement (DevTools)
* **Git, CMake, Cargo (Rust), NPM (Node.js), Pip/Pipx (Python)** : Gestionnaires de paquets et outils de compilation pour installer tout type de logiciel moderne.
* **Shellcheck** : Un vérificateur intelligent pour s'assurer que vos scripts Bash ne contiennent pas d'erreurs de sécurité.
* **Xclip** : Fait le pont entre votre presse-papiers visuel (bureau) et votre terminal.

---

## 🧩 11. Profils d'Installation
L'installateur propose 4 profils selon vos besoins :

| Profil | Commande | Description |
|--------|----------|-------------|
| **Standard** (défaut) | `bash install.sh` | IPFS + Nostr strfry + UPassport + Astroport complet |
| **nextcloud** | `bash install.sh "" "" "" nextcloud` | Standard + NextCloud AIO (cloud privé 128 Go, port 8443) |
| **ai-company** | `bash install.sh "" "" "" ai-company` | Standard + Stack IA Swarm (Ollama, Dify AI, Open WebUI, LiteLLM, Qdrant) |
| **dev** | `bash install.sh "" "" "" dev` | Standard + rnostr (remplace strfry, implémentation Rust) + Flutter SDK |

### Profil `ai-company` — services IA
| Service | URL | Rôle |
|---------|-----|------|
| Open WebUI | `http://localhost:8000` | Interface chat IA principale |
| Dify AI | `http://localhost:8010` | Agents IA automatisés |
| LiteLLM | `http://localhost:8010` | Proxy unifié vers les modèles |
| Qdrant | `http://localhost:6333` | Base vectorielle (recherche sémantique) |
| Ollama | `http://localhost:11434` | Moteur LLM local |

---

## 📁 12. Structure des Répertoires

```
~/.zen/
├── Astroport.ONE/      ← Code source cloné (GitHub papiche/Astroport.ONE)
├── workspace/
│   └── UPlanet/        ← Code UPlanet cloné (GitHub papiche/UPlanet)
├── G1BILLET/           ← Service impression billets Ğ1
├── game/
│   └── players/        ← Comptes Capitaines locaux
│       └── .current/   ← Capitaine actif
├── tmp/                ← Fichiers temporaires d'installation
└── install.errors.log  ← Journal des erreurs d'installation

~/.astro/               ← Environnement Python isolé (venv)
~/.ipfs/                ← Données IPFS (repo, blocks, config)
~/.local/bin/           ← Binaires Python (pipx : duniterpy, base58…)
```

---

## 🚀 13. Commandes Essentielles

```bash
# Interface principale de la station
~/.zen/Astroport.ONE/station.sh

# Tableau de bord économique du Capitaine
~/.zen/Astroport.ONE/captain.sh

# Démarrer / Arrêter les services
~/.zen/Astroport.ONE/start.sh
~/.zen/Astroport.ONE/stop.sh

# Ajouter un média (vidéo, audio, image)
~/.zen/Astroport.ONE/ajouter_media.sh

# Tests de la station
~/.zen/Astroport.ONE/test.sh

# Gérer les conteneurs Docker (TUI)
lazydocker

# Voir les conteneurs actifs
docker ps

# Logs de la stack principale
docker compose -f ~/.zen/Astroport.ONE/docker-compose.yml logs -f
```

---

## 🌡️ 14. Ports & Services Réseau

| Service | Port | Protocole | Accès |
|---------|------|-----------|-------|
| Astroport API | 12345 | HTTP | Local + externe |
| UPassport | 54321 | HTTP | Local |
| IPFS Gateway | 8080 | HTTP | Local |
| IPFS API | 5001 | HTTP | Local |
| Nostr Relay (strfry) | 7777 | WebSocket | Local + externe |
| Nginx Proxy Manager | 81 | HTTP | Local (admin) |
| Nginx Proxy Manager | 80/443 | HTTP/HTTPS | Externe |
| TiddlyWiki | 8080+ | HTTP | Local |
| G1BILLET | 33101 | HTTP | Local |
| Prometheus | 9090 | HTTP | Local |
| Node Exporter | 9100 | HTTP | Local |

---

### 💡 Le Mot du Mécanicien
L'installation a configuré un environnement Python isolé privé (`~/.astro`) pour éviter de casser votre système Linux. Vos applications décentralisées (DApps) s'appuieront sur la combinaison de la brique de communication (IPFS/Nostr) et de vos outils de traitement de données (Python/Multimédia).

Après l'installation, l'utilisateur est automatiquement ajouté au groupe `docker`. Pour que les permissions soient effectives dans votre session terminal courante, relancez votre session (`newgrp docker` ou déconnexion/reconnexion).

Les erreurs d'installation sont consignées dans `~/.zen/install.errors.log`.

*Bon voyage sur l'Astroport !* 🌌
