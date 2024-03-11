#!/bin/bash

# Fonction pour afficher l'interface du jeu
draw_game() {
    clear
    for ((i = 0; i < height; i++)); do
        for ((j = 0; j < width; j++)); do
            if [[ $i -eq 0 || $i -eq $((height - 1)) || $j -eq 0 || $j -eq $((width - 1)) ]]; then
                echo -e "\033[1;34m#\033[0m\c"
            elif [[ $i -eq $fruit_row && $j -eq $fruit_col ]]; then
                echo -e "\033[1;31m@\033[0m\c"
            else
                local is_snake_segment=false
                for ((k = 0; k < ${#snake_body_rows[@]}; k++)); do
                    if [[ $i -eq ${snake_body_rows[$k]} && $j -eq ${snake_body_cols[$k]} ]]; then
                        echo -e "\033[1;32m#\033[0m\c"
                        is_snake_segment=true
                        break
                    fi
                done
                if [[ $is_snake_segment == false ]]; then
                    echo -e " \c"
                fi
            fi
        done
        echo
    done
}

# Initialisation des variables
height=20
width=40
snake_body_rows=()
snake_body_cols=()
snake_length=1
direction="RIGHT"
fruit_row=$((RANDOM % (height - 2) + 1))
fruit_col=$((RANDOM % (width - 2) + 1))

# Position initiale du serpent
snake_body_rows[0]=$((height / 2))
snake_body_cols[0]=$((width / 2))

# Fonction pour déplacer le serpent
move_snake() {
    local i
    for ((i = ${#snake_body_rows[@]} - 1; i > 0; i--)); do
        snake_body_rows[$i]=${snake_body_rows[$((i - 1))]}
        snake_body_cols[$i]=${snake_body_cols[$((i - 1))]}
    done

    case $direction in
        "UP")
            snake_body_rows[0]=$((snake_body_rows[0] - 1))
            ;;
        "DOWN")
            snake_body_rows[0]=$((snake_body_rows[0] + 1))
            ;;
        "LEFT")
            snake_body_cols[0]=$((snake_body_cols[0] - 1))
            ;;
        "RIGHT")
            snake_body_cols[0]=$((snake_body_cols[0] + 1))
            ;;
    esac
}

# Fonction pour vérifier les collisions
check_collision() {
    if [[ ${snake_body_rows[0]} -le 0 || ${snake_body_rows[0]} -ge $((height - 1)) || ${snake_body_cols[0]} -le 0 || ${snake_body_cols[0]} -ge $((width - 1)) ]]; then
        return 1
    fi

    for ((i = 1; i < ${#snake_body_rows[@]}; i++)); do
        if [[ ${snake_body_rows[0]} -eq ${snake_body_rows[$i]} && ${snake_body_cols[0]} -eq ${snake_body_cols[$i]} ]]; then
            return 1
        fi
    done

    if [[ ${snake_body_rows[0]} -eq $fruit_row && ${snake_body_cols[0]} -eq $fruit_col ]]; then
        generate_fruit
        grow_snake
    fi

    return 0
}

# Fonction pour faire grandir le serpent
grow_snake() {
    local last_index=$(( ${#snake_body_rows[@]} - 1 ))
    local last_row=${snake_body_rows[$last_index]}
    local last_col=${snake_body_cols[$last_index]}
    snake_body_rows+=($last_row)
    snake_body_cols+=($last_col)
}

# Fonction pour générer un nouveau fruit
generate_fruit() {
    fruit_row=$((RANDOM % (height - 2) + 1))
    fruit_col=$((RANDOM % (width - 2) + 1))
}

# Boucle principale du jeu
while true; do
    draw_game
    echo "Score: ${#snake_body_rows[@]}"

    # Appel à la fonction move_snake pour que le serpent avance automatiquement
    move_snake

    read -s -t 0.2 -n 1 action

    case $action in
        "z")
            if [[ $direction != "DOWN" ]]; then
                direction="UP"
            fi
            ;;
        "s")
            if [[ $direction != "UP" ]]; then
                direction="DOWN"
            fi
            ;;
        "q")
            if [[ $direction != "RIGHT" ]]; then
                direction="LEFT"
            fi
            ;;
        "d")
            if [[ $direction != "LEFT" ]]; then
                direction="RIGHT"
            fi
            ;;
    esac

    # Vérifier les collisions après le déplacement
    check_collision
    if [[ $? -eq 1 ]]; then
        echo "Bravo ! Vous avez eu le score de ${#snake_body_rows[@]} ! Appuyez sur \"q\" pour quitter le jeu ou sur \"r\" pour rejouer"
        read -n 1 -s choice
        case $choice in
            q)
                ./kroo2.sh
                ;;
            r)
                ./meteofrance.sh
                ;;
            *)
                echo "Choix non reconnu."
                ;;
        esac
    fi
done





# #!/bin/bash
# ################################################################################
# # Author: Fred (support@qo-op.com)
# # Version: 0.1
# # License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
# ################################################################################
# MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
# mkdir -p ~/.zen/tmp/${MOATS}
# ################################################################################
# # Choisir la source de capture
# # https://fr.sat24.com/image?type=visual5HDComplete&region=fr

# MY_PATH="`dirname \"$0\"`"              # relative
# MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
# ME="${0##*/}"

# ## TEST IPFS
# [[ ! $(which ipfs) ]] && echo "Missing IPFS. Please install... https://ipfs.tech"  && exit 1

# ## PREPARE FILE SYSTEM CACHE
# mkdir -p ~/.zen/adventure/meteo.anim.eu
# rm -f ~/.zen/adventure/meteo.anim.eu/meteo.png

# ## SCRAPING meteo.png
# curl  -m 20 --output ~/.zen/adventure/meteo.anim.eu/meteo.png https://s.w-x.co/staticmaps/wu/wu/satir1200_cur/europ/animate.png

# if [[ ! -f  ~/.zen/adventure/meteo.anim.eu/meteo.png ]]; then

#     echo "Impossible de se connecter au service meteo"
#     exit 1

# else

#     echo "Mise à jour archive meteo : ${MOATS}"
#     echo ${MOATS} > ~/.zen/adventure/meteo.anim.eu/.moats

#     OLDID=$(cat ~/.zen/adventure/.meteo.index 2>/dev/null)
#         # TODO : COMPARE SIMILAR OR NOT
#         # ipfs get "/ipfs/$OLDID/meteo.anim.eu/meteo.png"

#     ## PREPARE NEW index.html
#     sed "s/_OLDID_/$OLDID/g" ${MY_PATH}/../templates/meteo_chain.html > /tmp/index.html
#     sed -i "s/_IPFSID_/$IPFSID/g" /tmp/index.html
#     sed -i "s/_DATE_/$(date -u "+%Y-%m-%d#%H:%M:%S")/g" /tmp/index.html
#     sed "s/_PSEUDO_/${USER}/g" /tmp/index.html > ~/.zen/adventure/index.html

#     # Copy style css
#     cp -r ${MY_PATH}/../templates/styles ~/.zen/adventure/

#     INDEXID=$(ipfs add -rHq ~/.zen/adventure/* | tail -n 1)
#     echo $INDEXID > ~/.zen/adventure/.meteo.index
#     echo "METEO INDEX : http://127.0.0.1:8080/ipfs/$INDEXID"

#     IPFS=$(ipfs add -q ~/.zen/adventure/meteo.anim.eu/meteo.png | tail -n 1)
#     echo $IPFS > ~/.zen/adventure/meteo.anim.eu/.chain

# fi

