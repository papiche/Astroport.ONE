#!/usr/bin/env python3
"""
nostr_connection_pool.py — Protocole partagé + aide client pour le daemon de
pool de connexions NOSTR (nostr_pool_daemon.py).

Contexte : chaque envoi NOSTR (nostr_send_secure_dm.py::_publish_event_to_relay)
ouvre une connexion WebSocket, envoie, attend "OK", ferme — mesuré en
conditions réelles : ~31ms (relais local) à ~180ms (relais distant) juste
pour la connexion, avant même l'envoi. Sur une conversation BRO complète
(jusqu'à 8 DMs), ça s'additionne.

Design retenu (validé avec le capitaine, 2026-07-06) :
  - PAS un daemon à connexions globales partagées : NIP-42 authentifie une
    CONNEXION, pas un message — dans un contexte multi-tenant (chaque
    MULTIPASS a sa propre clé), partager une connexion entre identités
    causerait des ré-authentifications en boucle.
  - Clé de pool (relay, pubkey) : une connexion par (relais, identité),
    jamais partagée entre deux pubkeys différentes, même sur le même relais.
  - Le daemon ne voit JAMAIS de clé privée (nsec) : nostr_send_secure_dm.py
    signe l'event AVANT de le transmettre au pool — le daemon ne fait que
    relayer un event déjà signé sur une connexion WebSocket réutilisée.
    C'est cohérent avec le fait que ce script ne fait d'ailleurs aucune
    authentification NIP-42 aujourd'hui (vérifié dans son code : connect →
    send → wait "OK", rien d'autre) — le pool ne retire donc aucune capacité
    existante, il n'accélère que la connexion elle-même.
  - Dégradation totalement transparente : si le daemon n'écoute pas (pas
    lancé, crashé, désactivé), try_publish_via_pool() retourne None et
    l'appelant retombe sur sa connexion directe historique, INCHANGÉE.
"""

import os
import json
import socket

SOCKET_PATH = os.path.expanduser("~/.zen/tmp/nostr_pool.sock")
POOL_TTL_SEC = 60          # inactivité avant fermeture d'une connexion pool
POOL_SCAN_INTERVAL_SEC = 15
CLIENT_TIMEOUT_SEC = 5     # côté appelant : au-delà, on suppose le daemon en panne


def _recv_line(sock, max_bytes=65536):
    """Lit jusqu'au premier '\\n' ou jusqu'à max_bytes — le protocole est une
    requête/réponse JSON par ligne, une seule par connexion cliente."""
    buf = b""
    while b"\n" not in buf and len(buf) < max_bytes:
        chunk = sock.recv(4096)
        if not chunk:
            break
        buf += chunk
    return buf.split(b"\n", 1)[0].decode("utf-8", errors="replace")


def try_publish_via_pool(event_dict: dict, relay_url: str, timeout: float = CLIENT_TIMEOUT_SEC):
    """Tente de publier `event_dict` (DÉJÀ SIGNÉ) vers `relay_url` via le
    daemon de pool. Retourne True/False si le daemon a répondu, ou None s'il
    est indisponible — dans ce dernier cas, l'appelant DOIT retomber sur sa
    propre logique de connexion directe (jamais de blocage sur son absence :
    le pool est une optimisation pure, jamais une dépendance dure)."""
    if not os.path.exists(SOCKET_PATH):
        return None
    sock = None
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        sock.connect(SOCKET_PATH)
        request = json.dumps({
            "relay": relay_url,
            "pubkey": event_dict.get("pubkey", ""),
            "event": event_dict,
        }) + "\n"
        sock.sendall(request.encode("utf-8"))
        raw = _recv_line(sock)
        if not raw:
            return None
        response = json.loads(raw)
        return bool(response.get("ok"))
    except Exception:
        # Daemon absent, socket obsolète, timeout... — dégradation
        # silencieuse et systématique vers le mode direct.
        return None
    finally:
        if sock:
            try:
                sock.close()
            except Exception:
                pass
