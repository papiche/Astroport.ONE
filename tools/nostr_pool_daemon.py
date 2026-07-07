#!/usr/bin/env python3
"""
nostr_pool_daemon.py — Daemon de pool de connexions WebSocket NOSTR.

Écoute sur une socket Unix locale (~/.zen/tmp/nostr_pool.sock) et maintient
un pool de connexions WebSocket ouvertes, une par (relais, pubkey), pour
éviter de repayer le coût de connexion (~30-180ms mesuré, voir
nostr_connection_pool.py) à chaque envoi NOSTR. TTL d'inactivité 60s : une
connexion inutilisée est fermée proprement, jamais gardée indéfiniment.

Protocole (une requête JSON par ligne, une par connexion cliente) :
  Requête  : {"relay": "wss://...", "pubkey": "<hex>", "event": {...déjà signé...}}
  Réponse  : {"ok": true|false, "error": "..." (si ok=false)}

Sécurité : ce daemon ne reçoit et ne voit JAMAIS de clé privée — seulement
des events NOSTR déjà signés par l'appelant. Il ne fait qu'un relais
transparent vers les WebSockets des relais, rien de plus.

Lancement :
    python3 nostr_pool_daemon.py                # avant-plan (Ctrl+C pour arrêter)
    python3 nostr_pool_daemon.py --daemon        # arrière-plan détaché

Ce daemon est un pur OPTIMISATEUR, jamais une dépendance dure : si absent ou
arrêté, les scripts appelants (nostr_send_secure_dm.py) retombent
automatiquement sur une connexion directe — comportement historique inchangé.
"""

# Auto-reinvocation dans le venv ~/.astro/ si dépendances absentes
import sys as _sys
import os as _os
_venv_python = _os.path.expanduser("~/.astro/bin/python3")
if _os.path.exists(_venv_python) and _sys.executable != _venv_python:
    _os.execv(_venv_python, [_venv_python] + _sys.argv)
del _sys, _os

import os
import sys
import json
import time
import socket
import signal
import logging
import threading
import websocket

from nostr_connection_pool import SOCKET_PATH, POOL_TTL_SEC, POOL_SCAN_INTERVAL_SEC

CONNECT_TIMEOUT_SEC = 10
PUBLISH_WAIT_SEC = 15

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [nostr_pool_daemon] %(message)s",
)
log = logging.getLogger(__name__)


class PoolEntry:
    """Une connexion WebSocket pool, verrouillée pour sérialiser les
    envois/réceptions (le protocole WebSocket n'est pas thread-safe pour un
    envoi concurrent sur le même socket — deux (relay, pubkey) distincts ont
    chacun leur propre PoolEntry, donc leurs envois restent parallèles)."""

    def __init__(self, relay_url):
        self.relay_url = relay_url
        self.ws = None
        self.lock = threading.Lock()
        self.last_used = time.time()

    def ensure_connected(self):
        if self.ws is not None:
            return True
        try:
            self.ws = websocket.create_connection(self.relay_url, timeout=CONNECT_TIMEOUT_SEC)
            return True
        except Exception as e:
            log.warning(f"Connexion à {self.relay_url} échouée : {e}")
            self.ws = None
            return False

    def close(self):
        if self.ws:
            try:
                self.ws.close()
            except Exception:
                pass
            self.ws = None


class NostrPool:
    def __init__(self):
        self._entries = {}          # (relay, pubkey) -> PoolEntry
        self._entries_lock = threading.Lock()
        self._stop = threading.Event()

    def _get_entry(self, relay_url, pubkey):
        key = (relay_url, pubkey)
        with self._entries_lock:
            entry = self._entries.get(key)
            if entry is None:
                entry = PoolEntry(relay_url)
                self._entries[key] = entry
            return entry

    def publish(self, relay_url, pubkey, event):
        """Publie `event` (déjà signé) sur la connexion pool (relay, pubkey),
        en la créant si besoin. Une seule tentative de reconnexion en cas de
        connexion morte (evict + retry), jamais de boucle infinie."""
        entry = self._get_entry(relay_url, pubkey)
        with entry.lock:
            entry.last_used = time.time()
            for attempt in (1, 2):
                if not entry.ensure_connected():
                    return False, "connexion impossible"
                try:
                    return self._send_and_wait(entry, event), None
                except (BrokenPipeError, ConnectionResetError, OSError,
                        websocket.WebSocketConnectionClosedException) as e:
                    log.info(f"Connexion {relay_url} morte ({e}) — reconnexion tentative {attempt}/2")
                    entry.close()
                    if attempt == 2:
                        return False, f"connexion perdue : {e}"
            return False, "échec après retry"

    def _send_and_wait(self, entry, event):
        event_id = event.get("id", "")
        entry.ws.settimeout(PUBLISH_WAIT_SEC)
        entry.ws.send(json.dumps(["EVENT", event]))
        deadline = time.time() + PUBLISH_WAIT_SEC
        while time.time() < deadline:
            try:
                entry.ws.settimeout(max(0.5, deadline - time.time()))
                raw = entry.ws.recv()
            except websocket.WebSocketTimeoutException:
                continue
            try:
                msg = json.loads(raw)
            except Exception:
                continue
            if not isinstance(msg, list) or not msg:
                continue
            if msg[0] == "OK" and len(msg) >= 3 and msg[1] == event_id:
                return bool(msg[2])
            if msg[0] == "CLOSED" and len(msg) >= 2 and msg[1] == event_id:
                return False
            # NOTICE, AUTH ou OK/CLOSED d'un autre event (ne devrait pas
            # arriver grâce au lock, mais robustesse) — on continue d'attendre.
        return False

    def reap_idle(self):
        """Ferme et retire les connexions inactives depuis > POOL_TTL_SEC —
        appelé périodiquement par le thread de fond, jamais depuis publish()
        pour ne pas fermer une connexion qu'on est en train d'utiliser
        (protégé par entry.lock : un reap ne peut jamais couper une publish
        en cours puisqu'il prend le même verrou avant de fermer)."""
        now = time.time()
        with self._entries_lock:
            idle_keys = [k for k, e in self._entries.items() if now - e.last_used > POOL_TTL_SEC]
        for key in idle_keys:
            with self._entries_lock:
                entry = self._entries.get(key)
                if entry is None:
                    continue
            with entry.lock:
                if time.time() - entry.last_used > POOL_TTL_SEC:
                    entry.close()
                    with self._entries_lock:
                        self._entries.pop(key, None)
                    log.info(f"Connexion {key} fermée (inactive > {POOL_TTL_SEC}s)")

    def close_all(self):
        with self._entries_lock:
            entries = list(self._entries.values())
            self._entries.clear()
        for entry in entries:
            with entry.lock:
                entry.close()


def _reaper_loop(pool, stop_event):
    while not stop_event.wait(POOL_SCAN_INTERVAL_SEC):
        try:
            pool.reap_idle()
        except Exception as e:
            log.warning(f"Erreur reaper : {e}")


def _handle_client(conn, pool):
    try:
        conn.settimeout(30)
        buf = b""
        while b"\n" not in buf:
            chunk = conn.recv(65536)
            if not chunk:
                break
            buf += chunk
        line = buf.split(b"\n", 1)[0].decode("utf-8", errors="replace")
        if not line:
            return
        req = json.loads(line)
        relay = req.get("relay", "")
        pubkey = req.get("pubkey", "")
        event = req.get("event")
        if not relay or not isinstance(event, dict) or not event.get("id"):
            conn.sendall((json.dumps({"ok": False, "error": "requête invalide"}) + "\n").encode())
            return
        ok, error = pool.publish(relay, pubkey, event)
        resp = {"ok": ok}
        if error:
            resp["error"] = error
        conn.sendall((json.dumps(resp) + "\n").encode())
    except Exception as e:
        try:
            conn.sendall((json.dumps({"ok": False, "error": str(e)}) + "\n").encode())
        except Exception:
            pass
    finally:
        try:
            conn.close()
        except Exception:
            pass


def run_server():
    os.makedirs(os.path.dirname(SOCKET_PATH), exist_ok=True)
    if os.path.exists(SOCKET_PATH):
        os.remove(SOCKET_PATH)

    pool = NostrPool()
    stop_event = threading.Event()
    reaper = threading.Thread(target=_reaper_loop, args=(pool, stop_event), daemon=True)
    reaper.start()

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(SOCKET_PATH)
    os.chmod(SOCKET_PATH, 0o600)  # socket locale, propriétaire uniquement
    server.listen(16)
    log.info(f"Daemon démarré, écoute sur {SOCKET_PATH} (TTL={POOL_TTL_SEC}s)")

    def _shutdown(signum, frame):
        log.info("Arrêt demandé — fermeture des connexions pool...")
        stop_event.set()
        pool.close_all()
        try:
            server.close()
        except Exception:
            pass
        if os.path.exists(SOCKET_PATH):
            os.remove(SOCKET_PATH)
        sys.exit(0)

    signal.signal(signal.SIGTERM, _shutdown)
    signal.signal(signal.SIGINT, _shutdown)

    try:
        while True:
            conn, _ = server.accept()
            threading.Thread(target=_handle_client, args=(conn, pool), daemon=True).start()
    except KeyboardInterrupt:
        _shutdown(None, None)


def main():
    if "--daemon" in sys.argv:
        log_dir = os.path.expanduser("~/.zen/tmp")
        os.makedirs(log_dir, exist_ok=True)
        log_file = os.path.join(log_dir, "nostr_pool_daemon.log")
        pid_file = os.path.join(log_dir, "nostr_pool_daemon.pid")
        if os.path.exists(pid_file):
            try:
                old_pid = int(open(pid_file).read().strip())
                os.kill(old_pid, 0)
                print(f"Déjà en cours (PID {old_pid}) — arrêt.")
                sys.exit(0)
            except (ProcessLookupError, ValueError, OSError):
                pass
        import subprocess
        with open(log_file, "a") as f:
            proc = subprocess.Popen(
                [sys.executable, os.path.abspath(__file__)],
                stdout=f, stderr=f, start_new_session=True,
            )
        with open(pid_file, "w") as f:
            f.write(str(proc.pid))
        print(f"Démon lancé (PID {proc.pid}) — logs : {log_file}")
        sys.exit(0)
    run_server()


if __name__ == "__main__":
    main()
