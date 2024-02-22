#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################

echo
echo "Un génie maléfique apparait"
echo "Il vous regarde de haut en bas d'un air dédaigneux comme s'il attendais quelquechose de vous."
echo "Qu'allez vous faire?"
echo "1 pour fuir, 2 pour lui parler 3 pour rester silencieux et 4 pour une action mystère"
echo
while true; do
    read -p "> " nsewuh
    case $nsewuh in
        3 ) echo "Le silence deviens pesant mais le génie ne vous quitte pas du regard..." ;;
        1 ) ./mainroom.sh
            exit ;;
        2 ) ./papier.sh
            exit ;;
        4 )  echo "Votre vision se trouble et vous perdez le sens de l'équilibre, le génie est en train de vous envoyer
        des ondes cérébrales afin de communiquer, des images commencent à se former dans votre esprit"
                sleep 2
              xdg-open "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
            ;;
        * ) echo "Je suis désolé, je ne vous comprends pas. Les commandes sont :
         1 pour fuir, 2 pour lui parler 3 pour rester silencieux et 4 pour une action mystère";;
    esac
done

esac
exit
