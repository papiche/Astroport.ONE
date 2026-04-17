#!/bin/bash
######################################################################## setup_npm_dynamic.sh
# Crée dynamiquement un proxy host NPM pour un service de tunnel P2P.
# Appelé par astrosystemctl après ouverture d'un tunnel, pour que
# le service soit accessible via un sous-domaine (service.DOMAIN).
#
# Usage : setup_npm_dynamic.sh <SERVICE_NAME> <LOCAL_PORT> [FORWARD_HOST]
# Exemple: setup_npm_dynamic.sh ollama 11434
#          → crée https://ollama.DOMAIN → 127.0.0.1:11434
#
# Licence : AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################

_SCRIPT="$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")"
MY_PATH="$(dirname "$_SCRIPT")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

SERVICE_NAME="${1:-}"
LOCAL_PORT="${2:-}"
FORWARD_OVERRIDE="${3:-}"

if [[ -z "$SERVICE_NAME" || -z "$LOCAL_PORT" ]]; then
    echo "Usage: $0 <SERVICE_NAME> <LOCAL_PORT> [FORWARD_HOST]"
    echo "  ex:  $0 ollama 11434"
    echo "  ex:  $0 comfyui 8188 127.0.0.1"
    exit 1
fi

# ── Config NPM ────────────────────────────────────────────────────────────────
NPM_DIR="$HOME/.zen/nginx-proxy-manager"
[[ -s "$HOME/.zen/Astroport.ONE/.env" ]] && source "$HOME/.zen/Astroport.ONE/.env"

DOMAIN=$(echo "${myIPFS:-}" | sed 's|https://ipfs\.||;s|http://.*||')
[[ -z "$DOMAIN" || "$DOMAIN" == "${myIPFS:-}" ]] && DOMAIN="${myDOMAIN:-localhost}"

# Pas de proxy dynamique sur copylaradio.com racine (SSL géré centralement)
if [[ "$DOMAIN" == "copylaradio.com" ]]; then
    echo "SKIP: domaine copylaradio.com — proxy dynamique non géré ici"
    exit 0
fi

# ── Détection URL NPM ─────────────────────────────────────────────────────────
if getent hosts npm >/dev/null 2>&1; then
    NPM_URL="http://npm:81"
elif curl -sf --max-time 3 http://127.0.0.1:81 >/dev/null 2>&1; then
    NPM_URL="http://127.0.0.1:81"
else
    echo "⚠️  NPM non accessible (port 81 fermé) — proxy non créé"
    exit 1
fi
NPM_API="${NPM_URL}/api"

# ── Authentification NPM ─────────────────────────────────────────────────────
NPM_TOKEN_FILE="${NPM_DIR}/data/.api_token"
TOKEN=""

if [[ -s "$NPM_TOKEN_FILE" ]]; then
    TOKEN=$(cat "$NPM_TOKEN_FILE")
    HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' \
        "$NPM_API/users" -H "Authorization: Bearer $TOKEN" 2>/dev/null)
    [[ "$HTTP_CODE" != "200" ]] && TOKEN=""
fi

if [[ -z "$TOKEN" ]] && [[ -s "${NPM_DIR}/data/.admin_pass" ]]; then
    NPM_PASS=$(cat "${NPM_DIR}/data/.admin_pass")
    TOKEN=$(curl -s -X POST "$NPM_API/tokens" \
        -H "Content-Type: application/json" \
        -d "{\"identity\":\"support@qo-op.com\",\"secret\":\"${NPM_PASS}\"}" \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null)
    [[ -n "$TOKEN" ]] && echo "$TOKEN" > "$NPM_TOKEN_FILE" && chmod 600 "$NPM_TOKEN_FILE"
fi

if [[ -z "$TOKEN" ]]; then
    echo "⚠️  Authentification NPM échouée — proxy non créé"
    exit 1
fi

# ── Mode SSL ─────────────────────────────────────────────────────────────────
SSL_MODE="letsencrypt"
if [[ "$DOMAIN" == *".copylaradio.com" ]] || \
   echo "$DOMAIN" | grep -qE '\.(local|localhost)$|^127\.|^192\.168\.|^10\.|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-1]\.'; then
    SSL_MODE="selfsigned"
fi

# ── Détection forward host ────────────────────────────────────────────────────
if [[ -n "$FORWARD_OVERRIDE" ]]; then
    FORWARD_HOST="$FORWARD_OVERRIDE"
elif getent hosts astroport >/dev/null 2>&1; then
    FORWARD_HOST="astroport"
elif docker ps --format '{{.Image}}' 2>/dev/null | grep -q 'nginx-proxy-manager'; then
    BRIDGE_GW=$(docker inspect bridge \
        --format '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null)
    FORWARD_HOST="${BRIDGE_GW:-172.17.0.1}"
else
    FORWARD_HOST="127.0.0.1"
fi

FQDN="${SERVICE_NAME}.${DOMAIN}"

# ── Vérification existence ────────────────────────────────────────────────────
EXISTING=$(curl -s "$NPM_API/nginx/proxy-hosts" \
    -H "Authorization: Bearer $TOKEN" \
    | python3 -c "
import sys,json
hosts=json.load(sys.stdin)
for h in hosts:
    if '${FQDN}' in h.get('domain_names',[]):
        print(h['id'])
        break
" 2>/dev/null)

if [[ -n "$EXISTING" ]]; then
    echo "ℹ️  Proxy ${FQDN} déjà configuré (id=${EXISTING})"
    exit 0
fi

# ── Certificat ───────────────────────────────────────────────────────────────
CERT_ID="0"
SSL_FORCED="false"
META="{}"

if [[ "$SSL_MODE" == "selfsigned" ]]; then
    SELF_SIGNED_DIR="${NPM_DIR}/self-signed"
    CERT_DIR="${SELF_SIGNED_DIR}/${FQDN}"
    mkdir -p "$CERT_DIR"

    if [[ ! -s "${CERT_DIR}/fullchain.pem" ]]; then
        openssl req -x509 -newkey rsa:2048 -nodes \
            -keyout "${CERT_DIR}/privkey.pem" \
            -out    "${CERT_DIR}/fullchain.pem" \
            -days 3650 \
            -subj "/CN=${FQDN}/O=Astroport.ONE/C=FR" \
            -addext "subjectAltName=DNS:${FQDN},DNS:*.${DOMAIN}" \
            2>/dev/null && echo "  Certificat auto-signé généré pour ${FQDN}"
    fi

    CERT_ID=$(curl -s -X POST "$NPM_API/nginx/certificates" \
        -H "Authorization: Bearer $TOKEN" \
        -F "nice_name=selfsigned-${FQDN}" \
        -F "certificate=@${CERT_DIR}/fullchain.pem" \
        -F "certificate_key=@${CERT_DIR}/privkey.pem" \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
    [[ -n "$CERT_ID" && "$CERT_ID" != "None" ]] && SSL_FORCED="true" || CERT_ID="0"

elif [[ "$SSL_MODE" == "letsencrypt" ]]; then
    CERT_ID='"new"'
    SSL_FORCED="true"
    META='{"letsencrypt_agree":true,"letsencrypt_email":"support@qo-op.com","dns_challenge":false}'
fi

# ── WebSocket (services streaming/API) ───────────────────────────────────────
WEBSOCKET="false"
case "$SERVICE_NAME" in
    ollama|open_webui|webui|nostr|relay|comfyui|dify) WEBSOCKET="true" ;;
esac

# ── Création proxy ────────────────────────────────────────────────────────────
echo -n "  CREATE ${FQDN} → ${FORWARD_HOST}:${LOCAL_PORT} [${SSL_MODE}] ... "

RESULT=$(curl -s -X POST "$NPM_API/nginx/proxy-hosts" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"domain_names\": [\"${FQDN}\"],
        \"forward_host\": \"${FORWARD_HOST}\",
        \"forward_port\": ${LOCAL_PORT},
        \"forward_scheme\": \"http\",
        \"access_list_id\": 0,
        \"certificate_id\": ${CERT_ID},
        \"ssl_forced\": ${SSL_FORCED},
        \"http2_support\": true,
        \"hsts_enabled\": false,
        \"hsts_subdomains\": false,
        \"block_exploits\": true,
        \"allow_websocket_upgrade\": ${WEBSOCKET},
        \"meta\": ${META},
        \"locations\": [],
        \"advanced_config\": \"\"
    }")

PROXY_ID=$(echo "$RESULT" | \
    python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

if [[ -n "$PROXY_ID" && "$PROXY_ID" != "None" ]]; then
    echo "OK (id=${PROXY_ID})"
    echo "✅ https://${FQDN} → localhost:${LOCAL_PORT}"
else
    ERROR=$(echo "$RESULT" | \
        python3 -c "import sys,json; print(json.load(sys.stdin).get('error',{}).get('message','?'))" 2>/dev/null)
    echo "FAILED: ${ERROR}"
    exit 1
fi
