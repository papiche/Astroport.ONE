#!/bin/bash
########################################################################
# Version: 0.4
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
#
# Script pour générer les liens géographiques entre UMAPs, SECTORs et REGIONs
#
# Usage:
#   ./Umap_geonostr.sh [latitude] [longitude]
#
# Description:
#   Ce script calcule les UMAPs adjacentes (0.01°), SECTORs (0.1°) et REGIONs (1°)
#   et génère un fichier JSON contenant les liens HEX de ces entités géographiques.
#
# Dépendances:
#   - jq (pour la génération du JSON)
#   - ipfs (pour la gestion des clés)
#   - keygen (outil personnalisé pour générer les clés)
#   - bc (pour les calculs mathématiques)
########################################################################

# Fonction d'aide
usage() {
    cat <<EOF
Usage: $0 [latitude] [longitude] [date]

Ce script génère les liens géographiques entre UMAPs adjacentes.

Arguments:
  latitude    Latitude de l'UMAP centrale (format décimal)
  longitude   Longitude de l'UMAP centrale (format décimal)

Exemple:
  $0 48.8566 2.3522
  $0 48.8566 2.3522 20230101
EOF
    exit 1
}

# Vérification des arguments
if [ "$#" -ne 2 ]; then
    usage
fi

# Chargement des dépendances et variables
MY_PATH="`dirname \"$0\"`"              # Chemin relatif
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # Chemin absolu et normalisé
. "$MY_PATH/my.sh"                      # Chargement des fonctions communes

# Variables principales
ZLAT=$1
ZLON=$2
LAT=$(makecoord ${ZLAT})
LON=$(makecoord ${ZLON})

if [[ ! ${LAT} || ! ${LON} ]]; then
    echo "ERREUR: Format invalide pour LAT ($LAT) ou LON ($LON)" >&2
    exit 1
fi

UMAP="_${LAT}_${LON}"
THEDATE=""

# Calcul des coordonnées SECTOR (0.1°) et REGION (1°) du centre
SLAT="${LAT::-1}"  # Enlever le dernier chiffre pour SECTOR (ex: 43.61 -> 43.6)
SLON="${LON::-1}"
SECTOR="_${SLAT}_${SLON}"

RLAT=$(echo ${LAT} | cut -d '.' -f 1)  # Partie entière pour REGION (ex: 43.61 -> 43)
RLON=$(echo ${LON} | cut -d '.' -f 1)
REGION="_${RLAT}_${RLON}"

# Création de l'arborescence de cache hiérarchique
BASE_CACHE_DIR="$HOME/.zen/tmp/coucou"
REGION_CACHE_DIR="${BASE_CACHE_DIR}/regions"
SECTOR_CACHE_DIR="${BASE_CACHE_DIR}/sectors"
UMAP_CACHE_DIR="${BASE_CACHE_DIR}/umaps"

mkdir -p "$REGION_CACHE_DIR" "$SECTOR_CACHE_DIR" "$UMAP_CACHE_DIR"

# Fichier de cache final
FINAL_CACHE_DIR="${BASE_CACHE_DIR}${UMAP}"
mkdir -p "$FINAL_CACHE_DIR"
FINAL_CACHE_FILE="$FINAL_CACHE_DIR/nostr_geolinks.json"

# Si le cache final existe, le retourner (cache permanent car calcul déterministe)
if [[ -s "$FINAL_CACHE_FILE" ]]; then
    cat "$FINAL_CACHE_FILE"
    exit 0
fi

# Fonction pour générer ou récupérer une UMAP depuis le cache (0.01°)
# Paramètres:
#   $1 - Type de direction (pour le logging)
#   $2 - Latitude ajustée
#   $3 - Longitude ajustée
generate_adjacent_umap() {
    local direction=$1
    local adj_lat=$2
    local adj_lon=$3
    
    local umap_id="_${adj_lat}_${adj_lon}"
    local cache_file="${UMAP_CACHE_DIR}${umap_id}.cache"
    
    # Vérifier si le cache existe
    if [[ -s "$cache_file" ]]; then
        cat "$cache_file"
        return 0
    fi

    # Génération de l'adresse Nostr pour UMAP
    local npub=$(${MY_PATH}/keygen -t nostr "${THEDATE}${UPLANETNAME}$adj_lat" "${THEDATE}${UPLANETNAME}$adj_lon")
    [[ ! ${npub} ]] && echo "ERREUR lors de la génération de ${direction} UMAP NOSTR" >&2 && exit 1

    local hex=$(${MY_PATH}/nostr2hex.py "${npub}")
    [[ ! ${hex} ]] && echo "ERREUR lors de la génération de ${direction} UMAP HEX" >&2 && exit 1

    # Sauvegarder dans le cache
    echo "${hex}" > "$cache_file"
    
    echo ${hex}
}

# Fonction pour générer ou récupérer une clé SECTOR depuis le cache (0.1°)
# Paramètres:
#   $1 - Type de direction (pour le logging)
#   $2 - Latitude du secteur (déjà calculée en 0.1°)
#   $3 - Longitude du secteur (déjà calculée en 0.1°)
generate_adjacent_sector() {
    local direction=$1
    local sector_lat=$2
    local sector_lon=$3
    
    # Format SECTOR: _45.7_1.2
    local sector_id="_${sector_lat}_${sector_lon}"
    local cache_file="${SECTOR_CACHE_DIR}${sector_id}.cache"
    
    # Vérifier si le cache existe
    if [[ -s "$cache_file" ]]; then
        cat "$cache_file"
        return 0
    fi
    
    # Génération de la clé Nostr pour SECTOR (même pattern pour salt et pepper)
    local npub=$(${MY_PATH}/keygen -t nostr "${THEDATE}${UPLANETNAME}${sector_id}" "${THEDATE}${UPLANETNAME}${sector_id}")
    [[ ! ${npub} ]] && echo "ERREUR lors de la génération de ${direction} SECTOR NOSTR" >&2 && exit 1

    local hex=$(${MY_PATH}/nostr2hex.py "${npub}")
    [[ ! ${hex} ]] && echo "ERREUR lors de la génération de ${direction} SECTOR HEX" >&2 && exit 1

    # Sauvegarder dans le cache
    echo "${hex}" > "$cache_file"

    echo ${hex}
}

# Fonction pour générer ou récupérer une clé REGION depuis le cache (1°)
# Paramètres:
#   $1 - Type de direction (pour le logging)
#   $2 - Latitude de la région (déjà calculée en 1°)
#   $3 - Longitude de la région (déjà calculée en 1°)
generate_adjacent_region() {
    local direction=$1
    local region_lat=$2
    local region_lon=$3
    
    # Format REGION: _45_1
    local region_id="_${region_lat}_${region_lon}"
    local cache_file="${REGION_CACHE_DIR}${region_id}.cache"
    
    # Vérifier si le cache existe
    if [[ -s "$cache_file" ]]; then
        cat "$cache_file"
        return 0
    fi
    
    # Génération de la clé Nostr pour REGION (même pattern pour salt et pepper)
    local npub=$(${MY_PATH}/keygen -t nostr "${THEDATE}${UPLANETNAME}${region_id}" "${THEDATE}${UPLANETNAME}${region_id}")
    [[ ! ${npub} ]] && echo "ERREUR lors de la génération de ${direction} REGION NOSTR" >&2 && exit 1

    local hex=$(${MY_PATH}/nostr2hex.py "${npub}")
    [[ ! ${hex} ]] && echo "ERREUR lors de la génération de ${direction} REGION HEX" >&2 && exit 1

    # Sauvegarder dans le cache
    echo "${hex}" > "$cache_file"

    echo ${hex}
}


##############################################################
## CALCUL DES UMAPS, SECTORS ET REGIONS
##############################################################

# Centre (HERE)
UMAPNS=$(generate_adjacent_umap "HERE" "$LAT" "$LON")
SECTORNS=$(generate_adjacent_sector "HERE" "$SLAT" "$SLON")
REGIONNS=$(generate_adjacent_region "HERE" "$RLAT" "$RLON")

# Nord (+0.01 pour UMAP, +0.1 pour SECTOR, +1 pour REGION)
UMAP_NLAT=$(echo "${LAT} + 0.01" | bc)
UMAP_NLON="${LON}"
NUMAPNS=$(generate_adjacent_umap "NORTH" "$UMAP_NLAT" "$UMAP_NLON")

SECTOR_NLAT=$(echo "${SLAT} + 0.1" | bc)
SECTOR_NLON="${SLON}"
NSECTORNS=$(generate_adjacent_sector "NORTH" "$SECTOR_NLAT" "$SECTOR_NLON")

REGION_NLAT=$(echo "${RLAT} + 1" | bc)
REGION_NLON="${RLON}"
NREGIONNS=$(generate_adjacent_region "NORTH" "$REGION_NLAT" "$REGION_NLON")

# Sud (-0.01 pour UMAP, -0.1 pour SECTOR, -1 pour REGION)
UMAP_SLAT=$(echo "${LAT} - 0.01" | bc)
UMAP_SLON="${LON}"
SUMAPNS=$(generate_adjacent_umap "SOUTH" "$UMAP_SLAT" "$UMAP_SLON")

SECTOR_SLAT=$(echo "${SLAT} - 0.1" | bc)
SECTOR_SLON="${SLON}"
SSECTORNS=$(generate_adjacent_sector "SOUTH" "$SECTOR_SLAT" "$SECTOR_SLON")

REGION_SLAT=$(echo "${RLAT} - 1" | bc)
REGION_SLON="${RLON}"
SREGIONNS=$(generate_adjacent_region "SOUTH" "$REGION_SLAT" "$REGION_SLON")

# Ouest
UMAP_WLAT="${LAT}"
UMAP_WLON=$(echo "${LON} - 0.01" | bc)
WUMAPNS=$(generate_adjacent_umap "WEST" "$UMAP_WLAT" "$UMAP_WLON")

SECTOR_WLAT="${SLAT}"
SECTOR_WLON=$(echo "${SLON} - 0.1" | bc)
WSECTORNS=$(generate_adjacent_sector "WEST" "$SECTOR_WLAT" "$SECTOR_WLON")

REGION_WLAT="${RLAT}"
REGION_WLON=$(echo "${RLON} - 1" | bc)
WREGIONNS=$(generate_adjacent_region "WEST" "$REGION_WLAT" "$REGION_WLON")

# Est
UMAP_ELAT="${LAT}"
UMAP_ELON=$(echo "${LON} + 0.01" | bc)
EUMAPNS=$(generate_adjacent_umap "EAST" "$UMAP_ELAT" "$UMAP_ELON")

SECTOR_ELAT="${SLAT}"
SECTOR_ELON=$(echo "${SLON} + 0.1" | bc)
ESECTORNS=$(generate_adjacent_sector "EAST" "$SECTOR_ELAT" "$SECTOR_ELON")

REGION_ELAT="${RLAT}"
REGION_ELON=$(echo "${RLON} + 1" | bc)
EREGIONNS=$(generate_adjacent_region "EAST" "$REGION_ELAT" "$REGION_ELON")

# Sud-Ouest
UMAP_SWLAT=$(echo "${LAT} - 0.01" | bc)
UMAP_SWLON=$(echo "${LON} - 0.01" | bc)
SWUMAPNS=$(generate_adjacent_umap "SOUTH WEST" "$UMAP_SWLAT" "$UMAP_SWLON")

SECTOR_SWLAT=$(echo "${SLAT} - 0.1" | bc)
SECTOR_SWLON=$(echo "${SLON} - 0.1" | bc)
SWSECTORNS=$(generate_adjacent_sector "SOUTH WEST" "$SECTOR_SWLAT" "$SECTOR_SWLON")

REGION_SWLAT=$(echo "${RLAT} - 1" | bc)
REGION_SWLON=$(echo "${RLON} - 1" | bc)
SWREGIONNS=$(generate_adjacent_region "SOUTH WEST" "$REGION_SWLAT" "$REGION_SWLON")

# Nord-Ouest
UMAP_NWLAT=$(echo "${LAT} + 0.01" | bc)
UMAP_NWLON=$(echo "${LON} - 0.01" | bc)
NWUMAPNS=$(generate_adjacent_umap "NORTH WEST" "$UMAP_NWLAT" "$UMAP_NWLON")

SECTOR_NWLAT=$(echo "${SLAT} + 0.1" | bc)
SECTOR_NWLON=$(echo "${SLON} - 0.1" | bc)
NWSECTORNS=$(generate_adjacent_sector "NORTH WEST" "$SECTOR_NWLAT" "$SECTOR_NWLON")

REGION_NWLAT=$(echo "${RLAT} + 1" | bc)
REGION_NWLON=$(echo "${RLON} - 1" | bc)
NWREGIONNS=$(generate_adjacent_region "NORTH WEST" "$REGION_NWLAT" "$REGION_NWLON")

# Nord-Est
UMAP_NELAT=$(echo "${LAT} + 0.01" | bc)
UMAP_NELON=$(echo "${LON} + 0.01" | bc)
NEUMAPNS=$(generate_adjacent_umap "NORTH EAST" "$UMAP_NELAT" "$UMAP_NELON")

SECTOR_NELAT=$(echo "${SLAT} + 0.1" | bc)
SECTOR_NELON=$(echo "${SLON} + 0.1" | bc)
NESECTORNS=$(generate_adjacent_sector "NORTH EAST" "$SECTOR_NELAT" "$SECTOR_NELON")

REGION_NELAT=$(echo "${RLAT} + 1" | bc)
REGION_NELON=$(echo "${RLON} + 1" | bc)
NEREGIONNS=$(generate_adjacent_region "NORTH EAST" "$REGION_NELAT" "$REGION_NELON")

# Sud-Est
UMAP_SELAT=$(echo "${LAT} - 0.01" | bc)
UMAP_SELON=$(echo "${LON} + 0.01" | bc)
SEUMAPNS=$(generate_adjacent_umap "SOUTH EAST" "$UMAP_SELAT" "$UMAP_SELON")

SECTOR_SELAT=$(echo "${SLAT} - 0.1" | bc)
SECTOR_SELON=$(echo "${SLON} + 0.1" | bc)
SESECTORNS=$(generate_adjacent_sector "SOUTH EAST" "$SECTOR_SELAT" "$SECTOR_SELON")

REGION_SELAT=$(echo "${RLAT} - 1" | bc)
REGION_SELON=$(echo "${RLON} + 1" | bc)
SEREGIONNS=$(generate_adjacent_region "SOUTH EAST" "$REGION_SELAT" "$REGION_SELON")

##############################################################
## GENERATION DU FICHIER JSON FINAL
##############################################################

# Créer un JSON structuré avec UMAPS, SECTORS et REGIONS
jq -n \
  --arg umap_north "${NUMAPNS}" \
  --arg umap_south "${SUMAPNS}" \
  --arg umap_east "${EUMAPNS}" \
  --arg umap_west "${WUMAPNS}" \
  --arg umap_northeast "${NEUMAPNS}" \
  --arg umap_northwest "${NWUMAPNS}" \
  --arg umap_southeast "${SEUMAPNS}" \
  --arg umap_southwest "${SWUMAPNS}" \
  --arg umap_here "${UMAPNS}" \
  --arg sector_north "${NSECTORNS}" \
  --arg sector_south "${SSECTORNS}" \
  --arg sector_east "${ESECTORNS}" \
  --arg sector_west "${WSECTORNS}" \
  --arg sector_northeast "${NESECTORNS}" \
  --arg sector_northwest "${NWSECTORNS}" \
  --arg sector_southeast "${SESECTORNS}" \
  --arg sector_southwest "${SWSECTORNS}" \
  --arg sector_here "${SECTORNS}" \
  --arg region_north "${NREGIONNS}" \
  --arg region_south "${SREGIONNS}" \
  --arg region_east "${EREGIONNS}" \
  --arg region_west "${WREGIONNS}" \
  --arg region_northeast "${NEREGIONNS}" \
  --arg region_northwest "${NWREGIONNS}" \
  --arg region_southeast "${SEREGIONNS}" \
  --arg region_southwest "${SWREGIONNS}" \
  --arg region_here "${REGIONNS}" \
  '{
    umaps: {
      north: $umap_north,
      south: $umap_south,
      east: $umap_east,
      west: $umap_west,
      northeast: $umap_northeast,
      northwest: $umap_northwest,
      southeast: $umap_southeast,
      southwest: $umap_southwest,
      here: $umap_here
    },
    sectors: {
      north: $sector_north,
      south: $sector_south,
      east: $sector_east,
      west: $sector_west,
      northeast: $sector_northeast,
      northwest: $sector_northwest,
      southeast: $sector_southeast,
      southwest: $sector_southwest,
      here: $sector_here
    },
    regions: {
      north: $region_north,
      south: $region_south,
      east: $region_east,
      west: $region_west,
      northeast: $region_northeast,
      northwest: $region_northwest,
      southeast: $region_southeast,
      southwest: $region_southwest,
      here: $region_here
    }
  }' > "$FINAL_CACHE_FILE"

# Afficher le résultat
cat "$FINAL_CACHE_FILE"

exit 0

