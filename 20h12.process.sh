#!/bin/bash
########################################################################
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/tools/my.sh"
start=`date +%s`
echo "20H12 (♥‿‿♥) $(hostname -f) $(date)"
espeak "Ding" > /dev/null 2>&1

## CLEANING  ~/.zen/tmp
rm -Rf ~/.zen/tmp/*

## RESTART IPFS DAEMON
# echo "$USER ALL=(ALL) NOPASSWD:/bin/systemctl" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/systemctl')
[[ -s /etc/sudoers.d/systemctl ]] && sudo systemctl restart ipfs && sleep 5

espeak "CODE git pull" > /dev/null 2>&1

## PROCESS TW BACKOFFICE TREATMENT
cd ~/.zen/Astroport.ONE/
git pull
## SOON /ipns/ Address !!!

espeak "20 HOURS 12 MINUTES. START NU ONE UPDATE" > /dev/null 2>&1
## Updating yt-dlp
$MY_PATH/youtube-dl.sh
sudo youtube-dl -U

# Refresh ~/.zen/game/world/G1VOEU
# NOW RUN FROM PLAYER.refresh.sh !! ~/.zen/Astroport.ONE/ASTROBOT/VOEUX.refresh.sh

espeak "Players refresh" > /dev/null 2>&1
# Refresh ~/.zen/game/players/PLAYER
~/.zen/Astroport.ONE/ASTROBOT/PLAYER.refresh.sh

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

~/.zen/Astroport.ONE/tools/ipfs_P2P_forward.sh

## MAIL LOG : support@qo-op.com
$MY_PATH/tools/mailjet.sh "support@g1sms.fr" "/tmp/20h12.log"

espeak "20 12 Storm & Thunder duration was $dur seconds" > /dev/null 2>&1

espeak "Restarting Astroport Station API" > /dev/null 2>&1
## CLOSING API PORT
[[ -s ~/.zen/.pid ]] && kill -9 $(cat ~/.zen/.pid)
## KILL ALL REMAINING nc
killall nc
## OPEN API ENGINE
~/.zen/Astroport.ONE/12345.sh > ~/.zen/tmp/12345.log &
PID=$!
echo $PID > ~/.zen/.pid

exit 0
