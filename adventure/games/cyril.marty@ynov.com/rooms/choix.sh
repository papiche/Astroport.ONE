
#!/bin/bash
clear
echo "_________                        __  .__                                                                                              "
echo "\_   ___ \_______   ____ _____ _/  |_|__| ____   ____      "
echo "/    \  \/\_  __ \_/ __ \\__  \\   __\  |/  _ \ /    \    "
echo "\     \____|  | \/\  ___/ / __ \|  | |  (  <_> )   |  \   "
echo " \______  /|__|    \___  >____  /__| |__|\____/|___|  /  "
echo "        \/             \/     \/                    \/   "

# Vérifier si le dossier "personnages" existe, sinon le créer
dossier_personnages="personnages"
if [ ! -d "$dossier_personnages" ]; then
    mkdir "$dossier_personnages"> /dev/null 2>&1
fi

# Fonction pour afficher les options et obtenir un choix de l'utilisateur
afficher_options() {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "Options disponibles :"
    echo "1. Créer un nouveau personnage"
    echo "2. Charger un personnage existant"
    echo "3. Quitter"
    echo "4. Commencer à jouer"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
}

# Fonction pour créer un personnage
creer_personnage() {
    read -p "Entrez le nom de votre personnage : " nom
    echo "Classes disponibles :"
    echo "1. Bicraveur : Vendez ce qui est impossible à vendre + 10 en dextérité"
    echo "2. Nikmook : Il a un besoin irrémédiable de séduire les daronnes + 10 en agilité"
    echo "3. Freefighter : Doit devenir le plus fort en combat + 10 en Force"
    echo "4. Hacker : Doit trouver un fichier compromettant sur le proviseur pour réussir + 10 en Intelligence"
    read -p "Choisissez une classe (1/2/3/4) : " classe

    case $classe in
        1)
            classe="Bicraveur"
            ;;
        2)
            classe="Nikmook"
            ;;
        3)
            classe="Freefighter"
            ;;
        4)
            classe="Hacker"
            ;;
        *)
            echo "Classe invalide."
            return
            ;;
    esac
mkdir "personnages/$nom"> /dev/null 2>&1

    echo "Équipements disponibles :"
    echo "1. Sacoche Lacoste + 5 en dextérité"
    echo "2. Bâton magique +5 en agilité"
    echo "3. Gant de boxe +5 en force"
    echo "4. Laptop +5 en Intelligence"
    read -p "Choisissez un équipement (1/2/3/4) : " equipement

    case $equipement in
        1)
            equipement="Sacoche Lacoste"
            ;;
        2)
            equipement="Bâton magique"
            ;;
        3)
            equipement="Gant de boxe"
            ;;
        4)
            equipement="Laptop"
            ;;
        *)
            echo "Équipement invalide."
            return
            ;;
    esac

    # Créer un fichier de sauvegarde pour le personnage
    nom_fichier="$dossier_personnages/$nom/$nom.txt"
    stats="$dossier_personnages/$nom/$nom_fichier_stats.txt"
    echo "Nom : $nom" > "$nom_fichier"
    echo "Classe : $classe" >> "$nom_fichier"
    echo "Équipement de base : $equipement" >> "$nom_fichier"
    echo "Point de vie : 100" > "$nom_fichier_stats"
# Assurez-vous que le fichier stats existe
stats="$dossier_personnages/$nom/$nom-fichier_stats.txt"
if [ ! -f "$stats" ]; then
    echo "Point de vie : 100" > "$stats"
    echo "Dextérité : 0" >> "$stats"
    echo "Force : 0" >> "$stats"
    echo "Agilité : 0" >> "$stats"
    echo "Intelligence : 0" >> "$stats"
fi

# Mettez à jour les points en fonction de la classe
case $classe in
    "Bicraveur")
        sed -i "s/Dextérité : .*/Dextérité : 10/" "$stats"
        ;;
    "Nikmook")
        sed -i "s/Agilité : .*/Agilité : 10/" "$stats"
        ;;
    "Freefighter")
        sed -i "s/Force : .*/Force : 10/" "$stats"
        ;;
    "Hacker")
        sed -i "s/Intelligence : .*/Intelligence : 10/" "$stats"
        ;;
esac

mkdir "$dossier_personnages/$nom/$nom-inventaire.txt"> /dev/null 2>&1

# Mettez à jour les points en fonction de l'équipement
case $equipement in
    "Sacoche Lacoste")
        # Obtenir la valeur actuelle de la dextérité
        valeur_dexterite=$(grep "Dextérité" "$stats" | awk '{print $3}')
        # Ajouter 5 à la valeur actuelle et mettre à jour le fichier
        nouvelle_dexterite=$((valeur_dexterite + 5))
        sed -i "s/Dextérité : .*/Dextérité : $nouvelle_dexterite/" "$stats"
        ;;
    "Bâton magique")
        # Obtenir la valeur actuelle de l'agilité
        valeur_agilite=$(grep "Agilité" "$stats" | awk '{print $3}')
        # Ajouter 5 à la valeur actuelle et mettre à jour le fichier
        nouvelle_agilite=$((valeur_agilite + 5))
        sed -i "s/Agilité : .*/Agilité : $nouvelle_agilite/" "$stats"
        ;;
    "Gant de boxe")
        # Obtenir la valeur actuelle de la force
        valeur_force=$(grep "Force" "$stats" | awk '{print $3}')
        # Ajouter 5 à la valeur actuelle et mettre à jour le fichier
        nouvelle_force=$((valeur_force + 5))
        sed -i "s/Force : .*/Force : $nouvelle_force/" "$stats"
        ;;
    "Laptop")
        # Obtenir la valeur actuelle de l'intelligence
        valeur_intelligence=$(grep "Intelligence" "$stats" | awk '{print $3}')
        # Ajouter 5 à la valeur actuelle et mettre à jour le fichier
        nouvelle_intelligence=$((valeur_intelligence + 5))
        sed -i "s/Intelligence : .*/Intelligence : $nouvelle_intelligence/" "$stats"
        ;;
esac

# Enregistrez l'équipement dans un fichier équipement
equipement_file="$dossier_personnages/$nom/$nom-equipement.txt"
echo "Équipement choisi : $equipement" > "$equipement_file"
    echo "Personnage créé et sauvegardé dans $nom_fichier."
}


# Boucle principale
while true; do
    afficher_options
    read -p "Choisissez une option (1/2/3) : " choix

    case $choix in
        1)
            creer_personnage
            ;;
        2)
    echo ""
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
ls personnages/
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo ""
            read -p "Entrez le nom du personnage à charger : " nom
            nom_fichier="$dossier_personnages/$nom/$nom.txt"
            if [ -f "$nom_fichier" ]; then
                cat "$nom_fichier"
            else
                echo "Personnage introuvable."
            fi
            ;;
        3)
            exit
            ;;
        4)
            # Exécutez le script menu.sh
            ./menu.sh "$nom"
            ;;
        *)
            echo "Option invalide. Veuillez choisir une option valide."
            ;;
    esac
done
# Effacer l'écran avant de passer à la suite du jeu
clear


