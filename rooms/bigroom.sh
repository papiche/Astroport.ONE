#!/bin/bash
clear
# Initialise the Title Art
file1="../art/titleart.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"

# This is close to the endgame, but affords the player a last set of things to try and do.
# Obviously if you use this framework to create a game of your own, you can extend this massively.

echo
sleep 1
echo "Vous décidez de sortir de la Sation Astroport."
echo
sleep 4
echo "aAu moment où vous franchiussez le seul.."
echo "Un immense flash fait jaillir partant de vos pieds votre ombre, immense silhouète aloongée"

            echoleverstate=`cat ../logic/stationlogic.ben`
            if [ "$leverstate" = "on" ]; then

                sleep 2
                echo "Il ne dépend que de vous d'explorer ce nouveau futur."
                echo "Le Visa MadeInZion vous permet de découvrir celui qui vous entoure"
                sleep 2
                echo "Nous vous attendons sur notre 'bon coin' https://gchange.fr "
                echo
                sleep 3
                echo "Il vous reste maintenant à installer IPFS pour rejoindre l'autre Internet."
                echo
                sleep 4
                echo "Devenez ambassadeur."
                echo "Renseignez vous sur les formations habitats posés, vissés et cousus. "
                echo "Apprenez à nourrir le sol et reconnaitre les plantes de votre environement. SOlDiag"
                echo
            else
                echo ""
                echo "Aucune entrée n'est visible."
            fi
echo
sleep 5
echo
echo "Que voulez vous faire?"

while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) echo "Pas moyen de se déplacer." ;;
        s ) echo ".Pas le choix." ;;
        e ) echo "Pas par là." ;;
        w ) echo "Plus à l'ouest que ça? Y'a pas!" ;;
        u ) ./end.sh
            exit ;;
        h ) echo "Comment refuser une telle proposition..." ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done

esac
exit
