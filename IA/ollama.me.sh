#!/bin/bash
## Check for local ollama 11434 port open
## Else try to open ssh port forward tunnel (could be ipfs p2p if 2122 port is not opened)
## Will be extended to load balance GPU units to every RPi Stations
## Spread IA to whole Swarm
########################################################
## TODO : Get in swarm GPU Station
########################################################
# Configuration
LOCAL_PORT=11434
REMOTE_USER="frd"
REMOTE_HOST="scorpio.copylaradio.com"
REMOTE_PORT=2122
SSH_OPTIONS="-fN -L $LOCAL_PORT:127.0.0.1:$LOCAL_PORT"

# Fonction pour vérifier si le port est ouvert
check_port() {
    if lsof -i :$LOCAL_PORT >/dev/null; then
        echo "Le port $LOCAL_PORT est déjà ouvert."
        return 0
    else
        echo "Le port $LOCAL_PORT n'est pas ouvert."
        return 1
    fi
}

# Fonction pour établir le tunnel SSH
establish_tunnel() {
    echo "Tentative d'établissement du tunnel SSH..."
    if ssh $SSH_OPTIONS $REMOTE_USER@$REMOTE_HOST -p $REMOTE_PORT; then
        echo "Tunnel SSH établi avec succès."
        return 0
    else
        echo "Échec de l'établissement du tunnel SSH."
        return 1
    fi
}

# Fonction pour fermer le tunnel SSH
close_tunnel() {
    echo "Fermeture du tunnel SSH..."
    # Trouver le processus SSH utilisant le port local
    PID=$(lsof -t -i :$LOCAL_PORT)
    if [ -z "$PID" ]; then
        echo "Aucun tunnel SSH trouvé sur le port $LOCAL_PORT."
        return 1
    else
        kill $PID
        if [ $? -eq 0 ]; then
            echo "Tunnel SSH fermé avec succès."
            return 0
        else
            echo "Échec de la fermeture du tunnel SSH."
            return 1
        fi
    fi
}

# Vérification des arguments
if [ "$1" == "OFF" ]; then
    close_tunnel
    exit $?
fi

# Vérification initiale du port
if check_port; then
    exit 0
fi

# Tentative d'établissement du tunnel SSH
if establish_tunnel; then
    exit 0
else
    echo "Veuillez vérifier les paramètres SSH et réessayer."
    exit 1
fi

