#!/bin/bash
################################################################################
# zen_like_retry.sh — rejoue les paiements ẐEN roaming (Kind 7) qui n'ont pas pu être relayés.
#
# NIP-101/filter/7.sh dépose dans ~/.zen/game/zen_like_pending/<event_id>.json tout paiement d'un
# utilisateur en roaming qu'il n'a pas pu transmettre à sa home station (home.station introuvable,
# secret du nœud absent, envoi intercom échoué). Ce script (lancé par 20h12.process.sh) retente :
#   - home.station connue maintenant + envoi OK → fichier supprimé ;
#   - toujours impossible → conservé ; au-delà de 7 jours : déplacé dans failed/ et le Capitaine est alerté.
# La home station revérifie tout (tools/zen_like_verify.py) : rejouer un message ne peut pas payer deux fois.
# Usage : zen_like_retry.sh [--dry-run]
################################################################################
MY_PATH="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
PENDING="$HOME/.zen/game/zen_like_pending"
FAILED="$PENDING/failed"
KEY_DIR="$HOME/.zen/game/nostr"
MAX_AGE=$((7 * 86400))
DRY=false; [[ "${1:-}" == "--dry-run" ]] && DRY=true

[[ -d "$PENDING" ]] || exit 0
shopt -s nullglob
files=("$PENDING"/*.json)
[[ ${#files[@]} -eq 0 ]] && exit 0

. "$MY_PATH/my.sh" >/dev/null 2>&1 || true
sent=0; kept=0; expired=0
for f in "${files[@]}"; do
    email=$(jq -r '.payload.email // ""' "$f" 2>/dev/null)
    at=$(jq -r '.at // 0' "$f" 2>/dev/null)
    age=$(( $(date +%s) - at ))
    home_hex=""
    [[ -n "$email" && -f "$KEY_DIR/$email/home.station" ]] && \
        home_hex=$(cut -d: -f2 < "$KEY_DIR/$email/home.station" | tr -d '[:space:]')

    if [[ ${#home_hex} -eq 64 && -s "$HOME/.zen/game/secret.nostr" ]]; then
        if $DRY; then echo "[dry-run] rejouerait $(basename "$f") → ${home_hex:0:12}…"; kept=$((kept+1)); continue; fi
        ( source "$HOME/.zen/game/secret.nostr"
          python3 "$MY_PATH/nostr_node_intercom.py" send --nsec "${NSEC:-}" --to "$home_hex" --channel zen_like \
              --payload "$(jq -c '.payload' "$f")" --relays "wss://relay.copylaradio.com" >/dev/null 2>&1 ) \
          && { rm -f "$f"; sent=$((sent+1)); echo "✈️ zen_like rejoué : $(basename "$f")"; continue; }
    fi

    if (( age > MAX_AGE )); then
        $DRY && { echo "[dry-run] expirerait $(basename "$f")"; expired=$((expired+1)); continue; }
        mkdir -p "$FAILED"; mv "$f" "$FAILED/" && expired=$((expired+1))
        if [[ -n "${CAPTAINEMAIL:-}" && -x "$MY_PATH/mailjet.sh" ]]; then
            tmp=$(mktemp /tmp/zen_like_XXXXXX.html)
            printf '<h2>💸 Paiement ẐEN roaming non relayé</h2><p>%s : %sẐ à destination de %s… n\x27a pas pu être transmis à sa station d\x27origine depuis plus de 7 jours.</p><p>Dossier : <code>%s</code></p>' \
                "$email" "$(jq -r '.payload.zen_amount' "$FAILED/$(basename "$f")")" "$(jq -r '.payload.g1pub_dest[:12]' "$FAILED/$(basename "$f")")" "$FAILED" > "$tmp"
            bash "$MY_PATH/mailjet.sh" --expire 48h "$CAPTAINEMAIL" "$tmp" "💸 Paiement roaming non relayé — $email" >/dev/null 2>&1
            rm -f "$tmp"
        fi
    else
        kept=$((kept+1))
    fi
done
echo "zen_like_retry : $sent rejoué(s), $kept en attente, $expired expiré(s)"
