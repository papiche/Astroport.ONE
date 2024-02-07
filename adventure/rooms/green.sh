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
echo "Vous atteignez une zone remplie de jeunes épineux"
echo "Vous reconnaissez des prunus, des aubépines."
echo "Quelques génévriers dont vous remarquez les baies noires."
echo "Un peu plus loin ce sont les ronces."
echo
echo "Plus vous progressez plus vous souffrez des épines. Existe-t-il un passage? Qui sait."
echo
echo "Que voulez vous faire?"

# And here's what you could have won...
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) echo "Un énorme roncier vous barre la route. Ca ne passe pas." ;;
        s ) echo "Vers le sud, aucun passage en vue." ;;
        e ) ./mainroom.sh
            exit ;;
        w ) echo "Vous voyez le même paysage à perte de vue" ;;
        u ) echo "Vous cueillez une baie de genèvrier. Vous la portez à la bouche. Croquez. La saveur est délicieuse. La force de la plante vous envahi." ;;
        h ) echo "Ce type de terrain est caractéritique des zones déboisées. La nature sort ses épines pour protéger les arbres qui poussent en dessous." ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done

esac
exit
