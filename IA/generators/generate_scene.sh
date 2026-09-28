#!/bin/bash
# Dependencies : jq ffmpeg ffprobe ipfs
#### generate_scene.sh : storyboard JSON → vidéo multi-plans (MiniMax H3) assemblée en 720p
#
# Usage: generate_scene.sh [-w workdir] <storyboard.json> [udrive_path]
#   -w  répertoire de travail ; relancer avec le même -w reprend la scène :
#       les plans déjà rendus (shot_NN.mp4) ne sont pas recalculés.
# Sortie stdout : URL IPFS de la vidéo finale (ou chemin du fichier si IPFS échoue)
# Codes de sortie : 0 ok, 1 erreur, 2 storyboard invalide, 3 ComfyUI non équipé, 4 timeout
#
# Storyboard (voir storyboard.example.json) :
# {
#   "ratio": "16:9", "megapixels": 0.4, "steps": 10, "style": "vhs", "height": 720, "seed": 42,
#   "shots": [
#     {"image_prompt": "...", "prompt": "...", "duration": 5},  image générée (generate_image.sh) puis animée
#     {"continue": true,      "prompt": "...", "duration": 5},  repart de la dernière image du plan précédent
#     {"image": "/chemin.png", "prompt": "...", "duration": 5}, image fournie
#     {"prompt": "...", "duration": 5}                          text-to-video
#   ]
# }
# Champs de plan optionnels :
#   voiceover  narration (texte FR) lue par Orpheus TTS (voix globale "voice" :
#              "amelie" | "pierre", défaut amelie), mixée sur l'ambiance du plan ;
#              la durée du plan est allongée si la phrase ne tient pas, et le prompt
#              vidéo reçoit « no speech » pour que MiniMax ne fasse que l'ambiance.
#   title      texte incrusté (bas de l'image) pendant tout le plan, après le style.
# Paramètres globaux, tous optionnels (défauts = priorité à la vitesse sur RTX 3090,
# ~5 min par plan de 5 s) :
#   ratio      "16:9" | "9:16" (vertical smartphone, Reels/Shorts) | "4:3" | "1:1"...
#   megapixels 0.4 (864x480 en 16:9) ; steps 10
#   height     petit côté de la vidéo finale, défaut 720 (1280x720 / 720x1280) ;
#              0 = résolution de calcul
#   style      "clean" (défaut) ou "vhs" : look cassette VHS qui masque les défauts
#              de la basse résolution (voir video_finish.sh)
#   upscale    facteur SeedVR2 (lent, qualité) ; défaut 1 = aucun. Au-delà de ~3 s
#              à 0.4 MP, x2 dépasse les 24 Go de VRAM.
#   seed       chaque plan utilise seed + index : scène reproductible.
# Un plan peut surcharger "seed" et "duration" (5 à 10 s conseillé).
#
# Écrire les prompts :
#  - une action par plan ; décrire le son : voix (langue, ton, texte exact entre
#    guillemets), bruitages, musique — sinon le plan est muet ;
#  - un texte parlé tient en ~2,5 mots/s : 5 s ≈ 12 mots ;
#  - pour une scène plus longue que 5 s, enchaîner des plans "continue": true en
#    répétant la description du personnage et du décor dans chaque prompt ;
#  - pas de texte à l'écran demandé au modèle (illisible) : l'ajouter au montage.

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

usage() {
  sed -n '5,9p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

WORK_DIR=""
while getopts "w:h" opt; do
  case $opt in
    w) WORK_DIR="$OPTARG" ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

STORYBOARD="$1"
UDRIVE_PATH="$2"
[ -f "$STORYBOARD" ] || usage

. "${HOME}/.zen/Astroport.ONE/tools/my.sh"

if ! jq -e '.shots | type == "array" and length > 0 and all(.[]; (.prompt | type) == "string")' "$STORYBOARD" > /dev/null 2>&1; then
  echo "Erreur : storyboard invalide (il faut .shots[] avec un .prompt chacun)" >&2
  exit 2
fi
if jq -e '.shots[0].continue == true' "$STORYBOARD" > /dev/null; then
  echo "Erreur : le premier plan ne peut pas être \"continue\"" >&2
  exit 2
fi

RATIO=$(jq -r '.ratio // "16:9"' "$STORYBOARD")
MEGAPIXELS=$(jq -r '.megapixels // 0.4' "$STORYBOARD")
STEPS=$(jq -r '.steps // 10' "$STORYBOARD")
UPSCALE=$(jq -r '.upscale // 1' "$STORYBOARD")
STYLE=$(jq -r '.style // "clean"' "$STORYBOARD")
FINAL_HEIGHT=$(jq -r '.height // 720' "$STORYBOARD")
VOICE=$(jq -r '.voice // "amelie"' "$STORYBOARD")
TTS_URL="http://localhost:5005/v1/audio/speech"
TITLE_FONT=$(fc-match -f '%{file}' 'DejaVu Sans:bold' 2>/dev/null)
BASE_SEED=$(jq -r '.seed // empty' "$STORYBOARD")
[ -z "$BASE_SEED" ] && BASE_SEED=$((RANDOM * RANDOM))
NB_SHOTS=$(jq '.shots | length' "$STORYBOARD")

# Images de départ générées directement au ratio de la vidéo (~1 MP, multiples de 64)
case "$RATIO" in
  16:9) IMAGE_SIZE=1344x768 ;;  9:16) IMAGE_SIZE=768x1344 ;;
  4:3)  IMAGE_SIZE=1152x896 ;;  3:4)  IMAGE_SIZE=896x1152 ;;
  3:2)  IMAGE_SIZE=1216x832 ;;  2:3)  IMAGE_SIZE=832x1216 ;;
  21:9) IMAGE_SIZE=1536x640 ;;  *)    IMAGE_SIZE=1024x1024 ;;
esac

WORK_DIR="${WORK_DIR:-$HOME/.zen/tmp/scenes/scene_$(date +%s)_$(openssl rand -hex 4)}"
mkdir -p "$WORK_DIR"
echo "Scène : $NB_SHOTS plans | ${RATIO} @ ${MEGAPIXELS} MP | ${STEPS} steps | upscale ${UPSCALE} | style ${STYLE} | ${FINAL_HEIGHT}p | seed ${BASE_SEED}" >&2
echo "Répertoire de travail (reprise avec -w) : $WORK_DIR" >&2

# Voix-off : Orpheus TTS local ou via la constellation (orpheus.me.sh ouvre le tunnel P2P)
if jq -e 'any(.shots[]; .voiceover)' "$STORYBOARD" > /dev/null; then
  "$MY_PATH/../services/orpheus.me.sh" > /dev/null 2>&1
  if ! curl -s -o /dev/null -m 10 "http://localhost:5005/docs"; then
    echo "Erreur : Orpheus TTS injoignable (IA/services/orpheus.me.sh)" >&2
    exit 1
  fi
fi

# $1 texte, $2 fichier wav
tts() {
  local code
  code=$(jq -n --arg t "$1" --arg v "$VOICE" '{model: "orpheus", input: $t, voice: $v, response_format: "wav", speed: 1.0}' \
         | curl -s -m 300 -o "$2" -w "%{http_code}" -H "Content-Type: application/json" --data-binary @- "$TTS_URL")
  [ "$code" = "200" ] && [ -s "$2" ]
}

for ((i = 0; i < NB_SHOTS; i++)); do
  n=$(printf "%02d" "$i")
  shot_file="$WORK_DIR/shot_${n}.mp4"
  if [ -s "$shot_file" ]; then
    echo "Plan $n déjà rendu, ignoré" >&2
    continue
  fi

  shot=$(jq -c ".shots[$i]" "$STORYBOARD")
  prompt=$(jq -r '.prompt' <<< "$shot")
  duration=$(jq -r '.duration // 5' <<< "$shot")
  seed=$(jq -r --argjson s "$((BASE_SEED + i))" '.seed // $s' <<< "$shot")

  voiceover=$(jq -r '.voiceover // empty' <<< "$shot")
  if [ -n "$voiceover" ]; then
    vo_file="$WORK_DIR/vo_${n}.wav"
    if [ ! -s "$vo_file" ]; then
      echo "Plan $n : voix-off ($VOICE)" >&2
      tts "$voiceover" "$vo_file" || { rm -f "$vo_file"; echo "Erreur : voix-off du plan $n échouée" >&2; exit 1; }
    fi
    vo_len=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$vo_file")
    # Voix décalée de 0,4 s, 0,4 s de marge en fin de plan
    duration=$(awk -v d="$duration" -v v="$vo_len" 'BEGIN { need = int(v + 0.8 + 0.999); print (need > d ? need : d) }')
    prompt="$prompt Audio: ambient sound effects and soft background music only, no speech, no voices, no singing."
  fi

  first_frame=""
  if jq -e '.continue == true' <<< "$shot" > /dev/null; then
    first_frame="$WORK_DIR/last_$(printf "%02d" $((i - 1))).png"
  elif jq -e '.image' <<< "$shot" > /dev/null; then
    first_frame=$(jq -r '.image' <<< "$shot")
  elif jq -e '.image_prompt' <<< "$shot" > /dev/null; then
    first_frame="$WORK_DIR/image_${n}.png"
    if [ ! -s "$first_frame" ]; then
      echo "Plan $n : génération de l'image de départ" >&2
      # Hors de ~/.zen/tmp.media : generate_image.sh y efface ses images en sortie
      mkdir -p "$HOME/.zen/tmp/scenes"
      image_dir=$(mktemp -d "$HOME/.zen/tmp/scenes/image_XXXXXX")
      IMAGE_SIZE=$IMAGE_SIZE "$MY_PATH/generate_image.sh" "$(jq -r '.image_prompt' <<< "$shot")" "$image_dir" > /dev/null \
        && mv "$(ls -t "$image_dir"/*.png 2>/dev/null | head -n 1)" "$first_frame"
      rm -rf "$image_dir"
      if [ ! -s "$first_frame" ]; then
        echo "Erreur : génération de l'image du plan $n échouée" >&2
        exit 1
      fi
    fi
  fi

  echo "=== Plan $((i + 1))/$NB_SHOTS (${duration}s) ===" >&2
  args=(-o "$shot_file" -d "$duration" -r "$RATIO" -m "$MEGAPIXELS" -s "$STEPS" -S "$seed")
  [ "$UPSCALE" != "1" ] && [ "$UPSCALE" != "0" ] && args+=(-u "$UPSCALE")
  [ -n "$first_frame" ] && args+=(-i "$first_frame")
  "$MY_PATH/generate_minimax.sh" "${args[@]}" "$prompt" > /dev/null
  rc=$?
  if [ $rc -ne 0 ] || [ ! -s "$shot_file" ]; then
    rm -f "$shot_file"
    echo "Erreur : plan $n échoué (code $rc). Relancer avec -w $WORK_DIR pour reprendre." >&2
    exit $([ $rc -ne 0 ] && echo $rc || echo 1)
  fi

  # Dernière image, point de départ d'un éventuel plan "continue" suivant
  ffmpeg -v error -y -sseof -0.1 -i "$shot_file" -update 1 -frames:v 1 "$WORK_DIR/last_${n}.png"
done

# Voix-off mixée sur l'ambiance MiniMax (baissée), puis assemblage : les plans
# partagent codec, résolution et fps → copie sans réencodage, réencodage en secours.
list="$WORK_DIR/concat.txt"
: > "$list"
titles_filter=""
offset=0
for ((i = 0; i < NB_SHOTS; i++)); do
  n=$(printf "%02d" "$i")
  part="$WORK_DIR/shot_${n}.mp4"
  if [ -s "$WORK_DIR/vo_${n}.wav" ]; then
    part="$WORK_DIR/mix_${n}.mp4"
    ffmpeg -v error -y -i "$WORK_DIR/shot_${n}.mp4" -i "$WORK_DIR/vo_${n}.wav" -filter_complex \
      "[0:a]volume=0.35[a0];[1:a]adelay=400:all=1,volume=1.4[a1];[a0][a1]amix=inputs=2:duration=first:normalize=0[a]" \
      -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 192k -ar 48000 "$part" || exit 1
  fi
  echo "file '$part'" >> "$list"

  len=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$part")
  title=$(jq -r ".shots[$i].title // empty" "$STORYBOARD")
  if [ -n "$title" ]; then
    printf '%s' "$title" > "$WORK_DIR/title_${n}.txt"
    # Police réduite pour que le titre tienne dans ~90 % de la largeur
    nchars=$(printf '%s' "$title" | wc -m)
    start=$(awk -v o="$offset" 'BEGIN { print o + 0.5 }')
    end=$(awk -v o="$offset" -v l="$len" 'BEGIN { print o + l }')
    titles_filter+="${titles_filter:+,}drawtext=fontfile='${TITLE_FONT}':textfile='$WORK_DIR/title_${n}.txt':fontsize='min(h/16,w*1.4/${nchars})':fontcolor=white:borderw=3:bordercolor=black@0.7:x=(w-text_w)/2:y=h*0.8-text_h/2:enable='between(t,${start},${end})':alpha='min(1,(t-${start})/0.6)'"
  fi
  offset=$(awk -v o="$offset" -v l="$len" 'BEGIN { print o + l }')
done

if [ -n "$UDRIVE_PATH" ] && [ -d "$UDRIVE_PATH" ]; then
  final="$UDRIVE_PATH/scene_$(date +%s).mp4"
else
  final="$WORK_DIR/scene.mp4"
fi
assembled="$WORK_DIR/assembled.mp4"
if ! ffmpeg -v error -y -f concat -safe 0 -i "$list" -c copy "$assembled"; then
  echo "Concaténation directe impossible, réencodage..." >&2
  ffmpeg -v error -y -f concat -safe 0 -i "$list" -c:v libx264 -crf 18 -preset medium -c:a aac -b:a 192k "$assembled" || exit 1
fi

# Finition : mise à l'échelle finale et style
finish_args=()
[ "$STYLE" = "vhs" ] && finish_args+=(-v)
if [ "$FINAL_HEIGHT" != "0" ] || [ "$STYLE" = "vhs" ]; then
  if [ "$FINAL_HEIGHT" = "0" ]; then
    FINAL_HEIGHT=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$assembled" \
                   | awk -F, '{print ($1 < $2 ? $1 : $2)}')
  fi
  "$MY_PATH/video_finish.sh" "${finish_args[@]}" -H "$FINAL_HEIGHT" "$assembled" "$final" > /dev/null || exit 1
else
  mv "$assembled" "$final"
fi

# Titres incrustés après le style, pour rester nets. drawtext n'est pas dans
# toutes les compilations de ffmpeg : celui du système (/usr/bin) l'a.
if [ -n "$titles_filter" ]; then
  FFMPEG_TEXT=/usr/bin/ffmpeg
  "$FFMPEG_TEXT" -hide_banner -h filter=drawtext 2>&1 | grep -q '^Filter drawtext' || FFMPEG_TEXT=ffmpeg
  "$FFMPEG_TEXT" -v error -y -i "$final" -vf "$titles_filter" -c:v libx264 -preset fast -crf 20 -pix_fmt yuv420p \
                 -c:a copy -movflags +faststart "$final.titles.mp4" \
    && mv "$final.titles.mp4" "$final" \
    || echo "Attention : incrustation des titres échouée (filtre drawtext absent ?)" >&2
fi
total=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$final")
echo "Scène assemblée : $final (${total%.*} s)" >&2

ipfs_hash=$(ipfs add -wq "$final" 2>/dev/null | tail -n 1)
if [ -n "$ipfs_hash" ]; then
  echo "$myIPFS/ipfs/$ipfs_hash/$(basename "$final")"
else
  echo "Attention : ajout IPFS échoué" >&2
  echo "$final"
fi
