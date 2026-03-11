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

echo "gcli can ACCESS BLOCKCHAIN"
gcli --version
gcli=$?

echo "G1check.sh can QUERY BALANCE via GraphQL"
${MY_PATH}/tools/G1check.sh ${CAPTAING1PUB}
g1check=$?

echo "primal_wallet_control.sh can VERIFY WALLET PRIMAL"
${MY_PATH}/tools/primal_wallet_control.sh \
    "$HOME/.zen/game/players/${CAPTAINEMAIL}/secret.dunikey" \
    "${CAPTAING1PUB}" \
    "${UPLANETNAME_G1}" \
    "${CAPTAINEMAIL}"
primal=$?

echo "amzqr can CREATE QR CODE"
amzqr "COUCOU" -l H -c -p ${MY_PATH}/images/TV.png -n TV.png -d /tmp
amzqr=$?

xdg-open /tmp/TV.png
x11=$?

[[ $x11 != "0" ]] && echo "HEADLESS MODE"

test=$tw$ipfs$keygen$gcli$g1check$primal$amzqr

[[ $test == "0000000" ]] && echo "PERFECT" && exit 0

[[ ${test::1} == "1" ]] && echo "PROBLEM WITH TiddlyWiki"
[[ ${test:1:1} == "1" ]] && echo "IPFS DAEMON IS ABSENT"
[[ ${test:2:1} == "1" ]] && echo "CRYPTO LAYER MALFUNCTION (keygen)"
[[ ${test:3:1} == "1" ]] && echo "gcli NOT INSTALLED"
[[ ${test:4:1} == "1" ]] && echo "GraphQL BALANCE CHECK FAILED"
[[ ${test:5:1} == "1" ]] && echo "PRIMAL WALLET CONTROL FAILED"

### PROMETHEUS NODE EXPORTER ##################
ls /usr/local/bin/node_exporter

exit 0
