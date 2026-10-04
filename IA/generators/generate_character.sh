#!/bin/bash
# Dependencies : jq ffmpeg ComfyUI (Z-Image) + venv Qwen3-TTS (install/install_qwen3_tts.sh)
#### generate_character.sh : portrait (Z-Image) + voix de référence (Qwen3-TTS VoiceDesign) d'un personnage
#
# Usage: generate_character.sh -w dossier [-S seed] NOM "look" "voix" "phrase"
#   look    description du visage et des vêtements (anglais conseillé), ex. "woman in her 30s, short black hair"
#   voix    description de la voix (anglais), ex. "warm low-pitched woman, calm and friendly"
#   phrase  ce que la voix dit en français (~8 s : l'acteur la reprend comme référence <Audio k>)
# Produit dossier/portrait.png et dossier/voice.wav (Qwen3-TTS, ou à défaut MiniMax) ; un fichier déjà présent n'est pas refait
# (le supprimer pour le régénérer). Suivi : dossier/progress.json (stages portrait voice done failed).
# Codes de sortie : 0 ok, 1 erreur, 2 arguments.

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"
. "$MY_PATH/lib/env.sh"

OUT="" SEED=42
while getopts "w:S:h" opt; do
  case $opt in w) OUT="$OPTARG" ;; S) SEED="$OPTARG" ;; *) sed -n '5,10p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;; esac
done
shift $((OPTIND - 1))
NAME="$1" LOOK="$2" VOICE_DESIGN="$3" LINE="$4"
if [ -z "$OUT" ] || [ -z "$NAME" ] || [ -z "$LOOK" ]; then
  sed -n '5,10p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
fi
mkdir -p "$OUT"
T0=$(date +%s)
progress() {
  jq -n --arg st "$1" --arg m "$2" --argjson t0 "$T0" --argjson now "$(date +%s)" \
    '{stage: $st, shot: -1, shots: 2, message: $m, started: $t0, updated: $now, done: []}' > "$OUT/progress.json.tmp" \
    && mv "$OUT/progress.json.tmp" "$OUT/progress.json"
}
OK=0
ERRMSG=""
# Le message d'échec affiché dans le Studio est la vraie cause (pas un « arrêt » générique)
fail() { ERRMSG="$1"; echo "Erreur : $1" >&2; exit 1; }
trap '[ "$OK" = 1 ] || progress failed "${ERRMSG:-arrêt}"' EXIT

if [ ! -s "$OUT/portrait.png" ]; then
  progress portrait "portrait de $NAME"
  mkdir -p "$HOME/.zen/tmp/scenes"
  image_dir=$(mktemp -d "$HOME/.zen/tmp/scenes/image_XXXXXX")
  # fond neutre indispensable : ref2va recopie tout ce qu'il voit dans la photo de référence
  IMAGE_SIZE=1024x1024 "$MY_PATH/generate_image.sh" \
    "$LOOK, head and shoulders portrait, plain neutral light grey studio background, soft even lighting, looking at the camera" \
    "$image_dir" > /dev/null && mv "$(ls -t "$image_dir"/*.png 2>/dev/null | head -n 1)" "$OUT/portrait.png"
  rm -rf "$image_dir"
  [ -s "$OUT/portrait.png" ] || fail "portrait échoué (ComfyUI / Z-Image injoignable ?)"
fi

DONE_MSG="terminé"
if [ ! -s "$OUT/voice.wav" ] && [ -n "$VOICE_DESIGN" ] && [ -n "$LINE" ]; then
  if [ -n "$QWEN3TTS_PY" ]; then
    progress voice "voix de $NAME"
    bash "$MY_PATH/../services/ollama.me.sh" FREE > /dev/null 2>&1
    curl -s -m 10 -X POST "http://127.0.0.1:8188/free" -H "Content-Type: application/json" \
         -d '{"unload_models": true, "free_memory": true}' > /dev/null 2>&1
    "$QWEN3TTS_PY" "$MY_PATH/generate_voice.py" -o "$OUT/voice_src.wav" -S "$SEED" "$VOICE_DESIGN" "$LINE" > /dev/null \
      && "$FFMPEG" -v error -y -i "$OUT/voice_src.wav" -ac 1 -ar 48000 "$OUT/voice.wav" \
      || { rm -f "$OUT/voice.wav"; fail "voix échouée (Qwen3-TTS)"; }
    rm -f "$OUT/voice_src.wav"
  else
    # Sans Qwen3-TTS (install/install_qwen3_tts.sh) : repli MiniMax, comme generate_scene.sh — le portrait dit la
    # phrase pendant 8 s et on garde la piste audio. La description de voix est donnée au modèle pour le timbre.
    progress voice "voix de $NAME (MiniMax)"
    echo "Attention : Qwen3-TTS absent (install/install_qwen3_tts.sh) — voix de référence créée par MiniMax." >&2
    line_clean=${LINE//\"/\'}
    prompt=$(python3 "$MY_PATH/lib/pronounce.py" "Close-up: the person looks at the camera and speaks in French at a relaxed pace, voice: ${VOICE_DESIGN}. They say: \"${line_clean}\" Quiet room, no music, no background noise.")
    "$MY_PATH/generate_minimax.sh" -o "$OUT/voice_src.mp4" -S "$SEED" -i "$OUT/portrait.png" -r 1:1 -m 0.25 -d 8 -s 10 "$prompt" > /dev/null
    [ -s "$OUT/voice_src.mp4" ] || fail "voix échouée (MiniMax / ComfyUI injoignable ?)"
    "$FFMPEG" -v error -y -i "$OUT/voice_src.mp4" -vn -ac 1 -ar 48000 "$OUT/voice.wav" || { rm -f "$OUT/voice.wav"; fail "extraction de la voix échouée"; }
    rm -f "$OUT/voice_src.mp4"
    DONE_MSG="terminé : portrait et voix de référence (créée par MiniMax, Qwen3-TTS absent)"
  fi
fi
OK=1
progress done "$DONE_MSG"
