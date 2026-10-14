#!/usr/bin/env python3
"""
mastodon_bridge.py — Pont conversationnel Mastodon → BRO (question.py), multi-tenant.

Même principe que telegram_bridge.py : chaque MULTIPASS configure SON PROPRE
compte Mastodon via cookie.html (onglet "API officielle"). Pas de long-poll
natif côté API REST Mastodon : on interroge /api/v1/notifications toutes les
POLL_INTERVAL secondes, par compte configuré.

Limite assumée (simplicité) : un compte qui retire sa config après le
démarrage du daemon continue d'être sondé jusqu'au prochain redémarrage.

Usage : mastodon_bridge.py [--stop]
"""
import os
import sys
import time
import json
import signal
import asyncio
import subprocess

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import mastodon_channel as mst  # noqa: E402

PID_FILE = os.path.expanduser("~/.zen/tmp/mastodon_bridge.pid")
LOG_FILE = os.path.expanduser("~/.zen/tmp/mastodon_bridge.log")
NOSTR_DIR = os.path.expanduser("~/.zen/game/nostr")
ASTRO_PATH = os.path.expanduser("~/.zen/Astroport.ONE")
QUESTION_PY = os.path.join(ASTRO_PATH, "IA", "question.py")
API_ACCESS_CLI = os.path.expanduser("~/.zen/UPassport/api_access_cli.py")
ASTRO_PYTHON = os.path.expanduser("~/.astro/bin/python3")
ACCOUNT_RESCAN_SEC = 300
POLL_INTERVAL = 30  # secondes — pas de long-poll natif côté API Mastodon

_running = True
_tasks: dict = {}  # email -> asyncio.Task


def _log(msg: str) -> None:
    line = f"[{time.strftime('%H:%M:%S')}] [mastodon_bridge] {msg}"
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


def _get_mastodon_config(email: str) -> dict | None:
    try:
        r = subprocess.run(
            [ASTRO_PYTHON, API_ACCESS_CLI, "get", email, "mastodon"],
            capture_output=True, text=True, timeout=35,
        )
        if r.returncode != 0:
            return None
        values = json.loads(r.stdout.strip() or "{}")
        return values if values.get("instance_url") and values.get("access_token") else None
    except Exception as e:
        _log(f"ERROR: _get_mastodon_config({email}): {type(e).__name__}: {e}")
        return None


def _ask_bro(text: str, email: str) -> str:
    """--user-id (PAS --npub, logging only) lie la réponse à la mémoire/identité
    de ce MULTIPASS — load_identity()/load_context() dans question.py résolvent
    ~/.zen/game/nostr/{user_id}/... avec l'EMAIL, pas le HEX."""
    try:
        cmd = [ASTRO_PYTHON, QUESTION_PY, text,
               "--model", "gemma3:latest", "--ctx", "8192", "--max-tokens", "480"]
        if email:
            cmd += ["--user-id", email]
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        answer = r.stdout.strip()
        if not answer:
            _log(f"WARN: question.py stdout vide (rc={r.returncode}) stderr={r.stderr[:200]}")
            return "⚠️ Service IA temporairement indisponible."
        return answer
    except subprocess.TimeoutExpired:
        return "⚠️ Délai dépassé — réessayez une question plus courte."
    except Exception as e:
        _log(f"ERROR: _ask_bro: {type(e).__name__}: {e}")
        return "⚠️ Erreur interne, réessayez plus tard."


async def _process_mention(email: str, instance_url: str, access_token: str, mention: dict) -> None:
    acct = mention.get("account_acct", "")
    text = mention.get("text", "")
    status_id = mention.get("status_id")
    if not status_id or not text:
        return
    _log(f"📩 {email}: mention de {acct}: {text[:80]}")
    answer = await asyncio.to_thread(_ask_bro, text, email)
    if await asyncio.to_thread(mst.reply, instance_url, access_token, status_id, answer, acct):
        _log(f"✅ {email}: réponse envoyée à {acct}")
    else:
        _log(f"WARN: {email}: échec réponse à {acct}")


async def _poll_account(email: str, instance_url: str, access_token: str) -> None:
    since_id_file = os.path.expanduser(f"~/.zen/tmp/mastodon_bridge_since_{email}.txt")
    since_id = None
    if os.path.exists(since_id_file):
        try:
            since_id = open(since_id_file).read().strip() or None
        except OSError:
            pass

    _log(f"🚀 Poll Mastodon démarré pour {email} ({instance_url})")
    while _running:
        mentions = await asyncio.to_thread(mst.fetch_mentions, instance_url, access_token, since_id)
        if mentions is None:
            _log(f"❌ {email}: token Mastodon invalide (401/403) — arrêt définitif du polling pour ce compte")
            return
        max_id = since_id
        for m in mentions:
            try:
                await _process_mention(email, instance_url, access_token, m)
            except Exception as e:
                _log(f"ERROR: _process_mention({email}): {type(e).__name__}: {e}")
            mid = m.get("id")
            if mid and (max_id is None or int(mid) > int(max_id)):
                max_id = mid
        if max_id and max_id != since_id:
            since_id = max_id
            try:
                with open(since_id_file, "w") as f:
                    f.write(str(since_id))
            except OSError:
                pass
        for _ in range(POLL_INTERVAL):
            if not _running:
                break
            await asyncio.sleep(1)
    _log(f"Poll Mastodon arrêté pour {email}")


async def _scan_loop() -> None:
    while _running:
        for email in _list_local_emails():
            task = _tasks.get(email)
            if task and not task.done():
                continue
            cfg = _get_mastodon_config(email)
            if cfg:
                _log(f"➕ Compte Mastodon configuré détecté : {email}")
                _tasks[email] = asyncio.create_task(
                    _poll_account(email, cfg["instance_url"], cfg["access_token"])
                )
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

    _log(f"🚀 Pont Mastodon multi-tenant démarré (PID {os.getpid()}, rescan {ACCOUNT_RESCAN_SEC}s)")
    try:
        asyncio.run(_scan_loop())
    finally:
        try:
            os.remove(PID_FILE)
        except OSError:
            pass
        _log("Pont Mastodon arrêté")
    return 0


if __name__ == "__main__":
    sys.exit(main())
