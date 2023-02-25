#!/bin/bash

for bootnode in $(cat ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | grep -Ev "#");
    do
        ipfsnodeid=${bootnode##*/}
        ipfs ping -n 3 $bootnode
        [ $? = 0 ] && ipfs swarm connect $bootnode \
                        || echo "BAD NODE $bootnode"
        ipfs swarm peers | grep $bootnode

    done

ipfs stats dht wan

echo "TODO : search for bootstrap and friends better connectivity"
