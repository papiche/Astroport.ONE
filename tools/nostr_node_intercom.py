#!/bin/env python
"""Canal de communication inter-NODE via DMs NIP-04 (kind 4).

Chaque message porte un champ `channel` qui identifie le sous-protocole,
permettant à un NODE de router les messages sans ambiguïté :

  udrive   — sync de fichier uDRIVE depuis une station visiteur
  (extensible : "did_update", "zen_payment", "alert", …)

Usage:
  # Envoyer (station B → station A) :
  nostr_node_intercom.py send \\
      --nsec    <NODE_NSEC_B> \\
      --to      <NODE_HEX_A> \\
      --channel udrive \\
      --payload '{"email":"x@y.z","cid":"Qm…","filename":"f.jpg","filetype":"image"}' \\
      --relays  wss://relay.copylaradio.com

  # Recevoir (station A — polling) :
  nostr_node_intercom.py receive \\
      --nsec    <NODE_NSEC_A> \\
      --channel udrive \\
      --since   <UNIX_TIMESTAMP> \\
      --relays  wss://relay.copylaradio.com
  # → JSON array vers stdout ; chaque entrée inclut channel, payload,
  #   event_id, sender, created_at

Canaux actuels
--------------
  udrive  payload requis : email, cid, filename, filetype
"""
import sys
import json
import argparse
import ssl
import threading
import time

from pynostr.key import PrivateKey


# ── WebSocket helper ──────────────────────────────────────────────────────────

def _ws_module():
    try:
        import websocket
        return websocket
    except ImportError:
        print("ERROR: websocket-client not installed (pip install websocket-client)",
              file=sys.stderr)
        sys.exit(1)


def _connect(url: str, on_open, on_message, timeout: int = 12):
    """Ouvre un WebSocket, appelle on_open puis on_message pour chaque message.
    Bloque jusqu'à fermeture du socket ou expiration du timeout."""
    ws_mod = _ws_module()
    done = threading.Event()

    def _on_open(ws):   on_open(ws)
    def _on_message(ws, msg): on_message(ws, msg)
    def _on_close(ws, *_):    done.set()
    def _on_error(ws, _err):  done.set()

    sslopt = {"cert_reqs": ssl.CERT_NONE} if url.startswith("wss://") else {}
    ws = ws_mod.WebSocketApp(
        url,
        on_open=_on_open,
        on_message=_on_message,
        on_close=_on_close,
        on_error=_on_error,
    )
    t = threading.Thread(target=ws.run_forever, kwargs={"sslopt": sslopt}, daemon=True)
    t.start()
    done.wait(timeout=timeout)
    try:
        ws.close()
    except Exception:
        pass


# ── send ─────────────────────────────────────────────────────────────────────

def cmd_send(args):
    private_key = PrivateKey.from_nsec(args.nsec)

    # Valider le JSON payload fourni par l'appelant
    try:
        payload_data = json.loads(args.payload)
    except json.JSONDecodeError as exc:
        print(f"ERROR: --payload n'est pas du JSON valide : {exc}", file=sys.stderr)
        sys.exit(1)

    envelope = {
        "channel": args.channel,
        "payload": payload_data,
    }
    encrypted = private_key.encrypt_message(json.dumps(envelope), args.to)

    from pynostr.event import Event
    ev = Event(
        kind=4,
        content=encrypted,
        tags=[["p", args.to]],
        public_key=private_key.public_key.hex(),
    )
    ev.sign(private_key.hex())
    event_dict = ev.to_dict()

    errors = []
    for relay_url in args.relays:
        sent = threading.Event()

        def on_open(ws, _d=event_dict):
            ws.send(json.dumps(["EVENT", _d]))

        def on_message(ws, msg, _done=sent):
            try:
                data = json.loads(msg)
                if data[0] in ("OK", "NOTICE"):
                    _done.set()
                    ws.close()
            except Exception:
                pass

        _connect(relay_url, on_open, on_message, timeout=10)
        if not sent.is_set():
            errors.append(relay_url)

    if errors:
        print(f"WARN: aucun OK de {errors}", file=sys.stderr)
    print(f"Sent [{args.channel}] to={args.to[:12]}... payload={list(payload_data.keys())}")


# ── receive ──────────────────────────────────────────────────────────────────

def cmd_receive(args):
    private_key = PrivateKey.from_nsec(args.nsec)
    pub_hex = private_key.public_key.hex()

    sub_filter: dict = {"kinds": [4], "#p": [pub_hex]}
    if args.since:
        sub_filter["since"] = int(args.since)

    all_events: list[dict] = []

    for relay_url in args.relays:
        collected: list[dict] = []

        def on_open(ws, _f=sub_filter):
            ws.send(json.dumps(["REQ", "intercom_recv", _f]))

        def on_message(ws, msg, _col=collected):
            try:
                data = json.loads(msg)
                if data[0] == "EVENT" and len(data) >= 3:
                    _col.append(data[2])
                elif data[0] == "EOSE":
                    ws.close()
            except Exception:
                pass

        _connect(relay_url, on_open, on_message, timeout=12)
        all_events.extend(collected)

    # Déchiffrer, décoder l'enveloppe, filtrer par canal
    results = []
    seen_ids: set[str] = set()
    for ev in all_events:
        eid = ev.get("id", "")
        if eid in seen_ids:
            continue
        seen_ids.add(eid)
        sender_hex = ev.get("pubkey", "")
        try:
            decrypted = private_key.decrypt_message(ev["content"], sender_hex)
            try:
                envelope = json.loads(decrypted)
            except (json.JSONDecodeError, ValueError):
                # DM texte brut (client Nostr standard) → canal "plain"
                envelope = {"channel": "plain", "payload": {"text": decrypted}}
        except Exception:
            continue

        channel = envelope.get("channel", "")
        # Filtrer par canal si --channel est précisé
        if args.channel and channel != args.channel:
            continue

        results.append({
            "channel":    channel,
            "payload":    envelope.get("payload", {}),
            "event_id":   eid,
            "sender":     sender_hex,
            "created_at": ev.get("created_at", 0),
        })

    print(json.dumps(results))


# ── main ─────────────────────────────────────────────────────────────────────

# ── Helpers pour le canal "udrive" (appelés depuis les scripts bash) ──────────

def cmd_send_udrive(args):
    """Raccourci : construit le payload udrive et appelle cmd_send."""
    payload = {
        "email":    args.email,
        "cid":      args.cid,
        "filename": args.filename,
        "filetype": args.filetype,
    }
    args.channel = "udrive"
    args.payload = json.dumps(payload)
    cmd_send(args)


# ── decrypt ──────────────────────────────────────────────────────────────────

def cmd_decrypt(args):
    """Déchiffre un event kind 4 passé en JSON sur stdin.
    Retourne {"channel", "payload", "sender", "event_id"} ou exit 1."""
    private_key = PrivateKey.from_nsec(args.nsec)
    try:
        ev = json.load(sys.stdin)
        # Supporte les deux formats : event brut ET envelope strfry {event:{...}}
        if "event" in ev:
            ev = ev["event"]
        sender_hex = ev.get("pubkey", "")
        decrypted = private_key.decrypt_message(ev["content"], sender_hex)
        try:
            envelope = json.loads(decrypted)
        except (json.JSONDecodeError, ValueError):
            envelope = {"channel": "plain", "payload": {"text": decrypted}}
        print(json.dumps({
            "channel":  envelope.get("channel", "plain"),
            "payload":  envelope.get("payload", {}),
            "sender":   sender_hex,
            "event_id": ev.get("id", ""),
        }))
    except Exception:
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Canal de communication inter-NODE via DMs NOSTR NIP-04",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    # ── send générique ────────────────────────────────────────────────────────
    p_send = sub.add_parser("send", help="Envoyer un message à un NODE distant")
    p_send.add_argument("--nsec",    required=True, help="NSEC du NODE émetteur")
    p_send.add_argument("--to",      required=True, help="HEX pubkey du NODE destinataire")
    p_send.add_argument("--channel", required=True, help="Canal : udrive, …")
    p_send.add_argument("--payload", required=True, help="Contenu JSON du message")
    p_send.add_argument("--relays",  nargs="+", required=True)

    # ── send udrive (raccourci bash-friendly) ─────────────────────────────────
    p_udrive = sub.add_parser("send-udrive",
                              help="Envoyer une demande de sync uDRIVE (canal udrive)")
    p_udrive.add_argument("--nsec",     required=True)
    p_udrive.add_argument("--to",       required=True, help="HEX pubkey de la home station")
    p_udrive.add_argument("--email",    required=True)
    p_udrive.add_argument("--cid",      required=True)
    p_udrive.add_argument("--filename", required=True)
    p_udrive.add_argument("--filetype", default="file",
                          choices=["image", "video", "audio", "document", "file"])
    p_udrive.add_argument("--relays",   nargs="+", required=True)

    # ── receive ───────────────────────────────────────────────────────────────
    p_recv = sub.add_parser("receive",
                            help="Recevoir les messages en attente (tous canaux ou filtré)")
    p_recv.add_argument("--nsec",    required=True)
    p_recv.add_argument("--channel", default=None,
                        help="Filtrer par canal (omis = tous les canaux)")
    p_recv.add_argument("--since",   default=None, help="Timestamp Unix minimum")
    p_recv.add_argument("--relays",  nargs="+", required=True)

    # ── decrypt (event kind 4 depuis stdin) ──────────────────────────────────
    p_dec = sub.add_parser("decrypt",
                           help="Déchiffrer un event kind 4 passé en JSON sur stdin")
    p_dec.add_argument("--nsec", required=True, help="NSEC du destinataire")

    args = parser.parse_args()
    if args.cmd == "send":
        cmd_send(args)
    elif args.cmd == "send-udrive":
        cmd_send_udrive(args)
    elif args.cmd == "decrypt":
        cmd_decrypt(args)
    else:
        cmd_receive(args)
