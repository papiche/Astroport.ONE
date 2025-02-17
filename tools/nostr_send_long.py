#!/usr/bin/env python3
import sys
import json
import argparse
import time
from pathlib import Path
from pynostr.event import Event
from pynostr.relay_manager import RelayManager
from pynostr.key import PrivateKey
from hashlib import sha256

def generate_summary(content, max_length=200):
    """Génère un résumé du contenu (200 caractères max)"""
    return content[:max_length].rsplit(" ", 1)[0] + "..." if len(content) > max_length else content

def send_nostr_event(private_key, kind, content, tags, relays, timeout):
    """Envoie un événement Nostr"""
    relay_manager = RelayManager()
    for relay in relays:
        relay_manager.add_relay(relay)

    relay_manager.open_connections()
    time.sleep(1)  # Laisser le temps aux connexions

    private_key = PrivateKey.from_nsec(private_key)
    event = Event(kind=kind, content=content, tags=tags)
    private_key.sign_event(event)

    print(f"📤 Envoi de l'événement kind {kind}...")
    relay_manager.publish_event(event)

    start_time = time.time()
    success = False

    while time.time() - start_time < timeout:
        relay_manager.run_sync()
        if event.id in relay_manager.sent_events:
            success = True
            break

    relay_manager.close_connections()
    return event.id if success else None

def send_long_nostr_event(private_key, file_path, relays, timeout, title, tags, attach):
    """Envoie un article long + résumé + support NIP-94"""
    file = Path(file_path)
    if not file.exists():
        print(f"❌ Erreur : Le fichier '{file_path}' n'existe pas.")
        sys.exit(1)

    content = file.read_text(encoding="utf-8")

    # Option NIP-94 (fichier attaché)
    if attach:
        attach_hash = sha256(content.encode()).hexdigest()
        tags.append(["L", attach_hash, "text/markdown"])  # L = attach

    # Envoi article long (Kind 30023)
    tags.append(["d", title])
    article_id = send_nostr_event(private_key, 30023, content, tags, relays, timeout)

    if article_id:
        print(f"✅ Article publié ! ID : {article_id}")

        # Générer un résumé et publier en Kind 1
        summary = generate_summary(content)
        summary_content = f"{title}\n\n{summary}\n\n📖 Lire l'article : nostr:{article_id}"
        summary_id = send_nostr_event(private_key, 1, summary_content, [["e", article_id]], relays, timeout)

        if summary_id:
            print(f"✅ Résumé publié (Kind 1) ! ID : {summary_id}")
    else:
        print("❌ Échec de l'envoi de l'article.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Envoyer un article Markdown sur Nostr (Kind 30023) avec résumé et NIP-94")

    parser.add_argument("private_key", help="Clé privée (nsec)")
    parser.add_argument("file", help="Fichier Markdown à envoyer")
    parser.add_argument("title", help="Titre de l'article")

    # Options
    parser.add_argument("--relay", type=str, action="append", default=["wss://relay.copylaradio.com"],
                        help="URL du relai Nostr (peut être utilisé plusieurs fois)")
    parser.add_argument("--timeout", type=int, default=10, help="Temps d'attente max pour la confirmation (secondes)")
    parser.add_argument("--tags", type=str, action="append", default=[],
                        help="Ajouter des tags à l'événement (ex: --tags p:npub1xxx --tags e:evtid)")
    parser.add_argument("--attach", action="store_true", help="Attacher le fichier via NIP-94")

    args = parser.parse_args()

    send_long_nostr_event(args.private_key, args.file, args.relay, args.timeout, args.title, args.tags, args.attach)
