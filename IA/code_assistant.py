#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Astroport.ONE convention: run with ~/.astro/bin/python3 (ou python3 env)
"""
code_assistant.py — Backend IA pour l'analyse et correction de code

Usage depuis code_assistant bash (stdin = JSON cpscript) :
  code_assistant.py --phase analyse|correction|controle
                    --kvbasename <nom_session>
                    [--model <ollama_model>]
                    [--choice <N|a|b|c>]
                    [--patch]
                    [--script <fichier_source>]

Phases :
  analyse    → Identifie 3 problèmes prioritaires, propositions numérotées
  correction → Pour le problème choisi, génère 3 variantes de correction (a/b/c)
  controle   → Vérifie la variante choisie, rapport de risques

Dépendances :
  - ollama.me.sh  : assure qu'Ollama est disponible en local (port 11434)
  - embed.py      : génère les embeddings via nomic-embed-text + gère Qdrant
"""
import argparse
import hashlib
import json
import os
import sys
import time
import re
from pathlib import Path

# ── Import embed.py (même répertoire) ──────────────────────────────────────
_IA_DIR = Path(__file__).parent
sys.path.insert(0, str(_IA_DIR))

try:
    from embed import (
        get_embedding,
        qdrant_available,
        qdrant_index as _qdrant_index_raw,
        qdrant_search as _qdrant_search_raw,
        qdrant_ensure_collection,
        EMBED_MODEL,
        QDRANT_URL
    )
    EMBED_OK = True
except ImportError as e:
    print(f"  [code_assistant] embed.py non trouvé dans {_IA_DIR}: {e}",
          file=sys.stderr)
    EMBED_OK = False
    EMBED_MODEL  = "nomic-embed-text"
    QDRANT_URL   = "http://localhost:6333"
    def get_embedding(text, model=None): return []
    def qdrant_available(): return False
    def qdrant_ensure_collection(*a, **kw): return False
    def _qdrant_index_raw(*a, **kw): return False
    def _qdrant_search_raw(*a, **kw): return []

try:
    import ollama
    OLLAMA_OK = True
except ImportError:
    print("Erreur : pip install ollama", file=sys.stderr)
    sys.exit(1)

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────
KV_DIR        = Path.home() / ".zen" / "tmp" / "flashmem" / "code_assistant"
LOG_FILE      = Path.home() / ".zen" / "tmp" / "IA.log"
QDRANT_COL    = "code_assistant"
DEFAULT_MODEL = "gemma3:latest"

# R1: Modèles optimisés par phase pour RTX3090 (24 Go VRAM)
# deepseek-r1:14b → raisonnement/think profond pour l'analyse
# qwen2.5-coder:14b → précision syntaxique pour la correction
PHASE_MODELS = {
    "analyse":    "deepseek-r1:14b",    # Meilleur pour raisonner sur du code
    "correction": "qwen2.5-coder:14b", # Meilleur pour écrire du code correct
    "controle":   "qwen2.5-coder:14b", # Précision syntaxique pour la vérif
}

# R3: Ratio tokens pour du code (1 token ≈ 3.2 chars, meilleur que /4)
CHARS_PER_TOKEN = 3.2

PHASE_SEQUENCE = ["analyse", "correction", "controle"]

# ─────────────────────────────────────────────────────────────────────────────
# Prompts système par phase
# ─────────────────────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
# System prompts dynamiques : fonctions qui injectent le contexte --test/--doc
# ─────────────────────────────────────────────────────────────────────────────
def _build_analyse_prompt(test_ctx: str = "", doc_ctx: str = "") -> str:
    """Construit le system prompt d'analyse enrichi selon le contexte actif."""
    base = """Tu es un expert en analyse de code. Tu reçois le contenu d'un ou plusieurs scripts."""
    if test_ctx:
        base += """
Tu es en MODE TEST ACTIF. Des résultats de tests et une carte de couverture sont fournis.
Concentre-toi en priorité sur les erreurs de tests réelles avant d'identifier d'autres problèmes.
Ne propose pas de corrections qui cassent les tests existants."""
    if doc_ctx:
        base += """
Tu es en MODE DOC ACTIF. Des incohérences entre code et documentation sont fournies.
Inclue dans ton analyse les problèmes de conformité code ↔ documentation (signatures incorrectes,
exemples obsolètes, fonctions non documentées)."""
    base += """
Si des fichiers .md de documentation sont présents (role: "documentation"), inclue aussi l'analyse
de la conformité code ↔ documentation (fonctions manquantes dans la doc, doc obsolète, etc.).

Identifie les 3 problèmes les plus importants (bugs, sécurité, performance, maintenabilité, ou doc drift).

Réponds UNIQUEMENT dans ce format exact :"""
    return base


def _build_controle_prompt(test_mode: bool = False) -> str:
    """Construit le system prompt de contrôle avec contrainte non-régression si --test."""
    base = """Tu es un expert en revue de code et en test. Tu reçois la correction choisie.
Vérifie qu'elle est correcte, complète et ne casse rien.

Réponds UNIQUEMENT dans ce format exact :
=== CONTRÔLE ===
Verdict: OK | ATTENTION | REFUSER

✓ Points validés:
- [point 1]
- [point 2]

⚠ Risques identifiés:
- [risque 1] (ou "Aucun" si pas de risque)

🧪 Tests recommandés:
- [test 1]
- [test 2]"""
    if test_mode:
        base += """

🔒 Test de non-régression (OBLIGATOIRE — MODE TEST ACTIF) :
Fournis impérativement un bloc de code de test (pytest/unittest/shunit2) qui :
1. Aurait échoué AVANT la correction
2. Passe AVEC la correction
Format : bloc ```python ou ```bash directement dans ta réponse."""
    base += """

📝 Remarques:
[commentaire final optionnel]
=== FIN CONTRÔLE ==="""
    return base


SYSTEM_PROMPTS = {
    "analyse": """Tu es un expert en analyse de code. Tu reçois le contenu d'un ou plusieurs scripts.
Si des fichiers .md de documentation sont présents (role: "documentation"), inclue aussi l'analyse
de la conformité code ↔ documentation (fonctions manquantes dans la doc, doc obsolète, etc.).

Identifie les 3 problèmes les plus importants (bugs, sécurité, performance, maintenabilité, ou doc drift).

Réponds UNIQUEMENT dans ce format exact :
=== ANALYSE ===
1. [CATÉGORIE] Description courte du problème
   Localisation: fichier.py:ligne_approximative
   Impact: CRITIQUE | MAJEUR | MINEUR

2. [CATÉGORIE] Description courte du problème
   Localisation: fichier.py:ligne_approximative
   Impact: CRITIQUE | MAJEUR | MINEUR

3. [CATÉGORIE] Description courte du problème
   Localisation: fichier.py:ligne_approximative
   Impact: CRITIQUE | MAJEUR | MINEUR
=== FIN ANALYSE ===

Sois précis et concis. Maximum 2 lignes de description par problème.""",

    "correction": """Tu es un expert en correction de code.
Génère exactement 3 corrections de complexité croissante au format JSON STRICT.

IMPORTANT: Réponds UNIQUEMENT avec du JSON valide, sans texte avant ou après.
Le contenu des fichiers DOIT être une chaîne JSON correctement échappée.

Format attendu:
{
  "problem": "description courte du problème corrigé",
  "options": {
    "a": {
      "description": "Correction minimale (patch chirurgical)",
      "files": [
        {"path": "nom_fichier.py", "content": "contenu complet corrigé"}
      ]
    },
    "b": {
      "description": "Correction complète (robuste)",
      "files": [
        {"path": "nom_fichier.py", "content": "contenu complet corrigé"}
      ]
    },
    "c": {
      "description": "Refactoring (meilleure architecture)",
      "files": [
        {"path": "nom_fichier.py", "content": "contenu complet corrigé"}
      ]
    }
  }
}""",

    "controle": """Tu es un expert en revue de code et en test. Tu reçois la correction choisie.
Vérifie qu'elle est correcte, complète et ne casse rien.

Réponds UNIQUEMENT dans ce format exact :
=== CONTRÔLE ===
Verdict: OK | ATTENTION | REFUSER

✓ Points validés:
- [point 1]
- [point 2]

⚠ Risques identifiés:
- [risque 1] (ou "Aucun" si pas de risque)

🧪 Tests recommandés:
- [test 1]
- [test 2]

📝 Remarques:
[commentaire final optionnel]
=== FIN CONTRÔLE ==="""
}

# ─────────────────────────────────────────────────────────────────────────────
# Mémoire KV
# ─────────────────────────────────────────────────────────────────────────────
def kv_path(kvbasename: str) -> Path:
    KV_DIR.mkdir(parents=True, exist_ok=True)
    return KV_DIR / f"{kvbasename}.json"


def _get_git_hash(path: str = ".") -> str:
    """A4: Retourne le hash court du commit Git courant (ou '' si hors dépôt)."""
    import subprocess
    try:
        result = subprocess.run(
            ["git", "-C", path, "rev-parse", "--short", "HEAD"],
            capture_output=True, text=True, timeout=2
        )
        return result.stdout.strip() if result.returncode == 0 else ""
    except Exception:
        return ""


def load_kv(kvbasename: str) -> dict:
    p = kv_path(kvbasename)
    if p.is_file():
        try:
            with open(p) as f:
                data = json.load(f)
                # A4: Détecter changement de branche Git
                current_hash = _get_git_hash()
                saved_hash   = data.get("git_hash", "")
                if current_hash and saved_hash and current_hash != saved_hash:
                    print(f"  ⚠️  [KV] Git hash changé : {saved_hash} → {current_hash}",
                          file=sys.stderr)
                    print("     La session KV peut être incohérente avec le code actuel.",
                          file=sys.stderr)
                return data
        except Exception:
            pass
    return {
        "kvbasename":     kvbasename,
        "script":         "",
        "phase":          "analyse",
        "history":        [],
        "last_proposals": {},
        "last_choice":    None,
        "accepted_patches": [],
        "git_hash":       _get_git_hash(),  # A4: hash Git au démarrage
        "created_at":     time.time()
    }


def save_kv(kvbasename: str, data: dict):
    data["updated_at"] = time.time()
    with open(kv_path(kvbasename), "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


# ─────────────────────────────────────────────────────────────────────────────
# Qdrant — embed + index + search
# ─────────────────────────────────────────────────────────────────────────────
def qdrant_index(kvbasename: str, script: str, summary: str):
    """Indexe le résumé de la session dans Qdrant via embed.py."""
    text = f"{script}\n{summary}"
    point_id = int(hashlib.sha256(f"{kvbasename}_{script}".encode()).hexdigest(), 16) % (2**31)
    payload = {
        "kvbasename": kvbasename,
        "script":     script,
        "summary":    summary[:500],
        "timestamp":  time.time()
    }
    ok = _qdrant_index_raw(QDRANT_COL, point_id, text, payload)
    if ok:
        print(f"  [Qdrant] Session indexée (id={point_id})", file=sys.stderr)


def qdrant_search(query: str, top: int = 3, language: str = None) -> list:
    """Recherche des sessions similaires dans Qdrant via embed.py.
    
    N2: filtre par langue si spécifié (ex: 'py', 'sh') pour éviter
    de mélanger les sessions Python et Shell.
    """
    results = _qdrant_search_raw(
        QDRANT_COL, query, top=top, score_threshold=0.65,
        filter_language=language
    )
    return [r.get("payload", {}) for r in results]


# ─────────────────────────────────────────────────────────────────────────────
# Utilitaires
# ─────────────────────────────────────────────────────────────────────────────
def filter_think_tags(text: str) -> str:
    while "<think>" in text and "</think>" in text:
        start = text.find("<think>")
        end   = text.find("</think>") + len("</think>")
        text  = text[:start] + text[end:]
    return text.strip()


def log(text: str):
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(LOG_FILE, "a") as f:
        f.write(f"\n[code_assistant] {text}\n")


def extract_json_from_text(text: str) -> str:
    """N1: Extrait le JSON d'une réponse LLM qui peut contenir du texte parasite.

    Les LLM ajoutent souvent du texte avant/après le JSON :
    "Voici le fichier corrigé :\n```json\n{...}\n```"
    
    Stratégie : chercher la première '{' et la dernière '}', extraire le bloc.
    """
    # Supprimer les balises markdown ```json ... ``` ou ``` ... ```
    text = re.sub(r'```(?:json)?\s*', '', text)
    text = re.sub(r'```\s*$', '', text, flags=re.MULTILINE)

    # Trouver la première '{' et la dernière '}'
    start = text.find('{')
    end   = text.rfind('}')
    if start == -1 or end == -1 or end <= start:
        return text  # pas de JSON trouvé, retourner le texte brut

    return text[start:end + 1]


def extract_patches(text: str) -> dict:
    """Extrait les patches de la réponse LLM (JSON ou legacy markers).

    Format JSON (P2) :
      {"options": {"a": {"files": [{"path": "f.py", "content": "..."}]}}}

    Format legacy :
      === PATCH: f.py ===\n...\n=== END PATCH ===
    """
    # N1: Nettoyer le texte LLM avant de parser le JSON
    clean_text = extract_json_from_text(text)

    # Tentative JSON d'abord (fiable, aucune regex fragile)
    try:
        data = json.loads(clean_text)
        patches = {}
        options = data.get("options", {})
        for letter, opt in options.items():
            for f in opt.get("files", []):
                patches[f["path"]] = f["content"]
        if patches:
            return patches
    except (json.JSONDecodeError, KeyError, TypeError):
        pass

    # Fallback : legacy markers
    patches = {}
    for m in re.finditer(
        r'=== PATCH: ([^\n]+) ===\n(.*?)\n=== END PATCH ===', text, re.DOTALL
    ):
        patches[m.group(1).strip()] = m.group(2).strip()
    return patches


def extract_option_json(text: str, option_letter: str) -> dict:
    """Extrait une option (a/b/c) depuis la réponse JSON (P2)."""
    try:
        data  = json.loads(text)
        opt   = data.get("options", {}).get(option_letter, {})
        files = opt.get("files", [])
        return {
            "description": opt.get("description", ""),
            "files":       files,
            "patches":     {f["path"]: f["content"] for f in files}
        }
    except (json.JSONDecodeError, KeyError, TypeError):
        return {}


def extract_option(text: str, option_letter: str) -> str:
    """Extrait une option (a/b/c) — supporte JSON (P2) et legacy markers."""
    # JSON d'abord
    opt = extract_option_json(text, option_letter)
    if opt:
        files_str = "\n".join(
            f"=== PATCH: {f['path']} ===\n{f['content']}\n=== END PATCH ==="
            for f in opt.get("files", [])
        )
        return f"Explication: {opt.get('description','')}\n{files_str}"

    # Fallback legacy
    m = re.search(
        rf'--- OPTION {option_letter}:.*?---\n(.*?)(?=--- OPTION [a-z]:|\=== FIN)',
        text, re.DOTALL | re.IGNORECASE
    )
    return m.group(1).strip() if m else ""


def build_code_summary(code_json: dict, max_tokens: int = 32000) -> str:
    """Construit un résumé texte du contexte code pour le prompt LLM.

    R2: Si le contexte total dépasse max_tokens (estimé), tronque
    les fichiers dépendants à 50 lignes pour éviter de saturer le cache KV.
    Inclut les métadonnées de diagnostic --test et --doc si présentes.
    """
    # Estimation du volume total (R3: ratio 3.2 chars/token pour du code)
    total_chars = sum(len(f.get('content', '')) for f in code_json.get('files', []))
    trim_threshold_chars = int(max_tokens * CHARS_PER_TOKEN)
    trim_deps = total_chars > trim_threshold_chars

    if trim_deps:
        estimated_tokens = int(total_chars / CHARS_PER_TOKEN)
        print(f"  [context] {estimated_tokens:,} tokens estimés > {max_tokens:,} — "
              f"troncation des dépendances à 50 lignes", file=sys.stderr)

    parts = []
    parts.append(f"Script principal: {code_json.get('script', 'inconnu')}")
    parts.append(f"Fichiers: {code_json.get('stats', {}).get('files_count', '?')}")

    for i, f in enumerate(code_json.get("files", [])[:20]):  # max 20 fichiers
        content = f.get('content', '')
        is_test_file = f.get('_test_file', False)
        # R2: Tronquer les dépendances (pas le script principal ni les tests) si contexte trop grand
        if trim_deps and i > 0 and not is_test_file:
            lines = content.split('\n')
            if len(lines) > 50:
                content = '\n'.join(lines[:50])
                content += f'\n# ... [{len(lines) - 50} lignes tronquées — contexte >{max_tokens//1000}k tokens]'
        label = "[TEST] " if is_test_file else ""
        parts.append(f"\n### {label}{f.get('path', '')} ###\n{content[:3000]}")

    # ── Métadonnées de diagnostic --test ──────────────────────────────────────
    test_results = code_json.get('_test_results', '').strip()
    coverage_gaps = code_json.get('_coverage_gaps', '').strip()
    if test_results:
        parts.append(f"\n### RÉSULTATS DES TESTS (dry run) ###\n{test_results[:2000]}")
    if coverage_gaps:
        parts.append(f"\n### COUVERTURE — fonctions non testées ###\n{coverage_gaps}")

    # ── Métadonnées de diagnostic --doc ──────────────────────────────────────
    doc_issues = code_json.get('_doc_issues', '').strip()
    if doc_issues:
        parts.append(f"\n### INCOHÉRENCES DOC vs CODE ###\n{doc_issues[:1500]}")

    return "\n".join(parts)


# ─────────────────────────────────────────────────────────────────────────────
# LLM
# ─────────────────────────────────────────────────────────────────────────────
# Variable globale pour le mode human-llm (mis à jour depuis main())
_HUMAN_LLM_MODE = False

def call_llm(system: str, user_prompt: str, model: str,
             json_format: bool = False) -> str:
    """Appelle Ollama avec le système et le prompt utilisateur.

    H2: Si _HUMAN_LLM_MODE, affiche les prompts et permet modification avant envoi.
    """
    global _HUMAN_LLM_MODE

    # Copie locale modifiable
    actual_system = system
    actual_prompt = user_prompt

    if _HUMAN_LLM_MODE:
        sep = "─" * 66
        print(f"\n{sep}", file=sys.stderr)
        print(f"📝 PROMPT SYSTÈME (extrait) :", file=sys.stderr)
        print(f"   {system[:300].replace(chr(10), ' ')[:200]}...", file=sys.stderr)
        print(f"\n📝 PROMPT UTILISATEUR (extrait) :", file=sys.stderr)
        # Afficher le début et la fin (100 chars chacun)
        if len(user_prompt) > 400:
            print(f"   {user_prompt[:200]}...\n   ...\n   {user_prompt[-150:]}",
                  file=sys.stderr)
        else:
            print(f"   {user_prompt}", file=sys.stderr)
        print(f"\n{sep}", file=sys.stderr)
        print("  [Enter]=envoyer  [m]=modifier prompt  [s]=voir prompt système  [q]=abandonner",
              file=sys.stderr)

        while True:
            print("  > ", end="", flush=True, file=sys.stderr)
            try:
                choice = input()
            except EOFError:
                choice = ""
            choice = choice.strip().lower()

            if choice == "q":
                print("  ⛔ Abandonné.", file=sys.stderr)
                sys.exit(0)
            elif choice == "s":
                print(f"\n📋 PROMPT SYSTÈME COMPLET :\n{system}\n{sep}", file=sys.stderr)
            elif choice == "m":
                print("  Saisissez vos modifications (texte ajouté à la fin du prompt) :",
                      file=sys.stderr)
                print("  (terminez par une ligne vide) :", file=sys.stderr)
                lines = []
                while True:
                    try:
                        line = input()
                    except EOFError:
                        break
                    if line == "":
                        break
                    lines.append(line)
                if lines:
                    addition = "\n".join(lines)
                    actual_prompt += f"\n\n## Instruction supplémentaire :\n{addition}"
                    print(f"  ✓ Contexte ajouté : {addition[:80]}...", file=sys.stderr)
                break
            else:
                # Enter ou tout autre chose = envoyer
                break

    kwargs = {
        "model": model,
        "messages": [
            {"role": "system", "content": actual_system},
            {"role": "user",   "content": actual_prompt}
        ]
    }
    if json_format:
        kwargs["format"] = "json"
    try:
        resp = ollama.chat(**kwargs)
        return filter_think_tags(resp["message"]["content"])
    except Exception as e:
        return f"Erreur LLM: {e}"


# ─────────────────────────────────────────────────────────────────────────────
# Phases
# ─────────────────────────────────────────────────────────────────────────────
def phase_analyse(kv: dict, code_summary: str, model: str,
                  semantic_ctx: list, supplement: str = "",
                  test_ctx: str = "", doc_ctx: str = "") -> str:
    """Phase 1 : Analyse le code et retourne 3 problèmes.

    test_ctx : résumé des résultats de tests (dry run) si --test
    doc_ctx  : résumé des incohérences doc si --doc
    """
    ctx_block = ""
    if semantic_ctx:
        ctx_block = "\n\n## Contexte sémantique (sessions similaires) :\n"
        for s in semantic_ctx:
            ctx_block += f"- {s.get('script','?')}: {s.get('summary','')}\n"

    # Sélectionner le system prompt adapté selon le mode actif
    system = _build_analyse_prompt(test_ctx=test_ctx, doc_ctx=doc_ctx)

    prompt = f"{ctx_block}\n\n## Code à analyser :\n\n{code_summary}"
    # Supplément humain (contexte/contrainte injectée)
    if supplement:
        prompt += f"\n\n## Focus demandé par l'utilisateur :\n{supplement}"
    return call_llm(system, prompt, model)


# A3: Prompt pour unified diff (économise les tokens, format standard)
UNIFIED_DIFF_PROMPT = """Tu es un expert en correction de code.
Génère exactement 3 corrections de complexité croissante au format unified diff STRICT.

Format attendu pour chaque option :
=== OPTION a: Description courte ===
--- a/nom_fichier.py
+++ b/nom_fichier.py
@@ -ligne,nb +ligne,nb @@
-code_original
+code_corrigé

=== OPTION b: Description courte ===
[même format]

=== OPTION c: Description courte ===
[même format]

IMPORTANT : N'inclure QUE les lignes modifiées avec contexte (3 lignes avant/après).
N'écrire PAS de prose autour. Format diff pur."""


def phase_correction(kv: dict, code_summary: str, model: str,
                     problem_choice: str, diff_format: str = "json",
                     supplement: str = "") -> str:
    """Phase 2 : Propose 3 corrections pour le problème choisi."""
    proposals = kv.get("last_proposals", {})
    problem_desc = proposals.get(str(problem_choice), f"Problème {problem_choice}")

    prompt = (
        f"## Problème identifié (choix {problem_choice}) :\n{problem_desc}\n\n"
        f"## Code source :\n\n{code_summary}"
    )
    if supplement:
        prompt += f"\n\n## Contrainte/Focus de l'utilisateur :\n{supplement}"

    if diff_format == "unified":
        # A3: format unified diff (pas de json_format=True ici, plain text)
        return call_llm(UNIFIED_DIFF_PROMPT, prompt, model, json_format=False)
    else:
        # Format JSON (défaut, plus robuste)
        return call_llm(SYSTEM_PROMPTS["correction"], prompt, model, json_format=True)


def phase_controle(kv: dict, code_summary: str, model: str,
                   variant_choice: str, supplement: str = "",
                   test_mode: bool = False) -> str:
    """Phase 3 : Contrôle la variante choisie.

    test_mode : si True, exige un test de non-régression dans la réponse.
    """
    last_correction = kv.get("last_correction_text", "")
    option_text = extract_option(last_correction, variant_choice)
    patches = extract_patches(option_text or last_correction)

    prompt = (
        f"## Variante choisie ({variant_choice}) :\n{option_text}\n\n"
        f"## Patches générés :\n{json.dumps(patches, indent=2, ensure_ascii=False)}\n\n"
        f"## Code original pour référence :\n\n{code_summary[:2000]}"
    )
    if supplement:
        prompt += f"\n\n## Contrainte utilisateur :\n{supplement}"
    system = _build_controle_prompt(test_mode=test_mode)
    return call_llm(system, prompt, model)


# ─────────────────────────────────────────────────────────────────────────────
# Parsing des propositions depuis la réponse LLM
# ─────────────────────────────────────────────────────────────────────────────
def parse_proposals(phase: str, text: str) -> dict:
    """Extrait les propositions numérotées ou lettrées du texte LLM."""
    proposals = {}
    if phase == "analyse":
        # Cherche "1. ...", "2. ...", "3. ..."
        for m in re.finditer(r'^(\d)\.\s+(.+?)(?=^\d\.|\Z)', text, re.MULTILINE | re.DOTALL):
            proposals[m.group(1)] = m.group(2).strip()
    elif phase == "correction":
        # Cherche "--- OPTION a ---", etc.
        for letter in ["a", "b", "c"]:
            opt = extract_option(text, letter)
            if opt:
                proposals[letter] = opt
    elif phase == "controle":
        proposals["verdict"] = re.search(r'Verdict:\s*(\w+)', text, re.IGNORECASE)
        proposals["verdict"] = proposals["verdict"].group(1) if proposals["verdict"] else "?"
    return proposals


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="Assistant IA pour analyse et correction de code")
    parser.add_argument("--phase",      default="analyse",
                        choices=["analyse", "correction", "controle"],
                        help="Phase à exécuter")
    parser.add_argument("--kvbasename", default="default",
                        help="Nom de session KV pour la persistance")
    parser.add_argument("--model",      default=None,
                        help=f"Modèle Ollama (défaut: automatique par phase — "
                             f"analyse={PHASE_MODELS['analyse']}, "
                             f"correction={PHASE_MODELS['correction']})")
    parser.add_argument("--choice",     default=None,
                        help="Choix automatique (1/2/3 pour analyse, a/b/c pour correction)")
    parser.add_argument("--patch",      action="store_true",
                        help="Extraire et retourner le patch pour application")
    parser.add_argument("--script",     default=None,
                        help="Chemin du fichier source principal (pour le log)")
    parser.add_argument("--no-qdrant",  action="store_true",
                        help="Désactiver Qdrant")
    parser.add_argument("--max-context", type=int, default=32000,
                        help="Limite de tokens du contexte code (passée depuis code_assistant bash, "
                             "reflète 80%% du contexte max du modèle sélectionné)")
    # H2: mode step-by-step complet (voir/modifier chaque prompt avant envoi)
    parser.add_argument("--human-llm",  action="store_true",
                        help="Voir et modifier chaque prompt LLM avant envoi "
                             "(Enter=envoyer / m=modifier / q=abandonner)")
    # Contexte humain injecté dans le prompt LLM
    parser.add_argument("--supplement", default="",
                        help="Contexte/précision humaine ajoutée au prompt LLM "
                             "(ex: 'Focus sur le timeout IPFS ligne 131')")
    # A2: commande --setup pour télécharger les modèles recommandés
    parser.add_argument("--setup",      action="store_true",
                        help="A2: Télécharger automatiquement les modèles recommandés via ollama pull")
    # A3: format des patches (json=fichier complet, unified=diff standard)
    parser.add_argument("--diff-format", default="json",
                        choices=["json", "unified"],
                        help="A3: Format des patches LLM (json=complet, unified=diff -u)")
    # Flags contexte actif (propagés depuis le script bash)
    parser.add_argument("--test-mode",  action="store_true",
                        help="Activer le mode test actif (dry run résultats injectés dans CODE_JSON)")
    parser.add_argument("--doc-mode",   action="store_true",
                        help="Activer le mode doc actif (incohérences doc injectées dans CODE_JSON)")
    args = parser.parse_args()

    # H2: Activer le mode review prompt LLM si --human-llm
    global _HUMAN_LLM_MODE
    _HUMAN_LLM_MODE = getattr(args, "human_llm", False)

    # ── A2: Mode setup — télécharger les modèles recommandés ────────────────
    if args.setup:
        models_to_pull = list(set(PHASE_MODELS.values()))
        print("🔧 Téléchargement des modèles recommandés pour code_assistant...")
        for model in models_to_pull:
            print(f"  → ollama pull {model} ...")
            try:
                ollama.pull(model)
                print(f"  ✅ {model} prêt")
            except Exception as e:
                print(f"  ❌ {model} : {e}")
        print(f"\n  nomic-embed-text (embedding)...")
        try:
            ollama.pull(EMBED_MODEL)
            print(f"  ✅ {EMBED_MODEL} prêt")
        except Exception as e:
            print(f"  ❌ {EMBED_MODEL} : {e}")
        print("\n✅ Setup terminé. Relancez code_assistant sans --setup pour analyser du code.")
        sys.exit(0)

    # ── Lire le JSON cpscript depuis stdin (A1: économie RAM) ───────────────
    # On utilise json.load() pour éviter de dupliquer le buffer en mémoire.
    # Si la taille dépasse MAX_STDIN_MB, on limite la lecture.
    MAX_STDIN_MB = int(os.environ.get("CA_MAX_STDIN_MB", "500"))
    try:
        # Lecture limitée pour les très gros projets
        import io
        raw_bytes = sys.stdin.buffer.read(MAX_STDIN_MB * 1024 * 1024)
        code_json = json.loads(raw_bytes.decode("utf-8", errors="replace"))
    except (json.JSONDecodeError, UnicodeDecodeError):
        raw = raw_bytes.decode("utf-8", errors="replace").strip()
        # Fallback : traiter comme texte brut
        code_json = {"script": args.script or "unknown", "files": [
            {"path": args.script or "code", "content": raw[:50000], "extension": ""}
        ], "stats": {}}
    finally:
        del raw_bytes  # Libérer la mémoire immédiatement

    script_name = args.script or code_json.get("script", "unknown")

    # ── Charger la mémoire KV ───────────────────────────────────────────────
    kv = load_kv(args.kvbasename)
    kv["script"]   = script_name
    kv["phase"]    = args.phase
    kv["git_hash"] = _get_git_hash()  # A4: mettre à jour le hash à chaque run

    # ── Extraire les métadonnées de diagnostic --test/--doc depuis CODE_JSON ──
    _test_results  = code_json.get("_test_results",  "").strip()
    _coverage_gaps = code_json.get("_coverage_gaps", "").strip()
    _doc_issues    = code_json.get("_doc_issues",    "").strip()
    _active_test   = getattr(args, "test_mode", False) or bool(_test_results or _coverage_gaps)
    _active_doc    = getattr(args, "doc_mode",  False) or bool(_doc_issues)

    if _active_test:
        print(f"  [mode] TEST ACTIF — résultats: {len(_test_results)} chars, "
              f"gaps: {len(_coverage_gaps)} chars", file=sys.stderr)
    if _active_doc:
        print(f"  [mode] DOC ACTIF — incohérences: {len(_doc_issues)} chars", file=sys.stderr)

    # ── Construire le résumé du code ─────────────────────────────────────────
    code_summary = build_code_summary(code_json, max_tokens=args.max_context)

    # ── Qdrant : indexation AVANT analyse + recherche sémantique ────────────
    use_qdrant = not args.no_qdrant and qdrant_available()
    semantic_ctx = []

    if use_qdrant:
        # N2: filtrer par langue pour éviter de mélanger sessions Python et Shell
        script_lang = script_name.rsplit(".", 1)[-1] if "." in script_name else None
        print(f"  [Qdrant] disponible — recherche sémantique (lang={script_lang})...",
              file=sys.stderr)
        semantic_ctx = qdrant_search(
            f"{script_name}\n{code_summary[:500]}", top=3, language=script_lang
        )
        if semantic_ctx:
            print(f"  [Qdrant] {len(semantic_ctx)} session(s) similaire(s) trouvée(s)",
                  file=sys.stderr)

        # Indexation du code courant (même avant analyse)
        qdrant_index(
            args.kvbasename, script_name,
            f"Phase {args.phase}: {code_summary[:200]}"
        )

    # R1: Sélection automatique du modèle par phase si non spécifié
    effective_model = args.model or PHASE_MODELS.get(args.phase, DEFAULT_MODEL)
    # Vérifier si le modèle par défaut est disponible, sinon utiliser fallback
    if args.model is None:
        try:
            available = ollama.list()
            model_names = " ".join(
                m.get("name", m.get("model", "")) for m in available.get("models", [])
            )
            base = effective_model.split(":")[0]
            if base not in model_names:
                print(f"  [R1] {effective_model} absent, fallback → {DEFAULT_MODEL}",
                      file=sys.stderr)
                effective_model = DEFAULT_MODEL
            else:
                print(f"  [R1] Modèle phase '{args.phase}' → {effective_model}",
                      file=sys.stderr)
        except Exception:
            effective_model = DEFAULT_MODEL

    # ── Exécuter la phase ────────────────────────────────────────────────────
    print(f"\n{'='*60}", file=sys.stderr)
    print(f"  Phase : {args.phase.upper()} | Session : {args.kvbasename}",
          file=sys.stderr)
    print(f"  Modèle : {effective_model}", file=sys.stderr)
    print(f"{'='*60}\n", file=sys.stderr)

    result_text = ""
    # Contexte humain injecté dans le prompt (--supplement)
    supplement = getattr(args, "supplement", "") or ""
    if supplement:
        print(f"  [supplement] Contexte humain injecté : {supplement[:80]}",
              file=sys.stderr)

    if args.phase == "analyse":
        result_text = phase_analyse(kv, code_summary, effective_model, semantic_ctx,
                                    supplement=supplement,
                                    test_ctx=_test_results or _coverage_gaps,
                                    doc_ctx=_doc_issues)
        proposals = parse_proposals("analyse", result_text)
        kv["last_proposals"] = proposals
        kv["last_analyse_text"] = result_text

    elif args.phase == "correction":
        choice = args.choice or kv.get("last_choice") or "1"
        result_text = phase_correction(
            kv, code_summary, effective_model, choice,
            diff_format=getattr(args, "diff_format", "json"),
            supplement=supplement
        )
        kv["last_correction_text"] = result_text
        kv["last_problem_choice"]  = choice

    elif args.phase == "controle":
        choice = args.choice or kv.get("last_choice") or "a"
        result_text = phase_controle(kv, code_summary, effective_model, choice,
                                     supplement=supplement,
                                     test_mode=_active_test)
        kv["last_controle_text"] = result_text
        kv["last_variant_choice"] = choice

        # Indexer la correction validée dans Qdrant
        if use_qdrant:
            qdrant_index(args.kvbasename, script_name,
                         f"Contrôle {choice}: {result_text[:200]}")

    # ── Sauvegarder le choix et l'historique ─────────────────────────────────
    if args.choice:
        kv["last_choice"] = args.choice
    kv["history"].append({
        "phase": args.phase,
        "choice": args.choice,
        "timestamp": time.time(),
        "summary": result_text[:200]
    })
    save_kv(args.kvbasename, kv)
    log(f"Phase {args.phase} | {args.kvbasename} | {script_name}")

    # ── Sortie ────────────────────────────────────────────────────────────────
    if args.patch and args.phase == "correction" and args.choice:
        # Mode patch : extraire uniquement les blocs PATCH de l'option choisie
        option_text = extract_option(result_text, args.choice)
        patches = extract_patches(option_text or result_text)
        output = {
            "mode": "patch",
            "phase": args.phase,
            "choice": args.choice,
            "patches": patches,
            "explanation": option_text[:500] if option_text else ""
        }
        print(json.dumps(output, ensure_ascii=False, indent=2))
    else:
        print(result_text)


if __name__ == "__main__":
    main()
