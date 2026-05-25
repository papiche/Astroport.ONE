#!/bin/bash
########################################################################
# nextcloud_bro_sync.sh — Synchronisation NextCloud/Astroport → #BRO
#
# Ce script synchronise les documents du dossier NextCloud "Astroport"
# (ou tout autre dossier de connaissance) vers Qdrant via Ollama,
# permettant à #BRO de répondre aux questions de la constellation.
#
# Architecture :
#   NextCloud /Astroport/  ─[WebDAV]─→  Fichiers locaux
#         ↓ (modifications)
#   Ollama nomic-embed-text ──────────→  Vecteurs 768d
#         ↓
#   Qdrant "nextcloud_kb"  ──[query]─→  #BRO / OpenWebUI / code_assistant
#
# Usage :
#   nextcloud_bro_sync.sh               # sync incrémentale
#   nextcloud_bro_sync.sh --full        # réindexation complète
#   nextcloud_bro_sync.sh --query "ma question"  # requête directe
#
# Prérequis :
#   - Ollama (port 11434) avec nomic-embed-text
#   - Qdrant (port 6333)
#   - curl, python3 (pour les requêtes WebDAV et embeddings)
#
# Stdout / Stderr :
#   --query  → stdout = réponse IA uniquement (pour capture dans les scripts)
#              stderr = logs de diagnostic
#   autres   → stdout = logs interactifs (tee → fichier)
########################################################################

MY_PATH="$(dirname "$(realpath "$0")")"
. "${HOME}/.zen/Astroport.ONE/tools/my.sh" 2>/dev/null || true

## ── Configuration ─────────────────────────────────────────────────────
NC_WEBDAV_BASE="${NC_WEBDAV_URL:-http://127.0.0.1:8001/remote.php/dav/files}"
NC_USER="${NC_USERNAME:-admin}"
NC_PASS_FILE="${NC_PASS_FILE:-$HOME/.zen/nginx-proxy-manager/data/.nextcloud_admin_pass}"
NC_COLLECTION_PATH="${NC_COLLECTION:-Astroport}"
QDRANT_URL="${QDRANT_URL:-http://127.0.0.1:6333}"
QDRANT_COLLECTION="nextcloud_kb"
OLLAMA_URL="${OLLAMA_URL:-http://127.0.0.1:11434}"

## ── Clé API Qdrant = UPLANETNAME (cohérence de constellation) ────────
## UPLANETNAME identifie l'essaim UPlanet ẐEN → clé partagée par toutes stations
## Cela permet à nextcloud_bro_sync.sh de se connecter à TOUT Qdrant de la constellation
## (même sur SSH tunnel ou IPFS P2P via ollama.me.sh)
QDRANT_API_KEY="${QDRANT_API_KEY:-}"
if [[ -z "$QDRANT_API_KEY" ]]; then
    ## Priorité 1 : UPLANETNAME (depuis my.sh, source de vérité constellation)
    [[ -n "${UPLANETNAME:-}" ]] && QDRANT_API_KEY="$UPLANETNAME"
fi
if [[ -z "$QDRANT_API_KEY" ]]; then
    ## Priorité 2 : .env ai-company (fallback si UPLANETNAME absent)
    _AI_ENV="$HOME/.zen/ai-company/.env"
    [[ -s "$_AI_ENV" ]] && QDRANT_API_KEY=$(grep '^QDRANT_API_KEY=' "$_AI_ENV" 2>/dev/null | cut -d'=' -f2)
fi
## En-tête curl Qdrant (vide si pas de clé — Qdrant sans auth)
_QDRANT_AUTH=()
if [[ -n "$QDRANT_API_KEY" ]]; then
    _QDRANT_AUTH=(-H "api-key: $QDRANT_API_KEY")
fi
EMBED_MODEL="nomic-embed-text"
CACHE_DIR="$HOME/.zen/tmp/nextcloud_sync"
SYNC_LOG="$HOME/.zen/tmp/nextcloud_sync.log"

mkdir -p "$CACHE_DIR"

## ── Fonctions de log ─────────────────────────────────────────────────
## Toutes les sorties de diagnostic vont sur stderr + fichier log.
## Seule _query_knowledge émet la réponse finale sur stdout.
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC_C='\033[0m'
_log_file() { echo "[$(date '+%H:%M:%S')] $*" >> "$SYNC_LOG"; }
ok()   { echo -e "${GREEN}✅ $*${NC_C}" >&2; _log_file "OK: $*"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC_C}" >&2; _log_file "WARN: $*"; }
err()  { echo -e "${RED}❌ $*${NC_C}" >&2; _log_file "ERR: $*"; }
info() { echo -e "${CYAN}ℹ️  $*${NC_C}" >&2; _log_file "INFO: $*"; }

## ── Lecture du mot de passe NextCloud ────────────────────────────────
NC_PASSWORD=""
if [[ -s "$NC_PASS_FILE" ]]; then
    NC_PASSWORD=$(cat "$NC_PASS_FILE")
elif [[ -n "${NC_PASSWORD_ENV:-}" ]]; then
    NC_PASSWORD="$NC_PASSWORD_ENV"
else
    warn "Mot de passe NextCloud non trouvé dans $NC_PASS_FILE"
    info "Définissez NC_PASSWORD_ENV ou créez $NC_PASS_FILE"
fi

## ── Fichier netrc temporaire (évite l'exposition de NC_PASSWORD dans ps aux) ──
_NC_NETRC=""
if [[ -n "$NC_PASSWORD" ]]; then
    _NC_NETRC=$(mktemp -t nc_netrc_XXXXXX)
    chmod 600 "$_NC_NETRC"
    printf 'machine 127.0.0.1\nlogin %s\npassword %s\n' "$NC_USER" "$NC_PASSWORD" > "$_NC_NETRC"
    trap 'rm -f "$_NC_NETRC"' EXIT
fi

## ── Résolution Ollama via ollama.me.sh (local ou P2P Swarm) ─────────
## ollama.me.sh établit un tunnel sur :
##   - 127.0.0.1:11434        (accès depuis l'hôte)
##   - ${DOCKER_BRIDGE_IP}:11434  (accès depuis les conteneurs Docker)
_ensure_ollama() {
    ## Vérifier si Ollama est déjà accessible via l'API HTTP
    if curl -sf --max-time 2 "$OLLAMA_URL/api/tags" &>/dev/null; then
        _CONN_STATUS_FILE="$HOME/.zen/tmp/ollama_connection.status"
        if [[ -s "$_CONN_STATUS_FILE" ]]; then
            _CONN_TYPE=$(grep '^CONNECTION_TYPE=' "$_CONN_STATUS_FILE" | cut -d'=' -f2)
            ok "Ollama accessible ($_CONN_TYPE) — $OLLAMA_URL"
        else
            ok "Ollama accessible — $OLLAMA_URL"
        fi
        return 0
    fi

    ## Ollama non accessible — lancer ollama.me.sh pour établir la connexion
    info "Ollama non accessible localement — tentative de connexion P2P via ollama.me.sh..."
    local OLLAMA_STARTER="$MY_PATH/../services/ollama.me.sh"
    if [[ -x "$OLLAMA_STARTER" ]]; then
        bash "$OLLAMA_STARTER" &>/dev/null &
        ## Attendre jusqu'à 20 secondes
        echo -n "  Attente Ollama" >&2
        for _i in $(seq 1 20); do
            sleep 1; echo -n "." >&2
            curl -sf --max-time 1 "$OLLAMA_URL/api/tags" &>/dev/null && { echo " ✅" >&2; return 0; }
        done
        echo "" >&2
        warn "Ollama non accessible après 20s (local + P2P)"
    else
        err "ollama.me.sh introuvable ($OLLAMA_STARTER)"
    fi

    ## Dernier recours : astrosystemctl connect ollama (Brain node constellation 🔥)
    ## Connecte dynamiquement un nœud GPU distant via tunnel IPFS P2P
    if command -v astrosystemctl &>/dev/null; then
        info "Tentative via astrosystemctl (Brain node constellation)..."
        astrosystemctl connect ollama 2>/dev/null &
        for _i in $(seq 1 10); do
            sleep 2
            curl -sf --max-time 1 "$OLLAMA_URL/api/tags" &>/dev/null && { ok "Ollama via Brain node ✅" >&2; return 0; }
        done
        warn "Aucun Brain node disponible dans la constellation"
    fi

    err "Ollama non accessible (local + P2P + constellation) — embeddings désactivés"
    return 1
}

## ── Vérifications préalables ─────────────────────────────────────────
_check_services() {
    local _ok=true
    if ! _ensure_ollama; then
        _ok=false
    fi
    if ! curl -sf --max-time 3 "${_QDRANT_AUTH[@]}" "$QDRANT_URL/collections" &>/dev/null; then
        err "Qdrant non accessible ($QDRANT_URL)"
        _ok=false
    fi
    [[ "$_ok" == "true" ]]
}

## ── Création de la collection Qdrant ─────────────────────────────────
_ensure_qdrant_collection() {
    local existing
    existing=$(curl -sf "${_QDRANT_AUTH[@]}" "$QDRANT_URL/collections/$QDRANT_COLLECTION" 2>/dev/null)
    if echo "$existing" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('result') else 1)" 2>/dev/null; then
        info "Collection Qdrant '$QDRANT_COLLECTION' existe"
    else
        info "Création de la collection Qdrant '$QDRANT_COLLECTION' (768d nomic)..."
        curl -sf -X PUT "$QDRANT_URL/collections/$QDRANT_COLLECTION" \
            "${_QDRANT_AUTH[@]}" \
            -H "Content-Type: application/json" \
            -d '{"vectors":{"size":768,"distance":"Cosine"}}' \
            | python3 -c "import sys,json; r=json.load(sys.stdin); print('✅ Collection créée' if r.get('result') else '❌ Erreur: '+str(r), file=sys.stderr)" 2>/dev/null
    fi
}

## ── Génération d'un embedding via Ollama ────────────────────────────
_embed_text() {
    local text="$1"
    local prompt_json
    prompt_json=$(python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$text")
    curl -sf -X POST "$OLLAMA_URL/api/embeddings" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$EMBED_MODEL\",\"prompt\":$prompt_json}" \
        | python3 -c "import sys,json; d=json.load(sys.stdin); print(' '.join(map(str,d.get('embedding',[]))))" 2>/dev/null
}

## ── Indexation d'un fichier dans Qdrant ─────────────────────────────
_index_document() {
    local filepath="$1"
    local filename
    filename=$(basename "$filepath")
    local extension="${filename##*.}"
    local content=""

    ## Extraction du texte selon le type de fichier
    ## Les chemins sont passés via variable d'env pour éviter l'injection dans python3 -c
    case "${extension,,}" in
        pdf)
            command -v pdftotext &>/dev/null \
                && content=$(pdftotext "$filepath" - 2>/dev/null | head -c 8000) \
                || content=$(FPATH="$filepath" python3 -c "
import subprocess, os
r = subprocess.run(['pdftotext', os.environ['FPATH'], '-'], capture_output=True, text=True)
print(r.stdout[:8000])" 2>/dev/null)
            ;;
        md|txt|rst)
            content=$(head -c 8000 "$filepath")
            ;;
        docx|odt)
            command -v pandoc &>/dev/null \
                && content=$(pandoc -t plain "$filepath" 2>/dev/null | head -c 8000) \
                || content=$(FPATH="$filepath" python3 -c "
import zipfile, os
z = zipfile.ZipFile(os.environ['FPATH'])
print(z.read('word/document.xml').decode('utf-8','ignore')[:8000])" 2>/dev/null)
            ;;
        html|htm)
            content=$(FPATH="$filepath" python3 -c "
import sys, re, os
t = open(os.environ['FPATH']).read()
print(re.sub(r'<[^>]+>', '', t)[:8000])" 2>/dev/null)
            ;;
        json)
            content=$(FPATH="$filepath" python3 -c "
import json, os
d = json.load(open(os.environ['FPATH']))
print(json.dumps(d, ensure_ascii=False)[:8000])" 2>/dev/null)
            ;;
        *)
            info "Format '$extension' non supporté pour $filename — ignoré"
            return 0
            ;;
    esac

    [[ -z "$content" ]] && warn "Contenu vide pour $filename" && return 1

    ## Générer l'embedding
    local vector
    vector=$(_embed_text "$content")
    [[ -z "$vector" ]] && warn "Embedding échoué pour $filename" && return 1

    ## Identifiant stable basé sur le chemin du fichier
    local doc_id
    doc_id=$(echo "$filepath" | python3 -c "import sys,hashlib; print(int(hashlib.md5(sys.stdin.read().strip().encode()).hexdigest()[:15],16))")

    ## Sérialiser le payload via python3 pour un JSON propre (pas de sed)
    local payload_json
    payload_json=$(python3 -c "
import json, sys, os
payload = {
    'filename':        sys.argv[1],
    'filepath':        sys.argv[2],
    'extension':       sys.argv[3],
    'content_preview': sys.argv[4][:300],
    'indexed_at':      os.popen('date -u +%Y-%m-%dT%H:%M:%SZ').read().strip(),
    'source':          'nextcloud/' + sys.argv[5],
}
print(json.dumps(payload))
" "$filename" "$filepath" "$extension" "${content:0:300}" "$NC_COLLECTION_PATH")

    ## Upsert dans Qdrant
    local vector_json="[$(echo "$vector" | tr ' ' ',')]"
    curl -sf -X PUT "$QDRANT_URL/collections/$QDRANT_COLLECTION/points" \
        "${_QDRANT_AUTH[@]}" \
        -H "Content-Type: application/json" \
        -d "{\"points\":[{\"id\":$doc_id,\"vector\":$vector_json,\"payload\":$payload_json}]}" \
        | python3 -c "import sys,json; r=json.load(sys.stdin); exit(0 if r.get('result',{}).get('status')=='acknowledged' else 1)" 2>/dev/null \
        && ok "Indexé : $filename (id=$doc_id)" \
        || err "Échec indexation : $filename"
}

## ── Requête sémantique vers Qdrant ──────────────────────────────────
## stdout = réponse IA uniquement (capturée par le listener DM)
## stderr = logs de diagnostic (terminal/log fichier)
## $1 = question, $2 = user_hex (optionnel), $3 = top_k (défaut 5)
_query_knowledge() {
    local question="$1" user_hex="${2:-}" slots="${3:-0}" top_k="${4:-5}"

    info "Recherche sémantique : '$question'"
    local q_vector
    q_vector=$(_embed_text "$question")
    if [[ -z "$q_vector" ]]; then
        err "Impossible de générer l'embedding de la question"
        echo "Désolé, le service d'embeddings est temporairement indisponible."
        return 1
    fi

    local vector_json="[$(echo "$q_vector" | tr ' ' ',')]"
    local results
    results=$(curl -sf -X POST "$QDRANT_URL/collections/$QDRANT_COLLECTION/points/search" \
        "${_QDRANT_AUTH[@]}" \
        -H "Content-Type: application/json" \
        -d "{\"vector\":$vector_json,\"limit\":$top_k,\"with_payload\":true}" 2>/dev/null)

    ## Diagnostics sur stderr uniquement
    {
        echo "═══ Résultats de la base de connaissance (top $top_k) ═══"
        echo "$results" | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = data.get('result', [])
if not results:
    print('  Aucun résultat trouvé (base vide?)')
    sys.exit(0)
for i, r in enumerate(results, 1):
    p = r.get('payload', {})
    print(f'  [{i}] {p.get(\"filename\",\"?\")} (score: {r.get(\"score\",0):.3f})')
    print(f'       {p.get(\"content_preview\",\"\")[:120]}...')
" 2>/dev/null
    } >&2

    ## Extraire le contexte global (top 3 nextcloud_kb)
    local context_global
    context_global=$(echo "$results" | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = data.get('result', [])
ctx = '\n\n'.join([r.get('payload',{}).get('content_preview','') for r in results[:3]])
print(ctx[:4000])
" 2>/dev/null)

    ## Fallback : si KB vide, chercher dans docs/ locaux via grep
    if [[ -z "$context_global" ]]; then
        local _docs_dir="$MY_PATH/../../docs"
        if [[ -d "$_docs_dir" ]]; then
            warn "KB Qdrant vide — recherche textuelle dans les docs locaux (fallback)"
            context_global=$(grep -ril "$question" "$_docs_dir" 2>/dev/null \
                | head -3 \
                | while IFS= read -r f; do
                    echo "### $(basename "$f") ###"
                    grep -i -A 3 -B 1 "$question" "$f" 2>/dev/null | head -20
                    echo ""
                done | head -c 3000)
        fi
    fi

    ## Recherche dans la mémoire personnelle si user_hex fourni
    local context_personal=""
    if [[ -n "$user_hex" ]]; then
        local _mem_collection="memory_${user_hex:0:16}"
        ## Vérifier que la collection existe avant de l'interroger
        local _col_check
        _col_check=$(curl -sf "${_QDRANT_AUTH[@]}" \
            "$QDRANT_URL/collections/$_mem_collection" 2>/dev/null)
        if echo "$_col_check" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('result') else 1)" 2>/dev/null; then
            ## Construire le filtre Qdrant par slot(s)
            ## slots="0" ou "" → pas de filtre (tous les slots)
            ## slots="1,5"     → filter: slot IN [1, 5]
            local _slot_filter=""
            if [[ -n "$slots" && "$slots" != "0" ]]; then
                _slot_filter=$(python3 -c "
import sys, json
raw = sys.argv[1]
nums = [int(x) for x in raw.split(',') if x.strip().isdigit() and x.strip() != '0']
if nums:
    f = {'must': [{'key': 'slot', 'match': {'any': nums}}]}
    print(json.dumps(f))
" "$slots" 2>/dev/null)
            fi
            local _search_body
            if [[ -n "$_slot_filter" ]]; then
                _search_body="{\"vector\":$vector_json,\"limit\":5,\"with_payload\":true,\"filter\":${_slot_filter}}"
                info "Filtre mémoire slots: $slots"
            else
                _search_body="{\"vector\":$vector_json,\"limit\":3,\"with_payload\":true}"
            fi
            local personal_results
            personal_results=$(curl -sf -X POST \
                "$QDRANT_URL/collections/$_mem_collection/points/search" \
                "${_QDRANT_AUTH[@]}" \
                -H "Content-Type: application/json" \
                -d "$_search_body" 2>/dev/null)
            context_personal=$(echo "$personal_results" | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = data.get('result', [])
ctx = '\n\n'.join([r.get('payload',{}).get('content','') for r in results[:3]])
print(ctx[:2000])
" 2>/dev/null)
            {
                echo "═══ Mémoire personnelle (${_mem_collection}) ═══"
                echo "$personal_results" | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = data.get('result', [])
if not results:
    print('  Aucun souvenir personnel pertinent')
    sys.exit(0)
for i, r in enumerate(results, 1):
    p = r.get('payload', {})
    print(f'  [{i}] slot={p.get(\"slot\",\"?\")} (score: {r.get(\"score\",0):.3f})')
    print(f'       {p.get(\"content\",\"\")[:120]}...')
" 2>/dev/null
            } >&2
        fi
    fi

    ## Construire le prompt selon la disponibilité des contextes
    local prompt_text
    if [[ -z "$context_global" && -z "$context_personal" ]]; then
        warn "Aucun document pertinent trouvé dans la base de connaissance"
        echo "Aucun document pertinent n'a été trouvé dans la base de connaissance pour répondre à cette question."
        return 0
    fi

    if [[ -n "$context_personal" ]]; then
        prompt_text="Base de connaissance de la station :
${context_global:-Aucun document pertinent dans la base globale.}

Contexte personnel de l'utilisateur (ses souvenirs partagés) :
$context_personal

Question : $question

Réponds en français en tenant compte du contexte personnel si pertinent."
    else
        prompt_text="Contexte:
$context_global

Question: $question

Réponds en français en te basant sur le contexte ci-dessus. Sois concis et précis."
    fi

    ## Synthèse via API HTTP Ollama (fonctionne en local, Docker ou tunnel IPFS P2P)
    ## N'utilise PAS le binaire `ollama` — compatible picoport sans Ollama installé localement
    if curl -sf --max-time 2 "$OLLAMA_URL/api/tags" &>/dev/null; then
        info "Synthèse Ollama HTTP en cours (${OLLAMA_MODEL:-gemma3:latest})..."
        local _prompt_json
        _prompt_json=$(python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$prompt_text")
        local _response
        _response=$(curl -sf --max-time 120 \
            -X POST "$OLLAMA_URL/api/generate" \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"${OLLAMA_MODEL:-gemma3:latest}\",\"prompt\":${_prompt_json},\"stream\":false}" \
            | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('response','').strip())" 2>/dev/null)
        if [[ -n "$_response" ]]; then
            echo "$_response"
        else
            warn "Ollama HTTP : réponse vide — fallback extrait Qdrant"
            echo "$results" | python3 -c "
import sys, json
data = json.load(sys.stdin)
r = data.get('result', [])
print(r[0].get('payload',{}).get('content_preview','Aucune réponse disponible.') if r else 'Aucune réponse disponible.')
" 2>/dev/null
        fi
    else
        info "Ollama non disponible — retour du meilleur extrait Qdrant"
        echo "$results" | python3 -c "
import sys, json
data = json.load(sys.stdin)
r = data.get('result', [])
print(r[0].get('payload',{}).get('content_preview','Aucune réponse disponible.') if r else 'Aucune réponse disponible.')
" 2>/dev/null
    fi
}

## ── Synchronisation WebDAV (si NextCloud disponible) ─────────────────
_sync_webdav() {
    local mode="${1:-incremental}"
    info "Synchronisation WebDAV depuis NextCloud/${NC_COLLECTION_PATH} (mode: $mode)..."

    if [[ -z "$NC_PASSWORD" ]]; then
        warn "Mot de passe NextCloud absent — indexation des docs locaux en fallback"
        local _docs_dir="$MY_PATH/../../docs"
        if [[ -d "$_docs_dir" ]]; then
            _index_local "$_docs_dir"
        else
            info "Déposez des fichiers manuellement dans $CACHE_DIR et relancez avec --index-local"
        fi
        return 0
    fi

    local webdav_url="${NC_WEBDAV_BASE}/${NC_USER}/${NC_COLLECTION_PATH}"
    local sync_dir="$CACHE_DIR/${NC_COLLECTION_PATH}"
    mkdir -p "$sync_dir"

    ## Lister les fichiers via PROPFIND WebDAV
    local file_list
    file_list=$(curl -sf --netrc-file "$_NC_NETRC" \
        -X PROPFIND \
        -H "Depth: infinity" \
        -H "Content-Type: application/xml" \
        "$webdav_url" \
        | python3 -c "
import sys, re
content = sys.stdin.read()
hrefs = re.findall(r'<D:href>([^<]+)</D:href>', content)
for h in hrefs:
    if any(h.endswith(ext) for ext in ['.pdf','.txt','.md','.docx','.odt','.html','.json','.rst']):
        print(h.strip())
" 2>/dev/null)

    if [[ -z "$file_list" ]]; then
        warn "Aucun fichier trouvé dans NextCloud/${NC_COLLECTION_PATH}"
        return 0
    fi

    local file_count=0
    local skip_count=0
    while IFS= read -r href; do
        [[ -z "$href" ]] && continue
        local filename
        filename=$(basename "$href")
        local local_file="$sync_dir/$filename"
        local nc_url="http://127.0.0.1:8001${href}"

        ## Mode incrémental : skip les fichiers locaux récents (< 24h)
        if [[ "$mode" != "--full" && -f "$local_file" ]]; then
            local local_age=$(( $(date +%s) - $(stat -c %Y "$local_file" 2>/dev/null || echo 0) ))
            if [[ $local_age -lt 86400 ]]; then
                info "Skip (< 24h) : $filename"
                ((skip_count++))
                continue
            fi
        fi

        ## Télécharger puis indexer en parallèle via sémaphore
        if curl -sf --netrc-file "$_NC_NETRC" -o "$local_file" "$nc_url" 2>/dev/null; then
            info "Téléchargé : $filename"
            (
                local _slot
                _slot=$(_idx_slot_acquire)
                _index_document "$local_file"
                _idx_slot_release "$_slot"
            ) &
            ((file_count++))
        else
            warn "Échec téléchargement : $filename"
        fi

    done <<< "$file_list"

    # Attendre tous les workers d'indexation
    wait
    ok "Synchronisation terminée : $file_count indexé(s), $skip_count ignoré(s) (récents)"
}

## ── Sémaphore d'indexation parallèle ─────────────────────────────────
## Slots PID dans /dev/shm pour limiter le nombre de workers simultanés.
## Basé sur le même pattern que bro_dm_daemon.sh.
_IDX_SLOTS_DIR="${TMPDIR:-/dev/shm}/bro_idx_slots_$$"
_IDX_MAX_JOBS=$(python3 - <<'PYEOF'
import re
try:
    mem_kb = int(re.search(r'MemAvailable:\s+(\d+)', open('/proc/meminfo').read()).group(1))
    print(max(1, min(4, int(mem_kb / 1024 / 1024 / 2))))
except Exception:
    print(2)
PYEOF
)
[[ -z "$_IDX_MAX_JOBS" || ! "$_IDX_MAX_JOBS" =~ ^[0-9]+$ ]] && _IDX_MAX_JOBS=2

_idx_slot_acquire() {
    local _pid=$BASHPID
    while true; do
        for _s in $(seq 1 "$_IDX_MAX_JOBS"); do
            local _f="$_IDX_SLOTS_DIR/s${_s}.pid"
            if (set -C; echo "$_pid" > "$_f") 2>/dev/null; then echo "$_f"; return; fi
            local _owner; _owner=$(cat "$_f" 2>/dev/null)
            [[ -n "$_owner" ]] && ! kill -0 "$_owner" 2>/dev/null && rm -f "$_f"
        done
        sleep 0.3
    done
}
_idx_slot_release() { rm -f "${1:-}"; }

## ── Indexation des fichiers locaux (sans WebDAV) — parallèle ──────────
_index_local() {
    local dir="${1:-$CACHE_DIR/$NC_COLLECTION_PATH}"
    info "Indexation des fichiers locaux depuis $dir (max $_IDX_MAX_JOBS workers)..."

    if [[ ! -d "$dir" ]]; then
        warn "Répertoire non trouvé : $dir"
        info "Créez le dossier et déposez-y vos fichiers :"
        info "  mkdir -p $dir"
        info "  cp mes-documents/*.pdf $dir/"
        return 1
    fi

    mkdir -p "$_IDX_SLOTS_DIR"
    local count=0 pids=()
    while IFS= read -r -d $'\0' file; do
        ((count++))
        (
            local _slot
            _slot=$(_idx_slot_acquire)
            _index_document "$file"
            _idx_slot_release "$_slot"
        ) &
        pids+=($!)
    done < <(find "$dir" -type f \( -name "*.pdf" -o -name "*.txt" -o -name "*.md" \
              -o -name "*.docx" -o -name "*.html" -o -name "*.json" \) -print0)

    # Attendre la fin de tous les workers
    for _p in "${pids[@]}"; do wait "$_p" 2>/dev/null || true; done
    rm -rf "$_IDX_SLOTS_DIR"

    ok "Indexation locale : $count fichier(s) traité(s)"
    info "Statistiques Qdrant : curl $QDRANT_URL/collections/$QDRANT_COLLECTION"
}

## ── Point d'entrée principal ──────────────────────────────────────────
## Bannière sur stderr uniquement (ne pollue pas les captures $(...))
{
    echo ""
    echo "🧠 nextcloud_bro_sync.sh — Constellation Knowledge Base"
    echo "   NextCloud/${NC_COLLECTION_PATH} (ou docs/ local) → Ollama[${EMBED_MODEL}] → Qdrant[${QDRANT_COLLECTION}]"
    echo ""
} >&2

case "${1:-}" in
    --query|-q)
        shift
        _USER_HEX=""
        _QUESTION=""
        _SLOTS="0"
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --user)  _USER_HEX="$2";  shift 2 ;;
                --slots) _SLOTS="$2";     shift 2 ;;
                *) _QUESTION="${_QUESTION:+$_QUESTION }$1"; shift ;;
            esac
        done
        if ! _check_services; then echo "Service indisponible (Ollama ou Qdrant). Réessayez plus tard."; exit 1; fi
        _query_knowledge "$_QUESTION" "$_USER_HEX" "$_SLOTS"
        ;;
    --index-local|-l)
        if ! _check_services; then exit 1; fi
        _ensure_qdrant_collection
        _index_local "${2:-}"
        ;;
    --full|-f)
        if ! _check_services; then exit 1; fi
        _ensure_qdrant_collection
        _sync_webdav "--full"
        ;;
    --status|-s)
        echo "=== Services ===" >&2
        curl -sf "$OLLAMA_URL/api/tags" &>/dev/null && ok "Ollama ✅" || err "Ollama ❌ ($OLLAMA_URL)"
        curl -sf "${_QDRANT_AUTH[@]}" "$QDRANT_URL/collections" &>/dev/null && ok "Qdrant ✅" || err "Qdrant ❌ ($QDRANT_URL)"
        echo ""
        echo "=== Collection Qdrant : $QDRANT_COLLECTION ==="
        curl -sf "${_QDRANT_AUTH[@]}" "$QDRANT_URL/collections/$QDRANT_COLLECTION" \
            | python3 -c "
import sys,json
d = json.load(sys.stdin).get('result',{})
print(f'  Points indexés : {d.get(\"points_count\",\"?\")}')
print(f'  Vecteurs : {d.get(\"vectors_count\",\"?\")}')
print(f'  Status : {d.get(\"status\",\"?\")}')
" 2>/dev/null || echo "  Collection non trouvée"
        echo ""
        echo "=== Cache local ==="
        echo "  $CACHE_DIR : $(find "$CACHE_DIR" -type f 2>/dev/null | wc -l) fichier(s)"
        ;;
    --help|-h)
        echo "Usage:"
        echo "  $0                           Sync incrémentale WebDAV → Qdrant"
        echo "  $0 --full                    Réindexation complète"
        echo "  $0 --index-local [DIR]       Indexer des fichiers locaux"
        echo "  $0 --query 'ma question'     Requête sémantique #BRO (stdout = réponse IA)"
        echo "  $0 --status                  Statut des services"
        echo ""
        echo "Variables d'environnement:"
        echo "  NC_WEBDAV_URL  (défaut: http://127.0.0.1:8001/remote.php/dav/files)"
        echo "  NC_USERNAME    (défaut: admin)"
        echo "  NC_COLLECTION  (défaut: Astroport)"
        echo "  QDRANT_URL     (défaut: http://127.0.0.1:6333)"
        echo "  OLLAMA_URL     (défaut: http://127.0.0.1:11434)"
        ;;
    *)
        ## Sync incrémentale par défaut
        if ! _check_services; then
            err "Services requis non disponibles. Vérifiez Ollama et Qdrant."
            info "Démarrez le profil ai-company: bash install.sh \"\" \"\" \"\" ai-company"
            exit 1
        fi
        _ensure_qdrant_collection
        _sync_webdav "incremental"
        ;;
esac
