#!/bin/bash
clear

# Initialise the Title Art
file1="../art/titleart.ben"
while IFS= read -r line; do
    echo "$line"
done < "$file1"
echo
leverstate1=$(cat ../logic/telephonelogic.ben)
# It's script time again...
sleep 1
echo "Vous pénétrez à l'intérieur de l'Astroport."
echo
sleep 3
echo "Une voix synthétique vous accueille."
espeak "Welcome. Please Identify." > /dev/null 2>&1
echo
echo "Vous parcourez l'espace du regard"
echo "Au nord, face à vous se trouve un foyer où brûle un feu."
echo
sleep 3
echo "À l'ouest sont suspendus tuyaux, ustensiles et bocaux. Une cuisine?"
echo "À l'est il y a un genre de 'photomaton' "
sleep 2
echo "Derrière vous, la porte par où vous êtes entré est encore ouverte."
echo
if [ "$leverstate1" = "on" ]; then
    echo "Le téléphone sonne"
    echo 
    echo "Vous décrochez et un homme visiblement très pressé commence à vous parler"
    echo 
    echo "Je ne sais pas qui tu es, mais sache que tout ce que tu vois n'est qu'illusion! Tu dois sortir de là et ne t'approcher pas du PC dans la station!"
    echo 
    echo "Tu dois trouver le code pour déverrouiller ce téléphone et appeler le contact 'EXIT'"
    echo 
    echo "L'homme vous raccroche au nez sans que vous ayez pu prononcer un mot"
    echo 
    echo "Que voulez-vous faire?"

    # And once again the room logic.

    while true; do
        read -p "> " nsewuh
        case $nsewuh in
            n ) 
                echo "Vous vous asseyez sur le grand tapis devant le feu. Vous vous relaxez un instant."
                ./magic8.sh
                ;;
            s ) 
                ./bigroom.sh
                exit ;;
            e ) 
                ./gameroom.sh
                exit ;;
            w ) 
                ./grue.sh
                exit ;;
            u ) 
                echo "Vous tapotez sur le baromètre. Une photo satellite?"
                ./meteofrance.sh
                exit
                ;;
            h ) 
                echo "La pièce est spacieuse. La chaleur du feu agréable, à gauche on dirait une cuisine explosée, à droite une chaise molletonnée fait face à un écran."
                ;;
            t )  
                if [ "$leverstate1" = "on" ]; then
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
                                        ##exit 
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
            * ) 
                echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h.."
                ;;
        esac
    done
fi
exit

