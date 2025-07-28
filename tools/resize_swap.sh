#!/bin/bash

# Fonction pour détecter l'emplacement, la taille et la date de création de l'espace swap actuel
detect_swap() {
    SWAP_INFO=$(swapon --show | grep -v -e "Nom du fichier" -e "Filename")
    if [ -z "$SWAP_INFO" ]; then
        echo "Aucun espace swap actif détecté / No active swap detected."
        return 1
    else
        SWAP_PATH=$(echo "$SWAP_INFO" | awk '{print $1}')
        SWAP_SIZE=$(echo "$SWAP_INFO" | awk '{print $3}')

        # Obtenir la date de création du fichier swap
        SWAP_CREATION_DATE=$(ls -l --time=creation "$SWAP_PATH" 2>/dev/null | awk '{print $6, $7, $8}')
        if [ -z "$SWAP_CREATION_DATE" ]; then
            SWAP_CREATION_DATE=$(ls -lc "$SWAP_PATH" | awk '{print $6, $7, $8}')
        fi

        echo "Espace swap actuel / Current swap space: $SWAP_PATH"
        echo "Taille / Size: $SWAP_SIZE"
        echo "Date de création / Creation date: $SWAP_CREATION_DATE"
        return 0
    fi
}

# Fonction pour vérifier l'utilisation du swap
check_swap_usage() {
    SWAP_LINE=$(free | grep -e "Échange" -e "Swap")
    SWAP_USAGE=$(echo "$SWAP_LINE" | awk '{print $3}')

    if [ "$SWAP_USAGE" -gt 0 ]; then
        echo "Attention : L'espace swap est actuellement utilisé / Warning: Swap space is currently in use."
        echo "Il est recommandé de redémarrer votre système avant de redimensionner l'espace swap / It is recommended to reboot your system before resizing the swap space."
        return 1
    else
        echo "L'espace swap n'est pas utilisé / Swap space is not in use. You can proceed with resizing."
        return 0
    fi
}

# Fonction pour redimensionner l'espace swap
resize_swap() {
    local SWAP_PATH=$1
    local NEW_SIZE=$2

    # Désactiver l'espace swap actuel
    sudo swapoff -a

    # Supprimer l'ancien fichier swap
    sudo rm "$SWAP_PATH"

    # Créer un nouveau fichier swap
    sudo fallocate -l "$NEW_SIZE" "$SWAP_PATH"

    # Définir les permissions appropriées
    sudo chmod 600 "$SWAP_PATH"

    # Configurer le fichier comme espace swap
    sudo mkswap "$SWAP_PATH"

    # Activer le nouvel espace swap
    sudo swapon "$SWAP_PATH"

    echo "Espace swap redimensionné à $NEW_SIZE et réactivé / Swap space resized to $NEW_SIZE and reactivated."
}

# Afficher le menu
afficher_menu() {
    echo "1. Détecter l'espace swap actuel / Detect current swap space"
    echo "2. Vérifier l'utilisation du swap / Check swap usage"
    echo "3. Redimensionner l'espace swap / Resize swap space"
    echo "4. Quitter / Quit"
}

# Boucle principale du menu
while true; do
    afficher_menu
    read -rp "Choisissez une option (1-4) / Choose an option (1-4): " OPTION

    case $OPTION in
        1)
            detect_swap
            ;;
        2)
            check_swap_usage
            ;;
        3)
            check_swap_usage
            if [ $? -eq 1 ]; then
                echo "Veuillez redémarrer votre système avant de redimensionner l'espace swap / Please reboot your system before resizing the swap space."
            else
                read -rp "Entrez la nouvelle taille de l'espace swap (ex: 16G) / Enter the new size for the swap space (e.g., 16G): " NEW_SIZE
                detect_swap
                if [ $? -eq 0 ]; then
                    resize_swap "$SWAP_PATH" "$NEW_SIZE"
                else
                    echo "Impossible de redimensionner, aucun espace swap détecté / Unable to resize, no swap space detected."
                fi
            fi
            ;;
        4)
            echo "Au revoir / Goodbye!"
            exit 0
            ;;
        *)
            echo "Option invalide, veuillez réessayer / Invalid option, please try again."
            ;;
    esac
done

