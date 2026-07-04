# Roaming uDRIVE Sync via NIP-04 DMs

Canal de communication inter-NODE pour synchroniser les fichiers uDRIVE d'un utilisateur MULTIPASS en itinérance vers sa home station.

## Principe

Quand un MULTIPASS se connecte à une station visiteur (B), il peut uploader des fichiers via UPassport. Ces fichiers doivent rejoindre son uDRIVE sur sa home station (A), qui seule a autorité pour publier l'IPNS.

```
Station B (visiteur) :
  1. NIP-42 auth → 22242.sh crée répertoire éphémère + .roaming flag
                   + sauvegarde NOSTRNS et G1PUBNOSTR depuis swarm data

  2. Upload → /api/fileupload
        → ipfs add (via upload2ipfs.sh) → CID
        → _maybe_send_roaming_dm() : DM NIP-04 immédiat vers home station NODE HEX
        → supprime le fichier local si DM réussi
        → retourne file_cid au client (pas de régénération uDRIVE locale)

  3. NOSTRCARD.refresh.sh CLEANUP (chaque cycle)
        Supprime les répertoires roaming sans marker NIP-42 depuis 24h

Station A (home) :
  NOSTRCARD.refresh.sh DM listener (en tête de chaque cycle)
  → nostr_node_intercom.py receive --channel udrive --since LAST_TS
  → ipfs get CID → APP/uDRIVE/[type]/[filename]
  → touch uDRIVE/ → should_refresh() détecte le changement
  → generate_ipfs_structure.sh + ipfs name publish (IPNS)
```

## Script : `tools/nostr_node_intercom.py`

Canal générique de communication inter-NODE via DMs NIP-04 (kind 4). Chaque message porte un champ `channel` identifiant le sous-protocole.

### Envoyer un fichier uDRIVE (Station B → Station A)

```bash
python3 tools/nostr_node_intercom.py send-udrive \
    --nsec    "$NODE_NSEC_B" \
    --to      "$HOME_NODE_HEX" \
    --email   "user@example.com" \
    --cid     "QmXxx..." \
    --filename "photo.jpg" \
    --filetype image \
    --relays  wss://relay.copylaradio.com
```

**Paramètres `--filetype`** : `image`, `video`, `audio`, `document`, `file`

### Recevoir les demandes de sync (Station A — home)

```bash
python3 tools/nostr_node_intercom.py receive \
    --nsec    "$NODE_NSEC_A" \
    --channel udrive \
    --since   "$LAST_TS" \
    --relays  wss://relay.copylaradio.com
```

**Sortie JSON** :

```json
[
  {
    "channel": "udrive",
    "payload": {
      "email":    "user@example.com",
      "cid":      "QmXxx...",
      "filename": "photo.jpg",
      "filetype": "image"
    },
    "event_id":   "abc123...",
    "sender":     "deadbeef...",
    "created_at": 1700000000
  }
]
```

### Envoyer un message générique

```bash
python3 tools/nostr_node_intercom.py send \
    --nsec    "$NODE_NSEC" \
    --to      "$DEST_HEX" \
    --channel "my_channel" \
    --payload '{"key": "value"}' \
    --relays  wss://relay.copylaradio.com
```

## Canaux définis

| Canal      | Payload requis                                                                                                                                                          | Usage                                                                              |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `udrive`   | `email`, `cid`, `filename`, `filetype`                                                                                                                                  | Sync fichier uDRIVE visiteur → home                                                |
| `vocals`   | `email`, `cid`, `filename`, `filetype`, `mime_type`, `duration`, `title`, `kind`                                                                                        | Publication kind 1222/1244 (vocal) via home                                        |
| `webcam`   | `email`, `cid`, `filename`, `filetype`, `mime_type`, `duration`, `title`                                                                                                | Publication kind 21/22 (vidéo) via home                                            |
| `bro_ia`   | `pubkey`, `event_id`, `lat`, `lon`, `message`, `url`, `kname`                                                                                                           | Commande BRO (#BRO kind 1) relayée depuis visiteur                                 |
| `zen_like` | `email`, `sender_pubkey`, `event_id`, `reacted_event_id`, `reacted_author_pubkey`, `zen_amount`, `comment`, `g1pub_dest`, `is_crowdfunding`, `project_id`, `bien_g1pub` | Paiement ZEN/G1 (kind 7) relayé depuis visiteur — **seulement si zen\_amount > 0** |

_(Extensible : `did_update`, `zen_payment`, `alert`, …)_

### Canal `bro_ia` — Relay des commandes BRO pour utilisateurs en roaming

Quand un MULTIPASS en roaming envoie un message kind 1 `#BRO` sur le relay de la station visiteur, `UPlanet_IA_Responder.sh` (station B) détecte le marker `.roaming`, lit `home.station` pour obtenir le NODE\_HEX de la home station, puis envoie un DM NIP-44 canal `bro_ia` plutôt que de traiter la commande localement.

```
Station B (visiteur) — UPlanet_IA_Responder.sh :
  1. Reçoit kind 1 #BRO de fred@example.com
  2. Détecte ~/.zen/game/nostr/fred@example.com/.roaming
  3. Lit home.station → HOME_NODE_HEX (64 hex)
  4. Construit payload bro_ia : {pubkey, event_id, lat, lon, message, url, kname}
  5. nostr_node_intercom.py send --channel bro_ia → DM NIP-44 → relay
  6. exit 0 (pas de traitement local)

Station A (home) — bro_dm_daemon.sh :
  1. inotifywait reçoit le fichier JSON dans bro_dm_queue/
  2. déchiffre via nostr_node_intercom.py decrypt
  3. channel == "bro_ia" → _handle_bro_ia()
  4. Appelle UPlanet_IA_Responder.sh avec les paramètres reconstruits
  5. Traitement complet avec les vraies clés joueur et le vrai uDRIVE
```

**Avantages** :

* La home station a les clés du joueur et accès à son uDRIVE/APP
* L'IPNS n'est publié que par la home station (source de vérité)
* Les ressources IA (Ollama, ComfyUI) de la home station sont utilisées
* La station visiteur reste légère (pas de traitement IA lourd)

### Résolution `home_node_hex` pour AMIS\_ROAMING

`HOME_IPFSNODEID` et `NOSTRNS` sauvegardés par `22242.sh` pour les utilisateurs `amisOfAmis_roaming` contiennent la **clé IPNS CIDv1** du joueur (`k51…`), pas le peer ID libp2p de la home station. La résolution suit donc cet ordre de priorité :

1. `user_dir/home.station` (cache local — mis à jour à chaque résolution réussie)
2. **strfry scan kind 0** du joueur → champ `home_station` (`IPFSNODEID:NODE_HEX_64`)
3. Scan `~/.zen/tmp/swarm/*/TW/{email}/` → `12345.json` → `NODEHEX` (SWARM\_ROAMING)
4. IPFS via `NOSTRNS/{email}/home.station` (lent, peut échouer)
5. IPFS via `/ipns/HOME_IPFSNODEID/{email}/home.station` (dernier recours)

**Prérequis** : la home station doit avoir publié le champ `home_station` dans le profil kind 0 du joueur via `nostr_setup_profile.py` (fait lors de la création MULTIPASS).

## Identités NODE

Chaque station a une paire de clés NOSTR dédiée :

* `~/.zen/game/secret.nostr` : `NSEC=…; NPUB=…; HEX=…`
* Créée lors de l'initialisation via `Ylevel.sh`
* Le HEX est publié dans le fichier `home.station` du MULTIPASS : `~/.zen/game/nostr/EMAIL/home.station` → `IPFSNODEID:NODE_HEX`

La station visiteur lit `home.station` depuis le répertoire local ou l'IPNS du joueur pour connaître le HEX de la home station et lui envoyer les DMs.

## Déclenchement

| Qui                                            | Quand             | Rôle                                            |
| ---------------------------------------------- | ----------------- | ----------------------------------------------- |
| `/api/fileupload` (Station B)                  | À chaque upload   | DM NIP-04 immédiat → home station               |
| `UPlanet_IA_Responder.sh` (Station B)          | Kind 1 #BRO reçu  | Détecte .roaming → DM bro\_ia → home station    |
| `bro_dm_daemon.sh` (Station A)                 | Queue DM inotify  | Canal bro\_ia → UPlanet\_IA\_Responder.sh local |
| `NOSTRCARD.refresh.sh` DM listener (Station A) | Chaque cycle      | Réception CIDs + dépôt APP/uDRIVE               |
| `NOSTRCARD.refresh.sh` CLEANUP (Station B)     | Chaque cycle      | Supprime comptes roaming > 24h inactifs         |
| `backfill_constellation.sh`                    | Toutes les heures | Propagation kind 4 inter-relays                 |

## Sécurité

* DMs chiffrés NIP-44 (ChaCha20-Poly1305 + HKDF-SHA256) : seule la home station peut déchiffrer
* Le CID IPFS garantit l'intégrité du fichier par contenu adressable
* La home station vérifie que l'email du payload correspond à un MULTIPASS local (non-roaming)
* Après envoi réussi, le fichier local est supprimé sur la station visiteur
* La clé NSEC utilisée est celle du NODE (pas du joueur) — séparation des responsabilités

## Voir aussi

* [media\_upload.py](https://github.com/papiche/Astroport.ONE/blob/master/UPassport/routers/media_upload.py) — `_maybe_send_roaming_dm()` + `/api/fileupload`
* `NOSTRCARD.refresh.sh` — DM listener (ligne \~325), PULL roaming (ligne \~1686)
* `NIP-101/relay.writePolicy.plugin/filter/22242.sh` — Création répertoire roaming éphémère
* `tools/make_NOSTRCARD.sh` — Écriture de `home.station` lors de la création MULTIPASS
* `IA/UPlanet_IA_Responder.sh` — Détection `.roaming` → DM channel `bro_ia` vers home station
* `IA/bro_dm_daemon.sh` — Canal `bro_ia` : `_handle_bro_ia()` appelle UPlanet\_IA\_Responder localement
