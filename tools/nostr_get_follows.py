#!/bin/env python
import argparse
import time
import json
import csv
from pynostr.key import PublicKey
from pynostr.relay_manager import RelayManager
from pynostr.filters import Filters
from pynostr.message_type import ClientMessageType

def get_follows(npub, relays, timeout):
    # Initialiser le gestionnaire de relais
    relay_manager = RelayManager()
    for relay in relays:
        relay_manager.add_relay(relay)

    relay_manager.open_connections()
    time.sleep(1)  # Laisser le temps aux connexions de s'établir

    # Créer un filtre pour récupérer le dernier event "kind: 3"
    filters = Filters([{
        "kinds": [3],  # Kind 3 = liste de contacts (follows)
        "authors": [PublicKey.from_npub(npub).hex()],  # Filtrer par l'auteur
        "limit": 1  # Dernier event seulement
    }])

    sub_id = "get_follows"
    message = [ClientMessageType.REQUEST, sub_id] + filters.to_json_array()
    relay_manager.publish_message(json.dumps(message))

    follows = set()
    start_time = time.time()

    # Boucle d'attente avec timeout dynamique
    while time.time() - start_time < timeout:
        relay_manager.run_sync()
        for relay in relay_manager.relays.values():
            for event in relay.subscription_handlers.get(sub_id, {}).get("events", []):
                for tag in event.tags:
                    if tag[0] == "p":  # Les follows sont stockés sous forme de tags "p"
                        follows.add(tag[1])

        if follows:  # Si on a trouvé des follows, on arrête d'attendre
            break

    relay_manager.close_connections()

    return list(follows)

def save_follows(follows, output_file, output_format):
    if output_format == "json":
        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(follows, f, indent=4)
    elif output_format == "csv":
        with open(output_file, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["npub"])  # En-tête du fichier CSV
            for follow in follows:
                writer.writerow([follow])

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Récupérer la liste des follows d'un compte Nostr.")
    parser.add_argument("npub", type=str, help="Clé publique Nostr (npub)")
    parser.add_argument("--relay", type=str, action="append", default=["wss://relay.copylaradio.com"],
                        help="URL du relay Nostr (peut être spécifié plusieurs fois)")
    parser.add_argument("--timeout", type=int, default=10, help="Temps d'attente max pour la réponse (secondes)")
    parser.add_argument("--format", type=str, choices=["json", "csv"], help="Exporter la liste des follows (json/csv)")
    parser.add_argument("--output", type=str, default="follows", help="Nom du fichier de sortie (sans extension)")

    args = parser.parse_args()

    follows = get_follows(args.npub, args.relay, args.timeout)

    if follows:
        print(f"✅ {args.npub} suit actuellement {len(follows)} comptes :")
        for follow in follows:
            print(f"- {follow}")

        if args.format:
            output_file = f"{args.output}.{args.format}"
            save_follows(follows, output_file, args.format)
            print(f"📂 Liste des follows enregistrée dans {output_file}")
    else:
        print(f"❌ Aucun follow trouvé pour {args.npub}")
