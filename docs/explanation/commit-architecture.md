# commit.sh — Architecture et intégration IA

## Vue d'ensemble

```
commit.sh
├── Sélection de branche (interactive ou --branch)
├── git pull --ff-only
│
├── MODE STAGED (-s) ──────────────────────────────────────────────
│   │
│   ├── interactive_stage()        [si rien n'est stagé]
│   │   ├── git diff --numstat     → stats +N/-M par fichier
│   │   ├── stat -c %Y             → mtime, tri décroissant
│   │   ├── [--ai] groupement IA   → question.py (ctx 2048, timeout 25s)
│   │   └── read sélection         → git add fichiers choisis
│   │
│   ├── git diff --cached          → DIFF_RAW
│   ├── Troncature head+tail        → DIFF_CONTENT (max 25k chars)
│   │
│   ├── generate_ai_summary()      → question.py (ctx 32768)
│   │   └── Format : # COMMIT / ## Tâches / ## Fichiers
│   │
│   ├── [--ai] ai_code_review()    → question.py (ctx 16384, timeout 35s)
│   │   ├── Affiche ✅ ou ⚠️ par fichier
│   │   └── [si ⚠️] intégration code_assistant
│   │       ├── Détecte code_assistant dans MY_PATH
│   │       ├── Parse les fichiers depuis les lignes ⚠️
│   │       ├── Lance : code_assistant <fichier> --kvbasename ca-<nom>-<date>
│   │       │           --supplement "REVUE DE COMMIT : <problème>"
│   │       └── exec "$0" --staged [--branch] [--ai] [--pr]
│   │
│   ├── Proposition commit [o/N/r]
│   │   └── r → git reset HEAD + exec "$0" --staged ...
│   │
│   ├── git commit -m "$COMMIT_MSG"
│   ├── git push
│   │
│   ├── [--pr] génération PR IA   → question.py (ctx 8192)
│   │   └── gh pr create
│   │
│   └── [fichiers restants] → exec "$0" --staged [--branch] [--ai] [--pr]
│
└── MODES TEMPORELS (-c/-d/-w/-m)
    └── git log / git diff → résumé IA → presse-papier
```

---

## Composants IA

### question.py

Backend LLM universel. Utilisé par commit.sh pour toutes les phases.

| Usage | Modèle | Contexte | Timeout |
|-------|--------|----------|---------|
| Groupement sémantique | `AI_MODEL` | 2048 | 25s |
| Message de commit | `AI_MODEL` | 32768 | — |
| Revue de code | `AI_MODEL` | 16384 | 35s |
| Corps Pull Request | `AI_MODEL` | 8192 | — |

`AI_MODEL` = `qwen2.5-coder:14b` par défaut, surchargeable avec `--model`.

### code_assistant

Outil de correction assistée en 3 phases, déclenché automatiquement par `ai_code_review()`.

| Phase | Rôle | Modèle auto |
|-------|------|-------------|
| analyse | Identifie 3 problèmes prioritaires | `deepseek-r1:14b` |
| correction | 3 variantes de correction | `qwen2.5-coder:14b` |
| contrôle | Vérifie + applique le patch | même modèle |

**Intégration** : commit.sh parse les `⚠️` du rapport de revue, extrait les noms de fichiers, et lance code_assistant avec le message d'erreur comme `--supplement`.

```bash
# Commande générée automatiquement :
code_assistant _12345.sh \
  --kvbasename ca-_12345-20260520 \
  --supplement "REVUE DE COMMIT : fichier tmp non nettoyé si erreur"
```

---

## Flux de données

```
git diff --cached
       │
       ▼ DIFF_RAW (troncature head+tail si > 25k chars)
       │
       ├──► generate_ai_summary()
       │         │ PROMPT: diff + stats + branch + commits
       │         ▼
       │    question.py → SUMMARY (# COMMIT format)
       │
       └──► ai_code_review()  [--ai seulement]
                 │ PROMPT: diff (14k max)
                 ▼
            question.py → _review (✅ ou ⚠️ fichier message)
                 │
                 ├── ✅ → rien
                 └── ⚠️ → parse fichiers → code_assistant → exec restart
```

---

## Persistance de session

| Donnée | Stockage | Durée |
|--------|----------|-------|
| Mémoire KV code_assistant | `~/.zen/flashmem/code_assistant/<kvbasename>.json` | permanente |
| Index Qdrant (refus, sessions) | `~/.zen/qdrant-data/` | permanente |
| Backups avant patch | `<fichier>.bak.<timestamp>` | permanente |
| Prompts temporaires | `/tmp/commit_prompt_*.txt` | durée session |

---

## Règles de sécurité

1. **Aucune action irréversible sans confirmation** : commit, push, PR, patch demandent tous `[o/N]`
2. **`r` disponible à la validation** : dé-stage et recommence sans perte
3. **Backup automatique avant tout patch** appliqué par code_assistant
4. **Sécurité anti-troncature** dans code_assistant : alerte si patch < 70% de l'original
5. **Validation syntaxique** avant application : `bash -n`, `python3 -m py_compile`, `jq .`

---

## Intégration dans le projet

```
Astroport.ONE/
├── commit.sh              # Ce script — workflow complet
├── code_assistant         # Correction assistée (déclenché par --ai)
├── cpscript               # Extraction contexte (utilisé par code_assistant)
└── IA/
    ├── question.py        # Backend LLM (Ollama)
    ├── code_assistant.py  # Phases LLM (analyse/correction/contrôle)
    └── ollama.me.sh       # Connectivité Ollama (local→SSH→P2P)
```
