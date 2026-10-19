#!/bin/bash
################################################################################
## gpu_room.sh — avant de SOUMETTRE un job à ComfyUI : Ollama doit laisser la place
## (la RTX 3090 est partagée ; un modèle Ollama résident peut faire planter le job
## ou le GPU). Sourcé (ne s'exécute pas) par les générateurs ; voir IA/gpu_headroom.py.
##
##   gpu_make_room <Go de VRAM de pointe estimés> <étiquette> || exit 1
##
## Si Ollama garde trop de VRAM, ses modèles sont déchargés (du plus gros au plus petit,
## après leurs requêtes en cours) ; échec = « ERROR:<étiquette>:gpu_busy » sur stderr.
## Les estimations passées par chaque script sont PRUDENTES mais non mesurées : GPU_NEED_OVERRIDE=<Go>
## les remplace pour un lancement. GPU_HEADROOM_OFF=1 désactive ; GPU_ALLOW_OLLAMA_UNLOAD=0 interdit de décharger.
################################################################################
## GPU_ROOM_TTL=<s> : ne revérifie pas plus d'une fois toutes les <s> secondes dans CE processus (lots de photos de faceid.sh).
gpu_make_room() {
  local need="${GPU_NEED_OVERRIDE:-$1}" label="${2:-comfyui}"
  local now; now=$(date +%s)
  if [ "${GPU_ROOM_TTL:-0}" -gt 0 ] && [ $(( now - ${_GPU_ROOM_LAST:-0} )) -lt "$GPU_ROOM_TTL" ]; then return 0; fi
  local py; py="$(dirname "${BASH_SOURCE[0]}")/../../gpu_headroom.py"
  if [ ! -f "$py" ]; then
    echo "ERROR:$label:gpu_headroom.py introuvable ($py) : place en VRAM non vérifiée" >&2
    return 1
  fi
  python3 "$py" comfy-room --need-gb "$need" --label "$label" >&2 \
    || { echo "ERROR:$label:gpu_busy" >&2; return 1; }
  _GPU_ROOM_LAST=$now
}

## ── Mesure des jobs ComfyUI (IA/ollama_metrics.py, kind « comfy » → ~/.zen/log/ollama_calls_*.jsonl) ──────────
## gpu_comfy_watch <étiquette> <prompt_id>  : à appeler juste après la soumission à /prompt. Lance un observateur DÉTACHÉ
##   (setsid nohup) qui suit /history/<id> et enregistre exec_ms / queue_ms / wall_ms / erreur (OOM compris) à la fin du job ;
##   ne change rien à l'attente du script. Erreurs de l'observateur : ~/.zen/log/comfy_watch.log.
gpu_comfy_watch() {
  [ "${OLLAMA_METRICS_OFF:-0}" = "1" ] && return 0
  [ -z "$2" ] || [ "$2" = "null" ] && return 0
  local py; py="$(dirname "${BASH_SOURCE[0]}")/../../ollama_metrics.py"
  if [ ! -f "$py" ]; then
    echo "WARN:$1:ollama_metrics.py introuvable ($py) : job $2 non mesuré" >&2
    return 0
  fi
  mkdir -p "$HOME/.zen/log"
  setsid nohup python3 "$py" comfy --label "$1" --prompt-id "$2" >> "$HOME/.zen/log/comfy_watch.log" 2>&1 < /dev/null &
}

## gpu_comfy_record_inline <étiquette> <prompt_id> <json /history/<id>> : pour les lots (faceid.sh : des milliers de jobs de
##   ~0,8 s, un processus Python par photo serait disproportionné) — la ligne est construite par jq depuis l'historique déjà lu.
gpu_comfy_record_inline() {
  [ "${OLLAMA_METRICS_OFF:-0}" = "1" ] && return 0
  mkdir -p "$HOME/.zen/log"
  jq -nc --arg label "$1" --arg id "$2" --argjson h "${3:-null}" --arg station "${IPFSNODEID:-$(hostname)}" \
         --arg source "${OLLAMA_SOURCE:-$1}" '
    ($h[$id] // {}) as $e | ($e.status.messages // []) as $m |
    ([$m[] | select(.[0] == "execution_start") | .[1].timestamp | tonumber] | first) as $s |
    ([$m[] | select(.[0] == "execution_success" or .[0] == "execution_error" or .[0] == "execution_interrupted") | .[1].timestamp | tonumber] | first) as $f |
    (try ($e.prompt[3].create_time | tonumber) catch null) as $c |
    ([$m[] | select(.[0] == "execution_error") | .[1] | ((.exception_type // "") + ": " + (.exception_message // "") | .[0:160])] | last) as $err |
    {ts: (now | strflocaltime("%Y-%m-%dT%H:%M:%S")), station: $station, source: $source, kind: "comfy", model: $label,
     ok: ($e.status.status_str == "success"),
     wall_ms: (if $f != null and $c != null then $f - $c else null end),
     exec_ms: (if $s != null and $f != null then $f - $s else null end),
     queue_ms: (if $s != null and $c != null then ([$s - $c, 0] | max) else null end),
     nodes: (try ($e.prompt[2] | length) catch null), error: $err, pid: 0}
    | with_entries(select(.value != null))' >> "$HOME/.zen/log/ollama_calls_$(date +%Y%m%d).jsonl" 2>/dev/null \
    || echo "WARN:$1:mesure du job $2 non enregistrée" >&2
}
