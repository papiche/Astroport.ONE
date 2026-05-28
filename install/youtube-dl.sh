#!/bin/bash

# Vérification des dépendances
command -v curl >/dev/null 2>&1 || {
    echo "curl n'est pas installé. Installation..."
    if command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm --needed curl
    else
        sudo apt install -y curl
    fi
}
command -v sudo >/dev/null 2>&1 || { echo "sudo n'est pas disponible. Exécution impossible."; exit 1; }

# Chemin absolu du script
MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
ME="${0##*/}"

# Options
INSTALL_DENO=0
for arg in "$@"; do
    case "$arg" in
        --deno) INSTALL_DENO=1 ;;
        --help|-h) echo "Usage: $ME [--deno]"; echo "  --deno  Installe aussi Deno (JS runtime, utilisé en dernier recours par yt-dlp)"; exit 0 ;;
    esac
done

# Installation de yt-dlp
if [[ ! -e "$HOME/.local/bin/yt-dlp" ]]; then
    mkdir -p "$HOME/.local/bin"
    rm -f "$HOME/.local/bin/yt-dlp"
    curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o "$HOME/.local/bin/yt-dlp"
    chmod +x "$HOME/.local/bin/yt-dlp"

    # Remplacement de youtube-dl par un lien symbolique vers yt-dlp
    ytdl=$(which youtube-dl)
    if [[ -n "$ytdl" && ! -f "${ytdl}.old" ]]; then
        sudo mv "$ytdl" "${ytdl}.old"
        sudo ln -s "$HOME/.local/bin/yt-dlp" "$ytdl"
    fi
fi

# Installation pour www-data (/usr/local/bin)
# Sur SteamOS, /usr/local est effacé à chaque mise à jour Valve → on n'y écrit pas
_IS_STEAMOS=0
grep -q "SteamOS" /etc/os-release 2>/dev/null && _IS_STEAMOS=1

if [[ "$_IS_STEAMOS" -eq 0 && -f "$HOME/.local/bin/yt-dlp" && ! -f "/usr/local/bin/yt-dlp" ]]; then
    sudo mkdir -p /usr/local/bin
    sudo cp "$HOME/.local/bin/yt-dlp" /usr/local/bin/yt-dlp
    sudo chmod +x /usr/local/bin/yt-dlp
    ln -sf /usr/local/bin/yt-dlp "$HOME/.local/bin/yt-dlp"
fi

# Réinitialisation du cache des commandes
hash -r

echo "yt-dlp est maintenant installé et accessible via :"
which yt-dlp
yt-dlp --version

# Installation du système anti-bot YouTube (optionnel, --deno)
# Composants : Deno (JS runtime EJS) + bgutil Docker (PO tokens)
# Utilisés par process_youtube.sh en dernier recours uniquement.
if [[ $INSTALL_DENO -eq 1 ]]; then
    echo ""
    echo "=== Installation du système anti-bot YouTube (Deno + EJS + bgutil) ==="
    bash "${MY_PATH}/install_deno.sh"
    bash "${MY_PATH}/install_yt_dlp_ejs_node.sh"
fi