#!/bin/bash
################################################################################
# Script: Astroport Swarm Node Manager
# Version: 0.2
# License: AGPL-3.0
#
# Description:
# Ce script gère la publication et la synchronisation des cartes de stations
# Astroport dans un réseau décentralisé basé sur IPFS (InterPlanetary File System).
#
# Fonctionnalités principales :
# 1. Initialisation de l'identité du nœud (clés IPFS, Nostr et Duniter).
# 2. Synchronisation avec les nœuds bootstrap pour maintenir une vue à jour du réseau.
# 3. Publication périodique des métadonnées du nœud via IPNS (système de nommage IPFS).
# 4. Service HTTP sur le port 12345 pour répondre aux requêtes des autres stations.
#
# Usage :
# - Exécutez ce script en tant que démon pour maintenir la présence de votre nœud
#   dans le réseau Astroport.
# - Les données sont stockées dans ~/.zen/tmp/ et ~/.zen/game/.
#
# Dépendances :
# - IPFS (nœud local configuré et en cours d'exécution).
# - Outils supplémentaires dans ./tools/ (keygen, ipfs_to_g1.py, etc.).
# - Packages : jq, netcat, curl.
#
# Auteur: Fred (support@qo-op.com)
# Notes :
# Ce script maintien la couche SWARM de l'essaim IPFS reliant les Astroport,
# PUBLISH AND SYNC ASTROPORT STATIONS SWARM MAPS
# This script scan Swarm API layer from official bootstraps
#################################################################################
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
NODECOINS=$($MY_PATH/tools/COINScheck.sh ${NODEG1PUB} | tail -n 1)
NODEZEN=$(echo "($NODECOINS - 1) * 10" | bc | cut -d '.' -f 1)
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
######################################################## MAKE IPFS NODE CHAN ID CPU RELATED
    echo "## MAKE /proc/cpuinfo IPFSNODEID DERIVATED KEY ##"
    SECRET1=$(cat /proc/cpuinfo | grep -Ev MHz | sha512sum | cut -d ' ' -f 1)
    SECRET2=${IPFSNODEID}
    ipfs key rm "MySwarm_${IPFSNODEID}"
    echo "SALT=$SECRET1 && PEPPER=$SECRET2" > ~/.zen/game/myswarm_secret.june
    chmod 600 ~/.zen/game/myswarm_secret.june
    ${MY_PATH}/tools/keygen -t ipfs -o ~/.zen/game/myswarm_secret.ipns "$SECRET1${UPLANETNAME}" "$SECRET2${UPLANETNAME}"
    chmod 600 ~/.zen/game/myswarm_secret.ipns
    ${MY_PATH}/tools/keygen -t duniter -o ~/.zen/game/myswarm_secret.dunikey "$SECRET1${UPLANETNAME}" "$SECRET2${UPLANETNAME}"
    chmod 600 ~/.zen/game/myswarm_secret.dunikey
    ipfs key import "MySwarm_${IPFSNODEID}" -f pem-pkcs8-cleartext ~/.zen/game/myswarm_secret.ipns
    CHAN=$(ipfs key list -l | grep -w "MySwarm_${IPFSNODEID}" | cut -d ' ' -f 1 )
fi

## NOSTR ##############################################
## CREATE ~/.zen/game/secret.nostr (for YLEVEL NODES only)
if [[ -s ~/.zen/game/secret.june && ! -s ~/.zen/game/secret.nostr ]]; then
    source ~/.zen/game/secret.june
    npub=$(${MY_PATH}/tools/keygen -t nostr "$SALT" "$PEPPER")
    hex=$(${MY_PATH}/tools/nostr2hex.py "$npub")
    nsec=$(${MY_PATH}/tools/keygen -t nostr "$SALT" "$PEPPER" -s)
    echo "NSEC=$nsec; NPUB=$npub; HEX=$hex" > ~/.zen/game/secret.nostr
    chmod 600 ~/.zen/game/secret.nostr
    echo $hex > ~/.zen/tmp/${IPFSNODEID}/HEX
fi

######################################### CAPTAIN RELATED
## CREATE ~/.zen/game/players/.current/secret.nostr
if [[ -s ~/.zen/game/players/.current/secret.june ]]; then
    source ~/.zen/game/players/.current/secret.june
    CAPTAING1PUB=$(${MY_PATH}/tools/keygen -t duniter "$SALT" "$PEPPER")
    CAPTAINCOINS=$($MY_PATH/tools/COINScheck.sh ${CAPTAING1PUB} | tail -n 1)
    CAPTAINZEN=$(echo "($CAPTAINCOINS - 1) * 10" | bc | cut -d '.' -f 1)
    captainNPUB=$(${MY_PATH}/tools/keygen -t nostr "$SALT" "$PEPPER")
    captainHEX=$(${MY_PATH}/tools/nostr2hex.py "$captainNPUB")
    captainNSEC=$(${MY_PATH}/tools/keygen -t nostr "$SALT" "$PEPPER" -s)
    echo "NSEC=$captainNSEC; NPUB=$captainNPUB; HEX=$captainHEX" \
        > ~/.zen/game/players/.current/secret.nostr
    chmod 600 ~/.zen/game/players/.current/secret.nostr

    ## Add CAPTAIN HEX to nostr WhiteList
    mkdir -p ~/.zen/game/nostr/CAPTAIN
    echo $captainHEX > ~/.zen/game/nostr/CAPTAIN/HEX
    echo $captainHEX > ~/.zen/tmp/${IPFSNODEID}/HEX_CAPTAIN

    ## REFRESH ZSWARM & HEX_CAPTAIN
    mkdir -p ~/.zen/game/nostr/ZSWARM
    cat ~/.zen/tmp/swarm/*/UPLANET/__/_*_*/_*.?_*.?/*/HEX > ~/.zen/game/nostr/ZSWARM/HEX
    cat ~/.zen/tmp/swarm/*/HEX* >> ~/.zen/game/nostr/ZSWARM/HEX

else

    rm -Rf ~/.zen/game/nostr/CAPTAIN

fi
##################################################

###########################################################""
## PUBLISH CHANNEL IPNS LINK
echo "<meta http-equiv=\"refresh\" content=\"0; url='/ipns/${CHAN}'\" />" > ~/.zen/tmp/${IPFSNODEID}/_MySwarm.$(myHostName).html

############################################################
############################################################
echo 0 > ~/.zen/tmp/random.sleep
###################################################################
###############################################
UPLANETCOINS=$($MY_PATH/tools/COINScheck.sh ${UPLANETG1PUB} | tail -n 1)
UPLANETZEN=$(echo "($UPLANETCOINS - 1) * 10" | bc | cut -d '.' -f 1)
###############################################
#### UPLANET GEOKEYS_refresh - not for UPlanet ORIGIN
if [[ $UPLANETNAME != "EnfinLibre" ]]; then
    ${MY_PATH}/RUNTIME/GEOKEYS_refresh.sh &
fi

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

    echo "/ip4/${myIP}/udp/4001/p2p/${IPFSNODEID}" > ~/.zen/tmp/${IPFSNODEID}/myIPFS.txt

    [[ ! -z ${zipit} ]] \
        && myIP=${zipit} \
        && echo "/ip4/${zipit}/udp/4001/p2p/${IPFSNODEID}" > ~/.zen/tmp/${IPFSNODEID}/myIPFS.txt

    [[ ! -z ${myDNSADDR} ]] \
        && echo "/dnsaddr/${myDNSADDR}/udp/4001/p2p/${IPFSNODEID}" > ~/.zen/tmp/${IPFSNODEID}/myIPFS.txt

    lastrun=$(cat ~/.zen/tmp/${IPFSNODEID}/_MySwarm.moats)
    duree=$(expr ${MOATS} - $lastrun)

    ## FIXING TIC TAC FOR NODE & SWARM REFRESH ( 1H in ms )
    if [[ ${duree} -gt 3600000 || ${duree} == "" ]]; then

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
        if [[ ! -s ~/.zen/tmp/ipfs.swarm.peers || $? != 0 ]]; then
            echo "---- SWARM COMMUNICATION BROKEN / RESTARTING IPFS DAEMON ----"
            [[ $(sudo systemctl status ipfs | grep disabled) == "" ]] && sudo systemctl restart ipfs
        fi

        ${MY_PATH}/ping_bootstrap.sh

        # IPNS flashmem desactivated - reactivate as needed - _UPLANET.refresh.sh TW system
        #~ #### UPLANET FLASHMEM UPDATES
        #~ GEOKEYSrunning=$(pgrep -au $USER -f 'GEOKEYS_refresh.sh' | tail -n 1 | xargs | cut -d " " -f 1)
        #~ [[ -z $GEOKEYSrunning ]] && ${MY_PATH}/RUNTIME/GEOKEYS_refresh.sh &

        ### NOSTR refresh
        ${MY_PATH}/RUNTIME/NOSTRCARD.refresh.sh &

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
        BSIZE=$(du -b ~/.zen/tmp/${IPFSNODEID} | tail -n 1 | xargs | awk '{print $1}')

        ## IPFS GET LAST ONLINE IPFSNODEID MAP
        rm -Rf ~/.zen/tmp/_${IPFSNODEID} 2>/dev/null
        mkdir -p ~/.zen/tmp/_${IPFSNODEID}
        ipfs get --progress="false" -o ~/.zen/tmp/_${IPFSNODEID}/ /ipns/${IPFSNODEID}/
        NSIZE=$(du -b ~/.zen/tmp/_${IPFSNODEID} | tail -n 1 | xargs | awk '{print $1}')

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
       # remove cache
        rm -Rf ~/.zen/tmp/_${IPFSNODEID} 2>/dev/null
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

    #######################################
    ## ZEN ECONOMY
    [[ -z $PAF ]] && PAF=56
    [[ -z $NCARD ]] && NCARD=4
    [[ -z $ZCARD ]] && ZCARD=15
    BILAN=$(cat ~/.zen/tmp/Ustats.json 2>/dev/null | jq -r '.BILAN')

    ## READ HEARTBOX ANALYSIS
    ANALYSIS_FILE=~/.zen/tmp/${IPFSNODEID}/heartbox_analysis.json
    if [[ -s ${ANALYSIS_FILE} ]]; then
        TEMP_CAPACITIES=$(cat ${ANALYSIS_FILE} | jq -r '.capacities')
        TEMP_SERVICES=$(cat ${ANALYSIS_FILE} | jq -r '.services')
        CAPACITIES=${TEMP_CAPACITIES:-"{\"reserved_captain_slots\":8}"}
        SERVICES=${TEMP_SERVICES:-"{\"ipfs\":{\"active\":true,\"peers_connected\":$(ipfs swarm peers | wc -l)},\"astroport\":{\"active\":true},\"g1billet\":{\"active\":true}}"}
    else
        CAPACITIES="{\"reserved_captain_slots\":8}"
        SERVICES="{\"ipfs\":{\"active\":true,\"peers_connected\":$(ipfs swarm peers | wc -l)},\"astroport\":{\"active\":true},\"g1billet\":{\"active\":true}}"
    fi

NODE12345="{
    \"version\" : \"3.5\",
    \"created\" : \"${MOATS}\",
    \"date\" : \"$(cat $HOME/.zen/tmp/${IPFSNODEID}/_MySwarm.staom)\",
    \"hostname\" : \"$(myHostName)\",
    \"myIP\" : \"${myIP}\",
    \"myIPv6\" : \"$(${MY_PATH}/tools/ipv6.sh | head -n 1)\",
    \"myASTROPORT\" : \"${myASTROPORT}\",
    \"myIPFS\" : \"${myIPFS}\",
    \"myAPI\" : \"${myAPI}\",
    \"uSPOT\" : \"${uSPOT}\",
    \"ipfsnodeid\" : \"${IPFSNODEID}\",
    \"astroport\" : \"http://${myIP}:1234\",
    \"g1station\" : \"${myIPFS}/ipns/${IPFSNODEID}\",
    \"g1swarm\" : \"${myIPFS}/ipns/${CHAN}\",
    \"captain\" : \"${CAPTAINEMAIL}\",
    \"captainZEN\" : \"${CAPTAINZEN}\",
    \"captainHEX\" : \"${captainHEX}\",
    \"SSHPUB\" : \"$(cat $HOME/.ssh/id_ed25519.pub)\",
    \"NODEG1PUB\" : \"${NODEG1PUB}\",
    \"NODEZEN\" : \"${NODEZEN}\",
    \"NODENPUB\" : \"${npub}\",
    \"NODEHEX\" : \"${hex}\",
    \"UPLANETG1PUB\" : \"${UPLANETG1PUB}\",
    \"UPLANETG1\" : \"${UPLANETCOINS}\",
    \"UPLANETZEN\" : \"${UPLANETZEN}\",
    \"PAF\" : \"${PAF}\",
    \"NCARD\" : \"${NCARD}\",
    \"ZCARD\" : \"${ZCARD}\",
    \"BILAN\" : \"${BILAN}\",
    \"capacities\" : ${CAPACITIES},
    \"services\" : ${SERVICES}
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
