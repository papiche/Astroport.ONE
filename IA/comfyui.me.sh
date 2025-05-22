#!/bin/bash
# Dependencies : jq curl
#### comfyui.me.sh : transform a prompt into an image usung comfyui

## Check for local comfyui 8188 port open
## Else try to open ssh port forward tunnel (could be ipfs p2p if 2122 port is not opened)
## Will be extended to load balance GPU units to every RPi Stations
## Spread IA to whole Swarm
########################################################
## TODO : Get in swarm GPU Station
########################################################

# Configuration
COMFYUI_PORT=8188
REMOTE_USER="frd"
REMOTE_HOST="scorpio.copylaradio.com"
REMOTE_PORT=2122
SSH_OPTIONS="-fN -L $COMFYUI_PORT:127.0.0.1:$COMFYUI_PORT"

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

# Fonction pour vérifier si le port est ouvert
check_port() {
    if lsof -i :$COMFYUI_PORT >/dev/null; then
        echo "Le port $COMFYUI_PORT est déjà ouvert."
        return 0
    else
        echo "Le port $COMFYUI_PORT n'est pas ouvert."
        return 1
    fi
}

# Fonction pour établir le tunnel SSH
establish_tunnel() {
    echo "Tentative d'établissement du tunnel SSH..."
    if ssh $SSH_OPTIONS $REMOTE_USER@$REMOTE_HOST -p $REMOTE_PORT; then
        echo "Tunnel SSH établi avec succès."
        return 0
    else
        echo "Échec de l'établissement du tunnel SSH."
        return 1
    fi
}

# Fonction pour fermer le tunnel SSH
close_tunnel() {
    echo "Fermeture du tunnel SSH..."
    # Trouver le processus SSH utilisant le port local
    PID=$(lsof -t -i :$COMFYUI_PORT)
    if [ -z "$PID" ]; then
        echo "Aucun tunnel SSH trouvé sur le port $COMFYUI_PORT."
        return 1
    else
        kill $PID
        if [ $? -eq 0 ]; then
            echo "Tunnel SSH fermé avec succès."
            return 0
        else
            echo "Échec de la fermeture du tunnel SSH."
            return 1
        fi
    fi
}

# Vérification des arguments
if [ "$1" == "OFF" ]; then
    close_tunnel
    exit $?
fi

# Vérification initiale du port
if check_port; then
    exit 0
fi

# Tentative d'établissement du tunnel SSH
if establish_tunnel; then
    exit 0
else
    echo "Veuillez vérifier les paramètres SSH et réessayer."
    exit 1
fi

# Vérifie si le prompt est fourni en argument
if [ -z "$1" ]; then
  echo "Usage: $0 <prompt>"
  exit 1
fi

. "${MY_PATH}/my.sh"

PROMPT="$1"

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
  local prompt_json=$(jq -n --arg prompt "$PROMPT" '{text: $prompt}')

  # Mettre à jour le premier CLIPTextEncode
  jq --argjson prompt_obj "$prompt_json" \
     '.nodes[] | select(.type == "CLIPTextEncode") | .widgets_values[0] = $prompt_obj.text' \
     "$WORKFLOW_FILE" > temp_workflow.json

  echo "Prompt mis à jour dans le fichier JSON temporaire temp_workflow.json "
}

# Fonction pour envoyer le workflow à l'API ComfyUI
send_workflow() {
  echo "Envoi du workflow à l'API ComfyUI..."
  local data
  data=$(jq -c . "temp_workflow.json")
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
  if [ -z "$prompt_id" ] ; then
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

  echo "Surveillance de la progression avec l'ID : $prompt_id"

  while true; do
    local progress_response
    progress_response=$(curl -s "$progress_url")

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
        break
      else
         echo "Progression : $current/$total"
        sleep 1
      fi
    else
       echo "Erreur lors de la récupération de la progression."
      echo "$progress_response"
       break
    fi
  done
}

get_image_result() {
  local prompt_id="$1"
  local history_url="$COMFYUI_URL/history/$prompt_id"

  local history_response
  history_response=$(curl -s "$history_url")

  if echo "$history_response" | jq -e '. != null'; then
    local node_id
    node_id=$(echo "$history_response" | jq -r 'keys[0]')

     local image_filename
    image_filename=$(echo "$history_response" | jq -r ".[\"$node_id\"].outputs.\"7\"[0].filename")

    local image_url
    image_url="$COMFYUI_URL/view/$image_filename"

    echo "Image générée : $image_url"
    local output_image="output.png"
    curl -s -o "$output_image" "$image_url"
     echo "Image saved in $output_image"

  else
      echo "Erreur lors de la récupération de l'historique."
      echo "$history_response"
    fi
}

# Main script
check_comfyui_port
if [ $? -ne 0 ]; then
    exit 1
fi

update_prompt
send_workflow
rm temp_workflow.json
