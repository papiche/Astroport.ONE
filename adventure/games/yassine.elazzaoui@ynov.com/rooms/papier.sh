#!/bin/bash
clear

# Initialise the Title Art
file1="../art/pfc.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"
echo

# Fonction pour générer le choix du génie
function choix_genie {
    choix=("pierre" "feuille" "ciseaux")
    choix_genie=${choix[$RANDOM % 3]}
}

# Fonction pour déterminer le gagnant
function determiner_gagnant {
    if [ "$1" == "$2" ]; then
        echo "C'est une égalité !"
    elif [ "$1" == "pierre" -a "$2" == "ciseaux" ] || [ "$1" == "feuille" -a "$2" == "pierre" ] || 
    [ "$1" == "ciseaux" -a "$2" == "feuille" ]; then
        echo "Tu as gagné! le génie ne te félicite même pas et disparait en lâchant un grognement malotru"
    else
        echo "Le génie a gagné et aspire ton âme, retour au début."
        ./mainroom.sh
            exit ;;
    fi
}

# Fonction principale du jeu
function jouer {
    echo "Choisis entre pierre, feuille et ciseaux :"
    read choix_joueur

    # Vérifier si le choix est valide
    if [ "$choix_joueur" != "pierre" ] && [ "$choix_joueur" != "feuille" ] && [ "$choix_joueur" != "ciseaux" ]; then
        echo "Choix invalide. Veuillez choisir entre pierre, feuille et ciseaux."
        jouer
    else
        choix_genie
        echo "L'ordinateur a choisi $choix_genie."
        determiner_gagnant "$choix_joueur" "$choix_genie"
    fi
}

#jeu pierre feuille ciseau

echo
echo "Vous lui demandez ce qu'il attends de vous mais il ne réponds pas, il vous regarde de haut en bas comme
        un prédateur jaugeant sa proie, il laisse échapper un soupir puis d'un geste vif et brusque ramènes son poing en face
        de votre figure! veut-il se battre? non, il secoue sa main de haut en bas et vous comprenez qu'il vous défie à une partie
        de pierre feuille ciseau, mais qu'y a t-il a gagné ? et surtout, que se passera t-il en cas de défaite?"
echo

# Appeler la fonction principale
jouer
