#!/bin/bash
# Dependencies : jq curl ollama (voir ../services/ollama.me.sh)
#### generate_storyboard.sh : assistant interactif → storyboard.json pour generate_scene.sh
#
# Usage: generate_storyboard.sh [-o fichier.json] [-m modele]
#   -o  fichier de sortie (défaut $SCENES_DIR/storyboard_<horodatage>.json)
#   -m  modèle Ollama à utiliser (sinon choix interactif parmi ceux installés)
#
# Pose une série de questions (sujet, format, personnages, voix-off…), les transforme
# en prompt pour une IA locale/essaim (Ollama, via question.py — même moteur que BRO),
# valide le JSON renvoyé avec les mêmes règles que generate_scene.sh (deux tentatives
# de correction si le modèle s'écarte du schéma), puis propose de lancer le rendu.
# Compte utilisé pour la trace (~/.zen/tmp/IA.log) : le Capitaine de la station.
# Codes de sortie : 0 ok, 1 erreur, 2 argument/réponse invalide, 3 Ollama injoignable.

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

QUESTION_PY="$MY_PATH/../question.py"
[ -s "$QUESTION_PY" ] || { echo "Erreur : $QUESTION_PY introuvable" >&2; exit 1; }

echo "=== Assistant storyboard (IA) — compte Capitaine : ${CAPTAINEMAIL:-inconnu} ===" >&2
echo >&2

# Ollama joignable (local → P2P essaim → SSH, même connecteur que pour ComfyUI)
if ! curl -sf -m 3 http://localhost:11434/api/tags > /dev/null 2>&1; then
  echo "Connexion à Ollama…" >&2
  bash "$MY_PATH/../services/ollama.me.sh" > /dev/null 2>&1
  curl -sf -m 5 http://localhost:11434/api/tags > /dev/null 2>&1 \
    || { echo "Erreur : Ollama injoignable (IA/services/ollama.me.sh)" >&2; exit 3; }
fi

# Moteur : -m donné tel quel, sinon choix interactif parmi les modèles installés
if [ -z "$MODEL" ]; then
  mapfile -t MODELS < <(curl -s -m 5 http://localhost:11434/api/tags | jq -r '.models[].name' | grep -v embed)
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
echo >&2

# ── Questions ─────────────────────────────────────────────────────────────────
read -rp "Sujet / scénario de la vidéo (ce qu'elle doit expliquer ou raconter) : " SUJET
[ -z "$SUJET" ] && { echo "Erreur : un sujet est nécessaire." >&2; exit 2; }
read -rp "Nombre de plans souhaité (défaut 8) : " NSHOTS; NSHOTS="${NSHOTS:-8}"
read -rp "Format [16:9/9:16/1:1] (défaut 16:9) : " RATIO; RATIO="${RATIO:-16:9}"
read -rp "Style [clean/vhs] (défaut clean) : " STYLE; STYLE="${STYLE:-clean}"
read -rp "Personnage(s) qui parlent, séparés par des virgules (vide = aucun, pas de dialogue) : " CASTNAMES
read -rp "Voix-off de narrateur en plus des dialogues ? [o/N] : " VO_YN
NARRATOR_DESIGN=""
if [[ "${VO_YN,,}" == o* ]]; then
  read -rp "Timbre du narrateur (ex: 'voix d'homme grave et posée, documentaire'), vide = voix par défaut : " NARRATOR_DESIGN
fi
read -rp "Carton final avec lien(s) à afficher ? URL (vide = pas de carton) : " CARD_URL
CARD_LABEL=""
[ -n "$CARD_URL" ] && read -rp "Libellé de ce lien : " CARD_LABEL

# ── Personnages : décrit ceux qui existent déjà (CLI ou Studio web), pour cohérence ─
CAST_BLOCK=""
IFS=',' read -ra NAMES <<< "$CASTNAMES"
for raw in "${NAMES[@]}"; do
  n=$(echo "$raw" | xargs)
  [ -z "$n" ] && continue
  bdir="$CAST_BANK/$n"
  if [ ! -s "$bdir/character.json" ] && [ ! -s "$bdir/portrait.png" ]; then
    "$ASTRO_PY" "$HOME/.zen/Astroport.ONE/tools/story_asset.py" resolve-character "$n" --dest "$bdir" > /dev/null 2>&1
  fi
  if [ -s "$bdir/portrait.png" ]; then
    look=$(jq -r '.look // .image_prompt // empty' "$bdir/character.json" 2>/dev/null)
    CAST_BLOCK+=$'\n'"- \"$n\" existe déjà : dans le JSON écrire \"$n\": {} (objet VIDE, ne pas inventer image_prompt/voice_line).${look:+ Apparence pour cohérence du texte : $look}"
  else
    CAST_BLOCK+=$'\n'"- \"$n\" est à créer : invente \"image_prompt\" (description physique en anglais, fond neutre) et \"voice_line\" (phrase française de 8 secondes environ, dans son propre style)."
  fi
done
[ -z "$CAST_BLOCK" ] && CAST_BLOCK=$'\n'"(aucun personnage : uniquement des plans muets ou avec voix-off de narrateur)"

# ── Prompt ────────────────────────────────────────────────────────────────────
PROMPT_FILE=$(mktemp)
{
cat <<EOF
Tu es un scénariste qui écrit des storyboards au format JSON STRICT pour un générateur
vidéo IA (MiniMax H3 + Z-Image). Réponds UNIQUEMENT avec un objet JSON valide, sans
markdown, sans commentaire, sans texte avant ou après — rien d'autre que le JSON.

SCHÉMA (n'utilise AUCUN champ en dehors de celui-ci) :
{
  "ratio": "$RATIO", "style": "$STYLE",
  "cast": { "nom": {"image_prompt": "...", "voice_line": "..."} },
  "shots": [
    {"cast": ["nom"], "duration": 7,
     "prompt": "description de l'action et du décor en anglais, se terminant par la
     réplique au style direct : Nom says in French: \\"...réplique exacte en français...\\""},
    {"prompt": "plan muet ou d'ambiance en anglais, décrit aussi le son (musique, bruitage)", "duration": 5},
    {"card": {"title": "...", "links": [{"label": "...", "url": "https://..."}]}, "duration": 8}
  ]
}

RÈGLES IMPORTANTES :
- Chaque plan avec un personnage qui parle DOIT contenir sa réplique française exacte,
  entre guillemets, introduite par "Nom says in French:" à l'intérieur du champ "prompt"
  (pas de champ séparé pour la réplique).
- Une réplique parlée tient en ~2,5 mots par seconde (une "duration" de 7 s ≈ 17 mots).
- Un seul personnage par plan qui parle (pas de dialogue croisé dans un même plan).
- "prompt" toujours en anglais, sauf la réplique elle-même qui est en français.
- Le premier plan ne peut pas avoir "continue": true.
- "cast" du haut doit lister TOUS les personnages utilisés dans "shots", et uniquement eux.

PERSONNAGES À UTILISER :$CAST_BLOCK

DEMANDE : un storyboard de $NSHOTS plans sur le sujet suivant : "$SUJET".
EOF
if [ -n "$NARRATOR_DESIGN" ]; then
  echo "Ajoute une voix-off de narrateur sur 1 ou 2 plans clés avec le champ \"voiceover\" (texte français), et ajoute au niveau racine \"narrator\": {\"voice_design\": \"$NARRATOR_DESIGN\"}."
fi
if [ -n "$CARD_URL" ]; then
  echo "Termine par un plan carton : {\"card\": {\"title\": \"...\", \"links\": [{\"label\": \"$CARD_LABEL\", \"url\": \"$CARD_URL\"}]}, \"duration\": 8}."
else
  echo "N'ajoute AUCUN plan \"card\" : aucun lien ni URL n'a été demandé, n'en invente pas."
fi
} > "$PROMPT_FILE"

# ── Appel IA, avec jusqu'à 2 corrections si le JSON ne respecte pas le schéma ────
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
trap 'rm -f "$PROMPT_FILE" "$RAW" "$CLEAN"' EXIT
NPUB_ARG=()
[ -n "${CAPTAINEMAIL:-}" ] && [ -s "$HOME/.zen/game/nostr/${CAPTAINEMAIL}/HEX" ] \
  && NPUB_ARG=(--npub "$(cat "$HOME/.zen/game/nostr/${CAPTAINEMAIL}/HEX")")

ATTEMPT=1
ERR=""
while [ "$ATTEMPT" -le 3 ]; do
  echo "Rédaction du storyboard par l'IA (tentative $ATTEMPT/3, $MODEL)…" >&2
  if [ -n "$ERR" ]; then
    printf '\nTa réponse précédente était invalide : %s. Corrige et renvoie UNIQUEMENT le JSON complet corrigé.\n' "$ERR" >> "$PROMPT_FILE"
  fi
  "$ASTRO_PY" "$QUESTION_PY" --prompt-file "$PROMPT_FILE" --model "$MODEL" --format-json \
    --temperature 0.4 --max-tokens 6000 "${NPUB_ARG[@]}" > "$RAW"
  if [ ! -s "$RAW" ]; then
    echo "Erreur : réponse vide d'Ollama" >&2
    exit 3
  fi
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
  ATTEMPT=$((ATTEMPT + 1))
done
if [ -n "$ERR" ]; then
  echo "Erreur : l'IA n'a pas produit un storyboard valide après 3 tentatives ($ERR)." >&2
  echo "Dernière réponse brute dans : $RAW (non supprimée pour inspection)" >&2
  trap - EXIT
  rm -f "$PROMPT_FILE" "$CLEAN"
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
