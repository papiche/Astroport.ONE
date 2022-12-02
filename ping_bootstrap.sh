#!/bin/bash

for bootnode in $(cat ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | grep -Ev "#");
    do
        ipfsnodeid=${bootnode##*/}
        ipfs ping -n 3 $bootnode
        [ $? = 0 ] && ipfs swarm connect $bootnode \
                        || echo "BAD NODE $bootnode"
        ipfs swarm peers | grep $bootnode

    done

## And friends
for friendnode in $(cat ~/.zen/game/players/*/FRIENDS/*/.astronautens | uniq);
    do
        ipfs ping -n 3 $friendnode
        [ $? = 0 ] && ipfs swarm connect $friendnode \
                        || echo "UNCONNECTED $friendnode"
         ipfs swarm peers | grep $friendnode
    done

ipfs stats dht wan

echo "TODO : search for bootstrap and friends better connectivity"
