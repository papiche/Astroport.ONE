#!/bin/sh
''''exec "$HOME/.astro/bin/python3" "$0" "$@"
'''
__usage__ = """
recorder.py — Surveillance vidéo VDO.ninja → uDRIVE

  Ouvre une room VDO.ninja dans un navigateur Chromium headless (Playwright),
  capture les frames WebRTC, détecte les mouvements par différence d'image
  (OpenCV) et sauvegarde automatiquement les séquences en MP4 dans le uDRIVE
  du Capitaine de la station.

USAGE
  recorder.py <ROOM>              Lancer en avant-plan (Ctrl+C pour arrêter)
  recorder.py <ROOM> --daemon     Lancer en arrière-plan (démon détaché)
  recorder.py --list              Lister les rooms surveillées et leur état
  recorder.py --close <ROOM>      Arrêter la surveillance d'une room
  recorder.py --close all         Arrêter toutes les rooms actives
  recorder.py --help | -h         Afficher cette aide

ARGUMENTS
  <ROOM>    Nom de la room VDO.ninja (ex: maRoom42).
            URL résolue : https://vdo.copylaradio.com/?scene&cleanoutput&autoplay&room=<ROOM>

DÉTECTION DE MOUVEMENT
  Seuil     10 000 pixels activés après blur + seuillage (MOTION_THRESHOLD)
  Calme     10 s sans mouvement → fin de séquence et sauvegarde (CALM_DELAY)
  Rotation  60 s max par segment → nouveau fichier automatiquement (SEGMENT_MAX)
  FPS       ~10 fps (capture canvas JS toutes les 100 ms)

FICHIERS DE SORTIE
  ~/.zen/game/nostr/<CAPTAINEMAIL>/APP/uDRIVE/Videos/alerte_<ts>_seg<NN>.mp4
  <ts>  = timestamp Unix du début de la séquence
  <NN>  = numéro de segment (01, 02…) en cas de rotation

  CAPTAINEMAIL est lu depuis $CAPTAINEMAIL ou ~/.zen/Astroport.ONE/.env

DÉMON (--daemon)
  Lance le processus en arrière-plan avec start_new_session.
  Logs  : ~/.zen/tmp/uplanet_udrive_<room>.log
  PID   : /tmp/uplanet_udrive_recorder_<room>.pid
  Arrêt : recorder.py --close <ROOM>  (SIGTERM propre, sauvegarde le segment en cours)
  Un second lancement sur la même room est silencieusement ignoré (verrou PID).

DÉPENDANCES
  pip install playwright opencv-python numpy
  playwright install chromium
  Python : ~/.astro/bin/python3  (venv Astroport)
"""
import base64
import cv2
import numpy as np
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from playwright.sync_api import sync_playwright

VDO_BASE = "https://vdo.copylaradio.com/?scene&cleanoutput&autoplay&room="


def pid_file(room):
    return Path(tempfile.gettempdir()) / f"uplanet_udrive_recorder_{room.lower()}.pid"


PYTHON = Path.home() / ".astro/bin/python3"


def log_file(room):
    log_dir = Path.home() / ".zen/tmp"
    log_dir.mkdir(parents=True, exist_ok=True)
    return log_dir / f"uplanet_udrive_{room.lower()}.log"


def list_active():
    tmp = Path(tempfile.gettempdir())
    pids = sorted(tmp.glob("uplanet_udrive_recorder_*.pid"))
    if not pids:
        print("Aucun enregistreur actif.")
        return
    print(f"{'ROOM':<20} {'PID':<8} {'ÉTAT':<20} LOGS")
    print("-" * 70)
    for pf in pids:
        room = pf.stem.replace("uplanet_udrive_recorder_", "").upper()
        pid = int(pf.read_text().strip())
        try:
            os.kill(pid, 0)
            state = "actif"
        except ProcessLookupError:
            state = "mort (PID obsolète)"
        lf = log_file(room.lower())
        log_info = str(lf) if lf.exists() else "(pas de log)"
        print(f"{room:<20} {pid:<8} {state:<20} {log_info}")


def close_room(room):
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
            pass
    pf.write_text(str(os.getpid()))


def release_pid_lock(room):
    pf = pid_file(room)
    if pf.exists():
        pf.unlink()


def run_as_daemon(room):
    lf = log_file(room)
    cmd = [str(PYTHON), sys.argv[0], room]
    with open(lf, 'a') as f:
        proc = subprocess.Popen(cmd, stdout=f, stderr=f, start_new_session=True)
    print(f"[{room}] Démon lancé (PID {proc.pid})")
    print(f"[{room}] Logs : {lf}")
    print(f"[{room}] Arrêt : python3 {sys.argv[0]} --close {room}")
    sys.exit(0)


def parse_args():
    argv = [a for a in sys.argv[1:] if a != '--daemon']
    daemon = '--daemon' in sys.argv[1:]

    if not argv:
        print(__usage__)
        sys.exit(1)
    if argv[0] in ("--help", "-h"):
        print(__usage__)
        sys.exit(0)
    if argv[0] == "--list":
        list_active()
        sys.exit(0)
    if argv[0] == "--close":
        if len(argv) < 2:
            print("Usage : --close <ROOM> ou --close all")
            sys.exit(1)
        close_room(argv[1])
        sys.exit(0)
    return argv[0], daemon


def get_captainemail():
    email = os.getenv("CAPTAINEMAIL", "")
    if email:
        print(f"[init] CAPTAINEMAIL via env : {email}")
        return email
    env_file = Path.home() / ".zen" / "Astroport.ONE" / ".env"
    print(f"[init] CAPTAINEMAIL non défini, lecture de {env_file}")
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            if line.startswith("CAPTAINEMAIL="):
                email = line.split("=", 1)[1].strip().strip("'\"")
                print(f"[init] CAPTAINEMAIL trouvé dans .env : {email}")
                return email
    print(f"[init] CAPTAINEMAIL introuvable dans {env_file}")
    return ""


def get_output_dir():
    email = get_captainemail()
    if not email:
        raise RuntimeError("CAPTAINEMAIL introuvable — source tools/my.sh ou définir la variable d'env")
    path = Path.home() / ".zen" / "game" / "nostr" / email / "APP" / "uDRIVE" / "Videos"
    path.mkdir(parents=True, exist_ok=True)
    print(f"[init] Dossier de sortie : {path}")
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

    # Flag d'arrêt propre (SIGTERM depuis --close ou systemd)
    shutdown = [False]

    def _sigterm(signum, frame):
        print(f"[{room}] SIGTERM reçu — arrêt propre en cours...")
        shutdown[0] = True

    signal.signal(signal.SIGTERM, _sigterm)

    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True,
            args=["--autoplay-policy=no-user-gesture-required"],
        )
        page = browser.new_page()
        print(f"[{room}] Connexion à {url}")
        page.goto(url)

        print(f"[{room}] Attente du sélecteur vidéo...")
        page.wait_for_selector("video", state="attached", timeout=60000)

        print(f"[{room}] Attente du flux WebRTC (videoWidth > 0)...")
        page.wait_for_function(
            "() => { const v = document.querySelector('video'); return v && v.videoWidth > 0; }",
            timeout=60000,
        )
        print(f"[{room}] Flux actif.")

        CALM_DELAY = 10        # secondes sans mouvement → sauvegarde
        SEGMENT_MAX = 60       # durée max d'un tronçon → rotation
        MOTION_THRESHOLD = 10000

        output_dir = get_output_dir()
        prev_frame = None
        recording = False
        out = None
        tmp_path = None
        start_ts = None
        segment_num = 0
        segment_start = None
        last_motion_time = None
        frame_count = 0
        last_idle_log = 0.0
        last_rec_log = 0.0

        def save_segment(forced=False):
            nonlocal out, tmp_path, recording, start_ts, segment_start, last_motion_time
            out.release()
            out = None
            duration = int(time.time() - segment_start)
            dest = output_dir / f"alerte_{start_ts}_seg{segment_num:02d}.mp4"
            shutil.move(tmp_path, dest)
            label = "Interrompu" if forced else "Segment"
            print(f"[{room}] {label} sauvegardé : {dest.name} ({duration}s)")
            tmp_path = None
            recording = False
            start_ts = None
            segment_start = None
            last_motion_time = None

        def start_segment(now, h, w):
            nonlocal out, tmp_path, recording, start_ts, segment_num, segment_start
            fd, tmp_path = tempfile.mkstemp(suffix=".mp4", prefix="uplanet_")
            os.close(fd)
            out = cv2.VideoWriter(tmp_path, cv2.VideoWriter_fourcc(*'mp4v'), 10.0, (w, h))
            if not out.isOpened():
                print(f"[{room}] ERREUR VideoWriter : impossible d'ouvrir {tmp_path} ({w}x{h})")
                out = None
                return
            start_ts = int(now)
            segment_num += 1
            segment_start = now
            recording = True
            print(f"[{room}] MOUVEMENT — enregistrement démarré "
                  f"(segment {segment_num}, {w}x{h}, seuil={MOTION_THRESHOLD})")

        try:
            while not shutdown[0]:
                frame = capture_frame(page)
                now = time.time()

                if frame is None:
                    time.sleep(0.5)
                    continue

                frame_count += 1
                h, w = frame.shape[:2]

                if frame_count == 1:
                    print(f"[{room}] Première frame : {w}x{h}")

                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                gray = cv2.GaussianBlur(gray, (21, 21), 0)

                if prev_frame is None or prev_frame.shape != gray.shape:
                    if prev_frame is not None:
                        print(f"[{room}] Résolution changée → réinitialisation")
                    prev_frame = gray
                    continue

                frame_delta = cv2.absdiff(prev_frame, gray)
                thresh = cv2.threshold(frame_delta, 25, 255, cv2.THRESH_BINARY)[1]
                thresh = cv2.dilate(thresh, None, iterations=2)
                motion_score = int(np.sum(thresh))
                motion = motion_score > MOTION_THRESHOLD

                if not recording:
                    # Log IDLE toutes les 15s
                    if now - last_idle_log > 15.0:
                        print(f"[{room}] [IDLE] score={motion_score} frames={frame_count}")
                        last_idle_log = now
                    if motion:
                        start_segment(now, h, w)
                        if out:
                            last_motion_time = now
                            out.write(frame)
                else:
                    if out:
                        out.write(frame)
                    if motion:
                        last_motion_time = now

                    calm_elapsed = now - last_motion_time
                    seg_elapsed  = now - segment_start

                    # Log REC toutes les 2s avec détail
                    if now - last_rec_log > 2.0:
                        mvt_label = "MOUVEMENT" if motion else f"calme {calm_elapsed:.1f}s/{CALM_DELAY}s"
                        print(f"[{room}] [REC seg={segment_num} dur={seg_elapsed:.0f}s] "
                              f"score={motion_score} {mvt_label}")
                        last_rec_log = now

                    if calm_elapsed >= CALM_DELAY:
                        print(f"[{room}] Calme depuis {CALM_DELAY}s → fin de séquence")
                        save_segment()
                    elif seg_elapsed >= SEGMENT_MAX:
                        print(f"[{room}] Rotation à {SEGMENT_MAX}s → retour idle")
                        save_segment()

                prev_frame = gray
                time.sleep(0.1)

        except KeyboardInterrupt:
            print(f"[{room}] Arrêt par l'utilisateur (Ctrl+C)")
        finally:
            if recording and out:
                print(f"[{room}] Sauvegarde du segment en cours...")
                save_segment(forced=True)
            elif out:
                out.release()
            if tmp_path and Path(tmp_path).exists():
                Path(tmp_path).unlink()
            try:
                browser.close()
            except Exception:
                pass
        print(f"[{room}] Démon arrêté. Segments sauvegardés : {segment_num}")


if __name__ == "__main__":
    room, daemon = parse_args()
    if daemon:
        run_as_daemon(room)
    acquire_pid_lock(room)
    try:
        detect_motion(room)
    finally:
        release_pid_lock(room)
