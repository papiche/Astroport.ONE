#!/usr/bin/env python3
import sys
import json
import argparse
import time
from pathlib import Path
from pynostr.event import Event
from pynostr.relay_manager import RelayManager
from pynostr.key import PrivateKey

def send_long_nostr_event(private_key, file_path, relays, timeout, title, tags):
    try:
        # Lire le contenu du fichier Markdown
        file = Path(file_path)
        if not file.exists():
            print(f"❌ Erreur : Le fichier '{file_path}' n'existe pas.")
            sys.exit(1)

        content = file.read_text(encoding="utf-8")

        # Initialiser le gestionnaire de relais
        relay_manager = RelayManager()
        for relay in relays:
            relay_manager.add_relay(relay)

        relay_manager.open_connections()
        time.sleep(1)  # Laisser le temps aux connexions de s'établir

        # Créer une clé privée à partir de la clé nsec
        private_key = PrivateKey.from_nsec(private_key)

        # Construire les tags (ajout automatique du titre)
        event_tags = [["d", title]]
        for tag in tags:
            key, value = tag.split(":", 1)
            event_tags.append([key, value])

        # Créer et signer l'événement Kind 30023 (articles longs)
        event = Event(kind=30023, content=content, tags=event_tags)
        private_key.sign_event(event)

        print(f"📤 Envoi d'un article '{title}' ({len(content)} caractères) à {len(relays)} relai(s)...")
        relay_manager.publish_event(event)

        start_time = time.time()
        success = False

        # Attente du résultat
        while time.time() - start_time < timeout:
            relay_manager.run_sync()
            if event.id in relay_manager.sent_events:
                success = True
                break

        # Fermeture des connexions
        relay_manager.close_connections()

        # Affichage du résultat
        if success:
            print(f"✅ Article envoyé avec succès ! ID : {event.id}")
        else:
            print(f"❌ Échec de l'envoi après {timeout} secondes.")

    except Exception as e:
        print(f"⚠️ Erreur : {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Envoyer un article Markdown sur Nostr (Kind 30023)")

    # Arguments obligatoires
    parser.add_argument("private_key", help="Clé privée (nsec)")
    parser.add_argument("file", help="Fichier Markdown à envoyer")
    parser.add_argument("title", help="Titre de l'article")

    # Options
    parser.add_argument("--relay", type=str, action="append", default=["wss://relay.damus.io"],
                        help="URL du relai Nostr (peut être utilisé plusieurs fois)")
    parser.add_argument("--timeout", type=int, default=10, help="Temps d'attente max pour la confirmation (secondes)")
    parser.add_argument("--tags", type=str, action="append", default=[],
                        help="Ajouter des tags à l'événement (ex: --tags p:npub1xxx --tags e:evtid)")

    args = parser.parse_args()

    # Appeler la fonction principale avec les arguments
    send_long_nostr_event(args.private_key, args.file, args.relay, args.timeout, args.title, args.tags)
