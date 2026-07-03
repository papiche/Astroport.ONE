#!/usr/bin/env python3
"""
scraper_mastodon.py — Rapport quotidien Mastodon via cookie de session.

Contrairement à WhatsApp, Mastodon utilise une authentification HTTP classique
(cookies Rails _session_id/_mastodon_session) : le cookie exporté depuis le
navigateur suffit, pas de QR code ni de profil persistant nécessaire.

Ce scraper tourne une fois par jour (déclenché par NOSTRCARD.refresh.sh) :
  - /notifications → mentions reçues (toujours pertinentes, always_alert)
  - /home           → fil d'actualité, posts publiés dans les dernières 24h
                       (pertinence évaluée par mots-clés/appris, canal "timeline")
  - /@moi           → propres posts récents (7 jours), transmis comme own_posts
                       pour résoudre la boucle de rétroaction (une suggestion
                       effectivement postée par le propriétaire alimente les
                       exemples de style des suggestions suivantes)

Chaque canal produit UN rapport de synthèse (une suggestion par item pertinent)
via bro_watch_core.process_watch_digest(), envoyé en DM NOSTR au propriétaire.

Usage :
    python3 scraper_mastodon.py --cookie-file COOKIE --instance mastodon.social --seen-file SEEN.json
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
import json
import time
import argparse
from datetime import datetime, timedelta, timezone

sys.path.insert(0, os.path.expanduser("~/.zen/Astroport.ONE/IA"))
import bro_watch_core

from playwright.sync_api import sync_playwright
from playwright_stealth import Stealth

MAX_SEEN = 500
TIMELINE_WINDOW_HOURS = 24


def parse_cookie_netscape(filepath, domain_filter):
    cookies = []
    with open(filepath, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split('\t')
            if len(parts) < 7:
                continue
            col_domain, col_path = parts[0], parts[2]
            col_secure = parts[3].strip().upper() == 'TRUE'
            col_name = parts[5]
            col_value = '\t'.join(parts[6:])
            if domain_filter not in col_domain:
                continue
            pw_domain = col_domain if col_domain.startswith('.') else f'.{col_domain}'
            cookies.append({
                "name": col_name, "value": col_value, "domain": pw_domain,
                "path": col_path or "/", "secure": col_secure,
                "httpOnly": False, "sameSite": "Lax",
            })
    return cookies


def load_seen(seen_file):
    try:
        with open(seen_file) as f:
            return set(json.load(f))
    except Exception:
        return set()


def save_seen(seen_file, seen):
    os.makedirs(os.path.dirname(seen_file), exist_ok=True)
    with open(seen_file, "w") as f:
        json.dump(list(seen)[-MAX_SEEN:], f)


def extract_mentions(page):
    return page.evaluate("""() => {
        const results = [];
        const items = document.querySelectorAll(
            '.notification-group--mention, .notification-ungrouped--mention'
        );
        items.forEach(el => {
            const contentEl = el.querySelector(
                '.notification-group__embedded-status__content, .status__content'
            );
            const text = contentEl ? contentEl.textContent.trim() : '';
            if (!text) return;

            const handleEl = el.querySelector('a.notification-group__embedded-status__account, .status__display-name');
            let handle = '';
            if (handleEl) {
                const bdi = handleEl.querySelector('bdi');
                handle = bdi ? bdi.textContent.trim() : handleEl.textContent.trim();
            }

            const linkEl = el.querySelector('a[href*="/@"][href*="/"]');
            const url = linkEl ? linkEl.href : null;

            results.push({ handle: handle || 'Inconnu', text, url: url || text.slice(0, 100) });
        });
        return results;
    }""")


def extract_timeline(page):
    """Extrait les posts du fil d'accueil avec leur date ISO (attribut datetime)."""
    return page.evaluate("""() => {
        const results = [];
        document.querySelectorAll('.status').forEach(el => {
            const contentEl = el.querySelector('.status__content');
            const text = contentEl ? contentEl.textContent.trim() : '';
            if (!text) return;

            const nameEl = el.querySelector('.status__display-name bdi');
            const handle = nameEl ? nameEl.textContent.trim() : 'Inconnu';

            const timeEl = el.querySelector('time');
            const datetime_iso = timeEl ? timeEl.getAttribute('datetime') : null;

            const linkEl = el.querySelector('a.status__relative-time, time');
            const url = linkEl && linkEl.closest('a') ? linkEl.closest('a').href : null;

            results.push({ handle, text, url, datetime_iso });
        });
        return results;
    }""")


def extract_own_username(page):
    """Déduit le pseudo du compte connecté depuis le lien de profil de la
    barre de navigation (ex: /@qoop). Retourne None si non détecté."""
    return page.evaluate("""() => {
        const links = Array.from(document.querySelectorAll('a[href^="/@"]'));
        for (const a of links) {
            const path = new URL(a.href).pathname;
            // Un lien de profil est de la forme /@handle (pas /@handle/12345, un statut)
            if (/^\\/@[^/]+$/.test(path)) return path.slice(2);
        }
        return null;
    }""")


def extract_recent_own_posts(page, since_hours=None):
    """Extrait les posts du profil de l'utilisateur connecté (pour la
    résolution de la boucle de rétroaction)."""
    posts = extract_timeline(page)
    if since_hours is None:
        return posts
    cutoff = datetime.now(timezone.utc) - timedelta(hours=since_hours)
    fresh = []
    for p in posts:
        if not p.get("datetime_iso"):
            continue
        try:
            posted_at = datetime.fromisoformat(p["datetime_iso"].replace("Z", "+00:00"))
        except Exception:
            continue
        if posted_at >= cutoff:
            fresh.append(p)
    return fresh


def main():
    parser = argparse.ArgumentParser(description="Rapport quotidien Mastodon.")
    parser.add_argument("--player", required=True, help="Email MULTIPASS propriétaire")
    parser.add_argument("--cookie-file", required=True)
    parser.add_argument("--instance", required=True, help="Domaine de l'instance (ex: mastodon.social)")
    parser.add_argument("--seen-file", required=True)
    args = parser.parse_args()

    owner_email = args.player
    account_id = args.instance

    # Traiter les commandes reçues par self-DM avant de générer le rapport du jour
    # (ex: "#watch mastodon.social off", "#ok" pour valider une suggestion en attente).
    bro_watch_core.process_incoming_commands(owner_email)

    bro_watch_core.ensure_watch_entry(owner_email, account_id, "notifications", always_alert=True)
    bro_watch_core.ensure_watch_entry(owner_email, account_id, "timeline", keywords=[])

    cookies = parse_cookie_netscape(args.cookie_file, args.instance)
    if not cookies:
        print(f"[MASTODON] Aucun cookie trouvé pour {args.instance}", file=sys.stderr)
        sys.exit(1)

    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=True, args=["--no-sandbox", "--disable-dev-shm-usage"])
        ctx = browser.new_context(
            viewport={"width": 1280, "height": 900},
            user_agent=("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                        "(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"),
            locale="fr-FR",
        )
        Stealth().apply_stealth_sync(ctx)
        ctx.add_cookies(cookies)
        page = ctx.new_page()

        # ── Mentions ──────────────────────────────────────────────────────
        page.goto(f"https://{args.instance}/notifications", timeout=45000, wait_until="domcontentloaded")
        time.sleep(5)
        try:
            page.wait_for_load_state("networkidle", timeout=15000)
        except Exception:
            pass
        time.sleep(2)

        if "/auth/sign_in" in page.url or "/sign_in" in page.url:
            print(f"[MASTODON] Cookie expiré/invalide — redirigé vers {page.url}", file=sys.stderr)
            browser.close()
            sys.exit(1)

        mentions = extract_mentions(page)
        own_username = extract_own_username(page)

        # ── Fil d'actualité (posts des dernières 24h) ────────────────────
        page.goto(f"https://{args.instance}/home", timeout=45000, wait_until="domcontentloaded")
        time.sleep(5)
        try:
            page.wait_for_load_state("networkidle", timeout=15000)
        except Exception:
            pass
        # Scroll pour charger davantage de posts (fil infini)
        for _ in range(3):
            page.evaluate("window.scrollBy(0, window.innerHeight)")
            time.sleep(1.5)
        time.sleep(1)

        timeline_raw = extract_timeline(page)

        # ── Profil propre (boucle de rétroaction) ─────────────────────────
        own_posts = []
        if own_username:
            page.goto(f"https://{args.instance}/@{own_username}", timeout=45000, wait_until="domcontentloaded")
            time.sleep(4)
            try:
                page.wait_for_load_state("networkidle", timeout=15000)
            except Exception:
                pass
            # Le profil virtualise l'affichage (seul le post visible est
            # pleinement rendu) — scroller pour forcer le rendu des suivants.
            for _ in range(3):
                page.evaluate("window.scrollBy(0, window.innerHeight)")
                time.sleep(1.5)
            # Fenêtre large (7 jours) : les suggestions peuvent être postées
            # plusieurs jours après le rapport, avant expiration (FEEDBACK_WINDOW_DAYS).
            own_posts_raw = extract_recent_own_posts(page, since_hours=24 * 7)
            own_posts = [{"text": p["text"], "url": p.get("url")} for p in own_posts_raw]
        else:
            print("[MASTODON] Pseudo du compte connecté non détecté — rétroaction désactivée cette exécution.",
                  file=sys.stderr)

        browser.close()

    print(f"[MASTODON] {len(mentions)} mention(s), {len(timeline_raw)} post(s) de fil, "
          f"{len(own_posts)} post(s) propre(s) trouvé(s)")

    cutoff = datetime.now(timezone.utc) - timedelta(hours=TIMELINE_WINDOW_HOURS)
    timeline_today = []
    for p in timeline_raw:
        if not p.get("datetime_iso"):
            continue
        try:
            posted_at = datetime.fromisoformat(p["datetime_iso"].replace("Z", "+00:00"))
        except Exception:
            continue
        if posted_at >= cutoff:
            timeline_today.append(p)

    print(f"[MASTODON] {len(timeline_today)} post(s) du fil publié(s) dans les dernières {TIMELINE_WINDOW_HOURS}h")

    seen = load_seen(args.seen_file)

    def dedup(items):
        fresh = []
        for it in items:
            key = it.get("url") or it["text"][:100]
            if key in seen:
                continue
            seen.add(key)
            fresh.append({"username": it["handle"], "text": it["text"], "url": it.get("url")})
        return fresh

    fresh_mentions = dedup(mentions)
    fresh_timeline = dedup(timeline_today)

    bro_watch_core.process_watch_digest(
        owner_email, account_id, "notifications", fresh_mentions,
        context_label=f"Mastodon @{args.instance} — mentions",
        own_posts=own_posts,
    )
    bro_watch_core.process_watch_digest(
        owner_email, account_id, "timeline", fresh_timeline,
        context_label=f"Mastodon @{args.instance} — fil d'actualité",
        own_posts=own_posts,
    )

    save_seen(args.seen_file, seen)
    print(f"[MASTODON] Terminé — {len(fresh_mentions)} nouvelle(s) mention(s), "
          f"{len(fresh_timeline)} nouveau(x) post(s) de fil.")


if __name__ == "__main__":
    main()
