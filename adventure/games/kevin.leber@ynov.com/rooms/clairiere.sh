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
echo "Au milieu de la clairère se trouve un smartphone."
echo 
sleep 1
echo "Le smartphone se met à sonner"
echo "que faite vous"


# And the choices go here.
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n )    ./green.sh
                exit;;
        s ) echo "Vous voyez le même paysage à perte de vue" ;;
        e ) echo "Vous voyez le même paysage à perte de vue" ;;
        w ) echo "Vous voyez le même paysage à perte de vue" ;;
        u )leverstate=`cat ../logic/prisonlogic.ben`
            if [ "$leverstate" = "off" ]; then
                echo "Vous tenté de prendre le smatphone mais un piège ce referme sur votre poigné, déchirant la chaire et brisant les os..." 
                echo ""
                echo "vous etes tomber dans un piège à ours et il vous est impossible de vous enfuir"
                sleep 3
                echo "vous mourrez de l'hémoragie."
                sleep 1
                echo "fin."
                exit 
            else
                echo "vous utiliser le pied de biche pour récupérer le telephone mais celui si est verouillé"
                echo "on" > ../logic/telephonelogic.ben
                
            fi
              ;;
        h ) echo " un objet a moitier enterrer sous le smartphone attire votre attention, on dirait un cercle d'acier..." ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done

esac
exit
