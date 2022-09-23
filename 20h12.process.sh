#!/bin/bash
########################################################################
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
start=`date +%s`

## RESTART IPFS DAEMON
# echo "$USER ALL=(ALL) NOPASSWD:/bin/systemctl" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/systemctl')
[[ -s /etc/sudoers.d/systemctl ]] && sudo systemctl restart ipfs && sleep 5

## PROCESS TW BACKOFFICE TREATMENT
cd ~/.zen/Astroport.ONE/
git pull

~/.zen/Astroport.ONE/ASTROBOT/VOEUX.refresh.sh
~/.zen/Astroport.ONE/ASTROBOT/PLAYER.refresh.sh


## ADD A_boostrap_nodes.txt TO BOOTSTRAP

ipfs bootstrap rm --all > /dev/null 2>&1
for bootnode in $(cat ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | grep -Ev "#") # remove comments
do
    ipfsnodeid=${bootnode##*/}
    ipfs bootstrap add $bootnode
done



########################################################################
end=`date +%s`
echo Execution time was `expr $end - $start` seconds.
exit 0
