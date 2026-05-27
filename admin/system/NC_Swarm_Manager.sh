#!/bin/bash
################################################################################
# Outil : NC_Swarm_Manager.sh
# Description : Outil de gestion Nextcloud AIO pour Astroport.
#               Sépare la sauvegarde IPFS/NOSTR (Manifest) de la réinstallation.
# Auteur : UPlanet IA / Astroport
# License: AGPL-3.0
################################################################################

MY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASTRO_TOOLS="${HOME}/.zen/Astroport.ONE/tools"

# Variables globales importantes pour IPFS via sudo
USER_IPFS_PATH="${HOME}/.ipfs"
NC_DATA_DIR="/nextcloud-data"

# 1. Chargement de l'environnement
if [[ -f "${ASTRO_TOOLS}/my.sh" ]]; then
    source "${ASTRO_TOOLS}/my.sh"
else
    echo "❌ Erreur : Impossible de charger l'environnement Astroport (my.sh introuvable)."
    exit 1
fi

# Fonction d'affichage de l'aide
show_help() {
    echo -e "\033[1;36m============================================================\033[0m"
    echo -e "\033[1;36m           NC_Swarm_Manager.sh - Astroport.ONE              \033[0m"
    echo -e "\033[1;36m============================================================\033[0m"
    echo "Gère les sauvegardes et l'infrastructure Nextcloud AIO."
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options disponibles :"
    echo "  --backup    Génère un Manifest IPFS (liste des CIDs) des fichiers de"
    echo "              chaque utilisateur et envoie le résultat par DM NIP-44."
    echo "              (N'affecte pas le fonctionnement de Nextcloud)"
    echo ""
    echo "  --rebuild   DÉTRUIT tous les conteneurs et données Nextcloud AIO,"
    echo "              puis relance un mastercontainer vierge."
    echo ""
    echo "  --help      Affiche ce message d'aide."
    echo ""
    echo "Exemple : $0 --backup"
}

# Fonction de Backup
do_backup() {
    echo -e "\n\033[1;34m[ SAUVEGARDE IPFS ET NOTIFICATION NOSTR ]\033[0m"

    # Demander et mémoriser le mot de passe sudo au début
    echo "🔑 Vérification des droits d'administration pour lire les fichiers Nextcloud..."
    sudo -v || { echo "❌ Droits sudo requis."; exit 1; }

    # S'assurer que le chemin par défaut existe, sinon demander
    if ! sudo test -d "$NC_DATA_DIR"; then
        read -e -i "/var/lib/docker/volumes/nextcloud_aio_nextcloud_data/_data" -p "Dossier introuvable. Entrez le chemin des données NC : " NC_DATA_DIR
    fi

    if ! sudo test -d "$NC_DATA_DIR"; then
        echo "❌ Erreur : Le répertoire $NC_DATA_DIR n'existe pas."
        exit 1
    fi

    TEMP_MANIFEST_DIR="/tmp/nc_manifests_$$"
    mkdir -p "$TEMP_MANIFEST_DIR"

    # Parcourir les comptes MULTIPASS locaux
    for user_dir in "${HOME}/.zen/game/nostr/"*@*; do
        [[ ! -d "$user_dir" ]] && continue
        EMAIL=$(basename "$user_dir")
        
        # Identifier le login Nextcloud associé
        YOUSER=$("${ASTRO_TOOLS}/clyuseryomail.sh" "$EMAIL")
        USER_NC_PATH="${NC_DATA_DIR}/${YOUSER}/files"
        
        if sudo test -d "$USER_NC_PATH" && [[ -s "${user_dir}/.secret.nostr" ]]; then
            echo "📦 Traitement de l'utilisateur : $EMAIL ($YOUSER)..."
            
            MANIFEST_FILE="${TEMP_MANIFEST_DIR}/manifest_${YOUSER}.json"
            
            echo "   -> Lecture des fichiers et ajout à IPFS..."
            
            # Utilisation de sudo IPFS_PATH pour lire les fichiers en tant que root 
            # sans casser les droits, mais en communiquant avec le noeud IPFS de l'utilisateur.
            sudo find "$USER_NC_PATH" -type f -print0 | while IFS= read -r -d '' file; do
                rel_path="${file#$USER_NC_PATH/}"
                # Ajout silencieux à IPFS via l'API locale de l'utilisateur
                cid=$(sudo IPFS_PATH="$USER_IPFS_PATH" ipfs add -Q "$file" 2>/dev/null)
                if [[ -n "$cid" ]]; then
                    printf '%s\t%s\0' "$rel_path" "$cid"
                fi
            done | jq -R -s -c '
                split("\u0000") | map(select(length > 0) | split("\t")) | map({"file": .[0], "cid": .[1]})
            ' > "$MANIFEST_FILE"
            
            FILE_COUNT=$(jq 'length' "$MANIFEST_FILE" 2>/dev/null || echo "0")
            if [[ "$FILE_COUNT" -eq 0 ]]; then
                echo "   -> Aucun fichier trouvé pour $EMAIL, on passe."
                rm -f "$MANIFEST_FILE"
                continue
            fi
            
            echo "   -> $FILE_COUNT fichier(s) indexé(s) dans le manifest."
            
            # Ajouter le manifest à IPFS
            MANIFEST_CID=$(ipfs add -Q "$MANIFEST_FILE")
            echo "   -> CID du manifest de sauvegarde : $MANIFEST_CID"
            
            # Extraire NSEC et HEX
            source "${user_dir}/.secret.nostr"
            
            # Préparer le message DM NIP-44 (Auto-DM)
            TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
            DM_MESSAGE="💾 [SAUVEGARDE NEXTCLOUD TERMINÉE]
Date : $TIMESTAMP

Vos fichiers Nextcloud ont été sauvegardés sur le réseau décentralisé IPFS.

📌 CID de votre Manifeste JSON : $MANIFEST_CID
🔗 Consulter l'inventaire : ${myIPFS}/ipfs/${MANIFEST_CID}

Ce fichier JSON contient la liste exacte de vos fichiers ainsi que leur nouveau CID IPFS individuel."

            # Envoyer le DM NIP-44 à soi-même (sender=NSEC, recipient=HEX)
            echo "   -> Envoi du DM NOSTR NIP-44 chiffré..."
            python3 "${ASTRO_TOOLS}/nostr_send_secure_dm.py" "$NSEC" "$HEX" "$DM_MESSAGE" "${myRELAY:-ws://127.0.0.1:7777}" >/dev/null 2>&1
            
            echo "   ✅ Backup terminé pour $EMAIL."
            rm -f "$MANIFEST_FILE"
        else
            echo "⏭️  Ignoré : $EMAIL (Pas de fichiers ou pas de clés NOSTR)."
        fi
    done
    rm -rf "$TEMP_MANIFEST_DIR"
    echo -e "\033[1;32m🎉 Sauvegarde globale terminée.\033[0m"
}

# Fonction de Destruction/Reconstruction
do_rebuild() {
    echo -e "\n\033[1;31m[ PROCÉDURE DE DESTRUCTION ET RÉINSTALLATION NEXTCLOUD AIO ]\033[0m"
    echo "⚠️  ATTENTION : Tous vos conteneurs, bases de données, et fichiers Nextcloud"
    echo "sur ce nœud vont être supprimés DÉFINITIVEMENT."
    echo ""
    read -p "Pour confirmer, tapez le mot 'DETRUIRE' (en majuscules) : " CONFIRM
    if [[ "$CONFIRM" != "DETRUIRE" ]]; then
        echo "Annulation."
        exit 0
    fi

    echo "🔑 Vérification des droits d'administration..."
    sudo -v || { echo "❌ Droits sudo requis."; exit 1; }

    echo "🛑 Arrêt des conteneurs..."
    sudo docker ps -a --filter "name=nextcloud-aio" -q | xargs -r sudo docker stop >/dev/null 2>&1

    echo "🗑️  Suppression des conteneurs..."
    sudo docker ps -a --filter "name=nextcloud-aio" -q | xargs -r sudo docker rm >/dev/null 2>&1

    echo "💥 Suppression des volumes Docker..."
    sudo docker volume ls --filter "name=nextcloud_aio" -q | xargs -r sudo docker volume rm >/dev/null 2>&1

    if sudo test -d "$NC_DATA_DIR"; then
        echo "🧹 Nettoyage total de $NC_DATA_DIR..."
        sudo rm -rf "${NC_DATA_DIR:?}"/*
    fi

    echo -e "\n\033[1;32m[ RENAISSANCE (RESTART) ]\033[0m"
    echo "🌱 Lancement du Mastercontainer Nextcloud AIO..."
    sudo docker run \
    --sig-proxy=false \
    --name nextcloud-aio-mastercontainer \
    --restart always \
    --publish 8002:8080 \
    --publish 8443:8443 \
    --env APACHE_PORT=8001 \
    --env APACHE_IP_BINDING=127.0.0.1 \
    --env NEXTCLOUD_DATADIR="${NC_DATA_DIR}" \
    --volume nextcloud_aio_mastercontainer:/mnt/docker-aio-config \
    --volume /var/run/docker.sock:/var/run/docker.sock:ro \
    -d nextcloud/all-in-one:latest >/dev/null

    echo -e "\n🎉 Le nouveau conteneur est lancé."
    echo "👉 Rendez-vous sur https://$(hostname -I | awk '{print $1}'):8443 pour refaire l'installation initiale."
    echo "(Mot de passe d'initialisation : exécutez 'sudo docker logs nextcloud-aio-mastercontainer')"
}


# ==============================================================================
# ENTRY POINT
# ==============================================================================

# Si pas d'argument, ou demande d'aide
if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_help
    exit 0
fi

# Parsing de la commande
case "$1" in
    --backup)
        # Vérification IPFS requise uniquement pour le backup
        if ! ipfs id >/dev/null 2>&1; then
            echo "❌ Erreur : Le daemon IPFS ne semble pas tourner."
            exit 1
        fi
        do_backup
        ;;
    --rebuild)
        do_rebuild
        ;;
    *)
        echo "❌ Option inconnue : $1"
        echo ""
        show_help
        exit 1
        ;;
esac