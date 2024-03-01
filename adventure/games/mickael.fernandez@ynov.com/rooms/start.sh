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
cat << EOF

L'aventure commence :

Vous voilà téléporté au cœur d'une station spacial inconnue.

Un soleil d'un bleu azur, observé par le hublot, vous révèle que vous n'évoluez plus dans votre système solaire familier.

Que souhaitez vous explorer  ?

Vos choix:

N (Nord): Emprunter un chemin obscure de la station.
E (Est): Explorer une salle voisine.
S (Sud): sortir de la station spacial par la porte exterieur.
O (Ouest): rester ou vous etes.
U (Utiliser): Utiliser un objet de votre inventaire (si vous en avez).
H (Aide): Afficher l'aide et les commandes disponibles.
Tapez votre choix (n, e, s, w, u ou h) et appuyez sur Entrée pour continuer.

EOF


while true; do
  read -p "> " nsewuh
  case $nsewuh in
    n) ./white.sh; exit ;;
    s) ./brown.sh; exit ;;
    e) ./red.sh; exit ;;
    w) echo "Vous allez vraiment rester là comme ça ? Comment avez-vous pu arriver ici ? Des souvenirs vous reviennent... https://www.youtube.com/watch?v=teIqu6r7jUE";;
    u) echo "Vous ouvrez votre sac. Il contient..." 
            file3="../script/inventaire.ben"
            while IFS= read -r line
            do
               echo "$line"
            done <"$file3";;
    h) echo "Désolé, il n'y a pas d'aide. Vous allez surement mourir prochainement." ;;
    *) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h." ;;
  esac
done

# inspiration pour le reste de  l'histoire neant... :(
esac
exit
