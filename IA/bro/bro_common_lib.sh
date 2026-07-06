#!/bin/bash
########################################################################
# bro_common_lib.sh — Bibliothèque commune BRO / inter-NODE
#
# Factorisation des fonctions dupliquées entre :
#   - IA/bro_dm_daemon.sh     (daemon DM NIP-44, kind 4)
#   - IA/UPlanet_IA_Responder.sh  (kind 1 #BRO/#BOT)
#   - ajouter_media.sh        (interface desktop media)
#
# Protocole BRO — résumé :
#   Copie YouTube depuis SoundSpot / n'importe quel client NOSTR :
#     kind 1  content: "#BRO #youtube <URL>"
#     relay : wss://relay.copylaradio.com
#     → strfry → UPlanet_IA_Responder.sh → process_youtube.sh
#
#   Requête BRO via DM (NIP-44, kind 4) :
#     channel "plain"     → question IA (RAG Qdrant + Ollama)
#     channel "udrive"    → sync fichier dans APP/uDRIVE
#     channel "vocals"    → publication kind 1222/1244 vocal
#     channel "webcam"    → publication webcam
#     channel "zen_like"  → paiement G1 cooperatif
#     channel "bro_ia"    → relay BRO depuis station visiteur (roaming)
#     channel "comfyui_job"    → délégation génération vidéo au Brain
#     channel "comfyui_result" → résultat Brain → home station
#
# Usage dans un script fils :
#   source "$(dirname "$(realpath "$0")")/bro_common_lib.sh"
#
# Variables attendues avant source (optionnelles) :
#   BRO_LOG_FILE   chemin du fichier log (défaut: ~/.zen/tmp/IA.log)
#   BRO_SCRIPT_ID  identifiant court du script appelant (défaut: "bro")
########################################################################

_BRO_LIB_MY_PATH="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
_BRO_ASTRO_TOOLS="${HOME}/.zen/Astroport.ONE/tools"

BRO_LOG_FILE="${BRO_LOG_FILE:-$HOME/.zen/tmp/IA.log}"
BRO_SCRIPT_ID="${BRO_SCRIPT_ID:-bro}"

# ── Chemins outils ──────────────────────────────────────────────────
BRO_NOSTR2HEX="${_BRO_ASTRO_TOOLS}/nostr2hex.py"
BRO_SECURE_DM="${_BRO_ASTRO_TOOLS}/nostr_send_secure_dm.py"
BRO_INTERCOM="${_BRO_ASTRO_TOOLS}/nostr_node_intercom.py"
BRO_MAILJET="${_BRO_ASTRO_TOOLS}/mailjet.sh"
BRO_USER_LEVEL="${_BRO_LIB_MY_PATH}/../bro_user_level.py"
_BRO_ALERT_LOCK="$HOME/.zen/flashmem/bro_alert.lock"

# ── Relay public constellation UPlanet ──────────────────────────────
# myRELAY peut valoir ws://127.0.0.1:7777 (non-routable depuis l'extérieur).
# Utiliser bro_build_relay_list() ou bro_find_home_relay() pour des relays routablees.
BRO_PUBLIC_RELAY="wss://relay.copylaradio.com"
if [[ -n "${myRELAY:-}" && ! "${myRELAY}" =~ ^ws://127\. ]]; then
    BRO_PUBLIC_RELAY="${myRELAY}"
fi

########################################################################
# bro_log MESSAGE
#   Journalise vers BRO_LOG_FILE (et stderr pour le daemon).
########################################################################
bro_log() {
    echo "[$(date '+%H:%M:%S')] [${BRO_SCRIPT_ID}] $*" | tee -a "$BRO_LOG_FILE" >&2
}

########################################################################
# bro_log_event ACTION SUCCESS [CATEGORY] [LATENCY_MS] [EXTRA_JSON]
#   Journalise un évènement STRUCTURÉ (JSONL) niveau STATION/NODE, EN PLUS
#   du texte libre écrit par bro_log()/log_debug() dans IA.log — additif,
#   ne remplace ni ne modifie l'écriture existante. Miroir bash du schéma
#   déjà utilisé côté BRO/utilisateur par IA/observability.py::log_event
#   (timestamp/action/success/latency_ms), pour permettre au niveau NODE un
#   filtrage par champ structuré au lieu des greps fragiles sur du texte
#   libre (ex: "youtube|yt-dlp" ou "tmdb|film|serie" dans log_file_watch.sh).
#
#   ACTION       libellé court de l'évènement (ex: "dispatch", "sync", "backup")
#   SUCCESS      0/1/true/false — tout le reste vaut false
#   CATEGORY     optionnel — remplace le mot-clé grep par un champ dédié
#                (ex: "youtube", "tmdb", "plain", "udrive", "backup")
#   LATENCY_MS   optionnel — durée en millisecondes, omis du JSON si absent
#   EXTRA_JSON   optionnel — objet JSON fusionné dans l'évènement
#                (ex: '{"player":"alice@example.com"}')
#
#   Fichier : ~/.zen/tmp/${IPFSNODEID:-_local}/observability/node-activity.jsonl
#   Ring buffer : BRO_ACTIVITY_RING_LIMIT lignes (défaut 200, même limite que
#   IA/observability.py::ACTIVITY_RING_LIMIT côté BRO/utilisateur).
#
#   Échoue TOUJOURS silencieusement — l'observabilité ne doit jamais
#   perturber ni ralentir l'appelant (même philosophie que bro_alert_captain).
########################################################################
BRO_ACTIVITY_RING_LIMIT="${BRO_ACTIVITY_RING_LIMIT:-200}"

bro_log_event() {
    local _action="$1" _success="$2" _category="${3:-}" _latency_ms="${4:-}" _extra="${5:-}"
    local _node="${IPFSNODEID:-_local}"
    local _dir="$HOME/.zen/tmp/${_node}/observability"
    local _path="${_dir}/node-activity.jsonl"

    mkdir -p "$_dir" 2>/dev/null || return 0

    local _ok="false"
    case "$_success" in
        1|true|TRUE|True) _ok="true" ;;
    esac

    python3 - "$_path" "${BRO_SCRIPT_ID:-bro}" "$_action" "$_ok" "$_category" "$_latency_ms" "$_extra" "$BRO_ACTIVITY_RING_LIMIT" <<'PYEOF' 2>/dev/null
import sys, json, time

path, script, action, ok, category, latency_ms, extra, limit = sys.argv[1:9]

event = {
    "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "script": script,
    "action": action,
    "success": ok == "true",
}
if category:
    event["category"] = category
if latency_ms:
    try:
        event["latency_ms"] = round(float(latency_ms), 1)
    except ValueError:
        pass
if extra:
    try:
        d = json.loads(extra)
        if isinstance(d, dict):
            event.update(d)
    except Exception:
        pass

try:
    with open(path, "a", encoding="utf-8") as f:
        f.write(json.dumps(event, ensure_ascii=False) + "\n")

    limit_n = int(limit)
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    if len(lines) > limit_n:
        with open(path, "w", encoding="utf-8") as f:
            f.writelines(lines[-limit_n:])
except Exception:
    pass
PYEOF
    return 0
}

########################################################################
# bro_alert_captain MESSAGE
#   Envoie un email HTML au capitaine via mailjet.sh.
#   Rate-limitée à 1 alerte par 24h (verrou $HOME/.zen/flashmem/bro_alert.lock).
########################################################################
bro_alert_captain() {
    local msg="$1"
    [[ -z "${CAPTAINEMAIL:-}" ]] && return
    [[ ! -x "$BRO_MAILJET" ]] && return

    if [[ -f "$_BRO_ALERT_LOCK" ]]; then
        local _age=$(( $(date +%s) - $(stat -c %Y "$_BRO_ALERT_LOCK") ))
        [[ $_age -lt 86400 ]] && return
    fi

    local _tmp _msg_html
    _tmp=$(mktemp /tmp/bro_alert_XXXXXX.html)
    _msg_html=$(printf '%s' "$msg" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
    cat > "$_tmp" <<EOF
<h2>🚨 BRO — erreur station $(hostname)</h2>
<p><strong>Date :</strong> $(date '+%Y-%m-%d %H:%M:%S')</p>
<p><strong>Station :</strong> ${myDOMAIN:-$(hostname)}</p>
<p><strong>Script :</strong> ${BRO_SCRIPT_ID}</p>
<p><strong>Détail :</strong></p>
<pre style="background:#fff3cd;padding:1em;border-radius:4px;white-space:pre-wrap;">${_msg_html}</pre>
<p>Log : <code>${BRO_LOG_FILE}</code></p>
<hr><p style="color:#888;font-size:0.85em;">Alerte rate-limitée 24h.</p>
EOF
    mkdir -p "$HOME/.zen/flashmem"
    touch "$_BRO_ALERT_LOCK"
    (
        bash "$BRO_MAILJET" --template "bro_alert" --expire 48h \
            "$CAPTAINEMAIL" "$_tmp" "🚨 BRO erreur — $(hostname)" 2>/dev/null
        rm -f "$_tmp"
    ) &
    bro_log "📧 Alerte Mailjet envoyée à $CAPTAINEMAIL"
}

########################################################################
# bro_bech32_to_hex BECH32
#   Convertit npub1.../nsec1... en hex 64 chars via nostr2hex.py.
#   Retourne chaîne vide si invalide.
########################################################################
bro_bech32_to_hex() {
    local _b32="$1"
    if [[ -x "$BRO_NOSTR2HEX" ]]; then
        python3 "$BRO_NOSTR2HEX" "$_b32" 2>/dev/null
        return
    fi
    # Fallback bech32 pur Python (utilisé si nostr2hex.py absent)
    python3 - "$_b32" <<'PYEOF'
import sys
CHARSET = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l'
_GEN = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
def _polymod(values):
    chk = 1
    for v in values:
        b = (chk >> 25) & 0x1f
        chk = ((chk & 0x1ffffff) << 5) ^ v
        for i in range(5):
            chk ^= _GEN[i] if ((b >> i) & 1) else 0
    return chk
def _hrp_expand(hrp):
    return [ord(x) >> 5 for x in hrp] + [0] + [ord(x) & 31 for x in hrp]
def bech32_to_hex(s):
    s = s.lower()
    pos = s.rfind('1')
    if pos < 1: return ''
    hrp = s[:pos]
    data = []
    for c in s[pos+1:]:
        if c not in CHARSET: return ''
        data.append(CHARSET.index(c))
    if len(data) < 6: return ''
    if _polymod(_hrp_expand(hrp) + data) != 1: return ''
    data = data[:-6]
    acc, bits, result = 0, 0, []
    for v in data:
        acc = ((acc << 5) | v) & 0x3fffffff
        bits += 5
        while bits >= 8:
            bits -= 8
            result.append((acc >> bits) & 0xff)
    if bits >= 5 or (acc & ((1 << bits) - 1)): return ''
    return bytes(result).hex()
try:
    result = bech32_to_hex(sys.argv[1])
    print(result if len(result) == 64 else '', end='')
except Exception:
    print('', end='')
PYEOF
}

########################################################################
# bro_load_node_keys
#   Charge les clés du NODE courant depuis ~/.zen/game/secret.nostr.
#   Exporte : BRO_NODE_NSEC BRO_NODE_NPUB BRO_NODE_HEX
#   Retourne 1 si le fichier est absent ou vide.
########################################################################
bro_load_node_keys() {
    local _secret="$HOME/.zen/game/secret.nostr"
    if [[ ! -s "$_secret" ]]; then
        bro_log "ERREUR: ~/.zen/game/secret.nostr absent"
        return 1
    fi
    local _tmp_nsec _tmp_npub _tmp_hex
    _tmp_nsec=$(grep -m1 '^NSEC=' "$_secret" | cut -d= -f2- | tr -d "[:space:]'\"")
    _tmp_npub=$(grep -m1 '^NPUB=' "$_secret" | cut -d= -f2- | tr -d "[:space:]'\"")
    _tmp_hex=$(grep  -m1 '^HEX='  "$_secret" | cut -d= -f2- | tr -d "[:space:]'\"")
    if [[ -z "$_tmp_nsec" ]]; then
        bro_log "ERREUR: NODE_NSEC absent dans secret.nostr"
        return 1
    fi
    BRO_NODE_NSEC="$_tmp_nsec"
    BRO_NODE_NPUB="$_tmp_npub"
    BRO_NODE_HEX="$_tmp_hex"
    export BRO_NODE_NSEC BRO_NODE_NPUB BRO_NODE_HEX
}

########################################################################
# bro_load_user_keys EMAIL
#   Charge les clés NOSTR d'un joueur depuis son répertoire.
#   Exporte : BRO_USER_NSEC BRO_USER_NPUB BRO_USER_HEX
#   Retourne 1 si .secret.nostr absent.
########################################################################
bro_load_user_keys() {
    local _email="$1"
    local _secret="$HOME/.zen/game/nostr/${_email}/.secret.nostr"
    if [[ ! -f "$_secret" ]]; then
        bro_log "WARN: .secret.nostr absent pour $_email"
        return 1
    fi
    local _tmp_nsec _tmp_npub _tmp_hex
    _tmp_nsec=$(grep -m1 '^NSEC=' "$_secret" | cut -d= -f2- | tr -d "[:space:]'\"")
    _tmp_npub=$(grep -m1 '^NPUB=' "$_secret" | cut -d= -f2- | tr -d "[:space:]'\"")
    _tmp_hex=$(grep  -m1 '^HEX='  "$_secret" | cut -d= -f2- | tr -d "[:space:]'\"")
    if [[ -z "$_tmp_nsec" ]]; then
        bro_log "WARN: USER_NSEC absent dans .secret.nostr pour $_email"
        return 1
    fi
    BRO_USER_NSEC="$_tmp_nsec"
    BRO_USER_NPUB="$_tmp_npub"
    BRO_USER_HEX="$_tmp_hex"
    export BRO_USER_NSEC BRO_USER_NPUB BRO_USER_HEX
}

########################################################################
# bro_resolve_email HEX_PUBKEY
#   Cherche l'email associé au hex dans ~/.zen/game/nostr/*/HEX.
#   Retourne chaîne vide si inconnu sur cette station.
#   Préfère un répertoire nommé comme un email réel (contient "@") : des
#   alias non-canoniques comme CAPTAIN/ peuvent porter le même HEX sans
#   avoir de .secret.nostr correspondant (copie partielle) — matcher un tel
#   alias en premier romprait le déchiffrement pour tout appelant qui lit
#   ensuite EMAIL/.secret.nostr.
########################################################################
bro_resolve_email() {
    local _hex="$1"
    local _hex_file
    _hex_file=$(grep -rl "^${_hex}$" "$HOME/.zen/game/nostr/"*"@"*"/HEX" 2>/dev/null | head -1)
    [[ -z "$_hex_file" ]] && \
        _hex_file=$(grep -rl "^${_hex}$" "$HOME/.zen/game/nostr/"*"/HEX" 2>/dev/null | head -1)
    [[ -n "$_hex_file" ]] && basename "$(dirname "$_hex_file")" || echo ""
}

########################################################################
# bro_resolve_hex EMAIL
#   Lit le hex pubkey depuis ~/.zen/game/nostr/$email/HEX.
########################################################################
bro_resolve_hex() {
    local _email="$1"
    cat "$HOME/.zen/game/nostr/${_email}/HEX" 2>/dev/null | tr -d '[:space:]'
}

########################################################################
# bro_udrive_path EMAIL [SUBDIR]
#   Retourne le chemin vers APP/uDRIVE[/SUBDIR] du joueur.
#   Crée le répertoire si absent. Retourne 1 si email inconnu.
########################################################################
bro_udrive_path() {
    local _email="$1" _sub="${2:-}"
    local _base="$HOME/.zen/game/nostr"
    local _user_dir=""

    # Recherche exacte d'abord, puis sous-chaîne
    if [[ -d "$_base/$_email" ]]; then
        _user_dir="$_base/$_email"
    else
        _user_dir=$(find "$_base" -maxdepth 1 -type d -name "*${_email}*" 2>/dev/null | head -1)
    fi

    if [[ -z "$_user_dir" || ! -d "$_user_dir" ]]; then
        bro_log "WARN: bro_udrive_path: répertoire inconnu pour $_email"
        return 1
    fi

    local _path="${_user_dir}/APP/uDRIVE${_sub:+/$_sub}"
    mkdir -p "$_path"
    echo "$_path"
}

########################################################################
# bro_is_roaming EMAIL
#   Retourne 0 si le joueur est marqué .roaming sur cette station, 1 sinon.
########################################################################
bro_is_roaming() {
    local _email="$1"
    [[ -f "$HOME/.zen/game/nostr/${_email}/.roaming" ]]
}

########################################################################
# bro_user_is_local EMAIL
#   Retourne 0 si le joueur est hébergé ici ET non-roaming, 1 sinon.
########################################################################
bro_user_is_local() {
    local _email="$1"
    [[ -z "$_email" ]] && return 1
    [[ ! -d "$HOME/.zen/game/nostr/$_email" ]] && return 1
    [[ -f "$HOME/.zen/game/nostr/$_email/.roaming" ]] && return 1
    return 0
}

########################################################################
# bro_user_language EMAIL
#   Retourne le code langue depuis ~/.zen/game/nostr/$email/LANG.
#   Défaut : "fr"
########################################################################
bro_user_language() {
    local _email="$1"
    local _f="$HOME/.zen/game/nostr/${_email}/LANG"
    if [[ -f "$_f" ]]; then
        local _l
        _l=$(tr -d '\n' < "$_f" | head -c 10)
        [[ -n "$_l" ]] && echo "$_l" && return 0
    fi
    echo "fr"
}

########################################################################
# bro_check_slot_access EMAIL [SLOT]
#   Retourne 0 si accès autorisé au slot (0=public, 1-12=sociétaires).
#   Accepte players/ (legacy) et game/nostr/ (make_NOSTRCARD).
########################################################################
bro_check_slot_access() {
    local _email="$1" _slot="${2:-0}"
    [[ "$_slot" == "0" ]] && return 0
    [[ -d "$HOME/.zen/game/players/$_email" ]] && return 0
    [[ -d "$HOME/.zen/game/nostr/$_email" ]] && return 0
    return 1
}

########################################################################
# bro_udrive_type_dir FILETYPE
#   Mappe un type MIME simplifié vers le sous-dossier uDRIVE.
#   image→Images  video→Videos  audio→Music  *→Documents
########################################################################
bro_udrive_type_dir() {
    case "${1:-}" in
        image)  echo "Images"    ;;
        video)  echo "Videos"    ;;
        audio)  echo "Music"     ;;
        *)      echo "Documents" ;;
    esac
}

########################################################################
# bro_send_dm FROM_NSEC TO_HEX MESSAGE [RELAY]
#   Envoie un DM NIP-44 chiffré via nostr_send_secure_dm.py.
#   RELAY défaut : BRO_PUBLIC_RELAY
########################################################################
bro_send_dm() {
    local _from_nsec="$1" _to_hex="$2" _msg="$3" _relay="${4:-$BRO_PUBLIC_RELAY}"
    if [[ ! -x "$BRO_SECURE_DM" ]]; then
        bro_log "WARN: bro_send_dm: nostr_send_secure_dm.py introuvable"
        return 1
    fi
    printf '%s\n' "$_from_nsec" | python3 "$BRO_SECURE_DM" --nsec-stdin "$_to_hex" "$_msg" "$_relay" 2>/dev/null
}

########################################################################
# bro_send_intercom TO_HEX CHANNEL PAYLOAD [TTL] [RELAY]
#   Envoie un DM inter-node NIP-44 via nostr_node_intercom.py.
#   Requiert que bro_load_node_keys() ait été appelé (BRO_NODE_NSEC).
#   TTL défaut : 3600s
########################################################################
bro_send_intercom() {
    local _to_hex="$1" _channel="$2" _payload="$3"
    local _ttl="${4:-3600}" _relay="${5:-$BRO_PUBLIC_RELAY}"
    if [[ ! -x "$BRO_INTERCOM" ]]; then
        bro_log "WARN: bro_send_intercom: nostr_node_intercom.py introuvable"
        return 1
    fi
    if [[ -z "${BRO_NODE_NSEC:-}" ]]; then
        bro_log "WARN: bro_send_intercom: BRO_NODE_NSEC non chargé — appeler bro_load_node_keys()"
        return 1
    fi
    printf '%s\n' "$BRO_NODE_NSEC" | python3 "$BRO_INTERCOM" send \
        --nsec-stdin \
        --to      "$_to_hex" \
        --channel "$_channel" \
        --payload "$_payload" \
        --ttl     "$_ttl" \
        --relays  "$_relay" \
        2>/dev/null
}

########################################################################
# bro_payload_get JSON_STRING FIELD [FIELD2 ...]
#   Parse un payload JSON et exporte _FIELD (majuscules) pour chaque champ.
#   Exemple : bro_payload_get "$payload" email cid → $_EMAIL $_CID
########################################################################
bro_payload_get() {
    local _p="$1"; shift
    local _varname _varval
    while IFS= read -r -d '' _varname && IFS= read -r -d '' _varval; do
        [[ "$_varname" =~ ^_[A-Z_]+$ ]] || continue
        declare -g "$_varname=$_varval"
    done < <(printf '%s' "$_p" | python3 - "$@" <<'PYEOF'
import json, sys
try:
    d = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
for field in sys.argv[1:]:
    val = d.get(field, "")
    sys.stdout.buffer.write(f"_{field.upper()}".encode() + b'\x00' + str(val).encode() + b'\x00')
PYEOF
    )
}

########################################################################
# bro_relay_bro_ia_to_home EMAIL PUBKEY EVENT_ID LAT LON MESSAGE URL KNAME
#   Relaie une commande BRO (kind 1 roaming) vers la home station du joueur.
#   Cherche le NODE HEX de la home station dans 12345.json du swarm.
#   Retourne 0 si le DM intercom a été envoyé, 1 si home station introuvable.
########################################################################
bro_relay_bro_ia_to_home() {
    local _email="$1" _pubkey="$2" _event_id="$3" _lat="$4" _lon="$5"
    local _message="$6" _url="${7:-}" _kname="${8:-}"

    # Chercher la home station dans le swarm
    local _home_hex=""
    for _j in "$HOME/.zen/tmp/swarm/"*/12345.json; do
        [[ ! -f "$_j" ]] && continue
        local _is_home _h
        _is_home=$(python3 -c "
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    players = d.get('players', {})
    if sys.argv[2] in players and not players[sys.argv[2]].get('roaming', True):
        print('yes')
except Exception: pass
" "$_j" "$_email" 2>/dev/null)
        if [[ "$_is_home" == "yes" ]]; then
            _home_hex=$(python3 -c "
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(d.get('NODEHEX', ''))
except Exception: pass
" "$_j" 2>/dev/null)
            break
        fi
    done

    if [[ -z "$_home_hex" || ${#_home_hex} -ne 64 ]]; then
        bro_log "WARN: bro_relay_bro_ia_to_home: home station HEX introuvable pour $_email"
        return 1
    fi

    bro_load_node_keys || return 1

    local _payload
    _payload=$(python3 -c "
import json, sys
print(json.dumps({
    'email':    sys.argv[1],
    'pubkey':   sys.argv[2],
    'event_id': sys.argv[3],
    'lat':      sys.argv[4],
    'lon':      sys.argv[5],
    'message':  sys.argv[6],
    'url':      sys.argv[7],
    'kname':    sys.argv[8],
}))
" "$_email" "$_pubkey" "$_event_id" "$_lat" "$_lon" "$_message" "$_url" "$_kname" 2>/dev/null)

    bro_log "✈️ bro_relay_bro_ia_to_home: relay BRO vers ${_home_hex:0:12}... pour $_email"
    bro_send_intercom "$_home_hex" "bro_ia" "$_payload" 3600 "$BRO_PUBLIC_RELAY"
}

########################################################################
# bro_build_relay_list
#   Construit une liste de relays NOSTR routablees depuis le swarm.
#   - Scanne ~/.zen/tmp/swarm/*/12345.json (champ myRELAY)
#   - Exclut les URLs localhost (ws://127.*)
#   - Pour les peers localhost avec x_strfry.sh : active le tunnel P2P
#     et ajoute ws://127.0.0.1:9999 (un seul tunnel à la fois)
#   - Inclut toujours wss://relay.copylaradio.com en fallback
#   Stdout: liste de relay URLs, une par ligne, dédupliquée
########################################################################
bro_build_relay_list() {
    local _swarm="$HOME/.zen/tmp/swarm"
    local -a _relays=("wss://relay.copylaradio.com")
    local _p2p_activated=0

    # Inclure myRELAY local s'il est routable
    if [[ -n "${myRELAY:-}" && ! "${myRELAY}" =~ ^ws://127\. ]]; then
        _relays+=("${myRELAY}")
    fi

    if [[ ! -d "$_swarm" ]]; then
        printf '%s\n' "${_relays[@]}" | sort -u
        return 0
    fi

    local _j _relay _nodeid
    for _j in "$_swarm"/*/12345.json; do
        [[ ! -f "$_j" ]] && continue
        _relay=$(python3 -c "
import json,sys
try: print(json.load(open(sys.argv[1])).get('myRELAY',''))
except: pass
" "$_j" 2>/dev/null)
        [[ -z "$_relay" ]] && continue

        if [[ "$_relay" =~ ^ws://127\. ]]; then
            # Peer localhost — tenter tunnel P2P (un seul à la fois sur port 9999)
            if [[ "$_p2p_activated" -eq 0 ]]; then
                _nodeid=$(basename "$(dirname "$_j")")
                local _xscript="$_swarm/$_nodeid/x_strfry.sh"
                if [[ -x "$_xscript" ]]; then
                    bash "$_xscript" >/dev/null 2>&1
                    _relays+=("ws://127.0.0.1:9999")
                    _p2p_activated=1
                fi
            fi
        else
            _relays+=("$_relay")
        fi
    done

    printf '%s\n' "${_relays[@]}" | sort -u
}

########################################################################
# bro_find_home_relay EMAIL
#   Retourne le relay de la home station d'un MULTIPASS.
#   Cherche dans le swarm le nœud où EMAIL est joueur non-roaming.
#   - Relay routable     → retourne l'URL wss:// directement
#   - Relay localhost    → active x_strfry.sh (port 9999) via DRAGON P2P
#                          et retourne ws://127.0.0.1:9999
#   - Home introuvable   → retourne BRO_PUBLIC_RELAY (fallback public)
########################################################################
bro_find_home_relay() {
    local _email="$1"

    if [[ -z "$_email" ]]; then
        echo "${BRO_PUBLIC_RELAY:-wss://relay.copylaradio.com}"
        return 0
    fi

    local _swarm="$HOME/.zen/tmp/swarm"
    local _j _relay _nodeid

    for _j in "$_swarm"/*/12345.json; do
        [[ ! -f "$_j" ]] && continue
        _relay=$(python3 -c "
import json,sys
try:
    d = json.load(open(sys.argv[1]))
    p = d.get('players', {})
    if sys.argv[2] in p and not p[sys.argv[2]].get('roaming', True):
        print(d.get('myRELAY',''))
except: pass
" "$_j" "$_email" 2>/dev/null)
        [[ -z "$_relay" ]] && continue

        if [[ "$_relay" =~ ^ws://127\. ]]; then
            _nodeid=$(basename "$(dirname "$_j")")
            local _xscript="$_swarm/$_nodeid/x_strfry.sh"
            if [[ -x "$_xscript" ]]; then
                bro_log "🔌 bro_find_home_relay: tunnel P2P x_strfry.sh → port 9999 pour $_email"
                bash "$_xscript" >/dev/null 2>&1
                echo "ws://127.0.0.1:9999"
                return 0
            fi
            # x_strfry.sh absent → fallback public
            bro_log "WARN: bro_find_home_relay: x_strfry.sh absent pour $_nodeid"
        else
            echo "$_relay"
            return 0
        fi
    done

    # Home station introuvable dans le swarm → fallback public
    echo "${BRO_PUBLIC_RELAY:-wss://relay.copylaradio.com}"
}

########################################################################
# bro_user_level HEX_PUBKEY [RELAY_URL]
#   Détermine le niveau d'accès BRO d'un expéditeur.
#
#   Retourne le niveau comme entier sur stdout :
#     0 anonyme      — aucun MULTIPASS local
#     1 locataire    — MULTIPASS actif (active_rental)
#     2 atome        — locataire + atom4love Kind 30078 valide
#     3 satellite    — sociétaire satellite (sans IA)
#     4 constellation— sociétaire constellation (avec IA)
#     5 capitaine    — accès complet
#
#   Définit également BRO_LEVEL_JSON (JSON complet) et BRO_LEVEL_EMAIL.
#
#   Cache fichier 5 min pour le niveau global, 1h pour atom4love.
########################################################################
bro_user_level() {
    local _hex="$1"
    local _relay="${2:-${BRO_PUBLIC_RELAY:-wss://relay.copylaradio.com}}"

    if [[ -z "$_hex" ]]; then
        BRO_LEVEL_JSON='{"level":0,"email":"","contract_status":"anonymous","atom4love":false}'
        BRO_LEVEL_EMAIL=""
        echo 0
        return
    fi

    local _python="${HOME}/.astro/bin/python3"
    command -v "$_python" &>/dev/null || _python="python3"

    BRO_LEVEL_JSON=$("$_python" "$BRO_USER_LEVEL" "$_hex" "$_relay" 2>/dev/null)
    if [[ -z "$BRO_LEVEL_JSON" ]]; then
        BRO_LEVEL_JSON='{"level":0,"email":"","contract_status":"unknown","atom4love":false}'
    fi

    local _lvl
    _lvl=$(echo "$BRO_LEVEL_JSON" | jq -r '.level // 0' 2>/dev/null)
    [[ "$_lvl" =~ ^[0-5]$ ]] || _lvl=0

    BRO_LEVEL_EMAIL=$(echo "$BRO_LEVEL_JSON" | jq -r '.email // ""' 2>/dev/null)
    export BRO_LEVEL_JSON BRO_LEVEL_EMAIL
    echo "$_lvl"
}
