#!/usr/bin/env python3
"""
arbor_scraper_forge.py — Forge à scrapers Arbor : génère et maintient automatiquement
les scrapers de domaines (scripts Python exécutés lors de la synchronisation uDRIVE
et des cycles BRO-WATCH quotidiens).

Quatre piliers :

1. CONTRAT D'INTERFACE STRICT
   Contrairement aux outils run(query)->str, les scrapers exposent :
     def run(cookie_file_path: str, target_domain: str) -> list
   avec sortie JSON stricte [{"username": "...", "text": "...", "url": "..."}]
   compatible bro_watch_core.process_watch_digest().
   Contrat vérifié par analyse AST (pas juste une consigne).

2. INJECTION DU CONTEXTE HTML (vital pour la génération)
   Avant tout appel LLM, la forge utilise Playwright pour charger la page cible
   avec les cookies réels de l'utilisateur et injecte le HTML de la page dans le
   prompt Claude — le modèle ne code jamais à l'aveugle sur des sélecteurs CSS
   qu'il ne peut pas voir.

3. BOUCLE DE SELF-HEALING (auto-guérison)
   Mode --heal DOMAIN : récupère le code existant du scraper, capture le nouveau
   HTML de la page, demande à Claude d'identifier ce qui a changé dans le DOM
   (nouveaux noms de classes CSS, nouvelle structure) et de mettre à jour les
   sélecteurs. Déclencheur automatique dans bro/media.py après 3 cycles en échec.

4. SANDBOXING AVEC RÉSEAU
   Contrairement aux outils classiques (--unshare-net), les scrapers testent
   contre le site réel — bwrap sans --unshare-net, mais filesystem hôte en
   lecture seule et prlimit mémoire/processus maintenus.

Gouvernance : même discipline qu'arbor_tool_forge.py — branche isolée, jamais
de merge automatique, notification capitaine, MAX_ITERATIONS tentatives avant
abandon propre.

Usage :
    python3 arbor_scraper_forge.py --owner-email EMAIL --domain mastodon.social
    python3 arbor_scraper_forge.py --owner-email EMAIL --domain mastodon.social --url https://mastodon.social/notifications
    python3 arbor_scraper_forge.py --heal mastodon.social --owner-email EMAIL
    python3 arbor_scraper_forge.py --heal mastodon.social --owner-email EMAIL --error "Cookie expiré"
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
import time
import argparse
import subprocess
from datetime import datetime, timezone

sys.path.insert(0, os.path.expanduser("~/.zen/Astroport.ONE/IA"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bro_watch_core as bwc
from arbor_self_improve import _create_worktree, _slugify, _run_git, _node_nsec, REPO_ROOT
from arbor_tool_forge import (
    _extract_code, _ask_claude, _notify_captain, claude_available,
    _bwrap_available, _prlimit_available,
    _FORBIDDEN_CALL_NAMES, _FORBIDDEN_IMPORT_MODULES, _FORBIDDEN_OS_ATTRS,
    _FORBIDDEN_DUNDER_NAMES, _attr_root_name, _collect_import_aliases,
    _SANDBOX_MEM_LIMIT_BYTES, _SANDBOX_NPROC_LIMIT, CODE_BLOCK_RE,
)

MAX_ITERATIONS = 3
HTML_CONTEXT_MAX_CHARS = 12000

# ─── Pilier 1 : Contrat d'interface strict ─────────────────────────────────

_SCRAPER_CONTRACT = (
    "CONTRAT STRICT (vérifié par analyse AST — pas juste une consigne) :\n"
    "- SIGNATURE EXACTE :  def run(cookie_file_path: str, target_domain: str) -> list\n"
    "- SORTIE : liste Python de dicts, chaque dict ayant exactement ces clés :\n"
    '  {"username": str, "text": str, "url": str}\n'
    "  (url peut être None, mais username et text doivent être des str non vides)\n"
    "- Retourne [] si aucun item trouvé — jamais None, jamais d'exception non attrapée\n"
    "- Si le cookie est expiré (page redirige vers /login, /sign_in, /auth/) :\n"
    "    raise RuntimeError('cookie_expired')\n"
    "- Si le site est inaccessible (timeout réseau, 5xx) :\n"
    "    raise RuntimeError('network_error')\n"
    "  Ces RuntimeError sont capturées par le déclencheur de self-healing\n"
)

_SCRAPER_IMPORTS = (
    "Imports AUTORISÉS (rien d'autre) :\n"
    "- playwright.sync_api  (sync_playwright)\n"
    "- playwright_stealth  (Stealth — optionnel, pour contourner les anti-bots)\n"
    "- bs4  (BeautifulSoup — optionnel, si le parsing HTML est plus simple ainsi)\n"
    "- json, re, datetime, time, typing, urllib.parse\n"
    "INTERDIT : subprocess, ctypes, pickle, shelve, marshal, importlib, multiprocessing,\n"
    "           eval, exec, compile, shell=True, os.system, os.popen, os.fork, os.exec*\n"
    "- Le cookie est au format Netscape (7 colonnes séparées par des tabulations)\n"
    "  → inclure la fonction _parse_cookies_netscape ci-dessous dans le code\n"
)

# Template de parseur cookie à inclure dans chaque scraper généré
_COOKIE_PARSER_TEMPLATE = '''\
def _parse_cookies_netscape(filepath, domain_filter):
    cookies = []
    try:
        with open(filepath, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split("\\t")
                if len(parts) < 7:
                    continue
                col_domain, col_path = parts[0], parts[2]
                col_secure = parts[3].strip().upper() == "TRUE"
                col_name, col_value = parts[5], "\\t".join(parts[6:])
                if domain_filter not in col_domain:
                    continue
                pw_domain = col_domain if col_domain.startswith(".") else f".{col_domain}"
                cookies.append({
                    "name": col_name, "value": col_value, "domain": pw_domain,
                    "path": col_path or "/", "secure": col_secure,
                    "httpOnly": False, "sameSite": "Lax",
                })
    except Exception:
        pass
    return cookies
'''

_SCRAPER_CONSTRAINTS = (
    f"{_SCRAPER_CONTRACT}\n"
    f"{_SCRAPER_IMPORTS}\n"
    "Autres contraintes Playwright :\n"
    "- Utiliser `with sync_playwright() as pw:` (context manager — fermeture garantie)\n"
    "- timeout=30000 pour goto(), timeout=15000 pour wait_for_selector()\n"
    "- Capturer TimeoutError : retourner [] plutôt que de propager\n"
    "- Vérifier si la page est une page de login : if '/login' in page.url or '/sign_in' in page.url:\n"
    "      raise RuntimeError('cookie_expired')\n"
    "- Ajouter --no-sandbox et --disable-dev-shm-usage dans browser launch args\n"
    "- Un seul fichier autonome, sans dépendance au reste du dépôt Astroport.ONE\n"
    f"\nInclure cette fonction dans le code (copier telle quelle) :\n```python\n{_COOKIE_PARSER_TEMPLATE}```\n"
)


# ─── Pilier 2 : Capture du contexte HTML ───────────────────────────────────

def _capture_page_context(url, cookie_file_path, domain, max_chars=HTML_CONTEXT_MAX_CHARS):
    """Charge la page avec Playwright + les cookies de l'utilisateur et retourne
    le HTML source tronqué pour injection dans le prompt (Pilier 2).

    Sans ce contexte, Claude ne peut pas identifier les sélecteurs CSS corrects."""
    try:
        from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout
    except ImportError:
        return (
            f"[AVERTISSEMENT: playwright non disponible — génération sans contexte HTML]\n"
            "Installe playwright : pip install playwright && playwright install chromium"
        )

    def _parse_netscape(filepath, domain_filter):
        cookies = []
        try:
            with open(filepath, encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    parts = line.split("\t")
                    if len(parts) < 7:
                        continue
                    col_domain, col_path = parts[0], parts[2]
                    col_secure = parts[3].strip().upper() == "TRUE"
                    col_name, col_value = parts[5], "\t".join(parts[6:])
                    if domain_filter not in col_domain:
                        continue
                    pw_domain = col_domain if col_domain.startswith(".") else f".{col_domain}"
                    cookies.append({
                        "name": col_name, "value": col_value, "domain": pw_domain,
                        "path": col_path or "/", "secure": col_secure,
                        "httpOnly": False, "sameSite": "Lax",
                    })
        except Exception:
            pass
        return cookies

    cookies = _parse_netscape(cookie_file_path, domain)
    if not cookies:
        return (
            f"[AVERTISSEMENT: aucun cookie trouvé pour {domain} dans {cookie_file_path}]\n"
            "Génération sans contexte HTML authentifié."
        )

    try:
        with sync_playwright() as pw:
            browser = pw.chromium.launch(
                headless=True,
                args=["--no-sandbox", "--disable-dev-shm-usage"],
            )
            ctx = browser.new_context(
                viewport={"width": 1280, "height": 900},
                user_agent=(
                    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
                ),
                locale="fr-FR",
            )
            ctx.add_cookies(cookies)
            page = ctx.new_page()
            try:
                page.goto(url, timeout=30000, wait_until="domcontentloaded")
                time.sleep(3)
                try:
                    page.wait_for_load_state("networkidle", timeout=10000)
                except Exception:
                    pass
                final_url = page.url
                title = page.title()
                html = page.content()
            except PWTimeout:
                browser.close()
                return f"[ERREUR: timeout en chargeant {url}]"
            except Exception as e:
                browser.close()
                return f"[ERREUR: {e}]"
            browser.close()

        # Tronquer intelligemment : début (structure/CSS) + fin (contenu frais)
        if len(html) > max_chars:
            half = max_chars // 2
            return (
                f"URL finale : {final_url}\nTitre : {title}\n\n"
                f"[HTML début — {half} chars]\n{html[:half]}\n\n"
                f"[HTML fin (contenu récent) — {half} chars]\n{html[-half:]}"
            )
        return f"URL finale : {final_url}\nTitre : {title}\n\n{html}"

    except Exception as e:
        return f"[ERREUR playwright: {e}]"


# ─── Sécurité : vérification statique adaptée aux scrapers ─────────────────

# Les scrapers peuvent importer playwright et bs4 — modules non-bloqués par défaut
# dans _FORBIDDEN_IMPORT_MODULES d'arbor_tool_forge, mais requests est aussi autorisé
# (pour les scrapers d'API JSON qui n'ont pas besoin d'un navigateur).
# subprocess, ctypes, pickle, importlib... restent interdits.

def _static_safety_check_scraper(code):
    """Sécurité AST pour scrapers : même règles qu'arbor_tool_forge._static_safety_check
    + vérification du contrat de signature run(cookie_file_path, target_domain) -> list."""
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
            for kw in node.keywords:
                if kw.arg == "shell" and isinstance(kw.value, ast.Constant) and kw.value.value is True:
                    issues.append("shell=True interdit")

        elif isinstance(node, ast.Import):
            for alias in node.names:
                top_module = alias.name.split(".")[0]
                # playwright, bs4, requests sont autorisés pour les scrapers
                if top_module in _FORBIDDEN_IMPORT_MODULES:
                    issues.append(f"import {alias.name} interdit")

        elif isinstance(node, ast.ImportFrom):
            if node.module:
                top = node.module.split(".")[0]
                if top in _FORBIDDEN_IMPORT_MODULES:
                    issues.append(f"from {node.module} import ... interdit")

        elif isinstance(node, ast.Name) and node.id in _FORBIDDEN_DUNDER_NAMES:
            issues.append(f"accès interdit : {node.id}")
        elif isinstance(node, ast.Attribute) and node.attr in _FORBIDDEN_DUNDER_NAMES:
            issues.append(f"accès interdit : .{node.attr}")
        elif isinstance(node, ast.Attribute) and node.attr == "modules" \
                and _resolved_root(node) == "sys":
            issues.append("accès interdit : sys.modules")

    if ".." in code and re.search(r"\.\./", code):
        issues.append("chemin relatif parent (../) suspect")

    # Vérification du contrat de signature (Pilier 1)
    run_funcs = [
        node for node in ast.walk(tree)
        if isinstance(node, ast.FunctionDef) and node.name == "run"
    ]
    if not run_funcs:
        issues.append("fonction run() obligatoire introuvable dans le code généré")
    else:
        run_func = run_funcs[0]
        arg_names = [a.arg for a in run_func.args.args]
        if arg_names != ["cookie_file_path", "target_domain"]:
            issues.append(
                f"signature incorrecte : run({', '.join(arg_names)}) — "
                "attendu : run(cookie_file_path, target_domain)"
            )

    return issues


# ─── Pilier 4 : Sandbox bwrap AVEC réseau ──────────────────────────────────

def _run_pytest_scraper_in_worktree(worktree_path, test_file_abs, extra_pythonpath, cookie_file_path=None):
    """Pytest sandboxé via bwrap, SANS --unshare-net (Pilier 4).

    Raison du réseau ouvert : les scrapers testent contre le site réel avec les
    cookies de l'utilisateur. Compensation de la surface d'attaque élargie :
    - Filesystem hôte reste en lecture seule (--ro-bind)
    - cookie_file_path monté en lecture seule (répertoire parent seulement)
    - prlimit mémoire + nproc maintenus si disponibles
    - /etc/resolv.conf et /etc/ssl montés en lecture seule (nécessaires pour HTTPS)"""
    if not _bwrap_available():
        return False, (
            "bwrap introuvable — bubblewrap requis pour exécuter le code généré "
            "de façon isolée (apt install bubblewrap). Rien n'est exécuté sans sandbox."
        )
    python_bin = sys.executable
    venv_root = os.path.expanduser("~/.astro")
    bwrap_venv_args = ["--ro-bind-try", venv_root, venv_root] if os.path.exists(venv_root) else []

    # Cookie file : monter le répertoire parent en lecture seule
    cookie_args = []
    if cookie_file_path and os.path.isfile(cookie_file_path):
        cookie_dir = os.path.dirname(os.path.abspath(cookie_file_path))
        cookie_args = ["--ro-bind-try", cookie_dir, cookie_dir]

    env = {
        "PYTHONPATH": extra_pythonpath,
        "PATH": os.path.dirname(python_bin) + ":/usr/bin:/bin",
    }
    cmd = [
        "bwrap",
        # Pas de --unshare-net : scrapers testés contre le site réel
        "--unshare-pid",
        "--ro-bind", "/usr", "/usr",
        "--ro-bind", "/lib", "/lib",
        "--ro-bind-try", "/lib64", "/lib64",
        "--ro-bind-try", "/etc/alternatives", "/etc/alternatives",
        "--ro-bind-try", "/etc/ssl", "/etc/ssl",
        "--ro-bind-try", "/etc/resolv.conf", "/etc/resolv.conf",
        "--ro-bind-try", "/etc/nsswitch.conf", "/etc/nsswitch.conf",
        "--ro-bind-try", "/etc/hosts", "/etc/hosts",
        *bwrap_venv_args,
        *cookie_args,
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
        cmd = [
            "prlimit", f"--as={_SANDBOX_MEM_LIMIT_BYTES}",
            f"--nproc={_SANDBOX_NPROC_LIMIT}", "--",
        ] + cmd
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120, env=env)
        output = result.stdout + result.stderr
        if not mem_capped:
            output += (
                "\n[garde-fou] prlimit introuvable — test sans plafond mémoire/process "
                "(apt install util-linux)."
            )
        return result.returncode == 0, output
    except subprocess.TimeoutExpired:
        return False, "Timeout (120s) — le test a bloqué (réseau ou site lent ?)"
    except Exception as e:
        return False, f"Erreur d'exécution pytest (bwrap) : {e}"


# ─── Génération du code et du test ─────────────────────────────────────────

def generate_scraper_code(domain, target_url, html_context, previous_code=None, error_output=None):
    """Génère le code du scraper avec injection du contexte HTML (Pilier 2).
    Mode guérison si previous_code + error_output fournis (Pilier 3)."""
    if previous_code and error_output:
        prompt = (
            f"Le scraper Python ci-dessous pour le domaine '{domain}' a échoué.\n\n"
            f"Code existant :\n```python\n{previous_code}\n```\n\n"
            f"Erreur / contexte de panne :\n{error_output[:2000]}\n\n"
            f"Voici le code source ACTUEL de la page (nouveau HTML) :\n"
            f"```html\n{html_context[:8000]}\n```\n\n"
            "Identifie d'abord PRÉCISÉMENT ce qui a changé dans le DOM (nouveaux noms "
            "de classes CSS, nouvelle structure d'éléments) par rapport au code existant, "
            "PUIS corrige le code en conséquence — ne pas se contenter de réécrire une "
            "variante proche du même bug.\n\n"
            f"{_SCRAPER_CONSTRAINTS}\n"
            "Réponds avec ton analyse en commentaire au début, puis le code corrigé "
            "dans un bloc ```python ... ```."
        )
    else:
        prompt = (
            f"Écris un scraper Python pour le domaine '{domain}'.\n\n"
            f"URL cible : {target_url}\n\n"
            f"Voici le code source HTML de la page chargée avec les cookies de l'utilisateur :\n"
            f"```html\n{html_context[:10000]}\n```\n\n"
            "En analysant ce HTML, identifie les sélecteurs CSS/DOM qui permettent d'extraire "
            "les posts/messages récents (auteur, texte, URL du post).\n\n"
            f"{_SCRAPER_CONSTRAINTS}\n"
            "Réponds avec le code Python dans un bloc ```python ... ```."
        )
    return _extract_code(_ask_claude(prompt, timeout=180))


def generate_scraper_test(domain, module_name, cookie_file_path=None):
    """Génère un test pytest avec accès réseau réel si cookie disponible."""
    if cookie_file_path and os.path.isfile(cookie_file_path):
        cookie_hint = (
            f"Un fichier cookie réel est disponible : {cookie_file_path}\n"
            "Le test DOIT utiliser ce chemin pour tester l'extraction contre le site réel."
        )
    else:
        cookie_hint = (
            "Aucun fichier cookie disponible — écrire un test qui vérifie uniquement "
            "la signature et le type de retour en mockant playwright."
        )
    prompt = (
        f"Écris un test pytest pour un module Python '{module_name}' qui expose :\n"
        f"  def run(cookie_file_path: str, target_domain: str) -> list\n"
        f"Domaine cible : {domain}\n"
        f"{cookie_hint}\n\n"
        "Le test doit :\n"
        "1. Appeler run(cookie_file_path, domain) avec le vrai cookie si disponible\n"
        "2. Vérifier que le résultat est une liste (même vide — peut être normal)\n"
        "3. Si la liste est non-vide, vérifier que chaque item a 'username', 'text', 'url'\n"
        "4. Si run() lève RuntimeError, utiliser pytest.skip() (cookie peut avoir expiré)\n"
        "5. Ne jamais échouer sur une liste vide\n\n"
        "Réponds avec le code du test dans un bloc ```python ... ```."
    )
    return _extract_code(_ask_claude(prompt, timeout=90))


# ─── URL par défaut pour les domaines courants ─────────────────────────────

def _default_scraper_url(domain):
    """Déduit l'URL cible principale pour un domaine connu.
    Utilisé quand --url n'est pas précisé, et en mode heal pour recapturer le HTML."""
    lowered = domain.lower()
    # Instances Mastodon (ActivityPub)
    if any(s in lowered for s in ["mastodon", "fosstodon", "hachyderm", "chaos.social",
                                   "infosec.exchange", "social.coop", "mstdn"]):
        return f"https://{domain}/notifications"
    # Forums Discourse
    if "forum." in lowered or "discourse" in lowered or "community." in lowered:
        return f"https://{domain}/latest"
    # Fallback générique
    return f"https://{domain}"


# ─── Shell wrapper template ────────────────────────────────────────────────

def _shell_wrapper_content(domain, scraper_module):
    """Contenu du script bash d'entrée appelé par bro/media.py::_run_scraper_background.

    Le wrapper délègue à run_generated_scraper.py (runner générique) qui :
    - appelle run(cookie_file, domain) du scraper généré
    - appelle bro_watch_core.process_watch_digest()
    - retourne exit 0/1/2 selon le résultat (utilisé par le compteur d'échecs)"""
    runner = os.path.join(
        os.path.expanduser("~/.zen/Astroport.ONE/IA"),
        "scrapers", "generic", "run_generated_scraper.py",
    )
    return (
        "#!/bin/bash\n"
        f"# {domain} — Scraper généré par arbor_scraper_forge.py\n"
        f'SCRIPT_DIR="$(cd "$(dirname "${{BASH_SOURCE[0]}}")" && pwd)"\n'
        f'VENV_PYTHON="$HOME/.astro/bin/python3"\n'
        f'PYTHON="${{VENV_PYTHON:-python3}}"\n'
        f'[ -x "$VENV_PYTHON" ] && PYTHON="$VENV_PYTHON"\n'
        f'exec "$PYTHON" "{runner}" \\\n'
        f'    --player "$1" \\\n'
        f'    --cookie-file "$2" \\\n'
        f'    --domain "{domain}" \\\n'
        f'    --module "$SCRIPT_DIR/{scraper_module}.py"\n'
    )


# ─── Pilier 3 : Forge + Heal ───────────────────────────────────────────────

def forge_scraper(owner_email, domain, target_url=None, notify_captain=False):
    """Génère un scraper pour le domaine donné (Piliers 1-4).

    Workflow :
    1. Localise le cookie → capture HTML avec Playwright (Pilier 2)
    2. Génère code par Claude avec le HTML injecté (Pilier 1 : contrat strict)
    3. Vérifie statiquement (AST) + teste en bwrap avec réseau (Pilier 4)
    4. Si OK : commit dans worktree isolé, notifie capitaine"""
    if not claude_available():
        print("❌ claude CLI introuvable — voir claude.vscodium.setup.sh (setup/migrate).")
        return None

    from bro._shared import NOSTR_DIR
    cookie_file_path = os.path.join(NOSTR_DIR, owner_email, f".{domain}.cookie")
    if not os.path.isfile(cookie_file_path):
        print(f"❌ Cookie introuvable : {cookie_file_path}")
        return None

    target_url = target_url or _default_scraper_url(domain)
    slug = _slugify(domain, 30)
    scraper_module = f"scraper_{slug}"
    print(f"🌐 Capture du contexte HTML de {target_url}...")
    html_context = _capture_page_context(target_url, cookie_file_path, domain)
    if html_context.startswith("[ERREUR") or html_context.startswith("[AVERTISSEMENT"):
        print(f"⚠️ Contexte HTML : {html_context[:120]}")

    print(f"🔨 Forge scraper : {scraper_module}")
    worktree_path, branch_name = _create_worktree(f"scraper-{slug}")
    scraper_dir = os.path.join(worktree_path, "IA", "scrapers", domain)
    test_dir = os.path.join(worktree_path, "IA", "tests", "generated")
    os.makedirs(scraper_dir, exist_ok=True)
    os.makedirs(test_dir, exist_ok=True)

    scraper_path = os.path.join(scraper_dir, f"{scraper_module}.py")
    shell_path = os.path.join(scraper_dir, f"{domain}.sh")
    test_path = os.path.join(test_dir, f"test_{scraper_module}.py")

    print("🤖 Génération du code par Claude...")
    code = generate_scraper_code(domain, target_url, html_context)
    test_code = generate_scraper_test(domain, scraper_module, cookie_file_path)

    passed, last_output, attempt = False, "", 0
    for attempt in range(1, MAX_ITERATIONS + 1):
        print(f"\n── Tentative {attempt}/{MAX_ITERATIONS} ──")

        issues = _static_safety_check_scraper(code)
        if issues:
            print(f"⚠️ Garde-fou statique : {issues}")
            code = generate_scraper_code(
                domain, target_url, html_context,
                previous_code=code,
                error_output="Violations de sécurité/contrat : " + "; ".join(issues),
            )
            continue

        with open(scraper_path, "w", encoding="utf-8") as f:
            f.write(code)
        with open(test_path, "w", encoding="utf-8") as f:
            f.write(test_code)

        passed, last_output = _run_pytest_scraper_in_worktree(
            worktree_path, test_path, scraper_dir, cookie_file_path,
        )
        print(last_output[-2000:])
        if passed:
            print("✅ Tests passants")
            break
        print("❌ Tests en échec — régénération avec contexte d'erreur...")
        code = generate_scraper_code(
            domain, target_url, html_context,
            previous_code=code, error_output=last_output,
        )

    if not passed:
        print(f"\n❌ Échec après {MAX_ITERATIONS} tentatives — rien n'est committé.")
        _run_git(["worktree", "remove", "--force", worktree_path], REPO_ROOT)
        if notify_captain:
            _notify_captain(
                f"🔨 Forge à scrapers BRO — échec\n\n"
                f"Domaine : {domain}\nURL : {target_url}\n"
                f"Tentatives : {MAX_ITERATIONS}/{MAX_ITERATIONS}, toutes en échec.\n\n"
                f"Dernière erreur :\n{last_output[-500:]}\n\nRien n'a été committé."
            )
        return None

    with open(shell_path, "w", encoding="utf-8") as f:
        f.write(_shell_wrapper_content(domain, scraper_module))
    os.chmod(shell_path, 0o755)

    rel_scraper = os.path.relpath(scraper_path, worktree_path)
    rel_shell = os.path.relpath(shell_path, worktree_path)
    rel_test = os.path.relpath(test_path, worktree_path)

    _run_git(["add", rel_scraper, rel_shell, rel_test], worktree_path)
    _run_git(
        ["commit", "-m",
         f"arbor: génère scraper {domain}\n\n"
         f"URL cible : {target_url}\n\n"
         f"Validé {attempt}/{MAX_ITERATIONS} tentative(s) — aucun fichier existant modifié."],
        worktree_path,
    )

    print(f"\n✅ Scraper généré — branche {branch_name}")
    print(f"   Fichiers : {rel_scraper}, {rel_shell}, {rel_test}")

    if notify_captain:
        _notify_captain(
            f"🔨 Forge à scrapers BRO — nouveau scraper prêt\n\n"
            f"Domaine : {domain}\nURL : {target_url}\n\n"
            f"Fichiers (nouveaux uniquement) :\n"
            f"  - {rel_scraper}\n  - {rel_shell}\n  - {rel_test}\n\n"
            f"Validé après {attempt}/{MAX_ITERATIONS} tentative(s).\n\n"
            f"Branche  : {branch_name}\n"
            f"Worktree : {worktree_path}\n"
            f"Revue    : cd {REPO_ROOT} && git diff master...{branch_name}\n\n"
            "Ce scraper n'est PAS encore actif — à vous de décider de merger."
        )

    return {
        "branch": branch_name, "worktree": worktree_path,
        "scraper": rel_scraper, "shell": rel_shell, "test": rel_test,
        "attempts": attempt,
    }


def heal_scraper(owner_email, domain, error_output=None, target_url=None, notify_captain=False):
    """Mode réparation (Pilier 3) : met à jour un scraper dont le DOM a changé.

    Différences avec forge_scraper :
    - Récupère le code existant depuis le worktree (historique git)
    - Prompt spécifique : « identifie ce qui a changé » plutôt que « génère depuis zéro »
    - Branche nommée heal- au lieu de scraper-"""
    if not claude_available():
        print("❌ claude CLI introuvable.")
        return None

    from bro._shared import NOSTR_DIR
    cookie_file_path = os.path.join(NOSTR_DIR, owner_email, f".{domain}.cookie")
    if not os.path.isfile(cookie_file_path):
        print(f"❌ Cookie introuvable : {cookie_file_path}")
        return None

    target_url = target_url or _default_scraper_url(domain)
    slug = _slugify(domain, 30)
    scraper_module = f"scraper_{slug}"

    print(f"🔧 Mode réparation pour {domain} — capture du nouveau HTML depuis {target_url}...")
    html_context = _capture_page_context(target_url, cookie_file_path, domain)

    worktree_path, branch_name = _create_worktree(f"heal-{slug}")
    scraper_dir = os.path.join(worktree_path, "IA", "scrapers", domain)
    test_dir = os.path.join(worktree_path, "IA", "tests", "generated")
    os.makedirs(scraper_dir, exist_ok=True)
    os.makedirs(test_dir, exist_ok=True)

    scraper_path = os.path.join(scraper_dir, f"{scraper_module}.py")
    test_path = os.path.join(test_dir, f"test_{scraper_module}.py")

    # Le code existant est dans le worktree (branche depuis HEAD)
    existing_code = ""
    if os.path.isfile(scraper_path):
        try:
            with open(scraper_path, encoding="utf-8") as f:
                existing_code = f.read()
            print(f"✅ Scraper existant chargé ({len(existing_code)} chars)")
        except Exception as e:
            print(f"⚠️ Lecture scraper existant échouée : {e}")
    else:
        print(f"⚠️ Aucun scraper existant pour {domain} — régénération complète")

    code = generate_scraper_code(
        domain, target_url, html_context,
        previous_code=existing_code or None,
        error_output=error_output,
    )
    test_code = generate_scraper_test(domain, scraper_module, cookie_file_path)

    passed, last_output, attempt = False, "", 0
    for attempt in range(1, MAX_ITERATIONS + 1):
        print(f"\n── Tentative heal {attempt}/{MAX_ITERATIONS} ──")

        issues = _static_safety_check_scraper(code)
        if issues:
            print(f"⚠️ Garde-fou statique : {issues}")
            code = generate_scraper_code(
                domain, target_url, html_context,
                previous_code=code,
                error_output="Violations : " + "; ".join(issues),
            )
            continue

        with open(scraper_path, "w", encoding="utf-8") as f:
            f.write(code)
        with open(test_path, "w", encoding="utf-8") as f:
            f.write(test_code)

        passed, last_output = _run_pytest_scraper_in_worktree(
            worktree_path, test_path, scraper_dir, cookie_file_path,
        )
        print(last_output[-2000:])
        if passed:
            print("✅ Tests passants")
            break
        code = generate_scraper_code(
            domain, target_url, html_context,
            previous_code=code, error_output=last_output,
        )

    if not passed:
        print(f"\n❌ Réparation échouée après {MAX_ITERATIONS} tentatives.")
        _run_git(["worktree", "remove", "--force", worktree_path], REPO_ROOT)
        if notify_captain:
            err_hint = (error_output or "inconnue")[:300]
            _notify_captain(
                f"🔧 Self-healing BRO — échec réparation\n\n"
                f"Domaine : {domain}\n"
                f"Erreur d'origine : {err_hint}\n"
                f"Tentatives : {MAX_ITERATIONS}, toutes en échec.\n\n"
                f"Dernière erreur pytest :\n{last_output[-500:]}"
            )
        return None

    rel_scraper = os.path.relpath(scraper_path, worktree_path)
    rel_test = os.path.relpath(test_path, worktree_path)

    _run_git(["add", rel_scraper, rel_test], worktree_path)
    _run_git(
        ["commit", "-m",
         f"arbor: répare scraper {domain} (self-healing)\n\n"
         f"Erreur déclenchante : {(error_output or 'inconnue')[:200]}\n\n"
         f"Validé {attempt}/{MAX_ITERATIONS} tentative(s)."],
        worktree_path,
    )

    print(f"\n✅ Scraper réparé — branche {branch_name}")

    if notify_captain:
        err_hint = (error_output or "inconnue")[:200]
        _notify_captain(
            f"🔧 Self-healing BRO — scraper réparé\n\n"
            f"Domaine : {domain}\n"
            f"Erreur déclenchante : {err_hint}\n\n"
            f"Branche  : {branch_name}\n"
            f"Worktree : {worktree_path}\n"
            f"Revue    : cd {REPO_ROOT} && git diff master...{branch_name}\n\n"
            "À merger manuellement pour activer la réparation."
        )

    return {
        "branch": branch_name, "worktree": worktree_path,
        "scraper": rel_scraper, "test": rel_test,
        "attempts": attempt,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--owner-email", required=True, help="Email MULTIPASS du propriétaire")
    parser.add_argument("--domain", help="Domaine à scraper (ex: mastodon.social)")
    parser.add_argument("--url", default=None, help="URL cible (sinon déduite du domaine)")
    parser.add_argument("--heal", metavar="DOMAIN",
                        help="Mode réparation : régénère le scraper du domaine donné")
    parser.add_argument("--error", default=None,
                        help="Message d'erreur déclenchant le heal (contexte pour Claude)")
    parser.add_argument("--notify-captain", action="store_true",
                        help="Envoie un DM NODE au capitaine (succès ou échec)")
    args = parser.parse_args()

    if args.heal:
        heal_scraper(
            args.owner_email, args.heal,
            error_output=args.error,
            target_url=args.url,
            notify_captain=args.notify_captain,
        )
    elif args.domain:
        forge_scraper(
            args.owner_email, args.domain,
            target_url=args.url,
            notify_captain=args.notify_captain,
        )
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
