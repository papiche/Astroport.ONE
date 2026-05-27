#!/bin/bash
########################################################################
# bro_dm_daemon.sh — Daemon temps réel pour les DMs du NODE (kind 4)
#
# Surveille ~/.zen/tmp/bro_dm_queue/ via inotifywait.
# Chaque nouveau fichier JSON déposé par filter/4.sh (strfry writePolicy)
# est déchiffré (NIP-44 avec fallback NIP-04) puis routé selon le canal :
#
#   channel "plain"  → question BRO : interroge la KB Nextcloud
#                       (RAG Qdrant + Ollama via nextcloud_bro_sync.sh)
#                       et répond en DM NIP-44 à l'expéditeur.
#
#   channel "udrive" → sync uDRIVE : récupère le CID IPFS et place
#                       le fichier dans APP/uDRIVE du joueur concerné
#                       (même logique que le listener poll de NOSTRCARD.refresh.sh).
#
# Les events sont traités en parallèle (max _BRO_MAX_JOBS jobs simultanés)
# via un sémaphore à slots PID — évite la saturation Ollama/GPU.
#
# Lancé automatiquement par _12345.sh si absent.
# Usage : bro_dm_daemon.sh [--stop]
########################################################################

MY_PATH="$(dirname "$(realpath "$0")")"
. "${HOME}/.zen/Astroport.ONE/tools/my.sh" 2>/dev/null || true

BRO_SCRIPT_ID="bro_dm"
BRO_LOG_FILE="$HOME/.zen/tmp/bro_dm_daemon.log"
# shellcheck source=bro_common_lib.sh
source "$MY_PATH/bro_common_lib.sh" 2>/dev/null || true

QUEUE_DIR="$HOME/.zen/tmp/bro_dm_queue"
PID_FILE="$HOME/.zen/tmp/bro_dm_daemon.pid"
LOG_FILE="$HOME/.zen/tmp/bro_dm_daemon.log"
INTERCOM="${HOME}/.zen/Astroport.ONE/tools/nostr_node_intercom.py"
SECURE_DM="${HOME}/.zen/Astroport.ONE/tools/nostr_send_secure_dm.py"
MAILJET="${HOME}/.zen/Astroport.ONE/tools/mailjet.sh"
BRO_SYNC="$MY_PATH/nextcloud_bro_sync.sh"

mkdir -p "$QUEUE_DIR"
mkdir -p "$HOME/.zen/flashmem"

## ── Sémaphore : jobs parallèles dynamiques selon RAM + GPU ─────────────
## Base: RAM_GiB / 4 (4 GiB par job Ollama), min 1 max 8.
## Si GPU NVIDIA détecté (Brain) : doublement du quota.
_BRO_MAX_JOBS=$(python3 - <<'PYEOF'
import subprocess, re, os
try:
    mem_kb = int(re.search(r'MemAvailable:\s+(\d+)', open('/proc/meminfo').read()).group(1))
    ram_gib = mem_kb / 1024 / 1024
except Exception:
    ram_gib = 4.0
jobs = max(1, min(8, int(ram_gib / 4)))
try:
    r = subprocess.run(
        ['nvidia-smi', '--query-gpu=memory.total', '--format=csv,noheader,nounits'],
        capture_output=True, text=True, timeout=3)
    if r.returncode == 0 and r.stdout.strip():
        jobs = min(8, jobs * 2)
except Exception:
    pass
print(jobs)
PYEOF
)
[[ -z "$_BRO_MAX_JOBS" || ! "$_BRO_MAX_JOBS" =~ ^[0-9]+$ ]] && _BRO_MAX_JOBS=3
_BRO_SLOTS_DIR="$HOME/.zen/tmp/bro_dm_slots"
mkdir -p "$_BRO_SLOTS_DIR"

IA_LOG="$HOME/.zen/tmp/IA.log"
_log() { echo "[$(date '+%H:%M:%S')] [bro_dm] $*" | tee -a "$LOG_FILE" -a "$IA_LOG"; }

## Wrapper sécurisé : NSEC passé via stdin, jamais en argument (invisible dans ps aux)
_send_dm() { printf '%s\n' "$NODE_NSEC" | python3 "$SECURE_DM" --nsec-stdin "$@" 2>/dev/null; }

## ── Alerte email capitaine (rate-limitée à 1/24h) ────────────────────
_ALERT_LOCK="$HOME/.zen/flashmem/bro_dm_alert.lock"
_alert_captain() {
    local msg="$1"
    [[ -z "${CAPTAINEMAIL:-}" ]] && return
    [[ ! -x "$MAILJET" ]] && return

    ## Rate-limit : 1 alerte max toutes les 24h
    if [[ -f "$_ALERT_LOCK" ]]; then
        local _age=$(( $(date +%s) - $(stat -c %Y "$_ALERT_LOCK") ))
        [[ $_age -lt 86400 ]] && return
    fi

    local _tmp
    _tmp=$(mktemp /tmp/bro_alert_XXXXXX.html)
    cat > "$_tmp" <<EOF
<h2>🚨 BRO Daemon — erreur station $(hostname)</h2>
<p><strong>Date :</strong> $(date '+%Y-%m-%d %H:%M:%S')</p>
<p><strong>Station :</strong> ${myDOMAIN:-$(hostname)}</p>
<p><strong>Détail :</strong></p>
<pre style="background:#fff3cd;padding:1em;border-radius:4px;white-space:pre-wrap;">${msg}</pre>
<p>Logs complets : <code>${LOG_FILE}</code></p>
<hr><p style="color:#888;font-size:0.85em;">Alerte valide 24h — une seule par fenêtre.</p>
EOF
    touch "$_ALERT_LOCK"
    (
        bash "$MAILJET" --template "$0" --expire 48h \
            "$CAPTAINEMAIL" "$_tmp" "🚨 BRO Daemon erreur — $(hostname)" \
            2>/dev/null
        rm -f "$_tmp"
    ) &
    _log "📧 Alerte Mailjet envoyée à $CAPTAINEMAIL"
}

## ── --stop ───────────────────────────────────────────────────────────
if [[ "${1:-}" == "--stop" ]]; then
    if [[ -f "$PID_FILE" ]]; then
        _pid=$(cat "$PID_FILE")
        kill "$_pid" 2>/dev/null && _log "Daemon arrêté (PID $_pid)" || _log "Daemon déjà arrêté"
        rm -f "$PID_FILE"
    else
        _log "Aucun daemon en cours"
    fi
    exit 0
fi

## ── Vérification singleton ───────────────────────────────────────────
if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    _log "Daemon déjà en cours (PID $(cat "$PID_FILE"))"
    exit 0
fi

## ── Charger NODE_NSEC ────────────────────────────────────────────────
if [[ ! -s "$HOME/.zen/game/secret.nostr" ]]; then
    _log "ERREUR: ~/.zen/game/secret.nostr absent — daemon non démarré"
    exit 1
fi
source "$HOME/.zen/game/secret.nostr"
NODE_NSEC="${NSEC:-}"
NODE_NPUB="${NPUB:-}"
unset NSEC NPUB HEX

if [[ -z "$NODE_NSEC" ]]; then
    _log "ERREUR: NODE_NSEC absent dans secret.nostr"
    exit 1
fi

## ── Vérifier inotifywait (optionnel — fallback polling si absent) ────
if ! command -v inotifywait &>/dev/null; then
    _log "WARN: inotifywait absent — fallback polling actif (apt install inotify-tools pour la réactivité temps réel)"
fi

## ── Relais ───────────────────────────────────────────────────────────
_RELAYS=("wss://relay.copylaradio.com")
[[ -n "${myRELAY:-}" ]] && _RELAYS+=("$myRELAY")

## Relay de la constellation accessible depuis tous les navigateurs roaming.
## Utilisé en tant que canal inter-station quand myRELAY=ws://127.0.0.1:7777
## (relay local non joignable depuis l'extérieur).
_CONSTELLATION_RELAY="wss://relay.copylaradio.com"
[[ -n "${myLIBRA:-}" ]] && _CONSTELLATION_RELAY="wss://relay.${myLIBRA#*://ipfs.}"

## ── PID guard ────────────────────────────────────────────────────────
echo $$ > "$PID_FILE"
## Nettoyer les slots de l'instance précédente (PID mort)
rm -f "$_BRO_SLOTS_DIR"/slot*.pid 2>/dev/null
_BRO_CLEAN_STOP=false
_SWEEP_PID=""
trap '_BRO_CLEAN_STOP=true' INT TERM
trap 'wait; kill "${_SWEEP_PID:-}" "${_CONSTELLATION_SUB_PID:-}" 2>/dev/null; rm -f "$PID_FILE" "$_BRO_SLOTS_DIR"/slot*.pid; _log "Daemon DM arrêté"; [[ "$_BRO_CLEAN_STOP" == false ]] && _alert_captain "Le daemon bro_dm_daemon.sh sest arrêté de façon inattendue (PID $$)."' EXIT

_log "🚀 Daemon DM NODE démarré (PID $$, max ${_BRO_MAX_JOBS} jobs) — queue: $QUEUE_DIR"

## ── Canal "#badge" : génération d'image de badge skill via ComfyUI ────────
## Syntaxe DM : "#badge <skill>"  ex: "#badge docker"
## Appelle generate_image.sh avec un prompt adapté, retourne l'URL IPFS.
_handle_badge() {
    local sender="$1" skill="$2"
    [[ -z "$skill" ]] && {
        _send_dm "$sender" \
            "⚠️ Usage : #badge <compétence>  ex: #badge docker" \
            "${_RELAYS[0]}" 2>/dev/null
        return
    }
    _log "🎨 #badge demande de ${sender:0:12}... pour skill: $skill"

    local GENERATE_IMG="$MY_PATH/../generators/generate_image.sh"
    if [[ ! -x "$GENERATE_IMG" ]]; then
        _send_dm "$sender" \
            "⚠️ Le générateur d'images (ComfyUI) n'est pas disponible sur cette station." \
            "${_RELAYS[0]}" 2>/dev/null
        return
    fi

    # Informer l'utilisateur que la génération est en cours
    _send_dm "$sender" \
        "🎨 Génération du badge '${skill}'… Cela peut prendre 30-60 secondes (ComfyUI)." \
        "${_RELAYS[0]}" 2>/dev/null

    local prompt="A pixel art badge icon for the '${skill}' skill, hexagonal shape, vibrant colors, dark background, technology emblem, professional logo, 8-bit style, clean design, WoTx2 skill badge"
    local ipfs_url
    ipfs_url=$(bash "$GENERATE_IMG" "$prompt" 2>/dev/null)

    if [[ -n "$ipfs_url" ]] && echo "$ipfs_url" | grep -q "ipfs"; then
        _log "🎨 #badge OK pour $skill : $ipfs_url"
        local _badge_reply
        _badge_reply=$(printf "✅ Badge '%s' généré !\n🖼️ %s\n\nCopiez ce lien pour l'ajouter comme ressource dans l'onglet Formation de my_wotx2.html" "$skill" "$ipfs_url")
        _send_dm "$sender" \
            "$_badge_reply" \
            "${_RELAYS[0]}" 2>/dev/null
    else
        _log "WARN: #badge échec génération pour $skill"
        _send_dm "$sender" \
            "❌ Échec de la génération pour '${skill}'. Vérifiez que ComfyUI est démarré (port 8188)." \
            "${_RELAYS[0]}" 2>/dev/null
    fi
}

## ── Canal "#craft" : décomposer une URL en recette WoTx2 via IA ────────
## Syntaxe DM : "#craft https://instructables.com/..."
## Récupère le contenu HTML, demande à question.py un JSON {name,icon,description,
## ingredients:[{skill,level}],resource_type} adapté à l'éditeur MineLife.
_handle_craft() {
    local sender="$1" url="$2"
    [[ -z "$url" ]] && {
        _send_dm "$sender" \
            "⚠️ Usage : #craft <url>  ex: #craft https://instructables.com/Arduino-TV-B-Gone/" \
            "${_RELAYS[0]}" 2>/dev/null
        return
    }
    _log "🔨 #craft analyse URL de ${sender:0:12}...: ${url:0:80}"

    _send_dm "$sender" \
        "⏳ Analyse IA en cours pour : $url" "${_RELAYS[0]}" 2>/dev/null

    local content
    content=$(python3 "$MY_PATH/../bro_url_content.py" "$url" 2>/dev/null | head -c 6000)

    if [[ ${#content} -lt 80 ]]; then
        _log "WARN: #craft contenu trop court pour $url — tentative describe_image"
        if command -v python3 &>/dev/null && [[ -f "$MY_PATH/../describe_image.py" ]]; then
            content=$(python3 "$MY_PATH/../describe_image.py" "$url" \
                --model "llama3.2-vision:11b" \
                --prompt "Décris ce tutoriel : titre, matériaux, étapes, compétences requises." \
                2>/dev/null | head -c 4000)
        fi
    fi

    if [[ ${#content} -lt 40 ]]; then
        _send_dm "$sender" \
            "❌ Impossible de récupérer le contenu de : $url" "${_RELAYS[0]}" 2>/dev/null
        return
    fi

    local tmp_prompt
    tmp_prompt=$(mktemp)
    cat > "$tmp_prompt" <<CRAFTPROMPT
Tu es un assistant pédagogique Crafting Mine Life sur UPlanet. Analyse ce tutoriel et identifie les compétences requises.
Réponds UNIQUEMENT en JSON valide sur une seule ligne (aucun texte autour, aucun markdown) :
{"name":"Nom en français","icon":"emoji","description":"1 phrase","ingredients":[{"skill":"nom_skill","level":1}],"resource_type":"lien"}
Règles strictes :
- skills : minuscules, pas d'espaces (underscores), 1-3 mots (ex: arduino, soudure, electronique_base)
- level : 1=débutant 2=intermédiaire 3=avancé
- 2 à 6 ingrédients
- resource_type : "document", "video" ou "lien"

Tutoriel :
$content
CRAFTPROMPT

    local answer
    answer=$(python3 "$MY_PATH/../question.py" \
        --prompt-file  "$tmp_prompt" \
        --model        "gemma3:latest" \
        --ctx          8192 \
        --max-tokens   256 \
        --temperature  0.2 \
        2>/dev/null)
    rm -f "$tmp_prompt"

    # Extraire uniquement le bloc JSON si la réponse contient du texte parasite
    local json_answer
    json_answer=$(echo "$answer" | grep -o '{.*}' | head -1)
    [[ -z "$json_answer" ]] && json_answer="$answer"
    [[ -z "$json_answer" ]] && json_answer='{"error":"IA indisponible — réessayez plus tard"}'

    _log "🔨 #craft réponse JSON pour ${sender:0:12}...: ${json_answer:0:100}"
    _send_dm "$sender" "$json_answer" "${_RELAYS[0]}" \
        && _log "🔨 #craft réponse envoyée" \
        || _log "WARN: #craft échec envoi DM"
}

## ── Canal "plain" : question BRO → réponse IA ────────────────────────
## slots : liste CSV de slots mémoire à inclure ("0" = tous, "1,5" = slots 1 et 5)
_handle_bro() {
    local sender="$1" question="$2" slots="${3:-0}"
    [[ -z "$question" ]] && return
    _log "🧠 BRO question de ${sender:0:12}... (slots: $slots): ${question:0:80}"

    local answer
    answer=$(bash "$BRO_SYNC" --query "$question" --user "$sender" --slots "$slots" 2>/dev/null)
    if [[ -z "$answer" ]]; then
        _log "WARN: BRO sync retourne vide — Ollama/Qdrant indisponible ?"
        _alert_captain "BRO Sync a retourné une réponse vide pour la question :\n${question}\n\nSender: ${sender}\n\nVérifiez Ollama et Qdrant."
        answer="⚠️ Le service IA est temporairement indisponible. Réessayez dans quelques minutes."
    fi

    _send_dm \
        "$sender" "$answer" \
        "${_RELAYS[0]}" \
        && _log "🧠 BRO réponse envoyée à ${sender:0:12}..." \
        || _log "WARN: BRO échec envoi DM à ${sender:0:12}..."
}

## ── Résoudre email depuis sender hex → délégué à bro_common_lib.sh ──
_sender_email() { bro_resolve_email "$1"; }

## ── Vérifier accès slot → bro_common_lib.sh ─────────────────────────
_check_slot_access() { bro_check_slot_access "$@"; }

## ── Canal "plain" #rec:<skill> : contribution à la mémoire partagée ───────
## Syntaxe : "#rec:devops Je maîtrise nginx" → ~/.zen/flashmem/skills/devops.md
_handle_rec_skill() {
    local sender="$1" skill="$2" content="$3"
    [[ -z "$skill" || -z "$content" ]] && return
    _log "💾 #rec:$skill de ${sender:0:12}...: ${content:0:60}"

    if python3 "$MY_PATH/../skill_flashmem.py" write \
            --skill "$skill" --text "$content" --npub "$sender" 2>/dev/null; then
        _send_dm "$sender" \
            "💾 Mémorisé dans la base partagée 'skills/${skill}'. Merci pour la contribution ! 🧠" \
            "${_RELAYS[0]}" 2>/dev/null
    else
        _send_dm "$sender" \
            "❌ Échec mémorisation skill $skill." \
            "${_RELAYS[0]}" 2>/dev/null
    fi
}

## ── Canal "plain" #mem:<skill> : lecture mémoire partagée ─────────────────
## Syntaxe : "#mem:devops" → affiche flashmem skills/devops.md
## Syntaxe : "#mem:"       → liste tous les skills mémorisés
_handle_mem_skill() {
    local sender="$1" skill="${2:-}"
    _log "📖 #mem:${skill:-all} de ${sender:0:12}..."

    local reply
    if [[ -z "$skill" ]]; then
        local skills_list
        skills_list=$(python3 "$MY_PATH/../skill_flashmem.py" list 2>/dev/null)
        if [[ -z "$skills_list" || "$skills_list" == "(aucun)" ]]; then
            reply="📚 Aucune mémoire skill enregistrée sur ce node.
Contribuez avec : #rec:<skill> <votre note>
Exemple : #rec:devops Je maîtrise nginx"
        else
            reply="📚 Skills mémorisés sur ce node :
${skills_list}

Consultez un skill : #mem:<skill>
Contribuez : #rec:<skill> <note>"
        fi
    else
        local content
        content=$(python3 "$MY_PATH/../skill_flashmem.py" read --skill "$skill" 2>/dev/null)
        if [[ -z "$content" ]]; then
            reply="📚 Aucune note pour '${skill}'. Contribuez avec :
#rec:${skill} <votre expérience ou ressource>"
        else
            local lines
            lines=$(echo "$content" | wc -l)
            reply="📚 Mémoire partagée '${skill}' (${lines} entrées) :
${content}"
        fi
    fi

    _send_dm "$sender" "${reply}" "${_RELAYS[0]}"
}

## ── Canal "plain" avec skill context : question liée à un skill ────────────
## Appelé quand le message contient [ctx:<skill>:<level>] (depuis minelife.html)
## ou directement avec skill extrait.
_handle_bro_skill() {
    local sender="$1" question="$2" skill="$3"
    [[ -z "$question" ]] && return
    _log "🎓 BRO skill:$skill de ${sender:0:12}...: ${question:0:80}"

    local answer
    answer=$(python3 "$MY_PATH/../question.py" "$question" \
        --model       "gemma3:latest" \
        --ctx         8192 \
        --max-tokens  2048 \
        --skill       "$skill" \
        --npub        "$sender" \
        2>/dev/null)

    if [[ -z "$answer" ]]; then
        _log "WARN: question.py skill vide — fallback BRO sync"
        answer=$(bash "$BRO_SYNC" --query "$question" --user "$sender" --slots "0" 2>/dev/null)
    fi
    [[ -z "$answer" ]] && answer="⚠️ Service IA temporairement indisponible."

    _send_dm "$sender" "$answer" "${_RELAYS[0]}" \
        && _log "🎓 BRO skill:$skill réponse envoyée à ${sender:0:12}..." \
        || _log "WARN: BRO skill:$skill échec envoi DM"
}

## ── Canal "plain" avec #rec : sauvegarde mémoire personnelle depuis DM ─
## Syntaxe DM : "#rec <texte>"               → slot 0
##              "#rec #2 <texte>"             → slot 2 (sociétaires)
##              "#rec <texte> #bro <question>"→ mémorise ET interroge l'IA
_handle_rec() {
    local sender="$1" content="$2" slot="${3:-0}"

    ## Trouver l'email associé au sender hex parmi les MULTIPASS locaux
    local email
    email=$(_sender_email "$sender")
    if [[ -z "$email" ]]; then
        _log "WARN: #rec DM: ${sender:0:12}... non hébergé sur cette station"
        _send_dm "$sender" \
            "❌ Votre compte n'est pas hébergé sur cette station — mémoire non sauvegardée." \
            "${_RELAYS[0]}" 2>/dev/null
        return
    fi

    ## Vérifier accès slot
    if ! _check_slot_access "$email" "$slot"; then
        _log "WARN: #rec slot $slot refusé pour ${sender:0:12}... ($email)"
        _send_dm "$sender" \
            "⚠️ Accès refusé : le slot $slot est réservé aux sociétaires. Le slot 0 reste accessible." \
            "${_RELAYS[0]}" 2>/dev/null
        return
    fi
    _log "💾 #rec DM de ${sender:0:12}... ($email) slot $slot : ${content:0:60}"

    ## Construire l'event JSON minimal pour short_memory.py
    local event_json
    event_json=$(jq -n --arg pub "$sender" --arg msg "$content" '{event: {pubkey: $pub, content: $msg}}')

    if [[ -n "$event_json" ]]; then
        python3 "$MY_PATH/../short_memory.py" "$event_json" "0" "0" "$slot" "$email" 2>/dev/null \
            && _log "💾 Mémorisé ($email, slot $slot)" \
            || _log "WARN: échec short_memory.py pour $email slot $slot"
    fi

    _send_dm "$sender" \
        "💾 Mémorisé dans slot $slot (${#content} caractères). Envoyez une question BRO par DM pour utiliser ce contexte." \
        "${_RELAYS[0]}" 2>/dev/null
}

## ── Canal "plain" avec #mem : afficher les mémoires personnelles ────────
## Syntaxe DM : "#mem"       → résumé de tous les slots non vides
##              "#mem #2"    → contenu du slot 2 (5 derniers messages)
_handle_mem() {
    local sender="$1" slot="${2:-0}"
    local email
    email=$(_sender_email "$sender")
    if [[ -z "$email" ]]; then
        _send_dm "$sender" \
            "❌ Votre compte n'est pas hébergé sur cette station." \
            "${_RELAYS[0]}" 2>/dev/null
        return
    fi

    local user_dir="$HOME/.zen/flashmem/$email"
    local reply

    if [[ "$slot" == "0" ]]; then
        reply=$(python3 - "$user_dir" <<'PYEOF'
import json, os, sys
user_dir = sys.argv[1]
lines = ["🧠 Mémoires enregistrées :"]
found = False
for s in range(13):
    sf = os.path.join(user_dir, f"slot{s}.json")
    if not os.path.exists(sf): continue
    try:
        d = json.load(open(sf))
        msgs = d.get("messages", [])
        if not msgs: continue
        last = msgs[-1].get("content", "")[:80]
        lines.append(f"  Slot {s} ({len(msgs)} msg) : {last}…")
        found = True
    except Exception:
        pass
if not found:
    lines = ["Aucune mémoire enregistrée. Utilisez #rec <texte> pour mémoriser."]
print("\n".join(lines))
PYEOF
        )
    else
        reply=$(python3 - "$user_dir" "$slot" <<'PYEOF'
import json, os, sys
user_dir, slot = sys.argv[1], sys.argv[2]
sf = os.path.join(user_dir, f"slot{slot}.json")
if not os.path.exists(sf):
    print(f"Slot {slot} vide.")
    sys.exit()
try:
    d = json.load(open(sf))
    msgs = d.get("messages", [])[-5:]
    lines = [f"📁 Slot {slot} ({len(d.get('messages',[]))} msg — 5 derniers) :"]
    for m in msgs:
        ts = m.get("timestamp", "")[:10]
        lines.append(f"  [{ts}] {m.get('content','')[:120]}")
    print("\n".join(lines))
except Exception as e:
    print(f"Erreur lecture slot {slot}: {e}")
PYEOF
        )
    fi

    _log "📖 #mem répondu à ${sender:0:12}... ($email, slot $slot)"
    _send_dm "$sender" "${reply:-Erreur lecture mémoire.}" \
        "${_RELAYS[0]}" 2>/dev/null
}

## ── Canal "plain" avec #reset : effacer mémoires personnelles ───────────
## Syntaxe DM : "#reset"     → efface tous les slots
##              "#reset #2"  → efface uniquement le slot 2
_handle_reset() {
    local sender="$1" slot="${2:-0}"
    local email
    email=$(_sender_email "$sender")
    if [[ -z "$email" ]]; then
        _send_dm "$sender" \
            "❌ Votre compte n'est pas hébergé sur cette station." \
            "${_RELAYS[0]}" 2>/dev/null
        return
    fi

    if ! _check_slot_access "$email" "$slot"; then
        _send_dm "$sender" \
            "⚠️ Accès refusé : le slot $slot est réservé aux sociétaires." \
            "${_RELAYS[0]}" 2>/dev/null
        return
    fi

    local user_dir="$HOME/.zen/flashmem/$email"
    local reply
    if [[ "$slot" == "0" ]]; then
        rm -f "$user_dir"/slot*.json 2>/dev/null
        reply="🗑️ Toutes les mémoires (slots 0-12) ont été effacées."
    else
        if [[ -f "$user_dir/slot${slot}.json" ]]; then
            rm -f "$user_dir/slot${slot}.json"
            reply="🗑️ Slot $slot effacé."
        else
            reply="Slot $slot déjà vide."
        fi
    fi

    _log "🗑️ #reset ($email, slot $slot)"
    _send_dm "$sender" "$reply" \
        "${_RELAYS[0]}"
}

## ── Helper : parser un payload JSON en plusieurs variables shell ─────
## Usage : _payload_get "$payload" field1 field2 … → variables _FIELD1 _FIELD2 …
_payload_get() {
    local _p="$1"; shift
    local _f _v
    for _f in "$@"; do
        _v=$(jq -r --arg k "$_f" '.[$k] // ""' <<< "$_p" 2>/dev/null)
        printf -v "_${_f^^}" '%s' "$_v"
    done
}

## ── Canal "vocals" : publication kind 1222/1244 depuis la home station ─
## La station visiteur a uploadé le fichier sur IPFS et envoie le CID +
## métadonnées via DM.  Ici on publie l'event NOSTR avec le secret du joueur.
_handle_vocals() {
    local payload="$1"
    _payload_get "$payload" email cid filename mime_type duration title \
                             description waveform kind file_hash info_cid \
                             reply_to_event_id reply_to_pubkey

    [[ -z "$_EMAIL" || -z "$_CID" || -z "$_FILENAME" ]] && \
        _log "WARN: ✈️ vocals: payload incomplet" && return

    bro_user_is_local "$_EMAIL" || { _log "WARN: ✈️ vocals: $_EMAIL non hébergé ou en roaming"; return; }

    local _SECRET="$HOME/.zen/game/nostr/${_EMAIL}/.secret.nostr"
    [[ ! -f "$_SECRET" ]] && \
        _log "WARN: ✈️ vocals: .secret.nostr absent pour $_EMAIL" && return

    local _PUBLISH_SCRIPT="${HOME}/.zen/Astroport.ONE/tools/publish_nostr_vocal.sh"
    [[ ! -x "$_PUBLISH_SCRIPT" ]] && \
        _log "WARN: ✈️ vocals: publish_nostr_vocal.sh introuvable" && return

    local _KIND="${_KIND:-1222}"
    [[ "$_KIND" != "1244" ]] && _KIND="1222"

    local -a _CMD=(
        bash "$_PUBLISH_SCRIPT"
        --nsec      "$_SECRET"
        --ipfs-cid  "$_CID"
        --filename  "$_FILENAME"
        --title     "${_TITLE:-vocal}"
        --mime-type "${_MIME_TYPE:-audio/webm}"
        --duration  "${_DURATION:-0}"
        --kind      "$_KIND"
        --channel   "$_EMAIL"
        --json
    )
    [[ -n "$_DESCRIPTION" ]] && _CMD+=(--description "$_DESCRIPTION")
    [[ -n "$_WAVEFORM"    ]] && _CMD+=(--waveform    "$_WAVEFORM")
    [[ -n "$_FILE_HASH"   ]] && _CMD+=(--file-hash   "$_FILE_HASH")
    [[ -n "$_INFO_CID"    ]] && _CMD+=(--info-cid    "$_INFO_CID")
    if [[ "$_KIND" == "1244" && -n "$_REPLY_TO_EVENT_ID" && -n "$_REPLY_TO_PUBKEY" ]]; then
        _CMD+=(--reply-to-event-id "$_REPLY_TO_EVENT_ID" --reply-to-pubkey "$_REPLY_TO_PUBKEY")
    fi

    local _RC
    timeout 30 "${_CMD[@]}" >> "${HOME}/.zen/tmp/bro_dm_daemon.log" 2>&1
    _RC=$?
    if [[ $_RC -eq 0 ]]; then
        _log "✈️ vocals OK: $_EMAIL kind $_KIND CID=${_CID:0:12}..."
    else
        _log "WARN: ✈️ vocals NOSTR ÉCHEC (rc=$_RC) pour $_EMAIL — fichier sync uDRIVE quand même"
    fi
    # Toujours sync le fichier dans uDRIVE (source de vérité, indépendant de NOSTR)
    _handle_udrive "$payload"
}

## ── Canal "webcam" : publication kind 21/22 depuis la home station ────
## Même principe que vocals mais pour les vidéos (NIP-71, kind 21/22).
_handle_webcam() {
    local payload="$1"
    _payload_get "$payload" email cid filename mime_type duration title \
                             description dimensions file_size \
                             thumbnail_ipfs gifanim_ipfs info_cid file_hash \
                             latitude longitude channel

    [[ -z "$_EMAIL" || -z "$_CID" || -z "$_FILENAME" ]] && \
        _log "WARN: ✈️ webcam: payload incomplet" && return

    bro_user_is_local "$_EMAIL" || { _log "WARN: ✈️ webcam: $_EMAIL non hébergé ou en roaming"; return; }

    local _SECRET="$HOME/.zen/game/nostr/${_EMAIL}/.secret.nostr"
    [[ ! -f "$_SECRET" ]] && \
        _log "WARN: ✈️ webcam: .secret.nostr absent pour $_EMAIL" && return

    local _PUBLISH_SCRIPT="${HOME}/.zen/Astroport.ONE/tools/publish_nostr_video.sh"
    [[ ! -x "$_PUBLISH_SCRIPT" ]] && \
        _log "WARN: ✈️ webcam: publish_nostr_video.sh introuvable" && return

    local -a _CMD=(
        bash "$_PUBLISH_SCRIPT"
        --nsec       "$_SECRET"
        --ipfs-cid   "$_CID"
        --filename   "$_FILENAME"
        --title      "${_TITLE:-video}"
        --mime-type  "${_MIME_TYPE:-video/webm}"
        --duration   "${_DURATION:-0}"
        --dimensions "${_DIMENSIONS:-640x480}"
        --file-size  "${_FILE_SIZE:-0}"
        --latitude   "${_LATITUDE:-0}"
        --longitude  "${_LONGITUDE:-0}"
        --source-type webcam
        --json
    )
    [[ -n "$_CHANNEL"       ]] && _CMD+=(--channel       "$_CHANNEL")
    [[ -n "$_DESCRIPTION"   ]] && _CMD+=(--description   "$_DESCRIPTION")
    [[ -n "$_THUMBNAIL_IPFS" ]] && _CMD+=(--thumbnail-cid "$_THUMBNAIL_IPFS")
    [[ -n "$_GIFANIM_IPFS"  ]] && _CMD+=(--gifanim-cid   "$_GIFANIM_IPFS")
    [[ -n "$_INFO_CID"      ]] && _CMD+=(--info-cid      "$_INFO_CID")
    [[ -n "$_FILE_HASH"     ]] && _CMD+=(--file-hash     "$_FILE_HASH")

    local _RC
    timeout 60 "${_CMD[@]}" >> "${HOME}/.zen/tmp/bro_dm_daemon.log" 2>&1
    _RC=$?
    if [[ $_RC -eq 0 ]]; then
        _log "✈️ webcam OK: $_EMAIL CID=${_CID:0:12}..."
    else
        _log "WARN: ✈️ webcam NOSTR ÉCHEC (rc=$_RC) pour $_EMAIL — fichier sync uDRIVE quand même"
    fi
    # Toujours sync le fichier dans uDRIVE (source de vérité, indépendant de NOSTR)
    _handle_udrive "$payload"
}

## ── Canal "zen_like" : paiement ZEN relayé depuis station visiteur (roaming) ─
## filter/7.sh (kind 7) n'a pas le .secret.dunikey d'un utilisateur en roaming.
## Si ZEN_AMOUNT > 0 il relaie ici via DM NIP-44. La home station exécute le
## vrai paiement G1 avec les clés locales puis enregistre la contribution CF.
_handle_zen_like() {
    local payload="$1"
    _payload_get "$payload" email sender_pubkey event_id reacted_event_id \
                             reacted_author_pubkey zen_amount comment \
                             g1pub_dest is_crowdfunding project_id bien_g1pub

    [[ -z "$_EMAIL" || -z "$_G1PUB_DEST" || -z "$_ZEN_AMOUNT" ]] && \
        _log "WARN: ✈️ zen_like: payload incomplet" && return

    ## Garde: ne traiter que les montants > 0 (redondant mais défensif)
    local _zen_num
    _zen_num=$(python3 -c "print(1 if float('${_ZEN_AMOUNT}') > 0 else 0)" 2>/dev/null)
    [[ "$_zen_num" != "1" ]] && \
        _log "WARN: ✈️ zen_like: ZEN_AMOUNT=0 ignoré" && return

    bro_user_is_local "$_EMAIL" || { _log "WARN: ✈️ zen_like: $_EMAIL non hébergé ou en roaming — paiement ignoré"; return; }

    local _DUNIKEY="$HOME/.zen/game/nostr/${_EMAIL}/.secret.dunikey"
    [[ ! -s "$_DUNIKEY" ]] && \
        _log "WARN: ✈️ zen_like: .secret.dunikey absent pour $_EMAIL" && return

    local _AMOUNT
    _AMOUNT=$(python3 -c "
v = float('${_ZEN_AMOUNT}') * 0.1
print(f'0{v:.2f}' if v < 1 else f'{v:.2f}')
" 2>/dev/null)
    [[ -z "$_AMOUNT" ]] && _log "WARN: ✈️ zen_like: calcul G1 échoué" && return

    _log "✈️ zen_like: ${_ZEN_AMOUNT}Ẑ → ${_AMOUNT}G1 pour $_EMAIL → ${_G1PUB_DEST:0:12}..."
    bash "$HOME/.zen/Astroport.ONE/tools/PAYforSURE.sh" \
        "$_DUNIKEY" "$_AMOUNT" "$_G1PUB_DEST" "${_COMMENT:-UPLANET:ROAMING:LIKE}" \
        >> "$LOG_FILE" 2>&1
    local _RC=$?
    if [[ $_RC -eq 0 ]]; then
        _log "✈️ zen_like OK: ${_ZEN_AMOUNT}Ẑ envoyés pour $_EMAIL"
        [[ "$_IS_CROWDFUNDING" == "True" && -n "$_PROJECT_ID" ]] && \
            _log "✈️ zen_like CF: contribution $_PROJECT_ID enregistrée (via prochain cycle relay)"
    else
        _log "WARN: ✈️ zen_like FAILED (rc=$_RC) pour $_EMAIL"
        _alert_captain "$(printf "zen_like paiement échoué pour %s\n%sẑ (%sG1) → %s...\nCode: %s" \
            "$_EMAIL" "$_ZEN_AMOUNT" "$_AMOUNT" "${_G1PUB_DEST:0:12}" "$_RC")"
    fi
}

## ── Canal "bro_ia" : commande BRO relayée depuis station visiteur (roaming) ─
## La station visiteur (B) a reçu un kind 1 #BRO pour un utilisateur .roaming
## et le relaie ici (home station A) via DM NIP-44. On appelle directement
## UPlanet_IA_Responder.sh avec les paramètres reconstruits depuis le payload.
_handle_bro_ia() {
    local payload="$1"
    _payload_get "$payload" pubkey event_id lat lon message url kname skill
    [[ -z "$_PUBKEY" || -z "$_MESSAGE" ]] && \
        _log "WARN: ✈️ bro_ia: payload incomplet (pubkey ou message manquant)" && return

    ## Extraire [ctx:<skill>] du message si non fourni explicitement dans le payload
    local _skill="${_SKILL:-}"
    if [[ -z "$_skill" && "$_MESSAGE" =~ ^\[ctx:([a-z0-9_-]+)(:[0-9]+)?\][[:space:]]*(.*) ]]; then
        _skill="${BASH_REMATCH[1]}"
        _MESSAGE="${BASH_REMATCH[3]}"
    fi

    _log "✈️ bro_ia: BRO roaming de ${_PUBKEY:0:12}... (${_KNAME:-?}) skill=${_skill:-none}: ${_MESSAGE:0:60}"

    if [[ -n "$_skill" ]]; then
        ## Réponse pédagogique directe via question.py (avec flashmem+Qdrant)
        _handle_bro_skill "$_PUBKEY" "$_MESSAGE" "$_skill"
    else
        bash "$MY_PATH/../UPlanet_IA_Responder.sh" \
            "$_PUBKEY" \
            "${_EVENT_ID:-}" \
            "${_LAT:-0.00}" \
            "${_LON:-0.00}" \
            "$_MESSAGE" \
            "${_URL:-}" \
            "${_KNAME:-}" \
            2>/dev/null
    fi
}

## ── GPU lock global : sérialise les générations vidéo sur ce Brain ─────────
_GPU_LOCK="$HOME/.zen/tmp/comfyui_brain.lock"

## ── Canal "comfyui_job" : génération vidéo déléguée par un satellite ───────
## Payload : email, prompt, mode (t2v|i2v), source_url,
##           reply_node_hex, reply_pubkey, job_id
_handle_comfyui_job() {
    local payload="$1" sender="$2"
    _payload_get "$payload" email prompt mode source_url reply_node_hex reply_pubkey job_id
    [[ -z "$_PROMPT" ]] && \
        _log "WARN: ✈️ comfyui_job: payload incomplet (prompt manquant)" && return
    _log "🎬 comfyui_job: mode=${_MODE:-t2v} job=${_JOB_ID:-?} de ${sender:0:12}... (${_EMAIL:-?})"

    ## Acquérir le verrou GPU exclusif (bloque jusqu'à 5 min max)
    (
        flock -x -w 300 9 || {
            _log "WARN: 🎬 comfyui_job: timeout GPU lock — abandon job ${_JOB_ID:-?}"
            exit 1
        }

        ## Connecter ComfyUI local (local > P2P > SSH)
        if ! bash "$MY_PATH/../services/comfyui.me.sh" 2>/dev/null; then
            _log "WARN: 🎬 comfyui_job: ComfyUI indisponible sur ce Brain"
            exit 1
        fi

        local _tmp_dir _result_url _status="failed"
        _tmp_dir=$(mktemp -d /tmp/comfyui_job_XXXXXX)

        if [[ "${_MODE:-t2v}" == "i2v" && -n "$_SOURCE_URL" ]]; then
            _result_url=$(bash "$MY_PATH/../generators/image_to_video.sh" \
                "$_PROMPT" "$_SOURCE_URL" "$_tmp_dir" 2>/dev/null | tail -1)
        else
            _result_url=$(bash "$MY_PATH/../generators/generate_video.sh" \
                "$_PROMPT" "$MY_PATH/../workflow/video_wan2_2_5B_ti2v.json" \
                "$_tmp_dir" 2>/dev/null | tail -1)
        fi
        rm -rf "$_tmp_dir"

        [[ -n "$_result_url" ]] && _status="ok"
        _log "🎬 comfyui_job: job=${_JOB_ID:-?} status=$_status url=${_result_url:0:60}"

        ## Renvoyer le résultat au satellite demandeur via DM
        if [[ -n "$_REPLY_NODE_HEX" && ${#_REPLY_NODE_HEX} -eq 64 ]]; then
            local _res_payload
            _res_payload=$(python3 -c "
import json, sys
print(json.dumps({
    'job_id':       sys.argv[1],
    'email':        sys.argv[2],
    'result_url':   sys.argv[3],
    'status':       sys.argv[4],
    'reply_pubkey': sys.argv[5],
    'mode':         sys.argv[6],
}))
" "${_JOB_ID:-}" "${_EMAIL:-}" "$_result_url" "$_status" \
  "${_REPLY_PUBKEY:-}" "${_MODE:-t2v}" 2>/dev/null)
            python3 "$INTERCOM" send \
                --nsec    "$NODE_NSEC" \
                --to      "$_REPLY_NODE_HEX" \
                --channel "comfyui_result" \
                --payload "$_res_payload" \
                --relays  "${_RELAYS[0]}" \
                2>/dev/null \
                && _log "🎬 comfyui_job: résultat → ${_REPLY_NODE_HEX:0:12}..." \
                || _log "WARN: 🎬 comfyui_job: DM résultat FAILED"
        fi
    ) 9>"$_GPU_LOCK"
}

## ── Canal "comfyui_result" : résultat reçu depuis un Brain ─────────────────
## Payload : job_id, email, result_url, status, reply_pubkey, mode
_handle_comfyui_result() {
    local payload="$1"
    _payload_get "$payload" job_id email result_url status reply_pubkey mode
    _log "🎬 comfyui_result: job=${_JOB_ID:-?} status=${_STATUS:-?} email=${_EMAIL:-?}"

    if [[ "${_STATUS:-}" != "ok" || -z "$_RESULT_URL" ]]; then
        [[ -n "$_REPLY_PUBKEY" ]] && _send_dm \
            "$_REPLY_PUBKEY" \
            "❌ Génération vidéo échouée (job ${_JOB_ID:-?}). Réessayez ultérieurement." \
            "${_RELAYS[0]}" 2>/dev/null
        return
    fi

    ## Stocker dans uDRIVE/Videos si l'utilisateur est hébergé localement
    if [[ -n "$_EMAIL" ]] && bro_user_is_local "$_EMAIL"; then
        local _cid _fname _udrive_videos
        _udrive_videos=$(bro_udrive_path "$_EMAIL" Videos) || _udrive_videos=""
        _cid=$(echo "$_RESULT_URL" | grep -oP 'Qm[A-Za-z0-9]+' | head -1)
        _fname="video_${_JOB_ID:-$(date +%s)}.mp4"
        if [[ -n "$_cid" && -n "$_udrive_videos" ]]; then
            timeout 120 ipfs get "/ipfs/$_cid" -o "$_udrive_videos/$_fname" 2>/dev/null \
                && touch "$HOME/.zen/game/nostr/$_EMAIL/APP/uDRIVE/" \
                && _log "🎬 comfyui_result: vidéo stockée uDRIVE/$_EMAIL ← $_fname"
        fi
    fi

    ## Notifier l'utilisateur par DM NIP-44
    if [[ -n "$_REPLY_PUBKEY" ]]; then
        local _notif
        _notif=$(printf "🎬 Votre vidéo est prête !\n🔗 %s" "$_RESULT_URL")
        _send_dm \
            "$_REPLY_PUBKEY" "$_notif" \
            "${_RELAYS[0]}" \
            && _log "🎬 comfyui_result: DM envoyé à ${_REPLY_PUBKEY:0:12}..." \
            || _log "WARN: 🎬 comfyui_result: DM FAILED pour ${_REPLY_PUBKEY:0:12}..."
    fi
}

## ── Canal "udrive" : sync fichier depuis IPFS → APP/uDRIVE ───────────
_handle_udrive() {
    local payload="$1"
    _payload_get "$payload" email cid filename filetype
    local _S_EMAIL="$_EMAIL" _S_CID="$_CID" _S_FILE="$_FILENAME" _S_TYPE="${_FILETYPE:-file}"

    [[ -z "$_S_EMAIL" || -z "$_S_CID" || -z "$_S_FILE" ]] && return

    bro_user_is_local "$_S_EMAIL" || { _log "WARN: ✈️ sync ignoré: $_S_EMAIL non hébergé ou en roaming"; return; }

    local _DEST_DIR
    _DEST_DIR=$(bro_udrive_type_dir "$_S_TYPE")
    local _UDRIVE
    _UDRIVE=$(bro_udrive_path "$_S_EMAIL" "$_DEST_DIR") || return

    local _TMP_FILE
    _TMP_FILE=$(mktemp -p "${HOME}/.zen/tmp" "udrive_XXXXXX")
    if timeout 30 ipfs get "/ipfs/${_S_CID}" -o "$_TMP_FILE" 2>/dev/null; then
        mv "$_TMP_FILE" "${_UDRIVE}/${_S_FILE}"
        touch "$(dirname "$_UDRIVE")/"
        _log "✈️ sync OK: $_S_EMAIL ← $_S_FILE (${_S_CID:0:12}...) dans $_DEST_DIR/"
    else
        rm -f "$_TMP_FILE"
        _log "WARN: ✈️ sync ÉCHEC ipfs get pour $_S_FILE (${_S_CID:0:12}...)"
    fi
}

## ── Message de bienvenue aux MULTIPASS locaux ────────────────────────
## Envoyé une seule fois par MULTIPASS (tracé dans bro_dm_welcomed.txt).
## Présente les capacités BRO du node et sa clé de contact.
_send_welcome_messages() {
    local WELCOMED_FILE="$HOME/.zen/flashmem/bro_dm_welcomed.txt"
    mkdir -p "$HOME/.zen/flashmem"
    touch "$WELCOMED_FILE" 2>/dev/null

    local WELCOME_MSG
    WELCOME_MSG="🧠 Bonjour ! Je suis BRO, l'assistant IA de votre station Astroport.

Envoyez-moi vos questions en DM — je rechercherai dans la base de connaissance (Nextcloud + docs) et vous répondrai grâce à Ollama.

━━━ COMMANDES ━━━

❓ Question libre → réponse IA (utilise slot 0 par défaut)
   Exemple : « Quels services sont disponibles ici ? »

🔢 Sélectionner des slots de mémoire pour le contexte :
   Ma question #1        → utilise le slot 1
   Ma question #1 #5     → utilise les slots 1 et 5 combinés

💾 #rec <texte>           → mémoriser dans le slot 0
   #rec #2 <texte>        → mémoriser dans le slot 2 (sociétaires)
   #rec <texte> #bro <?>  → mémoriser ET interroger l'IA

📖 #mem                   → voir toutes vos mémoires
   #mem #2                → voir le contenu du slot 2

🎯 Contexte skill (base de connaissance partagée du node) :
   #rec:<skill> <note>    → contribuer à la mémoire partagée du skill
   #mem:<skill>           → lire la mémoire partagée du skill
   #mem:                  → lister tous les skills mémorisés
   ex: #rec:devops Je maîtrise nginx et TLS
   ex: #mem:devops

🎨 #badge <skill>          → générer une image de badge skill (ComfyUI)
   ex: #badge docker      → badge IA pour la compétence docker

🔨 #craft <url>            → décomposer un tutoriel en recette MineLife (WoTx2)
   ex: #craft https://instructables.com/...
   → retourne un JSON {name, icon, ingredients, ...} pour l'éditeur de craft

🗑️ #reset                  → effacer toutes vos mémoires
   #reset #2              → effacer uniquement le slot 2

━━━━━━━━━━━━━━━━━

Ma clé de contact : ${NODE_NPUB:-NODE}
#BRO"

    local _hex _email_dir
    for _hex_file in "$HOME/.zen/game/nostr/"*"/HEX"; do
        [[ ! -f "$_hex_file" ]] && continue
        _hex=$(tr -d '[:space:]' < "$_hex_file")
        [[ -z "$_hex" || ${#_hex} -ne 64 ]] && continue

        ## Skip si déjà accueilli
        grep -qF "$_hex" "$WELCOMED_FILE" && continue

        ## Skip les comptes en roaming
        _email_dir=$(dirname "$_hex_file")
        [[ -f "$_email_dir/.roaming" ]] && continue

        _send_dm \
            "$_hex" "$WELCOME_MSG" \
            "${_RELAYS[0]}" \
            && { _log "📢 Bienvenue envoyé à ${_hex:0:12}..."; echo "$_hex" >> "$WELCOMED_FILE"; } \
            || _log "WARN: échec bienvenue à ${_hex:0:12}..."
    done
}

## ── Traitement asynchrone avec sémaphore à slots ────────────────────
## Acquiert un slot libre (bloquant), traite l'event, libère le slot.
## Usage : _process_event_async <fichier> &
_process_event_async() {
    local fname="$1"
    local _my_pid=$BASHPID _slot _sfile _pid
    while true; do
        for _slot in $(seq 1 "$_BRO_MAX_JOBS"); do
            _sfile="$_BRO_SLOTS_DIR/slot${_slot}.pid"
            ## Création atomique via noclobber
            if (set -C; echo "$_my_pid" > "$_sfile") 2>/dev/null; then
                _process_event "$fname"
                rm -f "$_sfile"
                return
            fi
            ## Récupérer le slot si le process propriétaire est mort
            _pid=$(cat "$_sfile" 2>/dev/null)
            if [[ -n "$_pid" ]] && ! kill -0 "$_pid" 2>/dev/null; then
                rm -f "$_sfile"
            fi
        done
        sleep 0.5
    done
}

## ── Traitement d'un event JSON ───────────────────────────────────────
_process_event() {
    local event_file="$1"
    [[ ! -f "$event_file" ]] && return

    local decoded
    decoded=$(NOSTR_NSEC="$NODE_NSEC" python3 "$INTERCOM" decrypt 2>/dev/null < "$event_file")
    rm -f "$event_file"

    if [[ -z "$decoded" ]]; then
        _log "WARN: déchiffrement échoué pour $(basename "$event_file")"
        return
    fi

    local channel sender payload
    channel=$(jq -r '.channel // "plain"' <<< "$decoded" 2>/dev/null)
    sender=$(  jq -r '.sender  // ""'     <<< "$decoded" 2>/dev/null)
    payload=$( jq -c '.payload // {}'     <<< "$decoded" 2>/dev/null)

    [[ -z "$sender" ]] && return

    case "$channel" in
        plain)
            local question
            question=$(jq -r '.text // ""' <<< "$payload" 2>/dev/null | tr '\n' ' ')

            ## Collecter TOUS les slots #N (1-12) mentionnés — ex: "#1 #5" → slots=(1 5)
            ## Cohérent avec UPlanet_IA_Responder.sh (slot détecté par tag standalone)
            local _slots=() slot=0
            for i in {1..12}; do
                if [[ "$question" =~ \#${i}([[:space:]]|$) ]]; then
                    _slots+=("$i")
                fi
            done
            ## slot = premier slot (pour #rec/#mem/#reset) ; slot_str = liste CSV pour BRO
            [[ ${#_slots[@]} -gt 0 ]] && slot="${_slots[0]}"
            local slot_str
            slot_str=$(IFS=,; echo "${_slots[*]:-0}")

            ## ── Extraire [ctx:<skill>:<level>] si présent (préfixe minelife.html) ──
            local _ctx_skill=""
            if [[ "$question" =~ ^\[ctx:([a-z0-9_-]+)(:[0-9]+)?\][[:space:]]*(.*) ]]; then
                _ctx_skill="${BASH_REMATCH[1]}"
                question="${BASH_REMATCH[3]}"
            fi

            ## Router selon la commande DM
            if echo "$question" | grep -qi '#reset'; then
                _handle_reset "$sender" "$slot"

            elif echo "$question" | grep -qi '#craft'; then
                ## #craft <url> → décomposer une URL en recette WoTx2
                local craft_url
                craft_url=$(echo "$question" | grep -oiE 'https?://[^[:space:]]+' | head -1)
                [[ -z "$craft_url" ]] && craft_url=$(echo "$question" | sed 's/#craft[[:space:]]*//' | xargs)
                _handle_craft "$sender" "$craft_url"

            elif echo "$question" | grep -qi '#badge'; then
                ## #badge <skill> → génère un badge image via ComfyUI
                local badge_skill
                badge_skill=$(echo "$question" | sed 's/.*#badge[[:space:]]*//' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-' | head -c 40)
                _handle_badge "$sender" "$badge_skill"

            elif [[ "$question" =~ ^#mem:([a-z0-9_-]*)([[:space:]]|$) ]]; then
                ## #mem:<skill> → lecture mémoire skill partagée
                _handle_mem_skill "$sender" "${BASH_REMATCH[1]}"

            elif echo "$question" | grep -qi '#mem'; then
                _handle_mem "$sender" "$slot"

            elif [[ "$question" =~ ^#rec:([a-z0-9_-]+)[[:space:]]+(.*) ]]; then
                ## #rec:<skill> <texte> → contribution mémoire partagée skill
                _handle_rec_skill "$sender" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"

            elif echo "$question" | grep -qi '#rec'; then
                ## Extraire le texte à mémoriser (sans #rec, sans tous les #N, sans #bro...)
                local mem_text bro_question=""
                mem_text=$(echo "$question" | sed 's/#rec\b[[:space:]]*//' | xargs)
                ## Supprimer tous les tags de slot détectés
                for _s in "${_slots[@]}"; do
                    mem_text=$(echo "$mem_text" | sed "s/#${_s}\b[[:space:]]*//" | xargs)
                done
                if echo "$mem_text" | grep -qi '#bro'; then
                    bro_question=$(echo "$mem_text" | grep -oi '#bro[[:space:]].*' | sed 's/#bro[[:space:]]//I' | xargs)
                    mem_text=$(echo "$mem_text" | sed 's/#bro.*//Ii' | xargs)
                fi
                [[ -n "$mem_text" ]] && _handle_rec "$sender" "$mem_text" "$slot"
                [[ -n "$bro_question" ]] && _handle_bro "$sender" "$bro_question" "$slot_str"

            elif [[ -n "$_ctx_skill" ]]; then
                ## Question avec contexte skill [ctx:<skill>] → réponse pédagogique
                _handle_bro_skill "$sender" "$question" "$_ctx_skill"

            else
                _handle_bro "$sender" "$question" "$slot_str"
            fi
            ;;
        udrive)
            _handle_udrive "$payload"
            ;;
        vocals)
            _handle_vocals "$payload"
            ;;
        webcam)
            _handle_webcam "$payload"
            ;;
        zen_like)
            _handle_zen_like "$payload"
            ;;
        bro_ia)
            _handle_bro_ia "$payload"
            ;;
        comfyui_job)
            _handle_comfyui_job "$payload" "$sender"
            ;;
        comfyui_result)
            _handle_comfyui_result "$payload"
            ;;
        *)
            _log "Canal inconnu '$channel' de ${sender:0:12}... — ignoré"
            ;;
    esac
}

## ── Traiter les fichiers déjà présents dans la queue (parallèle) ─────
for _f in "$QUEUE_DIR"/*.json; do
    [[ -f "$_f" ]] && _process_event_async "$_f" &
done

## ── Présentation du NODE aux MULTIPASS locaux (une seule fois chacun) ─
_send_welcome_messages

## Attendre la fin des traitements initiaux avant la boucle inotifywait
wait

## ── Dispatch atomique (utilisé par polling ET par inotifywait-retry) ────
_dispatch_file() {
    local _src="$1"
    [[ -f "$_src" ]] || return
    # Move atomique : si deux appelants concurrents tentent le mv, un seul gagne
    local _dst="${_src%.json}.dispatching"
    mv "$_src" "$_dst" 2>/dev/null || return  # l'autre process a déjà pris le fichier
    _process_event_async "$_dst" &
}

## Sweep périodique (30s) — rattrape les events perdus si le kernel inotify queue déborde
_sweep_loop() {
    while [[ "$_BRO_CLEAN_STOP" != true ]]; do
        sleep 30
        for _f in "$QUEUE_DIR"/*.json; do _dispatch_file "$_f"; done
    done
}
_sweep_loop &
_SWEEP_PID=$!

## ── Subscriber constellation relay ──────────────────────────────────
## Quand myRELAY=ws://127.0.0.1:7777 (non joignable depuis l'extérieur),
## les navigateurs en roaming envoient les DMs kind 4 via le relay de la
## constellation (_CONSTELLATION_RELAY). Ce subscriber les intercepte et
## les enfile dans la queue locale pour traitement identique aux DMs locaux.
##
## nostr_node_intercom.py receive effectue un REQ kind:4 #p:NODE_HEX
## avec un timeout de 30s, puis reboucle — chaque DM reçu est écrit dans
## la queue en tant que fichier JSON brut, déclenché par inotifywait.
_NODE_HEX=$(sed 's/.*HEX=\([^;]*\).*/\1/' ~/.zen/game/secret.nostr 2>/dev/null)

_constellation_subscriber_loop() {
    [[ -z "$_NODE_HEX" ]] && _log "WARN: HEX NODE absent — subscriber constellation désactivé" && return
    local _relay="$_CONSTELLATION_RELAY"

    ## Ne pas démarrer si le relay local EST le relay constellation (éviter double traitement)
    if [[ "${myRELAY:-}" == "$_relay" ]]; then
        _log "ℹ️  myRELAY == constellation relay — subscriber constellation non démarré (filter/4.sh suffit)"
        return
    fi

    _log "🌐 Subscriber constellation démarré → $_relay (NODE ${_NODE_HEX:0:12}…)"
    while [[ "$_BRO_CLEAN_STOP" != true ]]; do
        ## nostr_node_intercom.py receive — timeout 30s, lit UN DM puis exit
        ## On boucle pour maintenir un abonnement permanent
        local _raw_event
        _raw_event=$(NOSTR_NSEC="$NODE_NSEC" python3 "$INTERCOM" receive \
            --pubkey   "$_NODE_HEX" \
            --relay    "$_relay" \
            --timeout  30 \
            2>/dev/null)
        if [[ -n "$_raw_event" ]]; then
            local _dst
            _dst="$QUEUE_DIR/constellation_$(date +%s%N).json"
            printf '%s\n' "$_raw_event" > "$_dst"
            _log "🌐 DM constellation reçu → queue: $(basename "$_dst")"
        fi
        ## Pause courte si le relay a renvoyé EOSE ou timeout (évite busy-loop)
        [[ -z "$_raw_event" ]] && sleep 2
    done
    _log "🌐 Subscriber constellation arrêté"
}
_constellation_subscriber_loop &
_CONSTELLATION_SUB_PID=$!

## ── Boucle inotifywait avec fallback polling ─────────────────────────
_inotify_ok=false
command -v inotifywait &>/dev/null && _inotify_ok=true

while [[ "$_BRO_CLEAN_STOP" != true ]]; do
    if $_inotify_ok; then
        inotifywait -m -e close_write -e moved_to --format '%f' "$QUEUE_DIR" 2>/dev/null | \
        while IFS= read -r _fname; do
            [[ "$_BRO_CLEAN_STOP" == true ]] && break
            [[ "$_fname" == *.json ]] || continue
            _dispatch_file "$QUEUE_DIR/$_fname"
        done
        # inotifywait a terminé (dépassement inotify, remontage FS, SIGPIPE…)
        [[ "$_BRO_CLEAN_STOP" == true ]] && break
        _log "⚠️  inotifywait terminé — retry dans 5s"
        # Traiter les fichiers arrivés pendant la coupure
        for _f in "$QUEUE_DIR"/*.json; do _dispatch_file "$_f"; done
        sleep 5
    else
        # Fallback polling : move atomique garantit un seul traitement par fichier
        for _f in "$QUEUE_DIR"/*.json; do _dispatch_file "$_f"; done
        sleep 10
    fi
done
wait
