#!/bin/bash
# Dependencies : jq curl
#### generate_video.sh : transform a prompt into a video using comfyui

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

# Vérifie si les arguments sont fournis
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <prompt> <workflow_path>" >&2
  exit 1
fi

. "${MY_PATH}/../tools/my.sh"

# Escape double quotes and backslashes in the prompt
PROMPT=$(echo "$1" | sed 's/"/\\"/g')
WORKFLOW_PATH="$2"

# Créer le répertoire temporaire s'il n'existe pas
TMP_DIR="$HOME/.zen/tmp"
mkdir -p "$TMP_DIR"

# Générer un identifiant unique pour cette exécution
UNIQUE_ID=$(date +%s)_$(openssl rand -hex 4)
TMP_WORKFLOW="$TMP_DIR/workflow_${UNIQUE_ID}.json"
TMP_VIDEO="$TMP_DIR/video_${UNIQUE_ID}.mp4"

# Nettoyage des fichiers temporaires à la sortie
cleanup() {
    rm -f "$TMP_WORKFLOW" "$TMP_VIDEO"
}
trap cleanup EXIT

# Adresse de l'API ComfyUI
COMFYUI_URL="http://127.0.0.1:8188"

# Extraction de l'adresse IP et du port depuis l'URL
COMFYUI_HOST=$(echo "$COMFYUI_URL" | sed 's#http://##' | cut -d':' -f1)
COMFYUI_PORT=$(echo "$COMFYUI_URL" | sed 's#http://##' | cut -d':' -f2)

# Fonction pour vérifier si le port ComfyUI est ouvert
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

# Fonction pour mettre à jour le prompt dans le workflow JSON
update_prompt() {
  echo "Chargement du workflow JSON : ${WORKFLOW_PATH}" >&2

  # Create a modified JSON with the prompt replaced
  jq --arg prompt "$PROMPT" '(.["6"].inputs.text) = $prompt' "$WORKFLOW_PATH" > "$TMP_WORKFLOW"

  echo "Prompt mis à jour dans le fichier JSON temporaire $TMP_WORKFLOW" >&2
  
  # Debug - show content of modified node
  echo "Contenu du nœud modifié :" >&2
  jq '.["6"].inputs' "$TMP_WORKFLOW" >&2
}

# Fonction pour envoyer le workflow à l'API ComfyUI
send_workflow() {
  echo "Envoi du workflow à l'API ComfyUI..." >&2

  local response_body_file="$TMP_DIR/response_body_${UNIQUE_ID}.json"
  
  # Create proper API payload
  local api_payload_file="$TMP_DIR/api_payload_${UNIQUE_ID}.json"
  jq '{prompt: .}' "$TMP_WORKFLOW" > "$api_payload_file"
  
  echo "Contenu de la requête API :" >&2
  head -c 300 "$api_payload_file" >&2
  echo >&2

  # Send the workflow to ComfyUI
  local http_status
  http_status=$(curl -s -w "%{http_code}" -o "$response_body_file" \
                -X POST -H "Content-Type: application/json" \
                --data-binary @"$api_payload_file" \
                "$COMFYUI_URL/prompt")
  
  # Clean up API payload file
  rm -f "$api_payload_file"
  
  local response_body
  response_body=$(cat "$response_body_file")
  rm -f "$response_body_file" # Clean up the temp response file

  echo "HTTP code: $http_status" >&2
  echo "API response: $response_body" >&2

  if [ "$http_status" -ne 200 ]; then
    echo "Erreur lors de l'envoi du workflow, code HTTP : $http_status" >&2
    echo "API response (error details): $response_body" >&2
    exit 1
  fi

  echo "Workflow envoyé avec succès." >&2
  local prompt_id
  prompt_id=$(echo "$response_body" | jq -r '.prompt_id')
  echo "Prompt ID : $prompt_id" >&2
  if [ -z "$prompt_id" ] || [ "$prompt_id" = "null" ]; then
    echo "Erreur : prompt_id non trouvé dans la réponse." >&2
    echo "API response (error details): $response_body" >&2
    exit 1
  fi
  monitor_progress "$prompt_id"
}

# Fonction pour surveiller la progression de la génération
monitor_progress() {
  local prompt_id="$1"
  local history_url="$COMFYUI_URL/history"
  local max_attempts=300  # 5 minutes maximum d'attente (vidéo plus longue que l'image)
  local attempts=0
  local start_time=$(date +%s)

  echo "Surveillance de la progression avec l'ID : $prompt_id" >&2

  # Attendre que la vidéo soit générée
  while [ $attempts -lt $max_attempts ]; do
    # Calculer et afficher le temps écoulé
    local current_time=$(date +%s)
    local elapsed_time=$((current_time - start_time))
    local minutes=$((elapsed_time / 60))
    local seconds=$((elapsed_time % 60))
    echo "En attente de traitement par ComfyUI... (${minutes}m ${seconds}s)" >&2

    # Vérifier d'abord dans l'historique si la vidéo est déjà terminée
    local history_response
    history_response=$(curl -s "$history_url")
    
    # Check if prompt_id exists in history
    if echo "$history_response" | jq -e --arg id "$prompt_id" '.[$id]' > /dev/null 2>&1; then
      echo "Vidéo trouvée dans l'historique de ComfyUI!" >&2
      get_video_result "$prompt_id" "$elapsed_time"
      return $?
    fi
    
    # If not in history, check in queue
    local queue_response
    queue_response=$(curl -s "$COMFYUI_URL/prompt")
    
    # Check if running or queued
    if echo "$queue_response" | jq -e --arg id "$prompt_id" '.running[$id] or .pending[$id]' > /dev/null 2>&1; then
      echo "Vidéo en cours de génération ou en attente..." >&2
      sleep 9
      attempts=$((attempts + 9))
      continue
    fi
    
    # If not in queue or history yet, wait a bit and check again
    sleep 9
    attempts=$((attempts + 9))
  done

  echo "Erreur: Timeout lors de la génération de vidéo par ComfyUI." >&2
  return 1
}

# Fonction pour récupérer et traiter la vidéo générée
get_video_result() {
  local prompt_id="$1"
  local elapsed_time="$2"
  local history_url="$COMFYUI_URL/history"

  echo "Récupération de l'historique..." >&2
  local history_response
  history_response=$(curl -s "$history_url")
  
  # Get output data for this specific prompt
  local prompt_data
  prompt_data=$(echo "$history_response" | jq --arg id "$prompt_id" '.[$id]')
  
  if [ -z "$prompt_data" ] || [ "$prompt_data" = "null" ]; then
    echo "Erreur: Données de prompt non trouvées dans l'historique" >&2
    return 1
  fi

  # Debug: Afficher la structure complète des sorties
  echo "Structure complète des sorties :" >&2
  echo "$prompt_data" | jq '.outputs' >&2
  
  # Find the VideoCombine node (should be node 49)
  local video_node_outputs
  video_node_outputs=$(echo "$prompt_data" | jq '.outputs."49".gifs')
  
  if [ -z "$video_node_outputs" ] || [ "$video_node_outputs" = "null" ]; then
    echo "Erreur: Sorties du nœud VHS_VideoCombine introuvables" >&2
    echo "Contenu du prompt_data pour debug:" >&2
    echo "$prompt_data" | jq '.outputs."49"' >&2
    return 1
  fi
  
  # Get the video filename and subfolder
  local video_filename
  local video_subfolder
  video_filename=$(echo "$video_node_outputs" | jq -r '.[0].filename')
  video_subfolder=$(echo "$video_node_outputs" | jq -r '.[0].subfolder')
  
  if [ -z "$video_filename" ] || [ "$video_filename" = "null" ]; then
    echo "Erreur: Informations de fichier non trouvées dans la sortie du nœud VHS_VideoCombine" >&2
    return 1
  fi

  echo "Nom du fichier vidéo : $video_filename" >&2
  
  # Build proper URL
  local video_url
  if [ -z "$video_subfolder" ] || [ "$video_subfolder" = "null" ] || [ "$video_subfolder" = "" ]; then
    video_url="$COMFYUI_URL/view?filename=$video_filename"
  else
    video_url="$COMFYUI_URL/view?filename=$video_subfolder/$video_filename"
  fi
  
  echo "URL de la vidéo : $video_url" >&2

  # Télécharger la vidéo depuis le serveur ComfyUI
  echo "Téléchargement de la vidéo..." >&2
  curl -s -o "$TMP_VIDEO" "$video_url"
  if [ $? -ne 0 ]; then
    echo "Erreur lors du téléchargement de la vidéo" >&2
    return 1
  fi
  echo "Vidéo sauvegardée dans $TMP_VIDEO" >&2

  # Vérifier que la vidéo a été correctement téléchargée
  if [ ! -s "$TMP_VIDEO" ]; then
    echo "Erreur : la vidéo téléchargée est vide" >&2
    return 1
  fi

  # Ajouter à IPFS
  echo "Ajout de la vidéo à IPFS..." >&2
  local ipfs_hash
  ipfs_hash=$(ipfs add -wq "$TMP_VIDEO" 2>/dev/null | tail -n 1)
  if [ -n "$ipfs_hash" ]; then
    echo "Vidéo ajoutée à IPFS avec le hash : $ipfs_hash" >&2
    # Seule l'URL IPFS est envoyée à stdout, avec le temps de génération
    local minutes=$((elapsed_time / 60))
    local seconds=$((elapsed_time % 60))
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "🎬 $TIMESTAMP (⏱️ ${minutes}m ${seconds}s)\n📝 Description: $PROMPT\n🔗 $myIPFS/ipfs/$ipfs_hash/$(basename "$TMP_VIDEO")"
    return 0
  else
    echo "Erreur lors de l'ajout à IPFS" >&2
    return 1
  fi
}

# Main script execution

# Check if ComfyUI is accessible
check_comfyui_port
if [ $? -ne 0 ]; then
    exit 1
fi

# Update the workflow with the user's prompt
update_prompt

# Send the workflow to ComfyUI for processing
send_workflow 