#!/usr/bin/env python3
import sys
import json
import argparse
from pynostr.event import Event
from pynostr.relay_manager import RelayManager
from pynostr.key import PrivateKey

def send_nostr_event(private_key, kind, content, relay_url):
    # Initialiser le gestionnaire de relais
    relay_manager = RelayManager()
    relay_manager.add_relay(relay_url)

    # Créer une clé privée à partir de la clé nsec
    private_key = PrivateKey.from_nsec(private_key)
    public_key = private_key.public_key.hex()

    # Créer l'événement en fonction du kind
    event = Event(kind=kind, content=content)
    event.sign(private_key.hex())

    print(f"Envoi d'un événement de kind {kind} au relai {relay_url}...")
    relay_manager.publish_event(event)

    # Exécuter le gestionnaire de relais
    relay_manager.run_sync()

    print("Événement envoyé avec succès !")
    print(f"ID de l'événement : {event.id}")

    # Fermer les connexions
    relay_manager.close_connections()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Envoyer un événement Nostr")

    # Définir les arguments positionnels
    parser.add_argument("private_key", help="Clé privée (nsec)")
    parser.add_argument("kind", type=int, help="Type d'événement (kind)")
    parser.add_argument("content", help="Contenu de l'événement")

    # Définir un argument optionnel pour le relai avec une valeur par défaut
    parser.add_argument(
        "relay_url",
        nargs="?",
        default="ws://127.0.0.1:7777",
        help="URL du relai (par défaut : ws://127.0.0.1:7777)"
    )

    args = parser.parse_args()

    # Appeler la fonction principale avec les arguments
    send_nostr_event(args.private_key, args.kind, args.content, args.relay_url)
