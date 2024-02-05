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

echo "Vous avez suivi le chemin vers l'est."
echo "Vous tombez nez-à-nez avec une grande porte en métal sur un conteneur."

# Here we tell the player whether the lever is on or off.
leverstatetwo=`cat ../logic/leverlogictwo.ben`
            if [ "$leverstatetwo" = "on" ]; then
                echo "La porte est ouverte..."
            else
                echo "La porte semble vérouillée... Peut-être qu'il est possible de l'ouvrir avec un levier."
            fi
echo
echo "Que voulez-vous faire? Les commandes sont : n, e, s et w."

# In this set of actons lies the logic switch used later in the game.
# You have to set this switch to reach the endgame.
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) echo "Le chemin vers le nord est bloqué par un mur de conteneurs." ;;
        s ) echo "Si vous continuez à marcher dans la forêt. Vous allez vous perdre. Demi tour." ;;
        e ) echo "Le chemin à l'est n'est pas accessible, les arbres vous empêche de passer..." ;;
        w ) ./purple.sh
             exit ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w et u..";;
    esac
done

esac
exit
