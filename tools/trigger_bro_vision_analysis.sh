#!/bin/bash
########################################################################
# trigger_bro_vision_analysis.sh — Déclencheur FaceID côté Satellite
#
# Appelé en arrière-plan par tools/generate_ipfs_structure.sh dès qu'une
# image est ajoutée au uDRIVE d'un MULTIPASS. Envoie un job
# `vision_analysis_job` (canal inter-NODE NIP-44, cf. nostr_node_intercom.py)
# au Brain GPU actuellement connecté — ou à soi-même si cette station EST le
# Brain (pas de GPU distant configuré).
#
# Le Brain répond sur le canal `vision_analysis_result` vers `reply_node_hex`,
# où IA/bro/bro_dm_daemon.sh::_handle_vision_analysis_result() prend le relais.
#
# Usage: trigger_bro_vision_analysis.sh <SOURCE_DIR> <relative_path> <ipfs_link>
#   SOURCE_DIR    ~/.zen/game/nostr/{EMAIL}/APP/uDRIVE
#   relative_path Images/photo.jpg  (chemin dans le uDRIVE)
#   ipfs_link     Qm…/photo.jpg     (CID du répertoire wrapper + nom de fichier)
#
# Best effort intégral : TOUT échec sort en 0 silencieusement. Ce script est
# dans le chemin chaud de l'indexation uDRIVE — il ne doit jamais la faire
# échouer ni la ralentir.
########################################################################

SOURCE_DIR="$1"
RELPATH="$2"
IPFS_LINK="$3"

[[ -z "$SOURCE_DIR" || -z "$RELPATH" || -z "$IPFS_LINK" ]] && exit 0

INTERCOM="$HOME/.zen/Astroport.ONE/tools/nostr_node_intercom.py"
[[ -s "$INTERCOM" ]] || exit 0

## EMAIL dérivé de SOURCE_DIR = …/game/nostr/{EMAIL}/APP/uDRIVE
EMAIL=$(basename "$(dirname "$(dirname "$SOURCE_DIR")")")
[[ -z "$EMAIL" || ! -d "$HOME/.zen/game/nostr/$EMAIL" ]] && exit 0

## HEX du MULTIPASS propriétaire : c'est lui qui nomme la collection Qdrant
## faces_{owner_hex} côté satellite_face_matcher.py — jamais le NODE_HEX,
## le catalogue de visages appartient à l'utilisateur, pas à la station.
OWNER_HEX=$(tr -d '[:space:]' < "$HOME/.zen/game/nostr/$EMAIL/HEX" 2>/dev/null)
[[ ${#OWNER_HEX} -ne 64 ]] && exit 0

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
    '{email:$email, owner_hex:$owner_hex, path:$path, ipfs_link:$ipfs_link, reply_node_hex:$reply_node_hex}' \
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
