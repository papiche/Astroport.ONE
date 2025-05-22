#!/bin/bash
# Dependencies : jq curl
#### generate_image.sh : transform a prompt into an image using comfyui

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

# Vérifie si le prompt est fourni en argument
if [ -z "$1" ]; then
  echo "Usage: $0 <prompt>"
  exit 1
fi

. "${MY_PATH}/my.sh"

PROMPT="$1"

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
  echo "Vérification du port ComfyUI : ${COMFYUI_HOST}:${COMFYUI_PORT}"
  if nc -z "$COMFYUI_HOST" "$COMFYUI_PORT" > /dev/null 2>&1; then
    echo "Le port ComfyUI est accessible."
    return 0
  else
    echo "Erreur : Le port ComfyUI n'est pas accessible."
    return 1
  fi
}

# Fonction pour mettre à jour le prompt dans le workflow JSON
update_prompt() {
  echo "Chargement du workflow JSON : ${WORKFLOW_FILE}"
  
  # Créer un fichier temporaire avec le prompt remplacé
  sed "s/_PROMPT_/$PROMPT/g" "$WORKFLOW_FILE" > "$TMP_WORKFLOW"

  echo "Prompt mis à jour dans le fichier JSON temporaire $TMP_WORKFLOW"
}

# Fonction pour envoyer le workflow à l'API ComfyUI
send_workflow() {
  echo "Envoi du workflow à l'API ComfyUI..."
  local data
  data=$(jq -c . "$TMP_WORKFLOW")
  if [ $? -ne 0 ]; then
    echo "Erreur lors de la lecture du workflow JSON"
    cat "$TMP_WORKFLOW"
    exit 1
  fi

  echo "Workflow JSON préparé :"
  echo "$data"

  local response
  local http_code
  local curl_command
  curl_command="curl -s -w \"%{http_code}\" -X POST -H \"Content-Type: application/json\" -d '$data' '$COMFYUI_URL/prompt'"
  echo "Executing: $curl_command"
  response=$(eval "$curl_command" 2>&1)
  http_code=$(echo "$response" | grep -oP '^\d+' | tail -n 1)
  response=$(echo "$response" | grep -vP '^\d+$' )

  echo "HTTP code: $http_code"
  echo "API response: $response"

  if [ "$http_code" -ne 200 ]; then
    echo "Erreur lors de l'envoi du workflow, code HTTP : $http_code"
    echo "$response"
    exit 1
  fi

  echo "Workflow envoyé avec succès."
  local prompt_id
  prompt_id=$(echo "$response" | jq -r '.prompt_id')
  echo "Prompt ID : $prompt_id"
  if [ -z "$prompt_id" ] || [ "$prompt_id" = "null" ]; then
    echo "Erreur : prompt_id non trouvé dans la réponse."
    echo "$response"
    exit 1
  fi
  monitor_progress "$prompt_id"
}

# Fonction pour surveiller la progression de la génération
monitor_progress() {
  local prompt_id="$1"
  local progress_url="$COMFYUI_URL/queue/$prompt_id"
  local max_attempts=60  # 60 secondes maximum d'attente
  local attempts=0

  echo "Surveillance de la progression avec l'ID : $prompt_id"

  while [ $attempts -lt $max_attempts ]; do
    local progress_response
    progress_response=$(curl -s "$progress_url")
    echo "Réponse de progression : $progress_response"

    if echo "$progress_response" | jq -e '. != null'; then
      local current
      current=$(echo "$progress_response" | jq -r '.progress.value')
      local total
      total=$(echo "$progress_response" | jq -r '.progress.max')

      local status
      status=$(echo "$progress_response" | jq -r '.status')

      if [ "$status" = "completed" ]; then
         echo "Génération terminée."
         get_image_result "$prompt_id"
        return 0
      elif [ "$status" = "error" ]; then
         echo "Erreur lors de la génération :"
         echo "$progress_response"
         return 1
      else
         echo "Progression : $current/$total"
        sleep 1
        attempts=$((attempts + 1))
      fi
    else
       echo "Erreur lors de la récupération de la progression."
       echo "$progress_response"
       return 1
    fi
  done

  echo "Timeout : la génération a pris trop de temps"
  return 1
}

get_image_result() {
  local prompt_id="$1"
  local history_url="$COMFYUI_URL/history/$prompt_id"

  echo "Récupération de l'historique pour l'ID : $prompt_id"
  local history_response
  history_response=$(curl -s "$history_url")
  echo "Réponse historique : $history_response"

  if echo "$history_response" | jq -e '. != null'; then
    local node_id
    node_id=$(echo "$history_response" | jq -r 'keys[0]')
    echo "Node ID trouvé : $node_id"

    local image_filename
    image_filename=$(echo "$history_response" | jq -r ".[\"$node_id\"].outputs.\"7\"[0].filename")
    echo "Nom du fichier image : $image_filename"

    if [ -z "$image_filename" ] || [ "$image_filename" = "null" ]; then
      echo "Erreur : nom de fichier image non trouvé dans la réponse"
      echo "$history_response"
      return 1
    fi

    local image_url
    image_url="$COMFYUI_URL/view/$image_filename"
    echo "URL de l'image : $image_url"

    echo "Téléchargement de l'image..."
    curl -s -o "$TMP_IMAGE" "$image_url"
    if [ $? -ne 0 ]; then
      echo "Erreur lors du téléchargement de l'image"
      return 1
    fi
    echo "Image sauvegardée dans $TMP_IMAGE"

    # Vérifier que l'image a été correctement téléchargée
    if [ ! -s "$TMP_IMAGE" ]; then
      echo "Erreur : l'image téléchargée est vide"
      return 1
    fi

    # Ajouter à IPFS
    echo "Ajout de l'image à IPFS..."
    local ipfs_hash
    ipfs_hash=$(ipfs add -wq "$TMP_IMAGE" 2>/dev/null | tail -n 1)
    if [ -n "$ipfs_hash" ]; then
      echo "Image ajoutée à IPFS avec le hash : $ipfs_hash"
      echo "$myIPFS/ipfs/$ipfs_hash/$TMP_IMAGE"
      return 0
    else
      echo "Erreur lors de l'ajout à IPFS"
      return 1
    fi
  else
    echo "Erreur lors de la récupération de l'historique."
    echo "$history_response"
    return 1
  fi
}

# Main script
check_comfyui_port
if [ $? -ne 0 ]; then
    exit 1
fi

update_prompt
send_workflow 