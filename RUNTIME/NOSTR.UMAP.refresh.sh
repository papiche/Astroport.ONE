#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.5
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# NIP-101 related : strfry processing "UPlanet message"
# This script aggregates and manages geolocated content from Nostr.
# It identifies UMAPs (Geo Keys) from ~/.zen/game/nostr/UMAP*/HEX.
# Each UMAP acts as a Nostr identity, making friends with users whose messages
# are associated with its location. Daily, it retrieves messages from these
# friends, including processing special content like '#market' tags to download
# associated images. It then uses AI to summarize these messages into 'SECTOR journals'
# and 'REGION journals', which are subsequently published to Nostr and IPFS.
# It also manages friend activity, sending reminders or removing inactive friends.
# This script also generates a "friend of friend" list from active contacts.
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
NOTR.UMAP.refresh.sh'
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

    # Initialize NPRIV_HEX early for this UMAP
    local UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
    local NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$UMAPNSEC")

    local friends=($($MY_PATH/../tools/nostr_get_N1.sh $hex 2>/dev/null))
    local SINCE=$(date -d "24 hours ago" +%s)
    local WEEK_AGO=$(date -d "7 days ago" +%s)
    local MONTH_AGO=$(date -d "28 days ago" +%s)

    cd ~/.zen/strfry

    local TAGS=()
    local ACTIVE_FRIENDS=()

    for ami in ${friends[@]}; do
        process_friend_messages "$ami" "$UMAPPATH" "$LAT" "$LON" "$SINCE" "$WEEK_AGO" "$MONTH_AGO" "$NPRIV_HEX"
    done

    update_friends_list "${ACTIVE_FRIENDS[@]}"
    setup_ipfs_structure "$UMAPPATH" "$NPRIV_HEX"
}

process_friend_messages() {
    local ami=$1
    local UMAPPATH=$2
    local LAT=$3
    local LON=$4
    local SINCE=$5
    local WEEK_AGO=$6
    local MONTH_AGO=$7
    local NPRIV_HEX=$8

    local PROFILE=$(./strfry scan '{
      "kinds": [0],
      "authors": ["'"$ami"'"],
      "limit": 1
    }' 2>/dev/null | jq -r 'select(.kind == 0) | .content' | jq -r '[.name, .display_name, .about] | join(" | ")')

    if [[ -n "$PROFILE" ]]; then
        handle_active_friend "$ami" "$UMAPPATH" "$WEEK_AGO" "$MONTH_AGO" "$NPRIV_HEX"
        # Get friends of this friend and add to amisOfAmis.txt if not already present
        local fof_list=$($MY_PATH/../tools/nostr_get_N1.sh "$ami" 2>/dev/null)
        if [[ -n "$fof_list" ]]; then
            for fof in $fof_list; do
                # Only append if fof not already in file
                if ! grep -q "^${fof}$" ~/.zen/strfry/amisOfAmis.txt 2>/dev/null; then
                    echo "$fof" >> ~/.zen/strfry/amisOfAmis.txt
                fi
            done
        fi

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
    local NPRIV_HEX=$5

    local profile=$($MY_PATH/../tools/nostr_hex2nprofile.sh $ami 2>/dev/null)

    local RECENT_ACTIVITY=$(./strfry scan '{
      "kinds": [1],
      "authors": ["'"$ami"'"],
      "since": '"$MONTH_AGO"',
      "limit": 1
    }' 2>/dev/null | jq -r 'select(.kind == 1) | .created_at')

    if [[ -z "$RECENT_ACTIVITY" ]]; then
        handle_inactive_friend "$ami" "$profile" "$NPRIV_HEX"
    else
        echo "-----------------------------" >> ${UMAPPATH}/NOSTR_messages
        echo "👤 nostr:$profile" >> ${UMAPPATH}/NOSTR_messages
        handle_active_friend_activity "$ami" "$profile" "$WEEK_AGO" "$NPRIV_HEX"
    fi
}

handle_inactive_friend() {
    local ami=$1
    local profile=$2
    local NPRIV_HEX=$3

    # echo "🚫 Removing inactive friend: nostr:$profile (no activity in 4 weeks)" >> ${UMAPPATH}/NOSTR_messages
    local GOODBYE_MSG="👋 nostr:$profile ! It seems you've been inactive for a while. I remove you from my GeoKey list, but you're welcome to reconnect anytime! #UPlanet #Community"
    nostpy-cli send_event \
        -privkey "$NPRIV_HEX" \
        -kind 1 \
        -content "$GOODBYE_MSG" \
        -tags "[['p', '$ami']]" \
        --relay "$myRELAY" 2>/dev/null
}

handle_active_friend_activity() {
    local ami=$1
    local profile=$2
    local WEEK_AGO=$3
    local NPRIV_HEX=$4

    ACTIVE_FRIENDS+=("$ami")
    TAGS+=("[\"p\", \"$ami\", \"$myRELAY\", \"Ufriend\"]")

    local WEEK_ACTIVITY=$(./strfry scan '{
      "kinds": [1],
      "authors": ["'"$ami"'"],
      "since": '"$WEEK_AGO"',
      "limit": 1
    }' 2>/dev/null | jq -r 'select(.kind == 1) | .created_at')

    if [[ -z "$WEEK_ACTIVITY" ]]; then
        send_reminder_message "$ami" "$profile" "$NPRIV_HEX"
    fi
}

send_reminder_message() {
    local ami=$1
    local profile=$2
    local NPRIV_HEX=$3

    local REMINDER_MSG="👋 nostr:$profile ! Haven't seen you around lately. How are you doing? Feel free to share your thoughts or updates! #UPlanet #Community"
    nostpy-cli send_event \
        -privkey "$NPRIV_HEX" \
        -kind 1 \
        -content "$REMINDER_MSG" \
        -tags "[['p', '$ami']]" \
        --relay "$myRELAY"
    echo "📬 Sent reminder to $profile" 2>/dev/null >> ${UMAPPATH}/NOSTR_messages
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
        process_single_message "$message" "$UMAPPATH" "$LAT" "$LON" "$ami"
    done | head -n 25
}

process_single_message() {
    local message=$1
    local UMAPPATH=$2
    local LAT=$3
    local LON=$4
    local ami=$5

    local content=$(echo "$message" | jq -r .content)
    local message_id=$(echo "$message" | jq -r .id)
    local created_at=$(echo "$message" | jq -r .created_at)

    mkdir -p "${UMAPPATH}/APP/uMARKET/Images"
    mkdir -p "${UMAPPATH}/APP/uMARKET/ads"

    if [[ "$content" == *"#market"* ]]; then
        process_market_images "$content" "$UMAPPATH" "$LAT" "$LON"
        create_market_ad "$content" "${message_id}" "$UMAPPATH" "$LAT" "$LON" "$ami" "$created_at"
    fi

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
            if [[ ! -f "${UMAPPATH}/APP/uMARKET/Images/$umap_filename" ]]; then
                wget -q "$img_url" -O "${UMAPPATH}/APP/uMARKET/Images/$umap_filename"
            fi
        done
    fi
}

create_market_ad() {
    local content=$1
    local message_id=$2
    local UMAPPATH=$3
    local LAT=$4
    local LON=$5
    local ami=$6
    local created_at=$7

    # Get author profile information
    local author_nprofile=$($MY_PATH/../tools/nostr_hex2nprofile.sh "$ami" 2>/dev/null)
    
    # Extract local image filenames
    local local_images=()
    if [[ -d "${UMAPPATH}/APP/uMARKET/Images" ]]; then
        while IFS= read -r -d '' image; do
            local_images+=("$(basename "$image")")
        done < <(find "${UMAPPATH}/APP/uMARKET/Images" -name "UMAP_${UPLANETG1PUB:0:8}_${LAT}_${LON}_*" -print0)
    fi

    # Create JSON advertisement
    local ad_json=$(cat << EOF
{
    "id": "${message_id}",
    "content": "${content//\"/\\\"}",
    "author_pubkey": "${ami}",
    "author_nprofile": "${author_nprofile}",
    "created_at": ${created_at},
    "location": {
        "lat": ${LAT},
        "lon": ${LON}
    },
    "local_images": $(printf '%s\n' "${local_images[@]}" | jq -R . | jq -s .),
    "umap_id": "UMAP_${UPLANETG1PUB:0:8}_${LAT}_${LON}"
}
EOF
)

    echo "$ad_json" > "${UMAPPATH}/APP/uMARKET/ads/${message_id}.json"
}

setup_ipfs_structure() {
    local UMAPPATH=$1
    local NPRIV_HEX=$2

    mkdir -p "${UMAPPATH}/APP/uMARKET"
    cd "${UMAPPATH}/APP/uMARKET"
    
    # Check if there are market advertisements
    if [[ -d "ads" && $(find "ads" -name "*.json" | wc -l) -gt 0 ]]; then
        # Use uMARKET for market advertisements
        ln -sf "${MY_PATH}/../tools/generate_uMARKET.sh" ./generate_uMARKET.sh
        cleanup_old_files "$NPRIV_HEX"
        uCID=$(./generate_uMARKET.sh .)
    else
        # Use standard uMARKET for non-market content
        ln -sf "${MY_PATH}/../tools/generate_ipfs_structure.sh" ./generate_ipfs_structure.sh
        rm index.html _index.html manifest.json 2>/dev/null ## Reset uMARKET index & manifest
        cleanup_old_files "$NPRIV_HEX"
        uCID=$(./generate_ipfs_structure.sh .)
    fi
    
    ## Redirect to uCID actual ipfs CID
    echo "<html><head><meta http-equiv=\"refresh\" content=\"0; url=/ipfs/$uCID\"></head></html>" > index.html
    rm index.html ## DEBUG MODE (todo remove)
    cd - 2>&1>/dev/null
}

cleanup_old_files() {
    local SIX_MONTHS_AGO=$(date -d "6 months ago" +%s)

    cleanup_old_documents "$SIX_MONTHS_AGO" "$NPRIV_HEX"
    cleanup_old_images "$SIX_MONTHS_AGO"
}
cleanup_old_documents() {
    local SIX_MONTHS_AGO=$1
    local NPRIV_HEX=$2

    if [[ ! -d "ads" ]]; then
        return
    fi

    while IFS= read -r -d '' file; do
        local file_date=$(stat -c %Y "$file")

        if [[ $file_date -lt $SIX_MONTHS_AGO ]]; then
            # Extract author from JSON file
            local author=$(jq -r '.author_pubkey' "$file" 2>/dev/null)

            if [[ -n "$author" && "$author" != "null" ]]; then
                local notification="🛒 Votre annonce de marché a été retirée après 6 mois. Vous pouvez la republier si elle est toujours d'actualité. #UPlanet #Market #Community"

                nostpy-cli send_event \
                    -privkey "$NPRIV_HEX" \
                    -kind 1 \
                    -content "$notification" \
                    -tags "[['p', '$author']]" \
                    --relay "$myRELAY" 2>/dev/null
            fi

            rm "$file"
        fi
    done < <(find "ads" -type f -name "*.json" -print0)
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

    # NPRIV_HEX is already initialized in process_umap_friends, so we don't need to regenerate it
    # Just get the public key for reference
    UMAPNPUB=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}")

    local TAGS_JSON=$(printf '%s\n' "${TAGS[@]}" | jq -c . | tr '\n' ',' | sed 's/,$//')
    TAGS_JSON="[$TAGS_JSON]"

    # Get NPRIV_HEX from the calling context
    local UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
    local NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$UMAPNSEC")
    
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
        --relay "$myRELAY" 2>/dev/null

    if [[ $(cat ${UMAPPATH}/NOSTR_messages) != "" ]]; then
        nostpy-cli send_event \
            -privkey "$NPRIV_HEX" \
            -kind 1 \
            -content "$(cat ${UMAPPATH}/NOSTR_messages) $myIPFS/ipns/copylaradio.com" \
            --relay "$myRELAY" 2>/dev/null
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
        --relay "$myRELAY" 2>/dev/null

    if [[ -s $sectorpath/NOSTR_journal ]]; then
        nostpy-cli send_event \
            -privkey "$NPRIV_HEX" \
            -kind 1 \
            -content "$(cat $sectorpath/NOSTR_journal) $myIPFS/ipns/copylaradio.com" \
            --relay "$myRELAY" 2>/dev/null
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
        --relay "$myRELAY" 2>/dev/null

    if [[ -s $regionpath/NOSTR_journal ]]; then
        nostpy-cli send_event \
            -privkey "$NPRIV_HEX" \
            -kind 1 \
            -content "$(cat $regionpath/NOSTR_journal) $myIPFS/ipns/copylaradio.com" \
            --relay "$myRELAY" 2>/dev/null
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

    BLACKLIST_FILE="${HOME}/.zen/strfry/blacklist.txt"
    AMISOFAMIS_FILE="${HOME}/.zen/strfry/amisOfAmis.txt"

    # Process UMAPs
    for hexline in $(ls ~/.zen/game/nostr/UMAP_*_*/HEX); do
        process_umap_messages "$hexline"
    done

    # Process Sectors
    process_sectors

    # Process Regions
    process_regions

    # Remove entries from blacklist.txt that are found in amisOfAmis.txt
    if [[ -f "$BLACKLIST_FILE" && -f "$AMISOFAMIS_FILE" ]]; then
        # Create a temporary file for the filtered blacklist
        grep -v -f "$AMISOFAMIS_FILE" "$BLACKLIST_FILE" > "${BLACKLIST_FILE}.tmp"
        # Overwrite the original blacklist with the filtered content
        mv "${BLACKLIST_FILE}.tmp" "$BLACKLIST_FILE"
        echo "Cleaned $BLACKLIST_FILE: removed entries found in $AMISOFAMIS_FILE."
    elif [[ ! -f "$BLACKLIST_FILE" ]]; then
        echo "Info: $BLACKLIST_FILE not found, no blacklist to clean."
    elif [[ ! -f "$AMISOFAMIS_FILE" ]]; then
        echo "Info: $AMISOFAMIS_FILE not found, no friends of friends list for cleaning blacklist."
    fi

    exit 0
}

main
