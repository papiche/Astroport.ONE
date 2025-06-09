#!/bin/bash
###################################################################
# generate_speech.sh
# Script de synthèse vocale avec Orpheus TTS
#
# Usage: $0 <text> <voice>
#
# Fonctionnalités:
# - Génération de synthèse vocale avec Orpheus TTS
# - Support des voix pierre et amelie
# - Upload automatique vers IPFS
# - Retourne l'URL IPFS du fichier audio généré
###################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"

# Vérifie si les arguments sont fournis
if [ $# -lt 2 ]; then
    echo "Usage: $0 <text> <voice>" >&2
    echo "  text: Texte à synthétiser" >&2
    echo "  voice: Voix à utiliser (pierre ou amelie)" >&2
    exit 1
fi

TEXT="$1"
VOICE="$2"

. "${MY_PATH}/../tools/my.sh"

# Create temporary directory
TMP_DIR="$HOME/.zen/tmp/tts_$(date +%s)"
mkdir -p "$TMP_DIR"

# Cleanup function
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Function to generate speech with Orpheus TTS
generate_speech() {
    local text="$1"
    local voice="$2"
    local temp_dir="$3"
    
    # Ensure Orpheus is available
    if ! $MY_PATH/orpheus.me.sh >&2; then
        echo "Error: Failed to connect to Orpheus TTS" >&2
        return 1
    fi
    
    # Create filename with timestamp
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local audio_file="${temp_dir}/speech_${voice}_${timestamp}.wav"
    
    echo "Generating speech with voice: $voice" >&2
    
    # Call Orpheus API
    local response=$(curl -s -w "%{http_code}" -o "$audio_file" \
        http://localhost:5005/v1/audio/speech \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"orpheus\",
            \"input\": \"$text\",
            \"voice\": \"$voice\",
            \"response_format\": \"wav\",
            \"speed\": 1.0
        }")
    
    local http_code="${response: -3}"
    
    if [[ "$http_code" == "200" && -f "$audio_file" && -s "$audio_file" ]]; then
        # Add to IPFS
        local audio_ipfs=$(ipfs add -wq "$audio_file" 2>/dev/null | tail -n 1)
        if [[ -n "$audio_ipfs" ]]; then
            local filename=$(basename "$audio_file")
            echo "$myIPFS/ipfs/$audio_ipfs/$filename"
        else
            echo "Error: Failed to add audio to IPFS" >&2
            return 1
        fi
    else
        echo "Error: Orpheus TTS failed (HTTP: $http_code)" >&2
        return 1
    fi
}

# Main execution
generate_speech "$TEXT" "$VOICE" "$TMP_DIR" 