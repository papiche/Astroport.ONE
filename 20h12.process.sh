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

## IPFS DAEMON STATUS
LOWMODE=$(sudo systemctl status ipfs | grep disabled) ## IPFS DISABLED - START ONLY FOR SYNC -
[[ ! $(netstat -tan | grep 5001 | grep LISTEN) ]] && LOWMODE="NO 5001" ## IPFS IS STOPPED
[[ ! $isLAN ]] && LOWMODE="" ## LOWMODE ONLY FOR LAN STATION
# echo "$USER ALL=(ALL) NOPASSWD:/bin/systemctl" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/systemctl')

sudo systemctl restart ipfs && sleep 10

floop=0
while [[ ! $(netstat -tan | grep 5001 | grep LISTEN) ]]; do
    sleep 10
    ((floop++)) && [ $floop -gt 36 ] \
        && echo "ERROR. IPFS daemon not restarting" \
        && ${MY_PATH}/tools/mailjet.sh "support@qo-op.com" "/tmp/20h12.log" "IPFS RESTART ERROR 20H12" \
        && exit 1
done

## PING BOOSTRAP & SWARM NODES
${MY_PATH}/ping_bootstrap.sh

# show ZONE.sh cache of the day
ls ~/.zen/tmp/ZONE_*

## REMOVE TMP BUT KEEP SWARM and coucou
mv ~/.zen/tmp/swarm ~/.zen/swarm
mv ~/.zen/tmp/coucou ~/.zen/coucou
rm -Rf ~/.zen/tmp/*
mv ~/.zen/swarm ~/.zen/tmp/swarm
mv ~/.zen/coucou ~/.zen/tmp/coucou

## UPDATE G1BILLETS code
[[ -s ~/.zen/G1BILLET/G1BILLETS.sh ]] \
&& cd ~/.zen/G1BILLET/ && git pull \
&& rm -Rf ~/.zen/G1BILLET/tmp/*

## UPDATE Astroport.ONE code
cd ${MY_PATH}/
git pull

## SOON /ipns/ Address !!!

# espeak "20 HOURS 12 MINUTES. ASTROBOT RUNNING." > /dev/null 2>&1
## Updating yt-dlp
${MY_PATH}/youtube-dl.sh
sudo youtube-dl -U

## PING BOOSTRAP & SWARM NODES
${MY_PATH}/ping_bootstrap.sh

#####################################
# espeak "Players refresh" > /dev/null 2>&1
# Refresh ~/.zen/game/players/PLAYER
#####################################
${MY_PATH}/RUNTIME/PLAYER.refresh.sh
#####################################
#####################################
# espeak "REFRESHING UPLANET" > /dev/null 2>&1
#####################################
${MY_PATH}/RUNTIME/UPLANET.refresh.sh
#####################################
#####################################
# espeak "REFRESHING NODE" > /dev/null 2>&1
#####################################
${MY_PATH}/RUNTIME/NODE.refresh.sh
#####################################

    ## if [[ ! $isLAN ]]; then
    ## REFRESH BOOSTRAP LIST (OFFICIAL SWARM)
    espeak "bootstrap refresh" > /dev/null 2>&1

    ipfs bootstrap rm --all > /dev/null 2>&1
    for bootnode in $(cat ${MY_PATH}/A_boostrap_nodes.txt | grep -Ev "#") # remove comments
    do
        ipfsnodeid=${bootnode##*/}
        ipfs bootstrap add $bootnode
    done

    ## fi

########################################################################
end=`date +%s`
dur=`expr $end - $start`
hours=$((dur / 3600))
minutes=$(( (dur % 3600) / 60 ))
seconds=$((dur % 60))
echo "DURATION ${hours} hours ${minutes} minutes ${seconds} seconds"
echo "20H12 (♥‿‿♥) Execution time was $dur seconds."

## DRAGON SSH WOT
echo "STOP DRAGONS WOT"
${MY_PATH}/RUNTIME/DRAGON_p2p_ssh.sh off
## RESTART

## MAIL LOG : support@qo-op.com ##
${MY_PATH}/tools/mailjet.sh "support@qo-op.com" "/tmp/20h12.log" "20H12"

espeak "DURATION ${hours} hours ${minutes} minutes ${seconds} seconds" > /dev/null 2>&1

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
${MY_PATH}/RUNTIME/DRAGON_p2p_ssh.sh

exit 0
