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
#   6. Soumission à /prompt, attente par interrogation de /history (0,3 s)
#   7. Extraction de la sortie du node SaveText depuis /history
#
# Exit codes: 0 = succès (JSON valide sur stdout) ; 1 = échec (message
# détaillé sur stderr, préfixé "ERROR:faceid:").
#
# Mode --batch (depuis 2026-10-12, rattrapage rapide UPassport/faceid_reprocess.py
# --quick) : lit des chemins d'images LOCALES déjà en clair sur stdin, une par
# ligne, et écrit pour chacune UNE ligne JSON sur stdout, dans l'ordre :
#   {"file": "<chemin>", "ok": true, "faces": [...]}    ou
#   {"file": "<chemin>", "ok": false, "error": "<raison>"}
# my.sh, comfyui.me.sh (local → tunnel SSH → P2P IPFS) et la conversion du
# workflow ne sont faits qu'UNE fois pour tout le lot (mesuré : ~7 s sur ~8 s
# par appel unitaire, l'inférence elle-même ~0,6 s). Le verrou GPU est pris et
# relâché PAR IMAGE, pour ne jamais bloquer les envois en direct (DM
# vision_analysis_job) pendant un long rattrapage. Si ComfyUI est injoignable
# au démarrage : une ligne {"fatal": "comfyui_unreachable"} et exit 1.
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
    echo "Usage: $0 <image_locale_ou_lien_ipfs> [fichier_json_de_sortie] [decryption_key_hex]" >&2
    echo "       $0 --batch   (chemins d'images LOCALES en clair sur stdin, une ligne JSON par image sur stdout)" >&2
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
. "$MY_PATH/lib/gpu_room.sh"

_tmp_dir=$(mktemp -d /tmp/faceid_XXXXXX)
_cleanup() { rm -rf "$_tmp_dir"; }
trap _cleanup EXIT

_BATCH=""
[ "$IMG_ARG" = "--batch" ] && _BATCH=1

## 1. Résoudre l'image : fichier local existant, sinon lien/CID IPFS
##    (mode unitaire seulement — en --batch, l'appelant fournit des fichiers
##    locaux déjà déchiffrés)
if [ -n "$_BATCH" ]; then
    :
elif [ -f "$IMG_ARG" ]; then
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
        ## --key-stdin : la clé ne transite jamais en argv (invisible dans /proc/<pid>/cmdline)
        if ! { printf '%s\n' "$DECRYPTION_KEY"; cat "$_fetched"; } | \
            python3 "$_UENC_CODEC" decrypt --key-stdin \
            > "$_img" 2>/tmp/faceid_decrypt_err.$$; then
            echo "ERROR:faceid:decrypt_failed:$(cat /tmp/faceid_decrypt_err.$$ 2>/dev/null)" >&2
            rm -f "/tmp/faceid_decrypt_err.$$"
            exit 1
        fi
        rm -f "/tmp/faceid_decrypt_err.$$" "$_fetched"
    else
        _img="$_fetched"
    fi
fi

## Étapes 1.5 → 8.5 pour UNE image locale : `_detect_local <image> <nom>`
## écrit le JSON aplati {"faces":[…]} dans "$_tmp_dir/result.json" ; retour
## ≠ 0 + message "ERROR:faceid:…" sur stderr en cas d'échec. À appeler dans
## le shell COURANT (jamais dans un $( … )) : les caches ci-dessous doivent
## survivre d'une image à l'autre en --batch. Partagée par le mode unitaire
## et le mode --batch (même code, jamais deux implémentations).
_API_WORKFLOW_TEMPLATE=""    # conversion UI → API faite une fois, image injectée ensuite
_COMFY_READY=""              # comfyui.me.sh déjà vérifié (mode --batch)

_detect_local() {
    local _img="$1" _basename="$2"

    ## 1.5. Redimensionner pour la détection si l'image dépasse une taille
    ##      raisonnable — réduit la charge mémoire/GPU par job (cause
    ##      plausible de la charge excessive constatée lors d'un import WebDAV
    ##      de masse, 2026-10-03). bbox est reprojeté sur l'image ORIGINALE
    ##      (facteur _scale, étape 8.5) avant la sortie — jamais celui de la
    ##      copie réduite envoyée à ComfyUI, sous peine de recadrages décalés
    ##      en aval (mailjet.py::_crop_face_jpeg). L'orientation EXIF est
    ##      normalisée AVANT stockage (cloud_storage.py::ingest_plaintext) : un
    ##      simple facteur d'échelle suffit ici.
    local _MAX_DETECT_DIM=1600 _resize_info _detect_img _detect_basename _scale
    _resize_info=$(python3 - "$_img" "$_tmp_dir" "$_MAX_DETECT_DIM" <<'PYRESIZE' 2>"$_tmp_dir/resize_err"
import sys
from PIL import Image
path, tmp_dir, max_dim = sys.argv[1], sys.argv[2], int(sys.argv[3])
img = Image.open(path)
w, h = img.size
longest = max(w, h)
if longest <= max_dim:
    print(f"{path}\t1.0")
else:
    scale = longest / max_dim
    new_w, new_h = max(1, round(w / scale)), max(1, round(h / scale))
    out = f"{tmp_dir}/detect_resized.jpg"
    img.convert("RGB").resize((new_w, new_h), Image.LANCZOS).save(out, "JPEG", quality=90)
    print(f"{out}\t{scale}")
PYRESIZE
)
    if [ -z "$_resize_info" ]; then
        # Format exotique / image corrompue : on retombe sur l'image d'origine
        echo "WARN:faceid:resize_failed:$(tail -c 300 "$_tmp_dir/resize_err" 2>/dev/null) — envoi en taille native" >&2
        _detect_img="$_img"; _detect_basename="$_basename"; _scale="1.0"
    else
        _detect_img="${_resize_info%%$'\t'*}"
        _scale="${_resize_info##*$'\t'}"
        _detect_basename="$(basename "$_detect_img")"
    fi

    ## 2. Verrou GPU exclusif — un seul job ComfyUI FaceID à la fois sur ce
    ##    Brain. Ce script est le SEUL point d'acquisition de ce verrou (le
    ##    daemon ne le prend pas lui-même : deadlock parent/fils sinon).
    ##    Relâché en fin d'image, y compris en mode --batch.
    exec 9>"$_GPU_LOCK"
    if ! flock -x -w 300 9; then
        echo "ERROR:faceid:gpu_lock_timeout" >&2
        return 1
    fi

    ## 3. ComfyUI accessible (local → tunnel SSH → swarm P2P) — une seule fois
    ##    par lot en --batch.
    if [ -z "$_COMFY_READY" ]; then
        if ! bash "$MY_PATH/../services/comfyui.me.sh" >&2; then
            flock -u 9
            echo "ERROR:faceid:comfyui_unreachable" >&2
            return 2
        fi
        [ -n "$_BATCH" ] && _COMFY_READY=1
    fi

    ## 4. Téléverser l'image (éventuellement réduite) dans input/ de ComfyUI
    local _upload_resp _uploaded
    _upload_resp=$(curl -s -X POST -F "image=@${_detect_img};filename=${_detect_basename}" \
        "$_COMFYUI_URL/upload/image" 2>/dev/null)
    _uploaded=$(jq -r '.name // empty' <<< "$_upload_resp" 2>/dev/null)
    [ -z "$_uploaded" ] && _uploaded="$_detect_basename"

    ## 5. Workflow UI → API (converti une fois), nom de l'image injecté
    if [ -z "$_API_WORKFLOW_TEMPLATE" ]; then
        _API_WORKFLOW_TEMPLATE=$(python3 "$_UI2API" "$_WORKFLOW" --url "$_COMFYUI_URL" \
            --set "1.image=placeholder.png")
        if [ -z "$_API_WORKFLOW_TEMPLATE" ]; then
            flock -u 9
            echo "ERROR:faceid:workflow_conversion_failed (custom nodes InsightFace absents de ce ComfyUI ?)" >&2
            return 1
        fi
    fi
    local _api_workflow
    _api_workflow=$(jq -c --arg img "$_uploaded" '.["1"].inputs.image = $img' <<< "$_API_WORKFLOW_TEMPLATE")

    ## 5.5 La 3090 est partagée avec Ollama : lui faire libérer la place (revérifié au plus toutes les 30 s en --batch)
    GPU_ROOM_TTL=30 gpu_make_room 3 faceid || { flock -u 9; return 1; }

    ## 6. Soumettre à /prompt avec un client_id pour l'attente WebSocket ciblée
    local _client_id _submit_resp _prompt_id
    _client_id=$(python3 -c "import uuid; print(str(uuid.uuid4()))")
    _submit_resp=$(jq -n --argjson wf "$_api_workflow" --arg cid "$_client_id" \
        '{prompt:$wf, client_id:$cid}' 2>/dev/null | \
        curl -s -X POST -H "Content-Type: application/json" --data-binary @- \
             "$_COMFYUI_URL/prompt" 2>/dev/null)
    _prompt_id=$(jq -r '.prompt_id // empty' <<< "$_submit_resp" 2>/dev/null)
    if [ -z "$_prompt_id" ]; then
        # La réponse d'erreur ComfyUI nomme précisément l'entrée fautive.
        flock -u 9
        _COMFY_READY=""          # tunnel tombé ? revérifié à l'image suivante
        echo "ERROR:faceid:prompt_rejected:${_submit_resp:0:400}" >&2
        return 1
    fi

    ## 7. Attendre la fin en interrogeant /history (0,3 s). PAS de WebSocket
    ##    (comfyui_wait.py) ici : l'inférence ne dure que ~0,6 s, et le job
    ##    finissait souvent AVANT que le WebSocket soit connecté — l'événement
    ##    « terminé » était alors manqué et chaque photo perdait 180 s
    ##    (constaté au rattrapage --batch du 2026-10-12). /history porte aussi
    ##    l'erreur d'exécution éventuelle (status.status_str == "error").
    local _wait_result="timeout" _deadline=$((SECONDS + 180)) _history=""
    while [ "$SECONDS" -lt "$_deadline" ]; do
        _history=$(curl -s "$_COMFYUI_URL/history/${_prompt_id}" 2>/dev/null)
        case "$(jq -r --arg id "$_prompt_id" '.[$id].status.status_str // empty' <<< "$_history" 2>/dev/null)" in
            success) _wait_result="done"; break ;;
            error)   _wait_result="error:$(jq -c --arg id "$_prompt_id" '.[$id].status.messages' <<< "$_history" 2>/dev/null | head -c 400)"; break ;;
        esac
        sleep 0.3
    done
    if [ "$_wait_result" != "done" ]; then
        echo "WARN:faceid:comfyui_wait:${_wait_result} — tentative de lecture de /history quand même" >&2
    fi
    gpu_comfy_record_inline faceid "$_prompt_id" "$_history"     # mesure du job (lots : sans processus Python par photo)

    ## 8. Sortie texte du node SaveText depuis /history (clé "text" ou
    ##    "string", scalaire ou tableau [0] selon la version du node).
    local _faces_json _entry
    flock -u 9                   # le GPU est libre dès que le résultat est là
    _faces_json=$(jq -r --arg id "$_prompt_id" '
        [ .[$id].outputs // {} | to_entries[] | .value
          | (.text? // .string? // empty)
          | if type == "array" then .[0] else . end
          | select(. != null and . != "")
        ] | first // empty
    ' <<< "$_history" 2>/dev/null)
    if [ -z "$_faces_json" ] || [ "$_faces_json" = "null" ]; then
        _entry=$(jq -c --arg id "$_prompt_id" '.[$id] // "absent de /history"' <<< "$_history" 2>/dev/null | head -c 800)
        echo "ERROR:faceid:no_saveText_output — comfyui_wait=${_wait_result} — /history[${_prompt_id}]=${_entry}" >&2
        return 1
    fi

    ## 8.5. Aplatir puis reprojeter bbox sur l'image ORIGINALE.
    ##    La sortie SaveText est IMBRIQUÉE ({"images":[{"faces":[…]}]}) : les
    ##    deux formes sont fusionnées en un seul `faces` racine et `images`
    ##    est supprimé — TOUJOURS, réduction ou non. Avant 2026-10-12, ce jq
    ##    ne lisait que `.faces` racine (absent) → créait `faces: []` À CÔTÉ de
    ##    `images` intact, que bro_dm_daemon.sh::_vision_result_payload lisait
    ##    en priorité : TOUTE photo > _MAX_DETECT_DIM (= toute photo
    ##    smartphone) finissait marquée `no_face` malgré une détection réussie
    ##    (bug constaté sur un import WebDAV : 1877/2006 photos perdues).
    local _flat
    _flat=$(jq -c --argjson scale "$_scale" '
        .faces = [ ((.faces // []) + [ (.images // [])[] | (.faces? // [])[] ]) | .[] | . as $f |
            if $f.bbox and $scale != 1 then
                $f + {bbox: {x1: ($f.bbox.x1*$scale), y1: ($f.bbox.y1*$scale),
                             x2: ($f.bbox.x2*$scale), y2: ($f.bbox.y2*$scale)}}
            else $f end ] | del(.images)
    ' <<< "$_faces_json" 2>/dev/null)
    if [ -n "$_flat" ] && [ "$_flat" != "null" ]; then
        _faces_json="$_flat"
    else
        echo "WARN:faceid:flatten_failed — sortie brute renvoyée (scale=${_scale})" >&2
    fi
    rm -f "$_tmp_dir/detect_resized.jpg"
    printf '%s\n' "$_faces_json" > "$_tmp_dir/result.json"
}

## ── Mode --batch : un lot d'images locales, une ligne JSON par image ──────
if [ -n "$_BATCH" ]; then
    if ! bash "$MY_PATH/../services/comfyui.me.sh" >&2; then
        echo '{"fatal": "comfyui_unreachable"}'
        exit 1
    fi
    _COMFY_READY=1
    while IFS= read -r _file; do
        [ -z "$_file" ] && continue
        if [ ! -f "$_file" ]; then
            jq -cn --arg f "$_file" '{file:$f, ok:false, error:"file_not_found"}'
            continue
        fi
        if _detect_local "$_file" "$(basename "$_file")" 2>"$_tmp_dir/err"; then
            jq -c --arg f "$_file" '{file:$f, ok:true, faces:(.faces // [])}' "$_tmp_dir/result.json" \
                || jq -cn --arg f "$_file" '{file:$f, ok:false, error:"bad_json"}'
        else
            _err=$(grep -o 'ERROR:faceid:[^ ]*' "$_tmp_dir/err" | head -1)
            jq -cn --arg f "$_file" --arg e "${_err:-unknown}" '{file:$f, ok:false, error:$e}'
        fi
        cat "$_tmp_dir/err" >&2
    done
    exit 0
fi

## ── Mode unitaire ─────────────────────────────────────────────────────────
## 9. Sortie — zéro visage détecté n'enchaîne plus sur une analyse de scène
##    (retirée le 2026-10-02) : la photo est simplement marquée `no_face`
##    côté Satellite (satellite_face_matcher.py::_tag_ucloud_no_face).
if ! _detect_local "$_img" "$_basename"; then
    exit 1
fi
_final_json=$(cat "$_tmp_dir/result.json")
echo "$_final_json"
if [ -n "$OUT_JSON" ]; then
    echo "$_final_json" > "$OUT_JSON"
fi
exit 0
