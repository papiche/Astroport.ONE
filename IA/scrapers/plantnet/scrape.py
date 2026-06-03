#!/usr/bin/env python3
"""
scrapers/plantnet/scrape.py — Extrait la fiche espèce PlantNet via Playwright.
Usage : scrape.py <nom_scientifique_ou_url> [--json]
Retourne : {scientific_name, common_names, description, uses, characteristics, images}
"""

import sys
import os
_venv_python = os.path.expanduser("~/.astro/bin/python3")
if os.path.exists(_venv_python) and sys.executable != _venv_python:
    os.execv(_venv_python, [_venv_python] + sys.argv)

import json
import argparse
from urllib.parse import quote


def scrape_plantnet(species_or_url, lang='fr', json_output=False):
    from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout

    if species_or_url.startswith('http'):
        url = species_or_url
    else:
        slug = species_or_url.lower().replace(' ', '-')
        url = f"https://identify.plantnet.org/{lang}/k-world-flora/species/{slug}/view"

    result = {
        'url': url,
        'scientific_name': '',
        'common_names': [],
        'description': '',
        'uses': '',
        'characteristics': '',
        'images': [],
    }

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        try:
            page.goto(url, wait_until='networkidle', timeout=30000)

            # Nom scientifique
            try:
                result['scientific_name'] = page.locator('h1').first.inner_text(timeout=5000).strip()
            except Exception:
                pass

            # Noms communs
            try:
                common = page.locator('[class*="common-name"], [class*="vernacular"]').all_inner_texts()
                result['common_names'] = [n.strip() for n in common if n.strip()]
            except Exception:
                pass

            # Description / Caractéristiques
            try:
                desc_el = page.locator('[class*="description"], [class*="characteristic"]').first
                result['description'] = desc_el.inner_text(timeout=5000).strip()[:1000]
            except Exception:
                pass

            # Utilisations
            try:
                uses_el = page.locator('[class*="use"], [class*="usage"]').first
                result['uses'] = uses_el.inner_text(timeout=3000).strip()[:800]
            except Exception:
                pass

            # Fallback : scraper le texte général de la page si peu de données
            if not result['description'] and not result['uses']:
                try:
                    body_text = page.locator('main, article, [class*="content"]').first.inner_text(timeout=5000)
                    result['description'] = body_text.strip()[:1200]
                except Exception:
                    pass

            # Images représentatives
            try:
                imgs = page.locator('img[src*="plantnet"]').all()
                result['images'] = [img.get_attribute('src') for img in imgs[:3] if img.get_attribute('src')]
            except Exception:
                pass

        except PWTimeout:
            result['error'] = f"Timeout : {url}"
        except Exception as e:
            result['error'] = str(e)
        finally:
            browser.close()

    return result


def main():
    parser = argparse.ArgumentParser(description="Scrape fiche espèce PlantNet")
    parser.add_argument("target", help="Nom scientifique ou URL PlantNet")
    parser.add_argument("--lang", default="fr")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    data = scrape_plantnet(args.target, args.lang, args.json)

    if args.json:
        print(json.dumps(data, ensure_ascii=False, indent=2))
    else:
        print(f"=== {data.get('scientific_name', data['url'])} ===")
        if data.get('common_names'):
            print(f"Noms communs : {', '.join(data['common_names'])}")
        if data.get('description'):
            print(f"\nDescription :\n{data['description'][:600]}")
        if data.get('uses'):
            print(f"\nUtilisations :\n{data['uses'][:600]}")


if __name__ == "__main__":
    main()
