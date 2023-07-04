#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# PUBLISH AND SYNC ASTROPORT STATIONS SWARM MAPS
# This script scan Swarm API layer from official bootstraps
#
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/tools/my.sh"

## SEND LOG TO ~/.zen/tmp/_12345.log
exec 2>&1 >> ~/.zen/tmp/_12345.log

PORT=12345

    YOU=$(myIpfsApi); ## API of $USER running ipfs
    LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2) ## SWARM#0 ENTRANCE URL

## KILLING OLD DAEMON OF MYSELF
ncrunning=$(ps axf --sort=+utime | grep -w 'nc -l -p 12345' | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 2)
[[ $ncrunning != "" ]] && echo "(≖‿‿≖) - KILLING Already Running MAP Server -  (≖‿‿≖) " && kill -9 $ncrunning

## WHAT IS NODEG1PUB
NODEG1PUB=$($MY_PATH/tools/ipfs_to_g1.py ${IPFSNODEID})

## RESET SWARM LOCAL CACHE
rm -Rf ~/.zen/tmp/swarm/*

##############################################
[[ ${IPFSNODEID} == "" ]] && echo "IPFSNODEID is empty" && exit 1
mkdir -p ~/.zen/tmp/swarm
mkdir -p ~/.zen/tmp/${IPFSNODEID}

## AVOID A swarm IN swarm LOOP !!!
rm -Rf ~/.zen/tmp/${IPFSNODEID}/swarm

## TIMESTAMPING
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
echo "${MOATS}" > ~/.zen/tmp/.MySwarm.moats

############################################################
##  MySwarm KEY INIT & SET
############################################################
## CREATE CHAN = MySwarm_${IPFSNODEID}
    CHAN=$(ipfs key list -l | grep -w "MySwarm_${IPFSNODEID}" | cut -d ' ' -f 1)

    #######################################################
    ## CREATE MySwarm KEYS ?
    [[ -s ~/.zen/game/secret.dunikey ]] && mv ~/.zen/game/secret.dunikey ~/.zen/game/myswarm_secret.dunikey ## Change MySwarm key file name : TODOREMOVELINE : REMOVE FORMAT MIGRATION LINE
    [[ -s ~/.zen/game/secret.ipfskey ]] && mv ~/.zen/game/secret.ipfskey ~/.zen/game/myswarm_secret.ipfskey ## Change MySwarm key file name : TODOREMOVELINE : REMOVE FORMAT MIGRATION LINE

    [[ ! -s ~/.zen/game/myswarm_secret.dunikey ]] && ipfs key rm "MySwarm_${IPFSNODEID}" && CHAN="" ## NEW KEY FORMAT (NODEPUB)

    if [[ ${CHAN} == "" ]]; then
    echo "## MAKE /proc/cpuinfo IPFSNODEID DERIVATED KEY ##"
        SECRET1=$(cat /proc/cpuinfo | grep -Ev MHz | sha512sum | cut -d ' ' -f 1)
        SECRET2=${IPFSNODEID}
        ${MY_PATH}/tools/keygen -t ipfs -o ~/.zen/game/myswarm_secret.ipfskey "$SECRET1" "$SECRET2"
        ${MY_PATH}/tools/keygen -t duniter -o ~/.zen/game/myswarm_secret.dunikey "$SECRET1" "$SECRET2"
        ipfs key import "MySwarm_${IPFSNODEID}" -f pem-pkcs8-cleartext ~/.zen/game/myswarm_secret.ipfskey
        CHAN=$(ipfs key list -l | grep -w "MySwarm_${IPFSNODEID}" | cut -d ' ' -f 1 )
     fi
    ########################################################

## PUBLISH CHANNEL IPNS
    echo "/ipns/$CHAN" > ~/.zen/tmp/${IPFSNODEID}/.MySwarm
############################################################
############################################################
echo 0 > ~/.zen/tmp/random.sleep
###################
# NEVER ENDING LOOP
###################################################################
## WILL SCAN ALL BOOTSTRAP - REFRESH "SELF IPNS BALISE" - RECEIVE UPLINK ORDERS
###################################################################
while true; do

    start=`date +%s`
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

    lastrun=$(cat ~/.zen/tmp/.MySwarm.moats)
    duree=$(expr ${MOATS} - $lastrun)

    ## FIXING TIC TAC FOR NODE & SWARM REFRESH ( 1H )
    if [[ duree -gt 3600000 ]]; then

    #####################################
    ( ##### SUB-PROCESS RUN
    start=`date +%s`

    ############# GET BOOTSTRAP SWARM DATA
    for bootnode in $(cat ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | grep -Ev "#") # remove comments
    do

        echo "############# RUN LOOP ######### $(date)"
        ipfsnodeid=${bootnode##*/}

        [[ ${ipfsnodeid} == ${IPFSNODEID} ]] && echo "MYSELF : ${IPFSNODEID} - CONTINUE" && continue
        mkdir -p ~/.zen/tmp/swarm/${ipfsnodeid}

        ## GET bootnode IP
        iptype=$(echo ${bootnode} | cut -d '/' -f 2)
        nodeip=$(echo ${bootnode} | cut -d '/' -f 3)

        ## IPFS GET TO /swarm/${ipfsnodeid}
        echo "GETTING ${nodeip} : /ipns/${ipfsnodeid}"
        [[ $YOU ]] && ipfs --timeout 180s get -o ~/.zen/tmp/swarm/${ipfsnodeid} /ipns/${ipfsnodeid}/
        echo "UPDATED : ~/.zen/tmp/swarm/${ipfsnodeid}"

        ## SHOW WHAT WE GET
        echo "__________________________________________________"
        ls ~/.zen/tmp/swarm/${ipfsnodeid}
        echo "__________________________________________________"

        ## ASK BOOTSTRAP NODE TO GET MY MAP UPSYNC
        ## - MAKES MY BALISE PRESENT IN BOOTSTRAP SWARM KEY  -
        if [[  $iptype == "ip4" || $iptype == "ip6" ]]; then

            echo "STATION MAP UPSYNC : curl -s http://${nodeip}:12345/?${NODEG1PUB}=${IPFSNODEID}"
            curl -s -m 10 http://${nodeip}:12345/?${NODEG1PUB}=${IPFSNODEID} -o ~/.zen/tmp/swarm/${ipfsnodeid}/map.${nodeip}.json

            ## LOOKING IF ITS SWARM MAP COULD COMPLETE MINE
            echo "ANALYSING BOOTSTRAP SWARM MAP"
            itipnswarmap=$(cat ~/.zen/tmp/swarm/${ipfsnodeid}/map.${nodeip}.json | jq -r '.myswarm' | rev | cut -d '/' -f 1 | rev )
            ipfs ls /ipns/${itipnswarmap} | rev | cut -d ' ' -f 1 | rev | cut -d '/' -f 1 > ~/.zen/tmp/_swarm.${ipfsnodeid}

            echo "ZNODS LIST"
            cat ~/.zen/tmp/_swarm.${ipfsnodeid}
            echo "============================================"
            for znod in $(cat ~/.zen/tmp/_swarm.${ipfsnodeid}); do
                # CHECK znod validity
                cznod=$(${MY_PATH}/tools/ipfs_to_g1.py ${znod} 2>/dev/null)
                [[ ${cznod} == "" || ${cznod} == "null" ]] && echo "xxxxxxxxxxxx BAD ${znod} xxxx ON xxxxxx ${ipfsnodeid} - ERROR - CONTINUE" && continue

                if [[ -d ~/.zen/tmp/swarm/${znod} ]]; then
                    echo "COMPLETING MY SWARM DATA WITH ZNOD=${znod}"
                    mkdir -p ~/.zen/tmp/swarm/${znod}
                    ipfs --timeout 180s get -o ~/.zen/tmp/swarm/${znod} /ipns/${znod}
                else
                    echo "____________ KNOW ${znod}"
                    # TODO : SPEEDUP REFRESH COMPARE _MySwarm.moats AND KEEP LASTEST
                fi
            done
            echo "============================================"

        fi ## IP4 WAN BOOTSRAP UPSYNC FINISHED

    done

#############################################
    # ERASE EMPTY DIRECTORIES
    du -b ~/.zen/tmp/swarm > /tmp/du
    while read branch; do [[ $branch =~ "4096" ]] && echo "empty $branch" && rm -Rf $(echo $branch | cut -f 2 -d ' '); done < /tmp/du
    ############### UPDATE MySwarm CHAN
    ls ~/.zen/tmp/swarm
    SWARMSIZE=$(du -b ~/.zen/tmp/swarm | tail -n 1 | cut -f 1)

    ## SIZE MODIFIED => PUBLISH MySwarm_${IPFSNODEID}
    [[ ${SWARMSIZE} != $(cat ~/.zen/tmp/swarm/.bsize) ]] \
    && echo ${SWARMSIZE} > ~/.zen/tmp/swarm/.bsize \
    && SWARMH=$(ipfs add -rwq ~/.zen/tmp/swarm/* | tail -n 1 ) \
    && echo "=== ~/.zen/tmp/swarm EVOLVED : PUBLISHING NEW STATE ===" \
    && ipfs name publish --key "MySwarm_${IPFSNODEID}" --allow-offline /ipfs/${SWARMH}
#############################################

    ######################################
    ############# RE PUBLISH SELF BALISE

    # Clean Empty Directory (inode dependancy BUG ??)
    du -b ~/.zen/tmp/${IPFSNODEID} > /tmp/du
    while read branch; do [[ $branch =~ "4096" ]] && echo "empty $branch" && rm -Rf $(echo $branch | cut -f 2 -d ' '); done < /tmp/du

    # Scan local cache
    ls ~/.zen/tmp/${IPFSNODEID}/
    BSIZE=$(du -b ~/.zen/tmp/${IPFSNODEID} | tail -n 1 | cut -f 1)

    ## IPFS GET LAST PUBLISHED MAP VERSION
    rm -Rf ~/.zen/tmp/_${IPFSNODEID} 2>/dev/null
    mkdir -p ~/.zen/tmp/_${IPFSNODEID}
    ipfs get -o ~/.zen/tmp/_${IPFSNODEID} /ipns/${IPFSNODEID}/
    NSIZE=$(du -b ~/.zen/tmp/_${IPFSNODEID} | tail -n 1 | cut -f 1)

    ### CHECK IF SIZE DIFFERENCE ?
    ## Local / IPNS size differ => FUSION LOCAL OVER ONLINE & PUBLISH
    [[ ${BSIZE} != ${NSIZE} ]] \
    && echo "${MOATS}" > ~/.zen/tmp/${IPFSNODEID}/_MySwarm.moats \
    && MYCACHE=$(ipfs add -rwq ~/.zen/tmp/${IPFSNODEID}/* | tail -n 1 ) \
    && echo "PUBLISHING NEW BALISE STATE FOR STATION /ipns/${IPFSNODEID} INDEXES = $BSIZE octets" \
    && ipfs name publish --allow-offline /ipfs/${MYCACHE}

    end=`date +%s`
    echo "(*__*) MySwam Update ($BSIZE B) duration was "`expr $end - $start`' seconds. '$(date)

    ) & ##### SUB-PROCESS

    # last run recording
    echo "${MOATS}" > ~/.zen/tmp/.MySwarm.moats

    else

        echo "#######################"
        echo "NOT SO QUICK"
        echo "$duree only cache life"
        echo "#######################"

    fi

############ PREPARE HTTP 12345 JSON DOCUMENT
    HTTPSEND="HTTP/1.1 200 OK
Access-Control-Allow-Origin: \*
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET
Server: Astroport.ONE
Content-Type: application/json; charset=UTF-8

{
    \"created\" : \"${MOATS}\",
    \"hostname\" : \"$(myHostName)\",
    \"myIP\" : \"${myIP}\",
    \"ipfsnodeid\" : \"${IPFSNODEID}\",
    \"astroport\" : \"http://${myIP}:1234\",
    \"g1station\" : \"${myIPFS}/ipns/${IPFSNODEID}\",
    \"g1swarm\" : \"${myIPFS}/ipns/${CHAN}\"
}
"
    ######################################################################################
    #  WAIT FOR REQUEST ON PORT12345 (netcat is waiting)
    [[ ! -s ~/.zen/tmp/random.sleep ]] \
        && T2WAIT=$((3600-${RANDOM:0:3})) \
        || T2WAIT=$(cat ~/.zen/tmp/random.sleep)

    if [[ $T2WAIT == 0 || $T2WAIT != $(cat ~/.zen/tmp/random.sleep 2>/dev/null) ]]; then
        (
            echo $T2WAIT > ~/.zen/tmp/random.sleep
            sleep $T2WAIT && rm ~/.zen/tmp/random.sleep
            curl -s "http://127.0.0.1:12345"
        ) & ## AUTO RELAUNCH IN ABOUT AN HOUR : DESYNC SWARM REFRESHINGS
    fi
    ######################################################################################
    echo '(◕‿‿◕) http://'$myIP:'12345 READY (◕‿‿◕)'
    REQ=$(echo "$HTTPSEND" | nc -l -p 12345 -q 1) ## # WAIT FOR 12345 PORT CONTACT
    ######################################################################################
    ######################################################################################
    ######################################################################################
    ## VISIT RECEIVED
    URL=$(echo "$REQ" | grep '^GET' | cut -d ' ' -f2  | cut -d '?' -f2)
    HOSTP=$(echo "$REQ" | grep '^Host:' | cut -d ' ' -f2  | cut -d '?' -f2)
    HOST=$(echo "$HOSTP" | cut -d ':' -f 1)
    COOKIE=$(echo "$REQ" | grep '^Cookie:' | cut -d ' ' -f2)
    echo "RECEPTION : $URL"
    arr=(${URL//[=&]/ })

    #####################################################################
    ### UPSYNC STATION REQUEST /?G1PUB=g1_to_ipfs(G1PUB)&...
    ### TODO : include CODE HASH & TOKEN ....
    #####################################################################
    if [[ ${arr[0]} != "" ]]; then

        ## CHECK URL CONSISTENCY ( G1PUB=IPNSPUB is right ? )
        GPUB=${arr[0]}
        ASTROTOIPFS=$(${MY_PATH}/tools/g1_to_ipfs.py ${arr[0]} 2>/dev/null)

        if [[ "${ASTROTOIPFS}" == "${arr[1]}" && ${ASTROTOIPFS} != "" && ${arr[1]} != "" ]]; then
            ## WE SPEAK THE SAME PROTOCOL
            echo "MAJOR TOM TO GROUD CONTROL"
            echo "WE HAVE A STATION ${GPUB} CONTACT"
            (
            mkdir -p ~/.zen/tmp/swarm/${ASTROTOIPFS}
            echo "UPSYNC TO  ~/.zen/tmp/swarm/${ASTROTOIPFS}"
            [[ $YOU ]] && ipfs --timeout 180s get -o ~/.zen/tmp/swarm/${ASTROTOIPFS} /ipns/${ASTROTOIPFS}
            ) &

        fi
    fi

    #### 12345 NETWORK MAP TOKEN
    end=`date +%s`
    echo '(#__#) WAITING TIME was '`expr $end - $start`' seconds.'
    echo '(^‿‿^) 12345 TOKEN '${MOATS}' CONSUMED  (^‿‿^)'

done

exit 0
