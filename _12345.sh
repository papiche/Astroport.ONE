#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# PUBLISHING IPNS SWARM MAP
# This script scan Swarm API layer from official bootstraps
# Then publish map of json DApp data
#
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
IPFSNODEID=$(ipfs id -f='<id>\n')

myIP=$(hostname -I | awk '{print $1}' | head -n 1)
isLAN=$(echo $myIP | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")
[[ ! $myIP || $isLAN ]] && myIP="127.0.1.1"

PORT=12345

    YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1); ## $USER running ipfs
    LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2) ## SWARM#0 ENTRANCE URL

ncrunning=$(ps auxf --sort=+utime | grep -w 'nc -l -p 12345' | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1)
[[ $ncrunning ]] && echo "(≖‿‿≖) - API Server Already Running -  (≖‿‿≖) " && exit 1

## RESET MEMORY
rm -Rf ~/.zen/tmp/swarm/*
## NAME PUBLISH EMPTY !!!
ipfs name publish --allow-offline /ipfs/Qmc5m94Gu7z62RC8waSKkZUrCCBJPyHbkpmGzEePxy2oXJ

mkdir -p ~/.zen/tmp/swarm/${IPFSNODEID}
echo "${MOATS}" > ~/.zen/tmp/swarm/${IPFSNODEID}/.moats

# REFRESH FROM BOOTSTRAP (COULD, SHOULD BE MY FRIENDS !)
while true; do
    start=`date +%s`
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

    lastrun=$(cat ~/.zen/tmp/swarm/${IPFSNODEID}/.moats)
    duree=$(expr ${MOATS} - $lastrun)

    if [[ duree -gt 3600000 ]]; then

    (
    start=`date +%s`
    for bootnode in $(cat ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | grep -Ev "#") # remove comments
    do
        echo "############# RUN LOOP #########"

        ipfsnodeid=${bootnode##*/}
        mkdir -p ~/.zen/tmp/swarm/$ipfsnodeid
        echo "IPFS get  /ipns/$ipfsnodeid"
        [[ $YOU ]] && echo "http://$myIP:8080/ipns/${ipfsnodeid} ($YOU)" && ipfs --timeout 12s get -o ~/.zen/tmp/swarm/$ipfsnodeid /ipns/$ipfsnodeid
    ##    [[ ! -s ~/.zen/tmp/swarm/$ipfsnodeid/index.json ]] && echo "$LIBRA/ipns/${ipfsnodeid}" && curl -m 6 -so ~/.zen/tmp/swarm/$ipfsnodeid/index.json "$LIBRA/ipns/${ipfsnodeid}"

        ## TODO LOOP CREATE bootstrap json array
        #

        echo "Updated : ~/.zen/tmp/swarm/$ipfsnodeid"
        ls ~/.zen/tmp/swarm/$ipfsnodeid
    done

    ls ~/.zen/tmp/swarm/
    ROUTING=$(ipfs add -rwq ~/.zen/tmp/swarm/* | tail -n 1 )
    echo "SELF PUBLISHING SWARM STATUS"
    ipfs name publish --allow-offline /ipfs/$ROUTING

    end=`date +%s`
    echo '(*__*) UPDATE & PUBLISH duration was '`expr $end - $start`' seconds.'

    # last run recording
    echo "${MOATS}" > ~/.zen/tmp/swarm/${IPFSNODEID}/.moats

    ) &

    else
        echo "$duree only cache life"

    fi

    HTTPSEND="HTTP/1.1 200 OK
Access-Control-Allow-Origin: \*
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET
Server: Astroport.ONE
Content-Type: application/json; charset=UTF-8

{
    \"created\" : \"${MOATS}\",
    \"hostname\" : \"$(hostname)\",
    \"myIP\" : \"${myIP}\",
    \"ipfsnodeid\" : \"${IPFSNODEID}\",
    \"url\" : \"http://${myIP}:8080/ipns/${IPFSNODEID}\"
}
"
    ######################################################################################
    #  BLOCKING COMMAND nc 12345 port waiting
    echo '(◕‿‿◕) http://'$myIP:'12345 READY (◕‿‿◕)'
    echo "$HTTPSEND" | nc -l -p 12345 -q 1 > /dev/null 2>&1

    #### 12345 NETWORK MAP TOKEN
    end=`date +%s`
    echo '(#__#) WAITING TIME was '`expr $end - $start`' seconds.'
    echo '(^‿‿^) 12345 TOKEN '${MOATS}' CONSUMED  (^‿‿^)'

done

exit 0
