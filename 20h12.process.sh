#!/bin/bash
########################################################################
# Version: 0.4
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

## STOPPING ASTROPORT
sudo systemctl stop astroport

########################################################################
## UPDATE G1BILLET code
[[ -s ~/.zen/G1BILLET/G1BILLETS.sh ]] \
&& cd ~/.zen/G1BILLET/ && git pull \
&& rm -Rf ~/.zen/G1BILLET/tmp/*

## UPDATE UPassport
[[ -s ~/.zen/UPassport/54321.py ]] \
&& cd ~/.zen/UPassport && git pull

## UPDATE NIP-101
[[ -d ~/.zen/workspace/NIP-101 ]] \
&& cd ~/.zen/workspace/NIP-101 && git pull
## TODO LOG ROTATE

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

################################ CHECK FOR PRIVATE SWARM BLOOM #########
${MY_PATH}/RUNTIME/BLOOM.Me.sh

#################### NOSTR (Notes and Other Stuff Transmitted by Relays)
${MY_PATH}/RUNTIME/NOSTRCARD.refresh.sh
########################################################################

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
end=`date +%s`
dur=`expr $end - $start`
hours=$((dur / 3600))
minutes=$(( (dur % 3600) / 60 ))
seconds=$((dur % 60))
echo "DURATION ${hours} hours ${minutes} minutes ${seconds} seconds"
echo "20H12 (♥‿‿♥) Execution time was $dur seconds."

## MAIL LOG : support@qo-op.com ##
${MY_PATH}/tools/mailjet.sh "support@qo-op.com" "/tmp/20h12.log" "20H12 Solar Time : $(cat ~/.zen/GPS 2>/dev/null)"

espeak "DURATION ${hours} hours ${minutes} minutes ${seconds} seconds" > /dev/null 2>&1

exit 0
