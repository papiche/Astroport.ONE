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

## Most methods are breaking with games names containing SPACE !
GAMES=$(find "$GAMES_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
GAMES=$(ls $MY_PATH/games/)
GAMES=($(ls $MY_PATH/games/))

## cd
cd games
GAMES=(".." *) #create table
cd - ## go back

select game in "${GAMES[@]}"; do

    MY_GAME="$MY_PATH/games/$game"
    echo "SELECTION: "${MY_GAME}

    if [[ -x ${MY_GAME}/rooms/start.sh ]]; then
            sleep 1
            echo "Charging game..."
            sleep 1
            break
    else
            echo "ERROR - invalid game - choose another one - "
    fi

done

###################################################################
if hash uuidgen 2>/dev/null; then
    homefolder=$(pwd)
    newplayer=$(uuidgen)
    ## Copy Player Game Files
    mkdir -p $HOME/.zen/adventure/$newplayer
    cp -r ${MY_GAME}/rooms $HOME/.zen/adventure/$newplayer/rooms
    cp -r ${MY_GAME}/art $HOME/.zen/adventure/$newplayer/art
    cp -r ${MY_GAME}/script $HOME/.zen/adventure/$newplayer/script
    cp -r ${MY_GAME}/logic $HOME/.zen/adventure/$newplayer/logic
else
    echo "missing uuidgen. EXIT"
    exit 1
fi
###################################################################
echo "Loading..."
echo
sleep 2
###################################################################
if hash uuidgen 2>/dev/null; then
    cd $HOME/.zen/adventure/$newplayer/rooms
    ./start.sh
fi
###################################################################
# cleaning game files
if hash uuidgen 2>/dev/null; then
    cd "$homefolder"
    rm -r $HOME/.zen/adventure/$newplayer
fi
echo "To continue..."
exit
