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

test=$tw$ipfs$keygen$jaklis

[[ $test == "0000" ]] && echo "PERFECT" && exit 0

[[ ${test::1} == "1" ]] && echo "PROBLEM WITH TiddlyWiki"
[[ ${test:2:2} == "11" ]] && echo "CRYPTO LAYER MALFUNCTION"
[[ ${test::2} == "01" ]] && echo "IPFS DAEMON IS ABSENT"

exit 0
