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
sleep 2
echo "Une voix synthétique vous accueille."
espeak "Welcome. Please Identify." > /dev/null 2>&1
echo
echo "Vous parcourez l'espace du regard"
echo "Au nord, face à vous se trouve un foyer où brule un feu."
echo
sleep 2
echo "A l'ouest sont suspendus tuyaux, ustensiles et bocaux. Une cuisine?"
echo "A l'est il y a un genre de 'photomaton' "
sleep 2
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
        u ) echo "Vous tapotez sur l'ordinateur endommagé..........Il semble être corrompu........."
            echo "La chose qui a traversé votre corps est toujours présente et se transmet sur cet ordinteur corrompu...."
            echo "Comme s'il voulais...... nous empecher ........ de découvrir ........ la vérité"
            ./wiggle.sh
            exit
        ;;
        h ) echo "La pièce est spacieuse. La chaleur du feu agréable, à gauche on dirait une cuisine explosée, à droite une chaise moletonnée fait face à un écran." ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done

esac
exit
