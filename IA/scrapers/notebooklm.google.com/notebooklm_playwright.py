#!/usr/bin/env python3
"""
NotebookLM Playwright Extractor
================================
Extrait le contenu d'un notebook NotebookLM sans interaction utilisateur.

Prérequis:
    pip install playwright
    playwright install chromium

Usage:
    python notebooklm_playwright.py --url URL --cookie "NAME=VALUE; NAME2=VALUE2"
    python notebooklm_playwright.py --url URL --cookie-file cookies.json
    python notebooklm_playwright.py --url URL --cookie "..." --json --md
    python notebooklm_playwright.py --url URL --cookie "..." --raw --file ./out/

Formats de sortie (cumulables) :
    --json          Données structurées complètes (notebook.json)
    --md            Rendu Markdown lisible (notebook.md)
    --raw           HTML source brut (notebook_raw.html) + screenshot PNG
    --file DIR      Dossier de destination (défaut: ./output)
    (sans flag)     Affiche le JSON sur stdout

Cookies :
    --cookie "SID=xxx; SSID=yyy; ..."    String inline (format HTTP Cookie header)
    --cookie-file cookies.json           Fichier JSON (format Cookie-Editor)
    --cookie-file cookies.txt            Fichier Netscape/Mozilla

    Variables d'environnement :
    NOTEBOOKLM_COOKIE   équivalent à --cookie
    NOTEBOOKLM_URL      équivalent à --url
"""

# Auto-reinvocation dans le venv ~/.astro/ si dépendances absentes
import sys as _sys
import os as _os
_venv_python = _os.path.expanduser("~/.astro/bin/python3")
if _os.path.exists(_venv_python) and _sys.executable != _venv_python:
    _os.execv(_venv_python, [_venv_python] + _sys.argv)
del _sys, _os


import argparse
import json
import re
import sys
import time
from datetime import datetime
from pathlib import Path

# ─── Vérification dépendances ──────────────────────────────────────────────────

def check_deps():
    try:
        import playwright  # noqa
    except ImportError:
        print("❌ playwright manquant : pip install playwright && playwright install chromium",
              file=sys.stderr)
        sys.exit(1)

check_deps()

from playwright.sync_api import sync_playwright, Page, BrowserContext, Response

# ─── Constantes ────────────────────────────────────────────────────────────────

NOTEBOOKLM_HOST  = "notebooklm.google.com"
TIMEOUT_MS       = 45_000
NETWORKIDLE_MS   = 25_000
SETTLE_S         = 8    # plus long : SPA Angular, lazy-load sources

API_URL_PATTERNS = [
    r"/rpc", r"BatchExecute", r"batchexecute",
    r"ListSource", r"GetNotebook", r"/_/", r"/v1/",
]

# ─── Parsing des cookies ───────────────────────────────────────────────────────

def parse_cookie_string(cookie_str: str) -> list[dict]:
    """Parse une string 'Name=Val; Name2=Val2' → liste de dicts Playwright."""
    cookies = []
    for part in cookie_str.split(";"):
        part = part.strip()
        if "=" not in part:
            continue
        name, _, value = part.partition("=")
        name, value = name.strip(), value.strip()
        if name:
            cookies.append({
                "name": name, "value": value,
                "domain": ".google.com", "path": "/",
                "secure": True, "httpOnly": True, "sameSite": "None",
            })
    return cookies


def parse_cookie_json(filepath: str) -> list[dict]:
    """Charge cookies depuis un JSON (Cookie-Editor / EditThisCookie)."""
    with open(filepath, encoding="utf-8") as f:
        raw = json.load(f)
    cookies = []
    for c in raw:
        domain = c.get("domain", ".google.com")
        cookies.append({
            "name":     c.get("name", c.get("key", "")),
            "value":    c.get("value", ""),
            "domain":   domain if domain.startswith(".") else f".{domain}",
            "path":     c.get("path", "/"),
            "secure":   c.get("secure", True),
            "httpOnly": c.get("httpOnly", False),
            "sameSite": c.get("sameSite", "None"),
        })
    return [c for c in cookies if c["name"] and "google" in c["domain"]]


def parse_cookie_netscape(filepath: str) -> list[dict]:
    """Charge cookies depuis un fichier Netscape en respectant le flag de domaine.

    Format TSV Netscape :  domain  flag  path  secure  expiry  name  value
      flag TRUE  → domain cookie (valide pour tous les sous-domaines → préfixe '.')
      flag FALSE → host-only cookie (hôte exact uniquement, PAS de préfixe '.')

    OSID/__Secure-OSID de notebooklm.google.com ont flag=FALSE.
    Ajouter un '.' leur ferait rater la validation Playwright → échec auth.
    """
    cookies = []
    try:
        with open(filepath, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                parts = line.split('\t')
                if len(parts) < 7:
                    continue
                col_domain = parts[0]
                col_flag   = parts[1].strip().upper()   # TRUE ou FALSE
                col_path   = parts[2]
                col_secure = parts[3].strip().upper() == 'TRUE'
                col_name   = parts[5]
                col_value  = '\t'.join(parts[6:])

                if 'google' not in col_domain:
                    continue

                # flag TRUE  → préfixe '.' (domain cookie, sous-domaines inclus)
                # flag FALSE → sans '.' (host-only, domaine exact seulement)
                if col_flag == 'TRUE':
                    pw_domain = col_domain if col_domain.startswith('.') else f'.{col_domain}'
                else:
                    pw_domain = col_domain.lstrip('.')

                cookies.append({
                    "name":     col_name,
                    "value":    col_value,
                    "domain":   pw_domain,
                    "path":     col_path or "/",
                    "secure":   col_secure,
                    "httpOnly": False,
                    "sameSite": "None",
                })
    except Exception as e:
        log(f"⚠️  Erreur lecture cookies Netscape: {e}")
    return cookies


def resolve_cookies(args) -> list[dict]:
    """Résout les cookies depuis les args ou les variables d'environnement."""
    import os

    # 1. --cookie-file
    if args.cookie_file:
        path = args.cookie_file
        if path.endswith(".json"):
            cookies = parse_cookie_json(path)
        else:
            cookies = parse_cookie_netscape(path)
        log(f"🍪 {len(cookies)} cookies chargés depuis {path}")
        return cookies

    # 2. --cookie inline ou NOTEBOOKLM_COOKIE
    cookie_str = args.cookie or os.environ.get("NOTEBOOKLM_COOKIE", "")
    if cookie_str:
        cookies = parse_cookie_string(cookie_str)
        log(f"🍪 {len(cookies)} cookies parsés")
        return cookies

    die("❌ Aucun cookie fourni.\n"
        "   Utilise --cookie 'SID=…; SSID=…' ou --cookie-file cookies.json\n"
        "   ou la variable d'environnement NOTEBOOKLM_COOKIE")


# ─── Capture réseau ────────────────────────────────────────────────────────────

class NetworkCapture:
    def __init__(self):
        self.api_responses: list[dict] = []
        self._seen: set[str] = set()

    def on_response(self, response: Response):
        url = response.url
        if NOTEBOOKLM_HOST not in url:
            return
        if not any(re.search(p, url) for p in API_URL_PATTERNS):
            return
        if url in self._seen:
            return
        self._seen.add(url)
        try:
            ct = response.headers.get("content-type", "")
            if not ("json" in ct or "javascript" in ct or "text" in ct):
                return
            body = response.text()
            # Striper le préfixe Google : )]}'\n puis le préfixe de taille batchexecute ({N}\n)
            clean = re.sub(r"^\)\]\}',?\n?", "", body.strip())
            clean = re.sub(r"^\d+\n", "", clean.strip())
            try:
                parsed = json.loads(clean)
                self.api_responses.append({"url": url, "status": response.status, "data": parsed})
            except json.JSONDecodeError:
                if len(clean) < 200_000:
                    self.api_responses.append({"url": url, "status": response.status,
                                               "raw": clean})
        except Exception:
            pass


# ─── Extraction DOM ────────────────────────────────────────────────────────────

def extract_via_js(page: Page) -> dict:
    return page.evaluate("""() => {
        const txt = el => (el?.textContent || el?.innerText || "").trim();
        const result = {
            title: null, notebook_id: null,
            sources: [], notes: [], chat_history: [], raw_stores: {}
        };

        // Titre
        for (const sel of ['h1', '[data-notebook-title]', '.notebook-title']) {
            const el = document.querySelector(sel);
            if (el && txt(el)) { result.title = txt(el); break; }
        }
        if (!result.title)
            result.title = document.title.replace(/\\s*[-|]\\s*NotebookLM.*$/i, "").trim();

        // ID depuis URL
        const m = window.location.pathname.match(/notebook\\/([a-f0-9-]{36})/);
        if (m) result.notebook_id = m[1];

        // Sources
        for (const sel of ['[data-source-id]', '.source-item', '[class*="source-list"] li']) {
            document.querySelectorAll(sel).forEach(el => {
                const id    = el.getAttribute('data-source-id') || null;
                const title = txt(el.querySelector('[class*="title"], h3, h4, strong') || el).slice(0, 300);
                const type  = el.getAttribute('data-source-type') || 'unknown';
                if (title && !result.sources.find(s => s.title === title))
                    result.sources.push({ id, title, type });
            });
        }

        // Notes
        for (const sel of ['[data-note-id]', '.note-card', '[class*="note-item"]']) {
            document.querySelectorAll(sel).forEach(el => {
                const id      = el.getAttribute('data-note-id') || null;
                const content = txt(el).slice(0, 5000);
                if (content.length > 5 && !result.notes.find(n => n.content === content))
                    result.notes.push({ id, content });
            });
        }

        // Chat
        for (const sel of ['[data-role]', '[class*="chat-turn"]', '[class*="message-bubble"]']) {
            document.querySelectorAll(sel).forEach(el => {
                const role    = el.getAttribute('data-role')
                              || (el.className.includes('user') ? 'user' : 'assistant');
                const content = txt(el).slice(0, 5000);
                if (content.length > 10)
                    result.chat_history.push({ role, content });
            });
        }

        // Globals
        for (const g of ['__INITIAL_STATE__', '__APP_STATE__', 'AF_initDataCallbackData']) {
            try { if (window[g]) result.raw_stores[g] = window[g]; } catch(_){}
        }

        return result;
    }""")


def _decode_inner(val):
    """Décode la valeur interne d'un item wrb.fr (souvent une string JSON doublée)."""
    if isinstance(val, str):
        try:
            return json.loads(val)
        except Exception:
            return val
    return val


def _extract_wrb_methods(data) -> dict[str, object]:
    """Extrait le dict {method: inner_data} depuis un tableau batchexecute parsé.

    Format: [[\"wrb.fr\", method, inner_json_string, ...], [\"di\",...], ...]
    """
    result: dict[str, object] = {}
    if not isinstance(data, list):
        return result
    for item in data:
        if isinstance(item, list) and len(item) >= 3 and item[0] == "wrb.fr":
            method = item[1]
            inner  = _decode_inner(item[2])
            result[method] = inner
    return result


def _source_type(url: str) -> str:
    if re.search(r'youtube\.com|youtu\.be', url): return "youtube"
    if re.search(r'docs\.google\.com|drive\.google\.com', url): return "gdrive"
    if url.lower().endswith(".pdf"): return "pdf"
    return "web"


def _find_strings(obj, min_len=4, max_len=2000, depth=0) -> list[str]:
    """Collecte les strings dans une structure JSON imbriquée."""
    if depth > 15:
        return []
    results = []
    if isinstance(obj, str) and min_len <= len(obj) <= max_len:
        results.append(obj)
    elif isinstance(obj, (list, tuple)):
        for item in obj:
            results.extend(_find_strings(item, min_len, max_len, depth + 1))
    elif isinstance(obj, dict):
        for v in obj.values():
            results.extend(_find_strings(v, min_len, max_len, depth + 1))
    return results


def parse_api_data(api_responses: list[dict]) -> dict:
    """Parse les réponses batchexecute NotebookLM.

    NotebookLM utilise Google batchexecute. Chaque réponse contient :
      [["wrb.fr", "MethodName", "inner_json_as_string", ...], ...]

    Méthodes connues (observées) :
      wXbhsf / rLM1Ne  → GetNotebook : titre + liste des sources (id + titre)
      e3bVqc           → GetSource   : id + notebook_id + url + métadonnées
      I3xc3c           → ListNotes   : sections + notes (id + titre)
      sqTeoe           → AudioOverview: titre + description générés
    """
    sources: list[dict] = []
    notes:   list[dict] = []
    chat:    list[dict] = []
    seen_src_ids: set[str] = set()
    seen_note_ids: set[str] = set()
    url_re = re.compile(r'^https?://')

    for resp in api_responses:
        raw_data = resp.get("data")
        if raw_data is None:
            # Fallback: tenter de re-parser le raw si présent
            raw_str = resp.get("raw", "")
            if not raw_str:
                continue
            try:
                raw_data = json.loads(raw_str)
            except Exception:
                continue

        methods = _extract_wrb_methods(raw_data)
        if not methods:
            continue

        for method, inner in methods.items():
            if inner is None:
                continue

            # ── GetNotebook : wXbhsf ou rLM1Ne ───────────────────────────────
            # Format observé: [[notebook_title, [[[source_id], source_title, ...], ...]]]
            if method in ("wXbhsf", "rLM1Ne"):
                all_strs = _find_strings(inner, min_len=8, max_len=500)
                uuid_re  = re.compile(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
                # Les titres de sources sont des strings non-UUID entre 8 et 300 chars
                for s in all_strs:
                    if uuid_re.match(s):
                        continue
                    if url_re.match(s):
                        continue
                    # Heuristique : titre de source plausible
                    if 8 < len(s) < 300 and ' ' in s or '-' in s or '.' in s:
                        key = s[:100]
                        if key not in seen_src_ids:
                            seen_src_ids.add(key)
                            sources.append({"title": s, "url": None, "type": "unknown"})

            # ── GetSource : e3bVqc ────────────────────────────────────────────
            # Format observé: [[[source_id, [notebook_id, [url, ...]]]]]
            elif method == "e3bVqc":
                all_strs = _find_strings(inner, min_len=10, max_len=2000)
                uuid_re  = re.compile(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
                src_id   = None
                url_val  = None
                title    = None
                for s in all_strs:
                    if uuid_re.match(s) and src_id is None:
                        src_id = s
                    elif url_re.match(s) and url_val is None:
                        url_val = s
                    elif not uuid_re.match(s) and not url_re.match(s) and title is None:
                        if len(s) > 8 and len(s) < 300:
                            title = s
                if url_val or src_id:
                    key = url_val or src_id
                    if key not in seen_src_ids:
                        seen_src_ids.add(key)
                        sources.append({
                            "id":    src_id,
                            "title": title or (url_val.split("/")[-1][:120] if url_val else src_id),
                            "url":   url_val,
                            "type":  _source_type(url_val) if url_val else "unknown",
                        })

            # ── ListNotes : I3xc3c ────────────────────────────────────────────
            # Format observé: [[[section_title, [[note_id]], note_uuid, ""], ...]]
            elif method == "I3xc3c":
                uuid_re = re.compile(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
                all_strs = _find_strings(inner, min_len=2, max_len=5000)
                section_title = None
                for s in all_strs:
                    if uuid_re.match(s):
                        if s not in seen_note_ids:
                            seen_note_ids.add(s)
                    elif len(s) > 3 and not url_re.match(s):
                        # Titres de section ou contenu de notes
                        section_title = s
                        key = s[:200]
                        if key not in seen_note_ids:
                            seen_note_ids.add(key)
                            notes.append({"id": None, "content": s})

            # ── AudioOverview : sqTeoe ────────────────────────────────────────
            # Format observé: [[[1, title, description, ...]]]
            elif method == "sqTeoe":
                all_strs = _find_strings(inner, min_len=10, max_len=5000)
                for s in all_strs:
                    if len(s) > 20 and s not in seen_note_ids:
                        seen_note_ids.add(s[:100])
                        notes.append({"id": "audio_overview", "content": s})

            # ── Autres méthodes : extraire URLs et contenus longs ─────────────
            else:
                for s in _find_strings(inner, min_len=20, max_len=5000):
                    if url_re.match(s) and NOTEBOOKLM_HOST not in s:
                        key = s[:200]
                        if key not in seen_src_ids:
                            seen_src_ids.add(key)
                            sources.append({
                                "title": s.split("/")[-1][:120] or s[:80],
                                "url": s, "type": _source_type(s),
                            })

    # Fusionner : si une source avec URL matche un titre sans URL → enrichir
    titles_without_url = {s["title"]: s for s in sources if not s.get("url")}
    for s in sources:
        if s.get("url") and s["title"] in titles_without_url:
            titles_without_url[s["title"]]["url"] = s["url"]
            titles_without_url[s["title"]]["type"] = s["type"]
    sources = [s for s in sources if s.get("url") or s.get("id")]

    return {"sources": sources, "notes": notes, "chat": chat}


def extract_af_callbacks(html: str) -> list[dict]:
    blocks = []
    for m in re.finditer(
        r"AF_initDataCallback\s*\(\s*\{[^}]*?key\s*:\s*'([^']+)'[^}]*?data\s*:(\[.*?\])\s*\}\s*\)",
        html, re.DOTALL
    ):
        try:
            blocks.append({"key": m.group(1), "data": json.loads(m.group(2))})
        except json.JSONDecodeError:
            blocks.append({"key": m.group(1), "data": m.group(2)[:2000]})
    return blocks


# ─── Renderers de sortie ───────────────────────────────────────────────────────

def render_json(result: dict) -> str:
    return json.dumps(result, ensure_ascii=False, indent=2)


def render_markdown(result: dict) -> str:
    nb   = result["notebook"]
    meta = result["meta"]
    lines = [
        f"# {nb['title'] or 'Notebook sans titre'}",
        f"\n> Extrait le {meta['extracted_at']}  ",
        f"> ID : `{meta['notebook_id']}`  ",
        f"> URL : {meta['source_url']}",
        "",
    ]

    if nb["sources"]:
        lines += [f"\n## Sources ({len(nb['sources'])})\n"]
        for s in nb["sources"]:
            icon = {"pdf": "📄", "web": "🌐", "text": "📝", "youtube": "▶️"}.get(s.get("type",""), "📎")
            lines.append(f"- {icon} **{s['title']}**" + (f" *(id: {s['id']})*" if s.get("id") else ""))

    if nb["notes"]:
        lines += [f"\n## Notes ({len(nb['notes'])})\n"]
        for i, n in enumerate(nb["notes"], 1):
            lines.append(f"### Note {i}" + (f" `{n['id']}`" if n.get("id") else ""))
            lines.append(n["content"])
            lines.append("")

    if nb["chat_history"]:
        lines += [f"\n## Historique de chat ({len(nb['chat_history'])} tours)\n"]
        for turn in nb["chat_history"]:
            role_label = "**Vous**" if turn["role"] == "user" else "**NotebookLM**"
            lines.append(f"{role_label}\n\n{turn['content']}\n")
            lines.append("---")

    if result.get("api_calls_captured", 0):
        lines.append(f"\n*{result['api_calls_captured']} appels API capturés — voir notebook.json pour le détail.*")

    return "\n".join(lines)


# ─── Helpers ───────────────────────────────────────────────────────────────────

def log(msg: str):
    print(msg, file=sys.stderr)

def die(msg: str):
    print(msg, file=sys.stderr)
    sys.exit(1)


# ─── Pipeline Playwright ───────────────────────────────────────────────────────

def scrape(url: str, cookies: list[dict], headed: bool, browser_name: str = "firefox") -> tuple[dict, str]:
    """Retourne (result_dict, html_brut).

    browser_name: "firefox" (défaut) ou "chromium".
    Firefox est recommandé quand les cookies ont été exportés depuis Firefox —
    Google lie les sessions au browser fingerprint et détecte les discordances.
    """
    capture = NetworkCapture()

    with sync_playwright() as pw:
        if browser_name == "firefox":
            try:
                browser = pw.firefox.launch(headless=not headed)
                ctx: BrowserContext = browser.new_context(
                    viewport={"width": 1440, "height": 900},
                    user_agent=("Mozilla/5.0 (X11; Linux x86_64; rv:125.0) "
                                "Gecko/20100101 Firefox/125.0"),
                    locale="fr-FR",
                    timezone_id="Europe/Paris",
                )
                log("🦊 Navigateur: Firefox")
            except Exception as e:
                log(f"⚠️  Firefox indisponible ({e}), bascule sur Chromium")
                browser_name = "chromium"

        if browser_name == "chromium":
            browser = pw.chromium.launch(
                headless=not headed,
                args=["--disable-blink-features=AutomationControlled",
                      "--no-sandbox", "--disable-dev-shm-usage"],
            )
            ctx = browser.new_context(
                viewport={"width": 1440, "height": 900},
                user_agent=("Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                            "AppleWebKit/537.36 (KHTML, like Gecko) "
                            "Chrome/124.0.0.0 Safari/537.36"),
                locale="fr-FR",
                timezone_id="Europe/Paris",
            )
            log("🌐 Navigateur: Chromium")

        ctx.add_cookies(cookies)
        page = ctx.new_page()
        page.on("response", capture.on_response)

        log(f"🌐 Navigation → {url}")
        try:
            page.goto(url, timeout=TIMEOUT_MS, wait_until="domcontentloaded")
        except Exception as e:
            die(f"❌ Erreur de navigation : {e}")

        current = page.url
        if "accounts.google.com" in current or "signin" in current:
            die(f"❌ Authentification échouée — redirection vers : {current}\n"
                "   Vos cookies sont expirés ou exportés depuis un autre navigateur.\n"
                "   Re-exportez depuis Firefox et re-uploadez via /cookie.html")

        log("✅ Authentifié")
        log("⏳ Attente rendu JS…")
        try:
            page.wait_for_load_state("networkidle", timeout=NETWORKIDLE_MS)
        except Exception:
            pass

        # Scroll pour déclencher le lazy-load des sources/notes
        log("📜 Scroll pour déclencher le lazy-load…")
        for _ in range(4):
            page.evaluate("window.scrollBy(0, window.innerHeight)")
            time.sleep(1)
        page.evaluate("window.scrollTo(0, 0)")
        time.sleep(SETTLE_S)

        html             = page.content()
        js_data          = extract_via_js(page)
        screenshot_bytes = page.screenshot(full_page=True)

        browser.close()

    # Fusionner DOM + API
    api_extracted = parse_api_data(capture.api_responses)

    # DOM en priorité si non vide, sinon API
    dom_sources = js_data.get("sources", [])
    dom_notes   = js_data.get("notes", [])
    dom_chat    = js_data.get("chat_history", [])

    final_sources = dom_sources if dom_sources else api_extracted["sources"]
    final_notes   = dom_notes   if dom_notes   else api_extracted["notes"]
    final_chat    = dom_chat    if dom_chat     else api_extracted["chat"]

    log(f"📊 Sources: {len(final_sources)}  Notes: {len(final_notes)}  "
        f"Chat: {len(final_chat)}  API calls: {len(capture.api_responses)}")

    result = {
        "meta": {
            "extracted_at": datetime.now().isoformat(),
            "source_url":   url,
            "notebook_id":  js_data.get("notebook_id"),
        },
        "notebook": {
            "title":        js_data.get("title"),
            "sources":      final_sources,
            "notes":        final_notes,
            "chat_history": final_chat,
        },
        "api_calls_captured": len(capture.api_responses),
        "api_data":           capture.api_responses,
        "af_callbacks":       extract_af_callbacks(html),
        "internal_stores":    js_data.get("raw_stores", {}),
        "_screenshot_bytes":  screenshot_bytes,
    }
    return result, html


# ─── Point d'entrée ────────────────────────────────────────────────────────────

def main():
    import os

    parser = argparse.ArgumentParser(
        description="Extrait le contenu d'un notebook NotebookLM sans interaction.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )

    # ── Cible ──────────────────────────────────────────────────────────────────
    parser.add_argument("--url",
        default=os.environ.get("NOTEBOOKLM_URL"),
        help="URL du notebook (ou NOTEBOOKLM_URL)")

    # ── Authentification ───────────────────────────────────────────────────────
    auth = parser.add_mutually_exclusive_group(required=False)
    auth.add_argument("--cookie",
        default=None,
        metavar="'SID=x; SSID=y; …'",
        help="Cookies inline au format HTTP header Cookie (ou NOTEBOOKLM_COOKIE)")
    auth.add_argument("--cookie-file",
        default=None,
        metavar="FILE",
        help="Fichier cookies (.json Cookie-Editor ou .txt Netscape)")

    # ── Sorties ────────────────────────────────────────────────────────────────
    parser.add_argument("--json",  action="store_true", help="Écrire notebook.json")
    parser.add_argument("--md",    action="store_true", help="Écrire notebook.md")
    parser.add_argument("--raw",   action="store_true", help="Écrire HTML + screenshot PNG")
    parser.add_argument("--file",
        default="./output",
        metavar="DIR",
        help="Dossier de destination (défaut: ./output)")

    # ── Options ────────────────────────────────────────────────────────────────
    parser.add_argument("--headed",  action="store_true", help="Navigateur visible")
    parser.add_argument("--quiet",   action="store_true", help="Pas de log stderr")
    parser.add_argument("--browser", default="firefox",
                        choices=["firefox", "chromium"],
                        help="Navigateur Playwright (défaut: firefox — cookies exportés depuis Firefox)")

    args = parser.parse_args()

    if args.quiet:
        import io
        sys.stderr = io.StringIO()

    # Validation URL
    url = args.url
    if not url:
        die("❌ URL requise : --url URL  ou  NOTEBOOKLM_URL=…")
    if "notebooklm.google.com" not in url:
        die(f"❌ URL invalide : {url}")

    cookies = resolve_cookies(args)

    # Scraping
    result, html = scrape(url, cookies, args.headed, args.browser)

    screenshot_bytes = result.pop("_screenshot_bytes", None)

    # ── Aucun flag → stdout JSON ───────────────────────────────────────────────
    no_output_flag = not (args.json or args.md or args.raw)
    if no_output_flag:
        sys.stdout.write(render_json(result))
        sys.stdout.write("\n")
        return

    # ── Écriture des fichiers ──────────────────────────────────────────────────
    out = Path(args.file)
    out.mkdir(parents=True, exist_ok=True)

    written = []

    if args.json:
        p = out / "notebook.json"
        p.write_text(render_json(result), encoding="utf-8")
        written.append(str(p))

    if args.md:
        p = out / "notebook.md"
        p.write_text(render_markdown(result), encoding="utf-8")
        written.append(str(p))

    if args.raw:
        p_html = out / "notebook_raw.html"
        p_html.write_text(html, encoding="utf-8")
        written.append(str(p_html))
        if screenshot_bytes:
            p_png = out / "notebook_screenshot.png"
            p_png.write_bytes(screenshot_bytes)
            written.append(str(p_png))

    log("\n✅ Fichiers générés :")
    for f in written:
        log(f"   {f}")

    # Résumé rapide sur stderr
    nb = result["notebook"]
    log(f"\n   Titre   : {nb['title']}")
    log(f"   Sources : {len(nb['sources'])}")
    log(f"   Notes   : {len(nb['notes'])}")
    log(f"   Chat    : {len(nb['chat_history'])} tours")
    log(f"   API     : {result['api_calls_captured']} appels capturés")


if __name__ == "__main__":
    main()
