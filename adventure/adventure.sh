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
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

if hash uuidgen 2>/dev/null; then
homefolder=$(pwd)
newplayer=$(uuidgen)
mkdir -p $HOME/.zen/adventure/$newplayer
cp -r $MY_PATH/rooms $HOME/.zen/adventure/$newplayer/rooms
cp -r $MY_PATH/art $HOME/.zen/adventure/$newplayer/art
cp -r $MY_PATH/script $HOME/.zen/adventure/$newplayer/script
cp -r $MY_PATH/logic $HOME/.zen/adventure/$newplayer/logic
fi

echo "Loading..."
echo
sleep 4
if hash uuidgen 2>/dev/null; then
cd $HOME/.zen/adventure/$newplayer/rooms
else
cd rooms
fi
./start.sh
if hash uuidgen 2>/dev/null; then
cd "$homefolder"
rm -r $HOME/.zen/adventure/$newplayer
fi
echo
exit
