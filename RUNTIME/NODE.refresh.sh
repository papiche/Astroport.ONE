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

    ## COPY STATION  yt-dlp.list
    cp $HOME/.zen/.yt-dlp.list ~/.zen/tmp/${IPFSNODEID}/yt-dlp.list 2>/dev/null
    cp $HOME/.zen/.yt-dlp.mp3.list ~/.zen/tmp/${IPFSNODEID}/yt-dlp.mp3.list 2>/dev/null

    ## COPY COINS VALUE OF THE DAY
    rm -Rf ~/.zen/tmp/${IPFSNODEID}/COINS/
    mkdir -p ~/.zen/tmp/${IPFSNODEID}/COINS/
    cp -f ~/.zen/tmp/coucou/*.COINS ~/.zen/tmp/${IPFSNODEID}/COINS/

    ## COPY 20h12.log
    cp -f /tmp/20h12.log ~/.zen/tmp/${IPFSNODEID}/20h12.txt

    ## INFORM NODE GPS LOCATION from CAPTAIN player
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
    RESOLV=$(ipfs name resolve /ipns/${IPFSNODEID})
    ipfs pin rm ${RESOLV}

    NSIZE=$(du -b ~/.zen/tmp/${IPFSNODEID} | tail -n 1 | xargs | cut -d ' ' -f 1)
    ROUTING=$(ipfs add -rwHq ~/.zen/tmp/${IPFSNODEID}/* | tail -n 1 )
    ipfs name publish /ipfs/${ROUTING}
    echo ">> $NSIZE Bytes STATION BALISE > ${myIPFS}/ipns/${IPFSNODEID}"

fi

######################################################
echo "~/.zen/game/nostr/ 3 DAYS OLD LISTING"
find ~/.zen/game/nostr/ -mtime +3 -type d -exec echo '{}' \;
######################################################
## WRITE NOSTR HEX ADDRESS (strfry whitelisting)
##########################################################
echo "############################################"
echo "REFRESH UNODEs HEX"
rm -Rf ~/.zen/game/nostr/UNODE_* ## REMOVE OLD VALUE
## Get swarm NODES HEX
NODEHEXLIST=($(ls -t ~/.zen/tmp/swarm/*/HEX 2>/dev/null))
# Ajouter le HEX de $IPFSNODEID
NODEHEXLIST+=($(ls -t ~/.zen/tmp/$IPFSNODEID/HEX 2>/dev/null))
## Create
for nhex in ${NODEHEXLIST[@]}; do
    hex=$(cat $nhex)
    hexnode=$(echo $nhex | rev | cut -d '/' -f 2 | rev)
    [[ -s  ~/.zen/game/nostr/UNODE_$hexnode/HEX ]] && continue
    echo "NOSTR UNODE $hexnode : HEX = $hex"
    mkdir -p ~/.zen/game/nostr/UNODE_$hexnode
    echo "$hex" > ~/.zen/game/nostr/UNODE_$hexnode/HEX
done
##########################################################
echo "############################################"
echo "REFRESH UMAPs HEX"
rm -Rf ~/.zen/game/nostr/UMAP* ## REMOVE OLD VALUE
# Récupérer la liste des fichiers HEX du swarm
UMAPHEXLIST=($(ls -t ~/.zen/tmp/swarm/*/UPLANET/__/_*_*/_*_*/_*_*/HEX 2>/dev/null))
# Ajouter les fichiers HEX $IPFSNODEID
UMAPHEXLIST+=($(ls -t ~/.zen/tmp/$IPFSNODEID/UPLANET/__/_*_*/_*_*/_*_*/HEX 2>/dev/null))

# Parcourir tous les fichiers HEX dans UMAPHEXLIST
for nhex in ${UMAPHEXLIST[@]}; do
    hex=$(cat $nhex)
    hexumap=$(echo $nhex | rev | cut -d '/' -f 2 | rev)
    [[ -s  ~/.zen/game/nostr/UMAP$hexumap/HEX ]] && continue
    echo "NOSTR UMAP $hexumap : HEX = $hex"
    mkdir -p ~/.zen/game/nostr/UMAP$hexumap
    echo "$hex" > ~/.zen/game/nostr/UMAP$hexumap/HEX
done
##########################################################
echo "############################################"
echo "REFRESH REGIONS HEX"
rm -Rf ~/.zen/game/nostr/REGION* ## REMOVE OLD VALUE
# Récupérer la liste des fichiers HEX du swarm
REGIONHEXLIST=($(ls -t ~/.zen/tmp/swarm/*/UPLANET/REGIONS/_*_*/_*_*/HEX 2>/dev/null))
# Ajouter les fichiers HEX $IPFSNODEID
REGIONHEXLIST+=($(ls -t ~/.zen/tmp/$IPFSNODEID/UPLANET/REGIONS/_*_*/_*_*/HEX 2>/dev/null))

# Parcourir tous les fichiers HEX dans UMAPHEXLIST
for nhex in ${REGIONHEXLIST[@]}; do
    hex=$(cat $nhex)
    hexumap=$(echo $nhex | rev | cut -d '/' -f 2 | rev)
    [[ -s  ~/.zen/game/nostr/REGION$hexumap/HEX ]] && continue
    echo "NOSTR UMAP $hexumap : HEX = $hex"
    mkdir -p ~/.zen/game/nostr/REGION$hexumap
    echo "$hex" > ~/.zen/game/nostr/REGION$hexumap/HEX
done

echo "## CLEANING SWARM 3 DAYS OLD"
find  ~/.zen/tmp/swarm/ -mtime +3 -type d -exec rm -Rf '{}' \;
rm -Rf ~/.zen/tmp/swarm/${IPFSNODEID-null}

if [[ -z $(cat ~/.zen/MJ_APIKEY) ]]; then
    # Mailjet - UPlanet ORIGIN - edit config to change provider
    ipfs --timeout 30s cat /ipfs/QmVy7FKd1MGZqee4b7B5jmBKNgTJBvKKkoDhodnJWy23oN > ~/.zen/MJ_APIKEY
fi


exit 0
