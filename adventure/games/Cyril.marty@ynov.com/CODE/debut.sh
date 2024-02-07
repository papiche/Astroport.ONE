#!/bin/bash

# Fonction pour afficher le texte avec une pause entre les lignes
afficher_texte() {
    while read -r ligne; do
        echo "$ligne"
        sleep 1  # Pause d'une seconde entre chaque ligne
    done
}

# Titre du jeu
clear  # Effacer l'écran
echo "_______  .__ __                          __    "
echo " \      \ |__|  | __ _____   ____   ____ |  | __"
echo " /   |   \|  |  |/ //     \ /  _ \ /  _ \|  |/ /"
echo "/    |    \  |    <|  Y Y  (  <_> |  <_> )    < "
echo "\____|__  /__|__|_ \__|_|  /\____/ \____/|__|_ \""
echo "        \/        \/     \/                   \/"
echo "Bienvenue dans le jeu!"
echo

# Histoire
echo "Il était une fois, dans un lointain royaume.. un gosse mal éduquer"
echo "Un batard courageux se prépare à entreprendre une quête épique."
echo "Votre mission est de BAISER des mères périlleuses."
echo
echo "Appuyez sur ESPACE pour continuer..."
read -n 1 touche  # Attendre que l'utilisateur appuie sur ESPACE
echo

# Effacer l'écran avant de passer à la suite du jeu
clear

# Vous pouvez continuer à développer votre jeu à partir d'ici en ajoutant plus de fonctionnalités et de pages.

#read -n 1 touche  # Attendre que l'utilisateur appuie sur ESPACE
echo

# Exécuter le script suite.sh
if [ "$touche" == "" ]; then
    ./choix.sh
fi

# Effacer l'écran avant de passer à la suite du jeu
clear

