#!/bin/bash

# Initialisation des variables
ball_x=10
ball_y=10
ball_vx=1
ball_vy=1
paddle_y=10
width=40
height=20

# Fonction pour dessiner le terrain
draw() {
    clear
    for ((y=0; y<=height; y++)); do
        for ((x=0; x<=width; x++)); do
            if [[ $x -eq 0 || $x -eq $width || $y -eq 0 || $y -eq $height ]]; then
                echo -n "#"
            elif [[ $x -eq $ball_x && $y -eq $ball_y ]]; then
                echo -n "O"
            elif [[ $x -eq 2 && $y -ge $paddle_y && $y -le $(($paddle_y+3)) ]]; then
                echo -n "|"
            else
                echo -n " "
            fi
        done
        echo
    done
}

# Fonction pour mettre à jour la position de la balle
update() {
    ball_x=$(($ball_x+$ball_vx))
    ball_y=$(($ball_y+$ball_vy))

    # Collision avec les bords
    if [[ $ball_x -le 1 || $ball_x -ge $((width-1)) ]]; then
        ball_vx=$((-$ball_vx))
    fi
    if [[ $ball_y -le 1 || $ball_y -ge $((height-1)) ]]; then
        ball_vy=$((-$ball_vy))
    fi

    # Collision avec la raquette
    if [[ $ball_x -eq 3 && $ball_y -ge $paddle_y && $ball_y -le $(($paddle_y+3)) ]]; then
        ball_vx=$((-$ball_vx))
    fi
}

# Boucle principale du jeu
while true; do
    draw
    update
    read -t 0.1 -n 1 key

    if [[ $key == 'z' ]]; then
        ((paddle_y--))
    elif [[ $key == 's' ]]; then
        ((paddle_y++))
    fi

    # Limiter la raquette dans le terrain
    if [[ $paddle_y -le 1 ]]; then
        paddle_y=1
    elif [[ $paddle_y -ge $(($height-4)) ]]; then
        paddle_y=$(($height-4))
    fi
done
