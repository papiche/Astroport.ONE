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

echo '
o               ²        ___---___                    ²
       ²              ²--\        --²     ²     ²         ²
                    ²/²;_²\     __/~ \²
                   /;  / `-²  __\    ² \
 ²        ²       / ,--²     / ²   ²;   \        |
                 | ²|       /       __   |      -O-       ²
                |__/    __ |  ² ;   \ | ² |      |
                |      /  \\_    ² ;| \___|
   ²    o       |      \  ²~\\___,--²     |           ²
                 |     | ² ; ~~~~\_    __|
    |             \    \   ²  ²  ; \  /_/   ²
   -O-        ²    \   /         ² |  ~/                  ²
    |    ²          ~\ \   ²      /  /~          o
  ²                   ~--___ ; ___--~
                 ²          ---         ²
'
#########################################################################
#########################################################################
#########################################################################
## TAKES CARE OF ACTIVATED UMAPS
SECTORS=()
STAGS=() ## contains SECTOR friends

## Find all UMAP HEX (Uplanet NOSTR keys)
for hexline in $(ls ~/.zen/game/nostr/UMAP_*_*/HEX);
do
    #### CYCLING UMAPS
    echo $hexline
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
    ## To get conf file auto detected
    cd ~/.zen/strfry

    TAGS=() ## contains UMAP friends
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
            echo "👤 $PROFILE @$ami" >> ${UMAPPATH}/NOSTR_messages
            TAGS+=("[\"p\", \"$ami\", \"$myRELAY\", \"Ufriend\"]")
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

        ## DOES NOT WORK
        #~ echo "$($MY_PATH/../tools/nostr_hex2nprofile.py $ami)" >> ${UMAPPATH}/NOSTR_messages
    done
    echo "---------------------------------"

    cd - 2>&1>/dev/null

    cat ${UMAPPATH}/NOSTR_messages

    ## GET ENV VARIABLES
    $(${MY_PATH}/../tools/getUMAP_ENV.sh "${LAT}" "${LON}" | tail -n 1)

    STAGS+=("[\"p\", \"$SECTORHEX\", \"$myRELAY\", \"$SECTOR\"]")

    ## CREATE UMAP IDENTITY
    UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
    NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$UMAPNSEC")
    ## SELF FOLLOW
    UMAPNPUB=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}")

    ## Create JSON array of tags
    TAGS_JSON=$(printf '%s\n' "${TAGS[@]}" | jq -c . | tr '\n' ',' | sed 's/,$//')
    TAGS_JSON="[$TAGS_JSON]"

    ## RESET EVERY DAY FOLLOW LIST TO ONLY REGISTRED USER
    ## UMAP auto Follow UPlanet NOSTR Cards (kind 3)
    nostpy-cli send_event \
        -privkey "$NPRIV_HEX" \
        -kind 3 \
        -content "" \
        -tags "$TAGS_JSON" \
        --relay "$myRELAY"

    ## SEND MESSAGE kind 1
    if [[ $(cat ${UMAPPATH}/NOSTR_messages) != "" ]]; then
    nostpy-cli send_event \
      -privkey "$NPRIV_HEX" \
      -kind 1 \
      -content "$(cat ${UMAPPATH}/NOSTR_messages) $uSPOT/scan" \
      --relay "$myRELAY"
    fi
done

#########################################################################
#########################################################################
echo "___________________________________"
## Seek for NOSTR Card in SWARM Memory
for umap in $(ls ~/.zen/tmp/swarm/*/TW/*@*.*/HEX); do
    echo "NOSTR Card : ZUMAP $umap : $(cat $umap)"
done
echo "___________________________________"
#########################################################################
#########################################################################
#########################################################################
## TAKES CARE OF ACTIVATED sector
REGIONS=()
RTAGS=() ## contains REGION friends

UNIQUE_SECTORS=($(echo "${SECTORS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
## PRODUCE SECTOR JOURNAL
for sector in ${UNIQUE_SECTORS[@]}; do
    echo "Creating Sector ${sector} Journal"
    ## Get all messages
    message_text="$(cat ${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/${sector}/*/NOSTR_messages)"
    if [[ -z "$message_text" ]]; then
        echo "No messages found for sector ${sector}"
        continue
    fi
    ################################################## send to IA/question.py
    echo "Generating Ollama answer..."
    QUESTION="[TEXT] $message_text [/TEXT] --- # 1. Write a summary of [TEXT] # 2. Highlight key points with their authors # 3. Add hastags and emoticons # IMPORTANT : Use the same language as mostly used in [TEXT]."
    ANSWER="$($MY_PATH/../IA/question.py "${QUESTION}")"
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

    ##### IPFS DRIVE UPDATE
    SECROOT=$(ipfs add -rwHq $sectorpath/* | tail -n 1)
    ##################################
    ## SECROOT : ipfs link rolling calendar
    echo "${SECROOT}" > ${sectorpath}/ipfs.${DEMAINDATE} 2>/dev/null
    rm ${sectorpath}/ipfs.${YESTERDATE} 2>/dev/null
    ################################################################
    ## UPDATE REGION NOSTR PROFILE
    $(${MY_PATH}/../tools/getUMAP_ENV.sh "${slat}0" "${slon}0" | tail -n 1) ## GET ENV VARIABLES
    RTAGS+=("[\"p\", \"$REGIONHEX\", \"$myRELAY\", \"$REGION\"]")

    SECTORNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${SECTOR}" "${UPLANETNAME}${SECTOR}" -s)
    ${MY_PATH}/../tools/nostr_setup_profile.py \
    "$SECTORNSEC" \
    "SECTOR_${UPLANETG1PUB:0:8}${sector}" "${SECTORG1PUB}" \
    "UPlanet ${TODATE}${sector} -- VISIO ROOM : $myIPFS$VDONINJA/?room=${SECTORG1PUB:0:8}&effects&record" \
    "${myIPFS}/ipfs/Qmeezy8CtoXzz9LqA8mWqzYDweEYMqAvjZ1JyZFDW7pLQC/LivingTV.gif" \
    "${myIPFS}/ipfs/QmQAjxPE5UZWW4aQWcmsXgzpcFvfk75R1sSo2GuEgQ3Byu" \
    "" "${myIPFS}/ipfs/${SECROOT}" "" "$myIPFS$VDONINJA/?room=${SECTORG1PUB:0:8}&effects&record" "" "" \
    "$myRELAY" "wss://relay.copylaradio.com"
    ################################################################
    # https://ipfs.copylaradio.com/ipfs/QmRq6LusiEG49BA3nsUTQvBmQxUQnY3tjqNM4M66rbBEt7/?room=UPLANET&effects&record
    ################################################################
    ## FRIEND ZONE
    ## CREATE SECTOR IDENTITY
    NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$SECTORNSEC")

    ## Create JSON array of stags
    TAGS_JSON=$(printf '%s\n' "${STAGS[@]}" | jq -c . | tr '\n' ',' | sed 's/,$//')
    TAGS_JSON="[$TAGS_JSON]"

    ## UMAP auto Follow UPlanet NOSTR Cards
    nostpy-cli send_event \
        -privkey "$NPRIV_HEX" \
        -kind 3 \
        -content "" \
        -tags "$TAGS_JSON" \
        --relay "$myRELAY"
    ################################################################
    ## SEND MESSAGE kind 1
    if [[ -s $sectorpath/NOSTR_journal ]]; then
        nostpy-cli send_event \
          -privkey "$NPRIV_HEX" \
          -kind 1 \
          -content "$(cat $sectorpath/NOSTR_journal) $uSPOT/scan" \
          --relay "$myRELAY"
    fi
done

#########################################################################
#########################################################################
#########################################################################
## TAKES CARE OF ACTIVATED REGIONS
UNIQUE_REGIONS=($(echo "${REGIONS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
for region in ${UNIQUE_REGIONS[@]}; do
    rlat=$(echo ${region} | cut -d '_' -f 2)
    rlon=$(echo ${region} | cut -d '_' -f 3)
    echo "Creating Region ${region} Journal"
    message_text=$(cat ${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/${region}/*/NOSTR_journal)
    if [[ -z "$message_text" ]]; then
        echo "No messages found for region ${region}"
        continue
    fi
    ################################################## send to IA/question.py
    echo "Generating Ollama answer..."
    QUESTION="[TEXT] $message_text [/TEXT]--- # 1. Write a summary of [TEXT] # 2. Highlight key points with their authors # 3. Add hastags and emoticons # IMPORTANT : Use the same language as mostly used in [TEXT]."
    ANSWER="$($MY_PATH/../IA/question.py "${QUESTION}")"
    #######################################################################
    regionpath="${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/REGIONS/${region}"
    mkdir -p $regionpath
    echo "$ANSWER" > $regionpath/NOSTR_journal
    ## LOG ..............
    cat $regionpath/NOSTR_journal

    ##### IPFS DRIVE UPDATE
    REGROOT=$(ipfs add -rwHq $regionpath/* | tail -n 1)
    ##################################
    ## REGROOT : ipfs link rolling calendar
    echo "${REGROOT}" > ${regionpath}/ipfs.${DEMAINDATE} 2>/dev/null
    rm ${regionpath}/ipfs.${YESTERDATE} 2>/dev/null

    ## UPDATE REGION NOSTR PROFILE
    $(${MY_PATH}/../tools/getUMAP_ENV.sh "${rlat}.00" "${rlon}.00" | tail -n 1) ## GET ENV VARIABLES
    REGSEC=$(${MY_PATH}/../tools/keygen -t nostr "${UPLANETNAME}${region}" "${UPLANETNAME}${region}" -s)
    ${MY_PATH}/../tools/nostr_setup_profile.py \
    "$REGSEC" \
    "REGION_${UPLANETG1PUB:0:8}${region}" "${REGIONG1PUB}" \
    "UPlanet ${TODATE}${sector} -- VISIO ROOM : $myIPFS$VDONINJA/?room=${REGIONG1PUB:0:8}&effects&record" \
    "${myIPFS}/ipfs/QmRsRTZuVwL6UsjLGooVMFFTbNfeswfCaRmJHTBmk2XiqU/internet.png" \
    "${myIPFS}/ipfs/QmQAjxPE5UZWW4aQWcmsXgzpcFvfk75R1sSo2GuEgQ3Byu" \
    "" "${myIPFS}/ipfs/${REGROOT}" "" "$myIPFS$VDONINJA/?room=${REGIONG1PUB:0:8}&effects&record" "" "" \
    "$myRELAY" "wss://relay.copylaradio.com"
    ################################################/ipfs/Qmewe23bfnY8iXo6iNmD72muRipmkFCknpcE3kYcj2TkLQ/rec.png
    ################################################/ipfs/Qmeezy8CtoXzz9LqA8mWqzYDweEYMqAvjZ1JyZFDW7pLQC/LivingTV.gif
    ################################################/ipfs/QmPLxcKtjx4avibH4NiyjjBr2CPhfM3WokGy4Lwh9tBGRZ/carreblanc.png
    ## FRIEND ZONE
    ## CREATE REGION IDENTITY
    NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$REGSEC")

    ## Create JSON array of stags
    TAGS_JSON=$(printf '%s\n' "${RTAGS[@]}" | jq -c . | tr '\n' ',' | sed 's/,$//')
    TAGS_JSON="[$TAGS_JSON]"

    ## UMAP auto Follow UPlanet NOSTR Cards
    nostpy-cli send_event \
        -privkey "$NPRIV_HEX" \
        -kind 3 \
        -content "" \
        -tags "$TAGS_JSON" \
        --relay "$myRELAY"
    ################################################################
    ## SEND MESSAGE kind 1
    if [[ -s $regionpath/NOSTR_journal ]]; then
        nostpy-cli send_event \
          -privkey "$NPRIV_HEX" \
          -kind 1 \
          -content "$(cat $regionpath/NOSTR_journal) $uSPOT/scan" \
          --relay "$myRELAY"
    fi
done

exit 0
