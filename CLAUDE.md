# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Astroport.ONE is a decentralized Web3 platform combining IPFS storage, NOSTR identity, and G1 (June) libre currency. It turns a machine into a personal server ("Station") within the UPlanet cooperative ecosystem. The codebase is almost entirely **bash scripts** with some Python utilities.

Licensed under AGPL-3.0. Author: Fred (support@qo-op.com).

## Key Commands

### Bare Metal Installation
```bash
./install.sh                          # Standard : IPFS + NOSTR + G1 (interactif)
./install.sh "" "" "" nextcloud       # Standard + NextCloud AIO (cloud privé 128Go)
./install.sh "" "" "" ai-company      # Standard + Stack IA (Ollama, Open WebUI, Qdrant)
./install.sh "" "" "" dev             # Standard + rnostr (relay NOSTR Rust)
./start.sh                            # Start all services (ipfs, astroport, upassport)
./stop.sh                             # Stop services
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
  - `bro_dm_daemon.sh` - Daemon DM NOSTR (NIP-44) — traite udrive, comfyui_job/result en temps réel via inotifywait. **Lancé et surveillé par `_12345.sh`** (watchdog toutes les 300s)
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
  - `emit_skill.sh SKILL [LEVEL] [CID] [ICON] [DESC]` - Publie Kind 30503 (compétence WoTx², auto-attestée)
  - `emit_object.sh TITLE [TYPE] [KEY=VAL…]` - Publie Kind 30505 (objet/ressource physique ou logique)
  - `kin_oracle.sh` — Bibliothèque Dreamspell (tables, HTML cartes, GPS haversine, `_kin_meeting_block` avec Kin synchrone)
  - `kin_prefs.sh` — Préférences KIN par membre : `_kin_prefs_load EMAIL`, `_kin_type_enabled TYPE`, `_kin_build_scan_filter HEX`. Lit `~/.zen/game/nostr/EMAIL/.mailjet` (JSON géré par UPassport `/mailjet`)
  - `kin.sh` — Tables Dreamspell CLI + `KIN_TONE_KEYS[]` (Action|Pouvoir|Essence par tonalité)
- **`admin/`** - Tableaux de bord Capitaine (interfaces CLI interactives) :
  - `dashboard.sh` — Menu général de la station
  - `dashboard.WOTX2.manager.sh` — WoTx² / Grimoire / Oracle (Kind 30503–30508, objets, justice)
  - `dashboard.JUSTICE.manager.sh` — Protocole médiation (Kind 30506/1506/1984)
  - `dashboard.MAILJET.sh` — Notifications email : config clés API, opt-outs, prefs KIN, test envoi, logs
  - `dashboard.DID.manager.sh` — Identités DID / MULTIPASS
  - `dashboard.TUBE.manager.sh` — NostrTube (vidéos Kind 21/22)
  - `dashboard.COOKIE.manager.sh` — Cookies de session
- **`admin/monitor/`** - Monitoring et métriques :
  - `heartbox_analysis.sh` - Hardware analysis: CPU/RAM/GPU, Power-Score, services status, Ollama models. Cached in `~/.zen/tmp/$IPFSNODEID/heartbox_analysis.json`
- **`admin/system/`** - Gestion système P2P :
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

### Mémoire de BRO, embeddings et mémoire d'ARBOR (`IA/`, depuis 2026-10-19)

**Un seul modèle d'embedding** : `IA/embed_config.py` (`bge-m3`, 1024 d) porte le modèle ET les seuils mesurés
(`threshold("recall"|"topic"|"intent_margin"|"cluster"|"doc")`). Ne jamais coder un modèle, une dimension ou un
seuil en dur ; un autre modèle exige de re-mesurer. Collections reconstructibles (routage, rubriques, index) : recréées
seules si la dimension diffère ; la mémoire des utilisateurs et `arbor_memory` (historique) : jamais, elles lèvent.

**Mémoire personnelle** (`memory_manager.py`, collection `memory_<hex16>` par MULTIPASS) : schéma `kind`
(fact|episode|trait|person) · `source` · `visibility` (private|love) · `confidence` · `status`
(active|superseded|deleted). Plus de slots numérotés (`SLOT_SCHEMA` traduit les anciens appels). Id = hash du contenu :
écrire deux fois = un seul point. `unstorable_reason()` refuse tout secret (clé, mot de passe) — appelée aussi par le
journal des demandes d'ARBOR.

**Apprentissage** (`memory_writer.py` + `memory_sources.py`) : BRO écrit sa mémoire seul (extraction de faits par LLM,
décision ADD/UPDATE/DELETE, demandes « oublie… »). Consentement PAR SOURCE dans NOSTR (kind 31903 `d=memory_sources`,
chiffré NIP-44 pour soi) : chat (défaut) · love_dm · nostr_public · mastodon · agenda · contact ; les photos seulement
sur geste dans FaceCloud (`/api/cloud/memory/remember`). **N'apprendre que de canaux AUTHENTIFIÉS** (DM déchiffré,
self-DM) — jamais Telegram, Mastodon ou roaming (n'importe qui peut y écrire). Agenda et contacts : texte
déterministe, jamais de téléphone/e-mail/adresse. LOVE : souvenirs `visibility=love` seulement, comparaison entre deux
comptes de CETTE station (la synchro N² ne constitue aucune base globale). Interface : Mon compte › « Ce que BRO sait de moi ».

**Mémoire d'ARBOR** (`arbor_memory.py`, `code_chunker.py`) : l'index du code (`admin/ia_db/codebase_index.sh`) a UN
vecteur par fonction/classe/bloc (avec lignes) ; il cherche chaque projet sous plusieurs racines (dépôt de travail
`~/workspace/AAA/*` OU station `~/.zen/{Astroport.ONE,UPassport}` + `~/.zen/workspace/{NIP-101,UPlanet}`). ARBOR (dialogue
`arbor_chat`, forges `arbor_tool_forge`/`arbor_scraper_forge`, `arbor_self_improve`) retrouve le code pertinent
(lecture seule) et ses tentatives passées (collection `arbor_memory` : but, résultat, CAUSE de l'échec) et les enregistre.
Chaque appel est entouré d'un try/except qui DIT l'échec : jamais de repli muet.

**Qualité et garde-fous de l'apprentissage** (2026-10-19) : `IA/eval_memory.py` (jeu `IA/tests/eval_memory_cases.json`,
compte jetable) MESURE rappel hit@3, faux rappels hors-sujet, fuite de souvenirs obsolètes, oubli durable, protections,
secrets, extraction par le LLM (faux souvenirs) et corrections — à rejouer après tout changement de modèle d'embedding,
de seuil ou de consigne (sans option : embeddings seuls, ~2 s ; `--llm` ajoute extraction et corrections, ≈ 10-15 appels
espacés — le GPU est partagé ; code 1 sous un seuil). Garde-fous : supprimer un souvenir
(écran Mon compte ou « oublie… » dit à BRO) EFFACE le texte mais laisse une pierre tombale (`status=deleted`,
`deleted_by=user`, vecteur sans contenu) : seules les sources passives sont bloquées (exact ET reformulé, cosinus ≥
`TOMBSTONE_MIN` 0,85), le canal « chat » peut toujours se reprendre ; un souvenir écrit ou corrigé par la personne
(`origin=user`, `edited`, source manual/rec — `mm.is_pinned`) n'est ni remplacé ni supprimé par une source passive et
sa visibilité survit à la relecture (`upsert_memory(auto=True)`) ; confiance minimale 0,6 (chat) / 0,7 (autres) ;
demande d'oubli honorée seulement depuis le chat, bornée à 3 souvenirs (sinon « trop vague », rien d'effacé) ; les
épisodes (hors photos) perdent jusqu'à 0,08 de score en un an (classement seulement) ; secrets : mots de passe, PIN,
IBAN, cartes, NIR, clés d'API en plus de nsec/key_hex. BRO dit « je me souviens que… » quand un souvenir nourrit sa
réponse (`question.py`). Tests : `IA/tests/test_memory_guards.py`.

**GPU partagé (RTX 3090, Ollama + ComfyUI par ipfs p2p)** : `IA/gpu_headroom.py ensure(modèle)` se place AVANT tout appel
Ollama qui peut charger un modèle. Voie rapide : modèle déjà chargé (`/api/ps`, cache 3 s) ; sinon poids × 1,1 + marge
+ réserve ComfyUI comparés à la VRAM libre de la carte (`/system_stats` de ComfyUI) + modèles Ollama déchargeables ;
insuffisant et ComfyUI inactif → `/free` ; ComfyUI occupé → attente puis `GpuBusy` (message explicite, jamais de repli
silencieux ; ComfyUI injoignable = on passe et on journalise). Branché (sens Ollama) sur `question.py`, `memory_manager` (_embed, résumé RÊVE), `embed_config.embed`, `embed.py`,
`describe_image.py` (attente 300 s), `inventory_recognition`, `bro/tools.py`, `code_assistant`, `a_quoi_ca_sert`,
`admin/ia_db/codebase_index.py`, `UPassport/services/{ucloud_embed,story_assistant}.py` et les `curl` bash
(`generate_storyboard.sh`, `bro/nextcloud_bro_sync.sh`, `bro/love_handler.sh`, via `gpu_headroom.py check --model M`,
code 3 = occupé). SENS INVERSE (`make_room_for_comfy` / `gpu_headroom.py comfy-room --need-gb N`, bash :
`IA/generators/lib/gpu_room.sh::gpu_make_room N étiquette`) avant tout `POST /prompt` : VRAM totale − VRAM résidente
d'Ollama ≥ besoin + réserve, sinon les modèles Ollama sont déchargés du plus gros au plus petit (`keep_alive: 0`, après
leurs requêtes en cours) ; branché sur `generate_image` (12 Go), `generate_video` et `image_to_video` (20), `generate_music`
(8), `generate_minimax` (2), `apply_lipsync` (10), `generate_transcription` (4), `faceid.sh` (3, revérifié toutes les 30 s
en lot), `image_to_3dscene.py` (10). ⚠️ Ces besoins sont des estimations PRUDENTES NON MESURÉES (`GPU_NEED_OVERRIDE=<Go>`
pour un lancement) ; `generate_scene.sh` s'appuie sur ces sous-scripts. Réglages : `GPU_HEADROOM_WAIT/RESERVE_GB/
MARGIN_GB/ALLOW_COMFY_FREE/ALLOW_OLLAMA_UNLOAD`, `GPU_HEADROOM_OFF=1`. Les `curl` restants non branchés : `ollama.me.sh`
(c'est lui qui décharge) et tout nouvel appelant — le réflexe : `gpu_headroom.ensure(modèle)` avant d'appeler Ollama,
`gpu_make_room` avant de soumettre à ComfyUI. **Instrumentation des appels au GPU** (2026-10-20) : `IA/ollama_metrics.py` écrit UNE ligne JSON par appel Ollama dans
`~/.zen/log/ollama_calls_AAAAMMJJ.jsonl` (gzip > 2 j, purge > 30 j par `20h12.process.sh`) : source (`OLLAMA_SOURCE`, sinon
contexte `with source(...)`, sinon le script), type (chat|generate|embed|vision|gpu_wait|gpu_busy|comfy_room), modèle, durées
(`wall_ms`, `load_ms` = chargement du modèle : > 0,5 s = démarrage à froid), jetons, jet/s, contexte, erreur — JAMAIS de
contenu. Branché sur TOUS les appelants Ollama : `question.py`, `memory_manager`, `embed_config.embed`, `embed.py`,
`describe_image.py`, `inventory_recognition`, `bro/tools.py`, `code_assistant`, `a_quoi_ca_sert` (ces quatre via
`ollama_metrics.chat(**kwargs)` = garde-fou VRAM + mesure), `admin/ia_db/codebase_index.py`,
`UPassport/services/{ucloud_embed,story_assistant}.py`, les scripts bash (`generate_storyboard.sh`,
`bro/nextcloud_bro_sync.sh` : CLI `python3 IA/ollama_metrics.py record --kind K --model M --wall-ms N --source S <<< "$réponse"`,
une réponse vide = échec ; `bro/love_handler.sh` : dans son Python) et les évènements de `gpu_headroom` (attente de VRAM, refus,
déchargements d'Ollama pour ComfyUI). Lecture : `python3 IA/ollama_stats.py [--days N] [--json] [--include-tests]`.
**Rendu status.html (carte « 🎮 Usage du GPU partagé »)**, mêmes couches que Solaire/Consommation : (1) `20h12.process.sh`
lance `ollama_stats.py record-daily` (agrège les 3 derniers jours des journaux dans l'historique PERMANENT
`~/.zen/game/gpu/gpu_history.json`, idempotent) ; (2) `ollama_stats.py publish-cid` épingle l'historique et n'écrit que le CID dans
`~/.zen/tmp/$IPFSNODEID/GPU/gpu_history.json.ipfs` ; (3) `_12345.sh` expose l'instantané léger `gpu_usage` (jour, 7 jours,
heures de pointe — `ollama_stats.py gpu-stats`, erreurs dans `~/.zen/log/gpu_stats_12345.log`) et l'intègre au fingerprint
`NODE_STATE` ; (4) `templates/status.html::renderGpu` : 4 chiffres, graphique par jour (Appels / À froid / Latence / Attentes
VRAM × 7/30/90/Tout), histogramme des heures d'usage, détail (modèle et source principaux, places faites pour ComfyUI).
Chaque station n'y voit que SES appels. **Jobs ComfyUI** (kind `comfy`, 2026-10-20) : `gpu_comfy_watch <étiquette> <prompt_id>`
(`generators/lib/gpu_room.sh`, juste après la soumission à `/prompt`) lance un observateur DÉTACHÉ (`ollama_metrics.py comfy`) qui
suit `/history/<id>` puis enregistre `exec_ms` (début→fin), `queue_ms` (création→début : l'attente derrière les autres jobs de la
carte), `wall_ms`, nodes, erreur (`oom: true` si mémoire saturée), `queue_ahead` et `vram_free_gb` au départ — durées issues des
horodatages du SERVEUR (`create_time`, `execution_start/success`), aucun écart d'horloge. Branché sur `generate_image|video|music|
minimax`, `image_to_video`, `apply_lipsync`, `generate_transcription`, `image_to_3dscene.py` ; `faceid.sh` (des milliers de jobs de
~0,35 s) enregistre en ligne par jq (`gpu_comfy_record_inline`, sans processus Python par photo). Erreurs des observateurs :
`~/.zen/log/comfy_watch.log`. Un job qui n'apparaît jamais est enregistré comme ÉCHEC. La carte affiche jobs, échecs, durée et
attente en file ; `ollama_stats.py` détaille par étiquette. Un job soumis HORS de ces scripts n'est pas compté. Tests : `IA/tests/test_ollama_metrics.py`,
`tests/smoke_status_gpu.py` (Playwright, sans GPU). Les tests unitaires posent `OLLAMA_METRICS_OFF=1` : ils n'écrivent
JAMAIS dans le vrai journal. Premier relevé réel
(nœud nexus) : démarrage à froid de `bge-m3` ≈ 2,0 s et de `gemma3:12b` ≈ 4,0 s (modèle déchargé après 5 min d'inactivité),
contre 20 ms et 0,25 s à chaud. Tests : `IA/tests/test_ollama_metrics.py`.

**Contexte et cache KV** : `ensure(modèle, ctx=…)` compte aussi le cache KV du contexte demandé (2 × couches × têtes KV ×
dimension × 2 octets × jetons, lu dans `/api/show` ; qwen2.5-coder:14b ≈ 192 Ko/jeton → 32 768 jetons ≈ +6 Go sur 9 Go de poids) ;
un modèle déjà chargé avec un contexte plus petit que celui demandé est RECHARGÉ par Ollama (donc contrôlé, pas la voie
rapide). `question.py` transmet son `num_ctx`. **`commit.sh`** : appelle `question.py` (donc le garde-fou) avec qwen2.5-coder:14b
et `AI_CTX=32768` ; un pré-vol unique et visible (`gpu_headroom.py check --ctx`) réduit le contexte à 16 384 puis 8 192 si la
carte partagée est chargée, ou renonce à l'IA pour l'exécution (message jaune) — sans lui, le refus serait muet (`timeout`
25-35 s, `2>/dev/null`).

**Même GPU ou non** : le contrôle croisé n'a de sens que si Ollama et ComfyUI sont servis par la MÊME machine. `same_gpu()`
identifie la machine derrière chaque URL (pair `ipfs p2p` du tunnel via l'API IPFS, sinon cible ssh, sinon « local », sinon
l'hôte de l'URL) ; machines différentes (stations distinctes de l'essaim) → `ensure`, `make_room_for_comfy` et `wait_idle`
s'abstiennent. Identité non déterminable → supposé partagé (`GPU_ASSUME_SHARED=0` pour l'inverse) ; déclaration explicite :
`GPU_SAME_HOST=1|0`, `GPU_OLLAMA_HOST`, `GPU_COMFYUI_HOST`. **Tests et mesures sur GPU partagé** : appels au LLM opt-in
(`--llm`), un à la fois, espacés (`--pace`, 3 s), seulement si ComfyUI est au repos (`gpu_headroom.paced` / `wait_idle`) ; jamais
de requêtes parallèles ni de boucles ; les tests unitaires simulent la carte (aucun appel GPU).
Journal permanent : `~/.zen/log/gpu_headroom_AAAAMMJJ.log`. `gpu_headroom.py status` = VRAM, ComfyUI, modèles chargés.
Tests : `IA/tests/test_gpu_headroom.py` (cartes simulées).

**Chronométrage** : `IA/bench_memory.py [-n N] [--llm] [--json]` mesure (médiane et p95, en ms) l'écran mémoire, un message
à BRO, `#rec`, l'apprentissage, le refresh géo et la partie CPU des contacts, en sous-processus (comme UPassport) ET en
processus ; chaque passage s'ajoute à `~/.zen/log/bench_memory.jsonl` (rotation : 500 lignes, par `20h12.process.sh`)
pour comparer avant/après. Journaux PERMANENTS : `~/.zen/log/` (jamais `~/.zen/tmp/`, purgé chaque nuit) ; le
refresh géo écrit `geo_memory_AAAAMMJJ.log` (gzip > 2 j, purge > 30 j).

**Mémoire géolocalisée** (`IA/geo_memory.py`, collection `uplanet_geo`) : simple INDEX reconstruit depuis NOSTR à chaque
refresh de 20h12 (lancé détaché par `20h12.process.sh`). Publications géolocalisées (kinds 1/1222/1244, tags
latitude/longitude ou `g`) selon leurs likes distincts hors auteur : ≥1 UMAP, ≥3 SECTOR, ≥12 REGION ; chiffrées, sans
texte ou contenant un secret = exclues. Aucun fichier local (`short_memory.py` supprimé) ; la collection `knowledge`
(formation/WoTx²) est retirée en attendant une spécification UX (récupérable via l'historique git).
`#rec`/`#mem`/`#reset` passent par `memory_manager.py` (upsert-memory / list-memories / delete-all).

Pièges : un import de `bro.*` ou `arbor_chat` relance le process dans le venv (`execv`) — un script lu sur stdin perd
son entrée, les effets de bord de sa première moitié sont rejoués ; `~/.astro` embarque un vieux `argparse.py` qui masque
la stdlib (importer `argparse` AVANT `memory_manager`/`question`). Tests : `IA/tests/test_memory_v2.py`,
`test_embed_config.py`, `test_arbor_memory.py`, `test_geo_memory.py` (`python3 -m unittest tests.<nom>` depuis `IA/`).

### Briefing quotidien du Capitaine (`tools/captain_digest.py`, 2026-10-20)

Le mail 20H12 n'est plus le journal brut (800 lignes) : `20h12.process.sh::_send_captain_digest` envoie un **briefing**
— verdict 🟢/🟠/🔴 dans le sujet, liste PRIORISÉE de ce qui demande une action (avec la commande ou l'écran pour la
traiter), puis chiffres courts : Station (services, disque, charge, mémoire, durée 20h12), IA/GPU (`ollama_stats.py` :
appels, p50/p95, démarrages à froid, qui consomme), BRO (échecs récurrents par outil et par compte, démon DM),
ARBOR (runs en échec sur 7 jours, branches `arbor/*` à relire, éligibilité au bâton), Membres (nouveaux, invitations
FaceCloud, K viral). Le journal complet est JOINT (gz), avec le rapport de consommation. Règles : erreurs regroupées
et comptées (compteur « 938x » du journal respecté), nouvelles tentatives et « 0 failed » ignorées, `[WARN] ❌` reste un
avertissement, comptes de test (`@example.*`, `.invalid`) exclus du BRO, seuils de récurrence (≥ 10 échecs ET ≥ 30 %
BRO / 50 % NODE) — un échec isolé n'est pas une alerte. Un collecteur qui plante apparaît dans le message ; si tout le
briefing plante, le journal brut part quand même (repli visible dans le sujet). `python3 tools/captain_digest.py --log
~/.zen/log/20h12_AAAAMMJJ.log[.gz] --html out.html [--subject|--json]` pour rejouer sur un ancien journal. Tests :
`python3 -m unittest tests.test_captain_digest`. Les alertes ponctuelles (`bro_alert_captain` 1/24 h, `UPlanet_IA_Responder`,
ARBOR, PAYforSURE…) restent des événements distincts.

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
| 54321 | UPassport FastAPI (billets Ğ1 : `/qr/billet`) | `u.DOMAIN` |
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

Gestion : `admin/docker.sh [status|pull|update|restart|logs|clean|doctor|watchtower]` (via `tools/astro_compose.sh`).
- Les secrets IA vivent dans `~/.zen/ai-company/.env` ; `astro_compose` les recopie dans `docker/.env` (sans eux, compose retombe sur `changeme-…` et un `up` recréerait Qdrant avec une autre clé).
- Dify = pile indépendante, projet compose **`dify`** (`-p dify`, jamais le nom de dossier `docker`) ; migration d'une station existante : `install/migrate-dify-project.sh --yes`.
- Qdrant n'a qu'une définition : le compose (`astroport-qdrant`, volume `docker_qdrant_storage`). Jamais de `--remove-orphans`, `volume prune` ni `network prune` : voir `admin/docker.sh doctor`.

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

## Clés d'un compte : crédentiel isolé par UPlanet (NORME, 2026-10-20)

**Toute clé du MULTIPASS dérivée avec `keygen` d'un (SALT, PEPPER) l'est avec (SALT, PEPPER_<sel UPlanet>)**, sel =
`sha256(UPLANETNAME)[:16]` : NOSTR, Ğ1, IPNS, Bitcoin, Monero — sinon la même paire donnerait la même clé dans deux
UPlanets. Un seul endroit décide : `tools/my.sh`.
- **Création** (`make_NOSTRCARD.sh`) : un seul crédentiel pour toutes les clés (`uplanet_cred_file`), `.keyformula`
  écrit (`nostr=isolated g1=isolated ipns=isolated`), `pepper_g1` ET `pepper_nostr` dans `.multipass.json`.
- **Compte existant** : ne jamais écrire `keygen … "${salt}" "${pepper}"`. `account_cred_file <email> nostr|g1|ipns`
  donne le crédentiel de CE compte ; `account_key_formula` lit `.keyformula` ou RETROUVE la formule par la référence
  publique (HEX / G1PUBNOSTR / NOSTRNS) puis la met en cache ; sans correspondance : `ERROR:KEYS_MISMATCH`, jamais une
  clé « proche ». `resolve_key_formula`, `derive_account_keys` (roaming `check_ssss.sh`), `new_account_nostr_formula`.
- **Formule « legacy »** (pepper brut) : comptes antérieurs (leur clé NOSTR l'est encore : `fred@qwantic.com`,
  `dev@g1sms.fr`). Jamais CHOISIE pour un nouveau compte ; seulement retrouvée, ou imposée à la restauration d'un compte
  historique (`MULTIPASS_NOSTR_FORMULA=legacy`, lu dans le `.keyformula` de l'archive par `nostr_RESTORE_TW.sh`).
- `keygen -t ipfs` affiche un PeerID (12D3…) ; le nom IPNS (k51…) = `tools/peerid2ipns.py`.
- **Exceptions voulues, marquées dans le code** : `# ZENCARD` — la clé de la ẐEN Card (SALT/PEPPER de `secret.june`) reste
  BRUTE : elle compte les parts de CAPEX et doit être la même sur toutes les UPlanets ; `# COOP` — clés coopératives dont la
  graine contient déjà `UPLANETNAME` (UMAP, SECTOR, REGION, `UPLANETNAME.G1`…).
- **Garde** : `tests/test_key_formulas.sh` échoue sur toute dérivation `(salt, pepper)` brute non marquée dans
  `Astroport.ONE` et `UPassport`. UPassport : `identity.py` détecte les comptes par les DEUX npub possibles
  (`_derive_npubs_from_credentials`) ; `tests/test_identity_keys.py`.
- **Décisions de périmètre (Fred, 2026-10-20)** : les pages de démo crypto (`login-to-nsec.html`, `keygen.html`,
  `g1v1_to_nsec.html`) ne sont PAS concernées. TrocZen garde la formule BRUTE (billets électroniques à traçabilité
  partielle). La clé **LOVE** est la même partout (jamais isolée par UPlanet). **Norme côté client** : login
  « email + PASS » → le serveur renvoie tout ce qu'il faut pour s'auto-configurer (`nsec`, `pepper_g1`, `pepper_nostr`…) ;
  le client ne connaît jamais `UPLANETNAME` ni ne devine une formule. Le scan du QR + PASS (roaming, `check_ssss.sh`) sert
  aussi à **déménager** (chemin « même clé », cf. `UPassport/services/migration.py`).

## Configuration coopérative (cooperative_config.sh)

`tools/cooperative_config.sh` stocke la configuration coopérative dans un événement NOSTR Kind 30800 (DID), chiffré avec `$UPLANETNAME`. Il est propagé automatiquement à tous les relays constellation via `backfill_constellation.sh`.

Le tag `a4l_proof` (Kind 30078 `d=atom4love`, cf. `NIP-101/filter/30078.sh`) n'est plus vérifié contre une liste blanche d'apps : le relay exige seulement qu'il soit présent et non vide (aucune config à maintenir côté station).

## Development Notes

- Scripts are written in **bash** and must work on Debian/Ubuntu/Mint Linux
- Blockchain interaction uses **gcli** (Duniter v2s CLI) for payments and **GraphQL squid** for queries (balance, history, primal). Legacy tools silkaj/jaklis are deprecated
- The project depends on IPFS (Kubo), TiddlyWiki, gcli, Python 3 (with venv at `~/.astro/`), and numerous system packages
- MULTIPASS key generation (NOSTR/G1) is **random** (SALT + PEPPER secret, not derived from geolocation). Only the ATOM4LOVE "love key" (phi2x resonance) is deterministic, seeded by birth date + birth place
- The economic system uses two tiers: UPlanet ORIGIN (1 Zen = 0.1 G1) and UPlanet Zen (1 Zen = 1 EUR)
- Geographic coordinates drive data organization via UMAP (0.01 deg), SECTOR (0.1 deg), REGION (1 deg) grid cells
- Most documentation is bilingual French/English, with French being primary
