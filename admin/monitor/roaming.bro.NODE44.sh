#!/bin/bash
########################################################################
# roaming.bro.NODE44.sh — Moniteur temps réel DMs kind 4 BRO
#
# Écoute les DMs NIP-44 (kind 4) adressés à ce NODE sur un relay
# sélectionné parmi ceux découverts dans le swarm, puis déchiffre
# et affiche chaque message avec son canal et son aperçu de contenu.
#
# Canaux surveillés :
#   plain        → questions BRO (avec détection #rec/#mem/#badge/#craft/[ctx:])
#   udrive        → sync fichier IPFS → APP/uDRIVE
#   vocals        → publication kind 1222/1244 (vocal) via home station
#   webcam        → publication kind 21/22 (vidéo) via home station
#   zen_like      → paiement ZEN/G1 relayé depuis station visiteur
#   bro_ia        → commande BRO relayée depuis station visiteur (roaming)
#   comfyui_job   → job génération vidéo délégué à un Brain GPU
#   comfyui_result → résultat renvoyé par le Brain
#
# Usage :
#   roaming.bro.NODE44.sh [relay_url]
#   roaming.bro.NODE44.sh --poll 10              # poll toutes les 10s
#   roaming.bro.NODE44.sh --history 2            # 2h d'historique au démarrage
#   roaming.bro.NODE44.sh --channel plain        # filtrer sur un canal
#   roaming.bro.NODE44.sh --no-color             # sortie sans couleurs (pipe/logs)
#   roaming.bro.NODE44.sh --once                 # une passe, pas de boucle
#   roaming.bro.NODE44.sh --test                 # auto-test : envoie un DM à soi-même
########################################################################

. "${HOME}/.zen/Astroport.ONE/tools/my.sh" 2>/dev/null || true

INTERCOM="${HOME}/.zen/Astroport.ONE/tools/nostr_node_intercom.py"
LOG_FILE="${HOME}/.zen/tmp/roaming_bro_monitor.log"

## ── Paramètres par défaut ────────────────────────────────────────────
_RELAY_ARG=""
_POLL=5          # secondes entre chaque poll
_HISTORY=1       # heures d'historique au démarrage
_CHANNEL=""      # "" = tous les canaux
_COLOR=true
_ONCE=false
_TEST=false

## ── Parsing arguments ────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        wss://*|ws://*) _RELAY_ARG="$1" ;;
        --poll)      _POLL="${2:-5}";    shift ;;
        --history)   _HISTORY="${2:-1}"; shift ;;
        --channel)   _CHANNEL="${2:-}";  shift ;;
        --no-color)  _COLOR=false ;;
        --once)      _ONCE=true ;;
        --test)      _TEST=true ;;
        -h|--help)
            sed -n '3,20p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
    esac
    shift
done

## ── Couleurs ─────────────────────────────────────────────────────────
if $_COLOR && [[ -t 1 ]]; then
    R="\033[0;31m" G="\033[0;32m" Y="\033[1;33m" B="\033[0;34m"
    M="\033[0;35m" C="\033[0;36m" W="\033[1;37m" Z="\033[0m"
    DIM="\033[2m"  BOLD="\033[1m"
else
    R="" G="" Y="" B="" M="" C="" W="" Z="" DIM="" BOLD=""
fi

_log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
_err() { echo -e "${R}[ERROR]${Z} $*" >&2; }

## ── Charger NODE_NSEC ────────────────────────────────────────────────
if [[ ! -s "${HOME}/.zen/game/secret.nostr" ]]; then
    _err "${HOME}/.zen/game/secret.nostr absent — station non initialisée"
    exit 1
fi
source "${HOME}/.zen/game/secret.nostr"
NODE_NSEC="${NSEC:-}"
NODE_NPUB="${NPUB:-}"
NODE_HEX="${HEX:-}"
unset NSEC NPUB HEX

if [[ -z "$NODE_NSEC" || -z "$NODE_HEX" ]]; then
    _err "NODE_NSEC / HEX absents dans secret.nostr"
    exit 1
fi

## ── Découverte des relays depuis le swarm ────────────────────────────
_discover_relays() {
    local -A seen=()
    local -a relays=()

    _add() {
        local r="$1"
        [[ -z "$r" || "$r" == "null" || "$r" == "ws://127.0.0.1:7777" ]] && return
        [[ -n "${seen[$r]:-}" ]] && return
        seen["$r"]=1
        relays+=("$r")
    }

    # Relay constellation par défaut
    _add "wss://relay.copylaradio.com"

    # Relay du node courant
    [[ -n "${myRELAY:-}" ]] && _add "$myRELAY"

    # Relay de la libra (si défini)
    if [[ -n "${myLIBRA:-}" ]]; then
        local _lib_relay="wss://relay.${myLIBRA#*://ipfs.}"
        _add "$_lib_relay"
    fi

    # Scanner les 12345.json du swarm
    for _json in "${HOME}/.zen/tmp/swarm/"*"/12345.json"; do
        [[ ! -f "$_json" ]] && continue
        local _r
        # Champ myRELAY en priorité, sinon construire depuis domain
        _r=$(jq -r '.myRELAY // ""' "$_json" 2>/dev/null)
        _add "$_r"
        _r=$(jq -r 'if .domain then "wss://relay.\(.domain)" else "" end' "$_json" 2>/dev/null)
        _add "$_r"
    done

    printf '%s\n' "${relays[@]}"
}

## ── Sélection interactive du relay ──────────────────────────────────
_select_relay() {
    local -a _list
    mapfile -t _list < <(_discover_relays)

    if [[ ${#_list[@]} -eq 0 ]]; then
        _err "Aucun relay découvert. Passez un URL en argument."
        exit 1
    fi

    if [[ ${#_list[@]} -eq 1 ]]; then
        echo "${_list[0]}"
        return
    fi

    echo -e "\n${BOLD}${C}Relays disponibles (swarm + constellation) :${Z}" >&2
    local i=1
    for r in "${_list[@]}"; do
        printf "  ${BOLD}%2d${Z}  %s\n" "$i" "$r" >&2
        (( i++ ))
    done
    echo "" >&2
    printf "${Y}Choisissez un relay [1-%d] (défaut: 1) : ${Z}" "${#_list[@]}" >&2
    local choice
    read -r choice </dev/tty
    choice="${choice:-1}"
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#_list[@]} )); then
        choice=1
    fi
    echo "${_list[$((choice - 1))]}"
}

## ── Affichage d'un lot d'events JSON ─────────────────────────────────
## Les données JSON sont passées via la variable d'environnement
## BRO_DISPLAY_DATA afin d'éviter le conflit stdin (heredoc = script
## Python, pas données).
_display_events() {
    local json="$1"
    [[ -z "$json" || "$json" == "[]" ]] && return

    BRO_DISPLAY_DATA="$json" BRO_USE_COLOR="$_COLOR" python3 - <<'PYEOF'
import json, sys, datetime, os

use_color = os.environ.get('BRO_USE_COLOR', 'false') == 'True'
raw = os.environ.get('BRO_DISPLAY_DATA', '')

CHAN_COLOR = {
    "plain":          "\033[0;36m",
    "bro_ia":         "\033[1;33m",
    "udrive":         "\033[0;34m",
    "vocals":         "\033[0;35m",
    "webcam":         "\033[0;35m",
    "zen_like":       "\033[0;32m",
    "comfyui_job":    "\033[0;31m",
    "comfyui_result": "\033[1;31m",
}
ICONS = {
    "plain":          "🧠",
    "bro_ia":         "✈️ ",
    "udrive":         "📁",
    "vocals":         "🎤",
    "webcam":         "🎥",
    "zen_like":       "💰",
    "comfyui_job":    "🎨",
    "comfyui_result": "🎬",
}
RST  = "\033[0m"   if use_color else ""
DIM  = "\033[2m"   if use_color else ""
BOLD = "\033[1m"   if use_color else ""

def col(ch):
    return (CHAN_COLOR.get(ch, "\033[0m") if use_color else "")

def preview(ch, p):
    if ch == "plain":
        txt = p.get("text", "")
        if "#rec:" in txt:    tag = "📝 rec:skill"
        elif "#rec" in txt:   tag = "💾 #rec"
        elif "#mem:" in txt:  tag = "📖 mem:skill"
        elif "#mem" in txt:   tag = "📖 #mem"
        elif "#reset" in txt: tag = "🗑️  #reset"
        elif "#badge" in txt: tag = "🎨 #badge"
        elif "#craft" in txt: tag = "🔨 #craft"
        elif txt.startswith("[ctx:"): tag = "🎓 ctx"
        else:                 tag = "❓ question"
        return f"{tag} | {txt[:90]}"
    elif ch == "udrive":
        return (f"{p.get('email','?')[:22]} ← {p.get('filename','?')}"
                f"  CID:{p.get('cid','?')[:12]}…")
    elif ch == "vocals":
        return (f"{p.get('email','?')[:22]} | {p.get('filename','?')}"
                f"  kind={p.get('kind','1222')}")
    elif ch == "webcam":
        return (f"{p.get('email','?')[:22]} | {p.get('filename','?')}"
                f"  {p.get('mime_type','?')}")
    elif ch == "zen_like":
        return (f"{p.get('email','?')[:22]}"
                f" → {p.get('zen_amount','?')}Ẑ"
                f" → {p.get('g1pub_dest','?')[:14]}…"
                f" {'(CF)' if p.get('is_crowdfunding') else ''}")
    elif ch == "bro_ia":
        return (f"{p.get('pubkey','?')[:12]}… ({p.get('kname','?')})"
                f" | {p.get('message','?')[:80]}")
    elif ch == "comfyui_job":
        return (f"mode={p.get('mode','t2v')} job={str(p.get('job_id','?'))[:10]}"
                f" | {p.get('prompt','?')[:60]}")
    elif ch == "comfyui_result":
        return (f"job={str(p.get('job_id','?'))[:10]}"
                f" status={p.get('status','?')}"
                f" {p.get('result_url','?')[:50]}")
    return str(p)[:100]

if not raw or raw == "[]":
    sys.exit(0)
try:
    events = json.loads(raw)
except json.JSONDecodeError:
    sys.exit(0)
if not isinstance(events, list) or not events:
    sys.exit(0)

for ev in sorted(events, key=lambda e: e.get("created_at", 0)):
    ts  = ev.get("created_at", 0)
    dt  = datetime.datetime.fromtimestamp(ts).strftime("%H:%M:%S")
    ch  = ev.get("channel", "?")
    snd = ev.get("sender", "?")
    p   = ev.get("payload", {})
    ico = ICONS.get(ch, "❓")
    pv  = preview(ch, p)
    print(
        f"{DIM}[{dt}]{RST}"
        f" {ico} "
        f"{col(ch)}{BOLD}{ch:<14}{RST}"
        f" {DIM}{snd[:10]}…{RST}"
        f"  {pv}"
    )
PYEOF
}

## ── Mode test : menu interactif des commandes BRO existantes ─────────
## 3 étapes : choix du NODE destinataire, choix du MULTIPASS expéditeur,
## choix de la commande. Le DM NIP-44 est signé avec le NSEC du MULTIPASS
## et adressé au HEX du NODE choisi. Si le NODE destinataire n'est pas
## le NODE local, le monitor ne verra PAS la réponse (avertissement affiché).
_run_test() {
    local _relay="${_RELAY:-wss://relay.copylaradio.com}"

    ## ── Étape 1 : sélection du NODE destinataire ─────────────────────
    local -a _NODE_LABELS=()
    local -a _NODE_HEXES=()

    # NODE local — toujours en premier
    _NODE_LABELS+=("📍 Ce NODE (local)  ${NODE_HEX:0:14}…  ${NODE_NPUB:0:20}…")
    _NODE_HEXES+=("$NODE_HEX")

    # Noeuds du swarm (NODEHEX depuis 12345.json)
    for _json in "${HOME}/.zen/tmp/swarm/"*"/12345.json"; do
        [[ -f "$_json" ]] || continue
        local _nhex _info
        _nhex=$(jq -r '.NODEHEX // ""' "$_json" 2>/dev/null)
        [[ -z "$_nhex" || ${#_nhex} -ne 64 || "$_nhex" == "$NODE_HEX" ]] && continue
        _info=$(jq -r '"\(.captain.email // .hostname // "?")  relay:\(.myRELAY // "?")"' \
            "$_json" 2>/dev/null)
        _NODE_LABELS+=("🌐 ${_info}  ${_nhex:0:14}…")
        _NODE_HEXES+=("$_nhex")
    done

    echo -e "\n${BOLD}${C}┌─ NODE destinataire ────────────────────────────────────────────┐${Z}" >&2
    local i=1
    for _lbl in "${_NODE_LABELS[@]}"; do
        printf "  ${BOLD}%2d${Z}  %s\n" "$i" "$_lbl" >&2
        (( i++ ))
    done
    echo -e "${BOLD}${C}└────────────────────────────────────────────────────────────────┘${Z}" >&2
    printf "${Y}NODE destinataire [1-%d] (défaut: 1) : ${Z}" "${#_NODE_LABELS[@]}" >&2
    local _nc; read -r _nc </dev/tty
    _nc="${_nc:-1}"
    [[ ! "$_nc" =~ ^[0-9]+$ ]] || (( _nc < 1 || _nc > ${#_NODE_LABELS[@]} )) && _nc=1
    local _dest_hex="${_NODE_HEXES[$(( _nc - 1 ))]}"
    local _dest_label="${_NODE_LABELS[$(( _nc - 1 ))]}"
    if [[ "$_dest_hex" != "$NODE_HEX" ]]; then
        echo -e "  ${Y}⚠️  NODE distant sélectionné — le monitor local ne verra pas la réponse du daemon distant.${Z}" >&2
    fi

    ## ── Étape 2 : sélection du MULTIPASS expéditeur ──────────────────
    local -a _MP_LABELS=()
    local -a _MP_NSECS=()
    local -a _MP_HEXES=()
    local -a _MP_EMAILS=()

    # Ce NODE lui-même
    _MP_LABELS+=("🔑 Ce NODE lui-même  ${NODE_NPUB:0:20}…")
    _MP_NSECS+=("$NODE_NSEC")
    _MP_HEXES+=("$NODE_HEX")
    _MP_EMAILS+=("NODE")

    # MULTIPASS locaux (ont un .secret.nostr avec NSEC)
    for _hex_file in "${HOME}/.zen/game/nostr/"*"/HEX"; do
        [[ -f "$_hex_file" ]] || continue
        local _mp_dir _mp_email _mp_hex _mp_secret _mp_nsec _mp_npub
        _mp_dir=$(dirname "$_hex_file")
        _mp_email=$(basename "$_mp_dir")
        # Ignorer les dossiers techniques et les comptes en roaming
        [[ "$_mp_email" =~ ^(UNODE_|UMAP_|ZSWARM|CAPTAIN) ]] && continue
        [[ -f "$_mp_dir/.roaming" ]] && continue
        _mp_hex=$(tr -d '[:space:]' < "$_hex_file" 2>/dev/null)
        [[ -z "$_mp_hex" || ${#_mp_hex} -ne 64 ]] && continue
        _mp_secret="$_mp_dir/.secret.nostr"
        [[ ! -f "$_mp_secret" ]] && continue
        _mp_nsec=$(grep -o 'NSEC=[^;]*' "$_mp_secret" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')
        [[ -z "$_mp_nsec" || "${_mp_nsec:0:4}" != "nsec" ]] && continue
        _mp_npub=$(grep -o 'NPUB=[^;]*' "$_mp_secret" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')
        _MP_LABELS+=("👤 ${_mp_email}  ${_mp_hex:0:14}…  ${_mp_npub:0:20}…")
        _MP_NSECS+=("$_mp_nsec")
        _MP_HEXES+=("$_mp_hex")
        _MP_EMAILS+=("$_mp_email")
    done

    echo -e "\n${BOLD}${C}┌─ MULTIPASS expéditeur (FROM) ──────────────────────────────────┐${Z}" >&2
    i=1
    for _lbl in "${_MP_LABELS[@]}"; do
        printf "  ${BOLD}%2d${Z}  %s\n" "$i" "$_lbl" >&2
        (( i++ ))
    done
    echo -e "${BOLD}${C}└────────────────────────────────────────────────────────────────┘${Z}" >&2
    printf "${Y}MULTIPASS expéditeur [1-%d] (défaut: 1) : ${Z}" "${#_MP_LABELS[@]}" >&2
    local _mc; read -r _mc </dev/tty
    _mc="${_mc:-1}"
    [[ ! "$_mc" =~ ^[0-9]+$ ]] || (( _mc < 1 || _mc > ${#_MP_LABELS[@]} )) && _mc=1
    local _sender_nsec="${_MP_NSECS[$(( _mc - 1 ))]}"
    local _sender_hex="${_MP_HEXES[$(( _mc - 1 ))]}"
    local _sender_email="${_MP_EMAILS[$(( _mc - 1 ))]}"
    local _sender_label="${_MP_LABELS[$(( _mc - 1 ))]}"

    ## ── Étape 3 : sélection de la commande ───────────────────────────
    # Les payloads utilisent $_sender_hex / $_sender_email du MULTIPASS choisi.
    # Voir docs/reference/ROAMING_UDRIVE_SYNC.md pour les formats complets.
    local -a _LABELS=(
        "🧠  plain    — Question BRO libre"
        "💾  plain    — #rec texte (slot 0)"
        "💾  plain    — #rec #2 texte (slot 2)"
        "📝  plain    — #rec:devops (mémoire skill partagée)"
        "📖  plain    — #mem (toutes les mémoires)"
        "📖  plain    — #mem:devops (mémoire skill)"
        "🗑️   plain    — #reset (effacer toutes les mémoires)"
        "🎨  plain    — #badge docker"
        "🔨  plain    — #craft <url> (recette MineLife)"
        "🎓  plain    — [ctx:python:2] question pédagogique"
        "✈️   bro_ia   — commande BRO relayée depuis station visiteur"
        "📁  udrive   — sync fichier document → uDRIVE"
        "🎤  vocals   — publication audio kind 1222 (vocal)"
        "🎥  webcam   — publication vidéo kind 21 (webcam)"
        "💰  zen_like — paiement ZEN relayé (zen_amount=5)"
    )
    local -a _CHANNELS=(
        "plain" "plain" "plain" "plain" "plain"
        "plain" "plain" "plain" "plain" "plain"
        "bro_ia" "udrive" "vocals" "webcam" "zen_like"
    )
    # Payloads dynamiques : $_sender_hex, $_sender_email, $_dest_hex injectés
    local -a _PAYLOADS=(
        '{"text":"Quels services sont disponibles sur cette station Astroport ?"}'
        '{"text":"#rec Ceci est un texte de test mémorisé via le monitor BRO."}'
        '{"text":"#rec #2 Texte test slot 2 — réservé aux sociétaires."}'
        '{"text":"#rec:devops Je maîtrise nginx, TLS et Docker sur Debian."}'
        '{"text":"#mem"}'
        '{"text":"#mem:devops"}'
        '{"text":"#reset"}'
        '{"text":"#badge docker"}'
        '{"text":"#craft https://instructables.com/Arduino-TV-B-Gone/"}'
        '{"text":"[ctx:python:2] Comment utiliser les list comprehensions en Python ?"}'
        "{\"pubkey\":\"${_sender_hex}\",\"message\":\"Quels services IA sont disponibles ?\",\"kname\":\"test-monitor\",\"lat\":\"48.85\",\"lon\":\"2.35\",\"event_id\":\"\"}"
        "{\"email\":\"${_sender_email}\",\"cid\":\"QmTestCID123456789\",\"filename\":\"test_monitor.txt\",\"filetype\":\"document\"}"
        "{\"email\":\"${_sender_email}\",\"cid\":\"QmAudioTestCID111\",\"filename\":\"vocal_test.webm\",\"filetype\":\"audio\",\"mime_type\":\"audio/webm\",\"duration\":\"12\",\"title\":\"Test vocal monitor\",\"kind\":\"1222\"}"
        "{\"email\":\"${_sender_email}\",\"cid\":\"QmVideoTestCID222\",\"filename\":\"webcam_test.webm\",\"filetype\":\"video\",\"mime_type\":\"video/webm\",\"duration\":\"5\",\"title\":\"Test webcam monitor\",\"dimensions\":\"640x480\",\"file_size\":\"102400\"}"
        "{\"email\":\"${_sender_email}\",\"sender_pubkey\":\"${_sender_hex}\",\"event_id\":\"test000\",\"reacted_event_id\":\"react000\",\"reacted_author_pubkey\":\"${_dest_hex}\",\"zen_amount\":\"5\",\"comment\":\"TEST monitor\",\"g1pub_dest\":\"${CAPTAINZENCARDG1PUB:-${CAPTAING1PUB:-test_g1pub}}\",\"is_crowdfunding\":\"False\",\"project_id\":\"\",\"bien_g1pub\":\"\"}"
    )

    echo -e "\n${BOLD}${C}┌─ Commande à simuler ───────────────────────────────────────────┐${Z}" >&2
    i=1
    for _lbl in "${_LABELS[@]}"; do
        printf "  ${BOLD}%2d${Z}  %s\n" "$i" "$_lbl" >&2
        (( i++ ))
    done
    echo -e "${BOLD}${C}└────────────────────────────────────────────────────────────────┘${Z}" >&2
    printf "${Y}Commande [1-%d] (défaut: 1) : ${Z}" "${#_LABELS[@]}" >&2
    local _choice; read -r _choice </dev/tty
    _choice="${_choice:-1}"
    [[ ! "$_choice" =~ ^[0-9]+$ ]] || (( _choice < 1 || _choice > ${#_LABELS[@]} )) && _choice=1
    local _idx=$(( _choice - 1 ))
    local _chan="${_CHANNELS[$_idx]}"
    local _payload="${_PAYLOADS[$_idx]}"
    local _label="${_LABELS[$_idx]}"

    ## ── Récapitulatif + envoi ─────────────────────────────────────────
    echo -e "\n${BOLD}${Y}▶ Envoi du test${Z}"
    echo -e "  ${DIM}Commande : ${_label}${Z}"
    echo -e "  ${DIM}Canal    : ${_chan}${Z}"
    echo -e "  ${DIM}FROM     : ${_sender_label}${Z}"
    echo -e "  ${DIM}TO       : ${_dest_label}${Z}"
    echo -e "  ${DIM}Relay    : ${_relay}${Z}"
    echo -e "  ${DIM}Payload  : ${_payload:0:120}${Z}\n"

    local _result
    _result=$(printf '%s\n' "$_sender_nsec" | python3 "$INTERCOM" send \
        --nsec-stdin \
        --to      "$_dest_hex" \
        --channel "$_chan" \
        --payload "$_payload" \
        --relays  "$_relay" \
        2>&1)
    if echo "$_result" | grep -qi "Sent\|OK"; then
        if [[ "$_dest_hex" == "$NODE_HEX" ]]; then
            echo -e "  ${G}✓ Envoyé — attendez ${_POLL}s pour voir l'arrivée dans le monitor.${Z}\n"
        else
            echo -e "  ${G}✓ Envoyé vers le NODE distant — vérifiez son propre monitor.${Z}\n"
        fi
    else
        echo -e "  ${R}✗ Résultat : ${_result:-[vide]}${Z}\n"
    fi
}

## ── Sélection du relay ───────────────────────────────────────────────
if [[ -n "$_RELAY_ARG" ]]; then
    _RELAY="$_RELAY_ARG"
else
    _RELAY="$(_select_relay)"
fi

if [[ -z "$_RELAY" ]]; then
    _err "Aucun relay sélectionné."
    exit 1
fi

## ── Bandeau d'en-tête ────────────────────────────────────────────────
echo -e "\n${BOLD}${C}╔══════════════════════════════════════════════════════════════╗${Z}"
printf   "${BOLD}${C}║${Z}  ${W}🔭 BRO NODE44 Monitor${Z}                                         ${BOLD}${C}║${Z}\n"
printf   "${BOLD}${C}║${Z}  Relay  : ${G}%-51s${Z} ${BOLD}${C}║${Z}\n" "$_RELAY"
printf   "${BOLD}${C}║${Z}  NODE   : ${DIM}%-51s${Z} ${BOLD}${C}║${Z}\n" "${NODE_NPUB:-$NODE_HEX}"
printf   "${BOLD}${C}║${Z}  Poll   : ${Y}%ds${Z}   Historique : ${Y}%sh${Z}   Canal : ${Y}%s${Z}                  ${BOLD}${C}║${Z}\n" \
    "$_POLL" "$_HISTORY" "${_CHANNEL:-tous}"
printf   "${BOLD}${C}║${Z}  Log    : ${DIM}%-51s${Z} ${BOLD}${C}║${Z}\n" "$LOG_FILE"
echo -e  "${BOLD}${C}╚══════════════════════════════════════════════════════════════╝${Z}"
echo -e  "${DIM}  Ctrl+C pour quitter — chaque ligne = un DM déchiffré${Z}\n"

## ── Mode test (lance l'envoi PUIS continue le monitor) ───────────────
## --test : envoie un DM test avant de démarrer la boucle
## En cours de monitor, appuyez sur [t] + Entrée pour en envoyer un autre
$_TEST && _run_test

## ── Timestamp de départ (historique) ────────────────────────────────
_SINCE=$(( $(date +%s) - _HISTORY * 3600 ))
_SEEN_IDS=""   # liste d'IDs déjà affichés (pour éviter les doublons de poll)

## ── Fonction poll unique ─────────────────────────────────────────────
_poll_once() {
    local _args=(--nsec-stdin --relays "$_RELAY" --since "$_SINCE")
    [[ -n "$_CHANNEL" ]] && _args+=(--channel "$_CHANNEL")

    local _raw
    _raw=$(printf '%s\n' "$NODE_NSEC" | python3 "$INTERCOM" receive \
        "${_args[@]}" 2>/dev/null)

    [[ -z "$_raw" || "$_raw" == "[]" ]] && return

    # Filtrer les IDs déjà affichés (évite les doublons entre deux polls)
    # Données via env var : python3 -c lit le script depuis l'argument,
    # stdin reste libre — pas de conflit avec le heredoc.
    local _filtered
    _filtered=$(BRO_RAW="$_raw" BRO_SEEN="$_SEEN_IDS" python3 -c "
import json, os, sys
raw_in = os.environ.get('BRO_RAW', '')
seen_str = os.environ.get('BRO_SEEN', '')
if not raw_in or raw_in == '[]':
    sys.exit(0)
seen = set(seen_str.split(',')) if seen_str else set()
try:
    events = json.loads(raw_in)
except Exception:
    sys.exit(0)
fresh = [e for e in events if e.get('event_id', '') not in seen]
print(json.dumps(fresh))
" 2>/dev/null)

    [[ -z "$_filtered" || "$_filtered" == "[]" ]] && return

    # Afficher
    _display_events "$_filtered"

    # Mettre à jour _SINCE et _SEEN_IDS
    local _max_ts _new_ids
    _max_ts=$(python3 -c "
import json, sys
evs = json.loads(sys.stdin.read())
if evs: print(max(e.get('created_at',0) for e in evs))
" <<< "$_filtered" 2>/dev/null)
    _new_ids=$(python3 -c "
import json, sys
evs = json.loads(sys.stdin.read())
print(','.join(e.get('event_id','') for e in evs if e.get('event_id','')))
" <<< "$_filtered" 2>/dev/null)

    if [[ -n "$_max_ts" && "$_max_ts" -gt "$_SINCE" ]]; then
        _SINCE=$(( _max_ts + 1 ))
    fi
    if [[ -n "$_new_ids" ]]; then
        _SEEN_IDS="${_SEEN_IDS:+$_SEEN_IDS,}${_new_ids}"
        # Garder la liste à taille raisonnable (max 500 IDs)
        if [[ "${#_SEEN_IDS}" -gt 20000 ]]; then
            _SEEN_IDS=$(echo "$_SEEN_IDS" | tr ',' '\n' | tail -200 | tr '\n' ',' | sed 's/,$//')
        fi
    fi
}

## ── Gestion Ctrl+C ───────────────────────────────────────────────────
trap 'echo -e "\n${DIM}Monitor arrêté.${Z}"; exit 0' INT TERM

## ── Boucle principale ────────────────────────────────────────────────
if $_ONCE; then
    _poll_once
    exit 0
fi

echo -e "${DIM}  Astuce : tapez ${BOLD}t${Z}${DIM} + Entrée à tout moment pour envoyer un DM de test.${Z}\n"

_last_tick=""
while true; do
    _tick=$(date '+%H:%M:%S')
    if [[ "$_tick" != "$_last_tick" ]]; then
        # Indicateur de vie discret (toutes les minutes)
        if [[ "${_tick##*:}" == "00" ]]; then
            echo -e "${DIM}[${_tick}] — en écoute sur ${_RELAY} …${Z}"
        fi
        _last_tick="$_tick"
    fi
    _poll_once

    # Lecture non-bloquante stdin : "t" → envoyer un nouveau test
    if read -r -t "$_POLL" _input </dev/tty 2>/dev/null; then
        if [[ "${_input,,}" == "t" ]]; then
            _run_test
        fi
    fi
done
