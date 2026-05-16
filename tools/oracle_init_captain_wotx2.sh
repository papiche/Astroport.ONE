#!/bin/bash
################################################################################
# oracle_init_captain_wotx2.sh
#
# Bootstrap WoTx2 pour les compétences Capitaine Astroport.
#
# Ce script :
#   1. Crée les définitions de permits X1 (kind 30500) pour les compétences
#      capitaines prédéfinies (astroport, linux, bash, python, docker, dart,
#      flutter, nostr, ipfs, git) si elles n'existent pas encore.
#   2. Propose au capitaine de choisir ses compétences initiales.
#   3. Publie un événement 30501 (demande d'apprentissage) pour chaque
#      compétence choisie — à confirmer par des pairs de la constellation.
#   4. Oriente vers le tableau de bord personnel earth/my_wotx2.html.
#
# Appelé depuis install.sh après la création du MULTIPASS.
# Peut aussi être relancé manuellement : ./oracle_init_captain_wotx2.sh
#
# License: AGPL-3.0
# Author: Fred (support@qo-op.com)
################################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "${MY_PATH}/my.sh"

## Variables
ORACLE_API="${uSPOT:-http://127.0.0.1:54321}/api/permit"
NOSTR_SEND="${MY_PATH}/nostr_send_note.py"
PLAYER_EMAIL="${CAPTAINEMAIL:-$(cat ~/.zen/game/players/.current/.player 2>/dev/null)}"
PLAYER_KEYFILE=$(find ~/.zen/game/nostr/ -name ".secret.nostr" 2>/dev/null | head -1)

## Compétences capitaines prédéfinies (tag normalisé → description)
declare -A CAPTAIN_SKILLS=(
    ["astroport"]="Opération et administration d'un nœud Astroport UPlanet"
    ["linux"]="Administration système Linux (Debian/Ubuntu/Mint)"
    ["bash"]="Scripting Bash et automatisation shell"
    ["python"]="Développement Python (scripts, APIs, services)"
    ["docker"]="Containerisation Docker et Docker Compose"
    ["dart"]="Développement Dart / Flutter mobile"
    ["flutter"]="Applications Flutter multi-plateformes"
    ["nostr"]="Protocole NOSTR : relays, événements, NIPs"
    ["ipfs"]="IPFS : stockage décentralisé, pinning, IPNS"
    ["git"]="Gestion de versions Git et collaboration"
)

## Ordre d'affichage
SKILL_ORDER=(astroport linux bash python docker dart flutter nostr ipfs git)

################################################################################
check_api() {
    curl -s --max-time 5 "${ORACLE_API}/definitions" > /dev/null 2>&1
}

create_permit_definition() {
    local skill="$1"
    local desc="$2"
    local permit_id="PERMIT_${skill^^}_X1"
    permit_id="${permit_id//-/_}"  # tirets → underscores dans l'ID

    # Vérifier si le permit existe déjà
    existing=$(curl -s --max-time 5 "${ORACLE_API}/definitions" 2>/dev/null \
        | jq -r ".permits[]? | select(.id==\"${permit_id}\") | .id" 2>/dev/null)
    if [[ -n "$existing" ]]; then
        echo "    [OK] ${permit_id} existe déjà"
        return 0
    fi

    # Créer via l'API
    response=$(curl -s -X POST "${ORACLE_API}/define" \
        -H "Content-Type: application/json" \
        -d "{
            \"permit\": {
                \"id\": \"${permit_id}\",
                \"name\": \"${skill^}\",
                \"description\": \"${desc}\",
                \"min_attestations\": 1,
                \"valid_duration_days\": 0,
                \"revocable\": true,
                \"metadata\": {
                    \"category\": \"auto_proclaimed\",
                    \"level\": \"X1\",
                    \"auto_proclaimed\": true,
                    \"skill_tag\": \"${skill}\",
                    \"captain_skill\": true,
                    \"evolving_system\": {
                        \"type\": \"WoTx2_AutoProclaimed\",
                        \"auto_progression\": true
                    }
                }
            },
            \"npub\": null,
            \"bootstrap_emails\": null
        }" 2>/dev/null)

    if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        echo "    [CRÉÉ] ${permit_id}"
    else
        echo "    [WARN] ${permit_id} — ${response:0:80}"
    fi
}

publish_30501_request() {
    local skill="$1"
    local keyfile="$2"
    local permit_id="PERMIT_${skill^^}_X1"
    permit_id="${permit_id//-/_}"

    if [[ ! -f "$keyfile" ]]; then
        echo "    [SKIP] Keyfile absent : ${keyfile}"
        return 1
    fi

    local request_id="req_captain_${skill}_$(date +%s)"
    local content
    content=$(cat <<EOF
{
  "request_id": "${request_id}",
  "permit_definition_id": "${permit_id}",
  "statement": "Je déclare pratiquer et maîtriser la compétence ${skill} dans le cadre de l'opération de mon nœud Astroport UPlanet.",
  "requested_competency": "${skill}",
  "status": "pending"
}
EOF
)
    local tags
    tags=$(cat <<EOF
[
  ["d", "${request_id}"],
  ["l", "${permit_id}", "permit_type"],
  ["t", "permit"],
  ["t", "request"],
  ["t", "${skill}"]
]
EOF
)

    python3 "$NOSTR_SEND" \
        --keyfile "$keyfile" \
        --kind 30501 \
        --content "$content" \
        --tags "$tags" \
        --relay "${NOSTR_RELAY:-ws://127.0.0.1:7777}" \
        > /dev/null 2>&1 && echo "    [30501] Demande publiée → ${permit_id}" \
        || echo "    [WARN] Échec publication 30501 pour ${skill}"
}

################################################################################
echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║              🌐 WoTx2 — COMPÉTENCES CAPITAINE ASTROPORT                    ║"
echo "╠══════════════════════════════════════════════════════════════════════════════╣"
echo "║                                                                              ║"
echo "║  Ce système de Toile de Confiance (WoTx2) permet à la constellation        ║"
echo "║  de valider et faire progresser vos compétences techniques.                 ║"
echo "║                                                                              ║"
echo "║  Chaque compétence commence au niveau X1 (1 attestation requise).           ║"
echo "║  Vos pairs de la constellation peuvent vous attester (adoubement).          ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

## Vérifier l'API
if ! check_api; then
    echo "[WARN] L'API UPassport (port 54321) n'est pas accessible."
    echo "       Assurez-vous que le serveur est démarré avant de relancer ce script."
    echo "       → python3 ~/.zen/UPassport/54321.py &"
    echo ""
    echo "       Vous pourrez créer vos compétences WoTx2 plus tard via :"
    echo "       → http://127.0.0.1:54321/wotx2"
    exit 1
fi

## ÉTAPE 1 : Créer les définitions de permits prédéfinis
echo "[ÉTAPE 1] Initialisation des permits capitaines (kind 30500)..."
for skill in "${SKILL_ORDER[@]}"; do
    desc="${CAPTAIN_SKILLS[$skill]}"
    create_permit_definition "$skill" "$desc"
done
echo ""

## ÉTAPE 2 : Sélection des compétences du capitaine
echo "[ÉTAPE 2] Choisissez vos compétences initiales à déclarer :"
echo "          (Entrez les numéros séparés par des espaces, ex: 1 3 5)"
echo ""

i=1
for skill in "${SKILL_ORDER[@]}"; do
    printf "    [%2d] %-12s — %s\n" "$i" "$skill" "${CAPTAIN_SKILLS[$skill]}"
    ((i++))
done
echo "    [ 0] Tout sélectionner"
echo "    [ a] Ajouter une compétence libre non listée"
echo "    [ q] Ignorer (configurer plus tard via /wotx2)"
echo ""
read -r -p "  Votre choix : " choices

if [[ "$choices" == "q" ]] || [[ "$choices" == "Q" ]]; then
    echo ""
    echo "[INFO] Configuration WoTx2 ignorée."
    echo "       Vous pourrez déclarer vos compétences plus tard via :"
    echo "       → http://127.0.0.1:54321/wotx2"
    exit 0
fi

selected_skills=()
if [[ "$choices" == "0" ]]; then
    selected_skills=("${SKILL_ORDER[@]}")
else
    for num in $choices; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le "${#SKILL_ORDER[@]}" ]]; then
            selected_skills+=("${SKILL_ORDER[$((num-1))]}")
        fi
    done
fi

## Permettre l'ajout de compétences libres (folksonomie)
if [[ "$choices" == "a" ]] || [[ "$choices" == "A" ]] || echo "$choices" | grep -qi '\ba\b'; then
    echo ""
    echo "[ÉTAPE 2b] Entrez vos compétences libres (une par ligne, ligne vide pour terminer) :"
    echo "           Les tags seront normalisés : minuscules, sans accents, tirets (ex: 'Maître Nageur' → 'maitre-nageur')"
    echo ""
    while true; do
        read -r -p "  Compétence libre : " custom_skill
        [[ -z "$custom_skill" ]] && break
        # Normalisation bash : minuscules, suppression accents basique, espaces→tirets
        normalized=$(echo "$custom_skill" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')
        normalized=$(echo "$normalized" | sed 's/-\+/-/g; s/^-//; s/-$//')
        if [[ -n "$normalized" ]]; then
            echo "    → Tag normalisé : '${normalized}'"
            selected_skills+=("$normalized")
            # Ajouter dynamiquement dans CAPTAIN_SKILLS pour la création du permit
            CAPTAIN_SKILLS["$normalized"]="Compétence libre déclarée par le capitaine"
        fi
    done
fi

if [[ ${#selected_skills[@]} -eq 0 ]]; then
    echo "[INFO] Aucune compétence sélectionnée."
    exit 0
fi

## Créer les permits pour les compétences libres ajoutées
for skill in "${selected_skills[@]}"; do
    if [[ -z "${CAPTAIN_SKILLS[$skill]+x}" ]]; then
        CAPTAIN_SKILLS["$skill"]="Compétence libre déclarée par le capitaine"
    fi
    # Créer le permit s'il n'existe pas encore (idempotent)
    create_permit_definition "$skill" "${CAPTAIN_SKILLS[$skill]}" 2>/dev/null
done

## ÉTAPE 3 : Publier les demandes 30501 pour chaque compétence choisie
echo ""
echo "[ÉTAPE 3] Publication de vos déclarations de compétences (kind 30501)..."

if [[ -z "$PLAYER_KEYFILE" ]]; then
    echo "[WARN] Keyfile NOSTR du capitaine non trouvé."
    echo "       Les demandes 30501 ne seront pas publiées automatiquement."
    echo "       Utilisez l'interface web : http://127.0.0.1:54321/wotx2"
else
    echo "    Keyfile : ${PLAYER_KEYFILE}"
    for skill in "${selected_skills[@]}"; do
        publish_30501_request "$skill" "$PLAYER_KEYFILE"
    done
fi

## ÉTAPE 4 : Résumé
echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    ✅ COMPÉTENCES WoTx2 INITIALISÉES                       ║"
echo "╠══════════════════════════════════════════════════════════════════════════════╣"
echo "║                                                                              ║"
echo "║  Compétences déclarées (en attente d'attestation des pairs) :               ║"
for skill in "${selected_skills[@]}"; do
    printf "║    • %-72s║\n" "${skill} → PERMIT_${skill^^}_X1"
done
echo "║                                                                              ║"
echo "║  PROCHAINES ÉTAPES :                                                        ║"
echo "║  1. Partagez votre QR WoTx2 avec des pairs de la constellation.             ║"
echo "║  2. Demandez-leur de vous attester via TrocZen (Règle B) ou 3 likes        ║"
echo "║     (Règle A — Kind 7) pour valider chaque compétence.                     ║"
echo "║                                                                              ║"
echo "║  TABLEAU DE BORD PERSONNEL :                                                ║"
echo "║  → http://127.0.0.1:54321/wotx2                                             ║"
if [[ -n "${myDOMAIN:-}" ]]; then
echo "║  → https://u.${myDOMAIN}/wotx2                                              ║"
fi
echo "║                                                                              ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""
