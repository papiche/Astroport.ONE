#!/bin/bash
# =============================================================================
# claude-accounts v1.4.0 — Gestionnaire multi-comptes Claude Code
#
# Architecture :
#   ~/.claude        → symlink vers ~/.claude-{slug_default}  (compte actif par défaut)
#   ~/.claude.json   → symlink vers ~/.claude-{slug_default}/.claude.json
#   ~/.claude-{slug} → répertoire de config par compte
#
# Commandes : setup | add | migrate | list | remove | login | status | install | uninstall | help
# =============================================================================

VERSION="1.4.0"
SCRIPT_NAME="claude-accounts"
MARKER_START="# ── claude-accounts START ──"
MARKER_END="# ── claude-accounts END ──"
CONFIG_REGISTRY="$HOME/.claude-accounts.conf"
LOCAL_BIN="$HOME/.local/bin"
SELF_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# ── Couleurs ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ok()   { echo -e "${GREEN}✅ $*${RESET}"; }
warn() { echo -e "${YELLOW}⚠️  $*${RESET}"; }
err()  { echo -e "${RED}❌ $*${RESET}"; }
info() { echo -e "${CYAN}ℹ️  $*${RESET}"; }
h1()   { echo -e "\n${BOLD}${BLUE}$*${RESET}"; echo -e "${BLUE}$(printf '─%.0s' {1..54})${RESET}"; }

# ── Détection shell RC ────────────────────────────────────────────────────────
detect_shell_rc() {
  if [ -n "$ZSH_VERSION" ] || [ "$(basename "$SHELL")" = "zsh" ]; then
    echo "$HOME/.zshrc"
  elif [ -n "$BASH_VERSION" ] || [ "$(basename "$SHELL")" = "bash" ]; then
    echo "$HOME/.bashrc"
  else
    echo "$HOME/.profile"
  fi
}

# ── Vérification Claude Code ──────────────────────────────────────────────────
check_claude() {
  CLAUDE_BIN=$(which claude 2>/dev/null || echo "")
  if [ -z "$CLAUDE_BIN" ]; then
    err "Claude Code n'est pas installé."
    echo "  → npm install -g @anthropic-ai/claude-code"
    exit 1
  fi
}

# ── Normalise un nom en slug ──────────────────────────────────────────────────
slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g'
}

# ── Registre ──────────────────────────────────────────────────────────────────
load_registry()                { touch "$CONFIG_REGISTRY"; }
account_exists()               { grep -q "^${1}|" "$CONFIG_REGISTRY" 2>/dev/null; }
save_account()                 { echo "${1}|${2}|${3}" >> "$CONFIG_REGISTRY"; }
remove_account_from_registry() { sed -i "/^${1}|/d" "$CONFIG_REGISTRY"; }

get_default_slug() {
  # Retourne le slug du compte par défaut (celui pointé par ~/.claude symlink)
  local target
  target=$(readlink "$HOME/.claude" 2>/dev/null || echo "")
  if [ -n "$target" ]; then
    basename "$target" | sed 's/^\.claude-//'
  else
    echo ""
  fi
}

mark_default() {
  # Marque un compte comme défaut dans le registre (4ème champ)
  local slug="$1"
  # Retire l'ancien marqueur
  sed -i 's/|default$//' "$CONFIG_REGISTRY"
  # Ajoute le marqueur au nouveau défaut
  sed -i "s/^${slug}|\(.*\)$/${slug}|\1|default/" "$CONFIG_REGISTRY"
}

# ── Crée le symlink ~/.claude → ~/.claude-{slug} ─────────────────────────────
set_default_symlink() {
  local slug="$1"
  local dest="$HOME/.claude-${slug}"
  local link="$HOME/.claude"
  local link_json="$HOME/.claude.json"

  # ~/.claude symlink
  if [ -L "$link" ]; then
    rm -f "$link"
  elif [ -d "$link" ]; then
    err "~/.claude est un répertoire, pas un symlink. Migration requise d'abord."
    return 1
  fi
  ln -s "$dest" "$link"
  ok "~/.claude → ~/.claude-${slug}  (compte par défaut)"

  # ~/.claude.json symlink
  local json_src="${dest}/.claude.json"
  # Crée le fichier cible s'il n'existe pas encore (pour que le lien soit valide)
  touch "$json_src" 2>/dev/null || true
  if [ -L "$link_json" ]; then
    rm -f "$link_json"
  elif [ -f "$link_json" ]; then
    mv "$link_json" "$json_src"
    ok "~/.claude.json déplacé vers ~/.claude-${slug}/.claude.json"
  fi
  ln -s "$json_src" "$link_json"
  ok "~/.claude.json → ~/.claude-${slug}/.claude.json"

  mark_default "$slug"
}

# ── Saisie interactive d'un compte ───────────────────────────────────────────
# Usage : prompt_account [nom_suggere] [email_suggere]
# Remplit les vars globales : PROMPT_SLUG PROMPT_NAME PROMPT_EMAIL
prompt_account() {
  local sug_name="${1:-}" sug_email="${2:-}"

  # Nom
  while true; do
    if [ -n "$sug_name" ]; then
      echo -en "${BOLD}Nom de l'organisation${RESET} [${CYAN}${sug_name}${RESET}] : "
      read -r INPUT
      INPUT=$(echo "$INPUT" | xargs)
      PROMPT_NAME="${INPUT:-$sug_name}"
    else
      echo -en "${BOLD}Nom de l'organisation${RESET} (ex: MonEquipe) : "
      read -r PROMPT_NAME
      PROMPT_NAME=$(echo "$PROMPT_NAME" | xargs)
    fi
    [ -n "$PROMPT_NAME" ] && break
    warn "Le nom ne peut pas être vide."
  done

  # Email
  while true; do
    if [ -n "$sug_email" ]; then
      echo -en "${BOLD}Email du compte${RESET} [${CYAN}${sug_email}${RESET}] : "
      read -r INPUT
      INPUT=$(echo "$INPUT" | xargs)
      PROMPT_EMAIL="${INPUT:-$sug_email}"
    else
      echo -en "${BOLD}Email du compte${RESET} (ex: user@example.com) : "
      read -r PROMPT_EMAIL
      PROMPT_EMAIL=$(echo "$PROMPT_EMAIL" | xargs)
    fi
    echo "$PROMPT_EMAIL" | grep -qE '^[^@]+@[^@]+\.[^@]+$' && break
    warn "Email invalide. Réessaie."
  done

  # Slug
  local sug_slug
  sug_slug=$(slugify "$PROMPT_NAME")
  echo -en "Alias de commande [${CYAN}claude-${sug_slug}${RESET}] : "
  read -r INPUT
  INPUT=$(echo "$INPUT" | xargs)
  PROMPT_SLUG=$([ -n "$INPUT" ] && slugify "$INPUT" || echo "$sug_slug")
}

# ── Essaie de détecter l'email depuis ~/.claude.json ─────────────────────────
detect_current_email() {
  local json="$HOME/.claude.json"
  # Résoudre si symlink
  [ -L "$json" ] && json=$(readlink -f "$json" 2>/dev/null || echo "")
  [ -z "$json" ] || [ ! -f "$json" ] && echo "" && return

  # Cherche "email" ou "primaryEmail" dans le JSON (pas de dépendance jq)
  grep -oE '"(email|primaryEmail)"\s*:\s*"[^"]+"' "$json" 2>/dev/null \
    | head -1 \
    | grep -oE '"[^"]+@[^"]+"' \
    | tr -d '"' \
    || echo ""
}

# ── Essaie de détecter l'org depuis ~/.claude.json ───────────────────────────
detect_current_org() {
  local json="$HOME/.claude.json"
  [ -L "$json" ] && json=$(readlink -f "$json" 2>/dev/null || echo "")
  [ -z "$json" ] || [ ! -f "$json" ] && echo "" && return

  grep -oE '"(organizationName|orgName|organization)"\s*:\s*"[^"]+"' "$json" 2>/dev/null \
    | head -1 \
    | grep -oE ':\s*"[^"]+"' \
    | grep -oE '"[^"]+"' \
    | tr -d '"' \
    || echo ""
}

# ── Regénère le bloc d'alias ──────────────────────────────────────────────────
regenerate_aliases() {
  local shell_rc="$1"

  if grep -q "$MARKER_START" "$shell_rc" 2>/dev/null; then
    python3 - "$shell_rc" << 'PY'
import sys, re
path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()
content = re.sub(
    r'\n?# ── claude-accounts START ──.*?# ── claude-accounts END ──\n?',
    '', content, flags=re.DOTALL
)
with open(path, 'w') as f:
    f.write(content)
PY
  fi

  local default_slug
  default_slug=$(get_default_slug)

  # Résout le binaire à appeler : lien ~/.local/bin en priorité, sinon chemin absolu du script
  local bin_call
  if [ -x "${LOCAL_BIN}/${SCRIPT_NAME}" ]; then
    bin_call="${SCRIPT_NAME}"
  else
    bin_call="${SELF_PATH}"
  fi

  local all_slugs=""
  {
    echo ""
    echo "${MARKER_START}"
    echo "# claude-accounts v${VERSION} — comptes Claude Code"
    echo "# ~/.claude → symlink vers le compte par défaut"
    echo "# bin: ${bin_call}"
    echo "#"
    while IFS='|' read -r slug name email _rest; do
      [ -z "$slug" ] && continue
      local marker=""
      [ "$slug" = "$default_slug" ] && marker=" (défaut ✦)"
      echo "#   claude-${slug} → ${name} (${email})${marker}"
      all_slugs="${all_slugs}claude-${slug} "
    done < "$CONFIG_REGISTRY"
    echo "#   claude-default  → bascule le compte par défaut (~/.claude symlink)"
    echo "#   claude-list     → liste les comptes"
    echo ""
    while IFS='|' read -r slug name email _rest; do
      [ -z "$slug" ] && continue
      echo "alias claude-${slug}='CLAUDE_CONFIG_DIR=\$HOME/.claude-${slug} command claude'"
    done < "$CONFIG_REGISTRY"
    echo "alias claude-default='${bin_call} default'"
    echo "alias claude-list='${bin_call} list'"
    echo "alias claude='echo \"⚠️  Précise le compte : ${all_slugs% } | ou: claude (sans suffixe = compte par défaut via symlink)\"'"
    echo "${MARKER_END}"
  } >> "$shell_rc"

  ok "Alias régénérés dans $shell_rc"
}

# ══════════════════════════════════════════════════════════════════════════════
# COMMANDE : migrate — migration de la config existante + symlink
# ══════════════════════════════════════════════════════════════════════════════
cmd_migrate() {
  h1 "Migration de la config Claude existante"
  load_registry

  local src_dir="$HOME/.claude"
  local src_json="$HOME/.claude.json"
  local has_dir=0 has_json=0

  # ── Analyse de l'existant ─────────────────────────────────────────────────
  echo -e "${BOLD}Analyse de la config actuelle...${RESET}"
  echo ""

  if [ -L "$src_dir" ]; then
    local current_link
    current_link=$(readlink "$src_dir")
    info "~/.claude est déjà un symlink → $current_link"
    info "Migration déjà effectuée ou symlink manuel."
    echo -en "Reconfigurer quand même ? [o/N] : "
    read -r R; [ "$(echo "$R" | tr '[:upper:]' '[:lower:]')" != "o" ] && { info "Annulé."; exit 0; }
  elif [ -d "$src_dir" ]; then
    has_dir=1
    echo -e "  ${GREEN}~/.claude/${RESET}       répertoire trouvé  ($(du -sh "$src_dir" 2>/dev/null | cut -f1))"
  else
    echo -e "  ${YELLOW}~/.claude/${RESET}       absent"
  fi

  if [ -L "$src_json" ]; then
    info "~/.claude.json est déjà un symlink → $(readlink "$src_json")"
  elif [ -f "$src_json" ]; then
    has_json=1
    echo -e "  ${GREEN}~/.claude.json${RESET}    trouvé"
  elif [ "$has_dir" -eq 1 ] && [ -f "${src_dir}/.claude.json" ]; then
    # .claude.json est à l'intérieur du répertoire ~/.claude/ (cas fréquent)
    src_json="${src_dir}/.claude.json"
    has_json=1
    echo -e "  ${GREEN}~/.claude/.claude.json${RESET}  trouvé (dans le répertoire)"
  else
    echo -e "  ${YELLOW}~/.claude.json${RESET}    absent (sera créé vide)"
  fi

  # ── Détection auto de l'email / org (cherche dans src_json résolu) ─────────
  local detected_email detected_org
  # Passe le chemin résolu à la détection (src_dir/.claude.json si src_json a été trouvé dedans)
  detected_email=$(grep -oE '"(email|primaryEmail)"\s*:\s*"[^"]+"' "${src_json}" 2>/dev/null     | head -1 | grep -oE '"[^"]+@[^"]+"' | tr -d '"' || echo "")
  detected_org=$(grep -oE '"(organizationName|orgName|organization)"\s*:\s*"[^"]+"' "${src_json}" 2>/dev/null     | head -1 | grep -oE ':\s*"[^"]+"' | grep -oE '"[^"]+"' | tr -d '"' || echo "")

  echo ""
  if [ -n "$detected_email" ] || [ -n "$detected_org" ]; then
    echo -e "${BOLD}Compte détecté dans la config existante :${RESET}"
    [ -n "$detected_org" ]   && echo -e "  Organisation : ${CYAN}${detected_org}${RESET}"
    [ -n "$detected_email" ] && echo -e "  Email        : ${CYAN}${detected_email}${RESET}"
    echo ""
  fi

  # ── Saisie du compte de destination ──────────────────────────────────────
  h1 "Compte de destination"

  # Propose les comptes existants du registre ou création d'un nouveau
  local existing_count=0
  if [ -s "$CONFIG_REGISTRY" ]; then
    echo "Comptes déjà enregistrés :"
    local i=1
    local slugs=() names=()
    while IFS='|' read -r slug name email _rest; do
      [ -z "$slug" ] && continue
      echo -e "  [$i] ${CYAN}${name}${RESET} (${email})  →  ~/.claude-${slug}"
      slugs+=("$slug"); names+=("$name")
      ((i++)); ((existing_count++))
    done < "$CONFIG_REGISTRY"
    echo "  [N] Nouveau compte"
    echo ""
    echo -en "Choix [1-${existing_count} ou N] : "
    read -r CHOICE
  else
    CHOICE="N"
  fi

  local TARGET_SLUG TARGET_NAME TARGET_EMAIL

  if [ "$(echo "$CHOICE" | tr '[:upper:]' '[:lower:]')" = "n" ] || [ -z "$CHOICE" ] || [ "$existing_count" -eq 0 ]; then
    echo ""
    info "Saisie du nouveau compte :"
    prompt_account "$detected_org" "$detected_email"
    TARGET_SLUG="$PROMPT_SLUG"
    TARGET_NAME="$PROMPT_NAME"
    TARGET_EMAIL="$PROMPT_EMAIL"

    if account_exists "$TARGET_SLUG"; then
      err "Un compte 'claude-${TARGET_SLUG}' existe déjà."
      exit 1
    fi
    mkdir -p "$HOME/.claude-${TARGET_SLUG}"
    save_account "$TARGET_SLUG" "$TARGET_NAME" "$TARGET_EMAIL"
    ok "Compte '${TARGET_NAME}' enregistré."
  else
    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt "$existing_count" ]; then
      err "Choix invalide."; exit 1
    fi
    TARGET_SLUG="${slugs[$((CHOICE-1))]}"
    TARGET_NAME="${names[$((CHOICE-1))]}"
    TARGET_EMAIL=$(grep "^${TARGET_SLUG}|" "$CONFIG_REGISTRY" | cut -d'|' -f3)
  fi

  local dest="$HOME/.claude-${TARGET_SLUG}"
  mkdir -p "$dest"

  # ── Récapitulatif ─────────────────────────────────────────────────────────
  echo ""
  echo -e "┌──────────────────────────────────────────────────────┐"
  echo -e "│  Compte  : ${BOLD}${TARGET_NAME}${RESET} (${TARGET_EMAIL})"
  echo -e "│  Slot    : ${CYAN}~/.claude-${TARGET_SLUG}/${RESET}"
  echo -e "│  Symlink : ${CYAN}~/.claude${RESET} → ${CYAN}~/.claude-${TARGET_SLUG}/${RESET}  ${BOLD}(compte par défaut)${RESET}"
  if [ "$has_dir" -eq 1 ]; then
  echo -e "│  Action  : contenu ~/.claude/ copié vers le slot"
  fi
  if [ "$has_json" -eq 1 ]; then
  echo -e "│  Action  : ~/.claude.json déplacé vers le slot"
  fi
  echo -e "└──────────────────────────────────────────────────────┘"
  echo ""
  echo -en "Confirmer ? [O/n] : "
  read -r CONFIRM
  [ "$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')" = "n" ] && { info "Annulé."; exit 0; }

  # ── Sauvegarde si dest non vide ───────────────────────────────────────────
  if [ -d "$dest" ] && [ "$(ls -A "$dest" 2>/dev/null)" ]; then
    echo -en "Le slot ~/.claude-${TARGET_SLUG} n'est pas vide. Sauvegarder avant ? [O/n] : "
    read -r DO_BK
    if [ "$(echo "$DO_BK" | tr '[:upper:]' '[:lower:]')" != "n" ]; then
      local backup="${dest}.backup.$(date +%Y%m%d_%H%M%S)"
      cp -a "$dest" "$backup"
      ok "Sauvegarde : $backup"
    fi
  fi

  # ── Copie du contenu ~/.claude/ → slot ────────────────────────────────────
  if [ "$has_dir" -eq 1 ]; then
    cp -a "${src_dir}/." "$dest/"
    ok "~/.claude/ copié vers ~/.claude-${TARGET_SLUG}/"
    # Sauvegarde puis supprime le répertoire source (sera remplacé par symlink)
    mv "$src_dir" "${src_dir}.pre-migrate.$(date +%Y%m%d_%H%M%S)"
    ok "~/.claude/ sauvegardé (renommé .pre-migrate.*)"
  fi

  # ── Déplace ~/.claude.json → slot ─────────────────────────────────────────
  if [ "$has_json" -eq 1 ]; then
    # Si src_json était dans src_dir, il a déjà été copié par cp -a ci-dessus
    if [ "$src_json" = "$HOME/.claude.json" ]; then
      cp "$src_json" "${dest}/.claude.json"
      rm -f "$src_json"
      ok "~/.claude.json déplacé vers ~/.claude-${TARGET_SLUG}/.claude.json"
    else
      ok "~/.claude.json déjà présent dans ~/.claude-${TARGET_SLUG}/ (copié avec le répertoire)"
    fi
  fi

  # ── Crée les symlinks ─────────────────────────────────────────────────────
  set_default_symlink "$TARGET_SLUG"

  # ── Régénère les alias ────────────────────────────────────────────────────
  local shell_rc
  shell_rc=$(detect_shell_rc)
  regenerate_aliases "$shell_rc"

  h1 "Résultat"
  echo -e "  ${CYAN}~/.claude${RESET}      → ${CYAN}~/.claude-${TARGET_SLUG}/${RESET}"
  echo -e "  ${CYAN}~/.claude.json${RESET} → ${CYAN}~/.claude-${TARGET_SLUG}/.claude.json${RESET}"
  echo ""
  echo "Claude (sans alias) utilise maintenant automatiquement ${TARGET_NAME}."
  echo "Pour les autres comptes, utilise les alias dédiés."
  echo ""
  ok "Migration terminée ! Recharge : source $shell_rc"
}

# ══════════════════════════════════════════════════════════════════════════════
# COMMANDE : default — change le compte par défaut (rebascule le symlink)
# ══════════════════════════════════════════════════════════════════════════════
cmd_default() {
  h1 "Changer le compte par défaut"
  load_registry

  [ ! -s "$CONFIG_REGISTRY" ] && { warn "Aucun compte enregistré."; exit 0; }

  local current
  current=$(get_default_slug)
  [ -n "$current" ] && echo -e "Compte par défaut actuel : ${CYAN}claude-${current}${RESET}" || echo "Aucun compte par défaut défini."
  echo ""

  local i=1
  local slugs=() names=()
  while IFS='|' read -r slug name email _rest; do
    [ -z "$slug" ] && continue
    local marker=""; [ "$slug" = "$current" ] && marker=" ✦"
    echo -e "  [$i] ${CYAN}${name}${RESET} (${email})${marker}"
    slugs+=("$slug"); names+=("$name")
    ((i++))
  done < "$CONFIG_REGISTRY"
  echo ""
  echo -en "Nouveau compte par défaut [1-$((i-1))] : "
  read -r CHOICE

  if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt $((i-1)) ]; then
    err "Choix invalide."; exit 1
  fi

  local new_slug="${slugs[$((CHOICE-1))]}"
  local new_name="${names[$((CHOICE-1))]}"

  if [ "$new_slug" = "$current" ]; then
    info "Déjà le compte par défaut."; exit 0
  fi

  set_default_symlink "$new_slug"

  local shell_rc
  shell_rc=$(detect_shell_rc)
  regenerate_aliases "$shell_rc"

  ok "${new_name} est maintenant le compte par défaut."
  info "Recharge : source $shell_rc"
}

# ══════════════════════════════════════════════════════════════════════════════
# COMMANDE : setup — premier lancement totalement interactif
# ══════════════════════════════════════════════════════════════════════════════
cmd_setup() {
  h1 "Claude Code — Setup multi-comptes"
  check_claude
  load_registry

  local shell_rc
  shell_rc=$(detect_shell_rc)
  echo -e "Shell RC : ${CYAN}${shell_rc}${RESET}"

  # Détection config existante
  local detected_email detected_org
  detected_email=$(detect_current_email)
  detected_org=$(detect_current_org)

  local has_existing=0
  if [ -d "$HOME/.claude" ] && [ ! -L "$HOME/.claude" ]; then
    has_existing=1
  fi

  if [ "$has_existing" -eq 1 ] || [ -f "$HOME/.claude.json" ] && [ ! -L "$HOME/.claude.json" ]; then
    echo ""
    warn "Une config Claude existante a été détectée (~/.claude/ ou ~/.claude.json)."
    echo "  Il est recommandé de lancer ${CYAN}migrate${RESET} d'abord pour la rattacher à un compte."
    echo -en "Lancer migrate maintenant ? [O/n] : "
    read -r R
    if [ "$(echo "$R" | tr '[:upper:]' '[:lower:]')" != "n" ]; then
      cmd_migrate
      return
    fi
  fi

  echo ""
  echo "Combien de comptes souhaites-tu configurer ? (min 1)"
  echo -en "Nombre de comptes [${CYAN}2${RESET}] : "
  read -r NB_ACCOUNTS
  NB_ACCOUNTS=$(echo "$NB_ACCOUNTS" | xargs)
  [[ "$NB_ACCOUNTS" =~ ^[0-9]+$ ]] && [ "$NB_ACCOUNTS" -ge 1 ] || NB_ACCOUNTS=2

  local first_slug=""
  for ((n=1; n<=NB_ACCOUNTS; n++)); do
    echo ""
    echo -e "${BOLD}── Compte $n / $NB_ACCOUNTS ──────────────────────────────────${RESET}"

    # Pré-remplissage pour le 1er compte si détection possible
    local sug_name="" sug_email=""
    if [ "$n" -eq 1 ]; then
      sug_name="$detected_org"
      sug_email="$detected_email"
      [ -n "$sug_name" ] && info "Config détectée proposée en valeur par défaut."
    fi

    prompt_account "$sug_name" "$sug_email"

    if account_exists "$PROMPT_SLUG"; then
      warn "Compte 'claude-${PROMPT_SLUG}' déjà enregistré — ignoré."
      continue
    fi

    mkdir -p "$HOME/.claude-${PROMPT_SLUG}"
    save_account "$PROMPT_SLUG" "$PROMPT_NAME" "$PROMPT_EMAIL"
    ok "Compte ${PROMPT_NAME} enregistré → ~/.claude-${PROMPT_SLUG}"

    [ "$n" -eq 1 ] && first_slug="$PROMPT_SLUG"
  done

  # Symlink par défaut sur le 1er compte
  if [ -n "$first_slug" ]; then
    echo ""
    echo -e "Le premier compte (${CYAN}${first_slug}${RESET}) sera le compte par défaut (~/.claude symlink)."
    echo -en "Confirmer ou choisir un autre slug : [${CYAN}${first_slug}${RESET}] : "
    read -r DEFAULT_CHOICE
    DEFAULT_CHOICE=$(echo "$DEFAULT_CHOICE" | xargs)
    local default_slug="${DEFAULT_CHOICE:-$first_slug}"
    if account_exists "$default_slug"; then
      set_default_symlink "$default_slug"
    else
      warn "Slug '$default_slug' introuvable, utilisation de '$first_slug'."
      set_default_symlink "$first_slug"
    fi
  fi

  regenerate_aliases "$shell_rc"
  cmd_install

  h1 "Première connexion (à faire 1x par compte)"
  echo ""
  while IFS='|' read -r slug name email _rest; do
    [ -z "$slug" ] && continue
    echo -e "  ${CYAN}claude-${slug}${RESET}   # ${name} (${email})"
    echo -e "  ${YELLOW}# → 'Claude account with subscription' → ${name} → /exit${RESET}"
    echo ""
  done < "$CONFIG_REGISTRY"
  echo -e "  ${BOLD}source ${shell_rc}${RESET}"
  echo ""
  ok "Setup terminé !"
}


# ══════════════════════════════════════════════════════════════════════════════
# FONCTION : copy_context — copie le contexte de travail d'un compte vers un autre
#
# Copié  (profil, workspace) : CLAUDE.md, settings.json, plugins/, projects/
# Exclu  (session, secrets)  : .credentials.json, .claude.json, history.jsonl,
#                              backups/, cache/, downloads/, file-history/,
#                              paste-cache/, session-env/, sessions/, ide/
# ══════════════════════════════════════════════════════════════════════════════
CONTEXT_ITEMS=(
  "CLAUDE.md"
  "settings.json"
  "settings.json.bak"
  "plugins"
  "projects"
  "plans"
)
CONTEXT_EXCLUDE=(
  ".credentials.json"
  ".claude.json"
  "history.jsonl"
  "stats-cache.json"
  "mcp-needs-auth-cache.json"
  "policy-limits.json"
  "backups"
  "cache"
  "downloads"
  "file-history"
  "paste-cache"
  "session-env"
  "sessions"
  "ide"
)

copy_context() {
  local src_slug="$1" dest_slug="$2"
  local src="$HOME/.claude-${src_slug}"
  local dest="$HOME/.claude-${dest_slug}"

  if [ ! -d "$src" ]; then
    warn "Répertoire source ~/.claude-${src_slug} introuvable."; return 1
  fi

  echo ""
  echo -e "${BOLD}Éléments copiés de ${CYAN}${src_slug}${RESET}${BOLD} vers ${CYAN}${dest_slug}${RESET}${BOLD} :${RESET}"
  echo -e "${YELLOW}  (credentials, historique et cache exclus)${RESET}"
  echo ""

  local copied=0
  for item in "${CONTEXT_ITEMS[@]}"; do
    local src_item="${src}/${item}"
    if [ -e "$src_item" ]; then
      if [ -d "$src_item" ]; then
        cp -a "$src_item" "${dest}/"
      else
        cp "$src_item" "${dest}/${item}"
      fi
      echo -e "  ${GREEN}✓${RESET} ${item}"
      ((copied++))
    fi
  done

  if [ "$copied" -eq 0 ]; then
    info "Aucun élément de contexte trouvé dans ~/.claude-${src_slug}."
  else
    ok "${copied} élément(s) copié(s)."
  fi
  echo ""
}

# ── Propose le menu de copie de contexte ─────────────────────────────────────
prompt_copy_context() {
  local dest_slug="$1"
  load_registry

  # Comptes sources disponibles (exclu le compte qu'on vient de créer)
  local i=1
  local slugs=() names=()
  while IFS="|" read -r slug name email _rest; do
    [ -z "$slug" ] && continue
    [ "$slug" = "$dest_slug" ] && continue
    [ ! -d "$HOME/.claude-${slug}" ] && continue
    slugs+=("$slug"); names+=("$name")
    ((i++))
  done < "$CONFIG_REGISTRY"

  local nb_sources=${#slugs[@]}
  [ "$nb_sources" -eq 0 ] && return  # rien à proposer

  echo -e "${BOLD}Copier le contexte de travail d'un compte existant ?${RESET}"
  echo -e "${CYAN}  (CLAUDE.md, settings, plugins, projects — sans credentials ni historique)${RESET}"
  echo ""

  # Propose un profil optionnel
  echo -e "  ${BOLD}Profil de ce compte${RESET} (décrit le rôle de ce compte dans CLAUDE.md)"
  echo -e "  Exemples : 'Architecte réseau, développeur backend'"
  echo -e "             'Responsable produit, marketing'"
  echo -en "  Profil [laisser vide pour ne pas personnaliser] : "
  read -r CONTEXT_PROFILE
  CONTEXT_PROFILE=$(echo "$CONTEXT_PROFILE" | xargs)

  echo ""
  for ((j=0; j<nb_sources; j++)); do
    echo -e "  [$((j+1))] Copier depuis ${CYAN}${names[$j]}${RESET} (~/.claude-${slugs[$j]})"
  done
  echo "  [0] Démarrer avec une config vierge"
  echo ""
  echo -en "Choix [0-${nb_sources}] : "
  read -r CTX_CHOICE

  if [[ "$CTX_CHOICE" =~ ^[1-9][0-9]*$ ]] && [ "$CTX_CHOICE" -le "$nb_sources" ]; then
    local src_slug="${slugs[$((CTX_CHOICE-1))]}"
    copy_context "$src_slug" "$dest_slug"

    # Personnalise CLAUDE.md avec le profil si renseigné
    if [ -n "$CONTEXT_PROFILE" ]; then
      local claude_md="$HOME/.claude-${dest_slug}/CLAUDE.md"
      local profile_block="## Profil de ce compte\n${CONTEXT_PROFILE}\n"
      if [ -f "$claude_md" ]; then
        # Remplace ou ajoute la section Profil
        if grep -q "^## Profil de ce compte" "$claude_md"; then
          python3 - "$claude_md" "$CONTEXT_PROFILE" << 'PYMD'
import sys, re
path, profile = sys.argv[1], sys.argv[2]
with open(path) as f: c = f.read()
c = re.sub(r'## Profil de ce compte
.*?
(
|$)', f'## Profil de ce compte
{profile}

', c, flags=re.DOTALL)
with open(path, 'w') as f: f.write(c)
PYMD
        else
          printf "
## Profil de ce compte
%s
" "$CONTEXT_PROFILE" >> "$claude_md"
        fi
        ok "Profil ajouté dans CLAUDE.md : $CONTEXT_PROFILE"
      else
        printf "## Profil de ce compte
%s
" "$CONTEXT_PROFILE" > "$claude_md"
        ok "CLAUDE.md créé avec le profil : $CONTEXT_PROFILE"
      fi
    fi
  else
    if [ -n "$CONTEXT_PROFILE" ] && [ ! -f "$HOME/.claude-${dest_slug}/CLAUDE.md" ]; then
      printf "## Profil de ce compte
%s
" "$CONTEXT_PROFILE" > "$HOME/.claude-${dest_slug}/CLAUDE.md"
      ok "CLAUDE.md créé avec le profil : $CONTEXT_PROFILE"
    fi
    info "Démarrage avec une config vierge."
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# COMMANDE : add
# ══════════════════════════════════════════════════════════════════════════════
cmd_add() {
  h1 "Ajouter un nouveau compte Claude"
  check_claude
  load_registry
  local shell_rc
  shell_rc=$(detect_shell_rc)

  prompt_account

  if account_exists "$PROMPT_SLUG"; then
    err "Un compte 'claude-${PROMPT_SLUG}' existe déjà."
    exit 1
  fi

  echo ""
  echo -e "┌─────────────────────────────────────────┐"
  echo -e "│  Organisation : ${BOLD}${PROMPT_NAME}${RESET}"
  echo -e "│  Email        : ${BOLD}${PROMPT_EMAIL}${RESET}"
  echo -e "│  Alias        : ${CYAN}claude-${PROMPT_SLUG}${RESET}"
  echo -e "│  Config dir   : ~/.claude-${PROMPT_SLUG}"
  echo -e "└─────────────────────────────────────────┘"
  echo ""
  echo -en "Confirmer ? [O/n] : "
  read -r CONFIRM
  [ "$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')" = "n" ] && { info "Annulé."; exit 0; }

  mkdir -p "$HOME/.claude-${PROMPT_SLUG}"
  save_account "$PROMPT_SLUG" "$PROMPT_NAME" "$PROMPT_EMAIL"

  # ── Copie de contexte depuis un compte existant ───────────────────────────
  prompt_copy_context "$PROMPT_SLUG"

  regenerate_aliases "$shell_rc"

  echo ""
  echo -en "Définir ce compte comme compte par défaut (~/.claude symlink) ? [o/N] : "
  read -r SET_DEF
  if [ "$(echo "$SET_DEF" | tr '[:upper:]' '[:lower:]')" = "o" ]; then
    set_default_symlink "$PROMPT_SLUG"
    ok "${PROMPT_NAME} est maintenant le compte par défaut."
  fi

  h1 "Connexion du compte"
  echo -e "  ${BOLD}source ${shell_rc}${RESET}"
  echo ""
  echo -e "  ${CYAN}claude-${PROMPT_SLUG}${RESET}"
  echo -e "  ${YELLOW}# 1. 'Claude account with subscription'${RESET}"
  echo -e "  ${YELLOW}# 2. Organisation : ${PROMPT_NAME}${RESET}"
  echo -e "  ${YELLOW}# 3. Email : ${PROMPT_EMAIL}${RESET}"
  echo -e "  ${YELLOW}# 4. /exit une fois connecté${RESET}"
  echo ""
  echo "VSCodium avec profil dédié :"
  echo -e "  ${CYAN}codium --profile \"${PROMPT_NAME}\" /chemin/projet${RESET}"
  echo ""
  ok "Compte '${PROMPT_NAME}' ajouté !"
}


# ══════════════════════════════════════════════════════════════════════════════
# COMMANDE : context — copie/synchronise le contexte entre deux comptes
# ══════════════════════════════════════════════════════════════════════════════
cmd_context() {
  h1 "Copie de contexte entre comptes"
  load_registry

  [ ! -s "$CONFIG_REGISTRY" ] && { warn "Aucun compte enregistré."; exit 0; }

  cmd_list

  # Source
  echo -en "${BOLD}Compte SOURCE${RESET} (copier depuis, sans 'claude-') : "
  read -r SRC
  SRC=$(echo "$SRC" | xargs | sed 's/^claude-//')
  if ! account_exists "$SRC"; then err "Compte 'claude-${SRC}' introuvable."; exit 1; fi

  # Destination
  echo -en "${BOLD}Compte DESTINATION${RESET} (copier vers, sans 'claude-') : "
  read -r DEST
  DEST=$(echo "$DEST" | xargs | sed 's/^claude-//')
  if ! account_exists "$DEST"; then err "Compte 'claude-${DEST}' introuvable."; exit 1; fi

  if [ "$SRC" = "$DEST" ]; then err "Source et destination identiques."; exit 1; fi

  local dest_name
  dest_name=$(grep "^${DEST}|" "$CONFIG_REGISTRY" | cut -d'|' -f2)

  echo ""
  warn "Les fichiers de contexte de ${dest_name} seront écrasés par ceux de claude-${SRC}."
  echo -en "Confirmer ? [o/N] : "
  read -r C
  [ "$(echo "$C" | tr '[:upper:]' '[:lower:]')" != "o" ] && { info "Annulé."; exit 0; }

  copy_context "$SRC" "$DEST"

  # Propose de mettre à jour le profil dans CLAUDE.md
  echo -en "Mettre à jour le profil dans CLAUDE.md de claude-${DEST} ? [o/N] : "
  read -r DO_PROFILE
  if [ "$(echo "$DO_PROFILE" | tr '[:upper:]' '[:lower:]')" = "o" ]; then
    local claude_md="$HOME/.claude-${DEST}/CLAUDE.md"
    echo -en "Profil (ex: 'Responsable produit, marketing') : "
    read -r NEW_PROFILE
    NEW_PROFILE=$(echo "$NEW_PROFILE" | xargs)
    if [ -n "$NEW_PROFILE" ]; then
      if [ -f "$claude_md" ] && grep -q "^## Profil de ce compte" "$claude_md"; then
        python3 - "$claude_md" "$NEW_PROFILE" << 'PYMD'
import sys, re
path, profile = sys.argv[1], sys.argv[2]
with open(path) as f: c = f.read()
c = re.sub(r'## Profil de ce compte
.*?
(
|$)', f'## Profil de ce compte
{profile}

', c, flags=re.DOTALL)
with open(path, 'w') as f: f.write(c)
PYMD
      else
        printf "
## Profil de ce compte
%s
" "$NEW_PROFILE" >> "$claude_md"
      fi
      ok "Profil mis à jour : $NEW_PROFILE"
    fi
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# COMMANDE : list
# ══════════════════════════════════════════════════════════════════════════════
cmd_list() {
  h1 "Comptes Claude Code"
  load_registry

  [ ! -s "$CONFIG_REGISTRY" ] && { warn "Aucun compte. Lance : $0 setup"; exit 0; }

  local default_slug
  default_slug=$(get_default_slug)

  printf "  %-24s %-18s %-28s %s\n" "ALIAS" "ORG" "EMAIL" "STATUT"
  printf "  %-24s %-18s %-28s %s\n" "────────────────────────" "──────────────────" "────────────────────────────" "──────"
  while IFS='|' read -r slug name email _rest; do
    [ -z "$slug" ] && continue
    local st="✅" def=""
    [ ! -d "$HOME/.claude-${slug}" ] && st="⚠️ "
    [ "$slug" = "$default_slug" ] && def=" ${YELLOW}✦ défaut${RESET}"
    printf "  ${CYAN}%-24s${RESET} %-18s %-28s %s%b\n" "claude-${slug}" "$name" "$email" "$st" "$def"
  done < "$CONFIG_REGISTRY"
  echo ""
  if [ -n "$default_slug" ]; then
    echo -e "  ${YELLOW}✦${RESET} ${CYAN}~/.claude${RESET} → ${CYAN}~/.claude-${default_slug}${RESET}"
  fi
  echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# COMMANDE : remove
# ══════════════════════════════════════════════════════════════════════════════
cmd_remove() {
  h1 "Supprimer un compte"
  load_registry

  [ ! -s "$CONFIG_REGISTRY" ] && { warn "Aucun compte enregistré."; exit 0; }

  # Argument optionnel : remove [slug]
  local TARGET_SLUG
  if [ -n "${2:-}" ]; then
    TARGET_SLUG=$(echo "$2" | xargs | sed 's/^claude-//')
    info "Compte cible : claude-${TARGET_SLUG}"
    cmd_list
  else
    cmd_list
    echo -en "${BOLD}Alias à supprimer${RESET} (sans 'claude-') : "
    read -r TARGET_SLUG
    TARGET_SLUG=$(echo "$TARGET_SLUG" | xargs | sed 's/^claude-//')
  fi

  if ! account_exists "$TARGET_SLUG"; then
    err "Compte 'claude-${TARGET_SLUG}' introuvable."; exit 1
  fi

  local target_name
  target_name=$(grep "^${TARGET_SLUG}|" "$CONFIG_REGISTRY" | cut -d'|' -f2)
  local default_slug
  default_slug=$(get_default_slug)

  if [ "$TARGET_SLUG" = "$default_slug" ]; then
    warn "Ce compte est le compte par défaut (~/.claude symlink)."
    warn "Supprime d'abord le symlink ou change le compte par défaut."
    echo -en "Supprimer quand même le symlink ~/.claude ? [o/N] : "
    read -r DEL_LINK
    if [ "$(echo "$DEL_LINK" | tr '[:upper:]' '[:lower:]')" = "o" ]; then
      rm -f "$HOME/.claude" "$HOME/.claude.json"
      ok "Symlinks ~/.claude et ~/.claude.json supprimés."
    else
      info "Annulé."; exit 0
    fi
  fi

  echo -en "Supprimer aussi le répertoire ~/.claude-${TARGET_SLUG} ? [o/N] : "
  read -r DEL_DIR
  echo -en "Confirmer la suppression de '${target_name}' ? [o/N] : "
  read -r CONFIRM
  [ "$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')" != "o" ] && { info "Annulé."; exit 0; }

  remove_account_from_registry "$TARGET_SLUG"

  if [ "$(echo "$DEL_DIR" | tr '[:upper:]' '[:lower:]')" = "o" ]; then
    rm -rf "$HOME/.claude-${TARGET_SLUG}"
    ok "~/.claude-${TARGET_SLUG} supprimé."
  fi

  local shell_rc
  shell_rc=$(detect_shell_rc)
  regenerate_aliases "$shell_rc"
  ok "Compte '${target_name}' supprimé. Recharge : source ${shell_rc}"
}

# ══════════════════════════════════════════════════════════════════════════════
# COMMANDE : login
# ══════════════════════════════════════════════════════════════════════════════
cmd_login() {
  h1 "Guide de connexion"
  load_registry

  [ ! -s "$CONFIG_REGISTRY" ] && { warn "Aucun compte. Lance : $0 setup"; exit 0; }

  # Argument optionnel : login [slug] — filtre sur un seul compte
  local filter_slug=""
  if [ -n "${2:-}" ]; then
    filter_slug=$(echo "$2" | sed 's/^claude-//')
  fi

  local shell_rc
  shell_rc=$(detect_shell_rc)
  echo -e "  ${BOLD}source ${shell_rc}${RESET}"
  echo ""
  while IFS='|' read -r slug name email _rest; do
    [ -z "$slug" ] && continue
    [ -n "$filter_slug" ] && [ "$slug" != "$filter_slug" ] && continue
    echo -e "  ${CYAN}claude-${slug}${RESET}   # ${name} — ${email}"
    echo -e "  ${YELLOW}# → 'Claude account with subscription' → ${name} → /exit${RESET}"
    echo ""
  done < "$CONFIG_REGISTRY"
}

# ══════════════════════════════════════════════════════════════════════════════
# COMMANDE : status
# ══════════════════════════════════════════════════════════════════════════════
cmd_status() {
  h1 "État des comptes"
  check_claude
  load_registry

  [ ! -s "$CONFIG_REGISTRY" ] && { warn "Aucun compte enregistré."; exit 0; }

  local default_slug
  default_slug=$(get_default_slug)

  # Vérifie le symlink
  if [ -n "$default_slug" ]; then
    if [ -L "$HOME/.claude" ] && [ -d "$HOME/.claude" ]; then
      ok "~/.claude → ~/.claude-${default_slug}  (symlink valide)"
    else
      warn "~/.claude n'est pas un symlink valide → lance: $0 migrate"
    fi
  else
    warn "Aucun compte par défaut → lance: $0 migrate ou $0 default"
  fi
  echo ""

  while IFS='|' read -r slug name email _rest; do
    [ -z "$slug" ] && continue
    local dir="$HOME/.claude-${slug}"
    local def_marker=""; [ "$slug" = "$default_slug" ] && def_marker=" ${YELLOW}✦${RESET}"
    echo -en "  ${CYAN}claude-${slug}${RESET}${def_marker} (${name}) : "
    if [ ! -d "$dir" ]; then
      echo -e "${RED}répertoire manquant${RESET} → $0 add"
    elif ls "${dir}"/.credentials* 2>/dev/null | grep -q . || [ -f "${dir}/.claude.json" ] && [ -s "${dir}/.claude.json" ]; then
      echo -e "${GREEN}connecté ✅${RESET}"
    else
      echo -e "${YELLOW}connexion requise${RESET} → claude-${slug}"
    fi
  done < "$CONFIG_REGISTRY"
  echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# COMMANDE : install
# ══════════════════════════════════════════════════════════════════════════════
cmd_install() {
  h1 "Installation globale (~/.local/bin)"
  mkdir -p "$LOCAL_BIN"
  local target="${LOCAL_BIN}/${SCRIPT_NAME}"

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$SELF_PATH" ]; then
    info "Lien déjà en place : $target"; return
  fi

  ln -sf "$SELF_PATH" "$target"
  chmod +x "$SELF_PATH"
  ok "Lien : ${target} → ${SELF_PATH}"

  if ! echo "$PATH" | tr ':' '\n' | grep -qx "$LOCAL_BIN"; then
    local shell_rc
    shell_rc=$(detect_shell_rc)
    if ! grep -q '\.local/bin' "$shell_rc" 2>/dev/null; then
      echo "" >> "$shell_rc"
      echo '# ~/.local/bin dans PATH' >> "$shell_rc"
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_rc"
      warn "~/.local/bin ajouté au PATH dans $shell_rc"
    fi
  else
    ok "~/.local/bin déjà dans PATH"
  fi
  echo -e "Utilise maintenant : ${CYAN}${SCRIPT_NAME} <commande>${RESET}"
}

# ══════════════════════════════════════════════════════════════════════════════
# COMMANDE : uninstall
# ══════════════════════════════════════════════════════════════════════════════
_rm_aliases() {
  local shell_rc="$1"
  if grep -q "$MARKER_START" "$shell_rc" 2>/dev/null; then
    python3 - "$shell_rc" << 'PY'
import sys, re
path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()
content = re.sub(
    r'\n?# ── claude-accounts START ──.*?# ── claude-accounts END ──\n?',
    '', content, flags=re.DOTALL
)
with open(path, 'w') as f:
    f.write(content)
PY
    ok "Alias supprimés de $shell_rc"
  fi
}

cmd_uninstall() {
  h1 "Désinstallation"
  load_registry
  local shell_rc; shell_rc=$(detect_shell_rc)

  echo "  [1] Alias shell uniquement"
  echo "  [2] Alias + lien ~/.local/bin"
  echo "  [3] Complet (alias + lien + symlinks + configs + registre)"
  echo "  [0] Annuler"
  echo ""
  echo -en "Choix [0-3] : "
  read -r CHOICE

  case "$CHOICE" in
    1) _rm_aliases "$shell_rc" ;;
    2) _rm_aliases "$shell_rc"
       rm -f "${LOCAL_BIN}/${SCRIPT_NAME}" && ok "Lien supprimé." ;;
    3)
      echo ""
      warn "Suppression COMPLÈTE — credentials inclus."
      echo -en "Confirmer ? [o/N] : "
      read -r C; [ "$(echo "$C" | tr '[:upper:]' '[:lower:]')" != "o" ] && { info "Annulé."; exit 0; }
      _rm_aliases "$shell_rc"
      rm -f "${LOCAL_BIN}/${SCRIPT_NAME}"
      rm -f "$HOME/.claude" "$HOME/.claude.json"  # symlinks
      while IFS='|' read -r slug name _rest; do
        [ -z "$slug" ] && continue
        rm -rf "$HOME/.claude-${slug}"
        ok "~/.claude-${slug} supprimé (${name})"
      done < "$CONFIG_REGISTRY"
      rm -f "$CONFIG_REGISTRY"
      ok "Désinstallation complète."
      ;;
    0|"") info "Annulé." ;;
    *)   err "Choix invalide." ;;
  esac
  echo ""
  info "Recharge : source $shell_rc"
}

# ══════════════════════════════════════════════════════════════════════════════
# AIDE
# ══════════════════════════════════════════════════════════════════════════════
cmd_help() {
  echo ""
  echo -e "${BOLD}claude-accounts v${VERSION}${RESET} — Gestionnaire multi-comptes Claude Code"
  echo ""
  echo -e "${BOLD}Architecture :${RESET}"
  echo "  ~/.claude        → symlink vers ~/.claude-{slug} (compte par défaut)"
  echo "  ~/.claude.json   → symlink vers ~/.claude-{slug}/.claude.json"
  echo "  ~/.claude-{slug} → répertoire isolé par compte"
  echo ""
  echo -e "${BOLD}Usage :${RESET}  ${SCRIPT_NAME} <commande>"
  echo ""
  echo -e "${BOLD}Commandes :${RESET}"
  echo -e "  ${CYAN}setup${RESET}      Config initiale interactive (tous les comptes)"
  echo -e "  ${CYAN}migrate${RESET}    Migre ~/.claude existant → slot + crée le symlink"
  echo -e "  ${CYAN}add${RESET}        Ajoute un compte supplémentaire"
  echo -e "  ${CYAN}context${RESET}    Copie/sync le contexte entre deux comptes existants"
  echo -e "  ${CYAN}default${RESET}    Change le compte par défaut (rebascule le symlink)"
  echo -e "  ${CYAN}list${RESET}       Liste les comptes"
  echo -e "  ${CYAN}remove${RESET}     Supprime un compte"
  echo -e "  ${CYAN}login${RESET}      Guide d'authentification"
  echo -e "  ${CYAN}status${RESET}     État des connexions + symlink"
  echo -e "  ${CYAN}install${RESET}    Lien global dans ~/.local/bin"
  echo -e "  ${CYAN}uninstall${RESET}  Désinstalle (alias / lien / tout)"
  echo -e "  ${CYAN}help${RESET}       Cette aide"
  echo ""
  echo -e "${BOLD}Workflow initial (config VSCodium existante) :${RESET}"
  echo "  $0 migrate     # détecte config existante, propose le compte, crée symlink"
  echo "  $0 add         # ajoute les autres comptes"
  echo "  $0 status      # vérifie tout"
  echo ""
  echo -e "${BOLD}Utilisation quotidienne :${RESET}"
  echo "  claude                # compte par défaut (via symlink ~/.claude)"
  echo "  claude-{slug}         # compte spécifique"
  echo "  claude-default        # changer le compte par défaut"
  echo "  claude-list           # liste"
  echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# POINT D'ENTRÉE
# ══════════════════════════════════════════════════════════════════════════════
case "${1:-help}" in
  setup)     cmd_setup ;;
  migrate)   cmd_migrate ;;
  add)       cmd_add ;;
  default)   cmd_default ;;
  context)   cmd_context ;;
  list)      cmd_list ;;
  remove)    cmd_remove "$@" ;;
  login)     cmd_login "$@" ;;
  status)    cmd_status ;;
  install)   cmd_install ;;
  uninstall) cmd_uninstall ;;
  help|-h|--help) cmd_help ;;
  *)
    err "Commande inconnue : $1"
    cmd_help
    exit 1
    ;;
esac
