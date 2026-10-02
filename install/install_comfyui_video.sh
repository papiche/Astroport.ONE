#!/bin/bash
################################################################################
# install_comfyui_video.sh — Prérequis ComfyUI des générateurs vidéo (IA/generators/)
#
# Pour generate_scene.sh / generate_minimax.sh / generate_image.sh / generate_3dscene.sh
# (voir docs/how-to/VIDEO_GENERATION_MINIMAX.md). Idempotent : relançable à volonté.
#
#   1. paquets système : ffmpeg (drawtext), jq, qrencode, polices DejaVu
#   2. venv Astroport (~/.astro) : playwright + chromium (captures d'écran, cartons)
#   3. venv ComfyUI (~/comfyui_env) : trimesh, numpy, pillow (image_to_3dscene.py)
#   4. ComfyUI : pack KJNodes (VRAM_Debug), pack MultiGPU désactivé,
#      service sans --highvram (sinon OOM au décodage VAE)
#   5. modèles (~60 Go, GPU ≥ 24 Go) : MiniMax H3, Z-Image Turbo, SeedVR2
#
# Variables (toutes optionnelles) :
#   COMFYUI_DIR=~/workspace/ComfyUI   COMFYUI_VENV=~/comfyui_env   ASTRO_VENV=~/.astro
#   COMFYUI_VIDEO_MODELS=yes|no|ask   (défaut ask ; non interactif → no)
#   COMFYUI_VIDEO_SEEDVR2=yes|no      (défaut no : upscale lent, optionnel)
#   HF_TOKEN=...                      (jeton HuggingFace si les dépôts l'exigent)
#
# License: AGPL-3.0
################################################################################

COMFYUI_DIR="${COMFYUI_DIR:-$HOME/workspace/ComfyUI}"
COMFYUI_VENV="${COMFYUI_VENV:-$HOME/comfyui_env}"
ASTRO_VENV="${ASTRO_VENV:-$HOME/.astro}"
MODELS="$COMFYUI_DIR/models"

if [[ ! -f "$COMFYUI_DIR/main.py" ]]; then
    echo "  ❌ ComfyUI absent ($COMFYUI_DIR) — lancer d'abord install_gpu_ai.sh (INSTALL_COMFYUI=yes)"
    exit 1
fi

## ── 1. Paquets système ──────────────────────────────────────────────────────
_missing=()
for _p in ffmpeg jq qrencode curl git; do command -v "$_p" >/dev/null 2>&1 || _missing+=("$_p"); done
fc-list 2>/dev/null | grep -qi dejavu || _missing+=(fonts-dejavu-core)
if [[ ${#_missing[@]} -gt 0 ]]; then
    echo "  ⏳ apt : ${_missing[*]}"
    sudo apt-get install -y "${_missing[@]}" >/dev/null 2>&1 || echo "  ⚠️  apt install ${_missing[*]} échoué"
fi
## Le filtre drawtext (titres incrustés) manque à certains builds ffmpeg
if ! /usr/bin/ffmpeg -hide_banner -filters 2>/dev/null | grep -q drawtext \
   && ! ffmpeg -hide_banner -filters 2>/dev/null | grep -q drawtext; then
    echo "  ⚠️  ffmpeg sans filtre drawtext — titres ignorés (apt install ffmpeg)"
fi

## ── 2. Playwright (venv Astroport) ──────────────────────────────────────────
if [[ -x "$ASTRO_VENV/bin/python" ]]; then
    "$ASTRO_VENV/bin/python" -c "import playwright" 2>/dev/null \
        || "$ASTRO_VENV/bin/pip" install -q playwright
    if ! ls "$HOME"/.cache/ms-playwright/chromium-* >/dev/null 2>&1; then
        echo "  ⏳ Chromium pour Playwright..."
        "$ASTRO_VENV/bin/python" -m playwright install chromium >/dev/null 2>&1 \
            || echo "  ⚠️  playwright install chromium échoué"
    fi
else
    echo "  ⚠️  venv Astroport absent ($ASTRO_VENV) — captures d'écran indisponibles (repli python3)"
fi

## ── 3. Dépendances Python du venv ComfyUI ───────────────────────────────────
if [[ -x "$COMFYUI_VENV/bin/pip" ]]; then
    "$COMFYUI_VENV/bin/pip" install -q trimesh numpy pillow \
        && echo "  ✅ trimesh/numpy/pillow (venv ComfyUI)"
fi

## ── 4. Custom nodes et service ──────────────────────────────────────────────
CN="$COMFYUI_DIR/custom_nodes"
mkdir -p "$CN"
shopt -s nullglob
_kj=("$CN"/*[Kk][Jj][Nn]odes)
if [[ ${#_kj[@]} -eq 0 ]]; then
    echo "  ⏳ ComfyUI-KJNodes (VRAM_Debug)..."
    git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes.git "$CN/ComfyUI-KJNodes" \
        && [[ -x "$COMFYUI_VENV/bin/pip" ]] \
        && "$COMFYUI_VENV/bin/pip" install -q -r "$CN/ComfyUI-KJNodes/requirements.txt"
fi
## Le patch ModelPatcher de MultiGPU casse le déchargement des modèles
for _d in "$CN"/*[Mm]ulti[Gg][Pp][Uu]*; do
    [[ -d "$_d" && "$_d" != *.disabled ]] || continue
    mv "$_d" "${_d}.disabled" && echo "  ✅ $(basename "$_d") désactivé (incompatible MiniMax)"
done

_svc=/etc/systemd/system/comfyui.service
if [[ -f "$_svc" ]] && grep -q -- '--highvram' "$_svc"; then
    sudo sed -i 's/ --highvram//' "$_svc" && sudo systemctl daemon-reload \
        && sudo systemctl restart comfyui \
        && echo "  ✅ comfyui.service : --highvram retiré (NORMAL_VRAM requis par MiniMax)"
fi

## ── 5. Modèles ──────────────────────────────────────────────────────────────
GPU_VRAM_GB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null \
    | awk '{s+=$1} END {printf "%.0f", s/1024}')
if [[ ${GPU_VRAM_GB:-0} -lt 24 ]]; then
    echo "  ℹ️  GPU ${GPU_VRAM_GB:-0} Go < 24 Go : MiniMax H3 non utilisable ici."
    echo "     generate_scene.sh passera par un ComfyUI de la constellation (astrosystemctl)."
    exit 0
fi

_want="${COMFYUI_VIDEO_MODELS:-ask}"
if [[ "$_want" == "ask" ]]; then
    if [[ -t 0 ]]; then
        read -rp "  Télécharger les modèles MiniMax H3 + Z-Image (~60 Go) ? [o/N] : " _a
        [[ "${_a,,}" =~ ^(o|y) ]] && _want=yes || _want=no
    else
        _want=no
    fi
fi
[[ "$_want" == "yes" ]] || { echo "  ℹ️  Modèles ignorés (COMFYUI_VIDEO_MODELS=yes pour les télécharger)"; exit 0; }

# $1 dépôt HF, $2 chemin dans le dépôt, $3 destination (sous models/)
_hf() {
    local dest="$MODELS/$3"
    mkdir -p "$(dirname "$dest")"
    if [[ -s "$dest" ]]; then echo "  ✅ $(basename "$dest")"; return 0; fi
    echo "  ⏳ $(basename "$dest")"
    curl -fL -C - --retry 3 ${HF_TOKEN:+-H "Authorization: Bearer $HF_TOKEN"} \
        -o "$dest.part" "https://huggingface.co/$1/resolve/main/$2" \
        && mv "$dest.part" "$dest" || { echo "  ❌ $(basename "$dest") échoué (relancer pour reprendre)"; return 1; }
}

_mm=Comfy-Org/MiniMax-H3 _zi=Comfy-Org/z_image_turbo
_hf $_mm diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors  diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors
_hf $_mm diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors
_hf $_mm text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors         text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors
_hf $_mm vae/minimax_h3_video_vae_fp16.safetensors                          vae/minimax_h3_video_vae_fp16.safetensors
_hf $_mm vae/minimax_h3_audio_vae_fp32.safetensors                          vae/minimax_h3_audio_vae_fp32.safetensors
_hf $_zi split_files/diffusion_models/z_image_turbo_int8_convrot.safetensors diffusion_models/z_image_turbo_int8_convrot.safetensors
_hf $_zi split_files/text_encoders/qwen_3_4b_fp8_mixed.safetensors          text_encoders/qwen_3_4b_fp8_mixed.safetensors
_hf $_zi split_files/vae/ae.safetensors                                     vae/ae.safetensors
if [[ "${COMFYUI_VIDEO_SEEDVR2:-no}" == "yes" ]]; then
    _hf Comfy-Org/SeedVR2 diffusion_models/seedvr2_3b_int8_convrot.safetensors diffusion_models/seedvr2_3b_int8_convrot.safetensors
    _hf Comfy-Org/SeedVR2 vae/seedvr2_ema_vae_fp16.safetensors                 vae/seedvr2_ema_vae_fp16.safetensors
fi

sudo systemctl restart comfyui 2>/dev/null
echo "  ✅ Prérequis vidéo ComfyUI en place — essai : IA/generators/generate_scene.sh IA/generators/storyboard.example.json"
