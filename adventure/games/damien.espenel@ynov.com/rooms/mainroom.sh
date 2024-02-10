#!/bin/bash
clear

# This is a repeat of the opening room in the start.sh file - if the player
# wants to go back to the main room, this saves going through the whole
# start script over again.

# Initialise the Title Art
file1="../art/titleart.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"
echo

# Shakesphere wrote this, honest.
sleep 1
echo "Vous êtes de retour à votre point de départ."
echo "La forêt qui vous entoure est immense."
echo "Vous ne pouvez pas vraiment en imaginer la taille,"
echo
echo "Vous pouvez vous diriger au nord, à l'est, au sud et à l'ouest."
echo
echo "Vous apercevez quelque chose derrière un arbre.."
echo
sleep 2
echo "Un levier est installé là."
echo
echo "À côté, se trouve un vitre renfermant un marteau."
echo
leverstate2=`cat ../logic/leverlogic2.ben`
            if [ "$leverstate2" = "on" ]; then
                echo "La vitre est ouverte, vous avez récupéré le marteau."
            else
                echo "La vitre est fermée, et vous empêche de récupérer le marteau."
            fi
echo
echo "Que voulez-vous faire ?"

# And the room logic once again.
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) ./white.sh
            exit ;;
        s ) ./brown.sh
             exit ;;
        e ) ./red.sh
            exit ;;
        w ) ./green.sh
            exit ;;
        u ) leverstate2=`cat ../logic/leverlogic2.ben`
            if [ "$leverstate2" = "on" ]; then
                sh ../masterguesser.sh
            else
		echo "Il n'y a rien que vous puissiez utiliser ici."
            fi
        ;;
        h ) leverstate=`cat ../logic/leverlogic.ben`
	       if [ "$leverstate" = "on" ]; then
		       echo "Vous remarquez un petit terminal allumé..."
		       sleep 2
		       echo "Le jeu MasterGuesser y est ouvert !"
	       else       
		       echo "Vous observez votre montre, il est 20:12"
	       fi
	       ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done

esac
exit
