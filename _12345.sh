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
if [ -s "$HOME/.astro/bin/activate" ]; then
    source $HOME/.astro/bin/activate
fi
export PATH=$HOME/.local/bin:$PATH

## SEND LOG TO ~/.zen/tmp/_12345.log
rm ~/.zen/tmp/_12345.log
exec 2>&1 >> ~/.zen/tmp/_12345.log

PORT=12345

## KILLING OLD DAEMON OF MYSELF
ncrunning=$(pgrep -au $USER -f 'nc -l -p 12345' | tail -n 1 | xargs | cut -d " " -f 1)
[[ $ncrunning != "" ]] && echo "(≖‿‿≖) - KILLING Already Running MAP Server -  (≖‿‿≖) " && kill -9 $ncrunning

## WHAT IS NODEG1PUB
NODEG1PUB=$($MY_PATH/tools/ipfs_to_g1.py ${IPFSNODEID})

##############################################
[[ ${IPFSNODEID} == "" || ${IPFSNODEID} == "null" ]] && echo "IPFSNODEID is empty" && exit 1
mkdir -p ~/.zen/tmp/swarm
mkdir -p ~/.zen/tmp/${IPFSNODEID}

## AVOID A swarm IN swarm LOOP !!!
rm -Rf ~/.zen/tmp/${IPFSNODEID}/swarm

## TIMESTAMPING
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
echo "${MOATS}" > ~/.zen/tmp/${IPFSNODEID}/_MySwarm.moats
echo "$(date -u)" > ~/.zen/tmp/${IPFSNODEID}/_MySwarm.staom

############################################################
##  MySwarm KEY INIT & SET
############################################################
## CREATE CHAN = MySwarm_${IPFSNODEID}
CHAN=$(ipfs key list -l | grep -w "MySwarm_${IPFSNODEID}" | cut -d ' ' -f 1)

#######################################################
## CREATE MySwarm KEYS ?
if [[ ${CHAN} == "" || ${CHAN} == "null" || ! -s ~/.zen/game/myswarm_secret.june ]]; then
echo "## MAKE /proc/cpuinfo IPFSNODEID DERIVATED KEY ##"
    SECRET1=$(cat /proc/cpuinfo | grep -Ev MHz | sha512sum | cut -d ' ' -f 1)
    SECRET2=${IPFSNODEID}
    ipfs key rm "MySwarm_${IPFSNODEID}"
    echo "SALT=$SECRET1 && PEPPER=$SECRET2" > ~/.zen/game/myswarm_secret.june
    ${MY_PATH}/tools/keygen -t ipfs -o ~/.zen/game/myswarm_secret.ipfskey "$SECRET1${UPLANETNAME}" "$SECRET2${UPLANETNAME}"
    ${MY_PATH}/tools/keygen -t duniter -o ~/.zen/game/myswarm_secret.dunikey "$SECRET1${UPLANETNAME}" "$SECRET2${UPLANETNAME}"
    ipfs key import "MySwarm_${IPFSNODEID}" -f pem-pkcs8-cleartext ~/.zen/game/myswarm_secret.ipfskey
    CHAN=$(ipfs key list -l | grep -w "MySwarm_${IPFSNODEID}" | cut -d ' ' -f 1 )
 fi
######################################################## MAKE IPFS NODE CHAN ID CPU RELATED

## PUBLISH CHANNEL IPNS
echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipns/${CHAN}'\" />" > ~/.zen/tmp/${IPFSNODEID}/_MySwarm.$(myHostName).html

############################################################
############################################################
echo 0 > ~/.zen/tmp/random.sleep
###################################################################
###############################################
UPLANETG1PUB=$(${MY_PATH}/tools/keygen -t duniter "${UPLANETNAME}" "${UPLANETNAME}")
##############################
#### UPLANET GEOKEYS_refresh
${MY_PATH}/RUNTIME/GEOKEYS_refresh.sh &

###################################################################
## WILL SCAN ALL BOOSTRAP - REFRESH "SELF IPNS BALISE" - RECEIVE UPLINK ORDERS
###################################################################
###################
# NEVER ENDING LOOP
while true; do

    start=`date +%s`
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    [[ -z ${myIP} ]] && source "${MY_PATH}/tools/my.sh" ## correct 1st run DHCP latency
    [[ ${CHAN} == "" ]] && CHAN=$(ipfs key list -l | grep -w "MySwarm_${IPFSNODEID}" | cut -d ' ' -f 1)

    echo "/ip4/${myIP}/tcp/4001/p2p/${IPFSNODEID}" > ~/.zen/tmp/${IPFSNODEID}/myIPFS.txt

    [[ ! -z ${zipit} ]] \
        && myIP=${zipit} \
        && echo "/ip4/${zipit}/tcp/4001/p2p/${IPFSNODEID}" > ~/.zen/tmp/${IPFSNODEID}/myIPFS.txt

    [[ ! -z ${myDNSADDR} ]] \
        && echo "/dnsaddr/${myDNSADDR}/p2p/${IPFSNODEID}" > ~/.zen/tmp/${IPFSNODEID}/myIPFS.txt

    lastrun=$(cat ~/.zen/tmp/${IPFSNODEID}/_MySwarm.moats)
    duree=$(expr ${MOATS} - $lastrun)

    ## FIXING TIC TAC FOR NODE & SWARM REFRESH ( 1H in ms )
    if [[ ${duree} -gt 3600000 || ${duree} == "" ]]; then

        ### STOP SWARM SYNC 1H BEFORE 20H12 : TODO CHECK THIS
        if [[ -s /tmp/20h12.log ]]; then
            current_time=$(date +%s)
            file_modification_time=$(stat -c %Y "/tmp/20h12.log")
            time_difference=$((current_time - file_modification_time))
            [ "$time_difference" -ge $(( 23 * 60 * 60 )) ] \
                && echo "$(date +"%H%M") : 20H12 is running... " && continue
        fi

        PLAYERONE=($(ls -t ~/.zen/game/players/  | grep "@" 2>/dev/null))
        YIPNS=$(${MY_PATH}/tools/ssh_to_g1ipfs.py "$(cat ~/.ssh/id_ed25519.pub)")
        ## NOT Y LEVEL STATIONS
        if [[ ${IPFSNODEID} != ${YIPNS} ]]; then
            ## NO CAPTAIN ON BOARD
            [[ ${PLAYERONE[@]} == "" ]] \
                && duree=0 && lastrun=${MOATS} && break
        fi

        ## CHECK IF IPFS NODE IS RESPONDING
        ipfs --timeout=30s swarm peers 2>/dev/null > ~/.zen/tmp/ipfs.swarm.peers
        [[ ! -s ~/.zen/tmp/ipfs.swarm.peers || $? != 0 ]] \
            && echo "---- SWARM COMMUNICATION BROKEN / RESTARTING IPFS DAEMON ----" \
            && [[ $(sudo systemctl status ipfs | grep disabled) == "" ]] && sudo systemctl restart ipfs \
            && sleep 60

        ${MY_PATH}/ping_bootstrap.sh

        #### UPLANET FLASHMEM UPDATES
        GEOKEYSrunning=$(pgrep -au $USER -f 'GEOKEYS_refresh.sh' | tail -n 1 | xargs | cut -d " " -f 1)
        [[ -z $GEOKEYSrunning ]] && ${MY_PATH}/RUNTIME/GEOKEYS_refresh.sh &

        #####################################
        ( ##### SUB-PROCESS £
        start=`date +%s`
        ############# GET BOOSTRAP SWARM DATA
        for bootnode in $(cat ${STRAPFILE} | grep -Ev "#" | grep -v '^[[:space:]]*$') # remove comments and empty lines
        do

            ## ex: /ip4/149.102.158.67/tcp/4001/p2p/12D3KooWL2FcDJ41U9SyLuvDmA5qGzyoaj2RoEHiJPpCvY8jvx9u)
            echo "############# RUN LOOP ######### $(date)"
            ipfsnodeid=${bootnode##*/}

            [[ ${ipfsnodeid} == ${IPFSNODEID} ]] && echo "MYSELF : ${IPFSNODEID} - CONTINUE" && continue

            [[ ${ipfsnodeid} == "null" || ${ipfsnodeid} == "" ]] && echo "BAD ${IPFSNODEID} - CONTINUE" && continue

            ## SWARM CONNECT
            ipfs --timeout 20s swarm connect ${bootnode}

            ## PREPARE TO REFRESH SWARM LOCAL CACHE
            mkdir -p ~/.zen/tmp/swarm/${ipfsnodeid}
            mkdir -p ~/.zen/tmp/-${ipfsnodeid}

            ## GET bootnode IP
            iptype=$(echo ${bootnode} | cut -d '/' -f 2)
            nodeip=$(echo ${bootnode} | cut -d '/' -f 3)

            ## IPFS GET TO /swarm/${ipfsnodeid}
            echo "GETTING ${nodeip} : /ipns/${ipfsnodeid}"
            ipfs --timeout 720s get --progress="false" -o ~/.zen/tmp/-${ipfsnodeid}/ /ipns/${ipfsnodeid}/

            ## SHOW WHAT WE GET
            echo "__________________________________________________"
            ls ~/.zen/tmp/-${ipfsnodeid}/
            echo "__________________________________________________"

            ## LOCAL CACHE SWITCH WITH LATEST
            if [[ -s ~/.zen/tmp/-${ipfsnodeid}/_MySwarm.moats  ]]; then
                 # Compare MOATs here
                local_moat=$(cat ~/.zen/tmp/swarm/${ipfsnodeid}/_MySwarm.moats 2>/dev/null)
                remote_moat=$(cat ~/.zen/tmp/-${ipfsnodeid}/_MySwarm.moats)

                if [[ "$local_moat" != "$remote_moat"  || "$local_moat" == "" ]]; then

                    rm -Rf ~/.zen/tmp/swarm/${ipfsnodeid}
                    mv ~/.zen/tmp/-${ipfsnodeid} ~/.zen/tmp/swarm/${ipfsnodeid}
                    echo "UPDATED : ~/.zen/tmp/swarm/${ipfsnodeid}"
                else
                    echo "TimeStamp unchanged : ${local_moat}"
                    rm -Rf ~/.zen/tmp/-${ipfsnodeid}/
                    continue
                fi
            else
                echo "UNREACHABLE /ipns/${ipfsnodeid}/"
                continue
            fi

            ## ASK BOOSTRAP NODE TO GET MY MAP UPSYNC
            ## - MAKES MY BALISE PRESENT IN BOOSTRAP SWARM KEY  -
            if [[ $iptype == "ip4" || $iptype == "ip6" || $iptype == "dnsaddr" ]]; then
                ############ UPSYNC CALL
                if [[ $iptype == "dnsaddr" ]]; then
                    echo "STATION MAP UPSYNC : curl -s https://${nodeip}/12345/?${NODEG1PUB}=${IPFSNODEID}"
                    curl -s -m 10 https://${nodeip}/12345/?${NODEG1PUB}=${IPFSNODEID} \
                        -o ~/.zen/tmp/swarm/${ipfsnodeid}/12345.${nodeip}.json
                else
                    echo "STATION MAP UPSYNC : curl -s http://${nodeip}:12345/?${NODEG1PUB}=${IPFSNODEID}"
                    curl -s -m 10 http://${nodeip}:12345/?${NODEG1PUB}=${IPFSNODEID} \
                        -o ~/.zen/tmp/swarm/${ipfsnodeid}/12345.${nodeip}.json
                fi

                ### CHECK FOR SAME UPLANET
                uplanetpub=$(cat ~/.zen/tmp/swarm/${ipfsnodeid}/12345.${nodeip}.json | jq -r '.UPLANETG1PUB')
                [[ "$UPLANETG1PUB" != "$uplanetpub" && "$uplanetpub" != "" ]] \
                    && echo "!!! ALERT. UPlanet $uplanetpub IS DIFFERENT OF MINE ${UPLANETG1PUB} !!! REMOVE FROM SWARM MAP" \
                    && rm -Rf ~/.zen/tmp/swarm/${ipfsnodeid-none}/ \
                    && continue

                ## LOOKING IF ITS SWARM MAP COULD COMPLETE MINE
                echo "ANALYSING BOOSTRAP SWARM MAP"
                itipnswarmap=$(cat ~/.zen/tmp/swarm/${ipfsnodeid}/12345.${nodeip}.json | jq -r '.g1swarm' | rev | cut -d '/' -f 1 | rev )
                ipfs ls /ipns/${itipnswarmap} | rev | cut -d ' ' -f 1 | rev | cut -d '/' -f 1 > ~/.zen/tmp/_swarm.${ipfsnodeid}

                echo "================ ${nodeip} 12345 ZNODS LIST"
                cat ~/.zen/tmp/_swarm.${ipfsnodeid}
                echo "============================================"
                for znod in $(cat ~/.zen/tmp/_swarm.${ipfsnodeid}); do
                    # CHECK znod validity
                    cznod=$(${MY_PATH}/tools/ipfs_to_g1.py ${znod} 2>/dev/null)
                    [[ ${cznod} == "" || ${cznod} == "null" ]] \
                        && echo "xxxxxxxxxxxx BAD ${znod} xxxx ON xxxxxx ${ipfsnodeid} - ERROR - CONTINUE" \
                        && continue
                    [[ ${cznod} == ${IPFSNODEID} ]] \
                        && echo "IPFSNODEID MIRROR ME" \
                        && continue

                    echo "REFRESHING MY SWARM DATA WITH ZNOD=${znod}"
                    mkdir -p ~/.zen/tmp/swarm/${znod}
                    ipfs --timeout 180s get --progress="false" -o ~/.zen/tmp/swarm/${znod} /ipns/${znod}

                    ZMOATS=$(cat ~/.zen/tmp/swarm/${znod}/_MySwarm.moats 2>/dev/null)
                    MOATS_SECONDS=$(${MY_PATH}/tools/MOATS2seconds.sh ${MOATS})
                    ZMOATS_SECONDS=$(${MY_PATH}/tools/MOATS2seconds.sh ${ZMOATS})
                    DIFF_SECONDS=$((MOATS_SECONDS - ZMOATS_SECONDS))
                    if [ ${DIFF_SECONDS} -gt $(( 3 * 24 * 60 * 60 )) ]; then
                        echo "STATION IS STUCK... FOR MORE THAN 3 DAYS... REMOVING ${znod} FROM SWARM"
                        rm -Rf ~/.zen/tmp/swarm/${znod}/
                    else
                        echo "${DIFF_SECONDS} seconds old"
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
        SWARMSIZE=$(du -b ~/.zen/tmp/swarm | tail -n 1 | xargs | cut -f 1)

        ## SIZE MODIFIED => PUBLISH MySwarm_${IPFSNODEID}
        local_swarm_size=$(cat ~/.zen/tmp/swarm/.bsize 2>/dev/null)
        if [[ "$SWARMSIZE" != "$local_swarm_size"  || "$local_swarm_size" == "" ]] ; then
            echo ${SWARMSIZE} > ~/.zen/tmp/swarm/.bsize
            SWARMH=$(ipfs --timeout 180s add -rwq ~/.zen/tmp/swarm/* | tail -n 1 )
            echo "=== ~/.zen/tmp/swarm EVOLVED : PUBLISHING NEW STATE ==="
            ipfs --timeout=180s name publish --key "MySwarm_${IPFSNODEID}" /ipfs/${SWARMH}
        fi
    #############################################

        ######################################
        ############# RE PUBLISH SELF BALISE

        # Clean Empty Directory
        du -b ~/.zen/tmp/${IPFSNODEID} > /tmp/du
        while read branch; do [[ $branch =~ "4096" ]] && echo "empty $branch" && rm -Rf $(echo $branch | cut -f 2 -d ' '); done < /tmp/du

        # Scan IPFSNODEID cache
        ls ~/.zen/tmp/${IPFSNODEID}/
        BSIZE=$(du -b ~/.zen/tmp/${IPFSNODEID} | tail -n 1 | xargs | cut -f 1)

        ## IPFS GET LAST ONLINE IPFSNODEID MAP
        rm -Rf ~/.zen/tmp/_${IPFSNODEID} 2>/dev/null
        mkdir -p ~/.zen/tmp/_${IPFSNODEID}
        ipfs get --progress="false" -o ~/.zen/tmp/_${IPFSNODEID}/ /ipns/${IPFSNODEID}/
        NSIZE=$(du -b ~/.zen/tmp/_${IPFSNODEID} | tail -n 1 | xargs | cut -f 1)

        ### CHECK IF SIZE DIFFERENCE ?
        ## Local / IPNS size differ => FUSION LOCAL OVER ONLINE & PUBLISH

       local_moat_self=$(cat ~/.zen/tmp/${IPFSNODEID}/_MySwarm.moats 2>/dev/null)
       remote_moat_self=$(cat ~/.zen/tmp/_${IPFSNODEID}/_MySwarm.moats 2>/dev/null)

       if [[ "$BSIZE" != "$NSIZE"  || "$local_moat_self" != "$remote_moat_self" || "$local_moat_self" == "" ]]; then
            if [[ -s ~/.zen/tmp/${IPFSNODEID}/myIPFS.txt ]]; then
                echo "${MOATS}" > ~/.zen/tmp/${IPFSNODEID}/_MySwarm.moats
                MYCACHE=$(ipfs --timeout 180s add -rwq ~/.zen/tmp/${IPFSNODEID}/* | tail -n 1 )
                echo "PUBLISHING NEW BALISE STATE FOR STATION /ipns/${IPFSNODEID} INDEXES = $BSIZE octets"
                ipfs --timeout=180s name publish /ipfs/${MYCACHE}
            else
                echo "IPFSNODEID BALISE NOT COMPLETLY FORMED YET..."
            fi
       fi

        end=`date +%s`
        echo "(*__*) MySwam Update ($BSIZE B) duration was "`expr $end - $start`' seconds. '$(date)

        ) & ##### SUB-PROCESS

        # last run recording
        echo "${MOATS}" > ~/.zen/tmp/${IPFSNODEID}/_MySwarm.moats
        echo "$(date -u)" > ~/.zen/tmp/${IPFSNODEID}/_MySwarm.staom

    else

        echo "#######################"
        echo "NOT SO QUICK"
        echo "$duree only cache life"
        echo "#######################"

    fi

NODE12345="{
    \"version\" : \"2.0\",
    \"created\" : \"${MOATS}\",
    \"date\" : \"$(cat $HOME/.zen/tmp/${IPFSNODEID}/_MySwarm.staom)\",
    \"hostname\" : \"$(myHostName)\",
    \"myIP\" : \"${myIP}\",
    \"myASTROPORT\" : \"${myASTROPORT}\",
    \"myIPFS\" : \"${myIPFS}\",
    \"myAPI\" : \"${myAPI}\",
    \"ipfsnodeid\" : \"${IPFSNODEID}\",
    \"astroport\" : \"http://${myIP}:1234\",
    \"g1station\" : \"${myIPFS}/ipns/${IPFSNODEID}\",
    \"g1swarm\" : \"${myIPFS}/ipns/${CHAN}\",
    \"captain\" : \"${CAPTAINEMAIL}\",
    \"SSHPUB\" : \"$(cat $HOME/.ssh/id_ed25519.pub)\",
    \"NODEG1PUB\" : \"${NODEG1PUB}\",
    \"UPLANETG1PUB\" : \"${UPLANETG1PUB}\"
}
"

## PUBLISH ${IPFSNODEID}/12345.json
echo "${NODE12345}" > ~/.zen/tmp/${IPFSNODEID}/12345.json

############ PREPARE HTTP 12345 JSON DOCUMENT
    HTTPSEND="HTTP/1.1 200 OK
Access-Control-Allow-Origin: \*
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET
Server: Astroport.ONE
Content-Type: application/json; charset=UTF-8

${NODE12345}
"
    ######################################################################################
    #  WAIT FOR REQUEST ON PORT12345 (netcat is waiting)
    [[ ! -s ~/.zen/tmp/random.sleep ]] \
        && T2WAIT=$((3600-${RANDOM:0:3})) \
        || T2WAIT=$(cat ~/.zen/tmp/random.sleep)

    if [[ $T2WAIT == 0 || $T2WAIT != $(cat ~/.zen/tmp/random.sleep 2>/dev/null) ]]; then
        (
            echo "# AUTO RELAUNCH IN $T2WAIT SECONDS"
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
    ### UPSYNC STATION REQUEST :12345/?G1PUB=g1_to_ipfs(G1PUB)&...
    ## & JOIN 1234
    #####################################################################
    if [[ ${arr[0]} != "" ]]; then

        ## CHECK URL CONSISTENCY ( do we get G1PUB=IPNSPUB right ? )
        GPUB=${arr[0]}
        ASTROTOIPFS=$(${MY_PATH}/tools/g1_to_ipfs.py ${arr[0]} 2>/dev/null)

        if [[ "${ASTROTOIPFS}" == "${arr[1]}" && ${ASTROTOIPFS} != "" && ${arr[1]} != "" ]]; then
            ## WE SPEAK THE SAME PROTOCOL
            echo "WE HAVE A STATION ${GPUB} CONTACT"
            (
            timeon=`date +%s`
            mkdir -p ~/.zen/tmp/swarm/${ASTROTOIPFS}
            echo "<<< MAJOR TOM TO GROUND CONTROL >>> UPSYNC TO  ~/.zen/tmp/swarm/${ASTROTOIPFS}"
            ipfs --timeout 240s get --progress="false" -o ~/.zen/tmp/swarm/${ASTROTOIPFS} /ipns/${ASTROTOIPFS}
            timeoff=`date +%s`
            echo ">>> GROUND CONTROL FINISH in $(( timeoff - timeon )) sec <<<"
            ) &
        fi

    fi

    #### 12345 NETWORK MAP TOKEN
    end=`date +%s`
    echo '(#__#) WAITING TIME was '`expr $end - $start`' seconds.'
    echo '(^‿‿^) 12345 TOKEN '${MOATS}' CONSUMED  (^‿‿^)'

done

exit 0
