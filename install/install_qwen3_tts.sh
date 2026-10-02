#!/bin/bash
################################################################################
# install_qwen3_tts.sh — Qwen3-TTS (voix d'acteurs) dans un venv dédié
#
# Venv séparé (~/qwen3tts_env) : le paquet qwen-tts impose transformers==4.57.3,
# ce qui casserait le venv ComfyUI (transformers 5.x, MiniMax H3).
# Utilisé par IA/generators/generate_voice.py (modèle VoiceDesign : une voix à
# partir d'une description en langage naturel) et par generate_scene.sh.
#
# Variables : QWEN3TTS_VENV=~/qwen3tts_env 
# License: AGPL-3.0
################################################################################
QWEN3TTS_VENV="${QWEN3TTS_VENV:-$HOME/qwen3tts_env}"

command -v nvidia-smi >/dev/null 2>&1 || echo "  ⚠️  pas de GPU NVIDIA : Qwen3-TTS fonctionnera sur CPU (lent)"
if [[ ! -x "$QWEN3TTS_VENV/bin/python" ]]; then
    echo "  ⏳ venv $QWEN3TTS_VENV"
    python3 -m venv "$QWEN3TTS_VENV" || { echo "  ❌ venv impossible (apt install python3-venv)"; exit 1; }
fi
"$QWEN3TTS_VENV/bin/pip" install -q -U pip
"$QWEN3TTS_VENV/bin/pip" install -q -U qwen-tts soundfile \
    && echo "  ✅ qwen-tts installé" || { echo "  ❌ pip install qwen-tts échoué"; exit 1; }

models=(Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign Qwen/Qwen3-TTS-12Hz-1.7B-Base)
for m in "${models[@]}"; do
    echo "  ⏳ modèle $m"
    "$QWEN3TTS_VENV/bin/python" -c "from huggingface_hub import snapshot_download as d; d('$m')" \
        && echo "  ✅ $m" || echo "  ❌ $m échoué (relancer pour reprendre)"
done
