#!/usr/bin/env python3
import base64
import cv2
import numpy as np
import os
import shutil
import tempfile
import time
from pathlib import Path
from playwright.sync_api import sync_playwright

# >>>>>>
# pip install playwright opencv-python numpy
# playwright install chromium
# <<<<<<

# URL avec paramètres pour faciliter la capture
# &cleanoutput cache l'interface, &autoplay force la lecture
URL = "https://vdo.copylaradio.com/?scene&room=UPLANET&cleanoutput&autoplay"

def get_captainemail():
    email = os.getenv("CAPTAINEMAIL", "")
    if not email:
        env_file = Path.home() / ".zen" / "Astroport.ONE" / ".env"
        if env_file.exists():
            for line in env_file.read_text().splitlines():
                if line.startswith("CAPTAINEMAIL="):
                    email = line.split("=", 1)[1].strip().strip("'\"")
                    break
    return email

def get_output_dir():
    email = get_captainemail()
    if not email:
        raise RuntimeError("CAPTAINEMAIL introuvable — source tools/my.sh ou définir la variable d'env")
    path = Path.home() / ".zen" / "game" / "nostr" / email / "APP" / "uDRIVE" / "Videos"
    path.mkdir(parents=True, exist_ok=True)
    return path

JS_CAPTURE = """() => {
    const v = document.querySelector('video');
    if (!v || v.videoWidth === 0) return null;
    const c = document.createElement('canvas');
    c.width = v.videoWidth;
    c.height = v.videoHeight;
    c.getContext('2d').drawImage(v, 0, 0);
    return c.toDataURL('image/png').split(',')[1];
}"""

def capture_frame(page):
    b64 = page.evaluate(JS_CAPTURE)
    if not b64:
        return None
    return cv2.imdecode(np.frombuffer(base64.b64decode(b64), np.uint8), cv2.IMREAD_COLOR)

def detect_motion():
    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True,
            args=["--autoplay-policy=no-user-gesture-required"],
        )
        page = browser.new_page()
        page.goto(URL)

        print("Attente du flux vidéo...")
        # aria-hidden="true" sur la vidéo => state="attached", pas "visible"
        page.wait_for_selector("video", state="attached", timeout=60000)

        # Attendre que videoWidth > 0 (flux WebRTC établi)
        page.wait_for_function(
            "() => { const v = document.querySelector('video'); return v && v.videoWidth > 0; }",
            timeout=60000,
        )
        print("Flux actif. Analyse en cours... Appuyez sur Ctrl+C pour arrêter.")

        CALM_DELAY = 30  # secondes sans mouvement avant de sauvegarder
        output_dir = get_output_dir()
        prev_frame = None
        recording = False
        out = None
        tmp_path = None
        start_ts = None
        last_motion_time = None

        try:
            while True:
                frame = capture_frame(page)
                if frame is None:
                    time.sleep(0.5)
                    continue

                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                gray = cv2.GaussianBlur(gray, (21, 21), 0)

                if prev_frame is None:
                    prev_frame = gray
                    continue

                frame_delta = cv2.absdiff(prev_frame, gray)
                thresh = cv2.threshold(frame_delta, 25, 255, cv2.THRESH_BINARY)[1]
                thresh = cv2.dilate(thresh, None, iterations=2)
                motion_level = np.sum(thresh)
                now = time.time()

                if motion_level > 10000:
                    last_motion_time = now
                    if not recording:
                        print("MOUVEMENT DÉTECTÉ — début enregistrement")
                        recording = True
                        start_ts = int(now)
                        h, w, _ = frame.shape
                        fd, tmp_path = tempfile.mkstemp(suffix=".mp4", prefix="uplanet_")
                        os.close(fd)
                        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
                        out = cv2.VideoWriter(tmp_path, fourcc, 10.0, (w, h))
                    out.write(frame)
                else:
                    if recording:
                        out.write(frame)  # continuer à enregistrer pendant le calme
                        elapsed = now - last_motion_time
                        if elapsed >= CALM_DELAY:
                            out.release()
                            out = None
                            dest = output_dir / f"alerte_{start_ts}.mp4"
                            shutil.move(tmp_path, dest)
                            print(f"Calme depuis {CALM_DELAY}s — vidéo sauvegardée : {dest}")
                            recording = False
                            tmp_path = None
                            start_ts = None

                prev_frame = gray
                time.sleep(0.1)

        except KeyboardInterrupt:
            print("Arrêt par l'utilisateur")
        finally:
            if out:
                out.release()
            if tmp_path and Path(tmp_path).exists():
                Path(tmp_path).unlink()
            browser.close()

if __name__ == "__main__":
    detect_motion()
