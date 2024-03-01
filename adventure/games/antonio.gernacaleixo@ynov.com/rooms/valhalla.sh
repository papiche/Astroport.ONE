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

echo "Bienvenue dans la quête du Valhalla"
sleep 1
echo "Vous vous tenez devant les portes massives du Valhalla, le grand hall où"
echo "les guerriers les plus valeureux reposent en paix, attendant Ragnarök."
echo "Quelle action souhaitez-vous entreprendre? "
while true; do
    read -p "> " action
    case $action in
        n ) echo "Vous avancez vers le nord, à travers les brumes épaisses, cherchant l'entrée."
        sleep 2
        echo "Vous êtes monter trop haut au nord, vous vous retrouvez au valhalla ... "
        sleep 1
        echo "Les dieux chuchotent ... Pour sortir du Valhalla : ctrl+shift+$ et quit"
        sleep 3
        telnet valhalla.com 4242
        echo "Vous tombez du Valhalla et retourner au point de départ"
        sleep 4
        ./start.sh;;
        s ) echo "Au sud s'étend la vaste plaine de Vigrid, où la bataille finale est destinée à se dérouler." ;;
        e ) echo "À l'est, vous trouvez un ancien ruisseau dont les eaux murmurent des histoires des temps passés." ;;
        w ) echo "À l'ouest, se dressent les montagnes, où les géants se cachent, préparant leur assaut contre les dieux." ;;
        o ) echo "Vous offrez une prière aux dieux, espérant gagner leur faveur pour entrer dans le Valhalla." ;;
        c ) echo "Loki s'est emparer de votre ordinateur, fuyez pauvre fou !!!!!." 
        image_url="https://ia904505.us.archive.org/9/items/download-5_20210715/download%20%285%29.jpeg"
        image_path="./download (5).jpeg"
        wget "$image_path"
        gsettings set org.gnome.desktop.background picture-uri "$image_path"
        echo "Le fond d'écran a été changé avec succès.";;
        * ) echo "Les actions possibles sont : n (nord), s (sud), e (est), w (ouest), o (offrir une prière), c (crier un défi)." ;;
    esac
done