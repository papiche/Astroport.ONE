#!/bin/bash
clear
# Initialise the Title Art
file1="../art/titleart.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"
echo

#Setting up the room...
sleep 1
echo "Vous zntrée dans le taxi en direction du nord.."
echo "Vous n'avez que 50 euros avec vous"
echo "Le taximan peut vous rapprocher de l'aéroport et vous amener à Sainte Clotilde"
echo "Vous accepter et vous rapprocher considérablement de l'aéroport"
echo
echo "Une fois à Saint Clotilde, vous êtes pris par de Kaniar de rue"
echo "Il vous encercle dans une ruelle sans issu"
echo
# Here we're going to check to see if the lever - the only logic we are using in this game - is on or off.
leverstate=`cat ../logic/leverlogic.ben`
            if [ "$leverstate" = "on" ]; then
                echo "Une poignée est apparue sur la porte de la façade..."
            else
                echo "Vous êtes pris au piège"
                echo "Aucune entrée n'est visible."
            fi
echo
echo "Pas d'autre chemin praticable que celui d'où vous venez."
echo
echo "Que voulez-vous faire ?"
echo "(n) sortir un couteau"
echo "(e) se battre"
echo "(w) fuire"
echo "(s) respawn"

# Now lets capture this room's actions. Note that here, the actions change depending on whether or not
# the lever is on or off. If it's on, you go elsewhere. If it's off, you don't.
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) echo " Les kaniars vous encercle en nombre et vous tabasse ... " ;;
        s ) ./mainroom.sh
            exit ;;
        e ) echo " Les kaniars vous encercle en nombre et vous tabasse ... " ;;
        w ) echo "Vous courrez sans pouvoir trouver une échappatoire. Les kaniars vous encercle en nombre et vous tabasse ..." ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w ";;
    esac
done

esac
exit
