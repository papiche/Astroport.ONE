#!/bin/bash
## TEST CORE FONCTIONNALITY
##
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/tools/my.sh"

echo "LISTING IPFS SWARM PEER"
ipfs swarm peers

echo "GENERATING KEY"
~/.zen/tools/keygen "coucou" "coucou"

echo "ACCESS BLOCKCHAIN"
~/.zen/tools/jaklis/jaklis.py history -p ${WORLDG1PUB}

echo "RW TW"
tiddlywiki
