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
IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)

myIP=$(hostname -I | awk '{print $1}' | head -n 1)
isLAN=$(route -n |awk '$1 == "0.0.0.0" {print $2}' | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")
[[ ! $myIP || $isLAN ]] && myIP="ipfs.localhost"

PORT=12345

    YOU=$(ipfs swarm peers >/dev/null 2>&1 && echo "$USER" || ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1); ## $USER running ipfs
    LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2) ## SWARM#0 ENTRANCE URL

ncrunning=$(ps axf --sort=+utime | grep -w 'nc -l -p 12345' | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 2)
[[ $ncrunning ]] && echo "(≖‿‿≖) - API Server Already Running -  (≖‿‿≖) " && kill -9 $ncrunning

## RESET MEMORY
rm -Rf ~/.zen/tmp/swarm/*
## NAME PUBLISH EMPTY !!!
# ipfs name publish --allow-offline /ipfs/Qmc5m94Gu7z62RC8waSKkZUrCCBJPyHbkpmGzEePxy2oXJ
## INDICATE IPFSNODEID IS RUNNING
##############################################

mkdir -p ~/.zen/tmp/swarm
mkdir -p ~/.zen/tmp/$IPFSNODEID

echo "${MOATS}" > ~/.zen/tmp/${IPFSNODEID}/.MySwarm.moats

## CREATE CHAN = MySwarm_$IPFSNODEID
    CHAN=$(ipfs key list -l | grep -w "MySwarm_$IPFSNODEID" | cut -d ' ' -f 1)
    [[ ! $CHAN ]] && CHAN=$(ipfs key gen "MySwarm_$IPFSNODEID")
## PUBLISH CHANNEL IPNS
    echo "/ipns/$CHAN" > ~/.zen/tmp/$IPFSNODEID/.MySwarm


# REFRESH FROM BOOTSTRAP (COULD, SHOULD BE MY FRIENDS !)
while true; do
    start=`date +%s`
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

    lastrun=$(cat ~/.zen/tmp/${IPFSNODEID}/.MySwarm.moats)
    duree=$(expr ${MOATS} - $lastrun)

    ## FIXING TIC TAC FOR NODE & SWARM REFRESH
    if [[ duree -gt 3600000 ]]; then

    (
    start=`date +%s`

    ############# GET BOOTSTRAP SWARM DATA
    for bootnode in $(cat ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | grep -Ev "#") # remove comments
    do
        echo "############# RUN LOOP #########"

        ipfsnodeid=${bootnode##*/}
        mkdir -p ~/.zen/tmp/swarm/$ipfsnodeid

        echo "IPFS get  /ipns/$ipfsnodeid"
        [[ $YOU ]] && ipfs --timeout 12s get -o ~/.zen/tmp/swarm/$ipfsnodeid /ipns/$ipfsnodeid/

        echo "Updated : ~/.zen/tmp/swarm/$ipfsnodeid"

        ls ~/.zen/tmp/swarm/$ipfsnodeid

    done

    ############### UPDATE MySwarm CHAN
    ls ~/.zen/tmp/swarm
    BSIZE=$(du -b ~/.zen/tmp/swarm | tail -n 1 | cut -f 1)

    ## SIZE MODIFIED => PUBLISH MySwarm_$IPFSNODEID
    [[ $BSIZE != $(cat ~/.zen/tmp/swarm/.bsize) ]] \
    && echo $BSIZE > ~/.zen/tmp/swarm/.bsize \
    && SWARMH=$(ipfs add -rwq ~/.zen/tmp/swarm/* | tail -n 1 ) \
    && ipfs name publish --key "MySwarm_$IPFSNODEID" --allow-offline /ipfs/$SWARMH


    ############# PUBLISH IPFSNODEID BALISE
    # Clean Empty Directory (inode dependancy BUG ??)
    du -b ~/.zen/tmp/${IPFSNODEID} > /tmp/du
    while read branch; do [[ $branch =~ "4096" ]] && rmdir $(echo $branch | cut -f 2 -d ' '); done < /tmp/du

    # Scan local cache
    ls ~/.zen/tmp/${IPFSNODEID}/
    BSIZE=$(du -b ~/.zen/tmp/${IPFSNODEID} | tail -n 1 | cut -f 1)


    ## Merge with actual online version
    ipfs get -o ~/.zen/tmp/${IPFSNODEID} /ipns/${IPFSNODEID}/
    NSIZE=$(du -b ~/.zen/tmp/${IPFSNODEID} | tail -n 1 | cut -f 1)

    ## Local / IPNS size differ => Publish
    [[ $BSIZE != $NSIZE ]] \
    && ROUTING=$(ipfs add -rwq ~/.zen/tmp/${IPFSNODEID}/* | tail -n 1 ) \
    && echo "BALISE STATION /ipns/${IPFSNODEID} INDEXES = $NSIZE octets" \
    && ipfs name publish --allow-offline /ipfs/$ROUTING

    end=`date +%s`
    echo "(*__*) MySwam Update ($BSIZE B) duration was "`expr $end - $start`' seconds.'

    ) &

    # last run recording
    echo "${MOATS}" > ~/.zen/tmp/${IPFSNODEID}/.MySwarm.moats

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
    \"url\" : \"http://${myIP}:8080/ipns/${IPFSNODEID}\",
    \"myswarm\" : \"http://${myIP}:8080/ipns/${CHAN}\"
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
