#!/bin/bash
# Installe le système complet anti-bot YouTube : Deno (EJS) + bgutil (PO tokens)
# Usage: install_youtube_antibot.sh

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

echo "=== Installation YouTube Anti-Bot (Deno + EJS + bgutil) ==="
bash "${MY_PATH}/youtube-dl.sh" --deno
