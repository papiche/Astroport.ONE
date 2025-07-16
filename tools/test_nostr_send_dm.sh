#!/bin/bash
# Test script for nostr_send_dm.py (interactive, send as CAPTAIN)

CAPTAIN_SECRET="$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
if [[ ! -f "$CAPTAIN_SECRET" ]]; then
    echo "❌ Captain secret file not found: $CAPTAIN_SECRET"
    exit 1
fi
source "$CAPTAIN_SECRET"
if [[ -z "$NSEC" ]]; then
    echo "❌ No NSEC found in Captain secret file"
    exit 1
fi

# List all possible recipients
RECIPIENTS=()
RECIPIENT_HEX=()
echo "Available recipients:"
index=1
for dir in $HOME/.zen/game/nostr/*@*; do
    if [[ -d "$dir" && -f "$dir/HEX" ]]; then
        kname=$(basename "$dir")
        hex=$(cat "$dir/HEX")
        RECIPIENTS+=("$kname")
        RECIPIENT_HEX+=("$hex")
        echo "  [$index] $kname ($hex)"
        ((index++))
    fi
done
if [[ ${#RECIPIENTS[@]} -eq 0 ]]; then
    echo "❌ No recipients found in ~/.zen/game/nostr/*@*"
    exit 1
fi

# Ask user to select recipient
read -p "Select recipient number: " sel
if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel > ${#RECIPIENTS[@]} )); then
    echo "Invalid selection."
    exit 1
fi
recipient_name="${RECIPIENTS[$((sel-1))]}"
recipient_hex="${RECIPIENT_HEX[$((sel-1))]}"
echo "Selected: $recipient_name ($recipient_hex)"

# Ask for message
read -p "Enter the message to send (default: Hello from CAPTAIN!): " msg
if [[ -z "$msg" ]]; then
    msg="Hello from CAPTAIN to $recipient_name at $(date '+%Y-%m-%d %H:%M:%S')"
fi

echo "\nSending secret message..."
$HOME/.zen/Astroport.ONE/tools/nostr_send_dm.py "$NSEC" "$recipient_hex" "$msg"

exit $? 