#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# License: AGPL-3.0
################################################################################
#~ n2_mint_authorities.sh — maintient ~/.zen/strfry/n2_mint_authorities.txt
#~
#~ Chaque station possède SA clé de mint (~/.zen/game/n2_mint.nostr, jamais partagée) ; sa clé
#~ publique est publiée avec la balise (n2_mint.hex). Une station reconnaît comme autorités de
#~ mint : la sienne + celles des stations de SON essaim (~/.zen/tmp/swarm/*/n2_mint.hex).
#~
#~ APPEND-ONLY : les lignes existantes (ex. ancienne clé de mint partagée) ne sont JAMAIS
#~ retirées — les évènements déjà signés restent valides. Seuls des hex64 sont acceptés.
#~ Pour retirer une autorité : édition manuelle du fichier par le capitaine.
################################################################################
IPFSNODEID="${IPFSNODEID:-$(jq -r '.Identity.PeerID // empty' "$HOME/.ipfs/config" 2>/dev/null)}"
[[ -z "$IPFSNODEID" ]] && exit 0
AUTH="${N2_MINT_AUTHORITIES_FILE:-$HOME/.zen/strfry/n2_mint_authorities.txt}"
KEYFILE="${N2_MINT_KEYFILE:-$HOME/.zen/game/n2_mint.nostr}"
SWARM_DIR="${N2_SWARM_DIR:-$HOME/.zen/tmp/swarm}"
NODE_DIR="${N2_NODE_DIR:-$HOME/.zen/tmp/${IPFSNODEID}}"
mkdir -p "$(dirname "$AUTH")" "$NODE_DIR"; touch "$AUTH"

# 1. publier NOTRE clé publique de mint avec la balise (jamais la clé privée)
if [[ -s "$KEYFILE" ]]; then
    mine=$(grep -oP 'HEX=\K[0-9a-f]{64}' "$KEYFILE" | head -1)
    [[ -n "$mine" ]] && echo "$mine" > "$NODE_DIR/n2_mint.hex"
fi

# 2. reconnaître la nôtre + celles de l'essaim (hex64 uniquement, sans doublon)
{ cat "$NODE_DIR/n2_mint.hex" 2>/dev/null; cat "$SWARM_DIR"/*/n2_mint.hex 2>/dev/null; } \
  | tr -d ' \r' | grep -E '^[0-9a-f]{64}$' | sort -u | while read -r h; do
    grep -qx "$h" "$AUTH" || { echo "$h" >> "$AUTH"; echo "[n2_mint_authorities] + $h" >&2; }
done
exit 0
