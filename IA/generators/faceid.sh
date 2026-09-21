#!/bin/bash
###################################################################
# faceid.sh
# Détecte les visages sur une image via le workflow ComfyUI
# "Face Detect Embeddings JSON" (InsightFace) et retourne le JSON brut
# sur stdout.
#
# Usage: $0 <image_locale_ou_lien_ipfs> [fichier_json_de_sortie] [decryption_key_hex]
#
# Entrée:
#   - image_locale_ou_lien_ipfs : chemin d'un fichier local existant, OU
#     un CID/lien IPFS (ex: "QmHash.../photo.jpg", avec ou sans "/ipfs/"
#     en préfixe) — téléchargé automatiquement via `ipfs get`.
#   - fichier_json_de_sortie (optionnel) : si fourni, le JSON y est aussi
#     écrit en plus de stdout. Chaîne vide ("") pour le laisser vide tout en
#     fournissant decryption_key_hex.
#   - decryption_key_hex (optionnel, 64 hex chars) : si fourni, l'image
#     téléchargée est traitée comme un blob UENC chiffré (AES-256-GCM) et
#     déchiffrée EN MÉMOIRE (fichier temporaire local, jamais republié) avant
#     analyse — c'est le cas normal pour toute image venant du cloud chiffré
#     (/dav/), qui est la SEULE source de déclenchement FaceID (cf.
#     UPassport/CLAUDE.md : jamais depuis le uDRIVE public). Ignoré pour un
#     fichier local déjà en clair.
#
# Sortie (stdout, si succès) — forme produite par le node
# FaceDetectEmbeddingsToJSON (custom_nodes/comfyui-face-embeddings-json/
# sur le Brain GPU), enrichie d'un champ scene_analysis quand AUCUN visage
# n'est détecté (chaînage vers IA/inventory_recognition.py — classification
# Ollama Vision plante/insecte/animal/objet/lieu, PlantNet pour les plantes) :
#   {"faces":[{"bbox":{"x1":..,"y1":..,"x2":..,"y2":..},"det_score":0.99,
#              "embedding":[512 floats L2-normalisés]}, ...],
#    "scene_analysis": {"type":"object","category":..,"name":..,
#                        "description":..,"confidence":..,"tags":[..]}}
#   (scene_analysis absent si au moins un visage a été détecté)
#
# Process:
#   1. Résout l'image (fichier local ou téléchargement IPFS)
#   2. Verrou GPU exclusif (partagé avec le pipeline DM vision_analysis_job —
#      un seul job ComfyUI à la fois sur ce Brain)
#   3. Vérifie/connecte ComfyUI (local → tunnel SSH → swarm P2P via comfyui.me.sh)
#   4. Upload de l'image dans le dossier input ComfyUI (LoadImage ne lit que là)
#   5. Conversion du workflow UI → API (comfyui_ui2api.py) avec injection
#      du nom de fichier uploadé
#   6. Soumission à /prompt, attente via websocket (comfyui_wait.py)
#   7. Extraction de la sortie du node SaveText depuis /history
#
# Exit codes: 0 = succès (JSON valide sur stdout) ; 1 = échec (message
# détaillé sur stderr, préfixé "ERROR:faceid:").
#
# Réutilisé tel quel par Astroport.ONE/IA/bro/bro_dm_daemon.sh
# (_handle_vision_analysis_job, canal DM vision_analysis_job/result du
# pipeline FaceID Brain/Satellite) — ce script est la SEULE implémentation
# de la soumission ComfyUI FaceID ; ne pas dupliquer cette logique ailleurs.
###################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "${MY_PATH}" && pwd)"
ME="${0##*/}"

if [ -z "$1" ]; then
    echo "Usage: $0 <image_locale_ou_lien_ipfs> [fichier_json_de_sortie]" >&2
    echo "Exemple: $0 /home/user/photo.jpg" >&2
    echo "Exemple: $0 QmHash.../photo.jpg faces.json" >&2
    exit 1
fi

IMG_ARG="$1"
OUT_JSON="$2"
DECRYPTION_KEY="$3"

. "${HOME}/.zen/Astroport.ONE/tools/my.sh"

# Active le venv Python (custom nodes/scripts de conversion en dépendent)
VENV_DIR="${HOME}/.astro"
if [ -d "$VENV_DIR" ]; then
    source "$VENV_DIR/bin/activate"
fi

_COMFYUI_URL="http://127.0.0.1:8188"
_WORKFLOW="$MY_PATH/workflow/Face Detect Embeddings JSON.json"
_UI2API="$MY_PATH/../comfyui_ui2api.py"
_UENC_CODEC="$MY_PATH/../../tools/uenc_codec.py"
_GPU_LOCK="$HOME/.zen/tmp/comfyui_brain.lock"

_tmp_dir=$(mktemp -d /tmp/faceid_XXXXXX)
_cleanup() { rm -rf "$_tmp_dir"; }
trap _cleanup EXIT

## 1. Résoudre l'image : fichier local existant, sinon lien/CID IPFS
if [ -f "$IMG_ARG" ]; then
    _img="$IMG_ARG"
    _basename=$(basename "$IMG_ARG")
else
    _basename=$(basename "$IMG_ARG")
    _fetched="$_tmp_dir/$_basename"
    _cid="${IMG_ARG#/ipfs/}"
    # `ipfs get` imprime "Saving file(s) to ..." sur STDOUT (pas stderr) — sans
    # ce >/dev/null, cette ligne contaminait le JSON final que ce script
    # renvoie sur stdout : json.loads() côté appelant échouait silencieusement
    # dessus (except -> {}), donc `faces` arrivait vide malgré une détection
    # réussie. Invisible en lecture manuelle du terminal, fatal dès que la
    # sortie est parsée par du code — bug constaté en prod, 2026-09-20.
    if ! timeout 120 ipfs get "/ipfs/${_cid}" -o "$_fetched" >/dev/null 2>&1; then
        echo "ERROR:faceid:ipfs_get_failed:${IMG_ARG}" >&2
        exit 1
    fi

    if [ -n "$DECRYPTION_KEY" ]; then
        ## Blob UENC chiffré (AES-256-GCM) — déchiffrement local uniquement,
        ## jamais republié ni conservé au-delà de ce process (trap EXIT).
        ## Préfixe "decrypted_" OBLIGATOIRE : avec un CID nu (cas normal, pas
        ## de nom de fichier réel), "${_basename%.uenc}" ne retire rien — sans
        ## préfixe, _img retombait exactement sur _fetched. `>` tronque son
        ## fichier de sortie AVANT que `<` ne lise quoi que ce soit : lire et
        ## écrire le même fichier donnait donc un payload vide en entrée
        ## ("Payload UENC trop court"), systématique avec un CID nu — bug
        ## constaté en prod le 2026-09-20, jamais visible en test manuel avec
        ## un vrai nom de fichier local.
        _basename="decrypted_${_basename%.uenc}"
        _img="$_tmp_dir/$_basename"
        if ! python3 "$_UENC_CODEC" decrypt "$DECRYPTION_KEY" \
            < "$_fetched" > "$_img" 2>/tmp/faceid_decrypt_err.$$; then
            echo "ERROR:faceid:decrypt_failed:$(cat /tmp/faceid_decrypt_err.$$ 2>/dev/null)" >&2
            rm -f "/tmp/faceid_decrypt_err.$$"
            exit 1
        fi
        rm -f "/tmp/faceid_decrypt_err.$$" "$_fetched"
    else
        _img="$_fetched"
    fi
fi

## 2. Verrou GPU exclusif — un seul job ComfyUI FaceID à la fois sur ce Brain.
##    Ce script est désormais le SEUL point d'acquisition de ce verrou : le
##    daemon (_handle_vision_analysis_job) ne le prend plus lui-même, pour
##    éviter un deadlock (parent tenant le verrou en attendant ce script fils).
exec 9>"$_GPU_LOCK"
if ! flock -x -w 300 9; then
    echo "ERROR:faceid:gpu_lock_timeout" >&2
    exit 1
fi

## 3. ComfyUI accessible (local → tunnel SSH → swarm P2P)
if ! bash "$MY_PATH/../services/comfyui.me.sh" >&2; then
    echo "ERROR:faceid:comfyui_unreachable" >&2
    exit 1
fi

## 4. Téléverser l'image dans le dossier input de ComfyUI (LoadImage ne lit que là)
_upload_resp=$(curl -s -X POST -F "image=@${_img};filename=${_basename}" \
    "$_COMFYUI_URL/upload/image" 2>/dev/null)
_uploaded=$(jq -r '.name // empty' <<< "$_upload_resp" 2>/dev/null)
[ -z "$_uploaded" ] && _uploaded="$_basename"

## 5. Convertir le workflow UI → API et y injecter le nom de l'image
_api_workflow=$(python3 "$_UI2API" "$_WORKFLOW" --url "$_COMFYUI_URL" \
    --set "1.image=${_uploaded}")
if [ -z "$_api_workflow" ]; then
    echo "ERROR:faceid:workflow_conversion_failed (custom nodes InsightFace absents de ce ComfyUI ?)" >&2
    exit 1
fi

## 6. Soumettre à /prompt avec un client_id pour l'attente WebSocket ciblée
_client_id=$(python3 -c "import uuid; print(str(uuid.uuid4()))")
_submit_resp=$(jq -n --argjson wf "$_api_workflow" --arg cid "$_client_id" \
    '{prompt:$wf, client_id:$cid}' 2>/dev/null | \
    curl -s -X POST -H "Content-Type: application/json" --data-binary @- \
         "$_COMFYUI_URL/prompt" 2>/dev/null)
_prompt_id=$(jq -r '.prompt_id // empty' <<< "$_submit_resp" 2>/dev/null)
if [ -z "$_prompt_id" ]; then
    # La réponse d'erreur ComfyUI nomme précisément l'entrée fautive — la
    # journaliser entièrement est ce qui rend ce chemin débogable.
    echo "ERROR:faceid:prompt_rejected:${_submit_resp:0:400}" >&2
    exit 1
fi

## 7. Attendre la fin via WebSocket (comfyui_wait.py, réutilisé tel quel).
##    Sa sortie (une ligne: done / error:<msg> / timeout / no_websocket) est
##    le SEUL endroit où une exception ComfyUI (poids manquants, node en
##    échec...) est visible — la jeter silencieusement transformait toute
##    erreur réelle en un "/history vide" incompréhensible en aval.
_wait_result=$(python3 "$MY_PATH/../comfyui_wait.py" "$_client_id" "$_prompt_id" \
    --url "ws://127.0.0.1:8188/ws" --timeout 180 2>&1)
if [ "$_wait_result" != "done" ]; then
    echo "WARN:faceid:comfyui_wait:${_wait_result} — tentative de lecture de /history quand même" >&2
fi

## 8. Récupérer la sortie texte du node SaveText depuis /history
##    Le nom exact de la clé sous laquelle SaveText expose son texte dans
##    .outputs.<node_id> dépend de la version du node (souvent "text", parfois
##    "string", scalaire ou tableau [0]) — on essaie toutes les formes
##    plausibles, et on journalise le JSON brut si aucune ne matche.
_history=$(curl -s "$_COMFYUI_URL/history/${_prompt_id}" 2>/dev/null)
_faces_json=$(jq -r --arg id "$_prompt_id" '
    .[$id].outputs // {} | to_entries[] | .value
    | (.text? // .string? // empty)
    | if type == "array" then .[0] else . end
' <<< "$_history" 2>/dev/null | head -1)

if [ -z "$_faces_json" ] || [ "$_faces_json" = "null" ]; then
    # .outputs vide ne dit rien sur LA cause — .status (messages d'exécution,
    # y compris une éventuelle exception Python du node) est ce qui l'explique
    # réellement. On journalise les deux, plus le résultat de l'attente ci-dessus.
    _entry=$(jq -c --arg id "$_prompt_id" '.[$id] // "absent de /history"' <<< "$_history" 2>/dev/null | head -c 800)
    echo "ERROR:faceid:no_saveText_output — comfyui_wait=${_wait_result} — /history[${_prompt_id}]=${_entry}" >&2
    exit 1
fi

## 8.5. Zéro visage détecté → enchaîner sur la reconnaissance objet/lieu
##      (IA/inventory_recognition.py, déjà en place : classification Ollama
##      Vision multi-type plante/insecte/animal/objet/lieu, délégation
##      PlantNet pour les plantes) — sur le MÊME fichier déjà déchiffré en
##      local ($_img), jamais ré-uploadé nulle part. Le verrou GPU (fd 9) est
##      toujours tenu à ce stade : Ollama et ComfyUI ne se disputent donc
##      jamais le GPU en même temps.
##      Pas de GPS réel disponible ici (le Brain ne voit jamais de métadonnées
##      de localisation) — 0.0/0.0 en placeholder, la vraie géoloc EXIF est
##      extraite côté Satellite au moment du PUT (cloud_storage.py), pas ici.
_scene_json=""
_face_count=$(jq '[.. | .faces? // empty | .[]?] | length' <<< "$_faces_json" 2>/dev/null)
if [ "${_face_count:-0}" -eq 0 ] 2>/dev/null; then
    _INVENTORY="$MY_PATH/../inventory_recognition.py"
    if [ -s "$_INVENTORY" ]; then
        _scene_raw=$(python3 "$_INVENTORY" "$_img" 0.0 0.0 --json 2>>"$HOME/.zen/tmp/faceid_scene.log")
        _scene_json=$(jq -c '{
            type:        (.classification.type // "object"),
            category:    (.identification.category // .classification.category // null),
            name:        (.identification.name // null),
            description: (.identification.description // .classification.description // null),
            confidence:  (.classification.confidence // null),
            tags:        (.tags // [])
        }' <<< "$_scene_raw" 2>/dev/null)
        if [ -n "$_scene_json" ] && [ "$_scene_json" != "null" ]; then
            _log_scene_type=$(jq -r '.type' <<< "$_scene_json" 2>/dev/null)
            echo "INFO:faceid:scene_analysis:${_log_scene_type:-?}" >&2
        else
            _scene_json=""
        fi
    fi
fi

## 9. Sortie — fusionne faces + scene_analysis (si présent) dans un seul JSON
if [ -n "$_scene_json" ]; then
    _final_json=$(jq -c --argjson scene "$_scene_json" '. + {scene_analysis: $scene}' <<< "$_faces_json" 2>/dev/null)
    [ -z "$_final_json" ] && _final_json="$_faces_json"
else
    _final_json="$_faces_json"
fi
echo "$_final_json"
if [ -n "$OUT_JSON" ]; then
    echo "$_final_json" > "$OUT_JSON"
fi
exit 0
