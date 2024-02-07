#!/bin/bash
clear
# Initialise the Title Art
file1="../art/titleart.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"
echo

# Everybody clap your hands. I mean, here is the script.
sleep 1
echo "Une personne vous aide et vous propose de vous déposer directment à l'aéroport"
echo
echo "Vous entrez dans à l'intérieur de l'aéroport, et allez acheter un billet pour l'île Maurice."
echo " L'hotesse vous propose un billet à 79 € alors que vous n'avez que 50 €."

echo "Que voulez vous faire?"
echo "Plusieurs choix s'offre à vous."
echo "(n) Faire le mandian"
echo "(e) Respawn"
echo "(w) Négocier"
echo "(s) Passer en force"
# And here's what you could have won...
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) echo "Vous récolter les sous manquants, mais la douanes vous arrêtes et vous expulse" ;;
        s ) echo "La douanes vous arrêtes et vous expulse" ;;
        e ) ./mainroom.sh
            exit ;;
        w ) echo "Elle vous propose un billet à 55€" ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w ";;
    esac
done

esac
exit
