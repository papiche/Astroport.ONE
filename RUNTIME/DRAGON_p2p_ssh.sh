#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# Activate SUPPORT MODE: open ssh over IPFS
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh"
########################################################################
YOU=$(myIpfsApi) || er+=" ipfs daemon not running"
[[ "$YOU" == "" || "${IPFSNODEID}" == "" ]] && echo "ERROR : $er " && exit 1
########################################################################
## THIS SCRIPT COPY BOOSTRAP PUBKEY
### AND OPEN IPFS P2P SSH FORWARD ON CHANNEL
# Make Station publish SSH port on "/x/ssh-$(IPFSNODEID)"
########################################################################
## use STOP or OFF to finish forwarding

PARAM="$1"
if [[ "${PARAM,,}" == "off" || "${PARAM,,}" == "stop"  ]]; then
    ipfs p2p close --all
    rm ~/.zen/tmp/${IPFSNODEID}/x_ssh.sh 2>/dev/null
    rm ~/.zen/tmp/${IPFSNODEID}/y_ssh.pub 2>/dev/null
    echo "STOP" && exit 0
fi

############################################
## DISTRIBUTE DRAGON SSH WOT SEED
# A_boostrap_ssh.txt
############################################
while IFS= read -r line
do
    LINE=$(echo "$line"  | grep "ssh-ed25519" | grep -Ev "#") # Remove # & not ssh-ed25519
    [[ ! ${LINE} ]] && continue
    if [[ ! $(cat ~/.ssh/authorized_keys | grep "${LINE}") ]]
    then
        echo "# ADDING ${LINE} to ~/.ssh/authorized_keys"
        mkdir -p ~/.ssh && echo "${LINE}" >> ~/.ssh/authorized_keys
    else
        echo "TRUSTING ${LINE}"
    fi
done < ${MY_PATH}/../A_boostrap_ssh.txt

############################################
## PUBLISH SSH PUBKEY OVER IPFS
## KITTY ssh-keygen style
[[ -s ~/.ssh/id_ed25519.pub ]] && cp ~/.ssh/id_ed25519.pub ~/.zen/tmp/${IPFSNODEID}/y_ssh.pub
## DRAGONz PGP/SSH style (https://pad.p2p.legal/keygen)
gpg --export-ssh-key $(cat ~/.zen/game/players/.current/.player) 2>/dev/null > ~/.zen/tmp/${IPFSNODEID}/z_ssh.pub
[[ ! -s ~/.zen/tmp/${IPFSNODEID}/z_ssh.pub ]] && rm ~/.zen/tmp/${IPFSNODEID}/z_ssh.pub # remove empty file

############################################
### FORWARD SSH PORT over /x/ssh-${IPFSNODEID}
############################################
echo "Lanching  /x/ssh-${IPFSNODEID}"

[[ ! $(ipfs p2p ls | grep "/x/ssh-${IPFSNODEID}") ]] \
    && ipfs p2p listen /x/ssh-${IPFSNODEID} /ip4/127.0.0.1/tcp/22

ipfs p2p ls

echo
############################################
## PREPARE x_ssh.sh
## REMOTE ACCESS COMMAND FROM DRAGONS
############################################
PORT=22000
PORT=$((PORT+${RANDOM:0:3}))

#######################################################################
## Adapt $USER for the UPlanet /home/$USER Private Swarm specific one
#######################################################################

echo '#!/bin/bash
if [[ ! $(ipfs p2p ls | grep x/ssh-'${IPFSNODEID}') ]]; then
    ipfs --timeout=10s ping -n 4 /p2p/'${IPFSNODEID}'
    [[ $? == 0 ]] \
        && ipfs p2p forward /x/ssh-'${IPFSNODEID}' /ip4/127.0.0.1/tcp/'${PORT}' /p2p/'${IPFSNODEID}' \
        && ssh \$USER@127.0.0.1 -p '${PORT}' \
        || echo "CONTACT IPFSNODEID FAILED - ERROR -"
fi
' > ~/.zen/tmp/${IPFSNODEID}/x_ssh.sh

cat ~/.zen/tmp/${IPFSNODEID}/x_ssh.sh

echo "

                      /|               /\\
                 /^^^/ |^\Z           /  |
                |         \Z         /   |
                / @        \Z       /   / \_______
   (  \      _ /            \Z     /   /         /
 (     ---- /G       |\      |Z   /   /         /
  (  / ---- \    /---'/\     |Z  /   /         /
             \/--'   /--/   /Z  /             /
              |     /--/   |Z  /            / \_______
             /     /--/    |Z  \           /         /
          --/     /--/     \Z   |         /         /
           /     /--/       \Z  /                  /
                |--|         \Z/                  /
                |---|        /              /----'
                 \---|                     /^^^^^^^^^^^^\Z
                  \-/                                    \Z
                   /     /        |                       \Z
               \---'    |\________|      |_______          |Z
             \--'     /\/ \|_|_|_||      |_|_|_|_|\_       |Z
              '------'            /     /  /      |_       /Z
                              \---'    |  / ``````        /Z
                            \--'     /\/  \ _____________/Z
                             '------'      \

"
############################################
echo "CONNECT WITH THIS COMMAND"
echo "ipfs cat /ipns/${IPFSNODEID}/x_ssh.sh | bash"
############################################

exit 0
