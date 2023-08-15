#!/bin/bash
########################################################################
# Version: 0.5
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# PAD COCODING : https://pad.p2p.legal/s/G1Monit
# KODI SERVICE : Publish and Merge Friends Monit Movies into RSS Stream
########################################################################
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/../tools/my.sh"

echo "$ME RUNNING"
########################################################################
## SCAN FOR PAYMENT HISTORY
## BUILD python NetworkX script
## SEND MESSAGE TO SOURCEG1PUB
########################################################################
## THIS SCRIPT IS RUN WHEN A WALLET RECEIVED A TRANSACTION WITH COMMENT STARTING WITH N1Monit
########################################################################
INDEX="$1"
[[ ! ${INDEX} ]] && INDEX="$HOME/.zen/game/players/.current/ipfs/moa/index.html"
[[ ! -s ${INDEX} ]] && echo "ERROR - Please provide path to source TW index.html" && exit 1
[[ ! -s ${INDEX} ]] && echo "ERROR - Fichier TW absent. ${INDEX}" && exit 1

PLAYER="$2"
[[ ! ${PLAYER} ]] && PLAYER="$(cat ~/.zen/game/players/.current/.player 2>/dev/null)"
[[ ! ${PLAYER} ]] && echo "ERROR - Please provide PLAYER" && exit 1

ASTRONAUTENS=$(ipfs key list -l | grep -w ${PLAYER} | cut -d ' ' -f1)
[[ ! ${ASTRONAUTENS} ]] && echo "ERROR - Clef IPNS ${PLAYER} introuvable!"  && exit 1

G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub)
[[ ! $G1PUB ]] && echo "ERROR - G1PUB ${PLAYER} VIDE"  && exit 1

# Extract tag=tube from TW
MOATS="$3"
[[ ! ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

IPUBKEY="$4"
[[ ! ${IPUBKEY} ]] && echo "ERROR - MISSING COMMAND ISSUER !"  && exit 1

TH="$5"
[[ ! ${TH} ]] && echo "ERROR - MISSING COMMAND TITLE HASH ADDRESS !"  && exit 1

echo "${PLAYER} : ${IPUBKEY} SEEKING FOR ${TH}
${ASTRONAUTENS} ${G1PUB} "

#~ ###################################################################
#~ ## CREATE APP NODE PLAYER PUBLICATION DIRECTORY
#~ ###################################################################
mkdir -p $HOME/.zen/tmp/${MOATS} && echo $HOME/.zen/tmp/${MOATS}

## EXERCICE  ### TODO ###
## USE https://networkx.org/documentation/stable/tutorial.html#
## EXTRACT HISTORY WITH jaklis
## CREATE A PYTHON SCRIPT CREATING the 1st level of TX
echo "import networkx as nx
import matplotlib.pyplot as plt
G = nx.Graph()
...
G.add_node(SRCPUB)
G.add_node(DSTPUB)
G.edges[SRCPUB, DSTPUB]['g1'] = AMOUNT
...
nx.draw(G, with_labels=True, font_weight='bold')
plt.show()
"
## EXTEND N1Script WITH MORE FUNCTIONS... exemples ...
## N1Vote: permet de pratiquer le Vote Quadratique
## N1Conf: permet de signifier la Confiance
## ...

exit 0
