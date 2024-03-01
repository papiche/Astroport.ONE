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

### List games/E@MAIL/ directories
## ADD PROPOSAL ON THE METHOD
GAMES_DIR="games"
GAMES=$(find "$GAMES_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
GAMES=$(ls $MY_PATH/games/)
GAMES=($(ls -d $MY_PATH/games/))
# Above methods are breaking with games names containing SPACE !

# BASH is CREOLE
# this cd *@* METHOD resist to " " space
cd ${MY_PATH}/games \
    && GAMES=(".." *@*) && cd .. \
    || GAMES=".."
## but can still be fooled by file...

## personalisez le prompt
PS3="CHOIX DU GAME : __ "

select game in "${GAMES[@]}"; do

    # MY_GAME is the absolute path to selected game files
    MY_GAME="$MY_PATH/games/$game"
    echo "SELECTION: "${MY_GAME}

    diff --recursive --brief ${MY_GAME}/ ${MY_GAME}/../_votre\ jeu/

    echo "confirm ?"
    read ENTER

    if [[ ! $ENTER ]]; then
        # test game start protocol compatibility
        if [[ -x ${MY_GAME}/rooms/start.sh ]]; then
                sleep 1
                echo "Charging game..."
                sleep 1
                break
        else
                # not compatible
                echo "ERROR - not compatible game - SELECT ANOTHER - "
        fi
    else
        echo "CHOOSE NEXT"
    fi

done

########################################
# copy game files to user specific executable space
# $HOME/.zen/adventure/$newplayer
########################################
homefolder=$(pwd)
newplayer=$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 10)
## Copy Player Game Files
mkdir -p $HOME/.zen/adventure/$newplayer
cp -r ${MY_GAME}/rooms $HOME/.zen/adventure/$newplayer/rooms
cp -r ${MY_GAME}/art $HOME/.zen/adventure/$newplayer/art
cp -r ${MY_GAME}/script $HOME/.zen/adventure/$newplayer/script
cp -r ${MY_GAME}/logic $HOME/.zen/adventure/$newplayer/logic


###################################################################
echo "Loading... $newplayer/rooms/start.sh"
echo
sleep 2
###################################################################
cd $HOME/.zen/adventure/$newplayer/rooms
./start.sh

###################################################################
# cleaning game files
cd "$homefolder"
rm -r $HOME/.zen/adventure/$newplayer

echo "To continue..."
exit