#!/bin/bash
clear
# Initialise the Title Art
file1="../art/titleart.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"
echo

# This room gives the player a typical poisoned apple style scenaro.
# Just because something looks shiny and fun, doesn't make it any
# less deadly.
sleep 1
echo "Dans une cabine, un écran est disposé en coin. Un tout petit ordinateur"
echo "y est raccordé...  D'autres fils sortent de l'appareil. Une webcam. Une imprimante."
echo
echo "Que voulez vous faire?"
myIP=$(hostname -I | awk '{print $1}' | head -n 1)
[[ ! $myIP ]] && myIP="127.0.1.1"

while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) echo "Vous êtes dans une cabine. Des QRCode sont collés à la parois nord" ;;
        s ) echo "Cette paroie comprte un miroir. Pour se faire une beauté avant d'enregistrer une capsule vidéo." ;;
        w ) ./kroo.sh
            exit ;;
        e ) echo "Vous êtes face à l'écran. Au dessus des hauts parleurs, une webcam" ;;
        u ) leverstate=`cat ../logic/stationlogic.ben`
            if [ "$leverstate" = "on" ]; then
                echo "A chaque frappe d'une touche. l'écran fait défiler le texte 'SCANNEZ VISA SVP'."
            else
                sed -i='' 's/off/on/' ../logic/stationlogic.ben
            echo "Vous appuyez sur l'interupteur de l'écran. Y apparaît alors :"
            sleep 3
            echo "AMBASSADE MadeInZion - TerraPi4 - 2 To -"
            echo ""
            echo
            sleep 2
            echo "INTERNET est dangereux. il vend vos information personnelles pour que vous deveniez un produit.  "
            echo "Quittez INTERNET. Découvrez le Système de Fichiers Interplanétaire (IPFS)."
            sleep 2
            echo
            echo "Nous remplissons IPFS des identités des Astronautes qui explorent le mode de vie en forêt jardin."
            sleep 2
            echo
            echo "On y échange en pair à pair. La monnaie y est Libre."
            sleep 4
            file1="../art/astrored.ben"
            while IFS= read -r line
            do
                echo "$line"
            done <"$file1"
            echo
            echo
            echo "____ Astroport 20:12 est un programme qui permet de monter des ambassades de la 'présipauté pair à pair' MadeInZion....."
            echo "Chaque Lieu porte l'Arbre des rêves de ses habitants"
            echo "Chaque Astronaute fait des voeux et partage ses talents."
            echo "Participez au JEu d'ingénierie DIY lancez la terraformation forêt jardin."
            sleep 3
            echo
            echo "ASTROPORT ONE"
            echo
            read -p "Appuyez sur [ENTER] démarrez la Station Astroport.ONE"
            ~/.zen/Astroport.ONE/start.sh
            fi
        exit
        ;;

        h ) echo "'DEMARRER API http://$myIP:1234 ... Une Station Astroport.ONE.?." ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done

esac
exit
