#!/usr/bin/env python3
"""
telegram_channel.py — Adaptateur Telegram Bot API (lecture/écriture) pour BRO.

HTTP simple (requests), pas besoin du SDK python-telegram-bot pour ce
périmètre (sendMessage + getUpdates suffisent). Indépendant de NextCloud.

Paramétré par bot_token explicite (PAS une variable d'environnement globale)
depuis le pivot 2026-10-14 : chaque MULTIPASS a son propre bot, stocké
chiffré dans le vault API Access (UPassport/services/api_access_store.py,
CLI synchrone UPassport/api_access_cli.py) — jamais un seul bot pour toute
la station. Les ponts (telegram_bridge.py) appellent ces fonctions une fois
par compte configuré, avec SON token.

CLI (tests manuels, token en argument — jamais une variable d'env globale) :
    telegram_channel.py check <bot_token>
    telegram_channel.py send <bot_token> <chat_id> "texte"
    telegram_channel.py updates <bot_token> [--offset N]
"""
import sys
import json

import requests

TIMEOUT = 35  # > le long-poll demandé (30s) pour getUpdates
MAX_MSG_LEN = 4000  # limite Telegram (4096) — marge de sécurité


def _api(bot_token: str, method: str) -> str:
    return f"https://api.telegram.org/bot{bot_token}/{method}"


def check_credentials(bot_token: str) -> dict | None:
    if not bot_token:
        return None
    try:
        r = requests.get(_api(bot_token, "getMe"), timeout=TIMEOUT)
        if r.status_code == 200 and r.json().get("ok"):
            return r.json().get("result")
    except requests.RequestException as e:
        print(f"ERROR:telegram_channel:check_credentials:{e}", file=sys.stderr)
    return None


def send_message(bot_token: str, chat_id: str, text: str) -> int | None:
    """Envoie un message. Retourne le message_id, ou None en échec."""
    if not bot_token:
        print("INFO:telegram_channel: bot_token absent — envoi ignoré", file=sys.stderr)
        return None
    text = text[:MAX_MSG_LEN]
    try:
        r = requests.post(_api(bot_token, "sendMessage"),
                           json={"chat_id": chat_id, "text": text},
                           timeout=TIMEOUT)
        if r.status_code == 200 and r.json().get("ok"):
            return r.json()["result"]["message_id"]
        print(f"ERROR:telegram_channel:send_message:http_{r.status_code}:{r.text[:200]}", file=sys.stderr)
    except requests.RequestException as e:
        print(f"ERROR:telegram_channel:send_message:{e}", file=sys.stderr)
    return None


def get_updates(bot_token: str, offset: int | None = None, timeout: int = 30) -> list[dict] | None:
    """Long-polling getUpdates. Retourne une liste d'updates bruts (dict Telegram),
    ou None si le token est définitivement invalide (401/403 — ne JAMAIS réessayer
    ce token, contrairement à une liste vide qui signifie juste "rien de nouveau"
    après l'attente normale du long-poll)."""
    if not bot_token:
        return []
    params = {"timeout": timeout}
    if offset is not None:
        params["offset"] = offset
    try:
        r = requests.get(_api(bot_token, "getUpdates"), params=params, timeout=timeout + 5)
        if r.status_code == 200 and r.json().get("ok"):
            return r.json().get("result", [])
        if r.status_code in (401, 403):
            print(f"ERROR:telegram_channel:get_updates:invalid_token:http_{r.status_code}", file=sys.stderr)
            return None
        print(f"ERROR:telegram_channel:get_updates:http_{r.status_code}", file=sys.stderr)
    except requests.RequestException as e:
        print(f"ERROR:telegram_channel:get_updates:{e}", file=sys.stderr)
    return []


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    cmd, token = sys.argv[1], sys.argv[2]
    if cmd == "check":
        me = check_credentials(token)
        print(json.dumps(me) if me else "ERROR: identifiants invalides")
        sys.exit(0 if me else 1)
    elif cmd == "send":
        if len(sys.argv) < 5:
            print("Usage: telegram_channel.py send <bot_token> <chat_id> \"texte\"", file=sys.stderr)
            sys.exit(2)
        mid = send_message(token, sys.argv[3], sys.argv[4])
        print(mid or "ERROR: envoi échoué")
        sys.exit(0 if mid else 1)
    elif cmd == "updates":
        off = None
        if "--offset" in sys.argv:
            off = int(sys.argv[sys.argv.index("--offset") + 1])
        print(json.dumps(get_updates(token, offset=off, timeout=5), ensure_ascii=False, indent=2))
    else:
        print(f"Commande inconnue: {cmd}", file=sys.stderr)
        sys.exit(2)
