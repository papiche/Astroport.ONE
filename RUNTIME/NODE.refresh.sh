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
start=$(date +%s)
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
echo "## CLEANING DEACTIVATED PROFILES & OLD UMAP MESSAGES (NIP-40)"
${MY_PATH}/../tools/nostr_cleanup_deactivated.sh --force 2>/dev/null || true
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

    ## NOTE: UPLANET cache cleanup (UMAP/SECTOR/REGION) is now handled by
    ## NOSTR.UMAP.refresh.sh using is_closest_station() for intelligent
    ## geographic responsibility distribution

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
if [[ ! -s ~/.zen/game/secret.NODE.dunikey && -s ~/.ssh/id_ed25519 ]]; then
    echo "Generating default X level node Duniter key..."
    SSHASH=$(cat ~/.ssh/id_ed25519 | sha512sum | cut -d ' ' -f 1)
    SECRET1=$(echo "$SSHASH" | cut -c 1-64)
    SECRET2=$(echo "$SSHASH" | cut -c 65-128)
    ~/.zen/Astroport.ONE/tools/keygen -t duniter -o ~/.zen/game/secret.NODE.dunikey "$SECRET1" "$SECRET2"
    chmod 600 ~/.zen/game/secret.NODE.dunikey
fi

######################################################
#echo "~/.zen/game/nostr/ 3 DAYS OLD LISTING"
# find ~/.zen/game/nostr/ -mtime +3 -type d -exec echo '{}' \;
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
#################################################### strfry authorized keys
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
SECTORHEXLIST=($(ls -t ~/.zen/tmp/swarm/*/UPLANET/SECTORS/_*_*/_*_*/SECTORHEX 2>/dev/null))
# Ajouter les fichiers HEX $IPFSNODEID
SECTORHEXLIST+=($(ls -t ~/.zen/tmp/$IPFSNODEID/UPLANET/SECTORS/_*_*/_*_*/SECTORHEX 2>/dev/null))

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
REGIONHEXLIST=($(ls -t ~/.zen/tmp/swarm/*/UPLANET/REGIONS/_*_*/REGIONHEX 2>/dev/null))
# Ajouter les fichiers HEX $IPFSNODEID
REGIONHEXLIST+=($(ls -t ~/.zen/tmp/$IPFSNODEID/UPLANET/REGIONS/_*_*/REGIONHEX 2>/dev/null))

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
## ADD UMAP, SECTOR, REGION, UPLANET HEX to amisOfAmis.txt
## Required for strfry constellation sync (N² Memory)
## IMPORTANT: Only add LOCAL keys (managed by this node), not swarm keys
## This follows the same filtering as NOSTR.UMAP.refresh.sh
########################################################
echo "############################################"
echo "ADDING LOCAL GEOGRAPHIC KEYS TO amisOfAmis.txt"

# Initialize amisOfAmis.txt if it doesn't exist
touch "${HOME}/.zen/strfry/amisOfAmis.txt"

# Add uplanet.G1.nostr HEX (Central Oracle key)
if [[ -f "$HOME/.zen/game/uplanet.G1.nostr" ]]; then
    UPLANET_G1_HEX=$(grep "HEX=" "$HOME/.zen/game/uplanet.G1.nostr" 2>/dev/null | cut -d'=' -f2 | tr -d ';' | tr -d ' ')
    if [[ -n "$UPLANET_G1_HEX" && ${#UPLANET_G1_HEX} -eq 64 ]]; then
        if ! grep -qi "^${UPLANET_G1_HEX}$" "${HOME}/.zen/strfry/amisOfAmis.txt" 2>/dev/null; then
            echo "$UPLANET_G1_HEX" >> "${HOME}/.zen/strfry/amisOfAmis.txt"
            echo "Added uplanet.G1.nostr HEX: ${UPLANET_G1_HEX:0:16}..."
        fi
    fi
fi

# Add LOCAL UMAP HEX keys only (from this node's IPFSNODEID, not swarm)
# These are the UMAPs that NOSTR.UMAP.refresh.sh will actually process
UMAP_COUNT=0
for hexfile in ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/_*_*/_*_*/HEX; do
    [[ -f "$hexfile" ]] || continue
    hex=$(cat "$hexfile" 2>/dev/null | tr -d '[:space:]')
    if [[ -n "$hex" && ${#hex} -eq 64 && "$hex" =~ ^[0-9a-fA-F]{64}$ ]]; then
        if ! grep -qi "^${hex}$" "${HOME}/.zen/strfry/amisOfAmis.txt" 2>/dev/null; then
            echo "$hex" >> "${HOME}/.zen/strfry/amisOfAmis.txt"
            ((UMAP_COUNT++))
        fi
    fi
done
echo "Added $UMAP_COUNT LOCAL UMAP HEX keys to amisOfAmis.txt"

# Add LOCAL SECTOR HEX keys only (from this node's IPFSNODEID)
SECTOR_COUNT=0
for hexfile in ~/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/_*_*/_*_*/SECTORHEX; do
    [[ -f "$hexfile" ]] || continue
    hex=$(cat "$hexfile" 2>/dev/null | tr -d '[:space:]')
    if [[ -n "$hex" && ${#hex} -eq 64 && "$hex" =~ ^[0-9a-fA-F]{64}$ ]]; then
        if ! grep -qi "^${hex}$" "${HOME}/.zen/strfry/amisOfAmis.txt" 2>/dev/null; then
            echo "$hex" >> "${HOME}/.zen/strfry/amisOfAmis.txt"
            ((SECTOR_COUNT++))
        fi
    fi
done
echo "Added $SECTOR_COUNT LOCAL SECTOR HEX keys to amisOfAmis.txt"

# Add LOCAL REGION HEX keys only (from this node's IPFSNODEID)
REGION_COUNT=0
for hexfile in ~/.zen/tmp/${IPFSNODEID}/UPLANET/REGIONS/_*_*/REGIONHEX; do
    [[ -f "$hexfile" ]] || continue
    hex=$(cat "$hexfile" 2>/dev/null | tr -d '[:space:]')
    if [[ -n "$hex" && ${#hex} -eq 64 && "$hex" =~ ^[0-9a-fA-F]{64}$ ]]; then
        if ! grep -qi "^${hex}$" "${HOME}/.zen/strfry/amisOfAmis.txt" 2>/dev/null; then
            echo "$hex" >> "${HOME}/.zen/strfry/amisOfAmis.txt"
            ((REGION_COUNT++))
        fi
    fi
done
echo "Added $REGION_COUNT LOCAL REGION HEX keys to amisOfAmis.txt"

# Add UNODE HEX keys (other constellation nodes - these are always added for swarm sync)
UNODE_COUNT=0
for hexfile in ~/.zen/game/nostr/UNODE_*/HEX; do
    [[ -f "$hexfile" ]] || continue
    hex=$(cat "$hexfile" 2>/dev/null | tr -d '[:space:]')
    if [[ -n "$hex" && ${#hex} -eq 64 && "$hex" =~ ^[0-9a-fA-F]{64}$ ]]; then
        if ! grep -qi "^${hex}$" "${HOME}/.zen/strfry/amisOfAmis.txt" 2>/dev/null; then
            echo "$hex" >> "${HOME}/.zen/strfry/amisOfAmis.txt"
            ((UNODE_COUNT++))
        fi
    fi
done
echo "Added $UNODE_COUNT UNODE HEX keys to amisOfAmis.txt"

# Add SWARM SECTOR HEX keys (geographic sectors from all swarm nodes)
# Required for N² constellation sync across sectors
SWARM_SECTOR_COUNT=0
for hexfile in ~/.zen/game/nostr/SECTOR_*/HEX; do
    [[ -f "$hexfile" ]] || continue
    hex=$(cat "$hexfile" 2>/dev/null | tr -d '[:space:]')
    if [[ -n "$hex" && ${#hex} -eq 64 && "$hex" =~ ^[0-9a-fA-F]{64}$ ]]; then
        if ! grep -qi "^${hex}$" "${HOME}/.zen/strfry/amisOfAmis.txt" 2>/dev/null; then
            echo "$hex" >> "${HOME}/.zen/strfry/amisOfAmis.txt"
            ((SWARM_SECTOR_COUNT++))
        fi
    fi
done
echo "Added $SWARM_SECTOR_COUNT SWARM SECTOR HEX keys to amisOfAmis.txt"

# Add SWARM REGION HEX keys (geographic regions from all swarm nodes)
# Required for N² constellation sync across regions
SWARM_REGION_COUNT=0
for hexfile in ~/.zen/game/nostr/REGION_*/HEX; do
    [[ -f "$hexfile" ]] || continue
    hex=$(cat "$hexfile" 2>/dev/null | tr -d '[:space:]')
    if [[ -n "$hex" && ${#hex} -eq 64 && "$hex" =~ ^[0-9a-fA-F]{64}$ ]]; then
        if ! grep -qi "^${hex}$" "${HOME}/.zen/strfry/amisOfAmis.txt" 2>/dev/null; then
            echo "$hex" >> "${HOME}/.zen/strfry/amisOfAmis.txt"
            ((SWARM_REGION_COUNT++))
        fi
    fi
done
echo "Added $SWARM_REGION_COUNT SWARM REGION HEX keys to amisOfAmis.txt"

# Add SWARM UMAP HEX keys (all UMAPs from swarm nodes)
# Required for Collaborative Commons System (kind 30023 documents)
# See docs/COLLABORATIVE_COMMONS_SYSTEM.md - documents need UMAP pubkeys synced
SWARM_UMAP_COUNT=0
for hexfile in ~/.zen/game/nostr/UMAP_*/HEX; do
    [[ -f "$hexfile" ]] || continue
    hex=$(cat "$hexfile" 2>/dev/null | tr -d '[:space:]')
    if [[ -n "$hex" && ${#hex} -eq 64 && "$hex" =~ ^[0-9a-fA-F]{64}$ ]]; then
        if ! grep -qi "^${hex}$" "${HOME}/.zen/strfry/amisOfAmis.txt" 2>/dev/null; then
            echo "$hex" >> "${HOME}/.zen/strfry/amisOfAmis.txt"
            ((SWARM_UMAP_COUNT++))
        fi
    fi
done
echo "Added $SWARM_UMAP_COUNT SWARM UMAP HEX keys to amisOfAmis.txt (Collaborative Commons)"

# Remove duplicates and sort
sort -u "${HOME}/.zen/strfry/amisOfAmis.txt" -o "${HOME}/.zen/strfry/amisOfAmis.txt"
echo "Total amisOfAmis.txt entries after geographic sync: $(wc -l < ${HOME}/.zen/strfry/amisOfAmis.txt)"

echo "COPYing blacklist.txt $(cat $HOME/.zen/strfry/blacklist.txt | wc -l) + amisOfAmis.txt $(cat $HOME/.zen/strfry/amisOfAmis.txt | wc -l)"
cp -f "$HOME/.zen/strfry/blacklist.txt" ~/.zen/tmp/$IPFSNODEID/
cp -f "${HOME}/.zen/strfry/amisOfAmis.txt" ~/.zen/tmp/$IPFSNODEID/

# Merge swarm blacklist and amisOfAmis with local files
echo "Merging swarm blacklist and amisOfAmis files..."
cat ~/.zen/tmp/swarm/*/blacklist.txt 2>/dev/null | sort -u >> "$HOME/.zen/strfry/blacklist.txt"

# Clean amisOfAmis.txt: filter out log lines and keep only valid 64-char hex pubkeys
cat ~/.zen/tmp/swarm/*/amisOfAmis.txt 2>/dev/null | while IFS= read -r line; do
    # Remove whitespace for validation
    clean_line=$(echo "$line" | tr -d '[:space:]')
    # Only keep lines that are exactly 64 hex characters and don't contain log markers
    if [[ -n "$clean_line" && ${#clean_line} -eq 64 && "$clean_line" =~ ^[0-9a-fA-F]{64}$ && ! "$line" =~ \[|INFO|DEBUG|WARN|ERROR|Connected|Sent|Received|Found|Pong|Average|WebSocket|Local|PING|STRFRY ]]; then
        echo "$clean_line"
    fi
done | sort -u >> "${HOME}/.zen/strfry/amisOfAmis.txt"

# Remove duplicates from merged files
sort -u "$HOME/.zen/strfry/blacklist.txt" -o "$HOME/.zen/strfry/blacklist.txt"
sort -u "${HOME}/.zen/strfry/amisOfAmis.txt" -o "${HOME}/.zen/strfry/amisOfAmis.txt"

echo "Cleaned amisOfAmis.txt: removed invalid entries (logs, non-hex lines)"

echo "Updated blacklist.txt: $(cat $HOME/.zen/strfry/blacklist.txt | wc -l) entries"
echo "Updated amisOfAmis.txt: $(cat $HOME/.zen/strfry/amisOfAmis.txt | wc -l) entries"

########################################################
if [[ -z $(cat ~/.zen/MJ_APIKEY) ]]; then
    # Mailjet - UPlanet ORIGIN - edit config to change provider
    ipfs --timeout 30s cat /ipfs/QmVy7FKd1MGZqee4b7B5jmBKNgTJBvKKkoDhodnJWy23oN > ~/.zen/MJ_APIKEY
fi

########################################################
## Refresh Ustats.json
curl -s http://localhost:54321 > /dev/null
########################################################
stop=$(date +%s)
echo "## NODE.refresh.sh DONE in $((stop - start)) seconds"

exit 0
