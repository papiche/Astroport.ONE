#!/bin/bash
# Test de tools/ipns_handover.sh sur une CLÉ JETABLE, sans réseau (IPNS_HANDOVER_OFFLINE=1).
# La même clé sert d'« ancienne » puis de « nouvelle » station : export avant release, import après.
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
H="$SCRIPT_DIR/tools/ipns_handover.sh"
export IPNS_HANDOVER_OFFLINE=1 IPNS_HANDOVER_TIMEOUT=5s
K="handover-test-$$"; TMP=$(mktemp -d); PASS=0; FAIL=0
ok()  { echo "✅ $1"; PASS=$((PASS+1)); }
ko()  { echo "❌ $1"; FAIL=$((FAIL+1)); }
eq()  { [[ "$1" == "$2" ]] && ok "$3" || ko "$3 (attendu « $1 », obtenu « $2 »)"; }
cleanup() { ipfs key rm "$K" >/dev/null 2>&1; ipfs pin rm "$C1" "$C2" >/dev/null 2>&1; rm -rf "$TMP"; }
trap cleanup EXIT

ipfs key gen "$K" >/dev/null 2>&1 || { echo "ipfs indisponible"; exit 1; }
ID=$(ipfs key list -l | awk -v k="$K" '$2==k{print $1}')
C1=$(echo "ancien uDRIVE $$" | ipfs add -Q); C2=$(echo "nouveau uDRIVE $$" | ipfs add -Q)
C3=$(echo "non épinglé $$" | ipfs add -Q --pin=false)
seq_of() { ipfs routing get "/ipns/$ID" 2>/dev/null | ipfs name inspect 2>/dev/null | awk '/^Sequence:/{print $2; exit}'; }

# « Ancienne station » : plusieurs publications
for c in $C1 $C2 $C1 $C2 $C1 $C2; do ipfs name publish --allow-offline --key="$K" /ipfs/$c >/dev/null 2>&1; done
OLD=$(seq_of); ipfs key export "$K" -o "$TMP/k.key" >/dev/null 2>&1

# release : imprime la séquence, retire la clé
OUT=$("$H" release x@y.z --key "$K" 2>"$TMP/err")
eq "SEQ=$OLD" "$(echo "$OUT" | sed -n 1p)" "release : imprime la séquence courante ($OLD)"
eq "VALUE=/ipfs/$C2" "$(echo "$OUT" | sed -n 2p)" "release : imprime le contenu publié (à reprendre)"
[[ -z "$(ipfs key list -l | awk -v k="$K" '$2==k')" ]] && ok "release : clé retirée du trousseau" || ko "release : clé toujours présente"
"$H" release x@y.z --key "$K" >/dev/null 2>"$TMP/err"; grep -q "ERROR:NO_KEY" "$TMP/err" && ok "release deux fois : erreur visible NO_KEY" || ko "release deux fois : pas d'erreur"

# claim sans clé importée
"$H" claim x@y.z "$C2" --key "$K" >/dev/null 2>"$TMP/err"; grep -q "ERROR:NO_KEY" "$TMP/err" && ok "claim sans clé : erreur NO_KEY" || ko "claim sans clé : pas d'erreur"

# « Nouvelle station » : même clé importée
ipfs key import "$K" "$TMP/k.key" >/dev/null 2>&1

"$H" claim x@y.z "$C3" --key "$K" >/dev/null 2>"$TMP/err"; grep -q "ERROR:NOT_PINNED" "$TMP/err" && ok "claim d'un contenu non épinglé : refusé" || ko "claim non épinglé accepté"

NEW=$("$H" claim x@y.z "$C2" --key "$K" 2>"$TMP/err")
[[ "$NEW" =~ ^SEQ=([0-9]+)$ && "${BASH_REMATCH[1]}" -gt "$OLD" ]] && ok "claim : séquence ${NEW#SEQ=} > ancienne $OLD" || { ko "claim : $NEW"; cat "$TMP/err"; }
eq "/ipfs/$C2" "$(ipfs routing get /ipns/$ID 2>/dev/null | ipfs name inspect 2>/dev/null | awk -F'"' '/^Value:/{print $2}')" "claim : le record pointe vers le nouveau contenu"

# --after : l'ancienne station a vu une séquence plus haute que celle du réseau local
A=$(( $(seq_of) + 40 ))
AFT=$("$H" claim x@y.z "$C1" --key "$K" --after "$A" 2>"$TMP/err")
eq "SEQ=$((A+1))" "$AFT" "claim --after $A : séquence $((A+1))"

echo; echo "Passés: $PASS  Échoués: $FAIL"; [[ $FAIL -eq 0 ]]
