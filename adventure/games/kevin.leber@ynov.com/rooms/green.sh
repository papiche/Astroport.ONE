#!/bin/bash
clear

# Initialise the Title Art
file1="../art/titleart.ben"
while IFS= read -r line
do
    echo "$line"
done < "$file1"
echo
leverstate=$(cat ../logic/telephonelogic.ben)
# Everybody clap your hands. I mean, here is the script.
sleep 1
echo "Vous atteignez une zone remplie de jeunes épineux"
echo "Vous reconnaissez des prunus, des aubépines."
echo "Quelques génévriers dont vous remarquez les baies noires."
echo "Un peu plus loin ce sont les ronces."
echo
echo "Plus vous progressez plus vous souffrez des épines. Existe-t-il un passage? Qui sait."
echo
echo "Que voulez-vous faire?"

# And here's what you could have won...
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        n ) echo "Un énorme roncier vous barre la route. Ça ne passe pas." ;;
        s ) echo "Au sud, vous apercevez une clairière." 
            ./clairiere.sh
            exit ;;
        e ) ./mainroom.sh
            exit ;;
        w ) echo "Vous voyez le même paysage à perte de vue" ;;
        u ) echo "Vous cueillez une baie de genévrier. Vous la portez à la bouche. Croquez. La saveur est délicieuse. La force de la plante vous envahit." ;;
        h ) echo "Ce type de terrain est caractéristique des zones déboisées. La nature sort ses épines pour protéger les arbres qui poussent en dessous." ;;
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
        * ) 
            echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h.."
            ;;
    esac
done

        done
    fi
    ;;

        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont : n, e, s, w, u et h..";;
    esac
done

esac
exit
