#!/bin/bash
# love_handler.sh — Canal BRO "love" : assistance aux rencontres (Agence UPlanet)
# Sourcé par bro_dm_daemon.sh : source "$MY_PATH/love_handler.sh"
#
# 3 niveaux d'accès :
#   Tier 1 (tous)     : Quota 3 prompts/jour · Mémoire locale · Suggestions IA
#   Tier 2 (+18)      : + Matching local (score KIN + Phi²) · Posts publics NOSTR
#   Tier 3 (Parrain)  : + Matching constellation · Mise en relation facilitée
#
# MODÈLE DE CONFIDENTIALITÉ :
#   Données PRIVÉES (locales station, jamais publiées sur NOSTR) :
#     ~/.zen/flashmem/<email>/love/
#     ├── dialog.json      # 4 derniers échanges (contexte session uniquement)
#     ├── memories.json    # Préférences personnelles (max 50)
#     └── matches.json     # Historique des matchs vus
#   Données PUBLIQUES (lues depuis NOSTR strfry, sous contrôle de l'utilisateur) :
#     Kind 0  — nom, bio, nip05 (profil public NOSTR)
#     Kind 1  — messages publics récents
#     Kind 30078 d=love-profile — profil de rencontre (opt-in explicite)
#     Kind 30078 d=atom4love   — données Phi² ATOM4LOVE (opt-in)
#   Le fichier profile.json local sert de BROUILLON (non publié par défaut).
#
# Quota journalier : LOVE_DAILY_QUOTA (défaut 3) prompts de type "ask/suggest/kin/intro"
# Prompts IA modifiables sans redémarrer le daemon :
#   IA/bro/prompts/love/system_tier{1,2,3}.txt
#
# Debug :
#   tail -f ~/.zen/tmp/bro_dm_daemon.log | grep LOVE
#   LOVE_DEBUG=1 ./bro_dm_daemon.sh

_LOVE_PATH="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
_LOVE_PROMPT_DIR="$_LOVE_PATH/prompts/love"
_LOVE_MEM_BASE="$HOME/.zen/flashmem"
_LOVE_OLLAMA_URL="${OLLAMA_URL:-http://127.0.0.1:11434}"
_LOVE_MODEL="${LOVE_MODEL:-gemma3:latest}"
_LOVE_DAILY_QUOTA="${LOVE_DAILY_QUOTA:-3}"   # max prompts IA/jour par utilisateur
_LOVE_STRFRY="$HOME/.zen/strfry/strfry"      # binaire strfry pour lectures NOSTR

# Tables Dreamspell embarquées (pas de dépendance kin_oracle.sh au runtime)
_LOVE_KIN_SEALS=("Dragon" "Wind" "Night" "Seed" "Serpent" "WorldBridger" "Hand" "Star"
    "Moon" "Dog" "Monkey" "Human" "SkyWalker" "Wizard" "Eagle" "Warrior"
    "Earth" "Mirror" "Storm" "Sun")
_LOVE_KIN_TONES=("Magnétique" "Lunaire" "Électrique" "Auto-existante" "Harmonique"
    "Rythmique" "Résonnante" "Galactique" "Solaire" "Planétaire" "Spectrale"
    "Cristal" "Cosmique")
_LOVE_KIN_COLORS=("Rouge" "Blanc" "Bleu" "Jaune" "Vert")

## ── Répertoire mémoire love pour un email ────────────────────────────────────
_love_dir() { echo "$_LOVE_MEM_BASE/${1}/love"; }

## ── Quota journalier ─────────────────────────────────────────────────────────
## Retourne les asks restants pour aujourd'hui (0 = quota épuisé)
_love_remaining_asks() {
    local email="$1"
    local dir; dir="$(_love_dir "$email")"
    local today; today=$(date +%Y-%m-%d)
    local qfile="$dir/quota_${today}"
    [[ ! -f "$qfile" ]] && echo "$_LOVE_DAILY_QUOTA" && return
    local count; count=$(wc -l < "$qfile" 2>/dev/null || echo 0)
    local r=$(( _LOVE_DAILY_QUOTA - count ))
    echo $(( r < 0 ? 0 : r ))
}

## Consomme un prompt (retourne 0=OK, 1=quota épuisé)
_love_consume_ask() {
    local email="$1"
    local dir; dir="$(_love_dir "$email")"
    mkdir -p "$dir"
    local today; today=$(date +%Y-%m-%d)
    local qfile="$dir/quota_${today}"
    local count=0
    [[ -f "$qfile" ]] && count=$(wc -l < "$qfile" 2>/dev/null || echo 0)
    [[ $count -ge $_LOVE_DAILY_QUOTA ]] && return 1
    date -u +%H:%M:%SZ >> "$qfile"
    return 0
}

## ── Lire le profil public NOSTR (kind-0) pour un pubkey ─────────────────────
## Source : strfry local (données publiques signées par l'utilisateur)
_love_get_kind0() {
    local pubkey="$1"
    [[ -z "$pubkey" || ${#pubkey} -ne 64 ]] && echo "{}" && return
    [[ ! -x "$_LOVE_STRFRY" ]] && echo "{}" && return
    local content
    content=$(cd "$(dirname "$_LOVE_STRFRY")" && ./strfry scan \
        "{\"kinds\":[0],\"authors\":[\"${pubkey}\"]}" 2>/dev/null \
        | python3 -c "
import sys,json
evts=[json.loads(l) for l in sys.stdin if l.strip()]
if not evts: print('{}')
else:
    newest=max(evts,key=lambda e:e.get('created_at',0))
    print(newest.get('content','{}'))
" 2>/dev/null)
    echo "${content:-{}}"
}

## ── Lire le profil de rencontre public (kind-30078 d=love-profile) ───────────
## Publié volontairement par l'utilisateur pour le matching (opt-in)
_love_get_nostr_love_profile() {
    local pubkey="$1"
    [[ -z "$pubkey" || ${#pubkey} -ne 64 ]] && echo "{}" && return
    [[ ! -x "$_LOVE_STRFRY" ]] && echo "{}" && return
    local content
    content=$(cd "$(dirname "$_LOVE_STRFRY")" && ./strfry scan \
        "{\"kinds\":[30078],\"#d\":[\"love-profile\"],\"authors\":[\"${pubkey}\"]}" \
        2>/dev/null | head -1 | python3 -c "
import sys,json
line=sys.stdin.read().strip()
if not line: print('{}')
else:
    try: print(json.loads(line).get('content','{}'))
    except: print('{}')
" 2>/dev/null)
    echo "${content:-{}}"
}

## ── Publier le profil love sur NOSTR (kind-30078 d=love-profile) ─────────────
## Nécessite le .secret.nostr de l'email (nsec)
_love_publish_nostr_profile() {
    local email="$1" content="$2"
    local secret_file="$HOME/.zen/game/nostr/${email}/.secret.nostr"
    [[ ! -f "$secret_file" ]] && return 1
    local nsec; nsec=$(grep -m1 "^USER_NSEC=" "$secret_file" | cut -d= -f2- | tr -d '"' 2>/dev/null)
    [[ -z "$nsec" ]] && return 1
    local send_py="$_LOVE_PATH/../../../tools/nostr_send_note.py"
    [[ ! -f "$send_py" ]] && return 1
    python3 "$send_py" \
        --nsec "$nsec" \
        --kind 30078 \
        --content "$content" \
        --tag "d" "love-profile" \
        --tag "t" "love" \
        2>/dev/null
}

## ── Lire les derniers messages publics (kind-1) d'un pubkey ──────────────────
## Retourne les N derniers contenus, un par ligne
_love_get_recent_posts() {
    local pubkey="$1" limit="${2:-5}"
    [[ -z "$pubkey" || ${#pubkey} -ne 64 ]] && return
    [[ ! -x "$_LOVE_STRFRY" ]] && return
    cd "$(dirname "$_LOVE_STRFRY")" && ./strfry scan \
        "{\"kinds\":[1],\"authors\":[\"${pubkey}\"],\"limit\":${limit}}" \
        2>/dev/null \
        | python3 -c "
import sys,json
posts=[]
for line in sys.stdin:
    try:
        e=json.loads(line)
        c=e.get('content','').strip()
        if c and len(c) > 10: posts.append(c[:200])
    except: pass
posts.sort(key=len,reverse=True)
for p in posts[:${limit}]: print('•', p)
" 2>/dev/null
}

## ── Récupérer le pubkey NOSTR depuis l'email ─────────────────────────────────
_love_pubkey_for_email() {
    local email="$1"
    local mp="$HOME/.zen/game/nostr/${email}/.multipass.json"
    [[ ! -f "$mp" ]] && return
    python3 -c "import json; print(json.load(open('$mp')).get('hex',''))" 2>/dev/null
}

## ── URL de rencontre déterministe (Jitsi) ────────────────────────────────────
## Dérivée depuis les deux pubkeys, indépendante de l'ordre
_love_meeting_url() {
    local k1="$1" k2="$2"
    local room
    room=$(echo -n "$(echo -e "${k1}\n${k2}" | sort | tr -d '\n')" \
        | sha256sum | cut -c1-16)
    echo "https://meet.jit.si/uplanet-${room}"
}

## ── Lire les souvenirs (JSON array) ─────────────────────────────────────────
_love_get_mem() {
    local f; f="$(_love_dir "$1")/memories.json"
    [[ -f "$f" ]] && cat "$f" || echo "[]"
}

## ── Ajouter un souvenir (max 50) ─────────────────────────────────────────────
_love_add_mem() {
    local email="$1" content="$2"
    local dir; dir="$(_love_dir "$email")"
    mkdir -p "$dir"
    local f="$dir/memories.json"
    local ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local existing; existing=$([[ -f "$f" ]] && cat "$f" || echo "[]")
    python3 -c "
import json, sys
data = json.loads(sys.argv[1])
data.append({'timestamp': sys.argv[2], 'content': sys.argv[3]})
data = data[-50:]
print(json.dumps(data, ensure_ascii=False))
" "$existing" "$ts" "$content" > "$f" 2>/dev/null
}

## ── Effacer tous les souvenirs ────────────────────────────────────────────────
_love_clear_mem() {
    local dir; dir="$(_love_dir "$1")"
    mkdir -p "$dir"
    echo "[]" > "$dir/memories.json"
}

## ── Lire l'historique de dialogue ────────────────────────────────────────────
## Retourne les derniers échanges sous forme [{role, content}…]
_love_get_dialog() {
    local f; f="$(_love_dir "$1")/dialog.json"
    [[ -f "$f" ]] && cat "$f" || echo "[]"
}

## ── Ajouter un tour de dialogue (max 8 entrées = 4 échanges) ─────────────────
_love_add_dialog() {
    local email="$1" role="$2" content="$3"
    local dir; dir="$(_love_dir "$email")"
    mkdir -p "$dir"
    local f="$dir/dialog.json"
    local ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local existing; existing=$([[ -f "$f" ]] && cat "$f" || echo "[]")
    python3 -c "
import json, sys
data = json.loads(sys.argv[1])
data.append({'role': sys.argv[2], 'content': sys.argv[3][:800], 'ts': sys.argv[4]})
data = data[-8:]
print(json.dumps(data, ensure_ascii=False))
" "$existing" "$role" "$content" "$ts" > "$f" 2>/dev/null
}

## ── Effacer l'historique de dialogue ─────────────────────────────────────────
_love_clear_dialog() {
    local dir; dir="$(_love_dir "$1")"
    mkdir -p "$dir"
    echo "[]" > "$dir/dialog.json"
}

## ── Lire le profil ────────────────────────────────────────────────────────────
_love_get_profile() {
    local f; f="$(_love_dir "$1")/profile.json"
    [[ -f "$f" ]] && cat "$f" || echo "{}"
}

## ── Sauvegarder le profil (merge avec existant) ───────────────────────────────
_love_save_profile() {
    local email="$1" new_data="$2"
    local dir; dir="$(_love_dir "$email")"
    mkdir -p "$dir"
    local f="$dir/profile.json"
    local existing; existing=$([[ -f "$f" ]] && cat "$f" || echo "{}")
    python3 -c "
import json, sys
old = json.loads(sys.argv[1])
new = json.loads(sys.argv[2])
old.update(new)
print(json.dumps(old, ensure_ascii=False, indent=None))
" "$existing" "$new_data" > "$f" 2>/dev/null
}

## ── Calculer le KIN Dreamspell depuis la date de naissance ───────────────────
## Lit ~/.zen/game/nostr/<email>/.BIRTHDATE (format YYYY-MM-DD ou DD/MM/YYYY)
## Retourne une chaîne "KIN 42: Blanc Vent, Tonalité Résonnant (analogue: KIN 52)"
_love_get_kin() {
    local email="$1"
    local birth_file="$HOME/.zen/game/nostr/${email}/.BIRTHDATE"
    [[ ! -f "$birth_file" ]] && return 0   # pas de date de naissance connue

    local birth_raw; birth_raw=$(cat "$birth_file" 2>/dev/null | tr -d '[:space:]')
    [[ -z "$birth_raw" ]] && return 0

    python3 - "$birth_raw" <<'PYEOF' 2>/dev/null
import sys, re
from datetime import date

SEALS  = ["Dragon","Wind","Night","Seed","Serpent","WorldBridger","Hand","Star",
           "Moon","Dog","Monkey","Human","SkyWalker","Wizard","Eagle","Warrior",
           "Earth","Mirror","Storm","Sun"]
TONES  = ["Magnétique","Lunaire","Électrique","Auto-existante","Harmonique",
           "Rythmique","Résonnante","Galactique","Solaire","Planétaire","Spectrale",
           "Cristal","Cosmique"]
COLORS = ["Rouge","Blanc","Bleu","Jaune","Vert"]
SEAL_COLS = [i // 4 % 5 for i in range(20)]  # couleur du sceau

def date_to_kin(d):
    epoch = date(1987, 7, 26)
    return ((d - epoch).days % 260 + 260) % 260 + 1

def kin_info(k):
    seal  = (k - 1) % 20
    tone  = (k - 1) % 13
    color = (k - 1) // 13 % 5
    ana   = (seal + 10) % 20
    ana_k = ((ana * 221 + tone * 40) % 260) + 1
    return {
        'kin': k, 'seal': SEALS[seal], 'tone': TONES[tone],
        'color': COLORS[color], 'analog_kin': ana_k,
        'analog_seal': SEALS[ana], 'analog_color': COLORS[SEAL_COLS[ana]],
    }

raw = sys.argv[1]
# Accepter YYYY-MM-DD ou DD/MM/YYYY ou DD-MM-YYYY
try:
    if re.match(r'^\d{4}-\d{2}-\d{2}$', raw):
        d = date.fromisoformat(raw)
    elif re.match(r'^\d{2}[/-]\d{2}[/-]\d{4}$', raw):
        parts = re.split(r'[/-]', raw)
        d = date(int(parts[2]), int(parts[1]), int(parts[0]))
    else:
        sys.exit(0)
    info = kin_info(date_to_kin(d))
    print(f"KIN {info['kin']}: {info['color']} {info['seal']}, Tonalité {info['tone']}")
    print(f"Signe analogue: {info['analog_color']} {info['analog_seal']} (KIN {info['analog_kin']})")
except Exception:
    pass
PYEOF
}

## ── Score de compatibilité KIN entre deux numéros (0-100) ────────────────────
## Retourne "SCORE LABEL" ex: "75 KIN très compatibles (analogue)"
_love_kin_compat_score() {
    python3 - "$1" "$2" <<'PYEOF' 2>/dev/null
import sys, math

def parse_kin(s):
    try:
        k = int(s)
        return k if 1 <= k <= 260 else None
    except:
        return None

k1, k2 = parse_kin(sys.argv[1]), parse_kin(sys.argv[2])
if not k1 or not k2 or k1 == k2:
    print("0 inconnu")
    sys.exit(0)

s1, t1 = (k1-1)%20, (k1-1)%13
s2, t2 = (k2-1)%20, (k2-1)%13
c1, c2 = (k1-1)//13%5, (k2-1)//13%5

score = 0
label = []

# Analogue (sceau opposé +10) : affinité très forte
if abs(s1-s2) == 10:
    score += 40; label.append("analogues")

# Même tonalité : vibration harmonique
if t1 == t2:
    score += 30; label.append("même tonalité")

# Tonalités complémentaires (somme = 14)
elif t1 + t2 == 14:
    score += 20; label.append("tonalités complémentaires")

# Même famille de couleur (familles Red/White, Blue/Yellow, Green solo)
# Red(0)↔White(1), Blue(2)↔Yellow(3)
compat_colors = {0:1, 1:0, 2:3, 3:2}
if c1 == c2:
    score += 20; label.append("même couleur")
elif compat_colors.get(c1) == c2:
    score += 10; label.append("couleurs complémentaires")

# Antipode (tonalité + 7 mod 13)
if (t1 + 7) % 13 == t2 % 13:
    score += 10; label.append("antipode")

score = min(100, score)
desc = " & ".join(label) if label else "peu de résonance"
print(f"{score} {desc}")
PYEOF
}

## ── Récupérer les données ATOM4LOVE (Phi²) depuis strfry ────────────────────
## Retourne le contenu JSON du Kind 30078 d=atom4love validé, ou "{}"
## Champs utiles : personal_phase (φ), omega_bio (ω), biological_sex, kin_num, kin_conception
_love_get_a4l_data() {
    local email="$1"
    local multipass="$HOME/.zen/game/nostr/${email}/.multipass.json"
    [[ ! -f "$multipass" ]] && echo "{}" && return

    local pubkey
    pubkey=$(python3 -c "import json,sys; print(json.load(sys.stdin).get('hex',''))" \
        < "$multipass" 2>/dev/null)
    [[ -z "$pubkey" || ${#pubkey} -ne 64 ]] && echo "{}" && return

    local strfry_bin="$HOME/.zen/strfry/strfry"
    [[ ! -x "$strfry_bin" ]] && echo "{}" && return

    local evt
    evt=$(cd "$HOME/.zen/strfry" && ./strfry scan \
        "{\"kinds\":[30078],\"#d\":[\"atom4love\"],\"authors\":[\"${pubkey}\"]}" \
        2>/dev/null | head -1)
    [[ -z "$evt" ]] && echo "{}" && return

    local proof content
    proof=$(jq -r '.tags//[]|map(select(.[0]=="a4l_proof"))|first[1]//"" ' \
        <<< "$evt" 2>/dev/null)
    content=$(jq -r '.content // "{}"' <<< "$evt" 2>/dev/null)

    # Valider le a4l_proof (SHA256(pubkey:ATOM4LOVE_v1))
    if [[ -n "$proof" ]]; then
        local valid
        valid=$(python3 -c "
import hashlib,sys
expected=hashlib.sha256(('${pubkey}:ATOM4LOVE_v1').encode()).hexdigest()
print('ok' if expected==sys.argv[1] else 'fail')
" "$proof" 2>/dev/null)
        [[ "$valid" != "ok" ]] && echo "{}" && return
    fi

    echo "$content"
}

## ── Score de résonance Phi² entre deux phases (0-40 pts + label) ─────────────
## Formule ATOM4LOVE : k = 1/(1+|sin(Δφ)|)  →  [0.5, 1.0]
## Bonus omega_bio : cohérence ou complémentarité ω  →  +8 pts max (total plafonné à 50)
_love_phi2x_score() {
    python3 - "$1" "$2" "${3:-}" "${4:-}" <<'PYEOF' 2>/dev/null
import sys, math

def sf(s):
    try:    return float(s)
    except: return None

pa, pb  = sf(sys.argv[1]), sf(sys.argv[2])
oa, ob  = sf(sys.argv[3]) if len(sys.argv) > 3 else None, \
          sf(sys.argv[4]) if len(sys.argv) > 4 else None

if pa is None or pb is None:
    print("0 indisponible"); sys.exit(0)

# Résonance principale
k = 1.0 / (1.0 + abs(math.sin(pa - pb)))   # [0.5, 1.0]
score = round((k - 0.5) * 80)               # 0 – 40

# Bonus cohérence/complémentarité ω
bonus_omega, omega_lbl = 0, ""
if oa is not None and ob is not None:
    dw = abs(oa - ob)
    if dw < 0.05:                        # quasi-identiques → harmonique
        bonus_omega, omega_lbl = 8, "ω harmonique"
    elif abs(dw - 0.5) < 0.08:          # opposition → complémentaire Yin/Yang
        bonus_omega, omega_lbl = 6, "ω complémentaire"
    elif abs(dw - 0.25) < 0.06:         # quart → dynamique créatif
        bonus_omega, omega_lbl = 4, "ω créatif"

total   = min(50, score + bonus_omega)
pct     = round(k * 100)
label   = f"Φ²={pct}%"
if omega_lbl: label += f" {omega_lbl}"
print(f"{total} {label}")
PYEOF
}

## ── Lire les traces ATOM4LOVE (kind-10600 #t=trace #t=atom4love) ────────────
## Retourne un array JSON de URLs canoniques visitées (via extension navigateur)
_love_get_traces() {
    local pubkey="$1"
    [[ -z "$pubkey" ]] && echo "[]" && return
    [[ ! -x "$_LOVE_STRFRY" ]] && echo "[]" && return
    "$_LOVE_STRFRY" scan \
        --filter "{\"kinds\":[10600],\"#t\":[\"atom4love\"],\"authors\":[\"${pubkey}\"],\"limit\":500}" 2>/dev/null \
    | python3 -c "
import sys, json
urls = set()
for line in sys.stdin:
    try:
        ev = json.loads(line)
        for tag in ev.get('tags', []):
            if tag[0] == 'url' and len(tag) > 1 and tag[1]:
                urls.add(tag[1])
    except: pass
print(json.dumps(sorted(urls)))
"
}

## ── Score de traces communes (0-20 pts + liste) ─────────────────────────────
## 5 pts par URL commune, max 20 pts
_love_trace_score() {
    local my_json="$1" other_json="$2"
    python3 -c "
import json, sys
mine  = set(json.loads(sys.argv[1]))
other = set(json.loads(sys.argv[2]))
common = mine & other
score = min(20, len(common) * 5)
# Extraire une étiquette lisible depuis la partie finale de l'URL
def short(u):
    from urllib.parse import urlparse, parse_qs
    p = urlparse(u)
    if 'youtube.com' in p.netloc:
        v = parse_qs(p.query).get('v', [''])[0]
        return f'YT:{v[:8]}' if v else 'YouTube'
    if 'netflix.com' in p.netloc:
        parts = p.path.strip('/').split('/')
        return f'Netflix:{parts[-1][:12]}' if parts else 'Netflix'
    if 'spotify.com' in p.netloc:
        parts = p.path.strip('/').split('/')
        return f'Spotify:{parts[-1][:12]}' if len(parts)>1 else 'Spotify'
    return (p.path.split('/')[-1] or p.hostname or u)[:20]
labels = ', '.join(short(u) for u in sorted(common)[:3])
print(f'{score} {labels}' if labels else f'{score}')
" "$my_json" "$other_json" 2>/dev/null || echo "0"
}

## ── Vérifier si l'utilisateur est Tier 2 (+18) ───────────────────────────────
_love_is_tier2() {
    local profile; profile=$(_love_get_profile "$1")
    [[ "$(python3 -c "
import json,sys
try:
    p=json.loads(sys.argv[1])
    print('yes' if int(p.get('age',0)) >= 18 else 'no')
except: print('no')
" "$profile" 2>/dev/null)" == "yes" ]]
}

## ── Vérifier si l'utilisateur est Tier 3 (Parrain / Capitaine) ───────────────
_love_is_tier3() {
    local email="$1"
    local did_file="$HOME/.zen/game/nostr/${email}/did.json"
    [[ -f "$did_file" ]] || return 1
    [[ "$(python3 -c "
import json,sys
try:
    d=json.loads(open(sys.argv[1]).read())
    cs=d.get('contractStatus','')
    print('yes' if any(x in cs.lower() for x in ('parrain','captain','capitaine')) else 'no')
except: print('no')
" "$did_file" 2>/dev/null)" == "yes" ]]
}

## ── KIN numérique depuis le profil love ou la date de naissance ───────────────
_love_get_kin_number() {
    local email="$1"
    # 1. Profil love peut stocker le kin directement
    local profile; profile=$(_love_get_profile "$email")
    local kin_from_profile
    kin_from_profile=$(python3 -c "
import json,sys
try:
    p=json.loads(sys.argv[1])
    k=p.get('kin',0)
    print(int(k) if 1<=int(k)<=260 else 0)
except: print(0)
" "$profile" 2>/dev/null)
    [[ "${kin_from_profile:-0}" -gt 0 ]] && echo "$kin_from_profile" && return

    # 2. Calculer depuis .BIRTHDATE
    local birth_file="$HOME/.zen/game/nostr/${email}/.BIRTHDATE"
    [[ ! -f "$birth_file" ]] && echo "0" && return
    local raw; raw=$(cat "$birth_file" 2>/dev/null | tr -d '[:space:]')
    python3 - "$raw" <<'PYEOF' 2>/dev/null
import sys, re
from datetime import date
raw = sys.argv[1]
try:
    if re.match(r'^\d{4}-\d{2}-\d{2}$', raw):
        d = date.fromisoformat(raw)
    elif re.match(r'^\d{2}[/-]\d{2}[/-]\d{4}$', raw):
        p = re.split(r'[/-]', raw)
        d = date(int(p[2]), int(p[1]), int(p[0]))
    else:
        print(0); sys.exit(0)
    epoch = date(1987, 7, 26)
    print(((d - epoch).days % 260 + 260) % 260 + 1)
except:
    print(0)
PYEOF
}

## ── Choisir le bon prompt système selon le tier ──────────────────────────────
_love_system_prompt() {
    local email="$1"
    local tier=1
    _love_is_tier3 "$email" && tier=3 || _love_is_tier2 "$email" && tier=2
    local sys_file="$_LOVE_PROMPT_DIR/system_tier${tier}.txt"
    [[ -f "$sys_file" ]] && cat "$sys_file" \
        || echo "Tu es BRO en mode LOVE, assistant bienveillant pour les rencontres authentiques."
}

## ── Saison depuis la date courante ───────────────────────────────────────────
_love_current_season() {
    python3 -c "
from datetime import date
m = date.today().month
if m in (12, 1, 2):  print('Hiver')
elif m in (3, 4, 5): print('Printemps')
elif m in (6, 7, 8): print('Été')
else:                print('Automne')
" 2>/dev/null || echo ""
}

## ── Appel Ollama avec contexte love complet ──────────────────────────────────
## Usage : _love_query EMAIL QUESTION → stdout = réponse IA
_love_query() {
    local email="$1" question="$2"
    local system_prompt memories profile kin_info dialog context

    system_prompt=$(_love_system_prompt "$email")
    memories=$(_love_get_mem "$email")
    profile=$(_love_get_profile "$email")
    dialog=$(_love_get_dialog "$email")

    # KIN depuis .BIRTHDATE (calcul direct, pas de dépendance externe)
    kin_info=$(_love_get_kin "$email")

    # Construire le contexte structuré
    context=""

    # 1. Profil (sans private_notes ni public)
    [[ "$profile" != "{}" ]] && {
        local profile_text
        profile_text=$(python3 -c "
import json,sys
p=json.load(sys.stdin)
for k,v in p.items():
    if k not in ('private_notes','public','kin'): print(f'{k}: {v}')
" 2>/dev/null <<< "$profile")
        [[ -n "$profile_text" ]] && context+="=== Profil de l'utilisateur ===\n${profile_text}\n\n"
    }

    # 2. Signe KIN Dreamspell
    [[ -n "$kin_info" ]] && context+="=== Signe KIN Dreamspell ===\n${kin_info}\n\n"

    # 3. Souvenirs récents (5 derniers, triés par date)
    if [[ "$memories" != "[]" ]]; then
        local recent_mems
        recent_mems=$(python3 -c "
import json,sys
ms=json.load(sys.stdin)[-5:]
for m in ms: print(f'• {m[\"content\"][:200]}')
" 2>/dev/null <<< "$memories")
        [[ -n "$recent_mems" ]] && context+="=== Préférences mémorisées ===\n${recent_mems}\n\n"
    fi

    # 4. Historique de dialogue (4 derniers échanges)
    local dialog_context=""
    if [[ "$dialog" != "[]" ]]; then
        dialog_context=$(python3 -c "
import json,sys
turns=json.load(sys.stdin)
for t in turns:
    role='Toi' if t['role']=='user' else 'BRO'
    print(f'{role}: {t[\"content\"][:400]}')
" 2>/dev/null <<< "$dialog")
    fi

    [[ "${LOVE_DEBUG:-0}" == "1" ]] && \
        _log "💕 LOVE_DEBUG email=${email} tier=$(
            _love_is_tier3 "$email" && echo 3 || (_love_is_tier2 "$email" && echo 2 || echo 1)
        ) ctx=${context:0:100}… dialog_turns=$(echo "$dialog" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null)"

    # Sanitize triple-guillemets → évite la rupture du heredoc Python
    local _sys _ctx _dlg _que
    _sys="${system_prompt//\"\"\"/ }"
    _ctx="${context//\"\"\"/ }"
    _dlg="${dialog_context//\"\"\"/ }"
    _que="${question//\"\"\"/ }"

    python3 - <<PYEOF 2>/dev/null
import urllib.request, json

system = """${_sys}"""
context = """${_ctx}"""
dialog_ctx = """${_dlg}"""
question = """${_que}"""

# Assembler le prompt final
if dialog_ctx.strip():
    prompt = context + "=== Conversation précédente ===\n" + dialog_ctx + "\n\n=== Nouvelle question ===\n" + question
else:
    prompt = context + question

try:
    data = json.dumps({
        "model": "${_LOVE_MODEL}",
        "system": system,
        "prompt": prompt,
        "stream": False,
        "options": {
            "num_predict": 500,
            "temperature": 0.85,
            "top_p": 0.92,
            "repeat_penalty": 1.1
        }
    }).encode()
    req = urllib.request.Request(
        "${_LOVE_OLLAMA_URL}/api/generate",
        data=data, method="POST",
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=90) as r:
        resp = json.loads(r.read())
        print(resp.get("response", "").strip())
except Exception:
    print("")
PYEOF
}

## ── Handler : statut du compte LOVE ─────────────────────────────────────────
## Affiche quota restant, profil, prochaine étape suggérée
_handle_love_status() {
    local sender="$1"
    local email; email=$(bro_resolve_email "$sender")
    [[ -z "$email" ]] && \
        _send_dm "$sender" "💕 Compte non trouvé sur cette station." "${_RELAYS[0]}" && return

    local remaining; remaining=$(_love_remaining_asks "$email")
    local profile; profile=$(_love_get_profile "$email")
    local mem_count; mem_count=$(python3 -c "
import json,sys
ms=json.load(sys.stdin)
print(len(ms))
" 2>/dev/null <<< "$(_love_get_mem "$email")")

    local has_profile=false has_kin=false has_phi2x=false is_public=false
    python3 -c "import json,sys; p=json.load(sys.stdin); print('yes' if p.get('bio') else 'no')" \
        <<< "$profile" 2>/dev/null | grep -q yes && has_profile=true
    [[ $(_love_get_kin_number "$email") -gt 0 ]] && has_kin=true
    python3 -c "import json,sys; p=json.load(sys.stdin); print('yes' if p.get('public') else 'no')" \
        <<< "$profile" 2>/dev/null | grep -q yes && is_public=true

    # Vérifier si A4L actif + compter les traces Kind 10600
    local a4l; a4l=$(_love_get_a4l_data "$email")
    [[ "$a4l" != "{}" ]] && has_phi2x=true

    local trace_count=0
    if $has_phi2x; then
        local _my_hex; _my_hex=$(_love_pubkey_for_email "$email")
        if [[ -n "$_my_hex" ]]; then
            local _my_tr; _my_tr=$(_love_get_traces "$_my_hex")
            trace_count=$(python3 -c "import json,sys; print(len(json.loads(sys.argv[1])))" \
                "$_my_tr" 2>/dev/null || echo 0)
        fi
    fi

    local phi2x_line='💡 Phi² inactif (inscris-toi sur ATOM4LOVE)'
    if $has_phi2x; then
        phi2x_line='✅ Phi² ATOM4LOVE actif'
        [[ $trace_count -gt 0 ]] && phi2x_line+=" · 🌐 ${trace_count} pages tracées"
    fi

    local tier=1
    _love_is_tier3 "$email" && tier=3 || _love_is_tier2 "$email" && tier=2

    local status_msg="💕 **Statut LOVE — Agence UPlanet**

🕐 Prompts IA disponibles aujourd'hui : ${remaining}/${_LOVE_DAILY_QUOTA}
📊 Souvenirs mémorisés : ${mem_count:-0}
🎯 Niveau d'accès : Tier ${tier}

**Profil de rencontre :**
$(${has_profile} && echo '✅ Bio renseignée' || echo '❌ Bio manquante')
$(${has_kin}     && echo "✅ KIN Dreamspell : $(_love_get_kin "$email" | head -1)" || echo '❌ Date de naissance non renseignée (pour KIN)')
${phi2x_line}
$(${is_public}   && echo '✅ Profil visible pour le matching' || echo '🔒 Profil privé (envoie {"public":true} pour être visible)')"

    # Prochaine étape suggérée
    local next_step=""
    if ! $has_profile; then
        next_step="\n📋 **Prochaine étape** : Crée ton profil\n{\"age\":28,\"bio\":\"Décris-toi en quelques mots\",\"interests\":[\"musique\",\"nature\"]}"
    elif ! $has_phi2x; then
        next_step="\n⚛️ **Prochaine étape** : Rejoins ATOM4LOVE pour activer la résonance Phi²"
    elif ! $is_public && [[ $tier -ge 2 ]]; then
        next_step="\n🔍 **Prochaine étape** : Rends ton profil visible pour le matching\n{\"public\":true}"
    fi
    [[ -n "$next_step" ]] && status_msg+="$next_step"

    _send_dm "$sender" "$status_msg" "${_RELAYS[0]}"
}

## ── Handler : question libre ─────────────────────────────────────────────────
_handle_love_ask() {
    local sender="$1" question="$2"
    local email; email=$(bro_resolve_email "$sender")
    _log "💕 LOVE ask ${sender:0:12}: ${question:0:80}"

    if [[ -z "$email" ]]; then
        _send_dm "$sender" "💕 Compte non trouvé sur cette station." "${_RELAYS[0]}"
        return
    fi

    # Vérifier le quota journalier
    if ! _love_consume_ask "$email"; then
        local tomorrow; tomorrow=$(date -d "+1 day" +%d/%m 2>/dev/null || date +%d/%m)
        _send_dm "$sender" \
            "💕 Tu as utilisé tes ${_LOVE_DAILY_QUOTA} prompts LOVE pour aujourd'hui.\n\nL'Agence UPlanet limite les échanges pour encourager la réflexion et la qualité des rencontres.\n\nReviens demain (${tomorrow}) ou utilise les actions sans IA : Souvenirs, Profil, Status." \
            "${_RELAYS[0]}"
        return
    fi

    # Sauvegarder la question dans l'historique avant d'appeler Ollama
    _love_add_dialog "$email" "user" "$question"

    local answer; answer=$(_love_query "$email" "$question")
    if [[ -z "$answer" ]]; then
        answer="💕 Le service IA est temporairement indisponible. Réessaie dans quelques minutes."
    else
        _love_add_dialog "$email" "bro" "$answer"
    fi

    local remaining; remaining=$(_love_remaining_asks "$email")
    [[ $remaining -le 1 ]] && answer+=" _(${remaining} prompt restant aujourd'hui)_"

    _send_dm "$sender" "$answer" "${_RELAYS[0]}"
}

## ── Handler : lister les souvenirs ───────────────────────────────────────────
_handle_love_mem() {
    local sender="$1"
    local email; email=$(bro_resolve_email "$sender")
    [[ -z "$email" ]] && \
        _send_dm "$sender" "💕 Compte non trouvé sur cette station." "${_RELAYS[0]}" && return

    local memories; memories=$(_love_get_mem "$email")
    if [[ "$memories" == "[]" ]]; then
        _send_dm "$sender" \
            "💕 Aucun souvenir LOVE enregistré.\nUtilise #love_rec pour mémoriser tes préférences !" \
            "${_RELAYS[0]}"
        return
    fi

    local summary mem_count
    summary=$(python3 -c "
import json,sys
ms=json.load(sys.stdin)
lines=[f'{i+1}. [{m[\"timestamp\"][:10]}] {m[\"content\"]}' for i,m in enumerate(ms[-10:])]
print('\n'.join(lines))
" 2>/dev/null <<< "$memories")
    mem_count=$(python3 -c "import json,sys; print(min(len(json.load(sys.stdin)),10))" \
        2>/dev/null <<< "$memories")
    _send_dm "$sender" "💕 Tes souvenirs LOVE (${mem_count:-0} derniers) :\n\n${summary}" "${_RELAYS[0]}"
}

## ── Handler : mémoriser ───────────────────────────────────────────────────────
_handle_love_rec() {
    local sender="$1" content="$2"
    [[ -z "$content" ]] && \
        _send_dm "$sender" "💕 Syntaxe : envoie le texte à mémoriser via le bouton 'Souvenirs +'" "${_RELAYS[0]}" && return
    local email; email=$(bro_resolve_email "$sender")
    [[ -z "$email" ]] && \
        _send_dm "$sender" "💕 Compte non trouvé sur cette station." "${_RELAYS[0]}" && return

    _love_add_mem "$email" "$content"
    _send_dm "$sender" "💕 Mémorisé : «${content:0:120}»" "${_RELAYS[0]}"
}

## ── Handler : effacer la mémoire et le dialogue ──────────────────────────────
_handle_love_reset() {
    local sender="$1"
    local email; email=$(bro_resolve_email "$sender")
    [[ -z "$email" ]] && \
        _send_dm "$sender" "💕 Compte non trouvé sur cette station." "${_RELAYS[0]}" && return
    _love_clear_mem "$email"
    _love_clear_dialog "$email"
    _send_dm "$sender" "💕 Souvenirs LOVE et historique effacés." "${_RELAYS[0]}"
}

## ── Handler : voir / mettre à jour le profil ─────────────────────────────────
## text peut être un JSON inline : {"age":28,"bio":"...","interests":["yoga"]}
_handle_love_profile() {
    local sender="$1" text="$2"
    local email; email=$(bro_resolve_email "$sender")
    [[ -z "$email" ]] && \
        _send_dm "$sender" "💕 Compte non trouvé sur cette station." "${_RELAYS[0]}" && return

    # Tentative de parse JSON dans le texte
    local new_json="{}"
    if echo "$text" | python3 -c "import json,sys; json.load(sys.stdin)" &>/dev/null 2>&1; then
        new_json="$text"
    fi

    if [[ "$new_json" != "{}" ]]; then
        _love_save_profile "$email" "$new_json"
        # Si le KIN n'est pas dans le profil, tenter de l'ajouter depuis .BIRTHDATE
        local kin_num; kin_num=$(_love_get_kin_number "$email")
        if [[ "${kin_num:-0}" -gt 0 ]]; then
            _love_save_profile "$email" "{\"kin\": $kin_num}"
        fi
        _send_dm "$sender" "💕 Profil LOVE mis à jour !" "${_RELAYS[0]}"
    else
        # Afficher le profil actuel avec le KIN calculé
        local profile; profile=$(_love_get_profile "$email")
        local kin_info; kin_info=$(_love_get_kin "$email")
        local summary
        summary=$(python3 -c "
import json,sys
p=json.load(sys.stdin)
if not p:
    print('Aucun profil créé.\nEnvoie un JSON, ex:\n{\"age\":25,\"bio\":\"Amateur de randonnée\",\"interests\":[\"nature\",\"musique\"]}')
else:
    for k,v in p.items():
        if k not in ('private_notes',): print(f'• {k}: {v}')
" 2>/dev/null <<< "$profile")
        local msg="💕 Ton profil LOVE :\n\n${summary}"
        [[ -n "$kin_info" ]] && msg+="\n\n${kin_info}"
        _send_dm "$sender" "$msg" "${_RELAYS[0]}"
    fi
}

## ── Handler : suggestions de rendez-vous ─────────────────────────────────────
_handle_love_suggest() {
    local sender="$1" hint="${2:-}"
    local season; season=$(_love_current_season)
    local today; today=$(date +"%d/%m/%Y")
    local season_ctx="${season:+en $season, }le $today"

    local question
    if [[ -n "$hint" ]]; then
        question="Suggère-moi des idées de rendez-vous romantiques (${season_ctx}) pour : ${hint}. Propose 3 idées concrètes adaptées à ma personnalité et mes préférences."
    else
        question="Suggère-moi 3 idées originales et romantiques de rendez-vous pour ${season_ctx}, adaptées à mon profil et mes préférences. Pour chaque idée : lieu, ambiance, et ce qui la rend spéciale."
    fi
    _handle_love_ask "$sender" "$question"
}

## ── Handler : analyse compatibilité KIN ─────────────────────────────────────
_handle_love_kin() {
    local sender="$1"
    local email; email=$(bro_resolve_email "$sender")
    [[ -z "$email" ]] && \
        _send_dm "$sender" "💕 Compte non trouvé sur cette station." "${_RELAYS[0]}" && return

    local kin_info; kin_info=$(_love_get_kin "$email")
    local kin_num; kin_num=$(_love_get_kin_number "$email")

    local question
    if [[ -n "$kin_info" ]]; then
        question="Mon signe KIN Dreamspell est : ${kin_info}
Explique les caractéristiques de ce signe pour les relations amoureuses, les types de personnalités qui lui sont complémentaires, et les défis éventuels à surmonter en couple."
    else
        question="Je n'ai pas encore renseigné ma date de naissance dans mon profil UPlanet. Explique brièvement ce qu'est le KIN Dreamspell et comment il peut servir à la compatibilité amoureuse. Comment puis-je trouver mon KIN ?"
    fi
    _handle_love_ask "$sender" "$question"
}

## ── Handler : générer un message d'accroche ──────────────────────────────────
## action=intro text="description courte du profil cible"
_handle_love_intro() {
    local sender="$1" target_desc="${2:-}"
    [[ -z "$target_desc" ]] && \
        _send_dm "$sender" "💕 Précise quelque chose sur la personne pour générer une intro.\nEx : \"aime la musique et la randonnée, curieux et créatif\"" "${_RELAYS[0]}" && return

    local question="Rédige un message d'accroche authentique et chaleureux que je pourrais envoyer à quelqu'un dont voici le profil : ${target_desc}
Le message doit être court (3-5 phrases max), naturel, sincère, et refléter ma personnalité. Pas de clichés. Il doit donner envie de répondre sans être intrusif."
    _handle_love_ask "$sender" "$question"
}

## ── Handler : matching local (Tier 2, +18 requis) ───────────────────────────
## Score composite (120 pts max) :
##   • Intérêts communs  : 0-40 pts  (15 pts/intérêt commun, max 40)
##   • Compatibilité KIN : 0-30 pts  (formule Dreamspell seal/tone/couleur)
##   • Résonance Phi²    : 0-30 pts  (k=1/(1+|sin(Δφ)|) + bonus ω, ATOM4LOVE)
##   • Traces communes   : 0-20 pts  (URLs Kind 10600 visitées en commun)
_handle_love_match() {
    local sender="$1"
    local email; email=$(bro_resolve_email "$sender")
    [[ -z "$email" ]] && \
        _send_dm "$sender" "💕 Compte non trouvé sur cette station." "${_RELAYS[0]}" && return

    if ! _love_is_tier2 "$email"; then
        _send_dm "$sender" \
            "💕 Le matching est réservé aux membres majeurs (+18 ans).\n\nMets à jour ton profil avec ton âge :\n{\"age\": <ton_age>}" \
            "${_RELAYS[0]}"
        return
    fi

    local my_profile; my_profile=$(_love_get_profile "$email")
    local my_kin;     my_kin=$(_love_get_kin_number "$email")

    # Données Phi² de l'utilisateur (cache avant la boucle)
    local my_a4l; my_a4l=$(_love_get_a4l_data "$email")
    local my_phi my_omega
    my_phi=$(jq -r '.personal_phase // empty' <<< "$my_a4l" 2>/dev/null)
    my_omega=$(jq -r '.omega_bio // empty' <<< "$my_a4l" 2>/dev/null)
    local my_phi2x_available=false
    [[ -n "$my_phi" ]] && my_phi2x_available=true

    # Traces ATOM4LOVE (Kind 10600, ext navigateur) — cache avant la boucle
    local my_pubkey_hex; my_pubkey_hex=$(_love_pubkey_for_email "$email")
    local my_traces="[]"
    [[ -n "$my_pubkey_hex" ]] && my_traces=$(_love_get_traces "$my_pubkey_hex")
    local my_trace_count; my_trace_count=$(python3 -c "import json,sys; print(len(json.loads(sys.argv[1])))" "$my_traces" 2>/dev/null || echo 0)

    [[ "${LOVE_DEBUG:-0}" == "1" ]] && \
        _log "💕 LOVE match: email=$email kin=${my_kin:-0} phi2x=$my_phi2x_available traces=$my_trace_count"

    # Collecter tous les candidats avec leurs scores
    declare -A candidate_scores=()
    declare -A candidate_labels=()
    declare -A candidate_bios=()

    local other_dir other_email other_profile
    for other_dir in "$_LOVE_MEM_BASE"/*/love; do
        other_email=$(basename "$(dirname "$other_dir")")
        [[ "$other_email" == "$email" ]] && continue
        [[ ! -f "$other_dir/profile.json" ]] && continue

        other_profile=$(cat "$other_dir/profile.json")

        # Données publiques depuis NOSTR : profil d=love-profile (opt-in) ou kind-0 (fallback)
        local other_pubkey; other_pubkey=$(_love_pubkey_for_email "$other_email")
        local other_nostr_lp="{}"
        [[ -n "$other_pubkey" ]] && other_nostr_lp=$(_love_get_nostr_love_profile "$other_pubkey")

        # Filtres obligatoires :
        #   - âge ≥ 18 (depuis profil NOSTR love-profile ou profil local)
        #   - consentement public (flag "public":true dans l'un ou l'autre)
        local other_age other_public
        other_age=$(python3 -c "
import json,sys
lp=json.loads(sys.argv[1]); loc=json.loads(sys.argv[2])
age=lp.get('age') or loc.get('age',0)
print(int(age) if age else 0)
" "$other_nostr_lp" "$other_profile" 2>/dev/null)
        other_public=$(python3 -c "
import json,sys
lp=json.loads(sys.argv[1]); loc=json.loads(sys.argv[2])
print('true' if lp.get('public') or loc.get('public') else 'false')
" "$other_nostr_lp" "$other_profile" 2>/dev/null)
        [[ "${other_age:-0}" -lt 18 ]] && continue
        [[ "$other_public" != "true" ]] && continue

        # ── Score 1 : intérêts communs (0-40 pts) ──────────────────────────
        local score_interest=0 common_list=""
        local interest_raw
        interest_raw=$(python3 -c "
import json,sys
my=json.loads(sys.argv[1]); ot=json.loads(sys.argv[2])
my_i=set(my.get('interests',[])); ot_i=set(ot.get('interests',[]))
common=sorted(my_i & ot_i)
print(len(common), ','.join(common[:4]))
" "$my_profile" "$other_profile" 2>/dev/null)
        score_interest=$(echo "$interest_raw" | awk '{print $1}')
        common_list=$(echo "$interest_raw" | cut -d' ' -f2-)
        score_interest=$(( score_interest * 15 ))
        [[ $score_interest -gt 40 ]] && score_interest=40

        # ── Score 2 : compatibilité KIN Dreamspell (0-30 pts) ──────────────
        local score_kin=0 kin_pct=0 kin_label=""
        local other_kin
        other_kin=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('kin',0))" \
            "$other_profile" 2>/dev/null)
        if [[ "${my_kin:-0}" -gt 0 && "${other_kin:-0}" -gt 0 ]]; then
            local kin_raw; kin_raw=$(_love_kin_compat_score "$my_kin" "$other_kin")
            kin_pct=$(echo "$kin_raw" | awk '{print $1}')
            kin_label=$(echo "$kin_raw" | cut -d' ' -f2-)
            score_kin=$(( kin_pct * 30 / 100 ))
        fi

        # ── Score 3 : résonance Phi² ATOM4LOVE (0-30 pts) ─────────────────
        local score_phi2x=0 phi2x_label=""
        if [[ "$my_phi2x_available" == "true" ]]; then
            local other_a4l other_phi other_omega
            other_a4l=$(_love_get_a4l_data "$other_email")
            other_phi=$(jq -r '.personal_phase // empty' <<< "$other_a4l" 2>/dev/null)
            other_omega=$(jq -r '.omega_bio // empty' <<< "$other_a4l" 2>/dev/null)
            if [[ -n "$other_phi" ]]; then
                local phi2x_raw; phi2x_raw=$(_love_phi2x_score \
                    "$my_phi" "$other_phi" "${my_omega:-}" "${other_omega:-}")
                local phi2x_pts; phi2x_pts=$(echo "$phi2x_raw" | awk '{print $1}')
                phi2x_label=$(echo "$phi2x_raw" | cut -d' ' -f2-)
                # Ramener de 0-50 → 0-30
                score_phi2x=$(( phi2x_pts * 30 / 50 ))
            fi
        fi

        # ── Score 4 : traces communes ATOM4LOVE (0-20 pts) ───────────────
        local score_traces=0 trace_label=""
        if [[ "$my_trace_count" -gt 0 && -n "$other_pubkey" ]]; then
            local other_traces; other_traces=$(_love_get_traces "$other_pubkey")
            local trace_raw; trace_raw=$(_love_trace_score "$my_traces" "$other_traces")
            score_traces=${trace_raw%% *}
            trace_label="${trace_raw#* }"
            [[ "$trace_label" == "$score_traces" ]] && trace_label=""  # aucun label si score seul
        fi

        local total_score=$(( score_interest + score_kin + score_phi2x + score_traces ))
        [[ $total_score -lt 10 ]] && continue

        local bio
        bio=$(python3 -c "import json,sys; p=json.loads(sys.argv[1]); print(p.get('bio','…')[:100])" \
            "$other_profile" 2>/dev/null)

        # Construire le label d'affinité
        local affinity_parts=()
        [[ -n "$common_list" && "$common_list" != " " ]] && \
            affinity_parts+=("intérêts : ${common_list//,/, }")
        [[ $score_kin -gt 0 && -n "$kin_label" ]] && \
            affinity_parts+=("KIN ${kin_label} (${kin_pct}%)")
        [[ $score_phi2x -gt 0 && -n "$phi2x_label" ]] && \
            affinity_parts+=("$phi2x_label")
        [[ $score_traces -gt 0 && -n "$trace_label" ]] && \
            affinity_parts+=("🌐 ${trace_label}")

        candidate_scores["$other_email"]=$total_score
        local _sep="" _lbl=""
        for _part in "${affinity_parts[@]}"; do _lbl+="${_sep}${_part}"; _sep=" | "; done
        candidate_labels["$other_email"]="$_lbl"
        candidate_bios["$other_email"]="$bio"
    done

    if [[ ${#candidate_scores[@]} -eq 0 ]]; then
        local phi2x_hint=""
        [[ "$my_phi2x_available" != "true" ]] && \
            phi2x_hint="\n\n💡 Active ATOM4LOVE pour bénéficier de la résonance Phi² dans le matching."
        _send_dm "$sender" \
            "💕 Aucun profil compatible trouvé.\n\nEncourage d'autres membres à activer LOVE et rendre leur profil public : {\"public\": true}${phi2x_hint}" \
            "${_RELAYS[0]}"
        return
    fi

    # Trier par score décroissant, garder les 3 meilleurs
    local sorted_emails
    sorted_emails=$(for k in "${!candidate_scores[@]}"; do
        echo "${candidate_scores[$k]} $k"
    done | sort -rn | head -3 | awk '{print $2}')

    local matches_text="" count=0
    local my_pubkey; my_pubkey=$(_love_pubkey_for_email "$email")

    while IFS= read -r match_email; do
        [[ -z "$match_email" ]] && continue
        count=$(( count + 1 ))
        local sc="${candidate_scores[$match_email]}"
        local lbl="${candidate_labels[$match_email]}"
        local bio="${candidate_bios[$match_email]}"

        # Enrichir avec les données NOSTR publiques du match
        local match_pubkey; match_pubkey=$(_love_pubkey_for_email "$match_email")
        local nostr_name="" nostr_about="" recent_posts=""
        if [[ -n "$match_pubkey" ]]; then
            local k0; k0=$(_love_get_kind0 "$match_pubkey")
            nostr_name=$(python3 -c "
import json,sys
p=json.loads(sys.argv[1])
name=p.get('display_name') or p.get('name','')
nip05=p.get('nip05','')
print(f'{name} ({nip05})' if nip05 else name)
" "$k0" 2>/dev/null)
            nostr_about=$(python3 -c "
import json,sys
print(json.loads(sys.argv[1]).get('about','')[:150])
" "$k0" 2>/dev/null)
            recent_posts=$(_love_get_recent_posts "$match_pubkey" 3)
        fi

        # URL de rencontre déterministe (si les deux pubkeys sont connus)
        local meeting_url=""
        [[ -n "$my_pubkey" && -n "$match_pubkey" ]] && \
            meeting_url=$(_love_meeting_url "$my_pubkey" "$match_pubkey")

        # Construire la fiche du match
        matches_text+="${count}. **${nostr_name:-Profil anonyme}**\n"
        [[ -n "$nostr_about" ]] && matches_text+="   ${nostr_about}\n"
        [[ -n "$bio" && "$bio" != "…" ]] && matches_text+="   _(Love)_ ${bio}\n"
        matches_text+="   ⭐ ${sc}/120 | ${lbl}\n"
        if [[ -n "$recent_posts" ]]; then
            matches_text+="\n   📝 Posts récents :\n"
            while IFS= read -r post; do
                matches_text+="   ${post}\n"
            done <<< "$recent_posts"
        fi
        [[ -n "$meeting_url" ]] && matches_text+="\n   🎙️ Salle de rencontre : ${meeting_url}\n"
        matches_text+="\n"
    done <<< "$sorted_emails"

    # Journaliser les matchs vus (rotation 20)
    local dir; dir="$(_love_dir "$email")"
    mkdir -p "$dir"
    python3 -c "
import json,sys,os
from datetime import date
f='$dir/matches.json'
data=json.loads(open(f).read()) if os.path.exists(f) else []
data.append({'date':str(date.today()),'count':int(sys.argv[1])})
data=data[-20:]
open(f,'w').write(json.dumps(data,ensure_ascii=False))
" "$count" 2>/dev/null

    local phi2x_note=""
    [[ "$my_phi2x_available" != "true" ]] && \
        phi2x_note="\n💡 Inscris-toi sur ATOM4LOVE pour activer la résonance Phi² dans le matching."

    _send_dm "$sender" \
        "💕 ${count} profil(s) compatible(s) :\n\n${matches_text}Pour une mise en relation : utilise l'action Intro puis contacte le capitaine.${phi2x_note}" \
        "${_RELAYS[0]}"
}

## ── POINT D'ENTRÉE PRINCIPAL ─────────────────────────────────────────────────
## Appelé depuis bro_dm_daemon.sh :
##   love) _handle_love "$payload" "$sender" ;;
##
## Format payload NIP-44 attendu (JSON décrypté, champ payload du canal "love") :
##   {"action":"ask","text":"Aide-moi à..."}
##   {"action":"rec","text":"Je préfère les balades en forêt"}
##   {"action":"profile","text":"{\"age\":28,\"bio\":\"...\"}"}
##   {"action":"intro","text":"aime la cuisine et la nature"}
##   {"action":"suggest","text":"dîner romantique"}
##   {"action":"match"} | {"action":"mem"} | {"action":"reset"}
##   {"action":"kin"}
_handle_love() {
    local payload="$1" sender="$2"

    local action text
    IFS=$'\t' read -r action text <<< \
        "$(jq -r '[.action//"ask", .text//""] | @tsv' <<< "$payload" 2>/dev/null)"

    # Fallback : texte brut sans champ action → question libre
    [[ -z "$action" || "$action" == "null" ]] && action="ask"

    _log "💕 LOVE canal : action='$action' sender=${sender:0:12} text=${text:0:60}"

    case "$action" in
        ask)     _handle_love_ask     "$sender" "$text" ;;
        mem)     _handle_love_mem     "$sender" ;;
        rec)     _handle_love_rec     "$sender" "$text" ;;
        reset)   _handle_love_reset   "$sender" ;;
        profile) _handle_love_profile "$sender" "$text" ;;
        suggest) _handle_love_suggest "$sender" "$text" ;;
        kin)     _handle_love_kin     "$sender" ;;
        match)   _handle_love_match   "$sender" ;;
        intro)   _handle_love_intro   "$sender" "$text" ;;
        status)  _handle_love_status  "$sender" ;;
        *)       _handle_love_ask     "$sender" "${text:-$action}" ;;
    esac
}
