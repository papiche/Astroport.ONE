#!/bin/bash
# Dependencies : jq ffmpeg ffprobe ipfs qrencode (+ playwright dans ~/.astro pour screen/card)
#### generate_scene.sh : storyboard JSON → vidéo multi-plans (MiniMax H3) assemblée en 720p
#
# Usage: generate_scene.sh [-w workdir] [-c] [-i index] [-p coop|private] <storyboard.json> [udrive_path]
#   -w  répertoire de travail (défaut $SCENES_DIR/scene_*  (~/.zen/workspace/scenes), hors de ~/.zen/tmp
#       que le nettoyage d'Astroport vide) ; relancer avec le même -w reprend la scène :
#       acteurs, plans et captures déjà rendus ne sont pas recalculés.
#   -c  mode acteurs seuls : prépare/rafraîchit .cast (banque de personnages) sans
#       rendre aucun plan ; <storyboard.json> n'a alors pas besoin de .shots.
#   -i  ne (re)calcule que le plan d'index INDEX (0-based) et s'arrête (pas de finition ni
#       d'assemblage) ; utiliser avec le même -w qu'une scène existante pour reprendre
#       exactement son cache (acteurs, autres plans déjà rendus inchangés).
#   -p  publie la scène dans la bibliothèque du Studio vidéo IA (story.html) à la fin du rendu :
#       acteurs, scène (nouvelle version si le storyboard a changé), rendu avec ses plans sur IPFS,
#       prises de chaque plan. "coop" : visible des autres Capitaines ; "private" : chiffré, sans IPFS.
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
#     {"image": "/chemin.png" ou "ipfs://CID/nom.png", "prompt": "...", "duration": 5}, image fournie (fichier ou uDRIVE)
#     {"prompt": "...", "duration": 5}                          text-to-video
#     {"cast": ["lea"], "prompt": "Lea ... says: \"...\""}       acteur(s) : même visage et même voix (ref2va)
#     {"screen": "http://127.0.0.1:54321/g1", "presenter": "lea", "prompt": "Lea says: \"...\""}
#                                                               capture d'écran nette (défilement/zoom) +
#                                                               présentateur en incrustation ronde
#     {"video": "ipfs://Qm…", "start": 0, "duration": 6, "title": "…"}
#                                                               séquence vidéo importée (IPFS ou fichier de
#                                                               $SCENES_DIR), remise au format de la scène ;
#                                                               n'importer que du contenu dont on a les droits
#     {"screen": "https://…", "record": {"actions": [{"click": "#go"}, {"mark": true}, {"mouse": [x, y]}, {"wait": 700}]}, "duration": 8}
#                                                               page vivante (simulateur) : enregistrée en vidéo (lib/record_page.py)
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
#   screen_wait plan "screen" : attente après chargement de la page, en ms (défaut 6000 ; 12000 pour une carte qui se charge lentement)
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
PUBLISH_SCOPE=""
while getopts "w:ci:p:h" opt; do
  case $opt in
    w) WORK_DIR="$OPTARG" ;;
    c) CAST_ONLY=1 ;;
    i) SHOT_INDEX="$OPTARG" ;;
    p) PUBLISH_SCOPE="$OPTARG"
       case "$PUBLISH_SCOPE" in coop|private) ;; *) echo "Erreur : -p coop|private" >&2; exit 2 ;; esac ;;
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
              and all(.[]; (.prompt | type) == "string" or (.screen and (.presenter | not)) or .card or ((.video | type) == "string"))' "$STORYBOARD" > /dev/null 2>&1; then
    echo "Erreur : storyboard invalide (chaque plan : .prompt, ou .screen sans présentateur, ou .card, ou .video)" >&2
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

# Prises : chaque plan IA rendu est conservé sous $WORK_DIR/takes/NN/<id>.mp4 avec sa fiche <id>.json
# (qualité brouillon/normal, steps, prompt, signature, CID IPFS). Recommencer un plan après un
# changement de prompt, ou le refaire en qualité normale après un brouillon, n'écrase donc rien.
# IPFS (donc partageable) sauf rendu privé (STORY_NO_IPFS).
# $1 index NN, $2 index numérique, $3 fichier plan, $4 graine, $5 durée demandée
register_take() {
  local n="$1" idx="$2" f="$3" seed="$4" dur="$5" tdir id cid="" quality real
  tdir="$WORK_DIR/takes/$n"; mkdir -p "$tdir"
  id=$(date +%s); while [ -e "$tdir/$id.mp4" ]; do id=$((id + 1)); done
  cp "$f" "$tdir/$id.mp4" || return 0
  [ -z "$STORY_NO_IPFS" ] && cid=$(ipfs add -q "$tdir/$id.mp4" 2>/dev/null | tail -n 1)
  quality=$(jq -r 'if .quality then .quality elif ((.steps // 10) <= 6) then "draft" else "normal" end' "$STORYBOARD")
  real=$("$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$f" 2>/dev/null)
  jq -n --arg id "$id" --arg q "$quality" --arg cid "$cid" --arg sig "$(cat "$WORK_DIR/shot_$n.sig" 2>/dev/null)" \
        --argjson created "$(date +%s)" --argjson idx "$idx" --argjson seed "${seed:-0}" --argjson dur "${real:-0}" \
        --argjson steps "${STEPS:-10}" --argjson ref_steps "${REF_STEPS:-20}" --argjson mp "${MEGAPIXELS:-0.4}" \
        --arg ratio "$RATIO" --slurpfile shot <(jq -c ".shots[$idx]" "$STORYBOARD") \
        '{id: $id, index: $idx, created: $created, quality: $q, steps: $steps, ref_steps: $ref_steps, megapixels: $mp,
          ratio: $ratio, seed: $seed, duration: $dur, sig: $sig, cid: ($cid | if . == "" then null else . end),
          prompt: ($shot[0].prompt // ""), voiceover: ($shot[0].voiceover // null), cast: ($shot[0].cast // [])}' \
    > "$tdir/$id.json" 2>/dev/null || true
}

# Garde-fou de débit : au-delà de ~2,5 mots/s le modèle empâte ou invente des syllabes (charabia). Durée suffisante
# pour dire la réplique (~2,2 mots/s + marge, 15 s max) ; avertit si la réplique dépasse 14 mots. $1 prompt, $2 durée demandée, $3 étiquette du message ;
# durée sur stdout, messages sur stderr.
fit_speech_duration() {
  local nwords need
  nwords=$(python3 "$MY_PATH/lib/pronounce.py" --lines "$1" | tr -s ' ' '\n' | grep -c '[[:alpha:]]')
  need=$(awk -v n="$nwords" 'BEGIN { d = int(n / 2.2 + 1.5); print (d > 15 ? 15 : d) }')
  # Au-delà d'une phrase d'environ 14 mots, le modèle invente de la parole (essai : 12 mots = fidélité 1,00 ; 18 mots = 0,74)
  [ "$nwords" -gt 14 ] && echo "Attention : $3, réplique de $nwords mots > 14 : risque de charabia, à couper en plusieurs plans (une phrase par plan)" >&2
  if [ "$need" -gt "$2" ]; then
    echo "$3 : réplique de $nwords mots, durée portée de ${2} s à ${need} s (débit <= ~2,5 mots/s)" >&2
    echo "$need"
  else
    echo "$2"
  fi
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
        -i "$cdir/portrait.png" -r 1:1 -m 0.25 \
        -d "$(awk -v n="$(wc -w <<< "$line")" 'BEGIN { d = int(n / 2.2 + 1.5); if (d < 6) d = 6; if (d > 12) d = 12; print d }')" -s "$STEPS"
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

# $1 référence (CID IPFS, ipfs://CID[/fichier] tel que listé par le uDRIVE, /ipfs/CID, ou fichier sous $SCENES_DIR / le répertoire de
# travail), $2 fichier de sortie. Pas d'URL http arbitraire : un storyboard partagé ne doit pas pouvoir
# faire télécharger n'importe quoi à la station.
import_video() {
  local ref="$1" out="$2" cid p
  [ -s "$out" ] && return 0
  case "$ref" in
    ipfs://*|/ipfs/*|Qm*|bafy*)
      cid="${ref#ipfs://}"; cid="${cid#/ipfs/}"
      # CID puis chemin éventuel (uDRIVE : "CID/nom de fichier.mp4", espaces et accents permis ; pas de « .. »)
      [[ "$cid" == *..* ]] && return 1
      [[ "$cid" =~ ^(Qm[1-9A-HJ-NP-Za-km-z]{44}|bafy[a-z2-7]{50,})(/[^/[:cntrl:]]+)*$ ]] || return 1
      if timeout 600 ipfs cat "$cid" > "$out.part" 2>/dev/null && [ -s "$out.part" ]; then mv "$out.part" "$out"; else rm -f "$out.part"; return 1; fi ;;
    *)
      p="${ref//\$SCENES_DIR/$SCENES_DIR}"; p="${p//\$\{SCENES_DIR\}/$SCENES_DIR}"
      [[ "$p" == *..* ]] && return 1
      case "$p" in "$SCENES_DIR"/*|"$WORK_DIR"/*) [ -f "$p" ] && cp "$p" "$out" || return 1 ;; *) return 1 ;; esac ;;
  esac
  local sel=v; [ "$3" = audio ] && sel=a
  [ -n "$("$FFPROBE" -v error -select_streams "$sel" -show_entries stream=index -of csv=p=0 "$out" | head -1)" ] \
    || { rm -f "$out"; return 1; }
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
  # Nouvelle prise demandée par le Studio (plan seul) : graine décalée, sinon on referait exactement le même plan
  [ -n "$SHOT_INDEX" ] && [ -n "$SHOT_SEED_SHIFT" ] && seed=$((seed + SHOT_SEED_SHIFT))

  if [ -s "$shot_file" ]; then
    echo "Plan $n déjà rendu, ignoré" >&2
    continue
  fi
  progress shot "$i" "plan $((i + 1))/$NB_SHOTS"

  # ---- Voix-off du narrateur (tous types de plan : IA, capture d'écran, carton, vidéo importée) ----
  # Synthèse, puis durée du plan portée au temps nécessaire. Un plan « écran » avec présentateur garde la parole du
  # présentateur : la voix-off y est ignorée.
  voiceover=$(jq -r '.voiceover // empty' <<< "$shot")
  jq -e '.presenter' <<< "$shot" > /dev/null && voiceover=""
  if [ -n "$voiceover" ]; then
    vo_file="$WORK_DIR/vo_${n}.wav"
    if [ ! -s "$vo_file" ]; then
      echo "Plan $n : voix-off ($VOICE)" >&2
      tts "$voiceover" "$vo_file" || { rm -f "$vo_file"; echo "Erreur : voix-off du plan $n échouée" >&2; exit 1; }
    fi
    vo_len=$("$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$vo_file")
    # Voix décalée de 0,4 s, 0,4 s de marge en fin de plan
    duration=$(awk -v d="$duration" -v v="$vo_len" 'BEGIN { need = int(v + 0.8 + 0.999); print (need > d ? need : d) }')
  fi

  # ---- Carton final ----
  if jq -e '.card' <<< "$shot" > /dev/null; then
    echo "=== Plan $((i + 1))/$NB_SHOTS : carton ===" >&2
    card_image "$(jq -c '.card' <<< "$shot")" "$WORK_DIR/card_${n}.png" || { echo "Erreur : carton $n" >&2; exit 1; }
    screen_clip "$WORK_DIR/card_${n}.png" "$duration" static "$shot_file" || exit 1
    continue
  fi

  # ---- Séquence vidéo importée (IPFS) ----
  if jq -e '(.video | type) == "string"' <<< "$shot" > /dev/null; then
    echo "=== Plan $((i + 1))/$NB_SHOTS : vidéo importée ===" >&2
    vsrc=$(jq -r '.video' <<< "$shot")
    vfile="$WORK_DIR/import_${n}.mp4"
    import_video "$vsrc" "$vfile" || { echo "Erreur : vidéo du plan $n introuvable ou illisible ($vsrc)" >&2; exit 1; }
    vstart=$(jq -r '.start // 0' <<< "$shot")
    vlen=$(jq -r '.duration // empty' <<< "$shot"); [ -n "$vlen" ] && vlen=$duration; [ -z "$vlen" ] && vlen=120
    if [ -n "$("$FFPROBE" -v error -select_streams a -show_entries stream=index -of csv=p=0 "$vfile" | head -1)" ]; then
      vin=(-ss "$vstart" -i "$vfile"); vmap=(-map 0:v -map 0:a)
    else
      vin=(-ss "$vstart" -i "$vfile" -f lavfi -i anullsrc=r=48000:cl=stereo); vmap=(-map 0:v -map 1:a)
    fi
    "$FFMPEG" -v error -y "${vin[@]}" -t "$vlen" "${vmap[@]}" \
      -vf "scale=${FINAL_W}:${FINAL_H}:force_original_aspect_ratio=increase:flags=lanczos,crop=${FINAL_W}:${FINAL_H},setsar=1,fps=24,format=yuv420p" \
      -c:v libx264 -preset fast -crf 18 -c:a aac -ar 48000 -ac 2 -shortest "$shot_file" \
      || { echo "Erreur : mise au format de la vidéo du plan $n échouée" >&2; exit 1; }
    "$FFMPEG" -v error -y -sseof -0.1 -i "$shot_file" -update 1 -frames:v 1 "$WORK_DIR/last_${n}.png"
    continue
  fi

  # ---- Capture d'écran (+ présentateur) ----
  if jq -e '.screen' <<< "$shot" > /dev/null; then
    echo "=== Plan $((i + 1))/$NB_SHOTS : écran ===" >&2
    src=$(jq -r '.screen' <<< "$shot")
    # Page vivante (simulateur, animation) : enregistrement vidéo du navigateur avec des actions scriptées
    # {"screen": url, "record": {"wait": 4000, "actions": [{"click": "#start"}, {"mark": true}, {"mouse": [x, y]}, {"wait": 700}]}}
    if jq -e '.record' <<< "$shot" > /dev/null; then
      echo "Plan $n : enregistrement de la page animée ($duration s)" >&2
      "$ASTRO_PY" "$MY_PATH/lib/record_page.py" "$src" "$shot_file" "$FINAL_W" "$FINAL_H" --duration "$duration" \
        --wait "$(jq -r '.record.wait // 4000' <<< "$shot")" --actions "$(jq -c '.record.actions // []' <<< "$shot")" > /dev/null \
        || { echo "Erreur : enregistrement de $src échoué" >&2; exit 1; }
      continue
    fi
    png="$WORK_DIR/screen_${n}.png"
    if [ ! -s "$png" ]; then
      if [[ "$src" == *://* ]]; then
        js_args=()
        while IFS= read -r code; do js_args+=(--js "$code"); done < <(jq -r '.screen_js // empty | if type == "array" then .[] else . end' <<< "$shot")
        "$ASTRO_PY" "$MY_PATH/lib/capture_page.py" "$src" "$png" "$FINAL_W" "$FINAL_H" --full --wait "$(jq -r '.screen_wait // 6000' <<< "$shot")" "${js_args[@]}" \
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
        duration=$(fit_speech_duration "$prompt" "$duration" "Plan $n (présentateur)")
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
  if [ -n "$voiceover" ]; then
    prompt="$prompt Audio: ambient sound effects and soft background music only, no speech, no voices, no singing."
  fi

  # Plan avec acteur : la durée doit laisser le temps de dire la réplique
  jq -e '.cast' <<< "$shot" > /dev/null && duration=$(fit_speech_duration "$prompt" "$duration" "Plan $n")

  args=(-d "$duration" -r "$RATIO" -m "$MEGAPIXELS" -s "$STEPS")
  [ "$UPSCALE" != "1" ] && [ "$UPSCALE" != "0" ] && args+=(-u "$UPSCALE")

  if jq -e '.cast' <<< "$shot" > /dev/null; then
    cast_refs "$(jq -c '.cast' <<< "$shot")"
    args+=("${REF_ARGS[@]}" -s "$REF_STEPS")
    prompt="${REF_INTRO}${prompt}"
  elif jq -e '.continue == true' <<< "$shot" > /dev/null; then
    args+=(-i "$WORK_DIR/last_$(printf "%02d" $((i - 1))).png")
  elif jq -e '.image' <<< "$shot" > /dev/null; then
    start_img=$(jq -r '.image' <<< "$shot")
    case "$start_img" in
      ipfs://*|/ipfs/*|Qm*|bafy*)
        # Image de départ prise dans le uDRIVE (lien IPFS « CID/nom ») : téléchargée puis remise au format du plan
        sfile="$WORK_DIR/startimg_${n}.png"
        if [ ! -s "$sfile" ]; then
          import_video "$start_img" "$WORK_DIR/startimg_${n}.raw" \
            || { echo "Erreur : image de départ du plan $n introuvable ou illisible ($start_img)" >&2; exit 1; }
          "$FFMPEG" -v error -y -i "$WORK_DIR/startimg_${n}.raw" -frames:v 1 \
            -vf "scale=${IMAGE_SIZE%x*}:${IMAGE_SIZE#*x}:force_original_aspect_ratio=increase:flags=lanczos,crop=${IMAGE_SIZE%x*}:${IMAGE_SIZE#*x}" "$sfile" \
            || { echo "Erreur : image de départ du plan $n inutilisable" >&2; exit 1; }
        fi
        start_img="$sfile" ;;
    esac
    args+=(-i "$start_img")
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
  register_take "$n" "$i" "$shot_file" "$seed" "$duration"

  # Dernière image, point de départ d'un éventuel plan "continue" suivant
  "$FFMPEG" -v error -y -sseof -0.1 -i "$shot_file" -update 1 -frames:v 1 "$WORK_DIR/last_${n}.png"
done

########################################################################
# Finition plan par plan (voix-off, taille exacte, style, titre), puis assemblage
########################################################################
# Loudness intégrée (LUFS) de la piste audio de $1 ; vide si illisible
lufs() { "$FFMPEG" -nostats -hide_banner -i "$1" -vn -af ebur128=peak=true -f null - 2>&1 \
         | awk '/Summary/ { s = 1 } s && /^ *I:/ { print $2; exit }'; }
# Gain (dB) pour passer de $1 LUFS à $2 LUFS, borné à ±12 dB (piste muette : 0)
gain_db() { awk -v c="$1" -v t="$2" 'BEGIN { if (c == "" || c < -60) { print 0; exit } g = t - c; if (g > 12) g = 12; if (g < -12) g = -12; printf "%.1f", g }'; }
# Niveau cible : ambiance MiniMax -20 LUFS sous la voix-off, voix-off -16 LUFS, plans finis -16 LUFS
BED_LUFS=-20; VO_LUFS=-16; SHOT_LUFS=-16

progress finish -1 "finition des plans"
list="$WORK_DIR/concat.txt"
PARTS=(); PLEN=()
# Mode -i : seul ce plan nous intéresse ; on le finit (voix-off, volume, titre) pour pouvoir le juger tel qu'il sera
# dans le film, mais on ne touche ni à la liste d'assemblage ni aux autres plans.
F_START=0; F_END=$((NB_SHOTS - 1))
if [ -n "$SHOT_INDEX" ]; then F_START=$SHOT_INDEX; F_END=$SHOT_INDEX; else : > "$list"; fi
for ((i = F_START; i <= F_END; i++)); do
  n=$(printf "%02d" "$i")
  shot=$(jq -c ".shots[$i]" "$STORYBOARD")
  src="$WORK_DIR/shot_${n}.mp4"
  part="$WORK_DIR/part_${n}.mp4"

  if [ -s "$WORK_DIR/vo_${n}.wav" ]; then
    # Ambiance MiniMax ramenée à BED_LUFS (niveaux très inégaux d'un plan à l'autre), voix-off à VO_LUFS.
    # Ducking léger (≈5 dB sous la voix, ratio 2) : l'ambiance reste audible au lieu d'être écrasée.
    # La voix et son side-chain sont complétées par du silence (apad) puis coupées à la durée du plan :
    # sidechaincompress s'arrête sinon à la fin de la voix-off et la piste audio est tronquée.
    vdur=$("$FFPROBE" -v error -select_streams v -show_entries stream=duration -of csv=p=0 "$src" | head -1)
    bed_gain=$(gain_db "$(lufs "$src")" "$BED_LUFS")
    "$FFMPEG" -v error -y -i "$src" -i "$WORK_DIR/vo_${n}.wav" -filter_complex \
      "[0:a]aresample=48000,volume=${bed_gain}dB,apad,atrim=0:${vdur}[a0];[1:a]aresample=48000,adelay=400:all=1,loudnorm=I=${VO_LUFS}:TP=-1.5:LRA=7,aresample=48000,apad,atrim=0:${vdur},asplit=2[vo][sc];[a0][sc]sidechaincompress=threshold=0.1:ratio=2:attack=20:release=500:makeup=1[duck];[duck][vo]amix=inputs=2:duration=first:normalize=0,alimiter=limit=0.95[a]" \
      -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 192k -ar 48000 "$WORK_DIR/mix_${n}.mp4" || exit 1
    src="$WORK_DIR/mix_${n}.mp4"
  fi

  finish_args=(-s "${FINAL_W}x${FINAL_H}")
  if [ "$STYLE" = "vhs" ] && ! jq -e '.screen or .card' <<< "$shot" > /dev/null; then
    finish_args+=(-v)
  fi
  "$MY_PATH/video_finish.sh" "${finish_args[@]}" "$src" "$part" > /dev/null || exit 1

  # Volume homogène d'un plan à l'autre + fondus de 40 / 80 ms aux raccords (pas de clic ni de saut de niveau)
  pdur=$("$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$part")
  pgain=$(gain_db "$(lufs "$part")" "$SHOT_LUFS")
  fout=$(awk -v d="$pdur" 'BEGIN { printf "%.3f", (d > 0.2 ? d - 0.08 : 0) }')
  "$FFMPEG" -v error -y -i "$part" -c:v copy \
    -af "volume=${pgain}dB,alimiter=limit=0.95,afade=t=in:d=0.04,afade=t=out:st=${fout}:d=0.08" \
    -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart "$part.norm.mp4" \
    && mv "$part.norm.mp4" "$part" \
    || echo "Attention : volume du plan $n non normalisé" >&2

  # Titre incrusté après le style pour rester net
  title=$(jq -r '.title // empty' <<< "$shot")
  if [ -n "$title" ]; then
    printf '%s' "$title" > "$WORK_DIR/title_${n}.txt"
    nchars=$(printf '%s' "$title" | wc -m)
    # En haut de l'image quand un présentateur est incrusté en bas à droite
    title_y="h*0.8-text_h/2"
    jq -e '.presenter' <<< "$shot" > /dev/null && title_y="h*0.07"
    "$FFMPEG" -v error -y -i "$part" \
      -vf "drawtext=fontfile='${TITLE_FONT}':textfile='$WORK_DIR/title_${n}.txt':fontsize='min(h/16,w*1.4/${nchars})':fontcolor=white:borderw=2:bordercolor=black@0.7:box=1:boxcolor=black@0.45:boxborderw=14:x=(w-text_w)/2:y=${title_y}:enable='gte(t,0.5)':alpha='min(1,(t-0.5)/0.6)'" \
      -c:v libx264 -preset fast -crf 20 -pix_fmt yuv420p -c:a copy "$part.titled.mp4" \
      && mv "$part.titled.mp4" "$part" \
      || echo "Attention : titre du plan $n non incrusté (filtre drawtext absent ?)" >&2
  fi
  if [ -z "$SHOT_INDEX" ]; then
    echo "file '$part'" >> "$list"
    PARTS+=("$part"); PLEN+=("$("$FFPROBE" -v error -select_streams v -show_entries stream=duration -of csv=p=0 "$part" | head -n 1)")
  fi
  # Plan fini (voix-off, volume, titre) sur IPFS pour pouvoir le partager : plans.json {part_NN.mp4: CID}
  if [ -z "$STORY_NO_IPFS" ]; then
    pcid=$(ipfs add -q "$part" 2>/dev/null | tail -n 1)
    [ -n "$pcid" ] && { jq -c --arg k "part_${n}.mp4" --arg v "$pcid" '. + {($k): $v}' "$WORK_DIR/plans.json" 2>/dev/null \
                         || jq -nc --arg k "part_${n}.mp4" --arg v "$pcid" '{($k): $v}'; } > "$WORK_DIR/plans.json.tmp" \
      && mv "$WORK_DIR/plans.json.tmp" "$WORK_DIR/plans.json"
  fi
done

if [ -n "$SHOT_INDEX" ]; then
  FINISHED_OK=1
  progress done -1 "plan $((SHOT_INDEX + 1)) terminé"
  echo "$WORK_DIR/part_$(printf "%02d" "$SHOT_INDEX").mp4"
  exit 0
fi

progress assemble -1 "assemblage"
if [ -n "$UDRIVE_PATH" ] && [ -d "$UDRIVE_PATH" ]; then
  final="$UDRIVE_PATH/scene_$(date +%s).mp4"
else
  final="$WORK_DIR/scene.mp4"
fi
# Transitions : .shots[i].transition = {"type": "fade|fadeblack|fadewhite|dissolve|wipeleft|wiperight|slideleft|slideright|circleopen|zoomin|cut",
# "duration": 0.5} s'applique entre le plan i et le plan i+1 (image : xfade, son : acrossfade ; « cut » = raccord franc).
# Sans transition demandée, le chemin rapide ci-dessous (copie de l'image) est conservé.
TRANS_TYPES=" fade fadeblack fadewhite dissolve wipeleft wiperight slideleft slideright circleopen zoomin "
trans_any=$(jq -r '[.shots[:-1][] | select(((.transition.type // "cut") != "cut") and (.transition.type != null))] | length' "$STORYBOARD")
assembled=0
if [ "${trans_any:-0}" -gt 0 ] && [ "${#PARTS[@]}" -gt 1 ]; then
  echo "Assemblage avec transitions ($trans_any)…" >&2
  tin=(); for p in "${PARTS[@]}"; do tin+=(-i "$p"); done
  tvf=""; taf="[0:a]apad=whole_dur=${PLEN[0]},atrim=0:${PLEN[0]},asetpts=PTS-STARTPTS[p0];"; vprev="0:v"; aprev="p0"; cum="${PLEN[0]}"
  for ((k = 1; k < ${#PARTS[@]}; k++)); do
    tt=$(jq -r ".shots[$((k - 1))].transition.type // \"cut\"" "$STORYBOARD")
    td=$(jq -r ".shots[$((k - 1))].transition.duration // 0.5" "$STORYBOARD")
    if [ "$tt" = cut ]; then tt=fade; td=0.04; fi                          # xfade n'accepte pas une durée nulle
    case "$TRANS_TYPES" in *" $tt "*) ;; *) tt=fade ;; esac
    # jamais plus de la moitié du plus court des deux plans
    # durée et décalage en images entières : xfade tronque tout le film si le décalage dépasse le début de la dernière image du flux ;
    # sur la grille des images (24 i/s) l'image et le son restent calés de raccord en raccord (lipsync des derniers plans)
    td=$(awk -v d="$td" -v a="$cum" -v b="${PLEN[$k]}" 'BEGIN { m = (a < b ? a : b) / 2; f = int(d * 24 + 0.5); mx = int(m * 24); if (f > mx) f = mx; if (f < 2) f = 2; printf "%.5f", f / 24 }')
    off=$(awk -v c="$cum" -v d="$td" 'BEGIN { printf "%.5f", c - d }')
    tvf+="[$vprev][$k:v]xfade=transition=$tt:duration=$td:offset=$off[v$k];"
    # le son de chaque plan est calé sur la durée exacte de son image (sinon l'écart s'accumule de raccord en raccord)
    taf+="[$k:a]apad=whole_dur=${PLEN[$k]},atrim=0:${PLEN[$k]},asetpts=PTS-STARTPTS[p$k];[$aprev][p$k]acrossfade=d=$td[a$k];"
    vprev="v$k"; aprev="a$k"
    cum=$(awk -v o="$off" -v l="${PLEN[$k]}" 'BEGIN { printf "%.5f", o + l }')
  done
  if "$FFMPEG" -v error -y "${tin[@]}" -filter_complex "${tvf}${taf%;}" -map "[$vprev]" -map "[$aprev]" \
       -c:v libx264 -crf 18 -preset fast -pix_fmt yuv420p -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart "$final"; then
    assembled=1
  else
    echo "Attention : assemblage avec transitions impossible, raccords francs" >&2
  fi
fi
# Vidéo copiée, audio réencodé d'un seul tenant et recalé sur les horodatages (aresample async) :
# pas de trou ni de chevauchement aux raccords, le son reste calé sur l'image (lipsync des acteurs)
if [ "$assembled" = 1 ]; then
  :
elif ! "$FFMPEG" -v error -y -f concat -safe 0 -i "$list" -c:v copy \
       -af "aresample=async=1:first_pts=0" -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart "$final"; then
  echo "Concaténation directe impossible, réencodage..." >&2
  "$FFMPEG" -v error -y -f concat -safe 0 -i "$list" -c:v libx264 -crf 20 -preset fast -c:a aac -b:a 192k \
         -movflags +faststart "$final" || exit 1
fi
# Fond musical continu sous tout le film (storyboard .music = {"source": "ipfs://…|fichier", "prompt": "style ACE-Step",
# "lufs": -30, "max_seconds": 90}) : boucle avec fondus croisés, fondus d'entrée et de sortie, baisse du volume sous la voix (sidechain)
music_json=$(jq -c '.music // empty' "$STORYBOARD")
if [ -n "$music_json" ]; then
  mbed="$WORK_DIR/music_bed.wav"
  if [ ! -s "$mbed" ]; then
    msrc=$(jq -r '.source // empty' <<< "$music_json"); mraw="$WORK_DIR/music_src.raw"
    if [ -n "$msrc" ]; then
      import_video "$msrc" "$mraw" audio || echo "Attention : musique $msrc introuvable ou illisible, film sans fond musical" >&2
    elif [ -n "$(jq -r '.prompt // empty' <<< "$music_json")" ] && [ ! -s "$mraw" ]; then
      echo "Fond musical : génération (ACE-Step)…" >&2
      mmax=$(jq -r '.max_seconds // empty' <<< "$music_json")   # durée max de la chanson YuE2 (défaut du script : 90 s)
      mout=$(YUE2_MAX_SECONDS="${mmax:-${YUE2_MAX_SECONDS:-90}}" "$MY_PATH/generate_music.sh" "$(jq -r '.prompt' <<< "$music_json")" 2>/dev/null)
      murl=$(grep -o 'http[^ ]*' <<< "$mout" | tail -n 1)
      if [ -z "$murl" ]; then   # YuE2 en échec : repli ACE-Step (30 s, bouclé ensuite)
        echo "Fond musical : YuE2 indisponible, repli ACE-Step…" >&2
        mout=$(MUSIC_ENGINE=ace "$MY_PATH/generate_music.sh" "$(jq -r '.prompt' <<< "$music_json")" 2>/dev/null)
        murl=$(grep -o 'http[^ ]*' <<< "$mout" | tail -n 1)
      fi
      [ -n "$murl" ] && curl -s -m 120 -o "$mraw" "$murl" || echo "Attention : génération musicale échouée, film sans fond musical" >&2
    fi
    if [ -s "$mraw" ]; then
      mlen=$("$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$mraw")
      total_s=$("$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$final")
      # nombre de copies nécessaires, chaînées par des fondus croisés de 2 s
      ncopies=$(awk -v t="$total_s" -v m="$mlen" 'BEGIN { n = int(t / (m - 2)) + 1; print (n < 1 ? 1 : n) }')
      minputs=(); mchain=""; prev="0:a"
      for ((k = 0; k < ncopies; k++)); do minputs+=(-i "$mraw"); done
      for ((k = 1; k < ncopies; k++)); do mchain+="[$prev][$k:a]acrossfade=d=2[c$k];"; prev="c$k"; done
      "$FFMPEG" -v error -y "${minputs[@]}" -filter_complex "${mchain}[$prev]aresample=48000,aformat=channel_layouts=stereo[o]" -map "[o]" \
        -t "$total_s" "$mbed" || { rm -f "$mbed"; echo "Attention : fond musical inutilisable" >&2; }
    fi
  fi
  if [ -s "$mbed" ]; then
    mgain=$(gain_db "$(lufs "$mbed")" "$(jq -r '.lufs // -30' <<< "$music_json")")
    total_s=$("$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$final")
    fo=$(awk -v t="$total_s" 'BEGIN { printf "%.2f", (t > 4 ? t - 3 : 0) }')
    "$FFMPEG" -v error -y -i "$final" -i "$mbed" -filter_complex \
      "[1:a]volume=${mgain}dB,afade=t=in:d=2,afade=t=out:st=${fo}:d=3[m];[0:a]asplit=2[a][sc];[m][sc]sidechaincompress=threshold=0.04:ratio=4:attack=30:release=700:makeup=1[duck];[a][duck]amix=inputs=2:duration=first:normalize=0,alimiter=limit=0.95[mix]" \
      -map 0:v -map "[mix]" -c:v copy -c:a aac -b:a 192k -ar 48000 "$final.music.mp4" \
      && mv "$final.music.mp4" "$final" || echo "Attention : mixage du fond musical échoué" >&2
  fi
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
# -p : la scène apparaît dans story.html (acteurs, scène, rendu et plans sur IPFS, prises)
if [ -n "$PUBLISH_SCOPE" ]; then
  scene_name=$(jq -r '.name // empty' "$STORYBOARD")
  [ -z "$scene_name" ] && scene_name=$(basename "$STORYBOARD" .json)
  echo "Publication dans la bibliothèque du Studio (${PUBLISH_SCOPE})…" >&2
  python3_bin="${ASTRO_PY:-python3}"
  "$python3_bin" "$MY_PATH/../../tools/story_asset.py" publish-render "$scene_name" "$STORYBOARD" --work "$WORK_DIR" --scope "$PUBLISH_SCOPE" >&2 \
    || echo "Attention : publication dans la bibliothèque échouée (le rendu reste disponible dans $WORK_DIR)" >&2
fi
# STORY_NO_IPFS=1 : rendu d'un paquet privé, la vidéo ne part pas sur IPFS (UPassport la sert elle-même)
if [ -n "$STORY_NO_IPFS" ]; then echo "$final"; exit 0; fi
ipfs_hash=$(ipfs add -wq "$final" 2>/dev/null | tail -n 1)
if [ -n "$ipfs_hash" ]; then
  echo "$myIPFS/ipfs/$ipfs_hash/$(basename "$final")"
else
  echo "Attention : ajout IPFS échoué" >&2
  echo "$final"
fi
