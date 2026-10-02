#!/bin/bash
# Dependencies : jq ffmpeg ComfyUI (Z-Image) + venv Qwen3-TTS (install/install_qwen3_tts.sh)
#### generate_character.sh : portrait (Z-Image) + voix de référence (Qwen3-TTS VoiceDesign) d'un personnage
#
# Usage: generate_character.sh -w dossier [-S seed] NOM "look" "voix" "phrase"
#   look    description du visage et des vêtements (anglais conseillé), ex. "woman in her 30s, short black hair"
#   voix    description de la voix (anglais), ex. "warm low-pitched woman, calm and friendly"
#   phrase  ce que la voix dit en français (~8 s : l'acteur la reprend comme référence <Audio k>)
# Produit dossier/portrait.png et dossier/voice.wav ; un fichier déjà présent n'est pas refait
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
trap '[ "$OK" = 1 ] || progress failed "arrêt"' EXIT

if [ ! -s "$OUT/portrait.png" ]; then
  progress portrait "portrait de $NAME"
  mkdir -p "$HOME/.zen/tmp/scenes"
  image_dir=$(mktemp -d "$HOME/.zen/tmp/scenes/image_XXXXXX")
  # fond neutre indispensable : ref2va recopie tout ce qu'il voit dans la photo de référence
  IMAGE_SIZE=1024x1024 "$MY_PATH/generate_image.sh" \
    "$LOOK, head and shoulders portrait, plain neutral light grey studio background, soft even lighting, looking at the camera" \
    "$image_dir" > /dev/null && mv "$(ls -t "$image_dir"/*.png 2>/dev/null | head -n 1)" "$OUT/portrait.png"
  rm -rf "$image_dir"
  [ -s "$OUT/portrait.png" ] || { echo "Erreur : portrait échoué" >&2; exit 1; }
fi

if [ ! -s "$OUT/voice.wav" ] && [ -n "$VOICE_DESIGN" ] && [ -n "$LINE" ]; then
  [ -n "$QWEN3TTS_PY" ] || { echo "Erreur : Qwen3-TTS absent (install/install_qwen3_tts.sh)" >&2; exit 1; }
  progress voice "voix de $NAME"
  bash "$MY_PATH/../services/ollama.me.sh" FREE > /dev/null 2>&1
  curl -s -m 10 -X POST "http://127.0.0.1:8188/free" -H "Content-Type: application/json" \
       -d '{"unload_models": true, "free_memory": true}' > /dev/null 2>&1
  "$QWEN3TTS_PY" "$MY_PATH/generate_voice.py" -o "$OUT/voice_src.wav" -S "$SEED" "$VOICE_DESIGN" "$LINE" > /dev/null \
    && "$FFMPEG" -v error -y -i "$OUT/voice_src.wav" -ac 1 -ar 48000 "$OUT/voice.wav" \
    || { rm -f "$OUT/voice.wav"; echo "Erreur : voix échouée" >&2; exit 1; }
  rm -f "$OUT/voice_src.wav"
fi
OK=1
progress done "terminé"
