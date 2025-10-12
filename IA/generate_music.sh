#!/bin/bash
# Dependencies : jq curl
#### generate_music.sh : transform a prompt into music using comfyui

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

# Vérifie si le prompt est fourni en argument
if [ -z "$1" ]; then
  echo "Usage: $0 <prompt> [udrive_path]" >&2
  exit 1
fi

# Optional uDRIVE path parameter
UDRIVE_PATH="$2"

. "${MY_PATH}/../tools/my.sh"

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

# Déterminer le répertoire de destination
if [ -n "$UDRIVE_PATH" ] && [ -d "$UDRIVE_PATH" ]; then
    OUTPUT_DIR="$UDRIVE_PATH"
    echo "Using uDRIVE directory: $OUTPUT_DIR" >&2
else
    OUTPUT_DIR="$TMP_DIR"
    echo "Using temporary directory: $OUTPUT_DIR" >&2
fi

# Générer un identifiant unique pour cette exécution
UNIQUE_ID=$(date +%s)_$(openssl rand -hex 4)
TMP_WORKFLOW="$TMP_DIR/workflow_${UNIQUE_ID}.json"
TMP_AUDIO="$OUTPUT_DIR/audio_${UNIQUE_ID}.flac"

# Nettoyage des fichiers temporaires à la sortie
cleanup() {
    rm -f "$TMP_WORKFLOW"
    # Only remove TMP_AUDIO if it's in the temp directory, not in uDRIVE
    if [[ "$TMP_AUDIO" == "$TMP_DIR"* ]]; then
        rm -f "$TMP_AUDIO"
    fi
}
trap cleanup EXIT

# Chemin vers le fichier JSON du workflow
WORKFLOW_FILE="${MY_PATH}/workflow/audio_ace_step_1_t2m.json"

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

  # Extract lyrics if present in the prompt
  local lyrics=""
  if [[ "$PROMPT" =~ \#parole[[:space:]]+(.*) ]]; then
    lyrics="${BASH_REMATCH[1]}"
    # Remove the #parole part from the prompt
    PROMPT=$(echo "$PROMPT" | sed 's/#parole.*$//')
  fi

  # Create a modified JSON with the prompt, lyrics and seed replaced
  if [ -n "$lyrics" ]; then
    jq --arg prompt "$PROMPT" --arg lyrics "$lyrics" --argjson seed "$new_seed" \
      '(.["14"].inputs.tags) = $prompt | (.["14"].inputs.lyrics) = $lyrics | (.["3"].inputs.seed) = $seed' \
      "$WORKFLOW_FILE" > "$TMP_WORKFLOW"
  else
    jq --arg prompt "$PROMPT" --argjson seed "$new_seed" \
      '(.["14"].inputs.tags) = $prompt | (.["14"].inputs.lyrics) = "" | (.["3"].inputs.seed) = $seed' \
      "$WORKFLOW_FILE" > "$TMP_WORKFLOW"
  fi

  echo "Prompt, lyrics and seed updated in temporary JSON file $TMP_WORKFLOW" >&2
  
  # Debug - show content of modified nodes
  echo "Modified nodes content:" >&2
  jq '.["14"].inputs, .["3"].inputs' "$TMP_WORKFLOW" >&2

  # Return lyrics for later use
  echo "$lyrics"
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
  local max_attempts=60  # 1 minute maximum d'attente
  local attempts=0
  local start_time=$(date +%s)

  echo "Surveillance de la progression avec l'ID : $prompt_id" >&2

  # Attendre que l'audio soit généré
  while [ $attempts -lt $max_attempts ]; do
    # Calculer et afficher le temps écoulé
    local current_time=$(date +%s)
    local elapsed_time=$((current_time - start_time))
    local minutes=$((elapsed_time / 60))
    local seconds=$((elapsed_time % 60))
    echo "En attente de traitement par ComfyUI... (${minutes}m ${seconds}s)" >&2

    # Vérifier d'abord dans l'historique si l'audio est déjà terminé
    local history_response
    history_response=$(curl -s "$history_url")
    
    # Check if prompt_id exists in history
    if echo "$history_response" | jq -e --arg id "$prompt_id" '.[$id]' > /dev/null 2>&1; then
      echo "Audio trouvé dans l'historique de ComfyUI!" >&2
      get_audio_result "$prompt_id" "$elapsed_time" "$lyrics"
      return $?
    fi
    
    # If not in history, check in queue
    local queue_response
    queue_response=$(curl -s "$COMFYUI_URL/prompt")
    
    # Check if running or queued
    if echo "$queue_response" | jq -e --arg id "$prompt_id" '.running[$id] or .pending[$id]' > /dev/null 2>&1; then
      echo "Audio en cours de génération ou en attente..." >&2
      sleep 2
      attempts=$((attempts + 2))
      continue
    fi
    
    # If not in queue or history yet, wait a bit and check again
    sleep 2
    attempts=$((attempts + 2))
  done

  echo "Erreur: Timeout lors de la génération d'audio par ComfyUI." >&2
  return 1
}

# Fonction pour récupérer et traiter l'audio généré
get_audio_result() {
  local prompt_id="$1"
  local elapsed_time="$2"
  local lyrics="$3"
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
  
  # Find the SaveAudio node (should be node 19)
  local save_node_outputs
  save_node_outputs=$(echo "$prompt_data" | jq '.outputs."19".audio')
  
  if [ -z "$save_node_outputs" ] || [ "$save_node_outputs" = "null" ]; then
    echo "Erreur: Sorties du nœud SaveAudio introuvables" >&2
    echo "Contenu du prompt_data pour debug:" >&2
    echo "$prompt_data" | jq '.outputs."19"' >&2
    return 1
  fi
  
  # Get the audio filename and subfolder
  local audio_filename
  local audio_subfolder
  audio_filename=$(echo "$save_node_outputs" | jq -r '.[0].filename')
  audio_subfolder=$(echo "$save_node_outputs" | jq -r '.[0].subfolder')
  
  if [ -z "$audio_filename" ] || [ "$audio_filename" = "null" ]; then
    echo "Erreur: Informations de fichier non trouvées dans la sortie du nœud SaveAudio" >&2
    return 1
  fi

  echo "Nom du fichier audio : $audio_filename" >&2
  
  # Build proper URL
  local audio_url
  if [ -z "$audio_subfolder" ] || [ "$audio_subfolder" = "null" ] || [ "$audio_subfolder" = "" ]; then
    audio_url="$COMFYUI_URL/output/audio/$audio_filename"
  else
    audio_url="$COMFYUI_URL/output/$audio_subfolder/$audio_filename"
  fi
  
  echo "URL de l'audio : $audio_url" >&2

  # Vérifier que l'URL est accessible
  echo "Vérification de l'accessibilité de l'URL..." >&2
  if ! curl -s -I "$audio_url" | grep -q "200 OK"; then
    echo "Erreur: L'URL de l'audio n'est pas accessible" >&2
    echo "Tentative avec l'URL alternative..." >&2
    # Essayer avec l'URL alternative
    if [ -z "$audio_subfolder" ] || [ "$audio_subfolder" = "null" ] || [ "$audio_subfolder" = "" ]; then
      audio_url="$COMFYUI_URL/view?filename=audio/$audio_filename"
    else
      audio_url="$COMFYUI_URL/view?filename=$audio_subfolder/$audio_filename"
    fi
    echo "URL alternative : $audio_url" >&2
    if ! curl -s -I "$audio_url" | grep -q "200 OK"; then
      echo "Erreur: L'URL alternative n'est pas non plus accessible" >&2
      echo "Tentative avec l'URL finale..." >&2
      # Dernière tentative avec le chemin complet
      audio_url="$COMFYUI_URL/output/audio/$audio_filename"
      echo "URL finale : $audio_url" >&2
      if ! curl -s -I "$audio_url" | grep -q "200 OK"; then
        echo "Erreur: Aucune URL n'est accessible" >&2
        echo "Vérifiez que le fichier existe dans le dossier ComfyUI/output/audio/" >&2
        return 1
      fi
    fi
  fi

  # Télécharger l'audio depuis le serveur ComfyUI
  echo "Téléchargement de l'audio..." >&2
  curl -s -o "$TMP_AUDIO" "$audio_url"
  if [ $? -ne 0 ]; then
    echo "Erreur lors du téléchargement de l'audio" >&2
    return 1
  fi
  echo "Audio sauvegardé dans $TMP_AUDIO" >&2

  # Vérifier que l'audio a été correctement téléchargé
  if [ ! -s "$TMP_AUDIO" ]; then
    echo "Erreur : l'audio téléchargé est vide" >&2
    echo "Vérifiez que le fichier existe dans le dossier ComfyUI/output/audio/" >&2
    echo "Vous pouvez aussi essayer de le télécharger manuellement depuis : $audio_url" >&2
    return 1
  fi

  # Vérifier le type de fichier
  echo "Vérification du type de fichier..." >&2
  if ! file "$TMP_AUDIO" | grep -q "FLAC audio"; then
    echo "Erreur : le fichier téléchargé n'est pas un fichier FLAC valide" >&2
    echo "Type de fichier détecté :" >&2
    file "$TMP_AUDIO" >&2
    return 1
  fi

  # Convertir en MP3
  echo "Conversion en MP3..." >&2
  local mp3_file="${TMP_AUDIO%.flac}.mp3"
  # Get duration of the audio file
  local duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$TMP_AUDIO")
  # Calculate fade out start time (2 seconds before the end)
  local fade_start=$(echo "$duration - 2" | bc)
  if ! ffmpeg -i "$TMP_AUDIO" -af "afade=t=out:st=${fade_start}:d=2" -codec:a libmp3lame -qscale:a 2 "$mp3_file" 2>/dev/null; then
    echo "Erreur lors de la conversion en MP3" >&2
    return 1
  fi
  echo "Conversion en MP3 avec fade out terminée" >&2

  # Vérifier que le MP3 a été correctement créé
  if [ ! -s "$mp3_file" ]; then
    echo "Erreur : le fichier MP3 est vide" >&2
    return 1
  fi

  # Ajouter à IPFS
  echo "Ajout de l'audio à IPFS..." >&2
  local ipfs_hash
  ipfs_hash=$(ipfs add -wq "$mp3_file" 2>/dev/null | tail -n 1)
  if [ -n "$ipfs_hash" ]; then
    echo "Audio ajouté à IPFS avec le hash : $ipfs_hash" >&2
    echo "Audio saved to: $TMP_AUDIO" >&2
    # Seule l'URL IPFS est envoyée à stdout, avec le temps de génération
    local minutes=$((elapsed_time / 60))
    local seconds=$((elapsed_time % 60))
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local execution_time=$((minutes * 60 + seconds))
    local music_url="$myIPFS/ipfs/$ipfs_hash/$(basename "$mp3_file")"
    
    # Build the output with field values
    local output="🎵 $timestamp (⏱️ ${execution_time} s)\n"
    output+="🎼 Style : $PROMPT\n"
    if [ -n "$lyrics" ]; then
        output+="📜 Paroles : $lyrics\n"
    fi
    output+="🔗 $music_url"
    
    echo -e "$output"
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

# Update the workflow with the user's prompt and get lyrics
lyrics=$(update_prompt)

# Send the workflow to ComfyUI for processing
send_workflow 