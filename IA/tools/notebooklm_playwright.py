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

import argparse
import json
import re
import sys
import time
from datetime import datetime
from http.cookiejar import MozillaCookieJar
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
TIMEOUT_MS       = 35_000
NETWORKIDLE_MS   = 20_000
SETTLE_S         = 4

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
    """Charge cookies depuis un fichier Netscape/Mozilla cookies.txt."""
    jar = MozillaCookieJar(filepath)
    jar.load(ignore_discard=True, ignore_expires=True)
    cookies = []
    for c in jar:
        if "google" in c.domain:
            cookies.append({
                "name": c.name, "value": c.value,
                "domain": c.domain if c.domain.startswith(".") else f".{c.domain}",
                "path": c.path or "/",
                "secure": bool(c.secure),
                "httpOnly": False, "sameSite": "None",
            })
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
            body_clean = re.sub(r"^\)\]\}',?\n?", "", body.strip())
            try:
                parsed = json.loads(body_clean)
                self.api_responses.append({"url": url, "status": response.status, "data": parsed})
            except json.JSONDecodeError:
                if len(body_clean) < 100_000:
                    self.api_responses.append({"url": url, "status": response.status,
                                               "raw": body_clean[:10_000]})
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

def scrape(url: str, cookies: list[dict], headed: bool) -> tuple[dict, str]:
    """Retourne (result_dict, html_brut)."""
    capture = NetworkCapture()

    with sync_playwright() as pw:
        browser = pw.chromium.launch(
            headless=not headed,
            args=["--disable-blink-features=AutomationControlled",
                  "--no-sandbox", "--disable-dev-shm-usage"],
        )
        ctx: BrowserContext = browser.new_context(
            viewport={"width": 1440, "height": 900},
            user_agent=("Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                        "AppleWebKit/537.36 (KHTML, like Gecko) "
                        "Chrome/124.0.0.0 Safari/537.36"),
            locale="fr-FR",
            timezone_id="Europe/Paris",
        )
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
            die("❌ Authentification échouée — redirection vers Google Login.\n"
                "   Vos cookies sont expirés ou insuffisants.")

        log("✅ Authentifié")
        log("⏳ Attente rendu JS…")
        try:
            page.wait_for_load_state("networkidle", timeout=NETWORKIDLE_MS)
        except Exception:
            pass
        time.sleep(SETTLE_S)

        html      = page.content()
        js_data   = extract_via_js(page)
        screenshot_bytes = page.screenshot(full_page=True)

        browser.close()

    result = {
        "meta": {
            "extracted_at": datetime.now().isoformat(),
            "source_url":   url,
            "notebook_id":  js_data.get("notebook_id"),
        },
        "notebook": {
            "title":        js_data.get("title"),
            "sources":      js_data.get("sources", []),
            "notes":        js_data.get("notes", []),
            "chat_history": js_data.get("chat_history", []),
        },
        "api_calls_captured": len(capture.api_responses),
        "api_data":           capture.api_responses,
        "af_callbacks":       extract_af_callbacks(html),
        "internal_stores":    js_data.get("raw_stores", {}),
        "_screenshot_bytes":  screenshot_bytes,   # retiré avant sérialisation JSON
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
    parser.add_argument("--headed", action="store_true", help="Navigateur visible")
    parser.add_argument("--quiet",  action="store_true", help="Pas de log stderr")

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
    result, html = scrape(url, cookies, args.headed)

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
