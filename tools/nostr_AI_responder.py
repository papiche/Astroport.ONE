import requests
import time
import ssl
import os
import json
import uuid
import re
import gc
from datetime import datetime
from pynostr.event import Event, EventKind
from pynostr.relay_manager import RelayManager
from pynostr.message_type import ClientMessageType
from pynostr.key import PrivateKey
from pynostr.filters import FiltersList, Filters
from pynostr.encrypted_dm import EncryptedDirectMessage
from pynostr.utils import get_timestamp
import ollama
import logging

# Configuration du logging
logging.basicConfig(
    filename='nostr_bot.log',  # Nom du fichier de log
    level=logging.INFO,       # Niveau de log (INFO, DEBUG, WARNING, ERROR, CRITICAL)
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logging.info("Démarrage du bot Nostr.")

# Initialisation des relais
relay_manager = RelayManager(timeout=2)

# Récupération du modèle d'IA
model = os.environ.get("OLLAMA_MODEL")
if not model:
    print('The environment variable "OLLAMA_MODEL" is not set.')
    exit(1)

def system_message():
    """Retourne le message système du bot."""
    current_date = datetime.now().strftime("%A, %B %d, %Y")
    return f"You are ASTROBOT, an AI Assistant on UPlanet. Réponds dans la langue du PROMPT. Date : {current_date}."

def respond(message):
    """Génère une réponse avec Ollama."""
    messages = [{"role": "system", "content": system_message()}, {"role": "user", "content": message}]
    return ollama.chat(model=model, messages=messages)['message']['content']

def get_private_key(nsec=None):
    """Récupère la clé privée depuis un paramètre ou un fichier."""
    if nsec:
        return PrivateKey.from_nsec(nsec)

    secret_file = os.path.expanduser("~/.zen/game/secret.nostr")
    try:
        with open(secret_file, 'r') as f:
            content = f.read()
            nsec_match = re.search(r'NSEC=([^\s;]+)', content)
            if nsec_match:
                return PrivateKey.from_nsec(nsec_match.group(1))
            print("No NSEC key found in secret.nostr file")
    except FileNotFoundError:
        print(f"Secret file not found at {secret_file}")
    except Exception as e:
        print(f"Error reading secret file: {e}")
    return None

def run(nsec=None):
    """Exécution principale du bot."""
    messages_done = set()

    private_key = get_private_key(nsec)
    if not private_key:
        print('Could not get private key. Exiting.')
        exit(1)

    # Configuration des relais
    env_relays = os.getenv('RELAYS', "wss://relay.copylaradio.com")
    for relay in env_relays.split(","):
        print(f"Adding relay: {relay}")
        relay_manager.add_relay(relay)

    print(f"Pubkey: {private_key.public_key.bech32()}")
    print(f"Pubkey (hex): {private_key.public_key.hex()}")
    logging.info(f"Bot Pubkey (hex): {private_key.public_key.hex()}")

    start_timestamp = get_timestamp()

    while True:
        filters = FiltersList([
            Filters(pubkey_refs=[private_key.public_key.hex()], kinds=[EventKind.ENCRYPTED_DIRECT_MESSAGE, EventKind.TEXT_NOTE, EventKind.METADATA], since=start_timestamp) # Ajout de EventKind.METADATA
        ])
        subscription_id = uuid.uuid1().hex
        relay_manager.add_subscription_on_all_relays(subscription_id, filters)
        relay_manager.run_sync()

        while relay_manager.message_pool.has_notices():
            notice_msg = relay_manager.message_pool.get_notice()
            print(f"Notice: {notice_msg.content}")
            logging.info(f"Notice from relay: {notice_msg.content}") # Log des notices

        while relay_manager.message_pool.has_events():
            event_msg = relay_manager.message_pool.get_event()
            if event_msg.event.id in messages_done:
                continue

            messages_done.add(event_msg.event.id)
            recipient_pubkey = event_msg.event.pubkey
            event = event_msg.event # Raccourci pour event_msg.event

            if event.kind == EventKind.METADATA: # Log des events de kind 0
                logging.info(f"Received Metadata Event - ID: {event.id}, Pubkey: {event.pubkey}, Content: {event.content}")

            elif event.kind == EventKind.TEXT_NOTE: # Log des events de kind 1
                logging.info(f"Received Text Note Event - ID: {event.id}, Pubkey: {event.pubkey}, Content: {event.content}")

                content = re.sub(r'\b(nostr:)?(nprofile|npub)[0-9a-z]+[\s]*', '', event.content)
                if len(content) < 4:
                    continue

                print(f"Received public note: {content}")
                if recipient_pubkey != private_key.public_key.bech32():
                    reply = Event(content=respond(content))
                    reply.add_event_ref(event.id)
                    reply.add_pubkey_ref(event.pubkey)
                    reply.sign(private_key.hex())
                    relay_manager.publish_event(reply)
                    print("Public response sent.")

            elif event.kind == EventKind.ENCRYPTED_DIRECT_MESSAGE:
                dm = EncryptedDirectMessage()
                dm.decrypt(private_key.hex(), event.content, recipient_pubkey)
                if len(dm.cleartext_content) < 4:
                    continue

                print(f"Private message '{dm.cleartext_content}' from {recipient_pubkey}")
                response = respond(dm.cleartext_content)
                print(f"Sending response to {recipient_pubkey}")

                dm_reply = EncryptedDirectMessage()
                dm_reply.encrypt(private_key.hex(), recipient_pubkey, response)
                dm_event = dm_reply.to_event()
                dm_event.sign(private_key.hex())
                relay_manager.publish_event(dm_event)
                print(f"Response sent to {recipient_pubkey}")

            gc.collect()

        time.sleep(10)

try:
    run(nsec=os.getenv("NSEC"))
except KeyboardInterrupt:
    print("KeyboardInterrupt")
    logging.info("Bot arrêté par KeyboardInterrupt.")
    relay_manager.close_all_relay_connections()
except Exception as e:
    print(f"Exception: {e}")
    logging.error(f"Exception non gérée: {e}", exc_info=True) # Log de l'exception complète
    relay_manager.close_all_relay_connections()
    run()
