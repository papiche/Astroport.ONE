#!/bin/bash
########################################################################
# Version: 1.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/../tools/my.sh"

# Function to send email notification on NOSTR failure
send_nostr_failure_email() {
    local player="$1"
    local youtube_id="$2"
    local title="$3"
    local ipfs_link="$4"
    
    # Check if mailjet.sh exists
    if [[ ! -f "$MY_PATH/../tools/mailjet.sh" ]]; then
        echo "⚠️  mailjet.sh not found, cannot send failure notification email"
        return 1
    fi
    
    # Check if player email is valid
    if [[ ! "$player" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        echo "⚠️  Invalid player email format: $player, cannot send failure notification email"
        return 1
    fi
    
    # Create temporary message file
    local temp_message_file="$HOME/.zen/tmp/nostr_failure_${youtube_id}.txt"
    cat > "$temp_message_file" << EOF
NOSTR Message Failure Notification

Dear ${player},

The NOSTR message for your YouTube copy could not be sent successfully.

YouTube Copy Details:
- Title: ${title}
- YouTube ID: ${youtube_id}
- IPFS Link: ${ipfs_link}
- Timestamp: $(date -u)

The video has been successfully copied from YouTube and added to your Astroport TiddlyWiki and IPFS, but the public NOSTR announcement failed.

This could be due to:
- Network connectivity issues
- Relay server problems
- NOSTR key configuration issues

Your video is still available at: ${ipfs_link}

Please check your NOSTR configuration or try again later.

Best regards,
Astroport.ONE System
EOF
    
    # Send email using mailjet.sh
    echo "📧 Sending NOSTR failure notification email to ${player}"
    $MY_PATH/../tools/mailjet.sh --template "$0" --expire 48h "$player" "$temp_message_file" "NOSTR Message Failure - ${title}" 2>/dev/null
    
    local email_result=$?
    
    # Clean up temporary file
    rm -f "$temp_message_file"
    
    if [[ $email_result -eq 0 ]]; then
        echo "✅ NOSTR failure notification email sent successfully to ${player}"
    else
        echo "❌ Failed to send NOSTR failure notification email to ${player}"
    fi
    
    return $email_result
}

# Function to send YouTube copy as public NOSTR message
# Publish YouTube copy as NIP-71 video event (kind 21 or 22) via MULTIPASS NOSTR key
# Conforms to UPlanet_FILE_CONTRACT.md — videos appear in UPassport/templates/youtube.html
publish_nip71_video() {
    local player="$1"
    local video_file="$2"   # full local path to downloaded file
    local ilink="$3"        # IPFS CID of video
    local animh="$4"        # IPFS CID of GIF animation
    local title="$5"
    local mime="$6"
    local duration_sec="$7"  # SEC variable (integer seconds)
    local resolution="$8"    # WxH string
    local channel="$9"
    local youtube_url="${10}"

    # Use MULTIPASS .secret.nostr keyfile directly (UPlanet_FILE_CONTRACT.md §6.1)
    local keyfile="${HOME}/.zen/game/nostr/${player}/.secret.nostr"
    if [[ ! -f "$keyfile" ]]; then
        echo "⚠️  No MULTIPASS NOSTR keyfile for ${player} — skipping NIP-71 publication"
        return 1
    fi

    local ipfs_url="${myIPFS}/ipfs/${ilink}"

    # Calculate SHA256 hash (NIP-71 "x" tag)
    local file_hash=""
    [[ -f "$video_file" ]] && file_hash=$(sha256sum "$video_file" | cut -d' ' -f1)

    # Generate static thumbnail via ffmpeg at 10% of duration
    local thumb_cid=""
    if [[ -n "$duration_sec" && "$duration_sec" =~ ^[0-9]+$ && "$duration_sec" -gt 0 && -f "$video_file" ]]; then
        local thumb_time=$(( duration_sec / 10 ))
        local thumb_file="${video_file%.*}_thumb.jpg"
        ffmpeg -ss "$thumb_time" -i "$video_file" -vframes 1 -q:v 2 "$thumb_file" 2>/dev/null
        [[ -s "$thumb_file" ]] && thumb_cid=$(ipfs add -q "$thumb_file" | tail -n 1) && rm -f "$thumb_file"
    fi
    # Fallback: use GIF CID as thumbnail if static thumb failed
    [[ -z "$thumb_cid" && -n "$animh" ]] && thumb_cid="$animh"

    # Determine NIP-71 kind: 21 (long-form >60s) or 22 (short-form ≤60s)
    local kind=21
    [[ -n "$duration_sec" && "$duration_sec" =~ ^[0-9]+$ && $duration_sec -le 60 ]] && kind=22

    # Build NIP-71 tags JSON using jq (UPlanet_FILE_CONTRACT.md §3.2, §4.1.3)
    local tags
    tags=$(jq -cn \
        --arg title    "$title" \
        --arg url      "$ipfs_url" \
        --arg mime     "$mime" \
        --arg pubat    "$(date +%s)" \
        --arg dur      "$duration_sec" \
        --arg dim      "$resolution" \
        --arg thumb    "$thumb_cid" \
        --arg gif      "$animh" \
        --arg hash     "$file_hash" \
        --arg chan     "Channel-${channel}" \
        --arg yturl    "$youtube_url" \
        '[
            ["title",        $title],
            ["url",          $url],
            ["m",            $mime],
            ["published_at", $pubat],
            (if ($dur  | length) > 0 then ["duration",       $dur]   else empty end),
            (if ($dim  | length) > 0 then ["dim",            $dim]   else empty end),
            (if ($thumb| length) > 0 then ["thumbnail_ipfs", $thumb] else empty end),
            (if ($gif  | length) > 0 then ["gifanim_ipfs",   $gif]   else empty end),
            (if ($hash | length) > 0 then ["x",              $hash]  else empty end),
            ["t", $chan],
            ["t", "CopierYoutube"],
            ["t", "YouTube"],
            ["t", "Astroport"],
            ["r", $yturl]
        ]' 2>/dev/null)

    if [[ -z "$tags" ]]; then
        echo "❌ Failed to build NIP-71 tags (jq error) for ${youtube_url}"
        send_nostr_failure_email "$player" "$(basename "$video_file")" "$title" "$ipfs_url"
        return 1
    fi

    # Content for the event
    local content="🎬 ${title}

📺 Channel: ${channel}
🔗 IPFS: ${ipfs_url}
🌐 Source: ${youtube_url}

#CopierYoutube #YouTube #Astroport #IPFS"

    # Relays: local + public copylaradio
    local relays="${myRELAY}"
    [[ "$myRELAY" != "wss://relay.copylaradio.com" ]] && relays="${relays},wss://relay.copylaradio.com"

    echo "📡 Publishing NIP-71 kind ${kind} video event via MULTIPASS (${player})..."
    python3 "${MY_PATH}/../tools/nostr_send_note.py" \
        --keyfile "$keyfile" \
        --content "$content" \
        --kind    "$kind" \
        --tags    "$tags" \
        --relays  "$relays" \
        --json 2>/dev/null

    local result=$?
    if [[ $result -eq 0 ]]; then
        echo "✅ NIP-71 kind ${kind} event published — will appear in UPassport youtube.html"
    else
        echo "❌ Failed to publish NIP-71 kind ${kind} event for ${title}"
        send_nostr_failure_email "$player" "$(basename "$video_file")" "$title" "$ipfs_url"
    fi
    return $result
}

echo "-----"
echo "$ME RUNNING"
#######################################################################
# ASTROBOT SUBKEY PROGRAM : [G1]CopierYoutube "tag"
# Ce script se déclenche si le tiddler "voeu" "CopierYoutube" a été formulé dans le TW du PLAYER
# Il active l'extraction des liens (compatibles yt-dlp) trouvés dans les tiddlers portant le tag "CopierYoutube"
# Les vidéos (mp4) ou audio (mp3) (+tag "CopierYoutube MP3") sont inscrites dans un json puis importés dans le TW.
#######################################################################
INDEX="$1"
[[ ! ${INDEX} ]] && echo "ERROR - Please provide path to source TW index.html" && exit 1
[[ ! -s ${INDEX} ]] && echo "ERROR - Fichier TW absent. ${INDEX}" && exit 1

PLAYER="$2"
[[ ! ${PLAYER} ]] && echo "ERROR - Please provide IPFS publish key" && exit 1

ASTRONAUTENS=$(ipfs key list -l | grep -w ${PLAYER} | head -n1 | cut -d ' ' -f1)
[[ ! $ASTRONAUTENS ]] && echo "ERROR - Clef IPNS ${PLAYER} introuvable!"  && exit 1

G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub)

# Extract tag=tube from TW
MOATS="$3"
[[ ! $MOATS ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

###################################################################
## CREATE APP NODE PLAYER PUBLICATION DIRECTORY
###################################################################
mkdir -p ${HOME}/.zen/tmp/${IPFSNODEID}/G1CopierYoutube/${PLAYER}/
mkdir -p ${HOME}/.zen/game/players/${PLAYER}/G1CopierYoutube/

###################################################################
## tag[CopierYoutube] EXTRACT ~/.zen/tmp/CopierYoutube.json FROM TW
###################################################################
rm -f ~/.zen/game/players/${PLAYER}/G1CopierYoutube/CopierYoutube.json
tiddlywiki  --load ${INDEX} \
                    --output ~/.zen/game/players/${PLAYER}/G1CopierYoutube \
                    --render '.' 'CopierYoutube.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[CopierYoutube]]'

echo "DEBUG : cat ~/.zen/game/players/${PLAYER}/G1CopierYoutube/CopierYoutube.json | jq -r"
## CHEK FOR MP3 TAG
TAGS=()
TAGS=($(cat ~/.zen/game/players/${PLAYER}/G1CopierYoutube/CopierYoutube.json | jq -r .[].tags))
echo "TAGS :${#TAGS[@]}: ${TAGS[@]}"
isMP3=$(echo ${TAGS[@]} | grep -w "MP3")

## GET USER BROWSER for YOUTUBE COOKIES
BZER=$(xdg-settings get default-web-browser | cut -d '.' -f 1 | cut -d '-' -f 1) ## GET cookies-from-browser
[[ $BZER ]] && BROWSER="--cookies-from-browser $BZER " || BROWSER=""
[[ ! $isLAN ]] && BROWSER=""

###################################################################
## URL EXTRACTION & yt-dlp.cache.${PLAYER} upgrade
for YURL in $(cat ~/.zen/game/players/${PLAYER}/G1CopierYoutube/CopierYoutube.json | jq -r '.[].text' | grep 'http'); do
    [[ ! $(echo $YURL | grep "http" ) ]] && echo "$YURL error" && continue
    echo "G1CopierYoutube : $YURL"
    echo "Extracting video playlist into yt-dlp.cache.${PLAYER}"

    ### yt-dlp.command
    CMD=$(cat ~/.zen/game/players/${PLAYER}/G1CopierYoutube/yt-dlp.command 2>/dev/null | grep -- "$YURL" | tail -n 1)
    if [[ ! $CMD ]]; then
        echo "${PLAYER}&$YURL:$MOATS" >> ~/.zen/game/players/${PLAYER}/G1CopierYoutube/yt-dlp.command
        echo "NOUVEAU CANAL ${PLAYER}&$YURL:$MOATS"
        lastrun=$MOATS
        duree=604800000
    else
        lastrun=$(echo "$CMD" | rev | cut -d ':' -f 1 | rev) && echo "$CMD"
        duree=$(expr ${MOATS} - $lastrun)
    fi
    # ONE WEEK NEW SCAN
    if [[ $duree -ge 604800000 || ! -s ~/.zen/game/players/${PLAYER}/G1CopierYoutube/yt-dlp.cache.${PLAYER} ]]; then
        /usr/local/bin/yt-dlp $BROWSER --print "%(id)s&%(webpage_url)s" "${YURL}" 2>/dev/null >> ~/.zen/game/players/${PLAYER}/G1CopierYoutube/yt-dlp.cache.${PLAYER}
        sed -i "s~$lastrun~$MOATS~g" ~/.zen/game/players/${PLAYER}/G1CopierYoutube/yt-dlp.command # UPDATE LASTRUN
    fi

done # FINISH YURL loop

## CREATE SORT UNIQ SHUFFLED ~/.zen/tmp/${IPFSNODEID}/yt-dlp.cache.${PLAYER} (12345 ONLINE)
cat ~/.zen/game/players/${PLAYER}/G1CopierYoutube/yt-dlp.cache.${PLAYER} 2>/dev/null | sort | uniq | shuf > ~/.zen/tmp/${IPFSNODEID}/yt-dlp.cache.${PLAYER}

###################################################################
[[ ! -s  ~/.zen/tmp/${IPFSNODEID}/yt-dlp.cache.${PLAYER} ]] && echo "AUCUN YOUTUBEID pour CopierYoutube" && exit  0
###################################################################
boucle=0
tot=0
###################################################################
# PROCESS YOUTUBEID VIDEO DOWNLOAD AND CREATE TIDDLER in TW
###################################################################
while read LINE;
    do
    boucle=$((boucle+1))
    echo "_____ $LINE _____ $boucle"
    YID="$(echo "$LINE" | rev | cut -d '=' -f 1 | rev )"

    #~ [[ $boucle -gt 50 ]] && break ## TODO SCAN FOR ABROAD SAME COPY DONE
    ### MAKE BETTER THAN RANDOM !! CONNECT TO THE WARM...

###################################################################
## Search for $YID.TW.json TIDDLER in local & MySwarm cache
    #~ echo "--- CACHE SEARCH FOR $YID ---"
    TIDDLER=$(ls -t "${HOME}/.zen/game/players/"*"/G1CopierYoutube/$YID.TW.json" 2>/dev/null | head -n 1)
    ## TODO CORRECT - CACHE CHANGED -
    [[ ! $TIDDLER ]] && TIDDLER=$(ls -t "${HOME}/.zen/tmp/${IPFSNODEID}/G1CopierYoutube/"*"/$YID.TW.json" 2>/dev/null | head -n 1)
    [[ ! $TIDDLER ]] && TIDDLER=$(ls -t "${HOME}/.zen/tmp/swarm/"*"/G1CopierYoutube/"*"/$YID.TW.json" 2>/dev/null | head -n 1)
    #~ [[ $TIDDLER ]] && echo "Tiddler Found in CACHE  : $TIDDLER" \
                              #~ || echo "EMPTY."
###################################################################

    if [[ ! ${TIDDLER} ]]; then
    ###################################################################
    # COPY VIDEO AND MAKE TIDDLER
    ###################################################################
        ZYURL=$(echo "$LINE" | cut -d '&' -f 2-)
        echo "COPIE : $ZYURL"

        ## LIMIT TO 2 MAXIMUM COPY PER DAY PER PLAYER
        [[ $tot == 3 ]] && echo "MAXIMUM COPY REACHED FOR TODAY" && break
        ## TODO ACCEPT MORE WITH COINS

        TITLE="$(/usr/local/bin/yt-dlp $BROWSER --print "%(title)s" "${ZYURL}"  | detox --inline)"
        [[ ! $TITLE ]] && echo "NO TITLE" && continue

        start=`date +%s`

        echo ".... Downloading $TITLE ${isMP3}"
        # https://github.com/yt-dlp/yt-dlp#format-selection-examples
        # SUBS ? --write-subs --write-auto-subs --sub-langs "fr, en, en-orig" --embed-subs
        # (bv*[height<=720][vcodec~='^((he|a)vc|h26[45])']+ba)
        # TODO : DELAY COPY OPERATION...  Astro can download quicker at 03:00 AM
        echo "/usr/local/bin/yt-dlp -f \"(bv*[ext=mp4][height<=720]+ba/b[height<=720])\" --no-mtime --embed-thumbnail --add-metadata -o \"${HOME}/.zen/tmp/yt-dlp/$TITLE.%(ext)s\" ${ZYURL}"

        #############################################################################
        ## COPY FROM YOUTUBE (TODO DOUBLE COPY & MKV to MP4 OPTIMISATION)
        ## EXTRA PARAM TO TRY
        #  --write-subs --write-auto-subs --sub-langs "fr, en, en-orig" --embed-subs

        if [[ ${isMP3} == "" ]]; then
        # copying video
            /usr/local/bin/yt-dlp -q -f "(bv*[ext=mp4][height<=720]+ba/b[height<=720])" \
                        $BROWSER \
                        --download-archive ${HOME}/.zen/.yt-dlp.list \
                        -S res,ext:mp4:m4a --recode mp4 --no-mtime --embed-thumbnail --add-metadata \
                        -o "${HOME}/.zen/tmp/yt-dlp/$TITLE.%(ext)s" "${ZYURL}"
            ZFILE="$TITLE.mp4"

            ############################################################################
            ### CHECK RESULT CONVERT MKV TO MP4
            [[ -s "${HOME}/.zen/tmp/yt-dlp/$TITLE.mkv"  ]] \
                && ffmpeg -loglevel quiet -i "${HOME}/.zen/tmp/yt-dlp/$TITLE.mkv" -c:v libx264 -c:a aac "${HOME}/.zen/tmp/yt-dlp/$TITLE.mp4" \
                && rm "${HOME}/.zen/tmp/yt-dlp/$TITLE.mkv"

            if [[ ! -s "${HOME}/.zen/tmp/yt-dlp/${ZFILE}"  ]]; then
                echo "No FILE -- TRYING TO RESTORE CACHE FROM TW -- ${ZFILE}"
                tiddlywiki  --load ${INDEX} \
                        --output ~/.zen/game/players/${PLAYER}/G1CopierYoutube \
                        --render '.' "$YID.TW.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' "${ZFILE}"

                if [[ -s ~/.zen/game/players/${PLAYER}/G1CopierYoutube/${YID}.TW.json ]]; then
                    rm "${HOME}/.zen/game/players/${PLAYER}/G1CopierYoutube/${ZFILE}.json" 2>/dev/null
                    cd ${HOME}/.zen/game/players/${PLAYER}/G1CopierYoutube/
                    ln -s "./${YID}.TW.json" "${ZFILE}.json"
                    cd -
                else
                    ## REMOVE FILE FROM .yt-dlp.list - RETRY NEXT TIME
                    grep -v -- "$YID" ${HOME}/.zen/.yt-dlp.list > /tmp/.yt-dlp.list
                    mv /tmp/.yt-dlp.list ${HOME}/.zen/.yt-dlp.list
                fi

                continue
            fi

        else
        # copying mp3
            echo "COPYING MP3 (!-q)"
            /usr/local/bin/yt-dlp -x --no-mtime --audio-format mp3 --embed-thumbnail --add-metadata \
                        $BROWSER \
                        --download-archive ${HOME}/.zen/.yt-dlp.mp3.list \
                        -o "${HOME}/.zen/tmp/yt-dlp/$TITLE.%(ext)s" "${ZYURL}"

            ZFILE="$TITLE.mp3"
        fi

        echo

    ####################################################
        [[ -s ~/.zen/tmp/yt-dlp/${ZFILE} ]] \
            && echo "FOUND : ~/.zen/tmp/yt-dlp/${ZFILE}"

        FILE_BSIZE=$(du -b "${HOME}/.zen/tmp/yt-dlp/${ZFILE}" | awk '{print $1}')
        [[ ! $FILE_BSIZE ]] && echo "SIZE ERROR" && continue

        FILE_SIZE=$(echo "${FILE_BSIZE}" | awk '{ split( "B KB MB GB TB PB" , v ); s=1; while( $1>1024 ){ $1/=1024; s++ } printf "%.2f %s", $1, v[s] }')
        echo "$boucle - ${ZFILE} - FILE SIZE = $FILE_SIZE ($FILE_BSIZE octets)"
        echo

        ### CREATE GIF ANIM : make_video_gifanim_ipfs.sh
        [[ ${isMP3} == "" ]] \
            && $(${MY_PATH}/../tools/make_video_gifanim_ipfs.sh "${HOME}/.zen/tmp/yt-dlp" "${ZFILE}" | tail -n 1) \
            && echo "HOP=$HOP
        ANIMH=$ANIMH
        PROBETIME=$PROBETIME
        DURATION=$DURATION
        DUREE=$DUREE
        RES=$RES
        MIME=$MIME
        VTRATIO=$VTRATIO
        file=$file"

        ## Create gifanime ##  TODO Search for similarities BEFORE ADD
        echo "Adding to IPFS"
        ILINK=$(ipfs add -q "${HOME}/.zen/tmp/yt-dlp/${ZFILE}" | tail -n 1)
        echo "/ipfs/$ILINK === ${ZFILE}"

        [[ $ILINK == "" ]] && echo ">>>>> BIG PROBLEM PAPA. NO IPFS " && continue

        MIME=$(file --mime-type -b "${HOME}/.zen/tmp/yt-dlp/${ZFILE}")

        ## ADD TAGS
        SEC=$(/usr/local/bin/yt-dlp $BROWSER --print "%(duration)s" "${ZYURL}")
        CHANNEL=$(/usr/local/bin/yt-dlp $BROWSER --print "%(channel)s" "${ZYURL}" | sed -r 's/\<./\U&/g' | sed 's/ //g') # CapitalGluedWords
        PLAYLIST=$(/usr/local/bin/yt-dlp $BROWSER --print "%(playlist)s" "${ZYURL}" | sed -r 's/\<./\U&/g' | sed 's/ //g')
        EXTRATAG="$CHANNEL $PLAYLIST"

        if [[ ${isMP3} == "" ]]; then
        ## PREPARE VIDEO HTML5 CODE
            TEXT="<video controls width=100% poster='/ipfs/"${ANIMH}"'>
            <source src='/ipfs/"${ILINK}"' type='"${MIME}"'>
            Your browser does not support the video element.
            </video>
            <br>
            {{!!filesize}} - {{!!duration}} sec. - vtratio(dur) =  {{!!vtratio}} ({{!!dur}})
            <br>
            <h1><a target='_blank' href='"${ZYURL}"'>Web2.0 Origin</a></h1>"

        else
            TEXT="<audio controls>
            <source src='/ipfs/"${ILINK}"' type='"${MIME}"'>
            Your browser does not support the audio element.
            </audio>
            <br>
            {{!!filesize}} - {{!!duration}} sec. - vtratio(dur) =  {{!!vtratio}} ({{!!dur}})
            <br>
            <h1><a target='_blank' href='"${ZYURL}"'>Web2.0 Origin</a></h1>"

        fi

        end=`date +%s`
        dur=`expr $end - $start`

        echo "Creating Youtube \"${YID}\" tiddler : G1CopierYoutube !"

        CTITLE=$(echo ${ZFILE} | sed 's~_~ ~g' | sed 's~\.~ ~g')

        ## WAN ADD <<hide tiddler-controls>> TO text jq 'map(.text += "<<hide tiddler-controls>>")'
        [[ ! isLAN ]] && TEXT="$TEXT <<hide tiddler-controls>>"
        echo $TEXT

        mkdir -p ${HOME}/.zen/tmp/${IPFSNODEID}/G1CopierYoutube/${PLAYER} ## MISSING FOR FIRST RUN
        TIDDLER="${HOME}/.zen/tmp/${IPFSNODEID}/G1CopierYoutube/${PLAYER}/${YID}.TW.json"

        echo '[
      {
        "created": "'${MOATS}'",
        "resolution": "'${RES}'",
        "duree": "'${DUREE}'",
        "duration": "'${DURATION}'",
        "giftime": "'${PROBETIME}'",
        "gifanime": "'/ipfs/${ANIMH}'",
        "modified": "'${MOATS}'",
        "title": "'${ZFILE}'",
        "type": "'text/vnd.tiddlywiki'",
        "vtratio": "'${VTRATIO}'",
        "text": "'$TEXT'",
        "g1pub": "'${G1PUB}'",
        "mime": "'${MIME}'",
        "size": "'${FILE_BSIZE}'",
        "filesize": "'${FILE_SIZE}'",
        "sec": "'${SEC}'",
        "dur": "'${dur}'",
        "ipfs": "'/ipfs/${ILINK}'",
        "youtubeid": "'${YID}'",
        "zurl": "'${ZYURL}'",
        "issuer": "'${PLAYER}'",
        "tags": "'ipfs G1CopierYoutube ${PLAYER} ${EXTRATAG} ${MIME} ${CTITLE}'"
      }
    ]
    ' > ${TIDDLER}

            tot=$((tot+1))

    else
        ###################################################################
        #~ echo "${TIDDLER} FOUND"
        ###################################################################
        ## TODO : ADD EMAIL TAG ( TIMESTAMP & ADD SIGNATURE over existing ones)
        continue
    fi

    cp -f "${TIDDLER}" "${HOME}/.zen/game/players/${PLAYER}/G1CopierYoutube/"


#################################################################
### ADDING $YID.TW.json to ASTRONAUTENS INDEX.html
#################################################################
    echo "=========================="
    echo "Adding $YID tiddler to TW /ipns/$ASTRONAUTENS "

    rm -f ~/.zen/tmp/${IPFSNODEID}/newindex.html

    echo  ">>> Importing ${TIDDLER}"

    tiddlywiki --load ${INDEX} \
                    --import "${TIDDLER}" "application/json" \
                    --output ~/.zen/tmp/${IPFSNODEID} --render "$:/core/save/all" "newindex.html" "text/plain"

    if [[ -s ~/.zen/tmp/${IPFSNODEID}/newindex.html ]]; then

        ## COPY JSON TIDDLER TO PLAYER
        cd ${HOME}/.zen/game/players/${PLAYER}/G1CopierYoutube/
        ln -s "./$YID.TW.json" "${ZFILE}.json"
        cd -

        [[ $(diff ~/.zen/tmp/${IPFSNODEID}/newindex.html ${INDEX} ) ]] \
            && mv ~/.zen/tmp/${IPFSNODEID}/newindex.html ${INDEX} \
            && echo "===> Mise à jour ${INDEX}"

        ## PUBLISH NIP-71 VIDEO EVENT VIA MULTIPASS NOSTR KEY
        ## (UPlanet_FILE_CONTRACT.md §3.2 — kind 21/22 → appears in UPassport youtube.html)
        echo "Publishing NIP-71 video event via MULTIPASS NOSTR key..."
        publish_nip71_video \
            "$PLAYER" \
            "${HOME}/.zen/tmp/yt-dlp/${ZFILE}" \
            "$ILINK" \
            "$ANIMH" \
            "$TITLE" \
            "$MIME" \
            "$SEC" \
            "$RES" \
            "$CHANNEL" \
            "$ZYURL"

    else
        echo "Problem with tiddlywiki command. Missing ~/.zen/tmp/${IPFSNODEID}/newindex.html"
        echo "XXXXXXXXXXXXXXXXXXXXXXX"
        break
    fi

done  < ~/.zen/tmp/${IPFSNODEID}/yt-dlp.cache.${PLAYER} # FINISH YID loop 1

## COPY PLAYER CACHE TO STATION SWARM CACHE
cp -r ${HOME}/.zen/game/players/${PLAYER}/G1CopierYoutube/* \
    ~/.zen/tmp/${IPFSNODEID}/G1CopierYoutube/${PLAYER}/

exit 0
