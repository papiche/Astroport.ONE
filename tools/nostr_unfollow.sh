#!/bin/bash
# nostr_unfollow.sh <SOURCE_NSEC> <DESTINATION_HEX1> [DESTINATION_HEX2...] [RELAY]
# Inverse de nostr_follow.sh : retire les 'p' tags de la liste kind 3 de SOURCE_NSEC.
# SOURCE_NSEC="-" : lit la clé dans NOSTR_NSEC (évite de l'exposer dans `ps`).
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh"

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename "$0") <SOURCE_NSEC> <DESTINATION_HEX1> [DESTINATION_HEX2...] [RELAY]"
    echo "  Unfollows one or more DESTINATION_HEX using SOURCE_NSEC key"
    exit 1
fi

SOURCE_NSEC="$1"
[[ "$SOURCE_NSEC" == "-" ]] && SOURCE_NSEC="$NOSTR_NSEC"
shift
RELAY=""

for last; do true; done
if [[ "$last" =~ ^(wss://|ws://) ]]; then
    RELAY="$last"
    set -- "${@:1:$(($#-1))}"
fi
RELAY="${RELAY:-$myRELAY}"

SOURCE_HEX=$(NOSTR_NSEC="$SOURCE_NSEC" ${MY_PATH}/nostr_nsec2npub2hex.py -)
if [[ -z "$SOURCE_HEX" ]]; then
    echo "Error: Failed to derive pubkey from NSEC." >&2
    exit 1
fi

# Dernier kind 3 connu (le plus récent si plusieurs versions en base)
cd "$HOME/.zen/strfry" || exit 1
EXISTING_EVENT=$(./strfry scan '{"kinds":[3],"authors":["'$SOURCE_HEX'"]}' 2>/dev/null \
    | jq -cs 'max_by(.created_at) // empty' 2>/dev/null)
cd - >/dev/null 2>&1

if [[ -z "$EXISTING_EVENT" ]]; then
    echo "No follow list found for $SOURCE_HEX - nothing to unfollow"
    exit 0
fi

# Retire les p-tags ciblés, conserve tous les autres tags tels quels
HEX_JSON=$(printf '%s\n' "$@" | jq -R . | jq -cs .)
OLD_COUNT=$(echo "$EXISTING_EVENT" | jq '[.tags[] | select(.[0]=="p")] | length')
NEW_TAGS=$(echo "$EXISTING_EVENT" | jq -c --argjson rm "$HEX_JSON" \
    '[.tags[] | select((.[0] == "p" and ((.[1]) as $h | $rm | index($h))) | not)]')
NEW_COUNT=$(echo "$NEW_TAGS" | jq '[.[] | select(.[0]=="p")] | length')

if [[ "$OLD_COUNT" == "$NEW_COUNT" ]]; then
    echo "Not following any of the given pubkeys - list unchanged"
    exit 0
fi

mkdir -p "$HOME/.zen/tmp"
TMP_KEYFILE=$(mktemp -p "$HOME/.zen/tmp")
echo "NSEC=$SOURCE_NSEC;" > "$TMP_KEYFILE"

python3 $MY_PATH/nostr_send_note.py \
    --keyfile "$TMP_KEYFILE" \
    --kind 3 \
    --content "" \
    --tags "$NEW_TAGS" \
    --relays "$RELAY" 2>/dev/null
RET=$?

rm -f "$TMP_KEYFILE"

if [[ $RET -ne 0 ]]; then
    echo "Error: failed to publish updated follow list" >&2
    exit $RET
fi
echo "Follow list updated: $((OLD_COUNT - NEW_COUNT)) entrie(s) removed"
exit 0
