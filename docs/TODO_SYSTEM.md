# Système TODO — Documentation complète

**Scripts** : `todo.sh` · `IA/generate_article.sh`  
**Protocole** : N² Constellation (Conway's Angel Game — force 2)  
**Principe** : _"L'IA propose, l'Humain dispose"_

---

## Table des matières

1. [Vue d'ensemble](#1-vue-densemble)
2. [Architecture](#2-architecture)
3. [todo.sh — Référence complète](#3-todosh--référence-complète)
   - [Périodes d'analyse](#31-périodes-danalyse)
   - [Commandes mémoire N²](#32-commandes-mémoire-n)
   - [Publication](#33-publication)
   - [Options avancées](#34-options-avancées)
4. [Flux d'exécution détaillé](#4-flux-dexécution-détaillé)
5. [Système de mémoire N²](#5-système-de-mémoire-n)
6. [Système de publication](#6-système-de-publication)
   - [NOSTR kind 30023](#61-nostr-kind-30023)
   - [Open Collective](#62-open-collective)
   - [N² Memory (kind 31910)](#63-n-memory-kind-31910)
   - [Global Commons (UMAP 0.00, 0.00)](#64-global-commons-umap-000-000)
7. [generate_article.sh — Référence complète](#7-generate_articlesh--référence-complète)
8. [Intégration todo.sh ↔ generate_article.sh](#8-intégration-todosh--generate_articlesh)
9. [Configuration requise](#9-configuration-requise)
10. [Exemples d'utilisation](#10-exemples-dutilisation)
11. [Dépannage](#11-dépannage)

---

## 1. Vue d'ensemble

`todo.sh` est un **assistant de développement automatisé** qui :

1. **Analyse** les modifications Git sur une période donnée (depuis la dernière exécution, 24h, 7 jours ou 30 jours)
2. **Génère** un rapport structuré grâce à l'IA (Ollama via `question.py`)
3. **Propose** des recommandations stratégiques alignées avec l'architecture N²
4. **Apprend** des décisions passées (mémoire NOSTR partagée à toute la constellation)
5. **Publie** les rapports sur NOSTR, Open Collective et/ou le Global Commons

`generate_article.sh` est un script complémentaire qui transforme n'importe quel texte en article complet (résumé narratif + tags intelligents + illustration IA), réutilisant le pipeline `#search` de `UPlanet_IA_Responder.sh`.

---

## 2. Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                          todo.sh                                      │
│                   (Orchestrateur principal)                           │
├──────────────────┬────────────────────────┬──────────────────────────┤
│   ANALYSE GIT    │    IA LOCALE (Ollama)   │   MÉMOIRE N² (NOSTR)    │
│                  │                         │                          │
│ git log          │ question.py             │ kind 31910               │
│ git diff         │  → résumé technique     │  uplanet.G1.nostr key   │
│ git diff --stat  │  → recommandations N²   │  wss://relay.*          │
│                  │  → apprentissage passé  │                          │
├──────────────────┴────────────────────────┴──────────────────────────┤
│                    PIPELINE ARTICLE (nouveau)                         │
│                  IA/generate_article.sh                               │
│   texte source → résumé narratif → tags intelligents → image IA      │
├─────────────────────┬─────────────────────┬────────────────────────  │
│  NOSTR kind 30023   │  Open Collective     │  Global Commons          │
│  (blog technique)   │  GraphQL API         │  UMAP 0.00, 0.00        │
│  nostr_send_note.py │  https://oc.com      │  kind 30023 + vote      │
└─────────────────────┴─────────────────────┴────────────────────────  ┘
```

### Composants requis

| Composant | Rôle | Fichier |
|---|---|---|
| `question.py` | LLM local (Ollama) | `IA/question.py` |
| `generate_article.sh` | Pipeline article (résumé+tags+image) | `IA/generate_article.sh` |
| `nostr_send_note.py` | Envoi événements NOSTR | `tools/nostr_send_note.py` |
| `nostr_get_events.sh` | Lecture mémoire NOSTR | `tools/nostr_get_events.sh` |
| `my.sh` | Variables d'environnement UPlanet | `tools/my.sh` |
| `cooperative_config.sh` | Config DID chiffrée | `tools/cooperative_config.sh` |
| Ollama | LLM local | Service système |
| `uplanet.G1.nostr` | Clé mémoire N² | `~/.zen/game/uplanet.G1.nostr` |

---

## 3. `todo.sh` — Référence complète

### 3.1 Périodes d'analyse

| Option | Alias | Période | Fichier généré | Expiration NOSTR |
|---|---|---|---|---|
| `--last` | `-l` | Depuis dernière exécution (**défaut**) | `TODO.last.md` | 5 jours |
| `--day` | `-d` | Dernières 24 heures | `TODO.today.md` | 5 jours |
| `--week` | `-w` | Derniers 7 jours | `TODO.week.md` | 14 jours |
| `--month` | `-m` | Derniers 30 jours | `TODO.month.md` | 28 jours |

**Mode `--last` (défaut)** : utilise un fichier marqueur (`~/.zen/game/todo_last_run.marker`) pour retrouver le commit de la dernière exécution, permettant une analyse précise sans doublons. Lors de la première exécution, bascule sur 24h.

### 3.2 Commandes mémoire N²

Ces commandes agissent directement sur la mémoire NOSTR (kind 31910) sans générer de rapport :

```bash
# Lister les recommandations en attente (proposed + accepted)
./todo.sh --list

# Ajouter manuellement une idée (captain_todo)
./todo.sh --add "Décrire l'idée ici"

# Marquer une recommandation comme acceptée
./todo.sh --accept <ID>

# Marquer une recommandation comme rejetée
./todo.sh --reject <ID>

# Marquer une recommandation comme implémentée
./todo.sh --done <ID>

# Voter pour une recommandation (+1 priorité)
./todo.sh --vote <ID>

# Afficher les 20 dernières entrées mémoire
./todo.sh --memory
```

### 3.3 Publication

```bash
# Mode interactif (défaut) : 3 étapes guidées
./todo.sh

# Mode rapide : génère + publie sur NOSTR sans prompt
./todo.sh --quick

# Publication directe sur une cible spécifique
./todo.sh --publish nostr    # NOSTR kind 30023 (blog)
./todo.sh --publish n2       # N² Memory (kind 31910)
./todo.sh --publish global   # Global Commons (UMAP 0.00, 0.00)
./todo.sh --publish all      # Toutes les destinations

# Proposer le dernier rapport au Global Commons
./todo.sh --propose-global

# Lister les propositions Global Commons en attente
./todo.sh --commons
```

### 3.4 Options avancées

```bash
# Désactiver le mode interactif (batch, cron)
./todo.sh --no-interactive

# Exporter l'article dans un fichier (format déduit de l'extension)
./todo.sh --week --export /chemin/bilan.md    # Markdown
./todo.sh --week --export /chemin/bilan.json  # JSON
./todo.sh --week --export /chemin/bilan.html  # HTML
```

L'option `--export` appelle [`generate_article.sh`](../IA/generate_article.sh) après génération du rapport pour produire une version éditorialisée dans le format désiré.

---

## 4. Flux d'exécution détaillé

### Étape 1 — Initialisation et période

```
parse_args() → init_last_run_period()
     │
     ├── Mode --last : lit ~/.zen/game/todo_last_run.marker
     │      → commit hash + timestamp de la dernière exécution
     │      → Première fois : fallback 24h
     │
     └── Modes --day/--week/--month : période fixe (date git --since)
```

### Étape 2 — Collecte des données Git

```
get_git_changes()
     │
     ├── Commit hash connu → git log <hash>..HEAD (précision maximale)
     │
     └── Date → git log --since="<date>"
           ↓
     Génère .git_changes.txt (commits + fichiers modifiés)
```

### Étape 3 — Analyse par système

```
analyze_changes_by_system()
     │
     ├── 18 systèmes prédéfinis : UPassport, UPlanet, RUNTIME, IA, Tools,
     │   Nostr, Economy, DID, ORE, Oracle, PlantNet, Cookie, CoinFlip,
     │   uMARKET, NostrTube, N8N, Docs, Config
     │
     ├── Pour chaque système : fichiers touchés + stats +/- lignes
     │
     └── Catégorie "Autres" pour les fichiers non classés
```

### Étape 4 — Génération IA

```
generate_ai_prompt() → question.py (gemma3:latest)
     │
     ├── Contexte injecté :
     │   ├── N2_CONTEXT (architecture N², patterns, anti-patterns)
     │   ├── TODO.md principal (200 premières lignes)
     │   ├── Mémoire N² (15 dernières décisions constellation)
     │   ├── .git_changes.txt (commits)
     │   └── Analyse par système
     │
     └── Prompt structuré en 2 parties :
         ├── PARTIE 1 (50%) : Bilan
         │   → résumé exécutif, modifications par système, cohérence N²
         └── PARTIE 2 (50%) : Recommandations stratégiques
             → tableau priorité 🔴🟡🟢 avec justification N²
```

### Étape 5 — Génération du rapport

```
main() → TODO.{period}.md
     │
     ├── En-tête : titre, date, période analysée
     ├── Résumé IA (PARTIE 1 + PARTIE 2)
     └── Modifications détectées (analyze_changes_by_system)
```

### Étape 6 — Marquage et export

```
save_run_marker()          → ~/.zen/game/todo_last_run.marker
                               (commit HEAD + timestamp)

Export --export FILE       → generate_article.sh --format <ext>
                               (si ARTICLE_SCRIPT disponible)
```

### Étape 7 — UX Capitaine (mode interactif)

```
ÉTAPE 1/3 — Recommandations IA
     interactive_select_recommendations()
     ├── Extrait les lignes 🔴🟡🟢 du rapport
     ├── Stocke chaque recommandation dans NOSTR (kind 31910, status=proposed)
     └── Le Capitaine accepte (a, 1, 2 3...) / rejette (r1) / vote (v2)
           → store_n2_memory(status=accepted|rejected)
           → Les acceptées → TODO.md

ÉTAPE 2/3 — Édition
     captain_edit_report()
     └── o=ouvrir xdg-open / e=éditeur / v=voir / Entrée=passer

ÉTAPE 3/3 — Publication
     captain_publish_menu()
     └── 1=NOSTR / 2=Open Collective / 3=N² Memory / 4=Global Commons / a=tout
```

### Étape 8 — Publication (selon choix)

```
publish_todo_report()           → kind 30023 (NOSTR blog)
prepare_and_publish_opencollective() → Open Collective GraphQL
publish_summary_to_n2_memory()  → kind 31910 (rapport quotidien)
publish_report_to_global_commons()   → kind 30023 (vote constellation)
```

---

## 5. Système de mémoire N²

### Principe

La mémoire N² est un **graphe social distribué d'apprentissage** : chaque recommandation, décision et vote est stocké comme événement NOSTR partagé entre **tous les noeuds de la constellation**. L'IA consulte cette mémoire à chaque génération de rapport pour améliorer ses conseils.

### Structure d'un événement mémoire (kind 31910)

```json
{
  "kind": 31910,
  "content": {
    "type": "n2_todo",
    "version": "2.1",
    "id": "ai_20260320_145230_1_abc123456789",
    "content": "🔴 Ajouter expiration automatique DID",
    "status": "accepted",
    "rec_type": "ai_recommendation",
    "priority": "high",
    "station": "12D3KooWXxxxx",
    "captain": "captain@example.com",
    "votes": 0,
    "created_at": "2026-03-20T14:52:30Z"
  },
  "tags": [
    ["d", "ai_20260320_145230_1_abc123456789"],
    ["t", "n2-todo"],
    ["t", "ai_recommendation"],
    ["status", "accepted"],
    ["priority", "high"],
    ["station", "12D3KooWXxxxx"],
    ["captain", "captain@example.com"],
    ["created", "20260320"]
  ]
}
```

### Types d'événements

| `rec_type` | Description |
|---|---|
| `ai_recommendation` | Recommandation générée par l'IA |
| `captain_todo` | TODO ajouté manuellement par le Capitaine |
| `vote` | Vote pour une recommandation (lié via tag `["e", rec_id]`) |
| `status_update` | Mise à jour de statut (`accepted`, `rejected`, `done`) |
| `daily_report` | Résumé de rapport journalier/hebdomadaire/mensuel |
| `global_commons_proposal` | Proposition Global Commons |

### Clé de signature

La mémoire est signée avec `~/.zen/game/uplanet.G1.nostr` — la clé centrale de la banque G1 UPlanet. Elle est **la même sur tous les nœuds** (dérivée de `${UPLANETNAME}.G1`), permettant une lecture/écriture partagée.

```bash
# Créer la clé (si absente)
$HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}.G1" "${UPLANETNAME}.G1" \
    > ~/.zen/game/uplanet.G1.nostr
```

---

## 6. Système de publication

### 6.1 NOSTR kind 30023

**Audience** : Développeurs, noeuds de la constellation  
**Contenu** : Rapport technique complet  
**Durée de vie** : 5j (quotidien), 14j (hebdomadaire), 28j (mensuel)

Depuis la version intégrée avec `generate_article.sh`, les métadonnées sont enrichies :

```
publish_todo_report()
     │
     ├── generate_article.sh --format json --no-image  (si disponible)
     │        → title narratif (IA)
     │        → summary 2-3 phrases (IA)
     │        → tags intelligents (IA) + tags fixes (todo, rapport, git, UPlanet)
     │        → d_tag unique
     │
     └── nostr_send_note.py --kind 30023
              Tags NOSTR : ["d"], ["title"], ["summary"], ["published_at"],
                           ["expiration"], ["t", ...] × N tags
```

### 6.2 Open Collective

**Audience** : Communauté publique, investisseurs, non-développeurs  
**API** : GraphQL v2 (`https://api.opencollective.com/graphql/v2`)  
**Token** : Configuré via DID coopératif (chiffré NOSTR) ou `.env` (fallback)

```bash
# Configurer le token (recommandé : DID coopératif)
source ~/.zen/Astroport.ONE/tools/cooperative_config.sh
coop_config_set OCAPIKEY "votre_token_ici"
coop_config_set OPENCOLLECTIVE_SLUG "monnaie-libre"

# Obtenir un token : https://opencollective.com/dashboard/<slug>/admin/for-developers
```

Le workflow Open Collective propose au Capitaine d'éditer un **brouillon pré-rempli** avant publication :
- Template simplifié (pas de jargon technique)
- Sections : résumé communauté / prochaines étapes / message du Capitaine
- Options d'édition : xdg-open / éditeur terminal / preview HTML / publication directe

⚠️ L'API Open Collective est en test — vérifier la publication après envoi.

### 6.3 N² Memory (kind 31910)

**Audience** : Système interne (apprentissage constellation)  
**Contenu** : Résumé tronqué à 2000 caractères + métadonnées station

```bash
publish_summary_to_n2_memory()
     │
     └── store_n2_memory(type=daily_report, status=published)
             → Stocké sur wss://relay.copylaradio.com
```

### 6.4 Global Commons (UMAP 0.00, 0.00)

**Audience** : Toute la constellation (vote collectif)  
**Quorum** : 1/3 des stations dans `~/.zen/tmp/swarm` (minimum 2)  
**Expiration** : 28 jours  
**Clé** : `~/.zen/game/nostr/UMAP_0.00_0.00/.secret.nostr` (dérivée de `${UPLANETNAME}`)

```
publish_report_to_global_commons()
     │
     ├── Calcule le quorum (get_swarm_station_count / 3)
     ├── Génère la clé UMAP 0.00, 0.00 si absente
     └── Publie kind 30023 avec tags :
             ["d", "n2-report-YYYYMMDD-xxxx"]
             ["t", "collaborative"], ["t", "n2-report"]
             ["g", "0.00,0.00"]
             ["p", "<global_umap_hex>", "", "umap"]
             ["quorum", "N"]
             ["expiration", "timestamp"]

# Voter depuis l'interface web :
collaborative-editor.html?lat=0.00&lon=0.00&umap=<GLOBAL_UMAP_HEX>
```

---

## 7. `generate_article.sh` — Référence complète

### Interface

```bash
./IA/generate_article.sh [OPTIONS] ["texte source"]
./IA/generate_article.sh [OPTIONS] --file SOURCE_FILE
echo "texte" | ./IA/generate_article.sh [OPTIONS]
```

### Options

| Option | Description | Défaut |
|---|---|---|
| `--format json\|md\|html` | Format de sortie | `json` |
| `--lang LANG` | Langue ISO 639-1 (fr, en, es...) | `fr` |
| `--output FILE` | Écrire dans un fichier (défaut: stdout) | stdout |
| `--no-image` | Ne pas générer d'illustration | false |
| `--model MODEL` | Modèle Ollama | `gemma3:latest` |
| `--title TITLE` | Titre imposé (sinon IA génère) | IA |
| `--tags "t1 t2"` | Tags supplémentaires (sans #) | — |
| `--udrive PATH` | Répertoire de sortie pour l'image | temp |
| `--file FILE` / `-f` | Lire le texte source depuis un fichier | — |
| `--help` / `-h` | Affiche l'aide | — |

### Pipeline interne

```
1. SOURCE_TEXT  (fichier --file / argument / stdin)
        ↓
2. question.py  → ARTICLE_TITLE (max 80 chars)   [si --title absent]
        ↓
3. question.py  → SUMMARY (2-3 phrases narratives, public non-technique)
        ↓
4. question.py  → 5-8 tags intelligents (mots simples, lowercase)
     + EXTRA_TAGS (--tags)  →  déduplication, filtre 3-30 chars
        ↓
5. [optionnel] comfyui.me.sh → disponible ?
     question.py → prompt Stable Diffusion (descripteurs visuels anglais)
     generate_image.sh → IPFS URL illustration
        ↓
6. Rendu selon --format :
     json  → { title, summary, tags[], image_url, content, published_at, d_tag }
     md    → Markdown avec titre, résumé, image, contenu, tags
     html  → Page HTML autonome (styles inline, responsive)
        ↓
7. stdout ou --output FILE
```

### Structure JSON de sortie

```json
{
  "title": "Bilan hebdomadaire — Évolutions UPlanet",
  "summary": "L'équipe a renforcé le système de mémoire N² et amélioré la publication des rapports. L'intégration avec Open Collective est désormais opérationnelle. Les prochaines étapes visent la synchronisation backfill constellation.",
  "tags": ["nostr", "development", "uplanet", "todo", "git", "constellation"],
  "image_url": "https://ipfs.copylaradio.com/ipfs/QmHash/illustration.png",
  "content": "# TODO Hebdomadaire - 2026-03-20\n...",
  "published_at": 1774049138,
  "d_tag": "article_20260320_a644e746"
}
```

---

## 8. Intégration `todo.sh` ↔ `generate_article.sh`

### Flux intégré

```
todo.sh --week --export bilan.md
     │
     ├── [1] Analyse Git (7 jours)
     ├── [2] IA génère rapport technique → TODO.week.md
     ├── [3] save_run_marker
     │
     ├── [4] EXPORT (si --export bilan.md)
     │         generate_article.sh --format md --file TODO.week.md
     │              → résumé narratif pour non-développeurs
     │              → tags contextuels
     │              → bilan.md prêt à partager
     │
     └── [5] UX interactif → publication NOSTR (métadonnées enrichies)
                  generate_article.sh --format json --no-image --file TODO.week.md
                       → title, summary, tags pour kind 30023
```

### Variable `ARTICLE_SCRIPT`

```bash
ARTICLE_SCRIPT="$REPO_ROOT/IA/generate_article.sh"
```

Définie à la ligne 38 de `todo.sh`. Toutes les fonctions qui appellent `generate_article.sh` vérifient préalablement son existence avec `[[ -f "$ARTICLE_SCRIPT" ]]` et utilisent des **fallbacks** (extraction manuelle du titre/résumé) si absent.

---

## 9. Configuration requise

### Variables d'environnement (via `tools/my.sh`)

| Variable | Description | Exemple |
|---|---|---|
| `CAPTAINEMAIL` | Email du Capitaine (clé NOSTR) | `captain@example.com` |
| `IPFSNODEID` | ID du nœud IPFS | `12D3KooWXxxxx` |
| `myRELAY` | Relay NOSTR par défaut | `wss://relay.copylaradio.com` |
| `UPLANETNAME` | Nom UPlanet (seed des clés) | `UPlanet` |

### Clés NOSTR requises

```
~/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr   # Publication NOSTR (captain)
~/.zen/game/uplanet.G1.nostr                    # Mémoire N² constellation
~/.zen/game/nostr/UMAP_0.00_0.00/.secret.nostr  # Global Commons (auto-créée)
```

### Configuration Open Collective (optionnel)

```bash
# Via DID coopératif (recommandé — chiffré, partagé entre stations)
source tools/cooperative_config.sh
coop_config_set OCAPIKEY "tok_xxxx"
coop_config_set OPENCOLLECTIVE_SLUG "monnaie-libre"

# Via .env (legacy fallback)
echo 'OCAPIKEY="tok_xxxx"' >> .env
```

### Fichiers d'état

| Fichier | Description |
|---|---|
| `~/.zen/game/todo_last_run.marker` | Commit + timestamp de la dernière exécution |
| `~/.zen/game/opencollective/last_update_<period>.marker` | Dernier commit publié sur OC |
| `~/.zen/game/opencollective/updates.log` | Historique des publications OC |

---

## 10. Exemples d'utilisation

### Usage quotidien simple

```bash
# Rapport depuis la dernière exécution (défaut) + interface interactive
./todo.sh

# Rapport 24h en mode rapide (publie sur NOSTR sans prompt)
./todo.sh --day --quick
```

### Générer et exporter des bilans

```bash
# Bilan hebdomadaire → article Markdown prêt à partager
./todo.sh --week --export ~/Bureau/bilan-semaine.md

# Bilan mensuel → JSON (pour scripts avals)
./todo.sh --month --export /tmp/bilan-mars.json

# Bilan mensuel → page HTML autonome
./todo.sh --month --export ~/bilan-mars.html
```

### Générer un article depuis n'importe quel texte

```bash
# Depuis un fichier existant
./IA/generate_article.sh --file TODO.week.md --format md --output article.md

# Depuis stdin, export HTML
cat rapport-reunion.md | ./IA/generate_article.sh --format html > reunion.html

# Rapport + image générée, sortie JSON
./IA/generate_article.sh \
    --file TODO.last.md \
    --format json \
    --lang fr \
    --tags "uplanet nostr g1" \
    --output article.json

# Même chose en anglais, titre imposé
./IA/generate_article.sh \
    --file TODO.week.md \
    --lang en \
    --title "Weekly Development Report" \
    --format md \
    --output weekly.md
```

### Gestion de la mémoire N²

```bash
# Voir les recommandations en attente
./todo.sh --list

# Ajouter une idée
./todo.sh --add "Intégrer Radicle comme forge P2P décentralisée"

# Accepter la recommandation ID "ai_20260320_..."
./todo.sh --accept ai_20260320_145230_1_abc123456789

# Voir l'historique des décisions
./todo.sh --memory
```

### Publication ciblée

```bash
# Générer + publier uniquement sur NOSTR
./todo.sh --week --publish nostr

# Publier le dernier rapport au Global Commons
./todo.sh --propose-global

# Voir les propositions en attente de vote
./todo.sh --commons

# Tout publier sans interaction (CI/cron)
./todo.sh --no-interactive --publish all
```

---

## 11. Dépannage

### `❌ question.py introuvable`

```bash
ls IA/question.py
# Si absent : vérifier l'installation complète d'Astroport.ONE
```

### `⚠️ Ollama non disponible`

```bash
# Démarrer Ollama manuellement
bash IA/ollama.me.sh

# Ou directement
ollama serve &
```

`todo.sh` bascule automatiquement sur `generate_basic_summary()` (rapport sans analyse IA) si Ollama est inaccessible.

### `⚠️ N² memory key not found`

```bash
# Créer la clé uplanet.G1.nostr (nécessite UPLANETNAME défini)
source tools/my.sh
./tools/keygen -t nostr "${UPLANETNAME}.G1" "${UPLANETNAME}.G1" \
    > ~/.zen/game/uplanet.G1.nostr
```

### `❌ --export nécessite un chemin de fichier`

```bash
# Correct :
./todo.sh --week --export /chemin/bilan.md

# Incorrect (extension manquante → format json par défaut) :
./todo.sh --week --export bilan    # → JSON malgré le nom sans extension
```

### `⚠️ ComfyUI non disponible, pas d'illustration`

L'option `--no-image` désactive la génération d'image. Si ComfyUI est absent, `generate_article.sh` continue sans erreur (image_url = "").

### Vérifier les logs

```bash
# Logs IA globaux
tail -f ~/.zen/tmp/IA.log

# Log des publications Open Collective
cat ~/.zen/game/opencollective/updates.log
```

### Régénérer sans tenir compte du marqueur

```bash
# Forcer l'analyse des dernières 24h
./todo.sh --day

# Puis réinitialiser le marqueur
rm ~/.zen/game/todo_last_run.marker
```

---

## Voir aussi

- [`docs/N2_MEMORY_SYSTEM.md`](N2_MEMORY_SYSTEM.md) — Architecture mémoire N² détaillée
- [`docs/COLLABORATIVE_COMMONS_SYSTEM.md`](COLLABORATIVE_COMMONS_SYSTEM.md) — Global Commons et gouvernance
- [`code_assistant_DOC.md`](../code_assistant_DOC.md) — Assistant IA pour l'analyse de code
- [`plans/todo_code_assistant_integration.md`](../../plans/todo_code_assistant_integration.md) — Feuille de route des phases 2-4
