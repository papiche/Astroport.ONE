#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com) — réécriture v2 pour g1cli (Duniter v2s)
# Version: 2.0
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# PAYforSURE.sh
# Effectue un paiement Ğ1 via g1cli (Duniter v2s / Substrate)
# avec vérification du solde, retry multi-nœuds, et rapport HTML
#
# Usage: PAYforSURE.sh <keyfile|vault_name> <amount> <g1pub> [comment] [moats]
#
# <keyfile|vault_name> :
#   - Chemin vers un fichier dunikey v1 (id/secret) → importé en vault éphémère
#   - OU nom d'entrée vault gcli (ex: "poka", "player@example.com")
#
# Variables d'environnement utilisées (depuis my.sh) :
#   GCLI           : chemin vers le binaire gcli (défaut: gcli dans $PATH)
#   G1_WS_NODE     : nœud WebSocket principal (ex: wss://g1.p2p.legal/ws)
#   UPLANETG1PUB   : pubkey UPlanet (pour commentaire par défaut)
#   CAPTAINEMAIL   : email du capitaine (pour rapport)
#   CESIUMIPFS     : base URL Cesium (pour liens HTML)
################################################################################
# set -euo pipefail

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
ME="${0##*/}"

[[ -f "${MY_PATH}/my.sh" ]] && . "${MY_PATH}/my.sh"

# ── Configuration ─────────────────────────────────────────────────────────────
GCLI="${GCLI:-gcli}"
DECIMALS=2   # 1 Ğ1 = 100 centimes en brut (confirmé: amount=1 → 0.01 Ğ1)

# Nœuds WebSocket — peuplés dynamiquement via duniter_getnode.sh si disponible
# gcli utilise -u <URL> pour le nœud RPC
G1_WS_NODES=()
if [[ -x "${MY_PATH}/duniter_getnode.sh" ]]; then
    # Récupère les N meilleurs nœuds RPC depuis le cache / découverte
    while IFS= read -r node; do
        [[ -n "$node" ]] && G1_WS_NODES+=("$node")
    done < <("${MY_PATH}/duniter_getnode.sh" all 2>/dev/null | jq -r '.rpc[0:3][].url' 2>/dev/null)
fi
# Fallback hardcodé si duniter_getnode.sh absent ou cache vide
if [[ "${#G1_WS_NODES[@]}" -eq 0 ]]; then
    G1_WS_NODES=(
        "${G1_WS_NODE:-wss://g1.p2p.legal/ws}"
        "wss://duniter.g1.coinduf.eu/ws"
        "wss://g1.duniter.fr/ws"
    )
fi

# ── Couleurs ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ── Logging ───────────────────────────────────────────────────────────────────
log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
loge() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] $*${RESET}" >&2; }
logw() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] $*${RESET}"; }
logok(){ echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $*${RESET}"; }

# ── Prérequis ─────────────────────────────────────────────────────────────────
for cmd in gcli jq curl bc; do
    command -v "$cmd" &>/dev/null || { loge "Commande requise manquante : $cmd"; exit 1; }
done

# ── Arguments ─────────────────────────────────────────────────────────────────
if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <keyfile|vault_name> <amount> <g1pub> [comment] [moats]"
    exit 1
fi

KEY_OR_VAULT="$1"   # fichier dunikey OU nom vault gcli
AMOUNT="$2"
G1PUB="$3"
COMMENT="${4:-}"
MOATS="${5:-}"

[[ -z "$MOATS" ]] \
    && MOATS=$(date -u +"%Y%m%d%H%M%S%4N") \
    || log "Reprise de paiement échoué — ID: $MOATS"

# ── Conversion v1 pubkey → SS58 pour l'adresse de destination ───────────────
# gcli exige une adresse SS58 (préfixe g1...), pas une pubkey v1 base58
if [[ -n "$G1PUB" ]] && ! [[ "$G1PUB" =~ ^g1 ]]; then
    if [[ -x "${MY_PATH}/g1pub_to_ss58.py" ]]; then
        _SS58=$(python3 "${MY_PATH}/g1pub_to_ss58.py" "$G1PUB" 2>/dev/null)
        if [[ -n "$_SS58" ]]; then
            log "Conversion DEST v1→SS58 : $G1PUB → $_SS58"
            G1PUB="$_SS58"
        fi
    fi
fi

log "=== PAYforSURE démarrage ==="
log "DEST   : $G1PUB"
log "AMOUNT : $AMOUNT"
log "MOATS  : $MOATS"

# ── Montant nul ───────────────────────────────────────────────────────────────
# Ne pas évaluer avec bc si AMOUNT est un mot-clé (ALL, DRAIN)
if [[ "$AMOUNT" != "ALL" && "$AMOUNT" != "DRAIN" ]]; then
    if (( $(echo "${AMOUNT} == 0" | bc -l) )); then
        log "Montant nul, rien à payer."
        exit 0
    fi
fi

# ── Validation montant ────────────────────────────────────────────────────────
if ! [[ "$AMOUNT" =~ ^[0-9]+([.][0-9]+)?$|^ALL$|^DRAIN$ ]]; then
    loge "Montant invalide : $AMOUNT"
    exit 1
fi

# ── Résoudre l'identité vault / keyfile ───────────────────────────────────────
# Si KEY_OR_VAULT est un fichier existant → on l'importe de façon éphémère dans le vault
# Sinon → c'est un nom vault gcli existant

VAULT_NAME=""
VAULT_ADDRESS=""
TEMP_VAULT_IMPORTED=false

resolve_vault() {
    if [[ -f "$KEY_OR_VAULT" ]]; then
        log "Fichier dunikey détecté : $KEY_OR_VAULT"

        # Nom vault temporaire basé sur MOATS
        VAULT_NAME="paytemp_${MOATS}"

        # Nettoyer les entrées paytemp_* résiduelles pour éviter le prompt
        # interactif "Do you want to: 1. keep 2. overwrite" quand la même
        # adresse SS58 est déjà dans le vault
        $GCLI --no-password vault list all 2>/dev/null \
            | grep -oP 'paytemp_\S+' \
            | while read -r old_name; do
                $GCLI --no-password vault remove -v "$old_name" 2>/dev/null || true
            done

        # Déterminer le format du fichier et la méthode d'import
        local sec_key
        sec_key=$(grep -E '^sec:' "$KEY_OR_VAULT" | head -1 | awk '{print $2}')

        if [[ -n "$sec_key" ]]; then
            # Format PubSec (Type: PubSec) — contient clé ed25519 brute en base58
            # Extraire la seed (32 premiers bytes de la clé secrète)
            local seed_hex
            seed_hex=$(python3 -c "
import base58, sys
try:
    sec = base58.b58decode('$sec_key')
    print(sec[:32].hex())
except Exception as e:
    print('', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null)

            if [[ -n "$seed_hex" ]]; then
                log "Import dunikey PubSec (seed ed25519) sous le nom : $VAULT_NAME"
                $GCLI vault import -S substrate \
                    --uri "0x${seed_hex}" \
                    --no-password \
                    -n "$VAULT_NAME" \
                    2>/dev/null
                TEMP_VAULT_IMPORTED=true
                return 0
            fi
        fi

        # Fallback : format JSON cesium v1 {"salt":"...","password":"..."} ou {"pub":"...","sec":"..."}
        local id secret
        id=$(jq -r '.salt // .pub // .uid // empty' "$KEY_OR_VAULT" 2>/dev/null)
        secret=$(jq -r '.password // .sec // empty' "$KEY_OR_VAULT" 2>/dev/null)

        if [[ -n "$id" && -n "$secret" ]]; then
            log "Import dunikey g1v1 (salt/password) sous le nom : $VAULT_NAME"
            $GCLI vault import -S g1v1 \
                --g1v1-id "$id" \
                --g1v1-password "$secret" \
                --no-password \
                -n "$VAULT_NAME" \
                2>/dev/null
            TEMP_VAULT_IMPORTED=true
            return 0
        fi

        loge "Impossible d'extraire les clés depuis $KEY_OR_VAULT"
        return 1
    else
        # C'est un nom vault ou une adresse directe
        VAULT_NAME="$KEY_OR_VAULT"
        log "Utilisation du vault gcli : $VAULT_NAME"
        return 0
    fi
}

cleanup_temp_vault() {
    if [[ "$TEMP_VAULT_IMPORTED" == true && -n "$VAULT_NAME" ]]; then
        log "Suppression entrée vault temporaire : $VAULT_NAME"
        $GCLI --no-password vault remove -v "$VAULT_NAME" 2>/dev/null || true
    fi
}
trap cleanup_temp_vault EXIT

resolve_vault || exit 1

# ── Récupérer l'adresse publique depuis le vault ──────────────────────────────
get_address_from_vault() {
    local name="$1"
    # gcli --no-password -v "<name>" account balance → affiche l'adresse
    $GCLI --no-password -u "${G1_WS_NODES[0]:-wss://g1.1000i100.fr/ws}" -v "$name" account balance 2>/dev/null \
        | grep -oE 'g1[A-Za-z0-9]{40,}' | head -1
}

# Méthode directe : extraire la pub du dunikey et convertir en SS58
get_address_from_dunikey() {
    local keyfile="$1"
    local pub_v1
    pub_v1=$(grep -E '^pub:' "$keyfile" | head -1 | awk '{print $2}')
    if [[ -n "$pub_v1" && -x "${MY_PATH}/g1pub_to_ss58.py" ]]; then
        python3 "${MY_PATH}/g1pub_to_ss58.py" "$pub_v1" 2>/dev/null
    fi
}

ISSUERPUB=""

# 1. Si dunikey → extraire l'adresse SS58 directement (pas besoin du squid)
if [[ -f "$KEY_OR_VAULT" ]]; then
    ISSUERPUB=$(get_address_from_dunikey "$KEY_OR_VAULT")
    [[ -n "$ISSUERPUB" ]] && log "Adresse SS58 (depuis dunikey) : $ISSUERPUB"
fi

# 2. Fallback : interroger le vault gcli
if [[ -z "$ISSUERPUB" ]]; then
    ISSUERPUB=$(get_address_from_vault "$VAULT_NAME")
fi

# 3. Dernier recours : si c'est déjà une adresse g1
if [[ -z "$ISSUERPUB" ]]; then
    if [[ "$VAULT_NAME" =~ ^g1 ]]; then
        ISSUERPUB="$VAULT_NAME"
    else
        loge "Impossible de déterminer l'adresse publique depuis : $VAULT_NAME"
        exit 1
    fi
fi
log "Adresse émettrice : $ISSUERPUB"

# ── Récupérer le solde via gcli (Duniter RPC — source de vérité on-chain) ─────
get_balance_gcli() {
    local addr="$1"
    local raw
    # Essayer chaque noeud RPC disponible
    for rpc in "${G1_WS_NODES[@]}"; do
        raw=$($GCLI --no-password -a "$addr" -u "$rpc" -o json account balance 2>/dev/null \
            | jq -r '.transferable_balance // empty')
        if [[ -n "$raw" && "$raw" != "null" ]]; then
            echo "scale=2; ${raw} / 100" | bc
            return 0
        fi
    done
    echo "0"
    return 1
}

log "Récupération du solde via Duniter RPC..."
COINS=$(get_balance_gcli "$ISSUERPUB")
log "Solde de $ISSUERPUB : ${COINS} Ğ1"

if [[ -z "$COINS" || "$COINS" == "0" || "$COINS" == ".0000" ]]; then
    if [[ "$AMOUNT" != "DRAIN" ]]; then
        loge "Portefeuille vide ou introuvable : $ISSUERPUB"
        exit 1
    fi
    # Pour DRAIN : transferable_balance peut être 0 (seul l'existential deposit reste)
    # On continue — total_balance sera récupéré dans le bloc DRAIN ci-dessous
    logw "Solde transférable nul — DRAIN tentera de vider via total_balance (existential deposit)"
    COINS="0"
fi

# ── ALL = transférable / DRAIN = tout (y compris 1 Ğ1 existential deposit) ────
if [[ "$AMOUNT" == "DRAIN" ]]; then
    # Récupérer total_balance pour vider entièrement le wallet
    TOTAL_COINS=""
    for rpc in "${G1_WS_NODES[@]}"; do
        raw=$($GCLI --no-password -a "$ISSUERPUB" -u "$rpc" -o json account balance 2>/dev/null \
            | jq -r '.total_balance // empty')
        if [[ -n "$raw" && "$raw" != "null" ]]; then
            TOTAL_COINS=$(echo "scale=2; ${raw} / 100" | bc)
            break
        fi
    done
    if [[ -z "$TOTAL_COINS" || "$TOTAL_COINS" == "0" ]]; then
        loge "Impossible de récupérer le total_balance pour DRAIN"
        exit 1
    fi
    log "DRAIN : vidage total du wallet (${TOTAL_COINS} Ğ1 incluant 1 Ğ1 existential deposit)"
    AMOUNT="$TOTAL_COINS"
elif [[ "$AMOUNT" == "ALL" ]]; then
    AMOUNT="$COINS"
fi

# ── Vérifier le solde suffisant ───────────────────────────────────────────────
if (( $(echo "$COINS < $AMOUNT" | bc -l) )); then
    loge "Solde insuffisant : $COINS Ğ1 < $AMOUNT Ğ1 demandés"
    exit 1
fi

# ── Commentaire par défaut ────────────────────────────────────────────────────
[[ -z "$COMMENT" ]] && \
    COMMENT="UPLANET${UPLANETG1PUB:0:8}:ZEN:${ISSUERPUB:0:8}->${G1PUB:0:8}"

log "Commentaire : $COMMENT"

# ── Répertoire de travail ─────────────────────────────────────────────────────
PENDINGDIR="$HOME/.zen/tmp/${ISSUERPUB}"
mkdir -p "$PENDINGDIR"

# ── Fonction de paiement via g1cli ────────────────────────────────────────────
make_payment_gcli() {
    local vault_name="$1"
    local amount="$2"
    local dest="$3"
    local comment="$4"
    local ws_node="$5"
    local result_file="$6"

    log "Tentative paiement g1cli → nœud: ${ws_node:-défaut} | ${amount} Ğ1 → ${dest:0:12}..."

    # Syntaxe g1cli v0.8.0+ :
    #   gcli --no-password [-u <wss://...>] -v "<vault_name>" \
    #        account transfer <AMOUNT> <ADDRESS> [--comment "msg"] [--onchain]
    #
    # --comment  : crée un batch atomique (transfer + system.remark ou remark_with_event)
    # --onchain  : utilise system.remark_with_event → émet l'événement Remarked
    #              → inscrit le commentaire dans Duniter (immuable, audit légal)
    #              → indexé par le squid Duniter (visible UX Cesium/explorateurs)
    # Sans --onchain : system.remark → dans la tx blockchain mais pas indexé
    #
    # Pour les paiements officiels UPlanet, --onchain est OBLIGATOIRE
    # afin de garantir la traçabilité légale et la visibilité dans Cesium.

    local base_opts=(--no-password)
    [[ -n "$ws_node" ]] && base_opts+=(-u "$ws_node")

    local transfer_opts=()
    if [[ -n "$comment" ]]; then
        transfer_opts+=(--comment "$comment")
        # --onchain : inscription immuable dans Duniter + indexation squid pour UX
        transfer_opts+=(--onchain)
    fi

    local transfer_rc
    $GCLI "${base_opts[@]}" \
        -v "$vault_name" \
        account transfer "$amount" "$dest" "${transfer_opts[@]}" \
        > "$result_file" 2>&1
    transfer_rc=$?

    return $transfer_rc
}

# ── Conversion montant Ğ1 → centimes pour gcli ─────────────────────────────
# gcli utilise des centimes : 100 = 1.00 Ğ1 (DECIMALS=2)
AMOUNT_GCLI=$(python3 -c "print(int(round(float('$AMOUNT') * 10**$DECIMALS)))" 2>/dev/null)
if [[ -z "$AMOUNT_GCLI" || "$AMOUNT_GCLI" == "0" ]]; then
    loge "Conversion montant échouée : $AMOUNT Ğ1 → centimes"
    exit 1
fi
log "Montant gcli : $AMOUNT Ğ1 = $AMOUNT_GCLI centimes"

# ── Boucle retry sur les nœuds ────────────────────────────────────────────────
RESULT_FILE="${PENDINGDIR}/${MOATS}.result.txt"
ISOK=1

try_all_nodes() {
    local nodes=("$@")
    for ws_node in "${nodes[@]}"; do
        make_payment_gcli \
            "$VAULT_NAME" "$AMOUNT_GCLI" "$G1PUB" "$COMMENT" \
            "$ws_node" "$RESULT_FILE"
        ISOK=$?

        # gcli retourne 0 même en cas d'erreur on-chain — vérifier le résultat
        if [[ $ISOK -eq 0 ]] && grep -q "error\|Error\|failed\|cannot exist" "$RESULT_FILE" 2>/dev/null; then
            logw "gcli exit 0 mais erreur détectée dans le résultat"
            ISOK=1
        fi

        [[ $ISOK -eq 0 ]] && { logok "Paiement réussi via $ws_node"; return 0; }
        logw "Échec sur $ws_node, essai suivant..."
        sleep 2
    done
    return 1
}

# Premier essai avec les nœuds du cache
try_all_nodes "${G1_WS_NODES[@]}"

# Si échec total → forcer un refresh et réessayer avec les nouveaux nœuds
if [[ $ISOK -ne 0 && -x "${MY_PATH}/duniter_getnode.sh" ]]; then
    logw "Tous les nœuds ont échoué — rafraîchissement forcé de la liste..."
    "${MY_PATH}/duniter_getnode.sh" refresh >/dev/null 2>&1

    # Recharger les nœuds depuis le cache rafraîchi
    G1_WS_NODES_FRESH=()
    while IFS= read -r node; do
        [[ -n "$node" ]] && G1_WS_NODES_FRESH+=("$node")
    done < <("${MY_PATH}/duniter_getnode.sh" all 2>/dev/null | jq -r '.rpc[].url' 2>/dev/null)

    if [[ "${#G1_WS_NODES_FRESH[@]}" -gt 0 ]]; then
        log "Retry avec ${#G1_WS_NODES_FRESH[@]} nœuds frais"
        try_all_nodes "${G1_WS_NODES_FRESH[@]}"
    fi
fi

if [[ $ISOK -ne 0 ]]; then
    loge "Paiement échoué sur tous les nœuds (y compris après refresh)"
    cat "$RESULT_FILE" 2>/dev/null
    exit 1
fi

logok "=== TRANSACTION ENVOYÉE ==="

# ── Vérification blockchain (Duniter v2 : 1 bloc = 6s) ──────────────────────
log "Vérification confirmation blockchain..."
CONFIRMED="false"
for _try in 1 2 3 4 5; do
    sleep 6
    _dest_raw=$($GCLI --no-password -a "$G1PUB" -u "${G1_WS_NODES[0]}" -o json account balance 2>/dev/null \
        | jq -r '.total_balance // empty')
    if [[ -n "$_dest_raw" && "$_dest_raw" != "null" && "$_dest_raw" != "0" ]]; then
        _dest_g1=$(echo "scale=2; ${_dest_raw} / 100" | bc)
        logok "Confirmation blockchain: ${_dest_g1} Ğ1 sur ${G1PUB:0:12}..."
        CONFIRMED="true"
        break
    fi
    log "Attente bloc ${_try}/5..."
done
if [[ "$CONFIRMED" != "true" ]]; then
    loge "Pas de confirmation après 30s — la transaction n'a pas été confirmée sur la blockchain"
    exit 1
fi

# ── Mise à jour du cache de solde ─────────────────────────────────────────────
COUCOU="$HOME/.zen/tmp/coucou"
mkdir -p "$COUCOU"

COINSFILE="$COUCOU/${ISSUERPUB}.COINS"
DESTFILE="$COUCOU/${G1PUB}.COINS"

echo "$COINS - $AMOUNT" | bc > "$COINSFILE"

DES=$(cat "$DESTFILE" 2>/dev/null || echo "0")
[[ -z "$DES" || "$DES" == "null" ]] && DES="0"
echo "$DES + $AMOUNT" | bc > "$DESTFILE"

# ── Conversions ZEN ───────────────────────────────────────────────────────────
ZENAMOUNT=$(echo "$AMOUNT * 100" | awk '{printf "%.1f", $1}')
ZENCUR=$(echo "($COINS - $AMOUNT) * 10" | bc | awk '{printf "%.1f", $1}')
ZENDES=$(echo "($DES + $AMOUNT) * 10" | bc | awk '{printf "%.1f", $1}')

# ── Rapport HTML ──────────────────────────────────────────────────────────────
HTML_FILE="${PENDINGDIR}/${MOATS}.result.html"
TIMESTAMP=$(date '+%d/%m/%Y à %H:%M:%S')
CESIUM="${CESIUMIPFS:-https://cesium.copylaradio.com}"

cat > "$HTML_FILE" << HTMLEOF
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Transaction ZEN — ${COMMENT}</title>
<style>
  *{margin:0;padding:0;box-sizing:border-box}
  body{font-family:'Segoe UI',sans-serif;background:linear-gradient(135deg,#667eea,#764ba2);
       min-height:100vh;padding:20px;color:#333}
  .box{max-width:800px;margin:auto;background:#fff;border-radius:20px;
       box-shadow:0 20px 40px rgba(0,0,0,.1);overflow:hidden}
  .head{background:linear-gradient(135deg,#4facfe,#00f2fe);color:#fff;
        padding:30px;text-align:center}
  .head h1{font-size:2.2em;text-shadow:0 2px 4px rgba(0,0,0,.3)}
  .body{padding:40px}
  .badge{display:inline-block;padding:8px 16px;background:#51cf66;color:#fff;
         border-radius:20px;font-weight:bold;margin-bottom:20px}
  .amount{text-align:center;margin:20px 0}
  .amount .val{font-size:3em;font-weight:bold;color:#4facfe}
  .comment{background:#e3f2fd;border-radius:10px;padding:15px;margin:15px 0;
           border-left:4px solid #4facfe;font-style:italic;color:#1976d2}
  .flow{display:flex;align-items:center;justify-content:space-between;
        flex-wrap:wrap;gap:20px;margin:20px 0}
  .card{flex:1;min-width:240px;border-radius:15px;padding:20px;
        box-shadow:0 5px 15px rgba(0,0,0,.1);border:2px solid #e9ecef}
  .card.src{border-color:#ff6b6b}
  .card.dst{border-color:#51cf66}
  .label{font-size:.85em;color:#666;text-transform:uppercase;letter-spacing:1px;
         margin-bottom:8px}
  .addr{font-family:monospace;font-size:.85em;word-break:break-all;
        background:#f8f9fa;padding:8px;border-radius:6px;margin-bottom:10px}
  .bal{font-size:1.4em;font-weight:bold;color:#4facfe}
  .arrow{font-size:2em;color:#4facfe}
  .links a{display:inline-block;margin:4px 4px 0 0;padding:7px 14px;
           background:#4facfe;color:#fff;border-radius:20px;font-size:.85em;
           text-decoration:none}
  .links a.sec{background:#6c757d}
  .foot{background:#f8f9fa;padding:15px;text-align:center;color:#666;font-size:.85em}
</style>
</head>
<body>
<div class="box">
  <div class="head"><h1>🚀 Transaction ZEN</h1><p>Opération blockchain Duniter v2 réussie</p></div>
  <div class="body">
    <span class="badge">✅ Transaction confirmée</span>
    <div class="amount"><div class="val">${ZENAMOUNT}</div><div>ZEN</div></div>
    <div class="comment"><strong>Référence :</strong> ${COMMENT}</div>
    <div class="flow">
      <div class="card src">
        <div class="label">💰 Source</div>
        <div class="addr">${ISSUERPUB}</div>
        <div class="bal">${ZENCUR} ZEN</div>
        <div class="links">
          <a href="${CESIUM}/#/wot/tx/${ISSUERPUB}/" target="_blank">📊 Cesium</a>
        </div>
      </div>
      <div class="arrow">➡️</div>
      <div class="card dst">
        <div class="label">🎯 Destination</div>
        <div class="addr">${G1PUB}</div>
        <div class="bal">${ZENDES} ZEN</div>
        <div class="links">
          <a href="${CESIUM}/#/wot/tx/${G1PUB}/" target="_blank">📊 Cesium</a>
        </div>
      </div>
    </div>
  </div>
  <div class="foot">
    <p>Transaction traitée le ${TIMESTAMP}</p>
    <p>ID : ${MOATS} | Nœud v2 : Duniter v2s / Substrate</p>
  </div>
</div>
</body>
</html>
HTMLEOF

logok "Rapport HTML : $HTML_FILE"

# ── Notification email ────────────────────────────────────────────────────────
if [[ -n "${CAPTAINEMAIL:-}" ]] && [[ -x "${MY_PATH}/mailjet.sh" ]]; then
    "${MY_PATH}/mailjet.sh" --expire 48h "$CAPTAINEMAIL" \
        "$HTML_FILE" "${ZENAMOUNT} ZEN : ${COMMENT}" 2>/dev/null || true
fi

exit 0
