#!/bin/bash
########################################################################
# Version: 0.3
# License: AGPL-3.0
#
# Script pour générer une clé Nostr (hex) à partir de coordonnées sur UPlanet
#
# Usage:
#   ./Umap2hex.sh [latitude] [longitude] [date]
#
# Dépendances:
#   - keygen (outil personnalisé)
#   - nostr2hex.py (script de conversion)
############################################################# Umap2hex.sh
# Chargement des dépendances et variables
SCRIPT_DIR="`dirname \"$0\"`"              # Chemin relatif
SCRIPT_DIR="`( cd \"$SCRIPT_DIR\" && pwd )`"  # Chemin absolu et normalisé
. "$SCRIPT_DIR/my.sh"                      # Chargement des fonctions communes

usage() {
    echo "Usage: $0 [latitude] [longitude] [date]"
    echo "Génère une clé Nostr hex à partir de coordonnées"
    exit 1
}

# Vérification des arguments
[ "$#" -lt 2 ] && usage

# Chemins
KEYGEN="$SCRIPT_DIR/keygen"
NOSTR2HEX="$SCRIPT_DIR/nostr2hex.py"

# Variables principales
ZLAT=$1
ZLON=$2
THEDATE=$3

LAT=$(makecoord ${ZLAT})
LON=$(makecoord ${ZLON})
UMAP="_${LAT}_${LON}"
THEDATE=""

# Génération de la clé Nostr
NPUB=$("$KEYGEN" -t nostr "${DATE}${UPLANETNAME}${LAT}" "${DATE}${UPLANETNAME}${LON}") || {
    echo "Erreur: génération NPUB échouée" >&2
    exit 1
}

# Conversion en hex
HEX=$("$NOSTR2HEX" "$NPUB") || {
    echo "Erreur: conversion hex échouée" >&2
    exit 1
}

# Sortie
echo "$HEX"
