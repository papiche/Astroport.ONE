#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.4
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# NIP-101 related : strfry processing "UPlanet message"
# Search in ~/.zen/game/nostr/UMAP*/HEX to seek for UPlanet GEO Key
# Geo Keys get messages from nostr users and become friend with
# Each day we get all the messages from those friends on each UMAP
# Then Use IA to produce SECTOR journal
################################################################################
# UMAPs individuels → Secteurs géographiques → Régions
MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"

[[ ! -s $MY_PATH/../tools/my.sh ]] && echo "ERROR. Astroport.ONE is missing !!" && exit 1
source $MY_PATH/../tools/my.sh

#########################################################################
#########################################################################
#########################################################################
## TAKES CARE OF ACTIVATED UMAPS
SECTORS=()

## Find all UMAP HEX (Uplanet NOSTR keys)
for hexline in $(ls ~/.zen/game/nostr/UMAP_*_*/HEX);
do
    #### CYCLING UMAPS
    #~ echo $hexline
    hex=$(cat $hexline)
    #~ echo $hex
    LAT=$(echo $hexline | cut -d '_' -f 2)
    LON=$(echo $hexline | cut -d '_' -f 3 | cut -d '/' -f 1)
    ## SECTOR BANK COORD
    SLAT="${LAT::-1}"
    SLON="${LON::-1}"
    ## REGION
    RLAT=$(echo ${LAT} | cut -d '.' -f 1)
    RLON=$(echo ${LON} | cut -d '.' -f 1)
    ## IPFSNODEID output DATA for SWARM
    UMAPPATH="${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}"
    mkdir -p ${UMAPPATH}
    ## RESET NOSTR_messages
    echo "" > ${UMAPPATH}/NOSTR_messages

    SECTORS+=("_${SLAT}_${SLON}")

    ## GET UMAP FRIENDS
    friends=($($MY_PATH/../tools/nostr_get_N1.sh $hex 2>/dev/null))
    echo ${friends[@]}

    ## GET last 24h messages of UMAP friends
    SINCE=$(date -d "24 hours ago" +%s)
    cd ~/.zen/strfry

    for ami in ${friends[@]}; do
        echo "----------------------------- @$ami" >> ${UMAPPATH}/NOSTR_messages
        ## 1. Récupération du profil (kind 0)
        PROFILE=$(./strfry scan '{
          "kinds": [0],
          "authors": ["'"$ami"'"],
          "limit": 1
        }' 2>/dev/null | jq -r 'select(.kind == 0) | .content' | jq -r '[.name, .display_name, .about] | join(" | ")')

        ## 2. Affichage du profil
        if [[ -n "$PROFILE" ]]; then
            echo "👤 $PROFILE" >> ${UMAPPATH}/NOSTR_messages
        else
            # filtrage (sans profil) TODO PROD
            #~ continue
            echo "👤 UNKNOWN VISITOR" >> ${UMAPPATH}/NOSTR_messages
        fi
        echo "---------------------------------"
        #~ echo "📝 Messages :"
        ## 3. Display max 25 messages
        ./strfry scan '{
          "kinds": [1],
          "authors": ["'"$ami"'"],
          "since": '"$SINCE"'
        }' 2>/dev/null | jq -c 'select(.kind == 1) | {id: .id, content: .content}' | jq -r .content | head -n 25 >> ${UMAPPATH}/NOSTR_messages

        echo "$($MY_PATH/../tools/nostr_hex2nprofile.py $ami)" >> ${UMAPPATH}/NOSTR_messages
    done
    echo "---------------------------------"

    cd - 2>&1>/dev/null

    ## CREATE UMAP IDENTITY
    UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
    NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$UMAPNSEC")
    ## SELF FOLLOW
    UMAPNPUB=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}")

    ## Forget Today follows
    nostpy-cli send_event \
        -privkey "$NPRIV_HEX" \
        -kind 3 \
        -content "" \
        -tags "[['p', '$UMAPNPUB']]" \
        --relay "$myRELAY"

done

#########################################################################
#########################################################################
#########################################################################
## TAKES CARE OF ACTIVATED SECTORS
REGIONS=()

UNIQUE_SECTORS=($(echo "${SECTORS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
## PRODUCE SECTOR JOURNAL
for sector in ${UNIQUE_SECTORS[@]}; do
    echo "Creating Sector ${sector} Journal"
    ## Get all messages
    message_text="$(cat ${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/${sector}/*/NOSTR_messages)"
    ################################################## send to IA/question.py
    echo "Generating Ollama answer..."
    ANSWER="$($MY_PATH/../IA/question.py "$message_text --- MAKE A JOURNAL TO PUBLISH ON UPLANET SECTOR ${sector}")"
    #######################################################################
    # Write JOURNAL to SECTOR
    slat=$(echo ${sector} | cut -d '_' -f 2)
    slon=$(echo ${sector} | cut -d '_' -f 3)
    rlat=$(echo ${slat} | cut -d '.' -f 1)
    rlon=$(echo ${slon} | cut -d '.' -f 1)
    REGIONS+=("_${rlat}_${rlon}")

    #################################### Write Journal to IPFSNODEID
    sectorpath="${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/_${rlat}_${rlon}/_${slat}_${slon}"
    mkdir -p $sectorpath
    echo "$ANSWER" > $sectorpath/NOSTR_journal
    ## LOG ..............
    cat $sectorpath/NOSTR_journal
done

#########################################################################
#########################################################################
#########################################################################
## TAKES CARE OF ACTIVATED REGIONS

UNIQUE_REGIONS=($(echo "${REGIONS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
for region in ${UNIQUE_REGIONS[@]}; do
    echo "Creating Region ${region} Journal"
    message_text=$(cat ${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/${region}/*/NOSTR_journal)
    ################################################## send to IA/question.py
    echo "Generating Ollama answer..."
    ANSWER="$($MY_PATH/../IA/question.py "$message_text --- MAKE A JOURNAL TO PUBLISH ON UPLANET REGION ${region}")"
    #######################################################################
    regionpath="${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/REGIONS/${region}"
    echo "$ANSWER" > $regionpath/NOSTR_journal
    ## LOG ..............
    cat $regionpath/NOSTR_journal
done

exit 0
