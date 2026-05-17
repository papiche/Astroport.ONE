# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Astroport.ONE is a decentralized Web3 platform combining IPFS storage, NOSTR identity, and G1 (June) libre currency. It turns a machine into a personal server ("Station") within the UPlanet cooperative ecosystem. The codebase is almost entirely **bash scripts** with some Python utilities.

Licensed under AGPL-3.0. Author: Fred (support@qo-op.com).

## Key Commands

### Bare Metal Installation
```bash
./install.sh          # Full install (requires non-root user with sudo)
./start.sh            # Start all services (ipfs, astroport, g1billet, upassport)
./stop.sh             # Stop services
```

### Docker Installation
```bash
cd docker/
docker compose up -d                            # core : Astroport + NPM
docker compose --profile cloud up -d           # + NextCloud AIO
docker compose --profile ai up -d              # + Open WebUI + Mirofish + Qdrant + Vane
docker compose --profile dev up -d             # + rnostr (relay NOSTR Rust, port 8888)
docker compose --profile updates up -d         # + Watchtower (auto-update)
docker compose --profile full up -d            # cloud + ai + updates
docker compose logs -f astroport               # Follow logs

# GPU NVIDIA (overlay) :
docker compose -f docker-compose.yml -f docker-compose.gpu.yml --profile ai up -d

# Domaine personnalisé :
ASTRO_DOMAIN=mydomain.tld docker compose up -d

# Secrets IA (générer avant --profile ai) :
install/install-ai-company.docker.sh --check   # Vérifier compatibilité
install/install-ai-company.docker.sh           # Générer secrets + démarrer stack IA
```

### Testing
```bash
make tests            # Run all tests (shellcheck + shellspec)
make check            # Run shellcheck on all .sh files (non-fatal)
make specs            # Run shellspec specs (specs/ directory)
./test.sh             # Manual integration test (TiddlyWiki, IPFS, keygen, gcli, GraphQL, QR)
```

Run shellcheck on a specific directory:
```bash
make shellcheck-tools       # Lint tools/*.sh
make shellcheck-RUNTIME     # Lint RUNTIME/*.sh
```

Run shellspec specs:
```bash
shellspec -f tap specs      # Run specs/astroport_spec.sh
```

Test subsystems individually:
```bash
./tests/test_all_systems.sh          # Run all subsystem tests
./tests/test_did_system.sh           # Test DID system
./tests/test_oracle_system.sh        # Test Oracle system
./tests/test_ore_system.sh           # Test ORE system
```

### Linting
ShellCheck is the linter. All shell scripts should pass `shellcheck`.

## Architecture

### Core Script Pattern
Every bash script follows this initialization pattern:
```bash
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "${MY_PATH}/tools/my.sh"    # Load shared environment/functions
```

`tools/my.sh` is the central function library - it provides environment variables (`$IPFSNODEID`, `$CAPTAING1PUB`, `$CAPTAINEMAIL`, etc.) and utility functions (`myAstroPath()`, `myDate()`, `myDomainName()`, etc.).

### Directory Structure

- **`command.sh`** - Main CLI interface for station management
- **`12345.sh`** / **`_12345.sh`** - API server (port 1234 launcher / port 12345 station map)
- **`20h12.process.sh`** - Daily cron maintenance process
- **`IA/`** - Modules IA et communication inter-NODE :
  - `bro_dm_daemon.sh` - Daemon DM NOSTR (NIP-44) — traite bro_ia, udrive, comfyui_job/result en temps réel via inotifywait. **Lancé et surveillé par `_12345.sh`** (watchdog toutes les 300s)
  - `UPlanet_IA_Responder.sh` - Responder IA pour les stations UPlanet (BRO, image, vidéo, musique)
  - `comfyui.me.sh` - Swarm Connector ComfyUI : local → P2P → SSH, avec load-balancing par power_score et queue depth
  - `nostr_node_intercom.py` - Canal inter-NODE NIP-44 : send/receive/decrypt de DMs chiffrés entre stations
- **`RUNTIME/`** - Background services and refresh cycles:
  - `G1PalPay.sh` - G1 currency transaction monitoring
  - `NOSTRCARD.refresh.sh` - MULTIPASS account management (ne lance plus le daemon DM — géré par `_12345.sh`)
  - `PLAYER.refresh.sh` - ZenCard account management
  - `ZEN.ECONOMY.sh` - Cooperative economy engine
  - `VISA.new.sh` - New player/wallet creation
  - `DRAGON_p2p_ssh.sh` - P2P SSH/IPFS discovery
- **`ASTROBOT/`** - Smart contract automation scripts (N1*.sh commands)
- **`tools/`** - Utility scripts and libraries:
  - `my.sh` - Shared environment and functions (sourced by almost every script)
  - `keygen` - Key generator (G1, IPFS, NOSTR)
  - `natools.py` - NaCl crypto operations (Python)
  - `G1balance.sh`, `G1check.sh`, `G1history.sh`, `G1primal.sh` - G1 blockchain queries via GraphQL squid
  - `G1wallet_v2.sh` - Full G1 wallet operations (balance, history, transfers, uplanet, upassport)
  - `PAYforSURE.sh` - G1 payments via gcli (Duniter v2s)
  - `duniter_getnode.sh` - Dynamic Duniter v2 RPC/squid node discovery
  - `cron_VRFY.sh` - Cron job management
  - `make_NOSTRCARD.sh` - NOSTR Card creation
  - `heartbox_analysis.sh` - Hardware analysis: CPU/RAM/GPU, Power-Score, services status, Ollama models. Cached in `~/.zen/tmp/$IPFSNODEID/heartbox_analysis.json`
  - `astrosystemctl.sh` - **CLI Cloud P2P de Puissance** : compare Power-Score local vs swarm, connecte/active des services distants via tunnels IPFS P2P (`list`, `list-remote`, `connect`, `enable`, `disable`, `status`). Symlink : `~/.local/bin/astrosystemctl`
  - `setup_npm_dynamic.sh` - Crée dynamiquement un proxy host NPM pour un tunnel P2P (`SERVICE_NAME PORT` → `service.DOMAIN`)
- **`RUNTIME/TW/`** - TiddlyWiki templates and management
- **`templates/`** - HTML templates
- **`install/`** - Secondary install scripts (build-time):
  - `install_system.sh` - Sudoers, systemd, SSH, symlinks (dont `astrosystemctl`)
  - `install_upassport.sh`, `install_gcli.sh`, `install_deno.sh`, etc.
  - `setup/` - Runtime configuration scripts:
    - `setup.sh` - Hostname, IPFS init, .env, cron, captain onboarding
    - `ipfs_setup.sh` - IPFS node initialization
    - `setup_npm.sh` - Nginx Proxy Manager auto-configuration
- **`docker/`** - Docker deployment:
  - `docker-compose.yml` - Full stack (Astroport + NPM + NextCloud)
  - `astroport/Dockerfile` - Astroport container image
  - `astroport/astroport.sh` - Container entrypoint
- **`_DOCKER/`** - Third-party service configs (Duniter, PeerTube, etc.)
- **`specs/`** - ShellSpec test specs
- **`tests/`** - Integration test scripts

### Data Directory (`~/.zen/`)
All runtime data lives under `~/.zen/` (not in the repo):
- `~/.zen/game/players/` - Player data and keys
- `~/.zen/game/nostr/` - NOSTR identity data
- `~/.zen/tmp/` - Temp cache, logs, swarm data
- `~/.zen/tmp/$IPFSNODEID/heartbox_analysis.json` - Hardware analysis cache (5 min TTL), inclut `power_score`, `provider_ready`, `gpu`
- `~/.zen/tunnels/enabled/` - Tunnels P2P persistants (watchdog 20h12). Créés par `astrosystemctl enable`
- `~/.zen/.pid` - Service PID file

### Power-Score (GPS de Calcul)
Chaque station calcule son Power-Score = `GPU_VRAM_GB × 4 + CPU_cores × 2 + RAM_GB × 0.5`

| Score | Tier | Profil | Rôle |
|-------|------|--------|------|
| 0–10  | 🌿 Light   | Raspberry Pi Zero/3 | Consommateur uniquement |
| 11–40 | ⚡ Standard | PC bureautique | Petits modèles locaux |
| 41+   | 🔥 Brain    | GPU dédié | Fournisseur swarm |

Le score est publié dans `12345.json` via `capacities.power_score` et `capacities.provider_ready`.
`astrosystemctl list-remote` parcourt `~/.zen/tmp/swarm/*/12345.json` pour afficher les Brain-Nodes disponibles.

### Service Ports
| Port | Service | Subdomain |
|------|---------|-----------|
| 12345 | Station Map / UPlanet cartography | `astroport.DOMAIN` |
| 8080/4001/5001 | IPFS Gateway/Swarm/API | `ipfs.DOMAIN` |
| 7777 | NOSTR Relay (strfry — actuel, rnostr prévu) | `relay.DOMAIN` |
| 8888 | rnostr internal (metrics/admin, prévu) | localhost only |
| 54321 | UPassport FastAPI | `u.DOMAIN` |
| 33101 | G1Billet | `libra.DOMAIN` |
| 80/443/81 | Nginx Proxy Manager (SSL) | — |
| 8002/8443 | NextCloud AIO admin | `cloud.DOMAIN` |
| 11434 | Ollama LLM (via tunnel ou local) | `ollama.DOMAIN` (dynamique) |
| 8188 | ComfyUI (via tunnel ou local) | `comfyui.DOMAIN` (dynamique) |
| 1234 | Twist BASH API (deprecated) | — |

### Systemd Services (bare metal)
- `astroport` - Main API server (`12345.sh`)
- `upassport` - UPassport API
- `strfry` - NOSTR relay (port 7777 — binaire aussi utilisé pour DB locale : scan/import/delete)
- `rnostr` - Futur relay NOSTR Rust (remplacera strfry sur port 7777, migration planifiée)
- `ipfs` - IPFS daemon
- `g1billet` - G1Billet service

### Docker Services (docker-compose)
Réseau unique **`dragon-net`** — tous les services se joignent par nom de conteneur.

| Service | Profil | Port hôte | Rôle |
|---------|--------|-----------|------|
| `astroport` | core | 4001, 12345, 7777, 54321, 8080… | Station Web3 (IPFS+NOSTR+G1) |
| `npm` | core | 80, 443, 127.0.0.1:81 | Nginx Proxy Manager (SSL) |
| `nextcloud` | cloud, full | 127.0.0.1:8002, 8443 | NextCloud AIO (128Go/ZenCard) |
| `open-webui` | ai, full | 127.0.0.1:8000 | Chat IA membres (Ollama backend) |
| `mirofish` | ai, full | 127.0.0.1:5050 | Simulation opinion (Mem0+NOSTR) |
| `qdrant` | ai, full | 127.0.0.1:6333 | Base vectorielle souveraine |
| `vane` | ai, full | 127.0.0.1:3002 | Recherche IA augmentée |
| `rnostr` | dev | 127.0.0.1:8888, 9999 | Relay NOSTR Rust (migration strfry) |
| `watchtower` | updates, full | — | Auto-update conteneurs labelisés |

Labels utilisés :
- `astroport.monitor=true` → diffuse la santé au swarm (astrosystemctl)
- `com.centurylinklabs.watchtower.enable=true` → mis à jour par Watchtower

GPU overlay : `docker/docker-compose.gpu.yml` — ajoute `deploy.resources.reservations` NVIDIA sur `open-webui`.

## Deployment Modes

### Bare Metal (Debian/Ubuntu/Mint)
`install.sh` handles everything: apt packages, IPFS, Python venv, git clone, then calls:
1. `install/install_system.sh` — build-time ops (sudoers, systemd, SSH, symlinks)
2. `install/setup/setup.sh` — runtime ops (hostname, IPFS init, .env, NPM, captain)

### Docker
`docker/docker-compose.yml` orchestre jusqu'à 9 services sur le réseau **`dragon-net`** (pont unique). Deux fichiers compose :
- `docker/docker-compose.yml` — compose principal (profiles: core/cloud/ai/dev/updates/full)
- `docker/docker-compose.gpu.yml` — overlay GPU NVIDIA (à superposer avec `-f` pour le profil `ai`)

The entrypoint (`docker/astroport/astroport.sh`) runs idempotent setup on each start:
- IPFS init (if no repo), .env generation, captain onboarding (once only)
- Domain configurable via `ASTRO_DOMAIN` env var (default: `copylaradio.com`)

SSL is managed by NPM:
- `copylaradio.com` → skip (managed centrally by support@qo-op.com)
- Local domains → self-signed certificates (openssl)
- Public domains → Let's Encrypt (automatic)

### Install/Setup Separation (Docker-ready)
- `install/` — build-time (Dockerfile RUN): packages, binaries, config files
- `install/setup/` — runtime (entrypoint): identity, keys, network, .env, cron

## Development Notes

- Scripts are written in **bash** and must work on Debian/Ubuntu/Mint Linux
- Blockchain interaction uses **gcli** (Duniter v2s CLI) for payments and **GraphQL squid** for queries (balance, history, primal). Legacy tools silkaj/jaklis are deprecated
- The project depends on IPFS (Kubo), TiddlyWiki, gcli, Python 3 (with venv at `~/.astro/`), and numerous system packages
- Key generation is **deterministic** (based on email + geolocation), not random
- The economic system uses two tiers: UPlanet ORIGIN (1 Zen = 0.1 G1) and UPlanet Zen (1 Zen = 1 EUR)
- Geographic coordinates drive data organization via UMAP (0.01 deg), SECTOR (0.1 deg), REGION (1 deg) grid cells
- Most documentation is bilingual French/English, with French being primary
