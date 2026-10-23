#!/bin/bash
######################## Ustats.sh
# Wrapper : la génération vit désormais dans UPassport/services/ustats.py
# (carte station + swarm, cache ~/.zen/tmp/Ustats.json). Même contrat qu'avant :
#   Ustats.sh [lat lon deg] [--refresh]  → dernière ligne = chemin du JSON
####################################
UPASSPORT="${UPASSPORT_PATH:-$HOME/.zen/UPassport}"
[[ -d "$UPASSPORT/services" ]] || { echo '{"error": "UPassport introuvable"}'; exit 1; }
cd "$UPASSPORT" && exec "${UPASSPORT_PYTHON:-python3}" -m services.ustats "$@"
