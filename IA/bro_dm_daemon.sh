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
# Lancé automatiquement par NOSTRCARD.refresh.sh si absent.
# Usage : bro_dm_daemon.sh [--stop]
########################################################################

MY_PATH="$(dirname "$(realpath "$0")")"
. "$MY_PATH/../tools/my.sh" 2>/dev/null || true

QUEUE_DIR="$HOME/.zen/tmp/bro_dm_queue"
PID_FILE="$HOME/.zen/tmp/bro_dm_daemon.pid"
LOG_FILE="$HOME/.zen/tmp/bro_dm_daemon.log"
INTERCOM="$MY_PATH/../tools/nostr_node_intercom.py"
SECURE_DM="$MY_PATH/../tools/nostr_send_secure_dm.py"
BRO_SYNC="$MY_PATH/nextcloud_bro_sync.sh"
MAILJET="$MY_PATH/../tools/mailjet.sh"

mkdir -p "$QUEUE_DIR"
mkdir -p "$HOME/.zen/flashmem"

## ── Sémaphore : limiter les jobs parallèles (évite la saturation Ollama/GPU) ─
_BRO_MAX_JOBS=3
_BRO_SLOTS_DIR="$HOME/.zen/tmp/bro_dm_slots"
mkdir -p "$_BRO_SLOTS_DIR"

_log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

## ── Alerte email capitaine (rate-limitée à 1/48h) ────────────────────
_ALERT_LOCK="$HOME/.zen/flashmem/bro_dm_alert.lock"
_alert_captain() {
    local msg="$1"
    [[ -z "${CAPTAINEMAIL:-}" ]] && return
    [[ ! -x "$MAILJET" ]] && return

    ## Rate-limit : 1 alerte max toutes les 48h
    if [[ -f "$_ALERT_LOCK" ]]; then
        local _age=$(( $(date +%s) - $(stat -c %Y "$_ALERT_LOCK") ))
        [[ $_age -lt 172800 ]] && return
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
<hr><p style="color:#888;font-size:0.85em;">Alerte valide 48h — une seule par fenêtre.</p>
EOF
    touch "$_ALERT_LOCK"
    bash "$MAILJET" --template "$0" --expire 48h \
        "$CAPTAINEMAIL" "$_tmp" "🚨 BRO Daemon erreur — $(hostname)" \
        2>/dev/null &
    rm -f "$_tmp"
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

## ── Vérifier inotifywait ─────────────────────────────────────────────
if ! command -v inotifywait &>/dev/null; then
    _log "ERREUR: inotifywait absent (apt install inotify-tools)"
    exit 1
fi

## ── Relais ───────────────────────────────────────────────────────────
_RELAYS=("wss://relay.copylaradio.com")
[[ -n "${myRELAY:-}" ]] && _RELAYS+=("$myRELAY")

## ── PID guard ────────────────────────────────────────────────────────
echo $$ > "$PID_FILE"
## Nettoyer les slots de l'instance précédente (PID mort)
rm -f "$_BRO_SLOTS_DIR"/slot*.pid 2>/dev/null
_BRO_CLEAN_STOP=false
trap '_BRO_CLEAN_STOP=true' INT TERM
trap 'wait; rm -f "$PID_FILE"; _log "Daemon DM arrêté"; [[ "$_BRO_CLEAN_STOP" == false ]] && _alert_captain "Le daemon bro_dm_daemon.sh sest arrêté de façon inattendue (PID $$)."' EXIT

_log "🚀 Daemon DM NODE démarré (PID $$, max ${_BRO_MAX_JOBS} jobs) — queue: $QUEUE_DIR"

## ── Canal "#badge" : génération d'image de badge skill via ComfyUI ────────
## Syntaxe DM : "#badge <skill>"  ex: "#badge docker"
## Appelle generate_image.sh avec un prompt adapté, retourne l'URL IPFS.
_handle_badge() {
    local sender="$1" skill="$2"
    [[ -z "$skill" ]] && {
        python3 "$SECURE_DM" "$NODE_NSEC" "$sender" \
            "⚠️ Usage : #badge <compétence>  ex: #badge docker" \
            "${_RELAYS[0]}" 2>/dev/null
        return
    }
    _log "🎨 #badge demande de ${sender:0:12}... pour skill: $skill"

    local GENERATE_IMG="$MY_PATH/generate_image.sh"
    if [[ ! -x "$GENERATE_IMG" ]]; then
        python3 "$SECURE_DM" "$NODE_NSEC" "$sender" \
            "⚠️ Le générateur d'images (ComfyUI) n'est pas disponible sur cette station." \
            "${_RELAYS[0]}" 2>/dev/null
        return
    fi

    # Informer l'utilisateur que la génération est en cours
    python3 "$SECURE_DM" "$NODE_NSEC" "$sender" \
        "🎨 Génération du badge '${skill}'… Cela peut prendre 30-60 secondes (ComfyUI)." \
        "${_RELAYS[0]}" 2>/dev/null

    local prompt="A pixel art badge icon for the '${skill}' skill, hexagonal shape, vibrant colors, dark background, technology emblem, professional logo, 8-bit style, clean design, WoTx2 skill badge"
    local ipfs_url
    ipfs_url=$(bash "$GENERATE_IMG" "$prompt" 2>/dev/null)

    if [[ -n "$ipfs_url" ]] && echo "$ipfs_url" | grep -q "ipfs"; then
        _log "🎨 #badge OK pour $skill : $ipfs_url"
        python3 "$SECURE_DM" "$NODE_NSEC" "$sender" \
            "✅ Badge '${skill}' généré !\n🖼️ ${ipfs_url}\n\nCopiez ce lien pour l'ajouter comme ressource dans l'onglet Formation de my_wotx2.html" \
            "${_RELAYS[0]}" 2>/dev/null
    else
        _log "WARN: #badge échec génération pour $skill"
        python3 "$SECURE_DM" "$NODE_NSEC" "$sender" \
            "❌ Échec de la génération pour '${skill}'. Vérifiez que ComfyUI est démarré (port 8188)." \
            "${_RELAYS[0]}" 2>/dev/null
    fi
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

    python3 "$SECURE_DM" \
        "$NODE_NSEC" "$sender" "$answer" \
        "${_RELAYS[0]}" 2>/dev/null \
        && _log "🧠 BRO réponse envoyée à ${sender:0:12}..." \
        || _log "WARN: BRO échec envoi DM à ${sender:0:12}..."
}

## ── Résoudre email depuis sender hex (retourne "" si non hébergé) ─────
_sender_email() {
    local _hex_file
    _hex_file=$(grep -rl "^${1}$" "$HOME/.zen/game/nostr/"*"/HEX" 2>/dev/null | head -1)
    [[ -n "$_hex_file" ]] && basename "$(dirname "$_hex_file")" || echo ""
}

## ── Vérifier accès slot (0 = tous, 1-12 = sociétaires) ──────────────
_check_slot_access() {
    local email="$1" slot="${2:-0}"
    [[ "$slot" == "0" ]] && return 0
    [[ -d "$HOME/.zen/game/players/$email" ]] && return 0
    return 1
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
        python3 "$SECURE_DM" "$NODE_NSEC" "$sender" \
            "❌ Votre compte n'est pas hébergé sur cette station — mémoire non sauvegardée." \
            "${_RELAYS[0]}" 2>/dev/null
        return
    fi

    ## Vérifier accès slot
    if ! _check_slot_access "$email" "$slot"; then
        _log "WARN: #rec slot $slot refusé pour ${sender:0:12}... ($email)"
        python3 "$SECURE_DM" "$NODE_NSEC" "$sender" \
            "⚠️ Accès refusé : le slot $slot est réservé aux sociétaires. Le slot 0 reste accessible." \
            "${_RELAYS[0]}" 2>/dev/null
        return
    fi
    _log "💾 #rec DM de ${sender:0:12}... ($email) slot $slot : ${content:0:60}"

    ## Construire l'event JSON minimal pour short_memory.py
    local event_json
    event_json=$(python3 -c "
import json, sys, time
print(json.dumps({'event': {
    'id': 'dm_rec_' + str(int(time.time())),
    'pubkey': sys.argv[1],
    'content': sys.argv[2],
    'created_at': int(time.time()),
    'kind': 4,
    'tags': [],
}}))
" "$sender" "$content" 2>/dev/null)

    if [[ -n "$event_json" ]]; then
        python3 "$MY_PATH/short_memory.py" "$event_json" "0" "0" "$slot" "$email" 2>/dev/null \
            && _log "💾 Mémorisé ($email, slot $slot)" \
            || _log "WARN: échec short_memory.py pour $email slot $slot"
    fi

    python3 "$SECURE_DM" "$NODE_NSEC" "$sender" \
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
        python3 "$SECURE_DM" "$NODE_NSEC" "$sender" \
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
    python3 "$SECURE_DM" "$NODE_NSEC" "$sender" "${reply:-Erreur lecture mémoire.}" \
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
        python3 "$SECURE_DM" "$NODE_NSEC" "$sender" \
            "❌ Votre compte n'est pas hébergé sur cette station." \
            "${_RELAYS[0]}" 2>/dev/null
        return
    fi

    if ! _check_slot_access "$email" "$slot"; then
        python3 "$SECURE_DM" "$NODE_NSEC" "$sender" \
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
    python3 "$SECURE_DM" "$NODE_NSEC" "$sender" "$reply" \
        "${_RELAYS[0]}" 2>/dev/null
}

## ── Helper : parser un payload JSON en plusieurs variables shell ─────
## Usage : _payload_get "$payload" field1 field2 … → variables _FIELD1 _FIELD2 …
_payload_get() {
    local _p="$1"; shift
    eval "$(echo "$_p" | python3 - "$@" <<'PYEOF'
import json, sys, shlex
d = json.load(sys.stdin)
for field in sys.argv[1:]:
    val = d.get(field, "")
    print(f"_{field.upper()}={shlex.quote(str(val))}")
PYEOF
    )"
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

    local _USER_DIR="${HOME}/.zen/game/nostr/${_EMAIL}"
    [[ ! -d "$_USER_DIR" ]] && \
        _log "WARN: ✈️ vocals: $_EMAIL non hébergé ici" && return
    [[ -f "${_USER_DIR}/.roaming" ]] && \
        _log "WARN: ✈️ vocals: $_EMAIL en roaming sur cette station" && return

    local _SECRET="${_USER_DIR}/.secret.nostr"
    [[ ! -f "$_SECRET" ]] && \
        _log "WARN: ✈️ vocals: .secret.nostr absent pour $_EMAIL" && return

    local _PUBLISH_SCRIPT="${MY_PATH}/../tools/publish_nostr_vocal.sh"
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

    local _USER_DIR="${HOME}/.zen/game/nostr/${_EMAIL}"
    [[ ! -d "$_USER_DIR" ]] && \
        _log "WARN: ✈️ webcam: $_EMAIL non hébergé ici" && return
    [[ -f "${_USER_DIR}/.roaming" ]] && \
        _log "WARN: ✈️ webcam: $_EMAIL en roaming sur cette station" && return

    local _SECRET="${_USER_DIR}/.secret.nostr"
    [[ ! -f "$_SECRET" ]] && \
        _log "WARN: ✈️ webcam: .secret.nostr absent pour $_EMAIL" && return

    local _PUBLISH_SCRIPT="${MY_PATH}/../tools/publish_nostr_video.sh"
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
    [[ -n "$_THUMBNAIL_IPFS"]] && _CMD+=(--thumbnail-cid "$_THUMBNAIL_IPFS")
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

## ── Canal "udrive" : sync fichier depuis IPFS → APP/uDRIVE ───────────
_handle_udrive() {
    local payload="$1"
    local _S_EMAIL _S_CID _S_FILE _S_TYPE

    _S_EMAIL=$(echo "$payload" | python3 -c "import json,sys; print(json.load(sys.stdin).get('email',''))" 2>/dev/null)
    _S_CID=$(  echo "$payload" | python3 -c "import json,sys; print(json.load(sys.stdin).get('cid',''))" 2>/dev/null)
    _S_FILE=$( echo "$payload" | python3 -c "import json,sys; print(json.load(sys.stdin).get('filename',''))" 2>/dev/null)
    _S_TYPE=$( echo "$payload" | python3 -c "import json,sys; print(json.load(sys.stdin).get('filetype','file'))" 2>/dev/null)

    [[ -z "$_S_EMAIL" || -z "$_S_CID" || -z "$_S_FILE" ]] && return

    [[ ! -d "${HOME}/.zen/game/nostr/${_S_EMAIL}" ]] && \
        _log "WARN: ✈️ sync ignoré: $_S_EMAIL non hébergé ici" && return
    [[ -f "${HOME}/.zen/game/nostr/${_S_EMAIL}/.roaming" ]] && \
        _log "WARN: ✈️ sync ignoré: $_S_EMAIL en roaming" && return

    case "$_S_TYPE" in
        image)  _DEST_DIR="Images" ;;
        video)  _DEST_DIR="Videos" ;;
        audio)  _DEST_DIR="Music"  ;;
        *)      _DEST_DIR="Documents" ;;
    esac

    local _UDRIVE="${HOME}/.zen/game/nostr/${_S_EMAIL}/APP/uDRIVE"
    mkdir -p "${_UDRIVE}/${_DEST_DIR}"

    local _TMP_FILE
    _TMP_FILE=$(mktemp -p "${HOME}/.zen/tmp" "udrive_XXXXXX")
    if timeout 30 ipfs get "/ipfs/${_S_CID}" -o "$_TMP_FILE" 2>/dev/null; then
        mv "$_TMP_FILE" "${_UDRIVE}/${_DEST_DIR}/${_S_FILE}"
        touch "${_UDRIVE}/"
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

🎨 #badge <skill>          → générer une image de badge skill (ComfyUI)
   ex: #badge docker      → badge IA pour la compétence docker

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

        python3 "$SECURE_DM" \
            "$NODE_NSEC" "$_hex" "$WELCOME_MSG" \
            "${_RELAYS[0]}" 2>/dev/null \
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
    decoded=$(cat "$event_file" | python3 "$INTERCOM" decrypt --nsec "$NODE_NSEC" 2>/dev/null)
    rm -f "$event_file"

    if [[ -z "$decoded" ]]; then
        _log "WARN: déchiffrement échoué pour $(basename "$event_file")"
        return
    fi

    local channel sender payload
    channel=$(echo "$decoded" | python3 -c "import json,sys; print(json.load(sys.stdin).get('channel','plain'))" 2>/dev/null)
    sender=$(  echo "$decoded" | python3 -c "import json,sys; print(json.load(sys.stdin).get('sender',''))" 2>/dev/null)
    payload=$( echo "$decoded" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin).get('payload',{})))" 2>/dev/null)

    [[ -z "$sender" ]] && return

    case "$channel" in
        plain)
            local question
            question=$(echo "$payload" | python3 -c "import json,sys; print(json.load(sys.stdin).get('text',''))" 2>/dev/null | tr '\n' ' ')

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

            ## Router selon la commande DM
            if echo "$question" | grep -qi '#reset'; then
                _handle_reset "$sender" "$slot"

            elif echo "$question" | grep -qi '#badge'; then
                ## #badge <skill> → génère un badge image via ComfyUI
                local badge_skill
                badge_skill=$(echo "$question" | sed 's/.*#badge[[:space:]]*//' | tr -cd 'a-z0-9_-' | head -c 40)
                _handle_badge "$sender" "$badge_skill"

            elif echo "$question" | grep -qi '#mem'; then
                _handle_mem "$sender" "$slot"

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

## ── Boucle inotifywait ───────────────────────────────────────────────
inotifywait -m -e close_write -e moved_to --format '%f' "$QUEUE_DIR" 2>/dev/null | \
while IFS= read -r _fname; do
    [[ "$_fname" == *.json ]] || continue
    _process_event_async "$QUEUE_DIR/$_fname" &
done
wait
