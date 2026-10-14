#!/usr/bin/env python3
"""
telegram_bridge.py — Pont conversationnel Telegram → BRO (question.py), multi-tenant.

Chaque MULTIPASS configure SON PROPRE bot Telegram via cookie.html (onglet
"API officielle" — vault chiffré UPassport/services/api_access_store.py, clé
G1 propre, kind NOSTR 31904). Ce daemon découvre périodiquement les comptes
locaux ayant un bot configuré (via UPassport/api_access_cli.py, synchrone,
même frontière de confiance que IA/get_cookie.sh) et lance une boucle de
long-polling PAR compte, chacune répondant via le token et la mémoire
(--npub HEX) de CET utilisateur — la même mémoire que ses conversations
self-DM BRO sur NOSTR.

Limite assumée (simplicité) : un compte qui retire sa config après le
démarrage du daemon continue d'être sondé jusqu'au prochain redémarrage —
seul l'AJOUT d'un nouveau compte est détecté à chaud (ACCOUNT_RESCAN_SEC).

Usage : telegram_bridge.py [--stop]
"""
import os
import sys
import time
import json
import signal
import asyncio
import subprocess

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import telegram_channel as tg  # noqa: E402

PID_FILE = os.path.expanduser("~/.zen/tmp/telegram_bridge.pid")
LOG_FILE = os.path.expanduser("~/.zen/tmp/telegram_bridge.log")
NOSTR_DIR = os.path.expanduser("~/.zen/game/nostr")
ASTRO_PATH = os.path.expanduser("~/.zen/Astroport.ONE")
QUESTION_PY = os.path.join(ASTRO_PATH, "IA", "question.py")
API_ACCESS_CLI = os.path.expanduser("~/.zen/UPassport/api_access_cli.py")
ASTRO_PYTHON = os.path.expanduser("~/.astro/bin/python3")
ACCOUNT_RESCAN_SEC = 300

_running = True
_tasks: dict = {}  # email -> asyncio.Task


def _log(msg: str) -> None:
    line = f"[{time.strftime('%H:%M:%S')}] [telegram_bridge] {msg}"
    print(line, flush=True)
    try:
        with open(LOG_FILE, "a") as f:
            f.write(line + "\n")
    except OSError:
        pass


def _stop_handler(signum, frame):
    global _running
    _running = False


def _list_local_emails() -> list:
    if not os.path.isdir(NOSTR_DIR):
        return []
    return sorted(
        d for d in os.listdir(NOSTR_DIR)
        if "@" in d and os.path.isdir(os.path.join(NOSTR_DIR, d))
    )


def _get_telegram_config(email: str) -> dict | None:
    """Appelle api_access_cli.py (synchrone, UPassport) pour ce compte."""
    try:
        r = subprocess.run(
            [ASTRO_PYTHON, API_ACCESS_CLI, "get", email, "telegram"],
            capture_output=True, text=True, timeout=35,
        )
        if r.returncode != 0:
            return None
        values = json.loads(r.stdout.strip() or "{}")
        return values if values.get("bot_token") else None
    except Exception as e:
        _log(f"ERROR: _get_telegram_config({email}): {type(e).__name__}: {e}")
        return None


def _ask_bro(text: str, email: str) -> str:
    """Appelle question.py (RAG Qdrant + Ollama, indépendant de NextCloud).
    --user-id (PAS --npub, qui ne sert qu'au logging — vérifié dans question.py)
    lie la réponse à la MÊME mémoire/identité que les conversations self-DM BRO
    de ce MULTIPASS sur NOSTR : load_identity()/load_context() résolvent sur
    ~/.zen/game/nostr/{user_id}/... avec l'EMAIL, pas le HEX."""
    try:
        cmd = [ASTRO_PYTHON, QUESTION_PY, text,
               "--model", "gemma3:latest", "--ctx", "8192", "--max-tokens", "1024"]
        if email:
            cmd += ["--user-id", email]
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        answer = r.stdout.strip()
        if not answer:
            _log(f"WARN: question.py stdout vide (rc={r.returncode}) stderr={r.stderr[:200]}")
            return "⚠️ Service IA temporairement indisponible, réessayez dans quelques minutes."
        return answer
    except subprocess.TimeoutExpired:
        return "⚠️ Délai dépassé — réessayez une question plus courte."
    except Exception as e:
        _log(f"ERROR: _ask_bro: {type(e).__name__}: {e}")
        return "⚠️ Erreur interne, réessayez plus tard."


async def _process_update(email: str, bot_token: str, update: dict) -> None:
    msg = update.get("message") or update.get("edited_message")
    if not msg:
        return
    chat_id = msg.get("chat", {}).get("id")
    text = msg.get("text", "")
    if not chat_id or not text:
        return
    _log(f"📩 {email}: message de chat {chat_id}: {text[:80]}")
    answer = await asyncio.to_thread(_ask_bro, text, email)
    if await asyncio.to_thread(tg.send_message, bot_token, chat_id, answer):
        _log(f"✅ {email}: réponse envoyée")
    else:
        _log(f"WARN: {email}: échec envoi réponse")


async def _poll_account(email: str, bot_token: str) -> None:
    offset_file = os.path.expanduser(f"~/.zen/tmp/telegram_bridge_offset_{email}.txt")
    offset = None
    if os.path.exists(offset_file):
        try:
            offset = int(open(offset_file).read().strip())
        except (OSError, ValueError):
            pass

    _log(f"🚀 Poll Telegram démarré pour {email}")
    while _running:
        updates = await asyncio.to_thread(tg.get_updates, bot_token, offset, 30)
        if updates is None:
            _log(f"❌ {email}: token Telegram invalide (401/403) — arrêt définitif du polling pour ce compte")
            return
        if not updates:
            ## Liste vide SANS None : soit rien de nouveau après l'attente normale du
            ## long-poll (30s déjà écoulées, rien à faire de plus), soit une erreur
            ## réseau transitoire (timeout, DNS) qui, elle, revient immédiatement —
            ## un petit backoff évite de marteler l'API en boucle serrée dans ce cas.
            await asyncio.sleep(5)
        for upd in updates:
            try:
                await _process_update(email, bot_token, upd)
            except Exception as e:
                _log(f"ERROR: _process_update({email}): {type(e).__name__}: {e}")
            offset = upd["update_id"] + 1
            try:
                with open(offset_file, "w") as f:
                    f.write(str(offset))
            except OSError:
                pass
    _log(f"Poll Telegram arrêté pour {email}")


async def _scan_loop() -> None:
    while _running:
        for email in _list_local_emails():
            task = _tasks.get(email)
            if task and not task.done():
                continue
            cfg = _get_telegram_config(email)
            if cfg:
                _log(f"➕ Compte Telegram configuré détecté : {email}")
                _tasks[email] = asyncio.create_task(_poll_account(email, cfg["bot_token"]))
        for _ in range(ACCOUNT_RESCAN_SEC):
            if not _running:
                return
            await asyncio.sleep(1)


def main() -> int:
    if "--stop" in sys.argv:
        try:
            with open(PID_FILE) as f:
                pid = int(f.read().strip())
            os.kill(pid, signal.SIGTERM)
            _log(f"Arrêt demandé (PID {pid})")
        except (OSError, ValueError):
            _log("Aucun daemon en cours")
        try:
            os.remove(PID_FILE)
        except OSError:
            pass
        return 0

    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE) as f:
                old_pid = int(f.read().strip())
            os.kill(old_pid, 0)
            _log(f"Daemon déjà en cours (PID {old_pid})")
            return 0
        except (OSError, ValueError):
            pass

    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))
    signal.signal(signal.SIGTERM, _stop_handler)
    signal.signal(signal.SIGINT, _stop_handler)

    _log(f"🚀 Pont Telegram multi-tenant démarré (PID {os.getpid()}, rescan {ACCOUNT_RESCAN_SEC}s)")
    try:
        asyncio.run(_scan_loop())
    finally:
        try:
            os.remove(PID_FILE)
        except OSError:
            pass
        _log("Pont Telegram arrêté")
    return 0


if __name__ == "__main__":
    sys.exit(main())
