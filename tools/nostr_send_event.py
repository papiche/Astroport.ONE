#!/usr/bin/env python3
import sys
import json
import argparse
import time
from pynostr.event import Event
from pynostr.relay_manager import RelayManager
from pynostr.key import PrivateKey

def send_nostr_event(private_key, kind, content, relays, timeout, tags):
    try:
        # Initialiser le gestionnaire de relais
        relay_manager = RelayManager()
        for relay in relays:
            relay_manager.add_relay(relay)

        print("🔌 Opening connections to relays...")
        relay_manager.open_connections()
        time.sleep(1)  # Temps pour établir la connexion, may need adjustment

        # Créer une clé privée à partir de la clé nsec
        private_key = PrivateKey.from_nsec(private_key)

        # Construire les tags
        event_tags = []
        for tag in tags:
            key, value = tag.split(":", 1)
            event_tags.append([key, value])

        # Créer et signer l'événement
        event = Event(kind=kind, content=content, tags=event_tags)
        private_key.sign_event(event)

        print("📝 Event created:")
        print(f"   - ID: {event.id}")
        print(f"   - Kind: {event.kind}")
        print(f"   - Content: {event.content}")
        print(f"   - Tags: {event.tags}")
        print(f"   - Pubkey: {event.pubkey}")

        print(f"📤 Envoi d'un événement kind {kind} à {len(relays)} relai(s)...")
        relay_manager.publish_event(event)

        start_time = time.time()
        success = False

        # Attente du résultat
        while time.time() - start_time < timeout:
            relay_manager.run_sync()
            if event.id in relay_manager.sent_events:
                success = True
                break
            time.sleep(0.1) # reduce CPU usage

        # Fermeture des connexions
        relay_manager.close_connections()
        print("🚪 Connections closed.")

        # Affichage du résultat
        if success:
            print(f"✅ Événement envoyé avec succès ! ID : {event.id}")
        else:
            print(f"❌ Échec de l'envoi après {timeout} secondes.")

    except Exception as e:
        print(f"⚠️ Erreur : {type(e)}, {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Envoyer un événement Nostr")

    # Définir les arguments positionnels
    parser.add_argument("private_key", help="Clé privée (nsec)")
    parser.add_argument("kind", type=int, help="Type d'événement (kind)")
    parser.add_argument("content", help="Contenu de l'événement")

    # Options
    parser.add_argument("--relay", type=str, action="append", default=["wss://relay.damus.io", "wss://nos.social", "wss://relay.copylaradio.com"],
                        help="URL du relai Nostr (peut être utilisé plusieurs fois)")
    parser.add_argument("--timeout", type=int, default=30, help="Temps d'attente max pour la confirmation (secondes)")
    parser.add_argument("--tags", type=str, action="append", default=[],
                        help="Ajouter des tags à l'événement (ex: --tags p:npub1xxx --tags e:evtid)")

    args = parser.parse_args()

    # Appeler la fonction principale avec les arguments
    send_nostr_event(args.private_key, args.kind, args.content, args.relay, args.timeout, args.tags)
