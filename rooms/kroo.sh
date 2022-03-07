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
echo "Au nord, face à vous se trouve un foyer où brule un feu."
echo
echo "A l'ouest sont suspendus tuyaux, ustensiles et bocaux. Une cuisine?"
echo "Un écran et un clavier d'ordinateur se situent à l'est de votre position"
echo "Derrière vous, la porte par où vous êtes entré est encore ouverte."
echo
echo "Que voulez vous faire?"

# And once again the room logic.

while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) echo "Vous vous asseyez sur le grand tapis devant le feu. Vous vous relaxez un instant."
            ./magic8.sh
            ;;
        s ) ./bigroom.sh
             exit ;;
        e ) ./gameroom.sh
            exit ;;
        w ) ./grue.sh
            exit ;;
        u ) echo "Vous refermez la porte... Puis vous vous ravisez... Si la poignée disparaissait encore. Il vaut mieux la laisser ouverte." ;;
        h ) echo "La grande pièce est spacieuse, agréable. Devant un feu, à gauche la cuisine, à droite un salon." ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done

esac
exit
