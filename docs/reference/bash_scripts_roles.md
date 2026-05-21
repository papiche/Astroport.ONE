# Rôle des scripts Bash — Référence

Inventaire des scripts principaux d'Astroport.ONE avec leur rôle, fréquence d'exécution et dépendances clés.

> Pour la logique interne de chaque script, consultez le code source et les commentaires en tête de fichier.
> Ce document donne uniquement le **rôle fonctionnel** et les **points d'entrée**.

---

## Scripts racine (point d'entrée)

| Script | Rôle | Déclencheur |
|--------|------|-------------|
| `install.sh` | Installation bare-metal complète | Manuellement une fois |
| `start.sh` | Démarrage de tous les services | Boot / manuel |
| `stop.sh` | Arrêt propre des services | Manuel |
| `command.sh` | CLI d'administration de la station | Manuel |
| `12345.sh` | Lanceur de l'API station (port 12345) | systemd `astroport` |
| `_12345.sh` | API station — génère `12345.json` + watchdog DM daemon | Appelé par `12345.sh` |
| `20h12.process.sh` | Cycle économique quotidien | Cron 20h12 |

---

## RUNTIME/ — Services de fond

### Orchestrateur principal

| Script | Rôle | Fréquence |
|--------|------|-----------|
| `ZEN.ECONOMY.sh` | Moteur économique coopératif : collecte les PAF, applique la règle 3×1/3 (TREASURY/R&D/ASSETS), déclenche les sous-modules | Déclenché par `20h12.process.sh` |

### Identité et profils MULTIPASS

| Script | Rôle | Fréquence |
|--------|------|-----------|
| `NOSTRCARD.refresh.sh` | Mise à jour MULTIPASS, publication IPNS, scrapers cookies — lifecycle complet des identités | Quotidien |
| `PLAYER.refresh.sh` | Paiements ZENCard, dispatch ZINEs, TiddlyWiki refresh — cycle de vie des joueurs | Quotidien |
| `VISA.new.sh` | Création nouveau portefeuille / joueur | À la demande |
| `PLAYER.unplug.sh` | Déconnexion propre d'un joueur de la station (clôture TW, retrait cron, notification) | À la demande |

### Géographie et cartographie UPlanet

| Script | Rôle | Fréquence |
|--------|------|-----------|
| `NOSTR.UMAP.refresh.sh` | Posts géo UMap, graphe social N² — publie les événements NOSTR géolocalisés | Quotidien |
| `UPLANET.refresh.sh` | Rafraîchit les clés UPlanet (UMAP/SECTOR/REGION) et la cartographie | Quotidien |
| `GEOKEYS_refresh.sh` | Explore le swarm MAPNS — synchronise les clés géographiques découvertes dans l'essaim | Quotidien |
| `NODE.refresh.sh` | Rafraîchit la carte du nœud (MAP REFRESH) — met à jour `12345.json` et la position dans la constellation | Quotidien |

### Économie coopérative

| Script | Rôle | Fréquence |
|--------|------|-----------|
| `ZEN.COOPERATIVE.3x1-3.sh` | Allocation atomique 3×1/3 : distribue les revenus entre TREASURY, R&D et ASSETS selon l'anniversaire du Capitaine | Hebdomadaire |
| `ZEN.SWARM.payments.sh` | Vérifie et exécute les paiements hebdomadaires d'abonnements aux services swarm | Hebdomadaire |
| `ECONOMY.broadcast.sh` | Diffuse l'état économique de la station (santé financière, soldes) vers la constellation NOSTR | Quotidien |
| `G1PalPay.sh` | Surveillance des transactions Ğ1 entrant/sortant — déclenche les actions (MULTIPASS, ZENCard) | Continu |

### Voeux G1 (système de projets coopératifs)

| Script | Rôle | Fréquence |
|--------|------|-----------|
| `G1Voeu.sh` | Gestion d'un voeu G1 (titre, joueur, index) — crée/met à jour un engagement Ğ1 coopératif | À la demande |
| `VOEUX.create.sh` | Extraction et création de nouveaux voeux depuis le TiddlyWiki personnel (`[tag[voeu]]`) | Quotidien |
| `VOEUX.refresh.sh` | Rafraîchit les voeux G1 depuis TW — synchronise l'état des projets avec les soldes blockchain | Quotidien |

### Oracle et permis

| Script | Rôle | Fréquence |
|--------|------|-----------|
| `ORACLE.refresh.sh` | Maintien de l'écosystème des permis (WoTx2) — valide, renouvelle ou révoque les permis d'accès | Quotidien |

### Réseau P2P et essaim

| Script | Rôle | Fréquence |
|--------|------|-----------|
| `DRAGON_p2p_ssh.sh` | Découverte et activation des tunnels P2P SSH/IPFS dans le WoT | Au démarrage |
| `SWARM.discover.sh` | Découverte de l'essaim UPlanet — parcourt `~/.zen/tmp/swarm/*/12345.json`, évalue les capacités | Périodique |
| `BLOOM.Me.sh` | Génère ou rejoint un swarm privé — crée la configuration de groupe IPFS/swarm | À la demande |

### TiddlyWiki

| Script | Rôle | Fréquence |
|--------|------|-----------|
| `TW.refresh.sh` | Sync wiki personnel, graph N² constellation — publie le TW sur IPFS/IPNS | Quotidien |

---

## IA/ — Intelligence artificielle

Les scripts IA sont nombreux (50+). Seuls les scripts structurants sont listés ici — les modules de génération (image/vidéo/musique/speech) et les scrapers sont regroupés dans `IA/modules.list`.

### Démons et orchestration

| Script | Rôle | Mode |
|--------|------|------|
| `bro_dm_daemon.sh` | Daemon DM NOSTR NIP-44 — traite `bro_ia`, `udrive`, `comfyui_job/result` en temps réel via inotifywait | Lancé par `_12345.sh`, watchdog 300s |
| `UPlanet_IA_Responder.sh` | Responder IA : BRO, image, vidéo, musique — dispatche vers le module correct | À la demande |
| `nostr_node_intercom.py` | Canal inter-NODE NIP-44 : send/receive/decrypt entre stations | Démon |

### Modules de calcul (services swarm)

| Script | Rôle |
|--------|------|
| `comfyui.me.sh` | Swarm ComfyUI : local → P2P → SSH, load-balancing par `power_score` et queue depth |
| `ollama.me.sh` | Gestion service Ollama local (start/stop/status, pull modèles) |
| `open-webui.me.sh` | Gestion Open WebUI (chat IA membres) |
| `qdrant.me.sh` | Gestion base vectorielle Qdrant (start/stop, health check) |
| `mirofish.me.sh` | Simulation d'opinion (Mem0 + NOSTR) |
| `feed_mirofish.sh` | Alimentation du RAG MiroFish depuis NOSTR local |

### Génération de contenu

| Script | Rôle |
|--------|------|
| `generate_image.sh` | Génère image via ComfyUI ou Ollama vision |
| `generate_video.sh` | Génère vidéo (image-to-video) |
| `generate_music.sh` | Génère musique (Udio/local) |
| `generate_speech.sh` | Synthèse vocale (Orpheus TTS) |
| `generate_article.sh` | Génère article depuis contexte NOSTR |

### Scrapers domaine

| Script | Rôle |
|--------|------|
| `youtube.com.sh` | Scrape et archive vidéos YouTube → IPFS |
| `forum.monnaie-libre.fr.sh` | Scrape forum Ğ1 → embeddings Qdrant |
| `leboncoin.fr.sh` | Scrape annonces LeBonCoin → NOSTR |

> **Note :** L'intégralité des modules IA est référencée dans `IA/modules.list`.

---

## admin/ — Outils d'administration

Scripts déplacés hors de `tools/` pour séparer les outils du Capitaine des bibliothèques internes. Accessibles via symlinks `~/.local/bin/` (voir [LOCAL_BIN_SYMLINKS.md](../how-to/LOCAL_BIN_SYMLINKS.md)).

### admin/system/

| Script | Rôle | Symlink |
|--------|------|---------|
| `station-info.sh` | Affiche les 9 portefeuilles coopératifs ZEN.ECONOMY et l'IPFSNODEID | `station-info` |
| `astrosystemctl.sh` | CLI P2P cloud — compare Power-Score local/swarm, connecte/active services distants via tunnels IPFS | `astrosystemctl` |
| `cron_VRFY.sh` | Gestion des tâches cron (TOGGLE ON/OFF/RECALIBRATE, heure solaire 20h12) | — |
| `firewall.sh` | Gestion UFW : ports publics (22, 80, 443, 4001, 51820) + verrouillage localhost. Appelé au démarrage | — |
| `astroport_toggle.sh` | Bouton ON/OFF de la station via `cron_VRFY.sh` — icône bureau dynamique (ON/OFF) | — |
| `linux.kernels.clean.sh` | Nettoyage kernels Debian/Ubuntu : conserve les 3 derniers, purge APT, compacte journalctl | — |
| `setup_npm_dynamic.sh` | Crée dynamiquement un proxy host NPM pour exposer un tunnel P2P (`SERVICE PORT` → `service.DOMAIN`) | — |

### admin/monitor/

| Script | Rôle | Symlink |
|--------|------|---------|
| `heartbox_analysis.sh` | Analyse complète du hardware (CPU/RAM/GPU, Power-Score, services actifs). Cache 5 min dans `~/.zen/tmp/$IPFSNODEID/heartbox_analysis.json` | `heartbox_analysis.sh` |
| `heartbox_control.sh` | Interface CLI de gestion de la ♥️box — contrôle services, watchdog swarm, alertes capacité | — |
| `heartbox_prometheus_analysis.sh` | Variante Prometheus de heartbox_analysis — collecte métriques via `/metrics` pour intégration Grafana | — |
| `power_monitor.sh` | Wrapper PowerJoular : start/stop/report/status. Utilisé par `20h12.process.sh` pour mesure conso 24h | — |
| `generate_power_report.sh` | Génère rapport HTML de consommation électrique (graphe + stats 24h) | — |
| `generate_powerjoular_graph.py` | Génère graphes Python (matplotlib) depuis CSV PowerJoular | — |

### admin/swarm/

| Script | Rôle |
|--------|------|
| `SWARM.help.sh` | Guide d'aide interactif de l'essaim UPlanet — liste services, abonnements, paiements G1 disponibles dans le swarm |
| `SWARM.notifications.sh` | Envoie des notifications NOSTR (DM NIP-44) aux stations du swarm (alertes, annonces coopératives) |
| `wireguard_control.sh` | Gestion WireGuard LAN+IPFS multi-nœuds (`wg0`, port 51820) — add/remove peers, status, rotation clés |
| `wg-client-setup.sh` | Configuration client WireGuard pour rejoindre le VPN constellation (génère clés, configure interface) |

### admin/ia_db/

| Script | Rôle | Symlink |
|--------|------|---------|
| `codebase_index.sh` | Indexe le code source Astroport.ONE dans Qdrant via `nomic-embed-text`. `--incremental` pour mise à jour | `codebase_index.sh` |
| `knowledge_index.sh` | Indexe connaissances (.md/.pdf/NOSTR/uDRIVE) dans Qdrant. `--search`, `--stats`, `--reset` | `knowledge_index.sh` |

### admin/docker.sh

Script centralisé de gestion Docker pour le Capitaine — voir [install_docker.md](../tutorials/install_docker.md).

| Commande | Rôle |
|----------|------|
| `status` | État de tous les conteneurs |
| `update [service]` | Pull + redémarre uniquement les conteneurs modifiés |
| `logs [service]` | Logs en temps réel |
| `restart [service]` | Redémarrage |
| `clean` | Supprime images et volumes orphelins |
| `watchtower start\|stop\|status` | Gère les mises à jour automatiques |

---

## tools/ — Bibliothèque centrale

| Script/Outil | Rôle |
|--------------|------|
| `my.sh` | **Bibliothèque centrale** — variables d'env, fonctions utilitaires. Sourcé par presque tous les scripts |
| `keygen` | Générateur de clés déterministe (G1, IPFS, NOSTR) à partir d'email+passwd |
| `natools.py` | Opérations crypto NaCl (chiffrement, signature) |
| `heartbox_analysis.sh` | Analyse hardware : CPU/RAM/GPU, Power-Score, services. Cache `heartbox_analysis.json` |
| `astrosystemctl.sh` | CLI P2P cloud — list, connect, enable, disable, status. Symlink : `~/.local/bin/astrosystemctl` |
| `make_NOSTRCARD.sh` | Création identité MULTIPASS (NOSTR + Ğ1 + uDRIVE) |
| `nostr_setup_profile.py` | Publication profil NOSTR (kind 0 + NIP-39) |
| `G1wallet_v2.sh` | Opérations portefeuille Ğ1 (balance, history, transfer, uplanet, upassport) |
| `PAYforSURE.sh` | Paiements Ğ1 via gcli (Duniter v2s) avec retry |
| `G1impots.sh` | Calcul provisions fiscales TVA + IS depuis le wallet `UPLANET.IMPOT` → `/check_impots` |
| `G1revenue.sh` | Chiffre d'affaires ZENCOIN (param année optionnel) → `/check_revenue` |
| `G1society.sh` | Historique parts sociales SOCIÉTÉ wallet (opt `--nostr` pour DID kind 30800) → `/check_society` |
| `Umap_geonostr.sh` | Clés NOSTR déterministes des 9 UMAPs/SECTORs/REGIONs adjacentes à une coordonnée → `/api/umap/geolinks` |
| `duniter_getnode.sh` | Découverte dynamique des nœuds RPC/squid Duniter v2 |
| `cron_VRFY.sh` | Gestion et vérification des tâches cron |
| `setup_npm_dynamic.sh` | Crée dynamiquement un proxy host NPM pour un tunnel P2P |

---

## UPassport/ — Scripts Bash côté API

Scripts appelés par les routers FastAPI via `subprocess`.

| Script | Rôle | Déclencheur |
|--------|------|-------------|
| `check_ssss.sh` | Reconstruction clé DISCO via Shamir Secret Sharing (T=2/3) : valide format, résout IPNS, déchiffre part distante, combine, hydrate `~/.zen/game/nostr/{email}/.secret.disco` | `POST /ssss` |

---

## ASTROBOT/ — Contrats intelligents

Scripts `N1*.sh` — automatisations de smart contracts coopératifs.

| Pattern | Rôle |
|---------|------|
| `N1*.sh` | Commandes de niveau 1 (actions économiques automatisées) |
| `G1CopierYoutube.sh` | Téléchargement YouTube → IPFS + TW import + NIP-71 kind 21/22 + uDRIVE Videos/. Déclenché par voeu `CopierYoutube` dans le TW du joueur. |

## Scripts racine — Outils Capitaine

| Script | Rôle |
|--------|------|
| `ajouter_media.sh` | Interface GUI Zenity pour ajouter un média sur UPlanet : YouTube, MP3, PDF, Film/Série (TMDB), Vidéo personnelle, uDRIVE. Pipeline : téléchargement → IPFS → NIP-71/NIP-94 via UPassport API. Option IA : analyse Ollama + kind 30504 MineLife (en développement). |

---

## Conventions de nommage

- `*.sh` : scripts bash exécutables
- `*.py` : utilitaires Python (crypto, requêtes blockchain)
- `_*.sh` : variantes internes (non appelés directement par l'utilisateur)
- `*.refresh.sh` : processus de rafraîchissement périodique
- `N1*.sh` : smart contracts niveau 1 (ASTROBOT)

---

## Voir aussi

- [CLAUDE.md](../../CLAUDE.md) — architecture complète et patterns de code
- [how-to/LOCAL_BIN_SYMLINKS.md](../how-to/LOCAL_BIN_SYMLINKS.md) — inventaire des commandes du Capitaine (`~/.local/bin`) et journal `~/.zen/.astro`
- [how-to/ASTROSYSTEMCTL.md](../how-to/ASTROSYSTEMCTL.md) — utilisation d'`astrosystemctl`
- [how-to/SWARM_WIREGUARD.md](../how-to/SWARM_WIREGUARD.md) — VPN WireGuard constellation + modèle économique essaim
- [how-to/POWER_MONITORING.md](../how-to/POWER_MONITORING.md) — monitoring puissance PowerJoular
- [tutorials/install_docker.md](../tutorials/install_docker.md) — gestion Docker (`admin/docker.sh`)
