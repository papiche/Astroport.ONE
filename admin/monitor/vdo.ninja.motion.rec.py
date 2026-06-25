import cv2
import numpy as np
import time
import argparse
import os
import subprocess
import threading
from playwright.sync_api import sync_playwright

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ASTROPORT_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, '..', '..'))
RECORD_DIR = os.path.expanduser('~/.zen/tmp')


def get_default_player():
    """Lit l'email du capitaine courant depuis ~/.zen/game/players/.current/.player"""
    try:
        current_link = os.path.expanduser('~/.zen/game/players/.current')
        current_dir = os.path.realpath(current_link)
        with open(os.path.join(current_dir, '.player')) as f:
            return f.read().strip()
    except Exception:
        return ''


def publish_video(avi_file, player, room):
    """Publie l'enregistrement comme vidéo NOSTR Tube via ajouter_media.sh"""
    ajouter_script = os.path.join(ASTROPORT_DIR, 'ajouter_media.sh')
    if not os.path.isfile(ajouter_script):
        print(f"ERREUR: ajouter_media.sh introuvable: {ajouter_script}")
        return
    print(f"Publication NOSTR Tube: {avi_file} → player={player}")
    try:
        subprocess.run(
            ['bash', ajouter_script, avi_file, player, 'Video'],
            check=False
        )
    except Exception as e:
        print(f"Erreur publication: {e}")
    finally:
        try:
            os.remove(avi_file)
        except OSError:
            pass


def detect_motion(room, player):
    url = f"https://vdo.copylaradio.com/?scene&room={room}&cleanoutput&autoplay"
    print(f"Room VDO.Ninja: {room} | MULTIPASS: {player}")
    os.makedirs(RECORD_DIR, exist_ok=True)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        page.goto(url)

        print("Attente du flux vidéo...")
        video_element = page.wait_for_selector("video")
        time.sleep(5)

        prev_frame = None
        recording = False
        out = None
        current_filename = None

        print("Analyse en cours... Appuyez sur Ctrl+C pour arrêter.")

        try:
            while True:
                screenshot_bytes = video_element.screenshot()
                nparr = np.frombuffer(screenshot_bytes, np.uint8)
                frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

                if frame is None:
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

                if motion_level > 10000:
                    if not recording:
                        print("MOUVEMENT DÉTECTÉ !")
                        recording = True
                        h, w, _ = frame.shape
                        current_filename = os.path.join(
                            RECORD_DIR, f"alerte_{room}_{int(time.time())}.avi"
                        )
                        fourcc = cv2.VideoWriter_fourcc(*'XVID')
                        out = cv2.VideoWriter(current_filename, fourcc, 10.0, (w, h))
                    out.write(frame)
                else:
                    if recording:
                        print("Retour au calme. Fin de l'enregistrement.")
                        recording = False
                        out.release()
                        out = None
                        threading.Thread(
                            target=publish_video,
                            args=(current_filename, player, room),
                            daemon=True
                        ).start()
                        current_filename = None

                prev_frame = gray
                time.sleep(0.1)

        except KeyboardInterrupt:
            print("Arrêt par l'utilisateur")
        finally:
            if out:
                out.release()
            browser.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Détection de mouvement VDO.Ninja → publication NOSTR Tube'
    )
    parser.add_argument(
        '--room', default='UPLANET',
        help='Nom de la room VDO.Ninja (défaut: UPLANET)'
    )
    parser.add_argument(
        '--player', default='',
        help='Email du MULTIPASS pour publier (défaut: capitaine courant)'
    )
    args = parser.parse_args()

    player = args.player or get_default_player()
    if not player:
        print("Erreur: aucun MULTIPASS trouvé. Utilisez --player email@domain.tld")
        exit(1)

    detect_motion(args.room, player)
