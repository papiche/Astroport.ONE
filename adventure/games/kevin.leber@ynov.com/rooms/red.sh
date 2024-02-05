#!/bin/bash
clear

# Initialise the Title Art
file1="../art/titleart.ben"
while IFS= read -r line; do
    echo "$line"
done < "$file1"

echo
leverstate=$(cat ../logic/telephonelogic.ben)

# Set up the script for this room. It's a simple one!
sleep 1
echo "Vous entrez dans l'ancienne bergerie."
echo "Un canapé mauve est installé au milieu de l'espace."
echo "Une bâche transparente vous sépare du ciel."
echo
echo "Vous êtes dans une serre."
echo "Une seule sortie. À l'Ouest, d'où vous venez."
echo
echo "Que voulez-vous faire?"

# And the choices go here.
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) echo "Une fente dans le mur vous laisse observer une carcasse de voiture. Une vieille 2cv. Un grillage vous empêche de passer." ;;
        s ) echo "L'emplacement d'un grand feu se trouve là. Il ne reste que de la cendre." ;;
        e ) echo "Une autre pièce remplie de gravats et d'éboulis se trouve devant vous. Impossible d'y accéder." ;;
        w ) ./mainroom.sh
            exit ;;
        u ) echo "Vous vous asseyez dans le canapé. Vous vous sentez immédiatement happé par un nuage."
              sleep 2
              xdg-open "https://www.copylaradio.com/blog/blog-1/post/le-pas-a-pas-qui-libere-du-grand-mechant-cloud-36#scrollTop=0"
              ;;
        h ) echo "Vous remarquez un nombre gravé grossièrement sur une poutre, ce dernier est 9854."
            if [ "$leverstate" = "on" ]; then
                echo "Appuyez sur 't' pour utiliser le téléphone"
            fi
            ;;
        t ) if [ "$leverstate" = "on" ]; then
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
    ;;
    fi
            ;;

        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h." ;;
    esac
done
