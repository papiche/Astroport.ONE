#!/bin/bash

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

clear
# Initialise the Title Art
file1="$MY_PATH/../art/titleart.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"
echo

# Here's this room's script.

echo "Sur la direction du sud, vous traversez une zone plus sombre et humide."
echo "Le sol est glissant à cause de l'argile qui colle sous vos bottes"
echo "Vous finissez par croiser un chemin qui traverse la forêt d'Est en Ouest"
echo
echo "Un terminal informatique est installé là."
echo
echo "Il ressemble à une grosse calculatrice"


# Here we tell the player whether the lever is on or off.
leverstate=$(cat $MY_PATH/../logic/leverlogic.ben)
            if [ "$leverstate" = "on" ]; then
                echo "'VISA SVP' clignote sur l'écran..."
            else
                echo "La machine affiche l'heure : 20:12"
            fi
echo
echo "Il est tard pour explorer le chemin à pied, vous devriez retourner d'où vous venez."
echo
echo "Que faites vous?"

# In this set of actons lies the logic switch used later in the game.
# You have to set this switch to reach the endgame.
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) ./mainroom.sh
            exit ;;
        s ) echo "Si vous continuez à marcher dans la forêt. Vous allez vous perdre. Demi tour." ;;
        e ) echo "Le chemin qui part à l'Est est plein de boue... Impossble d'aller par là." ;;
        w ) echo "Une rivière vous empêche de passer." ;;
        u ) if [ "$leverstate" = "on" ]; then
                echo "A chaque frappe d'une touche. l'écran fait défiler le texte 'SCANNEZ VISA SVP'."
            else
                sed -i -e '${/^$/d;}' -e 's/off/on/' $MY_PATH/../logic/leverlogic.ben
                echo "Vous pianotez sur l'appareil..."
                echo "A moment où vous touchez la touche '#' L'écran se met à clignoter..."
                echo "Puis le message 'ACTIVATION STATION' défile sur les caractères lumineux."
            fi
            leverstate=$(cat $MY_PATH/../logic/leverlogic.ben)
        ;;
        h ) echo "Le terminal comporte un clavier numérique. Un petit écran.. Il est réalisé avec un mini ordinateur Raspberry Pi. Il porte l'adresse G1TAG [https://g1sms.fr]" ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done

esac
exit
