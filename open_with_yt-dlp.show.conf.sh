#!/bin/bash

echo"
# Open With https://addons.mozilla.org/fr/firefox/addon/open-with/
# Astroport - IPFS
$HOME/.zen/Astroport.ONE/ajouter_media.sh

# Vidéos/MP4
$HOME/.local/bin/yt-dlp --cookies-from-browser firefox --download-archive $HOME/.zen/.yt-dlp.list -f "[height=480]/best" --write-info-json --no-mtime --playlist-items 1 -o $HOME/Vidéos/MP4/%(title)s.%(ext)s

# Musique/MP3
$HOME/.local/bin/yt-dlp --cookies-from-browser firefox  --download-archive $HOME/.zen/.yt-dlp.list -x --no-mtime --audio-format mp3 --embed-thumbnail --add-metadata --playlist-items 1 -o $HOME/Musique/MP3/%(autonumber)s_%(title)s.%(ext)s
"
