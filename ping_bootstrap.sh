#!/bin/bash

## SHOW DHT STATS
echo "#########################"
echo "------------------------------------------------- ~/.zen/tmp/ipfs.stats.dht.wan"
echo "GETTING DHT STATS"
ipfs stats dht wan > ~/.zen/tmp/ipfs.stats.dht.wan
# cat ~/.zen/tmp/ipfs.stats.dht.wan
echo "#########################"

[[ -s ${HOME}/.zen/game/MY_boostrap_nodes.txt ]] \
    && STRAPFILE="${HOME}/.zen/game/MY_boostrap_nodes.txt" \
    || STRAPFILE="${HOME}/.zen/Astroport.ONE/A_boostrap_nodes.txt"

## BOOSTRAP
echo "#########################"
echo "BOOSTRAP NODES"
for bootnode in $(cat ${STRAPFILE} | grep -Ev "#" | grep -v '^[[:space:]]*$')
do
    ipfsnodeid=${bootnode##*/}
    ipfs swarm peers | grep $bootnode
    ipfs --timeout 5s ping -n 3 $bootnode
    [ $? = 0 ] && ipfs swarm connect $bootnode \
                    || echo "FAILED ipfs ping $bootnode"
    echo "*****"
    echo "in DHT ? --------------"
    cat ~/.zen/tmp/ipfs.stats.dht.wan | grep $ipfsnodeid
    echo "-------------------------------------------------"

done

## SWARM
echo
echo "#########################"
echo "SWARM NODES"
ls ~/.zen/tmp/swarm
echo "-------------------------------------------------"
for ipfsnodeid in $(ls ~/.zen/tmp/swarm);
do
    ipfs --timeout 5s ping -n 3 /p2p/$ipfsnodeid
    [ $? = 0 ] && ipfs swarm connect /p2p/$ipfsnodeid \
                    || echo "FAILED ipfs ping /p2p/$ipfsnodeid"
    echo "in DHT ? --------------"
    cat ~/.zen/tmp/ipfs.stats.dht.wan | grep $ipfsnodeid
    echo "-------------------------------------------------"
done
