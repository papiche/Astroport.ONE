#!/bin/bash
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

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
isLAN=$(route -n |awk '$1 == "0.0.0.0" {print $2}' | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")
[[ ! $myIP || $isLAN ]] && myIP="127.0.1.1"

while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) echo "Vous êtes dans une cabine. Des QRCode sont collés à la parois nord" ;;
        s ) echo "Cette paroie comporte un miroir. Pour se faire une beauté avant d'enregistrer une capsule vidéo." ;;
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
            sleep 2
            echo
            echo "Rebootez INTERNET. Activez votre TW sur le Système de Fichiers Interplanétaire (IPFS)."
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
            echo "____ Astroport déclenche à 20:12 la synchronisation de ses ambassades..."
            echo "Rapport 2022 : https://ipfs.asycn.io/ipfs/QmUtGpGeMZvwp47ftqebVmoFWCmvroy5wEtWsKvWvDWJpR"
            sleep 3
            echo
            echo "ASTROPORT ONE"
            echo "VISA pour le vaisseau spatial TERRE."
                if [[ -d ~/.zen/Astroport.ONE ]]; then
                    read -p "Appuyez sur [ENTER] pour activer votre Station Astroport.ONE"
                    espeak "Astroport Command" > /dev/null 2>&1

                    ~/.zen/Astroport.ONE/command.sh
                else
                    espeak "Please Install Astroport" > /dev/null 2>&1
                    echo "Install Astroport.ONE ..."
                    echo  "bash <(wget -qO- https://raw.githubusercontent.com/papiche/Astroport.ONE/master/install.sh)"
                    ./end.sh
                fi
            fi
        exit
        ;;

        h ) echo "'DEMARRER API http://$myIP:1234 ... Une Station Astroport.ONE.?." ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done

esac
exit
