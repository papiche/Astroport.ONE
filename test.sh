#!/bin/bash
## TEST CORE FONCTIONNALITY
##
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/tools/my.sh"

echo "TiddlyWiki RW"
which tiddlywiki
tw=$?

echo "IPFS SWARM PEER"
ipfs swarm peers
ipfs=$?


echo "keygen can GENERATE KEY"
${MY_PATH}/tools/keygen "coucou" "coucou"
keygen=$?

echo "jaklis can ACCESS BLOCKCHAIN"
${MY_PATH}/tools/jaklis/jaklis.py history -p ${WORLDG1PUB}
jaklis=$?


echo $tw $ipfs $keygen $jaklis
exit 0
