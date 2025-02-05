Voici comment utiliser nostr-commander-rs :

1. Installation :
   Téléchargez et installez nostr-commander-rs depuis son dépôt GitHub.

2. Configuration initiale :
   - Créez un nouvel utilisateur avec la commande :
     ```
     nostr-commander-rs --create-user --name "Votre Nom" --display-name "Pseudo" --about "Description" --picture "URL_avatar" --nip05 "votre_id@example.org" --add-relay "wss://relay.copylaradio.com" "wss://relay.g1sms.fr"
     ```
   - Cela générera un fichier de configuration par défaut dans `$HOME/.local/share/nostr-commander-rs/credentials.json`.

3. Commandes de base :
   - Publier une note :
     ```
     nostr-commander-rs --publish "Votre message"
     ```
   - Envoyer un message privé :
     ```
     nostr-commander-rs --dm npub1DestinatairePublicKey "Votre message privé"
     ```
   - S'abonner à un utilisateur :
     ```
     nostr-commander-rs --subscribe-author npub1UtilisateurPublicKey
     ```
   - Écouter les événements :
     ```
     nostr-commander-rs --listen
     ```

4. Gestion des contacts :
   - Ajouter un contact :
     ```
     nostr-commander-rs --add-contact --alias "surnom" --key npub1PublicKey --relay "wss://relay.com"
     ```
   - Afficher les contacts :
     ```
     nostr-commander-rs --show-contacts
     ```

5. Utilisation avancée :
   - Utiliser un proxy :
     ```
     nostr-commander-rs --add-relay "wss://relay.copylaradio.com" --proxy "127.0.0.1:9050"
     ```
   - Convertir les clés :
     ```
     nostr-commander-rs --npub-to-hex npub1PublicKey
     ```

6. Options de sortie :
   - Pour une sortie JSON :
     ```
     nostr-commander-rs --output json --publish "Message"
     ```

Consultez le manuel complet avec `nostr-commander-rs --manual` pour plus de détails sur toutes les options disponibles.
