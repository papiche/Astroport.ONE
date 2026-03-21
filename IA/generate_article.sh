#!/usr/bin/env bash
###############################################################################
# generate_article.sh — Génère un article (résumé + tags + image) depuis un texte
#
# Réutilise le pipeline #search de UPlanet_IA_Responder.sh :
#   texte source → résumé narratif → tags intelligents → illustration IA → article
#
# Usage: ./generate_article.sh [OPTIONS] "texte source"
#        echo "texte" | ./generate_article.sh [OPTIONS]
#
# Options:
#   --format json|md|html   Format de sortie (défaut: json)
#   --lang LANG             Langue ISO 639-1 (défaut: fr)
#   --output FILE           Écrire dans un fichier (défaut: stdout)
#   --no-image              Ne pas générer d'illustration
#   --model MODEL           Modèle Ollama (défaut: gemma3:latest)
#   --title TITLE           Titre imposé (sinon généré par l'IA)
#   --tags "tag1 tag2"      Tags supplémentaires (sans #, séparés par espace)
#   --udrive PATH           Répertoire de sortie pour l'image générée
#   --file FILE, -f FILE    Lire le texte source depuis un fichier
#   --help                  Affiche cette aide
#
# Sortie JSON:
#   {
#     "title": "...",       Titre de l'article
#     "summary": "...",     Résumé 2-3 phrases pour non-développeurs
#     "tags": ["t1","t2"],  Tags contextuels (IA + manuels)
#     "image_url": "...",   URL IPFS de l'illustration (ou "")
#     "content": "...",     Contenu source original
#     "published_at": 123,  Timestamp Unix
#     "d_tag": "..."        Identifiant unique pour NOSTR kind 30023
#   }
#
# Exemples:
#   ./generate_article.sh --file TODO.week.md --format md --output bilan.md
#   ./generate_article.sh --lang en --no-image --format json "Git changes summary..."
#   cat rapport.md | ./generate_article.sh --format html > bilan.html
###############################################################################

set -euo pipefail

MY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

QUESTION_PY="$MY_PATH/question.py"
GENERATE_IMAGE_SH="$MY_PATH/generate_image.sh"
COMFYUI_ME_SH="$MY_PATH/comfyui.me.sh"

# Couleurs (stderr uniquement)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ─── Valeurs par défaut ───────────────────────────────────────────────────────
FORMAT="json"
LANG="fr"
OUTPUT_FILE=""
NO_IMAGE=false
MODEL="gemma3:latest"
ARTICLE_TITLE=""
EXTRA_TAGS=""
UDRIVE_PATH=""
SOURCE_FILE=""
SOURCE_TEXT=""

# ─── Aide ────────────────────────────────────────────────────────────────────
show_help() {
    cat >&2 <<'EOF'
generate_article.sh — Génère un article (résumé + tags + image) depuis un texte

USAGE:
    ./generate_article.sh [OPTIONS] "texte source"
    ./generate_article.sh [OPTIONS] --file SOURCE_FILE
    echo "texte" | ./generate_article.sh [OPTIONS]

OPTIONS:
    --format json|md|html   Format de sortie (défaut: json)
    --lang LANG             Langue ISO 639-1 (défaut: fr)
    --output FILE           Écrire dans un fichier (défaut: stdout)
    --no-image              Ne pas générer d'illustration ComfyUI
    --model MODEL           Modèle Ollama (défaut: gemma3:latest)
    --title TITLE           Titre imposé (sinon généré par l'IA)
    --tags "tag1 tag2"      Tags supplémentaires (sans #, séparés par espace)
    --udrive PATH           Répertoire de sortie pour l'image
    --file FILE, -f FILE    Lire le texte source depuis un fichier
    --help, -h              Affiche cette aide

SORTIE JSON:
    { "title", "summary", "tags", "image_url", "content", "published_at", "d_tag" }

EXEMPLES:
    ./generate_article.sh --file TODO.week.md --format md --output bilan.md
    ./generate_article.sh --file rapport.md --lang en --no-image --format json
    cat rapport.md | ./generate_article.sh --format html > bilan.html
    ./generate_article.sh --format json "Résumé des évolutions de la semaine..."
EOF
    exit 0
}

# ─── Parse arguments ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)      show_help ;;
        --format)       FORMAT="$2";         shift 2 ;;
        --format=*)     FORMAT="${1#--format=}"; shift ;;
        --lang)         LANG="$2";           shift 2 ;;
        --lang=*)       LANG="${1#--lang=}"; shift ;;
        --output)       OUTPUT_FILE="$2";    shift 2 ;;
        --output=*)     OUTPUT_FILE="${1#--output=}"; shift ;;
        --no-image)     NO_IMAGE=true;       shift ;;
        --model)        MODEL="$2";          shift 2 ;;
        --model=*)      MODEL="${1#--model=}"; shift ;;
        --title)        ARTICLE_TITLE="$2";  shift 2 ;;
        --title=*)      ARTICLE_TITLE="${1#--title=}"; shift ;;
        --tags)         EXTRA_TAGS="$2";     shift 2 ;;
        --tags=*)       EXTRA_TAGS="${1#--tags=}"; shift ;;
        --udrive)       UDRIVE_PATH="$2";    shift 2 ;;
        --udrive=*)     UDRIVE_PATH="${1#--udrive=}"; shift ;;
        --file|-f)      SOURCE_FILE="$2";    shift 2 ;;
        --file=*)       SOURCE_FILE="${1#--file=}"; shift ;;
        -*)             echo -e "${RED}❌ Option inconnue: $1${NC}" >&2; show_help ;;
        *)              SOURCE_TEXT="$1";    shift ;;
    esac
done

# Lire depuis un fichier si --file spécifié (prioritaire sur l'argument positionnel)
if [[ -n "$SOURCE_FILE" ]]; then
    if [[ ! -f "$SOURCE_FILE" ]]; then
        echo -e "${RED}❌ Fichier source introuvable: $SOURCE_FILE${NC}" >&2
        exit 1
    fi
    SOURCE_TEXT="$(cat "$SOURCE_FILE")"
fi

# Lire depuis stdin si pas de texte fourni (ni --file ni argument)
if [[ -z "$SOURCE_TEXT" ]]; then
    if [[ ! -t 0 ]]; then
        SOURCE_TEXT="$(cat)"
    else
        echo -e "${RED}❌ Texte source requis (argument, --file ou stdin)${NC}" >&2
        show_help
    fi
fi

[[ -z "$SOURCE_TEXT" ]] && { echo -e "${RED}❌ Texte source vide${NC}" >&2; exit 1; }

# Validation format
case "$FORMAT" in
    json|md|html) ;;
    *) echo -e "${RED}❌ Format inconnu: $FORMAT (valeurs: json, md, html)${NC}" >&2; exit 1 ;;
esac

# ─── Python et dépendances ───────────────────────────────────────────────────
PYTHON3="${HOME}/.astro/bin/python3"
command -v "$PYTHON3" &>/dev/null || PYTHON3="$(command -v python3 2>/dev/null || echo python3)"

if [[ ! -f "$QUESTION_PY" ]]; then
    echo -e "${RED}❌ question.py introuvable: $QUESTION_PY${NC}" >&2
    exit 1
fi

# ─── Métadonnées de base ─────────────────────────────────────────────────────
PUBLISHED_AT=$(date -u +%s)
D_TAG="article_$(date -u +%Y%m%d)_$(echo -n "$SOURCE_TEXT" | md5sum | cut -c1-8)"

# Tronquer la source pour le contexte IA (évite les dépassements)
SOURCE_TRUNCATED="${SOURCE_TEXT:0:3000}"

log() { echo -e "${BLUE}$*${NC}" >&2; }
ok()  { echo -e "${GREEN}$*${NC}" >&2; }
warn(){ echo -e "${YELLOW}$*${NC}" >&2; }

log "📝 Génération de l'article..."

# ─── 1. Titre ─────────────────────────────────────────────────────────────────
if [[ -z "$ARTICLE_TITLE" ]]; then
    log "  🏷️  Titre..."
    ARTICLE_TITLE="$(
        $PYTHON3 "$QUESTION_PY" \
            "Génère UN titre court (max 80 caractères) pour cet article.
Langue: ${LANG}. Commence directement par le titre, sans guillemets ni ponctuation finale.
Contenu: ${SOURCE_TRUNCATED}" \
            --model "$MODEL" 2>/dev/null | head -1 | head -c 80 || true
    )"
    [[ -z "$ARTICLE_TITLE" ]] && ARTICLE_TITLE="Rapport du $(date +%Y-%m-%d)"
fi

# ─── 2. Résumé narratif ──────────────────────────────────────────────────────
log "  📄 Résumé..."
SUMMARY="$(
    $PYTHON3 "$QUESTION_PY" \
        "Écris 2-3 phrases résumant ce contenu pour un public non-technique.
Langue: ${LANG}. Commence directement, sans introduction ni métacommentaire.
Contenu: ${SOURCE_TRUNCATED}" \
        --model "$MODEL" 2>/dev/null \
    | tr '\n' ' ' | sed 's/  */ /g' | head -c 500 || true
)"
[[ -z "$SUMMARY" ]] && SUMMARY="$ARTICLE_TITLE"

# ─── 3. Tags intelligents ────────────────────────────────────────────────────
log "  🏷️  Tags..."
RAW_TAGS="$(
    $PYTHON3 "$QUESTION_PY" \
        "List 5 to 8 single-word keywords describing this content.
Rules: one word per keyword, lowercase only, no numbers, no hyphens, no explanation.
Output only the words separated by a single space on one line.
Example output: development nostr protocol constellation git
Content: ${SOURCE_TRUNCATED}" \
        --model "$MODEL" 2>/dev/null \
    | head -1 \
    | sed 's/#//g; s/,/ /g; s/[`*]//g; s/[0-9]//g' \
    | tr -s ' \n' ' ' | head -c 200 || true
)"

# Fusionner tags IA + manuels, nettoyer et déduplicer
TAGS_JSON="[]"
ALL_RAW="${RAW_TAGS} ${EXTRA_TAGS}"
for tag in $ALL_RAW; do
    tag="${tag,,}"                      # lowercase
    tag="${tag//[^a-z_-]/}"            # lettres + _ - uniquement (pas de chiffres parasites)
    [[ ${#tag} -ge 3 ]] || continue   # min 3 caractères
    [[ ${#tag} -le 30 ]] || continue  # max 30 caractères
    TAGS_JSON="$(echo "$TAGS_JSON" | jq --arg t "$tag" '. + [$t] | unique')"
done

# ─── 4. Illustration ─────────────────────────────────────────────────────────
IMAGE_URL=""
if [[ "$NO_IMAGE" == "false" ]] && [[ -f "$GENERATE_IMAGE_SH" ]]; then
    # Vérifier ComfyUI disponible
    COMFYUI_OK=false
    if [[ -f "$COMFYUI_ME_SH" ]] && "$COMFYUI_ME_SH" 2>/dev/null; then
        COMFYUI_OK=true
    fi

    if $COMFYUI_OK; then
        log "  🎨 Illustration..."
        SD_PROMPT="$(
            $PYTHON3 "$QUESTION_PY" \
                "Stable Diffusion image prompt for: ${SUMMARY}
OUTPUT ONLY visual descriptors in English. NO text, words, brands, logos.
Focus: composition, colors, lighting, style, abstract concept." \
                --model "$MODEL" 2>/dev/null | head -c 400 || true
        )"
        [[ -z "$SD_PROMPT" ]] && SD_PROMPT="abstract digital network collaboration technology"

        if [[ -n "$UDRIVE_PATH" ]] && [[ -d "$UDRIVE_PATH" ]]; then
            IMAGE_URL="$("$GENERATE_IMAGE_SH" "${SD_PROMPT}" "$UDRIVE_PATH" 2>/dev/null || true)"
        else
            IMAGE_URL="$("$GENERATE_IMAGE_SH" "${SD_PROMPT}" 2>/dev/null || true)"
        fi
        [[ -n "$IMAGE_URL" ]] && ok "  ✅ Image: $IMAGE_URL"
    else
        warn "  ⚠️  ComfyUI non disponible, pas d'illustration"
    fi
else
    [[ "$NO_IMAGE" == "true" ]] && warn "  ⏭️  Image désactivée (--no-image)"
fi

ok "✅ Article prêt: \"${ARTICLE_TITLE}\""

# ─── 5. Rendu selon le format ────────────────────────────────────────────────
render_json() {
    jq -n \
        --arg     title   "$ARTICLE_TITLE" \
        --arg     summary "$SUMMARY" \
        --argjson tags    "$TAGS_JSON" \
        --arg     image   "$IMAGE_URL" \
        --arg     content "$SOURCE_TEXT" \
        --argjson pub     "$PUBLISHED_AT" \
        --arg     d       "$D_TAG" \
        '{
            title:        $title,
            summary:      $summary,
            tags:         $tags,
            image_url:    $image,
            content:      $content,
            published_at: $pub,
            d_tag:        $d
        }'
}

render_md() {
    local tags_line
    tags_line="$(echo "$TAGS_JSON" | jq -r '.[] | "#\(.)"' | tr '\n' ' ')"
    local date_str
    date_str="$(date -u +"%Y-%m-%d %H:%M UTC")"
    local image_line=""
    [[ -n "$IMAGE_URL" ]] && image_line="![Illustration]($IMAGE_URL)"

    printf '# %s\n\n> %s\n\n%s\n\n---\n\n%s\n\n---\n\n_Généré le %s_ · %s\n' \
        "$ARTICLE_TITLE" "$SUMMARY" "$image_line" "$SOURCE_TEXT" "$date_str" "$tags_line"
}

render_html() {
    local tags_html
    tags_html="$(echo "$TAGS_JSON" | jq -r '.[] | "<span class=\"tag\">#\(.)</span>"' | tr '\n' ' ')"
    local date_str
    date_str="$(date -u +"%Y-%m-%d %H:%M UTC")"
    local image_html=""
    [[ -n "$IMAGE_URL" ]] && image_html="<figure><img src=\"$IMAGE_URL\" alt=\"$(echo "$ARTICLE_TITLE" | sed 's/"/\&quot;/g')\" /></figure>"
    # Contenu: échapper les caractères HTML
    local content_html
    content_html="$(printf '%s' "$SOURCE_TEXT" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')"
    local summary_safe
    summary_safe="$(printf '%s' "$SUMMARY" | sed 's/"/\&quot;/g')"
    local title_safe
    title_safe="$(printf '%s' "$ARTICLE_TITLE" | sed 's/"/\&quot;/g; s/</\&lt;/g; s/>/\&gt;/g')"

    cat <<HTMLEOF
<!DOCTYPE html>
<html lang="${LANG}">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="${summary_safe}">
  <title>${title_safe}</title>
  <style>
    body{font-family:system-ui,sans-serif;max-width:800px;margin:2em auto;padding:1em;line-height:1.7;color:#222}
    h1{border-bottom:2px solid #333;padding-bottom:.3em}
    .summary{background:#f0f7ff;border-left:4px solid #007bff;padding:1em;margin:1.2em 0;font-style:italic}
    .tag{display:inline-block;background:#e8f4f8;color:#0066cc;padding:2px 10px;border-radius:12px;margin:2px;font-size:.85em}
    figure{margin:1.2em 0}figure img{max-width:100%;border-radius:8px;box-shadow:0 2px 8px rgba(0,0,0,.15)}
    .content{white-space:pre-wrap;font-size:.95em}
    .meta{color:#666;font-size:.85em;border-top:1px solid #eee;padding-top:1em;margin-top:2em}
  </style>
</head>
<body>
  <h1>${title_safe}</h1>
  <div class="summary">${summary_safe}</div>
  ${image_html}
  <div class="content">${content_html}</div>
  <div class="meta">
    <p>Publié le ${date_str}</p>
    <p>Tags : ${tags_html}</p>
  </div>
</body>
</html>
HTMLEOF
}

# ─── 6. Écriture ─────────────────────────────────────────────────────────────
case "$FORMAT" in
    json) OUTPUT_CONTENT="$(render_json)" ;;
    md)   OUTPUT_CONTENT="$(render_md)"   ;;
    html) OUTPUT_CONTENT="$(render_html)" ;;
esac

if [[ -n "$OUTPUT_FILE" ]]; then
    printf '%s\n' "$OUTPUT_CONTENT" > "$OUTPUT_FILE"
    ok "💾 Sauvegardé: $OUTPUT_FILE"
else
    printf '%s\n' "$OUTPUT_CONTENT"
fi
