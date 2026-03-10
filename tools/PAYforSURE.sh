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
#   GCLI_PASSWORD  : (obsolète depuis --no-password) mot de passe vault gcli
#   SQUID_URL      : endpoint GraphQL squid pour vérification solde
#   G1_WS_NODE     : nœud WebSocket principal (ex: wss://g1.p2p.legal/ws)
#   UPLANETG1PUB   : pubkey UPlanet (pour commentaire par défaut)
#   CAPTAINEMAIL   : email du capitaine (pour rapport)
#   CESIUMIPFS     : base URL Cesium (pour liens HTML)
#   myUPLANET      : URL UPlanet locale
################################################################################
# set -euo pipefail

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
ME="${0##*/}"

[[ -f "${MY_PATH}/my.sh" ]] && . "${MY_PATH}/my.sh"

# ── Configuration ─────────────────────────────────────────────────────────────
GCLI="${GCLI:-gcli}"
SQUID_URL="${SQUID_URL:-https://squid.g1.gyroi.de/v1/graphql}"
DECIMALS=2   # 1 Ğ1 = 100 centimes en brut (confirmé: amount=1 → 0.01 Ğ1)

# Nœuds WebSocket — peuplés dynamiquement via duniter_getnode.sh si disponible
# gcli utilise -u <URL> pour le nœud et -i <INDEXER> pour le squid
G1_WS_NODES=()
if [[ -x "${MY_PATH}/duniter_getnode.sh" ]]; then
    # Récupère les N meilleurs nœuds RPC depuis le cache / découverte
    while IFS= read -r node; do
        [[ -n "$node" ]] && G1_WS_NODES+=("$node")
    done < <("${MY_PATH}/duniter_getnode.sh" all 2>/dev/null               | jq -r '.rpc[0:3][].url' 2>/dev/null)
    # Mise à jour du squid depuis le cache aussi
    _best_squid=$("${MY_PATH}/duniter_getnode.sh" squid 2>/dev/null)
    [[ -n "$_best_squid" ]] && SQUID_URL="$_best_squid"
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

log "=== PAYforSURE démarrage ==="
log "DEST   : $G1PUB"
log "AMOUNT : $AMOUNT"
log "MOATS  : $MOATS"

# ── Montant nul ───────────────────────────────────────────────────────────────
if (( $(echo "${AMOUNT} == 0" | bc -l) )); then
    log "Montant nul, rien à payer."
    exit 0
fi

# ── Validation montant ────────────────────────────────────────────────────────
if ! [[ "$AMOUNT" =~ ^[0-9]+([.][0-9]+)?$|^ALL$ ]]; then
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
        # Fichier dunikey v1 (id/secret format)
        log "Fichier dunikey détecté : $KEY_OR_VAULT"

        # Extraire id/secret depuis le dunikey
        local id secret
        id=$(grep -E '^uid:|^pub:' "$KEY_OR_VAULT" | head -1 | awk '{print $2}')
        secret=$(grep -E '^sec:|^sec:|^salt:|^password:' "$KEY_OR_VAULT" | head -1 | awk '{print $2}')

        # Fallback : format JSON {"pub":"...","sec":"..."}
        if [[ -z "$id" ]]; then
            id=$(jq -r '.pub // .uid // empty' "$KEY_OR_VAULT" 2>/dev/null)
            secret=$(jq -r '.sec // .salt // empty' "$KEY_OR_VAULT" 2>/dev/null)
        fi

        # Fallback : format cesium v1 {"salt":"...","password":"..."}
        if [[ -z "$id" ]]; then
            id=$(jq -r '.salt // empty' "$KEY_OR_VAULT" 2>/dev/null)
            secret=$(jq -r '.password // empty' "$KEY_OR_VAULT" 2>/dev/null)
        fi

        if [[ -z "$id" || -z "$secret" ]]; then
            loge "Impossible d'extraire id/secret depuis $KEY_OR_VAULT"
            return 1
        fi

        # Nom vault temporaire basé sur MOATS
        VAULT_NAME="paytemp_${MOATS}"

        log "Import dunikey g1v1 dans vault gcli sous le nom : $VAULT_NAME"
        # g1cli v0.8.0+ : import non-interactif avec --g1v1-id/--g1v1-password/--no-password
        $GCLI vault import -S g1v1 \
            --g1v1-id "$id" \
            --g1v1-password "$secret" \
            --no-password \
            -n "$VAULT_NAME" \
            2>/dev/null

        TEMP_VAULT_IMPORTED=true
        return 0
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
        $GCLI vault remove "$VAULT_NAME" 2>/dev/null || true
    fi
}
trap cleanup_temp_vault EXIT

resolve_vault || exit 1

# ── Récupérer l'adresse publique depuis le vault ──────────────────────────────
get_address_from_vault() {
    local name="$1"
    # gcli --no-password -v "<name>" account balance → affiche l'adresse
    $GCLI --no-password -i "$SQUID_URL" -v "$name" account balance 2>/dev/null \
        | grep -oE 'g1[A-Za-z0-9]{40,}' | head -1
}

ISSUERPUB=$(get_address_from_vault "$VAULT_NAME")
if [[ -z "$ISSUERPUB" ]]; then
    # Tentative directe avec -a si c'est une adresse
    if [[ "$VAULT_NAME" =~ ^g1 ]]; then
        ISSUERPUB="$VAULT_NAME"
    else
        loge "Impossible de déterminer l'adresse publique depuis : $VAULT_NAME"
        exit 1
    fi
fi
log "Adresse émettrice : $ISSUERPUB"

# ── Récupérer le solde via squid ──────────────────────────────────────────────
get_balance_squid() {
    local addr="$1"
    local query
    query=$(jq -cn --arg a "$addr" '{
        query: "query($a:String!){accounts(condition:{id:$a}){nodes{balance}}}",
        variables: {a: $a}
    }')
    local raw
    raw=$(curl -sf -X POST -H "Content-Type: application/json" \
        --data "$query" "$SQUID_URL" 2>/dev/null \
        | jq -r '.data.accounts.nodes[0].balance // "0"')
    # Convertir BigInt → Ğ1 flottant
    echo "scale=4; ${raw:-0} / $(python3 -c "print(10**$DECIMALS)" 2>/dev/null || echo 100)" | bc
}

log "Récupération du solde via squid..."
COINS=$(get_balance_squid "$ISSUERPUB")
log "Solde de $ISSUERPUB : ${COINS} Ğ1"

if [[ -z "$COINS" || "$COINS" == "0" || "$COINS" == ".0000" ]]; then
    loge "Portefeuille vide ou introuvable : $ISSUERPUB"
    exit 1
fi

# ── ALL = vider le wallet ─────────────────────────────────────────────────────
[[ "$AMOUNT" == "ALL" ]] && AMOUNT="$COINS"

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
    #   gcli --no-password [-u <wss://...>] [-i <squid_url>] -v "<vault_name>" \
    #        account transfer <AMOUNT> <ADDRESS> [--comment "msg"]
    # Le --comment crée un batch atomique (transfer + system.remark) on-chain

    local base_opts=(--no-password)
    [[ -n "$ws_node" ]] && base_opts+=(-u "$ws_node")
    [[ -n "$SQUID_URL" ]] && base_opts+=(-i "$SQUID_URL")

    local transfer_opts=()
    [[ -n "$comment" ]] && transfer_opts+=(--comment "$comment")

    local transfer_rc
    $GCLI "${base_opts[@]}" \
        -v "$vault_name" \
        account transfer "$amount" "$dest" "${transfer_opts[@]}" \
        > "$result_file" 2>&1
    transfer_rc=$?

    return $transfer_rc
}

# ── Boucle retry sur les nœuds ────────────────────────────────────────────────
RESULT_FILE="${PENDINGDIR}/${MOATS}.result.txt"
ISOK=1

for ws_node in "${G1_WS_NODES[@]}"; do
    make_payment_gcli \
        "$VAULT_NAME" "$AMOUNT" "$G1PUB" "$COMMENT" \
        "$ws_node" "$RESULT_FILE"
    ISOK=$?
    [[ $ISOK -eq 0 ]] && { logok "Paiement réussi via $ws_node"; break; }
    logw "Échec sur $ws_node, essai suivant..."
    sleep 2
done

if [[ $ISOK -ne 0 ]]; then
    loge "Paiement échoué sur tous les nœuds"
    cat "$RESULT_FILE" 2>/dev/null
    exit 1
fi

logok "=== TRANSACTION ENVOYÉE ==="

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
ZENAMOUNT=$(echo "scale=1; $AMOUNT * 10" | bc)
ZENCUR=$(echo "scale=1; ($COINS - $AMOUNT) * 10" | bc)
ZENDES=$(echo "scale=1; ($DES + $AMOUNT) * 10" | bc)

# ── Rapport HTML ──────────────────────────────────────────────────────────────
HTML_FILE="${PENDINGDIR}/${MOATS}.result.html"
TIMESTAMP=$(date '+%d/%m/%Y à %H:%M:%S')
CESIUM="${CESIUMIPFS:-https://cesium.app}"
UPLANET="${myUPLANET:-}"

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
    <span class="badge">✅ Transaction soumise</span>
    <div class="amount"><div class="val">${ZENAMOUNT}</div><div>ZEN</div></div>
    <div class="comment"><strong>Référence :</strong> ${COMMENT}</div>
    <div class="flow">
      <div class="card src">
        <div class="label">💰 Source</div>
        <div class="addr">${ISSUERPUB}</div>
        <div class="bal">${ZENCUR} ZEN</div>
        <div class="links">
          <a href="${CESIUM}/#/app/wot/tx/${ISSUERPUB}/" target="_blank">📊 Cesium</a>
          $([[ -n "$UPLANET" ]] && echo "<a href=\"${UPLANET}/g1gate/?pubkey=${ISSUERPUB}\" class=\"sec\" target=\"_blank\">🔍 Scanner</a>")
        </div>
      </div>
      <div class="arrow">➡️</div>
      <div class="card dst">
        <div class="label">🎯 Destination</div>
        <div class="addr">${G1PUB}</div>
        <div class="bal">${ZENDES} ZEN</div>
        <div class="links">
          <a href="${CESIUM}/#/app/wot/tx/${G1PUB}/" target="_blank">📊 Cesium</a>
          $([[ -n "$UPLANET" ]] && echo "<a href=\"${UPLANET}/g1gate/?pubkey=${G1PUB}\" class=\"sec\" target=\"_blank\">🔍 Scanner</a>")
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
