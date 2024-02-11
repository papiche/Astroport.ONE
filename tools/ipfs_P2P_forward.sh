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
[[ "$YOU" == "" || "$IPFSNODEID" == "" ]] && echo "ERROR : $er " && exit 1
########################################################################

PARAM="$1" ## can STOP or OFF
if [[ "${PARAM,,}" == "off" || "${PARAM,,}" == "stop"  ]]; then
    ipfs p2p close --all
    rm ~/.zen/tmp/$IPFSNODEID/x_ssh.sh 2>/dev/null
    echo "STOP" && exit 0
fi
# Make Station publish SSH port on "/x/ssh-$(IPFSNODEID)"
zuid=${IPFSNODEID}

if [[ ! $(cat ~/.ssh/authorized_keys | grep "fred@ONELOVE") ]]
then
    echo "# ADD fred@ONELOVE to ~/.ssh/authorized_keys" && mkdir -p ~/.ssh
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDFLHW8P88C/B7622yXzdAn1ZcTBfE1A4wMqajBwAoHwUVTOUaYfvkiSxbzb5H9dPTAXhQU6ZfuLa70kTo1m2b9TKH0tD6hR3RiKJ0NIjCHYEypcPGpLmHaZWnBKPq3IUU24qFVdUJxnTkDdFUszYMNoV4nqlXY/ZYdNpic8L1jPPyfOLLfPFkuSxagyQj4FGJq77UQE5j+skMJS3ISkazNTLqOCGLFJ5qtBC11BvQaCJ4cQ2Ss7ejPYhpx16NLJfg9VtG4dv9ZebEIl2pf7niiQGSPrDMFWHuQcGAuHt/patr0BcvfvD3Gv+qNsVfAJCNZ2U5NHEMKIhgj1ilNPEw7 fred@ONELOVE" >> ~/.ssh/authorized_keys
fi

echo "Lanching  /x/ssh-$zuid"
[[ ! $(ipfs p2p ls | grep "/x/ssh-$zuid") ]] && ipfs p2p listen /x/ssh-$zuid /ip4/127.0.0.1/tcp/22
# echo "echo \"ssh-$zuid local port please?\"; read lport; ipfs p2p forward /x/ssh-$zuid /ip4/127.0.0.1/tcp/$lport /p2p/$IPFSNODEID" >> ~/.zen/tmp/$IPFSNODEID/astroport/port

ipfs p2p ls

## PREPARE x_ssh.sh
## ipfs cat /ipns/$IPFSNODEID/.$IPFSNODEID/x_ssh.sh | bash
PORT=22000
PORT=$((PORT+${RANDOM:0:3}))

echo "if [[ ! \$(ipfs p2p ls | grep x/ssh-$zuid) ]]; then
ipfs --timeout=5s ping -n 1 /p2p/$IPFSNODEID
ipfs p2p forward /x/ssh-$zuid /ip4/127.0.0.1/tcp/$PORT /p2p/$IPFSNODEID
ssh $USER@127.0.0.1 -p $PORT
fi" > ~/.zen/tmp/$IPFSNODEID/x_ssh.sh

cat ~/.zen/tmp/$IPFSNODEID/x_ssh.sh

echo "$myIPFS/ipns/$IPFSNODEID/x_ssh.sh"

## THIS PORT FORWARDING HUB COULD BE MADE MORE CONTROLABLE USING FRIENDSHIP LEVEL & IPFS BALISES

