# Astroport.ONE — Guide d'installation rapide

Astroport.ONE transforme votre machine en station Web3 personnelle (IPFS + NOSTR + G1).
Deux modes d'installation : **Système** (bare metal) ou **Docker**.

---

## Mode A : Installation Système (bare metal)

### Prérequis

- Debian / Ubuntu / Mint Linux
- Utilisateur non-root avec `sudo`
- Connexion internet

### Installation

```bash
git clone --recurse-submodules https://github.com/papiche/Astroport.ONE.git
cd Astroport.ONE
./install.sh
```

L'installeur va :
1. Installer IPFS Kubo (si absent)
2. Installer les paquets système (git, jq, ffmpeg, imagemagick, qrencode, etc.)
3. Installer Python3 + venv (`~/.astro/`) avec les bibliothèques crypto
4. Installer TiddlyWiki, gcli (Duniter v2s), strfry (NOSTR relay), G1Billet
5. Cloner le code dans `~/.zen/Astroport.ONE`
6. Configurer systemd, SSH, cron, IPFS
7. Lancer `setup.sh` (hostname, IPFS, `.env`, NPM)

### Post-installation

```bash
# Embarquement UPlanet ẐEN (rejoindre une coopérative)
~/.zen/Astroport.ONE/uplanet_onboarding.sh

# Ou embarquement capitaine simple
~/.zen/Astroport.ONE/captain.sh
```

### Gestion des services

```bash
# Démarrer / Arrêter
./start.sh        # ipfs, astroport, g1billet, upassport
./stop.sh

# Tests
make tests        # shellcheck + shellspec
./test.sh         # test d'intégration manuel
```

### Services systemd

| Service | Description |
|---|---|
| `astroport` | API Station Map (12345) |
| `ipfs` | IPFS daemon |
| `upassport` | UPassport FastAPI (54321) |
| `strfry` | NOSTR relay (7777) |
| `g1billet` | G1Billet (33101) |

### Données

Toutes les données sont dans `~/.zen/` :
- `~/.zen/game/players/` — Comptes joueurs et clés
- `~/.zen/game/nostr/` — Identités NOSTR
- `~/.zen/tmp/` — Cache, logs, swarm
- `~/.ipfs/` — Identité IPFS + datastore
- `~/.zen/Astroport.ONE/.env` — Configuration domaine et économie

---

## Mode B : Installation Docker

### Prérequis

- Docker Engine 24+ avec `docker compose` (v2)
- Un nom de domaine pointant vers le serveur (A record + sous-domaines)
- Ports ouverts sur le firewall : **80**, **443**, **4001**, **12345**

### Démarrage rapide (UPlanet ORIGIN)

Le mode par défaut rejoint le réseau public ORIGIN (swarm.key `000...0`) :

```bash
cd docker/
docker compose up -d
```

L'entrypoint va automatiquement :
- Cloner/mettre à jour le code Astroport.ONE
- Initialiser IPFS avec la swarm.key ORIGIN
- Générer le fichier `.env` pour le domaine `copylaradio.com`
- Créer le compte capitaine (email auto-généré)
- Démarrer IPFS + l'API Station Map

### Avec votre domaine

```bash
ASTRO_DOMAIN=mondomaine.fr docker compose up -d
```

Sous-domaines à configurer (DNS) :

| Sous-domaine | Service |
|---|---|
| `astroport.mondomaine.fr` | Station Map |
| `ipfs.mondomaine.fr` | IPFS Gateway |
| `relay.mondomaine.fr` | NOSTR Relay |
| `u.mondomaine.fr` | UPassport API |
| `cloud.mondomaine.fr` | NextCloud (optionnel) |

### Mode UPlanet ẐEN (réseau coopératif privé)

Pour rejoindre un réseau ẐEN, fournir la **swarm.key** IPFS et l'**email du capitaine** :

```bash
CAPTAIN_EMAIL=capitaine@mondomaine.fr \
IPFS_SWARM_KEY=a1b2c3d4e5f6...64caractères_hex \
ASTRO_DOMAIN=mondomaine.fr \
docker compose up -d
```

> **Important** : en mode ẐEN, le portefeuille capitaine est dérivé de `UPLANETNAME.CAPTAIN_EMAIL`.
> Sans `CAPTAIN_EMAIL`, un email est auto-généré et les portefeuilles coopératifs ne correspondront pas au réseau ẐEN cible.

### Paramètres économiques

```bash
CAPTAIN_EMAIL=cap@zen.coop \
IPFS_SWARM_KEY=<hex64> \
ASTRO_DOMAIN=zen.coop \
MACHINE_VALUE_ZEN=1000 \
PAF=20 \
NCARD=2 \
ZCARD=5 \
docker compose up -d
```

| Variable | Défaut | Description |
|---|---|---|
| `MACHINE_VALUE_ZEN` | 500 | Valeur de la machine en ZEN |
| `PAF` | 14 | Coût hebdomadaire du noeud (ZEN) |
| `NCARD` | 1 | Frais hebdomadaire MULTIPASS (ZEN) |
| `ZCARD` | 4 | Frais hebdomadaire ZenCard (ZEN) |

### Avec NextCloud

```bash
docker compose --profile full up -d
```

Documentation : https://pad.p2p.legal/NextCloud#

### Fichier `.env` (recommandé)

Créez `docker/.env` pour éviter de passer les variables à chaque fois :

```bash
# docker/.env
ASTRO_DOMAIN=mondomaine.fr
CAPTAIN_EMAIL=cap@mondomaine.fr
IPFS_SWARM_KEY=a1b2c3d4e5f6...
MACHINE_VALUE_ZEN=500
PAF=14
NCARD=1
ZCARD=4
```

### Variables d'environnement Docker

| Variable | Défaut | Description |
|---|---|---|
| `ASTRO_DOMAIN` | `copylaradio.com` | Nom de domaine |
| `CAPTAIN_EMAIL` | *(auto-généré)* | Email du capitaine |
| `IPFS_SWARM_KEY` | `000...0` (ORIGIN) | Clé réseau privé IPFS (64 hex) |
| `MACHINE_VALUE_ZEN` | `500` | Valeur machine en ZEN |
| `PAF` | `14` | Coût hebdomadaire noeud |
| `NCARD` | `1` | Frais MULTIPASS |
| `ZCARD` | `4` | Frais ZenCard |
| `HOST_UID` | `1000` | UID utilisateur hôte |
| `HOST_GID` | `1000` | GID utilisateur hôte |
| `HOSTNAME` | `astroport` | Nom d'hôte du conteneur |

### Commandes utiles

```bash
# Logs
docker compose logs -f astroport

# Santé
curl http://127.0.0.1:54321/health

# Shell dans le conteneur
docker compose exec astroport bash

# Rebuild
docker compose build --no-cache astroport && docker compose up -d

# Arrêt
docker compose down

# Arrêt + suppression des volumes (PERTE DE DONNÉES)
docker compose down -v
```

---

## Ports exposés

| Port | Service | Système | Docker |
|---|---|---|---|
| 80 | HTTP (NPM) | — | Réseau |
| 443 | HTTPS (NPM) | — | Réseau |
| 4001 | IPFS Swarm P2P | Réseau | Réseau |
| 12345 | Station Map / UPSYNC | Réseau | Réseau |
| 81 | NPM Admin UI | — | Local |
| 8080 | IPFS Gateway | Local | Local (proxié NPM) |
| 5001 | IPFS API (admin) | Local | Local (ne jamais exposer) |
| 54321 | UPassport API | Local | Local (proxié NPM) |
| 7777 | NOSTR Relay | Local | Local (proxié NPM) |
| 33101 | G1Billet | Local | Local |

## Volumes persistants (Docker)

| Volume | Contenu |
|---|---|
| `astro_game` | Compte capitaine, clés joueurs, identités NOSTR |
| `astro_tmp` | Cache, swarm, logs |
| `astro_ipfs` | Identité IPFS + datastore |
| `astro_workspace` | Workspace UPlanet |
| `npm_data` | Configuration NPM |
| `npm_letsencrypt` | Certificats SSL |

## Architecture Docker

```
                        Internet
                   :80  :443  :4001  :12345
                     |    |     |      |
  ┌──────────────────┼────┼─────┼──────┼────────┐
  │             Docker (astronet)               │
  │                  │    │     │      │         │
  │  ┌───────────────▼────▼──┐  │  ┌──▼───────┐ │
  │  │   NPM (nginx)        │  │  │ Astroport │ │
  │  │   :80 :443 :81       │  │  │           │ │
  │  │                      │  │  │  :12345   │ │
  │  │ astroport.D ─────────┼──┼─▶  :8080    │ │
  │  │ ipfs.D ──────────────┼──┼─▶  :5001    │ │
  │  │ ipfs.D/12345/ ───────┼──┼─▶  :54321   │ │
  │  │ relay.D ─────────────┼──┼─▶  :7777    │ │
  │  │ u.D ─────────────────┼──┼─▶  :4001    │ │
  │  └──────────────────────┘  │  │  :33101   │ │
  │                            │  └───────────┘ │
  │  ┌──────────────────┐     │                 │
  │  │  NextCloud AIO   │◄────┘                 │
  │  │ (--profile full) │                       │
  │  └──────────────────┘                       │
  └─────────────────────────────────────────────┘
```

## NPM — Proxy hosts avec SSL

Au premier démarrage Docker, NPM est accessible sur `http://127.0.0.1:81` :
- Login par défaut : `admin@example.com` / `changeme`
- Le script `setup_npm.sh` configure automatiquement les proxy hosts

Le proxy `ipfs.DOMAIN` inclut un bloc `location /12345/` qui route vers le port 12345, permettant la découverte inter-stations via :
```
https://ipfs.DOMAIN/12345/?G1PUB=IPFSNODEID
```

## Support

- Issues : https://github.com/papiche/Astroport.ONE/issues
- Email : support@qo-op.com
- Licence : AGPL-3.0
