#!/bin/bash
########################################################################
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
#
# Script pour générer les liens géographiques entre UMAPs adjacentes
#
# Usage:
#   ./generate_geolinks.sh [latitude] [longitude]
#
# Description:
#   Ce script calcule les UMAPs adjacentes (nord, sud, est, ouest, etc.)
#   et génère un fichier JSON contenant les liens IPNS vers ces UMAPs.
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
  date        (Optionnel) Date de référence pour la génération des clés

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
THEDATE=$3

LAT=$(makecoord ${ZLAT})
LON=$(makecoord ${ZLON})
UMAP="_${LAT}_${LON}"
THEDATE=""

# Vérification du répertoire de travail
if [[ ! -d "$HOME/.zen/tmp/${UMAP}" ]]; then
    echo "ERREUR : Missing : ~/.zen/tmp/${UMAP} directory" >&2
    exit 1
fi

[[ -s ~/.zen/tmp/${UMAP}/ipfs_geolinks.json ]] \
    && cat ~/.zen/tmp/${UMAP}/ipfs_geolinks.json \
    && exit 0

# Fonction pour générer une UMAP adjacente
# Paramètres:
#   $1 - Type de direction (pour le logging)
#   $2 - Latitude ajustée
#   $3 - Longitude ajustée
generate_adjacent_umap() {
    local direction=$1
    local adj_lat=$2
    local adj_lon=$3

    key_file=~/.zen/tmp/keyfile.key

    # Génération de l'adresse Duniter
    local wallet=$(${MY_PATH}/keygen -t duniter "${THEDATE}${UPLANETNAME}$adj_lat" "${THEDATE}${UPLANETNAME}$adj_lon")
    [[ ! ${wallet} ]] && echo "ERREUR lors de la génération de ${direction} WALLET" >&2 && exit 1

    # Nettoyage et génération de la clé IPFS
    ipfs key rm ${wallet} > /dev/null 2>&1 # Évite les erreurs lors de l'import
    ${MY_PATH}/keygen -t ipfs -o ${key_file} "${THEDATE}${UPLANETNAME}$adj_lat" "${THEDATE}${UPLANETNAME}$adj_lon"
    local umap_ns=$(ipfs key import ${wallet} -f pem-pkcs8-cleartext ${key_file})
    ipfs key rm ${wallet} > /dev/null 2>&1

    rm ~/.zen/tmp/keyfile.key
    echo ${umap_ns}/${wallet}
}


UMAPNS=$(generate_adjacent_umap "HERE" "$LAT" "$LON")

##############################################################
## CALCUL DES UMAPS ADJACENTES
##############################################################

# Nord
NLAT=$(echo "${LAT} + 0.01" | bc)
NLON="${LON}"
NUMAPNS=$(generate_adjacent_umap "NORTH" "$NLAT" "$NLON")

# Sud
SLAT=$(echo "${LAT} - 0.01" | bc)
SLON="${LON}"
SUMAPNS=$(generate_adjacent_umap "SOUTH" "$SLAT" "$SLON")

# Ouest
WLAT="${LAT}"
WLON=$(echo "${LON} - 0.01" | bc)
WUMAPNS=$(generate_adjacent_umap "WEST" "$WLAT" "$WLON")

# Est
ELAT="${LAT}"
ELON=$(echo "${LON} + 0.01" | bc)
EUMAPNS=$(generate_adjacent_umap "EAST" "$ELAT" "$ELON")

# Sud-Ouest
SWLAT=$(echo "${LAT} - 0.01" | bc)
SWLON=$(echo "${LON} - 0.01" | bc)
SWUMAPNS=$(generate_adjacent_umap "SOUTH WEST" "$SWLAT" "$SWLON")

# Nord-Ouest
NWLAT=$(echo "${LAT} + 0.01" | bc)
NWLON=$(echo "${LON} - 0.01" | bc)
NWUMAPNS=$(generate_adjacent_umap "NORTH WEST" "$NWLAT" "$NWLON")

# Nord-Est
NELAT=$(echo "${LAT} + 0.01" | bc)
NELON=$(echo "${LON} + 0.01" | bc)
NEUMAPNS=$(generate_adjacent_umap "NORTH EAST" "$NELAT" "$NELON")

# Sud-Est
SELAT=$(echo "${LAT} - 0.01" | bc)
SELON=$(echo "${LON} + 0.01" | bc)
SEUMAPNS=$(generate_adjacent_umap "SOUTH EAST" "$SELAT" "$SELON")

##############################################################
## GENERATION DU FICHIER GEOJSON
##############################################################

jq -n \
  --arg north "${myIPFS}/ipns/${NUMAPNS}" \
  --arg south "${myIPFS}/ipns/${SUMAPNS}" \
  --arg east "${myIPFS}/ipns/${EUMAPNS}" \
  --arg west "${myIPFS}/ipns/${WUMAPNS}" \
  --arg northeast "${myIPFS}/ipns/${NEUMAPNS}" \
  --arg northwest "${myIPFS}/ipns/${NWUMAPNS}" \
  --arg southeast "${myIPFS}/ipns/${SEUMAPNS}" \
  --arg southwest "${myIPFS}/ipns/${SWUMAPNS}" \
  --arg here "${myIPFS}/ipns/${UMAPNS}" \
  '{north: $north, south: $south, east: $east, west: $west, northeast: $northeast, northwest: $northwest, southeast: $southeast, southwest: $southwest, here: $here}' \
  > ~/.zen/tmp/${UMAP}/ipfs_geolinks.json

cat ~/.zen/tmp/${UMAP}/ipfs_geolinks.json

exit 0

