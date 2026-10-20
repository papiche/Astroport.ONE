#!/bin/bash
# -----------------------------------------------------------------------------
# adopt_fixups.sh <EMAIL> — mises à jour PUBLIQUES, ciblées, quand un compte qui déménage (MÊME clé) arrive
# sur cette station : seul ce qui change est « chez qui il habite ». Rien n'est recréé, rien n'est écrasé :
#   1. home.station            → CETTE station (IPFSNODEID:NODEHEX)
#   2. DID (kind 30800)        → nouvelle version publiée (did_manager_nostr.sh update, état conservé)
#   3. profil kind 0           → SEUL le champ home_station change (nostr_update_profile.py fusionne avec
#                                le profil existant : nom, photo, bio de la personne intacts)
#   4. suivis                  → le Capitaine de CETTE station suit le compte, et le compte suit ce Capitaine
#                                (nostr_follow.sh ajoute à la liste existante, ne la remplace pas)
# Contrairement à make_NOSTRCARD.sh : aucune primo-transaction, aucun email de clés, aucun profil par défaut,
# aucune publication IPNS (réservée à ipns_handover.sh, séquence supérieure à l'ancienne).
# Sortie : une ligne OK:/WARN: par étape ; code 0 si tout est passé, 2 si une étape a échoué (jamais muet).
# -----------------------------------------------------------------------------
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "${MY_PATH}/my.sh"

EMAIL="$1"
[[ -n "$EMAIL" && "$EMAIL" == *@* ]] || { echo "ERROR:USAGE adopt_fixups.sh <EMAIL>" >&2; exit 1; }
DIR="${ZEN_GAME_NOSTR:-$HOME/.zen/game/nostr}/${EMAIL}"
[[ -s "$DIR/.secret.nostr" && -s "$DIR/HEX" ]] || { echo "ERROR:NO_ACCOUNT ${EMAIL}: .secret.nostr/HEX absents" >&2; exit 1; }
HEX=$(cat "$DIR/HEX")
RC=0
warn() { echo "WARN:$1" >&2; RC=2; }

## 1. home.station
NODE_HEX=""
[[ -s "$HOME/.zen/game/secret.nostr" ]] && NODE_HEX=$(sed 's/.*HEX=\([^;]*\).*/\1/' "$HOME/.zen/game/secret.nostr")
if [[ -n "$IPFSNODEID" && -n "$NODE_HEX" ]]; then
    echo "${IPFSNODEID}:${NODE_HEX}" > "$DIR/home.station"; chmod 644 "$DIR/home.station"
    echo "OK:home.station ${IPFSNODEID}"
else
    warn "home.station : IPFSNODEID ou identité NOSTR du NODE introuvable — non mis à jour"
fi

## 2. DID
if [[ -x "${MY_PATH}/did_manager_nostr.sh" ]]; then
    if "${MY_PATH}/did_manager_nostr.sh" update "$EMAIL" "MULTIPASS" 0 0 >/dev/null 2>&1; then echo "OK:DID republié"
    else warn "DID : did_manager_nostr.sh update a échoué"; fi
else warn "DID : did_manager_nostr.sh introuvable"; fi

## 3. profil kind 0 : home_station seulement
if [[ -n "$IPFSNODEID" && -n "$NODE_HEX" ]]; then
    if python3 "${MY_PATH}/nostr_update_profile.py" "$EMAIL" "ws://127.0.0.1:7777" "wss://relay.copylaradio.com" \
            --home_station "${IPFSNODEID}:${NODE_HEX}" >/dev/null 2>&1; then echo "OK:profil kind 0 (home_station)"
    else warn "profil : nostr_update_profile.py a échoué (home_station non publié)"; fi
fi

## 4. suivis (le Capitaine de cette station ↔ le compte), sauf si le compte EST le Capitaine
if [[ -n "$CAPTAINEMAIL" && "$CAPTAINEMAIL" != "$EMAIL" && -s "$HOME/.zen/game/nostr/${CAPTAINEMAIL}/HEX" ]]; then
    CAPTAINHEX=$(cat "$HOME/.zen/game/nostr/${CAPTAINEMAIL}/HEX")
    CAPTAINNSEC=$(grep -oP 'NSEC=\K[^;]+' "$HOME/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr" 2>/dev/null)
    if [[ -n "$CAPTAINNSEC" ]] && NOSTR_NSEC="$CAPTAINNSEC" "${MY_PATH}/nostr_follow.sh" - "$HEX" "$myRELAY" >/dev/null 2>&1; then
        echo "OK:le Capitaine ${CAPTAINEMAIL} suit ${EMAIL}"
    else warn "suivi : le Capitaine n'a pas pu suivre ${EMAIL}"; fi
    unset CAPTAINNSEC
    USERNSEC=$(grep -oP 'NSEC=\K[^;]+' "$DIR/.secret.nostr" 2>/dev/null)
    if [[ -n "$USERNSEC" ]] && NOSTR_NSEC="$USERNSEC" "${MY_PATH}/nostr_follow.sh" - "$CAPTAINHEX" "$myRELAY" >/dev/null 2>&1; then
        echo "OK:${EMAIL} suit le Capitaine ${CAPTAINEMAIL}"
    else warn "suivi : ${EMAIL} n'a pas pu suivre le Capitaine"; fi
    unset USERNSEC
else
    echo "OK:suivis (aucun Capitaine distinct à suivre)"
fi
exit $RC
