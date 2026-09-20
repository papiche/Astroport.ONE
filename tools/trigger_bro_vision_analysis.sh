#!/bin/bash
########################################################################
# trigger_bro_vision_analysis.sh — Déclencheur FaceID côté Satellite
#
# Appelé en arrière-plan par UPassport/services/cloud_storage.py juste après
# un PUT réussi sur le cloud chiffré (/dav/), quand le fichier est une image.
# Envoie un job `vision_analysis_job` (canal inter-NODE NIP-44, cf.
# nostr_node_intercom.py) au Brain GPU actuellement connecté — ou à soi-même
# si cette station EST le Brain (pas de GPU distant configuré).
#
# IMPORTANT (2026-09-20) : le déclenchement se fait UNIQUEMENT depuis le
# cloud chiffré, jamais depuis le uDRIVE public (manifest.json/IPNS) — voir
# UPassport/CLAUDE.md. `ipfs_link` référence donc un blob UENC chiffré, JAMAIS
# une image en clair, et `decryption_key` voyage dans ce DM déjà chiffré
# NIP-44 entre deux NODEs de confiance (même principe que le partage NIP-17
# aux amis, un cran plus tôt dans le pipeline) — le Brain déchiffre en
# mémoire pour l'analyse, ne persiste jamais le clair, et ne renvoie que les
# embeddings (aucune donnée nominative ni image ne repart du Brain).
#
# Le Brain répond sur le canal `vision_analysis_result` vers `reply_node_hex`,
# où IA/bro/bro_dm_daemon.sh::_handle_vision_analysis_result() prend le relais.
#
# Usage: trigger_bro_vision_analysis.sh <EMAIL> <OWNER_HEX> <PATH> <IPFS_LINK> [DECRYPTION_KEY_HEX]
#   EMAIL              MULTIPASS propriétaire du fichier
#   OWNER_HEX          HEX de ce MULTIPASS (nomme la collection Qdrant faces_{owner_hex})
#   PATH               chemin DAV, ex: /Photos/photo.jpg
#   IPFS_LINK          CID du blob UENC chiffré (jamais un lien en clair)
#   DECRYPTION_KEY_HEX clé AES-256 (64 hex chars) — optionnelle, mais requise
#                      pour tout ipfs_link chiffré (toujours le cas depuis 2026-09-20)
#
# Best effort intégral : TOUT échec sort en 0 silencieusement. Ce script est
# dans le chemin chaud du PUT — il ne doit jamais le faire échouer ni le
# ralentir (appelé en arrière-plan, fire-and-forget, par l'appelant Python).
########################################################################

EMAIL="$1"
OWNER_HEX="$2"
RELPATH="$3"
IPFS_LINK="$4"
DECRYPTION_KEY="$5"

[[ -z "$EMAIL" || -z "$OWNER_HEX" || -z "$RELPATH" || -z "$IPFS_LINK" ]] && exit 0
[[ ${#OWNER_HEX} -ne 64 ]] && exit 0
[[ -d "$HOME/.zen/game/nostr/$EMAIL" ]] || exit 0

INTERCOM="$HOME/.zen/Astroport.ONE/tools/nostr_node_intercom.py"
[[ -s "$INTERCOM" ]] || exit 0

## Identité NODE locale — même format que ~/.zen/game/secret.nostr partout
## ailleurs (NSEC=…;HEX=…), cf. filter/4.sh et bro_dm_daemon.sh.
SECRET_FILE="$HOME/.zen/game/secret.nostr"
[[ -s "$SECRET_FILE" ]] || exit 0
NODE_HEX_SELF=$(grep -oP 'HEX=\K[^;]+' "$SECRET_FILE" 2>/dev/null | tr -d '[:space:]')
NSEC=$(grep -oP 'NSEC=\K[^;]+' "$SECRET_FILE" 2>/dev/null | tr -d '[:space:]')
[[ ${#NODE_HEX_SELF} -ne 64 || -z "$NSEC" ]] && exit 0

## Cible : le Brain GPU auquel comfyui.me.sh est actuellement connecté
## (CONNECTION_NODE_HEX, écrit par IA/services/comfyui.me.sh::_try_connect_node).
## Absent = ComfyUI local ou pas encore connecté → on s'adresse le job à
## soi-même, le daemon le traitera comme n'importe quel job Brain.
STATUS_FILE="$HOME/.zen/tmp/comfyui_connection.status"
TARGET_HEX=$(grep -oP '^CONNECTION_NODE_HEX=\K.*' "$STATUS_FILE" 2>/dev/null | tr -d '[:space:]')
[[ ${#TARGET_HEX} -ne 64 ]] && TARGET_HEX="$NODE_HEX_SELF"

PAYLOAD=$(jq -n --arg email "$EMAIL" --arg owner_hex "$OWNER_HEX" \
    --arg path "$RELPATH" --arg ipfs_link "$IPFS_LINK" --arg reply_node_hex "$NODE_HEX_SELF" \
    --arg decryption_key "$DECRYPTION_KEY" \
    '{email:$email, owner_hex:$owner_hex, path:$path, ipfs_link:$ipfs_link, reply_node_hex:$reply_node_hex}
     + (if ($decryption_key|length) == 64 then {decryption_key:$decryption_key} else {} end)' \
    2>/dev/null)
[[ -z "$PAYLOAD" ]] && exit 0

## TTL 1800s : un job de détection de visages qui n'a pas été traité en 30 min
## n'a plus d'intérêt (l'utilisateur est passé à autre chose) — inutile de le
## laisser traîner sur le relay.
printf '%s\n' "$NSEC" | python3 "$INTERCOM" send \
    --nsec-stdin \
    --to      "$TARGET_HEX" \
    --channel "vision_analysis_job" \
    --payload "$PAYLOAD" \
    --ttl     1800 \
    --relays  "wss://relay.copylaradio.com" \
    >> "$HOME/.zen/tmp/bro_vision_trigger.log" 2>&1

exit 0
