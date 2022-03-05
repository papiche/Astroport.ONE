#!/bin/bash
clear

# This room gets a little artsy with sleep commands, to help with the
# narrative of the story. This is why there are two versions - foyer and foyer2.

# Initialise the Title Art
file1="../art/titleart.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"
echo

# It's script time again...
sleep 1
echo "Vous pénétrez à l'intérieur de l'Astroport."
echo
sleep 3
echo "Une voix synthétique vous accueille."
echo
echo "Vous parcourez l'espace du regard"
echo "Au nord, face à vous se trouve un foyer où brule un bon feu."
echo
echo "A l'Ouest se trouve un mur où sont suspendus tuyaux, ustensiles et bocaux"
echo "Un écran et clavier d'ordinateur se situent à l'Est"
echo "Derrière vous, la porte par où vous êtes entré est toujours ouverte."
echo
echo "Que voulez vous faire?"

# And once again the room logic.

while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) echo "Vous vous asseyez sur le grand tapis. Le feu est envoutant. Vous vous relaxez un instant." ;;
        s ) ./bigroom.sh
             exit ;;
        e ) ./gameroom.sh
            exit ;;
        w ) ./grue.sh
            exit ;;
        u ) echo "Choisissez une zone vers où vous diriger dans la pièce pour pouvoir agir." ;;
        h ) echo "La chaleur est agréable. Sur votre gauche une cuisine, à votre droite un salon" ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done

esac
exit
