#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# This script scan Swarm API layer from official bootstraps
# Then publish map of json DApp data

IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)

for bootnode in $(cat ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | grep -Ev "#") # remove comments
do
    ipfsnodeid=${bootnode##*/}
    mkdir -p ~/.zen/tmp/$IPFSNODEID/$ipfsnodeid
    echo "IPFS get  /ipns/$ipfsnodeid"
    ipfs get -o ~/.zen/tmp/$IPFSNODEID/$ipfsnodeid /ipns/$ipfsnodeid
    echo "Updated : ~/.zen/tmp/$IPFSNODEID/$ipfsnodeid"
    ls ~/.zen/tmp/$IPFSNODEID/$ipfsnodeid
done
