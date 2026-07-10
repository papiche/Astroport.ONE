# BRO — Agent Autonome UPlanet

> Canal NIP-44 chiffré · clés privées jamais exposées · gouvernance humaine

BRO est l'agent autonome de chaque station Astroport.ONE. Il écoute un flux de DMs chiffrés NOSTR (NIP-44), les déchiffre **localement** avec les clés de la station, et exécute des actions au nom des utilisateurs — questions IA, paiements G1, synchronisation IPFS, génération de médias — sans jamais transmettre de clé privée sur le réseau.

Quatre rôles structurent l'écosystème : le canal **SELF DM** pour les commandes du propriétaire, le **NODE** pour la continuité en roaming, le **CAPTAIN** pour la gouvernance humaine, et **ARBOR** pour l'auto-amélioration encadrée.

---

## Les quatre rôles

### SELF DM — Canal privé de commande

DM NIP-44 envoyé **à sa propre clef publique** (author == #p == MULTIPASS pubkey). Canal chiffré entre le propriétaire et son instance BRO, non déchiffrable par le NODE (qui ne possède pas la clé privée du joueur).

- kind 4 · author == #p == MULTIPASS pubkey
- Déchiffrable uniquement par la home station du propriétaire
- Si l'utilisateur est en roaming → relayé via NODE vers sa home station
- Lecture de commandes en langage naturel ou par hashtag (`#watch`, `#rec`, `#arbor`…)

### NODE — Relais et continuité réseau

Station Astroport autonome avec identité NOSTR + G1 + IPFS propres. Assure la continuité lors du roaming et dialogue avec le CAPTAIN de ce qu'ARBOR analyse.

- Identité : `NSEC` + `NPUB` + `HEX` propres au NODE (≠ clés utilisateurs)
- Relaie les SELF DMs vers la home station quand l'utilisateur est en roaming
- Authentification inter-NODE par présence du HEX dans le swarm local
- Publie `12345.json` (état station, players, services) sur IPNS + relay constellation

### CAPTAIN — Gouvernance humaine

Administrateur humain de la station, identifié par `$CAPTAINEMAIL`. Seul décideur sur les changements proposés par ARBOR.

- Niveau d'accès 5 (full BRO)
- Reçoit les alertes Mailjet en cas de panne (max 1 alerte/24h, rate-limitée)
- Déclenche ARBOR via `#arbor` en SELF DM
- Relit le diff git proposé par ARBOR et décide du merge — jamais automatique

### ARBOR — Auto-amélioration encadrée

Boucle d'amélioration du prompt d'interprétation de commandes BRO, inspirée du projet Arbor (RUC-NLPIR). Ne touche jamais au code principal sans validation humaine.

**Trois volets, même discipline de gouvernance (jamais de merge automatique) :**

1. **Prompt/modèle d'interprétation** — amélioration exclusive de `_build_interpretation_prompt()` / `COMMAND_INTERPRETATION_MODEL` (`bro/_shared.py`), validée par éval dev + held-out avant proposition.
2. **Mining des besoins non satisfaits** — analyse `~/.zen/flashmem/bro_tool_requests.jsonl` pour détecter des demandes récurrentes → notifie CAPTAIN (jamais de génération de code automatique).
3. **Observation du canal LOVE** *(depuis 2026-07-10)* — `arbor_self_improve.py --observe-love-channel` surveille en continu la santé du code (`shellcheck`/`py_compile` sur `love_handler.sh`, `phi2x.py`, `atom4love_dream_publish.py`, `atom4love_follow.py`) et l'usage réel (profils LOVE actifs, dream_vector publiés, exécutions de `LOVE MATCH`) pour **piloter de futures décisions d'évolution et d'optimisation** du code du canal LOVE. Observation et rapport uniquement en Stage Alpha — une boucle d'optimisation par éval dev/held-out sur les poids de `LOVE MATCH` n'a de sens qu'une fois un volume d'usage réel suffisant accumulé (fabriquer une vérité de terrain arbitraire serait prématuré et contraire à la discipline anti-surapprentissage d'ARBOR). Toute anomalie détectée (avertissement shellcheck nouveau, échec py_compile) est publiée en **issue Git** via `POST /api/feedback` (UPassport) — pas de secret Git connu d'ARBOR : l'endpoint résout `GIT_HOST`/`GIT_TOKEN`/`GIT_OWNER` depuis le DID coopératif (Kind 30800, `cooperative_config.sh`), avec repli email puis stockage local si Git est indisponible. Une seule issue par changement d'état (empreinte shellcheck/py_compile), jamais une par exécution de cron.

**Workflow (volet 1 — prompt/modèle) :**
1. CAPTAIN tape `#arbor` en SELF DM
2. `arbor_self_improve.py --apply --notify-captain` s'exécute en arrière-plan
3. Teste des candidats (modèles ou correctifs) sur le jeu eval dev
4. Valide le gagnant sur le jeu held-out (détection surapprentissage)
5. Crée une branch `arbor/bro-cmd-interp/*` dans un worktree git isolé
6. Notifie le CAPTAIN : diff proposé → validation manuelle avant merge

**Workflow (volet 3 — observation LOVE) :**
1. `arbor_self_improve.py --observe-love-channel --notify-captain` (cron ou déclenchement manuel)
2. Rapport shellcheck/py_compile + statistiques d'usage agrégées (aucune donnée personnelle)
3. Si l'empreinte de santé du code a changé ET révèle une anomalie → issue Git ouverte (`POST /api/feedback`, repo `{GIT_OWNER}/Astroport.ONE`)
4. DM NODE au CAPTAIN : lien vers l'issue si ouverte, sinon rapport complet — aucune modification de code à ce stade
5. Une fois l'usage suffisant : décision humaine d'ouvrir une boucle d'évolution dédiée (même infra worktree/branche que le volet 1, réutilisable via `LOVE_CHANNEL_FILES`)

---

## Flux principal — question IA

Trajet d'un DM `channel="plain"` depuis un utilisateur local ou en roaming.

```
[ Utilisateur ]  DM NIP-44  channel="plain"  "Ma question ?"
    │  signé avec clé MULTIPASS propre
    ▼
[ HOME STATION ]
  ├─ Local   : déchiffré par NODE_NSEC
  └─ Roaming : reçu via bro_send_intercom canal "bro_ia"
               (NODE visiteur → NODE home, auth par swarm HEX)
    │
    ▼
  bro_user_level HEX RELAY  →  { "level": 0-5, "email": "…" }
    │
    ├── level 0  →  ignoré silencieusement
    └── level ≥1  →  _handle_bro()
          │
          ├─ Slots mémoire  →  short_memory.py  (contexte #0…#12)
          ├─ RAG Qdrant     →  nextcloud_bro_sync.sh --query "…"
          └─ Ollama local   →  gemma3 / qwen3 (réponse)
                │
                ▼
[ Envoi DM réponse ]  printf NSEC | nostr_send_secure_dm.py
    → tous les relays connus du joueur
```

## Flux — commande SELF DM

Le propriétaire pilote BRO via son canal privé NIP-44 (envoyé à sa propre clef).

```
[ Propriétaire ]  DM self  "#watch mastodon.social notifications keywords blockchain"
    author == #p == PUBKEY_PROPRE   // NIP-44, non déchiffrable par NODE
    │
    ▼
[ HOME STATION ]  bro_watch_core.py check-commands
  Déclenché en temps réel (filter/4.sh dépose l'event self-DM dans
  ~/.zen/tmp/bro_self_dm_queue/, bro_dm_daemon.sh le détecte via inotify)
  et une fois par jour dans le cycle des scrapers cookie.
  _fetch_self_dms_since(EMAIL)
    ├─ Async websockets → relays du propriétaire
    ├─ Déchiffrement avec NSEC propre du joueur
    └─ Filtre anti-boucle : ignore réponses BRO (📋 ✅ 🤔)
    │
    ▼
  _interpret_natural_command(EMAIL, text)
    ├─ Prompt contextuel (sources surveillées actives)
    ├─ Ollama qwen2.5-coder:14b → JSON action
    └─ sanity_check : cohérence mots-clés ↔ action détectée
    │
    ▼
  _execute_interpreted_action(EMAIL, action)
    ├─ Mise à jour .cookie_manifest.json
    ├─ Républication Kind 31903 (Cookie Vault NIP-101)
    └─ DM confirmation à soi-même  "✅ Mots-clés mis à jour"
    │
[ ARBOR ]  si #arbor en SELF DM
    └─ arbor_self_improve.py --apply --notify-captain
       ├─ Évalue candidats sur jeu dev
       ├─ Valide sur held-out (anti-surapprentissage)
       └─ Crée branch git arbor/bro-cmd-interp/*
          → CAPTAIN relit le diff et décide
```

## Flux — roaming (relay inter-NODE)

```
[ Utilisateur ROAMING sur station B ]
    │  publie kind 1 : "#BRO #youtube https://…"
    │  sur relay constellation, signé MULTIPASS
    ▼
[ STATION B ]  UPlanet_IA_Responder.sh
    ├─ Détecte #BRO #youtube dans kind 1
    ├─ Cherche home station dans swarm/*.json
    └─ Introuvable localement → bro_relay_bro_ia_to_home
    │
    ▼
[ STATION A — HOME ]  via bro_send_intercom canal "bro_ia"
    └─ _handle_bro_ia() [bro_dm_daemon.sh]
        ├─ Reconstruction paramètres depuis payload intercom
        ├─ Appel UPlanet_IA_Responder.sh avec EMAIL/PUBKEY/MESSAGE
        └─ Exécution commande BRO avec identité locale
```

---

## Modèle de clés

Trois couches d'identité, toutes stockées localement (mode `0600`), jamais transmises sur le réseau.

| Couche | Fichier | Usage | Règle |
|--------|---------|-------|-------|
| NOSTR utilisateur | `~/.zen/game/nostr/EMAIL/.secret.nostr` | DMs, signature kind | Jamais exposé réseau |
| G1 / Duniter | `~/.zen/game/nostr/EMAIL/.secret.dunikey` | Paiements G1 via `gcli` | Passé via stdin uniquement |
| NODE (station) | `~/.zen/game/secret.nostr` | DMs inter-NODE | Ne signe jamais au nom d'un user |

Le NODE utilise **sa propre clé NSEC** pour les DMs inter-NODE (canaux techniques). Il ne peut pas déchiffrer les SELF DMs des utilisateurs — c'est le principe de séparation des identités.

---

## Niveaux d'accès BRO

Déterminé par `bro_user_level.py` — lecture `contractStatus` (DID cache) + vérification `atom4love` kind 30078 (cache 1h).

| Niveau | Profil | Accès |
|--------|--------|-------|
| **0** | Anonyme | Ignoré silencieusement (aucun MULTIPASS local) |
| **1** | Locataire | `active_rental` — accès de base |
| **2** | Atome | Locataire + kind 30078 atom4love — accès `#craft` |
| **3** | Satellite | Sociétaire sans IA — slots mémoire privés |
| **4** | Constellation | Sociétaire avec IA — RAG Qdrant + Ollama |
| **5** | Capitaine | Accès total — gouvernance ARBOR, alertes critiques |

---

## Canaux DM — kind 4 NIP-44

| `channel` | Émetteur | Action déclenchée |
|-----------|----------|-------------------|
| `plain` | Utilisateur | Question IA — RAG Qdrant + Ollama |
| `self_command_relay` | NODE visiteur | Relay SELF DM roaming → home station |
| `bro_ia` | NODE visiteur | Relay kind 1 #BRO #tag depuis roaming |
| `udrive` | Utilisateur | Sync fichier IPFS → `APP/uDRIVE` |
| `vocals` / `webcam` | Utilisateur | Publication kind 1222 / 1244 (audio / vidéo) |
| `zen_like` | Station roaming | Paiement G1 coopératif (ZEN → G1) |
| `comfyui_job` | NODE light | Génération vidéo (t2v / i2v) — verrou GPU exclusif |
| `comfyui_result` | NODE brain | Résultat vidéo → `uDRIVE/Videos` + notif DM |
| `nostr_delete` | NODE swarm | Suppression strfry authentifiée par HEX swarm |
| `love` | Utilisateur | Fonctionnalités sociales (profil, matching, kin) — `love_handler.sh`, code observé (pas modifié) par ARBOR volet 3 |

---

## Fichiers principaux

| Fichier | Lignes | Rôle |
|---------|--------|------|
| `IA/bro/bro_dm_daemon.sh` | 1 556 | Daemon principal — inotifywait, route, déchiffre, répond |
| `IA/bro/bro_common_lib.sh` | 606 | Bibliothèque partagée — `send_dm`, `bro_resolve_email`, `bro_user_level`… |
| `IA/bro_watch_core.py` | 1 187 | Surveillance Web2 multi-tenant + SELF DM + ARBOR (mining, trigger) |
| `IA/arbor_self_improve.py` | — | Auto-amélioration prompt/modèle + mining + observation canal LOVE (3 volets, discipline Arbor, gouvernance humaine) |
| `IA/bro/love_handler.sh` | — | Fonctionnalités sociales (profil, matching, kin) — observé (pas modifié) par ARBOR volet 3, cf. `LOVE_CHANNEL_FILES` |
| `tools/nostr_node_intercom.py` | — | Transport DM NIP-44 inter-NODE (encrypt / decrypt) |
| `IA/short_memory.py` | — | Slots mémoire personnelle (0-12) — `~/.zen/flashmem/EMAIL/` |
| `IA/question.py` | — | Interface Ollama + Qdrant pour questions RAG |

`bro_user_level` est une fonction bash définie dans `bro_common_lib.sh` (pas un fichier séparé).

---

## Démarrage du daemon

Le daemon BRO est lancé et surveillé par `_12345.sh` (watchdog à chaque boucle) :

```bash
# _12345.sh — extrait réel
_DM_PID_FILE="${HOME}/.zen/tmp/bro_dm_daemon.pid"
_dm_is_alive() {
    [[ -f "$_DM_PID_FILE" ]] || return 1
    local _p; _p=$(cat "$_DM_PID_FILE" 2>/dev/null)
    [[ -z "$_p" ]] && return 1
    kill -0 "$_p" 2>/dev/null && return 0
    pgrep -f "bro_dm_daemon.sh" > /dev/null 2>&1
}
if [[ -s ~/.zen/game/secret.nostr ]] && ! _dm_is_alive; then
    bash "${HOME}/.zen/Astroport.ONE/IA/bro/bro_dm_daemon.sh" >> "${HOME}/.zen/tmp/bro_dm_daemon.log" 2>&1 &
fi
```

Le daemon gère un arrêt propre sur `SIGTERM`/`SIGINT` : il attend toutes les sous-shells, tue les processus sweep et constellation subscriber, puis supprime le fichier PID.

---

## Principe cardinal de sécurité

- Les clés privées ne quittent **jamais** la station (ni en clair, ni chiffrées)
- Passées aux scripts via `stdin` uniquement (invisibles dans `ps aux`)
- Stockées en `0600` (lecture propriétaire uniquement)
- Le NODE signe avec **sa propre clé** pour les DMs inter-NODE — jamais avec celle d'un utilisateur
- Authentification inter-NODE : présence du HEX sender dans `~/.zen/tmp/swarm/` (source de vérité locale, pas le relay public)
- Alertes CAPTAIN rate-limitées (1/24h) pour éviter le spam en cas de boucle d'erreur
