#!/bin/bash

# Liste des jeux
jeux=("Super Mario" "Pokemon Rouge" "The Legend of Zelda" "Tetris" "Metroid")

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

# Fonction pour afficher le menu principal et l'interface GameBoy
afficher_interface() {
    clear
    echo "╔══════════════════════════════╗"
    echo "║        GameBoy Advance       ║"
    echo "╚══════════════════════════════╝"
    echo "  Menu principal :"
    echo "  1. Lancer Astroport (RENAULD)"
    echo "  2. Lancer Astropo version 974 (JANICK)"
    echo "  3. Jeux GameBoy"
    echo "  4. Quitter"
    echo "╚══════════════════════════════╝"
}

# Fonction pour exécuter le premier script
executer_script1() {
    echo "Exécution de Astroport..."
    # Ajoutez ici la commande pour lancer votre premier script
    "/home/janick/Astroport.ONE-master (1)/Astroport.ONE-master/adventure/adventure.sh"
}

# Fonction pour exécuter le deuxième script
executer_script2() {
    echo "Exécution de Astropo version 974..."
    # Ajoutez ici la commande pour lancer votre deuxième script
    "/home/janick/Astroport.ONE-master (1)/Astroport.ONE-master/adventure/games/Astropo_version_974/adventure.sh"
}

# Fonction pour exécuter le jeu sélectionné
executer_jeu() {
    choix=$1
    if [ "$choix" -ge 1 ] && [ "$choix" -le "${#jeux[@]}" ]; then
        jeu_selectionne="${jeux[$((choix-1))]}"
        echo "Lancement de $jeu_selectionne..."
        # Ajoutez ici la commande pour lancer votre script ou jeu
        # Par exemple : "./chemin/vers/votre_script.sh"
    elif [ "$choix" == "M" ] || [ "$choix" == "m" ]; then
        return
    elif [ "$choix" == "Q" ] || [ "$choix" == "q" ]; then
        echo "Au revoir!"
        exit 0
    else
        echo "Option invalide. Veuillez choisir une option valide."
    fi
}

# Boucle principale du menu
while true; do
    afficher_interface

    read -p "Choix : " choix

    case $choix in
        1)
            executer_script1
            ;;
        2)
            executer_script2
            ;;
        3)
            while true; do
                afficher_interface_gameboy
                read -p "Choix : " choix_jeu
                executer_jeu "$choix_jeu"
                read -p "Appuyez sur Entrée pour continuer..."
            done
            ;;
        4)
            echo "Au revoir!"
            exit 0
            ;;
        *)
            echo "Option invalide. Veuillez choisir une option valide."
            ;;
    esac
done
