#!/bin/bash
clear

# This is the endgame. This file does nothing but give you the final bit of storyline.
# Use (over-use) of 'sleep' is for dramatic effect - play around with it, see how it reads.

# Let's reset the lever, now that we're done with it.
sed -i 's/on/off/' ../logic/leverlogic.ben

# Initialise the Title Art
file1="../art/titleart.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"
echo
sleep 1
echo "Voici la fin de cette petite aventure."
echo
sleep 4
echo "Vous venez de visiter la forêt où s'est posé Astroport ONE."
sleep 3
echo
echo "Une oeuvre habitable. Un jardin sur sol vivant. Un progamme pair à pair interplanétaire"
sleep 4
echo
echo "Les terraformeurs"
echo "En quête de la meilleure façon de vivre sur le vaisseau spatial Terre..."
echo
sleep 5
echo "Vous aussi ouvrez votre Ambassade."
echo "Activez le JEu. Invitez vos visiteurs à rêver d'un monde meilleur"
echo "Reproduisez, améliorez, partagez les plans pour y parvenir."
echo
sleep 7
echo "Il est l'heure de laisser derrière vous la civilisation thermo industrielle."
echo "Gagnez en autonomie, en convivialité, en optimisme, en conscience."
echo
sleep 5
echo
echo "EMBARQUEZ VERS LE FUTUR"
echo
sleep 9
echo
file1="../art/bigfinish.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"
echo
echo
read -p "Appuyez sur [ENTER] pour terminer..."
echo
clear
file1="../art/titleart.ben"
while IFS= read -r line
do
    echo "$line"
done <"$file1"
echo
echo "Merci d'avoir joué le jeu"
echo "Je suis heureux de vous avoir fait partager le rêve des astronautes terraformeurs."
echo
echo "Le futur ne se prédit pas, il se construit. Il se vit."
echo
echo "                                                                - @Fred"
echo

# That's all, folks!

exit
