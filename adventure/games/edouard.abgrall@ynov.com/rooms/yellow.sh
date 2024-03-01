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
echo "Vous voila en train de vous glisser entre l'espace pour acceder à la voiture "
echo "vous faites le tour de la voiture, rien de particulierement notable."
echo "vous vous asseyez dans la voiture, cela devait être quelque chose de conduire ces engins."
echo
echo "le bruit semble venir d'un compartiment, vous l'ouvrez... "
echo "un petit boitier se trouve a l'interieur, et emets un bip régulier avec une petite lumiere rouge."
echo
echo "Que voulez-vous faire?"
echo " 'o' pour sortir, 'u' pour prendre l'objet"


# And the choices go here.
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        o ) echo "Vous vous extrayez de la carcasse." && ./red.sh ;;
        u )
    leverstate=$(cat ../logic/leverlogic.ben)
    if [ "$leverstate" = "on" ]; then
        echo "le boitier s'est éteint après vous avoir montré son message"
    else
        sed -i 's/off/on/' ../logic/leverlogic.ben
        echo "vous appuyez sur le bouton rouge"
        sleep 3
        echo "vous entendez au loin un grincement au fond de la forêt."
        echo "Puis le message 'OUVERTURE PORTE' s'affiche."
        echo "le boitier s'éteint doucement. Il n'avait vraiment plus beaucoup de batterie."
        
    fi
    ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : o et u.." ;;
    esac
done

esac
exit
