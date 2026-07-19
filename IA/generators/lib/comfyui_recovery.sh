#!/bin/bash
################################################################################
## comfyui_recovery.sh
## Détection d'erreur d'exécution ComfyUI (OOM GPU notamment) dans l'historique
## /history, et récupération de VRAM avant un unique retry, quand le ComfyUI
## utilisé tourne sur cette station (pas via un tunnel P2P/SSH vers un nœud
## distant du swarm).
##
## Sourcé par : generate_image.sh, generate_music.sh, generate_video.sh,
## image_to_video.sh (tous dans IA/generators/).
## Attend que $COMFYUI_URL et $MY_PATH soient déjà définis par l'appelant.
################################################################################

# Nombre de retries déjà effectués après libération VRAM (anti-boucle infinie)
_COMFYUI_OOM_RETRY_DONE="${_COMFYUI_OOM_RETRY_DONE:-0}"

# Analyse le prompt_data JSON (déjà extrait de /history) et affiche un
# diagnostic si ComfyUI a terminé en erreur.
# $1 : prompt_data (JSON)
# Retour : 0 si erreur OOM GPU détectée, 1 si erreur d'un autre type, 2 si pas d'erreur
comfyui_diagnose_error() {
  local prompt_data="$1"
  local status_str
  status_str=$(echo "$prompt_data" | jq -r '.status.status_str // "unknown"' 2>/dev/null)
  [ "$status_str" != "error" ] && return 2

  local last_error
  last_error=$(echo "$prompt_data" | jq -c '.status.messages[]? | select(.[0]=="execution_error") | .[1]' 2>/dev/null | tail -n 1)
  local node_type exception_type exception_message
  node_type=$(echo "$last_error" | jq -r '.node_type // "?"' 2>/dev/null)
  exception_type=$(echo "$last_error" | jq -r '.exception_type // "?"' 2>/dev/null)
  exception_message=$(echo "$last_error" | jq -r '.exception_message // "?"' 2>/dev/null | head -n 1)

  echo "Erreur d'exécution ComfyUI — nœud $node_type : $exception_type : $exception_message" >&2

  [[ "$exception_type" == *OutOfMemoryError* ]] && return 0
  return 1
}

# Le ComfyUI actuellement utilisé tourne-t-il sur cette station ?
# (fichier écrit par IA/services/comfyui.me.sh lors de la connexion)
_comfyui_is_local() {
  local status_file="$HOME/.zen/tmp/comfyui_connection.status"
  [[ -f "$status_file" ]] || return 1
  local conn_type
  conn_type=$(grep '^CONNECTION_TYPE=' "$status_file" | cut -d= -f2)
  [[ "$conn_type" == "LOCAL" ]]
}

# Libère la VRAM Ollama (modèles chargés partagent souvent le même GPU que
# ComfyUI en LOCAL) puis la VRAM ComfyUI elle-même, pour faire de la place
# avant un retry.
comfyui_free_vram_for_retry() {
  echo "OOM GPU détecté sur ComfyUI LOCAL — libération VRAM Ollama + ComfyUI avant retry..." >&2

  local ollama_me="${MY_PATH}/../services/ollama.me.sh"
  if [[ -f "$ollama_me" ]]; then
    bash "$ollama_me" FREE >&2 2>&1
  fi

  curl -s -X POST "$COMFYUI_URL/free" -H "Content-Type: application/json" \
       -d '{"unload_models": true, "free_memory": true}' >/dev/null 2>&1
  sleep 2
}

# Point d'entrée : à appeler quand la sortie attendue (image/audio/vidéo) est
# introuvable dans prompt_data. Retourne 0 si un retry doit être tenté (VRAM
# libérée sur ComfyUI LOCAL, quota de retry non atteint), 1 sinon.
comfyui_should_retry_after_oom() {
  local prompt_data="$1"
  comfyui_diagnose_error "$prompt_data"
  local diag=$?
  [ "$diag" -ne 0 ] && return 1

  if [ "$_COMFYUI_OOM_RETRY_DONE" -ge 1 ]; then
    echo "Retry déjà tenté après libération VRAM — abandon." >&2
    return 1
  fi

  if ! _comfyui_is_local; then
    echo "ComfyUI distant (P2P/SSH) — pas de VRAM locale à libérer, abandon." >&2
    return 1
  fi

  comfyui_free_vram_for_retry
  _COMFYUI_OOM_RETRY_DONE=1
  return 0
}
