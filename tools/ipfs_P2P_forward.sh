#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# Activate SUPPORT MODE: open ssh over IPFS
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/my.sh"
########################################################################
YOU=$(myIpfsApi) || er+=" ipfs daemon not running"
IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID) || er+=" ipfs id problem"
[[ "$YOU" == "" || "$IPFSNODEID" == "" ]] && echo "ERROR : $er " && exit 1
########################################################################

# Make Station publish SSH port on "/x/ssh-$(hostname)"
zuid="$(hostname -f)"
if [[ $zuid ]]
then
    if [[ ! $(cat ~/.ssh/authorized_keys | grep "fred@ONELOVE") ]]
    then
        echo "# ADD fred@ONELOVE to ~/.ssh/authorized_keys"
        echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDFLHW8P88C/B7622yXzdAn1ZcTBfE1A4wMqajBwAoHwUVTOUaYfvkiSxbzb5H9dPTAXhQU6ZfuLa70kTo1m2b9TKH0tD6hR3RiKJ0NIjCHYEypcPGpLmHaZWnBKPq3IUU24qFVdUJxnTkDdFUszYMNoV4nqlXY/ZYdNpic8L1jPPyfOLLfPFkuSxagyQj4FGJq77UQE5j+skMJS3ISkazNTLqOCGLFJ5qtBC11BvQaCJ4cQ2Ss7ejPYhpx16NLJfg9VtG4dv9ZebEIl2pf7niiQGSPrDMFWHuQcGAuHt/patr0BcvfvD3Gv+qNsVfAJCNZ2U5NHEMKIhgj1ilNPEw7 fred@ONELOVE" >> ~/.ssh/authorized_keys
    fi
    echo "Lanching  /x/ssh-$zuid"
    [[ ! $(ipfs p2p ls | grep "/x/ssh-$zuid") ]] && ipfs p2p listen /x/ssh-$zuid /ip4/127.0.0.1/tcp/22
    # echo "echo \"ssh-$zuid local port please?\"; read lport; ipfs p2p forward /x/ssh-$zuid /ip4/127.0.0.1/tcp/$lport /p2p/$IPFSNODEID" >> ~/.zen/tmp/$IPFSNODEID/astroport/port
fi

ipfs p2p ls

## CONNECT WITH COMMAND
## ipfs cat /ipns/$IPFSNODEID/.$IPFSNODEID/x_ssh-$zuid.sh | bash
rm ~/.zen/tmp/$IPFSNODEID/x_ssh-$zuid.sh >/dev/null 2>&1
if [[ ! -f ~/.zen/tmp/$IPFSNODEID/x_ssh-$zuid.sh ]]; then
    PORT=12345
    [ ${PORT} -eq 12345 ] && PORT=$((PORT+${RANDOM:0:3})) || PORT=$((PORT-${RANDOM:0:3}))
    echo "[[ ! \$(ipfs p2p ls | grep x/ssh-$zuid) ]] && ipfs --timeout=5s ping -n 1 /p2p/$IPFSNODEID && ipfs p2p forward /x/ssh-$zuid /ip4/127.0.0.1/tcp/$PORT /p2p/$IPFSNODEID && ssh $USER@127.0.0.1 -p $PORT" > ~/.zen/tmp/$IPFSNODEID/x_ssh-$zuid.sh
fi
cat ~/.zen/tmp/$IPFSNODEID/x_ssh-$zuid.sh

## THIS PORT FORWARDING HUB COULD BE MADE MORE CONTROLABLE USING FRIENDSHIP LEVEL & IPFS BALISES

