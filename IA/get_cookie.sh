#!/bin/bash
########################################################################
# get_cookie.sh
# Helper script to get cookie file path for a specific domain
#
# Usage: $0 <player_email> <domain>
#
# Examples:
#   $0 user@email.com youtube.com
#   $0 user@email.com leboncoin.fr
#   $0 npub1... amazon.fr
#
# Returns the path to the cookie file for the specified domain
########################################################################

PLAYER="$1"
DOMAIN="$2"

if [[ -z "$PLAYER" || -z "$DOMAIN" ]]; then
    echo "Usage: $0 <player_email> <domain>" >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  $0 user@email.com youtube.com" >&2
    echo "  $0 user@email.com leboncoin.fr" >&2
    echo "  $0 npub1... amazon.fr" >&2
    exit 1
fi

# Normalize domain (remove www, leading dot, etc.)
NORMALIZED_DOMAIN=$(echo "$DOMAIN" | sed 's/^www\.//' | sed 's/^\.//')

# Player directory path
PLAYER_DIR="$HOME/.zen/game/nostr/${PLAYER}"

# Check if player directory exists
if [[ ! -d "$PLAYER_DIR" ]]; then
    echo "Error: Player directory not found: $PLAYER_DIR" >&2
    exit 1
fi

# Priority paths to check (in order) - all hidden files at root of NOSTR directory
COOKIE_PATHS=(
    "${PLAYER_DIR}/.${NORMALIZED_DOMAIN}.cookie"       # Single-domain specific
    "${PLAYER_DIR}/.${DOMAIN}.cookie"                  # Single-domain specific (alternative)
    "${PLAYER_DIR}/.cookie.txt"                        # Multi-domain or legacy
)

# Try to find cookie file
for COOKIE_PATH in "${COOKIE_PATHS[@]}"; do
    if [[ -f "$COOKIE_PATH" ]]; then
        # Verify it's a valid cookie file
        if grep -q "${NORMALIZED_DOMAIN}" "$COOKIE_PATH" 2>/dev/null || grep -q "${DOMAIN}" "$COOKIE_PATH" 2>/dev/null; then
            echo "$COOKIE_PATH"
            exit 0
        fi
    fi
done

# If no specific cookie found, try to find any cookie file in player directory
# List all .cookie files that match the domain
for COOKIE_FILE in "$PLAYER_DIR"/.*.cookie "$PLAYER_DIR"/.cookie.txt; do
    if [[ -f "$COOKIE_FILE" ]]; then
        if grep -q "${NORMALIZED_DOMAIN}" "$COOKIE_FILE" 2>/dev/null || grep -q "${DOMAIN}" "$COOKIE_FILE" 2>/dev/null; then
            echo "$COOKIE_FILE"
            exit 0
        fi
    fi
done

# No cookie found
echo "Error: No cookie file found for domain '$DOMAIN' for player '$PLAYER'" >&2
echo "" >&2
echo "Paths checked:" >&2
echo "  - ${PLAYER_DIR}/.${NORMALIZED_DOMAIN}.cookie" >&2
echo "  - ${PLAYER_DIR}/.${DOMAIN}.cookie" >&2
echo "  - ${PLAYER_DIR}/.cookie.txt" >&2
echo "" >&2
echo "To upload a cookie file, use the /api/fileupload endpoint with a .txt cookie file." >&2
exit 1

