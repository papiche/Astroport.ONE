#!/bin/bash
# Dependencies : jq curl
###################################################################
# generate_image.sh
# Transform a text prompt into a high-quality image using ComfyUI
#
# Usage: $0 <prompt> [udrive_path]
#
# Input:
#   - prompt: Text description for image generation (e.g., "a cat sitting on a chair")
#   - udrive_path: Optional user directory for image storage (default: temp directory)
#
# Output:
#   - Returns IPFS URL of generated image (e.g., "https://ipfs.copylaradio.com/ipfs/QmHash/image_123456.png")
#   - Saves image file to specified directory or temp folder
#   - Adds image to IPFS network for permanent storage and sharing
#
# Process:
#   1. Validates ComfyUI API connection (port 8188)
#   2. Creates optimized workflow JSON with user prompt
#   3. Sends workflow to ComfyUI for image generation
#   4. Monitors generation progress (max 2 minutes timeout)
#   5. Downloads generated image from ComfyUI
#   6. Uploads image to IPFS network
#   7. Returns public IPFS URL for immediate use
#
# Features:
#   - Random seed generation for unique results
#   - User-specific storage in uDRIVE directories
#   - Automatic IPFS integration for decentralized storage
#   - Error handling and timeout protection
#   - Cleanup of temporary files
###################################################################

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

# Validate input parameters
# The script requires at least a text prompt for image generation
if [ -z "$1" ]; then
  echo "Usage: $0 <prompt> [udrive_path]" >&2
  echo "Example: $0 'a beautiful sunset over mountains' /home/user/uDRIVE/Images" >&2
  exit 1
fi

# Optional uDRIVE path parameter for user-specific storage
# If provided, images will be saved to user's personal directory
# If not provided, images will be saved to temporary directory
UDRIVE_PATH="$2"

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

# Determine output directory for generated images
# Priority: User's uDRIVE directory > Temporary directory
# This ensures images are properly organized and accessible
if [ -n "$UDRIVE_PATH" ] && [ -d "$UDRIVE_PATH" ]; then
    OUTPUT_DIR="$UDRIVE_PATH"
    echo "Using uDRIVE directory: $OUTPUT_DIR" >&2
    echo "Images will be permanently stored in user's personal space" >&2
else
    OUTPUT_DIR="$TMP_DIR"
    echo "Using temporary directory: $OUTPUT_DIR" >&2
    echo "Images will be stored temporarily and may be cleaned up" >&2
fi

# Générer un identifiant unique pour cette exécution
UNIQUE_ID=$(date +%s)_$(openssl rand -hex 4)
TMP_WORKFLOW="$TMP_DIR/workflow_${UNIQUE_ID}.json"
TMP_IMAGE="$OUTPUT_DIR/image_${UNIQUE_ID}.png"

# Nettoyage des fichiers temporaires à la sortie
cleanup() {
    rm -f "$TMP_WORKFLOW"
    # Only remove TMP_IMAGE if it's in the temp directory, not in uDRIVE
    if [[ "$TMP_IMAGE" == "$TMP_DIR"* ]]; then
        rm -f "$TMP_IMAGE"
    fi
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

# Function to update the ComfyUI workflow with user prompt and random seed
# This creates a customized workflow JSON for Stable Diffusion generation
update_prompt() {
  echo "Loading ComfyUI workflow template: ${WORKFLOW_FILE}" >&2

  # Generate a new random seed for unique image generation
  # Each run produces different results even with the same prompt
  local new_seed=$(generate_random_seed)
  echo "Using random seed: $new_seed" >&2

  # Create a modified JSON workflow with user's prompt and seed
  # Node 4: Text input for the prompt
  # Node 1: Seed input for randomization
  jq --arg prompt "$PROMPT" --argjson seed "$new_seed" \
     '(.["4"].inputs.text) = $prompt | (.["1"].inputs.seed) = $seed' \
     "$WORKFLOW_FILE" > "$TMP_WORKFLOW"

  echo "Workflow customized with prompt and seed in: $TMP_WORKFLOW" >&2
  
  # Debug information: show the modified nodes for verification
  echo "Modified workflow nodes:" >&2
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

# Function to retrieve and process the generated image from ComfyUI
# This function downloads the image and uploads it to IPFS for permanent storage
get_image_result() {
  local prompt_id="$1"
  local history_url="$COMFYUI_URL/history"

  echo "Retrieving generation history from ComfyUI..." >&2
  local history_response
  history_response=$(curl -s "$history_url")
  
  # Extract output data for this specific generation request
  local prompt_data
  prompt_data=$(echo "$history_response" | jq --arg id "$prompt_id" '.[$id]')
  
  if [ -z "$prompt_data" ] || [ "$prompt_data" = "null" ]; then
    echo "Error: Generation data not found in ComfyUI history" >&2
    return 1
  fi
  
  # Locate the SaveImage node output (typically node 7 in the workflow)
  local save_node_outputs
  save_node_outputs=$(echo "$prompt_data" | jq '.outputs."7".images')
  
  if [ -z "$save_node_outputs" ] || [ "$save_node_outputs" = "null" ]; then
    echo "Error: SaveImage node output not found in generation results" >&2
    return 1
  fi
  
  # Extract the generated image filename
  local image_filename
  image_filename=$(echo "$save_node_outputs" | jq -r '.[0].filename')
  
  if [ -z "$image_filename" ] || [ "$image_filename" = "null" ]; then
    echo "Error: Image filename not found in SaveImage node output" >&2
    return 1
  fi

  echo "Generated image filename: $image_filename" >&2

  # Check for subfolder organization (ComfyUI may organize images in folders)
  local image_subfolder
  image_subfolder=$(echo "$save_node_outputs" | jq -r '.[0].subfolder')
  
  # Build the complete ComfyUI image URL for download
  local image_url
  if [ -z "$image_subfolder" ] || [ "$image_subfolder" = "null" ] || [ "$image_subfolder" = "" ]; then
    image_url="$COMFYUI_URL/view?filename=$image_filename"
  else
    image_url="$COMFYUI_URL/view?filename=$image_subfolder/$image_filename"
  fi
  
  echo "ComfyUI image URL: $image_url" >&2

  # Download the generated image from ComfyUI
  echo "Downloading generated image..." >&2
  curl -s -o "$TMP_IMAGE" "$image_url"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to download image from ComfyUI" >&2
    return 1
  fi
  echo "Image saved locally to: $TMP_IMAGE" >&2

  # Verify the downloaded image is not empty
  if [ ! -s "$TMP_IMAGE" ]; then
    echo "Error: Downloaded image file is empty" >&2
    return 1
  fi

  # Upload image to IPFS for permanent, decentralized storage
  echo "Uploading image to IPFS network..." >&2
  local ipfs_hash
  ipfs_hash=$(ipfs add -wq "$TMP_IMAGE" 2>/dev/null | tail -n 1)
  if [ -n "$ipfs_hash" ]; then
    echo "Image successfully uploaded to IPFS with hash: $ipfs_hash" >&2
    echo "Local file saved to: $TMP_IMAGE" >&2
    # Return the public IPFS URL for immediate use
    # This URL can be used directly in web browsers and applications
    echo "$myIPFS/ipfs/$ipfs_hash/$(basename "$TMP_IMAGE")"
    return 0
  else
    echo "Error: Failed to upload image to IPFS network" >&2
    return 1
  fi
}

# Main script execution
# This script generates a high-quality image from a text prompt and returns an IPFS URL

# Step 1: Validate ComfyUI API is running and accessible
check_comfyui_port
if [ $? -ne 0 ]; then
    echo "Error: ComfyUI API is not accessible. Please start ComfyUI server." >&2
    exit 1
fi

# Step 2: Prepare the generation workflow with user's prompt
update_prompt

# Step 3: Submit workflow to ComfyUI and monitor generation
# This will generate the image and return the IPFS URL
send_workflow

# Final Output:
# - Success: Returns IPFS URL (e.g., "https://ipfs.copylaradio.com/ipfs/QmHash/image_123456.png")
# - Failure: Returns error code and message to stderr
# - Image file is saved locally and uploaded to IPFS for permanent access
