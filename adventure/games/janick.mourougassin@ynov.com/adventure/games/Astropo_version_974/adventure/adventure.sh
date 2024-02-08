#!/bin/bash
###################################################################
# This Launch script is based on BashVenture.
#
# Remember, kids - sharing is caring! Keep it open. Spread the love.
#                                                      - @BenNunney
# Thanks and gratitude to all living creatures and the whole creation.
#                                                      - @Fred
# $AGE×365,25×24×60×60×9,807÷299792458 = RELATIVE LIGHT GRAVITY SPEED
###################################################################
# Guide avancé d'écriture des scripts Bash : https://abs.traduc.org/abs-fr/
# GAMESHELL : https://github.com/phyver/GameShell/
###################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
###################################################################
### CREER VOTRE PROPRE VERSION DU JEU
### CHOISIR SCENARIO

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
