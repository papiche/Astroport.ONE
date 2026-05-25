#!/usr/bin/env bash
# ovh.me.sh — CLI DNSLink OVH pour UPlanet / Astroport.ONE
#
# Usage : ovh.me.sh <commande> [args...]
#
# Commandes :
#   list   [zone]                   — liste tous les records _dnslink.* de la zone
#   get    <sub> [zone]             — affiche le record TXT d'un subdomain
#   create <sub> <target> [zone]    — crée un record TXT (erreur si déjà existant)
#   update <sub> <target> [zone]    — met à jour (erreur si absent)
#   upsert <sub> <target> [zone]    — crée ou met à jour (recommandé)
#   delete <sub> [zone]             — supprime un record TXT
#
# Normalisation des sous-domaines :
#   "alice"            → "_dnslink.alice"
#   "_dnslink"         → "_dnslink"
#   "_dnslink.origin"  → "_dnslink.origin"
#
# Normalisation des targets :
#   "/ipns/k51q..."    → "dnslink=/ipns/k51q..."
#   "/ipfs/Qm..."      → "dnslink=/ipfs/Qm..."
#   "k51q..."          → "dnslink=/ipns/k51q..."  (IPNS base36)
#   "Qm..." / "bafy..."→ "dnslink=/ipfs/..."       (CID IPFS)
#   "dnslink=..."      → inchangé
#
# Credentials (par priorité) :
#   1. Variables ENV déjà exportées : OVH_APP_KEY / OVH_APP_SECRET / OVH_CONSUMER_KEY
#   2. cooperative_config.sh via Kind 30800 (si UPLANETNAME disponible)
################################################################################
# Author: Fred (support@qo-op.com)
# License: AGPL-3.0

MY_PATH="$(cd "$(dirname "$0")" && pwd)"

_OVH_ENDPOINT="https://eu.api.ovh.com/1.0"

# ── Chargement des credentials ────────────────────────────────────────────────
_load_credentials() {
    [[ -n "${OVH_APP_KEY:-}" && -n "${OVH_APP_SECRET:-}" && -n "${OVH_CONSUMER_KEY:-}" ]] && return 0

    local coop_sh="${HOME}/.zen/Astroport.ONE/tools/cooperative_config.sh"
    if [[ -f "$coop_sh" ]]; then
        # shellcheck source=/dev/null
        source "$coop_sh" 2>/dev/null
        OVH_APP_KEY=$(coop_config_get "OVH_APP_KEY" 2>/dev/null) || true
        OVH_APP_SECRET=$(coop_config_get "OVH_APP_SECRET" 2>/dev/null) || true
        OVH_CONSUMER_KEY=$(coop_config_get "OVH_CONSUMER_KEY" 2>/dev/null) || true
        OVH_ZONE=$(coop_config_get "OVH_ZONE" 2>/dev/null) || true
    fi

    if [[ -z "${OVH_APP_KEY:-}" || -z "${OVH_APP_SECRET:-}" || -z "${OVH_CONSUMER_KEY:-}" ]]; then
        echo "SKIP DNSLink: OVH_APP_KEY / OVH_APP_SECRET / OVH_CONSUMER_KEY manquants" >&2
        return 1
    fi
}

# ── Normalisation subdomain ───────────────────────────────────────────────────
_norm_sub() {
    local sub="$1"
    case "$sub" in
        _dnslink*) printf '%s' "$sub" ;;
        *)         printf '_dnslink.%s' "$sub" ;;
    esac
}

# ── Normalisation target ──────────────────────────────────────────────────────
_norm_target() {
    local t="$1"
    case "$t" in
        dnslink=*)   printf '%s' "$t" ;;
        /ipns/*)     printf 'dnslink=%s' "$t" ;;
        /ipfs/*)     printf 'dnslink=%s' "$t" ;;
        k51*)        printf 'dnslink=/ipns/%s' "$t" ;;  # IPNS base36
        *)           printf 'dnslink=/ipfs/%s' "$t" ;;  # CID IPFS (Qm, bafy, …)
    esac
}

# ── OVH API v1 HMAC-SHA1 ─────────────────────────────────────────────────────
_ovh_sign() {
    local method="$1" url="$2" body="$3" ts="$4"
    printf '%s' "${OVH_APP_SECRET}+${OVH_CONSUMER_KEY}+${method}+${url}+${body}+${ts}" \
        | sha1sum | cut -d' ' -f1
}

_ovh_api() {
    # Retourne le body de la réponse (erreurs OVH comprises — pas de -f)
    local method="$1" path="$2" body="${3:-}"
    local url="${_OVH_ENDPOINT}${path}"
    local ts
    ts=$(curl -s "${_OVH_ENDPOINT}/auth/time") \
        || { echo "ERROR: OVH /auth/time inaccessible" >&2; return 1; }
    local sig="\$1\$$(_ovh_sign "$method" "$url" "$body" "$ts")"
    local args=(-s -X "$method" "$url"
        -H "Content-Type: application/json"
        -H "X-Ovh-Application: ${OVH_APP_KEY}"
        -H "X-Ovh-Consumer: ${OVH_CONSUMER_KEY}"
        -H "X-Ovh-Timestamp: ${ts}"
        -H "X-Ovh-Signature: ${sig}")
    [[ -n "$body" ]] && args+=(-d "$body")
    curl "${args[@]}"
}

# ── Helpers internes ──────────────────────────────────────────────────────────
_get_record_id() {
    # Retourne l'ID numérique du premier record TXT pour <sub>.<zone>, ou "" si absent
    local sub="$1" zone="$2"
    local ids
    ids=$(_ovh_api GET "/domain/zone/${zone}/record?fieldType=TXT&subDomain=${sub}") || return 1
    if printf '%s' "$ids" | grep -q '"message"'; then
        echo "ERROR OVH API (GET): ${ids}" >&2
        return 1
    fi
    local record_id
    record_id=$(printf '%s' "$ids" | tr -d '[] \n\r' | cut -d',' -f1)
    [[ "$record_id" =~ ^[0-9]+$ ]] && printf '%s' "$record_id" || printf ''
}

# ── Sous-commandes ────────────────────────────────────────────────────────────

cmd_list() {
    local zone="${1:-${OVH_ZONE:-astroport.one}}"
    _load_credentials || return 1
    echo "## DNSLink records dans ${zone}"
    local ids
    ids=$(_ovh_api GET "/domain/zone/${zone}/record?fieldType=TXT") || return 1
    if printf '%s' "$ids" | grep -q '"message"'; then
        echo "ERROR OVH API: ${ids}" >&2; return 1
    fi
    local id
    for id in $(printf '%s' "$ids" | tr -d '[] ' | tr ',' '\n'); do
        [[ "$id" =~ ^[0-9]+$ ]] || continue
        local rec
        rec=$(_ovh_api GET "/domain/zone/${zone}/record/${id}") || continue
        printf '%s' "$rec" | grep -q '"subDomain":"_dnslink' || continue
        local sub tgt ttl
        sub=$(printf '%s' "$rec" | grep -o '"subDomain":"[^"]*"' | cut -d'"' -f4)
        tgt=$(printf '%s' "$rec" | grep -o '"target":"[^"]*"' | cut -d'"' -f4)
        ttl=$(printf '%s' "$rec" | grep -o '"ttl":[0-9]*' | cut -d: -f2)
        printf '  %-32s  %s  (ttl=%s)\n' "${sub}.${zone}" "$tgt" "$ttl"
    done
}

cmd_get() {
    local raw_sub="${1:?usage: ovh.me.sh get <sub> [zone]}"
    local zone="${2:-${OVH_ZONE:-astroport.one}}"
    local sub
    sub=$(_norm_sub "$raw_sub")
    _load_credentials || return 1
    local record_id
    record_id=$(_get_record_id "$sub" "$zone") || return 1
    if [[ -z "$record_id" ]]; then
        echo "NOT_FOUND: ${sub}.${zone}" >&2; return 1
    fi
    _ovh_api GET "/domain/zone/${zone}/record/${record_id}"
    printf '\n'
}

cmd_create() {
    local raw_sub="${1:?usage: ovh.me.sh create <sub> <target> [zone]}"
    local raw_target="${2:?usage: ovh.me.sh create <sub> <target> [zone]}"
    local zone="${3:-${OVH_ZONE:-astroport.one}}"
    local sub target
    sub=$(_norm_sub "$raw_sub")
    target=$(_norm_target "$raw_target")
    _load_credentials || return 1
    echo "## CREATE ${sub}.${zone} → ${target}"
    local body="{\"fieldType\":\"TXT\",\"subDomain\":\"${sub}\",\"target\":\"${target}\",\"ttl\":0}"
    local resp
    resp=$(_ovh_api POST "/domain/zone/${zone}/record" "$body") || return 1
    if printf '%s' "$resp" | grep -q '"message"'; then
        echo "ERROR OVH API (POST): ${resp}" >&2; return 1
    fi
    _ovh_api POST "/domain/zone/${zone}/refresh" > /dev/null
    echo "OK: record créé → ${target}"
}

cmd_update() {
    local raw_sub="${1:?usage: ovh.me.sh update <sub> <target> [zone]}"
    local raw_target="${2:?usage: ovh.me.sh update <sub> <target> [zone]}"
    local zone="${3:-${OVH_ZONE:-astroport.one}}"
    local sub target
    sub=$(_norm_sub "$raw_sub")
    target=$(_norm_target "$raw_target")
    _load_credentials || return 1
    echo "## UPDATE ${sub}.${zone} → ${target}"
    local record_id
    record_id=$(_get_record_id "$sub" "$zone") || return 1
    if [[ -z "$record_id" ]]; then
        echo "ERROR: record ${sub}.${zone} introuvable — utilisez 'create' ou 'upsert'" >&2
        return 1
    fi
    local resp
    resp=$(_ovh_api PUT "/domain/zone/${zone}/record/${record_id}" "{\"target\":\"${target}\"}") || return 1
    if printf '%s' "$resp" | grep -q '"message"'; then
        echo "ERROR OVH API (PUT): ${resp}" >&2; return 1
    fi
    _ovh_api POST "/domain/zone/${zone}/refresh" > /dev/null
    echo "OK: DNSLink mis à jour → ${target}"
}

cmd_upsert() {
    local raw_sub="${1:?usage: ovh.me.sh upsert <sub> <target> [zone]}"
    local raw_target="${2:?usage: ovh.me.sh upsert <sub> <target> [zone]}"
    local zone="${3:-${OVH_ZONE:-astroport.one}}"
    local sub target
    sub=$(_norm_sub "$raw_sub")
    target=$(_norm_target "$raw_target")
    _load_credentials || return 1
    echo "## UPSERT ${sub}.${zone} → ${target}"
    local record_id
    record_id=$(_get_record_id "$sub" "$zone") || return 1
    if [[ -z "$record_id" ]]; then
        echo "INFO: record absent — création..."
        local body="{\"fieldType\":\"TXT\",\"subDomain\":\"${sub}\",\"target\":\"${target}\",\"ttl\":0}"
        local created
        created=$(_ovh_api POST "/domain/zone/${zone}/record" "$body") || return 1
        if printf '%s' "$created" | grep -q '"message"'; then
            echo "ERROR OVH API (POST): ${created}" >&2; return 1
        fi
        echo "INFO: record créé (id: $(printf '%s' "$created" | grep -o '"id":[0-9]*' | cut -d: -f2))"
    else
        local resp
        resp=$(_ovh_api PUT "/domain/zone/${zone}/record/${record_id}" "{\"target\":\"${target}\"}") || return 1
        if printf '%s' "$resp" | grep -q '"message"'; then
            echo "ERROR OVH API (PUT): ${resp}" >&2; return 1
        fi
    fi
    _ovh_api POST "/domain/zone/${zone}/refresh" > /dev/null
    echo "OK: DNSLink mis à jour → ${target}"
}

cmd_delete() {
    local raw_sub="${1:?usage: ovh.me.sh delete <sub> [zone]}"
    local zone="${2:-${OVH_ZONE:-astroport.one}}"
    local sub
    sub=$(_norm_sub "$raw_sub")
    _load_credentials || return 1
    echo "## DELETE ${sub}.${zone}"
    local record_id
    record_id=$(_get_record_id "$sub" "$zone") || return 1
    if [[ -z "$record_id" ]]; then
        echo "WARN: record ${sub}.${zone} introuvable — rien à supprimer"
        return 0
    fi
    local resp
    resp=$(_ovh_api DELETE "/domain/zone/${zone}/record/${record_id}") || return 1
    if printf '%s' "$resp" | grep -q '"message"'; then
        echo "ERROR OVH API (DELETE): ${resp}" >&2; return 1
    fi
    _ovh_api POST "/domain/zone/${zone}/refresh" > /dev/null
    echo "OK: record ${sub}.${zone} supprimé"
}

_usage() {
    cat >&2 <<'EOF'
ovh.me.sh — CLI DNSLink OVH pour UPlanet / Astroport.ONE

Usage : ovh.me.sh <commande> [args...]

Commandes :
  list   [zone]                   liste tous les _dnslink.* de la zone
  get    <sub> [zone]             affiche le record TXT
  create <sub> <target> [zone]    crée un record TXT (erreur si existant)
  update <sub> <target> [zone]    met à jour (erreur si absent)
  upsert <sub> <target> [zone]    crée ou met à jour (recommandé)
  delete <sub> [zone]             supprime un record TXT

  zone (optionnel) : astroport.one par défaut, ou OVH_ZONE env var

Normalisation des sous-domaines :
  alice           → _dnslink.alice
  _dnslink        → _dnslink
  _dnslink.origin → _dnslink.origin

Normalisation des targets :
  /ipns/k51q...   → dnslink=/ipns/k51q...
  /ipfs/Qm...     → dnslink=/ipfs/Qm...
  k51q...         → dnslink=/ipns/k51q...
  QmXxx...        → dnslink=/ipfs/QmXxx...

Exemples :
  ovh.me.sh upsert alice /ipns/k51q...
  ovh.me.sh upsert _dnslink /ipfs/QmEARTH...
  ovh.me.sh list
  ovh.me.sh list monautrezone.fr
  ovh.me.sh get alice
  ovh.me.sh delete alice
EOF
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
case "${1:-}" in
    list)   shift; cmd_list   "$@" ;;
    get)    shift; cmd_get    "$@" ;;
    create) shift; cmd_create "$@" ;;
    update) shift; cmd_update "$@" ;;
    upsert) shift; cmd_upsert "$@" ;;
    delete) shift; cmd_delete "$@" ;;
    *)      _usage; exit 1 ;;
esac
