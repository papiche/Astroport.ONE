#!/bin/bash
# Dependencies : jq ffmpeg ffprobe ipfs qrencode (+ playwright dans ~/.astro pour screen/card)
#### generate_scene.sh : storyboard JSON → vidéo multi-plans (MiniMax H3) assemblée en 720p
#
# Usage: generate_scene.sh [-w workdir] <storyboard.json> [udrive_path]
#   -w  répertoire de travail (défaut ~/.zen/workspace/scenes/scene_*, hors de ~/.zen/tmp
#       que le nettoyage d'Astroport vide) ; relancer avec le même -w reprend la scène :
#       acteurs, plans et captures déjà rendus ne sont pas recalculés.
# Sortie stdout : URL IPFS de la vidéo finale (ou chemin du fichier si IPFS échoue)
# Codes de sortie : 0 ok, 1 erreur, 2 storyboard invalide, 3 ComfyUI non équipé, 4 timeout
#
# Storyboard (exemples : storyboard*.example.json, storyboards/*.json) :
# {
#   "ratio": "16:9", "megapixels": 0.4, "steps": 10, "style": "vhs", "height": 720, "seed": 42,
#   "cast": {
#     "lea": {"image_prompt": "portrait…",  "voice_line": "phrase FR de ~8 s"},
#     "malik": {"image": "/portrait.png", "voice": "/voix_10s.wav"}
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
# et voix de référence (fournie, ou créée par MiniMax en faisant dire "voice_line" au
# portrait). Dans un plan "cast", le script ajoute en tête du prompt la phrase qui lie
# chaque nom à <Picture k>/<Audio k> : écrire ensuite le prompt avec les noms.
# N'utiliser le visage ou la voix d'une personne réelle qu'avec son consentement.
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
ASTRO_PY="$HOME/.astro/bin/python"
BASE_SEED=$(jq -r '.seed // empty' "$STORYBOARD")
[ -z "$BASE_SEED" ] && BASE_SEED=$((RANDOM * RANDOM))
NB_SHOTS=$(jq '.shots | length' "$STORYBOARD")

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

WORK_DIR="${WORK_DIR:-$HOME/.zen/workspace/scenes/scene_$(date +%s)_$(openssl rand -hex 4)}"
mkdir -p "$WORK_DIR"
echo "Scène : $NB_SHOTS plans | ${RATIO} @ ${MEGAPIXELS} MP | ${STEPS} steps | upscale ${UPSCALE} | style ${STYLE} | ${FINAL_W}x${FINAL_H} | seed ${BASE_SEED}" >&2
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

########################################################################
# Acteurs : portrait neutre + voix de référence, préparés une fois
########################################################################
for name in $(jq -r '.cast // {} | keys[]' "$STORYBOARD"); do
  cdir="$WORK_DIR/cast/$name"
  mkdir -p "$cdir"
  actor=$(jq -c --arg n "$name" '.cast[$n]' "$STORYBOARD")

  if [ ! -s "$cdir/portrait.png" ]; then
    if jq -e '.image' <<< "$actor" > /dev/null; then
      cp "$(jq -r '.image' <<< "$actor")" "$cdir/portrait.png" || exit 1
    else
      echo "Acteur $name : portrait (Z-Image)" >&2
      gen_image "$(jq -r '.image_prompt' <<< "$actor"), head and shoulders portrait, plain neutral light grey studio background, soft even lighting, looking at the camera" \
        1024x1024 "$cdir/portrait.png" || { echo "Erreur : portrait de $name échoué" >&2; exit 1; }
    fi
  fi

  if [ ! -s "$cdir/voice.wav" ]; then
    if jq -e '.voice' <<< "$actor" > /dev/null; then
      ffmpeg -v error -y -i "$(jq -r '.voice' <<< "$actor")" -ac 1 -ar 48000 "$cdir/voice.wav" || exit 1
    else
      echo "Acteur $name : voix de référence (MiniMax)" >&2
      line=$(jq -r '.voice_line' <<< "$actor")
      render -o "$cdir/voice_src.mp4" -i "$cdir/portrait.png" -r 1:1 -m 0.25 -d 8 -s "$STEPS" -S "$BASE_SEED" \
        "Close-up: the person looks at the camera and speaks in French in a natural, calm voice, at a relaxed pace: \"$line\" Quiet room, no music, no background noise."
      ffmpeg -v error -y -i "$cdir/voice_src.mp4" -vn -ac 1 -ar 48000 "$cdir/voice.wav" || exit 1
    fi
  fi
done

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
# Plans
########################################################################
# $1 png, $2 durée, $3 motion, $4 sortie : plan net à la taille finale, sans IA
screen_clip() {
  local img_h
  img_h=$(ffprobe -v error -show_entries stream=height -of csv=p=0 "$1")
  local motion="$3"
  local img_w
  img_w=$(ffprobe -v error -show_entries stream=width -of csv=p=0 "$1")
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
  ffmpeg -v error -y -loop 1 -framerate 24 -i "$1" -f lavfi -i anullsrc=r=48000:cl=stereo -t "$2" \
         -vf "${vf},format=yuv420p,setsar=1" -c:v libx264 -preset fast -crf 18 -c:a aac -ar 48000 -ac 2 -shortest "$4"
}

# $1 écran, $2 présentateur (carré), $3 sortie : incrustation ronde en bas à droite,
# avec l'audio du présentateur
pip_compose() {
  local short=$(( FINAL_W < FINAL_H ? FINAL_W : FINAL_H ))
  local p=$(( short * 36 / 100 / 2 * 2 )) m=$(( short / 30 ))
  local ring=$(( p + 8 ))
  ffmpeg -v error -y -i "$1" -i "$2" -filter_complex \
    "[1:v]scale=${p}:${p},format=yuva420p,geq=lum='lum(X,Y)':cb='cb(X,Y)':cr='cr(X,Y)':a='if(lt(hypot(X-W/2,Y-H/2),W/2-1),255,0)'[face];
     color=c=white:s=${ring}x${ring},format=yuva420p,geq=lum='lum(X,Y)':cb='cb(X,Y)':cr='cr(X,Y)':a='if(lt(hypot(X-W/2,Y-H/2),W/2-1),230,0)'[disc];
     [0:v][disc]overlay=W-w-${m}:H-h-${m}:shortest=1[bg];[bg][face]overlay=W-w-$((m + 4)):H-h-$((m + 4)):shortest=1[v]" \
    -map "[v]" -map 1:a -c:v libx264 -preset fast -crf 18 -c:a aac -ar 48000 -ac 2 -shortest "$3"
}

# $1 JSON {title, subtitle?, links:[{label,url}]}, $2 png : carton HTML → capture
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
      </style></head><body>' "$FINAL_W" "$FINAL_H" $((FINAL_H / 12)) $((FINAL_H / 28)) $((FINAL_H / 30)) $((FINAL_H / 60)) \
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

for ((i = 0; i < NB_SHOTS; i++)); do
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
        render -o "$talk" "${REF_ARGS[@]}" -r 1:1 -m 0.2 -d "$duration" -s "$REF_STEPS" -S "$seed" \
          "${REF_INTRO}Close-up head-and-shoulders shot of ${presenter^} facing the camera against a plain softly lit neutral studio background, talking naturally with small gestures. $prompt"
      fi
      duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$talk")
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
    vo_len=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$vo_file")
    # Voix décalée de 0,4 s, 0,4 s de marge en fin de plan
    duration=$(awk -v d="$duration" -v v="$vo_len" 'BEGIN { need = int(v + 0.8 + 0.999); print (need > d ? need : d) }')
    prompt="$prompt Audio: ambient sound effects and soft background music only, no speech, no voices, no singing."
  fi

  args=(-o "$shot_file" -d "$duration" -r "$RATIO" -m "$MEGAPIXELS" -s "$STEPS" -S "$seed")
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
  render "${args[@]}" "$prompt"

  # Dernière image, point de départ d'un éventuel plan "continue" suivant
  ffmpeg -v error -y -sseof -0.1 -i "$shot_file" -update 1 -frames:v 1 "$WORK_DIR/last_${n}.png"
done

########################################################################
# Finition plan par plan (voix-off, taille exacte, style, titre), puis assemblage
########################################################################
FFMPEG_TEXT=/usr/bin/ffmpeg
"$FFMPEG_TEXT" -hide_banner -h filter=drawtext 2>&1 | grep -q '^Filter drawtext' || FFMPEG_TEXT=ffmpeg

list="$WORK_DIR/concat.txt"
: > "$list"
for ((i = 0; i < NB_SHOTS; i++)); do
  n=$(printf "%02d" "$i")
  shot=$(jq -c ".shots[$i]" "$STORYBOARD")
  src="$WORK_DIR/shot_${n}.mp4"
  part="$WORK_DIR/part_${n}.mp4"

  if [ -s "$WORK_DIR/vo_${n}.wav" ]; then
    ffmpeg -v error -y -i "$src" -i "$WORK_DIR/vo_${n}.wav" -filter_complex \
      "[0:a]volume=0.35[a0];[1:a]adelay=400:all=1,volume=1.4[a1];[a0][a1]amix=inputs=2:duration=first:normalize=0[a]" \
      -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 192k -ar 48000 "$WORK_DIR/mix_${n}.mp4" || exit 1
    src="$WORK_DIR/mix_${n}.mp4"
  fi

  finish_args=(-s "${FINAL_W}x${FINAL_H}")
  if [ "$STYLE" = "vhs" ] && ! jq -e '.screen or .card' <<< "$shot" > /dev/null; then
    finish_args+=(-v)
  fi
  "$MY_PATH/video_finish.sh" "${finish_args[@]}" "$src" "$part" > /dev/null || exit 1

  # Titre incrusté après le style pour rester net (drawtext : ffmpeg du système)
  title=$(jq -r '.title // empty' <<< "$shot")
  if [ -n "$title" ]; then
    printf '%s' "$title" > "$WORK_DIR/title_${n}.txt"
    nchars=$(printf '%s' "$title" | wc -m)
    # En haut de l'image quand un présentateur est incrusté en bas à droite
    title_y="h*0.8-text_h/2"
    jq -e '.presenter' <<< "$shot" > /dev/null && title_y="h*0.07"
    "$FFMPEG_TEXT" -v error -y -i "$part" \
      -vf "drawtext=fontfile='${TITLE_FONT}':textfile='$WORK_DIR/title_${n}.txt':fontsize='min(h/16,w*1.4/${nchars})':fontcolor=white:borderw=3:bordercolor=black@0.7:x=(w-text_w)/2:y=${title_y}:enable='gte(t,0.5)':alpha='min(1,(t-0.5)/0.6)'" \
      -c:v libx264 -preset fast -crf 20 -pix_fmt yuv420p -c:a copy "$part.titled.mp4" \
      && mv "$part.titled.mp4" "$part" \
      || echo "Attention : titre du plan $n non incrusté (filtre drawtext absent ?)" >&2
  fi
  echo "file '$part'" >> "$list"
done

if [ -n "$UDRIVE_PATH" ] && [ -d "$UDRIVE_PATH" ]; then
  final="$UDRIVE_PATH/scene_$(date +%s).mp4"
else
  final="$WORK_DIR/scene.mp4"
fi
# Plans finis à l'identique (taille, 24 i/s, AAC 48 kHz) → copie ; réencodage en secours
if ! ffmpeg -v error -y -f concat -safe 0 -i "$list" -c copy -movflags +faststart "$final"; then
  echo "Concaténation directe impossible, réencodage..." >&2
  ffmpeg -v error -y -f concat -safe 0 -i "$list" -c:v libx264 -crf 20 -preset fast -c:a aac -b:a 192k \
         -movflags +faststart "$final" || exit 1
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
