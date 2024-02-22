#!/bin/bash
clear
# Initialise the Title Art
file1="../art/titleart.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"
echo
sleep 1

# Here's this room's script.

echo "Sur la direction du sud, votre Bus vous amène à Saint Pierre."
echo "Chance pour vous, le voyage vous à couter 2€ uniquement et il vous reste 48€."
echo "En plus un deuxième Aéroport ce trouve à Saint Pierre"
echo
echo "Vous arrêter un passant pour lui demander ou aller."
echo
echo "Il vous indique que ou se trouve l'aéroport. Vous devait vous diriger vers PierreFonds."


# Here we tell the player whether the lever is on or off.
leverstate=`cat ../logic/leverlogic.ben`
            if [ "$leverstate" = "on" ]; then
                echo "'VISA SVP' clignote sur l'écran..."
            else
                echo "Vous avez faim"
            fi
echo
echo "Plusieurs choix s'offre à vous."
echo "(n) Respawn"
echo "(e) Faire du stop"
echo "(w) Payer un taxi"
echo "(s) Prendre un autre bus"
echo
echo "Que faites vous?"

# In this set of actons lies the logic switch used later in the game.
# You have to set this switch to reach the endgame.
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) ./mainroom.sh
            exit ;;
        s ) echo "Vous dépenser 2€ et le bus vous dépose à 30 min de l'aéroport ..." ;;
        e ) echo "Un Réunionnais s'arrête et vous dépose à l'aéroport" ;;
        w ) echo "Le  taximan vous taxe tous votre argent et ne vous redépose à Saint Denis car vous ne l'avez pas indiquer la bonne aéroport" ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w ";;
    esac
done

esac
exit

