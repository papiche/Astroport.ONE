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
            echo "Vous appuyez sur l'interupteur de l'écran et touchez la barre espace du clavier"
            sleep 3
            echo "AMBASSADE MadeInZion"
            echo "TerraPi4 2 To"
            echo
            sleep 2
            echo "Avant que le GRAND RESET ne nous oblige à totalement réglementer nos information personnelles"
            echo "En dehors de la version payante, un INTERNET gratuit existe. Il se contruit comme on collecte les oeufs à Paques."
            sleep 2
            echo
            echo "Certains l'appelle 'Le Blob'. On y échange en pair à pair."
            sleep 2
            echo
            echo "Cet endroit est une ambassade MadeInZion. Un crypto pays de la Nation d'Etat d'Esprit."
            echo "Version optimisée, décentralisée, sans frontière des anciens pays et gouvernements."
            sleep 4
            file1="../art/astrored.ben"
            while IFS= read -r line
            do
                echo "$line"
            done <"$file1"
            echo "__________________ Connexion....."
            echo "Parcourir l'Arbre des rêves "
            echo "Ajouter un Astronaute au JEu."
            sleep 3
            echo
            echo
            echo "INITIALISATION ASTROPORT"
            echo
            read -p "Appuyez sur [ENTER] pour accéder au MENU"
            ~/.zen/game/start.sh
            fi
        exit
        ;;

        h ) echo "Vous lisez l'inscription Wifi 'qo-op|0penS0urce!' - 192.168.220.1 - Nextcloud https://astroport.cloud - Jukebox https://astroport.music ..." ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done

esac
exit
