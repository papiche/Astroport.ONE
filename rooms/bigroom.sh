#!/bin/bash
clear
# Initialise the Title Art
file1="../art/titleart.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"

# This is close to the endgame, but affords the player a last set of things to try and do.
# Obviously if you use this framework to create a game of your own, you can extend this massively.
echo
sleep 1
echo "Vous décidez de sortir de la Sation Astroport."
echo
sleep 2
echo "Vous vérifiez le contenu de votre portefeuille"
echo "Il vous reste quelques billets..."
sleep 2
echo "Etrange."
echo
sleep 3
echo "Certains n'ont pas la même couleur que d'habitude."
echo
sleep 5
echo "Vous sous sentez nerveux."
echo "Vous avez du mal à vous souvenir de ce que vous êtiez venu faire ici"
echo "Est-ce que tout cela est vraiment arrivé?"
echo
sleep 5
echo
echo "Soudain un homme au visage souriant s'approche de vous,"
echo "Vous avez bien fait de venir dit-il d'une voix profonde au ton calme. Vous restez avec nous?"
echo "Voila le jeu. Nous allons tester votre capacité à agir pour l'oeuvre commune que vous visitez"
echo "Vous aurez le choix ensuite de voyager entre tous les lieux du réseau en franchise!"
echo
sleep 5
echo
echo "Que voulez vous faire?"

while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) echo "Pas moyen de se déplacer." ;;
        s ) echo ".Pas le choix." ;;
        e ) echo "Pas par là." ;;
        w ) echo "Plus à l'ouest que ça? Y'a pas!" ;;
        u ) ./end.sh
            exit ;;
        h ) echo "Comment refuser une telle proposition..." ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done

esac
exit
