#!/usr/bin/env bash
# =============================================================================
# git.notebook.sh — Initialise un projet Git géré par Claude Code
#                   à partir d'un notebook NotebookLM
#
# Usage:
#   ./git.notebook.sh --url URL --cookie "SID=x; SSID=y; ..."
#   ./git.notebook.sh --url URL --cookie-file cookies.json
#   ./git.notebook.sh --url URL --cookie "..." --project-dir ./mon-projet
#   ./git.notebook.sh --url URL --cookie "..." --non-interactive  # CI/CD
#
# Variables d'environnement acceptées :
#   NOTEBOOKLM_URL     URL du notebook
#   NOTEBOOKLM_COOKIE  Cookies inline
#
# Dépendances : python3, git, jq (optionnel)
# Python  : pip install playwright && playwright install chromium
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# ─── Couleurs ──────────────────────────────────────────────────────────────────
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_BLUE='\033[34m'
C_CYAN='\033[36m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_RED='\033[31m'
C_DIM='\033[2m'

header()  { echo -e "\n${C_BOLD}${C_BLUE}▶  $*${C_RESET}"; }
step()    { echo -e "   ${C_CYAN}→${C_RESET} $*"; }
ok()      { echo -e "   ${C_GREEN}✓${C_RESET} $*"; }
warn()    { echo -e "   ${C_YELLOW}⚠${C_RESET}  $*"; }
fail()    { echo -e "\n   ${C_RED}✗  $*${C_RESET}\n" >&2; exit 1; }
ask()     { echo -e "   ${C_BOLD}$*${C_RESET}"; }
dim()     { echo -e "   ${C_DIM}$*${C_RESET}"; }

# ─── Valeurs par défaut ────────────────────────────────────────────────────────
NB_URL="${NOTEBOOKLM_URL:-}"
NB_COOKIE="${NOTEBOOKLM_COOKIE:-}"
NB_COOKIE_FILE=""
PROJECT_DIR=""
NON_INTERACTIVE=false
SKIP_EXTRACT=false
NOTEBOOK_JSON=""

# ─── Parsing des arguments ─────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --url URL               URL du notebook NotebookLM
  --cookie 'K=V; K2=V2'  Cookies inline (ou NOTEBOOKLM_COOKIE)
  --cookie-file FILE      Fichier cookies (.json ou .txt Netscape)
  --project-dir DIR       Dossier destination du projet Git
  --notebook-json FILE    Sauter l'extraction, utiliser un JSON déjà produit
  --non-interactive       Pas de prompts — valeurs par défaut partout
  -h, --help              Afficher l'aide

EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)             NB_URL="$2";           shift 2 ;;
    --cookie)          NB_COOKIE="$2";        shift 2 ;;
    --cookie-file)     NB_COOKIE_FILE="$2";   shift 2 ;;
    --project-dir)     PROJECT_DIR="$2";      shift 2 ;;
    --notebook-json)   NOTEBOOK_JSON="$2"; SKIP_EXTRACT=true; shift 2 ;;
    --non-interactive) NON_INTERACTIVE=true;  shift ;;
    -h|--help)         usage ;;
    *) fail "Argument inconnu : $1" ;;
  esac
done

# ─── Bannière ──────────────────────────────────────────────────────────────────
echo -e "${C_BOLD}"
cat <<'BANNER'
 ╔══════════════════════════════════════════════════════╗
 ║   git.notebook — NotebookLM → Projet Claude Code     ║
 ║   Initialise un dépôt Git prêt pour Claude Code      ║
 ╚══════════════════════════════════════════════════════╝
BANNER
echo -e "${C_RESET}"

# ─── Vérifications prérequis ───────────────────────────────────────────────────
header "Vérification des prérequis"

command -v python3 >/dev/null 2>&1 || fail "python3 requis"
command -v git     >/dev/null 2>&1 || fail "git requis"
ok "python3 et git disponibles"

python3 -c "import playwright" 2>/dev/null || \
  fail "playwright manquant : pip install playwright && playwright install chromium"
ok "playwright disponible"

# jq est optionnel
JQ_AVAILABLE=false
command -v jq >/dev/null 2>&1 && JQ_AVAILABLE=true

# ─── Trouver le script d'extraction ───────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRACTOR="$SCRIPT_DIR/notebooklm_playwright.py"

if [[ ! -f "$EXTRACTOR" ]]; then
  # Chercher dans la structure IA/scrapers/ (après réorganisation)
  _IA_SCRAPER="${HOME}/.zen/Astroport.ONE/IA/scrapers/notebooklm.google.com/notebooklm_playwright.py"
  if [[ -f "$_IA_SCRAPER" ]]; then
    EXTRACTOR="$_IA_SCRAPER"
  else
    EXTRACTOR_PATH="$(command -v notebooklm_playwright.py 2>/dev/null || true)"
    [[ -n "$EXTRACTOR_PATH" ]] && EXTRACTOR="$EXTRACTOR_PATH" \
      || fail "notebooklm_playwright.py introuvable (cherché dans $SCRIPT_DIR et IA/scrapers/notebooklm.google.com/)."
  fi
fi
ok "Extracteur : $EXTRACTOR"

# ─── Validation URL + cookies ─────────────────────────────────────────────────
if [[ "$SKIP_EXTRACT" == false ]]; then
  [[ -z "$NB_URL" ]] && fail "--url requis (ou NOTEBOOKLM_URL)"
  [[ "$NB_URL" != *"notebooklm.google.com"* ]] && fail "URL invalide : $NB_URL"

  # Vérification cookie-file si fourni
  if [[ -n "$NB_COOKIE_FILE" && ! -f "$NB_COOKIE_FILE" ]]; then
    fail "Fichier cookie introuvable : $NB_COOKIE_FILE"
  fi

  # Aucun cookie fourni → chercher dans UPassport puis demander
  if [[ -z "$NB_COOKIE" && -z "$NB_COOKIE_FILE" ]]; then
    _UPASSPORT="http://127.0.0.1:54321"
    _PLAYER_NPUB=""
    # Essayer de lire le npub du joueur courant
    _CURRENT_DIR="$(readlink -f "$HOME/.zen/game/players/.current" 2>/dev/null || true)"
    if [[ -n "$_CURRENT_DIR" && -d "$_CURRENT_DIR" ]]; then
      _PLAYER_EMAIL="$(cat "$_CURRENT_DIR/.player" 2>/dev/null || true)"
      [[ -n "$_PLAYER_EMAIL" ]] && \
        _PLAYER_NPUB="$(cat "$HOME/.zen/game/nostr/${_PLAYER_EMAIL}/NPUB" 2>/dev/null || true)"
    fi

    if [[ -n "$_PLAYER_NPUB" ]]; then
      step "Aucun cookie fourni — tentative de récupération depuis UPassport…"
      _COOKIE_TMP="$(mktemp /tmp/notebooklm_cookie_XXXXXX.txt)"
      _HTTP_STATUS="$(curl -sf -w "%{http_code}" -o "$_COOKIE_TMP" \
        "${_UPASSPORT}/cookie/notebooklm.google.com?npub=${_PLAYER_NPUB}" 2>/dev/null || echo 000)"
      if [[ "$_HTTP_STATUS" == "200" ]] && grep -q "Netscape HTTP" "$_COOKIE_TMP" 2>/dev/null; then
        ok "Cookie NotebookLM récupéré depuis UPassport"
        NB_COOKIE_FILE="$_COOKIE_TMP"
        # Nettoyage du cookie temp à la sortie (en plus de TMPDIR_EXTRACT)
        trap 'rm -rf "$TMPDIR_EXTRACT" "$_COOKIE_TMP" 2>/dev/null || true' EXIT
      else
        rm -f "$_COOKIE_TMP"
        warn "Cookie NotebookLM absent dans UPassport."
        # Ouvrir la page d'upload et demander à l'utilisateur
        step "Ouverture de la page cookie UPassport…"
        xdg-open "${_UPASSPORT}/cookie?npub=${_PLAYER_NPUB}" 2>/dev/null || \
          echo "   👉 Ouvrez : ${_UPASSPORT}/cookie?npub=${_PLAYER_NPUB}"
        echo ""
        ask "Uploadez votre cookie NotebookLM (notebooklm.google.com) puis :"
        echo -e "   ${C_DIM}[1] Entrez le chemin vers le fichier cookie Netscape${C_RESET}"
        echo -e "   ${C_DIM}[2] Ou collez les cookies inline (ex: SID=x; HSID=y; ...)${C_RESET}"
        echo ""
        read -r -p "   Chemin fichier (ou Entrée pour cookies inline) : " _INPUT
        if [[ -n "$_INPUT" ]]; then
          [[ ! -f "$_INPUT" ]] && fail "Fichier introuvable : $_INPUT"
          NB_COOKIE_FILE="$_INPUT"
        else
          read -r -p "   Cookies inline : " NB_COOKIE
          [[ -z "$NB_COOKIE" ]] && fail "Cookie requis pour accéder à NotebookLM."
        fi
      fi
    else
      fail "--cookie ou --cookie-file requis (aucun joueur courant pour récupérer depuis UPassport)"
    fi
  fi
fi

# ─── Étape 1 : Extraction du notebook ─────────────────────────────────────────
header "Étape 1 — Extraction du notebook"

TMPDIR_EXTRACT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_EXTRACT"' EXIT

if [[ "$SKIP_EXTRACT" == true ]]; then
  ok "JSON fourni directement : $NOTEBOOK_JSON"
else
  step "Lancement de Playwright (headless)…"

  EXTRACT_ARGS=(
    --url "$NB_URL"
    --json
    --file "$TMPDIR_EXTRACT"
    --quiet
  )

  if [[ -n "$NB_COOKIE_FILE" ]]; then
    EXTRACT_ARGS+=(--cookie-file "$NB_COOKIE_FILE")
  else
    EXTRACT_ARGS+=(--cookie "$NB_COOKIE")
  fi

  python3 "$EXTRACTOR" "${EXTRACT_ARGS[@]}" || \
    fail "Extraction échouée. Vérifiez vos cookies ou relancez avec --headed."

  NOTEBOOK_JSON="$TMPDIR_EXTRACT/notebook.json"
  ok "Notebook extrait → $NOTEBOOK_JSON"
fi

[[ -f "$NOTEBOOK_JSON" ]] || fail "Fichier JSON introuvable : $NOTEBOOK_JSON"

# ─── Lecture du JSON ───────────────────────────────────────────────────────────
header "Étape 2 — Analyse du notebook"

if $JQ_AVAILABLE; then
  NB_TITLE="$(jq -r '.notebook.title // "Notebook sans titre"' "$NOTEBOOK_JSON")"
  NB_ID="$(jq -r '.meta.notebook_id // "unknown"' "$NOTEBOOK_JSON")"
  NB_SOURCE_COUNT="$(jq '.notebook.sources | length' "$NOTEBOOK_JSON")"
  NB_NOTE_COUNT="$(jq '.notebook.notes | length' "$NOTEBOOK_JSON")"
  NB_CHAT_COUNT="$(jq '.notebook.chat_history | length' "$NOTEBOOK_JSON")"
  NB_API_COUNT="$(jq '.api_calls_captured // 0' "$NOTEBOOK_JSON")"
else
  NB_TITLE="$(python3 -c "import json,sys; d=json.load(open('$NOTEBOOK_JSON')); print(d['notebook'].get('title','Notebook sans titre') or 'Notebook sans titre')")"
  NB_ID="$(python3 -c "import json,sys; d=json.load(open('$NOTEBOOK_JSON')); print(d['meta'].get('notebook_id','unknown') or 'unknown')")"
  NB_SOURCE_COUNT="$(python3 -c "import json; d=json.load(open('$NOTEBOOK_JSON')); print(len(d['notebook'].get('sources',[])))")"
  NB_NOTE_COUNT="$(python3 -c "import json; d=json.load(open('$NOTEBOOK_JSON')); print(len(d['notebook'].get('notes',[])))")"
  NB_CHAT_COUNT="$(python3 -c "import json; d=json.load(open('$NOTEBOOK_JSON')); print(len(d['notebook'].get('chat_history',[])))")"
  NB_API_COUNT="$(python3 -c "import json; d=json.load(open('$NOTEBOOK_JSON')); print(d.get('api_calls_captured',0))")"
fi

echo ""
echo -e "   ${C_BOLD}Titre   :${C_RESET} $NB_TITLE"
echo -e "   ${C_BOLD}ID      :${C_RESET} $NB_ID"
echo -e "   ${C_BOLD}Sources :${C_RESET} $NB_SOURCE_COUNT"
echo -e "   ${C_BOLD}Notes   :${C_RESET} $NB_NOTE_COUNT"
echo -e "   ${C_BOLD}Chat    :${C_RESET} $NB_CHAT_COUNT tours"
echo -e "   ${C_BOLD}API     :${C_RESET} $NB_API_COUNT appels capturés"

# Extraction des sources pour les afficher
if $JQ_AVAILABLE; then
  SOURCE_TITLES="$(jq -r '.notebook.sources[].title' "$NOTEBOOK_JSON" 2>/dev/null | head -10 || true)"
else
  SOURCE_TITLES="$(python3 -c "
import json
d = json.load(open('$NOTEBOOK_JSON'))
for s in d['notebook']['sources'][:10]:
    print(s.get('title','?'))
" 2>/dev/null || true)"
fi

if [[ -n "$SOURCE_TITLES" ]]; then
  echo ""
  echo -e "   ${C_DIM}Sources détectées :${C_RESET}"
  while IFS= read -r src; do
    [[ -n "$src" ]] && echo -e "     ${C_DIM}•${C_RESET} $src"
  done <<< "$SOURCE_TITLES"
fi

# ─── Étape 3 : Contexte technique (questions interactives) ────────────────────
header "Étape 3 — Contexte technique du projet"

prompt_default() {
  # prompt_default "question" "valeur_par_defaut"
  local question="$1"
  local default="$2"
  if $NON_INTERACTIVE; then
    echo "$default"
    return
  fi
  ask "$question"
  dim "Entrée vide = valeur par défaut : $default"
  read -r -p "   > " value
  echo "${value:-$default}"
}

prompt_required() {
  local question="$1"
  local default="${2:-}"
  if $NON_INTERACTIVE && [[ -n "$default" ]]; then
    echo "$default"
    return
  fi
  local value=""
  while [[ -z "$value" ]]; do
    ask "$question"
    [[ -n "$default" ]] && dim "Entrée vide = $default"
    read -r -p "   > " value
    value="${value:-$default}"
    [[ -z "$value" ]] && warn "Ce champ est requis."
  done
  echo "$value"
}

prompt_choice() {
  # prompt_choice "question" "choix1|choix2|..." "défaut"
  local question="$1"
  local choices="$2"
  local default="$3"
  if $NON_INTERACTIVE; then echo "$default"; return; fi
  ask "$question"
  IFS='|' read -ra opts <<< "$choices"
  local i=1
  for opt in "${opts[@]}"; do
    if [[ "$opt" == "$default" ]]; then
      echo -e "   ${C_GREEN}[$i]${C_RESET} $opt ${C_DIM}(défaut)${C_RESET}"
    else
      echo -e "   [$i] $opt"
    fi
    ((i++))
  done
  read -r -p "   > " sel
  if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#opts[@]} )); then
    echo "${opts[$((sel-1))]}"
  else
    echo "$default"
  fi
}

prompt_multiline() {
  local question="$1"
  local default="${2:-}"
  if $NON_INTERACTIVE; then echo "$default"; return; fi
  ask "$question"
  dim "(Terminez par une ligne vide ou Ctrl+D)"
  local lines=()
  while IFS= read -r line; do
    [[ -z "$line" ]] && break
    lines+=("$line")
  done
  if [[ ${#lines[@]} -eq 0 ]]; then
    echo "$default"
  else
    printf '%s\n' "${lines[@]}"
  fi
}

echo ""
dim "Répondez aux questions suivantes pour configurer le projet Git."
dim "Claude Code utilisera ces informations à chaque session."
echo ""

# Nom du projet
DEFAULT_SLUG="$(echo "$NB_TITLE" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//' | cut -c1-40)"
[[ -z "$DEFAULT_SLUG" ]] && DEFAULT_SLUG="mon-projet"
PROJECT_NAME="$(prompt_required "Nom du projet (slug, utilisé pour le dossier Git)" "$DEFAULT_SLUG")"
PROJECT_NAME="$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9-_' '-' | sed 's/^-//;s/-$//')"

# Description
PROJECT_DESC="$(prompt_required "Description courte du projet (1-2 phrases)" "Application générée à partir du notebook : $NB_TITLE")"

# Langage / stack
TECH_STACK="$(prompt_choice \
  "Stack technologique principale" \
  "TypeScript/Node.js|Python|Go|Rust|Java/Kotlin|PHP|Ruby|C#/.NET|Autre" \
  "TypeScript/Node.js")"

if [[ "$TECH_STACK" == "Autre" ]]; then
  TECH_STACK="$(prompt_required "Précisez la stack" "TypeScript/Node.js")"
fi

# Type d'application
APP_TYPE="$(prompt_choice \
  "Type d'application" \
  "API REST|Application web fullstack|CLI / outil en ligne de commande|Bibliothèque / SDK|Application mobile|Service microservice|Autre" \
  "API REST")"

# Framework
case "$TECH_STACK" in
  TypeScript*|JavaScript*)
    FW_DEFAULT="Express / Fastify"
    FW_CHOICES="Express|Fastify|NestJS|Next.js|Nuxt|Vite+React|Aucun / vanilla"
    ;;
  Python*)
    FW_DEFAULT="FastAPI"
    FW_CHOICES="FastAPI|Django|Flask|Starlette|Aucun / vanilla"
    ;;
  Go*)
    FW_DEFAULT="Gin"
    FW_CHOICES="Gin|Echo|Fiber|net/http|Aucun"
    ;;
  *)
    FW_DEFAULT="Aucun"
    FW_CHOICES="Aucun"
    ;;
esac

FRAMEWORK="$(prompt_choice "Framework principal" "$FW_CHOICES" "$FW_DEFAULT")"

# Base de données
DB="$(prompt_choice \
  "Base de données (si applicable)" \
  "PostgreSQL|MySQL/MariaDB|SQLite|MongoDB|Redis|Aucune" \
  "PostgreSQL")"

# Tests
TEST_FRAMEWORK="$(prompt_choice \
  "Framework de tests" \
  "Jest|Vitest|pytest|Go test|JUnit|RSpec|Aucun" \
  "$(if [[ "$TECH_STACK" == Python* ]]; then echo pytest; elif [[ "$TECH_STACK" == Go* ]]; then echo "Go test"; else echo Jest; fi)")"

# Conventions de code
echo ""
dim "Conventions de code (appuyer sur Entrée pour les defaults) :"
INDENT="$(prompt_default "  Indentation" "2 espaces")"
QUOTES="$(prompt_default "  Guillemets" "simples")"
LINTER="$(prompt_default "  Linter / formatter" "ESLint + Prettier")"

# Contraintes spécifiques
echo ""
CONSTRAINTS="$(prompt_multiline \
  "Contraintes ou règles spécifiques au projet ?" \
  "Aucune contrainte particulière.")"

# Dossier de sortie — défaut : ~/.zen/workspace/notebooklm/<name>
NB_WORKSPACE="${HOME}/.zen/workspace/notebooklm"
if [[ -z "$PROJECT_DIR" ]]; then
  PROJECT_DIR="$(prompt_default "Dossier de destination" "$NB_WORKSPACE/$PROJECT_NAME")"
fi

# ─── Étape 4 : Création du projet Git ─────────────────────────────────────────
header "Étape 4 — Création du projet Git"

# Résolution du chemin absolu (expansion ~ sans eval)
PROJECT_DIR="${PROJECT_DIR/#\~/$HOME}"
[[ "${PROJECT_DIR:0:1}" != "/" ]] && PROJECT_DIR="$(pwd)/$PROJECT_DIR"

# Créer le workspace notebooklm si nécessaire
mkdir -p "$NB_WORKSPACE"

if [[ -d "$PROJECT_DIR" ]]; then
  warn "Le dossier $PROJECT_DIR existe déjà."
  if ! $NON_INTERACTIVE; then
    read -r -p "   Continuer quand même ? [o/N] " confirm
    [[ "${confirm:-N}" =~ ^[oO]$ ]] || fail "Annulé."
  fi
else
  mkdir -p "$PROJECT_DIR"
fi

cd "$PROJECT_DIR"
step "Dossier : $PROJECT_DIR"

# Init Git
if [[ ! -d ".git" ]]; then
  git init -q
  ok "Dépôt Git initialisé"
else
  ok "Dépôt Git existant"
fi

# Structure de base
mkdir -p src tests docs .claude/commands .claude/rules
step "Structure de dossiers créée"

# ─── Génération des fichiers ───────────────────────────────────────────────────

# Timestamp et URL source
EXTRACTED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
NB_URL_SAFE="${NB_URL:-fourni via --notebook-json}"

# ── .gitignore ─────────────────────────────────────────────────────────────────
cat > .gitignore << EOF
# Dépendances
node_modules/
__pycache__/
*.pyc
.venv/
venv/
vendor/

# Build
dist/
build/
*.egg-info/
target/

# Environnement
.env
.env.*
!.env.example

# Éditeurs
.idea/
.vscode/
*.swp
*~

# OS
.DS_Store
Thumbs.db

# Claude Code — fichiers personnels (ne pas committer)
CLAUDE.local.md

# Données notebook (contient potentiellement des données sensibles)
.notebook_cache/
notebook_raw.html
notebook_screenshot.png
EOF
ok ".gitignore créé"

# ── README.md ──────────────────────────────────────────────────────────────────
cat > README.md << EOF
# $PROJECT_NAME

> $PROJECT_DESC

## Origine

Ce projet a été initialisé depuis le notebook NotebookLM :
- **Titre** : $NB_TITLE
- **ID** : \`$NB_ID\`
- **Extrait le** : $EXTRACTED_AT

## Stack

| Composant   | Choix             |
|-------------|-------------------|
| Langage     | $TECH_STACK       |
| Type        | $APP_TYPE         |
| Framework   | $FRAMEWORK        |
| Base de données | $DB           |
| Tests       | $TEST_FRAMEWORK   |

## Démarrage rapide

\`\`\`bash
# Cloner et installer
git clone <repo>
cd $PROJECT_NAME
# (commandes d'installation selon la stack)
\`\`\`

## Structure

\`\`\`
$PROJECT_NAME/
├── src/               # Code source
├── tests/             # Tests
├── docs/              # Documentation
├── .claude/
│   ├── commands/      # Commandes slash Claude Code
│   └── rules/         # Règles par chemin
├── CLAUDE.md          # Contexte persistant pour Claude Code
└── README.md
\`\`\`

## Développement avec Claude Code

Ce projet est configuré pour Claude Code. Lancez \`claude\` à la racine
pour démarrer une session avec tout le contexte préchargé.

Commandes slash disponibles :
- \`/review\`    — Revue de code selon les conventions du projet
- \`/test\`      — Générer ou compléter les tests
- \`/doc\`       — Documenter le code sélectionné
- \`/task\`      — Décomposer une fonctionnalité en tâches
- \`/notebook\`  — Consulter les sources et notes du notebook
EOF
ok "README.md créé"

# ── .env.example ──────────────────────────────────────────────────────────────
cat > .env.example << EOF
# Copiez ce fichier en .env et remplissez les valeurs
# Ne committez jamais .env

# Application
APP_ENV=development
APP_PORT=3000
APP_DEBUG=true

# Base de données
DB_HOST=localhost
DB_PORT=5432
DB_NAME=${PROJECT_NAME//-/_}_dev
DB_USER=
DB_PASSWORD=

# Secrets
SECRET_KEY=changeme
EOF
ok ".env.example créé"

# ── Extraction Markdown du notebook ───────────────────────────────────────────
step "Génération du digest Markdown du notebook…"

NOTEBOOK_DIGEST="$(python3 - << PYEOF
import json, sys, textwrap

try:
    with open("$NOTEBOOK_JSON") as f:
        d = json.load(f)
except Exception as e:
    print(f"(Impossible de lire le JSON : {e})")
    sys.exit(0)

nb = d.get("notebook", {})
meta = d.get("meta", {})
lines = []

lines.append("# Digest du Notebook")
lines.append("")
lines.append(f"**Titre** : {nb.get('title','?')}")
lines.append(f"**ID**    : \`{meta.get('notebook_id','?')}\`")
lines.append(f"**URL**   : {meta.get('source_url','?')}")
lines.append(f"**Extrait le** : {meta.get('extracted_at','?')}")
lines.append("")

# Sources
sources = nb.get("sources", [])
if sources:
    lines.append(f"## Sources ({len(sources)})")
    lines.append("")
    for s in sources:
        icon = {"pdf":"📄","web":"🌐","text":"📝","youtube":"▶️"}.get(s.get("type",""),"📎")
        lines.append(f"- {icon} **{s.get('title','?')}** *(type: {s.get('type','?')})*")
    lines.append("")

# Notes
notes = nb.get("notes", [])
if notes:
    lines.append(f"## Notes ({len(notes)})")
    lines.append("")
    for i, n in enumerate(notes, 1):
        content = n.get("content","").strip()
        if content:
            lines.append(f"### Note {i}")
            # Tronque à 1500 chars pour garder CLAUDE.md compact
            if len(content) > 1500:
                content = content[:1500] + "\n\n*(…tronqué — voir docs/notebook_full.json)*"
            lines.append(content)
            lines.append("")

# Chat (résumé)
chat = nb.get("chat_history", [])
if chat:
    lines.append(f"## Discussions ({len(chat)} tours)")
    lines.append("")
    lines.append("*(Extraits représentatifs)*")
    lines.append("")
    for turn in chat[:20]:  # 20 premiers tours max
        role = "**Vous**" if turn.get("role") == "user" else "**NotebookLM**"
        content = turn.get("content","").strip()[:600]
        if content:
            lines.append(f"{role}")
            lines.append("")
            lines.append(content)
            lines.append("")
            lines.append("---")
    if len(chat) > 20:
        lines.append(f"*… {len(chat)-20} tours supplémentaires dans docs/notebook_full.json*")

print("\n".join(lines))
PYEOF
)"

# Sauvegarde du JSON complet dans docs/
cp "$NOTEBOOK_JSON" docs/notebook_full.json
ok "docs/notebook_full.json copié"

# ── CLAUDE.md — Fichier mémoire principal ──────────────────────────────────────
cat > CLAUDE.md << CLAUDEMD
# $PROJECT_NAME — Contexte Claude Code

> Ce fichier est lu automatiquement par Claude Code à chaque session.
> Il constitue la mémoire persistante du projet.

---

## Identité du projet

| Champ        | Valeur                          |
|--------------|---------------------------------|
| Nom          | $PROJECT_NAME                   |
| Description  | $PROJECT_DESC                   |
| Type         | $APP_TYPE                       |
| Stack        | $TECH_STACK / $FRAMEWORK        |
| Base de données | $DB                          |
| Tests        | $TEST_FRAMEWORK                 |
| Initialisé   | $EXTRACTED_AT                   |

## Origine : NotebookLM

Ce projet est entièrement fondé sur le notebook :
- **Titre** : $NB_TITLE
- **ID** : \`$NB_ID\`
- **Sources** : $NB_SOURCE_COUNT documents analysés
- **Notes** : $NB_NOTE_COUNT notes extraites
- **Digest complet** : \`docs/notebook_full.json\`

@./docs/notebook_digest.md

## Architecture cible

\`\`\`
src/
├── core/          # Logique métier pure (pas de dépendances externes)
├── api/           # Couche HTTP / interface exposée
├── services/      # Services applicatifs
├── adapters/      # Connexions aux systèmes externes (DB, cache, etc.)
└── utils/         # Utilitaires partagés
tests/
├── unit/          # Tests unitaires (miroir de src/)
└── integration/   # Tests d'intégration
docs/
├── notebook_digest.md   # Résumé structuré du notebook
└── notebook_full.json   # Données brutes extraites
\`\`\`

## Conventions de code

- **Indentation** : $INDENT
- **Guillemets** : $QUOTES
- **Linter/Formatter** : $LINTER
- **Commits** : format Conventional Commits (\`feat:\`, \`fix:\`, \`docs:\`, \`test:\`, \`refactor:\`)
- **Branches** : \`main\` (stable) · \`develop\` (intégration) · \`feat/<slug>\` (fonctionnalités)

## Règles permanentes

1. **Toujours** écrire les tests avant ou en parallèle du code (\`$TEST_FRAMEWORK\`)
2. **Jamais** committer \`.env\` ou des secrets — utiliser \`.env.example\`
3. **Toujours** documenter les fonctions/classes publiques
4. **Ne jamais** modifier \`CLAUDE.md\` sans accord explicite — c'est la constitution du projet
5. Avant tout refactoring structurel, créer une branche dédiée

## Contraintes spécifiques

$CONSTRAINTS

## Commandes utiles

\`\`\`bash
# Lancer les tests
# (adapte selon ta stack)

# Linter
# (adapte selon ta stack)
\`\`\`

## Sources du notebook (référence rapide)

$(python3 - << 'PYEOF2'
import json, os
try:
    with open("docs/notebook_full.json") as f:
        d = json.load(f)
    sources = d.get("notebook", {}).get("sources", [])
    if sources:
        for s in sources[:15]:
            icon = {"pdf":"📄","web":"🌐","text":"📝","youtube":"▶️"}.get(s.get("type",""),"📎")
            print(f"- {icon} {s.get('title','?')}")
        if len(sources) > 15:
            print(f"- *(…{len(sources)-15} sources supplémentaires dans docs/notebook_full.json)*")
    else:
        print("- *(Aucune source détectée dans le JSON — vérifier docs/notebook_full.json)*")
except Exception:
    print("- *(Chargement des sources impossible — voir docs/notebook_full.json)*")
PYEOF2
)
CLAUDEMD

ok "CLAUDE.md créé"

# ── docs/notebook_digest.md ────────────────────────────────────────────────────
echo "$NOTEBOOK_DIGEST" > docs/notebook_digest.md
ok "docs/notebook_digest.md créé"

# ── .claude/rules/ — Règles par chemin ────────────────────────────────────────
cat > .claude/rules/api.md << 'EOF'
---
paths:
  - "src/api/**"
  - "src/routes/**"
---

# Règles — Couche API

- Valider systématiquement les entrées (schéma/Zod/Pydantic/validation framework)
- Retourner des erreurs structurées : `{ error: { code, message, details } }`
- Logger les erreurs inattendues avec contexte (mais jamais de données sensibles)
- Versionner les endpoints si une rupture de contrat est introduite
- Documenter chaque endpoint avec JSDoc/docstring incluant les codes de retour
EOF

cat > .claude/rules/tests.md << 'EOF'
---
paths:
  - "tests/**"
  - "**/*.test.*"
  - "**/*.spec.*"
---

# Règles — Tests

- Un test = un comportement attendu (pas un test par fonction)
- Nommer les tests : `should <comportement> when <condition>`
- Éviter les mocks globaux qui masquent les vrais comportements
- Les tests d'intégration doivent utiliser une base de données dédiée (pas la dev)
- Toujours nettoyer les fixtures après chaque test (teardown)
EOF

cat > .claude/rules/core.md << 'EOF'
---
paths:
  - "src/core/**"
  - "src/services/**"
---

# Règles — Logique métier

- Le core ne dépend d'aucun framework ni infrastructure (pur domaine)
- Utiliser des interfaces/protocoles pour toutes les dépendances externes
- Les erreurs métier sont des types explicites, pas des strings libres
- Pas d'effet de bord caché — chaque fonction déclare ce qu'elle modifie
EOF
ok ".claude/rules/ créé (3 règles de chemin)"

# ── Commandes slash Claude Code ────────────────────────────────────────────────

cat > .claude/commands/review.md << 'EOF'
---
description: Revue de code selon les conventions du projet
---

Effectue une revue de code exhaustive des fichiers modifiés ou fournis.

Vérifie :
1. **Conventions** : indentation, nommage, style (voir CLAUDE.md)
2. **Tests** : couverture suffisante ? cas limites couverts ?
3. **Erreurs** : gestion explicite de tous les cas d'erreur
4. **Sécurité** : pas de secrets exposés, validation des entrées
5. **Performance** : requêtes N+1, allocations inutiles, boucles imbriquées
6. **Documentation** : fonctions publiques documentées

Format de réponse :
- ✅ Points positifs
- ⚠️ Points à améliorer (non bloquants)
- 🔴 Problèmes bloquants à corriger avant merge
EOF

cat > .claude/commands/test.md << 'EOF'
---
description: Générer ou compléter les tests pour le code sélectionné
---

Pour le code fourni ou les fichiers récents :

1. Identifie les comportements à tester (happy path, edge cases, erreurs)
2. Génère des tests avec $TEST_FRAMEWORK suivant les conventions du projet
3. Nomme les tests : `should <résultat> when <condition>`
4. Ajoute des fixtures minimales (ne pas over-mocker)
5. Vérifie que chaque test est indépendant et idempotent
EOF

cat > .claude/commands/doc.md << 'EOF'
---
description: Documenter le code sélectionné
---

Documente le code fourni :

1. JSDoc/docstring pour chaque fonction/classe publique
2. Description du comportement (pas de la mécanique interne)
3. Paramètres : type, contraintes, valeurs par défaut
4. Valeur de retour et types d'erreurs possibles
5. Exemple d'utilisation si non trivial

Ne pas documenter les fonctions privées évidentes.
EOF

cat > .claude/commands/task.md << 'EOF'
---
description: Décomposer une fonctionnalité en tâches de développement
argument-hint: <description de la fonctionnalité>
---

Décompose la fonctionnalité suivante en tâches de développement : $ARGUMENTS

Pour chaque tâche :
1. Titre court (format : `[LAYER] Action`)
2. Description technique précise (2-5 lignes)
3. Dépendances (quelles tâches doivent être faites avant)
4. Critères d'acceptation testables
5. Estimation : XS / S / M / L / XL

Tiens compte de l'architecture définie dans CLAUDE.md.
EOF

cat > .claude/commands/notebook.md << EOF
---
description: Consulter les sources et notes du notebook d'origine
argument-hint: <question ou thème à rechercher>
---

Consulte les données extraites du notebook NotebookLM à l'origine de ce projet.

Fichiers de référence :
- \`docs/notebook_digest.md\` — résumé structuré
- \`docs/notebook_full.json\` — données brutes complètes

Requête : \$ARGUMENTS

Cherche dans les sources, notes et discussions du notebook.
Réponds en citant les passages pertinents.
Si aucune correspondance, dis-le clairement.
EOF

cat > .claude/commands/init-feature.md << 'EOF'
---
description: Initialiser le scaffolding d'une nouvelle fonctionnalité
argument-hint: <nom-de-la-feature>
---

Crée le scaffolding complet pour la fonctionnalité : $ARGUMENTS

Génère :
1. Branche Git : `feat/$ARGUMENTS`
2. Fichiers source dans `src/` (selon l'architecture du projet)
3. Fichier de tests correspondant dans `tests/`
4. Entrée dans `docs/` si API publique exposée

Respecte scrupuleusement les conventions de CLAUDE.md.
Ne génère pas de logique métier, uniquement la structure et les types/interfaces.
EOF
ok ".claude/commands/ créé (6 commandes slash)"

# ── Premier commit ─────────────────────────────────────────────────────────────
header "Étape 5 — Premier commit Git"

git add -A
git commit -q -m "feat: initialisation depuis NotebookLM

Notebook : $NB_TITLE
ID       : $NB_ID
Sources  : $NB_SOURCE_COUNT
Stack    : $TECH_STACK / $FRAMEWORK

Généré par git.notebook.sh"

ok "Premier commit créé"

# ─── Résumé final ─────────────────────────────────────────────────────────────
echo ""
echo -e "${C_BOLD}${C_GREEN}═══════════════════════════════════════════════════════${C_RESET}"
echo -e "${C_BOLD}${C_GREEN}  ✓  Projet initialisé avec succès !${C_RESET}"
echo -e "${C_BOLD}${C_GREEN}═══════════════════════════════════════════════════════${C_RESET}"
echo ""
echo -e "   ${C_BOLD}Dossier  :${C_RESET} $PROJECT_DIR"
echo -e "   ${C_BOLD}Stack    :${C_RESET} $TECH_STACK / $FRAMEWORK"
echo -e "   ${C_BOLD}Sources  :${C_RESET} $NB_SOURCE_COUNT documents du notebook intégrés"
echo ""
echo -e "   ${C_BOLD}Fichiers générés :${C_RESET}"
echo -e "   ${C_DIM}├── CLAUDE.md                  ← mémoire persistante de Claude Code${C_RESET}"
echo -e "   ${C_DIM}├── README.md${C_RESET}"
echo -e "   ${C_DIM}├── .gitignore${C_RESET}"
echo -e "   ${C_DIM}├── .env.example${C_RESET}"
echo -e "   ${C_DIM}├── docs/${C_RESET}"
echo -e "   ${C_DIM}│   ├── notebook_digest.md      ← résumé structuré du notebook${C_RESET}"
echo -e "   ${C_DIM}│   └── notebook_full.json      ← données brutes complètes${C_RESET}"
echo -e "   ${C_DIM}└── .claude/${C_RESET}"
echo -e "   ${C_DIM}    ├── commands/               ← /review /test /doc /task /notebook /init-feature${C_RESET}"
echo -e "   ${C_DIM}    └── rules/                  ← règles par chemin (api, tests, core)${C_RESET}"
echo ""
echo -e "   ${C_BOLD}Pour démarrer :${C_RESET}"
echo -e "   ${C_CYAN}cd $PROJECT_DIR && claude${C_RESET}"
echo ""
echo -e "   ${C_DIM}Dans Claude Code, tapez / pour voir les commandes disponibles.${C_RESET}"
echo ""
