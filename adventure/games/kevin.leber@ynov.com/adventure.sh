#!/bin/bash
###################################################################
# This Launch script is based on BashVenture.
# It runs on Astroport Stations and allow players to create their own digital stories
# First you have to install IPFS in order to play with everyone in the same network
#
# Remember, kids - sharing is caring! Keep it open. Spread the love.
#                                                      - @BenNunney
# Thanks and gratitude to all living creatures and the whole creation.
#                                                      - @Fred
# $AGE×365,25×24×60×60×9,807÷299792458 = RELATIVE LIGHT GRAVITY SPEED
###################################################################
# Here we check to see if uuidgen is installed - if not it will default to single-user mode. To run this on a server
# and support multipe-users, check you have everything set up correctly.
# Read the original instructions  : https://github.com/apetro/BashVenture/blob/master/README.md
###################################################################
# Guide avancé d'écriture des scripts Bash : https://abs.traduc.org/abs-fr/
###################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
###################################################################
if hash uuidgen 2>/dev/null; then
    homefolder=$(pwd)
    newplayer=$(uuidgen)
    ## Copy Player Game Files
    mkdir -p $HOME/.zen/adventure/$newplayer
    cp -r $MY_PATH/rooms $HOME/.zen/adventure/$newplayer/rooms
    cp -r $MY_PATH/art $HOME/.zen/adventure/$newplayer/art
    cp -r $MY_PATH/script $HOME/.zen/adventure/$newplayer/script
    cp -r $MY_PATH/logic $HOME/.zen/adventure/$newplayer/logic
fi
###################################################################
echo "Loading..."
echo
sleep 4
###################################################################
if hash uuidgen 2>/dev/null; then
    cd $HOME/.zen/adventure/$newplayer/rooms
else
    cd rooms
fi
./start.sh
###################################################################
if hash uuidgen 2>/dev/null; then
    cd "$homefolder"
    rm -r $HOME/.zen/adventure/$newplayer
fi
echo "To continue..."
exit
