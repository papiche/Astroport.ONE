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
echo "Vous pénétrez à l'intérieur de l'Astroport."
echo
echo "Une voix synthétique vous accueille."
espeak "Welcome. Please Identify." > /dev/null 2>&1
echo
echo "Vous parcourez l'espace du regard"
echo "Au nord, face à vous se trouve un foyer où brule un feu."
echo
echo "A l'ouest sont suspendus tuyaux, ustensiles et bocaux. Une cuisine?"
echo "A l'est il y a un genre de 'photomaton' "
echo
echo "Derrière vous, la porte par où vous êtes entré est encore ouverte."
echo
echo "Que voulez vous faire?"
echo
echo "Il y a également un ordinateur au millieu de la pièce avec l'inscription : 'Appuyez sur U pour lancer le jeu'"

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
        u ) echo "Vous tapotez sur le barmoètre. Une photo satellite?"
            ./meteofrance.sh
            exit
        ;;
        h ) echo "La pièce est spacieuse. La chaleur du feu agréable, à gauche on dirait une cuisine explosée, à droite une chaise moletonnée fait face à un écran." ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done

esac
exit
