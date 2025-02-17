#!/bin/env python
import argparse
import time
import json
import csv
from pynostr.key import PublicKey
from pynostr.relay_manager import RelayManager
from pynostr.filters import Filters
from pynostr.message_type import ClientMessageType

def get_followers(npub, relays, timeout):
    # Initialiser le gestionnaire de relais
    relay_manager = RelayManager()
    for relay in relays:
        relay_manager.add_relay(relay)

    relay_manager.open_connections()
    time.sleep(1)  # Laisser le temps aux connexions de s'établir

    # Filtrer les events kind: 3 où npub est dans les tags "p"
    filters = Filters([{
        "kinds": [3],  # Kind 3 = liste de contacts (follows)
        "#p": [PublicKey.from_npub(npub).hex()],  # On cherche qui suit cette clé
    }])

    sub_id = "get_followers"
    message = [ClientMessageType.REQUEST, sub_id] + filters.to_json_array()
    relay_manager.publish_message(json.dumps(message))

    followers = set()
    start_time = time.time()

    # Boucle d'attente avec timeout dynamique
    while time.time() - start_time < timeout:
        relay_manager.run_sync()
        for relay in relay_manager.relays.values():
            for event in relay.subscription_handlers.get(sub_id, {}).get("events", []):
                followers.add(event.pubkey)  # Le pubkey de l'auteur de cet event est un follower

        if followers:  # Si on a trouvé des followers, on arrête d'attendre
            break

    relay_manager.close_connections()

    return list(followers)

def save_followers(followers, output_file, output_format):
    if output_format == "json":
        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(followers, f, indent=4)
    elif output_format == "csv":
        with open(output_file, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["npub"])  # En-tête du fichier CSV
            for follower in followers:
                writer.writerow([follower])

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Récupérer la liste des followers d'un compte Nostr.")
    parser.add_argument("npub", type=str, help="Clé publique Nostr (npub)")
    parser.add_argument("--relay", type=str, action="append", default=["wss://relay.copylaradio.com"],
                        help="URL du relay Nostr (peut être spécifié plusieurs fois)")
    parser.add_argument("--timeout", type=int, default=10, help="Temps d'attente max pour la réponse (secondes)")
    parser.add_argument("--format", type=str, choices=["json", "csv"], help="Exporter la liste des followers (json/csv)")
    parser.add_argument("--output", type=str, default="followers", help="Nom du fichier de sortie (sans extension)")

    args = parser.parse_args()

    followers = get_followers(args.npub, args.relay, args.timeout)

    if followers:
        print(f"✅ {args.npub} a actuellement {len(followers)} followers :")
        for follower in followers:
            print(f"- {follower}")

        if args.format:
            output_file = f"{args.output}.{args.format}"
            save_followers(followers, output_file, args.format)
            print(f"📂 Liste des followers enregistrée dans {output_file}")
    else:
        print(f"❌ Aucun follower trouvé pour {args.npub}")
