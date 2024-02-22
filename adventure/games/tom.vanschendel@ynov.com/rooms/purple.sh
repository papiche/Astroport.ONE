#!/bin/bash
clear
# Initialise the Title Art
file1="../art/titleart.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"
echo
sleep 1

# Here's this room's script.

echo "Vous vous enfoncez dans la foret. Le chemin est étroit et sinueux."
echo "Vous entendez des bruits d'animaux dans les buissons."
echo "Il y a un nouveau levier devant vous sur un poteau."

# Here we tell the player whether the lever is on or off.
levertwostate=`cat ../logic/leverlogictwo.ben`
            if [ "$leverstatewo" = "on" ]; then
                echo "Le levier est en position ON."
            else
                echo "Le levier est en position OFF."
            fi
echo
echo "Que voulez-vous faire? Les commandes sont : n, e, s, w et u."

# In this set of actons lies the logic switch used later in the game.
# You have to set this switch to reach the endgame.
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) ./brown.sh
            exit ;;
        s ) echo "Si vous continuez à marcher dans la forêt. Vous allez vous perdre. Demi tour." ;;
        e ) ./orange.sh 
            exit ;;
        w ) echo "Une rivière vous empêche de passer." ;;
        u ) levertwostate=`cat ../logic/leverlogictwo.ben`
            if [ "$levertwostate" = "on" ]; then
                echo "Le levier est déjà en position ON, impossible de l'abbaisser maintenant..."
            else
                sed -i 's/off/on/' ../logic/leverlogictwo.ben
                echo "Vous relevez le levier en position ON en forcant un peu."
                echo "Vous entendez un bruit de mécanisme qui se déclenche à l'est."
            fi
        ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w et u..";;
    esac
done

esac
exit
