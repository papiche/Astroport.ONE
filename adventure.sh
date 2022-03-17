#!/bin/bash

# This Launch script is based on BashVenture.
# It runs on Astroport Stations and allow players to create their own digital stories
# First you have to install IPFS in order to play with everyone in the same network
#
# Remember, kids - sharing is caring! Keep it open. Spread the love.
#                                                      - @BenNunney
# Thanks and gratitude to all living creatures and the whole creation.
#                                                      - @Fred

homefolder=$(pwd)
newgame="$HOME/.zen/game"
mkdir -p $newgame

[[ -d  "$HOME/.zen/worlds" ]] &&  echo "Ambassade active - Astroport ONE - Le Menu" && ./start.sh && echo && exit

echo "Chargement..."
echo
sleep 3

cd "$homefolder/rooms"
./start.sh

echo
exit
