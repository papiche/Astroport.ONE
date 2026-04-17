#!/bin/bash
################################################################################
# feed_mirofish.sh - Extracteur NOSTR N² pour MiroFish (Spécifique aux Locaux)
#
# Ce script filtre intelligemment les MULTIPASS (emails) enregistrés localement 
# sur la station, exclut les clés systèmes (UNODE, ZSWARM), extrait leurs 
# derniers messages via strfry, et nourrit le moteur de simulation MiroFish.
#
# License: AGPL-3.0
################################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"
. "$MY_PATH/../tools/my.sh" 2>/dev/null || true

LIMIT=${1:-500} # Nombre de messages par défaut
STRFRY_DIR="$HOME/.zen/strfry"
MIROFISH_DATA_DIR="$HOME/.zen/ai-company/mirofish_data/seeds"

# Couleurs
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🐟 MIROFISH FEEDER : Scan de l'Intelligence Collective N1 ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"

# 1. Vérification et Connexion à MiroFish via mirofish.me.sh
if [[ -x "$MY_PATH/mirofish.me.sh" ]]; then
    echo -e "${YELLOW}🔌 Vérification de la connexion à MiroFish...${NC}"
    if ! "$MY_PATH/mirofish.me.sh" "TEST" >/dev/null 2>&1; then
        "$MY_PATH/mirofish.me.sh" >/dev/null 2>&1
    fi
else
    echo -e "${YELLOW}⚠️ Connecteur mirofish.me.sh non trouvé, tentative en local direct.${NC}"
fi

# 2. Filtrage des MULTIPASS locaux (On ignore UNODE_*, ZSWARM, etc.)
echo -e "${YELLOW}🔍 Recherche des MULTIPASS humains locaux (*@*)...${NC}"
MAP_FILE="$HOME/.zen/tmp/hex_to_name_mirofish.json"
echo "{}" > "$MAP_FILE"

AUTHORS_ARRAY="["
first=true
USER_COUNT=0

for user_dir in ~/.zen/game/nostr/*@*; do
    if [[ -d "$user_dir" && -f "$user_dir/HEX" ]]; then
        hex=$(cat "$user_dir/HEX")
        email=$(basename "$user_dir")
        pseudo=$(echo "$email" | cut -d'@' -f1)
        
        # Ajout à l'array JSON pour la requête strfry
        if [ "$first" = true ]; then
            AUTHORS_ARRAY+="\"$hex\""
            first=false
        else
            AUTHORS_ARRAY+=", \"$hex\""
        fi
        
        # Sauvegarde dans le mapping (HEX -> Pseudo)
        tmp=$(mktemp)
        jq --arg k "$hex" --arg v "$pseudo" '.[$k] = $v' "$MAP_FILE" > "$tmp" && mv "$tmp" "$MAP_FILE"
        ((USER_COUNT++))
    fi
done
AUTHORS_ARRAY+="]"

if [[ "$USER_COUNT" -eq 0 || "$AUTHORS_ARRAY" == "[]" ]]; then
    echo -e "${RED}❌ Aucun MULTIPASS humain enregistré sur cette station.${NC}"
    rm -f "$MAP_FILE"
    exit 0
fi

echo -e "${GREEN}✅ $USER_COUNT MULTIPASS locaux trouvés.${NC}"

# 3. Extraction optimisée via strfry
echo -e "\n${YELLOW}🎣 Extraction des $LIMIT derniers messages (kind 1) pour ces utilisateurs...${NC}"
cd "$STRFRY_DIR" || exit 1
# On demande directement à strfry de filtrer (extrêmement rapide)
QUERY="{\"kinds\":[1], \"authors\":$AUTHORS_ARRAY, \"limit\":$LIMIT}"
RAW_EVENTS=$(./strfry scan "$QUERY" 2>/dev/null)
cd - > /dev/null

if [[ -z "$RAW_EVENTS" ]]; then
    echo -e "${YELLOW}ℹ️  Aucun événement trouvé pour ces utilisateurs.${NC}"
    rm -f "$MAP_FILE"
    exit 0
fi

EVENT_COUNT=$(echo "$RAW_EVENTS" | wc -l)
echo -e "${GREEN}✅ $EVENT_COUNT événements récupérés de la base locale.${NC}"

# 4. Formatage Markdown pour RAG
mkdir -p "$MIROFISH_DATA_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUT_FILE="$MIROFISH_DATA_DIR/social_context_${TIMESTAMP}.md"

echo -e "${YELLOW}⚙️  Formatage des connaissances pour les Agents MiroFish...${NC}"

cat << 'EOF' > "$OUT_FILE"
# CONTEXTE SOCIAL LOCAL (UPLANET N1)
Archives des discussions locales de la station. 
Ceci représente les pensées, besoins et interactions des humains de cette Constellation.

## MESSAGES RÉCENTS :
EOF

# Traitement Python via stdin
echo "$RAW_EVENTS" | python3 -c "
import sys, json, datetime

map_file = '$MAP_FILE'
out_file = '$OUT_FILE'

try:
    with open(map_file, 'r') as f:
        identities = json.load(f)
except:
    identities = {}

valid = 0
with open(out_file, 'a', encoding='utf-8') as out:
    for line in sys.stdin:
        line = line.strip()
        if not line: continue
        try:
            event = json.loads(line)
            content = event.get('content', '').strip()
            if len(content) < 5: continue
            
            pubkey = event.get('pubkey', '')
            author = identities.get(pubkey, f'Astro_{pubkey[:6]}')
            
            dt = datetime.datetime.fromtimestamp(event.get('created_at', 0))
            date_str = dt.strftime('%Y-%m-%d %H:%M')
            
            out.write(f'### Message de {author} ({date_str})\n')
            out.write(f'{content}\n\n---\n\n')
            valid += 1
        except Exception as e:
            pass

print(valid)
" > "$HOME/.zen/tmp/mirofish_parsed_count.txt"

PARSED_COUNT=$(cat "$HOME/.zen/tmp/mirofish_parsed_count.txt")
rm -f "$MAP_FILE" "$HOME/.zen/tmp/mirofish_parsed_count.txt"

echo -e "${GREEN}✅ Fichier RAG généré : $OUT_FILE${NC}"
echo -e "${CYAN}📊 $PARSED_COUNT messages pertinents ont été formatés.${NC}"

# 5. Notification de l'API MiroFish (si accessible localement ou via le tunnel)
MIROFISH_PORT=${PORT_MIROFISH:-5050}
MIROFISH_API="http://localhost:$MIROFISH_PORT/api/v1/documents/sync"

echo -e "${YELLOW}🔔 Notification du moteur MiroFish...${NC}"
if curl -s -o /dev/null -w "%{http_code}" -X POST "$MIROFISH_API" --connect-timeout 2 | grep -q "200"; then
    echo -e "${GREEN}🔄 MiroFish synchronisé via API avec succès !${NC}"
else
    echo -e "${CYAN}ℹ️  L'API de synchro n'a pas répondu. (MiroFish indexera le fichier automatiquement).${NC}"
fi

echo -e "${CYAN}==============================================================${NC}"
echo -e "🧠 Le Mentat a maintenant absorbé le contexte social local de la station."
exit 0