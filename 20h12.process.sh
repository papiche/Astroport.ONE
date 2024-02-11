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
# espeak "CODE git pull" > /dev/null 2>&1

## REMOVE TMP BUT KEEP SWARM
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
cd ~/.zen/Astroport.ONE/
git pull

## SOON /ipns/ Address !!!

# espeak "20 HOURS 12 MINUTES. ASTROBOT RUNNING." > /dev/null 2>&1
## Updating yt-dlp
${MY_PATH}/youtube-dl.sh
sudo youtube-dl -U

# Refresh ~/.zen/game/world/G1VOEU
# NOW RUN FROM PLAYER.refresh.sh !! ~/.zen/Astroport.ONE/RUNTIME/VOEUX.refresh.sh

# espeak "Players refresh" > /dev/null 2>&1
# Refresh ~/.zen/game/players/PLAYER
~/.zen/Astroport.ONE/RUNTIME/PLAYER.refresh.sh

# espeak "REFRESHING UPLANET" > /dev/null 2>&1
~/.zen/Astroport.ONE/RUNTIME/UPLANET.refresh.sh

# espeak "REFRESHING NODE" > /dev/null 2>&1
~/.zen/Astroport.ONE/RUNTIME/NODE.refresh.sh


    ## if [[ ! $isLAN ]]; then
    ## REFRESH BOOSTRAP LIST (OFFICIAL SWARM)
    espeak "bootstrap refresh" > /dev/null 2>&1

    ipfs bootstrap rm --all > /dev/null 2>&1
    for bootnode in $(cat ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | grep -Ev "#") # remove comments
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
echo "RESTART DRAGONS WOT"
${MY_PATH}/tools/DRAGON_p2p_ssh.sh off
${MY_PATH}/tools/DRAGON_p2p_ssh.sh
## RESTART

## MAIL LOG : support@qo-op.com ##
${MY_PATH}/tools/mailjet.sh "support@qo-op.com" "/tmp/20h12.log" "20H12"

espeak "DURATION ${hours} hours ${minutes} minutes ${seconds} seconds" > /dev/null 2>&1

# espeak "Restarting Astroport Services" > /dev/null 2>&1
## CLOSING API PORT
[[ -s ~/.zen/.pid ]] && kill -9 $(cat ~/.zen/.pid) > /dev/null 2>&1
## KILL ALL REMAINING nc
killall nc 12345.sh > /dev/null 2>&1

## OPEN API ENGINE
if [[ ! -f /etc/systemd/system/astroport.service ]]; then
    ~/.zen/Astroport.ONE/12345.sh > ~/.zen/tmp/12345.log &
    PID=$!
    echo $PID > ~/.zen/.pid
else
    sudo systemctl restart astroport
    [[ -s ~/.zen/G1BILLET/G1BILLETS.sh ]] && sudo systemctl restart g1billet
    echo "Astroport processes systemd restart"

fi

echo "IPFS LOW MODE ?"
## IF IPFS DAEMON DISABLED : WAIT 1H & STOP IT
[[ $LOWMODE != "" ]] \
    && echo "ON. $LOWMODE" \
    && sleep 360 \
    && sudo systemctl stop ipfs \
    && exit 0

echo "OFF. RESTART IPFS"
sleep 60
sudo systemctl restart ipfs

exit 0
