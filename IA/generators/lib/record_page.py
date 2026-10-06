#!/usr/bin/env python3
"""
record_page.py — enregistre une page web VIVANTE en vidéo (simulateur, animation, démo interactive) avec des
actions scriptées, pour les plans « écran » animés de generate_scene.sh.

Usage : record_page.py <url> <sortie.mp4> <largeur> <hauteur> --duration S [--wait MS] [--actions JSON]

  --duration  durée de la séquence conservée, en secondes, comptée à partir du repère (« mark »)
  --wait      délai après le chargement de la page (défaut 4000 ms)
  --actions   liste JSON d'actions exécutées dans l'ordre :
                {"click": "#sel"}        clic sur un élément (CSS)
                {"mouse": [x, y]}        clic de souris : pixels, ou fractions de la fenêtre si x et y sont entre 0 et 1
                {"wait": 800}            pause (ms)
                {"js": "code"}           JavaScript dans la page
                {"mark": true}           début de la séquence conservée (sinon : avant la 1re action)
              Tout ce qui précède le repère (mise en place : démarrer un simulateur, aller au bon chapitre)
              est exécuté mais n'apparaît pas dans la vidéo.

Sortie : MP4 H.264 24 i/s à la taille demandée, avec une piste audio muette (plans concaténables).
Requiert playwright + chromium (environnement ~/.astro) et ffmpeg.
"""
import argparse
import asyncio
import json
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


async def record(url, out, width, height, duration, wait_ms, actions):
    from playwright.async_api import async_playwright

    tmp = Path(tempfile.mkdtemp(prefix="record_page_"))
    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch()
            ctx = await browser.new_context(viewport={"width": width, "height": height},
                                            record_video_dir=str(tmp), record_video_size={"width": width, "height": height})
            t_ctx = time.monotonic()
            page = await ctx.new_page()
            await page.goto(url, wait_until="domcontentloaded")
            await page.wait_for_timeout(wait_ms)
            marked = None
            for a in actions:
                if a.get("mark"):
                    marked = time.monotonic()
                    continue
                if marked is None and not any(x.get("mark") for x in actions):
                    marked = time.monotonic()      # pas de repère explicite : on garde tout depuis la 1re action
                if "click" in a:
                    await page.click(a["click"])
                elif "mouse" in a:
                    mx, my = a["mouse"]
                    if 0 <= mx <= 1 and 0 <= my <= 1:      # fractions de la fenêtre : valable quelle que soit la taille
                        mx, my = mx * width, my * height
                    await page.mouse.click(mx, my)
                elif "wait" in a:
                    await page.wait_for_timeout(int(a["wait"]))
                elif "js" in a:
                    await page.evaluate(a["js"])
            if marked is None:
                marked = time.monotonic()
            left = duration - (time.monotonic() - marked)
            if left > 0:
                await page.wait_for_timeout(int(left * 1000))
            await ctx.close()                       # finalise le fichier vidéo
            await browser.close()
        webm = next(tmp.glob("*.webm"))
        offset = max(0.0, marked - t_ctx)
        cmd = ["ffmpeg", "-v", "error", "-y", "-ss", f"{offset:.2f}", "-i", str(webm), "-t", f"{duration:.2f}",
               "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo",
               "-vf", f"fps=24,scale={width}:{height},format=yuv420p,setsar=1",
               "-c:v", "libx264", "-preset", "fast", "-crf", "18", "-c:a", "aac", "-ar", "48000", "-ac", "2",
               "-shortest", out]
        subprocess.run(cmd, check=True)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("url")
    ap.add_argument("out")
    ap.add_argument("width", type=int)
    ap.add_argument("height", type=int)
    ap.add_argument("--duration", type=float, required=True)
    ap.add_argument("--wait", type=int, default=4000)
    ap.add_argument("--actions", default="[]")
    a = ap.parse_args()
    try:
        actions = json.loads(a.actions)
        assert isinstance(actions, list)
    except (ValueError, AssertionError):
        print("Erreur : --actions doit être une liste JSON", file=sys.stderr)
        sys.exit(2)
    asyncio.run(record(a.url, a.out, a.width, a.height, a.duration, a.wait, actions))
    print(a.out)


if __name__ == "__main__":
    main()
