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
#   Qdrant "nextcloud_kb"  ──[query]─→  #BRO / OpenClaw / code_assistant
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
########################################################################

MY_PATH="$(dirname "$(realpath "$0")")"
. "$MY_PATH/../tools/my.sh" 2>/dev/null || true

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
    log "INFO" "Qdrant API Key: UPLANETNAME (${QDRANT_API_KEY:0:8}...)"
else
    log "INFO" "Qdrant sans authentification (UPLANETNAME absent)"
fi
EMBED_MODEL="nomic-embed-text"
CACHE_DIR="$HOME/.zen/tmp/nextcloud_sync"
SYNC_LOG="$HOME/.zen/tmp/nextcloud_sync.log"

mkdir -p "$CACHE_DIR"

## ── Couleurs ──────────────────────────────────────────────────────────
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC_C='\033[0m'
log()  { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$SYNC_LOG"; }
ok()   { echo -e "${GREEN}✅ $*${NC_C}"; log "OK: $*"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC_C}"; log "WARN: $*"; }
err()  { echo -e "${RED}❌ $*${NC_C}"; log "ERR: $*"; }
info() { echo -e "${CYAN}ℹ️  $*${NC_C}"; log "INFO: $*"; }

## ── Lecture du mot de passe NextCloud ────────────────────────────────
NC_PASSWORD=""
if [[ -s "$NC_PASS_FILE" ]]; then
    NC_PASSWORD=$(cat "$NC_PASS_FILE")
elif [[ -n "$NC_PASSWORD_ENV" ]]; then
    NC_PASSWORD="$NC_PASSWORD_ENV"
else
    warn "Mot de passe NextCloud non trouvé dans $NC_PASS_FILE"
    info "Définissez NC_PASSWORD_ENV ou créez $NC_PASS_FILE"
fi

## ── Résolution Ollama via ollama.me.sh (local ou P2P Swarm) ─────────
## ollama.me.sh établit un tunnel sur :
##   - 127.0.0.1:11434        (accès depuis l'hôte)
##   - ${DOCKER_BRIDGE_IP}:11434  (accès depuis les conteneurs Docker)
_ensure_ollama() {
    ## Vérifier si Ollama est déjà accessible
    if curl -sf --max-time 2 "$OLLAMA_URL/api/tags" &>/dev/null; then
        ## Lire le type de connexion depuis le fichier de status
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
    local OLLAMA_STARTER="$MY_PATH/ollama.me.sh"
    if [[ -x "$OLLAMA_STARTER" ]]; then
        bash "$OLLAMA_STARTER" &>/dev/null &
        ## Attendre jusqu'à 20 secondes
        echo -n "  Attente Ollama"
        for _i in $(seq 1 20); do
            sleep 1; echo -n "."
            curl -sf --max-time 1 "$OLLAMA_URL/api/tags" &>/dev/null && { echo " ✅"; return 0; }
        done
        echo ""
        warn "Ollama non accessible après 20s (local + P2P) — embeddings désactivés"
        return 1
    else
        err "ollama.me.sh introuvable ($OLLAMA_STARTER)"
        err "Installez Ollama: https://ollama.ai  puis: ollama serve"
        return 1
    fi
}

## ── Vérifications préalables ─────────────────────────────────────────
_check_services() {
    local ok=true
    if ! _ensure_ollama; then
        ok=false
    fi
    if ! curl -sf --max-time 3 "${_QDRANT_AUTH[@]}" "$QDRANT_URL/collections" &>/dev/null; then
        err "Qdrant non accessible ($QDRANT_URL)"
        ok=false
    fi
    [[ "$ok" == "true" ]]
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
            | python3 -c "import sys,json; r=json.load(sys.stdin); print('✅ Collection créée' if r.get('result') else '❌ Erreur: '+str(r))" 2>/dev/null
    fi
}

## ── Génération d'un embedding via Ollama ────────────────────────────
_embed_text() {
    local text="$1"
    curl -sf -X POST "$OLLAMA_URL/api/embeddings" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$EMBED_MODEL\",\"prompt\":$(python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$text")}" \
        | python3 -c "import sys,json; d=json.load(sys.stdin); print(' '.join(map(str,d.get('embedding',[]))))" 2>/dev/null
}

## ── Indexation d'un fichier dans Qdrant ─────────────────────────────
_index_document() {
    local filepath="$1"
    local filename=$(basename "$filepath")
    local extension="${filename##*.}"
    local content=""

    ## Extraction du texte selon le type de fichier
    case "${extension,,}" in
        pdf)
            command -v pdftotext &>/dev/null && content=$(pdftotext "$filepath" - 2>/dev/null | head -c 8000) \
                || content=$(python3 -c "import subprocess; print(subprocess.run(['pdftotext','-','$filepath'], capture_output=True, text=True).stdout[:8000])" 2>/dev/null)
            ;;
        md|txt|rst)
            content=$(head -c 8000 "$filepath")
            ;;
        docx|odt)
            command -v pandoc &>/dev/null && content=$(pandoc -t plain "$filepath" 2>/dev/null | head -c 8000) \
                || content=$(python3 -c "import zipfile; z=zipfile.ZipFile('$filepath'); print(z.read('word/document.xml').decode('utf-8','ignore')[:8000])" 2>/dev/null)
            ;;
        html|htm)
            content=$(cat "$filepath" | python3 -c "import sys,re; t=sys.stdin.read(); print(re.sub(r'<[^>]+>','',t)[:8000])" 2>/dev/null)
            ;;
        json)
            content=$(python3 -c "import json,sys; d=json.load(open('$filepath')); print(json.dumps(d,ensure_ascii=False)[:8000])" 2>/dev/null)
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

    ## Upsert dans Qdrant
    local vector_json="[$(echo "$vector" | tr ' ' ',')]"
    curl -sf -X PUT "$QDRANT_URL/collections/$QDRANT_COLLECTION/points" \
        -H "Content-Type: application/json" \
        -d "{
            \"points\": [{
                \"id\": $doc_id,
                \"vector\": $vector_json,
                \"payload\": {
                    \"filename\": \"$filename\",
                    \"filepath\": \"$filepath\",
                    \"extension\": \"$extension\",
                    \"content_preview\": \"$(echo "${content:0:300}" | sed 's/"/\\"/g; s/\n/\\n/g')\",
                    \"indexed_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
                    \"source\": \"nextcloud/${NC_COLLECTION_PATH}\"
                }
            }]
        }" \
        | python3 -c "import sys,json; r=json.load(sys.stdin); exit(0 if r.get('result',{}).get('status')=='acknowledged' else 1)" 2>/dev/null \
        && ok "Indexé : $filename (id=$doc_id)" \
        || err "Échec indexation : $filename"
}

## ── Requête sémantique vers Qdrant ──────────────────────────────────
_query_knowledge() {
    local question="$1"
    local top_k="${2:-5}"

    info "Recherche sémantique : '$question'"
    local q_vector
    q_vector=$(_embed_text "$question")
    [[ -z "$q_vector" ]] && err "Impossible de générer l'embedding de la question" && return 1

    local vector_json="[$(echo "$q_vector" | tr ' ' ',')]"
    local results
    results=$(curl -sf -X POST "$QDRANT_URL/collections/$QDRANT_COLLECTION/points/search" \
        "${_QDRANT_AUTH[@]}" \
        -H "Content-Type: application/json" \
        -d "{\"vector\":$vector_json,\"limit\":$top_k,\"with_payload\":true}" 2>/dev/null)

    echo ""
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
    score = r.get('score', 0)
    print(f'''
  [{i}] {p.get('filename', '?')} (score: {score:.3f})
       Source: {p.get('filepath', '?')}
       Extrait: {p.get('content_preview', '')[:150]}...
''')
" 2>/dev/null

    ## Optionnel : envoyer le contexte à Ollama pour une réponse synthétisée
    if command -v ollama &>/dev/null; then
        local context
        context=$(echo "$results" | python3 -c "
import sys,json
data = json.load(sys.stdin)
results = data.get('result', [])
ctx = '\n\n'.join([r.get('payload',{}).get('content_preview','') for r in results[:3]])
print(ctx[:4000])
" 2>/dev/null)
        echo ""
        echo "═══ Synthèse #BRO (Ollama) ═══"
        ollama run "${OLLAMA_MODEL:-llama3}" "Contexte: $context

Question: $question

Réponds en français en te basant sur le contexte ci-dessus." 2>/dev/null \
            || info "(Ollama non disponible pour la synthèse — résultats Qdrant ci-dessus)"
    fi
}

## ── Synchronisation WebDAV (si NextCloud disponible) ─────────────────
_sync_webdav() {
    local mode="${1:-incremental}"
    info "Synchronisation WebDAV depuis NextCloud/${NC_COLLECTION_PATH}..."

    if [[ -z "$NC_PASSWORD" ]]; then
        warn "Mot de passe NextCloud absent — sync WebDAV ignorée"
        info "Déposez des fichiers manuellement dans $CACHE_DIR et relancez avec --index-local"
        return 0
    fi

    local webdav_url="${NC_WEBDAV_BASE}/${NC_USER}/${NC_COLLECTION_PATH}"
    local sync_dir="$CACHE_DIR/${NC_COLLECTION_PATH}"
    mkdir -p "$sync_dir"

    ## Lister les fichiers via PROPFIND WebDAV
    local file_list
    file_list=$(curl -sf --user "${NC_USER}:${NC_PASSWORD}" \
        -X PROPFIND \
        -H "Depth: infinity" \
        -H "Content-Type: application/xml" \
        "$webdav_url" \
        | python3 -c "
import sys, re
content = sys.stdin.read()
# Extraire les hrefs des fichiers (pas les dossiers)
hrefs = re.findall(r'<D:href>([^<]+)</D:href>', content)
for h in hrefs:
    # Garder seulement les fichiers (extensions connues)
    if any(h.endswith(ext) for ext in ['.pdf','.txt','.md','.docx','.odt','.html','.json','.rst']):
        print(h.strip())
" 2>/dev/null)

    if [[ -z "$file_list" ]]; then
        warn "Aucun fichier trouvé dans NextCloud/${NC_COLLECTION_PATH}"
        return 0
    fi

    local file_count=0
    while IFS= read -r href; do
        [[ -z "$href" ]] && continue
        local filename=$(basename "$href")
        local local_file="$sync_dir/$filename"
        local nc_url="http://127.0.0.1:8001${href}"

        ## Vérifier si le fichier a changé (mode incrémental)
        if [[ "$mode" != "--full" && -f "$local_file" ]]; then
            local remote_mtime
            remote_mtime=$(curl -sf --user "${NC_USER}:${NC_PASSWORD}" -I "$nc_url" 2>/dev/null \
                | grep -i 'Last-Modified' | cut -d' ' -f2-)
            local local_mtime=$(stat -c %Y "$local_file" 2>/dev/null || echo 0)
            # Pour simplifier : toujours re-télécharger si le fichier est dans Qdrant
            # (comparison de dates plus complexe — à améliorer)
        fi

        ## Télécharger le fichier
        curl -sf --user "${NC_USER}:${NC_PASSWORD}" -o "$local_file" "$nc_url" 2>/dev/null \
            && info "Téléchargé : $filename" \
            || warn "Échec téléchargement : $filename"

        _index_document "$local_file"
        ((file_count++))

    done <<< "$file_list"

    ok "Synchronisation terminée : $file_count fichier(s) traité(s)"
}

## ── Indexation des fichiers locaux (sans WebDAV) ─────────────────────
_index_local() {
    local dir="${1:-$CACHE_DIR/$NC_COLLECTION_PATH}"
    info "Indexation des fichiers locaux depuis $dir..."

    if [[ ! -d "$dir" ]]; then
        warn "Répertoire non trouvé : $dir"
        info "Créez le dossier et déposez-y vos fichiers :"
        info "  mkdir -p $dir"
        info "  cp mes-documents/*.pdf $dir/"
        return 1
    fi

    local count=0
    while IFS= read -r -d $'\0' file; do
        _index_document "$file"
        ((count++))
    done < <(find "$dir" -type f \( -name "*.pdf" -o -name "*.txt" -o -name "*.md" -o -name "*.docx" -o -name "*.html" -o -name "*.json" \) -print0)

    ok "Indexation locale : $count fichier(s) traité(s)"
    info "Statistiques Qdrant : curl $QDRANT_URL/collections/$QDRANT_COLLECTION"
}

## ── Point d'entrée principal ──────────────────────────────────────────
echo ""
echo "🧠 nextcloud_bro_sync.sh — Constellation Knowledge Base"
echo "   NextCloud/${NC_COLLECTION_PATH} → Ollama[${EMBED_MODEL}] → Qdrant[${QDRANT_COLLECTION}]"
echo ""

case "${1:-}" in
    --query|-q)
        shift
        if ! _check_services; then exit 1; fi
        _query_knowledge "$*"
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
        echo "=== Services ==="
        curl -sf "$OLLAMA_URL/api/tags" &>/dev/null && ok "Ollama ✅" || err "Ollama ❌ ($OLLAMA_URL)"
        curl -sf "$QDRANT_URL/collections" &>/dev/null && ok "Qdrant ✅" || err "Qdrant ❌ ($QDRANT_URL)"
        echo ""
        echo "=== Collection Qdrant : $QDRANT_COLLECTION ==="
        curl -sf "$QDRANT_URL/collections/$QDRANT_COLLECTION" \
            | python3 -c "
import sys,json
d = json.load(sys.stdin).get('result',{})
print(f'  Points indexés : {d.get(\"points_count\",\"?\")}'  )
print(f'  Vecteurs : {d.get(\"vectors_count\",\"?\")}')
print(f'  Status : {d.get(\"status\",\"?\")}')
" 2>/dev/null || echo "  Collection non trouvée"
        echo ""
        echo "=== Cache local ==="
        echo "  $CACHE_DIR : $(find $CACHE_DIR -type f 2>/dev/null | wc -l) fichier(s)"
        ;;
    --help|-h)
        echo "Usage:"
        echo "  $0                           Sync incrémentale WebDAV → Qdrant"
        echo "  $0 --full                    Réindexation complète"
        echo "  $0 --index-local [DIR]       Indexer des fichiers locaux"
        echo "  $0 --query 'ma question'     Requête sémantique #BRO"
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
            info "Démarrez le profil bleeding-edge: bash install.sh \"\" \"\" \"\" bleeding-edge"
            exit 1
        fi
        _ensure_qdrant_collection
        _sync_webdav "incremental"
        ;;
esac
