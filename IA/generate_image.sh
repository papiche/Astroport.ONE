#!/bin/bash
# Dependencies : jq curl
#### generate_image.sh : transform a prompt into an image using comfyui

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

# Vérifie si le prompt est fourni en argument
if [ -z "$1" ]; then
  echo "Usage: $0 <prompt>" >&2
  exit 1
fi

. "${MY_PATH}/../tools/my.sh"

# Activate the virtual environment to access all Python modules
VENV_DIR="${HOME}/.astro"
if [ -d "$VENV_DIR" ]; then
    source "$VENV_DIR/bin/activate"
    echo "Python environment activated: $VENV_DIR" >&2
else
    echo "Warning: Python environment not found at $VENV_DIR" >&2
fi

# Escape double quotes and backslashes in the prompt
PROMPT=$(echo "$1" | sed 's/"/\\"/g')

# Generate a random seed
generate_random_seed() {
  # Generate a random number between 0 and 2^53-1 (max safe integer in JavaScript)
  echo $((RANDOM * RANDOM * RANDOM))
}

# Créer le répertoire temporaire s'il n'existe pas
TMP_DIR="$HOME/.zen/tmp"
mkdir -p "$TMP_DIR"

# Générer un identifiant unique pour cette exécution
UNIQUE_ID=$(date +%s)_$(openssl rand -hex 4)
TMP_WORKFLOW="$TMP_DIR/workflow_${UNIQUE_ID}.json"
TMP_IMAGE="$TMP_DIR/image_${UNIQUE_ID}.png"

# Nettoyage des fichiers temporaires à la sortie
cleanup() {
    rm -f "$TMP_WORKFLOW" "$TMP_IMAGE"
}
trap cleanup EXIT

# Chemin vers le fichier JSON du workflow
WORKFLOW_FILE="${MY_PATH}/workflow/FluxImage.json"

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

# Fonction pour mettre à jour le prompt et le seed dans le workflow JSON
update_prompt() {
  echo "Chargement du workflow JSON : ${WORKFLOW_FILE}" >&2

  # Generate a new random seed
  local new_seed=$(generate_random_seed)
  echo "Using random seed: $new_seed" >&2

  # Create a modified JSON with the prompt and seed replaced
  jq --arg prompt "$PROMPT" --argjson seed "$new_seed" \
     '(.["4"].inputs.text) = $prompt | (.["1"].inputs.seed) = $seed' \
     "$WORKFLOW_FILE" > "$TMP_WORKFLOW"

  echo "Prompt and seed updated in temporary JSON file $TMP_WORKFLOW" >&2
  
  # Debug - show content of modified nodes
  echo "Modified nodes content:" >&2
  jq '.["4"].inputs, .["1"].inputs' "$TMP_WORKFLOW" >&2
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
  local max_attempts=120  # 2 minutes maximum d'attente
  local attempts=0

  echo "Surveillance de la progression avec l'ID : $prompt_id" >&2

  # Attendre que l'image soit générée
  while [ $attempts -lt $max_attempts ]; do
    # Vérifier d'abord dans l'historique si l'image est déjà terminée
    local history_response
    history_response=$(curl -s "$history_url")
    
    # Check if prompt_id exists in history
    if echo "$history_response" | jq -e --arg id "$prompt_id" '.[$id]' > /dev/null 2>&1; then
      echo "Image trouvée dans l'historique de ComfyUI!" >&2
      get_image_result "$prompt_id"
      return $?
    fi
    
    # If not in history, check in queue
    local queue_response
    queue_response=$(curl -s "$COMFYUI_URL/prompt")
    
    # Check if running or queued
    if echo "$queue_response" | jq -e --arg id "$prompt_id" '.running[$id] or .pending[$id]' > /dev/null 2>&1; then
      echo "Image en cours de génération ou en attente..." >&2
      sleep 2
      attempts=$((attempts + 2))
      continue
    fi
    
    # If not in queue or history yet, wait a bit and check again
    echo "En attente de traitement par ComfyUI..." >&2
    sleep 2
    attempts=$((attempts + 2))
  done

  echo "Erreur: Timeout lors de la génération d'image par ComfyUI." >&2
  return 1
}

# Fonction pour récupérer et traiter l'image générée
get_image_result() {
  local prompt_id="$1"
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
  
  # Find the SaveImage node (should be node 7)
  local save_node_outputs
  save_node_outputs=$(echo "$prompt_data" | jq '.outputs."7".images')
  
  if [ -z "$save_node_outputs" ] || [ "$save_node_outputs" = "null" ]; then
    echo "Erreur: Sorties du nœud SaveImage introuvables" >&2
    return 1
  fi
  
  # Get the image filename
  local image_filename
  image_filename=$(echo "$save_node_outputs" | jq -r '.[0].filename')
  
  if [ -z "$image_filename" ] || [ "$image_filename" = "null" ]; then
    echo "Erreur: Nom de fichier non trouvé dans la sortie du nœud SaveImage" >&2
    return 1
  fi

  echo "Nom du fichier image : $image_filename" >&2

  # Get subfolder if present
  local image_subfolder
  image_subfolder=$(echo "$save_node_outputs" | jq -r '.[0].subfolder')
  
  # Build proper URL
  local image_url
  if [ -z "$image_subfolder" ] || [ "$image_subfolder" = "null" ] || [ "$image_subfolder" = "" ]; then
    image_url="$COMFYUI_URL/view?filename=$image_filename"
  else
    image_url="$COMFYUI_URL/view?filename=$image_subfolder/$image_filename"
  fi
  
  echo "URL de l'image : $image_url" >&2

  echo "Téléchargement de l'image..." >&2
  curl -s -o "$TMP_IMAGE" "$image_url"
  if [ $? -ne 0 ]; then
    echo "Erreur lors du téléchargement de l'image" >&2
    return 1
  fi
  echo "Image sauvegardée dans $TMP_IMAGE" >&2

  # Vérifier que l'image a été correctement téléchargée
  if [ ! -s "$TMP_IMAGE" ]; then
    echo "Erreur : l'image téléchargée est vide" >&2
    return 1
  fi

  # Ajouter à IPFS
  echo "Ajout de l'image à IPFS..." >&2
  local ipfs_hash
  ipfs_hash=$(ipfs add -wq "$TMP_IMAGE" 2>/dev/null | tail -n 1)
  if [ -n "$ipfs_hash" ]; then
    echo "Image ajoutée à IPFS avec le hash : $ipfs_hash" >&2
    # Seule l'URL IPFS est envoyée à stdout
    echo "$myIPFS/ipfs/$ipfs_hash/$(basename "$TMP_IMAGE")"
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
