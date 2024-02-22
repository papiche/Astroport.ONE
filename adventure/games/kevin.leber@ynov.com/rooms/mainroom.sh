#!/bin/bash
clear

# This is a repeat of the opening room in the start.sh file - if the player
# wants to go back to the main room, this saves going through the whole
# start script over again.

# Initialise the Title Art
file1="../art/titleart.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"
echo
leverstate=$(cat ../logic/telephonelogic.ben)
# Shakesphere wrote this, honest.
sleep 1
echo "Vous êtes de retour à votre point de départ."
echo "La forêt qui vous entoure est immense."
echo "Vous ne pouvez pas vraiment en imaginer la taille,"
echo
echo "Vous pouvez vous diriger au nord, à l'est, au sud et à l'ouest."
echo
echo "Que voulez-vous faire ?"

# And the room logic once again.
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) ./white.sh
            exit ;;
        s ) ./brown.sh
             exit ;;
        e ) ./red.sh
            exit ;;
        w ) ./green.sh
            exit ;;
        u ) echo "Il n'y a rien que vous puissiez utiliser ici." ;;
        h ) echo "Vous observez votre montre, il est 20:12" ;;
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

        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done

esac
exit
