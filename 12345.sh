#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2 (Refactored)
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
## ASTROPORT DAEMON LAUNCHER
## Legacy port 1234 (nc) and HTTP generation removed.
## Delegates directly to _12345.sh (Swarm API & Socat server on port 12345)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized

# Chargement de l'environnement
. "${MY_PATH}/tools/my.sh"
if [ -s "$HOME/.astro/bin/activate" ]; then
    source $HOME/.astro/bin/activate
fi

export PATH=$HOME/.local/bin:$PATH

echo "_________________________________________________________"
echo "LAUNCHING Astroport ONE Supervisor : $(date)"
echo "ASTROPORT : ${myASTROPORT:-http://127.0.0.1:12345}"
echo "_________________________________________________________"

YOU=$(pgrep -au $USER -f "ipfs daemon" > /dev/null && echo "$USER")
echo "YOU=$YOU"
LIBRA=$(myIpfsGw)
echo "LIBRA=$LIBRA"
TUBE=$(myTube)
echo "TUBE=$TUBE"

# Création des dossiers de base
mkdir -p ~/.zen/tmp ~/.zen/game/players/localhost

# Nettoyage des anciens démons netcat (port 1234 et pool 457xx dépréciés)
echo "[INFO] Cleaning up legacy netcat servers..."
pkill -f 'nc -l -p 1234 ' 2>/dev/null
pkill -f 'nc -l -p 457' 2>/dev/null

# Délégation totale au vrai démon SWARM
# L'utilisation de 'exec' remplace le processus actuel par _12345.sh
# Ainsi, systemd suivra le bon PID (pas de processus fantôme)
echo "[INFO] Handing over to _12345.sh (Swarm Node Manager on port 12345)..."
exec "${MY_PATH}/_12345.sh"