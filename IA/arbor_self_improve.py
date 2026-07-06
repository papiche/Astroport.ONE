#!/usr/bin/env python3
"""
arbor_self_improve.py — Auto-amélioration encadrée du prompt/modèle
d'interprétation des commandes BRO (bro_watch_core.interpret_command_with_context).

Inspiré d'Arbor (https://github.com/RUC-NLPIR/Arbor, Apache-2.0). Les fonctions
_slugify, _worktree_dir_name, _user_token et _create_worktree ci-dessous sont
adaptées — en synchrone, sans pydantic/asyncio — de
src/coordinator/tools/{worktree,git_ops}.py du projet Arbor. La garde
_PROTECTED_BRANCHES reprend la même idée : jamais de merge/écriture directe
sur master/main.

Portée volontairement restreinte (décision prise avec le capitaine) :
  - Auto-amélioration limitée au prompt/modèle d'interprétation des commandes
    bro_watch_core, jamais au reste du code.
  - Aucune autonomie complète : validation manuelle du capitaine avant tout
    merge (cette moulinette ne merge jamais elle-même).

Discipline Arbor appliquée :
  1. Hypothèses  — petite liste de candidats (modèle Ollama alternatif, ou
                   correctif de garde-fou lexical), chacun un nœud indépendant.
  2. Éval dev    — chaque hypothèse est testée UNIQUEMENT sur le jeu dev
                   (bro_watch_command_eval_dev.json).
  3. Sélection   — on ne retient une hypothèse que si elle bat STRICTEMENT
                   le score dev de référence.
  4. Validation  — le gagnant est re-testé sur le jeu held-out (jamais vu
                   pendant l'exploration) : si le gain ne se confirme pas,
                   c'est un signe de surapprentissage → hypothèse rejetée.
  5. Gouvernance — si validée, le changement est matérialisé dans un
                   worktree git isolé (nouvelle branche dédiée), commité là,
                   et JAMAIS mergé automatiquement. Le capitaine relit le
                   diff et décide.

Deuxième volet — détection continue de besoins (--mine-requests), portée
plus large mais gouvernance identique : analyse le corpus partagé
~/.zen/flashmem/bro_tool_requests.jsonl (alimenté par TOUS les propriétaires
via bro_watch_core._conversational_reply — chaque question à laquelle BRO n'a
pas su répondre par une commande reconnue) pour détecter, par clustering
sémantique (Qdrant/Ollama), des demandes récurrentes de nouveaux outils Web2
à déléguer. Ne génère JAMAIS de code de scraper automatiquement — seulement
une détection + notification capitaine (l'implémentation d'un nouvel outil
reste un choix et un travail humains, décision actée avec l'utilisateur).

Usage :
    python3 arbor_self_improve.py                 # explore + rapporte, n'écrit rien
    python3 arbor_self_improve.py --apply          # + matérialise le gagnant validé
                                                      dans un worktree isolé
    python3 arbor_self_improve.py --mine-requests --notify-captain
                                                   # analyse le corpus multi-utilisateurs,
                                                   # notifie le capitaine des patterns récurrents
"""

# Auto-reinvocation dans le venv ~/.astro/ si dépendances absentes
import sys as _sys
import os as _os
_venv_python = _os.path.expanduser("~/.astro/bin/python3")
if _os.path.exists(_venv_python) and _sys.executable != _venv_python:
    _os.execv(_venv_python, [_venv_python] + _sys.argv)
del _sys, _os

import sys
import os
import re
import json
import shutil
import getpass
import argparse
import hashlib
import subprocess
import tempfile
from datetime import datetime, timezone

sys.path.insert(0, os.path.expanduser("~/.zen/Astroport.ONE/IA"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# eval_command_interpretation.py est un harnais d'évaluation légitime, laissé
# dans IA/tests/ (contrairement à ce fichier, déplacé de IA/tests/ vers IA/
# car c'est un outil de production, pas un test) — chemin ajouté explicitement.
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "tests"))
import bro_watch_core as bwc
from eval_command_interpretation import run_eval

REPO_ROOT = os.path.expanduser("~/.zen/Astroport.ONE")
BRANCH_PREFIX = "arbor/bro-cmd-interp"

# Fichiers nécessaires pour qu'un worktree isolé soit un bac à sable
# autonome et exécutable (bro_watch_core.py et les tests associés ne sont
# pas encore committés dans ce dépôt — copie explicite, pas de dépendance
# implicite sur un `git checkout` qui les ignorerait).
SANDBOX_FILES = [
    "IA/bro_watch_core.py",
    "IA/prompt_safety.py",
    "IA/bro/__init__.py",
    "IA/bro/_shared.py",
    "IA/bro/nostr.py",
    "IA/bro/watch_store.py",
    "IA/bro/rag.py",
    "IA/bro/media.py",
    "IA/bro/economy.py",
    "IA/bro/identity.py",
    "IA/bro/tools.py",
    "IA/tests/eval_command_interpretation.py",
    "IA/tests/bro_watch_command_eval_dev.json",
    "IA/tests/bro_watch_command_eval_heldout.json",
    "IA/tests/arbor_self_improve.py",
]

# Jamais de merge/écriture directe sur ces branches (garde reprise d'Arbor :
# src/coordinator/tools/git_ops.py::_PROTECTED_BRANCHES).
_PROTECTED_BRANCHES = frozenset({"main", "master"})

# ── Hypothèses (arborescence à plat : chaque candidat est indépendant) ──
# Choisies suite à un sweep manuel de modèles Ollama locaux mené dans cette
# même session (gemma3:latest 6/8, orieg/gemma3-tools:12b 7/8, qwen2.5-coder:14b
# 8/8, qwen3:14b 7/8 — hermes3/qwen2.5:latest bien plus bas, exclus ici).
CANDIDATES = [
    {"id": "model-qwen2.5-coder-14b", "model": "qwen2.5-coder:14b"},
    {"id": "model-orieg-gemma3-tools-12b", "model": "orieg/gemma3-tools:12b"},
    {"id": "model-qwen3-14b", "model": "qwen3:14b"},
]


# ── Utilitaires git (adaptés d'Arbor, synchrones) ───────────────────────

def _slugify(text, max_len=32):
    slug = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return slug[:max_len] or "x"


def _user_token():
    """Suffixe par utilisateur pour le dossier temporaire du worktree,
    sûr même si os.getuid() est absent (adapté de git_ops._user_token)."""
    try:
        raw = str(os.getuid()) if hasattr(os, "getuid") else getpass.getuser()
    except Exception:
        raw = "user"
    return re.sub(r"[^A-Za-z0-9_.-]", "_", raw) or "user"


def _worktree_dir_name(branch_name):
    safe = branch_name.replace("/", "__").replace(".", "_")
    if len(safe) <= 180:
        return safe
    digest = hashlib.sha1(branch_name.encode("utf-8")).hexdigest()[:12]
    return f"{safe[:160]}__{digest}"


def _run_git(args, cwd):
    result = subprocess.run(["git"] + args, cwd=cwd, capture_output=True, text=True, timeout=60)
    return result.stdout.strip() + result.stderr.strip(), result.returncode


def _create_worktree(hypothesis_id):
    """Crée un worktree git isolé, branché depuis HEAD, dans un dossier
    temporaire (n'affecte jamais l'arbre de travail principal). Adapté de
    Arbor src/coordinator/tools/worktree.py::_create_worktree."""
    digest = hashlib.sha1(hypothesis_id.encode("utf-8")).hexdigest()[:8]
    branch_name = f"{BRANCH_PREFIX}/{_slugify(hypothesis_id, 40)}-{digest}"
    if branch_name in _PROTECTED_BRANCHES:
        raise RuntimeError("nom de branche en collision avec une branche protégée")

    worktree_base = os.path.join(tempfile.gettempdir(), f"bro-arbor-worktrees-{_user_token()}")
    os.makedirs(worktree_base, exist_ok=True)
    worktree_path = os.path.join(worktree_base, _worktree_dir_name(branch_name))

    if os.path.exists(worktree_path):
        _run_git(["worktree", "remove", "--force", worktree_path], REPO_ROOT)
        shutil.rmtree(worktree_path, ignore_errors=True)

    out, rc = _run_git(["worktree", "add", "-b", branch_name, worktree_path, "HEAD"], REPO_ROOT)
    if rc != 0:
        ts = datetime.now(timezone.utc).strftime("%m%d-%H%M%S")
        branch_name = f"{branch_name}-{ts}"
        worktree_path = os.path.join(worktree_base, _worktree_dir_name(branch_name))
        out, rc = _run_git(["worktree", "add", "-b", branch_name, worktree_path, "HEAD"], REPO_ROOT)
        if rc != 0:
            raise RuntimeError(f"git worktree add a échoué : {out}")

    return worktree_path, branch_name


def _apply_model_change(worktree_path, new_model):
    """Copie le bac à sable (fichiers non encore committés dans le dépôt
    principal) dans le worktree isolé, applique le changement de modèle par
    défaut, et committe — sans jamais toucher à l'arbre de travail principal
    ni à master/main."""
    for rel_path in SANDBOX_FILES:
        src = os.path.join(REPO_ROOT, rel_path)
        dst = os.path.join(worktree_path, rel_path)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(src, dst)

    # COMMAND_INTERPRETATION_MODEL vit dans bro/_shared.py depuis le split du
    # monolithe bro_watch_core.py (2026-07-06), pas dans bro_watch_core.py lui-même.
    target = os.path.join(worktree_path, "IA/bro/_shared.py")
    with open(target, encoding="utf-8") as f:
        content = f.read()
    old_line = f'COMMAND_INTERPRETATION_MODEL = "{bwc.COMMAND_INTERPRETATION_MODEL}"'
    new_line = f'COMMAND_INTERPRETATION_MODEL = "{new_model}"'
    if old_line not in content:
        raise RuntimeError("constante COMMAND_INTERPRETATION_MODEL introuvable — a-t-elle changé de forme ?")
    with open(target, "w", encoding="utf-8") as f:
        f.write(content.replace(old_line, new_line, 1))

    _run_git(["add"] + SANDBOX_FILES, worktree_path)
    _run_git(["commit", "-m",
              f"bro_watch_core: bascule COMMAND_INTERPRETATION_MODEL sur {new_model}\n\n"
              f"Proposé par arbor_self_improve.py — validé dev+held-out, en attente de revue capitaine."],
             worktree_path)


# ── Boucle Arbor : hypothèses → éval dev → sélection → validation ──────

def explore():
    print("── Baseline ──────────────────────────────────────────────")
    baseline_dev, _ = run_eval(model=None, split="dev")
    baseline_heldout, _ = run_eval(model=None, split="heldout")
    print(f"Référence ({bwc.COMMAND_INTERPRETATION_MODEL}) : dev={baseline_dev:.0%}  heldout={baseline_heldout:.0%}\n")

    print("── Exploration des hypothèses (jeu dev uniquement) ─────────")
    scored = []
    for cand in CANDIDATES:
        print(f"\n· hypothèse {cand['id']} ({cand['model']})")
        score, _ = run_eval(model=cand["model"], split="dev")
        scored.append({**cand, "dev_score": score})

    best = max(scored, key=lambda c: c["dev_score"])
    if best["dev_score"] <= baseline_dev:
        print(f"\n❌ Aucune hypothèse ne bat strictement la référence dev ({baseline_dev:.0%}). Rien à valider.")
        return None

    print(f"\n── Validation held-out du gagnant : {best['id']} ({best['model']}) ─────")
    heldout_score, _ = run_eval(model=best["model"], split="heldout", verbose=True)

    print("\n── Rapport ──────────────────────────────────────────────")
    print(f"Référence        : dev={baseline_dev:.0%}  heldout={baseline_heldout:.0%}")
    print(f"Candidat retenu  : dev={best['dev_score']:.0%}  heldout={heldout_score:.0%}  ({best['model']})")

    if heldout_score < baseline_heldout:
        print("❌ Gain non confirmé sur held-out (probable surapprentissage sur le phrasé du jeu dev) — rejeté.")
        return None

    print("✅ Gain confirmé sur dev ET held-out.")
    return {**best, "heldout_score": heldout_score,
            "baseline_dev": baseline_dev, "baseline_heldout": baseline_heldout}


def validate_choice(model, label=None):
    """Valide un choix du capitaine (pas forcément le gagnant automatique de
    explore()) : rejoue dev+held-out pour ce modèle précis et rapporte, sans
    appliquer le filtre 'doit battre la référence' — la décision humaine
    prime sur le score brut (gouvernance : validation capitaine requise)."""
    baseline_dev, _ = run_eval(model=None, split="dev")
    baseline_heldout, _ = run_eval(model=None, split="heldout")
    print(f"Référence ({bwc.COMMAND_INTERPRETATION_MODEL}) : dev={baseline_dev:.0%}  heldout={baseline_heldout:.0%}\n")

    print(f"── Choix capitaine : {label or model} ─────")
    dev_score, _ = run_eval(model=model, split="dev")
    heldout_score, _ = run_eval(model=model, split="heldout", verbose=True)

    print("\n── Rapport ──────────────────────────────────────────────")
    print(f"Référence        : dev={baseline_dev:.0%}  heldout={baseline_heldout:.0%}")
    print(f"Choix capitaine  : dev={dev_score:.0%}  heldout={heldout_score:.0%}  ({model})")
    return {"id": label or _slugify(model, 40), "model": model,
            "dev_score": dev_score, "heldout_score": heldout_score,
            "baseline_dev": baseline_dev, "baseline_heldout": baseline_heldout}


# ── Notification capitaine (clé NODE — jamais la clé propriétaire self-DM) ──
# La station elle-même (identité NODE, "qui représente la machine") prévient
# le capitaine qu'une proposition de code est prête à être relue — ce canal
# est distinct et volontairement séparé du self-DM propriétaire↔BRO (voir le
# commentaire au-dessus de _fetch_self_dms_since dans bro_watch_core.py :
# le NODE ne parle jamais dans le canal self-DM d'un propriétaire).

def _node_nsec():
    secret_file = os.path.expanduser("~/.zen/game/secret.nostr")
    try:
        with open(secret_file) as f:
            content = f.read()
        for part in content.replace("\n", ";").split(";"):
            part = part.strip()
            if part.startswith("NSEC="):
                return part.split("=", 1)[1].strip("\"'")
    except Exception:
        pass
    return ""


def _notify_captain_arbor(winner, branch_name, worktree_path):
    captain_email = os.environ.get("CAPTAINEMAIL", "").strip()
    if not captain_email:
        print("⚠️ CAPTAINEMAIL absent de l'environnement — notification capitaine sautée.")
        return False
    nsec = _node_nsec()
    captain_hex = bwc._owner_hex(captain_email)
    if not nsec or not captain_hex:
        print("⚠️ NODE nsec ou HEX capitaine introuvable — notification capitaine sautée.")
        return False

    message = (
        "🔧 Auto-amélioration BRO — proposition prête à relire\n\n"
        f"Modèle candidat : {winner['model']}\n"
        f"Score dev       : {winner['baseline_dev']:.0%} → {winner['dev_score']:.0%}\n"
        f"Score held-out  : {winner['baseline_heldout']:.0%} → {winner['heldout_score']:.0%}\n\n"
        f"Branche  : {branch_name}\n"
        f"Worktree : {worktree_path}\n"
        f"Revue    : cd {REPO_ROOT} && git diff master...{branch_name}\n\n"
        "Rien n'a été mergé — seule cette branche isolée contient le changement. "
        "Le merge reste votre décision."
    )
    script = os.path.join(REPO_ROOT, "tools", "nostr_send_secure_dm.py")
    try:
        proc = subprocess.run(
            ["python3", script, "--nsec-stdin", captain_hex, message, "wss://relay.copylaradio.com",
             "--ttl-days", "14"],
            input=nsec + "\n", capture_output=True, text=True, timeout=15,
        )
        return proc.returncode == 0
    except Exception as e:
        print(f"⚠️ Échec envoi notification capitaine : {e}")
        return False


# ── Mining continu des besoins multi-utilisateurs ───────────────────────
# Détection uniquement — jamais de génération de code de scraper/outil
# automatique. Un pattern récurrent est signalé au capitaine, qui décide
# seul s'il vaut la peine de développer la capacité correspondante.

MINED_CLUSTERS_STATE = os.path.expanduser("~/.zen/flashmem/bro_tool_requests_mined.json")
MIN_CLUSTER_SIZE = 3
# Calibré empiriquement (comme SEMANTIC_THRESHOLD dans bro_watch_core.py) sur
# 3 reformulations réelles d'une même demande ("suivre mon Twitter/X" dit
# différemment) : cosinus 0.695-0.798 entre elles vs 0.615-0.666 avec un
# message sans rapport. La marge est étroite (nomic-embed-text a un plancher
# élevé sur les phrases courtes) — biais volontaire vers le rappel : un faux
# rapprochement coûte une lecture inutile au capitaine, un pattern manqué
# rate complètement l'objectif de la fonctionnalité.
CLUSTER_SIMILARITY_THRESHOLD = 0.68


def _load_tool_requests():
    entries = []
    try:
        with open(bwc.TOOL_REQUESTS_LOG, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entries.append(json.loads(line))
                except Exception:
                    continue
    except Exception:
        pass
    return entries


def _cluster_requests(entries):
    """Regroupe les demandes par similarité sémantique (embeddings Ollama +
    cosinus, même approche que bro_watch_core.semantic_match) — clustering
    glouton par plus-proche-centroïde, suffisant pour un corpus modeste."""
    vecs = []
    for e in entries:
        try:
            vecs.append(bwc._qdrant_embed(e["text"]))
        except Exception:
            vecs.append(None)

    clusters = []  # [{"members": [idx...], "centroid": vec}]
    for i, v in enumerate(vecs):
        if v is None:
            continue
        placed = False
        for c in clusters:
            if bwc._cosine(v, c["centroid"]) >= CLUSTER_SIMILARITY_THRESHOLD:
                c["members"].append(i)
                placed = True
                break
        if not placed:
            clusters.append({"members": [i], "centroid": v})
    return [c for c in clusters if len(c["members"]) >= MIN_CLUSTER_SIZE]


def _cluster_fingerprint(entries, members):
    texts = sorted(entries[i]["text"] for i in members)
    return hashlib.sha1("||".join(texts).encode("utf-8")).hexdigest()


def _load_mined_state():
    try:
        with open(MINED_CLUSTERS_STATE, encoding="utf-8") as f:
            return set(json.load(f))
    except Exception:
        return set()


def _save_mined_state(fingerprints):
    os.makedirs(os.path.dirname(MINED_CLUSTERS_STATE), exist_ok=True)
    with open(MINED_CLUSTERS_STATE, "w", encoding="utf-8") as f:
        json.dump(sorted(fingerprints), f)


def _summarize_tool_cluster(sample_texts):
    prompt = (
        "Voici plusieurs demandes d'utilisateurs à BRO (assistant IA personnel UPlanet) "
        "que le système n'a pas su satisfaire par un outil existant :\n\n"
        + "\n".join(f"- {t}" for t in sample_texts)
        + "\n\nEn une phrase courte, quelle capacité/outil Web2 commun ces demandes "
        "révèlent-elles ? Réponds uniquement par cette phrase, sans préambule."
    )
    try:
        result = subprocess.run(
            ["python3", os.path.join(REPO_ROOT, "IA", "question.py"), prompt,
             "--temperature", "0.2", "--max-tokens", "100"],
            capture_output=True, text=True, timeout=30,
        )
        return result.stdout.strip() or "(résumé indisponible)"
    except Exception:
        return "(résumé indisponible)"


def mine_tool_requests():
    """Analyse le corpus multi-utilisateurs des demandes non satisfaites,
    détecte les patterns récurrents (≥ MIN_CLUSTER_SIZE demandes similaires)
    jamais encore signalés, et retourne un résumé par cluster frais. Ne
    modifie aucun code — seule la notification capitaine en découle."""
    entries = _load_tool_requests()
    if len(entries) < MIN_CLUSTER_SIZE:
        return []

    clusters = _cluster_requests(entries)
    already = _load_mined_state()
    fresh_reports = []
    for c in clusters:
        fp = _cluster_fingerprint(entries, c["members"])
        if fp in already:
            continue
        sample_texts = [entries[i]["text"] for i in c["members"]][:5]
        owners = sorted({entries[i]["owner"] for i in c["members"]})
        fresh_reports.append({
            "fingerprint": fp,
            "count": len(c["members"]),
            "owners": owners,
            "sample_texts": sample_texts,
            "summary": _summarize_tool_cluster(sample_texts),
        })
        already.add(fp)

    if fresh_reports:
        _save_mined_state(already)
    return fresh_reports


def _notify_captain_tool_requests(reports):
    captain_email = os.environ.get("CAPTAINEMAIL", "").strip()
    if not captain_email or not reports:
        return False
    nsec = _node_nsec()
    captain_hex = bwc._owner_hex(captain_email)
    if not nsec or not captain_hex:
        print("⚠️ NODE nsec ou HEX capitaine introuvable — notification sautée.")
        return False

    lines = ["🔍 BRO — nouveaux besoins récurrents détectés (analyse continue, tous comptes)\n"]
    for r in reports:
        lines.append(f"• {r['summary']}  ({r['count']} demande(s), {len(r['owners'])} compte(s))")
    lines.append("\nExemples de formulations :")
    for r in reports[:3]:
        for t in r["sample_texts"][:2]:
            lines.append(f"  « {t[:100]} »")
    lines.append("\nAucune action automatique — à vous de décider s'il faut développer un nouvel outil.")
    message = "\n".join(lines)

    script = os.path.join(REPO_ROOT, "tools", "nostr_send_secure_dm.py")
    try:
        proc = subprocess.run(
            ["python3", script, "--nsec-stdin", captain_hex, message, "wss://relay.copylaradio.com",
             "--ttl-days", "14"],
            input=nsec + "\n", capture_output=True, text=True, timeout=15,
        )
        return proc.returncode == 0
    except Exception as e:
        print(f"⚠️ Échec envoi notification besoins : {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true",
                         help="Si une hypothèse est validée, la matérialise dans un worktree git isolé pour revue capitaine")
    parser.add_argument("--model", type=str, default=None,
                         help="Force un modèle précis (choix capitaine) au lieu de l'exploration automatique")
    parser.add_argument("--notify-captain", action="store_true",
                         help="Envoie un DM NODE au capitaine (CAPTAINEMAIL) si une proposition/un pattern est détecté")
    parser.add_argument("--mine-requests", action="store_true",
                         help="Analyse le corpus multi-utilisateurs des demandes non satisfaites "
                              "(indépendant de l'auto-amélioration du prompt ci-dessus)")
    args = parser.parse_args()

    if args.mine_requests:
        reports = mine_tool_requests()
        if not reports:
            print("Aucun nouveau pattern récurrent détecté.")
            return
        print(f"🔍 {len(reports)} nouveau(x) pattern(s) détecté(s) :")
        for r in reports:
            print(f"  • {r['summary']} ({r['count']} demande(s), {len(r['owners'])} compte(s))")
        if args.notify_captain:
            if _notify_captain_tool_requests(reports):
                print("📨 Capitaine notifié par DM NODE.")
            else:
                print("⚠️ Notification capitaine non envoyée (voir logs ci-dessus).")
        return

    winner = validate_choice(args.model) if args.model else explore()
    if not winner:
        return

    if not args.apply:
        print("\n(rejouer avec --apply pour matérialiser ce changement dans un worktree isolé, sans le merger)")
        return

    worktree_path, branch_name = _create_worktree(winner["id"])
    _apply_model_change(worktree_path, winner["model"])
    print(f"\n── Proposition committée (branche isolée, PAS mergée) ─────")
    print(f"Branche  : {branch_name}")
    print(f"Worktree : {worktree_path}")
    print(f"Revue    : cd {REPO_ROOT} && git diff master...{branch_name}")
    print("Le capitaine décide seul du merge — cf. décision de gouvernance actée.")

    if args.notify_captain:
        if _notify_captain_arbor(winner, branch_name, worktree_path):
            print("📨 Capitaine notifié par DM NODE.")
        else:
            print("⚠️ Notification capitaine non envoyée (voir logs ci-dessus).")


if __name__ == "__main__":
    main()
