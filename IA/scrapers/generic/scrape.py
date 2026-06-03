#!/usr/bin/env python3
"""
scrapers/generic/scrape.py — Scrape le contenu principal d'une URL quelconque via Playwright.
Usage : scrape.py <url> [--json] [--max-chars 3000]
Retourne : {url, title, domain, text, sections}
"""

import sys
import os
_venv_python = os.path.expanduser("~/.astro/bin/python3")
if os.path.exists(_venv_python) and sys.executable != _venv_python:
    os.execv(_venv_python, [_venv_python] + sys.argv)

import json
import argparse
import re
from urllib.parse import urlparse

# JS : extrait le contenu principal en ignorant nav/footer/sidebar
_EXTRACT_JS = r"""
(maxChars) => {
    const clean = t => t.replace(/\s+/g,' ').trim();

    // Sélecteurs de contenu principal par priorité
    const MAIN_SEL = [
        'article', 'main', '[role="main"]',
        '.content', '#content', '.entry-content', '.post-content',
        '.article-body', '.article-content', '#bodyContent',
        '.mw-parser-output', '.wikibody',
    ];
    let root = null;
    for (const sel of MAIN_SEL) {
        root = document.querySelector(sel);
        if (root) break;
    }
    if (!root) root = document.body;

    // Ignorer ces zones
    const IGNORE = new Set(['nav','header','footer','aside',
        '.sidebar','.menu','.navigation','.ad','.advertisement',
        '.cookie','#toc','.toc','[role="navigation"]','.reflist',
        '.references','#references','#footnotes']);
    const skip = el => {
        if (!el) return false;
        const tag = el.tagName?.toLowerCase();
        if (IGNORE.has(tag)) return true;
        for (const sel of IGNORE) {
            try { if (el.matches(sel)) return true; } catch(e) {}
        }
        return false;
    };

    const sections = [];
    let cur = {title:'', content:[]};
    const chars = {n: 0};

    const walk = node => {
        if (chars.n >= maxChars) return;
        if (skip(node)) return;
        const tag = node.tagName?.toUpperCase();
        if (tag === 'H1'||tag === 'H2'||tag === 'H3') {
            if (cur.content.length) { sections.push({...cur}); }
            cur = {title: clean(node.innerText), content: []};
        } else if (tag === 'P') {
            const t = clean(node.innerText);
            if (t.length > 40) { cur.content.push(t); chars.n += t.length; }
        } else if (tag === 'UL'||tag === 'OL') {
            const items = Array.from(node.querySelectorAll('li'))
                .map(li => '• ' + clean(li.innerText))
                .filter(s => s.length > 8);
            if (items.length) {
                const block = items.join('\n');
                cur.content.push(block);
                chars.n += block.length;
            }
        } else {
            for (const child of node.children) walk(child);
        }
    };

    walk(root);
    if (cur.content.length) sections.push(cur);

    const title = document.querySelector('h1')?.innerText?.trim()
        || document.title?.split(/[|\-–]/)[0]?.trim() || '';

    const text = sections.map(s =>
        (s.title ? s.title + '\n' : '') + s.content.join('\n')
    ).join('\n\n').slice(0, maxChars);

    return {title, sections, text};
}
"""


def scrape_url(url, max_chars=3000, json_output=False):
    from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout

    domain = urlparse(url).netloc
    result = {'url': url, 'domain': domain, 'title': '', 'text': '', 'sections': []}

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        ctx = browser.new_context(
            user_agent='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36'
        )
        page = ctx.new_page()
        try:
            page.goto(url, wait_until='domcontentloaded', timeout=20000)
            # Attendre un peu pour le JS dynamique
            page.wait_for_timeout(800)
            data = page.evaluate(_EXTRACT_JS, max_chars)
            result.update(data)
        except PWTimeout:
            result['error'] = f"Timeout : {url}"
        except Exception as e:
            result['error'] = str(e)
        finally:
            browser.close()

    return result


def main():
    parser = argparse.ArgumentParser(description="Scrape le contenu principal d'une URL")
    parser.add_argument("url", help="URL à scraper")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--max-chars", type=int, default=3000)
    args = parser.parse_args()

    data = scrape_url(args.url, args.max_chars, args.json)

    if args.json:
        print(json.dumps(data, ensure_ascii=False, indent=2))
    else:
        print(f"=== {data['title']} ({data['domain']}) ===\n")
        if data.get('error'):
            print(f"Erreur : {data['error']}")
        else:
            print(data.get('text', '')[:2000])


if __name__ == "__main__":
    main()
