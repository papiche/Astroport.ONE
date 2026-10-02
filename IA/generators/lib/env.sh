#!/bin/bash
#### lib/env.sh : chemins des outils des générateurs (source, ne s'exécute pas)
#
# Chaque variable peut être imposée par l'environnement ; sinon détection :
#   FFMPEG / FFPROBE  ffmpeg avec le filtre drawtext (/usr/bin d'abord, puis PATH)
#   COMFY_PY          python du venv ComfyUI (~/comfyui_env), repli python3
#                     (pronounce.py n'utilise que la bibliothèque standard ;
#                      image_to_3dscene.py exige trimesh/numpy/PIL du venv)
#   ASTRO_PY          python du venv Astroport (~/.astro) avec playwright, repli python3
#   COMFYUI_DIR       dépôt ComfyUI (~/workspace/ComfyUI)
#   SCENES_DIR        acteurs et rendus (~/.zen/workspace/scenes)

_pick_ffmpeg() {
  local d
  for d in /usr/bin "$(dirname "$(command -v ffmpeg 2>/dev/null)")"; do
    [ -x "$d/ffmpeg" ] && "$d/ffmpeg" -hide_banner -filters 2>/dev/null | grep -q drawtext \
      && { FFMPEG="$d/ffmpeg" FFPROBE="$d/ffprobe"; return; }
  done
  FFMPEG=$(command -v ffmpeg) FFPROBE=$(command -v ffprobe)   # sans drawtext : les titres seront ignorés
}
if [ -z "$FFMPEG" ] || [ -z "$FFPROBE" ]; then _pick_ffmpeg; fi
if [ -z "$FFMPEG" ]; then echo "Erreur : ffmpeg introuvable (apt install ffmpeg)" >&2; exit 1; fi

_pick_python() {  # $1 venv python préféré
  [ -x "$1" ] && { echo "$1"; return; }
  command -v python3
}
COMFY_PY="${COMFY_PY:-$(_pick_python "$HOME/comfyui_env/bin/python")}"
ASTRO_PY="${ASTRO_PY:-$(_pick_python "$HOME/.astro/bin/python")}"
COMFYUI_DIR="${COMFYUI_DIR:-$HOME/workspace/ComfyUI}"
SCENES_DIR="${SCENES_DIR:-$HOME/.zen/workspace/scenes}"
#   QWEN3TTS_PY       python du venv Qwen3-TTS (~/qwen3tts_env, install/install_qwen3_tts.sh) ;
#                     vide si absent : generate_scene.sh retombe sur MiniMax pour les voix
[ -z "$QWEN3TTS_PY" ] && [ -x "$HOME/qwen3tts_env/bin/python" ] && QWEN3TTS_PY="$HOME/qwen3tts_env/bin/python"
