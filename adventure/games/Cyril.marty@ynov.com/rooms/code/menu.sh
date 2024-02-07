#!/bin/bash
clear
#récupérer la varible nom
nom="$1"
 
    # Afficher dynamiquement les informations du personnage à chaque fois que le menu s'affiche
cat "personnages/$nom/$nom.txt"
echo "-----------------------"
cat "personnages/$nom/$nom-fichier_stats.txt"
echo "-----------------------"

# Menu principal
while true; do
clear
    echo "--------------------------------------------------------------------------------"
    echo "                                Menu Principal                                  "
    echo "--------------------------------------------------------------------------------"
    echo ""
    echo ""
    echo "                                    ___       "
    echo "                                   |___|____  "
    echo "                                  /     \\    "
    echo "                                 | () () |    "
    echo "                                  \\  ^  /    "
    echo "                                   |||||      "
    echo "                                  /|||||\      "
    echo "                                  \|||||/     "
    echo "                                   |||||      "
    echo "                                   |||||     "
    echo "                                  /_\ /_\     "
    echo ""
    echo ""
    echo ""
    echo ""
    echo ""
    echo ""
    echo ""
    echo ""
    echo ""
    echo "1. Ouvrir le Sac                                               4. Regarder"
    echo "2. Ouvrir la carte                                             5. Agir"
    echo "3. Ouvir son portmonnaie                                       6. Se déplacer"
    echo "                                                        "
    echo "                                  7. Quitter le jeu"
    echo "                                         FDP"
    echo ""
    echo "--------------------------------------------------------------------------------"
    echo "                                                                                "
    echo "--------------------------------------------------------------------------------"

    read -p "Choisissez une option (1/2/3/4/5/6/7) : " choix

case $choix in
    1)
        # Insérez ici le code pour ouvrir le sac
        echo "Le sac n'est pas encore implémenté."
        ;;
    2)
        # Insérez ici le code pour ouvrir la carte
        if [ -f "map.sh" ]; then
            ./map.sh  # Exécuter le script si présent
        else
            echo "La carte n'est pas encore implémentée."
        fi  # Fin du bloc if
        ;;  # Fin de l'option 4
    3)
        cat "personnages/$nom/$nom-inventaire.txt"
        ;;
    4)
        afficher_statistiques_personnage
        ;;

    5)
        cat "personnages/$nom/$nom-inventaire.txt"
        ;;
    6)
        afficher_statistiques_personnage
        ;;

    7)
        exit
        ;;
    *)
        echo "Option invalide. Veuillez choisir une option valide."
        ;;
esac
done
