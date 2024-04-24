#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh"
################################################################################
## MAP REFRESH
# LOAD EXTRA DATA TO CACHE ~/.zen/tmp/${IPFSNODEID}/
# PUBLISH STATION BALISE
############################################
echo "## RUNNING NODE.refresh"
[[ ${IPFSNODEID} == "" ]] && echo "IPFSNODEID is empty - EXIT -" && exit 1

    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

#################################################################
## IPFSNODEID ASTRONAUTES SIGNALING ## 12345 port
############################

# UDATE STATION BALISE
if [[ -d ~/.zen/tmp/${IPFSNODEID} ]]; then

    # ONLY FRESH DATA HERE
    BSIZE=$(du -b ~/.zen/tmp/${IPFSNODEID} | tail -n 1 | xargs | cut -f 1)
    ## Getting actual online version
    #~ ipfs get -o ~/.zen/tmp/${IPFSNODEID} /ipns/${IPFSNODEID}/

    ## COPY STATION  yt-dlp.list
    cp $HOME/.zen/.yt-dlp.list ~/.zen/tmp/${IPFSNODEID}/yt-dlp.list
    cp $HOME/.zen/.yt-dlp.mp3.list ~/.zen/tmp/${IPFSNODEID}/yt-dlp.mp3.list

    ## COPY COINS VALUE OF THE DAY
    rm -Rf ~/.zen/tmp/${IPFSNODEID}/COINS/
    mkdir -p ~/.zen/tmp/${IPFSNODEID}/COINS/
    cp -f ~/.zen/tmp/coucou/*.COINS ~/.zen/tmp/${IPFSNODEID}/COINS/

    ## COPY 20h12.log
    rm -f ~/.zen/tmp/${IPFSNODEID}/20h12.log ## TODO REMOVE
    cp -f /tmp/20h12.log ~/.zen/tmp/${IPFSNODEID}/20h12.txt

    ## COPY FRIENDS
    PLAYERONE=($(ls -t ~/.zen/game/players/  | grep "@" 2>/dev/null))
    echo "FOUND : ${PLAYERONE[@]}"
    ## RUNING FOR ALL LOCAL PLAYERS
    for PLAYER in ${PLAYERONE[@]}; do
        echo "${PLAYER} GCHANGE FRIENDS"
        [[ -d ~/.zen/tmp/${IPFSNODEID}/${PLAYER} && ${PLAYER} != "" ]] && rm -Rf ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/ ## TODO REMOVE (PROTOCOL UPGRADE)
        mkdir -p ~/.zen/tmp/${IPFSNODEID}/GCHANGE/${PLAYER}/FRIENDS/
        cp -Rf ~/.zen/game/players/${PLAYER}/FRIENDS/* ~/.zen/tmp/${IPFSNODEID}/GCHANGE/${PLAYER}/FRIENDS/ 2>/dev/null
    done

    ## INFORM GPS LOCATION
    [[ -s ~/.zen/game/players/.current/GPS.json ]] \
        && cp ~/.zen/game/players/.current/GPS.json ~/.zen/tmp/${IPFSNODEID}/ \
        && LAT=$(cat ~/.zen/tmp/${IPFSNODEID}/GPS.json | jq -r .[].lat) \
        && LON=$(cat ~/.zen/tmp/${IPFSNODEID}/GPS.json | jq -r .[].lon) \
        && echo "LAT=${LAT}; LON=${LON}" > ~/.zen/GPS

    ## REFRESH TIMESTAMPING
    echo "${MOATS}" > ~/.zen/tmp/${IPFSNODEID}/_MySwarm.moats
    echo "$(date -u)" > ~/.zen/tmp/${IPFSNODEID}/_MySwarm.staom

    echo "############################################ MY MAP "
    ls ~/.zen/tmp/${IPFSNODEID}/
    echo "############################################"
    NSIZE=$(du -b ~/.zen/tmp/${IPFSNODEID} | tail -n 1 | xargs | cut -f 1)
    ROUTING=$(ipfs add -rwHq ~/.zen/tmp/${IPFSNODEID}/* | tail -n 1 )
    ipfs name publish /ipfs/${ROUTING}
    echo ">> $NSIZE Bytes STATION BALISE > ${myIPFS}/ipns/${IPFSNODEID}"

fi

echo "## CLEANING SWARM 3 DAYS OLD"
find  ~/.zen/tmp/swarm/ -mtime +3 -type d -exec rm -Rf '{}' \;

exit 0
