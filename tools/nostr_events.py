#!/usr/bin/env python3
import argparse
import json
import logging
import asyncio
from pynostr.key import PublicKey
from pynostr.filters import FiltersList, Filters
from pynostr.event import EventKind
from pynostr.relay_manager import RelayManager
from tornado.platform.asyncio import AsyncIOMainLoop

# Configuration des logs
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

# Liste des types d'événements courants sur NOSTR
EVENT_TYPES = {
    EventKind.SET_METADATA: "Mise à jour de profil",
    EventKind.TEXT_NOTE: "Message texte",
    EventKind.CONTACTS: "Liste des contacts",
    EventKind.ENCRYPTED_DIRECT_MESSAGE: "Message privé",
    EventKind.REACTION: "Reaction (like/dislike)",
    40: "Début d'une communauté",
    41: "Mise à jour de communauté",
    42: "Post dans une communauté"
}

async def fetch_events(npub: str, relay_url: str):
    """Récupère et affiche les messages NOSTR d'un utilisateur."""
    try:
        # Convertir npub en clé publique hexadécimale
        public_key = PublicKey.from_npub(npub).hex()
        logging.info(f"Clé publique hexadécimale : {public_key}")

        # Configurer le gestionnaire de relais et les filtres
        relay_manager = RelayManager(timeout=6)
        relay_manager.add_relay(relay_url)

        filters = FiltersList([
            Filters(authors=[public_key], kinds=list(EVENT_TYPES.keys()), limit=50)
        ])

        # Connexion aux relais et récupération des événements
        logging.info(f"Connexion au relais : {relay_url}")
        relay_manager.open_connections()
        await asyncio.sleep(1)  # Attendre que les connexions soient établies

        relay_manager.subscribe(filters)
        await asyncio.sleep(2)  # Attendre les réponses des relais

        event_dict = {}
        for message in relay_manager.message_pool.get_events():
            event_type = EVENT_TYPES.get(message.kind, f"Type inconnu ({message.kind})")
            if event_type not in event_dict:
                event_dict[event_type] = []
            event_dict[event_type].append(message.content)

            logging.info(f"Événement reçu : {event_type} -> {message.content[:100]}...")

        relay_manager.close_connections()

        # Afficher les résultats
        if event_dict:
            logging.info("Événements classés par type :")
            print(json.dumps(event_dict, indent=4, ensure_ascii=False))
        else:
            logging.warning("Aucun événement trouvé pour cet utilisateur.")

    except Exception as e:
        logging.error(f"Erreur lors de la récupération des événements : {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Lister les messages NOSTR d'un utilisateur et les classer par type.")
    parser.add_argument("npub", help="Clé publique NOSTR (npub1...)")
    parser.add_argument("--relay", default="ws://127.0.0.1:7777", help="URL du relais NOSTR (par défaut : ws://127.0.0.1:7777)")

    args = parser.parse_args()

    # Vérifier si le paramètre npub est présent
    if not args.npub:
        parser.error("Le paramètre npub est requis. Veuillez fournir une clé publique NOSTR (npub1...).")

    # Configure Tornado's AsyncIOMainLoop to work with asyncio
    AsyncIOMainLoop().install()

    # Run the main coroutine using asyncio's default loop
    asyncio.run(fetch_events(args.npub, args.relay))
