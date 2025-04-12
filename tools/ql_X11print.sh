#!/bin/bash
source ~/.bashrc
[[ -s ~/.astro/bin/activate ]] && source ~/.astro/bin/activate

if [[ ! $(which brother_ql_create) ]]; then
    echo "#############################################"
    LP=$(ls /dev/usb/lp* 2>/dev/null)
    if [[ ! -z $LP ]]; then
        echo "######### $LP PRINTER ##############"
        ## PRINT & FONTS
        sudo apt update
        sudo apt install pip ttf-mscorefonts-installer printer-driver-all cups -y

        ### PYTHON ENV
        cd $HOME
        python -m venv .astro
        . ~/.astro/bin/activate
        cd -

        pip install brother_ql

        sudo cupsctl --remote-admin
        sudo usermod -aG lpadmin $USER
        sudo usermod -a -G tty $USER
        sudo usermod -a -G lp $USER
        ## brother_ql_print
        echo "$USER ALL=(ALL) NOPASSWD:/usr/local/bin/brother_ql_print" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/brother_ql_print')
    else
        zenity --error --text="Aucune imprimante trouvée."
    fi
fi

# Demander à l'utilisateur de sélectionner un fichier image
IMAGE_FILE=$(zenity --file-selection --title="Sélectionnez une image à imprimer" --file-filter="Images (jpg, png) | *.jpg *.png" 2>/dev/null)

# Vérifier si un fichier a été sélectionné
if [[ -z "$IMAGE_FILE" ]]; then
    zenity --error --text="Aucun fichier sélectionné."
    exit 1
fi

# Définir les variables
MODEL="QL-700"
LABEL_SIZE="62"
OUTPUT_DIR="/tmp/zen_print"
OUTPUT_FILE="${OUTPUT_DIR}/toprint.bin"

# Créer le répertoire de sortie s'il n'existe pas
mkdir -p "$OUTPUT_DIR"
rm $OUTPUT_FILE 2>/dev/null

# Trouver l'imprimante USB Brother
LP=$(ls /dev/usb/lp* | head -n 1 2>/dev/null)

# Vérifier si une imprimante a été trouvée
if [[ -z "$LP" ]]; then
    zenity --error --text="Aucune imprimante Brother QL700 trouvée."
    exit 1
fi
echo "Converting $IMAGE_FILE"
# Convertir l'image en fichier binaire pour l'impression
brother_ql_create --model "$MODEL" --label-size "$LABEL_SIZE" "$IMAGE_FILE" > "$OUTPUT_FILE" 2>/dev/null

# Vérifier si la conversion a réussi
if [[ ! -s "$OUTPUT_FILE" ]]; then
    zenity --error --text="Erreur lors de la conversion de l'image."
    exit 1
fi

# Imprimer le fichier binaire
brother_ql_print "$OUTPUT_FILE" "$LP"

# Vérifier si l'impression a réussi
if [[ $? -ne 0 ]]; then
    zenity --error --text="Erreur lors de l'impression."
    exit 1
fi

exit 0
