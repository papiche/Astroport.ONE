#!/bin/bash
clear
# Initialise the Title Art
file1="../art/titleart.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"
echo

# I like this room. There is no way to get out of it alive.
sleep 1
echo "Un évier derrière une fenère, une ancienne porte d'armoire comme table."
echo "Un meuble fait de planches de bois cousues rempli de bocaux"
echo "Une glacière recouverte d'une couche d'isolant Un bruleur à gaz."
echo "C'est un espace pour cuisiner."
sleep 1
echo
echo "Vous avez soif. Un filtre à eau gravitationnel vous fait face"
echo "vous attraper un gobelet et le remplissez à raz bord du liquide de la bombone"
echo "Vous portez le verre à vos lèvres..."
echo
sleep 1
echo "A la première gorgée vous vous sentez ramolir. Comment savoir combien vous avez bu"
echo "quand votre corps devenu impossible à garder droit s'est éffondré sur le sol."
echo "Simplement le temps de vous demander pourquoi?"
echo
echo "Vous sombrez dans l'inconscience."
sleep 1
echo "VOUS VOUS SENTEZ DECOLLER."
echo
./prison.sh

exit
