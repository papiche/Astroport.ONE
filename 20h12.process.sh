#!/bin/bash
########################################################################
# Version: 0.4
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/tools/my.sh"
start=`date +%s`
echo "20H12 (♥‿‿♥) $(hostname -f) $(date)"
espeak "Ding" > /dev/null 2>&1

rm -Rf ~/.zen/tmp/*

## IPFS DAEMON STATUS
LOWMODE=$(sudo systemctl status ipfs | grep disabled) ## IPFS DISABLED - START ONLY FOR SYNC -
[[ $LOWMODE == "" ]] && LOWMODE=$(ipfs swarm peers 2>&1 | grep Error) ## IPFS IS STOPPED
[[ ! $isLAN ]] && LOWMODE="" ## LOWMODE ONLY FOR LAN STATION
# echo "$USER ALL=(ALL) NOPASSWD:/bin/systemctl" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/systemctl')
if [[ $LOWMODE != "" ]]; then
    sudo systemctl start ipfs && sleep 10
else
    sudo systemctl restart ipfs && sleep 10
fi

espeak "CODE git pull" > /dev/null 2>&1

## PROCESS TW BACKOFFICE TREATMENT
[[ -s ~/.zen/G1BILLET/G1BILLETS.sh ]] \
&& cd ~/.zen/G1BILLET/ && git pull \
&& rm -Rf ~/.zen/G1BILLET/tmp/*

cd ~/.zen/Astroport.ONE/
git pull

## SOON /ipns/ Address !!!

espeak "20 HOURS 12 MINUTES. ASTROBOT RUNNING." > /dev/null 2>&1
## Updating yt-dlp
$MY_PATH/youtube-dl.sh
sudo youtube-dl -U

# Refresh ~/.zen/game/world/G1VOEU
# NOW RUN FROM PLAYER.refresh.sh !! ~/.zen/Astroport.ONE/RUNTIME/VOEUX.refresh.sh

espeak "Players refresh" > /dev/null 2>&1
# Refresh ~/.zen/game/players/PLAYER
~/.zen/Astroport.ONE/RUNTIME/PLAYER.refresh.sh

espeak "REFRESHING SWARM" > /dev/null 2>&1
# Refresh ~/.zen/game/players/PLAYER
~/.zen/Astroport.ONE/RUNTIME/MAP.refresh.sh

espeak "REFRESHING UPLANET" > /dev/null 2>&1
# Refresh ~/.zen/game/players/PLAYER
~/.zen/Astroport.ONE/RUNTIME/UPLANET.refresh.sh


    ## if [[ ! $isLAN ]]; then
    ## REFRESH BOOTSTRAP LIST (OFFICIAL SWARM)
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
echo "20H12 (♥‿‿♥) Execution time was $dur" seconds.

# ~/.zen/Astroport.ONE/tools/ipfs_P2P_forward.sh ## COULD FORWARD LOCAL TCP PORT TO SWARM
rm ~/.zen/game/players/localhost/latest

## MAIL LOG : support@qo-op.com ##
$MY_PATH/tools/mailjet.sh "support@g1sms.fr" "/tmp/20h12.log"

espeak "duration was $dur seconds" > /dev/null 2>&1

espeak "Restarting Astroport Station API" > /dev/null 2>&1
## CLOSING API PORT
[[ -s ~/.zen/.pid ]] && kill -9 $(cat ~/.zen/.pid)
## KILL ALL REMAINING nc
killall nc 12345.sh
## OPEN API ENGINE
if [[ ! -f /etc/systemd/system/astroport.service ]]; then
    ~/.zen/Astroport.ONE/12345.sh > ~/.zen/tmp/12345.log &
    PID=$!
    echo $PID > ~/.zen/.pid
else
    sudo systemctl restart astroport
    [[ -s ~/.zen/G1BILLET/G1BILLETS.sh ]] && sudo systemctl restart g1billet
    echo "systemd restart"
fi

## IPFS DISABLED : STOP IT
[[ $LOWMODE != "" ]] && sleep 360 && sudo systemctl stop ipfs

exit 0
