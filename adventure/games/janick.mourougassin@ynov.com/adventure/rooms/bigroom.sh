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
            echoleverstate=`cat ../logic/stationlogic.ben`
            if [ "$leverstate" = "on" ]; then

                sleep 2
                echo "Il ne dépend que de vous d'explorer ce nouveau futur."
                echo "Le Visa MadeInZion inaugure un monde sans territoire, sans frontière, transnationnal, interplanétaire, à vous de voir?"
                sleep 2
                echo "Avant de nous rejoindre. Visitez notre 'bon coin' https://gchange.fr "
                echo
                sleep 3
                echo "Ouvrez une ambassade? Installez IPFS, devenons hébergeur, fournisseur d'accès de nos Internets."
                echo
                sleep 4
                echo "Ouvrez votre propriété au futur en commun, activez Astroport."
                echo "Nous organisons des formations habitats posés, vissés et cousus. Eau potable. Biogaz, Marmite Norvégienne..."
                echo "Comment nourrir le sol, reconnaitre les plantes... Redevenir ceuilleur, créateur."
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
