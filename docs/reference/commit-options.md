# commit.sh — Référence des options

## Synopsis

```bash
commit.sh [OPTIONS]
```

## Options

| Option | Court | Description |
|--------|-------|-------------|
| `--staged` | `-s` | Staging interactif par date de modification + commit IA |
| `--commit` | `-c` | Diff depuis le dernier commit (défaut) |
| `--day` | `-d` | Analyse des 24 dernières heures |
| `--week` | `-w` | Analyse des 7 derniers jours |
| `--month` | `-m` | Analyse des 30 derniers jours |
| `--branch <nom>` | `-b` | Basculer sur cette branche avant d'analyser |
| `--pr` | `-p` | Proposer une Pull Request après push (titre + corps IA) |
| `--ai` | `-a` | Mode IA étendu : groupement sémantique + revue de code + intégration code_assistant |
| `--model <nom>` | `-M` | Modèle Ollama (défaut: `qwen2.5-coder:14b`) |
| `--verbose` | `-v` | Mode verbeux : diff, prompt et réponse brute dans stderr |
| `--help` | `-h` | Aide |

---

## Mode `--staged` / `-s`

Le mode central pour les gros commits.

### Flux

```
1. Sélection de branche (si plusieurs branches locales)
2. git pull --ff-only
3. Si rien n'est stagé → interactive_stage()
   └── Liste fichiers par mtime décroissant + stats lignes
   └── Suggestion sémantique IA (si --ai)
   └── Sélection utilisateur → git add
4. Collecte du diff stagé
5. Génération du message de commit (IA)
6. Revue de code (si --ai) → intégration code_assistant si problèmes
7. Proposition commit [o/N/r]
   └── r = dé-stage + recommence depuis étape 3
8. git commit + git push
9. Pull Request (si --pr et branche non-principale)
10. Si fichiers restants → retour étape 3
```

### Sélection interactive

Syntaxes acceptées :
- `1` — fichier unique
- `1,3,7` — sélection par virgules (espaces tolérés : `1, 3, 7`)
- `1-5` — plage continue
- `tout` / `all` — tous les fichiers
- `aujourd'hui` / `today` — fichiers modifiés ce jour

---

## Mode `--ai` / `-a`

Active trois couches d'intelligence supplémentaires :

### 1. Groupement sémantique (avant la sélection)

L'IA analyse les noms et stats des fichiers et propose des groupes logiques pour des commits séparés. Exemple :

```
── Groupes suggérés ─────────────────────────────────────────
Groupe A [1,2]: feat(tools): publication NOSTR dynamique
Groupe B [3,4]: chore(install): intégration RTK
Groupe C [5]: docs(reference): mise à jour contrat
```

### 2. Revue de code (avant la validation du commit)

Après génération du message IA, le diff stagé est relu par un reviewer IA :

```
🔍 Revue de code IA (--ai)...
── Revue de code ────────────────────────────────────────
✅ Aucun problème détecté.
```

ou :

```
⚠️ install.sh RTK clone échoué : erreur non gérée
⚠️ commit.sh timeout 35s : peut être trop court pour grands diffs
```

### 3. Intégration code_assistant (si problèmes détectés)

Si des `⚠️` sont signalés, le script propose de lancer `code_assistant` :

```
🔧 Des problèmes ont été détectés par la revue.
   Corriger avec code_assistant (analyse → correction → patch) ? [o/N] :
```

Si `o` :
1. Les fichiers problématiques sont identifiés automatiquement
2. `code_assistant` démarre en mode **analyse** avec les problèmes comme contexte
3. L'utilisateur suit le cycle 3 phases : analyse → correction → contrôle+patch
4. Le script redémarre ensuite le cycle de commit avec les fichiers corrigés

---

## Mode `--pr` / `-p`

Après un push réussi sur une branche non-principale, propose de créer une Pull Request.

L'IA génère :
- **Titre** : court et précis (max 72 caractères)
- **Corps** : résumé, changements principaux, tests effectués

Nécessite `gh` (GitHub CLI) installé et authentifié :
```bash
gh auth login
```

Combinaison recommandée pour une feature complète :
```bash
commit.sh --staged --ai --pr
```

---

## Variables d'environnement

| Variable | Défaut | Description |
|----------|--------|-------------|
| `OLLAMA_HOST` | `http://localhost:11434` | Serveur Ollama |

---

## Exemples

```bash
# Commit simple sur master
commit.sh -s

# Gros chantier avec assistance IA complète
commit.sh -s --ai

# Feature branch → PR
commit.sh -s --ai --pr --branch feat/my-feature

# Analyse de la semaine pour le standup
commit.sh --week

# Forcer un modèle plus léger
commit.sh -s --model qwen2.5-coder:7b
```
