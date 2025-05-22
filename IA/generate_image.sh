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
  echo "Chargement du workflow JSON : ${WORKFLOW_FILE}" >&2

  # Créer un fichier temporaire avec le prompt remplacé
  sed "s/_PROMPT_/$PROMPT/g" "$WORKFLOW_FILE" > "$TMP_WORKFLOW"

  echo "Prompt mis à jour dans le fichier JSON temporaire $TMP_WORKFLOW" >&2
}

# Fonction pour envoyer le workflow à l'API ComfyUI
send_workflow() {
  echo "Envoi du workflow à l'API ComfyUI..." >&2
  local data
  data=$(jq -c . "$TMP_WORKFLOW")
  if [ $? -ne 0 ]; then
    echo "Erreur lors de la lecture du workflow JSON" >&2
    cat "$TMP_WORKFLOW" >&2
    exit 1
  fi

  echo "Workflow JSON préparé :" >&2
  echo "$data" >&2

  local response
  local http_code
  local curl_command
  curl_command="curl -s -w \"%{http_code}\" -X POST -H \"Content-Type: application/json\" -d \"$data\" '$COMFYUI_URL/prompt'"
  echo "Executing: $curl_command" >&2
  response=$(eval "$curl_command" 2>&1)
  http_code=$(echo "$response" | grep -oP '^\d+' | tail -n 1)
  response=$(echo "$response" | grep -vP '^\d+$' )

  echo "HTTP code: $http_code" >&2
  echo "API response: $response" >&2

  if [ "$http_code" -ne 200 ]; then
    echo "Erreur lors de l'envoi du workflow, code HTTP : $http_code" >&2
    echo "$response" >&2
    exit 1
  fi

  echo "Workflow envoyé avec succès." >&2
  local prompt_id
  prompt_id=$(echo "$response" | jq -r '.prompt_id')
  echo "Prompt ID : $prompt_id" >&2
  if [ -z "$prompt_id" ] || [ "$prompt_id" = "null" ]; then
    echo "Erreur : prompt_id non trouvé dans la réponse." >&2
    echo "$response" >&2
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

  echo "Surveillance de la progression avec l'ID : $prompt_id" >&2

  while [ $attempts -lt $max_attempts ]; do
    local progress_response
    progress_response=$(curl -s "$progress_url")
    echo "Réponse de progression : $progress_response" >&2

    if echo "$progress_response" | jq -e '. != null'; then
      local current
      current=$(echo "$progress_response" | jq -r '.progress.value')
      local total
      total=$(echo "$progress_response" | jq -r '.progress.max')

      local status
      status=$(echo "$progress_response" | jq -r '.status')

      if [ "$status" = "completed" ]; then
         echo "Génération terminée." >&2
         get_image_result "$prompt_id"
        return $?
      elif [ "$status" = "error" ]; then
         echo "Erreur lors de la génération :" >&2
         echo "$progress_response" >&2
         return 1
      else
         echo "Progression : $current/$total" >&2
        sleep 1
        attempts=$((attempts + 1))
      fi
    else
       echo "Erreur lors de la récupération de la progression." >&2
       echo "$progress_response" >&2
       return 1
    fi
  done

  echo "Timeout : la génération a pris trop de temps" >&2
  return 1
}

get_image_result() {
  local prompt_id="$1"
  local history_url="$COMFYUI_URL/history/$prompt_id"

  echo "Récupération de l'historique pour l'ID : $prompt_id" >&2
  local history_response
  history_response=$(curl -s "$history_url")
  echo "Réponse historique : $history_response" >&2

  if echo "$history_response" | jq -e '. != null'; then
    local node_id
    node_id=$(echo "$history_response" | jq -r 'keys[0]')
    echo "Node ID trouvé : $node_id" >&2

    local image_filename
    image_filename=$(echo "$history_response" | jq -r "."$node_id".outputs."7"[0].filename")
    echo "Nom du fichier image : $image_filename" >&2

    if [ -z "$image_filename" ] || [ "$image_filename" = "null" ]; then
      echo "Erreur : nom de fichier image non trouvé dans la réponse" >&2
      echo "$history_response" >&2
      return 1
    fi

    local image_url
    image_url="$COMFYUI_URL/view/$image_filename"
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
  else
    echo "Erreur lors de la récupération de l'historique." >&2
    echo "$history_response" >&2
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