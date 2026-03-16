#!/bin/bash

# =============================================
# Gestionnaire de politiques de redémarrage Docker
# Auteur : Le Chat (Mistral AI)
# Description : Ce script permet de lister et modifier les politiques de redémarrage des conteneurs Docker.
# =============================================

# Fonction pour afficher l'aide
show_help() {
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options :"
    echo "  --help, -h      Afficher cette aide."
    echo "  --list, -l      Lister les politiques de redémarrage de tous les conteneurs."
    echo "  --set, -s       Modifier la politique de redémarrage d'un conteneur spécifique."
    echo "  --set-all, -a   Appliquer la même politique de redémarrage à tous les conteneurs."
    echo ""
    echo "Exemples :"
    echo "  $0 --list"
    echo "  $0 --set"
    echo "  $0 --set-all always"
    echo ""
    echo "Politiques de redémarrage disponibles : always, unless-stopped, on-failure, no"
}

# Fonction pour lister les politiques de redémarrage de tous les conteneurs
list_restart_policies() {
    echo "=== Politique de redémarrage actuelle des conteneurs ==="
    for container in $(docker ps -aq); do
        # Récupère le nom du conteneur (sans le slash initial)
        name=$(docker inspect -f '{{.Name}}' "$container" | sed 's|/||')
        # Récupère la politique de redémarrage
        policy=$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' "$container")
        # Affiche l'ID (12 premiers caractères), le nom et la politique
        echo "ID: $(docker inspect -f '{{.Id}}' "$container" | cut -c1-12) - Nom: $name - Politique: $policy"
    done
}

# Fonction pour modifier la politique de redémarrage d'un conteneur spécifique
set_restart_policy() {
    read -p "Entrez l'ID (ou les 12 premiers caractères) du conteneur : " container_id
    read -p "Choisissez la nouvelle politique (always/unless-stopped/on-failure/no) : " new_policy

    # Vérifie si le conteneur existe
    if ! docker inspect "$container_id" &> /dev/null; then
        echo "Erreur : Conteneur non trouvé."
        return
    fi

    # Met à jour la politique de redémarrage
    docker update --restart="$new_policy" "$container_id"
    echo "Politique de redémarrage mise à jour pour le conteneur $container_id : $new_policy"
}

# Fonction pour appliquer la même politique à tous les conteneurs
set_restart_policy_all() {
    read -p "Choisissez la politique à appliquer à tous les conteneurs (always/unless-stopped/on-failure/no) : " new_policy

    # Applique la politique à chaque conteneur
    for container in $(docker ps -aq); do
        docker update --restart="$new_policy" "$container"
        name=$(docker inspect -f '{{.Name}}' "$container" | sed 's|/||')
        echo "Politique mise à jour pour $name : $new_policy"
    done
}

# Gestion des arguments en ligne de commande
if [ $# -gt 0 ]; then
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --list|-l)
            list_restart_policies
            exit 0
            ;;
        --set|-s)
            set_restart_policy
            exit 0
            ;;
        --set-all|-a)
            if [ -z "$2" ]; then
                echo "Erreur : Veuillez spécifier une politique (always/unless-stopped/on-failure/no)."
                exit 1
            fi
            new_policy="$2"
            # Vérifie que la politique est valide
            if ! [[ "$new_policy" =~ ^(always|unless-stopped|on-failure|no)$ ]]; then
                echo "Erreur : Politique invalide. Utilisez always, unless-stopped, on-failure ou no."
                exit 1
            fi
            for container in $(docker ps -aq); do
                docker update --restart="$new_policy" "$container" > /dev/null
                name=$(docker inspect -f '{{.Name}}' "$container" | sed 's|/||')
                echo "Politique mise à jour pour $name : $new_policy"
            done
            exit 0
            ;;
        *)
            echo "Option invalide. Utilisez --help pour voir les options disponibles."
            exit 1
            ;;
    esac
fi

# Menu interactif si aucun argument n'est fourni
while true; do
    echo ""
    echo "=== Gestionnaire de politiques de redémarrage Docker ==="
    echo "1. Lister les politiques de redémarrage"
    echo "2. Modifier la politique de redémarrage d'un conteneur"
    echo "3. Appliquer la même politique à tous les conteneurs"
    echo "4. Quitter"
    read -p "Choisissez une option (1/2/3/4) : " choice

    case $choice in
        1) list_restart_policies ;;
        2) set_restart_policy ;;
        3) set_restart_policy_all ;;
        4) exit 0 ;;
        *) echo "Option invalide. Veuillez réessayer." ;;
    esac
done
