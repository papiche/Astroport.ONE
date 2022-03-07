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
echo "y est raccordé...  D'autres fils sortent de l'appareil. Une webcam. Une imprimante. COOL!"
echo "Un TerraPi4. Astroport y est installé."
echo
sleep 2
echo "Depuis le GRAND RESET, partager des informations est totalement réglementé"
echo "En dehors de la version payante, cet autre INTERNET gratuit existe. Il se contruit comme on collecte les oeufs à Paques."
echo "Certains l'appelle 'Le Blob'. On y échange en pair à pair."
echo
echo "Cet endroit est une ambassade MadeInZion. Un crypto pays de la Nation d'Etat d'Esprit."
echo "Une version optimisée, décentralisée, sans frontière des anciens pays et gouvernements."
echo
echo "Vous pouvez "
echo
echo "Une version optimisée, décentralisée, sans frontière des anciens pays et gouvernements."
echo
echo "Que voulez vous faire?"

while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) echo "Vous êtes dans une cabine. Des QRCode sont collés à la parois nord" ;;
        s ) echo "Cette paroie comprte un miroir. Pour se faire une beauté avant d'enregistrer une capsule vidéo." ;;
        w ) ./kroo.sh
            exit ;;
        e ) echo "Vous êtes face à l'écran. Au dessus des hauts parleurs et une webcam" ;;
        u ) echo
            echo "Vous appuyez sur l'interupteur de l'écran et touchez la barre espace du clavier"
            echo "D'un coup d'oeil vous savez que votre intuition était la bonne"
            echo "Plusieurs icones sont là."
            echo
            sleep 4
            echo "Ajouter un rêve au lieu."
            echo "Ajouter un astronaute au jeu."
            echo "Voir les primes."
            echo "__________________ Connexion....."
            sleep 3
            echo
            echo
            echo "INITIALISATION ASTROPORT"
            echo
            read -p "Appuyez sur [ENTER] pour créer votre VISA"
            ../tools/VISA.new.sh
            exit

        ;;
        h ) echo "Votre smartphone a détecté le réseau Wifi 'qo-op' typique de ce lieu. Connectez-vous à son Nextcloud https://192.168.220.1 " ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done

esac
exit
