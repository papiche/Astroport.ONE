#!/bin/bash

# Génération d'un nombre aléatoire entre 1 et 100
nombre_secret=$(shuf -i 1-100 -n 1)

echo "Bienvenue dans le jeu 'MasterGuesser' !"
sleep 1
nohup mplayer ../music/masterguesser.mp3 > /dev/null 2>&1 &
sleep 1
echo "Une seule règle, trouver le nombre aléatoire entre 1 et 100 !"
sleep 1




devine_le_nombre() {
    read -p "Ton choix : " guess

    # Vérification de la réponse
    if [ $guess -eq $nombre_secret ]; then
        echo "Félicitations ! Tu as deviné le nombre secret !"
        echo "Fin de la session..."
        # kill $!
        ## CHECK FOR ANY ALREADY RUNNING mplayer
        mplayerrunning=$(pgrep -au $USER -f 'mplayer' | tail -n 1 | xargs | cut -d " " -f 1)
        [[ $mplayerrunning ]] && kill $mplayerrunning
        exit 0
    elif [ $guess -lt $nombre_secret ]; then
        echo "Le nombre est plus grand."
        devine_le_nombre
    else
        echo "Le nombre est plus petit."
        devine_le_nombre
    fi
}

devine_le_nombre
