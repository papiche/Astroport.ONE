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
echo "Vous entrez dans l'ancienne bergerie."
echo "Un canapé mauve est installé au milieu de l'espace"
echo "Une bache transparente vous sépare du ciel."
echo
echo "Vous êtes dans une serre."
echo "Une seule sortie. A l'Ouest, d'où vous venez."
echo
echo "Que voulez-vous faire?"

# And the choices go here.
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) echo "Une fente dans le mur vous laisse observer une carcasse de voiture. Une vieille 2cv. Un grillage vous empêche de passer." ;;
        s ) echo "L'emplacement d'un grand feu se trouve la. Il ne reste que de la cendre." ;;
        e ) echo "Une autre pièce remplie de gravats et d'éboulis se trouve devant vous. Impossible d'y accéder." ;;
        w ) ./mainroom.sh
            exit ;;
        u ) echo "Vous vous asseyez dans le canapé. Vous vous sentez immédiatement happé par un nuage."
              sleep 2
              xdg-open "https://www.copylaradio.com/blog/blog-1/post/le-pas-a-pas-qui-libere-du-grand-mechant-cloud-36#scrollTop=0"
              ;;
        h ) echo "Aucun détail particulier si ce n'est une tache sur le sofa." ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done

esac
exit
