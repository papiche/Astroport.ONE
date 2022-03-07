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

if [[ ! -d ~/.zen/game/rooms ]]; then
mkdir -p $newgame

cp -r rooms $newgame/rooms
cp -r art $newgame/art
cp -r script $newgame/script
cp -r logic $newgame/logic
cp -r tools $newgame/tools

fi

echo "Chargement..."
echo
sleep 3

cd $newgame/rooms
./start.sh

cd "$homefolder"
rm -r $newgame

echo
exit
