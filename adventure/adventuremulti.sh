echo "choissez le jeu :"
echo "a - AstroPort"
echo "b - MasterGuesser"

while true; do
        read -p "> " ab
        case $ab in
                a ) ./adventure.sh
                        exit ;;
                b ) $HOME/Astroport.ONE/games/masterguesser.sh
                        exit ;;
                * ) echo "Désolé, je ne vous comprends pas. Les commandes sont : a ou b";;
        esac
done

