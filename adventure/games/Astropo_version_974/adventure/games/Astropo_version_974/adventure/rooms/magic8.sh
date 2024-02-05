#!/bin/bash

# magic 8 ball. Yup. Pick a random number, output message
# source: https://www.linuxjournal.com/content/bash-shell-games-lets-play-go-fish

answers=("Oui c'est certain." "C'est carrément ça."
  "Sans aucun doute." "Oui - assurément."
  "Comptez la dessus." "Comme je le vois, oui." "Très probablement."
  "Bonne perspective." "Oui." "Les signes indiquent que oui."
  "Réponse floue, essayez à nouveau." "Redemandez plus tard."
  "Il vaut mieux ne pas vous le dire maintenant.." "Impossible de prédire maintenant."
  "Concentrez-vous et demandez à nouveau." "N'y comptez pas."
  "Ma réponse est non." "Mes sources disent que non."
  "Rien de bon." "Très douteux.")

echo "Oh ! Boule magique, dis-moi la vérité, s'il te plaît...." ; echo ""
/bin/echo -n "Quelle est votre question ? "
read question

answer=$(( $RANDOM % 20 ))

echo ""
echo "J'ai regardé dans le futur et je dis: "
echo "     ${answers[$answer]}" ; echo ""

sleep 3
./mainroom.sh

exit
