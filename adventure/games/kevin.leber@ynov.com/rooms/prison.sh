#!/bin/bash
clear
file1="../art/titleart.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"
echo

# Set up the script for this room. It's a simple one!
sleep 1
echo "Vous vous réveyer dans une pièce sombre un le pire mal de crâne de votre vie."
echo "Au nord une porte laisse échapper un faible rayon de lumière."
echo "au sud de la pièce vous percevais une commode."
echo
echo "Que voulez-vous faire?"

# And the choices go here.
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) leverstate=`cat ../logic/prisonlogic.ben`
            if [ "$leverstate" = "off" ]; then
                echo "'la porte est fermer" 
            else
                echo "vous utiliser le pied de biche pour forcer la porte."
                echo "en traversant la porte vous vous retrouver dans une bergerie."
                echo "en vous retournant vous remarquez que la porte a disparu."
                read -p "Appuyez sur [ENTER] pour revenir..."
                ./red.sh
                exit
            fi
              ;;
        s ) echo "il fait trop sombre pour explorer." ;;
        e ) echo "après 2 pas héroïque dans le noir vous vous cogner la tête dans un mur et revenais à moitier sonner au milieu de la pièce" ;;
        w ) echo "il fait trop sombre pour explorer." ;;
        u )leverstate=`cat ../logic/prisonlogic.ben`
            if [ "$leverstate" = "off" ]; then
            	echo "on" > ../logic/prisonlogic.ben
                echo "'Vous trouvez un pied de biche." 
            else
                echo "la commode est vide."
            fi
              ;;
        h ) echo "un objet est à moitier éclairé par l'unique rayon de lumière présent dans la pièce." ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done

esac
exit
