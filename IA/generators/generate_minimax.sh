#!/bin/bash
# Dependencies : jq curl nc ipfs
#### generate_minimax.sh : transform a prompt into a video (with audio) using MiniMax H3 on ComfyUI
#
# Workflow : workflow/video_minimax_h3_t2v_api.json (format API du template
# ComfyUI « video_minimax_h3_t2v », subgraph aplati).
# Sur GPU 24 Go, le DiT (20 Go) reste en VRAM après l'échantillonnage et
# ComfyUI sous-estime la mémoire du VAE vidéo : le node VRAM_Debug (KJNodes)
# décharge tout avant le décodage. Requiert ComfyUI lancé SANS --highvram
# (en HIGH_VRAM le déchargement ne libère rien → OOM au VAEDecode) et sans le
# pack ComfyUI-MultiGPU (son patch de ModelPatcher casse le déchargement).
# Custom node requis : https://github.com/kijai/ComfyUI-KJNodes
# Modèles requis dans ComfyUI/models (https://huggingface.co/Comfy-Org/MiniMax-H3) :
#   diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors
#   text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors
#   vae/minimax_h3_video_vae_fp16.safetensors
#   vae/minimax_h3_audio_vae_fp32.safetensors

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

usage() {
  cat >&2 <<EOF
Usage: $ME [-i image] [-u facteur] [-d secondes] [-r ratio] [-m megapixels] [-s steps] [-t timeout] <prompt> [udrive_path]
  -i  image de départ (image-to-video) ; sans -i : text-to-video
  -u  upscale SeedVR2 3B (ex. 2 → 864x480 devient 1728x960) ; défaut : aucun
  -d  durée de la vidéo en secondes (défaut 5, plage entraînée ~5-15)
  -r  ratio : 1:1 2:3 3:2 3:4 4:3 9:16 16:9 21:9 (défaut 16:9)
  -m  mégapixels (défaut 0.4 → 864x480 en 16:9)
  -s  nombre de steps (défaut 20)
  -t  timeout en secondes (défaut 3600)
EOF
  exit 1
}

DURATION=5
RATIO="16:9"
MEGAPIXELS=0.4
STEPS=20
MAX_WAIT=3600
FIRST_FRAME=""
UPSCALE=""
while getopts "i:u:d:r:m:s:t:h" opt; do
  case $opt in
    u) UPSCALE="$OPTARG" ;;
    i) FIRST_FRAME="$OPTARG" ;;
    d) DURATION="$OPTARG" ;;
    r) RATIO="$OPTARG" ;;
    m) MEGAPIXELS="$OPTARG" ;;
    s) STEPS="$OPTARG" ;;
    t) MAX_WAIT="$OPTARG" ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

[ -z "$1" ] && usage
if [ -n "$FIRST_FRAME" ] && [ ! -f "$FIRST_FRAME" ]; then
  echo "Image introuvable : $FIRST_FRAME" >&2
  exit 1
fi

# Libellé exact attendu par le node ResolutionSelector
case "$RATIO" in
  1:1)  ASPECT="1:1 (Square)" ;;
  2:3)  ASPECT="2:3 (Portrait Photo)" ;;
  3:2)  ASPECT="3:2 (Photo)" ;;
  3:4)  ASPECT="3:4 (Portrait Standard)" ;;
  4:3)  ASPECT="4:3 (Standard)" ;;
  9:16) ASPECT="9:16 (Portrait Widescreen)" ;;
  16:9) ASPECT="16:9 (Widescreen)" ;;
  21:9) ASPECT="21:9 (Ultrawide)" ;;
  *) echo "Ratio inconnu : $RATIO" >&2; usage ;;
esac

. "${HOME}/.zen/Astroport.ONE/tools/my.sh"
. "${MY_PATH}/lib/comfyui_recovery.sh"

PROMPT="$1"
UDRIVE_PATH="$2"
WORKFLOW_PATH="${MY_PATH}/workflow/video_minimax_h3_t2v_api.json"

TMP_DIR="$HOME/.zen/tmp.media"
mkdir -p "$TMP_DIR"

if [ -n "$UDRIVE_PATH" ] && [ -d "$UDRIVE_PATH" ]; then
    OUTPUT_DIR="$UDRIVE_PATH"
    echo "Using uDRIVE directory: $OUTPUT_DIR" >&2
else
    OUTPUT_DIR="$TMP_DIR"
    echo "Using temporary directory: $OUTPUT_DIR" >&2
fi

UNIQUE_ID=$(date +%s)_$(openssl rand -hex 4)
TMP_WORKFLOW="$TMP_DIR/workflow_minimax_${UNIQUE_ID}.json"
TMP_VIDEO="$OUTPUT_DIR/minimax_${UNIQUE_ID}.mp4"

cleanup() {
    rm -f "$TMP_WORKFLOW"
    # Only remove TMP_VIDEO if it's in the temp directory, not in uDRIVE
    if [[ "$TMP_VIDEO" == "$TMP_DIR"* ]]; then
        rm -f "$TMP_VIDEO"
    fi
}
trap cleanup EXIT

COMFYUI_URL="http://127.0.0.1:8188"
COMFYUI_HOST=$(echo "$COMFYUI_URL" | sed 's#http://##' | cut -d':' -f1)
COMFYUI_PORT=$(echo "$COMFYUI_URL" | sed 's#http://##' | cut -d':' -f2)

check_comfyui_port() {
  echo "Vérification du port ComfyUI : ${COMFYUI_HOST}:${COMFYUI_PORT}" >&2
  if nc -z "$COMFYUI_HOST" "$COMFYUI_PORT" > /dev/null 2>&1; then
    echo "Le port ComfyUI est accessible." >&2
    return 0
  else
    echo "Erreur : Le port ComfyUI n'est pas accessible." >&2
    return 1
  fi
}

# Injecte prompt, seed, durée, résolution et steps dans le workflow
update_workflow() {
  echo "Chargement du workflow JSON : ${WORKFLOW_PATH}" >&2
  local seed=$((RANDOM * RANDOM * RANDOM))
  echo "Seed: $seed | durée: ${DURATION}s | ${ASPECT} @ ${MEGAPIXELS} MP | ${STEPS} steps" >&2

  jq --arg prompt "$PROMPT" --argjson seed "$seed" \
     --argjson duration "$DURATION" --arg aspect "$ASPECT" \
     --argjson mp "$MEGAPIXELS" --argjson steps "$STEPS" \
     '.["104"].inputs.prompt = $prompt
      | .["15"].inputs.noise_seed = $seed
      | .["111"].inputs.value = $duration
      | .["115"].inputs.aspect_ratio = $aspect
      | .["115"].inputs.megapixels = $mp
      | .["9"].inputs.steps = $steps' \
     "$WORKFLOW_PATH" > "$TMP_WORKFLOW" || { echo "Erreur : jq a échoué (paramètre non numérique ?)" >&2; exit 1; }

  [ -n "$FIRST_FRAME" ] && add_first_frame
  [ -n "$UPSCALE" ] && add_upscale
}

# Upscale SeedVR2 3B int8 (template ComfyUI utility_seedvr2_3b_int8_upscale_video) :
# les images décodées passent par SeedVR2 avant CreateVideo, l'audio reste intact.
# Modèles : https://huggingface.co/Comfy-Org/SeedVR2
#   diffusion_models/seedvr2_3b_int8_convrot.safetensors
#   vae/seedvr2_ema_vae_fp16.safetensors
add_upscale() {
  echo "Upscale SeedVR2 x${UPSCALE}" >&2
  jq --argjson factor "$UPSCALE" --argjson seed "$((RANDOM * RANDOM))" \
     '.["140"] = {"class_type": "UNETLoader", "inputs": {"unet_name": "seedvr2_3b_int8_convrot.safetensors", "weight_dtype": "default"}}
      | .["141"] = {"class_type": "VAELoader", "inputs": {"vae_name": "seedvr2_ema_vae_fp16.safetensors"}}
      | .["142"] = {"class_type": "ResizeImageMaskNode", "inputs": {"input": ["10", 0], "resize_type": "scale by multiplier", "resize_type.multiplier": $factor, "scale_method": "lanczos"}}
      | .["143"] = {"class_type": "SeedVR2Preprocess", "inputs": {"resized_images": ["142", 0]}}
      | .["144"] = {"class_type": "VAEEncodeTiled", "inputs": {"pixels": ["143", 0], "vae": ["141", 0], "tile_size": 512, "overlap": 128, "temporal_size": 64, "temporal_overlap": 8}}
      | .["145"] = {"class_type": "SeedVR2Conditioning", "inputs": {"model": ["140", 0], "vae_conditioning": ["144", 0]}}
      | .["146"] = {"class_type": "KSampler", "inputs": {"model": ["140", 0], "positive": ["145", 0], "negative": ["145", 1], "latent_image": ["144", 0], "seed": $seed, "steps": 1, "cfg": 1, "sampler_name": "euler", "scheduler": "simple", "denoise": 1}}
      | .["147"] = {"class_type": "VAEDecodeTiled", "inputs": {"samples": ["146", 0], "vae": ["141", 0], "tile_size": 512, "overlap": 128, "temporal_size": 64, "temporal_overlap": 8}}
      | .["148"] = {"class_type": "SeedVR2PostProcessing", "inputs": {"images": ["147", 0], "original_resized_images": ["142", 0], "color_correction_method": "lab"}}
      | .["91"].inputs.images = ["148", 0]' \
     "$TMP_WORKFLOW" > "$TMP_WORKFLOW.tmp" && mv "$TMP_WORKFLOW.tmp" "$TMP_WORKFLOW"
}

# Image-to-video : envoie l'image dans ComfyUI/input puis la branche sur first_frame
add_first_frame() {
  echo "Upload de l'image de départ : $FIRST_FRAME" >&2
  local image_name
  image_name=$(curl -s -F "image=@${FIRST_FRAME}" -F "overwrite=true" "$COMFYUI_URL/upload/image" | jq -r '.name // empty')
  if [ -z "$image_name" ]; then
    echo "Erreur : upload de l'image vers ComfyUI échoué" >&2
    exit 1
  fi
  jq --arg image "$image_name" \
     '.["130"] = {"class_type": "LoadImage", "_meta": {"title": "First frame"}, "inputs": {"image": $image}}
      | .["104"].inputs.first_frame = ["130", 0]' \
     "$TMP_WORKFLOW" > "$TMP_WORKFLOW.tmp" && mv "$TMP_WORKFLOW.tmp" "$TMP_WORKFLOW"
}

send_workflow() {
  echo "Envoi du workflow à l'API ComfyUI..." >&2
  local response_body_file="$TMP_DIR/response_body_${UNIQUE_ID}.json"
  local http_status
  http_status=$(jq '{prompt: .}' "$TMP_WORKFLOW" | curl -s -w "%{http_code}" -o "$response_body_file" \
                -X POST -H "Content-Type: application/json" \
                --data-binary @- "$COMFYUI_URL/prompt")
  local response_body
  response_body=$(cat "$response_body_file")
  rm -f "$response_body_file"

  echo "HTTP code: $http_status" >&2
  if [ "$http_status" -ne 200 ]; then
    echo "Erreur lors de l'envoi du workflow : $response_body" >&2
    exit 1
  fi

  local prompt_id
  prompt_id=$(echo "$response_body" | jq -r '.prompt_id')
  echo "Prompt ID : $prompt_id" >&2
  if [ -z "$prompt_id" ] || [ "$prompt_id" = "null" ]; then
    echo "Erreur : prompt_id non trouvé dans la réponse : $response_body" >&2
    exit 1
  fi
  monitor_progress "$prompt_id"
}

monitor_progress() {
  local prompt_id="$1"
  local start_time=$(date +%s)
  echo "Surveillance de la progression avec l'ID : $prompt_id" >&2

  while true; do
    local elapsed_time=$(( $(date +%s) - start_time ))
    if [ "$elapsed_time" -ge "$MAX_WAIT" ]; then
      echo "Erreur: Timeout (${MAX_WAIT}s) lors de la génération MiniMax H3." >&2
      return 1
    fi
    echo "En attente de traitement par ComfyUI... ($((elapsed_time / 60))m $((elapsed_time % 60))s)" >&2

    if curl -s "$COMFYUI_URL/history/$prompt_id" | jq -e --arg id "$prompt_id" '.[$id]' > /dev/null 2>&1; then
      get_video_result "$prompt_id" "$elapsed_time"
      return $?
    fi
    sleep 10
  done
}

get_video_result() {
  local prompt_id="$1"
  local elapsed_time="$2"

  local prompt_data
  prompt_data=$(curl -s "$COMFYUI_URL/history/$prompt_id" | jq --arg id "$prompt_id" '.[$id]')

  # SaveVideo (node 92) : la vidéo est rapportée dans "images" avec animated=true
  local video_node_outputs
  video_node_outputs=$(echo "$prompt_data" | jq '.outputs."92" | .video // .videos // .images // empty')

  if [ -z "$video_node_outputs" ] || [ "$video_node_outputs" = "null" ]; then
    if comfyui_should_retry_after_oom "$prompt_data"; then
      echo "Nouvelle tentative de génération après libération de la VRAM..." >&2
      send_workflow
      return $?
    fi
    echo "Erreur: Aucune sortie vidéo trouvée (node 92)" >&2
    echo "$prompt_data" | jq '.status' >&2
    return 1
  fi

  local video_filename video_subfolder
  video_filename=$(echo "$video_node_outputs" | jq -r '.[0].filename')
  video_subfolder=$(echo "$video_node_outputs" | jq -r '.[0].subfolder // ""')
  echo "Nom du fichier vidéo : $video_subfolder/$video_filename" >&2

  curl -s -G -o "$TMP_VIDEO" "$COMFYUI_URL/view" \
       --data-urlencode "filename=$video_filename" \
       --data-urlencode "subfolder=$video_subfolder" \
       --data-urlencode "type=output"
  if [ ! -s "$TMP_VIDEO" ]; then
    echo "Erreur : la vidéo téléchargée est vide" >&2
    return 1
  fi
  echo "Vidéo sauvegardée dans $TMP_VIDEO" >&2

  echo "Ajout de la vidéo à IPFS..." >&2
  local ipfs_hash
  ipfs_hash=$(ipfs add -wq "$TMP_VIDEO" 2>/dev/null | tail -n 1)
  if [ -n "$ipfs_hash" ]; then
    echo "Vidéo ajoutée à IPFS avec le hash : $ipfs_hash" >&2
    # Seule l'URL IPFS est envoyée à stdout, avec le temps de génération
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "🎬 $TIMESTAMP (⏱️ $((elapsed_time / 60))m $((elapsed_time % 60))s)\n📝 Description: $PROMPT\n🔗 $myIPFS/ipfs/$ipfs_hash/$(basename "$TMP_VIDEO")"
    return 0
  else
    echo "Erreur lors de l'ajout à IPFS" >&2
    return 1
  fi
}

check_comfyui_port || exit 1
update_workflow
send_workflow
RESULT=$?

# Libère la VRAM après génération (DiT 20 Go + encodeur texte 15 Go)
curl -s -X POST "$COMFYUI_URL/free" -H "Content-Type: application/json" \
     -d '{"unload_models": true, "free_memory": true}' > /dev/null 2>&1 \
  && echo "VRAM freed successfully" >&2 \
  || echo "Warning: Could not free VRAM" >&2
exit $RESULT
