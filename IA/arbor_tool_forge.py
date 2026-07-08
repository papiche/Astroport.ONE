#!/usr/bin/env python3
"""
arbor_tool_forge.py — Forge à outils Arbor : génère un outil BRO autonome à
partir d'une description en langage naturel, avec boucle d'auto-correction
par tests sandboxés (pytest, max MAX_ITERATIONS tentatives).

Gouvernance (décisions actées avec le capitaine, 2026-07-03) :
  - Déclenchement CAPITAINE-ONLY en v1 : pas de panel adversarial disponible
    en exécution cron autonome (nécessite l'outil Agent, session interactive
    uniquement) — la décision "on développe cet outil" reste humaine tant
    que cette boucle n'a pas fait ses preuves. Le mining (arbor_self_improve.py
    --mine-requests) continue de détecter et notifier seul ; il ne déclenche
    JAMAIS cette forge automatiquement.
  - Fichiers NOUVEAUX uniquement : ce module ne modifie jamais un fichier
    existant du dépôt (ex: pas d'ajout d'import dans UPlanet_IA_Responder.sh).
    L'outil généré est autonome, testé, mais pas branché à BRO — le capitaine
    décide ensuite comment/où l'appeler.
  - Isolation git worktree (réutilise _create_worktree d'arbor_self_improve.py)
    et notification capitaine par DM NODE — jamais de merge automatique.
  - Échec après MAX_ITERATIONS tentatives → RIEN n'est committé, le capitaine
    est prévenu de l'échec avec la dernière erreur (pas de faux positif).

Backend LLM — répartition délibérée (constat du 2026-07-03, premier test réel
en conditions réelles) : les modèles Ollama locaux (qwen2.5-coder:14b compris)
se sont montrés trop limités pour une boucle d'auto-correction de code fiable
— la régénération ne progressait pas sur des bugs de logique fine, contrairement
aux violations de contraintes explicites. Cette forge utilise donc le CLI
`claude` (Claude Code, mode non-interactif `-p`) pour toute génération de code
(spec, outil, test, résumé), et laisse Ollama à ce qu'il fait bien : le
conversationnel de BRO (question.py, _conversational_reply). Prérequis :
`claude` doit être installé et authentifié — voir claude.vscodium.setup.sh
(commande `setup` ou `migrate`) à la racine du dépôt.

Contrat des outils générés : un fichier autonome exposant EXACTEMENT
    def run(query: str) -> str
et un test pytest associé qui l'exerce avec un exemple concret.

Usage :
    python3 arbor_tool_forge.py --need "Trouve la météo d'une ville" --slug meteo
    python3 arbor_tool_forge.py --need "..." --notify-captain
"""

# Auto-reinvocation dans le venv ~/.astro/ si dépendances absentes
import sys as _sys
import os as _os
_venv_python = _os.path.expanduser("~/.astro/bin/python3")
if _os.path.exists(_venv_python) and _sys.executable != _venv_python:
    _os.execv(_venv_python, [_venv_python] + _sys.argv)
del _sys, _os

import os
import re
import ast
import sys
import json
import argparse
import subprocess
from datetime import datetime, timezone

sys.path.insert(0, os.path.expanduser("~/.zen/Astroport.ONE/IA"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bro_watch_core as bwc
from arbor_self_improve import _create_worktree, _slugify, _run_git, _node_nsec, REPO_ROOT

MAX_ITERATIONS = 3
CODE_BLOCK_RE = re.compile(r"```(?:python)?\s*\n(.*?)```", re.DOTALL)

# Garde-fou statique — appliqué AVANT tout test sandboxé, sur chaque tentative.
# Ne remplace pas une revue humaine, mais coûte rien et bloque les cas évidents
# avant même de dépenser un cycle pytest dessus.
#
# AST plutôt que regex (2026-07-06) : les regex précédentes (\beval\s*\(...)
# ne survivent pas à une reformulation triviale (espaces, retour à la ligne,
# ré-affectation) et laissent passer shell=True hors du seul mot "subprocess"
# (ex: n'importe quel appel avec shell=True). L'analyse AST résout ces deux
# problèmes en inspectant la STRUCTURE réelle du code, pas son apparence
# textuelle.
#
# LIMITE HONNÊTE : une analyse statique de la structure syntaxique ne peut
# PAS résoudre `getattr(__builtins__, 'ev' + 'al')` comme «un appel à eval» —
# ce n'est structurellement pas un appel à eval, c'est un appel à getattr
# (bloqué ci-dessous en tant que tel, comme tout accès au nom __builtins__).
# Aucune analyse purement statique (regex OU AST) ne peut fermer cette classe
# de contournement en toute généralité — c'est exactement pour cette raison
# que bwrap (sandbox OS, voir _run_pytest_in_worktree) reste la VRAIE ligne de
# défense. Ce garde-fou n'est qu'un filtre rapide en amont, pas une preuve.
_FORBIDDEN_CALL_NAMES = {
    "eval", "exec", "compile", "__import__",
    "getattr", "setattr", "delattr", "vars", "globals", "locals",
}
_FORBIDDEN_IMPORT_MODULES = {
    "subprocess", "ctypes", "pickle", "shelve", "marshal", "importlib",
    "code", "pty", "multiprocessing",
}
_FORBIDDEN_OS_ATTRS = {
    "system", "popen", "fork", "forkpty", "posix_spawn",
    "spawnl", "spawnle", "spawnlp", "spawnlpe", "spawnv", "spawnve", "spawnvp", "spawnvpe",
    "execl", "execle", "execlp", "execlpe", "execv", "execve", "execvp", "execvpe",
}
_FORBIDDEN_DUNDER_NAMES = {
    "__builtins__", "__globals__", "__class__", "__subclasses__",
    "__mro__", "__bases__", "__loader__", "__import__",
}


def _extract_code(text):
    match = CODE_BLOCK_RE.search(text or "")
    return (match.group(1) if match else (text or "")).strip()


def _attr_root_name(attr_node):
    """Pour un ast.Attribute (ex: os.system), remonte à travers les accès
    chaînés jusqu'au nom racine (ex: os.path.join -> 'os'). Retourne None si
    la racine n'est pas un simple identifiant (ex: (a+b).system)."""
    node = attr_node.value
    while isinstance(node, ast.Attribute):
        node = node.value
    return node.id if isinstance(node, ast.Name) else None


def _collect_import_aliases(tree):
    """Mappe chaque nom LOCAL introduit par `import X as alias` vers son
    module racine réel X — sans ça, `import os as o; o.system(...)` contourne
    toute vérification qui compare littéralement contre le nom "os"."""
    aliases = {}
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                top_module = alias.name.split(".")[0]
                aliases[alias.asname or alias.name.split(".")[0]] = top_module
    return aliases


def _static_safety_check(code):
    """Analyse AST du code généré — voir le commentaire au-dessus de
    _FORBIDDEN_CALL_NAMES pour la portée et les limites de cette analyse."""
    issues = []
    try:
        tree = ast.parse(code)
    except SyntaxError as e:
        return [f"code non parsable (SyntaxError, ligne {e.lineno}) : {e.msg}"]

    import_aliases = _collect_import_aliases(tree)

    def _resolved_root(attr_node):
        root = _attr_root_name(attr_node)
        return import_aliases.get(root, root)

    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            func = node.func
            call_name = func.id if isinstance(func, ast.Name) else (
                func.attr if isinstance(func, ast.Attribute) else None)

            if call_name in _FORBIDDEN_CALL_NAMES:
                issues.append(f"appel interdit : {call_name}()")
            elif isinstance(func, ast.Attribute) and func.attr in _FORBIDDEN_OS_ATTRS \
                    and _resolved_root(func) == "os":
                issues.append(f"os.{func.attr}() interdit")
            elif call_name in ("get", "post") and isinstance(func, ast.Attribute) \
                    and _resolved_root(func) == "requests":
                if not any(kw.arg == "timeout" for kw in node.keywords):
                    issues.append(f"appel requests.{call_name}() sans paramètre timeout")

            # shell=True interdit sur N'IMPORTE QUEL appel, pas seulement
            # subprocess.* par son nom — un import subprocess renommé
            # (import subprocess as sp) reste de toute façon bloqué ci-dessous.
            for kw in node.keywords:
                if kw.arg == "shell" and isinstance(kw.value, ast.Constant) and kw.value.value is True:
                    issues.append("shell=True interdit (subprocess)")

        elif isinstance(node, ast.Import):
            for alias in node.names:
                top_module = alias.name.split(".")[0]
                if top_module in _FORBIDDEN_IMPORT_MODULES:
                    issues.append(f"import {alias.name} interdit")

        elif isinstance(node, ast.ImportFrom):
            if node.module and node.module.split(".")[0] in _FORBIDDEN_IMPORT_MODULES:
                issues.append(f"from {node.module} import ... interdit")

        elif isinstance(node, ast.Name) and node.id in _FORBIDDEN_DUNDER_NAMES:
            issues.append(f"accès interdit : {node.id}")
        elif isinstance(node, ast.Attribute) and node.attr in _FORBIDDEN_DUNDER_NAMES:
            issues.append(f"accès interdit : .{node.attr}")
        # sys.modules — trou trouvé le 2026-07-06 : sys.modules["os"].system(...)
        # passait inaperçu (Subscript, pas un Attribute simple — _resolved_root
        # ne le résout pas jusqu'à "os"). "modules" seul serait trop large
        # (nom d'attribut plausible ailleurs) : on vérifie précisément la
        # racine "sys", comme pour os.system ci-dessus.
        elif isinstance(node, ast.Attribute) and node.attr == "modules" \
                and _resolved_root(node) == "sys":
            issues.append("accès interdit : sys.modules")

    if ".." in code and re.search(r"\.\./", code):
        issues.append("chemin relatif parent (../) suspect")

    return issues


def claude_available():
    """Vérifie que le CLI claude est installé — ne garantit pas l'authentification
    (une session expirée échouera à l'appel réel, message d'erreur clair alors)."""
    from shutil import which
    return which("claude") is not None


def _ask_claude(prompt, timeout=180):
    """Appelle Claude Code CLI en mode non-interactif (claude -p) — voir
    IA/code_assistant.py::call_claude_cli, même pattern. Réservé à la
    génération de CODE (spec, outil, test, résumé) : Ollama reste le backend
    du conversationnel BRO (question.py), volontairement séparé."""
    try:
        result = subprocess.run(
            ["claude", "-p", prompt], capture_output=True, text=True, timeout=timeout,
        )
        if result.returncode != 0 and not result.stdout.strip():
            print(f"⚠️ Claude CLI erreur (code {result.returncode}) : {result.stderr[:300]}")
            return ""
        return result.stdout.strip()
    except FileNotFoundError:
        print("⚠️ claude CLI introuvable — voir claude.vscodium.setup.sh (setup/migrate) à la racine du dépôt.")
        return ""
    except subprocess.TimeoutExpired:
        print(f"⚠️ Timeout Claude CLI ({timeout}s)")
        return ""
    except Exception as e:
        print(f"⚠️ Appel Claude CLI échoué : {e}")
        return ""


def _extract_json(text):
    """Claude (contrairement à Ollama format=json) n'a pas de contrainte de
    décodage garantissant du JSON pur — parse direct en priorité, repli sur
    extraction du premier bloc {...} si le modèle a ajouté du texte autour."""
    try:
        return json.loads(text.strip())
    except Exception:
        pass
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if not match:
        return None
    try:
        return json.loads(match.group(0))
    except Exception:
        return None


def generate_spec(need_description):
    """Transforme un besoin en langage naturel en spec structurée — nom
    d'outil, description, exemple d'entrée/sortie. Sert aussi de base au
    résumé final destiné au capitaine.

    routing_examples (distinct de example_query) : plusieurs paraphrases
    réalistes de la requête, PAS la description formelle de l'outil — c'est
    ce que bro_watch_core.py::activate_tool() indexe pour que l'outil soit
    routé via match_intent() (marge positif/négatifs partagés) plutôt que
    via le seuil fixe de match_tool(), moins robuste (cf. l'incident
    documenté sur match_tool : comparer au texte de description seul a laissé
    passer un faux positif que la marge sur exemples réels rejette
    correctement, vérifié empiriquement avec nomic-embed-text)."""
    prompt = (
        "Tu es un développeur Python senior. Un besoin récurrent a été détecté chez "
        "des utilisateurs de BRO (assistant IA personnel décentralisé). Conçois la "
        "spec d'un outil Python autonome pour y répondre.\n\n"
        f"Besoin : {need_description}\n\n"
        "Réponds UNIQUEMENT en JSON, sans aucun texte autour, avec exactement ces champs : "
        '{"tool_name": "nom_court_snake_case", "description": "1 phrase claire", '
        '"example_query": "exemple concret de requête utilisateur", '
        '"example_output": "exemple concret de sortie attendue", '
        '"routing_examples": ["paraphrase 1", "paraphrase 2", "paraphrase 3", "paraphrase 4"]}\n\n'
        "routing_examples : 4 à 6 façons DIFFÉRENTES et réalistes dont un utilisateur "
        "pourrait formuler cette même requête en conversation naturelle (pas de variations "
        "triviales du même mot-à-mot — varie la structure de phrase, le niveau de langue, "
        "les mots utilisés)."
    )
    return _extract_json(_ask_claude(prompt, timeout=60))


_TOOL_CONSTRAINTS = (
    "Contraintes strictes, à respecter impérativement :\n"
    "- Un seul fichier autonome, sans dépendance au reste du dépôt Astroport.ONE\n"
    "- Expose EXACTEMENT : def run(query: str) -> str\n"
    "- Toute requête réseau (requests.get/post) DOIT avoir un paramètre timeout\n"
    "- INTERDIT (bloqué par une analyse statique du code, pas juste une consigne) : "
    "eval, exec, compile, __import__, getattr, setattr, delattr, vars, globals, locals, "
    "shell=True (sur n'importe quel appel), tout import de subprocess/ctypes/pickle/"
    "importlib/multiprocessing, et tout appel os.system/os.popen/os.fork/os.exec*/os.spawn*\n"
    "- N'utilise JAMAIS de sous-processus ou de commande shell pour cette tâche — "
    "requests (HTTP) suffit toujours pour appeler une API publique\n"
    "- Gérer les erreurs réseau/API avec un retour texte clair, jamais une exception non attrapée, "
    "MAIS ce message d'erreur doit inclure le détail technique réel (ex: f\"Erreur API : {e}\", "
    "ou le code HTTP retourné) — jamais un message générique du type \"problème avec l'API\" qui "
    "masquerait la vraie cause en cas d'échec\n"
    "- Bibliothèques autorisées : stdlib + requests uniquement\n"
    "- INTERDIT d'utiliser une API nécessitant une clé/authentification (ex: OpenWeatherMap "
    "avec appid), et INTERDIT de coder en dur un placeholder du type \"YOUR_API_KEY\" — ce "
    "code tourne dans un environnement automatisé sans accès à des secrets externes. "
    "Utilise exclusivement des API publiques sans authentification (ex: wttr.in pour la "
    "météo au format texte simple : https://wttr.in/VILLE?format=3, sans clé requise)\n"
)


def generate_tool_code(spec, previous_code=None, error_output=None):
    if previous_code and error_output:
        prompt = (
            f"Le code suivant a échoué (test ou garde-fou de sécurité) :\n\n"
            f"```python\n{previous_code}\n```\n\nErreur :\n{error_output[:1500]}\n\n"
            "Identifie d'abord précisément la ligne et la cause racine du problème "
            "(pas juste une reformulation de l'erreur), PUIS corrige le code en "
            f"conséquence — ne te contente pas de réécrire une variante proche du même bug. "
            f"{_TOOL_CONSTRAINTS}\n"
            "Réponds avec ton analyse en commentaire au début, puis le code Python corrigé "
            "dans un bloc ```python ... ```."
        )
    else:
        prompt = (
            f"Écris un outil Python pour : {spec['description']}\n"
            f"Exemple de requête : {spec['example_query']}\n"
            f"Exemple de sortie attendue : {spec['example_output']}\n\n"
            f"{_TOOL_CONSTRAINTS}\n"
            "Réponds avec le code Python dans un bloc ```python ... ```."
        )
    return _extract_code(_ask_claude(prompt, timeout=120))


def generate_test_code(spec, tool_module):
    prompt = (
        f"Écris un test pytest pour un module Python nommé '{tool_module}' qui expose "
        f"def run(query: str) -> str, importable via : from {tool_module} import run\n"
        f"Description de l'outil : {spec['description']}\n"
        f"Exemple de requête : {spec['example_query']}\n"
        f"Exemple de sortie attendue (approximative) : {spec['example_output']}\n\n"
        "Écris au moins un test qui appelle run() avec l'exemple de requête et vérifie "
        "que le résultat est une chaîne non vide et pertinente. Utilise des assertions "
        "souples (longueur, présence de mots-clés) — PAS d'égalité stricte avec une "
        "valeur exacte qui dépendrait d'une API externe en temps réel (ex: température "
        "du jour). Si l'outil peut échouer proprement (API indisponible), teste aussi "
        "que le message d'erreur retourné est une chaîne non vide plutôt qu'une exception.\n\n"
        "Réponds avec le code Python du test dans un bloc ```python ... ```."
    )
    return _extract_code(_ask_claude(prompt, timeout=90))


def _bwrap_available():
    from shutil import which
    return which("bwrap") is not None


def _prlimit_available():
    from shutil import which
    return which("prlimit") is not None


# bwrap isole réseau/filesystem mais ne plafonne ni mémoire ni nombre de
# process : un test généré par IA qui alloue en boucle peut faire OOM-killer
# la station entière (pas juste le sandbox) avant que le timeout de 60s
# n'intervienne. prlimit pose ces limites au niveau rlimit — héritées par
# bwrap et tous ses enfants (pytest, sous-process) — sans dépendre d'un
# service systemd --user (souvent absent sur nœuds légers / conteneurs).
_SANDBOX_MEM_LIMIT_BYTES = 512 * 1024 * 1024
_SANDBOX_NPROC_LIMIT = 64


def _run_pytest_in_worktree(worktree_path, test_file_abs, extra_pythonpath):
    """Exécute pytest isolé via bubblewrap (bwrap) — le garde-fou statique
    (_static_safety_check) ne bloque que des patterns textuels évidents et est
    trivialement contournable (ex: getattr(__builtins__, 'ev'+'al', ...)) ;
    l'isolation OS est la vraie ligne de défense pour du code généré par IA.
    --unshare-net : aucun accès réseau pendant le test (les tests générés
    doivent utiliser des assertions souples sans vraie requête, voir
    generate_test_code) — bloque aussi une éventuelle exfiltration.
    --ro-bind sur les libs système : rien d'écrivable hors le worktree lui-même.
    Pas de bind sur $HOME/~/.zen/le reste du dépôt : le code généré n'y a pas
    accès. --die-with-parent : pas de processus orphelin si pytest timeout.
    prlimit (si disponible) plafonne mémoire et nombre de process — voir
    _SANDBOX_MEM_LIMIT_BYTES."""
    if not _bwrap_available():
        return False, ("bwrap introuvable — bubblewrap est requis pour exécuter le code généré "
                        "de façon isolée (apt install bubblewrap). Rien n'est exécuté sans sandbox.")
    # pytest/requests vivent dans le venv ~/.astro (même auto-réinvocation
    # qu'en tête de ce fichier) — sys.executable le reflète déjà si présent.
    python_bin = sys.executable
    venv_root = os.path.expanduser("~/.astro")
    bwrap_venv_args = ["--ro-bind-try", venv_root, venv_root] if os.path.exists(venv_root) else []
    env = {"PYTHONPATH": extra_pythonpath, "PATH": os.path.dirname(python_bin) + ":/usr/bin:/bin"}
    cmd = [
        "bwrap",
        "--unshare-net", "--unshare-pid",
        "--ro-bind", "/usr", "/usr",
        "--ro-bind", "/lib", "/lib",
        "--ro-bind-try", "/lib64", "/lib64",
        "--ro-bind-try", "/etc/alternatives", "/etc/alternatives",
        *bwrap_venv_args,
        # tmpfs /tmp AVANT le bind du worktree : worktree_path vit sous
        # tempfile.gettempdir() (voir arbor_self_improve.py::_create_worktree)
        # — le monter dans l'autre ordre masquerait le bind sous le tmpfs.
        "--tmpfs", "/tmp",
        "--bind", worktree_path, worktree_path,
        "--proc", "/proc",
        "--dev", "/dev",
        "--chdir", worktree_path,
        "--die-with-parent",
        "--",
        python_bin, "-m", "pytest", test_file_abs, "-v", "--tb=short",
    ]
    mem_capped = _prlimit_available()
    if mem_capped:
        cmd = ["prlimit", f"--as={_SANDBOX_MEM_LIMIT_BYTES}",
               f"--nproc={_SANDBOX_NPROC_LIMIT}", "--"] + cmd
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60, env=env)
        output = result.stdout + result.stderr
        if not mem_capped:
            output += "\n[garde-fou] prlimit introuvable — test exécuté sans plafond mémoire/process (apt install util-linux)."
        return result.returncode == 0, output
    except subprocess.TimeoutExpired:
        return False, "Timeout (60s) — le test ou l'outil a probablement bloqué (réseau sans timeout ?)"
    except Exception as e:
        return False, f"Erreur d'exécution pytest (bwrap) : {e}"


def _generate_ai_summary(spec, need_description, code, test_code, iterations):
    prompt = (
        "Résume en 3-4 lignes, pour un capitaine non-développeur, ce que fait ce code "
        "Python et comment il a été validé. Sois concret et direct, pas de jargon inutile.\n\n"
        f"Besoin d'origine : {need_description}\n"
        f"Description prévue : {spec.get('description', '?')}\n"
        f"Nombre de tentatives avant succès : {iterations}/{MAX_ITERATIONS}\n\n"
        f"Code (extrait) :\n```python\n{code[:1500]}\n```\n\n"
        f"Test (extrait) :\n```python\n{test_code[:600]}\n```"
    )
    return _ask_claude(prompt, timeout=60) or "(résumé indisponible)"


def _write_tool_manifest(manifest_path, tool_module, spec, need_description, summary, attempts):
    """Manifeste d'audit humain à côté de l'outil — même esprit que SKILL.md
    (LifeOS) : description avec déclencheur explicite ("USE WHEN"), niveau
    d'accès RÉEL (celui appliqué par _register_arbor_tool à l'activation :
    ACCESS_ANY tant que le capitaine ne le restreint pas explicitement — pas
    un palier inventé ici), et traçabilité de la génération. Committé dans le
    même commit que l'outil, donc lu par le capitaine avant activate_tool()."""
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    description = spec.get("description", "").strip()
    example_query = spec.get("example_query", "").strip()
    frontmatter = (
        "---\n"
        f"name: {tool_module}\n"
        f"description: \"{description} USE WHEN l'utilisateur demande quelque chose "
        f"comme : « {example_query} »\"\n"
        "min_access: 0\n"
        "source: arbor\n"
        f"generated_at: {generated_at}\n"
        f"attempts: {attempts}/{MAX_ITERATIONS}\n"
        "---\n"
    )
    routing_examples = [str(e).strip() for e in (spec.get("routing_examples") or []) if str(e).strip()]
    routing_block = ""
    if routing_examples:
        examples_list = "\n".join(f"- {e}" for e in routing_examples)
        routing_block = (
            "\nExemples de routage (paraphrases pour le matching sémantique) :\n"
            f"{examples_list}\n"
        )
    body = (
        f"\nBesoin d'origine : {need_description}\n\n"
        f"Exemple de requête : {example_query}\n"
        f"Exemple de sortie attendue : {spec.get('example_output', '').strip()}\n"
        f"{routing_block}\n"
        f"Résumé :\n{summary}\n"
    )
    with open(manifest_path, "w", encoding="utf-8") as f:
        f.write(frontmatter + body)


def _notify_captain(message):
    captain_email = os.environ.get("CAPTAINEMAIL", "").strip()
    if not captain_email:
        print("⚠️ CAPTAINEMAIL absent de l'environnement — notification sautée.")
        return False
    nsec = _node_nsec()
    captain_hex = bwc._owner_hex(captain_email)
    if not nsec or not captain_hex:
        print("⚠️ NODE nsec ou HEX capitaine introuvable — notification sautée.")
        return False
    script = os.path.join(REPO_ROOT, "tools", "nostr_send_secure_dm.py")
    try:
        proc = subprocess.run(
            [bwc.PYTHON_BIN, script, "--nsec-stdin", captain_hex, message, "wss://relay.copylaradio.com",
             "--ttl-days", "14"],
            input=nsec + "\n", capture_output=True, text=True, timeout=15,
        )
        return proc.returncode == 0
    except Exception as e:
        print(f"⚠️ Échec envoi notification capitaine : {e}")
        return False


def forge_tool(need_description, slug=None, notify_captain=False):
    if not claude_available():
        print("❌ claude CLI introuvable — la génération de code nécessite Claude "
              "(les modèles Ollama locaux se sont montrés trop limités pour l'auto-correction).\n"
              "   Configure-le d'abord : bash claude.vscodium.setup.sh setup   (ou migrate)")
        return None

    print(f"🔨 Spec pour : {need_description}")
    spec = generate_spec(need_description)
    if not spec or not spec.get("description"):
        print("❌ Échec génération de spec — abandon.")
        return None

    tool_module = f"tool_{_slugify(slug or spec.get('tool_name', 'outil'), 30)}"
    print(f"📋 Spec : {json.dumps(spec, ensure_ascii=False)}")
    print(f"📦 Module : {tool_module}")

    worktree_path, branch_name = _create_worktree(f"tool-{tool_module}")
    tool_dir = os.path.join(worktree_path, "IA", "tools_generated")
    test_dir = os.path.join(worktree_path, "IA", "tests", "generated")
    os.makedirs(tool_dir, exist_ok=True)
    os.makedirs(test_dir, exist_ok=True)
    tool_path = os.path.join(tool_dir, f"{tool_module}.py")
    test_path = os.path.join(test_dir, f"test_{tool_module}.py")

    code = generate_tool_code(spec)
    test_code = generate_test_code(spec, tool_module)

    passed, last_output, attempt = False, "", 0
    for attempt in range(1, MAX_ITERATIONS + 1):
        print(f"\n── Tentative {attempt}/{MAX_ITERATIONS} ──")

        issues = _static_safety_check(code)
        if issues:
            print(f"⚠️ Garde-fou statique : {issues}")
            code = generate_tool_code(spec, previous_code=code,
                                       error_output="Violations de sécurité détectées : " + "; ".join(issues))
            continue

        with open(tool_path, "w", encoding="utf-8") as f:
            f.write(code)
        with open(test_path, "w", encoding="utf-8") as f:
            f.write(test_code)

        passed, last_output = _run_pytest_in_worktree(worktree_path, test_path, tool_dir)
        print(last_output[-1500:])
        if passed:
            print("✅ Tests passants")
            break
        print("❌ Tests en échec — régénération avec le contexte d'erreur...")
        code = generate_tool_code(spec, previous_code=code, error_output=last_output)

    if not passed:
        print(f"\n❌ Échec après {MAX_ITERATIONS} tentatives — rien n'est committé.")
        _run_git(["worktree", "remove", "--force", worktree_path], REPO_ROOT)
        if notify_captain:
            msg = (
                f"🔨 Forge à outils BRO — échec\n\n"
                f"Besoin : {need_description}\n"
                f"Tentatives : {MAX_ITERATIONS}/{MAX_ITERATIONS}, toutes en échec.\n\n"
                f"Dernière erreur :\n{last_output[-500:]}\n\n"
                "Rien n'a été committé — aucune branche créée."
            )
            _notify_captain(msg) and print("📨 Capitaine notifié de l'échec.")
        return None

    rel_tool = os.path.relpath(tool_path, worktree_path)
    rel_test = os.path.relpath(test_path, worktree_path)
    summary = _generate_ai_summary(spec, need_description, code, test_code, attempt)

    manifest_path = os.path.join(tool_dir, f"{tool_module}.md")
    _write_tool_manifest(manifest_path, tool_module, spec, need_description, summary, attempt)
    rel_manifest = os.path.relpath(manifest_path, worktree_path)

    _run_git(["add", rel_tool, rel_test, rel_manifest], worktree_path)
    _run_git(["commit", "-m",
              f"arbor: génère {tool_module}\n\nBesoin : {need_description}\n\n{summary}\n\n"
              f"Validé {attempt}/{MAX_ITERATIONS} tentative(s) — aucun fichier existant modifié."],
             worktree_path)

    print(f"\n✅ Outil généré et testé — branche {branch_name}")
    print(f"   Fichiers : {rel_tool}, {rel_test}, {rel_manifest}")

    if notify_captain:
        msg = (
            f"🔨 Forge à outils BRO — nouvel outil prêt à relire\n\n"
            f"Besoin : {need_description}\n\n"
            f"{summary}\n\n"
            f"Fichiers (nouveaux uniquement, rien d'existant modifié) :\n"
            f"  - {rel_tool}\n  - {rel_test}\n  - {rel_manifest}\n\n"
            f"Validé après {attempt}/{MAX_ITERATIONS} tentative(s) de test.\n\n"
            f"Branche  : {branch_name}\n"
            f"Worktree : {worktree_path}\n"
            f"Revue    : cd {REPO_ROOT} && git diff master...{branch_name}\n\n"
            "Cet outil n'est PAS encore connecté à BRO — à vous de décider comment/où "
            "l'appeler, puis de merger."
        )
        if _notify_captain(msg):
            print("📨 Capitaine notifié.")
        else:
            print("⚠️ Notification capitaine non envoyée (voir logs ci-dessus).")

    return {"branch": branch_name, "worktree": worktree_path, "tool": rel_tool,
            "test": rel_test, "manifest": rel_manifest, "summary": summary, "attempts": attempt}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--need", required=True, help="Description en langage naturel du besoin")
    parser.add_argument("--slug", default=None, help="Nom court pour le fichier (sinon déduit par le LLM)")
    parser.add_argument("--notify-captain", action="store_true",
                         help="Envoie un DM NODE au capitaine (succès ou échec)")
    args = parser.parse_args()
    forge_tool(args.need, slug=args.slug, notify_captain=args.notify_captain)


if __name__ == "__main__":
    main()
