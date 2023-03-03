#!/bin/bash

ipfs stats dht wan

for bootnode in $(cat ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | grep -Ev "#");
    do
        echo
        ipfsnodeid=${bootnode##*/}
        ipfs swarm peers | grep $bootnode
        ipfs ping -n 3 $bootnode
        [ $? = 0 ] && ipfs swarm connect $bootnode \
                        || echo "BAD NODE $bootnode"
        echo "*****"

    done



echo "TODO : search for bootstrap and friends better connectivity"
