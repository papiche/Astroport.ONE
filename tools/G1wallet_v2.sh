#!/usr/bin/env bash
# =============================================================================
# g1wallet.sh — Requêtes GraphQL vers l'indexeur Squid Ğ1
# Usage : g1wallet.sh <mode> <wallet> [options]
# =============================================================================
# Modes disponibles :
#   uplanet    <wallet>                          Première tx (marquage UPlanet)
#   upassport  <wallet> [montant_centimes]       2ème tx entrante (UPassport)
#   history    <wallet>                          Historique complet TX + DU
#   transfers  <wallet>                          Transferts seuls (entrée+sortie)
#   period     <wallet> <date_debut> <date_fin>  Historique sur une période
#   balance    <wallet>                          Solde actuel
#
# Exemples :
#   ./g1wallet.sh uplanet   5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY
#   ./g1wallet.sh upassport 5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY 10000
#   ./g1wallet.sh period    5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY 2024-01-01 2025-01-01
# =============================================================================

# --- Configuration -----------------------------------------------------------
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"

SQUID_URL="${SQUID_URL:-https://squid.g1.gyroi.de/v1/graphql}"

# Mise à jour squid dynamique via duniter_getnode.sh
if [[ -x "${MY_PATH}/duniter_getnode.sh" ]]; then
    _sq=$("${MY_PATH}/duniter_getnode.sh" squid 2>/dev/null)
    [[ -n "$_sq" ]] && SQUID_URL="$_sq"
fi

# Liste de squids avec fallback
SQUIDS=("$SQUID_URL"
    "https://squid.g1.gyroi.de/v1/graphql"
    "https://squid.g1.coinduf.eu/v1/graphql"
    "https://g1-squid.axiom-team.fr/v1/graphql"
)
# Dédupliquer
mapfile -t SQUIDS < <(printf '%s\n' "${SQUIDS[@]}" | awk '!seen[$0]++')

# --- Couleurs ----------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# --- Helpers -----------------------------------------------------------------
usage() {
  grep '^#' "$0" | grep -v '#!/' | sed 's/^# \{0,2\}//'
  exit 0
}

die() { echo -e "${RED}ERREUR: $*${RESET}" >&2; exit 1; }

require_cmd() { command -v "$1" &>/dev/null || die "'$1' est requis (apt/brew install $1)"; }

graphql_query() {
  # $1 = query JSON (compact)
  # Essaie chaque squid jusqu'à succès
  local response
  for sq in "${SQUIDS[@]}"; do
    response=$(curl -sf --max-time 10 \
      -X POST \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      --data "$1" \
      "$sq" 2>/dev/null) || { echo -e "${YELLOW}Échec sur $sq${RESET}" >&2; continue; }

    # Vérifie les erreurs GraphQL
    if echo "$response" | grep -q '"errors"'; then
      echo -e "${YELLOW}Erreur GraphQL sur $sq${RESET}" >&2
      continue
    fi

    SQUID_URL="$sq"
    echo "$response"
    return 0
  done

  die "Requête échouée sur tous les squids"
}

# Formate un BigInt Ğ1 en valeur lisible (divise par 10^4 = 4 décimales)
# Ajuster DECIMALS si besoin après vérification
DECIMALS=2   # 1 Ğ1 = 100 centimes en brut (v1 migré + v2 natif)
format_amount() {
  local raw="$1"
  if command -v python3 &>/dev/null; then
    python3 -c "print(f'{int('$raw') / 10**$DECIMALS:.4f} Ğ1')" 2>/dev/null || echo "${raw} (raw)"
  else
    echo "${raw} (raw, diviser par 10^${DECIMALS} pour Ğ1)"
  fi
}

print_transfer() {
  # $1 = nœud JSON d'un transfert
  local node="$1"
  local from to amount ts block comment direction wallet="$2"

  from=$(echo "$node"    | jq -r '.fromId // "—"')
  to=$(echo "$node"      | jq -r '.toId   // "—"')
  amount=$(echo "$node"  | jq -r '.amount')
  ts=$(echo "$node"      | jq -r '.timestamp // .blockNumber')
  block=$(echo "$node"   | jq -r '.blockNumber // "?"')
  comment=$(echo "$node" | jq -r '.comment.message // ""')

  if [[ "$to" == "$wallet" ]]; then
    direction="${GREEN}← REÇU  ${RESET}"
  elif [[ "$from" == "$wallet" ]]; then
    direction="${YELLOW}→ ENVOYÉ${RESET}"
  else
    direction="${CYAN}~ DU    ${RESET}"   # Dividende Universel (pas de from/to)
  fi

  echo -e "  ${direction} ${BOLD}$(format_amount "$amount")${RESET}"
  echo    "    bloc     : $block"
  echo    "    date     : $ts"
  [[ "$from" != "—" && "$from" != "$wallet" ]] && echo "    de       : $from"
  [[ "$to"   != "—" && "$to"   != "$wallet" ]] && echo "    vers     : $to"
  [[ -n "$comment" ]]                           && echo "    commentaire : $comment"
  echo
}

# =============================================================================
# MODE : balance
# =============================================================================
mode_balance() {
  local wallet="$1"
  [[ -z "$wallet" ]] && die "Usage: $0 balance <wallet>"

  echo -e "${CYAN}Solde du wallet :${RESET} $wallet"

  local query
  query=$(jq -cn --arg w "$wallet" '{
    query: "query($w:String!){accounts(condition:{id:$w}){nodes{id balance totalBalance}}}",
    variables: {w: $w}
  }')

  local resp
  resp=$(graphql_query "$query")

  local node
  node=$(echo "$resp" | jq '.data.accounts.nodes[0]')
  [[ "$node" == "null" || -z "$node" ]] && die "Wallet introuvable dans l'indexeur"

  local balance total
  balance=$(echo "$node" | jq -r '.balance')
  total=$(echo "$node"   | jq -r '.totalBalance // "N/A"')

  echo -e "  ${BOLD}Solde actuel  :${RESET} $(format_amount "$balance")"
  [[ "$total" != "N/A" ]] && \
  echo -e "  ${BOLD}Total (+ DU)  :${RESET} $(format_amount "$total")"
}

# =============================================================================
# MODE : uplanet — Première transaction du wallet
# =============================================================================
mode_uplanet() {
  local wallet="$1"
  [[ -z "$wallet" ]] && die "Usage: $0 uplanet <wallet>"

  echo -e "${CYAN}UPlanet — Première transaction :${RESET} $wallet\n"

  local query
  query=$(jq -cn --arg w "$wallet" '{
    query: "query($w:String!){accounts(condition:{id:$w}){nodes{transferWithUd(orderBy:BLOCK_NUMBER_ASC,first:1){nodes{amount timestamp blockNumber fromId toId comment{message}}}}}}",
    variables: {w: $w}
  }')

  local resp node
  resp=$(graphql_query "$query")
  node=$(echo "$resp" | jq '.data.accounts.nodes[0].transferWithUd.nodes[0]')

  [[ "$node" == "null" || -z "$node" ]] && die "Aucune transaction trouvée pour ce wallet"

  print_transfer "$node" "$wallet"
}

# =============================================================================
# MODE : upassport — 2ème tx entrante d'un montant donné
# =============================================================================
mode_upassport() {
  local wallet="$1"
  local montant="${2:-10000}"   # défaut : 10000 = 0.01 Ğ1 à 4 décimales

  [[ -z "$wallet" ]] && die "Usage: $0 upassport <wallet> [montant_centimes]"

  echo -e "${CYAN}UPassport — 2ème tx entrante à ${montant} (raw) :${RESET} $wallet\n"

  local query
  query=$(jq -cn --arg w "$wallet" --arg m "$montant" '{
    query: "query($w:String!,$m:BigInt!){transfers(filter:{toId:{equalTo:$w},amount:{equalTo:$m}},orderBy:BLOCK_NUMBER_ASC,first:2){nodes{fromId toId amount timestamp blockNumber comment{message}}totalCount}}",
    variables: {w: $w, m: $m}
  }')

  local resp total nodes node
  resp=$(graphql_query "$query")
  total=$(echo "$resp" | jq '.data.transfers.totalCount')
  nodes=$(echo "$resp" | jq '.data.transfers.nodes')

  echo -e "  Total de tx entrantes à ce montant : ${BOLD}$total${RESET}\n"

  if [[ "$total" -lt 2 ]]; then
    echo -e "${YELLOW}Moins de 2 transactions trouvées — UPassport pas encore marqué ?${RESET}"
    echo "  1ère tx trouvée :"
    node=$(echo "$nodes" | jq '.[0]')
    [[ "$node" != "null" ]] && print_transfer "$node" "$wallet"
    return
  fi

  echo "  2ème tx (marquage UPassport) :"
  node=$(echo "$nodes" | jq '.[1]')
  print_transfer "$node" "$wallet"

  echo "  (1ère tx pour référence) :"
  node=$(echo "$nodes" | jq '.[0]')
  print_transfer "$node" "$wallet"
}

# =============================================================================
# MODE : history — Historique complet TX + DU
# =============================================================================
mode_history() {
  local wallet="$1"
  [[ -z "$wallet" ]] && die "Usage: $0 history <wallet>"

  echo -e "${CYAN}Historique complet (TX + DU) :${RESET} $wallet\n"

  local query
  query=$(jq -cn --arg w "$wallet" '{
    query: "query($w:String!){accounts(condition:{id:$w}){nodes{balance transferWithUd(orderBy:BLOCK_NUMBER_ASC){totalCount nodes{amount timestamp blockNumber fromId toId comment{message}}}}}}",
    variables: {w: $w}
  }')

  local resp
  resp=$(graphql_query "$query")

  local account
  account=$(echo "$resp" | jq '.data.accounts.nodes[0]')
  [[ "$account" == "null" || -z "$account" ]] && die "Wallet introuvable"

  local total balance
  total=$(echo "$account"   | jq '.transferWithUd.totalCount')
  balance=$(echo "$account" | jq -r '.balance')

  echo -e "  Solde actuel  : ${BOLD}$(format_amount "$balance")${RESET}"
  echo -e "  Nb opérations : ${BOLD}$total${RESET}\n"

  echo "$account" | jq -c '.transferWithUd.nodes[]' | while IFS= read -r node; do
    print_transfer "$node" "$wallet"
  done
}

# =============================================================================
# MODE : period — Historique sur une période de temps
# =============================================================================
mode_period() {
  local wallet="$1"
  local debut="$2"
  local fin="$3"

  [[ -z "$wallet" || -z "$debut" || -z "$fin" ]] && \
    die "Usage: $0 period <wallet> <YYYY-MM-DD> <YYYY-MM-DD>"

  # Normalise en ISO 8601 avec heure
  [[ "$debut" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && debut="${debut}T00:00:00Z"
  [[ "$fin"   =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && fin="${fin}T23:59:59Z"

  echo -e "${CYAN}Historique du ${debut} au ${fin} :${RESET} $wallet\n"

  local query
  query=$(jq -cn --arg w "$wallet" --arg d "$debut" --arg f "$fin" '{
    query: "query($w:String!,$d:Datetime!,$f:Datetime!){accounts(condition:{id:$w}){nodes{transferWithUd(filter:{timestamp:{greaterThanOrEqualTo:$d,lessThanOrEqualTo:$f}},orderBy:BLOCK_NUMBER_ASC){totalCount nodes{amount timestamp blockNumber fromId toId comment{message}}}}}}",
    variables: {w: $w, d: $d, f: $f}
  }')

  local resp account total
  resp=$(graphql_query "$query")
  account=$(echo "$resp" | jq '.data.accounts.nodes[0]')
  [[ "$account" == "null" || -z "$account" ]] && die "Wallet introuvable"

  total=$(echo "$account" | jq '.transferWithUd.totalCount')
  echo -e "  Nb opérations sur la période : ${BOLD}$total${RESET}\n"

  echo "$account" | jq -c '.transferWithUd.nodes[]' | while IFS= read -r node; do
    print_transfer "$node" "$wallet"
  done
}

# =============================================================================
# MODE : transfers — Transferts uniquement (sans DU), entrée et sortie séparés
# =============================================================================
mode_transfers() {
  local wallet="$1"
  [[ -z "$wallet" ]] && die "Usage: $0 transfers <wallet>"

  echo -e "${CYAN}Transferts entrants et sortants :${RESET} $wallet\n"

  local query
  query=$(jq -cn --arg w "$wallet" '{
    query: "query($w:String!){recu:transfers(filter:{toId:{equalTo:$w}},orderBy:BLOCK_NUMBER_ASC){totalCount nodes{fromId toId amount timestamp blockNumber comment{message}}} envoye:transfers(filter:{fromId:{equalTo:$w}},orderBy:BLOCK_NUMBER_ASC){totalCount nodes{fromId toId amount timestamp blockNumber comment{message}}}}",
    variables: {w: $w}
  }')

  local resp
  resp=$(graphql_query "$query")

  local total_in total_out
  total_in=$(echo "$resp"  | jq '.data.recu.totalCount')
  total_out=$(echo "$resp" | jq '.data.envoye.totalCount')

  echo -e "  ${GREEN}← Reçus   :${RESET} $total_in"
  echo -e "  ${YELLOW}→ Envoyés :${RESET} $total_out\n"

  echo -e "${GREEN}=== REÇUS ===${RESET}\n"
  echo "$resp" | jq -c '.data.recu.nodes[]' | while IFS= read -r node; do
    print_transfer "$node" "$wallet"
  done

  echo -e "${YELLOW}=== ENVOYÉS ===${RESET}\n"
  echo "$resp" | jq -c '.data.envoye.nodes[]' | while IFS= read -r node; do
    print_transfer "$node" "$wallet"
  done
}

# =============================================================================
# Point d'entrée
# =============================================================================
require_cmd curl
require_cmd jq

MODE="${1:-}"
WALLET="${2:-}"

# Conversion automatique v1 pubkey → SS58 pour requêtes squid
if [[ -n "$WALLET" ]] && [[ -x "${MY_PATH}/g1pub_to_ss58.py" ]] && ! [[ "$WALLET" =~ ^g1 ]]; then
    _SS58=$(python3 "${MY_PATH}/g1pub_to_ss58.py" "$WALLET" 2>/dev/null)
    if [[ -n "$_SS58" ]]; then
        echo -e "${CYAN}Conversion v1→SS58 :${RESET} $WALLET → $_SS58" >&2
        WALLET="$_SS58"
    fi
fi

case "$MODE" in
  uplanet)   mode_uplanet   "$WALLET" ;;
  upassport) mode_upassport "$WALLET" "${3:-10000}" ;;
  history)   mode_history   "$WALLET" ;;
  transfers) mode_transfers "$WALLET" ;;
  period)    mode_period    "$WALLET" "${3:-}" "${4:-}" ;;
  balance)   mode_balance   "$WALLET" ;;
  help|--help|-h|"") usage ;;
  *) die "Mode inconnu : '$MODE'. Lancez '$0 help' pour l'aide." ;;
esac
