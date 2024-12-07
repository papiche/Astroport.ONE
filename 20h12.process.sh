#!/bin/bash
########################################################################
# Version: 0.4
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/tools/my.sh"
start=`date +%s`
echo "20H12 (♥‿‿♥) $(hostname -f) $(date)"
espeak "Ding" > /dev/null 2>&1

[[ -s ~/.astro/bin/activate ]] && source ~/.astro/bin/activate
echo "PATH=$PATH"

########################################################################
## IPFS DAEMON STATUS
LOWMODE=$(sudo systemctl status ipfs | grep disabled) ## IPFS DISABLED - START ONLY FOR SYNC -
[[ ! $(netstat -tan | grep 5001 | grep LISTEN) ]] && LOWMODE="NO 5001" ## IPFS IS STOPPED
[[ ! $isLAN ]] && LOWMODE="" ## LOWMODE ONLY FOR LAN STATION

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
ls ~/.zen/tmp/ZONE_* 2>/dev/null

########################################################################
## REMOVE TMP BUT KEEP swarm, flashmem and coucou
mv ~/.zen/tmp/swarm ~/.zen/swarm
mv ~/.zen/tmp/coucou ~/.zen/coucou
mv ~/.zen/tmp/flashmem ~/.zen/flashmem
rm -Rf ~/.zen/tmp/*
mv ~/.zen/swarm ~/.zen/tmp/swarm
mv ~/.zen/coucou ~/.zen/tmp/coucou
mv ~/.zen/flashmem ~/.zen/tmp/flashmem

########################################################################
### DELAY _12345 ASTROPORT DURING 20H12 UPDATE ###
if [[ "${LOWMODE}" == "" ]]; then
    ### NOT REFRESHING SWARM
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    MOATS_plus_5_hours=$(date -d "now + 5 hours" +"%Y%m%d%H%M%S%4N")
    mkdir ~/.zen/tmp/${IPFSNODEID}
    echo ${MOATS_plus_5_hours} > ~/.zen/tmp/${IPFSNODEID}/_MySwarm.moats
    echo 9000 > ~/.zen/tmp/random.sleep
else
    # REFRESHING SWARM
    echo 0 > ~/.zen/tmp/${IPFSNODEID}/_MySwarm.moats
    curl -s "http://127.0.0.1:12345"
    sleep 300 ## WAIT FOR 5MN
fi

########################################################################
## UPDATE G1BILLETS code
[[ -s ~/.zen/G1BILLET/G1BILLETS.sh ]] \
&& cd ~/.zen/G1BILLET/ && git pull \
&& rm -Rf ~/.zen/G1BILLET/tmp/*

########################################################################
## UPDATE Astroport.ONE code
cd ${MY_PATH}/
git pull

########################################################################
## Updating yt-dlp
${MY_PATH}/youtube-dl.sh
sudo yt-dlp -U

########################################################################
## DRAGON SSH WOT
echo "DRAGONS WOT OFF"
${MY_PATH}/RUNTIME/DRAGON_p2p_ssh.sh off

########################################################################
## PING BOOSTRAP & SWARM NODES
${MY_PATH}/ping_bootstrap.sh > /dev/null 2>&1

################################ CHECK FOR PRIVATE SWARM BLOOM #########
${MY_PATH}/RUNTIME/BLOOM.Me.sh

######################################################### UPLANET ######
#####################################
# GeoKeys UMAP / SECTOR / REGION ...
#####################################
${MY_PATH}/RUNTIME/UPLANET.refresh.sh
#####################################
#####################################
# Players TW analyse & ASTROBOT run
#####################################
${MY_PATH}/RUNTIME/PLAYER.refresh.sh
#####################################

########################################################################
########################################################################

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

    [[ -s ${HOME}/.zen/game/MY_boostrap_nodes.txt ]] \
        && STRAPFILE="${HOME}/.zen/game/MY_boostrap_nodes.txt" \
        || STRAPFILE="${MY_PATH}/A_boostrap_nodes.txt"

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
echo "DRAGONS WOT ON"
${MY_PATH}/RUNTIME/DRAGON_p2p_ssh.sh

## MAIL LOG : support@qo-op.com ##
${MY_PATH}/tools/mailjet.sh "support@qo-op.com" "/tmp/20h12.log" "20H12"

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
end=`date +%s`
dur=`expr $end - $start`
hours=$((dur / 3600))
minutes=$(( (dur % 3600) / 60 ))
seconds=$((dur % 60))
echo "DURATION ${hours} hours ${minutes} minutes ${seconds} seconds"
echo "20H12 (♥‿‿♥) Execution time was $dur seconds."

espeak "DURATION ${hours} hours ${minutes} minutes ${seconds} seconds" > /dev/null 2>&1

exit 0
