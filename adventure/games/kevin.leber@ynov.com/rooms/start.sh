#!/bin/bash

clear

# Logic in the game is stored in .ben files. This sample has just one 'logic' file.
# You can add more logic files by simply adding a 'sed' command and appropriate .ben file.
# First off, let us reset the game logic. Use this as an example.

sed -i='' 's/on/off/' ../logic/leverlogic.ben
sed -i='' 's/on/off/' ../logic/prisonlogic.ben
sed -i='' 's/on/off/' ../logic/telephonelogic.ben
# Who doen't love ASCII text, right?
# Next up, let's initialise the Title Art
file1="../art/titleart.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"
echo

# Next up, let's load in the initial introduction. Script is also stored in .ben files.
sleep 5
file2="../script/opening.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file2"
read -p "Pressez sur [ENTER] pour démarrer..."

#Okay, now that the introduction is out of the way, we can start the first room!
clear
file1="../art/titleart.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"
sleep 1

# Here's where you introduce the room to the player. Be sure to tell them if there
# Are exits - but don't give too much away. Make it fun for them to explore!
echo
echo "La téléportation vous a placé debout au centre d'une clairière."
echo "Vous vous trouvez près d'une ancienne bergerie aux gros murs de pierres."
echo "Le toit et une bonne partie des murs sont effondrés."
echo
echo "Tout autour la forêt. Des feuillus. Quelques arbustres épineux."
echo "Sous vos pieds. Le sol est rouge parsemé de cailloux blancs."
echo
echo "Vous pouvez vous diriger selon les points cardinaux."
echo "Au nord un chemin remonte, au sud un passage descend, à l'est, la bergerie, à l'ouest, des traces d'animaux"
echo
echo "Que voulez-vous faire? Les commandes sont : n, e, s, w, u et h."

# Now we wait for their response - and send them somewhere accordingly.
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) ./white.sh
            exit ;;       # These lines will take the player to a new room - a new script file.
        s ) ./brown.sh
            exit ;;       # Be sure to include 'exit' otherwise the game won't quit properly!
        e ) ./red.sh
            exit ;;
        w ) ./green.sh
            exit ;;
        u ) echo "Vous ouvrez votre sac il contient une tente, des vêtements, un thermos, une scie pliante et un couteau" ;;     # Something to say? You can also just echo.
        h ) echo "Comment avez-vous pu arriver ici.? Des souvenirs vous reviennent... https://web.archive.org/web/20211129105224/https://oasis.astroport.com/a-quel-jeu-voulons-nous-jouer/" ;;
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
