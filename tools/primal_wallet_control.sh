#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com) — réécriture v2 pour Duniter v2s + squid
# Version: 2.0
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# primal_wallet_control.sh
# Contrôle primal des transactions d'un wallet Ğ1 (Duniter v2s)
# Remplace G1history.sh (BMAS v1) et G1primal.sh (BMAS v1)
# par des requêtes GraphQL directes vers l'indexeur squid
#
# LOGIQUE :
#   - Récupère l'historique via squid (transfersReceived + transfersIssued)
#   - Pour chaque tx entrante, vérifie que la source a le même "primal wallet"
#   - Un "primal wallet" = fromId de la PREMIÈRE tx reçue par ce wallet
#   - Les intrusions sont redirigées vers UPLANETNAME_INTRUSION via PAYforSURE.sh
#   - Anti double-traitement : ID unique par tx dans le commentaire de redirection
#
# Usage: primal_wallet_control.sh <wallet_dunikey> <wallet_pubkey> <master_primal> <player_email>
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
ME="${0##*/}"

[[ -f "${MY_PATH}/my.sh" ]] && . "${MY_PATH}/my.sh"

# ── Configuration ─────────────────────────────────────────────────────────────
# Squid URL — mis à jour dynamiquement par duniter_getnode.sh si disponible
SQUID_URL="${SQUID_URL:-https://squid.g1.gyroi.de/v1/graphql}"
if [[ -x "${MY_PATH}/duniter_getnode.sh" ]]; then
    _dyn_squid=$("${MY_PATH}/duniter_getnode.sh" squid 2>/dev/null)
    [[ -n "$_dyn_squid" ]] && SQUID_URL="$_dyn_squid"
fi
DECIMALS=2   # 1 Ğ1 = 100 centimes en brut (v1 migré + v2 natif)
UPASSPORT_AMOUNT=1   # 0.01 Ğ1 = 1 centime brut (DECIMALS=2)

CESIUMIPFS="${CESIUMIPFS:-https://cesium.app}"

# ── Couleurs ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ── Prérequis ─────────────────────────────────────────────────────────────────
for cmd in curl jq bc; do
    command -v "$cmd" &>/dev/null || { echo "Commande requise manquante : $cmd" >&2; exit 1; }
done

# ── Helpers ───────────────────────────────────────────────────────────────────
log()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
loge()  { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERREUR: $*${RESET}" >&2; }
logw()  { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠  $*${RESET}"; }
logok() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $*${RESET}"; }
sep()   { echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; }
sep2()  { echo "═══════════════════════════════════════════════════════════════"; }

# Convertit un BigInt squid en Ğ1 flottant
bigint_to_g1() {
    local raw="$1"
    echo "scale=4; ${raw:-0} / $(python3 -c "print(10**$DECIMALS)" 2>/dev/null || echo 100)" | bc
}

# Génère un lien Cesium
cesium_link() { echo "${CESIUMIPFS}/#/app/wot/${1}/"; }

# ── Requête GraphQL générique ─────────────────────────────────────────────────
graphql() {
    local query_json="$1"
    local resp
    resp=$(curl -sf -X POST \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        --data "$query_json" \
        "$SQUID_URL") || { loge "Requête squid échouée"; return 1; }

    if echo "$resp" | jq -e '.errors' &>/dev/null; then
        loge "Erreur GraphQL : $(echo "$resp" | jq -c '.errors[0].message')"
        return 1
    fi
    echo "$resp"
}

# ── get_wallet_history_squid ──────────────────────────────────────────────────
# Récupère toutes les tx (reçues + envoyées) et les stocke dans output_file
# Format de chaque entrée JSON :
#   { "date": "ISO", "pubkey": "g1...", "amount": float, "amount_raw": int,
#     "comment": "...", "direction": "in"|"out", "blockNumber": int }
get_wallet_history_squid() {
    local wallet_pubkey="$1"
    local output_file="$2"

    log "Récupération historique squid pour ${wallet_pubkey:0:12}..."

    local query
    query=$(jq -cn --arg w "$wallet_pubkey" '{
        query: "query($w:String!){rx:transfers(filter:{toId:{equalTo:$w}},orderBy:BLOCK_NUMBER_ASC){nodes{fromId toId amount timestamp blockNumber comment{remark}}} tx:transfers(filter:{fromId:{equalTo:$w}},orderBy:BLOCK_NUMBER_ASC){nodes{fromId toId amount timestamp blockNumber comment{remark}}}}",
        variables: {w: $w}
    }')

    local resp
    resp=$(graphql "$query") || return 1

    # Fusionne entrantes (direction=in, amount positif) et sortantes (direction=out, amount négatif)
    # Trie par blockNumber ASC
    echo "$resp" | jq --argjson dec "$DECIMALS" '[
        (.data.rx.nodes[] | {
            direction: "in",
            date: .timestamp,
            blockNumber: .blockNumber,
            pubkey: .fromId,
            amount: ((.amount | tonumber) / pow(10; $dec)),
            amount_raw: (.amount | tonumber),
            comment: (.comment.remark // "")
        }),
        (.data.tx.nodes[] | {
            direction: "out",
            date: .timestamp,
            blockNumber: .blockNumber,
            pubkey: .toId,
            amount: (-((.amount | tonumber) / pow(10; $dec))),
            amount_raw: (.amount | tonumber),
            comment: (.comment.remark // "")
        })
    ] | sort_by(.blockNumber)' > "$output_file"

    local count
    count=$(jq 'length' "$output_file" 2>/dev/null || echo 0)
    logok "Historique récupéré : $count transactions"
    return 0
}

# ── get_primal_source_squid ───────────────────────────────────────────────────
# La source primale d'un wallet = fromId de sa toute première transaction reçue
get_primal_source_squid() {
    local wallet_pubkey="$1"
    local silent="${2:-false}"

    # Cache pour éviter de requerier une info immuable
    local cache_file="$HOME/.zen/tmp/coucou/${wallet_pubkey}.primal"
    mkdir -p "$(dirname "$cache_file")"

    if [[ -s "$cache_file" ]]; then
        local cached
        cached=$(cat "$cache_file")
        [[ "$silent" != "true" ]] && log "Primal (cache) pour ${wallet_pubkey:0:12} : ${cached:0:12}..."
        echo "$cached"
        return 0
    fi

    [[ "$silent" != "true" ]] && log "Recherche primal pour ${wallet_pubkey:0:12}..."

    local query
    query=$(jq -cn --arg w "$wallet_pubkey" '{
        query: "query($w:String!){transfers(filter:{toId:{equalTo:$w}},orderBy:BLOCK_NUMBER_ASC,first:1){nodes{fromId blockNumber}}}",
        variables: {w: $w}
    }')

    local resp primal
    resp=$(graphql "$query") || return 1
    primal=$(echo "$resp" | jq -r '.data.transfers.nodes[0].fromId // ""')

    if [[ -n "$primal" && "$primal" != "null" ]]; then
        echo "$primal" > "$cache_file"
        [[ "$silent" != "true" ]] && logok "Primal de ${wallet_pubkey:0:12} : ${primal:0:12}..."
        echo "$primal"
        return 0
    else
        [[ "$silent" != "true" ]] && logw "Pas de primal trouvé pour ${wallet_pubkey:0:12} (wallet sans historique ?)"
        echo ""
        return 1
    fi
}

# ── get_zencard_owner ─────────────────────────────────────────────────────────
get_zencard_owner() {
    local comment="$1"
    local tx_pubkey="$2"
    local email
    email=$(echo "$comment" | grep -oE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' | head -1)
    if [[ -n "$email" && -f "$HOME/.zen/game/players/${email}/.g1pub" ]]; then
        local zencard_pub
        zencard_pub=$(cat "$HOME/.zen/game/players/${email}/.g1pub" 2>/dev/null)
        [[ "$zencard_pub" == "$tx_pubkey" ]] && echo "$email"
    fi
}

# ── display_wallet_info ───────────────────────────────────────────────────────
display_wallet_info() {
    local title="$1" pubkey="$2" desc="$3"
    sep
    echo -e "🏦 ${BOLD}$title${RESET}"
    sep
    echo "📋 $desc"
    echo "🔑 $pubkey"
    echo "🔗 $(cesium_link "$pubkey")"
    echo
}

# ── create_intrusion_wallet ───────────────────────────────────────────────────
create_intrusion_wallet() {
    local dunikey="$HOME/.zen/game/uplanet.INTRUSION.dunikey"
    [[ -f "$dunikey" ]] && return 0

    log "Création du wallet UPLANETNAME_INTRUSION..."
    mkdir -p "$(dirname "$dunikey")"

    if [[ -x "${MY_PATH}/keygen" ]]; then
        "${MY_PATH}/keygen" -t duniter -o "$dunikey" \
            "${UPLANETNAME:-UPLANET}.INTRUSION" "${UPLANETNAME:-UPLANET}.INTRUSION"
        chmod 600 "$dunikey"
        logok "Wallet INTRUSION créé"
        return 0
    fi
    loge "keygen introuvable — impossible de créer le wallet INTRUSION"
    return 1
}

# ── get_intrusion_pubkey ──────────────────────────────────────────────────────
get_intrusion_pubkey() {
    local dunikey="$HOME/.zen/game/uplanet.INTRUSION.dunikey"
    [[ ! -f "$dunikey" ]] && return 1
    grep 'pub:' "$dunikey" | awk '{print $2}'
}

# ── count_existing_intrusions ─────────────────────────────────────────────────
count_existing_intrusions() {
    local history_file="$1"
    # Compte les tx sortantes dont le commentaire contient "INTRUSION" et "ID:"
    jq '[.[] | select(
            .direction == "out" and
            (.comment | (contains("INTRUSION") and contains("ID:")))
        )] | length' "$history_file" 2>/dev/null || echo 0
}

# ── is_intrusion_already_processed ───────────────────────────────────────────
is_intrusion_already_processed() {
    local history_file="$1"
    local tx_id="$2"
    local found
    found=$(jq --arg id "ID:${tx_id}" '
        [.[] | select(.direction == "out" and (.comment | contains($id)))] | length
    ' "$history_file" 2>/dev/null || echo 0)
    [[ "$found" -gt 0 ]]
}

# ── send_redirection_alert ────────────────────────────────────────────────────
send_redirection_alert() {
    local player_email="$1"  wallet_pubkey="$2"  sender="$3"
    local sender_primal="$4" amount="$5"          master_primal="$6"
    local count="$7"         intrusion_pub="$8"

    local template="${MY_PATH}/../templates/NOSTR/wallet_redirection.html"
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    local zenamount
    zenamount=$(echo "scale=1; $amount * 10" | bc)

    if [[ -f "$template" ]]; then
        sed \
            -e "s/{PLAYER}/$player_email/g" \
            -e "s/{TIMESTAMP}/$ts/g" \
            -e "s/{WALLET_PUBKEY}/${wallet_pubkey:0:8}/g" \
            -e "s|{WALLET_CESIUM_LINK}|$(cesium_link "$wallet_pubkey")|g" \
            -e "s/{INTRUSION_SENDER_PUBKEY}/${sender:0:8}/g" \
            -e "s|{SENDER_CESIUM_LINK}|$(cesium_link "$sender")|g" \
            -e "s/{INTRUSION_PRIMAL_PUBKEY}/${sender_primal:0:8}/g" \
            -e "s|{PRIMAL_CESIUM_LINK}|$(cesium_link "$sender_primal")|g" \
            -e "s/{AMOUNT}/$amount/g" \
            -e "s/{MASTER_PRIMAL}/${master_primal:0:8}/g" \
            -e "s|{MASTER_CESIUM_LINK}|$(cesium_link "$master_primal")|g" \
            -e "s/{INTRUSION_COUNT}/$count/g" \
            -e "s/{INTRUSION_WALLET_PUBKEY}/${intrusion_pub:0:8}/g" \
            -e "s|{INTRUSION_CESIUM_LINK}|$(cesium_link "$intrusion_pub")|g" \
            -e "s/{UPLANET_G1_PUBKEY}/${UPLANETNAME_G1:0:8}/g" \
            -e "s|{UPLANET_G1_CESIUM_LINK}|$(cesium_link "${UPLANETNAME_G1:-}")|g" \
            -e "s|{myIPFS}|${myIPFS:-}|g" \
            "$template" > "$HOME/.zen/tmp/primal_alert_${MOATS:-$$}.html"

        local title="🚨 INTRUSION #${count} — ${amount} Ğ1 redirigés vers INTRUSION (${wallet_pubkey:0:8})"
        "${MY_PATH}/mailjet.sh" "$player_email" \
            "$HOME/.zen/tmp/primal_alert_${MOATS:-$$}.html" "$title" 2>/dev/null || true
        log "📧 Alerte envoyée à $player_email"
    else
        logw "Template alerte introuvable : $template"
    fi
}

# ════════════════════════════════════════════════════════════════════════════════
# FONCTION PRINCIPALE : control_primal_transactions
# ════════════════════════════════════════════════════════════════════════════════
control_primal_transactions() {
    local wallet_dunikey="$1"
    local wallet_pubkey="$2"
    local master_primal="$3"
    local player_email="$4"

    [[ -z "$wallet_dunikey" || -z "$wallet_pubkey" || \
       -z "$master_primal"  || -z "$player_email"  ]] && {
        loge "Paramètres manquants"
        echo "Usage: $0 <wallet_dunikey> <wallet_pubkey> <master_primal> <player_email>"
        return 1
    }

    [[ ! -f "$wallet_dunikey" ]] && {
        loge "Fichier dunikey introuvable : $wallet_dunikey"
        return 1
    }

    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

    # ── Conversion v1 pubkeys → SS58 (le squid indexe par SS58) ────────────
    if [[ -x "${MY_PATH}/g1pub_to_ss58.py" ]]; then
        if ! [[ "$wallet_pubkey" =~ ^g1 ]]; then
            local _ss58
            _ss58=$(python3 "${MY_PATH}/g1pub_to_ss58.py" "$wallet_pubkey" 2>/dev/null)
            if [[ -n "$_ss58" ]]; then
                log "Conversion wallet v1→SS58 : $wallet_pubkey → $_ss58"
                wallet_pubkey="$_ss58"
            fi
        fi
        if ! [[ "$master_primal" =~ ^g1 ]]; then
            local _ss58m
            _ss58m=$(python3 "${MY_PATH}/g1pub_to_ss58.py" "$master_primal" 2>/dev/null)
            if [[ -n "$_ss58m" ]]; then
                log "Conversion primal v1→SS58 : $master_primal → $_ss58m"
                master_primal="$_ss58m"
            fi
        fi
    fi

    # ── Conversion variables globales v1→SS58 ─────────────────────────────────
    local UPLANETG1PUB_SS58="${UPLANETG1PUB:-}"
    local UPLANETNAME_SOCIETY_SS58="${UPLANETNAME_SOCIETY:-}"
    local UPLANETNAME_G1_SS58="${UPLANETNAME_G1:-}"
    if [[ -x "${MY_PATH}/g1pub_to_ss58.py" ]]; then
        [[ -n "$UPLANETG1PUB_SS58" && ! "$UPLANETG1PUB_SS58" =~ ^g1 ]] && \
            UPLANETG1PUB_SS58=$(python3 "${MY_PATH}/g1pub_to_ss58.py" "$UPLANETG1PUB_SS58" 2>/dev/null)
        [[ -n "$UPLANETNAME_SOCIETY_SS58" && ! "$UPLANETNAME_SOCIETY_SS58" =~ ^g1 ]] && \
            UPLANETNAME_SOCIETY_SS58=$(python3 "${MY_PATH}/g1pub_to_ss58.py" "$UPLANETNAME_SOCIETY_SS58" 2>/dev/null)
        [[ -n "$UPLANETNAME_G1_SS58" && ! "$UPLANETNAME_G1_SS58" =~ ^g1 ]] && \
            UPLANETNAME_G1_SS58=$(python3 "${MY_PATH}/g1pub_to_ss58.py" "$UPLANETNAME_G1_SS58" 2>/dev/null)
    fi

    # ── Détection CAPTAIN ────────────────────────────────────────────────────
    local is_captain=false
    [[ "$player_email" == "${CAPTAINEMAIL:-}" ]] && {
        is_captain=true
        log "CAPTAIN détecté — sources UPLANET autorisées"
    }

    # ── Affichage wallet surveillé ───────────────────────────────────────────
    display_wallet_info "WALLET SURVEILLÉ" "$wallet_pubkey" "Wallet sous contrôle primal"
    display_wallet_info "PRIMAL MAÎTRE" "$master_primal" "Source primale attendue pour les tx valides"

    if [[ "$is_captain" == true ]]; then
        echo "Sources UPLANET autorisées pour CAPTAIN :"
        [[ -n "$UPLANETG1PUB_SS58" ]]        && echo "  UPLANET MAIN    : $UPLANETG1PUB_SS58"
        [[ -n "$UPLANETNAME_SOCIETY_SS58" ]]  && echo "  UPLANET SOCIETY : $UPLANETNAME_SOCIETY_SS58"
        [[ -n "$UPLANETNAME_G1_SS58" ]]       && echo "  UPLANET G1      : $UPLANETNAME_G1_SS58"
        echo
    fi

    # ── Récupération de l'historique ─────────────────────────────────────────
    local tmp_history
    tmp_history=$(mktemp /tmp/g1history_XXXXXX.json)
    trap "rm -f '$tmp_history'" EXIT

    if ! get_wallet_history_squid "$wallet_pubkey" "$tmp_history"; then
        loge "Impossible de récupérer l'historique"
        return 1
    fi

    local tx_count
    tx_count=$(jq 'length' "$tmp_history" 2>/dev/null || echo 0)
    if [[ "$tx_count" -eq 0 ]]; then
        log "Aucune transaction pour ce wallet."
        return 0
    fi

    # ── Compte des intrusions existantes ─────────────────────────────────────
    local existing_intrusions
    existing_intrusions=$(count_existing_intrusions "$tmp_history")
    log "Intrusions existantes (déjà traitées) : $existing_intrusions"

    # ── Boucle sur les transactions ──────────────────────────────────────────
    local new_intrusions=0
    local incoming_count=0

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local direction date pubkey amount amount_raw comment block_num
        direction=$(echo "$line"   | jq -r '.direction')
        date=$(echo "$line"        | jq -r '.date')
        pubkey=$(echo "$line"      | jq -r '.pubkey // ""')
        amount=$(echo "$line"      | jq -r '.amount')
        amount_raw=$(echo "$line"  | jq -r '.amount_raw')
        comment=$(echo "$line"     | jq -r '.comment // ""')
        block_num=$(echo "$line"   | jq -r '.blockNumber')

        # Ignorer les lignes invalides
        [[ -z "$pubkey" || "$pubkey" == "null" ]] && continue
        [[ -z "$amount" || "$amount" == "null" ]] && continue

        # Ne traiter que les entrantes
        [[ "$direction" != "in" ]] && continue

        incoming_count=$(( incoming_count + 1 ))

        log "━ TX entrante #${incoming_count} | bloc ${block_num} | ${amount} Ğ1 | de ${pubkey:0:12}..."

        # ── Exception UPassport : 2ème tx entrante à 0.01 Ğ1 ────────────────
        if [[ "$incoming_count" -eq 2 && "$amount_raw" -eq "$UPASSPORT_AMOUNT" ]]; then
            logok "🪪 UPassport détecté : 0.01 Ğ1 de ${pubkey:0:12} — 2ème TX — AUTORISÉ"

            # Cache de la 2ème tx
            local cache_2nd="$HOME/.zen/tmp/coucou/${wallet_pubkey}.2nd"
            mkdir -p "$(dirname "$cache_2nd")"
            echo "$pubkey" > "$cache_2nd"
            log "📝 2ème tx mise en cache : $cache_2nd"

            # Vérification ZEN Card
            local owner_email
            owner_email=$(get_zencard_owner "$comment" "$pubkey")
            if [[ -n "$owner_email" ]]; then
                logok "ZEN Card vérifiée pour $owner_email"
                [[ -x "${MY_PATH}/../tools/did_manager_nostr.sh" ]] && \
                    "${MY_PATH}/../tools/did_manager_nostr.sh" \
                        update "$owner_email" "WOT_MEMBER" "0" "0" "$pubkey" 2>/dev/null || true
            else
                logw "Pas de ZEN Card trouvée — utilisation email joueur"
                [[ -x "${MY_PATH}/../tools/did_manager_nostr.sh" ]] && \
                    "${MY_PATH}/../tools/did_manager_nostr.sh" \
                        update "$player_email" "WOT_MEMBER" "0" "0" "$pubkey" 2>/dev/null || true
            fi
            continue
        fi

        # ── Vérification primal via squid ─────────────────────────────────
        local tx_primal
        tx_primal=$(get_primal_source_squid "$pubkey" "true")

        if [[ -z "$tx_primal" || "$tx_primal" == "null" ]]; then
            logw "Impossible de déterminer le primal de ${pubkey:0:12} — tx ignorée"
            continue
        fi

        log "  Primal de ${pubkey:0:12} : ${tx_primal:0:12}..."
        log "  🔗 $(cesium_link "$pubkey")"

        # ── Validation : même primal que master ? ─────────────────────────
        local is_valid=false

        if [[ "$is_captain" == true ]]; then
            # CAPTAIN : accepte aussi les wallets système UPLANET directement
            [[ "$master_primal" == "$pubkey"              ]] && is_valid=true
            [[ "$pubkey" == "$UPLANETG1PUB_SS58"          ]] && is_valid=true
            [[ "$pubkey" == "$UPLANETNAME_SOCIETY_SS58"   ]] && is_valid=true
            [[ "$pubkey" == "$UPLANETNAME_G1_SS58"        ]] && is_valid=true
            [[ "$master_primal" == "$tx_primal"           ]] && is_valid=true
            [[ "$tx_primal" == "$UPLANETG1PUB_SS58"       ]] && is_valid=true
            [[ "$tx_primal" == "$UPLANETNAME_SOCIETY_SS58" ]] && is_valid=true
        else
            # Joueur normal : seul master_primal est valide
            [[ "$master_primal" == "$pubkey"    ]] && is_valid=true
            [[ "$master_primal" == "$tx_primal" ]] && is_valid=true
        fi

        if [[ "$is_valid" == true ]]; then
            logok "TX valide — primal OK : ${tx_primal:0:12}"
            continue
        fi

        # ── INTRUSION détectée ────────────────────────────────────────────
        # ID unique basé sur bloc + pubkey (immuable, reproductible)
        local tx_id
        tx_id=$(echo "${block_num}_${pubkey:0:12}" | tr -d ':-. ')

        if is_intrusion_already_processed "$tmp_history" "$tx_id"; then
            log "Intrusion déjà traitée (ID: $tx_id) — skip"
            continue
        fi

        local current_total=$(( existing_intrusions + new_intrusions + 1 ))
        local intrusion_comment="UPLANET:${UPLANETG1PUB:0:8}:INTRUSION:${pubkey:0:8}:ID:${tx_id}"

        echo -e "${RED}🚨 INTRUSION #${current_total} détectée !${RESET}"
        echo "   Expéditeur : $pubkey"
        echo "   Primal exp : $tx_primal"
        echo "   Primal att : $master_primal"
        echo "   Montant    : ${amount} Ğ1"
        echo "   Bloc       : $block_num"
        echo "   ID tx      : $tx_id"

        # Créer le wallet INTRUSION si nécessaire
        if ! create_intrusion_wallet; then
            loge "Impossible de créer le wallet INTRUSION — abandon"
            continue
        fi

        local intrusion_pub
        intrusion_pub=$(get_intrusion_pubkey)
        if [[ -z "$intrusion_pub" ]]; then
            loge "Impossible de lire la clé du wallet INTRUSION"
            continue
        fi

        log "🔗 Wallet INTRUSION : $(cesium_link "$intrusion_pub")"

        # ── Redirection vers INTRUSION ────────────────────────────────────
        if "${MY_PATH}/PAYforSURE.sh" \
            "$wallet_dunikey" \
            "$amount" \
            "$intrusion_pub" \
            "$intrusion_comment" \
            "$MOATS" \
            2>/dev/null; then

            logok "Intrusion redirigée : ${amount} Ğ1 → INTRUSION (${intrusion_pub:0:12})"
            new_intrusions=$(( new_intrusions + 1 ))

            send_redirection_alert \
                "$player_email" "$wallet_pubkey" "$pubkey" \
                "$tx_primal"    "$amount"        "$master_primal" \
                "$current_total" "$intrusion_pub"
        else
            loge "Échec de la redirection de l'intrusion (ID: $tx_id)"
        fi

    done < <(jq -c '.[]' "$tmp_history")

    # ── Rapport final ─────────────────────────────────────────────────────────
    local total_intrusions=$(( existing_intrusions + new_intrusions ))
    echo
    sep2
    echo "📊 RAPPORT CONTRÔLE PRIMAL"
    sep2
    echo "👤 Joueur          : $player_email"
    echo "📅 Date            : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "🔢 TX entrantes    : $incoming_count"
    echo "🔢 Intrusions exist: $existing_intrusions"
    echo "🆕 Nouvelles intrus: $new_intrusions"
    echo "📊 Total intrusions: $total_intrusions"
    echo

    if [[ "$new_intrusions" -gt 0 ]]; then
        echo -e "${RED}🚨 $new_intrusions NOUVELLE(S) INTRUSION(S) DÉTECTÉE(S) ET REDIRIGÉE(S)${RESET}"
        local ipub
        ipub=$(get_intrusion_pubkey 2>/dev/null)
        [[ -n "$ipub" ]] && \
            display_wallet_info "WALLET INTRUSION" "$ipub" "Fonds intrusifs centralisés ici"
    else
        logok "Aucune nouvelle intrusion — wallet sécurisé"
    fi
    sep2

    return 0
}

# ── Point d'entrée ────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 4 ]]; then
        cat << EOF
Usage: $0 <wallet_dunikey> <wallet_pubkey> <master_primal> <player_email>

Paramètres :
  wallet_dunikey   Chemin vers le fichier dunikey du wallet à surveiller
  wallet_pubkey    Adresse publique g1... du wallet
  master_primal    Source primale attendue (primal du wallet légitime)
  player_email     Email du joueur (alertes + logs)

Variables d'environnement :
  SQUID_URL        Endpoint GraphQL squid  (défaut: squid.g1.gyroi.de)
  GCLI_PASSWORD    Mot de passe vault g1cli (évite le prompt interactif)
  G1_WS_NODE       Nœud WebSocket principal
  UPLANETG1PUB     Pubkey UPlanet principale
  CAPTAINEMAIL     Email du capitaine

Exemple :
  $0 ~/.zen/game/players/alice/secret.dunikey \\
     g1ABC...XYZ \\
     g1PRIMAL...XYZ \\
     alice@example.com
EOF
        exit 1
    fi

    control_primal_transactions "$@"
fi
