#!/usr/bin/env python3
"""
scrapers/wikipedia/scrape.py — Extrait le contenu structuré d'une page Wikipedia via Playwright.
Usage : scrape.py <url_ou_titre> [--lang fr] [--json]
Retourne : {title, summary, description, uses, how_to_use, warnings, raw_sections}
"""

import sys
import os
_venv_python = os.path.expanduser("~/.astro/bin/python3")
if os.path.exists(_venv_python) and sys.executable != _venv_python:
    os.execv(_venv_python, [_venv_python] + sys.argv)

import json
import argparse
import re
from urllib.parse import quote

# Sections à ignorer (navigation, références)
SKIP_SECTIONS = {
    'notes et références', 'voir aussi', 'liens externes', 'annexes',
    'bibliographie', 'références', 'notes', 'sources', 'galerie',
    'notes and references', 'see also', 'external links', 'further reading',
    'references', 'bibliography',
}

# Sections → catégorie sémantique
SECTION_CATEGORIES = {
    'description': [
        'description', 'morphologie', 'caractéristique', 'aspect', 'identification',
        'botanique', 'taxonomie', 'biologie', 'physiologie', 'anatomie',
        'présentation', 'généralité', 'forme', 'taille', 'couleur',
    ],
    'uses': [
        'utilisation', 'usage', 'emploi', 'application', 'propriété',
        'vertu', 'bénéfice', 'intérêt', 'valeur', 'nutrition', 'nutritionnel',
        'comestibilité', 'comestible', 'alimentaire', 'médicinal', 'médecine',
        'phytothérapie', 'thérapeutique', 'pharmacologie', 'pharmacognosie',
        'aromathérapie', 'herboristerie', 'remède', 'soin', 'beauté', 'cosmétique',
        'industriel', 'commercial', 'économique', 'artisanal', 'symbolique',
        'traditionnelle', 'populaire', 'ethnobotanique', 'usage traditionnel',
        'use', 'property', 'benefit', 'nutrition', 'medicinal',
    ],
    'how_to_use': [
        'préparation', 'recette', 'cuisine', 'cuisson', 'consommation',
        'conservation', 'récolte', 'cueillette', 'culture', 'plantation',
        'entretien', 'jardinage', 'taille', 'arrosage', 'sol', 'semis',
        'multiplication', 'reproduction', 'élagage', 'séchage', 'transformation',
        'extraction', 'infusion', 'décoction', 'macération', 'distillation',
        'comment', 'mode d\'emploi', 'utiliser', 'préparer', 'cuisiner',
        'cultivation', 'harvest', 'preparation', 'cooking', 'recipe',
        'how to', 'growing', 'planting', 'care',
    ],
    'warnings': [
        'toxicité', 'toxique', 'danger', 'précaution', 'contre-indication',
        'allergie', 'intoxication', 'risque', 'avertissement', 'attention',
        'poison', 'nocif', 'dangereux', 'effet secondaire', 'sécurité',
        'toxicity', 'danger', 'warning', 'caution', 'risk', 'poison',
    ],
}


def _categorize_section(title):
    t = title.lower()
    for category, keywords in SECTION_CATEGORIES.items():
        if any(kw in t for kw in keywords):
            return category
    return 'other'


# JS exécuté dans la page pour extraire toutes les sections en une passe
_EXTRACT_JS = r"""
() => {
    const SKIP = new Set([
        'notes et références','voir aussi','liens externes','annexes',
        'bibliographie','références','notes','sources','galerie',
        'notes and references','see also','external links','further reading',
        'references','bibliography'
    ]);
    const clean = t => t
        .replace(/\[modifier[^\]]*\]/g,'')
        .replace(/\[\d+\]/g,'')
        .replace(/\s+/g,' ')
        .trim();
    const headingLevel = el => {
        const tag = el.tagName;
        if (tag==='H2'||tag==='H3'||tag==='H4') return parseInt(tag[1]);
        if (tag==='DIV' && el.classList.contains('mw-heading')) {
            if (el.classList.contains('mw-heading2')) return 2;
            if (el.classList.contains('mw-heading3')) return 3;
            if (el.classList.contains('mw-heading4')) return 4;
        }
        return 0;
    };
    const sections = [];
    let cur = {title:'__intro__', level:0, content:[]};
    const root = document.querySelector('#mw-content-text .mw-parser-output');
    if (!root) return sections;
    for (const el of root.children) {
        const lvl = headingLevel(el);
        if (lvl) {
            if (cur.content.length) sections.push(cur);
            cur = {title: clean(el.innerText), level: lvl, content: []};
        } else if (el.tagName === 'P') {
            const t = clean(el.innerText);
            if (t.length > 40) cur.content.push(t);
        } else if (el.tagName === 'UL' || el.tagName === 'OL') {
            const items = Array.from(el.querySelectorAll('li'))
                .map(li => '• ' + clean(li.innerText))
                .filter(s => s.length > 8);
            if (items.length) cur.content.push(items.join('\n'));
        } else if (el.tagName === 'DL') {
            const items = Array.from(el.querySelectorAll('dt,dd'))
                .map(d => (d.tagName==='DT'?'▸ ':'  ') + clean(d.innerText))
                .filter(s => s.trim().length > 3);
            if (items.length) cur.content.push(items.join('\n'));
        }
    }
    if (cur.content.length) sections.push(cur);
    return sections.filter(s => !SKIP.has(s.title.toLowerCase()));
}
"""


def scrape_wikipedia(url_or_title, lang='fr', json_output=False):
    from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout

    if url_or_title.startswith('http'):
        url = url_or_title
        # Détecter la langue depuis l'URL
        m = re.match(r'https?://([a-z]+)\.wikipedia', url)
        if m:
            lang = m.group(1)
    else:
        slug = quote(url_or_title.replace(' ', '_'))
        url = f"https://{lang}.wikipedia.org/wiki/{slug}"

    result = {
        'url': url, 'title': '', 'lang': lang,
        'summary': '', 'description': '', 'uses': '',
        'how_to_use': '', 'warnings': '', 'raw_sections': [],
        'external_links': [],
    }

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        ctx = browser.new_context(locale=f'{lang}-{lang.upper()}')
        page = ctx.new_page()
        try:
            page.goto(url, wait_until='domcontentloaded', timeout=25000)

            # Titre propre
            result['title'] = page.evaluate(
                "() => document.querySelector('h1')?.innerText?.trim() || document.title.split(' — ')[0].split(' - ')[0]"
            )

            # Extraction JS en une passe
            sections = page.evaluate(_EXTRACT_JS)
            result['raw_sections'] = sections

            # Intro = première section __intro__
            intro = next((s for s in sections if s['title'] == '__intro__'), None)
            if intro:
                result['summary'] = '\n\n'.join(intro['content'][:4])

            # Catégoriser et agréger les autres sections
            buckets = {'description': [], 'uses': [], 'how_to_use': [], 'warnings': [], 'other': []}
            for s in sections:
                if s['title'] == '__intro__':
                    continue
                cat = _categorize_section(s['title'])
                text = f"**{s['title']}**\n" + '\n\n'.join(s['content'])
                buckets[cat].append(text)

            result['description'] = '\n\n'.join(buckets['description'])
            result['uses'] = '\n\n'.join(buckets['uses'])
            result['how_to_use'] = '\n\n'.join(buckets['how_to_use'])
            result['warnings'] = '\n\n'.join(buckets['warnings'])

            # Si description vide, prendre le résumé
            if not result['description'] and result['summary']:
                result['description'] = result['summary']

            # Liens externes (section "Liens externes" + liens de références)
            result['external_links'] = page.evaluate(r"""
() => {
    const links = [];
    const seen = new Set();
    const skip = /wikipedia\.org|wikimedia|wikidata|commons\.|upload\.|Special:|Fichier:|File:|mediawiki/i;
    const add = (href, label, ctx) => {
        if (!href || skip.test(href) || seen.has(href)) return;
        if (!href.startsWith('http')) return;
        seen.add(href);
        links.push({url: href, label: (label||'').trim().slice(0,120), context: ctx||''});
    };
    // Section Liens externes / See also
    document.querySelectorAll('.mw-heading').forEach(h => {
        const t = h.innerText.toLowerCase();
        if (!t.includes('liens externes') && !t.includes('voir aussi') &&
            !t.includes('external links') && !t.includes('see also')) return;
        let el = h.nextElementSibling;
        while (el && !el.classList?.contains('mw-heading')) {
            el.querySelectorAll('a[href]').forEach(a =>
                add(a.href, a.innerText, 'external_links'));
            el = el.nextElementSibling;
        }
    });
    // Références et citations (liens inline dans le texte)
    document.querySelectorAll('.references a[href^="http"], .reflist a[href^="http"]')
        .forEach(a => add(a.href, a.innerText, 'reference'));
    return links.slice(0, 30);
}
""")


        except PWTimeout:
            result['error'] = f"Timeout : {url}"
        except Exception as e:
            result['error'] = str(e)
        finally:
            browser.close()

    return result


def main():
    parser = argparse.ArgumentParser(description="Scrape Wikipedia avec Playwright")
    parser.add_argument("target", help="URL Wikipedia ou titre d'article")
    parser.add_argument("--lang", default="fr")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    data = scrape_wikipedia(args.target, args.lang, args.json)

    if args.json:
        print(json.dumps(data, ensure_ascii=False, indent=2))
        return

    print(f"=== {data['title']} ===\n")
    for label, key in [("Résumé", "summary"), ("Description", "description"),
                        ("Utilisations", "uses"), ("Comment s'en servir", "how_to_use"),
                        ("Avertissements", "warnings")]:
        val = data.get(key, '').strip()
        if val:
            print(f"--- {label} ---")
            print(val[:800])
            print()


if __name__ == "__main__":
    main()
