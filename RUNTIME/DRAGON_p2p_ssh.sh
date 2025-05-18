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
YOU=$(pgrep -au $USER -f "ipfs daemon" > /dev/null && echo "$USER") || er+=" ipfs daemon not running"
[[ "$YOU" == "" || "${IPFSNODEID}" == "" ]] && echo "ERROR : $er " && exit 1
########################################################################
## THIS SCRIPT COPY BOOSTRAP PUBKEY
### AND OPEN IPFS P2P SSH FORWARD ON CHANNEL
# Make Station publish SSH port on "/x/ssh-$(IPFSNODEID)"
########################################################################
## use STOP or OFF to finish forwarding

PARAM="$1"
if [[ "${PARAM,,}" == "off" || "${PARAM,,}" == "stop" ]]; then
    ipfs p2p close --all
    rm ~/.zen/tmp/${IPFSNODEID}/x_*.sh 2>/dev/null
    rm ~/.zen/tmp/${IPFSNODEID}/y_ssh.pub 2>/dev/null
    echo "STOP" && exit 0
fi


############################################
## Y LEVEL = SSH PUBKEY OVER IPFS y_ssh.pub
## https://pad.p2p.legal/keygen
if [[ -s ~/.ssh/id_ed25519.pub ]]; then
    ## TEST IF TRANSMUTATION IS MADE
    YIPNS=$(${MY_PATH}/../tools/ssh_to_g1ipfs.py "$(cat ~/.ssh/id_ed25519.pub)")
    if [[ ${IPFSNODEID} == ${YIPNS} ]]; then
            echo "Y LEVEL CONFIRMED !" \
            && cat ~/.ssh/id_ed25519.pub > ~/.zen/tmp/${IPFSNODEID}/y_ssh.pub
    else
        rm -f ~/.zen/tmp/${IPFSNODEID}/y_ssh.pub
        echo "IPFSNODEID not linked with SSH _____ ٩(̾●̮̮̃̾•̃̾)۶ _____"
        echo "${YIPNS} != ${IPFSNODEID}"
    fi
fi

## DRAGONz PGP style
gpg --export-ssh-key $(cat ~/.zen/game/players/.current/.player) 2>/dev/null > ~/.zen/tmp/${IPFSNODEID}/z_ssh.pub
[[ ! -s ~/.zen/tmp/${IPFSNODEID}/z_ssh.pub ]] && rm ~/.zen/tmp/${IPFSNODEID}/z_ssh.pub # remove empty file

## PRODUCE SWARM SEED PART - used to create swarm.key
if [[ -s ~/.zen/tmp/${IPFSNODEID}/z_ssh.pub || -s ~/.zen/tmp/${IPFSNODEID}/y_ssh.pub ]]; then
    [[ ! -s ~/.zen/tmp/${IPFSNODEID}/_swarm.egg.txt ]] \
        && head -c 12 /dev/urandom | od -t x1 -A none - | tr -d ' ' \
                > ~/.zen/tmp/${IPFSNODEID}/_swarm.egg.txt
fi

echo "${YIPNS}

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
                              \---'    |  / ²²²²²²        /Z
                            \--'     /\/  \ _____________/Z
                             '------'      \

"
[[ -z ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}

##################################################################################
############################################ SETUP CAPTAIN NOSTR PROFILE
if [[ -s ~/.zen/game/players/.current/secret.nostr ]]; then
    YOUSER=$($MY_PATH/../tools/clyuseryomail.sh "${CAPTAINEMAIL}")

    echo "Setup Captain NOSTR profile"
    source ~/.zen/game/players/.current/secret.nostr
     ${MY_PATH}/../tools/nostr_setup_profile.py \
    "$NSEC" \
    "UPlanet Captain $YOUSER" "$CAPTAING1PUB" \
    "UPlanet ${UPLANETG1PUB:0:8} -- $uSPOT/g1 [CopyLaRadio] Dragon WoT Member -- $CAPTAINEMAIL" \
    "https://ipfs.copylaradio.com/ipfs/QmfBK5h8R4LjS2qMtHKze3nnFrtdm85pCbUw3oPSirik5M/logo.uplanet.png" \
    "https://ipfs.copylaradio.com/ipfs/QmX1TWhFZwVFBSPthw1Q3gW5rQc1Gc4qrSbKj4q1tXPicT/P2Pmesh.jpg" \
    "$CAPTAINEMAIL" "$myIPFS/ipns/copylaradio.com" "" "" "" "" \
    "wss://relay.copylaradio.com" "$myRELAY" \
    --ipns_vault "/ipns/$(cat ~/.zen/game/players/.current/.playerns)" --ipfs_gw "$myIPFS"

    ## FOLLOW EVERY NOSTR CARD
    nostrhex=($(cat ~/.zen/game/nostr/*@*.*/HEX))
    ${MY_PATH}/../tools/nostr_follow.sh "$NSEC" "${nostrhex[@]}"
fi
##################################################################################

##################################################################################
##################################################################################
############################################ $HOME/.zen/game/My_boostrap_ssh.txt
## DISTRIBUTE DRAGON SSH WOT AUTHORIZED KEYS
SSHAUTHFILE="${MY_PATH}/../A_boostrap_ssh.txt"
[[ -s $HOME/.zen/game/My_boostrap_ssh.txt ]] && SSHAUTHFILE="$HOME/.zen/game/My_boostrap_ssh.txt"
############################################
[[ -s ~/.ssh/authorized_keys ]] \
    && cp ~/.ssh/authorized_keys ~/.zen/tmp/${MOATS}/authorized_keys \
    || echo "# ASTRO # ~/.ssh/authorized_keys" > ~/.zen/tmp/${MOATS}/authorized_keys

while IFS= read -r line
do
    LINE=$(echo "$line" | grep "ssh-ed25519" | grep -Ev "#") # Remove # & not ssh-ed25519
    [[ ! ${LINE} ]] && continue
    if [[ ! $(cat ~/.zen/tmp/${MOATS}/authorized_keys | grep "${LINE}") ]]
    then
        echo "# ADDING ${LINE} to ~/.zen/tmp/${MOATS}/authorized_keys"
        mkdir -p ~/.ssh && echo "${LINE}" >> ~/.zen/tmp/${MOATS}/authorized_keys
    else
        echo "ALREADY TRUSTING ${LINE}"
    fi
done < ${SSHAUTHFILE} ## INITIALIZED DURING BLOOM.Me PRIVATE SWARM ACTIVATION
## ADDING ${HOME}/.zen/game/players/${PLAYER}/ssh.pub (made during PLAYER.refresh)
cat ${HOME}/.zen/game/players/*/ssh.pub >> ~/.zen/tmp/${MOATS}/authorized_keys 2>/dev/null
### REMOVING DUPLICATION (NO ORDER CHANGING)
awk '!seen[$0]++' ~/.zen/tmp/${MOATS}/authorized_keys > ~/.zen/tmp/${MOATS}/authorized_keys.clean
cat ~/.zen/tmp/${MOATS}/authorized_keys.clean > ~/.ssh/authorized_keys
echo "-----------------------------------------------------"
echo "~/.ssh/authorized_keys"
cat ~/.ssh/authorized_keys
echo "-----------------------------------------------------"
##################################################################################
##################################################################################


##################################################################################
############################################
### FORWARD SSH PORT over /x/ssh-${IPFSNODEID}
############################################
echo "Launching SSH SHARE ACCESS /x/ssh-${IPFSNODEID}"
[[ ! $(ipfs p2p ls | grep "/x/ssh-${IPFSNODEID}") ]] \
    && ipfs p2p listen /x/ssh-${IPFSNODEID} /ip4/127.0.0.1/tcp/22
############################################
## PREPARE x_ssh.sh
## REMOTE ACCESS COMMAND FROM DRAGONS
############################################
PORT=22000
PORT=$((PORT+${RANDOM:0:3}))
echo '#!/bin/bash
if [[ ! $(ipfs p2p ls | grep x/ssh-'${IPFSNODEID}') ]]; then
    ipfs --timeout=10s ping -n 4 /p2p/'${IPFSNODEID}'
    [[ $? == 0 ]] \
        && ipfs p2p forward /x/ssh-'${IPFSNODEID}' /ip4/127.0.0.1/tcp/'${PORT}' /p2p/'${IPFSNODEID}' \
        && echo "ssh '${USER}'@127.0.0.1 -p '${PORT}'" \
        || echo "CONTACT IPFSNODEID FAILED - ERROR -"
else
    echo "Tunnel /x/ssh '${PORT}' already active..."
    echo "ssh '${USER}'@127.0.0.1 -p '${PORT}'"
    echo "ipfs p2p close -p /x/ssh-'${IPFSNODEID}'"
fi
' > ~/.zen/tmp/${IPFSNODEID}/x_ssh.sh

echo "ipfs cat /ipns/${IPFSNODEID}/x_ssh.sh | bash"


############################################
## PREPARE x_ollama.sh
## REMOTE ACCESS COMMAND FROM DRAGONS
############################################
if [[ ! -z $(pgrep ollama) ]]; then
    echo "Launching OLLAMA SHARE ACCESS /x/ollama-${IPFSNODEID}"
    [[ ! $(ipfs p2p ls | grep "/x/ollama-${IPFSNODEID}") ]] \
        && ipfs p2p listen /x/ollama-${IPFSNODEID} /ip4/127.0.0.1/tcp/11434

    PORT=11434
    echo '#!/bin/bash
    if [[ ! $(ipfs p2p ls | grep x/ollama-'${IPFSNODEID}') ]]; then
        ipfs --timeout=10s ping -n 4 /p2p/'${IPFSNODEID}'
        [[ $? == 0 ]] \
            && ipfs p2p forward /x/ollama-'${IPFSNODEID}' /ip4/127.0.0.1/tcp/'${PORT}' /p2p/'${IPFSNODEID}' \
            && echo "OLLAMA PORT FOR '${IPFSNODEID}'" \
            && export OLLAMA_API_BASE="http://127.0.0.1:'${PORT}'" \
            && echo "OLLAMA_API_BASE=$OLLAMA_API_BASE" \
            || echo "CONTACT IPFSNODEID FAILED - ERROR -"
    else
            echo "Tunnel /x/ollama '${PORT}' already active..."
            echo "ipfs p2p close -p /x/ollama-'${IPFSNODEID}'"
    fi
    ' > ~/.zen/tmp/${IPFSNODEID}/x_ollama.sh
    #~ cat ~/.zen/tmp/${IPFSNODEID}/x_ollama.sh

    echo "ipfs cat /ipns/${IPFSNODEID}/x_ollama.sh | bash"

fi

############################################
## PREPARE x_comfyui.sh
## REMOTE ACCESS COMMAND FROM DRAGONS
############################################
if [[ ! -z $(lsof -i :8188 | grep LISTEN) ]]; then
    echo "Launching comfyui SHARE ACCESS /x/comfyui-${IPFSNODEID}"
    [[ ! $(ipfs p2p ls | grep "/x/comfyui-${IPFSNODEID}") ]] \
        && ipfs p2p listen /x/comfyui-${IPFSNODEID} /ip4/127.0.0.1/tcp/8188

    PORT=8188
    echo '#!/bin/bash
    if [[ ! $(ipfs p2p ls | grep x/comfyui-'${IPFSNODEID}') ]]; then
        ipfs --timeout=10s ping -n 4 /p2p/'${IPFSNODEID}'
        [[ $? == 0 ]] \
            && ipfs p2p forward /x/comfyui-'${IPFSNODEID}' /ip4/127.0.0.1/tcp/'${PORT}' /p2p/'${IPFSNODEID}' \
            && echo "xdg-open http://127.0.0.1:'${PORT}'" \
            || echo "CONTACT IPFSNODEID FAILED - ERROR -"
    else
            echo "Tunnel /x/comfyui '${PORT}' already active..."
            echo "ipfs p2p close -p /x/comfyui-'${IPFSNODEID}'"
    fi
    ' > ~/.zen/tmp/${IPFSNODEID}/x_comfyui.sh
    #~ cat ~/.zen/tmp/${IPFSNODEID}/x_comfyui.sh

    echo "ipfs cat /ipns/${IPFSNODEID}/x_comfyui.sh | bash"

fi

echo "-----------------------------------------------------"
echo "ipfs p2p ls"
ipfs p2p ls
echo "-----------------------------------------------------"

############################################
echo "DRAGON WOKE UP"
############################################

exit 0
