#!/bin/bash
########################################################################
# Script 20H12 - Système de maintenance et gestion pour Astroport.ONE
#
# Description:
# Ce script effectue une série de tâches de maintenance pour un nœud Astroport.ONE,
# incluant la gestion des services IPFS, la mise à jour des composants logiciels,
# le rafraîchissement des données du réseau, et le monitoring du système.
#
# Fonctionnalités principales:
# - Vérification et gestion du démon IPFS
# - Mise à jour des dépôts Git (G1BILLET, UPassport, NIP-101, Astroport)
# - Maintenance du réseau P2P et des connexions SSH (DRAGON WOT)
# - Rafraîchissement des données UPlanet et Nostr
# - Gestion des services système via systemd
# - Journalisation et reporting par email
#
#
# Conçu pour s'exécuter régulièrement (via cron) avec des modes
# de fonctionnement différents selon l'environnement (LAN/public).
########################################################################
# Version: 1.2 - Analystes ♥️BOX extraites vers tools/heartbox_analysis.sh
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"  # absolutized and normalized
if [ -s "$HOME/.astro/bin/activate" ]; then
    source $HOME/.astro/bin/activate
fi

. "${MY_PATH}/tools/my.sh"
start=`date +%s`
echo "20H12 (♥‿‿♥) $(hostname -f) $(date)"
espeak "Ding" > /dev/null 2>&1

echo "PATH=$PATH"

########################################################################
## IPFS DAEMON STATUS
LOWMODE=$(sudo systemctl status ipfs | grep "preset: disabled") ## IPFS DISABLED - START ONLY FOR SYNC -
[[ ! $(netstat -tan | grep 5001 | grep LISTEN) ]] && LOWMODE="NO 5001" ## IPFS IS STOPPED
[[ ! $isLAN || ${zipit} != "" ]] && LOWMODE="" ## LOWMODE ONLY FOR LAN STATION

########################################################################
## CHECK IF IPFS NODE IS RESPONDING (ipfs name resolve ?)
########################################################################
ipfs --timeout=30s swarm peers 2>/dev/null > ~/.zen/tmp/ipfs.swarm.peers
[[ ! -s ~/.zen/tmp/ipfs.swarm.peers || $? != 0 ]] \
    && echo "---- SWARM COMMUNICATION BROKEN / RESTARTING IPFS DAEMON ----" \
    && sudo systemctl restart ipfs \
    && sleep 60

floop=0
while [[ ! $(netstat -tan | grep 5001 | grep LISTEN) ]]; do
    sleep 10
    ((floop++)) && [ $floop -gt 36 ] \
        && echo "ERROR. IPFS daemon not restarting" \
        && ${MY_PATH}/tools/mailjet.sh "support@qo-op.com" "/tmp/20h12.log" "IPFS RESTART ERROR 20H12" \
        && exit 1
done

########################################################################
# show ZONE.sh cache of the day
echo "TODAY UPlanet landings"
ls ~/.zen/tmp/ZONE_* 2>/dev/null # API v1
ls ~/.zen/tmp/Ustats*.json 2>/dev/null # API v2
########################################################################
## REMOVE TMP BUT KEEP swarm, flashmem and coucou
mv ~/.zen/tmp/swarm ~/.zen/swarm
mv ~/.zen/tmp/coucou ~/.zen/coucou
mv ~/.zen/tmp/flashmem ~/.zen/flashmem
rm -Rf ~/.zen/tmp/*
mv ~/.zen/swarm ~/.zen/tmp/swarm
mv ~/.zen/coucou ~/.zen/tmp/coucou
mv ~/.zen/flashmem ~/.zen/tmp/flashmem

## STOPPING ASTROPORT
sudo systemctl stop astroport

########################################################################
## UPDATE G1BILLET code # 33101
[[ -s ~/.zen/G1BILLET/G1BILLETS.sh ]] \
&& cd ~/.zen/G1BILLET/ && git pull \
&& rm -Rf ~/.zen/G1BILLET/tmp/*

## UPDATE UPassport # 54321 API
[[ -s ~/.zen/UPassport/54321.py ]] \
&& cd ~/.zen/UPassport && git pull

## UPDATE NIP-101 # strfry filter rules
[[ -d ~/.zen/workspace/NIP-101 ]] \
&& cd ~/.zen/workspace/NIP-101 && git pull

## UPDATE UPlanet (./earth CID = /ipns/copylaradio.com)
if [[ -d ~/.zen/workspace/UPlanet ]]; then
    cd ~/.zen/workspace/UPlanet
    # Store current commit hash before pull
    BEFORE_HASH=$(git rev-parse HEAD)
    git pull
    # Store new commit hash after pull
    AFTER_HASH=$(git rev-parse HEAD)
    # Compare hashes to detect changes
    if [[ "$BEFORE_HASH" != "$AFTER_HASH" ]]; then
        echo "UPlanet updated from $BEFORE_HASH to $AFTER_HASH"
        ipfs add -rw ~/.zen/workspace/UPlanet/* | grep earth
    fi
else
    mkdir -p ~/.zen/workspace
    cd ~/.zen/workspace
    git clone --depth 1 https://github.com/papiche/UPlanet
fi

########################################################################
## UPDATE Astroport.ONE code
cd ${MY_PATH}/
git pull

########################################################################
## Updating yt-dlp
${MY_PATH}/youtube-dl.sh
yt-dlp -U

########################################################################
## DRAGON SSH WOT
echo "DRAGONS SHIELD OFF"
${MY_PATH}/RUNTIME/DRAGON_p2p_ssh.sh off

########################################################################
## PING BOOSTRAP & SWARM NODES
${MY_PATH}/ping_bootstrap.sh > /dev/null 2>&1

################## NOSTR Cards (Notes and Other Stuff Transmitted by Relays)
rm "${HOME}/.zen/strfry/amisOfAmis.txt" ## RESET Friends of Friends List
${MY_PATH}/RUNTIME/NOSTRCARD.refresh.sh

########################################################################
if [[ ${UPLANETG1PUB} == "AwdjhpJNqzQgmSrvpUk5Fd2GxBZMJVQkBQmXn4JQLr6z" ]]; then
    #################### UPLANET ORIGIN : PRIVATE SWARM BLOOM #########
    ${MY_PATH}/RUNTIME/BLOOM.Me.sh
else
    # UPlanet Zen MULTIPASS / real ZenCard + TW hidden mode
    #####################################
    ${MY_PATH}/RUNTIME/PLAYER.refresh.sh
    #####################################
    ${MY_PATH}/RUNTIME/_UPLANET.refresh.sh
fi
######################################################### UPLANET ######
#####################################
# UPLANET : GeoKeys UMAP / SECTOR / REGION ...
##################################### ORIGIN
${MY_PATH}/RUNTIME/UPLANET.refresh.sh
############### SOCIAL NETWORK + UPLANET SHARING & CARING #########

########################################################################
## REMOVE TMP BUT KEEP swarm, flashmem ${IPFSNODEID} and coucou
mv ~/.zen/tmp/${IPFSNODEID} ~/.zen/${IPFSNODEID}
mv ~/.zen/tmp/swarm ~/.zen/swarm
mv ~/.zen/tmp/coucou ~/.zen/coucou
mv ~/.zen/tmp/flashmem ~/.zen/flashmem
rm -Rf ~/.zen/tmp/*
mv ~/.zen/${IPFSNODEID} ~/.zen/tmp/${IPFSNODEID}
mv ~/.zen/swarm ~/.zen/tmp/swarm
mv ~/.zen/coucou ~/.zen/tmp/coucou
mv ~/.zen/flashmem ~/.zen/tmp/flashmem

########################################################################
################################# updating ipfs bootstrap
espeak "bootstrap refresh" > /dev/null 2>&1
ipfs bootstrap rm --all > /dev/null 2>&1
for bootnode in $(cat ${STRAPFILE} | grep -Ev "#") # remove comments
do
    ipfsnodeid=${bootnode##*/}
    ipfs bootstrap add $bootnode
done

########################################################################
echo "IPFS DAEMON LEVEL"
######### IPFS DAMEON NOT RUNNING ALL DAY
## IF IPFS DAEMON DISABLED : WAIT 1H & STOP IT
[[ $LOWMODE != "" ]] \
    && echo "STOP IPFS $LOWMODE" \
    && sleep 3600 \
    && sudo systemctl stop ipfs \
    && exit 0

echo "HIGH. RESTART IPFS"
sleep 60
sudo systemctl restart ipfs

#################################
### DRAGON WOT : SSH P2P RING OPENING
#################################
sleep 30
echo "DRAGONS SHIELD ON"
${MY_PATH}/RUNTIME/DRAGON_p2p_ssh.sh

## RESTART ASTROPORT
# espeak "Restarting Astroport Services" > /dev/null 2>&1
## CLOSING API PORT
[[ -s ~/.zen/.pid ]] && kill -9 $(cat ~/.zen/.pid) > /dev/null 2>&1
## KILL ALL REMAINING nc
killall nc 12345.sh > /dev/null 2>&1

## SYSTEMD OR NOT SYSTEMD
if [[ ! -f /etc/systemd/system/astroport.service ]]; then
    ${MY_PATH}/12345.sh > ~/.zen/tmp/12345.log &
    PID=$!
    echo $PID > ~/.zen/.pid
else
    sudo systemctl restart astroport
    [[ -s ~/.zen/G1BILLET/G1BILLETS.sh ]] && sudo systemctl restart g1billet
    echo "Astroport processes systemd restart"
fi

#####################################
# Node refreshing
#####################################
${MY_PATH}/RUNTIME/NODE.refresh.sh
#####################################

########################################################################
## ANALYSE FINALE ET RAPPORT
########################################################################
end=`date +%s`
dur=`expr $end - $start`
hours=$((dur / 3600))
minutes=$(( (dur % 3600) / 60 ))
seconds=$((dur % 60))

# Ajouter un résumé final au log avec analyse finale
echo "
#######################################################################
20H12 EXECUTION TERMINÉE - $(date)
#######################################################################
DURÉE: ${hours}h ${minutes}m ${seconds}s ($dur secondes)
HOSTNAME: $(hostname -f)
IPFS NODE: ${IPFSNODEID}
UPLANET: ${UPLANETG1PUB}
STATUS: SUCCESS
#######################################################################" >> /tmp/20h12.log

echo "📊 Lancement de l'analyse de la ♥️BOX - Captain ${CAPTAINEMAIL}..."
ANALYSIS_JSON=$(${MY_PATH}/tools/heartbox_analysis.sh export --json)

if [[ -n "$ANALYSIS_JSON" ]]; then
    ZENCARD_SLOTS=$(echo "$ANALYSIS_JSON" | jq -r '.capacities.zencard_slots' 2>/dev/null)
    NOSTR_SLOTS=$(echo "$ANALYSIS_JSON" | jq -r '.capacities.nostr_slots' 2>/dev/null)
    AVAILABLE_SPACE_GB=$(echo "$ANALYSIS_JSON" | jq -r '.capacities.available_space_gb' 2>/dev/null)

    echo "Capacités UPlanet détectées:"
    echo "  ZenCard Slots (128GB/slot): $ZENCARD_SLOTS"
    echo "  NOSTR/MULTIPASS Slots (10GB/slot): $NOSTR_SLOTS"
    echo "  Espace disque disponible (GB): $AVAILABLE_SPACE_GB"

    # Save analysis JSON to ~/.zen/tmp/$IPFSNODEID/
    mkdir -p ~/.zen/tmp/$IPFSNODEID
    ANALYSIS_FILE=~/.zen/tmp/$IPFSNODEID/heartbox_analysis.json
    echo "$ANALYSIS_JSON" > "$ANALYSIS_FILE"
    echo "✅ Analyse JSON sauvegardée dans $ANALYSIS_FILE"
else
    echo "❌ Erreur: Impossible d'obtenir les données d'analyse JSON de heartbox_analysis.sh."
fi

end=`date +%s`
dur=`expr $end - $start`
hours=$((dur / 3600))
minutes=$(( (dur % 3600) / 60 ))
seconds=$((dur % 60))

echo "TOTAL DURATION ${hours} hours ${minutes} minutes ${seconds} seconds"
echo "20H12 (♥‿‿♥) Execution time was $dur seconds."

## MAIL LOG : support@qo-op.com ##
${MY_PATH}/tools/mailjet.sh "support@qo-op.com" "/tmp/20h12.log" "$(cat ~/.zen/GPS 2>/dev/null) 20H12 : $(cat ~/.zen/game/players/.current/.player 2>/dev/null)"

espeak "DURATION ${hours} hours ${minutes} minutes ${seconds} seconds" > /dev/null 2>&1

exit 0
