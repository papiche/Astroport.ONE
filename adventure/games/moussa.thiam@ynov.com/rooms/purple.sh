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
echo "Vous venez d'entrer dans la salle de karting"
echo "En face de vous, il y a l'accueil avec l'hote de caisse."
echo "Vous pouvez utiliser vos bon coins que vous avez gagné récemment dans la précédente partie."
echo "Une partie de 15min de Karting vous coute 10 coins."
echo
echo "Plus vous jouez plus vous dépensez plus. Si tu finis premier, possible de jouer une autre partie gratuitement."
echo
echo "Que voulez vous faire?"

# And here's what you could have won...
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) echo "Avancer vers le hote de caisse" ;;
        s ) echo "Vers le sud, aucun passage en vue." ;;
        e ) ./mainroom.sh
            exit ;;
        w ) echo "Je commande quelques chose à manger d'abord." ;;
        u ) echo "oui je joue." ;;
        h ) echo "Je vérifie le nombre de coins que j'ai pour décider le nombre de partie que je vais jouer hormis mon classement" ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done

exit
