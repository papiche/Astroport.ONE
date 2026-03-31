#!/bin/bash
########################################################################
# bootstrap_constellation.sh — Initialisation d'une nouvelle station
# 1. Récupère la config globale (30800) de UPLANETNAME_G1
# 2. Découvre les autres Capitaines (30850) via le swarm_id
# 3. Récupère leurs listes de membres (Kind 3)
# 4. Autorise tout le monde (amisOfAmis.txt) et synchronise (backfill)
########################################################################
MY_PATH="$(cd "$(dirname "$0")" && pwd)"
. "${MY_PATH}/tools/my.sh"

# On s'assure d'avoir les outils de config coopérative
source "${MY_PATH}/tools/cooperative_config.sh" 2>/dev/null

echo "🚀 AMORÇAGE DE LA STATION DANS LA CONSTELLATION..."

# --- ÉTAPE 1 : Récupérer la CONFIGURATION COOPÉRATIVE (30800) ---
# C'est ici qu'on récupère la PAF, les Ratios, etc.
echo "📥 Récupération des paramètres globaux (Kind 30800)..."
coop_config_refresh  # Cette fonction de ton script va chercher le 30800 de la Coop

# --- ÉTAPE 2 : Découvrir les pairs via les rapports de santé (30850) ---
echo "🔍 Recherche des stations actives (swarm_id: ${UPLANETG1PUB:0:8})..."
# On cherche les 30850 de cet essaim sur le relai central
STATIONS_JSON=$(python3 "${MY_PATH}/tools/nostr_did_client.py" query \
    --kind 30850 \
    --tag swarm_id "$UPLANETG1PUB" \
    --relay "wss://relay.copylaradio.com" 2>/dev/null)

# --- ÉTAPE 3 : Agrégation des membres et Autorisations ---
echo "👥 Identification des membres de l'essaim..."
TEMP_HEX=$(mktemp)

# Ajouter la clé de la Coopérative elle-même
coop_get_pubkey >> "$TEMP_HEX"

# Ajouter tous les Capitaines trouvés dans les 30850
echo "$STATIONS_JSON" | jq -r '.[].pubkey' >> "$TEMP_HEX"

# Pour chaque Capitaine, on récupère sa liste de contacts (Kind 3)
CAPTAINS=$(echo "$STATIONS_DATA" | jq -r '.[].pubkey' | sort -u)
for cap in $CAPTAINS; do
    log "  → Listing contacts from Captain ${cap:0:8}..."
    python3 -c "
import asyncio, websockets, json, sys
async def get_follows():
    try:
        async with websockets.connect('wss://relay.copylaradio.com') as ws:
            await ws.send(json.dumps(['REQ', 'f', {'kinds': [3], 'authors': ['$cap'], 'limit': 1}]))
            while True:
                resp = await asyncio.wait_for(ws.recv(), timeout=2)
                data = json.loads(resp)
                if data[0] == 'EVENT':
                    for tag in data[2].get('tags', []):
                        if tag[0] == 'p': print(tag[1])
                if data[0] == 'EOSE': break
    except: pass
asyncio.run(get_follows())
" >> "$TEMP_HEX" 2>/dev/null
done

# --- ÉTAPE 4 : Mise à jour de la sécurité et Synchronisation ---
if [[ -s "$TEMP_HEX" ]]; then
    sort -u "$TEMP_HEX" -o "$TEMP_HEX"
    M_COUNT=$(wc -l < "$TEMP_HEX")
    echo "✅ $M_COUNT membres identifiés."
    
    # Autoriser ces clés dans le relai local (indispensable pour que le backfill soit accepté)
    cat "$TEMP_HEX" >> ~/.zen/strfry/amisOfAmis.txt
    sort -u ~/.zen/strfry/amisOfAmis.txt -o ~/.zen/strfry/amisOfAmis.txt
    
    # Lancer le backfill ciblé pour ramener les contenus (Profils, DIDs, Notes)
    echo "🔄 Lancement de la synchronisation des données (Backfill)..."
    bash "${MY_PATH}/backfill_constellation.sh" --days 30 --verbose
else
    echo "❌ Aucune donnée trouvée sur le relai central."
fi

rm -f "$TEMP_HEX"
echo "✨ Bootstrap terminé. Station synchronisée."