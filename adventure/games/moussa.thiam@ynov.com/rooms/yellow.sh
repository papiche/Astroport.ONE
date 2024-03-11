#!/bin/bash
clear
# Initialise the Title Art
file1="../art/titleart.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"
echo

# Set up the script for this room. It's a simple one!
sleep 1
echo "Vous entrez dans un bar."
echo "l'accueil est en face  au fond et il y a des tables autour blindé de monde "
echo "il y a une queue à faire car ce bar est trés prisé."
echo
echo "A votre tour de faire votre choix."
echo
echo "Que désiriez-vous Monsieur?"

# And the choices go here.
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) echo "en choisissant le nord tu peux prendre le tunel qui méne à la salle de Karting et il faut cliquuer sur w pour y avoir accé." ;;
        s ) echo "Il faut commander d'abord avant de prendre une table." ;;
        e ) echo " il n'y a que les toilettes à l'Est." ;;
        w ) ./purple.sh
            exit ;;
        u ) echo "Je voudrais une peinte de 5 coins." ;;
        h ) echo " vous avez quel type de bière et de quoi est composée cette dernière" ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, nw, ne, sw,se, u et h..";;
    esac
done

esac
exit
