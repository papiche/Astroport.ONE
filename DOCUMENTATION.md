Voici une version actualisée et enrichie de la documentation hub de **Astroport.ONE**. Cette mise à jour intègre les concepts récents de l'économie circulaire **Ẑen**, la sécurité **Primale**, et l'architecture sociale **N² (Nostr + Nœuds)**.

---

# 🌍 L'Écosystème UPlanet ẐEN : Documentation Hub

## 🎯 Vision et Fondamentaux

**Astroport.ONE** n'est pas qu'un logiciel, c'est l'OS d'une station de la constellation **UPlanet**. Il transforme un ordinateur en un nœud souverain capable de gérer l'identité, le stockage et l'économie sans intermédiaire.

1.  **[🧭 README.md](README.md)** - Introduction globale et philosophie du projet.
2.  **[🌱 WELCOME.md](WELCOME.md)** - Guide d'accueil pour les nouveaux arrivants (Français).
3.  **[🏗️ ARCHITECTURE.md](ARCHITECTURE.md)** - Le triptyque technologique : **Nostr** (Social), **IPFS** (Data), **Ğ1** (Confiance).

---

## 🔑 Identités et Rôles

Le système repose sur une gradation de la souveraineté numérique :

*   **[🎟️ MULTIPASS (Usage)](docs/IDENTITY_MULTIPASS.md)** : Identité Nostr + Wallet de revenu. Accès au **uDRIVE** (10Go) et aux services de base.
*   **[💳 ZEN Card (Propriété)](docs/IDENTITY_ZENCARD.md)** : Parts sociales de la coopérative. Accès au cloud privé **NextCloud** (128Go) et à l'IA.
*   **[🪪 UPassport (Sociétaire)](api-upassport.md)** : Preuve de co-propriété de l'infrastructure physique et des terres de la SCIC.
*   **[👨‍✈️ Rôles du Réseau](docs/ROLES.md)** : Distinction entre l'**Armateur** (fournisseur de matériel) et le **Capitaine** (opérateur logiciel).

---

## 💰 Économie Circulaire Ẑen

Le **Ẑen (Ẑ)** est l'unité de compte interne (1 Ẑ = 0.1 Ğ1). Le système automatise la redistribution de la richesse.

*   **[🏦 ZEN Economy](docs/ZEN.ECONOMY.v3.md)** : La règle constitutionnelle des **3x1/3 + 1%** (Trésorerie, R&D, Patrimoine + Parrain).
*   **[🛡️ Contrôle Primal](tools/primal_wallet_control.README.md)** : Système de sécurité unique vérifiant l'origine de chaque Ğ1 entrant pour protéger la station contre les intrusions.
*   **[🔄 OC2UPlanet](https://github.com/papiche/OC2UPlanet)** : Le pont financier entre les Euros (OpenCollective) et l'économie Ẑen.
*   **[🛍️ uMARKET](docs/uMARKET.md)** : Marketplace décentralisée indexée géographiquement. A TESTER -> MIGRER vers ORE UMAP

---

## ⚙️ Cœur du Système (Automation)

L'intelligence d'Astroport réside dans sa maintenance autonome indexée sur le temps solaire.

*   **[☀️ Astroport 20H12](20h12.process.sh)** : Le cycle de maintenance quotidienne (Mises à jour, Backups, Calibration solaire).
*   **[📡 Swarm Node Manager (_12345.sh)](https://github.com/papiche/ISBP-spec)** : Gestion de la balise IPNS et synchronisation avec l'essaim mondial (un monde par ẐEN).
*   **[🐉 DRAGON P2P Support](RUNTIME/DRAGON_p2p_ssh.sh)** : Partage de services sécurisé via IPFS pour le partage de ressources à distance.
*   **[🔄 NOSTR Auth (NIP-42)](docs/API.NOSTRAuth.readme.md)** : Système d'authentification renforcé par marqueurs locaux sécurisés (NIP-42 relai && swarm auth).

---

## 🤖 IA et Services Multimédia

*   **[🎬 Nostr Tube](docs/README.NostrTube.md)** : Alternative Web3 à YouTube (Stockage IPFS, Commentaires Nostr, Ancrage Géo). -- partager ses vidéos à ses amis et leurs amis (demo N²)
*   **[🧠 Slot Memory System](IA/SLOT_MEMORY_README.md)** : Gestion de la mémoire courte pour les agents IA AstroBot. -- en cours de migration vers base KV...
*   **[🌿 PlantNet](docs/PLANTNET_SYSTEM.md) & [ORE](docs/ORE_SYSTEM.md)** : Recensement de la biodiversité et activation automatique de contrats environnementaux.  A TESTER  ...
*   **[🎲 CoinFlip](https://github.com/papiche/UPlanet/tree/main/earth/coinflip)** : Application de démonstration de micro-paiements ZEN instantanés (Paradoxe de St-Pétersbourg) -  A TESTER  !!

---

## 🔧 Administration et Développement

*   **[📋 Système TODO](docs/TODO_SYSTEM.md)** : Rapports quotidiens générés par IA sur l'avancement du code.
*   **[🍪 Cookie System](docs/COOKIE_SYSTEM.md)** : Gestion des accès authentifiés pour les scrapers automatisés.
*   **[🐳 Docker Setup](_DOCKER/Readme.md)** : Déploiement par conteneurs de la stack expérimentale.
*   **[🛠️ Tools Directory](tools/)** : Index des scripts utilitaires (Keygen, Conversions, MailJet).

---

## 🔗 Liens Utiles et Gouvernance

*   **[Statuts SCIC CopyLaRadio](https://pad.p2p.legal/s/CopyLaRadio#)** : Le cadre juridique de la coopérative.
*   **[Ğ1FabLab](https://g1sms.fr)** : Incubateur de technologies pour la Monnaie Libre.
*   **[Réseau N1N2](https://ipfs.copylaradio.com/ipns/copylaradio.com/bang.html)** : Visualisation de la portée du réseau d'amis d'amis.

---

**💡 Besoin d'assistance ?**
Contactez le support technique (Les Dragons) : `support@qo-op.com` ou via votre **UMAP** locale sur Nostr.

**🚀 Prêt à décoller ?**
```bash
# Installation rapide (Ubuntu/Debian/Mint)
bash <(curl -sL https://install.astroport.com)
```
