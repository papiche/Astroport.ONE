#!/bin/bash
########################################################################
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
start=`date +%s`
echo "20H12 (♥‿‿♥) $(hostname) $(date)"
espeak "Ding" > /dev/null 2>&1


myIP=$(hostname -I | awk '{print $1}' | head -n 1)
isLAN=$(echo $myIP | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")
[[ ! $myIP || $isLAN ]] && myIP="ipfs.localhost"

## CLEANING  ~/.zen/tmp
rm -Rf ~/.zen/tmp/*

## RESTART IPFS DAEMON
# echo "$USER ALL=(ALL) NOPASSWD:/bin/systemctl" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/systemctl')
[[ -s /etc/sudoers.d/systemctl ]] && sudo systemctl restart ipfs && sleep 5

espeak "Ding Ding" > /dev/null 2>&1


## PROCESS TW BACKOFFICE TREATMENT
cd ~/.zen/Astroport.ONE/
git pull
## SOON /ipns/ Address !!!

# Refresh ~/.zen/game/world/G1VOEU
# NOW RUN FROM PLAYER.refresh.sh !! ~/.zen/Astroport.ONE/ASTROBOT/VOEUX.refresh.sh

## CLOSING 1234 API PORT
killall 12345.sh
killall _12345.sh
killall nc
killall tail

espeak "Ding Ding Ding" > /dev/null 2>&1

# Refresh ~/.zen/game/players/PLAYER
~/.zen/Astroport.ONE/ASTROBOT/PLAYER.refresh.sh

espeak "Bills Kills Bills" > /dev/null 2>&1


## OPEN API ENGINE
~/.zen/Astroport.ONE/12345.sh > ~/.zen/tmp/12345.log &

if [[ ! $isLAN ]]; then
    ## REFRESH BOOTSTRAP LIST (OFFICIAL SWARM)
    ipfs bootstrap rm --all > /dev/null 2>&1
    for bootnode in $(cat ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | grep -Ev "#") # remove comments
    do
        ipfsnodeid=${bootnode##*/}
        ipfs bootstrap add $bootnode
    done
fi

########################################################################
end=`date +%s`
echo "20H12 (♥‿‿♥) Execution time was "`expr $end - $start` seconds.

## MAIL LOG : support@qo-op.com
$MY_PATH/tools/mailjet.sh "support@qo-op.com" "/tmp/20h12.log.txt"

espeak "Byte Storm Over" > /dev/null 2>&1

exit 0
