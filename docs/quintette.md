# Quintette `feedback` · `issue` · `commit` · `cpscript` · `cpcode`

Documentation suivant la méthode **Diataxis** (quatre modes : Tutoriel · Guides pratiques · Référence · Explication).

`cpscript` et `cpcode` sont les outils de **bundling de contexte** qui alimentent `issue.sh` : ils transforment le code source en un corpus ingestible par l'IA.

---

## Tutoriel — De la panne au correctif en une session

> **Objectif** : Tu n'as jamais utilisé ces outils. À la fin tu auras signalé un vrai bug, analysé sa cause avec une IA, proposé un correctif et livré un commit documenté.

### Prérequis

- Station Astroport tournant localement (`./start.sh` dans `Astroport.ONE/`)
- Ollama installé avec le modèle `deepseek-coder-v2:dagbs` (ou `--ai claude` avec clé API)
- Un repo Git avec des issues ouvertes (GitHub ou Gitea)

---

### Étape 1 — Signaler un bug depuis le navigateur

1. Ouvre n'importe quelle page UPlanet (ex. `roaming.html`, `feedback.html`).
2. Clique sur le bouton **Signaler un bug** (coin inférieur droit).
3. Sur la page qui s'ouvre, appuie sur **Lancer le diagnostic automatique**.

   Le diagnostic teste quatre points :
   - `UPassport /health` (la station répond-elle ?)
   - WebSocket relay (le relay NOSTR est-il joignable ?)
   - Extension NIP-07 (Alby / nos2x détectée ?)
   - Authentification NIP-42 (résultat du dernier test roaming)

4. Le formulaire se pré-remplit avec les résultats. Ajoute un titre et clique **Envoyer**.
5. Le rapport est posté vers `POST /api/feedback` de ta station. Si le dépôt Git est configuré, une issue est créée automatiquement. Note son numéro (ex. `#8`).

---

### Étape 2 — Analyser l'issue avec l'IA

```bash
cd ~/workspace/AAA/Astroport.ONE
./issue.sh analyze 8 --verbose --minify
```

En coulisse, `issue.sh` appelle `cpscript` et `cpcode` pour construire le contexte code :

```
issue.sh analyze 8
   ├── Recherche Qdrant → fichiers candidats
   ├── cpscript --json --depth 1 --maxtoken 10000 <fichier_principal>
   │       → agrège le fichier + toutes ses dépendances récursives
   ├── cpcode --maxfilesize 32768 <dossier> sh py
   │       → fallback : tous les .sh/.py du dossier
   └── Injecte le tout dans {{CODE_CONTEXT}} du prompt IA
```

L'outil :
- récupère le titre, la description et les commentaires de l'issue `#8`
- cherche dans la base vectorielle Qdrant les fichiers sources les plus pertinents
- bundle le code avec `cpscript` (dépendances récursives) ou `cpcode` (fallback dossier)
- injecte le code dans un prompt structuré et appelle l'IA
- affiche le plan de correction

---

### Étape 3 — Générer et affiner le correctif

```bash
# Depuis le menu affiché après l'analyse :
# tape "f" pour passer en mode fix

./issue.sh analyze 8 --ai claude
# → [f] Fix  [p] PR  [suite]
f
```

Si la première suggestion ne convainc pas :
```
[r] Insister / reformuler
Choix [r/t/c/k/suite] : r
🔥 Consigne supplémentaire : Cherche dans 22242.sh autour de exit 1 ligne 60
```

L'IA reçoit la pression supplémentaire et propose un correctif affiné.

---

### Étape 4 — Commiter le travail

Après avoir appliqué le patch manuellement :

```bash
cd ~/workspace/AAA/NIP-101
git add relay.writePolicy.plugin/filter/22242.sh
../Astroport.ONE/commit.sh --staged
```

`commit.sh` génère un message Conventional Commit basé sur le diff, te montre la proposition et propose de créer le commit directement.

---

## Guides pratiques

### Choisir le bon backend IA pour `issue.sh`

| Situation | Commande |
|-----------|----------|
| Analyse rapide, hors ligne | `issue.sh analyze N` (Ollama, défaut) |
| Code complexe, multi-fichiers | `issue.sh analyze N --ai claude` |
| Besoin d'un deuxième avis | `issue.sh analyze N --ai gemini` |
| Modèle personnalisé Ollama | `issue.sh analyze N --model codellama:34b` |

Les clés API Claude et Gemini sont chargées depuis `tools/cooperative_config.sh` (chiffré NOSTR). Si elles sont absentes, `issue.sh` bascule sur Ollama.

---

### Analyser une issue sans Qdrant (grep manuel)

Si la base vectorielle Qdrant n'est pas disponible, `issue.sh` bascule automatiquement sur une recherche par fréquence de mots-clés. Pour forcer un contexte précis :

```bash
# Pointer explicitement les fichiers à injecter
issue.sh analyze 8 --depth 2 --maxtoken 15000
```

- `--depth 2` : suit deux niveaux de dépendances (source → imports → imports des imports)
- `--maxtoken 15000` : augmente le budget par fichier (défaut 10 000)

---

### Lire un rapport feedback comme l'IA le verra

Chaque rapport posté par `feedback.js` contient trois blocs structurés :

```
[STATE]
```json
{ "correlation_id": "fb-...", "station": "http://u.domain:54321", "relay": "wss://...", ... }
```

[PROTOCOLE]
```json
{ "auth_ok": false, "source": "unknown", "auth_reason": "no marker found" }
```

[LOGS]
[10:23:01.123][ERR] WebSocket closed before AUTH received
[10:23:01.456][LOG] challenge=abc123 relayTag=wss://relay.domain/
```

Le **Correlation ID** (`fb-...`) permet de relier le rapport de l'utilisateur aux logs serveur (`nostr.auth.22242.log`) et à l'issue Git créée. Cherche ce même ID dans tous les logs pour reconstituer la séquence complète.

---

### Analyser un diff sur une période passée avec `commit.sh`

```bash
# Résumé de la semaine
commit.sh --week

# Résumé des 3 derniers jours sur une autre branche
commit.sh --day --branch feature/nip42-roaming
# Nombre de jours par défaut = 1 ; --week = 7 ; --month = 30
```

Le résultat est copié dans le presse-papier (wl-copy → xclip → xsel selon l'environnement).

---

### Pré-remplir le formulaire feedback depuis une autre page

Depuis n'importe quelle page du site, avant d'ouvrir `feedback.html` :

```javascript
localStorage.setItem('uplanet_feedback_prefill', JSON.stringify({
    title: 'NIP-42 : AUTH toujours rejetée sur mobile',
    description: 'Relay tag ne correspond pas à l'URL de connexion...',
    ts: Date.now()   // TTL 30 s
}));
window.open('feedback.html', '_blank');
```

### Commiter avec staging interactif et revue IA (`--staged --ai`)

`commit.sh --staged` affiche d'abord tous les fichiers modifiés ou non-trackés, triés du plus récent au plus ancien, avec le nombre de lignes `+ajoutées/-supprimées`. Avec `--ai`, une revue de code est intercalée avant la validation du commit.

```bash
commit.sh --staged --ai claude
```

1. La liste s'affiche — sélectionne : `Entrée` = tout, `1,3,5` = fichiers précis, `1-4` = plage, `aujourd'hui` = modifier du jour.
2. La revue IA analyse le diff et signale bugs évidents, TODOs oubliés, failles de sécurité.
3. Si des ⚠️ apparaissent, Claude peut corriger directement (`Entrée`) ou tu forces le commit (`f`).
4. Le message Conventional Commit est affiché → `Entrée` = commit, `r` = relancer, `n` = annuler.
5. Le commit est créé et pushé. S'il reste des fichiers, un nouveau cycle est proposé.

**Démarche typique sur une branche de correctif :**

```bash
git checkout fix/issue-8
commit.sh --staged --ai claude --pr
# → sélection fichiers → revue → commit → push → PR créée automatiquement
```

---

### Proposer une Pull Request après commit (`--pr`)

Sur une branche de correctif (ex. `fix/issue-8`), `--pr` déclenche après le push la génération IA du titre et du corps de la PR, puis appelle `gh pr create` :

```bash
commit.sh --staged --pr
```

L'IA rédige la PR en français à partir du message de commit et du résumé des tâches. Le titre est affiché et modifiable avant confirmation. **Condition** : `gh` (GitHub CLI) doit être authentifié (`gh auth login`). Sans `gh`, l'étape est silencieusement ignorée.

---

### Gérer le cycle de vie d'une issue (list / create / close / comment)

`issue.sh` permet de gérer les issues sans quitter le terminal :

```bash
# Lister les issues ouvertes avec label
issue.sh list --state open --label bug

# Voir le détail complet (titre, description, commentaires)
issue.sh show 8

# Créer une issue directement depuis le terminal
issue.sh create "NIP-42 : relay tag avec slash final" \
    "Reproduit sur mobile quand l'URL relay = wss://relay.domain/" \
    --label bug

# Fermer avec un commentaire de clôture
issue.sh close 8 "Corrigé dans commit abc1234 — relay tag normalisé sans slash final"

# Ajouter un commentaire sans fermer
issue.sh comment 8 "Confirmé sur Firefox Android 124 — logs disponibles via Correlation ID fb-lz2k3a-x7r9q2"

# Attribuer des labels
issue.sh label 8 bug nip-42 roaming

# Rouvrir si la correction régresse
issue.sh reopen 8
```

---

### Bundler le contexte code manuellement avec `cpscript` / `cpcode`

Utile pour alimenter directement un LLM en dehors d'`issue.sh` (ex. poser une question dans Claude.ai).

```bash
# Tout le service UPassport + ses dépendances → presse-papier
cpscript UPassport/54321.py --depth 2 --maxtoken 8000

# Seulement les routers FastAPI (pattern Python)
cpscript UPassport/routers/identity.py --route /g1nostr

# Tous les filtres Bash du relay strfry → JSON pour LLM
cpscript NIP-101/relay.writePolicy.plugin/filter/22242.sh --json

# Page HTML UPlanet sans les libs tierces (économise ~50 % de tokens)
cpscript UPlanet/earth/index.html --well-known

# Page HTML + dépendances JSON pour issue.sh, sans libs tierces
cpscript UPlanet/earth/minelife.html --well-known --json --maxtoken 20000

# Tous les fichiers JS/CSS d'un dossier (pour revue globale)
cpcode js css UPlanet/earth/

# Sans les bibliothèques tierces embarquées (jQuery, Bootstrap…)
cpcode js UPlanet/earth/ --well-known

# Valider chaque dépendance interactivement avant inclusion
cpscript Astroport.ONE/RUNTIME/NOSTRCARD.refresh.sh --human
```

**Règle de choix :**
- Tu as **un fichier point d'entrée** et veux ses dépendances → `cpscript`
- Tu veux **tous les fichiers d'un type** dans un dossier → `cpcode`

---

## Référence

### `commit.sh`

```
commit.sh [OPTIONS]
```

| Option | Défaut | Description |
|--------|--------|-------------|
| `--commit` / `-c` | ✓ | Diff depuis HEAD (staged + unstaged) |
| `--staged` / `-s` | | Staging interactif par date + commit IA en boucle |
| `--day` / `-d` | | Rapport d'activité des 24 dernières heures |
| `--week` / `-w` | | Rapport d'activité des 7 derniers jours |
| `--month` / `-m` | | Rapport d'activité des 30 derniers jours |
| `--period N` / `-P N` | | Rapport d'activité des N derniers jours |
| `--branch B` / `-b B` | branche courante | Basculer sur `B` avant analyse |
| `--pr` / `-p` | | Proposer une Pull Request après push (IA) |
| `--ai [BACKEND]` / `-a` | `ollama` | Revue de code IA avant commit. BACKEND : `ollama` \| `claude` \| `gemini`. Avec `claude` : correction directe des bugs détectés |
| `--model M` / `-M M` | `qwen2.5-coder:14b` | Modèle Ollama |
| `--verbose` / `-v` | | Affiche diff complet, prompt et réponse brute |
| `--help` / `-h` | | Aide |

**Format de sortie IA :**
```
# COMMIT
<type>(<scope>): <description en impératif, français>

## Tâches réalisées
- …

## Fichiers clés
- …
```

Types Conventional Commit reconnus : `feat`, `fix`, `refactor`, `docs`, `chore`.

**Dépendances runtime :**
- `~/.zen/Astroport.ONE/IA/question.py` (ou `./IA/question.py`)
- `ollama.me.sh` (démarrage Ollama)
- `xclip` / `xsel` / `wl-copy` pour le presse-papier

---

### `issue.sh`

```
issue.sh <commande> [OPTIONS]
```

#### Commandes de gestion

| Commande | Description |
|----------|-------------|
| `list [--state open\|closed\|all] [--label L]` | Liste les issues |
| `show N` | Détail + commentaires de l'issue N |
| `create "titre" "desc" [--label L]` | Crée une issue |
| `close N [commentaire]` | Ferme l'issue N |
| `reopen N` | Rouvre l'issue N |
| `comment N "msg"` | Ajoute un commentaire |
| `label N l1 l2…` | Attribue des labels |
| `repos` | Liste les repos du propriétaire Git |
| `pr N [--base B] [--title "T"]` | Crée une PR liée à l'issue N |

#### Commande `analyze`

```
issue.sh analyze N [OPTIONS]
```

| Option | Défaut | Description |
|--------|--------|-------------|
| `--ai ollama\|claude\|gemini` | `ollama` | Backend IA |
| `--model M` | `deepseek-coder-v2:dagbs` | Modèle (Ollama) |
| `--template T` | `issue_analyze` | Template prompt (`IA/prompts/T.md`) |
| `--depth N` | `1` | Profondeur des dépendances |
| `--maxtoken N` | `10000` | Budget tokens par fichier |
| `--minify` | | Supprime commentaires et lignes vides |
| `--verbose` / `-v` | | Affiche prompt et réponse brute |
| `--logs` | | Ajoute 50 dernières lignes des logs .log mentionnés |
| `--json` | | Sortie JSON brute |
| `--repo OWNER/REPO` | auto (git remote) | Dépôt cible |

**Séquence interne `analyze` :**
1. Fetch issue + commentaires via API Git
2. Recherche de code (Qdrant vectoriel → fallback grep fréquence)
3. Bundling via `cpscript` (dépendances) + `cpcode` (listing dossier)
4. Injection CLAUDE.md (max 1 500 car) + logs (si `--logs`)
5. Minification optionnelle
6. Substitution des placeholders via Python (sûr vis-à-vis des caractères spéciaux)
7. Appel IA avec SYSPROMPT expert UPlanet
8. Menu post-analyse : `[f]ix [p]r [s]how [c]omment [suite]`

**Retry loop (mode fix) :**
- `[r]` + consigne → relance l'IA avec pression cumulée
- `[t]` → teste le correctif proposé
- `[c]` → poste le correctif en commentaire sur l'issue
- `[k]` → crée une branche `fix/issue-N` et y commit le patch

**Placeholders dans les templates :**
`{{ISSUE_NUMBER}}`, `{{ISSUE_TITLE}}`, `{{ISSUE_BODY}}`, `{{CODE_CONTEXT}}`

---

### `feedback.js`

#### API publique (window)

| Fonction | Description |
|----------|-------------|
| `window.openFeedbackPage(target)` | Ouvre `feedback.html` + snapshot logs |
| `window.runAutoDiagnostic()` | Lance les 4 tests et injecte dans le textarea |
| `window.submitFeedback()` | Envoie le rapport structuré |
| `window.connectNostr()` | Connexion NIP-07 + fetch profil kind 0 |
| `window.clearFeedbackLogs()` | Vide le ringbuffer console |

#### Clés sessionStorage / localStorage

| Clé | Stockage | Contenu |
|-----|----------|---------|
| `uplanet_correlation_id` | session | ID corrélation `fb-<ts36>-<rand6>` |
| `uplanet_feedback_logs` | session | Ringbuffer console (max 80, scrubbed) |
| `uplanet_feedback_page` | session | Snapshot URL page source |
| `uplanet_feedback_log_source` | session | Snapshot logs au moment du clic |
| `uplanet_nip42_diagnostic` | session | Résultat NIP-42 écrit par `roaming.html` |
| `uplanet_feedback_prefill` | local | Pré-remplissage titre/desc (TTL 30 s) |

#### Endpoint `/api/feedback`

```
POST {station}/api/feedback
Content-Type: application/x-www-form-urlencoded
X-Correlation-ID: fb-...

title=...&description=...&source=...&category=...&correlation_id=...&pubkey=...
```

Réponse attendue :
```json
{ "ok": true, "stored": "git|email|local", "issue_number": 42, "issue_url": "https://…" }
```

#### Blocs du rapport

| Bloc | Présence | Contenu |
|------|----------|---------|
| `[STATE]` | Toujours | correlation_id, timestamp, station, relay, has_nip07, user_agent |
| `[PROTOCOLE]` | Si NIP-42 testé | auth_ok, source, relay, auth_reason |
| `[LOGS]` | Si console capturée | Tous ERR/WARN + 10 derniers LOG, horodatés |

**Scrubbing appliqué :**
- Remplace `nsec1…` par `[nsec_redacted]`
- Masque les champs JSON `password`, `token`, `key`, `secret` par `[redacted]`
- Efface les en-têtes `Authorization: Basic …` des logs

### `cpscript`

```
cpscript <fichier> [OPTIONS]
```

| Option | Défaut | Description |
|--------|--------|-------------|
| `--depth N` | illimité | Profondeur de résolution des dépendances (0 = illimité) |
| `--maxtoken N` | 500 000 | Budget total en tokens |
| `--maxfilesize N` | aucun | Taille max par fichier en octets |
| `--only sh\|py\|html\|js\|css` | tous | Filtrer par type de dépendance |
| `--route <pattern>` | | Routes FastAPI contenant le pattern (Python uniquement) |
| `--exclude <fichier>` | | Exclure un basename (répétable) |
| `--well-known` | | Exclure les bibliothèques tierces connues des LLM (jQuery, Bootstrap, nacl, scrypt, nostr.bundle, marked, sphere-hacked, world.js…). Liste partagée avec `cpcode` dans `tools/well_known_libs.sh` |
| `--json` | | Sortie JSON structurée au lieu du texte |
| `--clean` | | Renomme `.sh` → `._sh` dans les commentaires du corpus |
| `--human` | | Mode interactif : valider chaque dépendance (Y/n/a/q) |
| `--doc` | | Inclure les `.md` de `docs/` qui référencent le script |

**Langages supportés pour la résolution de dépendances :**
- **Bash** : `source`, `bash ./x.sh`, `${MY_PATH}/x.sh`, chemins `.sh`/`.py` dans les strings
- **Python** : `from X import Y`, `import X`, `subprocess.run(["x.sh"])`, string literals
- **HTML** : `<link href="style.css">`, `<script src="app.js">` (URLs http ignorées)
- **JS** : `import … from './module.js'`, `require('./util.js')`

**Format de sortie JSON :**
```json
{
  "tool": "cpscript",
  "script": "/abs/path/to/file.sh",
  "stats": { "files_count": 7, "total_chars": 42000, "total_tokens": 10500 },
  "files": [{ "path": "...", "filename": "...", "extension": "sh", "content": "..." }]
}
```

---

### `cpcode`

```
cpcode <ext1 [ext2 ...]> <dossier> [OPTIONS]
```

| Option | Défaut | Description |
|--------|--------|-------------|
| `--maxfilesize N` | aucun | Taille max par fichier en octets |
| `--exclude <pattern>` | | Exclure les chemins contenant le pattern (répétable) |
| `--well-known` | | Exclure les bibliothèques tierces connues (jQuery, Bootstrap, Leaflet, nacl, scrypt, blake2b, axios, mermaid, helia, nostr.bundle…) |
| `--json` | | Sortie JSON structurée |

**Découverte :** `find <dossier> -type f -name "*.EXT"` pour chaque extension, filtre les binaires.

**Format de sortie JSON :**
```json
{
  "tool": "cpcode",
  "source_dir": "/abs/path/to/dir",
  "extensions": ["js", "css"],
  "stats": { "files_count": 12, "total_chars": 95000, "total_tokens": 24000 },
  "files": [{ "path": "...", "filename": "...", "extension": "js", "content": "..." }]
}
```

---

## Explication — Pourquoi le quintette et comment il s'articule

### `commit.sh` : le commit comme artefact de connaissance

L'historique Git d'un projet Bash/Python est souvent illisible : messages vagues ("fix"), aucun scope, aucune trace d'intention. `commit.sh` impose le format **Conventional Commits** pour une raison structurelle : le type (`feat`, `fix`, `refactor`, `docs`, `chore`) et le scope (dossier principal) permettent à `issue.sh` — ou à une IA — de retrouver les corrections passées par sujet.

Trois choix de conception :

**Le presse-papier comme interface de sortie.** Le résumé complet (tâches + fichiers clés) est copié même si le commit est annulé. Il sert alors de note de travail, de contenu de PR, ou d'entrée directe pour Claude.ai.

**La troncature head + tail du diff (pas head seule).** Pour les gros diffs (> 25 000 car.), `commit.sh` conserve le début *et* la fin plutôt que de couper en haut. La fin d'un diff contient souvent les dernières modifications — les plus récentes et les plus significatives pour le message.

**Le staging interactif trié par `mtime`.** La sélection de fichiers triés du plus récent au plus ancien correspond à la façon dont un développeur pense : "qu'est-ce que j'ai touché ce matin ?" plutôt que "quels fichiers sont dans ce dossier ?". La sélection `aujourd'hui` est un raccourci quotidien naturel.

---

### La boucle développement → terrain → correctif

Ces cinq outils ferment une boucle qui n'existait pas : un utilisateur en production sur `/e/OS Android` rencontre une erreur NIP-42. Il clique sur "Signaler". Le rapport arrive sur le repo Git avec les logs précis, le correlation ID et le résultat du test NIP-42 intégré. Le développeur lance `issue.sh analyze` : `cpscript` construit automatiquement le corpus code, l'IA reçoit à la fois le rapport de terrain **et** le code source exact. Le commit généré par `commit.sh` documente le correctif dans le registre de connaissances du projet.

Sans `feedback.js`, le développeur obtiendrait "ça marche pas" sans logs. Sans `cpscript`/`cpcode`, l'IA analyserait le bug sans voir le code. Sans `issue.sh`, il copierait-collerait manuellement. Sans `commit.sh`, l'historique Git ne contiendrait pas de trace structurée.

---

### Le Correlation ID comme fil conducteur

Le format `fb-<timestamp base36>-<6 chars aléatoires>` est généré une seule fois par session navigateur et persisté en `sessionStorage`. Il est propagé :

1. Dans l'en-tête HTTP `X-Correlation-ID` de chaque requête feedback
2. Dans les paramètres URL de l'issue Git créée
3. Dans les logs station (`nostr.auth.22242.log`) via les blocs `[STATE]`

Cela permet à `issue.sh` d'extraire automatiquement les lignes de log pertinentes quand il détecte l'ID dans la description de l'issue (`--logs`).

---

### `cpscript` vs `cpcode` : deux stratégies de contexte

L'IA ne peut pas lire un dépôt entier. Le défi est de lui fournir **exactement** les fichiers pertinents, ni trop ni trop peu. Les deux outils incarnent des stratégies opposées :

**`cpscript` — stratégie centripète (tirage par les imports)**
Part d'un point d'entrée connu et suit les dépendances vers l'intérieur. Idéal quand le bug a une signature claire (`22242.sh` rejette des events → on sait exactement quel fichier analyser). Risque : les dépendances indirectes peuvent exploser le budget ; `--depth 1` ou `--maxtoken` pour contrôler.

**`cpcode` — stratégie centrifuge (balayage de surface)**
Part d'un dossier et collecte par type. Idéal quand l'origine du bug est inconnue ou que l'on cherche des incohérences entre plusieurs fichiers du même type (ex. tous les filtres `filter/*.sh` du relay). Risque : inclut du code non pertinent ; `--well-known` et `--exclude` pour élaguer.

**`--well-known` — applicable aux deux outils**
Les pages HTML/JS d'UPlanet (`earth/`, `UPassport/static/`) embarquent des bibliothèques tierces volumineuses déjà connues des LLM (jQuery, Bootstrap, nacl, nostr.bundle…). `--well-known` les filtre avant d'envoyer le contexte — typiquement −40 à −60 % de tokens sur `index.html`. La liste commune est dans `tools/well_known_libs.sh` ; l'adapter si de nouvelles libs sont ajoutées au projet.

Dans `issue.sh`, les deux sont utilisés en séquence : `cpscript` en premier (dépendances précises), `cpcode` en fallback (si `cpscript` échoue ou retourne trop peu de fichiers).

---

### Pourquoi l'IA est guidée par un SYSPROMPT strict

Le SYSPROMPT de `issue.sh` contient des règles délibérément contraignantes :

- **Règle "FACTUEL"** : sans cette règle, les LLM hallucinent des chemins de fichiers plausibles mais faux dans un projet Bash/IPFS peu connu.
- **Règle "TRIGGER unknown"** : `SOURCE=unknown` est la signature exacte d'un cas roaming non géré. Sans cette règle, l'IA propose des correctifs génériques au lieu de pointer le `exit 1` dans `22242.sh`.
- **Règle "POINT DE RUPTURE"** : force l'IA à identifier la dernière étape `[✅ OK]` avant la première `[❌]`. C'est la méthode de bisection appliquée au diagnostic.
- **Règle "PENSÉE ADVERSAIRE"** : interdit la réponse "le code est correct". Toute étape `[❌]` **implique** une erreur, même subtile.

Ces règles compensent l'absence de contexte d'exécution live : l'IA ne peut pas lancer le code, elle raisonne uniquement sur les artefacts (logs, code, rapports).

---

### NIP-42 et le roaming : pourquoi c'est difficile à déboguer

L'authentification NIP-42 implique une synchronisation exacte entre trois composants :

```
roaming.html          22242.sh              UPassport 54321.py
─────────────         ─────────────         ──────────────────
Signe l'event   →     Crée marker     →     Vérifie marker
relay tag = URL       .nip42_auth_HEX       check_nip42_auth_local_marker()
```

Si le tag `relay` dans l'event signé diffère d'un seul caractère de l'URL de connexion (ex. slash final), strfry rejette l'event avant même que `22242.sh` soit appelé. Si `check_authorization` échoue dans `22242.sh`, le marker n'est pas créé. Si le marker n'existe pas, UPassport retourne 401. L'utilisateur voit "non authentifié" sans aucun message d'erreur visible.

`feedback.js` capture ce cas précisément : `sessionStorage.uplanet_nip42_diagnostic` contient `auth_ok: false` et `auth_reason` qui explique lequel des trois maillons a rompu. Le bloc `[PROTOCOLE]` dans le rapport le rend directement lisible par `issue.sh analyze`.

---

### Architecture de détection de la station et du relay

`feedback.js` utilise une stratégie de détection en cascade pour fonctionner sur toute page UPlanet sans configuration :

```
Station URL :
  1. window.NostrState.upassportUrl  ← injecté par common.js (le plus fiable)
  2. Substitution hostname : ipfs.domain → u.domain:54321
  3. Fallback : localhost:54321

Relay URL :
  1. window.NostrState.DEFAULT_RELAYS[0]  ← injecté par common.js
  2. Substitution hostname : u./ipfs. → relay., port wss://
  3. Fallback : wss://relay.{hostname}
```

Cette cascade garantit que le module fonctionne même injecté dans une page statique IPFS qui ne charge pas `common.js`.
