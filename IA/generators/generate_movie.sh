#!/bin/bash
# generate_movie.sh : Workflow Cinéma complet
# Usage: $0 <prompt_action> <image_ref_url> <audio_url>

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"

PROMPT="$1"
IMAGE_REF="$2"
AUDIO_URL="$3"

# 1. On anime l'image
echo "Phase 1 : Animation..." >&2
# Utilise ton script image_to_video.sh actuel
VIDEO_SILENT_URL=$("${MY_PATH}/image_to_video.sh" "$PROMPT" "$IMAGE_REF")

# 2. On ajoute la parole
echo "Phase 2 : Lip-Sync..." >&2
FINAL_MOVIE_URL=$("${MY_PATH}/apply_lipsync.sh" "$VIDEO_SILENT_URL" "$AUDIO_URL")

echo "$FINAL_MOVIE_URL"