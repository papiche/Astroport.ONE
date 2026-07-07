#!/usr/bin/env python3
"""
page_screenshot.py — Screenshot headless Chromium via Playwright
Remplace pyppeteer (abandonné depuis 2022) par playwright (Microsoft, maintenu).
Pas de dépendance sur `websockets` → plus de conflit avec uvicorn.

Installation :
    pip install playwright
    playwright install chromium   # ou: python -m playwright install chromium
    # Pour utiliser le Chromium système (apt install chromium) :
    #   PLAYWRIGHT_BROWSERS_PATH=0 playwright install chromium --with-deps
"""

# Auto-reinvocation dans le venv ~/.astro/ si dépendances absentes
import sys as _sys
import os as _os
_venv_python = _os.path.expanduser("~/.astro/bin/python3")
if _os.path.exists(_venv_python) and _sys.executable != _venv_python:
    _os.execv(_venv_python, [_venv_python] + _sys.argv)
del _sys, _os

import asyncio
import sys
import os
from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeout, Error as PlaywrightError


async def take_screenshot(url, output_file, width, height):
    async with async_playwright() as p:
        browser = None
        try:
            # Détecte le Chromium système si disponible (évite double téléchargement)
            import subprocess
            chromium_path = (
                subprocess.run(['which', 'chromium'], capture_output=True, text=True).stdout.strip()
                or subprocess.run(['which', 'chromium-browser'], capture_output=True, text=True).stdout.strip()
                or None
            )

            launch_kwargs = dict(
                headless=True,
                args=[
                    '--disable-gpu',
                    '--no-sandbox',
                    '--disable-setuid-sandbox',
                    '--disable-dev-shm-usage',
                    '--disable-web-security',
                    '--disable-features=IsolateOrigins,site-per-process',
                ]
            )
            if chromium_path:
                launch_kwargs['executable_path'] = chromium_path

            browser = await p.chromium.launch(**launch_kwargs)
            page = await browser.new_page()

            # Taille de la fenêtre
            await page.set_viewport_size({'width': width, 'height': height})

            # Navigation avec timeout étendu pour le contenu IPFS
            print(f"Loading URL: {url}", file=sys.stderr)
            await page.goto(url, wait_until='networkidle', timeout=45000)

            # Attente des tuiles Leaflet avec retry
            tiles_loaded = False
            for attempt in range(3):
                try:
                    await page.wait_for_function(
                        '''() => {
                            const tiles = document.querySelectorAll('.leaflet-tile-loaded');
                            return tiles.length > 0;
                        }''',
                        timeout=15000
                    )
                    tiles_loaded = True
                    break
                except PlaywrightTimeout:
                    if attempt < 2:
                        print(f"Tiles not loaded yet, retry {attempt + 1}/3...", file=sys.stderr)
                        await asyncio.sleep(2)

            if not tiles_loaded:
                print("Warning: Tiles may not be fully loaded, taking screenshot anyway", file=sys.stderr)

            # Capture
            await page.screenshot(path=output_file, full_page=False)

            if os.path.exists(output_file) and os.path.getsize(output_file) > 0:
                print(f"Screenshot saved: {output_file} ({os.path.getsize(output_file)} bytes)", file=sys.stderr)
                return True
            else:
                print("Error: Screenshot file not created or empty", file=sys.stderr)
                return False

        except PlaywrightTimeout as e:
            print(f"Timeout error: {e}", file=sys.stderr)
            return False
        except PlaywrightError as e:
            print(f"Playwright error (URL unreachable?): {e}", file=sys.stderr)
            return False
        except Exception as e:
            print(f"Unexpected error: {type(e).__name__}: {e}", file=sys.stderr)
            return False
        finally:
            if browser:
                try:
                    # Timeout borné sur le cleanup lui-même : si browser.close()
                    # pend (chromium ne répond plus), on ne veut pas que ce
                    # nettoyage devienne à son tour un blocage sans fin — mieux
                    # vaut abandonner proprement que de laisser le process
                    # entier suspendu au-delà du timeout global de main().
                    await asyncio.wait_for(browser.close(), timeout=10)
                except Exception:
                    pass


def main():
    if len(sys.argv) != 5:
        print("Usage: python page_screenshot.py <URL> <output_file> <width> <height>", file=sys.stderr)
        sys.exit(1)

    url = sys.argv[1]
    output_file = sys.argv[2]

    try:
        width = int(sys.argv[3])
        height = int(sys.argv[4])
    except ValueError as e:
        print(f"Invalid dimensions: {e}", file=sys.stderr)
        sys.exit(1)

    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    # Tâche créée explicitement (plutôt que passée directement à wait_for) pour
    # pouvoir la ré-attendre nous-mêmes après un TimeoutError : asyncio.wait_for
    # annule déjà la tâche interne et attend sa fin avant de lever l'exception
    # (CPython >= 3.8, _cancel_and_wait), mais ce ré-await explicite est une
    # garantie supplémentaire bon marché que le `finally: await browser.close()`
    # de take_screenshot() a bien fini de tourner avant qu'on ferme la loop —
    # sans ça, un chromium headless peut survivre en zombie si jamais ce
    # comportement venait à changer (dépendance implicite non testée ici).
    task = loop.create_task(take_screenshot(url, output_file, width, height))
    try:
        success = loop.run_until_complete(asyncio.wait_for(task, timeout=90))
        if not success:
            sys.exit(1)
    except asyncio.TimeoutError:
        print("Global timeout (90s): URL may be unreachable or IPFS slow", file=sys.stderr)
        # Toujours consommer le résultat/l'exception de la tâche, qu'elle soit
        # déjà terminée ou pas : entre l'annulation par wait_for et ce point,
        # la tâche peut avoir fini (avec sa propre exception) sans que
        # personne ne l'ait jamais lue — sinon asyncio log un warning
        # "exception was never retrieved" à la destruction du Future.
        try:
            loop.run_until_complete(task)
        except (asyncio.CancelledError, Exception):
            pass
        sys.exit(1)
    except KeyboardInterrupt:
        print("Interrupted by user", file=sys.stderr)
        sys.exit(130)
    finally:
        loop.close()


if __name__ == "__main__":
    main()
