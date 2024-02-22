#!/bin/bash

# Fonction pour afficher l'interface ASCII
afficher_ascii() {
    cat << "EOF"
        ____ _           _     _ _     _                  _                 
 __/\__/ ___| |__   ___ (_)___(_) |_  | |_ ___  _ __     (_) ___ _   ___/\__
 \    / |   | '_ \ / _ \| / __| | __| | __/ _ \| '_ \    | |/ _ \ | | \    /
 /_  _\ |___| | | | (_) | \__ \ | |_  | || (_) | | | |   | |  __/ |_| /_  _\
   \/  \____|_| |_|\___/|_|___/_|\__|  \__\___/|_| |_|  _/ |\___|\__,_| \/  
                                                      |__/                  
EOF
}

# Fonction pour afficher le menu
afficher_menu() {
    echo "Choisissez une option :"
    echo "1. Lancer Astroport (RENAULD)"
    echo "2. Lancer Astropo version 974 (JANICK)"
    echo "3. Quitter"
}


# Fonction pour exécuter le premier script
executer_script1() {
    echo "Exécution de Astroport..."
    # Ajoutez ici la commande pour lancer votre premier script
    "/home/janick/Astroport.ONE/adventure/adventure.sh"
}

# Fonction pour exécuter le deuxième script
executer_script2() {
    echo "Exécution de Astropo version 974..."
    # Ajoutez ici la commande pour lancer votre deuxième script
    "/home/janick/Astroport.ONE-master (1)/Astroport.ONE-master/adventure/games/Astropo_version_974/adventure.sh"

}

# Boucle principale du menu
while true; do
    clear  # Efface l'écran pour un affichage propre
    afficher_ascii
    afficher_menu

    read -p "Choix : " choix

    case $choix in
        1)
            executer_script1
            ;;
        2)
            executer_script2
            ;;
        3)
            echo "Au revoir!"
            exit 0
            ;;
        *)
            echo "Option invalide. Veuillez choisir une option valide."
            ;;
    esac

    read -p "Appuyez sur Entrée pour continuer..."
done
