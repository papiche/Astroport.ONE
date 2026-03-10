# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Astroport.ONE is a decentralized Web3 platform combining IPFS storage, NOSTR identity, and G1 (June) libre currency. It turns a machine into a personal server ("Station") within the UPlanet cooperative ecosystem. The codebase is almost entirely **bash scripts** with some Python utilities.

Licensed under AGPL-3.0. Author: Fred (support@qo-op.com).

## Key Commands

### Installation
```bash
./install.sh          # Full install (requires non-root user with sudo)
./setup.sh            # Post-install system configuration (IPFS, systemd, SSH, cron)
./start.sh            # Start all services (ipfs, astroport, g1billet, upassport)
./stop.sh             # Stop services
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
- **`API/`** - HTTP API endpoint handlers (QRCODE.sh, SALT.sh, UPLANET.sh, PLAYER.sh, etc.)
- **`RUNTIME/`** - Background services and refresh cycles:
  - `G1PalPay.sh` - G1 currency transaction monitoring
  - `NOSTRCARD.refresh.sh` - MULTIPASS account management
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
- **`RUNTIME/TW/`** - TiddlyWiki templates and management
- **`templates/`** - HTML templates
- **`_DOCKER/`** - Docker Compose files (Duniter, NextCloud, PeerTube, etc.)
- **`specs/`** - ShellSpec test specs
- **`tests/`** - Integration test scripts

### Data Directory (`~/.zen/`)
All runtime data lives under `~/.zen/` (not in the repo):
- `~/.zen/game/players/` - Player data and keys
- `~/.zen/game/nostr/` - NOSTR identity data
- `~/.zen/tmp/` - Temp cache, logs, swarm data
- `~/.zen/.pid` - Service PID file

### Service Ports
| Port | Service |
|------|---------|
| 1234 | Twist BASH API (deprecated) |
| 12345 | Station Map / UPlanet cartography |
| 33101 | G1Billet |
| 54321 | UPassport FastAPI |
| 7777 | NOSTR Relay (strfry) |
| 8080/4001/5001 | IPFS Gateway |

### Systemd Services
- `astroport` - Main API server (`12345.sh`)
- `upassport` - UPassport API
- `strfry` - NOSTR relay
- `ipfs` - IPFS daemon
- `g1billet` - G1Billet service

## Development Notes

- Scripts are written in **bash** and must work on Debian/Ubuntu/Mint Linux
- Blockchain interaction uses **gcli** (Duniter v2s CLI) for payments and **GraphQL squid** for queries (balance, history, primal). Legacy tools silkaj/jaklis are deprecated
- The project depends on IPFS (Kubo), TiddlyWiki, gcli, Python 3 (with venv at `~/.astro/`), and numerous system packages
- Key generation is **deterministic** (based on email + geolocation), not random
- The economic system uses two tiers: UPlanet ORIGIN (1 Zen = 0.1 G1) and UPlanet Zen (1 Zen = 1 EUR)
- Geographic coordinates drive data organization via UMAP (0.01 deg), SECTOR (0.1 deg), REGION (1 deg) grid cells
- Most documentation is bilingual French/English, with French being primary
