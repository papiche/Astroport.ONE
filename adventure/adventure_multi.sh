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
    mkdir -p $HOME/.zen/adventure_multi/$newplayer
    cp -r $MY_PATH/games/moussa.thiam@ynov.com/rooms $HOME/.zen/adventure_multi/$newplayer/rooms
    cp -r $MY_PATH/games/moussa.thiam@ynov.com/art $HOME/.zen/adventure_multi/$newplayer/art
    cp -r $MY_PATH/games/moussa.thiam@ynov.com/script $HOME/.zen/adventure_multi/$newplayer/script
    cp -r $MY_PATH/games/moussa.thiam@ynov.com/logic $HOME/.zen/adventure_multi/$newplayer/logic
fi
###################################################################
echo "Loading..."
echo
sleep 4
###################################################################
if hash uuidgen 2>/dev/null; then
    cd $HOME/.zen/adventure_multi/$newplayer/rooms
else
    cd rooms
fi
./start.sh
###################################################################
if hash uuidgen 2>/dev/null; then
    cd "$homefolder"
    rm -r $HOME/.zen/adventure_multi/$newplayer
fi
echo "To continue..."
exit
