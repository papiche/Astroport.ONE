#!/bin/bash
################################################################################
# tools/gps_crypt.sh — Chiffrement/déchiffrement GPS avec UPLANETNAME
#
# Même algorithme que cooperative_config.sh (AES-256-CBC/pbkdf2, IV aléatoire).
# La clé est dérivée de UPLANETNAME : toutes les stations de la constellation
# partagent UPLANETNAME et peuvent donc déchiffrer le GPS de n'importe quel
# MULTIPASS de leur constellation.
#
# Format stocké : "<iv_hex_32chars>:<base64_encrypted>"
#
# Usage (en tant que library) :
#   source "${MY_PATH}/gps_crypt.sh"
#   encrypted=$(gps_encrypt "LAT=44.83; LON=-0.58;")
#   plaintext=$(gps_decrypt "$encrypted")
################################################################################

# Chiffre une chaîne GPS avec UPLANETNAME (AES-256-CBC, IV aléatoire)
# Usage  : gps_encrypt "LAT=xx.xx; LON=yy.yy;"
# Sortie : "iv_hex:base64_encrypted" ou vide si échec
gps_encrypt() {
    local plaintext="$1"
    if [[ -z "$UPLANETNAME" ]]; then
        echo "[ERROR gps_crypt] UPLANETNAME non défini" >&2
        return 1
    fi
    [[ -z "$plaintext" ]] && echo "" && return 0
    local key; key=$(echo -n "$UPLANETNAME" | sha256sum | cut -d' ' -f1)
    local iv; iv=$(openssl rand -hex 16 2>/dev/null)
    local enc; enc=$(printf '%s' "$plaintext" \
        | openssl enc -aes-256-cbc -pbkdf2 -a -A -K "$key" -iv "$iv" 2>/dev/null)
    if [[ -z "$enc" ]]; then
        echo "[ERROR gps_crypt] Échec du chiffrement openssl" >&2
        return 1
    fi
    echo "${iv}:${enc}"
}

# Déchiffre un blob GPS produit par gps_encrypt
# Usage  : gps_decrypt "iv_hex:base64_encrypted"
# Sortie : "LAT=xx.xx; LON=yy.yy;" ou vide si échec / UPLANETNAME incorrect
gps_decrypt() {
    local data="$1"
    if [[ -z "$UPLANETNAME" || -z "$data" ]]; then
        return 1
    fi
    local iv="${data%%:*}"
    local enc="${data#*:}"
    if [[ -z "$iv" || -z "$enc" || "$iv" == "$data" ]]; then
        return 1
    fi
    local key; key=$(echo -n "$UPLANETNAME" | sha256sum | cut -d' ' -f1)
    local plain; plain=$(printf '%s' "$enc" \
        | openssl enc -aes-256-cbc -pbkdf2 -d -a -A -K "$key" -iv "$iv" 2>/dev/null)
    [[ -z "$plain" ]] && return 1
    echo "$plain"
}

# Extrait LAT et LON depuis un blob chiffré ou depuis le format texte clair.
# Usage  : eval $(gps_parse_did_coords "$did_json_content")
# Expose : GPS_LAT_PARSED  GPS_LON_PARSED
gps_parse_did_coords() {
    local cnt="$1"
    local lat="" lon=""
    # Essayer d'abord le format chiffré (nouveau DID)
    local enc; enc=$(echo "$cnt" | jq -r '.metadata.coordinates.encrypted // empty' 2>/dev/null)
    if [[ -n "$enc" ]]; then
        local plain; plain=$(gps_decrypt "$enc" 2>/dev/null)
        if [[ -n "$plain" ]]; then
            lat=$(echo "$plain" | grep -oP '(?<=LAT=)[^;]+' | tr -d ' ')
            lon=$(echo "$plain" | grep -oP '(?<=LON=)[^;]+' | tr -d ' ')
        fi
    fi
    # Fallback : format texte clair (ancien DID)
    if [[ -z "$lat" || -z "$lon" ]]; then
        lat=$(echo "$cnt" | jq -r '.metadata.coordinates.latitude  // empty' 2>/dev/null | tr -d ' ')
        lon=$(echo "$cnt" | jq -r '.metadata.coordinates.longitude // empty' 2>/dev/null | tr -d ' ')
    fi
    printf 'GPS_LAT_PARSED=%q; GPS_LON_PARSED=%q' "$lat" "$lon"
}
