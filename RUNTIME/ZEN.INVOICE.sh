#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ ZEN.INVOICE.sh
#~ Burn Ẑen + soumission OpenCollective (createExpense) pour la facturation
#~ consolidée Armateur/Capitaine — déclenché explicitement (oc_admin.html),
#~ jamais par cron silencieux.
#
# Remplace l'automatisation désactivée de ZEN.ECONOMY.sh::fourweeks_paf_burn_and_convert()
# (conservée telle quelle, dépréciée) en corrigeant deux défauts identifiés à l'audit :
#   1. Marqueur anti-doublon posé UNIQUEMENT si burn G1 ET création Expense OC réussissent
#      tous les deux (l'ancien code posait le marqueur dès le burn seul — Ẑen perdus sans
#      retry possible si l'étape OC échouait ensuite).
#   2. Verrou flock (absent de l'ancien code, présent dans oc_expense_monitor.sh).
#
# Usage :
#   ZEN.INVOICE.sh <lines.json> [invoice_id]
#
#   lines.json : tableau JSON de lignes à traiter
#     [{"role":"armateur|capitaine", "node_id":"<IPFSNODEID>", "email":"<payee>",
#       "amount_zen": 140.00, "description": "PAF35 - Hébergement..."}, ...]
#
# Sortie : JSON récapitulatif sur stdout (une entrée par ligne : status burn/oc, ids).
################################################################################
## Pas de `set -u` : tools/my.sh référence des variables (ex. __CACHE_HOSTNAME,
## VIRTUAL_ENV) sans garantir leur initialisation — cohérent avec ZEN.ECONOMY.sh
## et oc2uplanet.sh, qui ne l'utilisent pas non plus.
set -o pipefail

MY_PATH="$(cd "$(dirname "$0")" && pwd)"
. "${MY_PATH}/../tools/my.sh"
. "${MY_PATH}/../tools/cooperative_config.sh" 2>/dev/null || true
. "${MY_PATH}/../tools/armateur_registry.sh"

## Protection contre les exécutions concurrentes (pattern oc_expense_monitor.sh:16-18)
exec 200>"/tmp/zen_invoice.lock"
flock -n 200 || { echo '{"error":"ZEN.INVOICE.sh déjà en cours"}' >&2; exit 1; }

LINES_FILE="${1:-}"
INVOICE_ID="${2:-FACTURE-$(date -u +%Y%m%d%H%M%S)}"
MARKER_DIR="$HOME/.zen/game/.zen_invoice"
mkdir -p "$MARKER_DIR"

if [[ -z "$LINES_FILE" || ! -s "$LINES_FILE" ]]; then
    echo '{"error":"Usage: ZEN.INVOICE.sh <lines.json> [invoice_id] — fichier introuvable ou vide"}' >&2
    exit 1
fi
if ! jq -e 'type == "array" and length > 0' "$LINES_FILE" >/dev/null 2>&1; then
    echo '{"error":"lines.json doit être un tableau JSON non vide"}' >&2
    exit 1
fi

################################################################################
## Mode ORIGIN vs production — ORIGIN est un régime économique réel (1Ẑ=0.1Ğ1),
## pas un sandbox factice : burn ET soumission OC restent actifs, sans bascule
## vers une API staging (non configurée pour ce collectif — contrairement à
## oc_expense_monitor.sh, qui suppose une config staging qui n'existe pas ici).
## Perdre des Ẑen sur ORIGIN n'est pas grave (un "bon au porteur" d'un "bon au
## porteur" — valeur symbolique, pas la vraie économie €), mais le Capitaine
## doit TOUJOURS être informé en cas d'échec (aucun `2>/dev/null` sur les
## opérations qui peuvent échouer silencieusement plus bas).
################################################################################
OC_API_URL="https://api.opencollective.com/graphql/v2"

################################################################################
## Détection du niveau de station (Level X/Y) — identique à l'ancienne fonction
## fourweeks_paf_burn_and_convert() de ZEN.ECONOMY.sh (lignes 869-882).
################################################################################
STATION_LEVEL="X"
if [[ -s ~/.ssh/id_ed25519.pub ]]; then
    _YIPNS=$("${MY_PATH}/../tools/ssh_to_g1ipfs.py" "$(cat ~/.ssh/id_ed25519.pub)" 2>/dev/null)
    [[ -n "$_YIPNS" && "$IPFSNODEID" == "$_YIPNS" ]] && STATION_LEVEL="Y"
fi

################################################################################
## Résolution des identités payee. Chargée depuis la config station / le
## registre, jamais depuis les lignes d'entrée (qui ne fournissent que
## montant/rôle/node_id/description) : évite qu'un appelant compromette le
## payee réel en le passant lui-même dans lines.json.
##
## Armateur : un Armateur = une station = une clef IPFSNODEID (cf. facture
## consolidée réelle : une ligne hébergement + une ligne par nœud hébergé,
## chacun potentiellement facturé par un Armateur différent). Résolu via le
## registre tools/armateur_registry.sh, indexé par node_id — repli sur
## ARMATEUR_EMAIL de la station locale si ce nœud précis n'y est pas enregistré
## (cas simple : auto-hébergement, un seul Armateur pour toute la facture).
################################################################################
ENV_FILE="${MY_PATH}/../.env"
ARMATEUR_EMAIL_LOCAL="${ARMATEUR_EMAIL:-$(grep '^ARMATEUR_EMAIL=' "$ENV_FILE" 2>/dev/null | cut -d'=' -f2-)}"
[[ -z "$ARMATEUR_EMAIL_LOCAL" ]] && ARMATEUR_EMAIL_LOCAL="$CAPTAINEMAIL"

_payee_for_role() {
    local role="$1" node_id="${2:-}"
    case "$role" in
        armateur)
            local _registered
            _registered=$(armateur_registry_get "$node_id" email 2>/dev/null)
            echo "${_registered:-$ARMATEUR_EMAIL_LOCAL}"
            ;;
        capitaine) echo "$CAPTAINEMAIL" ;;
        *) echo "" ;;
    esac
}

_wallet_for_role() {
    ## LIMITATION CONNUE : le burn signe toujours depuis le wallet de CETTE
    ## station locale (celle qui exécute ZEN.INVOICE.sh), quel que soit le
    ## node_id de la ligne — brûler le PAF d'un AUTRE nœud de la constellation
    ## nécessiterait d'exécuter ce script depuis le contexte (~/.zen/) de ce
    ## nœud précis (chaque station ne détient que ses propres clefs privées).
    ## node_id ne sert ici qu'à la traçabilité et à la résolution du payee
    ## Armateur (registre) — pas encore à un vrai routage multi-stations du
    ## burn. Une facture consolidée multi-nœuds suppose donc, pour l'instant,
    ## que ZEN.INVOICE.sh est relancé une fois par station concernée, avec le
    ## même invoice_id, avant soumission OC groupée.
    ##
    ## tools/sibling_stations.sh identifie QUELLES stations appartiennent au
    ## même Capitaine (convention email+alias@domaine, cf. RFC 5233 — toutes
    ## les adresses "base+xxx@domaine" reçoivent leurs notifications dans la
    ## même boîte que "base@domaine", mais dérivent des MULTIPASS distincts).
    ## La station tenant l'adresse SANS "+" est la station "maîtresse" où la
    ## facture consolidée se compose (oc_admin.html, Phase D) ; ses stations
    ## sœurs restent à brûler individuellement tant qu'aucun mécanisme P2P de
    ## déclenchement à distance n'existe.
    if [[ "$STATION_LEVEL" == "Y" && -f "$HOME/.zen/game/secret.NODE.dunikey" ]]; then
        echo "$HOME/.zen/game/secret.NODE.dunikey"
    elif [[ -n "$CAPTAINEMAIL" && -f "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.dunikey" ]]; then
        echo "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.dunikey"
    else
        echo ""
    fi
}

################################################################################
## Preuve NOSTR kind 30851 (type=debit) — cf. NIP-101/KIND_REGISTRY.md
################################################################################
CAPTAIN_NOSTR_KEYFILE=""
trap '[[ -n "$CAPTAIN_NOSTR_KEYFILE" ]] && rm -f "$CAPTAIN_NOSTR_KEYFILE"' EXIT INT TERM

_init_captain_nostr_key() {
    [[ -n "$CAPTAIN_NOSTR_KEYFILE" ]] && return 0
    local _secret="$HOME/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr"
    if [[ ! -s "$_secret" ]]; then
        echo "⚠️  Clef NOSTR Capitaine introuvable (${_secret}) — preuve 30851 non publiée." >&2
        return 1
    fi
    local _raw _nsec
    _raw=$(cat "$_secret")
    _nsec=$(echo "$_raw" | grep -oP 'NSEC=\K[^;]+' || true)
    [[ -z "$_nsec" || "$_nsec" != nsec1* ]] && _nsec=$(echo "$_raw" | grep -oP 'nsec1[a-z0-9]+' || true)
    if [[ "$_nsec" != nsec1* ]]; then
        echo "⚠️  Clef NOSTR Capitaine illisible (${_secret}) — preuve 30851 non publiée." >&2
        return 1
    fi
    CAPTAIN_NOSTR_KEYFILE=$(mktemp /tmp/zen_invoice_key_XXXXXX)
    echo "NSEC=$_nsec;" > "$CAPTAIN_NOSTR_KEYFILE"
}

## Publie/actualise la preuve de burn pour une ligne. $7 (extra_json) fusionné dans content.
## Toute erreur est imprimée sur stderr — jamais de `2>/dev/null` : le Capitaine
## doit savoir si une preuve n'a pas pu être publiée, même quand le burn/la
## conversion OC eux-mêmes ont réussi (sinon la trace NOSTR devient incomplète
## sans que personne ne le remarque).
_publish_burn_proof() {
    local d_tag="$1" role="$2" node_id="$3" email="$4" amount="$5" status="$6" extra_json="${7:-{\}}"

    _init_captain_nostr_key || { echo "⚠️  Preuve NOSTR [$status] non publiée pour $d_tag" >&2; return 1; }
    if [[ -z "${UPLANETG1PUB:-}" ]]; then
        echo "⚠️  UPLANETG1PUB non défini — preuve NOSTR [$status] non publiée pour $d_tag" >&2
        return 1
    fi

    local content_json
    content_json=$(jq -cn \
        --arg role "$role" --arg node_id "$node_id" --arg email "$email" \
        --arg amount "$amount" --arg invoice_id "$INVOICE_ID" --arg status "$status" \
        --arg generated_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" --arg uplanet "${UPLANETG1PUB}" \
        --argjson extra "$extra_json" \
        '{type:"debit", role:$role, node_id:$node_id, email:$email, amount:($amount|tonumber),
          invoice_id:$invoice_id, status:$status, generated_at:$generated_at, uplanet:$uplanet}
         * $extra')
    if [[ $? -ne 0 || -z "$content_json" ]]; then
        echo "⚠️  Construction JSON (content) échouée pour la preuve $d_tag" >&2
        return 1
    fi

    local tags_json
    tags_json=$(jq -cn \
        --arg d "$d_tag" --arg role "$role" --arg node_id "$node_id" --arg email "$email" \
        --arg amount "$amount" --arg s "$status" --arg invoice_id "$INVOICE_ID" \
        --arg constellation "${UPLANETG1PUB}" \
        '[["d",$d],["t","uplanet"],["t","oc-burn"],["type","debit"],["s",$s],
          ["email",$email],["amount",$amount],["role",$role],["node",$node_id],
          ["invoice_id",$invoice_id],["constellation",$constellation]]')
    if [[ $? -ne 0 || -z "$tags_json" ]]; then
        echo "⚠️  Construction JSON (tags) échouée pour la preuve $d_tag" >&2
        return 1
    fi

    local _pub_err
    _pub_err=$(python3 "${MY_PATH}/../tools/nostr_send_note.py" \
        --keyfile "$CAPTAIN_NOSTR_KEYFILE" --kind 30851 \
        --content "$content_json" --tags "$tags_json" \
        --relay "ws://127.0.0.1:7777" 2>&1 >/dev/null)
    local rc=$?
    [[ $rc -ne 0 ]] && echo "⚠️  Publication preuve NOSTR [$status] échouée pour $d_tag : ${_pub_err}" >&2
    return $rc
}

################################################################################
## createExpense GraphQL — une mutation PAR payee distinct (l'API OC ne supporte
## qu'un seul payee par Expense), même schéma que l'ancienne
## request_opencollective_conversion() (ZEN.ECONOMY.sh:1038-1057), mais items[]
## consolidé sur toutes les lignes de ce payee plutôt qu'un item unique.
################################################################################
_submit_oc_expense() {
    local payee_email="$1" items_json="$2"  # items_json: [{"description":"...","amount":cents}, ...]

    local OC_TOKEN OC_SLUG
    OC_TOKEN=$(coop_config_get "OCAPIKEY")
    [[ -z "$OC_TOKEN" ]] && OC_TOKEN="${OCAPIKEY:-}"
    OC_SLUG=$(coop_config_get "OCSLUG")
    [[ -z "$OC_SLUG" ]] && OC_SLUG="${OCSLUG:-monnaie-libre}"

    if [[ -z "$OC_TOKEN" || -z "$OC_SLUG" ]]; then
        echo "⚠️  OCAPIKEY/OCSLUG manquant — impossible de soumettre l'Expense OC pour ${payee_email}" >&2
        echo '{"success":false,"error":"OCAPIKEY/OCSLUG manquant"}'
        return 1
    fi

    local description="Facture ${INVOICE_ID} — ${IPFSNODEID:0:8}"
    local payload
    payload=$(jq -cn \
        --arg slug "$OC_SLUG" --arg email "$payee_email" --arg desc "$description" \
        --argjson items "$items_json" \
        '{query:"mutation CreateExpense($expense: ExpenseCreateInput!) { createExpense(expense: $expense) { id legacyId status } }",
          variables:{expense:{account:{slug:$slug}, payee:{email:$email}, type:"INVOICE",
                              description:$desc, tags:["paf-burn","operational-costs","zen-conversion"],
                              items:$items}}}')

    local response curl_err
    ## --max-time : sans lui un OC API lent/rate-limité bloque le burn indéfiniment,
    ## alors que le G1 a déjà été brûlé (irréversible) — le Capitaine doit voir l'échec
    ## rapidement (cf. même correctif sur oc2uplanet.sh/oc_expense_monitor.sh).
    response=$(curl -sS --max-time 30 -X POST "$OC_API_URL" \
        -H "Personal-Token: $OC_TOKEN" -H "Content-Type: application/json" \
        -d "$payload" 2>/tmp/zen_invoice_curl_err.$$)
    curl_err=$(cat /tmp/zen_invoice_curl_err.$$ 2>/dev/null); rm -f /tmp/zen_invoice_curl_err.$$

    if [[ -z "$response" ]]; then
        echo "⚠️  Échec réseau vers ${OC_API_URL} pour ${payee_email} : ${curl_err:-réponse vide}" >&2
        jq -cn --arg e "network: ${curl_err:-empty response}" '{success:false,error:$e}'
        return 1
    fi
    if ! echo "$response" | jq -e . >/dev/null 2>&1; then
        echo "⚠️  Réponse OC illisible pour ${payee_email} : ${response:0:300}" >&2
        jq -cn --arg e "invalid_json_response" '{success:false,error:$e}'
        return 1
    fi

    local errors expense_id
    errors=$(echo "$response" | jq -r '.errors[0].message // empty')
    if [[ -n "$errors" ]]; then
        echo "⚠️  OpenCollective a refusé l'Expense pour ${payee_email} : ${errors}" >&2
        jq -cn --arg e "$errors" '{success:false,error:$e}'
        return 1
    fi
    expense_id=$(echo "$response" | jq -r '.data.createExpense.id // empty')
    if [[ -z "$expense_id" ]]; then
        echo "⚠️  Réponse OC inattendue pour ${payee_email} : ${response:0:300}" >&2
        jq -cn --arg e "unexpected_response" '{success:false,error:$e}'
        return 1
    fi
    jq -cn --arg id "$expense_id" '{success:true,expense_id:$id}'
}

################################################################################
## Boucle principale — étape 1 : burn ligne par ligne (idempotent, marqueur
## posé uniquement après confirmation PAYforSURE.sh)
################################################################################
declare -A LINE_STATUS   # d_tag -> "burned"|"burn_failed"
declare -A LINE_PAYEE    # d_tag -> email
RESULTS="[]"

_line_count=$(jq 'length' "$LINES_FILE")
for ((_i = 0; _i < _line_count; _i++)); do
    line=$(jq -c ".[$_i]" "$LINES_FILE")
    role=$(echo "$line" | jq -r '.role')
    node_id=$(echo "$line" | jq -r '.node_id')
    amount_zen=$(echo "$line" | jq -r '.amount_zen')
    description=$(echo "$line" | jq -r '.description // "PAF"')

    payee=$(_payee_for_role "$role" "$node_id")
    if [[ -z "$payee" ]]; then
        RESULTS=$(echo "$RESULTS" | jq --argjson l "$line" '. += [$l + {status:"error", error:"payee_unresolved"}]')
        continue
    fi

    d_tag="oc-burn-${INVOICE_ID}:${role}:${node_id}:${payee}"
    marker_burn="${MARKER_DIR}/${d_tag//[:\/]/_}.burn_done"
    marker_conv="${MARKER_DIR}/${d_tag//[:\/]/_}.conversion_done"

    if [[ -f "$marker_burn" ]]; then
        LINE_STATUS["$d_tag"]="burned"
        LINE_PAYEE["$d_tag"]="$payee"
        continue
    fi

    _publish_burn_proof "$d_tag" "$role" "$node_id" "$payee" "$amount_zen" "PENDING" "{\"description\":\"$description\"}" \
        || echo "⚠️  Continuation malgré l'échec de publication de la preuve PENDING pour $d_tag" >&2

    wallet=$(_wallet_for_role "$role")
    if [[ -z "$wallet" ]]; then
        echo "⚠️  Aucun wallet local disponible pour brûler la ligne $d_tag (rôle=$role)" >&2
        RESULTS=$(echo "$RESULTS" | jq --argjson l "$line" --arg d "$d_tag" '. += [$l + {d_tag:$d, status:"error", error:"no_wallet"}]')
        _publish_burn_proof "$d_tag" "$role" "$node_id" "$payee" "$amount_zen" "FAIL" '{"error":"no_wallet"}'
        continue
    fi

    amount_g1=$(makecoord "$(echo "scale=2; $amount_zen / 10" | bc -l 2>/dev/null || echo 0)")
    echo "→ Burn en cours : $d_tag (${amount_zen}Ẑ / ${amount_g1}Ğ1)" >&2
    ## Pas de `2>/dev/null` ici : PAYforSURE.sh affiche sa progression (vérification de
    ## solde, retry multi-nœuds, confirmation post-paiement) — le Capitaine doit la voir
    ## en direct, surtout en cas d'échec (solde insuffisant, nœud RPC injoignable, etc.).
    "${MY_PATH}/../tools/PAYforSURE.sh" "$wallet" "$amount_g1" "${UPLANETNAME_G1}" \
        "UP:${UPLANETG1PUB:0:8}:BURN:${INVOICE_ID}:${role}:${amount_zen}Z"
    burn_rc=$?

    if [[ $burn_rc -eq 0 ]]; then
        echo "$(date -u +%Y%m%d%H%M%S) BURN_OK $d_tag $amount_zen" > "$marker_burn"
        chmod 600 "$marker_burn"
        LINE_STATUS["$d_tag"]="burned"
        LINE_PAYEE["$d_tag"]="$payee"
    else
        LINE_STATUS["$d_tag"]="burn_failed"
        _publish_burn_proof "$d_tag" "$role" "$node_id" "$payee" "$amount_zen" "FAIL" '{"error":"payforsure_failed"}'
        RESULTS=$(echo "$RESULTS" | jq --argjson l "$line" --arg d "$d_tag" '. += [$l + {d_tag:$d, status:"burn_failed"}]')
    fi
done

################################################################################
## Étape 2 — regroupement par payee des lignes brûlées avec succès, une
## mutation createExpense PAR payee (jamais de perte silencieuse : chaque ligne
## dont la conversion échoue est republiée FAIL, jamais laissée dans un état
## ambigu comme dans l'ancien fourweeks_paf_burn_and_convert()).
################################################################################
mapfile -t distinct_payees < <(printf '%s\n' "${LINE_PAYEE[@]}" | sort -u)

for payee in "${distinct_payees[@]}"; do
    [[ -z "$payee" ]] && continue
    items="[]"
    payee_dtags=()
    for d_tag in "${!LINE_PAYEE[@]}"; do
        [[ "${LINE_PAYEE[$d_tag]}" != "$payee" ]] && continue
        [[ "${LINE_STATUS[$d_tag]}" != "burned" ]] && continue
        marker_conv="${MARKER_DIR}/${d_tag//[:\/]/_}.conversion_done"
        [[ -f "$marker_conv" ]] && continue   # déjà converti lors d'un run précédent
        payee_dtags+=("$d_tag")
    done
    [[ ${#payee_dtags[@]} -eq 0 ]] && continue

    # Reconstruire les items depuis lines.json (par d_tag) pour ce payee
    for d_tag in "${payee_dtags[@]}"; do
        # d_tag = oc-burn-{invoice}:{role}:{node}:{email} → extraire role/node pour retrouver la ligne
        IFS=':' read -r _ role node_id _ <<< "$d_tag"
        line=$(jq -c --arg role "$role" --arg node "$node_id" \
            'map(select(.role == $role and .node_id == $node)) | first' "$LINES_FILE")
        amount_cents=$(echo "$line" | jq -r '(.amount_zen * 100 | round)')
        desc=$(echo "$line" | jq -r '.description // "PAF"')
        items=$(echo "$items" | jq --arg desc "$desc" --argjson amt "$amount_cents" '. += [{description:$desc, amount:$amt}]')
    done

    oc_result=$(_submit_oc_expense "$payee" "$items")
    oc_ok=$(echo "$oc_result" | jq -r '.success')
    expense_id=$(echo "$oc_result" | jq -r '.expense_id // empty')

    for d_tag in "${payee_dtags[@]}"; do
        IFS=':' read -r _ role node_id _ <<< "$d_tag"
        line=$(jq -c --arg role "$role" --arg node "$node_id" \
            'map(select(.role == $role and .node_id == $node)) | first' "$LINES_FILE")
        amount_zen=$(echo "$line" | jq -r '.amount_zen')
        marker_conv="${MARKER_DIR}/${d_tag//[:\/]/_}.conversion_done"

        if [[ "$oc_ok" == "true" ]]; then
            echo "$(date -u +%Y%m%d%H%M%S) CONVERSION_OK $d_tag $expense_id" > "$marker_conv"
            chmod 600 "$marker_conv"
            _publish_burn_proof "$d_tag" "$role" "$node_id" "$payee" "$amount_zen" "OK" \
                "{\"expense_id\":\"$expense_id\"}"
            RESULTS=$(echo "$RESULTS" | jq --argjson l "$line" --arg d "$d_tag" --arg eid "$expense_id" \
                '. += [$l + {d_tag:$d, status:"ok", expense_id:$eid}]')
        else
            ## Burn déjà fait (irréversible) mais conversion OC échouée : statut FAIL explicite,
            ## PAS de marqueur conversion_done → retentable au prochain run (corrige le bug audité).
            _publish_burn_proof "$d_tag" "$role" "$node_id" "$payee" "$amount_zen" "FAIL" \
                "$(echo "$oc_result" | jq -c '{oc_error: .error}')"
            RESULTS=$(echo "$RESULTS" | jq --argjson l "$line" --arg d "$d_tag" \
                '. += [$l + {d_tag:$d, status:"burned_but_oc_failed"}]')
        fi
    done
done

echo "$RESULTS" | jq -c "{invoice_id: \"$INVOICE_ID\", results: .}"
