



Voici une proposition de fichier `README.md` structuré, rédigé pour expliquer clairement à quoi servent tous les outils installés sur votre station **Astroport.ONE**. Il reprend le thème "Capitaine de vaisseau" présent dans votre script.

---

# 🚀 ASTROPORT.ONE - ZEN STATION
**Manuel de bord du Capitaine - Inventaire des systèmes**

Bienvenue à bord de l'Astroport.ONE ! Ce document détaille l'ensemble des logiciels, bibliothèques et outils qui viennent d'être installés et configurés sur votre nœud. 

Votre station est désormais équipée pour le Web décentralisé (Web3), l'hébergement de données, l'intelligence artificielle locale, la cryptographie, et la gestion multimédia avancée.

---

## 🌐 1. Cœur de Réseau & P2P (Web Décentralisé)
Votre nœud est prêt à interagir avec les réseaux décentralisés et les blockchains.
* **Kubo (IPFS)** : Le moteur principal pour héberger et partager des fichiers sur le réseau planétaire décentralisé IPFS (InterPlanetary File System).
* **Wireguard (et wireguard-tools)** : Technologie de Réseau Privé Virtuel (VPN) ultra-rapide et sécurisée pour relier vos nœuds entre eux.
* **MiniUPnPc** : Permet d'ouvrir automatiquement les ports de votre routeur/box internet (UPnP) pour rendre votre nœud accessible de l'extérieur.

## 🔒 2. Sécurité, Réseau & Administration
Les boucliers et les capteurs de votre vaisseau.
* **Fail2ban** : Protège votre serveur contre les attaques par force brute en bannissant les adresses IP malveillantes.
* **OpenSSH Server & SSHFS** : Pour vous connecter à distance à votre machine et monter des systèmes de fichiers distants de manière sécurisée.
* **Nmap, DNSutils, Whois, Geoip-bin** : Outils de scan réseau, de résolution de noms de domaine et de géolocalisation des adresses IP.
* **Btop & Ncdu** : Moniteurs système esthétiques et puissants. `btop` surveille le CPU/RAM/Réseau en temps réel, et `ncdu` analyse l'espace disque.
* **Multitail** : Permet de lire plusieurs fichiers de logs en même temps dans votre terminal.
* **Parallel** : Exécute des tâches en parallèle pour maximiser l'utilisation de vos processeurs.

## 🔗 3. Cryptographie & Économie Décentralisée (Python)
L'Astroport est un nœud financier et cryptographique complet.
* **Duniterpy** : Permet à votre nœud d'interagir avec la blockchain Duniter et la Monnaie Libre (Ğ1 - June).
* **Bitcoin & Monero** : Bibliothèques pour interagir avec les blockchains Bitcoin et Monero.
* **Pynostr & Bech32** : Outils pour se connecter au réseau social décentralisé et incensurable Nostr.
* **Substrate-interface** : Permet l'interaction avec l'écosystème Polkadot et les blockchains basées sur Substrate.
* **GnuPG, Pynacl, ECDSA, Secp256k1, JWCrypto** : Une suite complète d'outils de chiffrement, de signatures électroniques et de gestion de clés privées/publiques.

## 🤖 4. Intelligence Artificielle, Scraping & Data
* **Ollama** : Moteur pour faire tourner des intelligences artificielles (LLM) directement en local sur votre machine, sans dépendre du cloud.
* **Pyppeteer & BeautifulSoup4** : Outils d'automatisation de navigateur (headless Chrome) et d'extraction de données (scraping) sur le web.
* **Httrack** : Aspirateur de sites web pour les consulter ou les archiver hors-ligne.
* **Miller & Gawk** : Couteaux suisses ultra-puissants pour manipuler des données massives (CSV, JSON, texte).
* **Matplotlib** : Génération de graphiques et visualisation de données mathématiques.

## 🎬 5. Multimédia, Fichiers & Conversion
Une véritable station de traitement de médias.
* **FFmpeg & VLC** : Les références absolues pour lire, convertir et diffuser des flux vidéo et audio.
* **Sox & MP3info** : Traitement professionnel de fichiers audio en ligne de commande.
* **ImageMagick** : Outil ultra-puissant pour redimensionner, convertir et manipuler des images en masse.
* **OCRmyPDF** : Ajoute une couche de texte (Reconnaissance Optique de Caractères) à des PDF scannés pour les rendre cherchables.
* **Pandoc & Markdown** : Le couteau suisse de la conversion de documents (passe du Markdown au PDF, HTML, Word, etc.).
* **Espeak** : Synthèse vocale, permet à votre terminal de "parler" en lisant du texte.
* **Qrencode & Amzqr** : Générateurs de QR Codes, avec `amzqr` qui permet de créer des QR codes animés (GIF) ou stylisés.
* **V4l-utils** : Outils pour contrôler vos webcams et flux vidéo matériels.
* **Detox** : Renomme automatiquement les fichiers pour remplacer les espaces et caractères spéciaux, garantissant leur compatibilité sur le web.

## 🎨 6. Esthétique Terminal & ASCII Art
Parce qu'un vaisseau spatial doit avoir une interface qui en jette.
* **Cmatrix** : Fait défiler le code vert de "Matrix" dans votre terminal.
* **Figlet** : Génère de grands titres en ASCII art (comme le "EMBARQUEMENT CAPITAINE" au début de votre script).
* **Cowsay** : Fait parler une vache (ou d'autres personnages) en ASCII dans le terminal.
* **Fonts-hack-ttf** : Une police de caractères spécialement optimisée pour le code et la ligne de commande.
* **Robohash** : Génère un avatar de robot unique à partir de n'importe quel texte ou adresse IP (très utilisé dans le web3).

## 🛠 7. Environnements de Développement (DevTools)
* **Git, CMake, Cargo (Rust), NPM (Node.js), Pip/Pipx (Python)** : Gestionnaires de paquets et outils de compilation pour installer tout type de logiciel moderne.
* **Shellcheck** : Un vérificateur intelligent pour s'assurer que vos scripts Bash ne contiennent pas d'erreurs de sécurité.
* **Xclip** : Fait le pont entre votre presse-papiers visuel (bureau) et votre terminal.

---

### 💡 Le Mot du Mécanicien
L'installation a configuré un environnement Python isolé privé (`~/.astro`) pour éviter de casser votre système Linux. Vos applications décentralisées (DApps) s'appuieront sur la combinaison de la brique de communication (IPFS/Nostr) et de vos outils de traitement de données (Python/Multimédia).

*Bon voyage sur l'Astroport !* 🌌
