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
echo "Vous prenez une trotinette électrique."
echo "Vous traversez toute la ville "
echo "A la sortie de la ville votre trotinette commence à manquer de puissance."
echo
echo "La batterie se vide."
echo "Pour joindre l'aéroport vous devez vous rendre dans l'autre ville Sainte Marie à 30 min"
echo
echo "Que voulez-vous faire?"
echo "Plusieurs choix s'offre à vous."
echo "(n) Payer un taxi"
echo "(e) Faire du stop"
echo "(w) Respawn"
echo "(s) Recharger la trotinette"

# And the choices go here.
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) echo "Le  taximan vous taxe tous votre argent et vous dépose à l'aéroport" ;;
        s ) echo "L'emplacement de recharge vous fais attendre 30 min." ;;
        e ) echo "Un Réunionnais s'arrête et vous dépose à l'aéroport." ;;
        w ) ./mainroom.sh
            exit ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w ";;
    esac
done

esac
exit
