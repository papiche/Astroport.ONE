#!/bin/bash

# This Launch script is based on BashVenture. https://github.com/apetro/BashVenture
# It runs on Astroport Stations and allow players to create their own digital stories
# First you have to install IPFS in order to play with everyone in the same network
#
# Remember, kids - sharing is caring! Keep it open. Spread the love.
#                                                      - @BenNunney
# Thanks and gratitude to all living creatures and the whole creation.
#                                                      - @Fred

# Here we check to see if uuidgen is installed - if not it will default to single-user mode. To run this on a server
# and support multipe-users, check you have everthing set up correctly. Follow the instructions in the ReadMe file on GitHub.


if hash uuidgen 2>/dev/null; then
homefolder=$(pwd)
newplayer=$(uuidgen)
mkdir -p $HOME/.zen/tmp/adventure/$newplayer
cp -r rooms $HOME/.zen/tmp/adventure/$newplayer/rooms
cp -r art $HOME/.zen/tmp/adventure/$newplayer/art
cp -r script $HOME/.zen/tmp/adventure/$newplayer/script
cp -r logic $HOME/.zen/tmp/adventure/$newplayer/logic
fi

echo "Loading..."
echo
sleep 4
if hash uuidgen 2>/dev/null; then
cd $HOME/.zen/tmp/adventure/$newplayer/rooms
else
cd rooms
fi
./start.sh
if hash uuidgen 2>/dev/null; then
cd "$homefolder"
rm -r $HOME/.zen/tmp/adventure/$newplayer
fi
echo
exit
