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

echo "IPFS can connect SWARM"
ipfs swarm peers
ipfs=$?


echo "keygen can GENERATE KEY"
${MY_PATH}/tools/keygen "coucou" "coucou"
keygen=$?

echo "jaklis can ACCESS BLOCKCHAIN"
${MY_PATH}/tools/jaklis/jaklis.py history -p ${WORLDG1PUB}
jaklis=$?

echo "amzqr can CREATE QR CODE"
amzqr "COUCOU" -l H -c -p ${MY_PATH}/images/TV.png -n TV.png -d /tmp
amzqr=$?

xdg-open /tmp/TV.png
x11=$?

[[ $x11 != "0" ]] && echo "HEADLESS MODE"

test=$tw$ipfs$keygen$jaklis$amzqr

[[ $test == "00000" ]] && echo "PERFECT" && exit 0

[[ ${test::1} == "1" ]] && echo "PROBLEM WITH TiddlyWiki"
[[ ${test:2:2} == "11" ]] && echo "CRYPTO LAYER MALFUNCTION"
[[ ${test::2} == "01" ]] && echo "IPFS DAEMON IS ABSENT"

### PROMETHEUS NODE EXPORTER ##################
ls /usr/local/bin/node_exporter

exit 0
