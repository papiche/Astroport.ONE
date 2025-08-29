################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ ZEN.ECONOMY.sh
#~ Make payments between UPlanet / NODE / Captain & NOSTR / PLAYERS Cards
################################################################################
# Ce script gère l'économie de l'écosystème UPlanet :
# 1. Vérifie les soldes des différents acteurs (UPlanet, Node, Captain)
# 2. Gère le paiement hebdomadaire de la PAF (Participation Aux Frais)
# 3. Implémente le système de solidarité entre les nœuds
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"
################################################################################
start=`date +%s`

#######################################################################
# Weekly payment check - ensure payment is made only once per week
# Check if payment was already done this week using marker file
#######################################################################
PAYMENT_MARKER="$HOME/.zen/game/.weekly_payment.done"
rm -f "$HOME/.zen/game/.payment.done" ## TODO REMOVE

# Get current week number (ISO week)
CURRENT_WEEK=$(date +%V)
CURRENT_YEAR=$(date +%Y)
WEEK_KEY="${CURRENT_YEAR}-W${CURRENT_WEEK}"

# Check if payment was already done this week
if [[ -f "$PAYMENT_MARKER" ]]; then
    LAST_PAYMENT_WEEK=$(cat "$PAYMENT_MARKER")
    if [[ "$LAST_PAYMENT_WEEK" == "$WEEK_KEY" ]]; then
        echo "ZEN ECONOMY: Weekly payment already completed this week ($WEEK_KEY)"
        echo "Skipping payment process..."
        exit 0
    fi
fi

echo "ZEN ECONOMY: Starting weekly payment process for week $WEEK_KEY"

#######################################################################
# Vérification des soldes des différents acteurs du système
# UPlanet : La "banque centrale" coopérative
# Node : Le serveur physique (PC Gamer ou RPi5)
# Captain : Le gestionnaire du Node
#######################################################################
echo "UPlanet G1PUB : ${UPLANETG1PUB}"
UCOIN=$(${MY_PATH}/../tools/G1check.sh ${UPLANETG1PUB} | tail -n 1)
UZEN=$(echo "($UCOIN - 1) * 10" | bc | cut -d '.' -f 1)
echo "$UZEN Ẑen"

# Vérification du Node (Astroport)
NODEG1PUB=$($MY_PATH/../tools/ipfs_to_g1.py ${IPFSNODEID})
echo "NODE G1PUB : ${NODEG1PUB}"
NODECOIN=$(${MY_PATH}/../tools/COINScheck.sh ${NODEG1PUB} | tail -n 1)
NODEZEN=$(echo "($NODECOIN - 1) * 10" | bc | cut -d '.' -f 1)
echo "$NODEZEN Ẑen"

# Vérification du Captain (gestionnaire) - MULTIPASS (NOSTR)
echo "CAPTAIN G1PUB : ${CAPTAING1PUB}"
CAPTAINCOIN=$(${MY_PATH}/../tools/COINScheck.sh ${CAPTAING1PUB} | tail -n 1)
CAPTAINZEN=$(echo "($CAPTAINCOIN - 1) * 10" | bc | cut -d '.' -f 1)
echo "Captain MULTIPASS balance: $CAPTAINZEN Ẑen"

# Vérification de la ZEN Card du Captain (PLAYERS)
if [[ -n "$CAPTAINEMAIL" ]]; then
    CAPTAIN_ZENCARD_PATH="$HOME/.zen/game/players/$CAPTAINEMAIL"
    if [[ -d "$CAPTAIN_ZENCARD_PATH" && -s "$CAPTAIN_ZENCARD_PATH/secret.dunikey" ]]; then
        CAPTAIN_ZENCARD_PUB=$(cat "$CAPTAIN_ZENCARD_PATH/secret.dunikey" 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
        if [[ -n "$CAPTAIN_ZENCARD_PUB" ]]; then
            CAPTAIN_ZENCARD_COIN=$(${MY_PATH}/../tools/COINScheck.sh ${CAPTAIN_ZENCARD_PUB} | tail -n 1)
            CAPTAIN_ZENCARD_ZEN=$(echo "($CAPTAIN_ZENCARD_COIN - 1) * 10" | bc | cut -d '.' -f 1)
            echo "Captain ZEN Card balance: $CAPTAIN_ZENCARD_ZEN Ẑen"
        else
            CAPTAIN_ZENCARD_ZEN=0
            echo "Captain ZEN Card not found or invalid"
        fi
    else
        CAPTAIN_ZENCARD_ZEN=0
        echo "Captain ZEN Card not found"
    fi
else
    CAPTAIN_ZENCARD_ZEN=0
    echo "Captain email not configured"
fi

#######################################################################
# Comptage des utilisateurs actifs
# NOSTR : Utilisateurs avec carte NOSTR (1 Ẑen/semaine)
# PLAYERS : Utilisateurs avec carte ZEN (4 Ẑen/semaine)
#######################################################################
NOSTRS=($(ls -t ~/.zen/game/nostr/ 2>/dev/null | grep "@" ))
PLAYERS=($(ls -t ~/.zen/game/players/ 2>/dev/null | grep "@" ))
echo "NODE hosts MULTIPASS : ${#NOSTRS[@]} / ZENCARD : ${#PLAYERS[@]}"

#######################################################################
# Configuration des paramètres économiques
# PAF : Participation Aux Frais (coûts de fonctionnement)
# NCARD : Coût hebdomadaire de la carte NOSTR
# ZCARD : Coût hebdomadaire de la carte ZEN
#######################################################################
[[ -z $PAF ]] && PAF=14  # PAF hebdomadaire par défaut
[[ -z $NCARD ]] && NCARD=1  # Coût hebdomadaire carte NOSTR
[[ -z $ZCARD ]] && ZCARD=4  # Coût hebdomadaire carte ZEN

# PAF hebdomadaire
WEEKLYPAF=$PAF
echo "ZEN ECONOMY : PAF=$WEEKLYPAF ZEN/week :: NCARD=$NCARD // ZCARD=$ZCARD"
WEEKLYG1=$(makecoord $(echo "$WEEKLYPAF / 10" | bc -l))

##################################################################################
# Système de solidarité : Paiement hebdomadaire de la PAF = House + Electricity + IP Connexion
# Le Captain paie la PAF hebdomadaire au NODE
# Si le Captain n'a pas assez de Ẑen, UPlanet (la caisse commune) paie la PAF
#######################################################################
if [[ $(echo "$WEEKLYG1 > 0" | bc -l) -eq 1 ]]; then
    if [[ $(echo "$NODECOIN >= 1" | bc -l) -eq 1 ]]; then
        if [[ $(echo "$CAPTAINZEN > $WEEKLYPAF" | bc -l) -eq 1 ]]; then
            ## CAPTAIN MULTIPASS CAN PAY NODE : ECONOMY +
            CAPTYOUSER=$($MY_PATH/../tools/clyuseryomail.sh ${CAPTAINEMAIL})
            ${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.dunikey" "$WEEKLYG1" "${NODEG1PUB}" "UPLANET:${UPLANETG1PUB:0:8}:$CAPTYOUSER:WEEKLYPAF" 2>/dev/null
            echo "CAPTAIN MULTIPASS paid weekly PAF: $WEEKLYPAF ZEN ($WEEKLYG1 G1) to NODE"
        elif [[ $(echo "$CAPTAIN_ZENCARD_ZEN > $WEEKLYPAF" | bc -l) -eq 1 ]]; then
            ## CAPTAIN ZEN CARD CAN PAY NODE : ECONOMY +
            CAPTYOUSER=$($MY_PATH/../tools/clyuseryomail.sh ${CAPTAINEMAIL})
            ${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/players/$CAPTAINEMAIL/secret.dunikey" "$WEEKLYG1" "${NODEG1PUB}" "UPLANET:${UPLANETG1PUB:0:8}:$CAPTYOUSER:WEEKLYPAF_ZENCARD" 2>/dev/null
            echo "CAPTAIN ZEN CARD paid weekly PAF: $WEEKLYPAF ZEN ($WEEKLYG1 G1) to NODE"
        else
            ## UPLANET MUST PAY NODE: ECONOMY -
            ${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.dunikey" "$WEEKLYG1" "${NODEG1PUB}" "UPLANET:${UPLANETG1PUB:0:8}:---:WEEKLYPAF" 2>/dev/null
            echo "UPLANET paid weekly PAF: $WEEKLYPAF ZEN ($WEEKLYG1 G1) to NODE (Captain insufficient funds on both MULTIPASS and ZEN Card)"
        fi
    else
        echo "NODE $NODECOIN G1 is NOT INITIALIZED !! UPlanet send 1 G1 to NODE"
        if [[ ! -s ~/.zen/game/uplanet.dunikey ]]; then
            ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.dunikey "${UPLANETNAME}" "${UPLANETNAME}"
            chmod 600 ~/.zen/game/uplanet.dunikey
        fi
        ${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.dunikey" "1" "${NODEG1PUB}" "UPLANET:${UPLANETG1PUB:0:8}:$IPFSNODEID:NODEINIT" 2>/dev/null
    fi
fi

#######################################################################

## AFTER PAF PAYMENT: CHECK SWARM SUBSCRIPTIONS
# ${MY_PATH}/ZEN.SWARM.payments.sh
## Ouverture d'un compte sur un autre noeud de l'essaim pour activer des services...
## Il suffit d'alimenter le MULTIPASS pour payer sur place.


#######################################################################
# Cooperative allocation check - trigger 3x1/3 allocation if conditions are met
# This will be executed after PAF payment to ensure proper economic flow
#######################################################################
echo "ZEN ECONOMY: Checking cooperative allocation conditions..."
${MY_PATH}/ZEN.COOPERATIVE.3x1-3.sh

#######################################################################
# Mark weekly payment as completed
# Create marker file with current week to prevent duplicate payments
#######################################################################
echo "$WEEK_KEY" > "$PAYMENT_MARKER"
echo "ZEN ECONOMY: Weekly payment completed and marked for week $WEEK_KEY"

exit 0
