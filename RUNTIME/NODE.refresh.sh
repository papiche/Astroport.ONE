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
echo "
 _   _  ___  ____  _____             __               _     
| \ | |/ _ \|  _ \| ____|  _ __ ___ / _|_ __ ___  ___| |__  
|  \| | | | | | | |  _|   | '__/ _ \ |_| '__/ _ \/ __| '_ \ 
| |\  | |_| | |_| | |___  | | |  __/  _| | |  __/\__ \ | | |
|_| \_|\___/|____/|_____| |_|  \___|_| |_|  \___||___/_| |_|
"
echo "## RUNNING NODE.refresh"
[[ ${IPFSNODEID} == "" ]] && echo "IPFSNODEID is empty - EXIT -" && exit 1

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

########################################################
echo "## CLEANING NOSTR & NODE SWARM > 3 DAYS OLD"
find ~/.zen/game/nostr/UMAP* -mtime +3 -type d -exec rm -Rf '{}' \;
find ~/.zen/game/nostr/SECTOR* -mtime +3 -type d -exec rm -Rf '{}' \;
find ~/.zen/game/nostr/REGION* -mtime +3 -type d -exec rm -Rf '{}' \;
find  ~/.zen/tmp/swarm/ -mtime +3 -type d -exec rm -Rf '{}' \;
rm -Rf ~/.zen/tmp/swarm/${IPFSNODEID-null}
########################################################
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

########################################################
if [[ ! -s ~/.zen/game/secret.dunikey && -s ~/.ssh/id_ed25519 ]]; then
    echo "Generating default X level node Duniter key..."
    SSHASH=$(cat ~/.ssh/id_ed25519 | sha512sum | cut -d ' ' -f 1)
    SECRET1=$(echo "$SSHASH" | cut -c 1-64)
    SECRET2=$(echo "$SSHASH" | cut -c 65-128)
    ~/.zen/Astroport.ONE/tools/keygen -t duniter -o ~/.zen/game/secret.dunikey "$SECRET1" "$SECRET2"
    chmod 600 ~/.zen/game/secret.dunikey
fi

######################################################
echo "~/.zen/game/nostr/ 3 DAYS OLD LISTING"
find ~/.zen/game/nostr/ -mtime +3 -type d -exec echo '{}' \;
######################################################
## WRITE NOSTR HEX ADDRESS (strfry whitelisting)
##########################################################
echo "############################################"
echo "REFRESH UNODEs HEX"
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

# Table associative HEX -> dossier UMAP (bash 4+)
declare -A HEX_TO_UMAP

for nhex in ${UMAPHEXLIST[@]}; do
    hex=$(cat "$nhex")
    hexumap=$(echo $nhex | rev | cut -d '/' -f 2 | rev)
    # Si ce HEX n'a pas encore été vu, on l'associe à ce nom de dossier
    if [[ -z "${HEX_TO_UMAP[$hex]}" ]]; then
        HEX_TO_UMAP[$hex]="$hexumap"
    fi
    # Sinon, on ignore (on garde le premier nom de dossier rencontré)
done

for hex in "${!HEX_TO_UMAP[@]}"; do
    hexumap="${HEX_TO_UMAP[$hex]}"
    echo "NOSTR UMAP $hexumap : HEX = $hex"
    mkdir -p ~/.zen/game/nostr/UMAP$hexumap
    echo "$hex" > ~/.zen/game/nostr/UMAP$hexumap/HEX
done
##########################################################
echo "############################################"
echo "REFRESH SECTORS HEX"
rm -Rf ~/.zen/game/nostr/SECTOR* ## REMOVE OLD VALUE
# Récupérer la liste des fichiers HEX du swarm
SECTORHEXLIST=($(ls -t ~/.zen/tmp/swarm/*/UPLANET/SECTORS/_*_*/_*_*/HEX 2>/dev/null))
# Ajouter les fichiers HEX $IPFSNODEID
SECTORHEXLIST+=($(ls -t ~/.zen/tmp/$IPFSNODEID/UPLANET/SECTORS/_*_*/_*_*/HEX 2>/dev/null))

# Parcourir tous les fichiers HEX dans UMAPHEXLIST
for nhex in ${SECTORHEXLIST[@]}; do
    hex=$(cat $nhex)
    hexsector=$(echo $nhex | rev | cut -d '/' -f 2 | rev)
    [[ -s  ~/.zen/game/nostr/SECTOR$hexsector/HEX ]] && continue
    echo "NOSTR SECTOR $hexsector : HEX = $hex"
    mkdir -p ~/.zen/game/nostr/SECTOR$hexsector
    echo "$hex" > ~/.zen/game/nostr/SECTOR$hexsector/HEX
done
##########################################################
echo "############################################"
echo "REFRESH REGIONS HEX"
rm -Rf ~/.zen/game/nostr/REGION* ## REMOVE OLD VALUE
# Récupérer la liste des fichiers HEX du swarm
REGIONHEXLIST=($(ls -t ~/.zen/tmp/swarm/*/UPLANET/REGIONS/_*_*/HEX 2>/dev/null))
# Ajouter les fichiers HEX $IPFSNODEID
REGIONHEXLIST+=($(ls -t ~/.zen/tmp/$IPFSNODEID/UPLANET/REGIONS/_*_*/HEX 2>/dev/null))

# Parcourir tous les fichiers HEX dans UMAPHEXLIST
for nhex in ${REGIONHEXLIST[@]}; do
    hex=$(cat $nhex)
    hexumap=$(echo $nhex | rev | cut -d '/' -f 2 | rev)
    [[ -s  ~/.zen/game/nostr/REGION$hexumap/HEX ]] && continue
    echo "NOSTR UMAP $hexumap : HEX = $hex"
    mkdir -p ~/.zen/game/nostr/REGION$hexumap
    echo "$hex" > ~/.zen/game/nostr/REGION$hexumap/HEX
done


########################################################
if [[ -z $(cat ~/.zen/MJ_APIKEY) ]]; then
    # Mailjet - UPlanet ORIGIN - edit config to change provider
    ipfs --timeout 30s cat /ipfs/QmVy7FKd1MGZqee4b7B5jmBKNgTJBvKKkoDhodnJWy23oN > ~/.zen/MJ_APIKEY
fi

########################################################
## Refresh Ustats.json
curl -s http://localhost:54321 > /dev/null
########################################################

exit 0
