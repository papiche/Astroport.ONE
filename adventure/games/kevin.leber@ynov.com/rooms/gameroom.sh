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
leverstate=$(cat ../logic/telephonelogic.ben)
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
        t )  
    if [ "$leverstate" = "on" ]; then
        echo "Entrez le code PIN"
        echo

        while true; do
            read -p "> " pin

            if [ "$pin" == "9854" ]; then
                echo "Téléphone déverrouillé"
                echo "Qui voulez-vous contacter?"
                echo "1) Batman"
                echo "2) Maman"
                echo "3) EXIT"
                echo "4) DIEU"

                while true; do
                    read -p "> " contacte

                    case $contacte in
                        1 ) 
                            echo "Après plusieurs sonneries successives, une voix robotique dit : Le correspondant que vous cherchez à joindre est indisponible pour le moment, merci de rappeler ultérieurement."
                            ;;
                        2 ) 
                            echo "Une femme décroche et s'exclame : Encore toi ! Ne me rappelle plus tant que tu n'auras pas de boulot ! Et elle raccroche immédiatement."
                            ;;
                        3 ) 
                            echo "Vous êtes comme aspiré par le téléphone et vous réveillez dans une cuve d'un liquide visqueux."
                            sleep 1
                            echo
                            echo "Une énorme machine s'approche de vous et vous déconnecte des câbles auxquels vous n'étiez même pas conscient d'être attaché."
                            sleep 2
                            echo
                            echo "Vous êtes désorienté et un vaisseau s'approche pour vous récupérer."
                            sleep 1
                            echo
                            echo "La suite..."
                            sleep 2
                            echo "... est une autre histoire"
                            echo 
                            echo "Fin."
                            sleep 5
                            exit 
                            ;;
                        4 ) 
                            echo "Une boîte vocale répond et dit : Le temps d'attente pour joindre Dieu est estimé à 16357824 heures. Merci de patienter. Vous raccrochez frustré par le temps d'attente."
                            ;;
                        * ) 
                            echo "Choix invalide. Veuillez sélectionner 1, 2, 3 ou 4."
                            ;;
                    esac
                done
            else
                echo "Code PIN incorrect. Réessayez."
            fi
        done
    fi
    ;;


        h ) echo "'DEMARRER API http://$myIP:1234 ... Une Station Astroport.ONE.?." ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done

esac
exit
