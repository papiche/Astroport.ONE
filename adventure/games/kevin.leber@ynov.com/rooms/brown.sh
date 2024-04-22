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
leverstate=$(cat ../logic/telephonelogic.ben)
# Here's this room's script.

echo "Sur la direction du sud, vous traversez une zone plus sombre et humide."
echo "Le sol est glissant à cause de l'argile qui colle sous vos bottes"
echo "Vous finissez par croiser un chemin qui traverse la forêt d'Est en Ouest"
echo
echo "Un terminal informatique est installé là."
echo
echo "Il ressemble à une grosse calculatrice"


# Here we tell the player whether the lever is on or off.
leverstate1=$(cat ../logic/leverlogic.ben)
if [ "$leverstate" = "on" ]; then
    echo "'VISA SVP' clignote sur l'écran..."
else
    echo "La machine affiche l'heure : 20:12"
fi
echo
echo "Il est tard pour explorer le chemin à pied, vous devriez retourner d'où vous venez."
echo
echo "Que faites-vous?"

# In this set of actions lies the logic switch used later in the game.
# You have to set this switch to reach the endgame.
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) ./mainroom.sh
            exit ;;
        s ) echo "Si vous continuez à marcher dans la forêt. Vous allez vous perdre. Demi-tour." ;;
        e ) echo "Le chemin qui part à l'Est est plein de boue... Impossible d'aller par là." ;;
        w ) echo "Une rivière vous empêche de passer." ;;
        u ) leverstate=$(cat ../logic/leverlogic.ben)
            if [ "$leverstate" = "on" ]; then
                echo "À chaque frappe d'une touche. L'écran fait défiler le texte 'SCANNEZ VISA SVP'."
            else
                sed -i='' 's/off/on/' ../logic/leverlogic.ben
                echo "Vous pianotez sur l'appareil..."
                sleep 3
                echo "Au moment où vous touchez la touche '#', l'écran se met à clignoter..."
                echo "Puis le message 'ACTIVATION STATION' défile sur les caractères lumineux."
            fi
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
        h ) echo "Le terminal comporte un clavier numérique. Un petit écran.. Il est réalisé avec un mini ordinateur Raspberry Pi. Il porte l'adresse G1TAG [https://g1sms.fr]" ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done
exit
