#!/bin/bash

clear

# Logic in the game is stored in .ben files. This sample has just one 'logic' file.
# You can add more logic files by simply adding a 'sed' command and appropriate .ben file.
# First off, let us reset the game logic. Use this as an example.

sed -i='' 's/on/off/' ../logic/leverlogic.ben

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
echo
echo "La téléportation vous a placé debout près d'une batisse en ruine."
echo "C'est une ancienne grange faites de gros murs de pierre."
echo "Le toit et une partie des murs sont effondrés."
echo
echo "Vous disposez d'un sac à dos et d'une bouteille isotherme."
echo "Le soleil est déjà haut dans le ciel."
echo
echo "Vous pouvez vous diriger selon les points cardinaux."
echo "Nord, Sud, Est, Ouest."
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
		u ) echo "Vous ouvrez votre sac il contient une tente et des vêtements chauds." ;;     # Something to say? You can also just echo.
		h ) echo "Vous vous souvenez..." ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done

esac
exit
