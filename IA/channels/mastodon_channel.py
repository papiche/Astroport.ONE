#!/usr/bin/env python3
"""
mastodon_channel.py — Adaptateur Mastodon (lecture/écriture) pour BRO.

Pas de SDK lourd : l'API Mastodon est du simple REST+Bearer token, couvert
par `requests` (déjà dans ~/.astro). Indépendant de NextCloud/Qdrant.

Paramétré par (instance_url, access_token) explicites (PAS une variable
d'environnement globale) depuis le pivot 2026-10-14 : chaque MULTIPASS a son
propre compte Mastodon, stocké chiffré dans le vault API Access
(UPassport/services/api_access_store.py, CLI synchrone
UPassport/api_access_cli.py) — jamais un seul compte pour toute la station.

CLI (tests manuels) :
    mastodon_channel.py check <instance_url> <access_token>
    mastodon_channel.py post <instance_url> <access_token> "texte du statut"
    mastodon_channel.py mentions <instance_url> <access_token> [--since-id N]
"""
import sys
import json
import re

import requests

TIMEOUT = 20
MAX_STATUS_LEN = 480  # limite Mastodon par défaut (500) — marge de sécurité


def _headers(access_token: str) -> dict:
    return {"Authorization": f"Bearer {access_token}"}


def check_credentials(instance_url: str, access_token: str) -> dict | None:
    """Retourne le compte authentifié (dict) ou None si identifiants invalides."""
    if not (instance_url and access_token):
        return None
    try:
        r = requests.get(f"{instance_url.rstrip('/')}/api/v1/accounts/verify_credentials",
                          headers=_headers(access_token), timeout=TIMEOUT)
        if r.status_code == 200:
            return r.json()
    except requests.RequestException as e:
        print(f"ERROR:mastodon_channel:check_credentials:{e}", file=sys.stderr)
    return None


def post_status(instance_url: str, access_token: str, text: str,
                 visibility: str = "public", in_reply_to_id: str | None = None) -> str | None:
    """Publie un statut. Retourne l'id du statut créé, ou None en échec."""
    if not (instance_url and access_token):
        print("INFO:mastodon_channel: non configuré — post ignoré", file=sys.stderr)
        return None
    text = text[:MAX_STATUS_LEN]
    data = {"status": text, "visibility": visibility}
    if in_reply_to_id:
        data["in_reply_to_id"] = in_reply_to_id
    try:
        r = requests.post(f"{instance_url.rstrip('/')}/api/v1/statuses",
                           headers=_headers(access_token), data=data, timeout=TIMEOUT)
        if r.status_code in (200, 201):
            return r.json().get("id")
        print(f"ERROR:mastodon_channel:post_status:http_{r.status_code}:{r.text[:200]}", file=sys.stderr)
    except requests.RequestException as e:
        print(f"ERROR:mastodon_channel:post_status:{e}", file=sys.stderr)
    return None


def fetch_mentions(instance_url: str, access_token: str,
                    since_id: str | None = None, limit: int = 20) -> list[dict] | None:
    """Retourne les notifications de type 'mention' depuis since_id (exclu).
    Chaque item : {id, status_id, text, account_acct, account_id}.
    Retourne None si le token est définitivement invalide (401/403) — ne
    JAMAIS réessayer ce token, contrairement à une liste vide récupérable."""
    if not (instance_url and access_token):
        return []
    params = {"types[]": "mention", "limit": limit}
    if since_id:
        params["since_id"] = since_id
    try:
        r = requests.get(f"{instance_url.rstrip('/')}/api/v1/notifications",
                          headers=_headers(access_token), params=params, timeout=TIMEOUT)
        if r.status_code in (401, 403):
            print(f"ERROR:mastodon_channel:fetch_mentions:invalid_token:http_{r.status_code}", file=sys.stderr)
            return None
        if r.status_code != 200:
            print(f"ERROR:mastodon_channel:fetch_mentions:http_{r.status_code}", file=sys.stderr)
            return []
        out = []
        for n in r.json():
            status = n.get("status") or {}
            account = n.get("account") or {}
            text = status.get("content", "")
            for tag, repl in (("<p>", ""), ("</p>", "\n"), ("<br>", "\n"), ("<br/>", "\n")):
                text = text.replace(tag, repl)
            text = re.sub(r"<[^>]+>", "", text).strip()
            out.append({
                "id": n.get("id"),
                "status_id": status.get("id"),
                "text": text,
                "account_acct": account.get("acct", ""),
                "account_id": account.get("id", ""),
            })
        return out
    except requests.RequestException as e:
        print(f"ERROR:mastodon_channel:fetch_mentions:{e}", file=sys.stderr)
        return []


def reply(instance_url: str, access_token: str, status_id: str, text: str, mention_acct: str) -> str | None:
    """Répond à un statut — préfixe automatiquement @acct (Mastodon ne le fait pas seul)."""
    prefix = f"@{mention_acct} " if mention_acct else ""
    return post_status(instance_url, access_token, f"{prefix}{text}", in_reply_to_id=status_id)


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    cmd, instance, token = sys.argv[1], sys.argv[2], sys.argv[3]
    if cmd == "check":
        acct = check_credentials(instance, token)
        print(json.dumps(acct) if acct else "ERROR: identifiants invalides")
        sys.exit(0 if acct else 1)
    elif cmd == "post":
        if len(sys.argv) < 5:
            print("Usage: mastodon_channel.py post <instance_url> <access_token> \"texte\"", file=sys.stderr)
            sys.exit(2)
        sid = post_status(instance, token, sys.argv[4])
        print(sid or "ERROR: publication échouée")
        sys.exit(0 if sid else 1)
    elif cmd == "mentions":
        since = None
        if "--since-id" in sys.argv:
            since = sys.argv[sys.argv.index("--since-id") + 1]
        print(json.dumps(fetch_mentions(instance, token, since_id=since), ensure_ascii=False, indent=2))
    else:
        print(f"Commande inconnue: {cmd}", file=sys.stderr)
        sys.exit(2)
