#!/usr/bin/env python3
import argparse
import time
import json
import logging
import asyncio
import signal
import sys
from pynostr.key import PublicKey
from pynostr.relay_manager import RelayManager
from pynostr.filters import Filters
from pynostr.message_type import ClientMessageType

# Capture SIGINT et SIGTERM pour fermer proprement
def cleanup_and_exit(sig, frame):
    print("\n🚨 Interruption détectée ! Fermeture des connexions...")
    sys.exit(0)

signal.signal(signal.SIGINT, cleanup_and_exit)
signal.signal(signal.SIGTERM, cleanup_and_exit)

# Configuration des logs
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

EVENT_TYPES = {
    0: "Mise à jour de profil",
    1: "Message texte",
    3: "Liste des contacts",
    4: "Message privé",
    7: "Reaction (like/dislike)",
    40: "Début d'une communauté",
    41: "Mise à jour de communauté",
    42: "Post dans une communauté"
}

async def fetch_events(npub, relay_url, timeout=6):
    """Récupère et affiche les messages NOSTR d'un utilisateur."""
    try:
        public_key = PublicKey.from_npub(npub).hex()
        logging.info(f"Clé publique hexadécimale : {public_key}")

        relay_manager = RelayManager()
        relay_manager.add_relay(relay_url)

        await relay_manager.open_connections()
        await asyncio.sleep(1)  # Attente pour l'établissement des connexions

        filters = Filters([{
            "authors": [public_key],
            "kinds": list(EVENT_TYPES.keys()),
            "limit": 50
        }])

        sub_id = "fetch_events"
        message = [ClientMessageType.REQUEST, sub_id, filters.to_dict()]  # Correction : `to_dict()` est correct
        relay_manager.publish_message(json.dumps(message))

        events = []
        start_time = time.time()

        while time.time() - start_time < timeout:
            await relay_manager.run_async()
            for relay in relay_manager.relays.values():
                for event in relay.subscription_handlers.get(sub_id, {}).get("events", []):
                    event_type = EVENT_TYPES.get(event.kind, f"Type inconnu ({event.kind})")
                    events.append({"type": event_type, "content": event.content})

            if events:
                break

        await asyncio.sleep(1)  # Laisser du temps pour les derniers messages
        await relay_manager.close_connections()

        if events:
            logging.info("Événements classés par type :")
            print(json.dumps(events, indent=4, ensure_ascii=False))
        else:
            logging.warning("Aucun événement trouvé pour cet utilisateur.")

    except Exception as e:
        logging.error(f"Erreur lors de la récupération des événements : {e}")

def main():
    parser = argparse.ArgumentParser(description="Lister les messages NOSTR d'un utilisateur et les classer par type.")
    parser.add_argument("npub", help="Clé publique NOSTR (npub1...)")
    parser.add_argument("--relay", default="wss://relay.copylaradio.com", help="URL du relais NOSTR (par défaut : wss://relay.copylaradio.com)")
    parser.add_argument("--timeout", type=int, default=6, help="Temps d'attente pour la réponse (secondes)")

    args = parser.parse_args()

    # Gestion de la boucle asyncio pour éviter "This event loop is already running"
    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)

    loop.run_until_complete(fetch_events(args.npub, args.relay, args.timeout))

if __name__ == "__main__":
    main()
