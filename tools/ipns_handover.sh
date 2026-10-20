#!/bin/bash
# -----------------------------------------------------------------------------
# ipns_handover.sh — passation du /ipns/<NOSTRNS> d'un MULTIPASS entre deux stations
#
# Déménagement à clé identique : la clé IPNS est dérivée des identifiants du
# MULTIPASS (make_NOSTRCARD.sh : keygen -t ipfs), donc la nouvelle station retrouve
# exactement le même /ipns/. Le piège est le NUMÉRO DE SÉQUENCE : les résolveurs et
# le pubsub gardent le record de séquence la plus haute. L'ancienne station publie à
# chaque cycle (centaines de fois) ; une station neuve repart de 0 et resterait
# INVISIBLE jusqu'à l'expiration de l'ancien record (48 h par défaut), sans aucune erreur.
#
#   ipns_handover.sh release <EMAIL> [--key NOM]
#       ANCIENNE station : lit la séquence courante, retire la clé du trousseau Kubo
#       (sinon Kubo republie l'ancien record toutes les 4 h et se dispute la séquence).
#       Imprime SEQ=<n> et VALUE=/ipfs/<cid> sur stdout (à transmettre à la nouvelle
#       station : --after, et le contenu à épingler puis publier).
#
#   ipns_handover.sh claim <EMAIL> <CID> [--after N] [--key NOM]
#       NOUVELLE station : publie <CID> avec une séquence STRICTEMENT supérieure à
#       max(séquence vue sur le réseau, N). Relit et vérifie. Le contenu doit être
#       épinglé ici AVANT (sinon l'IPNS pointerait vers un contenu que personne ne sert).
#       Imprime SEQ=<n> sur stdout.
#
# Ne touche JAMAIS au DNSLink (OVH) : l'ancienne station le supprimerait après que la
# nouvelle l'a recréé (même sous-domaine).
#
# Variables : ZEN_GAME_NOSTR (défaut ~/.zen/game/nostr), IPNS_HANDOVER_OFFLINE=1 (tests :
# --allow-offline, aucun accès réseau), IPNS_HANDOVER_TIMEOUT (lecture du routage, défaut 30s). Erreurs : lignes ERROR:<code> sur stderr, code 1.
# -----------------------------------------------------------------------------

GAME_NOSTR="${ZEN_GAME_NOSTR:-$HOME/.zen/game/nostr}"
OFFLINE=()
[[ "${IPNS_HANDOVER_OFFLINE:-0}" == "1" ]] && OFFLINE=(--allow-offline)

die() { echo "ERROR:$1 $2" >&2; exit 1; }

# Séquence du record IPNS vu par le routage : nombre, ou "none" si introuvable.
# Affiche la séquence du record (ou "none").
net_sequence() {
    local id="$1" rec seq inspect
    rec=$(mktemp) || die mktemp ""
    if ! ipfs routing get "/ipns/${id}" --timeout="${IPNS_HANDOVER_TIMEOUT:-30s}" > "$rec" 2>/dev/null || [[ ! -s "$rec" ]]; then
        rm -f "$rec"; echo none; return 0
    fi
    inspect=$(ipfs name inspect < "$rec" 2>/dev/null)
    rm -f "$rec"
    seq=$(echo "$inspect" | awk '/^Sequence:/{print $2; exit}')
    [[ "$seq" =~ ^[0-9]+$ ]] || die BAD_RECORD "séquence illisible pour /ipns/${id}"
    echo "$seq"
}

resolve_key() {   # EMAIL [NOM] -> pose KEY_NAME, IPNS_ID
    local email="$1" forced="$2" g1pub
    if [[ -n "$forced" ]]; then
        KEY_NAME="$forced"
    else
        [[ -s "${GAME_NOSTR}/${email}/G1PUBNOSTR" ]] || die NO_MULTIPASS "${email} : G1PUBNOSTR absent de ${GAME_NOSTR}"
        g1pub=$(cat "${GAME_NOSTR}/${email}/G1PUBNOSTR")
        KEY_NAME="${g1pub}:NOSTR"
    fi
    IPNS_ID=$(ipfs key list -l | awk -v k="$KEY_NAME" '$2==k{print $1}')
}

ACTION="$1"; EMAIL="$2"; shift 2 2>/dev/null
CID=""; AFTER=""; FORCED_KEY=""
[[ "$ACTION" == "claim" ]] && { CID="$1"; shift 1 2>/dev/null; }
while [[ $# -gt 0 ]]; do
    case "$1" in
        --after) AFTER="$2"; shift 2 ;;
        --key)   FORCED_KEY="$2"; shift 2 ;;
        *) die USAGE "argument inconnu : $1" ;;
    esac
done
[[ -n "$ACTION" && -n "$EMAIL" ]] || die USAGE "ipns_handover.sh release|claim <EMAIL> [<CID>] [--after N] [--key NOM]"
[[ -z "$AFTER" || "$AFTER" =~ ^[0-9]+$ ]] || die USAGE "--after attend un entier"
command -v ipfs >/dev/null || die NO_IPFS "ipfs introuvable"

resolve_key "$EMAIL" "$FORCED_KEY"

case "$ACTION" in
release)
    [[ -n "$IPNS_ID" ]] || die NO_KEY "clé « ${KEY_NAME} » absente du trousseau Kubo (déjà libérée ?)"
    SEQ=$(net_sequence "$IPNS_ID")
    VALUE=$(ipfs routing get "/ipns/${IPNS_ID}" --timeout="${IPNS_HANDOVER_TIMEOUT:-30s}" 2>/dev/null | ipfs name inspect 2>/dev/null | awk -F'"' '/^Value:/{print $2; exit}')
    if [[ "$SEQ" == "none" ]]; then
        echo "WARN:no_record /ipns/${IPNS_ID} introuvable sur le réseau (jamais publié ou expiré) — séquence 0" >&2
        SEQ=0
    fi
    ipfs key rm "$KEY_NAME" >/dev/null || die KEY_RM "ipfs key rm « ${KEY_NAME} » a échoué"
    echo "released /ipns/${IPNS_ID} (clé retirée, Kubo ne republiera plus)" >&2
    echo "SEQ=${SEQ}"
    echo "VALUE=${VALUE}"
    ;;
claim)
    [[ -n "$IPNS_ID" ]] || die NO_KEY "clé « ${KEY_NAME} » absente du trousseau Kubo : recréer le MULTIPASS (même salt/pepper) d'abord"
    [[ -n "$CID" ]] || die USAGE "claim : CID requis"
    # Le contenu doit être servi par CETTE station avant de pointer dessus.
    # (--type=all parcourt les épingles indirectes : des minutes sur un CID inconnu)
    { ipfs pin ls --type=recursive "$CID" || ipfs pin ls --type=direct "$CID"; } >/dev/null 2>&1 || die NOT_PINNED "${CID} n'est pas épinglé ici — ipfs pin add d'abord"

    NET=$(net_sequence "$IPNS_ID")
    BASE=-1
    [[ "$NET" != "none" ]] && BASE=$NET
    [[ -n "$AFTER" && "$AFTER" -gt "$BASE" ]] && BASE=$AFTER
    TARGET=$((BASE + 1))

    OUT=$(ipfs name publish "${OFFLINE[@]}" --key="$KEY_NAME" --sequence="$TARGET" "/ipfs/${CID}" 2>&1)
    if [[ $? -ne 0 ]]; then
        # Kubo a déjà un record local plus haut que notre cible : il choisit seul la suite.
        if echo "$OUT" | grep -q "must be greater than the current record sequence"; then
            OUT=$(ipfs name publish "${OFFLINE[@]}" --key="$KEY_NAME" "/ipfs/${CID}" 2>&1) \
                || die PUBLISH "$OUT"
        else
            die PUBLISH "$OUT"
        fi
    fi

    # Vérification : le record relu doit pointer vers CID avec une séquence > l'ancienne.
    REC=$(mktemp)
    ipfs routing get "/ipns/${IPNS_ID}" --timeout="${IPNS_HANDOVER_TIMEOUT:-30s}" > "$REC" 2>/dev/null
    INSPECT=$(ipfs name inspect < "$REC" 2>/dev/null); rm -f "$REC"
    GOT_SEQ=$(echo "$INSPECT" | awk '/^Sequence:/{print $2; exit}')
    GOT_VAL=$(echo "$INSPECT" | awk -F'"' '/^Value:/{print $2; exit}')
    [[ "$GOT_VAL" == "/ipfs/${CID}" ]] || die VERIFY "le record relu pointe vers « ${GOT_VAL} », attendu /ipfs/${CID}"
    [[ "$GOT_SEQ" =~ ^[0-9]+$ && "$GOT_SEQ" -gt "$BASE" ]] || die VERIFY "séquence relue ${GOT_SEQ:-?} <= ancienne ${BASE}"
    echo "claimed /ipns/${IPNS_ID} -> /ipfs/${CID} (séquence ${GOT_SEQ}, ancienne ${NET})" >&2
    echo "SEQ=${GOT_SEQ}"
    ;;
*)
    die USAGE "action inconnue : $ACTION (release|claim)"
    ;;
esac
