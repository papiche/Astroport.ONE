#!/bin/bash

clear

# Logic in the game is stored in .ben files. This sample has just one 'logic' file.
# You can add more logic files by simply adding a 'sed' command and appropriate .ben file.
# First off, let us reset the game logic. Use this as an example.

sed -i 's/on/off/' ../logic/leverlogic.ben

# Who doen't love ASCII text, right?
# Next up, let's initialise the Title Art
file1="../art/titleart.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"
echo

# Next up, let's load in the initial introduction. Script is also stored in .ben files.
sleep 5
file2="../script/opening.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file2"
read -p "Pressez sur [ENTER] pour démarrer..."

#Okay, now that the introduction is out of the way, we can start the first room!
clear
file1="../art/titleart.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"
sleep 1

# Here's where you introduce the room to the player. Be sure to tell them if there
# Are exits - but don't give too much away. Make it fun for them to explore!
echo "Salut à toi jeune déglingo."
echo "Vous attérissez au chef lieu de L'île de le Réunion."
echo "Vous êtes actuellement situé à Saint Denis."
echo
echo "Vous devrez choisir entre plusiers choix pour vous déplacer."
echo "Le but de ce jeu est de pouvoir voyager vers l'îles Maurice."
echo
echo "Vous pouvez vous diriger selon les points cardinaux."
echo "Au nord vous diriger vers un taxi, au sud vers un bus, à l'est, une trotinette, à l'ouest, vous marcher jusquà trouver de l'aide"
echo
echo "Que voulez-vous faire? Les commandes sont : n, e, s, w, u et h."
# Now we wait for their response - and send them somewhere accordingly.
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) ./white.sh
            exit ;;       # These lines will take the player to a new room - a new script file.
        s ) ./brown.sh
            exit ;;       # Be sure to include 'exit' otherwise the game won't quit properly!
        e ) ./red.sh
            exit ;;
        w ) ./green.sh
            exit ;;
        u ) echo "Vous ouvrez votre sac il contient une tente, des vêtements, un thermos, une scie pliante et un couteau" ;;     # Something to say? You can also just echo.
        h ) echo "Suivez ses coordonnées GPS 16.864841, 11.953808" ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;

    esac
done

esac
exit
