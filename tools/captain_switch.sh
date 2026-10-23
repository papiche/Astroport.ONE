#!/bin/bash
################################################################################
# captain_switch.sh — Change le capitaine de la station
# Author: Fred (support@qo-op.com)
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
#
# Usage : captain_switch.sh [--list] [--dry-run] [--no-restart] [--no-primo]
#                           [--no-funds] [--yes] EMAIL
#
# Fait, dans l'ordre :
#   1. vérifie que EMAIL a une ZEN Card (players/EMAIL) ET un MULTIPASS (nostr/EMAIL)
#   2. repointe ~/.zen/game/players/.current
#   3. purge le cache du wallet capitaine (uplanet.captain.{dunikey,ss58}) : il est
#      nommé par préfixe, pas par email — sans purge il reste celui de l'ancien capitaine
#   4. purge les fichiers publiés qui désignent l'ancien capitaine (HEX_CAPTAIN…)
#   5. recharge my.sh et vérifie que CAPTAINEMAIL / CAPTAINHEX / CAPTAING1PUB suivent
#   6. PRIMO TX : tout portefeuille d'une UPlanet doit avoir pour source primale le
#      portefeuille central (uplanet.G1). Pour la ZEN Card, le MULTIPASS et le wallet
#      capitaine du nouveau capitaine : contrôle du primal réel (G1primal.sh), et 1 Ğ1
#      depuis uplanet.G1 s'ils sont vides. Un wallet au mauvais primal est signalé (immuable)
#   7. transfère les Ẑen (tout le solde transférable) de l'ancien capitaine vers le
#      nouveau : ZEN Card → ZEN Card, MULTIPASS → MULTIPASS, wallet capitaine → wallet
#      capitaine. Le dépôt existentiel (1 Ğ1) reste sur l'ancien wallet, qui reste vivant.
#      Jamais vers un wallet dont le primal n'est pas validé.
#   8. redémarre astroport (sauf --no-restart)
################################################################################
MY_PATH="$( cd "$(dirname "$0")" && pwd )"
ASTRO="$( cd "$MY_PATH/.." && pwd )"

PLAYERS="$HOME/.zen/game/players"
NOSTR="$HOME/.zen/game/nostr"
GAME="$HOME/.zen/game"
CURRENT_LINK="$PLAYERS/.current"

DRY=0; RESTART=1; YES=0; LIST=0; PRIMO=1; FUNDS=1; TARGET=""
for a in "$@"; do
    case "$a" in
        --list) LIST=1 ;;
        --dry-run) DRY=1 ;;
        --no-restart) RESTART=0 ;;
        --no-primo) PRIMO=0 ;;
        --no-funds) FUNDS=0 ;;
        --yes|-y) YES=1 ;;
        -h|--help) sed -n 2,26p "$0"; exit 0 ;;
        -*) echo "Option inconnue : $a" >&2; exit 2 ;;
        *) TARGET="$a" ;;
    esac
done

run() { if [[ $DRY == 1 ]]; then echo "  [dry-run] $*"; else "$@"; fi; }

# Solde Ğ1 frais (0 si illisible). Les Ẑen = (Ğ1 - 1) * 10
balance() { "$ASTRO/tools/G1check.sh" "$1" --fresh 2>/dev/null | tail -n 1 | grep -E '^[0-9]+(\.[0-9]+)?$' || echo 0; }
zen() { echo "scale=1; ($1 - 1) * 10" | bc -l 2>/dev/null | sed 's/^\./0./; s/^-\./-0./'; }
gt() { (( $(echo "$1 > $2" | bc -l 2>/dev/null || echo 0) )); }

OLD=$(cat "$CURRENT_LINK/.player" 2>/dev/null)

if [[ $LIST == 1 || -z "$TARGET" ]]; then
    echo "Capitaine actuel : ${OLD:-<aucun>}"
    echo "Candidats (ZEN Card + MULTIPASS) :"
    for d in "$PLAYERS"/*@*/; do
        e=$(basename "$d")
        [[ -s "$d/.g1pub" && -s "$NOSTR/$e/HEX" ]] || continue
        [[ "$e" == "$OLD" ]] && echo "  * $e  (actuel)" || echo "    $e"
    done
    [[ -z "$TARGET" && $LIST == 0 ]] && echo && echo "Usage : $0 [--dry-run] [--no-restart] [--no-primo] [--no-funds] [--yes] EMAIL"
    exit 0
fi

## 1. Contrôles : un capitaine incomplet donnerait des variables vides, sans erreur
err=0
for f in "$PLAYERS/$TARGET/.player" "$PLAYERS/$TARGET/.g1pub" "$PLAYERS/$TARGET/secret.dunikey" \
         "$NOSTR/$TARGET/HEX" "$NOSTR/$TARGET/G1PUBNOSTR"; do
    [[ -s "$f" ]] || { echo "❌ manquant : $f" >&2; err=1; }
done
[[ $err == 1 ]] && { echo "Capitaine $TARGET incomplet — rien n'a été modifié." >&2; exit 1; }
if [[ "$(cat "$PLAYERS/$TARGET/.player")" != "$TARGET" ]]; then
    echo "❌ $PLAYERS/$TARGET/.player ne contient pas '$TARGET'" >&2; exit 1
fi
if [[ "$TARGET" == "$OLD" ]]; then
    echo "$TARGET est déjà capitaine."; exit 0
fi
if [[ ( $PRIMO == 1 || $FUNDS == 1 ) && $DRY == 0 && ! -s "$GAME/uplanet.G1.dunikey" ]]; then
    echo "❌ $GAME/uplanet.G1.dunikey absent (source de la primo TX). Utiliser --no-primo --no-funds pour ne changer que le lien." >&2
    exit 1
fi

## Wallets de l'ancien et du nouveau capitaine (les 3 paires à transférer)
O_ZC=$(cat "$PLAYERS/$OLD/.g1pub" 2>/dev/null);          O_ZC_KEY="$PLAYERS/$OLD/secret.dunikey"
O_MP=$(cat "$NOSTR/$OLD/G1PUBNOSTR" 2>/dev/null);        O_MP_KEY="$NOSTR/$OLD/.secret.dunikey"
N_ZC=$(cat "$PLAYERS/$TARGET/.g1pub");
N_MP=$(cat "$NOSTR/$TARGET/G1PUBNOSTR")
O_CP=$(cat "$GAME/uplanet.captain.ss58" 2>/dev/null)

# Le wallet capitaine est purgé à l'étape 3 : on garde la clé de l'ancien pour le transfert
SCRATCH=$(mktemp -d); chmod 700 "$SCRATCH"; trap 'rm -rf "$SCRATCH"' EXIT
O_CP_KEY="$SCRATCH/old.captain.dunikey"
[[ -s "$GAME/uplanet.captain.dunikey" ]] && cp "$GAME/uplanet.captain.dunikey" "$O_CP_KEY" && chmod 600 "$O_CP_KEY"

echo "Capitaine : ${OLD:-<aucun>}  →  $TARGET"
if [[ $FUNDS == 1 && -n "$OLD" ]]; then
    echo "Soldes de l'ancien capitaine (Ğ1 → Ẑen) :"
    for p in "ZEN Card:$O_ZC" "MULTIPASS:$O_MP" "Wallet capitaine:$O_CP"; do
        pub="${p#*:}"; [[ -n "$pub" ]] || continue
        b=$(balance "$pub"); echo "  ${p%%:*} : $b Ğ1 ($(zen "$b") Ẑen)"
    done
fi
if [[ $YES == 0 && $DRY == 0 ]]; then
    read -r -p "Confirmer ? [o/N] " r
    [[ "$r" =~ ^[oOyY]$ ]] || { echo "Annulé."; exit 1; }
fi

## 2. Lien .current
echo "→ lien .current"
run rm -f "$CURRENT_LINK"
run ln -s "$PLAYERS/$TARGET" "$CURRENT_LINK"

## 3. Wallet capitaine : cache nommé par préfixe, pas par email
echo "→ purge du cache wallet capitaine"
run rm -f "$GAME/uplanet.captain.dunikey" "$GAME/uplanet.captain.ss58"

## 4. Fichiers publiés / dérivés de l'ancien capitaine
NODEID=$(cat "$GAME/.IPFSNODEID" 2>/dev/null)
echo "→ purge des fichiers publiés de l'ancien capitaine"
[[ -n "$NODEID" ]] && run rm -f "$HOME/.zen/tmp/$NODEID/HEX_CAPTAIN"
run rm -f "$HOME/.zen/tmp/UPLANETNAME_CAPTAIN"

## 5. Vérification : my.sh doit suivre le nouveau capitaine
N_CP=""
if [[ $DRY == 0 ]]; then
    check=$(env -u CAPTAINEMAIL bash -c ". '$MY_PATH/my.sh' >/dev/null 2>&1; echo \"\$CAPTAINEMAIL|\$CAPTAINHEX|\$CAPTAING1PUB|\$UPLANETNAME_CAPTAIN\"")
    IFS='|' read -r c_mail c_hex c_g1 N_CP <<< "$check"
    echo "→ CAPTAINEMAIL       = $c_mail"
    echo "→ CAPTAINHEX         = ${c_hex:0:16}…"
    echo "→ CAPTAING1PUB       = $c_g1"
    echo "→ UPLANETNAME_CAPTAIN= $N_CP"
    if [[ "$c_mail" != "$TARGET" || -z "$c_hex" || -z "$c_g1" || -z "$N_CP" ]]; then
        echo "❌ my.sh ne résout pas correctement le nouveau capitaine." >&2
        echo "   Retour arrière : ln -sfn $PLAYERS/$OLD $CURRENT_LINK" >&2
        exit 1
    fi
    # La clé IPNS du capitaine (ASTRONAUTENS) est cherchée par email dans le trousseau IPFS
    ipfs key list -l 2>/dev/null | grep -qw "$TARGET" \
        || echo "⚠️  aucune clé IPFS nommée '$TARGET' (ASTRONAUTENS) : à régénérer si besoin." >&2
fi

FAIL=()

## 6. PRIMO TX : TOUT portefeuille d'une UPlanet doit avoir pour source primale le portefeuille
##    central (uplanet.G1 = UPLANETNAME_G1). Vérifié sur le primal RÉEL (G1primal.sh), pas sur le
##    solde : un wallet déjà crédité par quelqu'un d'autre a un mauvais primal, définitif.
##    Donc AVANT tout transfert, et pour les 3 wallets du nouveau capitaine.
declare -A PRIMO_OK=()
primo() { # <pub> <label>
    local pub="$1" label="$2" youser b p
    [[ -n "$pub" ]] || { echo "  ⏭  $label : wallet inconnu"; return 0; }
    if [[ $DRY == 1 ]]; then echo "  [dry-run] $label ($pub) : contrôle du primal, primo TX 1 Ğ1 depuis uplanet.G1 si vide"; return 0; fi
    p=$(cat "$HOME/.zen/tmp/coucou/${pub}.primal" 2>/dev/null)
    [[ -n "$p" ]] || p=$("$ASTRO/tools/G1primal.sh" "$pub" 2>/dev/null | tail -n 1 | grep -E '^g1|^[1-9A-HJ-NP-Za-km-z]{43,50}$')
    if [[ -n "$p" ]]; then
        if [[ "$p" == "$UPLANETNAME_G1" ]]; then
            echo "  ✅ $label : primal = portefeuille central"; return 0
        fi
        echo "  ❌ $label : primal = ${p:0:12}… ≠ central (${UPLANETNAME_G1:0:12}…) — non réparable (primal immuable)" >&2
        return 1
    fi
    b=$(balance "$pub")
    if gt "$b" 0; then
        echo "  ❌ $label : crédité ($b Ğ1) mais primal introuvable — vérifier avant tout transfert" >&2
        return 1
    fi
    youser=$("$ASTRO/tools/clyuseryomail.sh" "$TARGET" 2>/dev/null)
    if "$ASTRO/tools/PAYforSURE.sh" "$GAME/uplanet.G1.dunikey" 1 "$pub" \
        "UPLANET:${UPLANETG1PUB:0:8}:${youser:-INIT}:${label}:PRIMAL" >/dev/null 2>&1; then
        echo "  ✅ $label : primo TX 1 Ğ1 depuis le portefeuille central"
        mkdir -p "$HOME/.zen/tmp/coucou"; echo "${UPLANETNAME_G1}" > "$HOME/.zen/tmp/coucou/${pub}.primal"
        [[ "$label" == "MULTIPASS" ]] && echo "${UPLANETNAME_G1}" > "$NOSTR/$TARGET/G1PRIME" 2>/dev/null
        return 0
    fi
    echo "  ❌ $label : primo TX échouée" >&2
    return 1
}
if [[ $PRIMO == 1 ]]; then
    echo "→ primo TX / contrôle du primal (nouveau capitaine)"
    # UPLANETNAME_G1 / UPLANETG1PUB viennent de my.sh
    # shellcheck disable=SC1091
    [[ $DRY == 0 ]] && . "$MY_PATH/my.sh" >/dev/null 2>&1
    primo "$N_ZC" ZENCARD   && PRIMO_OK[zc]=1 || FAIL+=("primal ZEN Card")
    primo "$N_MP" MULTIPASS && PRIMO_OK[mp]=1 || FAIL+=("primal MULTIPASS")
    primo "$N_CP" CAPTAIN   && PRIMO_OK[cp]=1 || FAIL+=("primal wallet capitaine")
else
    PRIMO_OK[zc]=1; PRIMO_OK[mp]=1; PRIMO_OK[cp]=1
fi

## 7. Transfert des Ẑen : tout le transférable (ALL), le dépôt existentiel reste
transfer() { # <label> <clé source> <pub source> <pub destination> <ok>
    local label="$1" key="$2" src="$3" dst="$4" ok="$5" b
    [[ -n "$src" && -n "$dst" ]] || { echo "  ⏭  $label : wallet source ou destination inconnu"; return 0; }
    [[ "$src" == "$dst" ]] && return 0
    [[ -s "$key" ]] || { echo "  ⏭  $label : clé source absente ($key)"; return 0; }
    if [[ "$ok" != 1 ]]; then
        echo "  ⛔ $label : destination non initialisée (primo TX manquante) — transfert refusé"
        FAIL+=("transfert $label refusé"); return 1
    fi
    if [[ $DRY == 1 ]]; then echo "  [dry-run] $label : ALL ${src:0:8}… → ${dst:0:8}…"; return 0; fi
    b=$(balance "$src")
    # < 1.10 Ğ1 : rien de transférable au-delà du dépôt existentiel (1 Ğ1) + un reste
    if ! gt "$b" 1.10; then echo "  ⏭  $label : solde $b Ğ1, rien à transférer"; return 0; fi
    if "$ASTRO/tools/PAYforSURE.sh" "$key" ALL "$dst" "UPLANET:CAPTAIN:SWITCH:${OLD}->${TARGET}:${label}" >/dev/null 2>&1; then
        echo "  ✅ $label : $(zen "$b") Ẑen transférés (${src:0:8}… → ${dst:0:8}…)"
    else
        echo "  ❌ $label : transfert échoué (solde source $b Ğ1)" >&2
        FAIL+=("transfert $label"); return 1
    fi
}
if [[ $FUNDS == 1 && -n "$OLD" ]]; then
    echo "→ transfert des Ẑen $OLD → $TARGET"
    transfer "ZEN Card"         "$O_ZC_KEY" "$O_ZC" "$N_ZC" "${PRIMO_OK[zc]:-0}"
    transfer "MULTIPASS"        "$O_MP_KEY" "$O_MP" "$N_MP" "${PRIMO_OK[mp]:-0}"
    transfer "Wallet capitaine" "$O_CP_KEY" "$O_CP" "$N_CP" "${PRIMO_OK[cp]:-0}"
fi

## 8. Redémarrage
if [[ $RESTART == 1 ]]; then
    echo "→ redémarrage d'astroport"
    run sudo systemctl restart astroport
else
    echo "→ pas de redémarrage (--no-restart) : relancer 'sudo systemctl restart astroport'"
fi

if [[ ${#FAIL[@]} -gt 0 ]]; then
    echo "⚠️  Capitaine : $TARGET — étapes en échec : ${FAIL[*]}" >&2
    echo "   Relancer à la main : UPLANET.official.sh -l $TARGET -m 1 (primo) ; tools/PAYforSURE.sh <clé> ALL <dest>" >&2
    exit 3
fi
echo "✅ Capitaine : $TARGET"
echo "   _12345.sh republiera HEX_CAPTAIN et l'état au prochain cycle (le swarm le verra alors)."
exit 0
