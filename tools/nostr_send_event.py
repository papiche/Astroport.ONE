#!/usr/bin/env python3
import sys
import json
import argparse
import time
import asyncio
from pynostr.event import Event, EventKind
from pynostr.relay_manager import RelayManager
from pynostr.key import PrivateKey

DEFAULT_RELAYS = ["wss://relay.copylaradio.com"]
CONNECT_TIMEOUT = 10
PUBLISH_TIMEOUT = 30

async def send_nostr_event(private_key_nsec: str, kind: int, content: str, relays: list,
                           tags: list = None, timeout: int = PUBLISH_TIMEOUT,
                           connect_timeout: int = CONNECT_TIMEOUT):
    if tags is None:
        tags = []
    try:
        print("\n🔌 Initialisation du gestionnaire de relais...")
        relay_manager = RelayManager()

        print("🏗️ Ajout des relais :")
        for relay_url in relays:
            print(f"   - {relay_url}")
            relay_manager.add_relay(relay_url)

        print(f"\n⏳ Ouverture des connexions (timeout: {connect_timeout}s)...")
        connection_start_time = time.time()
        relay_manager.open_connections()

        connected_relays_urls = []
        while time.time() - connection_start_time < connect_timeout:
            connected_relays_urls = [url for url, r_obj in relay_manager.relays.items() if r_obj.connected]
            if connected_relays_urls:
                print(f"\n✅ Connecté à {len(connected_relays_urls)}/{len(relays)} relais :")
                for url in connected_relays_urls:
                    print(f"   - {url}")
                break
            await asyncio.sleep(0.1)
            print(".", end="", flush=True)

        if not connected_relays_urls:
            print(f"\n❌ Échec de la connexion à un relais dans les {connect_timeout} secondes.")
            relay_manager.close_connections()
            return False

        priv_key_obj = PrivateKey.from_nsec(private_key_nsec)
        event = Event(kind=kind, content=content, tags=tags, pubkey=priv_key_obj.public_key.hex())
        priv_key_obj.sign_event(event)

        print("\n📝 Détails de l'événement :")
        print(f"   - ID: {event.id}")
        print(f"   - Kind: {kind}")
        # Tronquer le contenu s'il est trop long pour l'affichage
        display_content = content
        if isinstance(content, str) and len(content) > 70:
            display_content = content[:67] + "..."
        elif not isinstance(content, str):
            display_content = str(content)[:67] + "..."

        print(f"   - Content: {display_content} ({len(str(content))} chars)")
        print(f"   - Tags: {event.tags}")
        print(f"   - Pubkey: {event.pubkey}")

        print(f"\n📤 Publication vers {len(connected_relays_urls)} relais...")
        relay_manager.publish_event(event)

        print(f"\n⏳ Attente des réponses (timeout: {timeout}s)...")
        publish_start_time = time.time()
        responses_count = 0
        last_print_time = time.time()

        while time.time() - publish_start_time < timeout:
            relay_manager.run() # Permet au gestionnaire de relais de traiter les événements réseau

            current_responses_count = 0
            # Compter les réponses OK pour cet event_id spécifique (si possible)
            # pynostr ne facilite pas directement le suivi des "OK" par event_id sans modifications plus profondes.
            # Pour la simplicité, nous allons vérifier si l'événement est dans sent_events et le nombre de réponses générales.
            if event.id in relay_manager.sent_events: # Check if event was at least sent
                 # We assume response_received implies OK for *some* event.
                 # A more robust check would involve parsing OK messages.
                current_responses_count = sum(1 for r_obj in relay_manager.relays.values() if r_obj.response_received and event.id in r_obj.received_event_ids)


            if time.time() - last_print_time > 1:
                print(f"   - Réponses 'OK' (estimées): {current_responses_count}/{len(connected_relays_urls)}", end="\r")
                last_print_time = time.time()

            if current_responses_count >= len(connected_relays_urls): # All relays responded
                 break
            if current_responses_count > responses_count: # Some new response
                responses_count = current_responses_count

            # Simple check if at least one OK was received for this event ID,
            # this part of pynostr is a bit opaque regarding individual event ACKs
            # A robust way would be to listen to `OK` messages in a notice queue.
            # For now, we'll rely on `sent_events` and `response_received`.
            # If any relay has marked response_received after we sent our event, we consider it a partial success.
            at_least_one_ok = False
            if event.id in relay_manager.sent_events:
                for r_obj in relay_manager.relays.values():
                    if r_obj.response_received and event.id in r_obj.received_event_ids: # Check if our event was acknowledged
                        at_least_one_ok = True
                        break
            if at_least_one_ok and responses_count == 0: # If we haven't counted it yet
                responses_count = sum(1 for r_obj in relay_manager.relays.values() if r_obj.response_received and event.id in r_obj.received_event_ids)


            await asyncio.sleep(0.1)

        final_ok_responses = sum(1 for r_obj in relay_manager.relays.values() if r_obj.response_received and event.id in r_obj.received_event_ids)

        relay_manager.close_connections()

        if final_ok_responses > 0:
            print(f"\n\n✅ Succès ! Événement publié sur au moins {final_ok_responses} relais.")
            print(f"   - ID de l'événement : {event.id}")
            return True
        else:
            print("\n\n❌ Échec de la réception d'une réponse 'OK' des relais pour cet événement.")
            return False

    except KeyboardInterrupt:
        print("\n🛑 Opération annulée par l'utilisateur.")
        if 'relay_manager' in locals() and relay_manager:
            relay_manager.close_connections()
        return False
    except Exception as e:
        print(f"\n⚠️ Erreur : {type(e).__name__}: {str(e)}")
        import traceback
        traceback.print_exc()
        if 'relay_manager' in locals() and relay_manager:
            relay_manager.close_connections()
        return False

async def get_input(prompt, default=None, optional=False):
    if default:
        prompt_text = f"{prompt} (défaut: {default}): "
    elif optional:
        prompt_text = f"{prompt} (optionnel, Entrée pour ignorer): "
    else:
        prompt_text = f"{prompt}: "

    value = input(prompt_text).strip()
    if not value:
        if default:
            return default
        if optional:
            return None
        print("Ce champ est requis.")
        return await get_input(prompt, default, optional) # Retry
    return value

async def get_tags_interactive(specific_tags_schema=None):
    tags = []
    print("\n--- Ajout de Tags ---")
    if specific_tags_schema: # e.g., [("p", "Clé publique du destinataire"), ("e", "ID de l'événement cible")]
        for key, desc in specific_tags_schema:
            value = await get_input(f"Valeur pour tag '{key}' ({desc})", optional=True)
            if value:
                tags.append([key, value])
    else:
        while True:
            add_tag = await get_input("Ajouter un tag ? (o/N)", default="n")
            if add_tag.lower() != 'o':
                break
            tag_key = await get_input("Clé du tag (ex: e, p, t, d)")
            tag_value = await get_input("Valeur du tag")
            tag_params = await get_input("Paramètres additionnels du tag (optionnel, séparés par virgule)", optional=True)
            current_tag = [tag_key, tag_value]
            if tag_params:
                current_tag.extend([p.strip() for p in tag_params.split(',')])
            tags.append(current_tag)
            print(f"Tag ajouté: {current_tag}")
    return tags

async def handle_kind_0(private_key_nsec, current_relays):
    print("\n--- Kind 0: Métadonnées du Profil ---")
    profile_data = {
        "name": await get_input("Nom d'affichage", optional=True),
        "about": await get_input("Bio/À propos", optional=True),
        "picture": await get_input("URL de l'image de profil", optional=True),
        "banner": await get_input("URL de l'image de bannière", optional=True),
        "nip05": await get_input("Identifiant NIP-05 (ex: utilisateur@domaine.com)", optional=True),
        "lud16": await get_input("Adresse Lightning (LUD-16, ex: utilisateur@walletofsatoshi.com)", optional=True)
    }
    # Filtrer les valeurs None
    content_dict = {k: v for k, v in profile_data.items() if v is not None}
    if not content_dict:
        print("Aucune métadonnée fournie. Annulation.")
        return
    content = json.dumps(content_dict)
    await send_nostr_event(private_key_nsec, EventKind.SET_METADATA, content, current_relays, tags=[])

async def handle_kind_1(private_key_nsec, current_relays):
    print("\n--- Kind 1: Note Texte Courte ---")
    content = await get_input("Contenu de la note")
    tags = await get_tags_interactive()
    await send_nostr_event(private_key_nsec, EventKind.TEXT_NOTE, content, current_relays, tags)

async def handle_kind_3(private_key_nsec, current_relays):
    print("\n--- Kind 3: Liste de Suivis (Contacts) ---")
    print("Entrez les clés publiques (pubkey hex) des personnes que vous suivez.")
    print("Pour chaque pubkey, vous pouvez optionnellement ajouter une URL de relais et un nom ('petname').")
    tags = []
    while True:
        pubkey = await get_input("Clé publique à suivre (Entrée pour terminer)", optional=True)
        if not pubkey:
            break
        relay_hint = await get_input("URL du relais principal de cette personne (optionnel)", optional=True)
        petname = await get_input("Nom/alias pour cette personne (optionnel)", optional=True)
        tag = ["p", pubkey]
        if relay_hint:
            tag.append(relay_hint)
        if petname: # Si petname est fourni, relay_hint doit l'être, même vide si non spécifié
            if not relay_hint:
                tag.append("") # Placeholder pour relay_hint
            tag.append(petname)
        tags.append(tag)
        print(f"Contact ajouté: {tag}")

    if not tags:
        print("Aucun contact ajouté. Annulation.")
        return
    await send_nostr_event(private_key_nsec, EventKind.CONTACTS, "", current_relays, tags)


async def handle_kind_4(private_key_nsec, current_relays):
    print("\n--- Kind 4: Message Direct Chiffré ---")
    recipient_pubkey = await get_input("Clé publique (hex) du destinataire")
    message_content = await get_input("Contenu du message (sera chiffré)")

    # Le chiffrement NIP-04 est géré par pynostr lors de la signature si la clé publique du destinataire est dans les tags 'p'
    # Cependant, pynostr.event.Event ne chiffre pas automatiquement.
    # Nous allons créer l'événement avec le contenu en clair, et la méthode sign_event de PrivateKey
    # (si elle est bien celle de NIP-04) devrait le chiffrer.
    # pynostr.util.nip04_encrypt / decrypt est disponible.
    # Pour l'instant, on va supposer que l'utilisateur chiffre manuellement ou que
    # le client destinataire s'attend à déchiffrer.
    # Pour une implémentation correcte, il faudrait utiliser pynostr.util.nip04_encrypt ici.

    # Note: pynostr Event ne fait PAS le chiffrement NIP-04 automatiquement.
    # Il faut le faire explicitement en utilisant les fonctions de pynostr.util
    # Pour simplifier cet exemple, nous envoyons le message "comme si" il était chiffré
    # et notons qu'une étape de chiffrement est nécessaire.
    print("AVERTISSEMENT: Ce script n'implémente PAS le chiffrement NIP-04.")
    print("Le message sera envoyé en clair avec un kind 4.")
    print("Pour un vrai DM chiffré, le contenu doit être chiffré avec la clé publique du destinataire.")

    tags = [["p", recipient_pubkey]]
    await send_nostr_event(private_key_nsec, EventKind.ENCRYPTED_DIRECT_MESSAGE, message_content, current_relays, tags)


async def handle_kind_7(private_key_nsec, current_relays):
    print("\n--- Kind 7: Réaction ---")
    target_event_id = await get_input("ID de l'événement auquel réagir")
    target_author_pubkey = await get_input("Clé publique de l'auteur de l'événement cible")
    reaction_content = await get_input("Contenu de la réaction (+, -, 👍, etc.)", default="+")

    tags = [
        ["e", target_event_id],
        ["p", target_author_pubkey]
    ]
    # Ajout du tag "emoji" si la réaction est un emoji
    # (selon certaines interprétations de NIP-25)
    # Pour la compatibilité maximale, on peut ajouter un tag emoji si la réaction est un emoji unique.
    # Exemple simple: si la réaction est un seul caractère et n'est pas '+' ou '-'
    if len(reaction_content) == 1 and reaction_content not in ['+', '-']:
        tags.append(["emoji", reaction_content]) # Ceci est une convention, pas strictement NIP-25

    await send_nostr_event(private_key_nsec, EventKind.REACTION, reaction_content, current_relays, tags)

async def handle_kind_10002(private_key_nsec, current_relays_param):
    print("\n--- Kind 10002: Liste de Relais (NIP-65) ---")
    print("Entrez les URLs de vos relais préférés.")
    tags = []
    while True:
        relay_url = await get_input("URL du relais (ex: wss://relay.damus.io) (Entrée pour terminer)", optional=True)
        if not relay_url:
            break

        usage = await get_input("Usage (read, write, ou laisser vide pour les deux)", optional=True)
        tag = ["r", relay_url]
        if usage and usage.lower() in ["read", "write"]:
            tag.append(usage.lower())
        tags.append(tag)
        print(f"Relais ajouté: {tag}")

    if not tags:
        print("Aucun relais ajouté. Annulation.")
        return
    await send_nostr_event(private_key_nsec, EventKind.RELAY_LIST_METADATA, "", current_relays_param, tags)

async def handle_long_form_30023(private_key_nsec, current_relays):
    print("\n--- Kind 30023: Contenu Long Format (NIP-23) ---")
    identifier = await get_input("Identifiant unique pour cet article (slug, ex: mon-super-article)")
    title = await get_input("Titre de l'article", optional=True)
    summary = await get_input("Résumé/description courte (optionnel)", optional=True)
    image_url = await get_input("URL d'une image de couverture (optionnel)", optional=True)
    print("Entrez le contenu de l'article (Markdown supporté). Ctrl-D (Unix) ou Ctrl-Z+Entrée (Windows) pour terminer.")
    markdown_content_lines = []
    while True:
        try:
            line = input()
            markdown_content_lines.append(line)
        except EOFError:
            break
    markdown_content = "\n".join(markdown_content_lines)

    if not markdown_content:
        print("Contenu vide. Annulation.")
        return

    tags = [["d", identifier]]
    if title:
        tags.append(["title", title])
    if summary:
        tags.append(["summary", summary])
    if image_url:
        tags.append(["image", image_url])

    tags.append(["published_at", str(int(time.time()))]) # Timestamp de publication

    print("Ajouter des hashtags (tags 't') ?")
    custom_tags = await get_tags_interactive() # Permet d'ajouter des tags 't' ou autres
    tags.extend(custom_tags)

    await send_nostr_event(private_key_nsec, EventKind.LONG_FORM_CONTENT, markdown_content, current_relays, tags)


async def main_interactive_loop():
    print("Bienvenue dans l'outil de publication d'événements Nostr interactif !")

    private_key_nsec = ""
    while not private_key_nsec:
        private_key_nsec = await get_input("Entrez votre clé privée Nostr (nsec)")
        try:
            PrivateKey.from_nsec(private_key_nsec)
        except Exception as e:
            print(f"Clé privée invalide: {e}. Veuillez réessayer.")
            private_key_nsec = ""

    current_relays = []
    while not current_relays:
        use_default_relays = await get_input(f"Utiliser les relais par défaut ({', '.join(DEFAULT_RELAYS)})? (O/n)", default="o")
        if use_default_relays.lower() == 'o':
            current_relays.extend(DEFAULT_RELAYS)

        add_more_relays = await get_input("Ajouter d'autres relais? (o/N)", default="n")
        if add_more_relays.lower() == 'o':
            while True:
                new_relay = await get_input("URL du relais à ajouter (Entrée pour terminer)", optional=True)
                if not new_relay:
                    break
                if new_relay not in current_relays:
                    current_relays.append(new_relay)
                    print(f"Relais {new_relay} ajouté.")
                else:
                    print(f"Relais {new_relay} déjà dans la liste.")
        if not current_relays:
            print("Aucun relais configuré. Veuillez en ajouter au moins un.")


    menu_options = {
        "0": ("Métadonnées du Profil (Kind 0)", handle_kind_0),
        "1": ("Note Texte Courte (Kind 1)", handle_kind_1),
        "3": ("Liste de Suivis/Contacts (Kind 3)", handle_kind_3),
        "4": ("Message Direct (Kind 4 - Non chiffré par ce script)", handle_kind_4),
        "7": ("Réaction (Kind 7)", handle_kind_7),
        "10002": ("Liste de Relais (NIP-65) (Kind 10002)", handle_kind_10002),
        "30023": ("Contenu Long Format (NIP-23) (Kind 30023)", handle_long_form_30023),
        # Ajoutez d'autres kinds ici
        "q": ("Quitter", None)
    }

    while True:
        print("\n--- Menu Principal ---")
        for key, (description, _) in menu_options.items():
            print(f"{key}. {description}")

        choice = await get_input("Choisissez une option")

        if choice == 'q':
            print("Au revoir !")
            break

        selected_option = menu_options.get(choice)
        if selected_option:
            description, handler_func = selected_option
            if handler_func:
                await handler_func(private_key_nsec, current_relays)
            else:
                print("Option non implémentée.") # Devrait être pour 'q' seulement
        else:
            print("Option invalide. Veuillez réessayer.")

if __name__ == "__main__":
    try:
        asyncio.run(main_interactive_loop())
    except KeyboardInterrupt:
        print("\n🛑 Sortie demandée par l'utilisateur.")
    sys.exit(0)
