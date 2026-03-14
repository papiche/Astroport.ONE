#!/bin/bash
######################################################################## setup_npm.sh
# Nginx Proxy Manager: deploy + auto-configure proxy hosts with SSL
# Called by setup.sh after .env generation
# - copylaradio.com: skip (SSL managed centrally by support@qo-op.com)
# - Local domains (.local, LAN IPs): self-signed certificates
# - Public domains: Let's Encrypt certificates
# Requires: docker, docker-compose
# License: AGPL-3.0
########################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"

NPM_DIR="$HOME/.zen/nginx-proxy-manager"
NPM_COMPOSE_STANDALONE="${MY_PATH}/../../_DOCKER/nginx-proxy-manager/docker-compose.yml"
SELF_SIGNED_DIR="${NPM_DIR}/self-signed"

## Detect NPM URL: inside docker-compose (container name "npm") or localhost
if getent hosts npm >/dev/null 2>&1; then
    NPM_URL="http://npm:81"       # Docker network (astronet)
elif curl -sf http://127.0.0.1:81 >/dev/null 2>&1; then
    NPM_URL="http://127.0.0.1:81" # Already running on host
else
    NPM_URL="http://127.0.0.1:81" # Will be started below
fi
NPM_API="${NPM_URL}/api"

## Source .env for domain config
[[ -s "$HOME/.zen/Astroport.ONE/.env" ]] && source "$HOME/.zen/Astroport.ONE/.env"

## Extract domain from myIPFS (https://ipfs.DOMAIN -> DOMAIN)
DOMAIN=$(echo "$myIPFS" | sed 's|https://ipfs\.||;s|http://.*||')
[[ -z "$DOMAIN" || "$DOMAIN" == "$myIPFS" ]] && echo "ERROR: Cannot extract domain from myIPFS=$myIPFS" && exit 1

## Skip for copylaradio.com root domain (SSL managed centrally by support@qo-op.com)
## But allow subdomains like NODEoo.copylaradio.com for automatic installations
if [[ "$DOMAIN" == "copylaradio.com" ]]; then
    echo "SKIP NPM: domain copylaradio.com — SSL managed by support@qo-op.com"
    echo ">>> Using public gateways: ipfs/relay/u/astroport.copylaradio.com"
    exit 0
fi

## For NODEoo.copylaradio.com subdomains, use self-signed certs
## (SSL will be managed by the central copylaradio.com infrastructure)
if [[ "$DOMAIN" == *".copylaradio.com" ]]; then
    echo ">>> Subdomain of copylaradio.com detected: ${DOMAIN}"
    echo ">>> Using self-signed certificates (SSL termination at central infrastructure)"
    SSL_MODE="selfsigned"
fi

## Detect SSL mode: self-signed for local, letsencrypt for public
SSL_MODE="letsencrypt"
if echo "$DOMAIN" | grep -qE '\.(local|localhost)$|^127\.|^192\.168\.|^10\.|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-1]\.'; then
    SSL_MODE="selfsigned"
fi

echo "#############################################"
echo "## NGINX PROXY MANAGER SETUP"
echo "## Domain: ${DOMAIN}"
echo "## SSL: ${SSL_MODE}"
echo "#############################################"

########################################################################
## 1. GENERATE SELF-SIGNED CERTIFICATES (if needed)
########################################################################
generate_selfsigned_cert() {
    local fqdn="$1"
    local cert_dir="${SELF_SIGNED_DIR}/${fqdn}"

    if [[ -s "${cert_dir}/fullchain.pem" && -s "${cert_dir}/privkey.pem" ]]; then
        echo "  CERT ${fqdn}: already exists"
        return 0
    fi

    mkdir -p "${cert_dir}"

    ## Generate CA + cert for wildcard + specific FQDN
    openssl req -x509 -newkey rsa:2048 -nodes \
        -keyout "${cert_dir}/privkey.pem" \
        -out "${cert_dir}/fullchain.pem" \
        -days 3650 \
        -subj "/CN=${fqdn}/O=Astroport.ONE/C=FR" \
        -addext "subjectAltName=DNS:${fqdn},DNS:*.${DOMAIN}" \
        2>/dev/null

    if [[ $? -eq 0 ]]; then
        echo "  CERT ${fqdn}: self-signed (10 years)"
    else
        echo "  CERT ${fqdn}: FAILED"
        return 1
    fi
}

########################################################################
## 2. DEPLOY NPM CONTAINER (bare metal only — in docker-compose, NPM is a sibling)
########################################################################
if getent hosts npm >/dev/null 2>&1; then
    echo ">>> NPM available via Docker network (astronet)"
elif docker ps --format '{{.Image}}' | grep -q 'nginx-proxy-manager'; then
    echo ">>> NPM already running"
elif [[ -f "${NPM_COMPOSE_STANDALONE}" ]]; then
    echo ">>> Starting Nginx Proxy Manager (standalone)..."
    mkdir -p "${NPM_DIR}/data" "${NPM_DIR}/letsencrypt"
    docker compose -f "${NPM_COMPOSE_STANDALONE}" up -d
    [[ $? -ne 0 ]] && echo "ERROR: docker compose failed" && exit 1
else
    echo "ERROR: NPM not running and no compose file found"
    exit 1
fi

## Wait for NPM API to be ready (max 60s)
echo -n "Waiting for NPM API"
for i in $(seq 1 30); do
    if curl -s -o /dev/null -w '%{http_code}' "${NPM_API}/tokens" 2>/dev/null | grep -q '401\|405\|200'; then
        echo " OK"
        break
    fi
    echo -n "."
    sleep 2
done

########################################################################
## 3. AUTHENTICATE (default credentials on first run)
########################################################################
NPM_TOKEN_FILE="${NPM_DIR}/data/.api_token"

npm_auth() {
    local email="$1" password="$2"
    curl -s -X POST "${NPM_API}/tokens" \
        -H "Content-Type: application/json" \
        -d "{\"identity\":\"${email}\",\"secret\":\"${password}\"}" \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null
}

## Try existing token
TOKEN=""
if [[ -s "${NPM_TOKEN_FILE}" ]]; then
    TOKEN=$(cat "${NPM_TOKEN_FILE}")
    ## Validate token
    HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' "${NPM_API}/users" \
        -H "Authorization: Bearer ${TOKEN}" 2>/dev/null)
    [[ "$HTTP_CODE" != "200" ]] && TOKEN=""
fi

## Try default credentials (first install)
if [[ -z "$TOKEN" ]]; then
    TOKEN=$(npm_auth "admin@example.com" "changeme")
    if [[ -n "$TOKEN" ]]; then
        echo ">>> Authenticated with default credentials"
        ## Change default admin email and password
        NPM_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
        ADMIN_EMAIL="${CAPTAINEMAIL:-admin@${DOMAIN}}"

        ## Get admin user ID
        ADMIN_ID=$(curl -s "${NPM_API}/users" \
            -H "Authorization: Bearer ${TOKEN}" \
            | python3 -c "import sys,json; users=json.load(sys.stdin); print(users[0]['id'] if users else '')" 2>/dev/null)

        if [[ -n "$ADMIN_ID" ]]; then
            ## Update admin credentials
            curl -s -X PUT "${NPM_API}/users/${ADMIN_ID}" \
                -H "Authorization: Bearer ${TOKEN}" \
                -H "Content-Type: application/json" \
                -d "{\"name\":\"Captain\",\"nickname\":\"captain\",\"email\":\"${ADMIN_EMAIL}\"}" > /dev/null

            curl -s -X PUT "${NPM_API}/users/${ADMIN_ID}/auth" \
                -H "Authorization: Bearer ${TOKEN}" \
                -H "Content-Type: application/json" \
                -d "{\"type\":\"password\",\"current\":\"changeme\",\"secret\":\"${NPM_PASS}\"}" > /dev/null

            ## Re-authenticate with new credentials
            TOKEN=$(npm_auth "${ADMIN_EMAIL}" "${NPM_PASS}")
            echo ">>> Admin updated: ${ADMIN_EMAIL}"
            echo ">>> NPM password saved to ${NPM_DIR}/data/.admin_pass"
            echo "${NPM_PASS}" > "${NPM_DIR}/data/.admin_pass"
            chmod 600 "${NPM_DIR}/data/.admin_pass"
        fi
    fi
fi

if [[ -z "$TOKEN" ]]; then
    ## Try with saved password
    if [[ -s "${NPM_DIR}/data/.admin_pass" ]]; then
        ADMIN_EMAIL="${CAPTAINEMAIL:-admin@${DOMAIN}}"
        NPM_PASS=$(cat "${NPM_DIR}/data/.admin_pass")
        TOKEN=$(npm_auth "${ADMIN_EMAIL}" "${NPM_PASS}")
    fi
fi

if [[ -z "$TOKEN" ]]; then
    echo "ERROR: Cannot authenticate to NPM API"
    echo ">>> Access ${NPM_URL} and configure manually"
    exit 1
fi

## Save token for reuse
echo "${TOKEN}" > "${NPM_TOKEN_FILE}"
chmod 600 "${NPM_TOKEN_FILE}"

########################################################################
## 4. UPLOAD SELF-SIGNED CERTIFICATE TO NPM (returns cert ID)
########################################################################
npm_upload_selfsigned() {
    local fqdn="$1"
    local cert_dir="${SELF_SIGNED_DIR}/${fqdn}"

    ## Check if certificate already uploaded
    EXISTING_CERT=$(curl -s "${NPM_API}/nginx/certificates" \
        -H "Authorization: Bearer ${TOKEN}" \
        | python3 -c "
import sys,json
certs=json.load(sys.stdin)
for c in certs:
    if c.get('nice_name','') == 'selfsigned-${fqdn}':
        print(c['id'])
        break
" 2>/dev/null)

    if [[ -n "$EXISTING_CERT" ]]; then
        echo "$EXISTING_CERT"
        return 0
    fi

    ## Upload via multipart form
    CERT_ID=$(curl -s -X POST "${NPM_API}/nginx/certificates" \
        -H "Authorization: Bearer ${TOKEN}" \
        -F "nice_name=selfsigned-${fqdn}" \
        -F "certificate=@${cert_dir}/fullchain.pem" \
        -F "certificate_key=@${cert_dir}/privkey.pem" \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

    echo "$CERT_ID"
}

########################################################################
## 5. CREATE PROXY HOSTS WITH SSL
########################################################################

npm_create_proxy() {
    local subdomain="$1" forward_host="$2" forward_port="$3" scheme="${4:-http}" websocket="${5:-false}" advanced="${6:-}"

    local fqdn="${subdomain}.${DOMAIN}"

    ## Check if proxy already exists
    EXISTING=$(curl -s "${NPM_API}/nginx/proxy-hosts" \
        -H "Authorization: Bearer ${TOKEN}" \
        | python3 -c "
import sys,json
hosts=json.load(sys.stdin)
for h in hosts:
    if '${fqdn}' in h.get('domain_names',[]):
        print(h['id'])
        break
" 2>/dev/null)

    if [[ -n "$EXISTING" ]]; then
        echo "  SKIP ${fqdn} (already configured, id=${EXISTING})"
        return 0
    fi

    echo -n "  CREATE ${fqdn} -> ${scheme}://${forward_host}:${forward_port} "

    ## Build SSL config based on mode
    local cert_id="0"
    local ssl_forced="false"
    local meta="{}"

    if [[ "$SSL_MODE" == "letsencrypt" ]]; then
        echo -n "[Let's Encrypt] ... "
        cert_id="\"new\""
        ssl_forced="true"
        meta="{
            \"letsencrypt_agree\": true,
            \"letsencrypt_email\": \"${ADMIN_EMAIL}\",
            \"dns_challenge\": false
        }"
    elif [[ "$SSL_MODE" == "selfsigned" ]]; then
        echo -n "[self-signed] ... "
        ## Generate self-signed cert for this FQDN
        generate_selfsigned_cert "${fqdn}"
        ## Upload to NPM and get cert ID
        cert_id=$(npm_upload_selfsigned "${fqdn}")
        if [[ -n "$cert_id" && "$cert_id" != "None" && "$cert_id" != "" ]]; then
            ssl_forced="true"
        else
            echo "WARN: cert upload failed, creating proxy without SSL"
            cert_id="0"
        fi
        meta="{}"
    fi

    ## Escape advanced_config for JSON
    local advanced_escaped=""
    if [[ -n "$advanced" ]]; then
        advanced_escaped=$(echo "$advanced" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' '\n' | sed ':a;N;$!ba;s/\n/\\n/g')
    fi

    RESULT=$(curl -s -X POST "${NPM_API}/nginx/proxy-hosts" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"domain_names\": [\"${fqdn}\"],
            \"forward_host\": \"${forward_host}\",
            \"forward_port\": ${forward_port},
            \"forward_scheme\": \"${scheme}\",
            \"access_list_id\": 0,
            \"certificate_id\": ${cert_id},
            \"ssl_forced\": ${ssl_forced},
            \"http2_support\": true,
            \"hsts_enabled\": false,
            \"hsts_subdomains\": false,
            \"block_exploits\": true,
            \"allow_websocket_upgrade\": ${websocket},
            \"meta\": ${meta},
            \"locations\": [],
            \"advanced_config\": \"${advanced_escaped}\"
        }")

    ## Check result
    PROXY_ID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
    if [[ -n "$PROXY_ID" && "$PROXY_ID" != "None" ]]; then
        echo "OK (id=${PROXY_ID})"
    else
        ERROR=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error',{}).get('message','unknown'))" 2>/dev/null)
        echo "FAILED: ${ERROR}"
    fi
}

## Detect forward host:
## - Docker compose (astronet): use container name "astroport"
## - Bare metal with Docker NPM: use docker bridge gateway
## - Bare metal without Docker: use 127.0.0.1
if getent hosts astroport >/dev/null 2>&1; then
    FORWARD_HOST="astroport"  ## Docker network (astronet) — container name
elif docker ps --format '{{.Image}}' | grep -q 'nginx-proxy-manager'; then
    FORWARD_HOST="172.17.0.1"  ## Docker bridge gateway (host from NPM container)
    BRIDGE_GW=$(docker inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null)
    [[ -n "$BRIDGE_GW" ]] && FORWARD_HOST="$BRIDGE_GW"
else
    FORWARD_HOST="127.0.0.1"
fi

ADMIN_EMAIL="${CAPTAINEMAIL:-admin@${DOMAIN}}"

echo ">>> Creating proxy hosts for ${DOMAIN} [${SSL_MODE}]..."
echo ">>> Forward to host: ${FORWARD_HOST}"

## astroport.DOMAIN -> :12345 (Station Map / swarm discovery)
npm_create_proxy "astroport" "${FORWARD_HOST}" 12345 "http" "false"

## ipfs.DOMAIN -> :8080 (IPFS Gateway) + /12345/ -> :12345 (swarm discovery)
## The /12345/ location allows inter-station UPSYNC via https://ipfs.DOMAIN/12345/?G1PUB=IPFSNODEID
IPFS_ADVANCED="location /12345/ {
    proxy_pass http://${FORWARD_HOST}:12345/;
}"
npm_create_proxy "ipfs" "${FORWARD_HOST}" 8080 "http" "false" "$IPFS_ADVANCED"

## relay.DOMAIN -> :7777 (NOSTR strfry relay - WebSocket)
npm_create_proxy "relay" "${FORWARD_HOST}" 7777 "http" "true"

## u.DOMAIN -> :54321 (UPassport FastAPI)
npm_create_proxy "u" "${FORWARD_HOST}" 54321 "http" "true"

## cloud.DOMAIN -> nextcloud:8001 (NextCloud AIO, if running)
if getent hosts nextcloud-aio-mastercontainer >/dev/null 2>&1; then
    npm_create_proxy "cloud" "nextcloud-aio-mastercontainer" 8001 "http" "false"
elif docker ps --format '{{.Names}}' | grep -q 'nextcloud-aio'; then
    npm_create_proxy "cloud" "${FORWARD_HOST}" 8001 "http" "false"
else
    echo "  SKIP cloud.${DOMAIN} (NextCloud not running)"
    echo "  >>> Start with: docker compose --profile full up -d"
fi

echo "#############################################"
echo "## NPM SETUP COMPLETE"
echo "## Admin UI: ${NPM_URL}"
echo "## SSL mode: ${SSL_MODE}"
echo "## Proxied: astroport/ipfs/relay/u .${DOMAIN}"
echo "#############################################"
