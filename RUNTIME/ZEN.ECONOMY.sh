################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ ZEN.ECONOMY.sh
#~ Make payments between UPlanet / NODE / Captain & NOSTR / PLAYERS Cards
################################################################################
# Ce script gère l'économie de l'écosystème UPlanet :
# 1. Vérifie les soldes des différents acteurs (UPlanet, Node, Captain)
# 2. Gère le paiement quotidien de la PAF (Participation Aux Frais)
# 3. Implémente le système de solidarité entre les nœuds
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"
################################################################################
start=`date +%s`

#######################################################################
# Vérification des soldes des différents acteurs du système
# UPlanet : La "banque centrale" coopérative
# Node : Le serveur physique (PC Gamer ou RPi5)
# Captain : Le gestionnaire du Node
#######################################################################
echo "UPlanet G1PUB : ${UPLANETG1PUB}"
UCOIN=$(${MY_PATH}/../tools/COINScheck.sh ${UPLANETG1PUB} | tail -n 1)
UZEN=$(echo "($UCOIN - 1) * 10" | bc | cut -d '.' -f 1)
echo "$UZEN Ẑen"

# Vérification du Node (Astroport)
NODEG1PUB=$($MY_PATH/../tools/ipfs_to_g1.py ${IPFSNODEID})
echo "NODE G1PUB : ${NODEG1PUB}"
NODECOIN=$(${MY_PATH}/../tools/COINScheck.sh ${NODEG1PUB} | tail -n 1)
NODEZEN=$(echo "($NODECOIN - 1) * 10" | bc | cut -d '.' -f 1)
echo "$NODEZEN Ẑen"

# Vérification du Captain (gestionnaire)
echo "CAPTAIN G1PUB : ${CAPTAING1PUB}"
CAPTAINCOIN=$(${MY_PATH}/../tools/COINScheck.sh ${NODEG1PUB} | tail -n 1)
CAPTAINZEN=$(echo "($CAPTAINCOIN - 1) * 10" | bc | cut -d '.' -f 1)
echo "$CAPTAINZEN Ẑen"

#######################################################################
# Comptage des utilisateurs actifs
# NOSTR : Utilisateurs avec carte NOSTR (4 Ẑen/mois)
# PLAYERS : Utilisateurs avec carte ZEN (16 Ẑen/mois)
#######################################################################
NOSTRS=($(ls -t ~/.zen/game/nostr/ 2>/dev/null | grep "@" ))
PLAYERS=($(ls -t ~/.zen/game/players/ 2>/dev/null | grep "@" ))
echo "NODE hosts NOSTR : ${#NOSTRS[@]} / ZEN : ${#PLAYERS[@]}"

#######################################################################
# Configuration des paramètres économiques
# PAF : Participation Aux Frais (coûts de fonctionnement)
# NCARD : Coût mensuel de la carte NOSTR
# ZCARD : Coût mensuel de la carte ZEN
#######################################################################
[[ -z $PAF ]] && PAF=56  # PAF mensuel par défaut
[[ -z $NCARD ]] && NCARD=4  # Coût mensuel carte NOSTR
[[ -z $ZCARD ]] && ZCARD=16  # Coût mensuel carte ZEN

# Calcul du PAF quotidien (PAF mensuel / 28 jours)
DAILYPAF=$(makecoord $(echo "$PAF / 28" | bc -l))
echo "ZEN ECONOMY : $PAF ($DAILYPAF ZEN) :: NCARD=$NCARD // ZCARD=$ZCARD"
DAILYG1=$(makecoord $(echo "$DAILYPAF / 10" | bc -l))

#######################################################################
# Système de solidarité : Paiement de la PAF
# Si le Captain a assez de Ẑen, il paie la PAF
# Sinon, UPlanet (la caisse commune) paie la PAF
#######################################################################
if [[ $(echo "$NODECOIN >= 1" | bc -l) -eq 1 ]]; then
    if [[ $(echo "$CAPTAINZEN > $DAILYPAF" | bc -l) -eq 1 ]]; then
        ## CAPTAIN CAN PAY NODE : ECONOMY +
        CAPTYOUSER=$($MY_PATH/../tools/clyuseryomail.sh ${CAPTAINEMAIL})
        ${MY_PATH}/../tools/PAY4SURE.sh "$HOME/.zen/game/players/.current/secret.dunikey" "$DAILYG1" "${NODEG1PUB}" "UPLANET${UPLANETG1PUB:0:8}:$CAPTYOUSER:PAF" 2>/dev/null
    else
        ## UPLANET MUST PAY NODE: ECONOMY -
        ${MY_PATH}/../tools/PAY4SURE.sh "$HOME/.zen/game/uplanet.dunikey" "$DAILYG1" "${NODEG1PUB}" "UPLANET${UPLANETG1PUB:0:8}:PAF" 2>/dev/null
    fi
else
    echo "NODE $NODECOIN G1 is NOT INITIALIZED !! UPlanet send 1 G1 to NODE"
    ${MY_PATH}/../tools/PAY4SURE.sh "$HOME/.zen/game/uplanet.dunikey" "1" "${NODEG1PUB}" "UPLANET${UPLANETG1PUB:0:8}:$IPFSNODEID:INIT" 2>/dev/null
fi

#######################################################################

## AFTER PAF PAYMENT: CHECK SWARM SUBSCRIPTIONS
${MY_PATH}/ZEN.SWARM.payments.sh

exit 0
