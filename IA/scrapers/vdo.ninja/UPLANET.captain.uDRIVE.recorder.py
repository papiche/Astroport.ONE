#!/usr/bin/env python3
"""
UPLANET.captain.uDRIVE.recorder.py — Enregistreur de mouvement VDO.ninja

Capture le flux vidéo d'une room VDO.ninja, détecte les mouvements et
sauvegarde automatiquement les séquences en MP4 dans uDRIVE/Videos.

Usage:
    python3 UPLANET.captain.uDRIVE.recorder.py <ROOM>       # démarrer
    python3 UPLANET.captain.uDRIVE.recorder.py --list        # lister les rooms actives
    python3 UPLANET.captain.uDRIVE.recorder.py --close <ROOM> # arrêter une room
    python3 UPLANET.captain.uDRIVE.recorder.py --close all    # arrêter toutes les rooms

Comportement:
    - Surveille en continu le flux de la room indiquée
    - Commence à enregistrer dès qu'un mouvement est détecté
    - Sauvegarde la vidéo après 30s sans mouvement
    - Fichier : ~/.zen/game/nostr/<CAPTAINEMAIL>/APP/uDRIVE/Videos/alerte_<ts>.mp4
    - Instance unique par room : un second lancement est ignoré

Dépendances:
    pip install playwright opencv-python numpy
    playwright install chromium
"""
import base64
import cv2
import numpy as np
import os
import shutil
import sys
import tempfile
import time
from pathlib import Path
from playwright.sync_api import sync_playwright

VDO_BASE = "https://vdo.copylaradio.com/?scene&cleanoutput&autoplay&room="

def pid_file(room):
    return Path(tempfile.gettempdir()) / f"uplanet_udrive_recorder_{room.lower()}.pid"

def list_active():
    tmp = Path(tempfile.gettempdir())
    pids = sorted(tmp.glob("uplanet_udrive_recorder_*.pid"))
    if not pids:
        print("Aucun enregistreur actif.")
        return
    print(f"{'ROOM':<20} {'PID':<8} {'ÉTAT'}")
    print("-" * 40)
    for pf in pids:
        room = pf.stem.replace("uplanet_udrive_recorder_", "").upper()
        pid = int(pf.read_text().strip())
        try:
            os.kill(pid, 0)
            state = "actif"
        except ProcessLookupError:
            state = "mort (PID obsolète)"
        print(f"{room:<20} {pid:<8} {state}")

def close_room(room):
    import signal
    targets = []
    if room.lower() == "all":
        tmp = Path(tempfile.gettempdir())
        targets = [(pf.stem.replace("uplanet_udrive_recorder_", "").upper(), pf)
                   for pf in tmp.glob("uplanet_udrive_recorder_*.pid")]
    else:
        targets = [(room.upper(), pid_file(room))]
    if not targets:
        print("Aucun enregistreur trouvé.")
        return
    for name, pf in targets:
        if not pf.exists():
            print(f"[{name}] Pas de PID file — déjà arrêté ?")
            continue
        pid = int(pf.read_text().strip())
        try:
            os.kill(pid, signal.SIGTERM)
            print(f"[{name}] SIGTERM envoyé au PID {pid}")
        except ProcessLookupError:
            print(f"[{name}] Process {pid} introuvable — nettoyage du PID file")
            pf.unlink()

def acquire_pid_lock(room):
    pf = pid_file(room)
    if pf.exists():
        pid = int(pf.read_text().strip())
        try:
            os.kill(pid, 0)
            print(f"[{room}] Déjà en cours (PID {pid}) — arrêt.")
            sys.exit(0)
        except ProcessLookupError:
            pass  # process mort, PID file obsolète
    pf.write_text(str(os.getpid()))

def release_pid_lock(room):
    pf = pid_file(room)
    if pf.exists():
        pf.unlink()

def parse_args():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    if sys.argv[1] == "--list":
        list_active()
        sys.exit(0)
    if sys.argv[1] == "--close":
        if len(sys.argv) < 3:
            print("Usage : --close <ROOM> ou --close all")
            sys.exit(1)
        close_room(sys.argv[2])
        sys.exit(0)
    return sys.argv[1]

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

def detect_motion(room):
    url = VDO_BASE + room
    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True,
            args=["--autoplay-policy=no-user-gesture-required"],
        )
        page = browser.new_page()
        print(f"[{room}] Connexion à {url}")
        page.goto(url)

        print("Attente du flux vidéo...")
        # aria-hidden="true" sur la vidéo => state="attached", pas "visible"
        page.wait_for_selector("video", state="attached", timeout=60000)

        # Attendre que videoWidth > 0 (flux WebRTC établi)
        page.wait_for_function(
            "() => { const v = document.querySelector('video'); return v && v.videoWidth > 0; }",
            timeout=60000,
        )
        print(f"[{room}] Flux actif. Analyse en cours... Appuyez sur Ctrl+C pour arrêter.")

        CALM_DELAY = 10        # secondes sans mouvement → sauvegarde et retour idle
        SEGMENT_MAX = 60       # durée max d'un tronçon → rotation forcée
        MOTION_THRESHOLD = 10000

        output_dir = get_output_dir()
        prev_frame = None
        # États : idle / recording
        recording = False
        out = None
        tmp_path = None
        start_ts = None
        segment_start = None
        last_motion_time = None

        def save_segment():
            nonlocal out, tmp_path, recording, start_ts, segment_start, last_motion_time
            out.release()
            out = None
            dest = output_dir / f"alerte_{start_ts}_{int(segment_start)}.mp4"
            shutil.move(tmp_path, dest)
            print(f"[{room}] Tronçon sauvegardé : {dest.name}")
            tmp_path = None
            recording = False
            start_ts = None
            segment_start = None
            last_motion_time = None

        def start_segment(now, h, w):
            nonlocal out, tmp_path, recording, start_ts, segment_start
            fd, tmp_path = tempfile.mkstemp(suffix=".mp4", prefix="uplanet_")
            os.close(fd)
            out = cv2.VideoWriter(tmp_path, cv2.VideoWriter_fourcc(*'mp4v'), 10.0, (w, h))
            start_ts = int(now)
            segment_start = now
            recording = True
            print(f"[{room}] MOUVEMENT — enregistrement démarré")

        try:
            while True:
                frame = capture_frame(page)
                if frame is None:
                    time.sleep(0.5)
                    continue

                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                gray = cv2.GaussianBlur(gray, (21, 21), 0)

                if prev_frame is None or prev_frame.shape != gray.shape:
                    prev_frame = gray
                    continue

                frame_delta = cv2.absdiff(prev_frame, gray)
                thresh = cv2.threshold(frame_delta, 25, 255, cv2.THRESH_BINARY)[1]
                thresh = cv2.dilate(thresh, None, iterations=2)
                motion = np.sum(thresh) > MOTION_THRESHOLD
                now = time.time()

                if not recording:
                    # IDLE : on attend un mouvement pour démarrer
                    if motion:
                        h, w, _ = frame.shape
                        start_segment(now, h, w)
                        last_motion_time = now
                        out.write(frame)
                else:
                    # RECORDING : on écrit la frame courante
                    out.write(frame)
                    if motion:
                        last_motion_time = now

                    calm_elapsed = now - last_motion_time
                    seg_elapsed  = now - segment_start

                    if calm_elapsed >= CALM_DELAY:
                        # 10s sans mouvement → fin de séquence
                        print(f"[{room}] Calme depuis {CALM_DELAY}s → fin de séquence")
                        save_segment()
                    elif seg_elapsed >= SEGMENT_MAX:
                        # Tronçon trop long → rotation, retour idle
                        print(f"[{room}] Rotation à {SEGMENT_MAX}s → retour idle")
                        save_segment()

                prev_frame = gray
                time.sleep(0.1)

        except KeyboardInterrupt:
            print(f"[{room}] Arrêt par l'utilisateur")
        finally:
            if out:
                out.release()
            if tmp_path and Path(tmp_path).exists():
                Path(tmp_path).unlink()
            try:
                browser.close()
            except Exception:
                pass

if __name__ == "__main__":
    room = parse_args()
    acquire_pid_lock(room)
    try:
        detect_motion(room)
    finally:
        release_pid_lock(room)
