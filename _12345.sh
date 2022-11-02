#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# This script scan Swarm API layer from official bootstraps
# Then publish map of json DApp data
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)
myIP=$(hostname -I | awk '{print $1}' | head -n 1)
[[ ! $myIP ]] && myIP="127.0.1.1"

PORT=12345

    YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1); ## $USER running ipfs
    LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2) ## SWARM#0 ENTRANCE URL


for bootnode in $(cat ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | grep -Ev "#") # remove comments
do
    ipfsnodeid=${bootnode##*/}
    mkdir -p ~/.zen/tmp/swarm/$ipfsnodeid
    echo "IPFS get  /ipns/$ipfsnodeid"
    [[ $YOU ]] && echo "http://$myIP:8080/ipns/${ipfsnodeid} ($YOU)" && ipfs --time-out 12s get -o ~/.zen/tmp/swarm/$ipfsnodeid /ipns/$ipfsnodeid
##    [[ ! -s ~/.zen/tmp/swarm/$ipfsnodeid/index.json ]] && echo "$LIBRA/ipns/${ipfsnodeid}" && curl -m 6 -so ~/.zen/tmp/swarm/$ipfsnodeid/index.json "$LIBRA/ipns/${ipfsnodeid}"

    echo "Updated : ~/.zen/tmp/swarm/$ipfsnodeid"
    ls ~/.zen/tmp/swarm/$ipfsnodeid
done



ls ~/.zen/tmp/${IPFSNODEID}/
ROUTING=$(ipfs add -rwq ~/.zen/tmp/${IPFSNODEID} | tail -n 1 )
echo "SELF PUBLISHING SWARM STATUS"
ipfs name publish --allow-offline /ipfs/$ROUTING

HTTPCORS="HTTP/1.1 200 OK
Access-Control-Allow-Origin: '*'
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET
Server: Astroport.ONE
Content-Type: application/json; charset=UTF-8

{
    \"ipns\"=\"${IPFSNODEID}\"
    \"url\"=\"http://${myIP}:8080/ipns/${IPFSNODEID}\"
}
"

