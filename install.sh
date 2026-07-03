#!/bin/bash
umask 077
############################################################ install.sh
# Version: 0.5 (Modifié pour forcer MAJ apt/pip)
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
{
## Détection emplacement script et initialisation "MY_PATH"
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
start=`date +%s`
################################################################## HELP
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "================================================================="
    echo "                 🚀 ASTROPORT.ONE INSTALLER 🚀                 "
    echo "================================================================="
    echo "Usage :"
    echo "  bash install.sh [EMAIL] [NODE_DOMAIN] [EMAIL_DOMAIN] [PROFILE]"
    echo ""
    echo "Options :"
    echo "  --help, -h       Affiche cette aide et quitte."
    echo ""
    echo "Paramètres positionnels (optionnels) :"
    echo "  1. EMAIL         Email du Capitaine (ex: alice@mail.com)."
    echo "                   Laissez vide (\"\") pour un email automatique."
    echo "  2. NODE_DOMAIN   Domaine du Nœud/Armateur (ex: ma-base.org)."
    echo "                   Laissez vide (\"\") pour copylaradio.com."
    echo "  3. EMAIL_DOMAIN  Domaine pour l'email captainerie (ex: mon-asso.org)."
    echo "                   Laissez vide (\"\") pour qo-op.com."
    echo "  4. PROFILE       Profil d'installation (voir ci-dessous)."
    echo "                   Laissez vide pour l'installation standard."
    echo ""
    echo "Profils disponibles :"
    echo "  (vide)         Standard : IPFS + Nostr strfry + UPassport + Astroport + Qdrant (si score ≥ 11)"
    echo "  nextcloud      Standard + NextCloud AIO (cloud privé 128Go pour ZEN Card)"
    echo "  ai-company  Standard + Stack IA (Ollama + Dify.ai + Open WebUI + Qdrant)"
    echo "                 → install-ai-company.docker.sh + code_assistant"
    echo "  dev            Standard + rnostr (remplace strfry, sémantique Qdrant)"
    echo ""
    echo "Variables d'environnement supportées :"
    echo "  CAPTAIN_EMAIL, NODE_DOMAIN, CAPTAIN_EMAIL_DOMAIN, INSTALL_PROFILE"
    echo "  INSTALL_OLLAMA=yes|no    → Ollama (si GPU détecté)"
    echo "  INSTALL_COMFYUI=yes|no   → ComfyUI Docker (si GPU détecté)"
    echo "  INSTALL_AI_SERVICES      → Liste des services IA à installer (ex: open-webui,qdrant) (si profil ai-company)"
    echo ""
    echo "Options supplémentaires :"
    echo "  -y, --yes        Mode silencieux : accepte toutes les valeurs par défaut."
    echo "                   Utile pour cron/CI. Peut se placer en 5ème argument."
    echo ""
    echo "Exemples d'installation silencieuse :"
    echo "  bash install.sh \"\" \"ma-base.org\"                    -> Standard sur ma-base.org"
    echo "  bash install.sh \"\" \"\" \"\" nextcloud               -> Standard + NextCloud"
    echo "  bash install.sh \"\" \"\" \"\" ai-company           -> Standard + Stack IA"
    echo "  bash install.sh \"contact@me.com\" \"\" \"\" dev       -> Dev (rnostr)"
    echo "  bash install.sh \"\" \"\" \"\" \"\" -y                 -> Upgrade silencieux (cron)"
    echo "================================================================="
    exit 0
fi

## Mode silencieux : -y / --yes peut apparaître en n'importe quelle position
_SILENT=false
for _arg in "$@"; do
    [[ "$_arg" == "-y" || "$_arg" == "--yes" ]] && _SILENT=true && break
done
########################################################################
##################################################################  SUDO
##  Lancement "root" interdit...
########################################################################
[ $(id -u) -eq 0 ] && echo "LANCEMENT root INTERDIT. " && exit 1
[[ ! $(groups | grep -w sudo) && ! $(groups | grep -w wheel) ]] \
    && echo "AUCUN GROUPE sudo/wheel — corrigez puis relancez :" \
    && echo "  su - root -c \"usermod -aG sudo $USER\"" \
    && echo "  (Arch/SteamOS : usermod -aG wheel $USER)" \
    && exit 1

########################################################################
## STEAMOS : vérification du mode Bureau (Gaming Mode incompatible)
########################################################################
if grep -q "SteamOS" /etc/os-release 2>/dev/null; then
    # GAMESCOPE_EMBEDDED est défini quand on est dans la session Gaming (gamescope)
    if [[ -n "${GAMESCOPE_EMBEDDED:-}" ]] || pgrep -x "gamescope-session" >/dev/null 2>&1; then
        echo "⛔ SteamOS GAMING MODE détecté !"
        echo "   Astroport.ONE doit être installé depuis le MODE BUREAU."
        echo "   → Appuyez sur [Steam] → Basculer vers le Bureau"
        echo "   → Ouvrez Konsole et relancez ce script."
        exit 1
    fi
fi

################################################################## PARAMÈTRES
## $1 = Email Capitaine (ou "" pour auto)
## $2 = Domaine Armateur/Nœud (ou "" pour copylaradio.com)
## $3 = Domaine Email Capitaine (ou "" pour qo-op.com)
## $4 = Profil d'installation  (ou "" pour standard)
########################################################################
export CUSTOM_CAPTAIN_EMAIL="${1:-${CAPTAIN_EMAIL:-}}"
export CUSTOM_NODE_DOMAIN="${2:-${NODE_DOMAIN:-}}"
export CUSTOM_EMAIL_DOMAIN="${3:-${CAPTAIN_EMAIL_DOMAIN:-}}"
export INSTALL_PROFILE="${4:-${INSTALL_PROFILE:-}}"
## Charger la configuration existante si elle est présente
[[ -f ~/.zen/Astroport.ONE/.env ]] && source ~/.zen/Astroport.ONE/.env
export CUSTOM_CAPTAIN_EMAIL="${CUSTOM_CAPTAIN_EMAIL:-${CAPTAIN_EMAIL:-}}"
export CUSTOM_NODE_DOMAIN="${CUSTOM_NODE_DOMAIN:-${NODE_DOMAIN:-}}"
export CUSTOM_EMAIL_DOMAIN="${CUSTOM_EMAIL_DOMAIN:-${CAPTAIN_EMAIL_DOMAIN:-}}"
## Détecter une installation existante via le fichier .player
_PLAYER_FILE="$HOME/.zen/game/players/.current/.player"
if [[ -z "$CUSTOM_CAPTAIN_EMAIL" && -f "$_PLAYER_FILE" ]]; then
    CUSTOM_CAPTAIN_EMAIL=$(cat "$_PLAYER_FILE" | tr -d '[:space:]')
    export _IS_UPGRADE=true
fi

########################################################################
## BACKUP PRÉ-UPGRADE (si installation existante détectée)
## Chaîne crypto sauvegardée : ~/.zen/game ↔ ~/.ssh ↔ ~/.ipfs/{config,swarm.key}
## (Ylevel.sh : SSH ed25519 → IPFS PeerID → G1/Duniter — inséparables)
########################################################################
if [[ "${_IS_UPGRADE:-false}" == "true" ]]; then
    _BACKUP_DIR="/tmp/astroport_backups"
    _BACKUP_FILE="${_BACKUP_DIR}/astroport_$(date +%Y%m%d_%H%M%S).tar.gz"
    mkdir -p "$_BACKUP_DIR"
    echo "🗄️  Backup pré-upgrade → ${_BACKUP_FILE}"

    ## Construire la liste des chemins à archiver (existants seulement)
    _BACKUP_PATHS=()
    [[ -d "$HOME/.zen/game"           ]] && _BACKUP_PATHS+=("$HOME/.zen/game")
    [[ -f "$HOME/.zen/Astroport.ONE/.env" ]] && _BACKUP_PATHS+=("$HOME/.zen/Astroport.ONE/.env")
    [[ -d "$HOME/.ssh"                ]] && _BACKUP_PATHS+=("$HOME/.ssh")
    [[ -f "$HOME/.ipfs/config"        ]] && _BACKUP_PATHS+=("$HOME/.ipfs/config")
    [[ -f "$HOME/.ipfs/swarm.key"     ]] && _BACKUP_PATHS+=("$HOME/.ipfs/swarm.key")
    [[ -d "$HOME/.ipfs/keystore"      ]] && _BACKUP_PATHS+=("$HOME/.ipfs/keystore")

    tar -czf "$_BACKUP_FILE" \
        --exclude="$HOME/.zen/tmp" \
        --exclude="$HOME/.zen/UPassport" \
        --exclude="$HOME/.zen/Astroport.ONE" \
        "${_BACKUP_PATHS[@]}" \
        2>/dev/null \
        && echo "✅ Backup OK — chaîne SSH→IPFS→G1 archivée" \
        && echo "   Restaurer : tar -xzf $_BACKUP_FILE -C /" \
        || echo "⚠️  Backup partiel (certains fichiers inaccessibles)"

    ## Purge automatique des backups > 7 jours
    find "$_BACKUP_DIR" -name "astroport_*.tar.gz" -mtime +7 -delete 2>/dev/null || true

    ## Upgrade : ré-appliquer sudoers et bashrc (nouveaux binaires, nouvelles entrées)
    echo "🔧 Upgrade — réapplication sudoers + .bashrc..."
    bash "${MY_PATH}/install/install_sudoers.sh" || true
    bash "${MY_PATH}/install/install_bashrc.sh"  || true

    ## Détecter une session SSH via tunnel IPFS P2P (source = 127.0.0.1)
    ## Dans ce cas, redémarrer IPFS couperait la connexion SSH active
    _IPFS_TUNNEL_SSH=false
    if [[ -n "${SSH_CONNECTION:-}" ]]; then
        _ssh_src_ip=$(echo "$SSH_CONNECTION" | awk '{print $1}')
        if [[ "$_ssh_src_ip" == "127.0.0.1" ]] || ipfs p2p ls 2>/dev/null | grep -q .; then
            _IPFS_TUNNEL_SSH=true
            echo ""
            echo "⚠️  Tunnel SSH IPFS P2P détecté — le redémarrage d'IPFS sera ignoré"
            echo "   Pour redémarrer IPFS après déconnexion (console locale) :"
            echo "     sudo systemctl restart ipfs"
            echo ""
        fi
    fi
    export _IPFS_TUNNEL_SSH
fi

########################################################################
## DÉTECTION CHANGEMENT DE PROFIL → teardown des anciens services
########################################################################
_OLD_PROFILE=$(grep "^INSTALL_PROFILE=" "$HOME/.zen/Astroport.ONE/.env" 2>/dev/null \
    | cut -d= -f2 | tr -d '"' | xargs)
if [[ -n "$_OLD_PROFILE" && -n "$INSTALL_PROFILE" && \
      "$_OLD_PROFILE" != "$INSTALL_PROFILE" && \
      "$_OLD_PROFILE" != "standard" ]]; then
    echo "🔄 Changement de profil : ${_OLD_PROFILE} → ${INSTALL_PROFILE:-standard}"
    case "$_OLD_PROFILE" in
        dev)
            echo "  ↳ Arrêt rnostr (profil dev obsolète)..."
            sudo systemctl stop rnostr 2>/dev/null && sudo systemctl disable rnostr 2>/dev/null || true
            sudo systemctl start strfry 2>/dev/null && sudo systemctl enable strfry 2>/dev/null || true
            echo "  ✅ strfry réactivé (port 7777)"
            ;;
        ai-company)
            echo "  ↳ Arrêt stack IA Docker (profil ai-company obsolète)..."
            _COMPOSE="$HOME/.zen/Astroport.ONE/docker/docker-compose.yml"
            [[ -f "$_COMPOSE" ]] && \
                docker compose -f "$_COMPOSE" --profile ai down 2>/dev/null || true
            ;;
        nextcloud)
            echo "  ↳ Arrêt NextCloud Docker (profil nextcloud obsolète)..."
            _COMPOSE="$HOME/.zen/Astroport.ONE/docker/docker-compose.yml"
            [[ -f "$_COMPOSE" ]] && \
                docker compose -f "$_COMPOSE" --profile cloud down 2>/dev/null || true
            ;;
    esac
fi

########################################################################
## Dossier de logs centralisé (toutes les erreurs ici, pas dans ~/.zen/ racine)
_LOG_DIR="$HOME/.zen/log"
mkdir -p "$_LOG_DIR"
_INSTALL_LOG="$_LOG_DIR/install.log"
_ERROR_LOG="$_LOG_DIR/install.errors.log"
## Rediriger stderr global vers le log d'install (en plus du terminal)
exec 2> >(tee -a "$_INSTALL_LOG" >&2)
echo "=== INSTALL $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$_INSTALL_LOG"

########################################################################
echo "## HARDWARE CHECK (détection avant toute question) ##"
_AVAIL_KB=$(df . | awk 'NR==2 {print $4}')
[[ ${_AVAIL_KB:-0} -lt 2000000 ]] && echo "❌ Espace disque insuffisant (<2Go)" && exit 1
## Vérification renforcée pour le profil ai-company (Ollama + modèles = 20Go+)
if [[ "${INSTALL_PROFILE}" == "ai-company" ]]; then
    _AVAIL_GB=$(( ${_AVAIL_KB:-0} / 1048576 ))
    if [[ $_AVAIL_GB -lt 20 ]]; then
        echo "❌ Profil ai-company nécessite ≥ 20 Go libres (disponible : ${_AVAIL_GB} Go)"
        echo "   (Ollama ≈ 600 Mo + modèles IA ≥ 4 Go + stack Docker ≈ 5 Go)"
        exit 1
    fi
    echo "✅ Espace disque OK pour ai-company : ${_AVAIL_GB} Go disponibles"
fi
########################################################################
_CPU=$(grep -c "processor" /proc/cpuinfo 2>/dev/null || echo 1)
_RAM=$(awk '/MemTotal/ {printf "%.0f", $2/1048576}' /proc/meminfo 2>/dev/null || echo 0)
_VRAM=0; _GPU_VENDOR="none"; _GPU_NAME=""
if command -v nvidia-smi >/dev/null 2>&1; then
    _v=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null \
        | awk '{sum+=$1} END {printf "%.0f", sum/1024}')
    if [[ -n "$_v" && "$_v" -gt 0 ]]; then
        _VRAM=$_v; _GPU_VENDOR="nvidia"
        _GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 | xargs)
    fi
fi
if [[ $_VRAM -eq 0 ]]; then
    for _sysf in /sys/class/drm/card*/device/mem_info_vram_total; do
        [[ -f "$_sysf" ]] || continue
        _v=$(( $(cat "$_sysf" 2>/dev/null || echo 0) / 1073741824 ))
        [[ "$_v" -gt 0 ]] || continue
        _VRAM=$(( _VRAM + _v ))
        case "$(cat "${_sysf%mem_info_vram_total}vendor" 2>/dev/null)" in
            "0x1002") _GPU_VENDOR="amd" ;;
            "0x8086") _GPU_VENDOR="intel" ;;
            *)        _GPU_VENDOR="unknown" ;;
        esac
    done
fi
if [[ -z "$_GPU_NAME" ]] && command -v lspci >/dev/null 2>&1; then
    _GPU_NAME=$(lspci 2>/dev/null | grep -iE 'VGA|3D|Display' | head -1 | sed 's/^.*: //' | xargs)
    if [[ "$_GPU_VENDOR" == "none" ]]; then
        echo "$_GPU_NAME" | grep -qi 'intel'       && _GPU_VENDOR="intel_integrated"
        echo "$_GPU_NAME" | grep -qi 'amd\|radeon' && _GPU_VENDOR="amd_integrated"
    fi
fi
_SCORE=$(( _VRAM * 4 + _CPU * 2 + _RAM / 2 ))
if   [[ $_SCORE -gt 40 ]]; then _TIER="🔥 Brain-Node"; _RANK="DRAGON COMPUTE"; _MVAL=$(( _SCORE * 12 )); _PAF_DEFAULT=28
elif [[ $_SCORE -gt 10 ]]; then _TIER="⚡ Standard";   _RANK="DRAGON ORIGIN";  _MVAL=$(( _SCORE * 6  )); _PAF_DEFAULT=14
else                             _TIER="🌿 Léger";      _RANK="Nœud Léger";     _MVAL=100;               _PAF_DEFAULT=7
fi

## _env_upsert KEY VALUE FILE — met à jour la clé si présente, sinon l'ajoute
## (copie locale de install/setup/setup.sh::_env_upsert — disponible dès le début du script)
_env_upsert() {
    local _k="$1" _v="$2" _f="$3"
    [[ ! -f "$_f" ]] && return 0
    local _v_esc="${_v//|/\\|}"   # échapper | pour sed
    if grep -q "^${_k}=" "${_f}" 2>/dev/null; then
        sed -i "s|^${_k}=.*|${_k}=${_v_esc}|" "${_f}"
    else
        echo "${_k}=${_v}" >> "${_f}"
    fi
}

## _TOTAL_SAVINGS est accumulé dans le bloc Desktop GUI (si détecté)
## Initialisé ici pour rester défini sur les installs headless
_TOTAL_SAVINGS=0

########################################################################
## EMBARQUEMENT INTERACTIF — affiché si aucun argument CLI fourni
########################################################################
if [[ "${_IS_UPGRADE:-false}" == "true" ]]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║            🔄 MISE À JOUR ASTROPORT.ONE                     ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    printf "║  Capitaine : %-48s ║\n" "$CUSTOM_CAPTAIN_EMAIL"
    printf "║  Matériel  : CPU=%sc  RAM=%sGo  VRAM=%sGo  Score=%s      \n" \
        "$_CPU" "$_RAM" "$_VRAM" "$_SCORE"
    printf "║  Tier      : %-48s ║\n" "$_TIER"
    [[ -n "$_GPU_NAME" ]] && printf "║  GPU       : %-48s ║\n" "${_GPU_NAME} (${_GPU_VENDOR})"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  Installation existante détectée — mise à jour en cours...  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
elif [[ -z "$CUSTOM_CAPTAIN_EMAIL" && -z "$CUSTOM_NODE_DOMAIN" && "$_SILENT" == "false" ]]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║            🚀 EMBARQUEMENT ASTROPORT.ONE                    ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    printf "║  Matériel  : CPU=%sc  RAM=%sGo  VRAM=%sGo  Score=%s        \n" \
        "$_CPU" "$_RAM" "$_VRAM" "$_SCORE"
    printf "║  Tier      : %-48s ║\n" "$_TIER"
    [[ -n "$_GPU_NAME" ]] && printf "║  GPU       : %-48s ║\n" "${_GPU_NAME} (${_GPU_VENDOR})"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  Appuyez sur Entrée pour utiliser les valeurs automatiques. ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    read -r -p "Email Capitaine [auto: support+node...@qo-op.com] : " CUSTOM_CAPTAIN_EMAIL
    read -r -p "Domaine Nœud   [auto: copylaradio.com]            : " CUSTOM_NODE_DOMAIN
fi

[[ -n "$CUSTOM_CAPTAIN_EMAIL" ]] && echo ">>> Email Capitaine : $CUSTOM_CAPTAIN_EMAIL" || echo ">>> Email Capitaine : Automatique"
[[ -n "$CUSTOM_NODE_DOMAIN" ]]   && echo ">>> Domaine Nœud    : $CUSTOM_NODE_DOMAIN"   || echo ">>> Domaine Nœud    : Automatique (copylaradio.com)"
[[ -n "$CUSTOM_EMAIL_DOMAIN" ]]  && echo ">>> Domaine Email   : $CUSTOM_EMAIL_DOMAIN"  || echo ">>> Domaine Email   : Automatique (qo-op.com)"

## Sélection du profil si non fourni en argument ($4)
if [[ -z "$INSTALL_PROFILE" && "${_IS_UPGRADE:-false}" != "true" && "$_SILENT" == "false" ]]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  PROFIL D'INSTALLATION    (Tier : ${_TIER})                 "
    echo "╠══════════════════════════════════════════════════════════════╣"
    if [[ $_SCORE -gt 10 ]]; then
    echo "║  (vide)     Standard — IPFS + NOSTR + G1 + Qdrant (recommandé)║"
    else
    echo "║  (vide)     Standard — IPFS + NOSTR + G1  (recommandé)     ║"
    fi
    echo "║  nextcloud  Standard + NextCloud AIO  (cloud privé 128Go)  ║"
    if [[ $_SCORE -gt 10 ]]; then
    echo "║  ai-company Standard + Stack IA  (Ollama, Open WebUI, Qdrant)║"
    else
    echo "║  ai-company ⚠️  Score faible — stack IA déconseillée         ║"
    fi
    echo "║  dev        Standard + rnostr  (relay NOSTR Rust — devs)   ║"
    _ARCH=$(uname -m)
    if [[ "$_SCORE" -le 10 && ( "$_ARCH" == "aarch64" || "$_ARCH" == "armv7l" ) ]]; then
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  sound-spot 🎵 RPi WiFi AP audio (Icecast+Snapcast+BT+ẑen) ║"
    echo "║             → clone + lance deploy_on_pi.sh, sort d'ici     ║"
    fi
    echo "╚══════════════════════════════════════════════════════════════╝"
    read -r -p "Profil [standard] : " INSTALL_PROFILE
fi
echo ">>> Profil : ${INSTALL_PROFILE:-standard}"

## ── Aiguillage sound-spot (avant toute installation Astroport) ──────────
if [[ "${INSTALL_PROFILE}" == "sound-spot" ]]; then
    _SS_DIR="${HOME}/.zen/workspace/sound-spot"
    echo ""
    echo "🎵  Profil sound-spot sélectionné — démarrage de l'aiguillage RPi..."
    mkdir -p "${HOME}/.zen/workspace"
    if [[ ! -d "$_SS_DIR/.git" ]]; then
        git clone --depth=1 https://github.com/papiche/sound-spot "$_SS_DIR" \
            && echo "✅ sound-spot cloné → ${_SS_DIR}" \
            || { echo "⚠️  Clonage sound-spot échoué (vérifier la connexion Internet)"; exit 1; }
    else
        echo "✅ sound-spot déjà présent dans ${_SS_DIR} — mise à jour..."
        git -C "$_SS_DIR" pull --ff-only 2>/dev/null || true
    fi
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Lancez maintenant l'installation SoundSpot :"
    echo "    sudo bash ${_SS_DIR}/deploy_on_pi.sh"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
fi

_env_upsert "INSTALL_PROFILE" "${INSTALL_PROFILE:-standard}" "${HOME}/.zen/Astroport.ONE/.env"

########################################################################
## NOM DE LA MACHINE
########################################################################
if [[ -z "${CUSTOM_MACHINE_NAME:-}" && "$_SILENT" == "false" && "${_IS_UPGRADE:-false}" != "true" ]]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  🖥️  NOM DE VOTRE MACHINE                                    ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  Choisissez un nom mémorable — 2 chiffres auto seront      ║"
    echo "║  ajoutés.  Ex: pirate → pirate-42   dragon → dragon-17     ║"
    echo "║  Appuyez sur Entrée pour un nom aléatoire (diceware).      ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    read -r -p "Nom de votre machine [auto] : " CUSTOM_MACHINE_NAME
fi
export CUSTOM_MACHINE_NAME
[[ -n "$CUSTOM_MACHINE_NAME" ]] \
    && echo ">>> Nom machine : ${CUSTOM_MACHINE_NAME}-XX" \
    || echo ">>> Nom machine : auto-diceware-XX"

########################################################################
## FAIL-FAST ai-company — vérification GPU AVANT tout téléchargement
########################################################################
if [[ "${INSTALL_PROFILE}" == "ai-company" ]]; then
    if   [[ $_VRAM -ge 24 ]]; then _AI_TIER="🔥 Excellent (≥24 Go) — grands modèles 70B+"
    elif [[ $_VRAM -ge 8  ]]; then _AI_TIER="⚡ Bon (8-23 Go) — modèles 7B-13B"
    elif [[ $_VRAM -ge 4  ]]; then _AI_TIER="🟡 Limité (4-7 Go) — petits modèles 3B-7B"
    elif [[ $_VRAM -ge 1  ]]; then _AI_TIER="⚠️  Très limité (1-3 Go) — ≤ 3B seulement"
    else                           _AI_TIER="❌ Pas de VRAM dédiée"
    fi
    case "$_GPU_VENDOR" in
        nvidia)           _AI_COMPAT="✅ CUDA — Ollama + ComfyUI supportés" ;;
        amd)              _AI_COMPAT="⚠️  ROCm (expérimental) — GPU RX 5000+ requis" ;;
        intel)            _AI_COMPAT="⚠️  SYCL/XPU (expérimental) — Intel Arc requis" ;;
        intel_integrated) _AI_COMPAT="❌ GPU intégré — Ollama/ComfyUI non supportés" ;;
        amd_integrated)   _AI_COMPAT="❌ GPU intégré — Ollama/ComfyUI non supportés" ;;
        *)                _AI_COMPAT="❓ Compatibilité inconnue" ;;
    esac
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  🧠 PROFIL ai-company — vérification matériel               ║"
    printf "║  %-58s ║\n" "GPU    : ${_GPU_NAME:-inconnu}  (${_GPU_VENDOR})"
    printf "║  %-58s ║\n" "VRAM   : ${_VRAM} Go  →  ${_AI_TIER}"
    printf "║  %-58s ║\n" "Compat : ${_AI_COMPAT}"
    echo "╚══════════════════════════════════════════════════════════════╝"
    if [[ $_VRAM -lt 4 || "$_GPU_VENDOR" == *_integrated* ]]; then
        read -r -p "⚠️  Ce profil n'est pas recommandé sur cette machine. Continuer ? [y/N] " _cont
        [[ "${_cont}" != "y" && "${_cont}" != "Y" ]] && exit 1
    fi
fi

[[ -t 0 ]] && read -r -p $'\n  ↵  Paramètres confirmés — Entrée pour démarrer l\'installation... ' _

########################################################################
echo "## DÉTECTION OS & GESTIONNAIRE DE PAQUETS ##"
########################################################################
PKG_MANAGER="apt"
if command -v pacman >/dev/null 2>&1; then
    PKG_MANAGER="pacman"
    if grep -q "SteamOS" /etc/os-release 2>/dev/null; then
        echo "🎮 SteamOS détecté — déverrouillage système de fichiers..."
        sudo steamos-readonly disable
        sudo pacman-key --init 2>/dev/null || true
        sudo pacman-key --populate archlinux holo 2>/dev/null || true
    fi
    # -Syu obligatoire sur Arch : -Sy seul = partial upgrade = casse système garantie
    echo "🐧 Arch Linux / SteamOS — mise à jour complète (Syu)..."
    sudo pacman -Syu --noconfirm

    if ! command -v yay >/dev/null 2>&1; then
        echo ">>> Installation de yay (AUR helper)..."
        sudo pacman -S --noconfirm --needed git base-devel
        _yay_tmp=$(mktemp -d)
        git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$_yay_tmp/yay-bin" \
            && (cd "$_yay_tmp/yay-bin" && makepkg -si --noconfirm) \
            && echo "✅ yay installé" \
            || echo "⚠️  yay install échoué — paquets AUR non disponibles" >&2
        rm -rf "$_yay_tmp"
    fi
else
    echo "🐧 Debian/Ubuntu/Mint — mise à jour apt..."
    sudo apt-get update -y
fi

# Traduit un nom de paquet Debian → Arch (retourne IGNORE ou AUR:nom si nécessaire)
translate_pkg_name() {
    local pkg="$1"
    if [[ "$PKG_MANAGER" == "pacman" ]]; then
        case "$pkg" in
            wireguard)                 echo "wireguard-tools" ;;
            openssh-server)            echo "openssh" ;;
            netcat-traditional)        echo "gnu-netcat" ;;
            libsodium*)                echo "libsodium" ;;
            libcurl4-openssl-dev)      echo "IGNORE" ;;   # inclus dans curl
            libgpgme-dev)              echo "gpgme" ;;
            libffi-dev)                echo "libffi" ;;
            cron)                      echo "cronie" ;;
            iputils-ping)              echo "iputils" ;;
            python3-venv|python3-dev)  echo "IGNORE" ;;   # inclus dans python
            build-essential)           echo "base-devel" ;;
            libssl-dev)                echo "openssl" ;;
            python3-magic)             echo "python-magic" ;;
            pipx)                      echo "python-pipx" ;;
            python3-pip)               echo "python-pip" ;;
            python3-setuptools)        echo "python-setuptools" ;;
            python3-base58)            echo "IGNORE" ;;   # via pip dans le venv
            python3-wheel)             echo "python-wheel" ;;
            python3-dotenv)            echo "python-dotenv" ;;
            python3-gpg)               echo "python-gpg" ;;
            python3-jwcrypto)          echo "IGNORE" ;;   # via pip
            python3-brotli)            echo "python-brotli" ;;
            python3-aiohttp)           echo "python-aiohttp" ;;
            python3-prometheus-client) echo "python-prometheus_client" ;;
            python3-tk)                echo "tk" ;;
            cargo)                     echo "rust" ;;
            geoip-bin)                 echo "geoip" ;;
            bind9-dnsutils)            echo "bind" ;;
            ntpsec-ntpdate)            echo "ntp" ;;
            espeak)                    echo "espeak-ng" ;;
            musl-dev)                  echo "musl" ;;
            libmagic1t64)              echo "IGNORE" ;;   # inclus dans file
            libimage-exiftool-perl)    echo "perl-image-exiftool" ;;
            poppler-utils)             echo "poppler" ;;
            fonts-hack-ttf)            echo "ttf-hack" ;;
            basez)                     echo "IGNORE" ;;   # base64 dans coreutils
            markdown)                  echo "discount" ;;
            x11-utils)                 echo "xorg-xdpyinfo" ;;
            printer-driver-all)        echo "IGNORE" ;;
            # Paquets AUR — préfixe pour les traiter séparément
            mp3info)                   echo "AUR:mp3info" ;;
            ssss)                      echo "AUR:ssss" ;;
            ttf-mscorefonts-installer) echo "AUR:ttf-ms-fonts" ;;
            prometheus-node-exporter)  echo "AUR:prometheus-node-exporter" ;;
            ocrmypdf)                  echo "AUR:ocrmypdf" ;;
            detox)                     echo "AUR:detox" ;;
            httrack)                   echo "AUR:httrack" ;;
            *)                         echo "$pkg" ;;
        esac
    else
        # Debian : normaliser libsodium* (glob invalide pour dpkg-query)
        case "$pkg" in
            libsodium*) echo "libsodium-dev" ;;
            *)          echo "$pkg" ;;
        esac
    fi
}

# Vérifie si un paquet est installé — traduit d'abord le nom (idempotence Arch garantie)
is_installed() {
    local pkg
    pkg=$(translate_pkg_name "$1")
    [[ "$pkg" == "IGNORE" ]] && return 0
    [[ "$pkg" == AUR:* ]] && pkg="${pkg#AUR:}"
    if [[ "$PKG_MANAGER" == "pacman" ]]; then
        pacman -Qs "^${pkg}$" >/dev/null 2>&1
    else
        dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"
    fi
}

# Installe un paquet individuel (pour les appels ponctuels : git, cups, etc.)
install_pkg() {
    local pkg
    pkg=$(translate_pkg_name "$1")
    [[ "$pkg" == "IGNORE" ]] && return 0
    if [[ "$pkg" == AUR:* ]]; then
        pkg="${pkg#AUR:}"
        if ! command -v yay >/dev/null 2>&1; then
            echo "⚠️  yay absent — paquet AUR '$pkg' ignoré" >&2; return 1
        fi
        yay -S --noconfirm --needed "$pkg" \
            || { echo "⚠️  yay: '$pkg' échoué" >&2; return 1; }
    elif [[ "$PKG_MANAGER" == "pacman" ]]; then
        sudo pacman -S --noconfirm --needed "$pkg" \
            || { echo "⚠️  pacman: '$pkg' non disponible" >&2; return 1; }
    else
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" \
            || { echo "⚠️  apt: '$pkg' non disponible" >&2; return 1; }
    fi
}

#### GIT CLONE ###############################################################
echo "#############################################"
echo "=== CODE CLONING TO '~/.zen/Astroport.ONE' ==="
echo "#############################################"
echo "UPDATING SYSTEM REPOSITORY"
install_pkg git
mkdir -p ~/.zen/workspace
cd ~/.zen/workspace
if [ -d UPlanet ]; then
    cd UPlanet
    # Stash uniquement si des modifications non committées existent (évite la fuite de stash en cron)
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        git stash push -m "install.sh auto-stash $(date +%Y%m%d-%H%M)" 2>/dev/null \
            && echo "ℹ️  Modifications locales UPlanet stashées (git stash pop pour les récupérer)"
    fi
    git fetch --all && git reset --hard origin/main \
        && echo "✅ UPlanet mis à jour (git reset --hard)" \
        || echo "⚠️  UPlanet git reset échoué"
    cd ..
else git clone --depth 1 https://github.com/papiche/UPlanet; fi
cd ~/.zen
if [ -d Astroport.ONE ]; then
    cd Astroport.ONE
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        git stash push -m "install.sh auto-stash $(date +%Y%m%d-%H%M)" 2>/dev/null \
            && echo "ℹ️  Modifications locales Astroport.ONE stashées (git stash pop pour les récupérer)"
    fi
    git fetch --all && git reset --hard origin/main \
        && echo "✅ Astroport.ONE mis à jour (git reset --hard)" \
        || echo "⚠️  Astroport.ONE git reset échoué"
    cd ..
else git clone --depth 1 https://github.com/papiche/Astroport.ONE.git; fi
# TODO INSTALL FROM IPFS / IPNS

## S'assurer que tous les scripts principaux sont exécutables après le clone
chmod +x ~/.zen/Astroport.ONE/*.sh \
         ~/.zen/Astroport.ONE/tools/*.sh \
         ~/.zen/Astroport.ONE/RUNTIME/*.sh 2>/dev/null || true
echo "✅ Scripts rendus exécutables"

## Créer .env depuis template si absent (évite "Aucun fichier" au démarrage des services)
[[ ! -f ~/.zen/Astroport.ONE/.env ]] \
    && cp ~/.zen/Astroport.ONE/.env.template ~/.zen/Astroport.ONE/.env \
    && echo "✅ ~/.zen/Astroport.ONE/.env créé depuis .env.template" \
    || echo "ℹ️  ~/.zen/Astroport.ONE/.env déjà présent"

################################################################### IPFS
## installation de ipfs
########################################################################
[[ ! $(which ipfs) ]] \
&& ~/.zen/Astroport.ONE/install/install.kubo_v0.40.0_linux.sh \
|| echo "=== IPFS FOUND === OK"

[[ ! $(which ipfs) ]] && echo "INSTALL IPFS PLEASE" && exit 1


####################################################################
# INSTALLATION EN LOT — traduit + vérifie + installe en 2 appels max
# (1 appel pacman/apt pour les dépôts officiels, 1 appel yay pour AUR)
####################################################################
echo "#############################################"
echo "######### INSTALL SYSTEM PACKAGES (batch) ###"
echo "#############################################"

_ALL_PKGS=(
    # Outils système
    zip ssss dos2unix make cmake hdparm iptables ufw fail2ban wireguard openssh-server sshfs
    parallel npm shellcheck multitail netcat-traditional socat ncdu chromium miller inotify-tools
    curl net-tools "libsodium*" miniupnpc libcurl4-openssl-dev libgpgme-dev libffi-dev htop cron psmisc iputils-ping
    # Python build
    python3-venv python3-dev libssl-dev build-essential python3-magic
    # Python libs
    pipx python3-pip python3-setuptools python3-base58 python3-wheel python3-dotenv python3-gpg
    python3-jwcrypto python3-brotli python3-aiohttp python3-prometheus-client python3-tk
    # Multimédia & données
    qrencode pv gnupg pandoc cargo btop sox ocrmypdf ca-certificates basez markdown jq bc file gawk ffmpeg
    geoip-bin bind9-dnsutils ntpsec-ntpdate v4l-utils espeak vlc mp3info musl-dev openssl detox nmap httrack
    html2text imagemagick libmagic1t64 libimage-exiftool-perl poppler-utils
    # ASCII art
    figlet cmatrix cowsay fonts-hack-ttf
)

_STD_MISSING=()
_AUR_MISSING=()

for _raw in "${_ALL_PKGS[@]}"; do
    _t=$(translate_pkg_name "$_raw")
    [[ "$_t" == "IGNORE" ]] && continue
    if [[ "$_t" == AUR:* ]]; then
        _aur="${_t#AUR:}"
        pacman -Qs "^${_aur}$" >/dev/null 2>&1 || _AUR_MISSING+=("$_aur")
    else
        if [[ "$PKG_MANAGER" == "pacman" ]]; then
            pacman -Qs "^${_t}$" >/dev/null 2>&1 || _STD_MISSING+=("$_t")
        else
            dpkg-query -W -f='${Status}' "$_t" 2>/dev/null | grep -q "ok installed" || _STD_MISSING+=("$_t")
        fi
    fi
done

if [[ ${#_STD_MISSING[@]} -gt 0 ]]; then
    echo ">>> ${#_STD_MISSING[@]} paquets manquants : ${_STD_MISSING[*]}"
    if [[ "$PKG_MANAGER" == "pacman" ]]; then
        sudo pacman -S --noconfirm --needed "${_STD_MISSING[@]}" \
            || echo "⚠️  pacman batch: certains paquets ont échoué" >> "$_ERROR_LOG"
    else
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${_STD_MISSING[@]}" \
            || echo "⚠️  apt batch: certains paquets ont échoué" >> "$_ERROR_LOG"
    fi
else
    echo ">>> Tous les paquets standards déjà installés ✅"
fi

if [[ ${#_AUR_MISSING[@]} -gt 0 && "$PKG_MANAGER" == "pacman" ]]; then
    if command -v yay >/dev/null 2>&1; then
        echo ">>> AUR — ${#_AUR_MISSING[@]} paquets manquants : ${_AUR_MISSING[*]}"
        yay -S --noconfirm --needed "${_AUR_MISSING[@]}" \
            || echo "⚠️  yay batch AUR: certains paquets ont échoué" >> "$_ERROR_LOG"
    else
        echo "⚠️  yay absent — paquets AUR ignorés : ${_AUR_MISSING[*]}" >> "$_ERROR_LOG"
    fi
fi

if [[ $(which X 2>/dev/null) || -n "$DISPLAY" || -n "$WAYLAND_DISPLAY" ]]; then
    echo "#############################################"
    echo "######### INSTALL DESKTOP TOOLS  ######"
    echo "#############################################"
    
    # 1. Outils systèmes de base pour l'environnement graphique
    for i in x11-utils xclip zenity; do
        if ! is_installed "$i"; then
            echo ">>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Installation $i <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
            install_pkg "$i"
            [[ $? != 0 ]] && echo "INSTALL $i FAILED." && echo "INSTALL $i FAILED." >> "$_ERROR_LOG" && continue
        fi
    done

    # 2. Menu interactif : Logiciels de Création Libres vs Propriétaires
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  🎨 LOGICIELS DESKTOP — L'ÉMANCIPATION NUMÉRIQUE             ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║ Score machine : ${_SCORE} | VRAM : ${_VRAM} Go"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║ [1] Graphisme 2D (Économie estimée : ~1150€)                 ║"
    echo "║     • GIMP      (alt. Photoshop ~240€/an)                    ║"
    echo "║     • Inkscape  (alt. Illustrator ~240€/an)                  ║"
    echo "║     • Krita     (alt. Corel Painter ~430€)                   ║"
    echo "║     • Scribus   (alt. InDesign ~240€/an)                     ║"
    echo "║                                                              ║"
    echo "║ [2] Bureautique & Multimédia (Économie estimée : ~250€)      ║"
    echo "║     • LibreOffice (alt. MS Office ~150€)                     ║"
    echo "║     • Thunderbird (alt. Outlook ~50€)                        ║"
    echo "║     • VLC         (alt. PowerDVD/Lecteurs payants ~50€)      ║"
    echo "║                                                              ║"
    
    if [[ $_SCORE -gt 10 ]]; then
        echo "║ [3] Audiovisuel (Économie estimée : ~630€)                   ║"
        echo "║     • Kdenlive  (alt. Premiere Pro ~240€/an)                 ║"
        echo "║     • Mixxx     (alt. Traktor Pro ~100€)                     ║"
        echo "║     • OBS Studio(alt. XSplit ~50€/an)                        ║"
        echo "║     • Audacity  (alt. Adobe Audition ~240€/an)               ║"
    else
        echo "║ [3] Audiovisuel ⚠️ (Score > 10 recommandé)                   ║"
    fi
    
    echo "║                                                              ║"
    
    if [[ $_SCORE -gt 40 || $_VRAM -ge 4 ]]; then
        echo "║ [4] 3D, CAO & MAO Pro (Économie estimée : ~4200€)            ║"
        echo "║     • Blender   (alt. Maya/3ds Max ~1700€/an)                ║"
        echo "║     • FreeCAD   (alt. AutoCAD ~2000€/an)                     ║"
        echo "║     • LMMS      (alt. FL Studio ~200€)                       ║"
        echo "║     • Ardour    (alt. Pro Tools ~300€/an)                    ║"
    else
        echo "║ [4] 3D, CAO & MAO ⚠️ (Brain-Node ou GPU 4Go+ recommandé)     ║"
    fi
    
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║ [5] TOUT INSTALLER (Sélectionne les packs compatibles)       ║"
    echo "║ [0] Passer         (Ne rien installer de plus)               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    
    read -r -p "Choix des packs (ex: 1 2 3) [0] : " _desktop_choices
    
    _PKGS=""
    _TOTAL_SAVINGS=0
    
    if [[ "$_desktop_choices" == *"1"* || "$_desktop_choices" == *"5"* ]]; then
        _PKGS+=" gimp inkscape krita scribus"
        _TOTAL_SAVINGS=$((_TOTAL_SAVINGS + 1150))
    fi
    
    if [[ "$_desktop_choices" == *"2"* || "$_desktop_choices" == *"5"* ]]; then
        _PKGS+=" libreoffice libreoffice-l10n-fr thunderbird vlc"
        _TOTAL_SAVINGS=$((_TOTAL_SAVINGS + 250))
    fi
    
    if [[ "$_desktop_choices" == *"3"* || "$_desktop_choices" == *"5"* ]]; then
        # En mode 'Tout installer', on vérifie que le PC tient la route
        if [[ $_SCORE -gt 10 || "$_desktop_choices" != *"5"* ]]; then
            _PKGS+=" kdenlive mixxx obs-studio audacity"
            _TOTAL_SAVINGS=$((_TOTAL_SAVINGS + 630))
        fi
    fi
    
    if [[ "$_desktop_choices" == *"4"* || "$_desktop_choices" == *"5"* ]]; then
        # En mode 'Tout installer', on vérifie que le PC tient la route
        if [[ $_SCORE -gt 40 || $_VRAM -ge 4 || "$_desktop_choices" != *"5"* ]]; then
            _PKGS+=" blender freecad lmms ardour"
            _TOTAL_SAVINGS=$((_TOTAL_SAVINGS + 4200))
        fi
    fi
    
    if [[ -n "$_PKGS" ]]; then
        echo ">>> Préparation de l'installation des logiciels :$_PKGS"
        for p in $_PKGS; do
            if ! is_installed "$p"; then
                echo ">>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Installation $p <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
                install_pkg "$p"
                [[ $? != 0 ]] && echo "INSTALL $p FAILED." && echo "INSTALL $p FAILED." >> "$_ERROR_LOG"
            fi
        done
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║ 🎉 INSTALLATION GRAPHIQUE TERMINÉE !                         ║"
        echo "╠══════════════════════════════════════════════════════════════╣"
        printf "║ 💰 Valeur estimée des licences évitées : %-19s ║\n" "${_TOTAL_SAVINGS} €"
        echo "║                                                              ║"
        echo "║ Le Logiciel Libre vous fait économiser cet argent chaque     ║"
        echo "║ année tout en respectant votre vie privée!                   ║"
        echo "║ -> Le G1FabLab vous permet de choisir leur évolution...      ║"
        echo "║ -> https://opencollective.com/monnaie-libre                  ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo ""
        [[ -t 0 ]] && read -r -p "  ↵  [Entrée pour continuer] " _
    else
        echo ">>> Aucun pack créatif supplémentaire sélectionné."
    fi
fi

echo "################################## ~/.astro/bin PYTHON ENV"
cd $HOME
## Auto-réparation : venv cassé après upgrade OS (ex: 22.04→24.04 change le binaire Python)
if [[ -d ~/.astro ]] && ! ~/.astro/bin/python3 -c "print('ok')" &>/dev/null; then
    echo "⚠️  Venv Python corrompu (upgrade OS ?) — recréation de ~/.astro..."
    rm -rf ~/.astro
fi
if [[ ! -s ~/.astro/bin/activate ]]; then
    python3 -m venv .astro \
        && echo "✅ Python venv créé : ~/.astro" \
        || { echo "❌ Création venv échouée — python3-venv installé ?"
             echo "   Réparation manuelle : ~/.zen/Astroport.ONE/admin/system/.astro_venv_restore.sh"
             exit 1; }
fi
[[ -s ~/.astro/bin/activate ]] && . ~/.astro/bin/activate \
    || { echo "❌ ~/.astro/bin/activate absent — correction : ~/.zen/Astroport.ONE/admin/system/.astro_venv_restore.sh"
         exit 1; }
cd -

echo "#####################################"
echo "## PYTHON TOOLS & CRYPTO LIB ##"
echo "#####################################"
export PATH=$HOME/.local/bin:$PATH
## add monero & bitcoin compatible keys
## duniterpy : installé uniquement dans le venv ~/.astro (pas de double via pipx)
# Installation en lot — pip résout l'arbre de dépendances en une seule passe
~/.astro/bin/pip install -U \
    pip python-dotenv scrypt setuptools wheel termcolor amzqr ollama \
    requests geohash beautifulsoup4 browser-cookie3 cryptography jwcrypto secp256k1 \
    gql base58 pybase64 google pynacl python-gnupg pynentry paho-mqtt \
    aiohttp ipfshttpclient bitcoin monero ecdsa pynostr bech32 \
    matplotlib readability-lxml duniterpy cachetools pydantic-settings \
    robohash substrate-interface websocket-client websockets imap_tools \
    fastapi aiofiles jinja2 python-multipart python-magic uvicorn python-telegram-bot \
    qdrant-client \
    2>> "$_ERROR_LOG" \
    && echo "✅ Paquets Python installés/mis à jour" \
    || echo "⚠️  pip batch: certains paquets ont échoué — voir $_ERROR_LOG"
## playwright remplace pyppeteer (abandonné 2022) pour tools/page_screenshot.py
echo ">>> playwright (remplaçant pyppeteer — tools/page_screenshot.py) <<<"
~/.astro/bin/pip install -U playwright 2>> "$_ERROR_LOG" \
    && echo "✅ playwright installé" \
    || echo "⚠️  playwright install FAILED — voir ~/.zen/install.errors.log"
## Installe le binaire Chromium de playwright (utilise le Chromium système si présent)
~/.astro/bin/python -m playwright install chromium 2>> "$_ERROR_LOG" \
    && echo "✅ playwright chromium prêt" \
    || echo "⚠️  playwright chromium install FAILED (page_screenshot.py utilisera /usr/bin/chromium)"
## Firefox requis par git.notebook.sh (NotebookLM) — Google lie ses sessions au browser fingerprint
~/.astro/bin/python -m playwright install firefox 2>> "$_ERROR_LOG" \
    && echo "✅ playwright firefox prêt (git.notebook.sh)" \
    || echo "⚠️  playwright firefox install FAILED — git.notebook.sh utilisera le fallback chromium"
## playwright-stealth : contourne la détection d'automatisation (ex: scrapers/mastodon)
~/.astro/bin/pip install -U playwright-stealth 2>> "$_ERROR_LOG" \
    && echo "✅ playwright-stealth installé" \
    || echo "⚠️  playwright-stealth install FAILED — voir ~/.zen/install.errors.log"


####################################################################
# MAIN # INSTALLATION / MISE À JOUR ASTROPORT.ONE
# (idempotent : safe à relancer sur une station existante)

echo "#############################################"
echo "###### ASTROPORT.ONE ZEN STATION ############"
echo "#############################################"
echo "######### INSTALL DOCKER ........ ###########"
echo "#############################################"
~/.zen/Astroport.ONE/install/install.docker.sh

echo "#############################################"
echo "######### INSTALL TIDDLYWIKI ############"
echo "#############################################"
######## TW is for ZenCard.refresh data storage & sharing
######## les versions supérieures @5.2.3 ne fonctionnent pas !
mkdir -p "$HOME/.local/lib/node_modules"
npm config set prefix "$HOME/.local"
npm install -g tiddlywiki@5.2.3 \
    && echo "✅ TiddlyWiki installé dans ~/.local/bin" \
    || { echo "INSTALL tiddlywiki FAILED." && echo "INSTALL tiddlywiki FAILED." >> "$_ERROR_LOG"; }

## ── Vérification Docker, Node.js, NPM, TiddlyWiki ───────────────────────────
echo "#############################################"
echo "######### VERIFICATION DOCKER & NODE   ######"
echo "#############################################"
DOCKER_OK=false; NPM_OK=false; TW_OK=false; DOCKER_COMPOSE_OK=false; DENO_OK=false
## sg docker active le groupe sans newgrp ; fallback sudo si sg échoue (CI, groupe fraîchement ajouté)
(sg docker -c "docker --version" 2>/dev/null || sudo docker --version 2>/dev/null) && DOCKER_OK=true || echo "⚠️  Docker non disponible"
(sg docker -c "docker compose version" 2>/dev/null || sudo docker compose version 2>/dev/null) && DOCKER_COMPOSE_OK=true || echo "⚠️  Docker Compose non disponible"
node --version 2>/dev/null && NPM_OK=true || echo "⚠️  Node.js non disponible"
npm --version 2>/dev/null || echo "⚠️  NPM non disponible"
tiddlywiki --version 2>/dev/null && TW_OK=true || echo "⚠️  TiddlyWiki non accessible (PATH?)"
## Deno : moteur JS alternatif pour yt-dlp EJS quand Node < v20
## Permet aussi d'exécuter des scripts navigateur dans un conteneur Docker (youtube-dl via EJS)
deno --version 2>/dev/null | head -1 && DENO_OK=true || echo "⚠️  Deno non disponible (yt-dlp EJS peut être affecté)"
echo ""
echo "  Docker    : $($DOCKER_OK && echo '✅' || echo '❌')  | Compose : $($DOCKER_COMPOSE_OK && echo '✅' || echo '❌')"
echo "  Node.js   : $($NPM_OK && echo '✅' || echo '❌')  | TW      : $($TW_OK && echo '✅' || echo '❌')  | Deno : $($DENO_OK && echo '✅' || echo '❌')"
echo ""
echo "  DOCKER STATUS:"
(sg docker -c "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" 2>/dev/null \
    || sudo docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null) | head -10 || echo "  (aucun conteneur)"
echo "#############################################"

## Correct PDF restrictions for imagemagick (v6 Debian ou v7 Arch)
echo "######### IMAGEMAGICK PDF ############"
_IM_POLICY=""
for _d in /etc/ImageMagick-6 /etc/ImageMagick-7 /etc/ImageMagick; do
    [[ -f "$_d/policy.xml" ]] && _IM_POLICY="$_d/policy.xml" && break
done
if [[ -n "$_IM_POLICY" ]] && grep -q "PDF" "$_IM_POLICY" 2>/dev/null; then
    ## Backup AVANT modification (pour restauration par uninstall.sh)
    [[ ! -f "${_IM_POLICY}.backup" ]] \
        && sudo cp "$_IM_POLICY" "${_IM_POLICY}.backup" \
        && echo "Backup ImageMagick policy.xml → ${_IM_POLICY}.backup"
    grep -Ev "PDF" "$_IM_POLICY" > /tmp/policy.xml
    sudo cp /tmp/policy.xml "$_IM_POLICY"
fi

echo "#############################################"
echo "#############################################"
LP=$(ls /dev/usb/lp* 2>/dev/null)
if [[ ! -z $LP ]]; then
echo "######### $LP PRINTER ##############"
########### QRCODE : ZENCARD / G1BILLET : PRINTER ##############
    ## PRINT & FONTS
    install_pkg ttf-mscorefonts-installer
    install_pkg printer-driver-all
    install_pkg cups
    ~/.astro/bin/pip install brother_ql
    # pipx install brother_ql
    sudo cupsctl --remote-admin
    sudo usermod -aG lpadmin $USER
    sudo usermod -a -G tty $USER
    sudo usermod -a -G lp $USER
    ## brother_ql_print
    echo "$USER ALL=(ALL) NOPASSWD:/usr/local/bin/brother_ql_print" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/brother_ql_print')
fi

## UPASSPORT API
echo "######### UPASSPORT ##############"
echo "INSTALL UPASSPORT : http://localhost:54321"
~/.zen/Astroport.ONE/install/install_upassport.sh

## NIP-101 strfry NOSTR relay
echo "######### NIP-101 strfry NOSTR relay ##############"
echo "INSTALL NOSTR RELAY : wss://localhost:7777"
# Sur Arch : utiliser le script local (déjà Arch-compatible) pour éviter de télécharger
# la version GitHub qui est Debian-only. Sur Debian : comportement original (wget).
_NIP101_LOCAL="$HOME/.zen/workspace/NIP-101/install_strfry.sh"
if [[ "$PKG_MANAGER" == "pacman" ]]; then
    if [[ ! -f "$_NIP101_LOCAL" ]]; then
        mkdir -p "$HOME/.zen/workspace"
        git clone --depth 1 https://github.com/papiche/NIP-101.git "$HOME/.zen/workspace/NIP-101" 2>/dev/null \
            || echo "⚠️  NIP-101 clone échoué"
    fi
    [[ -f "$_NIP101_LOCAL" ]] && bash "$_NIP101_LOCAL" \
        || echo "⚠️  install_strfry.sh introuvable — strfry non installé"
else
    bash <(wget -qO- https://github.com/papiche/NIP-101/raw/refs/heads/main/install_strfry.sh)
fi

## g1cli (gcli) — Duniter v2s CLI client (compiled from source, branche nostr)
echo "######### g1cli Duniter v2 Client ##############"
~/.zen/Astroport.ONE/install/install_gcli.sh

## G1BILLET -- needs reviewing --- code used for .print.sh scipt
echo "######### G1BILLET ##############"
echo "INSTALL G1BILLET : http://g1billet.localhost:33101"
cd ~/.zen
git clone https://github.com/papiche/G1BILLET.git
# cd G1BILLET && ./setup_systemd.sh ## NETWORK SERVICE NOT USED
cd -

echo

###############################################################
echo "##  ADDING lazydocker ================"
~/.zen/Astroport.ONE/install/install.lazydocker.sh

###############################################################
echo "## INSTALL yt-dlp (youtube copier, sans anti-bot) ##############"
# Anti-bot optionnel : astrosystemctl local install youtube-antibot
~/.zen/Astroport.ONE/install/youtube-dl.sh

###############################################################
echo "## INSTALL PowerJoular (Power consumption monitoring) ##########"
~/.zen/Astroport.ONE/install/install_powerjoular.sh

###############################################################
## prometheus-node-exporter seul : léger, expose /metrics sur :9100
## Prometheus serveur complet : installé uniquement avec le profil ai-company
echo "## INSTALL prometheus-node-exporter (heartbox metrics export) ##########"
install_pkg prometheus-node-exporter \
    && echo "✅ prometheus-node-exporter actif sur :9100" \
    || echo "⚠️  prometheus-node-exporter non disponible"

###############################################################
echo "## INSTALL RTK (Rust Token Killer — optimiseur tokens Claude Code) ##"
###############################################################
## Standard : one-liner curl (rapide)
## Dev      : clone + build cargo (modifiable, rebuildable)
if [[ "${INSTALL_PROFILE}" == "dev" ]]; then
    mkdir -p ~/.zen/workspace
    if [[ ! -d ~/.zen/workspace/rtk ]]; then
        git clone --depth 1 https://github.com/rtk-ai/rtk.git ~/.zen/workspace/rtk \
            && echo "✅ RTK cloné dans ~/.zen/workspace/rtk" \
            || echo "⚠️  RTK clone échoué"
    else
        (cd ~/.zen/workspace/rtk && git pull --ff-only 2>/dev/null) && echo "✅ RTK à jour" || true
    fi
    if [[ -f ~/.zen/workspace/rtk/Cargo.toml ]]; then
        echo "⏳ Compilation RTK (cargo build --release)..."
        (cd ~/.zen/workspace/rtk && cargo build --release 2>/dev/null) \
            && cp ~/.zen/workspace/rtk/target/release/rtk ~/.local/bin/rtk \
            && echo "✅ RTK compilé : ~/.local/bin/rtk" \
            || echo "⚠️  RTK build échoué (cargo requis)"
    fi
    ## Sélection de l'éditeur à relier à RTK
    if command -v rtk >/dev/null 2>&1; then
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║  🔌 RTK — Relier à votre éditeur de code                    ║"
        echo "╠══════════════════════════════════════════════════════════════╣"
        echo "║  [1] Claude Code (VS Code extension)   rtk init             ║"
        echo "║  [2] Cursor                            rtk init             ║"
        echo "║  [3] Neovim / Vim                      rtk init --global    ║"
        echo "║  [4] Tous les projets (global)         rtk init --global    ║"
        echo "║  [0] Passer (configurer plus tard)                          ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        read -r -p "Choix [1-4, défaut: 4] : " _rtk_editor
        case "${_rtk_editor:-4}" in
            1|2) rtk init 2>/dev/null       && echo "✅ RTK hook activé (projet courant)" || true ;;
            3|4) rtk init --global 2>/dev/null && echo "✅ RTK hook global activé" || true ;;
            0)   echo "→ RTK installé, configurez avec : rtk init --global" ;;
        esac
    fi
else
    ## Mode standard — one-liner officiel
    if ! command -v rtk >/dev/null 2>&1; then
        echo "⏳ Installation RTK via curl..."
        curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh | sh \
            && echo "✅ RTK installé" \
            || echo "⚠️  RTK install échoué (curl requis)"
        ## Hook global silencieux (pas d'éditeur à choisir en mode standard)
        command -v rtk >/dev/null 2>&1 && rtk init --global 2>/dev/null || true
    else
        echo "ℹ️  RTK déjà présent : $(rtk --version 2>/dev/null || echo 'version inconnue')"
    fi
fi

if [[ $INSTALL_PROFILE == "dev" ]]; then
    ###############################################################
    echo "## INSTALL Flutter SDK (web builds for Ginkgo app) ##########"
    ~/.zen/Astroport.ONE/install/install_flutter.sh
    ## Add Flutter to PATH for the rest of install
    export PATH="$HOME/.flutter/bin:$PATH"
fi

echo "=== INSTALL SYSTEM (sudoers, systemd, SSH, symlinks)"
~/.zen/Astroport.ONE/install/install_system.sh

echo "=== SETUP ASTROPORT (runtime config)"
~/.zen/Astroport.ONE/install/setup/setup.sh

###############################################################
echo "## ACTIVER LE PARE-FEU UFW ################################"
~/.zen/Astroport.ONE/admin/system/firewall.sh ON

## _CPU/_RAM/_VRAM/_SCORE/_TIER/_MVAL/_PAF_DEFAULT déjà calculés en tête d'install

###############################################################
echo "## INSTALLATIONS CONDITIONNELLES SELON PROFIL ###########"
###############################################################
NEXTCLOUD_ACTIVE=false
AISTACK_ACTIVE=false
RNOSTR_ACTIVE=false

case "${INSTALL_PROFILE}" in
    nextcloud)
        bash "$HOME/.zen/Astroport.ONE/install/install_nextcloud.sh" \
            && NEXTCLOUD_ACTIVE=true \
            || echo "⚠️  NextCloud — erreur d'installation (voir ~/.zen/install.errors.log)"
        ;;
    ai-company)
        echo "🧠 PROFIL ai-company — démarrage installation Stack IA..."
        ## Prometheus serveur complet : collecte les métriques heartbox + node_exporter
        ## Utile pour les Brain-Nodes (GPU) qui veulent monitorer leur charge IA
        echo "⏳ Installation Prometheus + exporters heartbox..."
        ~/.zen/Astroport.ONE/install/install_prometheus.sh \
            && echo "✅ Prometheus heartbox monitoring actif (:9090)" \
            || echo "⚠️  Prometheus — erreur (non bloquant)"
        
        AI_SVC_ARGS=""
        if [[ -n "${INSTALL_AI_SERVICES:-}" ]]; then
            AI_SVC_ARGS="${INSTALL_AI_SERVICES}"
        fi
        
        ~/.zen/Astroport.ONE/install/install-ai-company.docker.sh $AI_SVC_ARGS \
            && AISTACK_ACTIVE=true \
            && echo "✅ AI Company Stack démarrée" \
            || echo "⚠️  AI Stack — erreur (voir ~/.zen/ai-company/)"
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║  ⚠️  AVERTISSEMENT — Stack en cours d'intégration            ║"
        echo "╠══════════════════════════════════════════════════════════════╣"
        echo "║                                                               ║"
        echo "║  Les services IA démarrés (Dify.ai, Open WebUI, LiteLLM) ║"
        echo "║  ne sont PAS encore intégrés nativement à Astroport.ONE.   ║"
        echo "║  Ils fonctionnent en parallèle mais nécessitent :           ║"
        echo "║                                                               ║"
        echo "║  • Connexion Open WebUI → créer compte admin à 1ère ouvert. ║"
        echo "║  • Connexion Ollama ↔ LiteLLM à valider                    ║"
        echo "║  • Intégration #BRO (NOSTR → Open WebUI OpenAI API)         ║"
        echo "║                                                               ║"
        echo "║  🐉 APPEL AUX DRAGONS U.SOCIETY :                           ║"
        echo "║  Cette stack est votre terrain d'expérimentation.            ║"
        echo "║  Participez à son intégration dans la constellation :        ║"
        echo "║  → support@qo-op.com — Objet : 'DRAGON ai-company'       ║"
        echo "║  → Salon Nostr U.SOCIETY : #BRO develop                     ║"
        echo "║                                                               ║"
        echo "║  Services (si démarrés) :                                    ║"
        echo "║    Open WebUI : http://localhost:8000  ← interface IA        ║"
        echo "║    Dify.ai  :   http://localhost:8010  (agents)              ║"
        echo "║    Qdrant     : http://localhost:6333/dashboard              ║"
        echo "║    Ollama     : http://localhost:11434                       ║"
        echo "║    code_assistant : ~/.zen/Astroport.ONE/code_assistant      ║"
        echo "║                                                               ║"
        echo "║  DOC : ~/.zen/ai-company/install-ai-company.md              ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        [[ -t 0 ]] && read -r -p "  ↵  [Entrée pour continuer] " _
        ;;
    dev)
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║  ⚙️  PROFIL dev — Migration strfry → rnostr (Rust)           ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        ## strfry doit être arrêté avant rnostr (port 7777 partagé via NPM)
        echo "⏹️  Arrêt et désactivation de strfry..."
        sudo systemctl stop strfry 2>/dev/null || true
        sudo systemctl disable strfry 2>/dev/null || true
        ## rnostr = relai Nostr en Rust, plus performant, support Qdrant sémantique
        if [[ -f ~/.zen/Astroport.ONE/install/install_rnostr_semantic.sh ]]; then
            ~/.zen/Astroport.ONE/install/install_rnostr_semantic.sh \
                && RNOSTR_ACTIVE=true \
                && echo "✅ rnostr installé (remplace strfry)" \
                || echo "⚠️  rnostr — erreur d'installation"
        else
            echo "⚠️  install_rnostr_semantic.sh introuvable — rnostr non installé"
            echo "   → compilez depuis : https://github.com/rnostr/rnostr"
        fi
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║  📋 CHANTIER DEV — Migration des plugins writePolicy         ║"
        echo "╠══════════════════════════════════════════════════════════════╣"
        echo "║                                                               ║"
        echo "║  SITUATION ACTUELLE (strfry bash) :                         ║"
        echo "║  Les plugins de filtrage Nostr sont des scripts bash :       ║"
        echo "║  • all_but_blacklist.sh  (filtre principal)                 ║"
        echo "║  • filter/1.sh  7.sh  9735.sh  30023.sh ...                 ║"
        echo "║  Ils reçoivent les événements Nostr via stdin/stdout JSON,   ║"
        echo "║  filtrent par kind, classifient (nobody/player/uplanet),    ║"
        echo "║  gèrent la blacklist et la liste amisOfAmis.txt.            ║"
        echo "║                                                               ║"
        echo "║  OBJECTIF (rnostr Rust) :                                   ║"
        echo "║  Réécrire ces filtres comme des règles rnostr en Rust ou    ║"
        echo "║  comme plugins WASM compatibles rnostr. Avantages :         ║"
        echo "║  • Performance × 10-100 vs bash                             ║"
        echo "║  • Intégration Qdrant sémantique native                     ║"
        echo "║  • Classification IA des messages (LLM local Ollama)        ║"
        echo "║                                                               ║"
        echo "║  FICHIERS À MIGRER :                                        ║"
        echo "║  NIP-101/relay.writePolicy.plugin/all_but_blacklist.sh      ║"
        echo "║  NIP-101/relay.writePolicy.plugin/filter/*.sh               ║"
        echo "║  → Logique cible : rnostr/config.toml rules + Rust plugin   ║"
        echo "║                                                               ║"
        echo "║  🐉 APPEL AUX DRAGONS dev/Rust :                            ║"
        echo "║  → support@qo-op.com — Objet : 'DRAGON rnostr migration'    ║"
        echo "║  → Repo rnostr : https://github.com/rnostr/rnostr           ║"
        echo "║  → Repo NIP-101 : https://github.com/papiche/NIP-101        ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        [[ -t 0 ]] && read -r -p "  ↵  [Entrée pour continuer] " _
        ;;
    ""|standard)
        echo "   Profil standard."
        ## Qdrant VectorDB — base vectorielle souveraine de la station
        ## Légère (~200Mo RAM), utile dès ⚡ Standard pour les embeddings locaux
        if [[ $_SCORE -gt 10 ]] && command -v docker >/dev/null 2>&1; then
            if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^qdrant$'; then
                echo "   ⚡ Score ${_SCORE} ≥ 11 — démarrage Qdrant VectorDB (port 6333)..."
                docker network inspect dragon-net >/dev/null 2>&1 \
                    || docker network create dragon-net >/dev/null 2>&1
                docker run -d \
                    --name qdrant \
                    --restart unless-stopped \
                    --network dragon-net \
                    -p 127.0.0.1:6333:6333 \
                    -v qdrant_storage:/qdrant/storage \
                    qdrant/qdrant:latest \
                    && echo "✅ Qdrant démarré (http://localhost:6333)" \
                    || echo "⚠️  Qdrant — erreur de démarrage"
            else
                echo "   ✅ Qdrant déjà actif."
            fi
        elif [[ $_SCORE -le 10 ]]; then
            echo "   🌿 Score ${_SCORE} — Qdrant non installé (nécessite ⚡ Standard, score ≥ 11)"
        else
            echo "   ⚠️  Docker absent — Qdrant non installé (requis pour Qdrant)"
        fi
        ;;
    *)
        echo "⚠️  Profil inconnu '${INSTALL_PROFILE}' — installation standard uniquement."
        ;;
esac

###############################################################
echo "## DÉTECTION GPU — Installation IA optionnelle ###########"
###############################################################
## Variables optionnelles pour mode silencieux :
##   INSTALL_OLLAMA=yes    → Ollama installé sans confirmation
##   INSTALL_COMFYUI=yes   → ComfyUI installé sans confirmation
##   INSTALL_OLLAMA=no     → Ignoré même si GPU présent
## En mode -y, on répond oui automatiquement si GPU présent.
if [[ "$_SILENT" == "true" ]]; then
    export INSTALL_OLLAMA="${INSTALL_OLLAMA:-yes}"
    export INSTALL_COMFYUI="${INSTALL_COMFYUI:-yes}"
fi
~/.zen/Astroport.ONE/install/install_gpu_ai.sh

###############################################################
echo "## DUNITER v2s — MIRROIR G1 (optionnel) #################"
###############################################################
## Un nœud mirroir Duniter v2s synchronise la blockchain G1 localement.
## Avantages : RPC local :9944 (gcli/wallet sans dépendance externe),
## participation réseau P2P G1. Prérequis : > 10 Go disque, lien stable.
##
## Recommandation selon Power-Score :
##   Score > 40 🔥 Brain    → optimal (SSD, sync rapide)
##   Score > 10 ⚡ Standard  → recommandé
##   Score ≤ 10 🌿 Light    → déconseillé (sync lente, disque limité)
_DUNITER_DC="$HOME/.zen/Astroport.ONE/_DOCKER/duniter_v2/docker-compose.yml"
_DUNITER_ACTIVE=false

if docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'duniter'; then
    echo "✅ Duniter v2s déjà actif"
    _DUNITER_ACTIVE=true
elif [[ -f "$_DUNITER_DC" ]] && command -v docker >/dev/null 2>&1; then
    if   [[ $_SCORE -gt 40 ]]; then _DUNITER_REC="🔥 Optimal — Brain-Node (SSD, sync rapide)"
    elif [[ $_SCORE -gt 10 ]]; then _DUNITER_REC="⚡ Recommandé — Standard"
    else                             _DUNITER_REC="⚠️  Déconseillé — Light (sync lente, disque limité)"
    fi
    _DISK_AVAIL_GB=$(df "$HOME" --output=avail -BG 2>/dev/null | tail -1 | tr -d 'G ' || echo 0)
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ⛓️  DUNITER v2s — MIRROIR G1 (blockchain Ğ1 libre currency) ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    printf "║  Matériel : %-47s ║\n" "${_DUNITER_REC}"
    printf "║  Disque disponible : %-38s ║\n" "${_DISK_AVAIL_GB} Go  (≥ 10 Go requis)"
    echo "║                                                              ║"
    echo "║  • RPC local :9944      → gcli/wallet sans dépendance       ║"
    echo "║  • P2P public :30333    → contribution au réseau G1         ║"
    echo "║  • Prometheus :9615     → métriques mirroir                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    if [[ $_SCORE -le 10 ]]; then
        read -r -p "⚠️  Non recommandé sur cette machine. Installer quand même ? [y/N] " _dun_cont
        [[ "${_dun_cont}" == "y" || "${_dun_cont}" == "Y" ]] && _dun_choice="y" || _dun_choice="n"
    else
        read -r -p "Installer le mirroir Duniter v2s G1 ? [y/N] " _dun_choice
    fi
    if [[ "${_dun_choice}" == "y" || "${_dun_choice}" == "Y" ]]; then
        echo "⏳ Démarrage mirroir Duniter v2s..."
        (sg docker -c "docker compose -f '$_DUNITER_DC' up -d" 2>/dev/null \
            || sudo docker compose -f "$_DUNITER_DC" up -d) \
            && _DUNITER_ACTIVE=true \
            && echo "✅ Duniter v2s mirroir G1 démarré (RPC: 127.0.0.1:9944, P2P: :30333)" \
            || echo "⚠️  Duniter v2s — erreur de démarrage (voir: docker compose -f $_DUNITER_DC logs)"
        if [[ "$_DUNITER_ACTIVE" == "true" ]] && command -v ufw >/dev/null 2>&1 \
           && sudo ufw status 2>/dev/null | grep -q "Status: active"; then
            sudo ufw allow 30333/tcp comment 'Duniter v2s P2P TCP' >/dev/null 2>&1
            sudo ufw allow 30333/udp comment 'Duniter v2s P2P UDP' >/dev/null 2>&1
            echo "🔥 UFW : port 30333 ouvert (Duniter P2P)"
        fi
    else
        echo "→ Mirroir Duniter ignoré."
    fi
else
    echo "ℹ️  Duniter v2s : docker-compose introuvable — ignoré"
fi

# --- INJECTION : CALCUL VALEUR COMPARATIVE CLOUD ---
_CLOUD_SAVINGS=0

# Valeur de base (Infrastructure de base, Orchestration, P2P vs Centralisé)
_CLOUD_SAVINGS=$((_CLOUD_SAVINGS + 1200)) # Équivalent VPS + Orchestrateur managé / an

if [[ "${INSTALL_PROFILE}" == "nextcloud" ]]; then
    _CLOUD_SAVINGS=$((_CLOUD_SAVINGS + 450)) # Équivalent SaaS Cloud 128Go + Maintenance / an
fi

if [[ "${INSTALL_PROFILE}" == "ai-company" ]]; then
    # Comparaison avec une instance GPU managée (ex: Lambda Labs ou AWS p3.2xlarge)
    # Une instance GPU coûte environ 1$ à 3$ / heure. 
    # En auto-hébergé, on économise le coût d'une instance "On-Demand".
    _CLOUD_SAVINGS=$((_CLOUD_SAVINGS + 5200)) # Équivalent Instance GPU 24/7 / an
fi

# Sauvegarde dans le .env pour persistance
_env_upsert "CLOUD_EMANCIPATION_VALUE" "${_CLOUD_SAVINGS}" "${HOME}/.zen/Astroport.ONE/.env"
# ---------------------------------------------------

###############################################################
echo "## SCORE CARD DU NŒUD ################################"
###############################################################
## Calcul inline — pas de dépendance à IPFS au moment de l'install
_CPU=$(grep -c "processor" /proc/cpuinfo 2>/dev/null || echo 1)
_RAM=$(awk '/MemTotal/ {printf "%.0f", $2/1048576}' /proc/meminfo 2>/dev/null || echo 0)
## _VRAM/_GPU_VENDOR déjà calculés en tête de section — on ne re-détecte pas
_SCORE=$(( _VRAM * 4 + _CPU * 2 + _RAM / 2 ))

if   [[ $_SCORE -gt 40 ]]; then _TIER="🔥 Brain-Node (GPU)"; _RANK="DRAGON COMPUTE"; _MVAL=$(( _SCORE * 12 )); _PAF_DEFAULT=28
elif [[ $_SCORE -gt 10 ]]; then _TIER="⚡ Standard";         _RANK="DRAGON ORIGIN";  _MVAL=$(( _SCORE * 6  )); _PAF_DEFAULT=14
else                             _TIER="🌿 Léger";            _RANK="Nœud Léger";     _MVAL=100;               _PAF_DEFAULT=7
fi

## ── Benchmark disque — dd (écriture) + hdparm (lecture réelle) ──────────────
## Écriture  : dd + fdatasync — force le flush sur disque, fiable sur tous supports
## Lecture   : hdparm -t --direct — bypasse le page cache, donne le vrai débit I/O
## Fallback  : dd lecture si hdparm impossible (LVM, container, pas de sudo)

## Convertit sortie dd en Mo/s (GB/s, MB/s, kB/s)
_dd_to_mbps() {
    local _raw
    _raw=$(echo "$1" | grep -oE '[0-9.]+ [GkM]B/s' | tail -1)
    case "$_raw" in
        *" GB/s") printf "%.0f" "$(echo "${_raw% GB/s} * 1000" | bc 2>/dev/null || echo 0)" ;;
        *" MB/s") printf "%.0f" "${_raw% MB/s}" ;;
        *" kB/s") printf "%.0f" "$(echo "${_raw% kB/s} / 1000" | bc 2>/dev/null || echo 0)" ;;
        *)        echo 0 ;;
    esac
}
## Convertit sortie hdparm en Mo/s (MB/sec ou GB/sec)
_hdparm_to_mbps() {
    local _raw
    _raw=$(echo "$1" | grep -oE '[0-9.]+ [GM]B/sec' | tail -1)
    case "$_raw" in
        *" GB/sec") printf "%.0f" "$(echo "${_raw% GB/sec} * 1000" | bc 2>/dev/null || echo 0)" ;;
        *" MB/sec") printf "%.0f" "${_raw% MB/sec}" ;;
        *)          echo 0 ;;
    esac
}
## Détecte le block device racine (NVMe, SATA/IDE/VirtIO) — vide si LVM/overlay
_detect_disk_dev() {
    local _src
    _src=$(df "$HOME" --output=source 2>/dev/null | tail -1 | xargs)
    case "$_src" in
        /dev/nvme*p*) echo "${_src%p*}" ;;
        /dev/[shv]d[a-z][0-9]*) echo "${_src%%[0-9]*}" ;;
        /dev/mapper/*|tmpfs|overlay) echo "" ;;
        *) echo "$_src" ;;
    esac
}

_DISK_CACHE="$HOME/.zen/game/disk_bench.cache"
mkdir -p "$HOME/.zen/game"
## Relance si absent, valeurs nulles, ou cache > 24h
_disk_cache_age=$(( $(date +%s) - $(stat -c %Y "$_DISK_CACHE" 2>/dev/null || echo 0) ))
if [[ ! -s "$_DISK_CACHE" ]] || grep -q "^0 0$" "$_DISK_CACHE" 2>/dev/null || \
   [[ $_disk_cache_age -gt 86400 ]]; then
    echo "⏱️  Benchmark disque (dd écriture + hdparm lecture)..."
    _tmp_bench=$(mktemp -p "$HOME")

    _out=$(LANG=C dd if=/dev/zero of="$_tmp_bench" bs=1M count=256 conv=fdatasync 2>&1)
    _disk_write=$(_dd_to_mbps "$_out")
    rm -f "$_tmp_bench"

    _disk_dev=$(_detect_disk_dev)
    _disk_read=0
    if [[ -n "$_disk_dev" ]] && command -v hdparm >/dev/null 2>&1; then
        _out=$(LANG=C sudo hdparm -t --direct "$_disk_dev" 2>&1)
        _disk_read=$(_hdparm_to_mbps "$_out")
    fi
    ## Fallback dd si hdparm a échoué ou indisponible
    if [[ "${_disk_read:-0}" -eq 0 ]]; then
        echo "  (hdparm indisponible — lecture via dd, résultat non comparable)"
        _tmp_bench=$(mktemp -p "$HOME")
        LANG=C dd if=/dev/zero of="$_tmp_bench" bs=1M count=256 conv=fdatasync >/dev/null 2>&1
        _out=$(LANG=C dd if="$_tmp_bench" of=/dev/null bs=1M 2>&1)
        _disk_read=$(_dd_to_mbps "$_out")
        rm -f "$_tmp_bench"
    fi
    echo "${_disk_write:-0} ${_disk_read:-0}" > "$_DISK_CACHE"
fi
read _disk_write _disk_read < "$_DISK_CACHE" 2>/dev/null
_disk_write="${_disk_write:-0}"; _disk_read="${_disk_read:-0}"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🏆 SCORE CARD — Rang dans la constellation                  ║"
echo "╠══════════════════════════════════════════════════════════════╣"
printf "║  %-58s ║\n" "CPU : ${_CPU} cœurs  RAM : ${_RAM} Go  VRAM : ${_VRAM} Go"
printf "║  %-58s ║\n" "GPU : ${_GPU_NAME:-aucun}  (${_GPU_VENDOR})"
printf "║  %-58s ║\n" "Disque écriture : ${_disk_write} Mo/s  lecture : ${_disk_read} Mo/s"
printf "║  %-58s ║\n" "Power-Score : ${_SCORE}  →  ${_TIER}"
printf "║  %-58s ║\n" "Rang DRAGON : ${_RANK}"
echo "╠══════════════════════════════════════════════════════════════╣"
_CLOUD_VAL=$(grep "^CLOUD_EMANCIPATION_VALUE=" "${HOME}/.zen/Astroport.ONE/.env" | cut -d'=' -f2 || echo "0")
_TOTAL_ECO=$(( _CLOUD_VAL + _TOTAL_SAVINGS )) # _TOTAL_SAVINGS vient de la partie Desktop

printf "║  %-58s ║\n" "Valeur Matériel (CAPITAL) : ${_MVAL} ẐEN"
printf "║  %-58s ║\n" "Émancipation Cloud (FLOSS) : ${_CLOUD_VAL} € / an"
if [ "$_TOTAL_SAVINGS" -gt 0 ]; then
    printf "║  %-58s ║\n" "Émancipation Créative     : ${_TOTAL_SAVINGS} € / an"
fi
echo "╠══════════════════════════════════════════════════════════════╣"
printf "║  %-58s ║\n" "VALEUR TOTALE LIBÉRÉE : ${_TOTAL_ECO} € / an"
echo "║  (vs Solutions Cloud Propriétaires & Kubernetes Managé)      ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Participez au concours DRAGON UPlanet :                    ║"
echo "║  Publiez votre score → kind:30850 (ECONOMY.broadcast.sh)    ║"
echo "║  Faites évaluer votre nœud → support@qo-op.com              ║"
echo "║  → Devenez DRAGON ORIGIN, DRAGON COMPUTE ou DRAGON ẐEN      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
[[ -t 0 ]] && read -r -p "  ↵  [Entrée pour continuer] " _

## Initialiser MACHINE_VALUE, PAF, CAPITAL_DATE dans game/.env si absents
_GAME_ENV="$HOME/.zen/game/.env"
if ! grep -q "^MACHINE_VALUE=" "$_GAME_ENV" 2>/dev/null; then
    echo "MACHINE_VALUE=${_MVAL}"                        >> "$_GAME_ENV"
    echo "PAF=${_PAF_DEFAULT}"                           >> "$_GAME_ENV"
    echo "CAPITAL_DATE=$(date +%Y%m%d)000000000"        >> "$_GAME_ENV"
    echo "DEPRECIATION_WEEKS=156"                        >> "$_GAME_ENV"
    echo "  ✅ Valeurs initiales sauvegardées → ${_GAME_ENV}"
    echo "     MACHINE_VALUE=${_MVAL} ẐEN | PAF=${_PAF_DEFAULT} ẐEN/sem"
fi

end=`date +%s`
DURATION=$((end - start))
MINUTES=$((DURATION / 60))
SECONDS_REM=$((DURATION % 60))

## Source my.sh for display variables (domain, hostname, network type)
. ~/.zen/Astroport.ONE/tools/my.sh 2>/dev/null
HOSTNAME_DISPLAY=$(hostname)
DOMAIN_DISPLAY="${myDOMAIN:-copylaradio.com}"
IPFS_DISPLAY="${myIPFS:-https://ipfs.${DOMAIN_DISPLAY}}"
RELAY_DISPLAY="${myRELAY:-wss://relay.${DOMAIN_DISPLAY}}"
USPOT_DISPLAY="${uSPOT:-https://u.${DOMAIN_DISPLAY}}"

if [[ "${UPLANETNAME}" == "0000000000000000000000000000000000000000000000000000000000000000" ]]; then
    NETWORK_DISPLAY="UPlanet ORIGIN (sandbox)"
else
    NETWORK_DISPLAY="UPlanet ZEN (${DOMAIN_DISPLAY})"
fi

###############################################################
echo "## QDRANT — VectorDB IA apprenante pour MULTIPASS ##########"
###############################################################
## Stratégie selon Power-Score :
##   Score > 10 (Standard/Brain) + Docker → Qdrant local (docker compose --profile ai)
##   Score ≤ 10 (Light/PiZero/picoport)   → tunnel IPFS P2P vers nœud swarm
##
## Dans les deux cas : QDRANT_URL=http://127.0.0.1:6333 dans .env
## Ce QDRANT_URL active BRO/nextcloud_bro_sync.sh, memory_manager, short_memory
## pour les MULTIPASS hébergés sur ce nœud — même sur un Pi Zero 2W (picoport).
##
## TODO (davfs) : sur nœud Léger avec ZenCard, monter le Nextcloud de la constellation
##   via WebDAV pour stocker les snapshots Qdrant de façon persistante :
##   mount -t davfs https://cloud.domain/remote.php/webdav/ /mnt/nc_qdrant
##   → qdrant_storage volume → /mnt/nc_qdrant/qdrant/

_QDRANT_URL="http://127.0.0.1:6333"
_QDRANT_INSTALLED=false
_ENVFILE="$HOME/.zen/Astroport.ONE/.env"

## Helper sed-upsert (indépendant de _env_upsert défini dans setup.sh)
_set_env_qdrant() {
    if grep -q "^QDRANT_URL=" "$_ENVFILE" 2>/dev/null; then
        sed -i "s|^QDRANT_URL=.*|QDRANT_URL=\"${_QDRANT_URL}\"|" "$_ENVFILE"
    else
        echo "QDRANT_URL=\"${_QDRANT_URL}\"" >> "$_ENVFILE"
    fi
}

if [[ $_SCORE -gt 10 ]] && command -v docker >/dev/null 2>&1; then
    ##
    ## Standard / Brain → installer Qdrant localement (standalone, sans Ollama requis)
    ##
    echo "⚡ Power-Score ${_SCORE} (${_TIER}) + Docker → installation Qdrant locale"
    _ASTRO_COMPOSE="$HOME/.zen/Astroport.ONE/docker/docker-compose.yml"
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'qdrant'; then
        echo "✅ Qdrant déjà actif"
        _QDRANT_INSTALLED=true
    elif [[ -f "$_ASTRO_COMPOSE" ]]; then
        echo "⏳ Démarrage Qdrant (docker compose --profile ai)..."
        if docker compose -f "$_ASTRO_COMPOSE" --profile ai up -d qdrant 2>/dev/null; then
            _QDRANT_INSTALLED=true
            echo "✅ Qdrant local démarré (port 6333)"
        else
            echo "⚠️  Qdrant docker échoué — vérifiez : docker compose -f $HOME/.zen/Astroport.ONE/docker/docker-compose.yml --profile ai logs qdrant"
        fi
    else
        echo "⚠️  docker-compose.yml absent — Qdrant non démarré"
    fi

    ## Partager Qdrant avec la constellation (le retirer de DRAGON_PRIVATE_SERVICES)
    ## pour que les nœuds Légers puissent s'y connecter via IPFS P2P
    if [[ "$_QDRANT_INSTALLED" == "true" ]] && [[ -f "$_ENVFILE" ]]; then
        _priv=$(grep -oP 'DRAGON_PRIVATE_SERVICES="\K[^"]*' "$_ENVFILE" 2>/dev/null \
             || grep -oP "DRAGON_PRIVATE_SERVICES='\K[^']*" "$_ENVFILE" 2>/dev/null || echo "")
        if echo " $_priv " | grep -qw "qdrant"; then
            _new_priv=$(echo "$_priv" | tr ' ' '\n' | grep -vxF "qdrant" | tr '\n' ' ' | xargs)
            sed -i "s|^DRAGON_PRIVATE_SERVICES=.*|DRAGON_PRIVATE_SERVICES=\"${_new_priv}\"|" "$_ENVFILE"
            echo "🌐 Qdrant partagé au swarm (retiré de DRAGON_PRIVATE_SERVICES)"
        fi
    fi

else
    ##
    ## Light (Pi Zero, picoport, sound-spot) → tenter une connexion swarm via IPFS P2P
    ##
    echo "🌿 Power-Score ${_SCORE} (${_TIER}) — Qdrant local non installé"
    echo "   Recherche d'un nœud swarm exposant Qdrant via IPFS P2P..."
    _ASYS="$HOME/.zen/Astroport.ONE/tools/astrosystemctl.sh"
    [[ ! -x "$_ASYS" ]] && command -v astrosystemctl >/dev/null 2>&1 && _ASYS="astrosystemctl"

    if [[ -x "$_ASYS" ]] && find "$HOME/.zen/tmp/swarm/" -name "x_qdrant.sh" 2>/dev/null | grep -q .; then
        echo "   Nœud Qdrant trouvé dans le swarm — connexion persistante..."
        bash "$_ASYS" enable qdrant 2>/dev/null \
            && _QDRANT_INSTALLED=true \
            && echo "✅ Qdrant swarm connecté (tunnel IPFS P2P persistant sur port 6333)" \
            || echo "⚠️  astrosystemctl enable qdrant échoué"
    else
        echo "ℹ️  Aucun nœud swarm n'expose Qdrant pour l'instant."
        echo "   → BRO/MULTIPASS fonctionnera en mode dégradé (flashmem local uniquement)"
        echo "   → Dès qu'un nœud Standard+ rejoint l'essaim, relancez :"
        echo "     astrosystemctl connect qdrant && astrosystemctl enable qdrant"
    fi
fi

## Écrire QDRANT_URL dans .env (http://127.0.0.1:6333 dans tous les cas — local ou tunnel P2P)
_set_env_qdrant
if [[ "$_QDRANT_INSTALLED" == "true" ]]; then
    echo "✅ QDRANT_URL=${_QDRANT_URL} → IA apprenante MULTIPASS activée"
else
    echo "ℹ️  QDRANT_URL=${_QDRANT_URL} inscrit dans .env (inactif jusqu'à connexion swarm)"
fi

echo "######### Enterprise Swarm AI Stack Manager ##############
TRY IT UPGRADE IT : ~/.zen/Astroport.ONE/install/install-ai-company.docker.sh"

echo
echo "#############################################"
echo "  INSTALLATION TERMINEE (${MINUTES}min ${SECONDS_REM}s)"
echo "#############################################"
echo
echo "  Station:  ${HOSTNAME_DISPLAY}"
echo "  Reseau:   ${NETWORK_DISPLAY}"
echo "  Capitaine: $(cat ~/.zen/game/players/.current/.player 2>/dev/null || echo 'embarquement en cours...')"
echo
echo "  PROFIL INSTALLÉ: ${INSTALL_PROFILE:-standard}"
echo
echo "  INFRASTRUCTURE (Docker) :"
sg docker -c "docker ps --format '    {{.Names}}: {{.Status}}'" 2>/dev/null | head -30 || echo "    (aucun conteneur actif)"
echo
echo "  NODE.JS / NPM / DENO :"
echo "    Node.js    $(node --version 2>/dev/null || echo '⚠️ non disponible')"
echo "    NPM        v$(npm --version 2>/dev/null || echo '⚠️ non disponible')"
echo "    TiddlyWiki $(tiddlywiki --version 2>/dev/null || echo '⚠️ — relancez: sudo npm install -g tiddlywiki@5.2.3')"
echo "    Deno       $(deno --version 2>/dev/null | head -1 || echo '⚠️ non disponible (yt-dlp EJS)')"
echo "    (Deno sert de runtime JS pour yt-dlp EJS : extraction YouTube via navigateur)"
echo
echo "  SERVICES ASTROPORT :"
echo "    Astroport  http://localhost:12345"
echo "    UPassport  http://localhost:54321"
echo "    IPFS       http://localhost:8080"
echo "    NOSTR      ws://localhost:7777"
echo "    G1Billet   http://localhost:33101"
if [[ "${NEXTCLOUD_ACTIVE}" == "true" ]]; then
echo "    NextCloud  http://127.0.0.1:8443  (admin initial)"
echo "               https://cloud.${DOMAIN_DISPLAY}  (via NPM)"
fi
if command -v ollama >/dev/null 2>&1; then
echo "    Ollama     http://localhost:11434  ← LLM GPU local"
fi
if systemctl is-active --quiet comfyui 2>/dev/null; then
echo "    ComfyUI    http://localhost:8188   ← Génération d'images GPU"
fi
if [[ "${AISTACK_ACTIVE}" == "true" ]]; then
echo "    Open WebUI http://localhost:8000  ← portail IA pour les membres"
echo "    Dify.ai    http://localhost:8010  ← création d'agents/workflows"
echo "    Qdrant     http://localhost:6333"
echo "    Ollama     http://localhost:11434"
fi
if [[ "${RNOSTR_ACTIVE}" == "true" ]]; then
echo "    rnostr     ws://localhost:8888  (relay NOSTR Rust — dev)"
fi
echo
echo "  DOCKER :"
echo "    docker ps"
echo "    docker compose -f ~/.zen/Astroport.ONE/docker/docker-compose.yml ps"
echo "    docker compose -f ~/.zen/Astroport.ONE/docker/docker-compose.yml logs -f"
echo
echo "  ESSAIM :"
echo "    IPFS       ${IPFS_DISPLAY}"
echo "    Relay      ${RELAY_DISPLAY}"
echo "    UPassport  ${USPOT_DISPLAY}"
echo
echo "  COMMANDES :"
echo "    astrosystemctl list          ← score local vs swarm"
echo "    astrosystemctl list-remote   ← Brain-Nodes disponibles"
echo "    station-info                 ← état station (terminal)"
echo "    station                      ~/.zen/Astroport.ONE/station.sh"
echo "    captain                      ~/.zen/Astroport.ONE/captain.sh"
echo "    start / stop                 ~/.zen/Astroport.ONE/start.sh | stop.sh"
if [[ "${AISTACK_ACTIVE}" == "true" ]]; then
echo ""
echo "  STACK IA :"
echo "    docker compose -f ~/.zen/Astroport.ONE/docker/docker-compose.yml --profile ai ps"
echo "    install/install-ai-company.docker.sh --check   ← compatibilité GPU"
fi
echo
echo "  EXTENSIONS NAVIGATEUR :"
echo "    Pour archiver YouTube directement dans votre uDRIVE :"
echo "    1. Installez l'extension 'Open With' sur Firefox :"
echo "       https://addons.mozilla.org/firefox/addon/open-with"
echo "    2. Importez la configuration dans l'extension :"
echo "       bash ~/.zen/open_with_yt-dlp.txt"
echo
echo "  ERREURS: ~/.zen/install.errors.log"
echo "#############################################"
echo
[[ -t 0 ]] && read -r -p "  ↵  [Entrée pour voir la suite] " _
## ─── Message final conditionné par le mode réseau ───────────────────────────
if [[ "${UPLANETNAME}" == "0000000000000000000000000000000000000000000000000000000000000000" || -z "${UPLANETNAME}" ]]; then
## ══════════════════════  MODE ACADÉMIE / UPLANET ORIGIN  ══════════════════════
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║             🎮 ACADÉMIE UPLANET ORIGIN — ÉTAPE 1 / 4                       ║"
echo "╠══════════════════════════════════════════════════════════════════════════════╣"
echo "║                                                                              ║"
echo "║  Cette station fonctionne en mode BACS À SABLE (swarm.key = zéro).           ║"
echo "║  Elle est hébergée par vous (ARMATEUR) mais opérée par le collectif          ║"
echo "║  G1FabLab en attendant votre certification comme CAPITAINE.                  ║"
echo "║                                                                              ║"
echo "║  💰 En tant qu'Armateur, vous pouvez percevoir jusqu'à 14 Ẑen / sem          ║"
echo "║     → Souscrivez sur : https://opencollective.com/monnaie-libre              ║"
echo "║                                                                              ║"
echo "║  👉 VOTRE MISSION POUR DEVENIR CAPITAINE :                                   ║"
echo "║                                                                              ║"
echo "║  1. Ouvrez votre navigateur :  http://127.0.0.1:54321/g1                     ║"
echo "║  2. Créez votre MULTIPASS avec votre VÉRITABLE adresse email.                ║"
echo "║  3. Lisez les ZINEs quotidiens que le système va vous envoyer.               ║"
echo "║  4. Contactez support@qo-op.com pour valider votre formation DRAGON.         ║"
echo "║                                                                              ║"
echo "║  🐉 Formation DRAGON → swarm.key privé → UPlanet ẐEN → + 28 Ẑen/sem          ║"
echo "║                                                                              ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
else
## ══════════════════════  MODE PRODUCTION / UPLANET ẐEN  ══════════════════════
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    🚀 PROCHAINE ÉTAPE — ACTIVATION CAPITAINE               ║"
echo "╠══════════════════════════════════════════════════════════════════════════════╣"
echo "║                                                                              ║"
echo "║  Votre station est installée et votre compte GMARKMAIL créé.                 ║"
echo "║                                                                              ║"
echo "║  ⚠️  IMPORTANT : Pour activer votre statut de Capitaine, un autre            ║"
echo "║  Capitaine de la constellation doit valider votre recrutement.               ║"
echo "║                                                                              ║"
echo "║  📧 Contactez-nous pour rejoindre la constellation :                         ║"
echo "║     support@qo-op.com                                                        ║"
echo "║                                                                              ║"
echo "║  Indiquez dans votre email :                                                 ║"
echo "║    • Votre email GMARKMAIL : $(cat ~/.zen/game/players/.current/.player 2>/dev/null || echo 'voir ci-dessus')  ║"
echo "║    • Votre hostname : $(hostname)                                            ║"
echo "║    • Votre position GPS : $(cat ~/.zen/GPS 2>/dev/null || echo 'non détectée')         ║"
echo "║                                                                              ║"
echo "║  🌐 Notre Système d'Information Décentralisé : https://qo-op.com             ║"
echo "║  📚 Réseau Décentralisé : https://$myLIBRA/ipns/astroport.one                ║"
echo "║  📚 Rechargez en Ğ1 votre UPlanet Ẑen : $UPLANETNAME_G1      ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
fi
echo
. ~/.bashrc
##########################################################
# Bootstrap WoTx2 — Compétences Capitaine Astroport
# Propose au capitaine de déclarer ses compétences techniques initiales
[[ -f ~/.zen/Astroport.ONE/tools/oracle_init_captain_wotx2.sh ]] && \
    ~/.zen/Astroport.ONE/tools/oracle_init_captain_wotx2.sh
##########################################################
##########################################################
~/.zen/Astroport.ONE/RUNTIME/DRAGON_p2p_ssh.sh ON
##########################################################

##########################################################
## COMPTES DÉMO — identités NOSTR uniques par station
## Salt = prénom perso (coucou/toto/jean)
## Pepper = adresse email format UPlanet avec hostname
## → clés différentes sur chaque station, pas de collision MULTIPASS/ZenCard
##########################################################
# _DEMO_HOSTNAME=$(hostname)
# _KEYGEN="${HOME}/.zen/Astroport.ONE/tools/keygen"
# _DEMO_DIR="$HOME/.zen/demo"
# ## Domaine email hérite de la configuration de la station
# _DEMO_DOMAIN="${CAPTAIN_EMAIL_DOMAIN:-${CUSTOM_EMAIL_DOMAIN:-qo-op.com}}"
# mkdir -p "$_DEMO_DIR"

# echo ""
# echo "╔══════════════════════════════════════════════════════════════╗"
# echo "║  🎭 COMPTES DE DÉMONSTRATION WoTx2 / MineLife                ║"
# echo "╠══════════════════════════════════════════════════════════════╣"
# echo ""

# for _demo in coucou toto jean; do
#     _demo_file="${_DEMO_DIR}/${_demo}.keys"
#     _demo_salt="${_demo}"
#     _demo_pepper="support+${_demo}-${_DEMO_HOSTNAME}@${_DEMO_DOMAIN}"
#     _DEMO_DISPLAY="$(echo "${_demo}" | awk '{print toupper(substr($0,1,1)) substr($0,2)}') [DEMO]"
#     if [[ ! -s "$_demo_file" ]]; then
#         _nsec=$("$_KEYGEN" -t nostr -s "$_demo_salt" "$_demo_pepper" 2>/dev/null || echo "")
#         _npub=$("$_KEYGEN" -t nostr    "$_demo_salt" "$_demo_pepper" 2>/dev/null || echo "")
#         if [[ -n "$_nsec" && -n "$_npub" ]]; then
#             printf "NSEC=%s\nNPUB=%s\nEMAIL=%s\n" \
#                 "$_nsec" "$_npub" "$_demo_pepper" > "$_demo_file"
#             chmod 600 "$_demo_file"
#             ## Publier le profil Kind 0 tagué DEMO sur le relay local
#             _DEMO_CONTENT="{\"name\":\"${_DEMO_DISPLAY}\",\"about\":\"Compte de démonstration WoTx2 — ${_DEMO_HOSTNAME}\",\"demo\":true,\"picture\":\"https://robohash.org/${_demo_pepper}?set=set4\"}"
#             ~/.astro/bin/python3 ~/.zen/Astroport.ONE/tools/nostr_node_intercom.py publish \
#                 --nsec "$_nsec" \
#                 --kind 0 \
#                 --tags '[["t","demo"]]' \
#                 --content "$_DEMO_CONTENT" \
#                 --relays "ws://localhost:7777" 2>/dev/null \
#                 && echo "  ✅ ${_DEMO_DISPLAY} — profil publié sur le relay" \
#                 || echo "  ⚠️  ${_DEMO_DISPLAY} — publication différée (relay non prêt)"
#         fi
#     fi
#     _nsec=$(grep "^NSEC=" "$_demo_file" 2>/dev/null | cut -d= -f2)
#     _npub=$(grep "^NPUB=" "$_demo_file" 2>/dev/null | cut -d= -f2)
#     _email=$(grep "^EMAIL=" "$_demo_file" 2>/dev/null | cut -d= -f2)
#     printf "  👤 %-10s  <%s>\n" "$_DEMO_DISPLAY" "$_email"
#     printf "     nsec : %s\n" "${_nsec:-(keygen non disponible)}"
#     printf "     npub : %s...\n" "${_npub:0:24}"
#     echo ""
# done

# echo "  Les clés sont sauvegardées dans ~/.zen/demo/"
# echo ""

# ## Publier la graine WoTx2 (skills + objets + crafts + transactions demo)
# if [[ -f "${MY_PATH}/tools/demo_wotx2_seed.sh" ]]; then
#     echo "  🌱 Publication de la graine WoTx2 (skills/objets/crafts)…"
#     bash "${MY_PATH}/tools/demo_wotx2_seed.sh" \
#         --relay "${NOSTR_RELAY_WS:-ws://127.0.0.1:7777}" \
#         || echo "  ⚠️  Graine WoTx2 partielle — relay non prêt ? Re-exécutez tools/demo_wotx2_seed.sh"
# fi

# echo "  ┌───────────────────────────────────────────────────────────┐"
# echo "  │ X. Ouvrez MineLife dans votre navigateur :                │"
# echo "  │    http://127.0.0.1:54321/earth/minelife.html             │"
# echo "  │    Changez d'identité dans nos2x pour simuler la WoTx2    │"
# echo "  │    objects.html → inventaire objets                        │"
# echo "  │    skills.html  → nuage de compétences                    │"
# echo "  └───────────────────────────────────────────────────────────┘"
# echo ""
# [[ -t 0 ]] && read -r -p "  ↵  [Entrée pour continuer] " _

##########################################################
## MULTIPASS CAPITAINE — Clé NOSTR d'identité principale
##########################################################
_CAPTAIN_EMAIL=$(cat ~/.zen/game/players/.current/.player 2>/dev/null || echo "")
_CAP_SECRET="$HOME/.zen/game/nostr/${_CAPTAIN_EMAIL}/.secret.nostr"
if [[ -n "$_CAPTAIN_EMAIL" && -s "$_CAP_SECRET" ]]; then
    _CAP_NSEC=$(grep -oP 'NSEC=\K[^;]+' "$_CAP_SECRET" 2>/dev/null || echo "")
    _CAP_NPUB=$(grep -oP 'NPUB=\K[^;]+' "$_CAP_SECRET" 2>/dev/null || echo "")
    if [[ -n "$_CAP_NSEC" ]]; then
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║  🔑 MULTIPASS CAPITAINE — CLÉ NOSTR PRIVÉE                  ║"
        echo "╠══════════════════════════════════════════════════════════════╣"
        printf "║  Capitaine : %-46s ║\n" "${_CAPTAIN_EMAIL:0:46}"
        echo "║                                                              ║"
        echo "║  ⚠️  INSEREZ CETTE CLÉ DANS VOTRE NAVIGATEUR                 ║"
        echo "║  ⚠️  Elle donne accès à votre identité CAPTAIN sur NOSTR     ║"
        echo "║                                                              ║"
        printf "║  nsec : %-51s ║\n" "${_CAP_NSEC}"
        printf "║  npub : %-51s ║\n" "${_CAP_NPUB:0:51}"
        echo "║                                                              ║"
        echo "║  → Importez la nsec dans nos2x / Alby / Amethyst pour       ║"
        echo "║    accéder à votre identité NOSTR sur tous vos appareils.   ║"
        echo "║  Sauvegarde : ~/.zen/game/nostr/$_CAPTAIN_EMAIL/.secret.nostr"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo ""
        [[ -t 0 ]] && read -r -p "  ⚠️  NOTEZ VOTRE nsec CI-DESSUS — Entrée pour continuer... " _
    fi
fi

##########################################################
## SESSION DE FORMATION LIVE — vdo.ninja UPLANET
##########################################################
_CAPTAIN_EMAIL=$(cat ~/.zen/game/players/.current/.player 2>/dev/null || echo "")
_CAPTAIN_NPUB=$(cat ~/.zen/game/nostr/${_CAPTAIN_EMAIL}/NPUB 2>/dev/null | head -1 || echo "")
_VDO_ID="${_CAPTAIN_NPUB:0:12}"
[[ -z "$_VDO_ID" ]] && _VDO_ID="uplanet"

_VDO_ROOM="uplanet_${_VDO_ID}"
_VDO_HOST="https://vdo.copylaradio.com/?room=${_VDO_ROOM}&push=captain&record=1"
_VDO_VIEW="https://vdo.copylaradio.com/?room=${_VDO_ROOM}&view"
_VDO_FORM="https://vdo.copylaradio.com/?room=uplanet_formation&view"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🎥 SESSION DE FORMATION — vdo.ninja UPLANET                  ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Rejoignez une session visio avec un formateur certifié.     ║"
echo "║  La session sera enregistrée → publiée sur votre MULIPASS.   ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                               ║"
echo "║  Votre canal personnel (hôte + enregistrement) :              ║"
printf "║    %-58s ║\n" "${_VDO_HOST:0:58}"
echo "║                                                               ║"
echo "║  Canal FORMATION collectif (spectateur) :                     ║"
printf "║    %-58s ║\n" "${_VDO_FORM:0:58}"
echo "║                                                               ║"
echo "║  📧 Planifiez votre session : support@qo-op.com               ║"
echo "║     Objet : 'Formation DRAGON — $(hostname)'                  ║"
echo "║                                                               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
[[ -t 0 ]] && read -r -p "  ↵  [Entrée pour terminer] " _

########################################################################
## REDÉMARRAGE DES SERVICES (apt upgrade equivalent)
########################################################################
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🔄 REDÉMARRAGE DES SERVICES ASTROPORT                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
sudo systemctl daemon-reload 2>/dev/null || true

_svc_restart() {
    local svc="$1"
    if systemctl is-enabled --quiet "$svc" 2>/dev/null; then
        sudo systemctl restart "$svc" 2>/dev/null \
            && echo "  ✅ $svc redémarré" \
            || echo "  ⚠️  $svc — erreur redémarrage"
    fi
}
_svc_restart astroport
_svc_restart upassport
if [[ "${INSTALL_PROFILE}" == "dev" ]]; then
    _svc_restart rnostr
else
    _svc_restart strfry
fi
if [[ "${_IPFS_TUNNEL_SSH:-false}" == "true" ]]; then
    echo "  ⏭️  ipfs — redémarrage ignoré (tunnel SSH actif, relancer manuellement)"
else
    _svc_restart ipfs
fi
_svc_restart g1billet

## Mise à jour des images Docker actives (docker pull si running)
if command -v docker >/dev/null 2>&1; then
    echo "  🐳 Mise à jour images Docker actives..."
    _COMPOSE="$HOME/.zen/Astroport.ONE/docker/docker-compose.yml"
    if [[ -f "$_COMPOSE" ]] && docker ps -q 2>/dev/null | grep -q .; then
        docker compose -f "$_COMPOSE" pull --quiet 2>/dev/null || true
        docker compose -f "$_COMPOSE" up -d --remove-orphans 2>/dev/null || true
        docker image prune -f >/dev/null 2>&1 || true
        echo "  ✅ Conteneurs mis à jour (images orphelines purgées)"
    fi
fi

echo "  ✅ Redémarrage terminé"

########################################################################
## REVERROUILLAGE STEAMOS (si applicable)
########################################################################
if grep -q "SteamOS" /etc/os-release 2>/dev/null; then
    echo ""
    echo "🎮 SteamOS — Reverrouillage du système de fichiers en lecture seule..."
    sudo steamos-readonly enable 2>/dev/null || true
    echo "✅ Système de fichiers reverrouillé."
    echo ""
    echo "⚠️  IMPORTANT — SteamOS & mises à jour Valve :"
    echo "   Lors d'une mise à jour majeure de SteamOS par Valve, les paquets"
    echo "   système (Docker, UFW, IPFS) peuvent être effacés de /usr."
    echo "   → ~/.zen/, ~/.ipfs/, ~/.astro/ (données & identité) sont préservés dans /home."
    echo "   → Si Astroport ne démarre plus après une MAJ Valve, relancez simplement :"
    echo "       bash ~/.zen/Astroport.ONE/install.sh"
fi

}
