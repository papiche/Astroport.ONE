#!/usr/bin/env python3
"""
capture_page.py — capture d'écran d'une page web (ou d'un fichier HTML local)
pour les plans "screen" et "card" de generate_scene.sh.

Usage : capture_page.py <url|fichier.html> <sortie.png> <largeur> <hauteur> [--full] [--wait MS] [--js CODE]...
  --full  page entière (plus haute que la fenêtre → plan en défilement)
  --wait  délai après chargement pour les cartes et scripts (défaut 4000 ms)
  --js    JavaScript exécuté dans la page avant la capture (répétable, 1,5 s après
          chacun) : cliquer un onglet, remplir un champ, avancer un assistant…

Requiert playwright + chromium (environnement ~/.astro).
"""

import argparse
import asyncio
import pathlib

from playwright.async_api import async_playwright

# Certains serveurs de tuiles refusent l'agent « HeadlessChrome »
USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36"


async def capture(url, out, width, height, full, wait_ms, scripts):
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page(viewport={"width": width, "height": height},
                                      device_scale_factor=1, user_agent=USER_AGENT)
        await page.goto(url, wait_until="networkidle", timeout=60000)
        await page.wait_for_timeout(wait_ms)
        for code in scripts:
            await page.evaluate(code)
            await page.wait_for_timeout(1500)
        await page.screenshot(path=out, full_page=full)
        await browser.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("url")
    parser.add_argument("out")
    parser.add_argument("width", type=int)
    parser.add_argument("height", type=int)
    parser.add_argument("--full", action="store_true")
    parser.add_argument("--wait", type=int, default=4000)
    parser.add_argument("--js", action="append", default=[])
    args = parser.parse_args()
    url = args.url
    if "://" not in url:
        url = pathlib.Path(url).resolve().as_uri()
    asyncio.run(capture(url, args.out, args.width, args.height, args.full, args.wait, args.js))


if __name__ == "__main__":
    main()
