# Roaming uDRIVE Sync via NIP-04 DMs

Canal de communication inter-NODE pour synchroniser les fichiers uDRIVE
d'un utilisateur MULTIPASS en itinérance vers sa home station.

## Principe

Quand un MULTIPASS se connecte à une station visiteur (B), il peut uploader
des fichiers via UPassport. Ces fichiers doivent rejoindre son uDRIVE sur sa
home station (A), qui seule a autorité pour publier l'IPNS.

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

Canal générique de communication inter-NODE via DMs NIP-04 (kind 4).
Chaque message porte un champ `channel` identifiant le sous-protocole.

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

| Canal    | Payload requis                          | Usage                               |
|----------|-----------------------------------------|-------------------------------------|
| `udrive` | `email`, `cid`, `filename`, `filetype` | Sync fichier uDRIVE visiteur → home |

*(Extensible : `did_update`, `zen_payment`, `alert`, …)*

## Intégration UPassport (`/api/fileupload`)

La fonction `_maybe_send_roaming_dm()` dans [media_upload.py](../UPassport/routers/media_upload.py)
est appelée automatiquement si **`user_dir/.roaming` existe OU si `APP/uDRIVE/` n'existe pas**
(pas de uDRIVE local → impossible de régénérer le manifest localement) :

1. Lit `home.station` (fichier local ou IPFS fallback via NOSTRNS)
2. Extrait le NODE_HEX de la home station (`IPFSNODEID:HEX`)
3. Lit `~/.zen/game/secret.nostr` → NSEC du NODE local (station B)
4. Appelle `nostr_node_intercom.py send-udrive` en subprocess async
5. Si succès → supprime le fichier local, retourne `file_cid` au client
6. Si échec → laisse le fichier, NOSTRCARD.refresh.sh fera le relais

## Identités NODE

Chaque station a une paire de clés NOSTR dédiée :

- `~/.zen/game/secret.nostr` : `NSEC=…; NPUB=…; HEX=…`
- Créée lors de l'initialisation via `Ylevel.sh`
- Le HEX est publié dans le fichier `home.station` du MULTIPASS :
  `~/.zen/game/nostr/EMAIL/home.station` → `IPFSNODEID:NODE_HEX`

La station visiteur lit `home.station` depuis le répertoire local ou l'IPNS
du joueur pour connaître le HEX de la home station et lui envoyer les DMs.

## Déclenchement

| Qui                                 | Quand             | Rôle                                      |
|-------------------------------------|-------------------|-------------------------------------------|
| `/api/fileupload` (Station B)       | À chaque upload   | DM NIP-04 immédiat → home station         |
| `NOSTRCARD.refresh.sh` DM listener (Station A) | Chaque cycle | Réception CIDs + dépôt APP/uDRIVE |
| `NOSTRCARD.refresh.sh` CLEANUP (Station B) | Chaque cycle | Supprime comptes roaming > 24h inactifs |
| `backfill_constellation.sh`         | Toutes les heures | Propagation kind 4 inter-relays           |

## Sécurité

- DMs chiffrés NIP-04 (ECDH + AES-CBC) : seule la home station peut déchiffrer
- Le CID IPFS garantit l'intégrité du fichier par contenu adressable
- La home station vérifie que l'email du payload correspond à un MULTIPASS local (non-roaming)
- Après envoi réussi, le fichier local est supprimé sur la station visiteur
- La clé NSEC utilisée est celle du NODE (pas du joueur) — séparation des responsabilités

## Voir aussi

- [media_upload.py](../UPassport/routers/media_upload.py) — `_maybe_send_roaming_dm()` + `/api/fileupload`
- `NOSTRCARD.refresh.sh` — DM listener (ligne ~325), PULL roaming (ligne ~1686)
- `NIP-101/relay.writePolicy.plugin/filter/22242.sh` — Création répertoire roaming éphémère
- `tools/make_NOSTRCARD.sh` — Écriture de `home.station` lors de la création MULTIPASS
