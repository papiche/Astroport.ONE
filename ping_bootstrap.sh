#!/bin/bash

ipfs stats dht wan > ~/.zen/tmp/ipfs.stats.dht.wan
cat ~/.zen/tmp/ipfs.stats.dht.wan

for bootnode in $(cat ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | grep -Ev "#" | grep -v '^[[:space:]]*$')
    do
        echo
        ipfsnodeid=${bootnode##*/}
        ipfs swarm peers | grep $bootnode
        ipfs ping -n 3 $bootnode
        [ $? = 0 ] && ipfs swarm connect $bootnode \
                        || echo "BAD NODE $bootnode"
        echo "*****"

        cat ~/.zen/tmp/ipfs.stats.dht.wan | grep $ipfsnodeid

    done

