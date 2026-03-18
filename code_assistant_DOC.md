# code_assistant — Documentation

> Assistant IA interactif pour l'analyse, la correction et le contrôle de code.  
> Utilise Ollama (local/swarm), Qdrant (mémoire sémantique) et cpscript  
> pour offrir un cycle complet d'amélioration de code guidé par l'IA.

---

## Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Prérequis](#prérequis)
3. [Installation rapide](#installation-rapide)
4. [Utilisation de base](#utilisation-de-base)
5. [Options complètes](#options-complètes)
6. [Profils automatiques (server / client)](#profils-automatiques-server--client)
7. [Règles projet (`.assistant_rules`)](#règles-projet-assistantrules)
8. [Flux de travail détaillé](#flux-de-travail-détaillé)
9. [Mode `--test` — Diagnostic actif](#mode---test--diagnostic-actif)
10. [Mode `--doc` — Diagnostic actif](#mode---doc--diagnostic-actif)
11. [Mémoire KV (`--kvbasename`)](#mémoire-kv---kvbasename)
12. [Intégration Qdrant](#intégration-qdrant)
13. [Application des patches (`--patch`)](#application-des-patches---patch)
14. [Outils connexes](#outils-connexes)
15. [Architecture](#architecture)
16. [Dépannage](#dépannage)

---

## Vue d'ensemble

`code_assistant` orchestre 4 couches :

```
┌─────────────────────────────────────────────────────────────────┐
│  code_assistant (bash)                                          │
│  → Orchestration, UX, diff interactif, application des patches │
│  → Détection de profil (server/client), .assistant_rules       │
│  → Dry run tests, coverage map, diagnostic doc ↔ code          │
├─────────────────────────────────────────────────────────────────┤
│  cpscript                                                       │
│  → Extraction récursive du contexte code (JSON)                 │
│  → Détection imports Python (ast), source Bash sans extension   │
├─────────────────────────────────────────────────────────────────┤
│  IA/code_assistant.py                                           │
│  → Phases LLM (analyse/correction/contrôle), mémoire KV        │
│  → System prompts adaptatifs (--test, --doc, profil client)    │
│  IA/embed.py                                                    │
│  → Embeddings nomic-embed-text + indexation/recherche Qdrant    │
├─────────────────────────────────────────────────────────────────┤
│  IA/ollama.me.sh                                                │
│  → Connectivité Ollama : local → SSH tunnel → IPFS P2P Swarm   │
│     + test latence + disponibilité modèles sur chaque nœud      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Prérequis

| Composant | Requis | Installation |
|---|---|---|
| `python3` | ✅ | `sudo apt install python3` |
| `ollama` (Python) | ✅ | `pip install ollama` |
| `requests` (Python) | Recommandé | `pip install requests` |
| Ollama (serveur) | ✅ | https://ollama.ai ou via `IA/ollama.me.sh` |
| `deepseek-r1:14b` | Recommandé (analyse) | `ollama pull deepseek-r1:14b` |
| `qwen2.5-coder:14b` | Recommandé (correction) | `ollama pull qwen2.5-coder:14b` |
| `nomic-embed-text` | Recommandé (mémoire) | `ollama pull nomic-embed-text` |
| Qdrant | Optionnel | `docker run -p 6333:6333 qdrant/qdrant` |
| `curl`, `diff`, `jq` | ✅ | `sudo apt install curl diffutils jq` |
| `node` | Optionnel (validation JS) | `sudo apt install nodejs` |

---

## Installation rapide

```bash
# Se placer dans le projet
cd Astroport.ONE

# Rendre exécutables
chmod +x code_assistant cpscript IA/embed.py IA/code_assistant.py

# Télécharger les modèles recommandés
./code_assistant --setup

# Vérifier Ollama
IA/ollama.me.sh            # démarre/connecte Ollama si nécessaire

# Vérifier le modèle d'embedding
python3 IA/embed.py --check

# Optionnel : démarrer Qdrant
docker run -d -p 6333:6333 -p 6334:6334 \
  -v "$(pwd)/qdrant_storage:/qdrant/storage:z" \
  qdrant/qdrant
```

---

## Utilisation de base

### Flux recommandé en 3 étapes

```bash
# Étape 1 : ANALYSE — Identifier les problèmes
./code_assistant UPassport/routers/geo.py --kvbasename geo-fix

# Étape 2 : CORRECTION — Générer des options pour le problème 2
./code_assistant UPassport/routers/geo.py --kvbasename geo-fix \
  --phase correction --choice 2

# Étape 3 : CONTRÔLE + APPLICATION — Vérifier et appliquer la variante b
# Avec --patch, l'application est directe (pas de copier-coller)
./code_assistant UPassport/routers/geo.py --kvbasename geo-fix \
  --phase controle --choice b --patch
```

### Exemple de sortie — Phase ANALYSE

```
╔══════════════════════════════════════════════════════════════╗
║  🤖 CODE ASSISTANT — Phase : ANALYSE                         ║
╠══════════════════════════════════════════════════════════════╣
║  Script  : geo.py                                            ║
║  Session : geo-fix                                           ║
║  Modèle  :                                                   ║
║  Profil  : 🖥️  server  (Bash/Python/Markdown)                ║
╚══════════════════════════════════════════════════════════════╝

📦 Extraction du contexte (depth=1, maxtoken=32000)...
  ✓ 5 fichier(s) — ~8200 tokens

=== ANALYSE ===
1. [SÉCURITÉ] Paramètres lat/lon non validés — injection possible
   Localisation: geo.py:48
   Impact: CRITIQUE

2. [PERFORMANCE] Requête synchrone bloque le worker async
   Localisation: geo.py:112
   Impact: MAJEUR

3. [MAINTENABILITÉ] Constantes magiques non documentées
   Localisation: geo.py:77,89,134
   Impact: MINEUR
=== FIN ANALYSE ===
```

---

## Options complètes

```
Usage : code_assistant <script> [options]

Options :
  --kvbasename <nom>   Nom de session persistante (mémoire entre runs)
                       Default : "default"

  --model <nom>        Modèle Ollama (défaut: auto par phase)
                       Analyse    → deepseek-r1:14b
                       Correction → qwen2.5-coder:14b

  --phase <phase>      Phase à exécuter (défaut: analyse)
                       Valeurs : analyse | correction | controle

  --depth N            Profondeur d'extraction cpscript (défaut: 1)
                       1 = script + dépendances directes seulement
                       2 = +dépendances des dépendances

  --maxtoken N         Limite tokens du contexte code (défaut: 32000)

  --exclude <f>        Exclure un fichier par basename (répétable)
                       Ex: --exclude my.sh --exclude config.py

  --choice <N|a|b|c>   Choix direct (non-interactif)
                       N = 1|2|3 pour analyse, a|b|c pour correction

  --supplement <txt>   Contexte humain injecté dans le prompt LLM
                       Ex: --supplement "Focus sur le timeout IPFS ligne 131"
                       Inline avec choix : "2 Focus sur le timeout"

  --human              Mode interactif extraction + revue des prompts LLM
                       [Y=inclure / n=ignorer / a=tout / q=quitter]

  --doc                Inclure les .md de docs/ qui référencent ce script
                       + diagnostic actif incohérences doc ↔ code

  --test               Charger les tests depuis tests/ + diagnostic actif
                       Dry run pytest/unittest/bats, coverage map via ast
                       Si tests échouent, stacktraces injectées dans le contexte LLM

  --patch              Appliquer la correction dans le fichier source
                       Montre un diff coloré + validation syntaxique
                       En phase controle : application directe (exec)

  --no-qdrant          Désactiver Qdrant (même s'il est disponible)

  --diff-format <fmt>  Format des patches LLM (défaut: unified)
                       json    = fichier complet (robuste)
                       unified = diff -u (économise les tokens)

  --setup              Télécharger les modèles recommandés via ollama pull
                       (deepseek-r1:14b, qwen2.5-coder:14b, nomic-embed-text)

  --help               Affiche cette aide
```

---

## Profils automatiques (server / client)

`code_assistant` détecte automatiquement le profil selon l'extension du fichier fourni :

| Extension | Profil | Contexte LLM injecté |
|---|---|---|
| `.sh`, `.py` | **server** | scripts Linux, Python, Bash |
| `.html`, `.js`, `.css` | **client** | web old-school, jQuery/vanilla |
| `.md`, `.json` | auto | client si `.html`/`.js` coexistent, sinon server |
| autre | **server** | fallback |

### Profil `client` — contraintes injectées automatiquement

Si aucun `--supplement` n'est fourni, le système injecte :

> *"HTML5 + CSS3 + JavaScript vanilla ou jQuery. Bibliothèques via `<script src='...'>` uniquement (CDN).  
> PAS de frameworks modernes (React, Vue, Angular, Svelte, Next.js).  
> PAS de npm, webpack, vite, TypeScript, Babel.  
> PAS de modules ES6 (`import/export`)."*

Les CDN déjà utilisés dans les `.html` du projet sont détectés et listés dans la contrainte.

Le profil est affiché dans l'en-tête :
```
║  Profil  : 🌐 client  (HTML/CSS/JS vanilla·jQuery·CDN)       ║
```

---

## Règles projet (`.assistant_rules`)

Créez un fichier `.assistant_rules` dans le répertoire du script, du projet ou de `Astroport.ONE/` pour injecter des règles permanentes dans tous les prompts :

```
# .assistant_rules
Toujours utiliser des docstrings Google Style.
Pas de bibliothèques externes absentes de requirements.txt.
Nommer les fonctions en snake_case.
Pas de print() dans le code de production, utiliser logging.
```

**Recherche en cascade** (premier trouvé) :
1. `<dir_du_script>/.assistant_rules`
2. `<dir_du_script>/../.assistant_rules`
3. `<dossier_code_assistant>/.assistant_rules`

Si trouvé, affiché dans l'en-tête :
```
║  Rules   : 📋 .assistant_rules chargé                        ║
```

Le contenu est annexé au `--supplement` existant (sans l'écraser).

---

## Flux de travail détaillé

### Phase `analyse`

**Objectif** : Identifier les 3 problèmes prioritaires du code.

**Entrée** : Contexte code extrait par `cpscript --json`  
**Sortie** : Liste numérotée 1/2/3 avec catégorie, localisation, impact

**Modèle** : `deepseek-r1:14b` (raisonnement Chain-of-Thought)

```bash
# Analyse simple
./code_assistant mon_script.py --kvbasename session1

# Avec focus utilisateur
./code_assistant mon_script.py --kvbasename session1 \
  --supplement "Focus sur la gestion des erreurs réseau"

# Sans Qdrant
./code_assistant mon_script.sh --kvbasename session1 --no-qdrant
```

---

### Phase `correction`

**Objectif** : Générer 3 variantes de correction pour le problème choisi.

**Modèle** : `qwen2.5-coder:14b` (code spécialisé)

**Format JSON LLM** :
```json
{
  "problem": "Paramètres non validés",
  "options": {
    "a": { "description": "Correction minimale (patch chirurgical)",
           "files": [{"path": "geo.py", "content": "..."}] },
    "b": { "description": "Correction complète (robuste)",
           "files": [{"path": "geo.py", "content": "..."}] },
    "c": { "description": "Refactoring (meilleure architecture)",
           "files": [{"path": "geo.py", "content": "..."}] }
  }
}
```

```bash
# Corriger le problème 2
./code_assistant mon_script.py --kvbasename session1 \
  --phase correction --choice 2

# Avec contexte supplémentaire
./code_assistant mon_script.py --kvbasename session1 \
  --phase correction --choice 2 \
  --supplement "Préfère une solution async compatible asyncio"
```

---

### Phase `controle`

**Objectif** : Vérifier la correction, identifier les risques.

**Sortie** : Rapport avec verdict (OK / ATTENTION / REFUSER)

```bash
# Contrôler la variante b
./code_assistant mon_script.py --kvbasename session1 \
  --phase controle --choice b

# Contrôler ET appliquer directement (exec, pas de copier-coller)
./code_assistant mon_script.py --kvbasename session1 \
  --phase controle --choice b --patch
```

**Exemple de sortie** :
```
=== CONTRÔLE ===
Verdict: OK

✓ Points validés:
- Validation Pydantic correctement intégrée
- Pas de régression sur les endpoints existants

⚠ Risques identifiés:
- Les coordonnées hors plage [-90,90]/[-180,180] non gérées

🧪 Tests recommandés:
- test_geo.py::test_invalid_coordinates
- test_geo.py::test_boundary_values
=== FIN CONTRÔLE ===
```

---

## Mode `--test` — Diagnostic actif

Le mode `--test` passe de l'injection passive à un **diagnostic d'exécution réel** :

### 1. Détection des fichiers de test

Cherche dans 4 répertoires candidats : `tests/`, `../tests/`, `test/`, `../test/`  
Patterns : `test_<script>.*` et `<script>_test.*`

### 2. Dry Run

Avant l'envoi au LLM, exécute les tests détectés :

| Extension | Runner prioritaire | Fallback |
|---|---|---|
| `.py` | `pytest -x --tb=short` | `unittest` |
| `.sh` | `bats` | `bash <test>` |

```
🧪 Mode --test : diagnostic actif des tests unitaires
  ✓ Fichier(s) de test trouvé(s) :
    • tests/test_geo.py
  🏃 Dry run pytest...
  ❌ 2 test(s) en échec (pytest) :
     FAILED test_geo.py::test_validate_coords - AssertionError
     ERROR  test_geo.py::test_boundary - TypeError: ...
  📊 Fonctions sans couverture détectée : validate_range, build_response
```

### 3. Coverage Map (ast)

Extrait les fonctions publiques du script source et vérifie leur présence dans les fichiers de test. Sans `coverage.py`, 100% fiable via `ast`.

### 4. Injection dans le contexte LLM

Les résultats sont injectés dans des sections dédiées du contexte :
- `### RÉSULTATS DES TESTS (dry run) ###` — stacktraces réelles
- `### COUVERTURE — fonctions non testées ###` — gaps de couverture

### 5. System prompt adaptatif

**Si tests en échec** : l'IA est contrainte à résoudre uniquement les erreurs réelles.  
**Si tests passants** : l'IA identifie les fonctions non couvertes.

### 6. Contrainte non-régression (phase contrôle)

Avec `--test`, la phase `controle` exige **obligatoirement** :

> *"🔒 Fournis le bloc pytest/shunit2 qui aurait échoué AVANT et passe AVEC la correction."*

### Exemples

```bash
# Analyse avec diagnostic test
./code_assistant geo.py --kvbasename geo-fix --test

# Correction ciblée sur les tests en échec
./code_assistant geo.py --kvbasename geo-fix \
  --test --phase correction --choice 2

# Contrôle + non-régression + patch
./code_assistant geo.py --kvbasename geo-fix \
  --test --phase controle --choice b --patch

# Si aucun test trouvé : l'IA propose de les créer
./code_assistant utils.py --kvbasename utils --test
#  ⚠️  Aucun test trouvé — l'IA proposera tests/test_utils.py
```

---

## Mode `--doc` — Diagnostic actif

Le mode `--doc` va au-delà de l'injection des `.md` : il compare les signatures du code avec la documentation.

### 1. Détection des `.md` associés

`cpscript --doc` charge les fichiers `.md` de `docs/` qui référencent le script.

### 2. Diagnostic signatures (Python)

Un script Python `ast` embarqué :
- Extrait toutes les signatures `def func(arg1, arg2)` du code source
- Cherche leurs mentions dans les `.md`
- Détecte les arguments dans la doc qui n'existent plus dans le code
- Détecte les fonctions `` `func()` `` dans la doc mais absentes du code

```
📖 Mode --doc : diagnostic actif doc ↔ code...
  ⚠️  Incohérences doc ↔ code détectées :
    • [docs/api.md] validate_coords(): args inconnus dans la doc : id_int
    • [docs/api.md] `old_helper()` mentionné mais absent du code
```

### 3. Injection dans le contexte LLM

Section ajoutée : `### INCOHÉRENCES DOC vs CODE ###`

### 4. System prompt adaptatif

En mode `--doc`, l'IA est guidée vers la conformité code ↔ documentation.

```bash
# Analyse avec diagnostic doc
./code_assistant geo.py --kvbasename geo-fix --doc

# Combiné test + doc (cycle complet)
./code_assistant geo.py --kvbasename geo-fix --test --doc
```

---

## Mémoire KV (`--kvbasename`)

La session est stockée dans `~/.zen/tmp/flashmem/code_assistant/<kvbasename>.json`.

### Structure KV

```json
{
  "kvbasename": "geo-fix",
  "script": "/path/to/geo.py",
  "phase": "controle",
  "history": [
    {"phase": "analyse",    "choice": null, "timestamp": 1710000000, "summary": "..."},
    {"phase": "correction", "choice": "2",  "timestamp": 1710000100, "summary": "..."}
  ],
  "last_proposals": {
    "1": "Sécurité: paramètres non validés...",
    "2": "Performance: requête synchrone...",
    "3": "Maintenabilité: constantes magiques..."
  },
  "last_correction_text": "{\"options\":{\"a\":{...},\"b\":{...},\"c\":{...}}}",
  "last_choice": "2",
  "last_variant_choice": "b",
  "accepted_patches": [],
  "git_hash": "a3f9c1d"
}
```

### Reprendre une session

```bash
# Voir l'état d'une session
cat ~/.zen/tmp/flashmem/code_assistant/geo-fix.json | python3 -m json.tool

# Continuer depuis n'importe quelle phase
./code_assistant geo.py --kvbasename geo-fix --phase controle
```

---

## Intégration Qdrant

Qdrant est utilisé pour la **mémoire sémantique** entre les sessions.

### Indexation automatique

À chaque phase, l'assistant indexe automatiquement le résumé de la session avec un ID stable via `SHA-256` (pas de doublons entre redémarrages).

### Apprentissage des refus

Quand un patch est refusé (`n`), l'outil propose d'enregistrer la raison :

```
  ⏭️  Patch ignoré pour geo.py
  📝 Raison du refus (optionnel, mémoire IA) : trop intrusif, préférer async
```

La raison est indexée dans la collection `ca_refusals` de Qdrant. Lors des prochaines analyses, l'IA peut recevoir ce contexte : *"L'utilisateur a précédemment rejeté une solution de type X car Y"*.

### Recherche sémantique au démarrage

Avant chaque analyse, les 3 sessions les plus similaires sont récupérées et injectées dans le prompt (filtrées par langue : Python/Shell).

### Utilisation directe de `embed.py`

```bash
# Vérifier la connectivité
python3 IA/embed.py --check

# Générer un embedding
echo "validation des coordonnées GPS" | python3 IA/embed.py

# Indexer dans Qdrant
python3 IA/embed.py --index --collection code_assistant \
  --payload '{"script":"geo.py","session":"geo-fix"}' \
  "$(cat geo.py)"

# Rechercher des analyses similaires
python3 IA/embed.py --search --collection code_assistant \
  --language py --top 5 \
  "validation paramètres FastAPI"
```

---

## Application des patches (`--patch`)

### Mode diff interactif

```diff
  📄 routers/geo.py
  ┌─── DIFF (original → correction) ───────────────────
  │ --- a/routers/geo.py
  │ +++ b/routers/geo.py
  │ @@ -45,7 +45,12 @@
  │ -async def get_geo(lat, lon):
  │ +async def get_geo(
  │ +    lat: float = Query(..., ge=-90, le=90),
  │ +    lon: float = Query(..., ge=-180, le=180)
  │ +) -> GeoResponse:
  └─── 8 lignes modifiées ────────────────────────────
  
  Appliquer ce patch ? [Y/n]
```

### Validation syntaxique préalable

Avant d'écraser le fichier, la syntaxe est vérifiée :

| Extension | Outil | Comportement |
|---|---|---|
| `.py` | `python3 -m py_compile` | Bloque si invalide |
| `.sh` | `bash -n` | Bloque si invalide |
| `.json` | `jq .` | Bloque si invalide |
| `.js` | `node --check` | Bloque si invalide |
| `.html` | heuristique ast | Avertissement (non bloquant) |

### Sécurité anti-destruction

Si le patch représente moins de 70% des lignes de l'original (sur un fichier > 20 lignes) :

```
  ⚠️  ⚠️  RISQUE DE TRONCATURE DÉTECTÉ !
     Original : 245 lignes  →  Patch : 48 lignes (19%)
     Le LLM a peut-être renvoyé du code tronqué ('// ... reste inchangé ...')
  Forcer quand même l'application ? [y/N]
```

### Backup automatique

```
geo.py.bak.20260317161530
```

### Application directe en phase contrôle

Avec `--patch` en phase `controle`, l'approbation déclenche directement la phase correction+patch via `exec` — pas de commande à copier-coller.

---

## Outils connexes

### `cpscript` — Extraction récursive

```bash
# Contexte JSON pour code_assistant (défaut: depth=1)
cpscript --json --depth 1 --maxtoken 32000 mon_script.py

# Inclure la documentation associée
cpscript --json --doc mon_script.py

# Mode interactif : valider chaque dépendance
cpscript --json --human mon_script.py

# Exclure les fichiers bruyants
cpscript --json --exclude my.sh --exclude config.py mon_script.py
```

### `embed.py` — Embeddings + Qdrant

```bash
# Test de l'infrastructure
python3 IA/embed.py --check

# Télécharger le modèle si absent
python3 IA/embed.py --pull

# Recherche multi-langue
python3 IA/embed.py --search --collection code_assistant \
  --top 10 "upload fichier IPFS"
```

---

## Architecture

```
Astroport.ONE/
├── code_assistant          # Script bash front-end (orchestration)
├── code_assistant_DOC.md   # Cette documentation
├── cpscript                # Extraction récursive .sh/.py → JSON/texte
├── .assistant_rules        # Règles projet (optionnel)
└── IA/
    ├── code_assistant.py   # Backend Python (phases LLM + KV)
    ├── embed.py            # Embeddings nomic-embed-text + Qdrant
    └── ollama.me.sh        # Connectivité Ollama (local/SSH/P2P)
```

### Flux de données complet

```
<script_source>
       │
       ▼
cpscript --json
       │ JSON {files: [{path, content, extension}]}
       ▼
code_assistant (bash) — enrichissement
       ├── Profil auto (server/client) → supplement système
       ├── .assistant_rules → ajout au supplement
       ├── --test : dry run pytest/bats + coverage ast
       │     → CODE_JSON {_test_results, _coverage_gaps}
       ├── --doc : diagnostic signatures ast vs .md
       │     → CODE_JSON {_doc_issues}
       │
       ▼ stdin = CODE_JSON enrichi
code_assistant.py
       ├── build_code_summary() → sections TEST/DOC/COVERAGE
       ├── _build_analyse_prompt(test_ctx, doc_ctx)
       ├── _build_controle_prompt(test_mode)
       ├── Qdrant search (embed.py) → contexte sémantique
       ├── Ollama LLM (phase: analyse/correction/controle)
       ├── Mémoire KV (save/load ~/.zen/tmp/flashmem/)
       └── Qdrant index (embed.py) → mémorisation session
       │
       ▼ stdout
code_assistant (bash)
       ├── Affichage coloré des propositions
       ├── Validation syntaxique (py/sh/json/js/html)
       ├── Vérification anti-destruction (taille < 70% → alerte)
       ├── Diff coloré + confirmation [Y/n]
       ├── Apprentissage des refus → Qdrant (collection ca_refusals)
       └── Phase contrôle + --patch → exec direct (pas de copier-coller)
```

---

## Dépannage

### Ollama non disponible

```bash
# Vérifier
curl -sf http://localhost:11434/api/tags | python3 -m json.tool

# Démarrer via ollama.me.sh (local → SSH → P2P)
bash IA/ollama.me.sh

# Forcer le mode local
ollama serve &
```

### Modèle manquant

```bash
# Télécharger tous les modèles recommandés
./code_assistant --setup

# Manuellement
ollama pull deepseek-r1:14b
ollama pull qwen2.5-coder:14b
ollama pull nomic-embed-text

# Vérifier l'embedding
python3 IA/embed.py --check
```

### cpscript ne génère pas de JSON valide

```bash
# Tester cpscript seul
Astroport.ONE/cpscript --json --depth 1 mon_script.py 2>&1 | head -5

# Si erreur "Aucun contenu généré" :
# → Vérifier les --exclude (trop larges ?)
# → Essayer sans --only
# → Augmenter --maxtoken
```

### Patch non appliqué (aucun patch dans la réponse)

Le LLM n'a pas répondu au bon format. Consultez le log :

```bash
tail -50 ~/.zen/tmp/IA.log
```

Solutions :
- Réduisez le contexte : `--maxtoken 16000` ou `--depth 1`
- Reformulez via `--supplement`
- Relancez la phase `correction` avec un autre `--choice`

### Qdrant non accessible

```bash
# Vérifier
curl -sf http://localhost:6333/health

# Démarrer Qdrant
docker start qdrant  # si container existant
# ou
docker run -d -p 6333:6333 qdrant/qdrant

# Désactiver si non nécessaire
./code_assistant script.py --no-qdrant
```

---

## Variables d'environnement

| Variable | Défaut | Description |
|---|---|---|
| `OLLAMA_HOST` | `http://localhost:11434` | URL du serveur Ollama |
| `QDRANT_URL` | `http://localhost:6333` | URL du serveur Qdrant |
| `CA_MAX_STDIN_MB` | `500` | Limite RAM pour le JSON entrant |

```bash
# Exemple avec Ollama distant
OLLAMA_HOST=http://192.168.1.100:11434 \
  ./code_assistant mon_script.py --kvbasename session1
```

---

## Exemples avancés

### Analyse d'un projet Python complet

```bash
./code_assistant UPassport/routers/media_upload.py \
  --kvbasename upload-audit \
  --exclude my.sh \
  --depth 2 \
  --maxtoken 64000
```

### Cycle complet avec test et doc

```bash
# Analyse avec contexte tests + doc
./code_assistant geo.py --kvbasename geo-v2 --test --doc

# Correction du problème le plus critique
./code_assistant geo.py --kvbasename geo-v2 \
  --phase correction --choice 1

# Contrôle + non-régression + application directe
./code_assistant geo.py --kvbasename geo-v2 \
  --phase controle --choice a --patch --test
```

### Mode client web (profil auto)

```bash
# Profil client détecté automatiquement (.html)
./code_assistant UPlanet/earth/index.html --kvbasename earth-ui

# Profil client + règles projet custom
cat > .assistant_rules << 'EOF'
jQuery 3.x uniquement — pas d'async/await.
Compatibilité Chrome 80+ et Firefox 78+.
EOF
./code_assistant UPlanet/earth/common.js --kvbasename earth-js
```

### Pipeline CI non-interactif

```bash
#!/bin/bash
SCRIPT="mon_script.py"
SESSION="ci-$(date +%Y%m%d)"

# Analyse + choix automatique
./code_assistant "$SCRIPT" --kvbasename "$SESSION" \
  --choice 1 --no-qdrant

# Correction variante minimale
./code_assistant "$SCRIPT" --kvbasename "$SESSION" \
  --phase correction --choice 1

# Contrôle + patch automatique (stdin non-TTY)
echo "y" | ./code_assistant "$SCRIPT" --kvbasename "$SESSION" \
  --phase controle --choice a --patch
```

---

---

## Assistants de code alternatifs pour le Capitaine

`code_assistant` est l'outil **souverain et hors-ligne** d'Astroport.ONE.
Pour les phases de développement connectées, le capitaine peut utiliser
des interfaces visuelles plus riches. Voici les options recommandées :

---

### 🖥️ Option 1 — VSCode + Roo Code (interface graphique)

**Roo Code** est une extension VSCode open-source qui offre une expérience
similaire à Claude Code, avec support multi-modèle (Anthropic, OpenAI, Ollama…).

```bash
# 1. Installer VSCode si nécessaire
sudo apt install code  # ou télécharger sur https://code.visualstudio.com

# 2. Installer l'extension Roo Code
#    → Ouvrir VSCode > Extensions > chercher "Roo Code" > Installer
#    → ou en ligne de commande :
code --install-extension RooVetGit.roo-cline

# 3. Configurer avec Ollama local (souverain, hors-ligne)
#    → VSCode Settings > Roo Code > API Provider: Ollama
#    → Base URL: http://localhost:11434
#    → Lancer Ollama d'abord :
bash ~/.zen/Astroport.ONE/IA/ollama.me.sh

# 4. Configurer avec l'API Anthropic (connecté)
#    → API Provider: Anthropic
#    → Saisir votre clé API : https://console.anthropic.com
```

**Avantages Roo Code :**
- Interface visuelle dans l'IDE avec diff coloré et approbation inline
- Gestion des fichiers multi-repo dans un seul workspace
- Support Ollama local → **fonctionne hors-ligne avec les modèles de l'essaim**
- Mémoire de projet via `.roo/` (règles, contexte)
- Compatible `.assistant_rules` (même philosophie que `code_assistant`)

**Fichier de règles Roo** (`~/.zen/Astroport.ONE/.roo/rules/rules.md`) :
```markdown
# Règles Astroport.ONE pour Roo Code
- Stack : Bash/Python/HTML5/jQuery — PAS de frameworks JS modernes
- Bibliothèques JS via CDN <script src="..."> uniquement
- Respecter l'architecture ~/.zen/ existante
- Ne jamais modifier les fichiers de clés (*.seed, secret.june, .player)
- Tester avec bash -n (scripts) ou python3 -m py_compile (Python) avant tout patch
```

```bash
# Créer les règles Roo pour Astroport.ONE
mkdir -p ~/.zen/Astroport.ONE/.roo/rules
cp ~/.zen/Astroport.ONE/.assistant_rules \
   ~/.zen/Astroport.ONE/.roo/rules/rules.md 2>/dev/null || \
cat > ~/.zen/Astroport.ONE/.roo/rules/rules.md << 'EOF'
Stack Bash/Python/HTML5/jQuery — PAS de frameworks JS modernes.
Bibliothèques JS via CDN uniquement.
Ne modifier aucun fichier de clés cryptographiques.
EOF
```

> 🔗 Dépôt officiel : https://github.com/RooVetGit/Roo-Code

---

### ⚡ Option 2 — OpenCode (terminal, style Claude Code)

**OpenCode** est un assistant de code en ligne de commande (TUI), open-source,
inspiré de Claude Code. Il fonctionne dans le terminal sans VSCode.

```bash
# Installation via npm (nécessite Node.js 18+)
sudo npm install -g opencode-ai

# Ou via cargo (Rust)
cargo install opencode

# Lancer dans un projet
cd ~/.zen/Astroport.ONE
opencode

# Configurer un modèle Ollama local
opencode config set provider ollama
opencode config set model qwen2.5-coder:14b
opencode config set base-url http://localhost:11434
```

**Avantages OpenCode :**
- Interface TUI (terminal) — fonctionne en SSH sur une ♥BOX distante
- Pas besoin de VSCode installé
- Support natif Ollama → **100% local et souverain**
- Gestion de conversation multi-tours avec contexte projet
- Compatible avec le workflow en 3 phases de `code_assistant`

> 🔗 Dépôt officiel : https://github.com/sst/opencode

---

### 📊 Comparatif des approches

| Critère | `code_assistant` | Roo Code (VSCode) | OpenCode (TUI) |
|---|---|---|---|
| **Interface** | Terminal bash | Graphique IDE | Terminal TUI |
| **Hors-ligne** | ✅ Ollama/P2P | ✅ si Ollama | ✅ si Ollama |
| **Contexte Astroport** | ✅ cpscript récursif | Manuel | Manuel |
| **Mémoire Qdrant** | ✅ intégrée | ❌ | ❌ |
| **Accès SSH ♥BOX** | ✅ | ❌ (besoin X11) | ✅ |
| **Multi-fichiers** | ✅ depth N | ✅ workspace | ✅ |
| **Souveraineté** | ✅✅ essaim swarm | ✅ si Ollama | ✅ si Ollama |
| **Apprentissage refus** | ✅ Qdrant | ❌ | ❌ |

**Recommandation :**
- **Sur la ♥BOX en SSH** → `code_assistant` ou `opencode`
- **Sur le poste de travail avec écran** → Roo Code (VSCode)
- **En production / maintenance** → `code_assistant` (souverain, sans dépendance cloud)

---

### 🔗 Ressources

| Outil | Lien |
|---|---|
| Roo Code extension | https://marketplace.visualstudio.com/items?itemName=RooVetGit.roo-cline |
| Roo Code GitHub | https://github.com/RooVetGit/Roo-Code |
| OpenCode GitHub | https://github.com/sst/opencode |
| Ollama (moteur IA local) | https://ollama.ai |
| Astroport.ONE essaim | `bash ~/.zen/Astroport.ONE/IA/ollama.me.sh SCAN` |

---

*Mis à jour le 2026-03-18 — Astroport.ONE / UPlanet*
