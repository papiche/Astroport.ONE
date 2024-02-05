#!/bin/bash
clear

# This is a repeat of the opening room in the start.sh file - if the player
# wants to go back to the main room, this saves going through the whole
# start script over again.

# Initialise the Title Art
file1="../art/titleart.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"
echo

# Shakesphere wrote this, honest.
sleep 1
echo "Vous êtes de retour à votre point de départ."
echo "La forêt qui vous entoure est immense."
echo "Vous ne pouvez pas vraiment en imaginer la taille,"
echo
echo "Vous pouvez vous diriger au nord, à l'est, au sud et à l'ouest."
echo
echo "Un terminal informatique est installé là."
echo
echo "Il ressemble à une grosse calculatrice"
echo
leverstate=`cat ../logic/leverlogic.ben`
            if [ "$leverstate" = "on" ]; then
                echo "'VISA SVP' clignote sur l'écran..."
            else
                echo "La machine affiche l'heure : 20:12"
            fi
echo
echo "Que voulez-vous faire ?"

# And the room logic once again.
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) ./white.sh
            exit ;;
        s ) ./brown.sh
             exit ;;
        e ) ./red.sh
            exit ;;
        w ) ./green.sh
            exit ;;
        u ) leverstate=`cat ../logic/leverlogic.ben`
            if [ "$leverstate" = "on" ]; then
                echo "A chaque frappe d'une touche. l'écran fait défiler le texte 'SCANNEZ VISA SVP'."
            else
                sed -i='' 's/off/on/' ../logic/leverlogic.ben
                echo "Vous pianotez sur l'appareil..."
                sleep 3
                echo "A moment où vous touchez la touche '#' L'écran se met à clignoter..."
                echo "Puis le message 'ACTIVATION STATION' défile sur les caractères lumineux."
            fi
        ;;
        h ) echo "Le terminal comporte un clavier numérique. Un petit écran.. Il est réalisé avec un mini ordinateur Raspberry Pi. Il porte l'adresse G1TAG [https://g1sms.fr]" ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done

esac
exit
