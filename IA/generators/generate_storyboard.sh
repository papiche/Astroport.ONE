#!/bin/bash
# Dependencies : jq curl ollama (voir ../services/ollama.me.sh)
#### generate_storyboard.sh : discussion avec une IA → storyboard.json pour generate_scene.sh
#
# Usage: generate_storyboard.sh [-o fichier.json] [-m modele]
#   -o  fichier de sortie (défaut $SCENES_DIR/storyboard_<horodatage>.json)
#   -m  modèle Ollama à utiliser (sinon choix interactif parmi ceux installés)
#
# Engage une VRAIE conversation (pas un simple questionnaire) : décrivez votre idée, l'IA
# pose les questions utiles (sujet flou, format, personnages, voix-off…), propose plusieurs
# pistes de scénario, les affine selon vos retours — tapez "go" dès qu'une piste vous
# convient pour générer le storyboard JSON final (jusqu'à 3 tentatives de correction
# automatique si le JSON ne respecte pas le schéma attendu par generate_scene.sh, en
# conservant tout l'historique de la discussion pour la correction).
# Compte utilisé pour la trace (~/.zen/tmp/IA.log) : le Capitaine de la station.
# Codes de sortie : 0 ok, 1 erreur, 2 réponse invalide, 3 Ollama injoignable.

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"
. "$MY_PATH/lib/env.sh"
. "${HOME}/.zen/Astroport.ONE/tools/my.sh"

usage() {
  sed -n '5,8p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

OUT="" MODEL=""
while getopts "o:m:h" opt; do
  case $opt in
    o) OUT="$OPTARG" ;;
    m) MODEL="$OPTARG" ;;
    *) usage ;;
  esac
done

OLLAMA_URL="http://localhost:11434"
echo "=== Assistant storyboard (IA) — compte Capitaine : ${CAPTAINEMAIL:-inconnu} ===" >&2
echo >&2

# Ollama joignable (local → P2P essaim → SSH, même connecteur que pour ComfyUI)
if ! curl -sf -m 3 "$OLLAMA_URL/api/tags" > /dev/null 2>&1; then
  echo "Connexion à Ollama…" >&2
  bash "$MY_PATH/../services/ollama.me.sh" > /dev/null 2>&1
  curl -sf -m 5 "$OLLAMA_URL/api/tags" > /dev/null 2>&1 \
    || { echo "Erreur : Ollama injoignable (IA/services/ollama.me.sh)" >&2; exit 3; }
fi

# Moteur : -m donné tel quel, sinon choix interactif parmi les modèles installés
if [ -z "$MODEL" ]; then
  mapfile -t MODELS < <(curl -s -m 5 "$OLLAMA_URL/api/tags" | jq -r '.models[].name' | grep -v embed)
  if [ ${#MODELS[@]} -eq 0 ]; then
    MODEL="gemma3:latest"
  elif [ ${#MODELS[@]} -eq 1 ]; then
    MODEL="${MODELS[0]}"
  else
    echo "Moteur IA (Ollama) :" >&2
    default_i=1
    for i in "${!MODELS[@]}"; do
      [ "${MODELS[$i]}" = "gemma3:latest" ] && default_i=$((i + 1))
      printf "  [%d] %s\n" "$((i + 1))" "${MODELS[$i]}" >&2
    done
    read -rp "Numéro (défaut $default_i) : " choice
    [[ "$choice" =~ ^[0-9]+$ ]] || choice="$default_i"
    MODEL="${MODELS[$((choice - 1))]:-${MODELS[0]}}"
  fi
fi
echo "→ Moteur retenu : $MODEL" >&2

# ── Personnages déjà disponibles (banque CLI, alimentée aussi par le Studio web via
#    resolve-character) : donnés à l'IA dès le départ pour qu'elle les propose d'elle-même ─
EXISTING_CAST=""
if [ -d "$CAST_BANK" ]; then
  for d in "$CAST_BANK"/*/; do
    [ -s "${d}portrait.png" ] || continue
    n=$(basename "$d")
    look=$(jq -r '.look // .image_prompt // empty' "${d}character.json" 2>/dev/null)
    EXISTING_CAST+=$'\n'"- $n${look:+ : $look}"
  done
fi
[ -z "$EXISTING_CAST" ] && EXISTING_CAST=$'\n'"(aucun pour l'instant)"

# ── Conversation : messages = tableau JSON [{role,content}], manipulé via jq ─────────────
MESSAGES='[]'
add_msg() {  # $1 role, $2 contenu
  MESSAGES=$(jq -c --arg r "$1" --arg c "$2" '. + [{"role":$r,"content":$c}]' <<< "$MESSAGES")
}
# $1 = "json" pour forcer une sortie JSON stricte (génération finale), sinon conversation libre
chat_call() {
  local temp="0.6" want_json=0
  [ "$1" = "json" ] && { temp="0.3"; want_json=1; }
  local body
  body=$(jq -nc --arg model "$MODEL" --argjson msgs "$MESSAGES" --argjson t "$temp" \
    '{model:$model, messages:$msgs, stream:false, options:{temperature:$t}}')
  [ "$want_json" = 1 ] && body=$(jq -c '. + {format:"json"}' <<< "$body")
  curl -s -m 180 -X POST "$OLLAMA_URL/api/chat" -H "Content-Type: application/json" -d "$body" \
    | jq -r '.message.content // empty'
}

SYSTEM_PROMPT=$(cat <<EOF
Tu es un scénariste qui aide, PAR LA DISCUSSION, à concevoir un storyboard vidéo pour un
générateur IA (MiniMax H3 + Z-Image). Réponds en français, de façon concise et conversationnelle.

PENDANT LA DISCUSSION (tant que l'utilisateur n'a pas tapé "go") :
- Ne produis JAMAIS de JSON. Discute normalement.
- Si le sujet est encore flou, pose UNE ou DEUX questions courtes à la fois (jamais un long
  questionnaire d'un coup) : sujet précis, ton/ambiance, format (16:9 paysage / 9:16 vertical /
  1:1 carré), style (net ou "vhs" cassette), personnages qui parlent, voix-off de narrateur,
  carton final avec un lien.
- Dès que tu as une idée du sujet, propose 2 ou 3 PISTES DE SCÉNARIO différentes, numérotées,
  en une ou deux phrases chacune (angle, nombre de plans approximatif, ton). Demande laquelle
  retenir, ou si l'utilisateur veut en combiner/ajuster.
- Affine la piste retenue à chaque message suivant, en tenant compte de tous les retours.
- Reste bref : pas de longs pavés, l'utilisateur doit pouvoir répondre vite.

PERSONNAGES DÉJÀ DISPONIBLES (les proposer activement si pertinent ; les réutiliser SANS
changer leur apparence) :$EXISTING_CAST

Quand l'utilisateur tape "go", tu recevras une demande explicite de produire le JSON final —
pas avant.
EOF
)
add_msg system "$SYSTEM_PROMPT"

echo >&2
echo "Décrivez votre idée de vidéo (même vague). Tapez \"go\" à tout moment pour générer le" >&2
echo "storyboard dès qu'une piste vous convient, \"stop\" pour abandonner." >&2
echo >&2

while true; do
  read -rp "Vous> " USER_MSG
  case "${USER_MSG,,}" in
    go) break ;;
    stop|quit|exit) echo "Abandonné." >&2; exit 0 ;;
    "") continue ;;
  esac
  add_msg user "$USER_MSG"
  echo "…" >&2
  REPLY=$(chat_call)
  if [ -z "$REPLY" ]; then
    echo "Erreur : pas de réponse d'Ollama (réessayez, ou \"stop\" pour abandonner)." >&2
    MESSAGES=$(jq -c '.[:-1]' <<< "$MESSAGES")  # retire le message non répondu
    continue
  fi
  add_msg assistant "$REPLY"
  echo >&2
  echo "IA> $REPLY" >&2
  echo >&2
done

# ── Génération finale, avec jusqu'à 3 tentatives de correction (même conversation) ───────
validate_sb() {
  # $1 fichier JSON ; écrit le message d'erreur sur stdout, rien si valide
  jq -e 'type == "object"' "$1" > /dev/null 2>&1 || { echo "ce n'est pas un objet JSON"; return; }
  jq -e '.shots | type == "array" and length > 0
         and all(.[]; (.prompt | type) == "string" or (.screen and (.presenter | not)) or .card)' "$1" > /dev/null 2>&1 \
    || { echo 'chaque plan doit avoir "prompt" (texte), ou "screen" sans présentateur, ou "card"'; return; }
  jq -e '.shots[0].continue != true' "$1" > /dev/null 2>&1 \
    || { echo 'le premier plan ne peut pas avoir "continue": true'; return; }
  missing=$(jq -r '(.cast // {}) as $c | [.shots[] | ((.cast // []) + [.presenter // empty])[] | select($c[.] | not)] | unique | join(" ")' "$1" 2>/dev/null)
  [ -n "$missing" ] && { echo "acteur(s) absent(s) de \"cast\" : $missing"; return; }
}

RAW=$(mktemp)
CLEAN=$(mktemp)
trap 'rm -f "$RAW" "$CLEAN"' EXIT

add_msg user "Parfait, génère maintenant le storyboard JSON final de ce qu'on vient de définir.
Réponds UNIQUEMENT avec un objet JSON valide, sans markdown, sans texte autour — rien d'autre
que le JSON. Schéma strict, aucun champ en dehors :
{\"ratio\": \"16:9\", \"style\": \"clean\",
 \"cast\": {\"nom\": {\"image_prompt\": \"...\", \"voice_line\": \"...\"}},
 \"shots\": [
   {\"cast\": [\"nom\"], \"duration\": 7,
    \"prompt\": \"description en anglais, finissant par : Nom says in French: \\\"réplique exacte en français\\\"\"},
   {\"prompt\": \"plan muet ou d'ambiance en anglais, décrit aussi le son\", \"duration\": 5}
 ]}
Un personnage déjà existant (voir liste donnée plus haut) s'écrit \"nom\": {} (objet VIDE),
jamais avec image_prompt/voice_line. Une réplique tient ~2,5 mots/s. Un seul personnage par
plan qui parle. Le premier plan ne peut pas avoir \"continue\": true. \"cast\" en haut doit
lister exactement les personnages utilisés dans \"shots\", ni plus ni moins. N'ajoute un plan
\"card\" (carton + liens) que si on en a explicitement discuté — sinon aucun carton, n'en
invente pas. Pour tout paramètre non discuté (format, style...), choisis une valeur par défaut
raisonnable sans redemander."

ATTEMPT=1
ERR=""
while [ "$ATTEMPT" -le 3 ]; do
  echo "Génération du storyboard (tentative $ATTEMPT/3, $MODEL)…" >&2
  REPLY=$(chat_call json)
  if [ -z "$REPLY" ]; then
    echo "Erreur : réponse vide d'Ollama" >&2
    exit 3
  fi
  add_msg assistant "$REPLY"
  printf '%s' "$REPLY" > "$RAW"
  if jq '.' "$RAW" > "$CLEAN" 2>/dev/null; then :; else
    # Repli : extrait le premier bloc {...} si le modèle a ajouté du texte autour
    python3 -c "import re,sys
t = open(sys.argv[1]).read()
m = re.search(r'\{.*\}', t, re.S)
sys.exit(1) if not m else print(m.group(0))" "$RAW" | jq '.' > "$CLEAN" 2>/dev/null || true
  fi
  if [ -s "$CLEAN" ]; then
    ERR=$(validate_sb "$CLEAN")
    [ -z "$ERR" ] && break
    echo "Réponse invalide (tentative $ATTEMPT) : $ERR" >&2
  else
    ERR="le JSON n'a pas pu être analysé"
    echo "Réponse invalide (tentative $ATTEMPT) : $ERR" >&2
  fi
  add_msg user "Ta réponse n'était pas un storyboard valide : $ERR. Renvoie UNIQUEMENT le JSON complet corrigé, rien d'autre."
  ATTEMPT=$((ATTEMPT + 1))
done
if [ -n "$ERR" ]; then
  echo "Erreur : l'IA n'a pas produit un storyboard valide après 3 tentatives ($ERR)." >&2
  echo "Dernière réponse brute dans : $RAW (non supprimée pour inspection)" >&2
  trap - EXIT
  rm -f "$CLEAN"
  exit 2
fi

OUT="${OUT:-$SCENES_DIR/storyboard_$(date +%s).json}"
mkdir -p "$(dirname "$OUT")"
jq '.' "$CLEAN" > "$OUT"
echo >&2
echo "✅ Storyboard écrit : $OUT" >&2
jq -r '"   " + (.shots | length | tostring) + " plan(s), cast: " + ((.cast // {}) | keys | join(", "))' "$OUT" >&2

read -rp "Lancer le rendu maintenant avec generate_scene.sh ? [o/N] : " GO
if [[ "${GO,,}" == o* ]]; then
  exec "$MY_PATH/generate_scene.sh" -w "${OUT%.json}_work" "$OUT"
fi
echo "Pour le lancer plus tard : $MY_PATH/generate_scene.sh -w <dossier> $OUT" >&2
