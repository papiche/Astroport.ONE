#!/bin/bash
# Dependencies : jq ffmpeg ffprobe ipfs qrencode (+ playwright dans ~/.astro pour screen/card)
#### generate_scene.sh : storyboard JSON → vidéo multi-plans (MiniMax H3) assemblée en 720p
#
# Usage: generate_scene.sh [-w workdir] [-c] [-i index] <storyboard.json> [udrive_path]
#   -w  répertoire de travail (défaut $SCENES_DIR/scene_*  (~/.zen/workspace/scenes), hors de ~/.zen/tmp
#       que le nettoyage d'Astroport vide) ; relancer avec le même -w reprend la scène :
#       acteurs, plans et captures déjà rendus ne sont pas recalculés.
#   -c  mode acteurs seuls : prépare/rafraîchit .cast (banque de personnages) sans
#       rendre aucun plan ; <storyboard.json> n'a alors pas besoin de .shots.
#   -i  ne (re)calcule que le plan d'index INDEX (0-based) et s'arrête (pas de finition ni
#       d'assemblage) ; utiliser avec le même -w qu'une scène existante pour reprendre
#       exactement son cache (acteurs, autres plans déjà rendus inchangés).
# Sortie stdout : URL IPFS de la vidéo finale (ou chemin du fichier si IPFS échoue)
# Codes de sortie : 0 ok, 1 erreur, 2 storyboard invalide, 3 ComfyUI non équipé, 4 timeout
#
# Storyboard (exemples : storyboard*.example.json, storyboards/*.json) :
# {
#   "ratio": "16:9", "megapixels": 0.4, "steps": 10, "style": "vhs", "height": 720, "seed": 42,
#   "cast": {
#     "lea": {"image_prompt": "portrait…",  "voice_line": "phrase FR de ~8 s"},
#     "malik": {"image": "/portrait.png", "voice": "/voix_10s.wav"},
#     "ana":   {"image_prompt": "…", "voice_design": "warm low-pitched woman in her 50s, slow", "voice_line": "…"}
#   },
#   "shots": [
#     {"image_prompt": "...", "prompt": "...", "duration": 5},  image générée (generate_image.sh) puis animée
#     {"continue": true,      "prompt": "...", "duration": 5},  repart de la dernière image du plan précédent
#     {"image": "/chemin.png", "prompt": "...", "duration": 5}, image fournie
#     {"prompt": "...", "duration": 5}                          text-to-video
#     {"cast": ["lea"], "prompt": "Lea ... says: \"...\""}       acteur(s) : même visage et même voix (ref2va)
#     {"screen": "http://127.0.0.1:54321/g1", "presenter": "lea", "prompt": "Lea says: \"...\""}
#                                                               capture d'écran nette (défilement/zoom) +
#                                                               présentateur en incrustation ronde
#     {"card": {"title": "...", "links": [{"label": "...", "url": "https://..."}]}, "duration": 8}
#                                                               carton final avec QR codes
#   ]
# }
# Acteurs ("cast", ref2va) : portrait sur fond neutre (fourni ou généré par Z-Image)
# et voix de référence : fournie ("voice"), inventée par Qwen3-TTS VoiceDesign d'après
# "voice_design" (description du timbre, âge, ton : une voix distincte par acteur), ou à
# défaut créée par MiniMax en faisant dire "voice_line" au portrait. Dans un plan "cast", le script ajoute en tête du prompt la phrase qui lie
# chaque nom à <Picture k>/<Audio k> : écrire ensuite le prompt avec les noms.
# N'utiliser le visage ou la voix d'une personne réelle qu'avec son consentement.
#
# Banque de personnages (~/.zen/workspace/characters/<nom>/, hors ~/.zen/tmp : jamais
# purgée) : portrait.png et voice.wav sont enregistrés là après une première génération,
# et repris tels quels par tout storyboard suivant qui déclare le même nom — même un
# simple "nom": {} suffit alors (pas besoin de redonner image_prompt/voice_line).
# "refresh": true dans l'entrée .cast force une régénération et remplace la banque.
#
# Champs de plan optionnels :
#   voiceover  narration (texte FR) lue par Orpheus TTS (voix globale "voice" :
#              "amelie" | "pierre"), mixée sur l'ambiance du plan ; la durée est
#              allongée si la phrase ne tient pas, et MiniMax reçoit « no speech ».
#   title      texte incrusté (bas de l'image) pendant tout le plan, après le style.
#   motion     plan "screen" : "scroll" (défaut si la page dépasse l'écran) | "zoom"
#   screen_js  plan "screen" : JavaScript (chaîne ou liste) exécuté avant la capture,
#              ex. cliquer un onglet : "document.querySelector('#tab').click()"
# Paramètres globaux, tous optionnels (défauts = priorité à la vitesse sur RTX 3090,
# ~5 min par plan de 5 s) :
#   ratio      "16:9" | "9:16" (vertical smartphone, Reels/Shorts) | "4:3" | "1:1"...
#   megapixels 0.4 (864x480 en 16:9), 0.25 ≈ 360p ; steps 10 ;
#   ref_steps  steps des plans avec acteur (ref2va), défaut 20 : en dessous, artefacts
#   Les répliques passent par lib/prononciation_fr.json (orthographe phonétique des
#   sigles : MULTIPASS, NOSTR, UMAP…) : y ajouter tout mot mal prononcé.
#   height     petit côté de la vidéo finale, défaut 720 (1280x720 / 720x1280)
#   style      "clean" (défaut) ou "vhs" (plans IA seulement : écrans et cartons restent nets)
#   upscale    facteur SeedVR2 (lent) ; défaut 1 = aucun. OOM au-delà de ~3 s à 0.4 MP.
#   seed       chaque plan utilise seed + index : scène reproductible.
# Un plan peut surcharger "seed" et "duration" (5 à 10 s conseillé).
#
# Écrire les prompts :
#  - une action par plan ; décrire le son : voix (langue, ton, texte exact entre
#    guillemets), bruitages, musique — sinon le plan est muet ;
#  - un texte parlé tient en ~2,5 mots/s : 5 s ≈ 12 mots ;
#  - gros plans pour les visages : ils restent nets même en basse résolution ;
#  - pas de texte à l'écran demandé au modèle (illisible) : utiliser "title" ou "card".

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
# FFMPEG (avec drawtext), COMFY_PY, ASTRO_PY, SCENES_DIR : voir lib/env.sh
. "$MY_PATH/lib/env.sh"

usage() {
  sed -n '5,13p' "$0" | sed 's/^# \{0,1\}//' >&2
  echo >&2
  echo "Pas de storyboard sous la main ? generate_storyboard.sh pose quelques questions et en" >&2
  echo "rédige un avec l'aide d'une IA (Ollama, moteur au choix) :" >&2
  echo "  $MY_PATH/generate_storyboard.sh" >&2
  exit 2
}

WORK_DIR=""
CAST_ONLY=0
SHOT_INDEX=""
while getopts "w:ci:h" opt; do
  case $opt in
    w) WORK_DIR="$OPTARG" ;;
    c) CAST_ONLY=1 ;;
    i) SHOT_INDEX="$OPTARG" ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

STORYBOARD="$1"
UDRIVE_PATH="$2"
[ -f "$STORYBOARD" ] || usage

. "${HOME}/.zen/Astroport.ONE/tools/my.sh"

if [ "$CAST_ONLY" -eq 1 ]; then
  if ! jq -e '.cast | type == "object" and length > 0' "$STORYBOARD" > /dev/null 2>&1; then
    echo "Erreur : -c nécessite un storyboard avec .cast non vide (.shots n'est pas requis)" >&2
    exit 2
  fi
else
  if ! jq -e '.shots | type == "array" and length > 0
              and all(.[]; (.prompt | type) == "string" or (.screen and (.presenter | not)) or .card)' "$STORYBOARD" > /dev/null 2>&1; then
    echo "Erreur : storyboard invalide (chaque plan : .prompt, ou .screen sans présentateur, ou .card)" >&2
    exit 2
  fi
  if jq -e '.shots[0].continue == true' "$STORYBOARD" > /dev/null; then
    echo "Erreur : le premier plan ne peut pas être \"continue\"" >&2
    exit 2
  fi
  missing_cast=$(jq -r '(.cast // {}) as $c | [.shots[] | ((.cast // []) + [.presenter // empty])[] | select($c[.] | not)] | unique | join(" ")' "$STORYBOARD")
  if [ -n "$missing_cast" ]; then
    echo "Erreur : acteur(s) absent(s) de .cast : $missing_cast" >&2
    exit 2
  fi
fi

# Chemins du storyboard portables : $HOME, ${HOME} et $SCENES_DIR sont résolus ici
mkdir -p "$SCENES_DIR"
RESOLVED=$(mktemp "${TMPDIR:-/tmp}/storyboard_XXXXXX.json")
FINISHED_OK=0
# Sortie : le suivi de progression passe en "failed" si le script s'arrête avant la fin
cleanup() {
  local rc=$?
  rm -f "$RESOLVED"
  if [ "$FINISHED_OK" != 1 ] && [ -n "$PROGRESS" ] && [ -d "$WORK_DIR" ]; then
    progress failed -1 "arrêt (code $rc)"
  fi
}
trap cleanup EXIT
jq --arg h "$HOME" --arg s "$SCENES_DIR" \
   'walk(if type == "string" then gsub("\\$\\{?SCENES_DIR\\}?"; $s) | gsub("\\$\\{?HOME\\}?"; $h) else . end)' \
   "$STORYBOARD" > "$RESOLVED" && STORYBOARD="$RESOLVED"

RATIO=$(jq -r '.ratio // "16:9"' "$STORYBOARD")
MEGAPIXELS=$(jq -r '.megapixels // 0.4' "$STORYBOARD")
STEPS=$(jq -r '.steps // 10' "$STORYBOARD")
# ref2va (acteurs) : sous ~20 steps, dérive en dessin, dominante verte ou pseudo-texte
REF_STEPS=$(jq -r '.ref_steps // 20' "$STORYBOARD")
UPSCALE=$(jq -r '.upscale // 1' "$STORYBOARD")
STYLE=$(jq -r '.style // "clean"' "$STORYBOARD")
FINAL_HEIGHT=$(jq -r '.height // 720' "$STORYBOARD")
VOICE=$(jq -r '.voice // "amelie"' "$STORYBOARD")
TTS_URL="http://localhost:5005/v1/audio/speech"
TITLE_FONT=$(fc-match -f '%{file}' 'DejaVu Sans:bold' 2>/dev/null)
BASE_SEED=$(jq -r '.seed // empty' "$STORYBOARD")
[ -z "$BASE_SEED" ] && BASE_SEED=$((RANDOM * RANDOM))
NB_SHOTS=$(jq '(.shots // []) | length' "$STORYBOARD")
if [ -n "$SHOT_INDEX" ]; then
  if ! [[ "$SHOT_INDEX" =~ ^[0-9]+$ ]] || [ "$SHOT_INDEX" -ge "$NB_SHOTS" ]; then
    echo "Erreur : -i $SHOT_INDEX hors plage (0-$((NB_SHOTS - 1)))" >&2
    exit 2
  fi
fi

# Taille exacte de la vidéo finale : petit côté = height, grand côté au ratio (pair)
rw=${RATIO%:*} rh=${RATIO#*:}
if [ "$rw" -ge "$rh" ]; then
  FINAL_H=$FINAL_HEIGHT
  FINAL_W=$(( (FINAL_HEIGHT * rw / rh + 1) / 2 * 2 ))
else
  FINAL_W=$FINAL_HEIGHT
  FINAL_H=$(( (FINAL_HEIGHT * rh / rw + 1) / 2 * 2 ))
fi

# Images de départ générées directement au ratio de la vidéo (~1 MP, multiples de 64)
case "$RATIO" in
  16:9) IMAGE_SIZE=1344x768 ;;  9:16) IMAGE_SIZE=768x1344 ;;
  4:3)  IMAGE_SIZE=1152x896 ;;  3:4)  IMAGE_SIZE=896x1152 ;;
  3:2)  IMAGE_SIZE=1216x832 ;;  2:3)  IMAGE_SIZE=832x1216 ;;
  21:9) IMAGE_SIZE=1536x640 ;;  *)    IMAGE_SIZE=1024x1024 ;;
esac

WORK_DIR="${WORK_DIR:-$SCENES_DIR/scene_$(date +%s)_$(openssl rand -hex 4)}"
mkdir -p "$WORK_DIR"
# Graine tirée au sort : mémorisée dans le répertoire de travail, sinon chaque reprise
# changerait la signature de tous les plans et rien ne serait réutilisé
if ! jq -e '.seed' "$STORYBOARD" > /dev/null; then
  if [ -s "$WORK_DIR/.seed" ]; then BASE_SEED=$(cat "$WORK_DIR/.seed"); else echo "$BASE_SEED" > "$WORK_DIR/.seed"; fi
fi
echo "Scène : $NB_SHOTS plans | ${RATIO} @ ${MEGAPIXELS} MP | ${STEPS} steps | upscale ${UPSCALE} | style ${STYLE} | ${FINAL_W}x${FINAL_H} | seed ${BASE_SEED}" >&2
echo "Répertoire de travail (reprise avec -w) : $WORK_DIR" >&2
SCENE_START=$(date +%s)

# Suivi de progression (lu par l'interface UPlanet/earth/story.html via UPassport) :
# $WORK_DIR/progress.json = {stage, shot, shots, message, started, updated, done:[indices rendus]}
# stages : prepare cast voiceover shot finish assemble done failed
PROGRESS="$WORK_DIR/progress.json"
progress() {  # $1 stage, $2 index du plan (-1 si sans objet), $3 message
  local done_list="" k
  # Mode -i (un seul plan) : un job de progression à 1 plan, indépendant du reste de la scène
  if [ -n "$SHOT_INDEX" ]; then
    [ -s "$WORK_DIR/shot_$(printf "%02d" "$SHOT_INDEX").mp4" ] && done_list="0"
    jq -n --arg st "$1" --argjson i 0 --argjson n 1 --arg m "$3" \
          --argjson t0 "$SCENE_START" --argjson now "$(date +%s)" --argjson d "[${done_list}]" \
          '{stage: $st, shot: $i, shots: $n, message: $m, started: $t0, updated: $now, done: $d}' \
      > "$PROGRESS.tmp" 2>/dev/null && mv "$PROGRESS.tmp" "$PROGRESS"
    return
  fi
  for ((k = 0; k < NB_SHOTS; k++)); do
    [ -s "$WORK_DIR/shot_$(printf "%02d" "$k").mp4" ] && done_list+="$k,"
  done
  jq -n --arg st "$1" --argjson i "${2:--1}" --argjson n "$NB_SHOTS" --arg m "$3" \
        --argjson t0 "$SCENE_START" --argjson now "$(date +%s)" --argjson d "[${done_list%,}]" \
        '{stage: $st, shot: $i, shots: $n, message: $m, started: $t0, updated: $now, done: $d}' \
    > "$PROGRESS.tmp" 2>/dev/null && mv "$PROGRESS.tmp" "$PROGRESS"
}
progress prepare -1 "préparation"

# Voix-off : Qwen3-TTS si le storyboard décrit un "narrator" et que le venv existe (voix
# constante, prononciation du lexique), sinon Orpheus TTS local ou via la constellation
NARRATOR_DESIGN=$(jq -r '.narrator.voice_design // empty' "$STORYBOARD")
NARRATOR_QWEN=0
[ -n "$NARRATOR_DESIGN" ] && [ -n "$QWEN3TTS_PY" ] && NARRATOR_QWEN=1
[ -n "$NARRATOR_DESIGN" ] && [ "$NARRATOR_QWEN" = 0 ] \
  && echo "Attention : narrator ignoré (install/install_qwen3_tts.sh non lancé), repli Orpheus" >&2
if [ "$NARRATOR_QWEN" = 0 ] && jq -e 'any((.shots // [])[]; .voiceover)' "$STORYBOARD" > /dev/null; then
  "$MY_PATH/../services/orpheus.me.sh" > /dev/null 2>&1
  if ! curl -s -o /dev/null -m 10 "http://localhost:5005/docs"; then
    echo "Erreur : Orpheus TTS injoignable (IA/services/orpheus.me.sh)" >&2
    exit 1
  fi
fi

# $1 texte, $2 fichier wav
tts() {
  local code
  code=$(jq -n --arg t "$("$COMFY_PY" "$MY_PATH/lib/pronounce.py" --text "$1")" --arg v "$VOICE" '{model: "orpheus", input: $t, voice: $v, response_format: "wav", speed: 1.0}' \
         | curl -s -m 300 -o "$2" -w "%{http_code}" -H "Content-Type: application/json" --data-binary @- "$TTS_URL")
  [ "$code" = "200" ] && [ -s "$2" ]
}

# $1 prompt, $2 taille LxH, $3 fichier png. Hors de ~/.zen/tmp.media :
# generate_image.sh y efface ses images en sortie.
gen_image() {
  mkdir -p "$HOME/.zen/tmp/scenes"
  local image_dir
  image_dir=$(mktemp -d "$HOME/.zen/tmp/scenes/image_XXXXXX")
  IMAGE_SIZE=$2 "$MY_PATH/generate_image.sh" "$1" "$image_dir" > /dev/null \
    && mv "$(ls -t "$image_dir"/*.png 2>/dev/null | head -n 1)" "$3"
  rm -rf "$image_dir"
  [ -s "$3" ]
}

# $@ arguments de generate_minimax.sh ; sort en propageant son code d'erreur
render() {
  local out="$2"
  "$MY_PATH/generate_minimax.sh" "$@" > /dev/null
  local rc=$?
  if [ $rc -ne 0 ] || [ ! -s "$out" ]; then
    rm -f "$out"
    echo "Erreur : rendu de $(basename "$out") échoué (code $rc). Relancer avec -w $WORK_DIR pour reprendre." >&2
    exit $([ $rc -ne 0 ] && echo $rc || echo 1)
  fi
}

# $1 sortie, $2 seed, $3 prompt, $@ autres arguments de generate_minimax.sh :
# les répliques entre guillemets passent en orthographe phonétique (lib/pronounce.py)
speech_render() {
  local out="$1" seed="$2" prompt="$3"
  shift 3
  render -o "$out" "$@" -S "$seed" "$(python3 "$MY_PATH/lib/pronounce.py" "$prompt")"
}

########################################################################
# Acteurs : portrait neutre + voix de référence, préparés une fois
########################################################################
# Signatures : un acteur ou un plan modifié depuis le dernier rendu est recalculé, les autres sont
# réutilisés (le répertoire -w sert de cache entre les versions d'une même scène)
sig_of() { sha256sum | cut -c1-16; }
declare -A STALE_ACTOR
GLOBAL_SIG=$(printf '%s|' "$RATIO" "$MEGAPIXELS" "$STEPS" "$REF_STEPS" "$UPSCALE" "$STYLE" "$FINAL_HEIGHT" "$BASE_SEED" "$VOICE" \
             "$(jq -c '.narrator // {}' "$STORYBOARD")" | sig_of)
for name in $(jq -r '.cast // {} | keys[]' "$STORYBOARD"); do
  cdir="$WORK_DIR/cast/$name"
  csig=$(jq -c --arg n "$name" '.cast[$n]' "$STORYBOARD" | sig_of)
  if [ -d "$cdir" ] && [ "$(cat "$cdir/.sig" 2>/dev/null)" != "$csig" ]; then
    echo "Acteur $name modifié : portrait et voix refaits" >&2
    rm -rf "$cdir"
    STALE_ACTOR[$name]=1  # la banque de personnages ne doit pas ramener l'ancien visage
  fi
  mkdir -p "$cdir"; echo "$csig" > "$cdir/.sig"
done
prev_stale=0
for ((i = 0; i < NB_SHOTS; i++)); do
  n=$(printf "%02d" "$i")
  ssig=$( { jq -c ".shots[$i]" "$STORYBOARD"; echo "$GLOBAL_SIG"
            for c in $(jq -r "(.shots[$i].cast // []) + [.shots[$i].presenter // empty] | .[]" "$STORYBOARD"); do cat "$WORK_DIR/cast/$c/.sig"; done
          } | sig_of)
  if [ -f "$WORK_DIR/shot_$n.sig" ] && { [ "$(cat "$WORK_DIR/shot_$n.sig")" != "$ssig" ] \
       || { [ "$prev_stale" = 1 ] && jq -e ".shots[$i].continue == true" "$STORYBOARD" > /dev/null; }; }; then
    echo "Plan $n modifié : recalculé" >&2
    rm -f "$WORK_DIR"/{shot,talk,screenclip,mix,part,vo,image,last,card,screen}_"$n".* "$WORK_DIR/title_$n.txt"
    prev_stale=1
  else
    prev_stale=0
  fi
  echo "$ssig" > "$WORK_DIR/shot_$n.sig"
done

# CAST_BANK (voir lib/env.sh) modifiable : les rendus du Studio vidéo IA (UPassport) utilisent
# une banque par rendu, pour ne pas écraser vos propres personnages par ceux d'un paquet
# partagé qui porte le même nom

for name in $(jq -r '.cast // {} | keys[]' "$STORYBOARD"); do
  cdir="$WORK_DIR/cast/$name"
  bdir="$CAST_BANK/$name"
  progress cast -1 "acteur $name"
  mkdir -p "$cdir" "$bdir"
  actor=$(jq -c --arg n "$name" '.cast[$n]' "$STORYBOARD")
  refresh=$(jq -r '.refresh // false' <<< "$actor")
  [ -n "${STALE_ACTOR[$name]}" ] && refresh=true
  # Graine propre à chaque acteur : avec la graine de la scène pour tous, les voix se ressemblaient
  actor_seed=$(jq -r --argjson s "$(( BASE_SEED + $(printf '%s' "$name" | cksum | cut -d' ' -f1) % 100000 ))" '.seed // $s' <<< "$actor")

  # Repli : personnage publié dans la bibliothèque du Studio web (NOSTR/IPFS, Kind 30510)
  # mais absent de cette banque locale — pont CLI/Web (story_asset.py::resolve_character).
  # Seulement en reprise pure (aucune définition propre dans le storyboard) : une vraie
  # définition locale garde toujours la priorité.
  if [ "$refresh" != "true" ] && { [ ! -s "$bdir/portrait.png" ] || [ ! -s "$bdir/voice.wav" ]; } \
     && ! jq -e '.image or .image_prompt or .voice or .voice_line' <<< "$actor" > /dev/null; then
    echo "Acteur $name : recherche dans la bibliothèque du Studio (NOSTR/IPFS)…" >&2
    "$ASTRO_PY" "$HOME/.zen/Astroport.ONE/tools/story_asset.py" resolve-character "$name" --dest "$bdir" > /dev/null 2>&1 \
      && echo "Acteur $name : trouvé dans la bibliothèque, installé dans la banque" >&2
  fi

  # Personnage déjà créé pour une scène précédente : mêmes visage et voix, repris
  # depuis la banque persistante (hors ~/.zen/tmp, jamais purgée par Astroport)
  if [ "$refresh" != "true" ]; then
    if [ -s "$bdir/portrait.png" ] && [ ! -s "$cdir/portrait.png" ] && ! jq -e '.image' <<< "$actor" > /dev/null; then
      cp "$bdir/portrait.png" "$cdir/portrait.png"
      echo "Acteur $name : portrait repris de la banque ($bdir)" >&2
    fi
    if [ -s "$bdir/voice.wav" ] && [ ! -s "$cdir/voice.wav" ] && ! jq -e '.voice' <<< "$actor" > /dev/null; then
      cp "$bdir/voice.wav" "$cdir/voice.wav"
      echo "Acteur $name : voix reprise de la banque ($bdir)" >&2
    fi
  fi

  if [ ! -s "$cdir/portrait.png" ]; then
    if jq -e '.image' <<< "$actor" > /dev/null; then
      cp "$(jq -r '.image' <<< "$actor")" "$cdir/portrait.png" || exit 1
    elif jq -e '.image_prompt' <<< "$actor" > /dev/null; then
      echo "Acteur $name : portrait (Z-Image)" >&2
      gen_image "$(jq -r '.image_prompt' <<< "$actor"), head and shoulders portrait, plain neutral light grey studio background, soft even lighting, looking at the camera" \
        1024x1024 "$cdir/portrait.png" || { echo "Erreur : portrait de $name échoué" >&2; exit 1; }
    else
      echo "Erreur : acteur $name absent de la banque ($bdir) et sans .image/.image_prompt dans le storyboard" >&2
      exit 2
    fi
  fi

  if [ ! -s "$cdir/voice.wav" ]; then
    if jq -e '.voice' <<< "$actor" > /dev/null; then
      "$FFMPEG" -v error -y -i "$(jq -r '.voice' <<< "$actor")" -ac 1 -ar 48000 "$cdir/voice.wav" || exit 1
    elif jq -e '.voice_design' <<< "$actor" > /dev/null && [ -n "$QWEN3TTS_PY" ]; then
      # Voix inventée par Qwen3-TTS VoiceDesign d'après la description : une voix distincte par acteur
      echo "Acteur $name : voix de référence (Qwen3-TTS VoiceDesign)" >&2
      # ~4 Go de VRAM : on libère Ollama et ComfyUI (même GPU) comme le fait lib/comfyui_recovery.sh
      bash "$MY_PATH/../services/ollama.me.sh" FREE > /dev/null 2>&1
      curl -s -m 10 -X POST "http://127.0.0.1:8188/free" -H "Content-Type: application/json" \
           -d '{"unload_models": true, "free_memory": true}' > /dev/null 2>&1
      "$QWEN3TTS_PY" "$MY_PATH/generate_voice.py" -o "$cdir/voice_src.wav" -S "$actor_seed" \
        "$(jq -r '.voice_design' <<< "$actor")" "$(jq -r '.voice_line' <<< "$actor")" > /dev/null \
        && "$FFMPEG" -v error -y -i "$cdir/voice_src.wav" -ac 1 -ar 48000 "$cdir/voice.wav" \
        || { rm -f "$cdir/voice.wav"; echo "Erreur : voix Qwen3-TTS de $name échouée" >&2; exit 1; }
    elif jq -e '.voice_line' <<< "$actor" > /dev/null; then
      jq -e '.voice_design' <<< "$actor" > /dev/null \
        && echo "Attention : voice_design ignoré (install/install_qwen3_tts.sh non lancé), repli MiniMax" >&2
      echo "Acteur $name : voix de référence (MiniMax)" >&2
      line=$(jq -r '.voice_line' <<< "$actor")
      speech_render "$cdir/voice_src.mp4" "$actor_seed" \
        "Close-up: the person looks at the camera and speaks in French in a natural, calm voice, at a relaxed pace: \"$line\" Quiet room, no music, no background noise." \
        -i "$cdir/portrait.png" -r 1:1 -m 0.25 -d 8 -s "$STEPS"
      "$FFMPEG" -v error -y -i "$cdir/voice_src.mp4" -vn -ac 1 -ar 48000 "$cdir/voice.wav" || exit 1
    else
      echo "Erreur : acteur $name absent de la banque ($bdir) et sans .voice/.voice_line dans le storyboard" >&2
      exit 2
    fi
  fi

  # Alimente la banque pour les prochains storyboards (portrait et voix définitifs)
  cp "$cdir/portrait.png" "$bdir/portrait.png"
  cp "$cdir/voice.wav" "$bdir/voice.wav"
  # Mémorise la définition d'origine, sauf reprise pure d'un personnage déjà en banque
  if jq -e '.image_prompt or .image or .voice_line or .voice' <<< "$actor" > /dev/null 2>&1; then
    jq -c 'del(.refresh)' <<< "$actor" > "$bdir/character.json" 2>/dev/null || true
  fi
done

if [ "$CAST_ONLY" -eq 1 ]; then
  echo "Personnage(s) prêt(s) dans la banque ($CAST_BANK) :" >&2
  jq -r '.cast // {} | keys[]' "$STORYBOARD" | sed 's/^/  - /' >&2
  FINISHED_OK=1
  progress done -1 "terminé"
  exit 0
fi

# $1 JSON array de noms → arguments -R/-A et préambule du prompt (variables globales)
cast_refs() {
  REF_ARGS=()
  # ref2va dérive parfois vers l'illustration ou une dominante de couleur : on l'ancre
  REF_INTRO="Photorealistic live-action video footage with natural colors and lighting, not an illustration, not a cartoon, not a poster. "
  local k=1 name
  for name in $(jq -r '.[]' <<< "$1"); do
    REF_ARGS+=(-R "$WORK_DIR/cast/$name/portrait.png" -A "$WORK_DIR/cast/$name/voice.wav")
    REF_INTRO+="Use <Picture $k> as the reference for ${name^}'s face, hair and clothing, and <Audio $k> as the reference for ${name^}'s voice. "
    k=$((k + 1))
  done
}

########################################################################
# Voix-off Qwen3-TTS : toutes les lignes en un seul passage (un chargement de modèle),
# voix du narrateur conçue une fois puis clonée pour chaque plan
########################################################################
if [ "$NARRATOR_QWEN" = 1 ]; then
  vo_lines="$WORK_DIR/vo_lines.json"
  # une ligne par plan à voix-off ; celles déjà synthétisées sont ignorées (reprise)
  todo="[]"
  v_start=0 v_end=$((NB_SHOTS - 1))
  [ -n "$SHOT_INDEX" ] && v_start=$SHOT_INDEX && v_end=$SHOT_INDEX
  for ((i = v_start; i <= v_end; i++)); do
    text=$(jq -r ".shots[$i].voiceover // empty" "$STORYBOARD")
    out="$WORK_DIR/vo_$(printf "%02d" "$i").wav"
    [ -n "$text" ] && [ ! -s "$out" ] \
      && todo=$(jq -c --arg t "$text" --arg o "$out" '. + [{text: $t, out: $o}]' <<< "$todo")
  done
  if [ "$todo" != "[]" ]; then
    progress voiceover -1 "voix-off ($(jq 'length' <<< "$todo") ligne(s))"
    echo "Voix-off : $(jq 'length' <<< "$todo") ligne(s) (Qwen3-TTS)" >&2
    printf '%s' "$todo" > "$vo_lines"
    bash "$MY_PATH/../services/ollama.me.sh" FREE > /dev/null 2>&1
    curl -s -m 10 -X POST "http://127.0.0.1:8188/free" -H "Content-Type: application/json" \
         -d '{"unload_models": true, "free_memory": true}' > /dev/null 2>&1
    narr_ref=$(jq -r '.narrator.ref // empty' "$STORYBOARD")
    "$QWEN3TTS_PY" "$MY_PATH/generate_voice.py" --narrate "$vo_lines" -S "$BASE_SEED" \
      --ref "${narr_ref:-$WORK_DIR/narrator.wav}" --design "$NARRATOR_DESIGN" > /dev/null \
      || { echo "Erreur : voix-off Qwen3-TTS échouée" >&2; exit 1; }
  fi
fi

########################################################################
# Plans
########################################################################
# $1 png, $2 durée, $3 motion, $4 sortie : plan net à la taille finale, sans IA
screen_clip() {
  local img_h
  img_h=$("$FFPROBE" -v error -show_entries stream=height -of csv=p=0 "$1")
  local motion="$3"
  local img_w
  img_w=$("$FFPROBE" -v error -show_entries stream=width -of csv=p=0 "$1")
  local scaled_h=$(( img_h * FINAL_W / img_w ))
  [ -z "$motion" ] && { [ "$scaled_h" -gt $(( FINAL_H * 115 / 100 )) ] && motion=scroll || motion=zoom; }
  local vf
  if [ "$motion" = scroll ] && [ "$scaled_h" -gt "$FINAL_H" ]; then
    # Défilement du haut vers le bas, pause de 0,8 s au début et à la fin
    vf="scale=${FINAL_W}:-2,crop=${FINAL_W}:${FINAL_H}:0:'(ih-${FINAL_H})*min(1,max(0,t-0.8)/($2-1.6))'"
  else
    vf="scale=$((FINAL_W * 2)):$((FINAL_H * 2)):force_original_aspect_ratio=increase,crop=$((FINAL_W * 2)):$((FINAL_H * 2)):0:0"
    vf+=",zoompan=z='1+0.08*on/($2*24)':x='iw/2-(iw/zoom/2)':y='ih/3-(ih/zoom/3)':d=1:s=${FINAL_W}x${FINAL_H}:fps=24"
  fi
  "$FFMPEG" -v error -y -loop 1 -framerate 24 -i "$1" -f lavfi -i anullsrc=r=48000:cl=stereo -t "$2" \
         -vf "${vf},format=yuv420p,setsar=1" -c:v libx264 -preset fast -crf 18 -c:a aac -ar 48000 -ac 2 -shortest "$4"
}

# $1 écran, $2 présentateur (carré), $3 sortie : incrustation ronde en bas à droite,
# avec l'audio du présentateur
pip_compose() {
  local short=$(( FINAL_W < FINAL_H ? FINAL_W : FINAL_H ))
  local p=$(( short * 36 / 100 / 2 * 2 )) m=$(( short / 30 ))
  local ring=$(( p + 8 ))
  "$FFMPEG" -v error -y -i "$1" -i "$2" -filter_complex \
    "[1:v]scale=${p}:${p},format=yuva420p,geq=lum='lum(X,Y)':cb='cb(X,Y)':cr='cr(X,Y)':a='if(lt(hypot(X-W/2,Y-H/2),W/2-1),255,0)'[face];
     color=c=white:s=${ring}x${ring},format=yuva420p,geq=lum='lum(X,Y)':cb='cb(X,Y)':cr='cr(X,Y)':a='if(lt(hypot(X-W/2,Y-H/2),W/2-1),230,0)'[disc];
     [0:v][disc]overlay=W-w-${m}:H-h-${m}:shortest=1[bg];[bg][face]overlay=W-w-$((m + 4)):H-h-$((m + 4)):shortest=1[v]" \
    -map "[v]" -map 1:a -c:v libx264 -preset fast -crf 18 -c:a aac -ar 48000 -ac 2 -shortest "$3"
}

# $1 JSON {title, subtitle?, links:[{label,url}]}, $2 png : carton HTML → capture
# (police du titre réduite pour tenir dans la largeur)
card_image() {
  local html="${2%.png}.html"
  {
    printf '<!doctype html><html><head><meta charset="utf-8"><style>
      body{margin:0;width:%spx;height:%spx;background:radial-gradient(circle at 30%% 20%%,#16324a,#070b10 70%%);
           color:#f2efe6;font-family:"DejaVu Sans",sans-serif;display:flex;flex-direction:column;align-items:center;justify-content:center}
      h1{font-size:%spx;margin:0 0 .2em;letter-spacing:.04em;color:#f5c542;text-align:center}
      h2{font-size:%spx;margin:0 0 1.2em;font-weight:normal;opacity:.85;text-align:center}
      .grid{display:flex;flex-wrap:wrap;gap:%spx;justify-content:center;max-width:94%%}
      .q{background:#fff;color:#111;border-radius:14px;padding:%spx;width:%spx;text-align:center}
      .q svg{width:100%%;height:auto;display:block}
      .l{font-weight:bold;font-size:%spx;margin-top:.4em}.u{font-size:%spx;word-break:break-all;opacity:.7}
      </style></head><body>' "$FINAL_W" "$FINAL_H" "$(jq -r --argjson w "$FINAL_W" --argjson h "$FINAL_H" '(.title // "" | length) as $n | [($h / 12), ($w * 1.2 / ([$n, 1] | max))] | min | floor' <<< "$1")" $((FINAL_H / 28)) $((FINAL_H / 30)) $((FINAL_H / 60)) \
      $(( (FINAL_W < FINAL_H ? FINAL_W * 38 / 100 : FINAL_H * 30 / 100) )) $((FINAL_H / 42)) $((FINAL_H / 62))
    printf '<h1>%s</h1>' "$(jq -r '.title // ""' <<< "$1" | sed 's/&/\&amp;/g;s/</\&lt;/g')"
    printf '<h2>%s</h2><div class="grid">' "$(jq -r '.subtitle // ""' <<< "$1" | sed 's/&/\&amp;/g;s/</\&lt;/g')"
    jq -c '.links[]?' <<< "$1" | while read -r link; do
      local url label
      url=$(jq -r '.url' <<< "$link")
      label=$(jq -r '.label' <<< "$link" | sed 's/&/\&amp;/g;s/</\&lt;/g')
      printf '<div class="q">%s<div class="l">%s</div><div class="u">%s</div></div>' \
        "$(qrencode -t SVG -m 1 -o - "$url" | sed '1,/<svg/{/<svg/!d}')" "$label" "${url#https://}"
    done
    printf '</div></body></html>'
  } > "$html"
  "$ASTRO_PY" "$MY_PATH/lib/capture_page.py" "$html" "$2" "$FINAL_W" "$FINAL_H" --wait 300
}

SHOT_START=0 SHOT_END=$((NB_SHOTS - 1))
[ -n "$SHOT_INDEX" ] && SHOT_START=$SHOT_INDEX && SHOT_END=$SHOT_INDEX
for ((i = SHOT_START; i <= SHOT_END; i++)); do
  n=$(printf "%02d" "$i")
  shot=$(jq -c ".shots[$i]" "$STORYBOARD")
  shot_file="$WORK_DIR/shot_${n}.mp4"
  duration=$(jq -r '.duration // 5' <<< "$shot")
  seed=$(jq -r --argjson s "$((BASE_SEED + i))" '.seed // $s' <<< "$shot")
  prompt=$(jq -r '.prompt // ""' <<< "$shot")

  if [ -s "$shot_file" ]; then
    echo "Plan $n déjà rendu, ignoré" >&2
    continue
  fi
  progress shot "$i" "plan $((i + 1))/$NB_SHOTS"

  # ---- Carton final ----
  if jq -e '.card' <<< "$shot" > /dev/null; then
    echo "=== Plan $((i + 1))/$NB_SHOTS : carton ===" >&2
    card_image "$(jq -c '.card' <<< "$shot")" "$WORK_DIR/card_${n}.png" || { echo "Erreur : carton $n" >&2; exit 1; }
    screen_clip "$WORK_DIR/card_${n}.png" "$duration" static "$shot_file" || exit 1
    continue
  fi

  # ---- Capture d'écran (+ présentateur) ----
  if jq -e '.screen' <<< "$shot" > /dev/null; then
    echo "=== Plan $((i + 1))/$NB_SHOTS : écran ===" >&2
    src=$(jq -r '.screen' <<< "$shot")
    png="$WORK_DIR/screen_${n}.png"
    if [ ! -s "$png" ]; then
      if [[ "$src" == *://* ]]; then
        js_args=()
        while IFS= read -r code; do js_args+=(--js "$code"); done < <(jq -r '.screen_js // empty | if type == "array" then .[] else . end' <<< "$shot")
        "$ASTRO_PY" "$MY_PATH/lib/capture_page.py" "$src" "$png" "$FINAL_W" "$FINAL_H" --full --wait 6000 "${js_args[@]}" \
          || { echo "Erreur : capture de $src échouée" >&2; exit 1; }
      else
        cp "$src" "$png" || exit 1
      fi
    fi
    presenter=$(jq -r '.presenter // empty' <<< "$shot")
    if [ -n "$presenter" ]; then
      talk="$WORK_DIR/talk_${n}.mp4"
      if [ ! -s "$talk" ]; then
        cast_refs "[\"$presenter\"]"
        speech_render "$talk" "$seed" \
          "${REF_INTRO}Close-up head-and-shoulders shot of ${presenter^} facing the camera against a plain softly lit neutral studio background, talking naturally with small gestures. $prompt" \
          "${REF_ARGS[@]}" -r 1:1 -m 0.2 -d "$duration" -s "$REF_STEPS"
      fi
      duration=$("$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$talk")
      screen_clip "$png" "$duration" "$(jq -r '.motion // empty' <<< "$shot")" "$WORK_DIR/screenclip_${n}.mp4" || exit 1
      pip_compose "$WORK_DIR/screenclip_${n}.mp4" "$talk" "$shot_file" || exit 1
    else
      screen_clip "$png" "$duration" "$(jq -r '.motion // empty' <<< "$shot")" "$shot_file" || exit 1
    fi
    continue
  fi

  # ---- Plan IA (MiniMax) ----
  voiceover=$(jq -r '.voiceover // empty' <<< "$shot")
  if [ -n "$voiceover" ]; then
    vo_file="$WORK_DIR/vo_${n}.wav"
    if [ ! -s "$vo_file" ]; then
      echo "Plan $n : voix-off ($VOICE)" >&2
      tts "$voiceover" "$vo_file" || { rm -f "$vo_file"; echo "Erreur : voix-off du plan $n échouée" >&2; exit 1; }
    fi
    vo_len=$("$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$vo_file")
    # Voix décalée de 0,4 s, 0,4 s de marge en fin de plan
    duration=$(awk -v d="$duration" -v v="$vo_len" 'BEGIN { need = int(v + 0.8 + 0.999); print (need > d ? need : d) }')
    prompt="$prompt Audio: ambient sound effects and soft background music only, no speech, no voices, no singing."
  fi

  args=(-d "$duration" -r "$RATIO" -m "$MEGAPIXELS" -s "$STEPS")
  [ "$UPSCALE" != "1" ] && [ "$UPSCALE" != "0" ] && args+=(-u "$UPSCALE")

  if jq -e '.cast' <<< "$shot" > /dev/null; then
    cast_refs "$(jq -c '.cast' <<< "$shot")"
    args+=("${REF_ARGS[@]}" -s "$REF_STEPS")
    prompt="${REF_INTRO}${prompt}"
  elif jq -e '.continue == true' <<< "$shot" > /dev/null; then
    args+=(-i "$WORK_DIR/last_$(printf "%02d" $((i - 1))).png")
  elif jq -e '.image' <<< "$shot" > /dev/null; then
    args+=(-i "$(jq -r '.image' <<< "$shot")")
  elif jq -e '.image_prompt' <<< "$shot" > /dev/null; then
    first_frame="$WORK_DIR/image_${n}.png"
    if [ ! -s "$first_frame" ]; then
      echo "Plan $n : génération de l'image de départ" >&2
      gen_image "$(jq -r '.image_prompt' <<< "$shot")" "$IMAGE_SIZE" "$first_frame" \
        || { echo "Erreur : génération de l'image du plan $n échouée" >&2; exit 1; }
    fi
    args+=(-i "$first_frame")
  fi

  echo "=== Plan $((i + 1))/$NB_SHOTS (${duration}s) ===" >&2
  speech_render "$shot_file" "$seed" "$prompt" "${args[@]}"

  # Dernière image, point de départ d'un éventuel plan "continue" suivant
  "$FFMPEG" -v error -y -sseof -0.1 -i "$shot_file" -update 1 -frames:v 1 "$WORK_DIR/last_${n}.png"
done

# Mode -i : seul ce plan nous intéresse, pas de finition ni d'assemblage de la scène entière
if [ -n "$SHOT_INDEX" ]; then
  FINISHED_OK=1
  progress done -1 "plan $((SHOT_INDEX + 1)) terminé"
  echo "$WORK_DIR/shot_$(printf "%02d" "$SHOT_INDEX").mp4"
  exit 0
fi

########################################################################
# Finition plan par plan (voix-off, taille exacte, style, titre), puis assemblage
########################################################################
progress finish -1 "finition des plans"
list="$WORK_DIR/concat.txt"
: > "$list"
for ((i = 0; i < NB_SHOTS; i++)); do
  n=$(printf "%02d" "$i")
  shot=$(jq -c ".shots[$i]" "$STORYBOARD")
  src="$WORK_DIR/shot_${n}.mp4"
  part="$WORK_DIR/part_${n}.mp4"

  if [ -s "$WORK_DIR/vo_${n}.wav" ]; then
    "$FFMPEG" -v error -y -i "$src" -i "$WORK_DIR/vo_${n}.wav" -filter_complex \
      "[0:a]volume=0.6[a0];[1:a]aresample=48000,adelay=400:all=1,loudnorm=I=-16:TP=-1.5:LRA=7,asplit=2[vo][sc];[a0][sc]sidechaincompress=threshold=0.03:ratio=10:attack=15:release=350:makeup=1[duck];[duck][vo]amix=inputs=2:duration=first:normalize=0,alimiter=limit=0.95[a]" \
      -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 192k -ar 48000 "$WORK_DIR/mix_${n}.mp4" || exit 1
    src="$WORK_DIR/mix_${n}.mp4"
  fi

  finish_args=(-s "${FINAL_W}x${FINAL_H}")
  if [ "$STYLE" = "vhs" ] && ! jq -e '.screen or .card' <<< "$shot" > /dev/null; then
    finish_args+=(-v)
  fi
  "$MY_PATH/video_finish.sh" "${finish_args[@]}" "$src" "$part" > /dev/null || exit 1

  # Titre incrusté après le style pour rester net
  title=$(jq -r '.title // empty' <<< "$shot")
  if [ -n "$title" ]; then
    printf '%s' "$title" > "$WORK_DIR/title_${n}.txt"
    nchars=$(printf '%s' "$title" | wc -m)
    # En haut de l'image quand un présentateur est incrusté en bas à droite
    title_y="h*0.8-text_h/2"
    jq -e '.presenter' <<< "$shot" > /dev/null && title_y="h*0.07"
    "$FFMPEG" -v error -y -i "$part" \
      -vf "drawtext=fontfile='${TITLE_FONT}':textfile='$WORK_DIR/title_${n}.txt':fontsize='min(h/16,w*1.4/${nchars})':fontcolor=white:borderw=3:bordercolor=black@0.7:x=(w-text_w)/2:y=${title_y}:enable='gte(t,0.5)':alpha='min(1,(t-0.5)/0.6)'" \
      -c:v libx264 -preset fast -crf 20 -pix_fmt yuv420p -c:a copy "$part.titled.mp4" \
      && mv "$part.titled.mp4" "$part" \
      || echo "Attention : titre du plan $n non incrusté (filtre drawtext absent ?)" >&2
  fi
  echo "file '$part'" >> "$list"
done

progress assemble -1 "assemblage"
if [ -n "$UDRIVE_PATH" ] && [ -d "$UDRIVE_PATH" ]; then
  final="$UDRIVE_PATH/scene_$(date +%s).mp4"
else
  final="$WORK_DIR/scene.mp4"
fi
# Plans finis à l'identique (taille, 24 i/s, AAC 48 kHz) → copie ; réencodage en secours
if ! "$FFMPEG" -v error -y -f concat -safe 0 -i "$list" -c copy -movflags +faststart "$final"; then
  echo "Concaténation directe impossible, réencodage..." >&2
  "$FFMPEG" -v error -y -f concat -safe 0 -i "$list" -c:v libx264 -crf 20 -preset fast -c:a aac -b:a 192k \
         -movflags +faststart "$final" || exit 1
fi
total=$("$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$final")
echo "Scène assemblée : $final (${total%.*} s)" >&2

# Énergie de ce rendu (CPU + GPU) d'après le relevé 24/7 de PowerJoular, si présent
if [ -r "${POWER_24H_CSV:-/var/lib/powerjoular/power_24h.csv}" ] \
   && python3 "$MY_PATH/lib/energy_window.py" "$SCENE_START" "$(date +%s)" --json > "$WORK_DIR/energy.json" 2>/dev/null; then
  echo "Énergie du rendu : $(python3 "$MY_PATH/lib/energy_window.py" "$SCENE_START" "$(date +%s)")" >&2
fi

FINISHED_OK=1
progress done -1 "terminé"
# STORY_NO_IPFS=1 : rendu d'un paquet privé, la vidéo ne part pas sur IPFS (UPassport la sert elle-même)
if [ -n "$STORY_NO_IPFS" ]; then echo "$final"; exit 0; fi
ipfs_hash=$(ipfs add -wq "$final" 2>/dev/null | tail -n 1)
if [ -n "$ipfs_hash" ]; then
  echo "$myIPFS/ipfs/$ipfs_hash/$(basename "$final")"
else
  echo "Attention : ajout IPFS échoué" >&2
  echo "$final"
fi
