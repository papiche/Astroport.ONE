#!/bin/bash
# Dependencies : jq curl ffmpeg python3
#### generate_transcription.sh : transcrit un audio ou une vidéo avec Phonon-2 (nœud SpeechToText de ComfyUI)
#
# Usage: $0 <fichier|url> [format] [output_dir]
#   fichier     audio ou vidéo local, ou URL http(s)/IPFS d'un média
#   format      txt | srt | vtt | json | words | all (défaut : all)
#   output_dir  dossier de sortie (défaut : ~/.zen/tmp.media/transcription_<id>)
#
# Sorties : <nom>.txt <nom>.srt <nom>.vtt <nom>.json (mots + horodatages) <nom>.words.txt
#   - format unique : son contenu est écrit sur stdout
#   - all           : un objet JSON {text, srt, vtt, words, files, ipfs} est écrit sur stdout
#
# Prérequis ComfyUI : nœud SpeechToText + modèle phonon-2.safetensors dans models/audio_encoders
# (conversion : ComfyUI/script_examples/convert_phonon2.py). PHONON_MODEL force un autre nom de fichier.

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"

if [ -z "$1" ]; then
  echo "Usage: $0 <fichier|url> [txt|srt|vtt|json|words|all] [output_dir]" >&2
  exit 1
fi

INPUT="$1"
FORMAT="${2:-all}"
case "$FORMAT" in
  txt|srt|vtt|json|words|all) ;;
  *) echo "Erreur : format inconnu '$FORMAT' (txt srt vtt json words all)" >&2; exit 1 ;;
esac

. "${HOME}/.zen/Astroport.ONE/tools/my.sh"
. "${MY_PATH}/lib/env.sh"

COMFYUI_URL="${COMFYUI_URL:-http://127.0.0.1:8188}"
MAX_WAIT="${MAX_WAIT:-900}"
UNIQUE_ID=$(date +%s)_$(openssl rand -hex 4)
OUTPUT_DIR="${3:-$HOME/.zen/tmp.media/transcription_${UNIQUE_ID}}"
WORK_DIR="$HOME/.zen/tmp.media/transcribe_work_${UNIQUE_ID}"
mkdir -p "$OUTPUT_DIR" "$WORK_DIR"
trap 'rm -rf "$WORK_DIR"' EXIT

# 1. Média source : téléchargement si URL, puis audio mono 16 kHz
if [[ "$INPUT" =~ ^https?:// ]]; then
  SRC="$WORK_DIR/source_media"
  curl -sfL -o "$SRC" "$INPUT" || { echo "Erreur : téléchargement impossible : $INPUT" >&2; exit 1; }
  NAME="$(basename "${INPUT%%\?*}")"
else
  SRC="$INPUT"
  NAME="$(basename "$INPUT")"
fi
[ -s "$SRC" ] || { echo "Erreur : fichier introuvable ou vide : $INPUT" >&2; exit 1; }
BASENAME="${NAME%.*}"
[ -n "$BASENAME" ] || BASENAME="transcription"

AUDIO_NAME="phonon_${UNIQUE_ID}.wav"
"$FFMPEG" -v error -y -i "$SRC" -vn -ac 1 -ar 16000 "$WORK_DIR/$AUDIO_NAME" \
  || { echo "Erreur : ffmpeg n'a pas pu extraire l'audio de $INPUT" >&2; exit 1; }

# 2. ComfyUI : port, nœud SpeechToText, modèle Phonon-2
if ! curl -s -m 5 "$COMFYUI_URL/system_stats" > /dev/null; then
  echo "Erreur : ComfyUI inaccessible sur $COMFYUI_URL" >&2
  exit 1
fi
if ! curl -s -m 5 "$COMFYUI_URL/object_info/SpeechToText" | jq -e '.SpeechToText' > /dev/null 2>&1; then
  echo "Erreur : nœud SpeechToText absent, mettre à jour ComfyUI et le redémarrer" >&2
  exit 1
fi
MODEL="${PHONON_MODEL:-$(curl -s -m 5 "$COMFYUI_URL/object_info/AudioEncoderLoader" \
  | jq -r '.AudioEncoderLoader.input.required.audio_encoder_name | (.[1].options // .[0])[]?' | grep -i phonon | head -n 1)}"
if [ -z "$MODEL" ]; then
  echo "Erreur : phonon-2.safetensors absent de models/audio_encoders" >&2
  echo "  tar --zstd -xf phonon-2.bps.tar.zst && python ComfyUI/script_examples/convert_phonon2.py model.fermion phonon-2.safetensors" >&2
  exit 1
fi
echo "Modèle : $MODEL" >&2

# 3. Envoi de l'audio dans le dossier input de ComfyUI
curl -sf -F "image=@$WORK_DIR/$AUDIO_NAME" -F "overwrite=true" "$COMFYUI_URL/upload/image" > /dev/null \
  || { echo "Erreur : envoi de l'audio à ComfyUI impossible" >&2; exit 1; }

# 4. Workflow : LoadAudio -> SpeechToText -> PreviewAny (texte) + PreviewAny (horodatages)
PAYLOAD=$(jq -n --arg audio "$AUDIO_NAME" --arg model "$MODEL" '{prompt: {
  "1": {class_type: "LoadAudio", inputs: {audio: $audio}},
  "2": {class_type: "AudioEncoderLoader", inputs: {audio_encoder_name: $model}},
  "3": {class_type: "SpeechToText", inputs: {audio_encoder: ["2", 0], audio: ["1", 0]}},
  "4": {class_type: "PreviewAny", inputs: {source: ["3", 0]}},
  "5": {class_type: "PreviewAny", inputs: {source: ["3", 1]}}
}}')
RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$COMFYUI_URL/prompt")
PROMPT_ID=$(echo "$RESPONSE" | jq -r '.prompt_id // empty')
if [ -z "$PROMPT_ID" ]; then
  echo "Erreur : workflow refusé par ComfyUI : $RESPONSE" >&2
  exit 1
fi
echo "Prompt ID : $PROMPT_ID" >&2

# 5. Attente du résultat
HISTORY=""
for ((waited = 0; waited < MAX_WAIT; waited += 2)); do
  HISTORY=$(curl -s "$COMFYUI_URL/history/$PROMPT_ID" | jq --arg id "$PROMPT_ID" '.[$id] // empty')
  [ -n "$HISTORY" ] && break
  sleep 2
done
[ -n "$HISTORY" ] || { echo "Erreur : délai dépassé (${MAX_WAIT}s)" >&2; exit 1; }
if [ "$(echo "$HISTORY" | jq -r '.status.status_str')" = "error" ]; then
  echo "Erreur ComfyUI : $(echo "$HISTORY" | jq -r '[.status.messages[] | select(.[0]=="execution_error") | .[1].exception_message][-1]')" >&2
  exit 1
fi
echo "$HISTORY" | jq -r '.outputs["4"].text[0] // empty' > "$WORK_DIR/text.txt"
echo "$HISTORY" | jq -r '.outputs["5"].text[0] // empty' > "$WORK_DIR/timestamps.txt"

# 6. Formats : lignes "[début - fin] mot" -> txt, srt, vtt, json, words
RESULT=$(python3 - "$WORK_DIR" "$OUTPUT_DIR" "$BASENAME" <<'PY'
import json, re, sys

work, out, base = sys.argv[1:4]
text = open(f"{work}/text.txt", encoding="utf-8").read().strip()
words = [{"start": float(m[0]), "end": float(m[1]), "word": m[2]}
         for m in re.findall(r"^\[([\d.]+) - ([\d.]+)\] (.*)$", open(f"{work}/timestamps.txt", encoding="utf-8").read(), re.M)]

# sous-titres : coupe sur fin de phrase, pause > 1 s, 7 s ou 12 mots
cues, cue = [], []
for w in words:
    if cue and (w["start"] - cue[-1]["end"] > 1.0 or w["end"] - cue[0]["start"] > 7.0 or len(cue) >= 12):
        cues.append(cue)
        cue = []
    cue.append(w)
    if w["word"][-1] in ".?!…":
        cues.append(cue)
        cue = []
if cue:
    cues.append(cue)

def stamp(t, sep):
    ms = round(t * 1000)
    return f"{ms // 3600000:02}:{ms // 60000 % 60:02}:{ms // 1000 % 60:02}{sep}{ms % 1000:03}"

def subtitles(header, sep):
    body = "\n\n".join(f"{i}\n{stamp(c[0]['start'], sep)} --> {stamp(c[-1]['end'], sep)}\n{' '.join(w['word'] for w in c)}" for i, c in enumerate(cues, 1))
    return header + body + "\n"

files = {
    "txt": text + "\n",
    "srt": subtitles("", ","),
    "vtt": subtitles("WEBVTT\n\n", "."),
    "json": json.dumps({"text": text, "words": words}, ensure_ascii=False, indent=2) + "\n",
    "words": "".join(f"[{w['start']:.2f} - {w['end']:.2f}] {w['word']}\n" for w in words),
}
paths = {}
for ext, content in files.items():
    paths[ext] = f"{out}/{base}.words.txt" if ext == "words" else f"{out}/{base}.{ext}"
    open(paths[ext], "w", encoding="utf-8").write(content)
print(json.dumps({"text": text, "srt": files["srt"], "vtt": files["vtt"], "words": words, "files": paths}, ensure_ascii=False))
PY
)
[ -n "$RESULT" ] || { echo "Erreur : mise en forme de la transcription impossible" >&2; exit 1; }
if [ -z "$(echo "$RESULT" | jq -r '.text')" ]; then
  echo "Aucune parole détectée" >&2
fi

if [ "$FORMAT" != "all" ]; then
  FILE_PATH=$(echo "$RESULT" | jq -r --arg f "$FORMAT" '.files[$f]')
  cat "$FILE_PATH"
  exit 0
fi

# Dossier ajouté à IPFS si disponible
IPFS_URL=""
if command -v ipfs > /dev/null; then
  IPFS_HASH=$(ipfs add -rwq "$OUTPUT_DIR" 2>/dev/null | tail -n 1)
  [ -n "$IPFS_HASH" ] && IPFS_URL="$myIPFS/ipfs/$IPFS_HASH"
fi
echo "$RESULT" | jq --arg ipfs "$IPFS_URL" '. + {ipfs: $ipfs}'
