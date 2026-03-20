#!/bin/bash
# Sauvegarde du répertoire courant au début du script
ORIGINAL_DIR="$PWD"

# Astroport.ONE - task & process scheduler
cd ~/.zen/Astroport.ONE
git pull

# 54321 API
cd ~/.zen/UPassport
git pull

# UPlanet - /ipns/copylaradio.com
cd ~/.zen/workspace/UPlanet
git pull

# NIP101 implementation // strfry plugin rules
cd ~/.zen/workspace/NIP-101
git pull

# OC2UPlanet €/Ẑ interface
cd ~/.zen/workspace/OC2UPlanet
git pull

# Retour au répertoire d'origine
cd "$ORIGINAL_DIR"
