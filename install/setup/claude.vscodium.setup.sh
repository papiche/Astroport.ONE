#!/bin/bash
# =============================================================================
# claude-accounts v1.2.0 — Gestionnaire multi-comptes Claude Code
# Commandes : setup | add | list | remove | migrate | login | status | install | uninstall | help
# =============================================================================

VERSION="1.2.0"
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

# ── Registre des comptes ──────────────────────────────────────────────────────
load_registry() { touch "$CONFIG_REGISTRY"; }

account_exists() { grep -q "^${1}|" "$CONFIG_REGISTRY" 2>/dev/null; }

save_account() { echo "${1}|${2}|${3}" >> "$CONFIG_REGISTRY"; }

remove_account_from_registry() { sed -i "/^${1}|/d" "$CONFIG_REGISTRY"; }

# ── Regénère le bloc d'alias dans le shell RC ─────────────────────────────────
regenerate_aliases() {
  local shell_rc="$1"

  # Supprime l'ancien bloc via python3
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

  # Construit les alias et la liste commentée
  local aliases="" names_list=""
  while IFS='|' read -r slug name email; do
    [ -z "$slug" ] && continue
    aliases="${aliases}alias claude-${slug}='CLAUDE_CONFIG_DIR=\$HOME/.claude-${slug} claude'\n"
    names_list="${names_list}#   claude-${slug} → ${name} (${email})\n"
  done < "$CONFIG_REGISTRY"

  local all_slugs
  all_slugs=$(awk -F'|' '{printf "claude-%s ", $1}' "$CONFIG_REGISTRY" | sed 's/ $//')

  # Écrit le nouveau bloc (heredoc sans interprétation des \n dans les vars)
  {
    echo ""
    echo "${MARKER_START}"
    echo "# claude-accounts v${VERSION} — comptes Claude Code"
    echo "# Usage :"
    printf "%b" "$names_list"
    echo "#   claude-list     → liste les comptes"
    printf "%b" "$aliases"
    echo "alias claude-list='cat \$HOME/.claude-accounts.conf | column -t -s\"|\" | sed \"s/^/  /\"'"
    echo "alias claude='echo \"⚠️  Précise le compte. Ex: ${all_slugs}\"'"
    echo "${MARKER_END}"
  } >> "$shell_rc"

  ok "Alias régénérés dans $shell_rc"
}

# ══════════════════════════════════════════════════════════════════════════════
# COMMANDE : install — lien dans ~/.local/bin pour appel global
# ══════════════════════════════════════════════════════════════════════════════
cmd_install() {
  h1 "Installation globale"
  mkdir -p "$LOCAL_BIN"

  local target="${LOCAL_BIN}/${SCRIPT_NAME}"

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$SELF_PATH" ]; then
    info "Lien déjà en place : $target → $SELF_PATH"
    return
  fi

  ln -sf "$SELF_PATH" "$target"
  chmod +x "$SELF_PATH"
  ok "Lien créé : ${target} → ${SELF_PATH}"

  # Vérifie que ~/.local/bin est dans le PATH
  if ! echo "$PATH" | tr ':' '\n' | grep -qx "$LOCAL_BIN"; then
    local shell_rc
    shell_rc=$(detect_shell_rc)
    if ! grep -q 'LOCAL_BIN\|\.local/bin' "$shell_rc" 2>/dev/null; then
      echo "" >> "$shell_rc"
      echo "# ~/.local/bin dans PATH" >> "$shell_rc"
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_rc"
      warn "~/.local/bin ajouté au PATH dans $shell_rc"
      warn "Recharge ton shell : source $shell_rc"
    else
      info "~/.local/bin déjà présent dans $shell_rc"
    fi
  else
    ok "~/.local/bin déjà dans PATH"
  fi

  echo ""
  echo -e "Tu peux maintenant utiliser : ${CYAN}${SCRIPT_NAME} <commande>${RESET}"
  echo -e "  depuis n'importe où, sans chemin absolu."
}

# ══════════════════════════════════════════════════════════════════════════════
# COMMANDE : uninstall — désinstalle tout proprement
# ══════════════════════════════════════════════════════════════════════════════
cmd_uninstall() {
  h1 "Désinstallation"
  load_registry

  local shell_rc
  shell_rc=$(detect_shell_rc)

  echo -e "${BOLD}Que souhaites-tu supprimer ?${RESET}"
  echo ""
  echo "  [1] Alias shell uniquement (garde les configs et credentials)"
  echo "  [2] Alias + lien ~/.local/bin"
  echo "  [3] Désinstallation complète (alias + lien + configs + registre)"
  echo "  [0] Annuler"
  echo ""
  echo -en "Choix [0-3] : "
  read -r CHOICE

  case "$CHOICE" in
    1)
      _uninstall_aliases "$shell_rc"
      ok "Alias supprimés. Les configs ~/.claude-* sont conservées."
      ;;
    2)
      _uninstall_aliases "$shell_rc"
      _uninstall_symlink
      ok "Alias et lien supprimés."
      ;;
    3)
      echo ""
      warn "ATTENTION : ceci supprimera credentials et configurations de TOUS les comptes."
      echo -en "Confirmer la désinstallation complète ? [o/N] : "
      read -r CONFIRM
      CONFIRM=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
      [ "$CONFIRM" != "o" ] && { info "Annulé."; exit 0; }

      _uninstall_aliases "$shell_rc"
      _uninstall_symlink

      # Supprime les répertoires de config
      while IFS='|' read -r slug name _email; do
        [ -z "$slug" ] && continue
        if [ -d "$HOME/.claude-${slug}" ]; then
          rm -rf "$HOME/.claude-${slug}"
          ok "Supprimé : ~/.claude-${slug} (${name})"
        fi
      done < "$CONFIG_REGISTRY"

      # Supprime le registre
      rm -f "$CONFIG_REGISTRY"
      ok "Registre supprimé : $CONFIG_REGISTRY"

      echo ""
      ok "Désinstallation complète terminée."
      ;;
    0|"")
      info "Annulé."
      ;;
    *)
      err "Choix invalide."
      exit 1
      ;;
  esac

  echo ""
  info "Recharge ton shell pour appliquer : source $shell_rc"
}

_uninstall_aliases() {
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
    ok "Bloc d'alias supprimé de $shell_rc"
  else
    info "Aucun bloc d'alias trouvé dans $shell_rc"
  fi
}

_uninstall_symlink() {
  local target="${LOCAL_BIN}/${SCRIPT_NAME}"
  if [ -L "$target" ]; then
    rm -f "$target"
    ok "Lien supprimé : $target"
  else
    info "Aucun lien trouvé dans $LOCAL_BIN"
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# COMMANDE : migrate — copie ~/.claude par défaut vers un slot
# ══════════════════════════════════════════════════════════════════════════════
cmd_migrate() {
  h1 "Migration de la config par défaut (~/.claude)"
  load_registry

  local src="$HOME/.claude"
  local src_json="$HOME/.claude.json"

  # Vérifications source
  if [ ! -d "$src" ] && [ ! -f "$src_json" ]; then
    err "Aucune config Claude par défaut trouvée (~/.claude ou ~/.claude.json)"
    info "Il n'y a rien à migrer."
    exit 1
  fi

  echo "Source détectée :"
  [ -d "$src" ]      && echo -e "  ${CYAN}~/.claude/${RESET}       ($(du -sh "$src" 2>/dev/null | cut -f1))"
  [ -f "$src_json" ] && echo -e "  ${CYAN}~/.claude.json${RESET}    (credentials / session)"
  echo ""

  # Choix du compte de destination
  if [ ! -s "$CONFIG_REGISTRY" ]; then
    err "Aucun compte enregistré. Lance d'abord : $0 setup"
    exit 1
  fi

  echo -e "${BOLD}Vers quel compte migrer ?${RESET}"
  echo ""
  local i=1
  local slugs=() names=()
  while IFS='|' read -r slug name email; do
    [ -z "$slug" ] && continue
    echo "  [$i] $name ($email)  →  ~/.claude-${slug}"
    slugs+=("$slug")
    names+=("$name")
    ((i++))
  done < "$CONFIG_REGISTRY"
  echo ""
  echo -en "Choix [1-$((i-1))] : "
  read -r IDX

  if ! [[ "$IDX" =~ ^[0-9]+$ ]] || [ "$IDX" -lt 1 ] || [ "$IDX" -gt $((i-1)) ]; then
    err "Choix invalide."
    exit 1
  fi

  local target_slug="${slugs[$((IDX-1))]}"
  local target_name="${names[$((IDX-1))]}"
  local dest="$HOME/.claude-${target_slug}"

  echo ""
  echo -e "┌──────────────────────────────────────────────────┐"
  echo -e "│  Source : ${CYAN}~/.claude/${RESET} + ${CYAN}~/.claude.json${RESET}"
  echo -e "│  Dest   : ${CYAN}~/.claude-${target_slug}/${RESET}  (${target_name})"
  echo -e "└──────────────────────────────────────────────────┘"
  echo ""

  # Sauvegarde si dest non vide
  if [ -d "$dest" ] && [ "$(ls -A "$dest" 2>/dev/null)" ]; then
    local backup="${dest}.backup.$(date +%Y%m%d_%H%M%S)"
    echo -en "La destination ~/.claude-${target_slug} n'est pas vide. Sauvegarder avant migration ? [O/n] : "
    read -r DO_BACKUP
    DO_BACKUP=$(echo "$DO_BACKUP" | tr '[:upper:]' '[:lower:]')
    if [ "$DO_BACKUP" != "n" ]; then
      cp -a "$dest" "$backup"
      ok "Sauvegarde créée : $backup"
    fi
  fi

  echo -en "Confirmer la migration ? [O/n] : "
  read -r CONFIRM
  CONFIRM=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
  [ "$CONFIRM" = "n" ] && { info "Annulé."; exit 0; }

  # ── Copie ~/.claude/ → dest ───────────────────────────────────────────────
  if [ -d "$src" ]; then
    mkdir -p "$dest"
    cp -a "${src}/." "$dest/"
    ok "~/.claude/ copié vers ~/.claude-${target_slug}/"
  fi

  # ── Copie ~/.claude.json → dest/.claude.json ──────────────────────────────
  # (Claude Code lit les credentials depuis CLAUDE_CONFIG_DIR/.claude.json sur Linux)
  if [ -f "$src_json" ]; then
    cp "$src_json" "${dest}/.claude.json"
    ok "~/.claude.json copié vers ~/.claude-${target_slug}/.claude.json"
  fi

  echo ""
  echo -e "${BOLD}La config par défaut est conservée intacte.${RESET}"
  echo -e "Tu peux la supprimer manuellement si tu le souhaites."
  echo ""
  echo "Vérifie la migration avec :"
  echo -e "  ${CYAN}$0 status${RESET}"
  echo ""
  echo "Puis lance Claude Code sur ce compte :"
  echo -e "  ${CYAN}claude-${target_slug}${RESET}"
  echo ""
  ok "Migration terminée → ${target_name} est prêt !"
}

# ══════════════════════════════════════════════════════════════════════════════
# COMMANDE : setup
# ══════════════════════════════════════════════════════════════════════════════
cmd_setup() {
  h1 "Claude Code — Setup initial"
  check_claude
  load_registry
  local shell_rc
  shell_rc=$(detect_shell_rc)

  echo -e "Shell RC détecté : ${CYAN}${shell_rc}${RESET}"
  echo ""

  local -a INIT_SLUGS=("g1fablab" "axiomteam")
  local -a INIT_NAMES=("G1FabLab" "AxiomTeam")
  local -a INIT_EMAILS=("support@qo-op.com" "frd@ajr.ai")

  for i in 0 1; do
    local slug="${INIT_SLUGS[$i]}"
    if account_exists "$slug"; then
      info "Compte ${INIT_NAMES[$i]} déjà enregistré — ignoré."
    else
      mkdir -p "$HOME/.claude-${slug}"
      save_account "$slug" "${INIT_NAMES[$i]}" "${INIT_EMAILS[$i]}"
      ok "Compte ${INIT_NAMES[$i]} (${INIT_EMAILS[$i]}) enregistré → ~/.claude-${slug}"
    fi
  done

  regenerate_aliases "$shell_rc"

  # Installation du lien ~/.local/bin automatique
  echo ""
  cmd_install

  h1 "Étape suivante : migration VSCodium"
  echo "Tu utilises déjà VSCodium avec G1FabLab → migre la config existante :"
  echo ""
  echo -e "  ${CYAN}$0 migrate${RESET}   (ou: ${CYAN}${SCRIPT_NAME} migrate${RESET} après install)"
  echo ""
  h1 "Première connexion"
  echo "Recharge ton shell puis connecte chaque compte :"
  echo ""
  while IFS='|' read -r slug name email; do
    echo -e "  ${CYAN}claude-${slug}${RESET}   # → ${name} (${email})"
    echo "  /exit"
    echo ""
  done < "$CONFIG_REGISTRY"
  echo -e "  ${BOLD}source ${shell_rc}${RESET}"
  echo ""
  ok "Setup terminé !"
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

  while true; do
    echo -en "${BOLD}Nom de l'organisation${RESET} (ex: MonEquipe) : "
    read -r ORG_NAME
    ORG_NAME=$(echo "$ORG_NAME" | xargs)
    [ -n "$ORG_NAME" ] && break
    warn "Le nom ne peut pas être vide."
  done

  while true; do
    echo -en "${BOLD}Email du compte${RESET} (ex: user@example.com) : "
    read -r ORG_EMAIL
    ORG_EMAIL=$(echo "$ORG_EMAIL" | xargs)
    echo "$ORG_EMAIL" | grep -qE '^[^@]+@[^@]+\.[^@]+$' && break
    warn "Email invalide. Réessaie."
  done

  local SUGGESTED_SLUG
  SUGGESTED_SLUG=$(slugify "$ORG_NAME")
  echo ""
  echo -en "Alias suggéré : ${CYAN}claude-${SUGGESTED_SLUG}${RESET}  [Entrée pour accepter ou tape un autre] : "
  read -r CUSTOM_SLUG
  CUSTOM_SLUG=$(echo "$CUSTOM_SLUG" | xargs)
  local SLUG
  SLUG=$([ -n "$CUSTOM_SLUG" ] && slugify "$CUSTOM_SLUG" || echo "$SUGGESTED_SLUG")

  if account_exists "$SLUG"; then
    err "Un compte 'claude-${SLUG}' existe déjà."
    exit 1
  fi

  echo ""
  echo -e "┌─────────────────────────────────────────┐"
  echo -e "│  Organisation : ${BOLD}${ORG_NAME}${RESET}"
  echo -e "│  Email        : ${BOLD}${ORG_EMAIL}${RESET}"
  echo -e "│  Alias        : ${CYAN}claude-${SLUG}${RESET}"
  echo -e "│  Config dir   : ~/.claude-${SLUG}"
  echo -e "└─────────────────────────────────────────┘"
  echo ""
  echo -en "Confirmer ? [O/n] : "
  read -r CONFIRM
  [ "$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')" = "n" ] && { info "Annulé."; exit 0; }

  mkdir -p "$HOME/.claude-${SLUG}"
  save_account "$SLUG" "$ORG_NAME" "$ORG_EMAIL"
  regenerate_aliases "$shell_rc"

  h1 "Connexion du compte"
  echo -e "  ${BOLD}source ${shell_rc}${RESET}"
  echo ""
  echo -e "  ${CYAN}claude-${SLUG}${RESET}"
  echo -e "  ${YELLOW}# 1. Sélectionne 'Claude account with subscription'${RESET}"
  echo -e "  ${YELLOW}# 2. Organisation : ${ORG_NAME}${RESET}"
  echo -e "  ${YELLOW}# 3. Email : ${ORG_EMAIL}${RESET}"
  echo -e "  ${YELLOW}# 4. /exit une fois connecté${RESET}"
  echo ""
  echo "VSCodium avec profil dédié :"
  echo -e "  ${CYAN}codium --profile \"${ORG_NAME}\" /chemin/projet${RESET}"
  echo ""
  echo "Par projet (.env à la racine) :"
  echo -e "  ${CYAN}CLAUDE_CONFIG_DIR=\$HOME/.claude-${SLUG}${RESET}"
  echo ""
  ok "Compte '${ORG_NAME}' ajouté !"
}

# ══════════════════════════════════════════════════════════════════════════════
# COMMANDE : list
# ══════════════════════════════════════════════════════════════════════════════
cmd_list() {
  h1 "Comptes Claude Code enregistrés"
  load_registry

  if [ ! -s "$CONFIG_REGISTRY" ]; then
    warn "Aucun compte. Lance : $0 setup"
    exit 0
  fi

  printf "  %-22s %-18s %-30s\n" "ALIAS" "ORG" "EMAIL"
  printf "  %-22s %-18s %-30s\n" "──────────────────────" "──────────────────" "──────────────────────────────"
  while IFS='|' read -r slug name email; do
    [ -z "$slug" ] && continue
    local st="✅"
    [ ! -d "$HOME/.claude-${slug}" ] && st="⚠️ "
    printf "  ${CYAN}%-22s${RESET} %-18s %-30s %s\n" "claude-${slug}" "$name" "$email" "$st"
  done < "$CONFIG_REGISTRY"
  echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# COMMANDE : remove
# ══════════════════════════════════════════════════════════════════════════════
cmd_remove() {
  h1 "Supprimer un compte"
  load_registry

  [ ! -s "$CONFIG_REGISTRY" ] && { warn "Aucun compte enregistré."; exit 0; }

  cmd_list

  echo -en "${BOLD}Alias à supprimer${RESET} (sans 'claude-') : "
  read -r TARGET_SLUG
  TARGET_SLUG=$(echo "$TARGET_SLUG" | xargs | sed 's/^claude-//')

  if ! account_exists "$TARGET_SLUG"; then
    err "Compte 'claude-${TARGET_SLUG}' introuvable."
    exit 1
  fi

  local target_name
  target_name=$(grep "^${TARGET_SLUG}|" "$CONFIG_REGISTRY" | cut -d'|' -f2)

  echo ""
  warn "Supprimer : ${target_name} (claude-${TARGET_SLUG})"
  echo -en "Supprimer aussi le répertoire ~/.claude-${TARGET_SLUG} ? [o/N] : "
  read -r DEL_DIR

  echo -en "Confirmer ? [o/N] : "
  read -r CONFIRM
  [ "$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')" != "o" ] && { info "Annulé."; exit 0; }

  remove_account_from_registry "$TARGET_SLUG"

  if [ "$(echo "$DEL_DIR" | tr '[:upper:]' '[:lower:]')" = "o" ]; then
    rm -rf "$HOME/.claude-${TARGET_SLUG}"
    ok "Répertoire ~/.claude-${TARGET_SLUG} supprimé."
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

  local shell_rc
  shell_rc=$(detect_shell_rc)

  echo -e "  ${BOLD}source ${shell_rc}${RESET}"
  echo ""
  while IFS='|' read -r slug name email; do
    [ -z "$slug" ] && continue
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

  while IFS='|' read -r slug name email; do
    [ -z "$slug" ] && continue
    local dir="$HOME/.claude-${slug}"
    echo -en "  ${CYAN}claude-${slug}${RESET} (${name}) : "
    if [ ! -d "$dir" ]; then
      echo -e "${RED}répertoire manquant${RESET} → $0 add"
    elif ls "${dir}"/.credentials* 2>/dev/null | grep -q . || [ -f "${dir}/.claude.json" ]; then
      echo -e "${GREEN}connecté ✅${RESET}"
    else
      echo -e "${YELLOW}connexion requise${RESET} → claude-${slug}"
    fi
  done < "$CONFIG_REGISTRY"
  echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# AIDE
# ══════════════════════════════════════════════════════════════════════════════
cmd_help() {
  echo ""
  echo -e "${BOLD}claude-accounts v${VERSION}${RESET} — Gestionnaire multi-comptes Claude Code"
  echo ""
  echo -e "${BOLD}Usage :${RESET}  ${SCRIPT_NAME} <commande>   (ou: $0 <commande>)"
  echo ""
  echo -e "${BOLD}Commandes :${RESET}"
  echo -e "  ${CYAN}setup${RESET}      Initialise G1FabLab + AxiomTeam + lien global"
  echo -e "  ${CYAN}add${RESET}        Ajoute un nouveau compte (interactif)"
  echo -e "  ${CYAN}migrate${RESET}    Copie ~/.claude par défaut vers un slot (ex: VSCodium actif)"
  echo -e "  ${CYAN}list${RESET}       Liste tous les comptes"
  echo -e "  ${CYAN}remove${RESET}     Supprime un compte"
  echo -e "  ${CYAN}login${RESET}      Guide d'authentification"
  echo -e "  ${CYAN}status${RESET}     Vérifie l'état des connexions"
  echo -e "  ${CYAN}install${RESET}    Crée un lien dans ~/.local/bin pour usage global"
  echo -e "  ${CYAN}uninstall${RESET}  Désinstalle (alias / lien / tout)"
  echo -e "  ${CYAN}help${RESET}       Affiche cette aide"
  echo ""
  echo -e "${BOLD}Workflow typique :${RESET}"
  echo "  $0 setup          # 1. Initialise"
  echo "  $0 migrate        # 2. Migre la session VSCodium → g1fablab"
  echo "  $0 status         # 3. Vérifie"
  echo "  $0 add            # 4. Ajoute un 3ème compte si besoin"
  echo ""
  echo -e "${BOLD}Utilisation quotidienne :${RESET}"
  echo "  claude-g1fablab   # G1FabLab (support@qo-op.com)"
  echo "  claude-axiomteam  # AxiomTeam (frd@ajr.ai)"
  echo "  claude-list       # Liste les comptes"
  echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# POINT D'ENTRÉE
# ══════════════════════════════════════════════════════════════════════════════
case "${1:-help}" in
  setup)     cmd_setup ;;
  add)       cmd_add ;;
  migrate)   cmd_migrate ;;
  list)      cmd_list ;;
  remove)    cmd_remove ;;
  login)     cmd_login ;;
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
