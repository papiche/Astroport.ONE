#!/usr/bin/env python3
import argparse
import json
import subprocess
import os

def load_default_relays():
    config_path = os.path.expanduser("~/.nostr_config.json")
    if os.path.exists(config_path):
        with open(config_path) as f:
            cfg = json.load(f)
            return cfg.get("default_relays", ["wss://relay.copylaradio.com"])
    return ["wss://relay.copylaradio.com"]

def run_nostpy_cli(npub, relays):
    cmd = [
        "nostpy-cli",
        "query",
        "--kinds", "0",  # On suppose que vous voulez les événements 'kind: 0' (métadonnées)
        "--authors", npub  # Utilisation correcte du paramètre --authors pour spécifier la clé publique
    ]

    # Ajouter chaque relais à la commande
    for relay in relays:
        cmd.extend(["--relay", relay])

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print("❌ Erreur lors de l'exécution de nostpy-cli :", result.stderr)
        return None
    try:
        events = json.loads(result.stdout)
        return events
    except json.JSONDecodeError:
        print("❌ Échec du décodage JSON")
        return None

def parse_metadata_event(events):
    if not events:
        return None
    # Utiliser le plus récent
    sorted_events = sorted(events, key=lambda e: e.get("created_at", 0), reverse=True)
    return sorted_events[0]

def main():
    parser = argparse.ArgumentParser(description="Lire un profil Nostr via nostpy-cli")
    parser.add_argument("npub", help="Clé publique Nostr (npub...)")
    parser.add_argument("relays", nargs="*", help="Liste des relais (wss://...)", default=load_default_relays())
    parser.add_argument("--json", action="store_true", help="Affiche le profil brut en JSON")
    args = parser.parse_args()

    events = run_nostpy_cli(args.npub, args.relays)
    event = parse_metadata_event(events)
    if not event:
        print("⚠️ Aucun événement 'kind: 0' trouvé.")
        return

    content = json.loads(event.get("content", "{}"))
    tags = event.get("tags", [])

    if args.json:
        print(json.dumps({"content": content, "tags": tags}, indent=2))
    else:
        print("📄 Profil Nostr de :", args.npub)
        for k, v in content.items():
            print(f"  {k:10} : {v}")
        if tags:
            print("\n🏷️  Tags externes :")
            for tag in tags:
                if isinstance(tag, list) and len(tag) >= 2:
                    print(f"  [{tag[0]}] {tag[1]}")

if __name__ == "__main__":
    main()
