#!/bin/bash
# Dependencies : jq curl
#### apply_lipsync.sh : Synchronisation labiale via ComfyUI (LivePortrait)
# Usage: $0 <video_path_ou_url> <audio_path_ou_url> [udrive_path]

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"
source "${MY_PATH}/../tools/my.sh"

VIDEO_INPUT="$1"
AUDIO_INPUT="$2"
UDRIVE_PATH="$3"

# Configuration ComfyUI
COMFYUI_URL="http://127.0.0.1:8188"
WORKFLOW_JSON="${MY_PATH}/workflow/lipsync_liveportrait.json"

if [ ! -f "$WORKFLOW_JSON" ]; then
    echo "Erreur : Fichier workflow lipsync_liveportrait.json non trouvé dans $MY_PATH/workflow/" >&2
    exit 1
fi

# Création du dossier temporaire
UNIQUE_ID=$(date +%s)_$RANDOM
TMP_DIR="$HOME/.zen/tmp.media/lipsync_${UNIQUE_ID}"
mkdir -p "$TMP_DIR"

# 1. Préparation des fichiers (Téléchargement si nécessaire)
prepare_file() {
    local input="$1"
    local prefix="$2"
    local target=""
    
    if [[ "$input" =~ ^https?:// ]]; then
        local ext="${input##*.}"
        # Nettoyage extension si paramètres dans l'URL
        ext=$(echo $ext | cut -d'?' -f1)
        target="${TMP_DIR}/${prefix}.${ext}"
        curl -sL "$input" -o "$target"
    else
        target="$input"
    fi
    echo "$target"
}

echo "Préparation des médias..." >&2
LOCAL_VIDEO=$(prepare_file "$VIDEO_INPUT" "input_video")
LOCAL_AUDIO=$(prepare_file "$AUDIO_INPUT" "input_audio")

# 2. Upload vers l'input de ComfyUI
upload_to_comfy() {
    local file_path="$1"
    local filename=$(basename "$file_path")
    local resp=$(curl -s -X POST -F "image=@${file_path}" "$COMFYUI_URL/upload/image")
    echo "$resp" | jq -r '.name'
}

echo "Upload vers ComfyUI..." >&2
COMFY_VIDEO_NAME=$(upload_to_comfy "$LOCAL_VIDEO")
COMFY_AUDIO_NAME=$(upload_to_comfy "$LOCAL_AUDIO")

# 3. Injection dans le JSON
# On cherche les nodes par class_type pour plus de flexibilité
TMP_WORKFLOW="${TMP_DIR}/exec_workflow.json"

jq --arg vid "$COMFY_VIDEO_NAME" \
   --arg aud "$COMFY_AUDIO_NAME" \
   '(.[] | select(.class_type == "VHS_LoadVideo") | .inputs.video) = $vid |
    (.[] | select(.class_type == "VHS_LoadAudio") | .inputs.audio) = $aud' \
   "$WORKFLOW_JSON" > "$TMP_WORKFLOW"

# 4. Exécution
echo "Lancement de la synchronisation labiale..." >&2
PROMPT_ID=$(curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"prompt\": $(cat "$TMP_WORKFLOW")}" "$COMFYUI_URL/prompt" | jq -r '.prompt_id')

if [ "$PROMPT_ID" == "null" ]; then
    echo "Erreur API ComfyUI" >&2 ; exit 1
fi

# 5. Monitoring (Max 5 minutes)
attempts=0
while [ $attempts -lt 150 ]; do
    check=$(curl -s "$COMFYUI_URL/history")
    if echo "$check" | jq -e ".\"$PROMPT_ID\"" > /dev/null; then
        echo "Traitement terminé !" >&2
        break
    fi
    sleep 2
    ((attempts++))
done

# 6. Récupération du résultat (Node VHS_VideoCombine ou SaveVideo)
# On cherche dynamiquement dans les outputs du prompt_id
OUTPUT_FILENAME=$(echo "$check" | jq -r ".\"$PROMPT_ID\".outputs | to_entries[] | .value.gifs[0].filename // .value.video[0].filename // .value.images[0].filename")

if [ "$OUTPUT_FILENAME" == "null" ] || [ -z "$OUTPUT_FILENAME" ]; then
    echo "Erreur : Fichier de sortie introuvable dans l'historique." >&2
    exit 1
fi

# Téléchargement depuis ComfyUI
FINAL_VIDEO_FILE="${TMP_DIR}/final_movie.mp4"
curl -s -o "$FINAL_VIDEO_FILE" "$COMFYUI_URL/view?filename=$OUTPUT_FILENAME&type=output"

# 7. Stockage IPFS
echo "Publication sur IPFS..." >&2
IPFS_HASH=$(ipfs add -wq "$FINAL_VIDEO_FILE" | tail -n 1)
FINAL_URL="$myIPFS/ipfs/$IPFS_HASH/final_movie.mp4"

# 8. Nettoyage VRAM et Temp
curl -s -X POST "$COMFYUI_URL/free" -H "Content-Type: application/json" -d '{"unload_models": true, "free_memory": true}' > /dev/null
rm -rf "$TMP_DIR"

echo "$FINAL_URL"