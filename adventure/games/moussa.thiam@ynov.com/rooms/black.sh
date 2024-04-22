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

echo "En prenant le sud Est, vous vous dirigez vers un zoo."
echo "N'amenez pas de nourriture avec vous car les animaux peuvent être attirés par l'odeur "
echo "Tout est presque numérique ici."
echo
echo "Un ordinateur est installé devant l'entrée."
echo
echo " Vous pouvez scanner votre code QR qui vous sert d'entrée "


# Here we tell the player whether the lever is on or off.
leverstate=`cat ../logic/leverlogic_1.ben`
            if [ "$leverstate" = "on" ]; then
                echo "'Billet s'il vous plaît' clignote sur l'écran..."
            else
                echo "La machine affiche l'heure d'entrée: 10:00"
            fi
echo
echo "Les cages renferment des animaux ."
echo
echo "Voulez vous commencer avec quel animal."

# In this set of actons lies the logic switch used later in the game.
# You have to set this switch to reach the endgame.
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) echo "C'est l'autre sortie aprés avoir visité le parc, vous êtes à nouveau au point de départ."
            ./mainroom.sh
            exit ;;
        s ) echo "C'est la sortie, vous êtes entrain de faire demi tour." ;;
        e ) echo "Ici il y a les cages des reptiles.." ;;
        w ) echo "Vous trouverez les fellins dans ce coin. l'animal le plius visitez ici est le lion." ;;
        u ) leverstate=`cat ../logic/leverlogic_1.ben`
            if [ "$leverstate" = "on" ]; then
                echo "vous êts entrain de scanner votre code QR'."
            else
                sed -i='' 's/off/on/' ../logic/leverlogic_1.ben
                echo "billet validé..."
                sleep 3
                echo "A moment où vous touchez la touche '#' L'écran se met à clignoter..."
            fi
        ;;
        h ) echo "Vous avez les détails sur la réservation et aussi une facture au cas où vous voulez un remboursement." ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, nw, ne, sw, se, u et h..";;
    esac
done

esac
exit
