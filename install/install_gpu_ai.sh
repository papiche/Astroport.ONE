#!/bin/bash
################################################################################
# install_gpu_ai.sh — Détection GPU + installation Ollama (systemd) & ComfyUI (venv+systemd)
#
# Paramètres de référence sagittarius :
#   Ollama  : User=ollama, OLLAMA_HOST=0.0.0.0, FLASH_ATTENTION=1, NUM_PARALLEL=2
#   ComfyUI : ~/comfyui_env/ + ~/workspace/ComfyUI/ --highvram --listen 0.0.0.0
#
# Variables d'entrée (mode silencieux) :
#   INSTALL_OLLAMA=yes|no|ask   (défaut: ask)
#   INSTALL_COMFYUI=yes|no|ask  (défaut: ask)
#
# License: AGPL-3.0
################################################################################

## ── Détection GPU ─────────────────────────────────────────────────────────────
GPU_NAME=""
GPU_VRAM=0
GPU_VENDOR="unknown"

if command -v nvidia-smi >/dev/null 2>&1; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null \
        | head -1 | xargs)
    GPU_VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null \
        | awk '{sum+=$1} END {printf "%.0f", sum/1024}')
    GPU_VENDOR="nvidia"
fi

## Fallback lspci (AMD, Intel, NVIDIA sans driver installé)
if [[ -z "$GPU_NAME" ]] && command -v lspci >/dev/null 2>&1; then
    GPU_NAME=$(lspci 2>/dev/null | grep -iE 'VGA|3D|Display' \
        | head -1 | sed 's/^.*: //' | xargs)
    echo "$GPU_NAME" | grep -qi 'amd\|radeon' && GPU_VENDOR="amd"
    echo "$GPU_NAME" | grep -qi 'nvidia'       && GPU_VENDOR="nvidia"
    echo "$GPU_NAME" | grep -qi 'intel'        && GPU_VENDOR="intel"
fi

if [[ -z "$GPU_NAME" ]]; then
    echo "   Aucun GPU détecté — Ollama/ComfyUI ignorés."
    exit 0
fi

## ── Affichage GPU ─────────────────────────────────────────────────────────────
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🔥 GPU DÉTECTÉ                                             ║"
echo "╠══════════════════════════════════════════════════════════════╣"
printf  "║  %-58s ║\n" "GPU    : ${GPU_NAME}"
[[ $GPU_VRAM -gt 0 ]] && \
printf  "║  %-58s ║\n" "VRAM   : ${GPU_VRAM} Go"
printf  "║  %-58s ║\n" "Vendor : ${GPU_VENDOR}"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Services recommandés :                                     ║"
echo "║    • Ollama    — LLM local (systemd, port 11434)            ║"
echo "║    • ComfyUI   — Génération d'images (venv+systemd, :8188)  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

## ── Helper interactif ─────────────────────────────────────────────────────────
_ask_yes() {
    local var_name="$1"
    local question="$2"
    local val="${!var_name:-ask}"
    if   [[ "$val" == "yes" ]]; then return 0
    elif [[ "$val" == "no"  ]]; then return 1
    elif [[ -t 0 ]]; then
        read -rp "  ${question} [O/n] : " _ans
        [[ "${_ans,,}" == "n" ]] && return 1 || return 0
    else
        echo "  (non-interactif) → ${question} : OUI"
        return 0
    fi
}

## ── Sélectionner le flag VRAM pour ComfyUI ────────────────────────────────────
if   [[ $GPU_VRAM -ge 8 ]]; then COMFYUI_VRAM_FLAG="--highvram"
elif [[ $GPU_VRAM -ge 4 ]]; then COMFYUI_VRAM_FLAG="--normalvram"
elif [[ $GPU_VRAM -gt 0 ]]; then COMFYUI_VRAM_FLAG="--lowvram"
else                              COMFYUI_VRAM_FLAG="--cpu"
fi

## ══════════════════════════════════════════════════════════════════════════════
## OLLAMA
## ══════════════════════════════════════════════════════════════════════════════
OLLAMA_INSTALLED=false

if _ask_yes INSTALL_OLLAMA "Installer Ollama (LLM local, systemd, port 11434) ?"; then

    if command -v ollama >/dev/null 2>&1; then
        echo "  ✅ Ollama déjà installé : $(ollama --version 2>/dev/null)"
        OLLAMA_INSTALLED=true
    else
        echo "  ⏳ Installation Ollama via script officiel..."
        curl -fsSL https://ollama.com/install.sh | sh
        if ! command -v ollama >/dev/null 2>&1; then
            echo "  ❌ Ollama — installation échouée"
        fi
    fi

    if command -v ollama >/dev/null 2>&1; then
        OLLAMA_INSTALLED=true

        ## ── Patch du service systemd avec les paramètres optimisés ──────────
        ## Utilise un drop-in override pour ne pas toucher au service principal
        ## (résiste aux mises à jour Ollama qui réécrivent /etc/systemd/system/ollama.service)
        OLLAMA_OVERRIDE_DIR="/etc/systemd/system/ollama.service.d"
        sudo mkdir -p "${OLLAMA_OVERRIDE_DIR}"

        cat << EOF | sudo tee "${OLLAMA_OVERRIDE_DIR}/astroport.conf" > /dev/null
# Override généré par Astroport.ONE install_gpu_ai.sh
# Paramètres de référence : sagittarius
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
Environment="OLLAMA_FLASH_ATTENTION=1"
Environment="OLLAMA_NUM_PARALLEL=2"
Environment="OLLAMA_KV_CACHE_TYPE=q4_0"
Environment="OLLAMA_MAX_LOADED_MODELS=2"
EOF

        if [[ "$GPU_VENDOR" == "nvidia" && -n "$GPU_VRAM" && "$GPU_VRAM" -gt 0 ]]; then
            echo 'Environment="CUDA_VISIBLE_DEVICES=0"' \
                | sudo tee -a "${OLLAMA_OVERRIDE_DIR}/astroport.conf" > /dev/null
        fi

        sudo systemctl daemon-reload
        sudo systemctl enable --now ollama
        sudo systemctl restart ollama
        echo "  ✅ Ollama actif (systemd + override Astroport)"
        echo "  ✅ OLLAMA_HOST=0.0.0.0 → accessible depuis la constellation"

        ## Suggestions de modèles selon VRAM
        echo ""
        echo "  Modèles suggérés (VRAM : ${GPU_VRAM} Go) :"
        if   [[ $GPU_VRAM -ge 24 ]]; then
            echo "    ollama pull llama3.1:70b"
            echo "    ollama pull mistral"
        elif [[ $GPU_VRAM -ge 8 ]]; then
            echo "    ollama pull mistral"
            echo "    ollama pull phi3:mini"
        elif [[ $GPU_VRAM -gt 0 ]]; then
            echo "    ollama pull phi3:mini"
            echo "    ollama pull gemma:2b"
        else
            echo "    ollama pull phi3:mini   (CPU)"
        fi
    fi
fi

echo ""

## ══════════════════════════════════════════════════════════════════════════════
## COMFYUI — venv Python + systemd (comme sagittarius)
## ══════════════════════════════════════════════════════════════════════════════
COMFYUI_INSTALLED=false

if _ask_yes INSTALL_COMFYUI "Installer ComfyUI (venv Python + systemd, port 8188, flag: ${COMFYUI_VRAM_FLAG}) ?"; then

    COMFYUI_REPO="$HOME/workspace/ComfyUI"
    COMFYUI_VENV="$HOME/comfyui_env"

    ## ── Cloner ComfyUI si absent ──────────────────────────────────────────────
    mkdir -p "$HOME/workspace"
    if [[ -d "$COMFYUI_REPO/.git" ]]; then
        echo "  ✅ ComfyUI déjà cloné — mise à jour..."
        git -C "$COMFYUI_REPO" pull --ff-only 2>/dev/null || true
    else
        echo "  ⏳ Clonage ComfyUI..."
        git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_REPO"
    fi

    if [[ ! -d "$COMFYUI_REPO" ]]; then
        echo "  ❌ Clone ComfyUI échoué"
    else
        ## ── Créer le venv ─────────────────────────────────────────────────────
        if [[ ! -f "$COMFYUI_VENV/bin/activate" ]]; then
            echo "  ⏳ Création venv Python : ${COMFYUI_VENV}"
            python3 -m venv "$COMFYUI_VENV"
        fi

        ## ── Installer PyTorch avec support CUDA ou CPU ────────────────────────
        if [[ "$GPU_VENDOR" == "nvidia" && $GPU_VRAM -gt 0 ]]; then
            echo "  ⏳ Installation PyTorch CUDA..."
            "$COMFYUI_VENV/bin/pip" install --upgrade pip -q
            "$COMFYUI_VENV/bin/pip" install torch torchvision torchaudio \
                --extra-index-url https://download.pytorch.org/whl/cu121 -q \
                && echo "  ✅ PyTorch CUDA installé" \
                || echo "  ⚠️  PyTorch CUDA — essai CPU fallback..."
        else
            echo "  ⏳ Installation PyTorch CPU (pas de NVIDIA)..."
            "$COMFYUI_VENV/bin/pip" install --upgrade pip -q
            "$COMFYUI_VENV/bin/pip" install torch torchvision torchaudio -q
        fi

        ## ── Dépendances ComfyUI ───────────────────────────────────────────────
        echo "  ⏳ Installation dépendances ComfyUI..."
        "$COMFYUI_VENV/bin/pip" install -r "$COMFYUI_REPO/requirements.txt" -q \
            && echo "  ✅ Dépendances ComfyUI installées"

        ## ── Service systemd ───────────────────────────────────────────────────
        cat << EOF | sudo tee /etc/systemd/system/comfyui.service > /dev/null
[Unit]
Description=ComfyUI — Image Generation
After=network.target
$(systemctl is-enabled ollama 2>/dev/null | grep -q enabled && echo "Wants=ollama.service")

[Service]
Type=simple
User=${USER}
WorkingDirectory=${COMFYUI_REPO}
ExecStart=${COMFYUI_VENV}/bin/python ${COMFYUI_REPO}/main.py ${COMFYUI_VRAM_FLAG} --preview-method auto --listen 0.0.0.0
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

        sudo systemctl daemon-reload
        sudo systemctl enable --now comfyui
        sleep 3

        if systemctl is-active --quiet comfyui; then
            COMFYUI_INSTALLED=true
            echo "  ✅ ComfyUI actif → http://localhost:8188"
            echo "  📁 Modèles    : ${COMFYUI_REPO}/models/checkpoints/"
            echo "  📁 Sorties    : ${COMFYUI_REPO}/output/"
        else
            echo "  ⚠️  ComfyUI non actif — vérifiez :"
            echo "       sudo journalctl -u comfyui -n 30"
        fi

        echo ""
        echo "  ℹ️  Pour télécharger un checkpoint Stable Diffusion :"
        echo "     wget -P ${COMFYUI_REPO}/models/checkpoints/ \\"
        echo "       https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.ckpt"
    fi
fi

echo ""

## ── Résumé ─────────────────────────────────────────────────────────────────────
if [[ "$OLLAMA_INSTALLED" == "true" || "$COMFYUI_INSTALLED" == "true" ]]; then
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  🧠 SERVICES GPU INSTALLÉS                                  ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    [[ "$OLLAMA_INSTALLED"  == "true" ]] && \
    echo "║  ✅ Ollama     http://localhost:11434  (OLLAMA_HOST=0.0.0.0)║"
    [[ "$COMFYUI_INSTALLED" == "true" ]] && \
    echo "║  ✅ ComfyUI    http://localhost:8188   (${COMFYUI_VRAM_FLAG})$(printf '%*s' $((20-${#COMFYUI_VRAM_FLAG})) '')║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  Détectés automatiquement par heartbox_analysis.sh         ║"
    echo "║  Publiés dans la constellation via DRAGON_p2p_ssh.sh       ║"
    echo "║  → astrosystemctl list                                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
fi
