#!/bin/bash
# =============================================================================
# paperclip-configure-channels.sh - UPlanet AI Company · Connecteurs marketing multi-canal
#
# Canaux supportés :
#   Telegram   — bot groupe/canal
#   Gmail      — OAuth2 séquences email
#   Mastodon   — API REST statuts
#   LinkedIn   — API officielle (optionnel, phase 2)
#   Nostr      — Astroport.ONE local
# DOC : ~/.zen/Astroport.ONE/docs/paperclip_uplanet_setup_guide.html
# Usage : ./paperclip-configure-channels.sh [--check|--deps|--telegram|--gmail|--mastodon|--all|--health]
# =============================================================================

set -e
MY_PATH="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.zen/ai-company"
ENV_FILE="$INSTALL_DIR/.env"
SKILLS_DIR="$INSTALL_DIR/paperclip_data/skills"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

mkdir -p "$SKILLS_DIR"

[ -f "$ENV_FILE" ] && export $(grep -v '^#' "$ENV_FILE" | xargs) 2>/dev/null || true

# =============================================================================
# UTILITAIRES
# =============================================================================

ok()   { echo -e "${GREEN}  ✓ $1${NC}"; }
warn() { echo -e "${YELLOW}  ⚠ $1${NC}"; }
err()  { echo -e "${RED}  ✗ $1${NC}"; }
info() { echo -e "${CYAN}  → $1${NC}"; }

add_env() {
    local key="$1" val="$2"
    if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
    else
        echo "${key}=${val}" >> "$ENV_FILE"
    fi
    ok "Ajouté : ${key}"
}

# =============================================================================
# SANITY CHECK — stack Docker
# =============================================================================

check_stack() {
    echo -e "\n${BOLD}${CYAN}=== Vérification de la stack ===${NC}"
    local all_ok=true
    for svc in paperclip open-webui llm-proxy qdrant; do
        if docker ps --filter "name=ai-company" --filter "status=running" \
           --format "{{.Names}}" | grep -q "$svc"; then
            ok "$svc est UP"
        else
            err "$svc est DOWN"
            all_ok=false
        fi
    done
    if [ "$all_ok" = false ]; then
        warn "Relancer : cd $INSTALL_DIR && docker compose -p ai-company-swarm up -d"
        exit 1
    fi

    # Vérifier Ollama sur l'hôte
    if curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
        ok "Ollama répond sur :11434"
    else
        warn "Ollama ne répond pas — vérifier : ollama serve"
    fi
}

# =============================================================================
# DÉPENDANCES DANS LE CONTENEUR PAPERCLIP
# =============================================================================

ensure_paperclip_deps() {
    echo -e "\n${BOLD}${CYAN}=== Dépendances runtime du conteneur Paperclip ===${NC}"

    # Trouver le conteneur paperclip (nom contenant "paperclip", hors autres services)
    local container
    container=$(docker ps --filter "name=ai-company" --filter "status=running" \
        --format "{{.Names}}" \
        | grep -i "paperclip" \
        | grep -v "open-webui\|llm-proxy\|qdrant\|litellm" \
        | head -1)

    if [ -z "$container" ]; then
        warn "Conteneur Paperclip introuvable — impossible de vérifier les dépendances runtime"
        warn "Assurez-vous que la stack tourne : cd $INSTALL_DIR && docker compose -p ai-company-swarm up -d"
        return 1
    fi

    ok "Conteneur Paperclip détecté : $container"

    # --- Node.js (runtime principal des skills Paperclip — doit être présent) ---
    if docker exec "$container" node --version >/dev/null 2>&1; then
        local node_ver
        node_ver=$(docker exec "$container" node --version 2>/dev/null)
        ok "Node.js présent dans le conteneur : $node_ver"
        # Vérifier fetch natif (Node 18+)
        local node_major
        node_major=$(echo "$node_ver" | sed 's/v//' | cut -d. -f1)
        if [ "$node_major" -ge 18 ]; then
            ok "fetch natif disponible (Node ≥ 18) — aucune dépendance npm requise pour les skills"
        else
            warn "Node.js < 18 — fetch natif absent. Mise à jour recommandée (node-fetch peut être nécessaire)"
        fi
    else
        err "Node.js absent du conteneur — les skills Paperclip ne pourront pas s'exécuter"
        err "Vérifiez l'image : docker exec -it $container node --version"
        return 1
    fi

    # --- curl (utilisé par les scripts de setup hôte, présent par défaut dans le conteneur) ---
    if docker exec "$container" which curl >/dev/null 2>&1; then
        ok "curl présent dans le conteneur"
    else
        info "curl absent — installation via apt-get..."
        docker exec "$container" apt-get update -qq >/dev/null 2>&1 \
        && docker exec "$container" apt-get install -y -qq curl >/dev/null 2>&1 \
        && ok "curl installé" \
        || err "Échec installation curl — docker exec -it $container apt-get install -y curl"
    fi

    ok "Vérification des dépendances terminée pour : $container (skills JS natifs — aucune lib Python requise)"
}

# =============================================================================
# TELEGRAM
# =============================================================================

setup_telegram() {
    echo -e "\n${BOLD}${CYAN}=== Configuration Telegram ===${NC}"

    # Token
    if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
        echo -e "  Ouvrir @BotFather sur Telegram → /newbot"
        read -p "  Entrez votre Bot Token : " token
        add_env "TELEGRAM_BOT_TOKEN" "$token"
        TELEGRAM_BOT_TOKEN="$token"
    else
        ok "TELEGRAM_BOT_TOKEN déjà présent"
    fi

    # Vérifier le token
    info "Test du token Telegram..."
    resp=$(curl -sf "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe" || echo '{"ok":false}')
    if echo "$resp" | grep -q '"ok":true'; then
        botname=$(echo "$resp" | node -e "
let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{
  try{console.log(JSON.parse(d).result.username);}catch(e){console.log('inconnu');}
})" 2>/dev/null || echo "inconnu")
        ok "Bot actif : @$botname"
    else
        err "Token invalide ou réseau inaccessible"
        return 1
    fi

    # Chat ID
    if [ -z "$TELEGRAM_CHAT_ID" ]; then
        info "Envoyez un message à votre bot ou dans le groupe, puis appuyez sur Entrée..."
        read -p "  (Appuyez sur Entrée après avoir envoyé un message) " _
        updates=$(curl -sf "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates")
        chat_id=$(echo "$updates" | node -e "
let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{
  try{
    const msgs=(JSON.parse(d).result||[]);
    if(msgs.length){
      const m=msgs[msgs.length-1];
      const chat=(m.message||m.channel_post||{}).chat||{};
      console.log(chat.id||'');
    }
  }catch(e){}
})" 2>/dev/null || echo "")
        if [ -n "$chat_id" ]; then
            ok "Chat ID détecté : $chat_id"
            add_env "TELEGRAM_CHAT_ID" "$chat_id"
            TELEGRAM_CHAT_ID="$chat_id"
        else
            read -p "  Chat ID non détecté. Entrez-le manuellement (ex: -1001234567890) : " chat_id
            add_env "TELEGRAM_CHAT_ID" "$chat_id"
            TELEGRAM_CHAT_ID="$chat_id"
        fi
    else
        ok "TELEGRAM_CHAT_ID déjà présent : $TELEGRAM_CHAT_ID"
    fi

    # Test d'envoi
    info "Envoi d'un message de test..."
    curl -sf -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=UPlanet AI Company connectee via Paperclip ✓" \
        -d "parse_mode=HTML" >/dev/null && ok "Message de test envoyé !"

    # Générer le skill Paperclip
    generate_skill_telegram
}

generate_skill_telegram() {
    cat > "$SKILLS_DIR/telegram_poster.js" << 'SKILL_EOF'
/**
 * Skill Paperclip : Telegram poster pour UPlanet
 * Variables requises dans l'environnement Paperclip :
 *   TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
 */
export default {
  name: "telegram_poster",
  description: "Poste un message dans le groupe ou canal Telegram UPlanet",
  parameters: {
    message: { type: "string", description: "Texte du message (HTML supporté)" },
    preview: { type: "boolean", description: "Afficher un aperçu du lien", default: true }
  },
  async run({ message, preview = true }) {
    const token = process.env.TELEGRAM_BOT_TOKEN;
    const chatId = process.env.TELEGRAM_CHAT_ID;
    if (!token || !chatId) throw new Error("TELEGRAM_BOT_TOKEN ou TELEGRAM_CHAT_ID manquant");

    const res = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        chat_id: chatId,
        text: message,
        parse_mode: "HTML",
        disable_web_page_preview: !preview
      })
    });
    const data = await res.json();
    if (!data.ok) throw new Error(`Telegram API: ${data.description}`);
    return { success: true, message_id: data.result.message_id };
  }
};
SKILL_EOF
    ok "Skill généré : $SKILLS_DIR/telegram_poster.js"
}

# =============================================================================
# GMAIL
# =============================================================================

setup_gmail() {
    echo -e "\n${BOLD}${CYAN}=== Configuration Gmail OAuth2 ===${NC}"

    # Vérifier les dépendances Node.js dans le conteneur Paperclip
    ensure_paperclip_deps || warn "Dépendances conteneur non vérifiées — le skill gmail_sender.js pourrait ne pas fonctionner"

    # Le flux OAuth2 initial (obtention du refresh_token) tourne sur l'HÔTE
    # et nécessite python3 + google-auth pour ouvrir le navigateur
    if ! command -v python3 >/dev/null 2>&1; then
        err "Python3 requis sur l'HÔTE uniquement pour le flux OAuth2 initial (ouverture navigateur)"
        err "Installation : sudo apt-get install -y python3 python3-pip"
        err "Le skill gmail_sender.js dans le conteneur n'a pas besoin de Python."
        return 1
    fi

    pip install --quiet --break-system-packages google-auth-oauthlib google-auth-httplib2 google-api-python-client 2>/dev/null || true

    local creds_file="$INSTALL_DIR/gmail_credentials.json"

    if [ ! -f "$creds_file" ]; then
        echo -e "  1. Aller sur https://console.cloud.google.com"
        echo -e "  2. Créer un projet 'UPlanet Marketing'"
        echo -e "  3. APIs & Services → Gmail API → Activer"
        echo -e "  4. Credentials → OAuth 2.0 Client ID → Application bureau"
        echo -e "  5. Télécharger le JSON et copier son chemin"
        read -p "  Chemin vers credentials.json : " src_path
        if [ -f "$src_path" ]; then
            cp "$src_path" "$creds_file"
            ok "credentials.json copié"
        else
            err "Fichier introuvable : $src_path"
            return 1
        fi
    else
        ok "credentials.json déjà présent"
    fi

    if [ -z "$GMAIL_REFRESH_TOKEN" ]; then
        info "Démarrage du flux OAuth2 (navigateur requis)..."
        refresh=$(python3 - << 'PYEOF'
import json, sys
from google_auth_oauthlib.flow import InstalledAppFlow
SCOPES = [
    'https://www.googleapis.com/auth/gmail.send',
    'https://www.googleapis.com/auth/gmail.readonly',
    'https://www.googleapis.com/auth/gmail.modify'
]
import os
creds_path = os.path.expanduser("~/.zen/ai-company/gmail_credentials.json")
flow = InstalledAppFlow.from_client_secrets_file(creds_path, SCOPES)
creds = flow.run_local_server(port=0, open_browser=True)
with open(creds_path.replace('credentials','token'), 'w') as f:
    json.dump({'token': creds.token, 'refresh_token': creds.refresh_token,
               'client_id': creds.client_id, 'client_secret': creds.client_secret}, f)
print(creds.refresh_token)
PYEOF
        )
        if [ -n "$refresh" ]; then
            add_env "GMAIL_REFRESH_TOKEN" "$refresh"
            ok "Refresh token Gmail obtenu et sauvegardé"
        else
            err "Échec de l'authentification Gmail"
            return 1
        fi
    else
        ok "GMAIL_REFRESH_TOKEN déjà présent"
    fi

    # Générer le skill
    generate_skill_gmail
}

generate_skill_gmail() {
    cat > "$SKILLS_DIR/gmail_sender.js" << 'SKILL_EOF'
/**
 * Skill Paperclip : Envoi email Gmail pour UPlanet
 * Variables requises dans l'environnement Paperclip :
 *   GMAIL_REFRESH_TOKEN, GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET
 * Runtime : Node.js 18+ (fetch natif — aucune dépendance npm)
 */
export default {
  name: "gmail_sender",
  description: "Envoie un email via Gmail OAuth2 pour UPlanet",
  parameters: {
    to:      { type: "string",  description: "Adresse email du destinataire" },
    subject: { type: "string",  description: "Sujet de l'email" },
    body:    { type: "string",  description: "Corps de l'email (HTML accepté)" },
    sender:  { type: "string",  description: "Nom de l'expéditeur", default: "UPlanet" }
  },
  async run({ to, subject, body, sender = "UPlanet" }) {
    const refreshToken = process.env.GMAIL_REFRESH_TOKEN;
    const clientId     = process.env.GMAIL_CLIENT_ID;
    const clientSecret = process.env.GMAIL_CLIENT_SECRET;
    if (!refreshToken || !clientId || !clientSecret)
      throw new Error("GMAIL_REFRESH_TOKEN, GMAIL_CLIENT_ID ou GMAIL_CLIENT_SECRET manquant");

    // 1. Obtenir un access_token via le refresh_token
    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type:    "refresh_token",
        refresh_token: refreshToken,
        client_id:     clientId,
        client_secret: clientSecret
      })
    });
    const { access_token, error: tokenErr } = await tokenRes.json();
    if (!access_token) throw new Error(`OAuth2 Gmail : ${tokenErr || "access_token non obtenu"}`);

    // 2. Construire le message MIME encodé en base64url (RFC 2822)
    const mime = [
      `From: ${sender} <me>`,
      `To: ${to}`,
      `Subject: ${subject}`,
      "MIME-Version: 1.0",
      'Content-Type: text/html; charset="UTF-8"',
      "",
      body
    ].join("\r\n");
    const raw = Buffer.from(mime).toString("base64url");

    // 3. Envoyer via l'API REST Gmail (pas d'import npm nécessaire)
    const sendRes = await fetch(
      "https://gmail.googleapis.com/gmail/v1/users/me/messages/send",
      {
        method: "POST",
        headers: {
          Authorization:  `Bearer ${access_token}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ raw })
      }
    );
    const result = await sendRes.json();
    if (result.error) throw new Error(`Gmail API : ${result.error.message}`);
    return { success: true, id: result.id };
  }
};
SKILL_EOF
    ok "Skill généré : $SKILLS_DIR/gmail_sender.js"
}

# =============================================================================
# MASTODON
# =============================================================================

setup_mastodon() {
    echo -e "\n${BOLD}${CYAN}=== Configuration Mastodon ===${NC}"

    # Vérifier les dépendances Node.js dans le conteneur Paperclip
    ensure_paperclip_deps || warn "Dépendances conteneur non vérifiées — le skill mastodon_poster.js pourrait ne pas fonctionner"

    if [ -z "$MASTODON_INSTANCE" ]; then
        read -p "  Instance Mastodon (ex: https://mamot.fr) : " instance
        add_env "MASTODON_INSTANCE" "$instance"
        MASTODON_INSTANCE="$instance"
    else
        ok "MASTODON_INSTANCE : $MASTODON_INSTANCE"
    fi

    if [ -z "$MASTODON_TOKEN" ]; then
        echo -e "  Sur $MASTODON_INSTANCE → Préférences → Développement → Nouvelle application"
        echo -e "  Scopes requis : write:statuses, read:accounts"
        read -p "  Access Token : " token
        add_env "MASTODON_TOKEN" "$token"
        MASTODON_TOKEN="$token"
    else
        ok "MASTODON_TOKEN déjà présent"
    fi

    # Vérifier
    info "Vérification du compte Mastodon..."
    acct=$(curl -sf -H "Authorization: Bearer $MASTODON_TOKEN" \
        "$MASTODON_INSTANCE/api/v1/accounts/verify_credentials" \
        | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{
  try{console.log(JSON.parse(d).acct||'?');}catch(e){console.log('erreur');}
})" 2>/dev/null || echo "erreur")

    if [ "$acct" != "erreur" ]; then
        ok "Compte vérifié : @$acct"
    else
        warn "Impossible de vérifier — token invalide ou instance inaccessible"
    fi

    # Test post
    read -p "  Envoyer un toot de test ? (y/N) : " confirm
    if [[ $confirm =~ ^[Yy] ]]; then
        curl -sf -X POST \
            -H "Authorization: Bearer $MASTODON_TOKEN" \
            -F "status=UPlanet AI Company connectée via Paperclip — Internet souverain en marche #UPlanet #Nostr #LibreCommun" \
            "$MASTODON_INSTANCE/api/v1/statuses" >/dev/null && ok "Toot envoyé !"
    fi

    generate_skill_mastodon
}

generate_skill_mastodon() {
    cat > "$SKILLS_DIR/mastodon_poster.js" << 'SKILL_EOF'
/**
 * Skill Paperclip : Poster un statut Mastodon pour UPlanet
 * Variables requises dans l'environnement Paperclip :
 *   MASTODON_INSTANCE, MASTODON_TOKEN
 * Runtime : Node.js 18+ (fetch natif — aucune dépendance npm)
 */
export default {
  name: "mastodon_poster",
  description: "Publie un statut sur Mastodon depuis le compte UPlanet",
  parameters: {
    status:     { type: "string", description: "Texte du toot (500 caractères max)" },
    visibility: { type: "string", description: "public | unlisted | private | direct", default: "public" }
  },
  async run({ status, visibility = "public" }) {
    const instance = process.env.MASTODON_INSTANCE;
    const token    = process.env.MASTODON_TOKEN;
    if (!instance || !token)
      throw new Error("MASTODON_INSTANCE ou MASTODON_TOKEN manquant");

    const res = await fetch(`${instance}/api/v1/statuses`, {
      method: "POST",
      headers: {
        Authorization:  `Bearer ${token}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ status, visibility })
    });
    const data = await res.json();
    if (data.error) throw new Error(`Mastodon API : ${data.error}`);
    return { success: true, id: data.id, url: data.url };
  }
};
SKILL_EOF
    ok "Skill généré : $SKILLS_DIR/mastodon_poster.js"
}

# =============================================================================
# NOSTR / ASTROPORT
# =============================================================================

setup_nostr() {
    echo -e "\n${BOLD}${CYAN}=== Configuration Nostr / Astroport.ONE ===${NC}"

    if [ -z "$NOSTR_NSEC" ]; then
        warn "Clé privée Nostr (nsec1...) requise pour publier sur le réseau UPlanet"
        info "Récupérer depuis : ~/.zen/game/players/*/secret.june"
        read -p "  nsec1... (laisser vide pour ignorer) : " nsec
        [ -n "$nsec" ] && add_env "NOSTR_NSEC" "$nsec"
    else
        ok "NOSTR_NSEC déjà présent"
    fi

    if [ -z "$ASTROPORT_API" ]; then
        read -p "  URL API Astroport local (ex: http://localhost:1234) : " api
        add_env "ASTROPORT_API" "${api:-http://localhost:1234}"
    else
        ok "ASTROPORT_API : $ASTROPORT_API"
    fi

    ok "Nostr configuré — les posts passeront par l'Astroport local"
}

# =============================================================================
# RAPPORT DE SANTÉ
# =============================================================================

health_check() {
    echo -e "\n${BOLD}${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║     UPlanet AI Company — Rapport de santé    ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════╝${NC}"

    # Docker
    echo -e "\n${BOLD}Services Docker :${NC}"
    for svc in paperclip open-webui llm-proxy qdrant; do
        if docker ps --filter "name=ai-company" --filter "status=running" \
           --format "{{.Names}}" | grep -q "$svc"; then
            ok "$svc"
        else
            err "$svc (DOWN)"
        fi
    done

    # Canaux
    echo -e "\n${BOLD}Canaux configurés :${NC}"
    [ -n "$TELEGRAM_BOT_TOKEN" ] && ok "Telegram (token présent)" || warn "Telegram (non configuré)"
    [ -n "$GMAIL_REFRESH_TOKEN" ] && ok "Gmail OAuth2" || warn "Gmail (non configuré)"
    [ -n "$MASTODON_TOKEN" ] && ok "Mastodon ($MASTODON_INSTANCE)" || warn "Mastodon (non configuré)"
    [ -n "$LINKEDIN_ACCESS_TOKEN" ] && ok "LinkedIn" || info "LinkedIn (optionnel, phase 2)"
    [ -n "$NOSTR_NSEC" ] && ok "Nostr / Astroport" || warn "Nostr (non configuré)"

    # Skills générés
    echo -e "\n${BOLD}Skills Paperclip (Node.js natif) :${NC}"
    for skill in telegram_poster.js gmail_sender.js mastodon_poster.js; do
        if [ -f "$SKILLS_DIR/$skill" ]; then
            ok "$skill"
        else
            warn "$skill (non généré)"
        fi
    done

    # Paperclip
    echo -e "\n${BOLD}Paperclip :${NC}"
    if curl -sf http://localhost:3100/api/health >/dev/null 2>&1; then
        ok "Paperclip répond sur :3100"
    else
        warn "Paperclip ne répond pas — http://localhost:3100"
    fi

    echo -e "\n${BOLD}Accès :${NC}"
    echo -e "  Paperclip : ${CYAN}http://localhost:3100${NC}"
    echo -e "  Open WebUI: ${CYAN}http://localhost:8000${NC}"
    echo -e "  Skills     : ${YELLOW}$SKILLS_DIR${NC}"
    echo ""
}

# =============================================================================
# MENU PRINCIPAL
# =============================================================================

show_menu() {
    echo -e "\n${BOLD}${CYAN}UPlanet AI Company — Configuration des canaux${NC}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "  [1] Vérifier la stack Docker"
    echo -e "  [d] Vérifier dépendances conteneur (Node.js ≥ 18, curl)"
    echo -e "  [2] Configurer Telegram"
    echo -e "  [3] Configurer Gmail"
    echo -e "  [4] Configurer Mastodon"
    echo -e "  [5] Configurer Nostr / Astroport"
    echo -e "  [6] Tout configurer (d→2→3→4→5)"
    echo -e "  [7] Rapport de santé"
    echo -e "  [q] Quitter"
    echo ""
}

# Traitement des arguments
# Usage : ./paperclip-configure-channels.sh [--check|--deps|--telegram|--gmail|--mastodon|--all|--health]
case "$1" in
    --check)    check_stack; health_check; exit 0 ;;
    --deps)     check_stack; ensure_paperclip_deps; exit 0 ;;
    --telegram) check_stack; setup_telegram; health_check; exit 0 ;;
    --gmail)    check_stack; setup_gmail; health_check; exit 0 ;;
    --mastodon) check_stack; setup_mastodon; health_check; exit 0 ;;
    --all)      check_stack; ensure_paperclip_deps; setup_telegram; setup_gmail; setup_mastodon; setup_nostr; health_check; exit 0 ;;
    --health)   health_check; exit 0 ;;
esac

# Mode interactif
while true; do
    show_menu
    read -p "Choix : " choice
    case "$choice" in
        1) check_stack ;;
        d|D) ensure_paperclip_deps ;;
        2) setup_telegram ;;
        3) setup_gmail ;;
        4) setup_mastodon ;;
        5) setup_nostr ;;
        6) check_stack; ensure_paperclip_deps; setup_telegram; setup_gmail; setup_mastodon; setup_nostr ;;
        7) health_check ;;
        q|Q) echo -e "${GREEN}Au revoir !${NC}"; exit 0 ;;
        *) warn "Choix invalide" ;;
    esac
done
