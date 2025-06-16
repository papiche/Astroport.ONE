#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.5
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# NIP-101 related : strfry processing "UPlanet message"
# Search in ~/.zen/game/nostr/UMAP*/HEX to seek for UPlanet GEO Key
# Geo Keys get messages from nostr users and become friend with
# Each day we get all the messages from those friends on each UMAP
# Then Use IA to produce SECTOR journal and REGION journal
################################################################################

# Global variables
MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"
SECTORS=()
STAGS=()
REGIONS=()
RTAGS=()

################################################################################
# Utility Functions
################################################################################

check_dependencies() {
    [[ ! -s $MY_PATH/../tools/my.sh ]] && echo "ERROR. Astroport.ONE is missing !!" && exit 1
    source $MY_PATH/../tools/my.sh
}

display_banner() {
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
}

################################################################################
# UMAP Management Functions
################################################################################

process_umap_messages() {
    local hexline=$1
    local hex=$(cat $hexline)
    local LAT=$(makecoord $(echo $hexline | cut -d '_' -f 2))
    local LON=$(makecoord $(echo $hexline | cut -d '_' -f 3 | cut -d '/' -f 1))
    local SLAT="${LAT::-1}"
    local SLON="${LON::-1}"
    local RLAT=$(echo ${LAT} | cut -d '.' -f 1)
    local RLON=$(echo ${LON} | cut -d '.' -f 1)
    
    local UMAPPATH="${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}"
    mkdir -p ${UMAPPATH}
    echo "" > ${UMAPPATH}/NOSTR_messages

    SECTORS+=("_${SLAT}_${SLON}")
    
    process_umap_friends "$hex" "$UMAPPATH" "$LAT" "$LON"
    setup_umap_identity "$LAT" "$LON" "$UMAPPATH"
}

process_umap_friends() {
    local hex=$1
    local UMAPPATH=$2
    local LAT=$3
    local LON=$4
    
    local friends=($($MY_PATH/../tools/nostr_get_N1.sh $hex 2>/dev/null))
    local SINCE=$(date -d "24 hours ago" +%s)
    local WEEK_AGO=$(date -d "7 days ago" +%s)
    local MONTH_AGO=$(date -d "28 days ago" +%s)
    
    cd ~/.zen/strfry
    
    local TAGS=()
    local ACTIVE_FRIENDS=()
    
    for ami in ${friends[@]}; do
        process_friend_messages "$ami" "$UMAPPATH" "$LAT" "$LON" "$SINCE" "$WEEK_AGO" "$MONTH_AGO"
    done
    
    update_friends_list "${ACTIVE_FRIENDS[@]}"
    setup_ipfs_structure "$UMAPPATH"
}

process_friend_messages() {
    local ami=$1
    local UMAPPATH=$2
    local LAT=$3
    local LON=$4
    local SINCE=$5
    local WEEK_AGO=$6
    local MONTH_AGO=$7
    
    echo "----------------------------- @$ami" >> ${UMAPPATH}/NOSTR_messages
    
    local PROFILE=$(./strfry scan '{
      "kinds": [0],
      "authors": ["'"$ami"'"],
      "limit": 1
    }' 2>/dev/null | jq -r 'select(.kind == 0) | .content' | jq -r '[.name, .display_name, .about] | join(" | ")')
    
    if [[ -n "$PROFILE" ]]; then
        handle_active_friend "$ami" "$UMAPPATH" "$WEEK_AGO" "$MONTH_AGO"
    else
        echo "👤 UNKNOWN VISITOR" >> ${UMAPPATH}/NOSTR_messages
    fi
    
    process_recent_messages "$ami" "$UMAPPATH" "$LAT" "$LON" "$SINCE"
}

handle_active_friend() {
    local ami=$1
    local UMAPPATH=$2
    local WEEK_AGO=$3
    local MONTH_AGO=$4
    
    local profile=$($MY_PATH/../tools/nostr_hex2nprofile.py $ami 2>/dev/null)
    echo "👤 $profile nostr:$profile" >> ${UMAPPATH}/NOSTR_messages
    
    local RECENT_ACTIVITY=$(./strfry scan '{
      "kinds": [1],
      "authors": ["'"$ami"'"],
      "since": '"$MONTH_AGO"',
      "limit": 1
    }' 2>/dev/null | jq -r 'select(.kind == 1) | .created_at')

    if [[ -z "$RECENT_ACTIVITY" ]]; then
        handle_inactive_friend "$ami" "$profile"
    else
        handle_active_friend_activity "$ami" "$profile" "$WEEK_AGO"
    fi
}

handle_inactive_friend() {
    local ami=$1
    local profile=$2
    
    echo "🚫 Removing inactive friend: $profile (no activity in 4 weeks)" >> ${UMAPPATH}/NOSTR_messages
    local GOODBYE_MSG="👋 It seems you've been inactive for a while. I'll remove you from my friends list, but you're welcome to reconnect anytime! #UPlanet #Community"
    nostpy-cli send_event \
        -privkey "$NPRIV_HEX" \
        -kind 1 \
        -content "$GOODBYE_MSG" \
        -tags "[['p', '$ami']]" \
        --relay "$myRELAY"
}

handle_active_friend_activity() {
    local ami=$1
    local profile=$2
    local WEEK_AGO=$3
    
    ACTIVE_FRIENDS+=("$ami")
    TAGS+=("[\"p\", \"$ami\", \"$myRELAY\", \"Ufriend\"]")
    
    local WEEK_ACTIVITY=$(./strfry scan '{
      "kinds": [1],
      "authors": ["'"$ami"'"],
      "since": '"$WEEK_AGO"',
      "limit": 1
    }' 2>/dev/null | jq -r 'select(.kind == 1) | .created_at')

    if [[ -z "$WEEK_ACTIVITY" ]]; then
        send_reminder_message "$ami" "$profile"
    fi
}

send_reminder_message() {
    local ami=$1
    local profile=$2
    
    local REMINDER_MSG="👋 Hey! Haven't seen you around lately. How are you doing? Feel free to share your thoughts or updates! #UPlanet #Community"
    nostpy-cli send_event \
        -privkey "$NPRIV_HEX" \
        -kind 1 \
        -content "$REMINDER_MSG" \
        -tags "[['p', '$ami']]" \
        --relay "$myRELAY"
    echo "📬 Sent reminder to $profile" >> ${UMAPPATH}/NOSTR_messages
}

process_recent_messages() {
    local ami=$1
    local UMAPPATH=$2
    local LAT=$3
    local LON=$4
    local SINCE=$5
    
    echo "---------------------------------"
    
    ./strfry scan '{
      "kinds": [1],
      "authors": ["'"$ami"'"],
      "since": '"$SINCE"'
    }' 2>/dev/null | jq -c 'select(.kind == 1) | {id: .id, content: .content}' | while read -r message; do
        process_single_message "$message" "$UMAPPATH" "$LAT" "$LON"
    done | head -n 25
}

process_single_message() {
    local message=$1
    local UMAPPATH=$2
    local LAT=$3
    local LON=$4
    
    local content=$(echo "$message" | jq -r .content)
    local message_id=$(echo "$message" | jq -r .id)
    
    mkdir -p "${UMAPPATH}/APP/uDRIVE/Images"
    mkdir -p "${UMAPPATH}/APP/uDRIVE/Documents"
    
    if [[ "$content" == *"#market"* ]]; then
        process_market_images "$content" "$UMAPPATH" "$LAT" "$LON"
    fi
    
    create_message_html "$content" "$message_id" "$UMAPPATH" "$LAT" "$LON"
    echo "$content" >> ${UMAPPATH}/NOSTR_messages
}

process_market_images() {
    local content=$1
    local UMAPPATH=$2
    local LAT=$3
    local LON=$4
    
    local image_urls=$(echo "$content" | grep -o 'https\?://[^[:space:]]*\.\(jpg\|jpeg\|png\|gif\)')
    if [[ -n "$image_urls" ]]; then
        for img_url in $image_urls; do
            local filename=$(basename "$img_url")
            local umap_filename="UMAP_${UPLANETG1PUB:0:8}_${LAT}_${LON}_${filename}"
            if [[ ! -f "${UMAPPATH}/APP/uDRIVE/Images/$umap_filename" ]]; then
                wget -q "$img_url" -O "${UMAPPATH}/APP/uDRIVE/Images/$umap_filename"
            fi
        done
    fi
}

create_message_html() {
    local content=$1
    local message_id=$2
    local UMAPPATH=$3
    local LAT=$4
    local LON=$5
    
    local html_content="<!DOCTYPE html>
<html>
<head>
    <meta charset='UTF-8'>
    <title>Message ${message_id}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .message { border: 1px solid #ddd; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .author { color: #666; font-size: 0.9em; }
        .content { margin-top: 10px; }
        img { max-width: 100%; height: auto; }
    </style>
</head>
<body>
    <div class='message'>
        <div class='author'>From: $ami</div>
        <div class='content'>$(echo "$content" | sed 's/#market/\\n#market/g' | markdown)</div>
    </div>
</body>
</html>"
    
    echo "$html_content" > "${UMAPPATH}/APP/uDRIVE/Documents/UMAP_${UPLANETG1PUB:0:8}_${LAT}_${LON}_${message_id}.html"
}

setup_ipfs_structure() {
    local UMAPPATH=$1
    
    mkdir -p "${UMAPPATH}/APP/uDRIVE"
    cd "${UMAPPATH}/APP/uDRIVE"
    ln -sf "${MY_PATH}/../tools/generate_ipfs_structure.sh" ./generate_ipfs_structure.sh
    rm index.html _index.html 2>/dev/null
    cleanup_old_files
    UDRIVE=$(./generate_ipfs_structure.sh .)
    ## Redirect to UDRIVE actual ipfs CID
    echo "<html><head><meta http-equiv=\"refresh\" content=\"0; url=/ipfs/$UDRIVE\"></head></html>" > index.html
    cd - 2>&1>/dev/null
}

cleanup_old_files() {
    local SIX_MONTHS_AGO=$(date -d "6 months ago" +%s)
    
    cleanup_old_documents "$SIX_MONTHS_AGO"
    cleanup_old_images "$SIX_MONTHS_AGO"
}
cleanup_old_documents() {
    local SIX_MONTHS_AGO=$1
    
    if [[ ! -d "Documents" ]]; then
        return
    fi
    
    while IFS= read -r -d '' file; do
        local file_date=$(stat -c %Y "$file")
        
        if [[ $file_date -lt $SIX_MONTHS_AGO ]]; then
            local author=$(sed -n 's/.*From: \([^<]*\).*/\1/p' "$file")
            
            if [[ -n "$author" ]]; then
                local notification="📢 Votre annonce a été retirée après 6 mois. Vous pouvez la republier si elle est toujours d'actualité. #UPlanet #Community"
                
                nostpy-cli send_event \
                    -privkey "$NPRIV_HEX" \
                    -kind 1 \
                    -content "$notification" \
                    -tags "[['p', '$author']]" \
                    --relay "$myRELAY"
            fi
            
            rm "$file"
        fi
    done < <(find "Documents" -type f -name "*.html" -print0)
}

cleanup_old_images() {
    local SIX_MONTHS_AGO=$1
    
    if [[ ! -d "Images" ]]; then
        return
    fi
    
    while IFS= read -r -d '' image; do
        local file_date=$(stat -c %Y "$image")
        
        if [[ $file_date -lt $SIX_MONTHS_AGO ]]; then
            rm "$image"
        fi
    done < <(find "Images" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" \) -print0)
}

setup_umap_identity() {
    local LAT=$1
    local LON=$2
    local UMAPPATH=$3
    
    $(${MY_PATH}/../tools/getUMAP_ENV.sh "${LAT}" "${LON}" | tail -n 1)
    STAGS+=("[\"p\", \"$SECTORHEX\", \"$myRELAY\", \"$SECTOR\"]")
    
    UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
    NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$UMAPNSEC")
    UMAPNPUB=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}")
    
    local TAGS_JSON=$(printf '%s\n' "${TAGS[@]}" | jq -c . | tr '\n' ',' | sed 's/,$//')
    TAGS_JSON="[$TAGS_JSON]"
    
    send_nostr_events "$NPRIV_HEX" "$TAGS_JSON" "$UMAPPATH"
}

send_nostr_events() {
    local NPRIV_HEX=$1
    local TAGS_JSON=$2
    local UMAPPATH=$3
    
    nostpy-cli send_event \
        -privkey "$NPRIV_HEX" \
        -kind 3 \
        -content "" \
        -tags "$TAGS_JSON" \
        --relay "$myRELAY"
    
    if [[ $(cat ${UMAPPATH}/NOSTR_messages) != "" ]]; then
        nostpy-cli send_event \
            -privkey "$NPRIV_HEX" \
            -kind 1 \
            -content "$(cat ${UMAPPATH}/NOSTR_messages) $myIPFS/ipns/copylaradio.com" \
            --relay "$myRELAY"
    fi
}

################################################################################
# Sector Management Functions
################################################################################

process_sectors() {
    local UNIQUE_SECTORS=($(echo "${SECTORS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    
    for sector in ${UNIQUE_SECTORS[@]}; do
        create_sector_journal "$sector"
    done
}

create_sector_journal() {
    local sector=$1
    echo "Creating Sector ${sector} Journal from sub UMAPS"
    # Get from local then swarm
    local message_text="$(cat ${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*_*/${sector}/*/NOSTR_messages)"
    if [[ -z "$message_text" ]]; then
        echo "search for sector ${sector} journal in swarm"
        message_text="$(cat ${HOME}/.zen/tmp/swarm/*/UPLANET/__/_*_*/${sector}/*/NOSTR_messages)"
        if [[ -z "$message_text" ]]; then
            echo "No NOSTR_messages found for sector ${sector}"
            return
        fi
    fi
    
    local ANSWER=$(generate_ai_summary "$message_text")
    save_sector_journal "$sector" "$ANSWER"
    update_sector_nostr_profile "$sector" "$ANSWER"
}

save_sector_journal() {
    local sector=$1
    local ANSWER=$2
    
    local slat=$(echo ${sector} | cut -d '_' -f 2)
    local slon=$(echo ${sector} | cut -d '_' -f 3)
    local rlat=$(echo ${slat} | cut -d '.' -f 1)
    local rlon=$(echo ${slon} | cut -d '.' -f 1)
    REGIONS+=("_${rlat}_${rlon}")
    
    local sectorpath="${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/_${rlat}_${rlon}/_${slat}_${slon}"
    mkdir -p $sectorpath
    echo "$ANSWER" > $sectorpath/NOSTR_journal
    
    SECROOT=$(ipfs add -rwHq $sectorpath/* | tail -n 1)
    update_sector_calendar "$sectorpath" "$SECROOT"
}

update_sector_calendar() {
    local sectorpath=$1
    local SECROOT=$2
    
    echo "${SECROOT}" > ${sectorpath}/ipfs.${DEMAINDATE} 2>/dev/null
    rm ${sectorpath}/ipfs.${YESTERDATE} 2>/dev/null
    
    local JOUR_SEMAINE=$(LANG=fr_FR.UTF-8 date +%A)
    local HIER=$(LANG=fr_FR.UTF-8 date --date="yesterday" +%A)
    echo '<meta http-equiv="refresh" content="0;url='${myIPFS}'/ipfs/'${SECROOT}'">' > ${sectorpath}/${JOUR_SEMAINE}.html 2>/dev/null
    rm ${sectorpath}/${HIER}.html 2>/dev/null
}

update_sector_nostr_profile() {
    local sector=$1
    local ANSWER=$2
    
    local slat=$(echo ${sector} | cut -d '_' -f 2)
    local slon=$(echo ${sector} | cut -d '_' -f 3)
    local rlat=$(echo ${slat} | cut -d '.' -f 1)
    local rlon=$(echo ${slon} | cut -d '.' -f 1)
    
    $(${MY_PATH}/../tools/getUMAP_ENV.sh "${slat}0" "${slon}0" | tail -n 1)
    RTAGS+=("[\"p\", \"$REGIONHEX\", \"$myRELAY\", \"$REGION\"]")
    
    local SECTORNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${SECTOR}" "${UPLANETNAME}${SECTOR}" -s)
    local NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$SECTORNSEC")
    
    ${MY_PATH}/../tools/nostr_setup_profile.py \
        "$SECTORNSEC" \
        "SECTOR_${UPLANETG1PUB:0:8}${sector} ${TODATE}" "${SECTORG1PUB}" \
        "VISIO ROOM : $myIPFS$VDONINJA/?room=${SECTORG1PUB:0:8}&effects&record" \
        "${myIPFS}/ipfs/Qmeezy8CtoXzz9LqA8mWqzYDweEYMqAvjZ1JyZFDW7pLQC/LivingTV.gif" \
        "${myIPFS}/ipfs/QmQAjxPE5UZWW4aQWcmsXgzpcFvfk75R1sSo2GuEgQ3Byu" \
        "" "${myIPFS}/ipfs/${SECROOT}" "" "$myIPFS$VDONINJA/?room=${SECTORG1PUB:0:8}&effects&record" "" "" \
        "$myRELAY" "wss://relay.copylaradio.com"
    
    local TAGS_JSON=$(printf '%s\n' "${STAGS[@]}" | jq -c . | tr '\n' ',' | sed 's/,$//')
    TAGS_JSON="[$TAGS_JSON]"
    
    nostpy-cli send_event \
        -privkey "$NPRIV_HEX" \
        -kind 3 \
        -content "" \
        -tags "$TAGS_JSON" \
        --relay "$myRELAY"
    
    if [[ -s $sectorpath/NOSTR_journal ]]; then
        nostpy-cli send_event \
            -privkey "$NPRIV_HEX" \
            -kind 1 \
            -content "$(cat $sectorpath/NOSTR_journal) $myIPFS/ipns/copylaradio.com" \
            --relay "$myRELAY"
    fi
}

################################################################################
# Region Management Functions
################################################################################

process_regions() {
    local UNIQUE_REGIONS=($(echo "${REGIONS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    
    for region in ${UNIQUE_REGIONS[@]}; do
        create_region_journal "$region"
    done
}

create_region_journal() {
    local region=$1
    local rlat=$(echo ${region} | cut -d '_' -f 2)
    local rlon=$(echo ${region} | cut -d '_' -f 3)
    
    echo "Creating Region ${region} Journal from sub SECTORS"
    local message_text=$(cat ${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/SECTORS/${region}/*/NOSTR_journal)
    
    if [[ -z "$message_text" ]]; then
        echo "No messages found for region ${region}"
        return
    fi
    
    local ANSWER=$(generate_ai_summary "$message_text")
    save_region_journal "$region" "$ANSWER"
    update_region_nostr_profile "$region" "$ANSWER"
}

save_region_journal() {
    local region=$1
    local ANSWER=$2
    
    local regionpath="${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/REGIONS/${region}"
    mkdir -p $regionpath
    echo "$ANSWER" > $regionpath/NOSTR_journal
    
    REGROOT=$(ipfs add -rwHq $regionpath/* | tail -n 1)
    update_region_calendar "$regionpath" "$REGROOT"
}

update_region_calendar() {
    local regionpath=$1
    local REGROOT=$2
    
    echo "${REGROOT}" > ${regionpath}/ipfs.${DEMAINDATE} 2>/dev/null
    rm ${regionpath}/ipfs.${YESTERDATE} 2>/dev/null
}

update_region_nostr_profile() {
    local region=$1
    local ANSWER=$2
    
    local rlat=$(echo ${region} | cut -d '_' -f 2)
    local rlon=$(echo ${region} | cut -d '_' -f 3)
    
    $(${MY_PATH}/../tools/getUMAP_ENV.sh "${rlat}.00" "${rlon}.00" | tail -n 1) ## Get UMAP ENV for REGION
    local REGSEC=$(${MY_PATH}/../tools/keygen -t nostr "${UPLANETNAME}${region}" "${UPLANETNAME}${region}" -s)
    local NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$REGSEC")
    
    ${MY_PATH}/../tools/nostr_setup_profile.py \
        "$REGSEC" \
        "REGION_${UPLANETG1PUB:0:8}${region}" "${REGIONG1PUB}" \
        "UPlanet ${TODATE} -- VISIO ROOM : $myIPFS$VDONINJA/?room=${REGIONG1PUB:0:8}&effects&record" \
        "${myIPFS}/ipfs/QmRsRTZuVwL6UsjLGooVMFFTbNfeswfCaRmJHTBmk2XiqU/internet.png" \
        "${myIPFS}/ipfs/QmQAjxPE5UZWW4aQWcmsXgzpcFvfk75R1sSo2GuEgQ3Byu" \
        "" "${myIPFS}/ipfs/${REGROOT}" "" "$myIPFS$VDONINJA/?room=${REGIONG1PUB:0:8}&effects&record" "" "" \
        "$myRELAY" "wss://relay.copylaradio.com"
    
    local TAGS_JSON=$(printf '%s\n' "${RTAGS[@]}" | jq -c . | tr '\n' ',' | sed 's/,$//')
    TAGS_JSON="[$TAGS_JSON]"
    
    nostpy-cli send_event \
        -privkey "$NPRIV_HEX" \
        -kind 3 \
        -content "" \
        -tags "$TAGS_JSON" \
        --relay "$myRELAY"
    
    if [[ -s $regionpath/NOSTR_journal ]]; then
        nostpy-cli send_event \
            -privkey "$NPRIV_HEX" \
            -kind 1 \
            -content "$(cat $regionpath/NOSTR_journal) $myIPFS/ipns/copylaradio.com" \
            --relay "$myRELAY"
    fi
}

################################################################################
# NOSTR Management Functions
################################################################################

update_friends_list() {
    local friends=("$@")
    
    # Get UMAP NSEC from environment
    local UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
    
    # Update friends list using nostr_follow.sh
    if [[ ${#friends[@]} -gt 0 ]]; then
        $MY_PATH/../tools/nostr_follow.sh "$UMAPNSEC" "${friends[@]}" "$myRELAY"
        echo "Updated friends list with ${#friends[@]} active friends"
    else
        echo "No active friends to update"
    fi
}

generate_ai_summary() {
    local text=$1
    local QUESTION="[TEXT] $text [/TEXT] --- # 1. Write a summary of [TEXT] # 2. Highlight key points with their authors # 3. Add hastags and emoticons # IMPORTANT : Use the same language as mostly used in [TEXT]."
    $MY_PATH/../IA/question.py "${QUESTION}"
}

################################################################################
# Main Execution
################################################################################

main() {
    check_dependencies
    display_banner
    
    # Process UMAPs
    for hexline in $(ls ~/.zen/game/nostr/UMAP_*_*/HEX); do
        process_umap_messages "$hexline"
    done
    
    # Process Sectors
    process_sectors
    
    # Process Regions
    process_regions
    
    exit 0
}

main
