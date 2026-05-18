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

| Script | Rôle | Fréquence |
|--------|------|-----------|
| `NOSTRCARD.refresh.sh` | Mise à jour MULTIPASS, publication IPNS, scrapers cookies | Quotidien |
| `PLAYER.refresh.sh` | Paiements ZENCard, dispatch ZINEs, TiddlyWiki refresh | Quotidien |
| `TW.refresh.sh` | Sync wiki personnel, graph N² constellation | Quotidien |
| `NOSTR.UMAP.refresh.sh` | Posts géo UMap, graphe social N² | Quotidien |
| `ZEN.ECONOMY.sh` | Moteur économique coopératif (3×PAF, 3×1/3) | Déclenché par `20h12.process.sh` |
| `G1PalPay.sh` | Surveillance des transactions Ğ1 | Continu |
| `VISA.new.sh` | Création nouveau portefeuille / joueur | À la demande |
| `DRAGON_p2p_ssh.sh` | Découverte et activation des tunnels P2P SSH/IPFS | Au démarrage |

---

## IA/ — Intelligence artificielle

| Script | Rôle | Mode |
|--------|------|------|
| `bro_dm_daemon.sh` | Daemon DM NOSTR NIP-44 (bro_ia, udrive, comfyui) | Lancé par `_12345.sh`, watchdog 300s |
| `UPlanet_IA_Responder.sh` | Responder IA : BRO, image, vidéo, musique | À la demande |
| `comfyui.me.sh` | Swarm ComfyUI : local → P2P → SSH, load-balancing power_score | À la demande |
| `nostr_node_intercom.py` | Canal inter-NODE NIP-44 : send/receive/decrypt | Démon |

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
| `G1CopierYoutube.sh` | Téléchargement YouTube → IPFS + publication kind 21 |

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
- [how-to/ASTROSYSTEMCTL.md](../how-to/ASTROSYSTEMCTL.md) — utilisation d'astrosystemctl
