# ATTENTION  POUR VOIR LES IMAGES OUVRIR LE DOCX !


Adventure.sh avec WSL

Dans un premier temps, trouver le projet cloné qui pour moi ce situe sur le bureau.
Passer par /mnt une fois l’environnement wsl lancé pour accéder au répertoire de mon windows

Résolution des bugs :
 
Supprimer le saut de ligne (ligne 20) pour la première erreur
Puis installer dos2unix pour la 2eme :
sudo apt install dos2unix

Si l’installation ne fonctionne pas, n’oubliez pas de faire :
sudo apt update
Et 
sudo apt upgrade

Une fois dos2unix installé, faites dos2unix adventure.sh pour convertir le fichier.
Maintenant nous avons ces erreurs :
 
Pour régler ça j’ai dû modifier un peu la partie des PATH dans adventure.sh :

'''
if hash uuidgen 2>/dev/null; then
    homefolder=$(pwd)
    newplayer=$(uuidgen)
    ## Copy Player Game Files
    mkdir -p "$HOME/.zen/adventure/$newplayer"
    if [ -d "$MY_PATH/rooms" ]; then
        cp -r "$MY_PATH/rooms" "$HOME/.zen/adventure/$newplayer/"
    else
        echo "Source directory $MY_PATH/rooms does not exist or is not a directory."
    fi

    if [ -d "$MY_PATH/art" ]; then
        cp -r "$MY_PATH/art" "$HOME/.zen/adventure/$newplayer/"
    else
        echo "Source directory $MY_PATH/art does not exist or is not a directory."
    fi

    if [ -d "$MY_PATH/script" ]; then
        cp -r "$MY_PATH/script" "$HOME/.zen/adventure/$newplayer/"
    else
        echo "Source directory $MY_PATH/script does not exist or is not a directory."
    fi

    if [ -d "$MY_PATH/logic" ]; then
        cp -r "$MY_PATH/logic" "$HOME/.zen/adventure/$newplayer/"
    else
        echo "Source directory $MY_PATH/logic does not exist or is not a directory."
    fi
fi
'''

Autre erreur me dit que :
 
Ça traduit une erreur d’interprétation dans le fichier « start.sh » que j’ai réglé en utilisant la commande ''' dos2unix *.sh ''' dans le dossier « rooms » pour convertir tous les fichiers :
 
BRAVO :
 
Dans le jeu on se rend compte que cette erreur apparaît :
 

Il faut installer ''' sudo apt install xdg-utils ''' ainsi que ''' sudo apt install firefox ''' pour résoudre ça 

Le levier ne fonctionne  pas, « ACTIVATION STATION » mais rien ne se passe. 

c'est parce que le script ne se souvient que du premiere appel du levier donc il faut le lui rappeller juste après l'action avec :

            leverstate=$(cat $MY_PATH/../logic/leverlogic.ben)



