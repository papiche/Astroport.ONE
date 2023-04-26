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
[[ $IPFSNODEID == "" ]] && IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID) || er+=" ipfs id problem"
[[ "$YOU" == "" || "$IPFSNODEID" == "" ]] && echo "ERROR : $er " && exit 1
########################################################################
# SHARE TCP PORT WITH "ipfs p2p"
#

PLAYER=$(cat ~/.zen/game/players/.current/.player)
[[ ${PLAYER} == "" ]] && echo "MISSING PLAYER" && exit 1
echo "HELLO ${PLAYER}"
## ZENITY
[[ $XDG_SESSION_TYPE == 'x11' ]] && MYPORT=$(zenity --entry --width 300 --title "IPFS SHARE A PORT" --text "PORT : " --entry-text="")
[[ ${MYPORT} == "" ]] && echo "IPFS SHARE A PORT ? " && read MYPORT

# Make Station publish SSH port on "/x/astro-${PLAYER}-${MYPORT}"
zuid="astro-${PLAYER}-${MYPORT}"

if [[ $zuid ]]
then

    echo "Lanching  /x/$zuid"
    [[ ! $(ipfs p2p ls | grep "/x/$zuid") ]] && ipfs p2p listen /x/$zuid /ip4/127.0.0.1/tcp/${MYPORT}

fi

ipfs p2p ls

## CONNECT WITH COMMAND
## ipfs cat /ipns/$IPFSNODEID/.$IPFSNODEID/x_$zuid.sh | bash
rm ~/.zen/tmp/$IPFSNODEID/x_$zuid.sh >/dev/null 2>&1
if [[ ! -f ~/.zen/tmp/$IPFSNODEID/x_$zuid.sh ]]; then
    PORT=22345
    [ ${PORT} -le 22345 ] && PORT=$((PORT+${RANDOM:0:3})) || PORT=$((PORT-${RANDOM:0:3}))
    echo "if [[ ! \$(ipfs p2p ls | grep x/$zuid) ]]; then
    ipfs --timeout=5s ping -n 1 /p2p/$IPFSNODEID
    ipfs p2p forward /x/$zuid /ip4/127.0.0.1/tcp/$PORT /p2p/$IPFSNODEID
    xdg-open http://127.0.0.1:$PORT
fi" > ~/.zen/tmp/$IPFSNODEID/x_$zuid.sh
fi

cat ~/.zen/tmp/$IPFSNODEID/x_$zuid.sh
echo "https://ipfs.copylaradio.com/ipns/$IPFSNODEID/x_$zuid.sh"
echo "cat ~/.zen/tmp/$IPFSNODEID/x_$zuid.sh"
## THIS PORT FORWARDING HUB COULD BE MADE MORE CONTROLABLE USING FRIENDSHIP LEVEL & IPFS BALISES

