#!/bin/bash
########################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# COPY ~/Astroport/${PLAYER}/* files to IPFS
# Publish INDEX ~/.zen/game/players/$PLAYER/ipfs/.*/${PREFIX}ASTRXBIAN
######## #### ### ## #
start=`date +%s`

exec 2>&1 >> ~/.zen/tmp/ajouter_media.log

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/my.sh"

ME="${0##*/}"
countMErunning=$(pgrep -au $USER -f "$ME" | wc -l)
[[ $countMErunning -gt 2 ]] && echo "$ME already running $countMErunning time" && exit 0

YOU=$(pgrep -au $USER -f "ipfs daemon" > /dev/null && echo "$USER")
[[ ! $IPFSNODEID ]] && echo 'ERROR missing IPFS Node id !! IPFS is not responding !?' && exit 1

alias zenity='zenity 2> >(grep -v GtkDialog >&2)'

# Function to send email notification on NOSTR failure
send_nostr_failure_email() {
    local player="$1"
    local mediakey="$2"
    local title="$3"
    local ipfs_link="$4"
    
    # Check if mailjet.sh exists
    if [[ ! -f "$MY_PATH/mailjet.sh" ]]; then
        echo "⚠️  mailjet.sh not found, cannot send failure notification email"
        return 1
    fi
    
    # Check if player email is valid
    if [[ ! "$player" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        echo "⚠️  Invalid player email format: $player, cannot send failure notification email"
        return 1
    fi
    
    # Create temporary message file
    local temp_message_file="$HOME/.zen/tmp/nostr_failure_${mediakey}.txt"
    cat > "$temp_message_file" << EOF
NOSTR Message Failure Notification

Dear ${player},

The NOSTR message for your media could not be sent successfully.

Media Details:
- Title: ${title}
- Media Key: ${mediakey}
- IPFS Link: ${myIPFS}${ipfs_link}
- Timestamp: $(date -u)

The media has been successfully added to your Astroport TiddlyWiki and IPFS, but the public NOSTR announcement failed.

This could be due to:
- Network connectivity issues
- Relay server problems
- NOSTR key configuration issues

Your media is still available at: ${ipfs_link}

Please check your NOSTR configuration or try again later.

Best regards,
Astroport.ONE System
EOF
    
    # Send email using mailjet.sh
    echo "📧 Sending NOSTR failure notification email to ${player}"
    $MY_PATH/mailjet.sh "$player" "$temp_message_file" "NOSTR Message Failure - ${title}" 2>/dev/null
    
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

# Function to send media as public NOSTR message
send_media_nostr_message() {
    local player="$1"
    local mediakey="$2"
    local title="$3"
    local description="$4"
    local ipfs_link="$5"
    local mime_type="$6"
    local file_size="$7"
    local duration="$8"
    local resolution="$9"
    local hashtags="${10}"
    local g1pub="${11}"
    local subtitles_desc="${12}"
    local comments_link="${13}"
    
    # Check if player has NOSTR keys
    if [[ ! -f ~/.zen/game/nostr/${player}/.secret.nostr ]]; then
        echo "No NOSTR keys found for player ${player}, skipping NOSTR message"
        return 0
    fi
    
    # Load NOSTR keys
    source ~/.zen/game/nostr/${player}/.secret.nostr
    if [[ -z "$NSEC" ]]; then
        echo "No NSEC found for player ${player}, skipping NOSTR message"
        return 0
    fi
    
    # Convert NSEC to hex
    NPRIV_HEX=$($MY_PATH/nostr2hex.py "$NSEC")
    if [[ -z "$NPRIV_HEX" ]]; then
        echo "Failed to convert NSEC to hex for player ${player}, skipping NOSTR message"
        return 0
    fi
    
    # Build NOSTR message content
    local nostr_content="🎬 New Media Added: ${title}"
    
    if [[ -n "$description" ]]; then
        nostr_content="${nostr_content}

📝 ${description}"
    fi
    
    nostr_content="${nostr_content}

🔗 IPFS: ${ipfs_link}"
    
    if [[ -n "$file_size" ]]; then
        nostr_content="${nostr_content}
📊 Size: ${file_size}"
    fi
    
    if [[ -n "$duration" ]]; then
        nostr_content="${nostr_content}
⏱️ Duration: ${duration}"
    fi
    
    if [[ -n "$resolution" ]]; then
        nostr_content="${nostr_content}
📺 Resolution: ${resolution}"
    fi
    
    nostr_content="${nostr_content}

#Astroport #Media #IPFS"
    
    if [[ -n "$hashtags" ]]; then
        nostr_content="${nostr_content} ${hashtags}"
    fi

    # Optional extras
    if [[ -n "$subtitles_desc" ]]; then
        nostr_content="${nostr_content}

🗒️ Subtitles: ${subtitles_desc}"
    fi

    if [[ -n "$comments_link" ]]; then
        nostr_content="${nostr_content}

💬 Comments: ${comments_link}"
    fi
    
    # Send NOSTR message to primary relay
    echo "Sending NOSTR message for media: ${mediakey}"
    nostpy-cli send_event \
        -privkey "$NPRIV_HEX" \
        -kind 1 \
        -content "$nostr_content" \
        -tags "[['t', 'AstroportMedia'], ['t', 'Media'], ['t', 'IPFS'], ['r', '${ipfs_link}'], ['g1pub', '${g1pub}'], ['mediakey', '${mediakey}'], ['mime', '${mime_type}']]" \
        --relay "$myRELAY" 2>/dev/null
    
    local primary_result=$?
    if [[ $primary_result -eq 0 ]]; then
        echo "✅ NOSTR message sent successfully to primary relay for ${mediakey}"
    else
        echo "❌ Failed to send NOSTR message to primary relay for ${mediakey}"
    fi

}

########################################################################
path="$1"

if [[ "$path" == "" ]]; then
    echo "## BATCH RUN. READ FIFO FILE."
fi

# Add trailing / if needed
length=${#path}
last_char=${path:length-1:1}
[[ $last_char != "/" ]] && path="$path/" || true

file="$2"

G1PUB="$3"
PLAYER="$4"

### ECHO COMMAND RECEIVED :
echo "FOUNIR 'PATH' 'FILE' et 'G1PUB' du PLAYER inscrit sur la STATION"
echo "$MY_PATH/new_file_in_astroport.sh PATH/ \"$path\" FILE \"$file\" G1PUB \"$G1PUB\" PLAYER \"$PLAYER\" "

################################################
## FILE ANALYSE & IDENTIFICATION TAGGINGS
extension="${file##*.}"
TITLE="${file%.*}"
# CapitalGluedTitle
CapitalGluedTitle=$(echo "${TITLE}" | sed -r 's/\<./\U&/g' | sed 's/ //g')

# .part file false flag correcting (in case inotify has launched script)
#~ [[ ! -f "${path}${file}" ]] && file="${TITLE%.*}" && extension="${TITLE##*.}" && [[ ! -f "${path}${file}" ]] && er="NO FILE" && echo "$er" && exit 1

MIME=$(file --mime-type -b "${path}${file}")

############# EXTEND MEDIAKEY IDENTIFATORS https://github.com/NapoleonWils0n/ffmpeg-scripts
if [[ $(echo "$MIME" | grep 'video') ]]; then
    ## Create gifanime ##
    echo "(✜‿‿✜) GIFANIME (✜‿‿✜)"
    $(${MY_PATH}/make_video_gifanim_ipfs.sh "$path" "$file" | tail -n 1)
    echo "HOP=$HOP ANIMH=$ANIMH PROBETIME=$PROBETIME DURATION=$DURATION DUREE=$DUREE RES=$RES MIME=$MIME VTRATIO=$VTRATIO file=$file"
    #~ [[ -s "${path}${file}.mp4" ]] && file="${file}.mp4"
    echo "$DUREE GIFANIM ($PROBETIME) : /ipfs/$ANIMH"
fi

########################################################################
# GET CONNECTED PLAYER
########################################################################
[[ ! $G1PUB ]] && G1PUB=$(cat ~/.zen/game/players/.current/.g1pub 2>/dev/null)
[[ ! $PLAYER ]] && PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null);
[[ ! $PLAYER ]] && echo "(╥☁╥ ) No player. Please Login" && exit 1

# NOT CURRENT PLAYER (CHECK FOR TW & KEY)
if [[ $(ipfs key list -l | grep -w $G1PUB) ]]; then
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    echo "(ᵔ◡◡ᵔ) INVITATION $G1PUB"
    ASTRONS=$($MY_PATH/g1_to_ipfs.py "$G1PUB")
    $MY_PATH/TW.cache.sh ${ASTRONS} ${MOATS}
else
    echo "(╥☁╥ ) I cannot help you"
fi
########################################################################
## Indicate IPFSNODEID copying
mkdir -p ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}

### SOURCE IS ~/Astroport/${PLAYER}/ !!
[[ ! $(echo "$path" | cut -d '/' -f 4 | grep 'Astroport') ]] \
    && er="Les fichiers sont à placer dans ~/Astroport/${PLAYER}/ MERCI" \
    && echo "$er" && exit 1

### TyPE & type & T = related to ~/astroport location of the infile (mimetype subdivision)
TyPE=$(echo "$path" | cut -d '/' -f 6) # ex: /home/$YOU/Astroport/${PLAYER}/... TyPE(film, youtube, mp3, video, pdf)/ REFERENCE /
type=$(echo "$TyPE" | awk '{ print tolower($0) }')
PREFIX=$(echo "$TyPE" | head -c 1 | awk '{ print toupper($0) }' ) # ex: F, Y, M ou Y (all the alaphabet can address a data type

# File cannot be without "TyPE" in ~/astroport
if [[ $PREFIX == "" ]]
then
    [[ ! $3 ]] && [[ "$USER" != "xbian" ]] && zenity --warning --width 300 --text "Désolé votre fichier ne peut pas être traité"
    er="$er | WARNING. $TyPE is root file UNTREATED" && echo "$er" && exit 1
fi

########################################################################
# EXTRACT INDEX REFERENCE : TMDB or YOUTUBE (TODO : EXTEND)
########################################################################
case ${type} in
    video)
        INDEXPREFIX="VIDEO_"
        REFERENCE=$(echo "$path" | cut -d '/' -f 7 )
        TITLE="${file%.*}"
    ;;
    youtube)
        INDEXPREFIX="YOUTUBE_"
        REFERENCE=$(echo "$path" | cut -d '/' -f 7 )
        TITLE="${file%.*}"
    ;;
    pdf)
        INDEXPREFIX="PDF_"
        REFERENCE=$(echo "$path" | cut -d '/' -f 7 )
        TITLE="${file%.*}"
    ;;
    mp3)
        INDEXPREFIX="MP3_"
        REFERENCE=$(echo "$path" | cut -d '/' -f 7 )
        TITLE="${file%.*}"
    ;;
    film | serie)
        INDEXPREFIX="TMDB_"
        REFERENCE=$(echo "$path" | cut -d '/' -f 7 ) # Path contains TMDB id
        if ! [[ "$REFERENCE" =~ ^[0-9]+$ ]] # ${REFERENCE} NOT A NUMBER
        then
            er="$er | ERROR: $path BAD TMDB code. Get it from https://www.themoviedb.org/ or use your a mobile phone number ;)"
            echo "$er"
            exit 1
        fi
    ;;
    *)
        INDEXPREFIX=$(echo "$type" | awk '{ print toupper($0) }')
        REFERENCE=$(echo "$path" | cut -d '/' -f 7 )
        echo "Media type $INDEXPREFIX REFERENCE : $REFERENCE"
        [[ ${INDEXPREFIX} == "" ||  ${REFERENCE} ==  "" ]] && echo "Must put file in ~/Astroport/${PLAYER}/${type}/REFERENCE" && exit 1
    ;;

esac

### SET MEDIAKEY (PROVIDED IN BATCH FROM AJOUTER MEDIA)
[[ $MEDIAKEY == "" ]] && MEDIAKEY="${INDEXPREFIX}${REFERENCE}"
echo ">>>>>>>>>> $MEDIAKEY ($MIME) <<<<<<<<<<<<<<<"

########################################################################
# Check if file exists and is not empty
[[ -z "$file" ]] && echo "ERROR: No file specified" && exit 1
[[ ! -f "${path}${file}" ]] && echo "ERROR: File ${path}${file} not found" && exit 1

    echo "ADDING ${path}${file} to IPFS "
echo "-----------------------------------------------------------------"

### FILE SIZING ####
FILE_BSIZE=$(du -b "${path}${file}" | awk '{print $1}')
FILE_SIZE=$(echo "${FILE_BSIZE}" | awk '{ split( "B KB MB GB TB PB" , v ); s=1; while( $1>1024 ){ $1/=1024; s++ } printf "%.2f %s", $1, v[s] }')

################################
###########################################
###########################################################
### IPFS ADD ###########################################################
###########################################################
startipfs=`date +%s`

echo "ADDING FILE SIZE = $FILE_SIZE ($FILE_BSIZE octets)"
espeak "Adding $FILE_SIZE file" 2>&1 > /dev/null
IPFS=$(ipfs add -wq "${path}${file}")
IPFSREPFILEID=$(echo $IPFS | cut -d ' ' -f 2)
IPFSID=$(echo $IPFS | cut -d ' ' -f 1)
[[ $IPFSREPFILEID == "" ]] && echo "ipfs add ERROR" && exit 1

end=`date +%s`
ipfsdur=`expr $end - $startipfs`
echo "IPFS ADD time was $ipfsdur seconds. $URLENCODE_FILE_NAME"

URLENCODE_FILE_NAME=$(echo ${file} | jq -Rr @uri)

########################################################################
# Detect YouTube sidecar files (subtitles, comments, infojson)
########################################################################
SUBTITLES_JSON="[]"
SUBTITLES_DESC=""
COMMENTS_IPFS=""
INFO_IPFS=""

base_no_ext="${file%.*}"

# Subtitles: *.vtt (all languages), optional *.srt
subtitle_files=( $(ls "${path}"${base_no_ext}.*.vtt 2>/dev/null) )
if [[ ${#subtitle_files[@]} -gt 0 ]]; then
    tmp_subs_json="["
    first=true
    for subf in "${subtitle_files[@]}"; do
        [[ ! -f "$subf" ]] && continue
        sub_cid=$(ipfs add -q "$subf" | tail -n 1)
        lang=$(basename "$subf")
        lang=${lang#${base_no_ext}.}
        lang=${lang%.*}
        # Build JSON array and description list
        if $first; then
            first=false
        else
            tmp_subs_json+=" ,"
        fi
        tmp_subs_json+="{\"lang\":\"${lang}\",\"ipfs\":\"/ipfs/${sub_cid}\"}"
        # Human-readable list for NOSTR
        if [[ -z "$SUBTITLES_DESC" ]]; then
            SUBTITLES_DESC="${lang}"
        else
            SUBTITLES_DESC="${SUBTITLES_DESC}, ${lang}"
        fi
    done
    tmp_subs_json+="]"
    SUBTITLES_JSON="$tmp_subs_json"
fi

# Comments JSON
if [[ -f "${path}${base_no_ext}.comments.json" ]]; then
    COMMENTS_IPFS=$(ipfs add -q "${path}${base_no_ext}.comments.json" | tail -n 1)
fi

# Info JSON
if [[ -f "${path}${base_no_ext}.info.json" ]]; then
    INFO_IPFS=$(ipfs add -q "${path}${base_no_ext}.info.json" | tail -n 1)
fi

########################################################################
# type TW PUBLISHING
########################################################################
if [[ "${type}" =~ ^(pdf|film|serie|youtube|video|mp3)$ ]]
then

    ## ASK FOR EXTRA METADATA
    [[ ! $3 ]] && OUTPUT=$(zenity --forms --width 480 --title="METADATA" --text="Metadonnées (séparateur espace)" --separator="~" --add-entry="Description" --add-entry="extra tag(s)")
    [[ ! $3 ]] && DESCRIPTION=$(awk -F '~' '{print $1}' <<<$OUTPUT)
    [[ ! $3 ]] && HASHTAG=$(awk -F '~' '{print $2}' <<<$OUTPUT)

    # # # # ${MOATS}_ajouter_video.txt DATA # # # #
    if [[ -f ~/Astroport/${PLAYER}/${TyPE}/${REFERENCE}/ajouter_video.txt ]]
    then
        line=$(cat ~/Astroport/${PLAYER}/${TyPE}/${REFERENCE}/ajouter_video.txt | sed "s/_IPFSREPFILEID_/$IPFSREPFILEID/g" | sed "s/_IPNSKEY_/$IPNS/g" )
    else
        line="$type;${REFERENCE};$YEAR;$TITLE;$SAISON;;${IPNS};$RES;/ipfs/$IPFSREPFILEID/$URLENCODE_FILE_NAME"
    fi
    echo "-------------------- ${MOATS}_ajouter_video.txt  -----------------------------"
    echo "$line"
    echo "UPDATE ~/Astroport/${PLAYER}/${TyPE}/${REFERENCE}/ajouter_video.txt"
    echo "$line" > ~/Astroport/${PLAYER}/${TyPE}/${REFERENCE}/${MOATS}_ajouter_video.txt

    echo "----------------- GETTING  METADATA ----------------------"
    CAT=$(echo "$type" | sed -r 's/\<./\U&/g' | sed 's/ //g') # CapitalGluedWords
    GENRE=$(cat ~/Astroport/${PLAYER}/${TyPE}/${REFERENCE}/${MOATS}_ajouter_video.txt | cut -d ';' -f 6 | sed 's/|/ /g' | jq -r '@csv' | sed 's/ /_/g' | sed 's/,/ /g' | sed 's/\"//g' )
    YEAR=$(cat ~/Astroport/${PLAYER}/${TyPE}/${REFERENCE}/${MOATS}_ajouter_video.txt | cut -d ';' -f 3 )

    ## Adapt TMDB url for season & tag naming
    [[ $CAT == "Film" ]] \
    && TITLE="$TITLE ($YEAR)" \
    && H1="<h1><a target='tmdb' href='https://www.themoviedb.org/movie/"${REFERENCE}"'>"${TITLE}"</a></h1>" \
    && FILETAG="$CapitalGluedTitle"

    [[ $CAT == "Serie" ]] && H1="<h1><a target='tmdb' href='https://www.themoviedb.org/tv/"${REFERENCE}"'>"${TITLE}"</a></h1>" \
    && SAISON=$(cat ~/Astroport/${PLAYER}/${TyPE}/${REFERENCE}/${MOATS}_ajouter_video.txt | cut -d ';' -f 5 | cut -d '_' -f 2) \
    && FILETAG=$(echo "$CapitalGluedTitle" | cut -d '_' -f 1)

    [[ $CAT == "Youtube" ]] \
    && H1="<h1><a target='youtube' href='https://www.youtube.com/watch?v="$(echo ${REFERENCE} | rev | cut -d '_' -f 1 | rev)"'>"${TITLE}"</a></h1>" \
    && PATCH="Copier"

    [[ $CAT == "Mp3" ]] \
    && H1="<h1>🎵 ${TITLE}</h1>" \
    && PATCH="Audio"

    echo $GENRE $SAISON

    ## Add screenshot
    [[ -f $HOME/Astroport/${PLAYER}/${TyPE}/${REFERENCE}/screen.png ]] \
    && SCREEN=$(ipfs add -q "$HOME/Astroport/${PLAYER}/${TyPE}/${REFERENCE}/screen.png" | tail -n 1)


    if [[ $(echo "$MIME" | grep 'video') ]]; then

        TEXT="<video controls width=100% poster='/ipfs/"${ANIMH}"'><source src='/ipfs/"${IPFSID}"' type='"${MIME}"'></video>
        <br>{{!!filesize}} - {{!!duration}} sec. - vtratio(dur) =  {{!!vtratio}} ({{!!dur}})<br>
        "$H1"<h2>"$DESCRIPTION"</h2>"

        # Append subtitles and comments links if available
        if [[ "$SUBTITLES_JSON" != "[]" ]]; then
            TEXT="${TEXT}<br>Subtitles: ${SUBTITLES_DESC}"
        fi
        if [[ -n "$COMMENTS_IPFS" ]]; then
            TEXT="${TEXT}<br>Comments: <a href='${myLIBRA}/ipfs/${COMMENTS_IPFS}'>IPFS</a>"
        fi

        TidType="text/vnd.tiddlywiki" ## MAYBE REAL ONCE TW CAN SHOW ATTACHED IPFS VIDEO (TODO: TESTINGS)
        TAGS="G1${PATCH}${CAT} ${PLAYER} ${FILETAG} $SAISON $GENRE ipfs ${HASHTAG} $YEAR $MIME"
        # TyPE="$MIME"
        # CANON="/ipfs/"${IPFSID}
        CANON=''
    elif [[ $(echo "$MIME" | grep 'audio') ]]; then

        TEXT="<audio controls width=100%><source src='/ipfs/"${IPFSID}"' type='"${MIME}"'></audio>
        <br>{{!!filesize}} - {{!!duration}} sec.<br>
        "$H1"<h2>"$DESCRIPTION"</h2>"

        TidType="text/vnd.tiddlywiki"
        TAGS="G1${PATCH}${CAT} ${PLAYER} ${FILETAG} $SAISON $GENRE ipfs ${HASHTAG} $YEAR $MIME"
        CANON=''
    else
        TidType="${MIME}"
        TITLE="$TITLE.$CAT"
        TEXT='${MEDIAKEY}'
        TAGS="'$:/isAttachment $:/isIpfs G1${CAT} ${PLAYER} ${CapitalGluedTitle} $GENRE ${HASHTAG}"
        CANON="/ipfs/"${IPFSID}
    fi

    ## Archive previous dragdrop.json
    [[ -s ~/Astroport/${PLAYER}/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json ]] \
    && cp ~/Astroport/${PLAYER}/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json ~/Astroport/${PLAYER}/${TyPE}/${REFERENCE}/${MOATS}.${MEDIAKEY}.dragdrop.json

    echo "## Creation json tiddler"
    echo '[
  {
    "text": "'${TEXT}'",
    "title": "'${TITLE//_/ }'",
    "season": "'${SAISON}'",
    "created": "'${MOATS}'",
    "resolution": "'${RES}'",
    "duree": "'${DUREE}'",
    "duration": "'${DURATION}'",
    "giftime": "'${PROBETIME}'",
    "vtratio": "'${VTRATIO}'",
    "screen": "'/ipfs/${SCREEN}'",
    "gifanime": "'/ipfs/${ANIMH}'",
    "type": "'${TidType}'",
    "mime": "'${MIME}'",
    "dur": "'${ipfsdur}'",
    "cat": "'${CAT}'",
    "filesize": "'${FILE_SIZE}'",
    "size": "'${FILE_BSIZE}'",
    "description": "'${DESCRIPTION}'",
    "g1pub": "'${G1PUB}'",
    "ipfsroot": "'/ipfs/${IPFSREPFILEID}'",
    "file": "'${file}'",
    "ipfs": "'/ipfs/${IPFSREPFILEID}/${URLENCODE_FILE_NAME}'",
    "mediakey": "'${MEDIAKEY}'",
    "ipns": "'/ipns/${IPNS}'",
    "tmdb": "'${REFERENCE}'",
    "modified": "'${MOATS}'",
    "issuer": "'${PLAYER}'",
    "tags": "'${TAGS}'",
    "subtitles": '"${SUBTITLES_JSON}"',
    "comments": "'/ipfs/${COMMENTS_IPFS}'",
    "info": "'/ipfs/${INFO_IPFS}'"
  ' > ~/Astroport/${PLAYER}/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json

    [[ ${CANON} != "" ]] && echo  ',
    "_canonical_uri": "'${CANON}'"' >> ~/Astroport/${PLAYER}/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json

    echo '
  }
]
' >> ~/Astroport/${PLAYER}/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json

#############################################################################
## ARCHIVE FOR IPFSNODEID CACHE SHARING (APPNAME=KEY)
#~ mkdir -p "$HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MIME}/${MEDIAKEY}/${G1PUB}/"
#~ cp ~/Astroport/${PLAYER}/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json \
    #~ "$HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MIME}/${MEDIAKEY}/${G1PUB}/tiddler.json"
#############################################################################


    # echo "SEND TW LINK to GCHANGE MESSAGE & MULTIPASS nostr messaging"
    if [[ -n $3 ]]; then
        ~/.zen/Astroport.ONE/tools/timeout.sh -t 12 ~/.zen/Astroport.ONE/tools/jaklis/jaklis.py \
        -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "$myDATA" send -d "$3" \
        -t "${TITLE} ${MEDIAKEY}" -m "MEDIA : $myIPFSGW/ipfs/${IPFSREPFILEID}"

        ## SEND MEDIA AS PUBLIC NOSTR MESSAGE
        echo "Sending media as public NOSTR message..."
        # Build optional extras for NOSTR
        SUBS_DESC_NOSTR="$SUBTITLES_DESC"
        COMMENTS_LINK_NOSTR=""
        if [[ -n "$COMMENTS_IPFS" ]]; then
            COMMENTS_LINK_NOSTR="${myLIBRA}/ipfs/${COMMENTS_IPFS}"
        fi

        send_media_nostr_message \
            "$PLAYER" \
            "$MEDIAKEY" \
            "$TITLE" \
            "$DESCRIPTION" \
            "$myLIBRA/ipfs/${IPFSREPFILEID}/${URLENCODE_FILE_NAME}" \
            "$MIME" \
            "$FILE_SIZE" \
            "$DUREE" \
            "$RES" \
            "$HASHTAG" \
            "$G1PUB" \
            "$SUBS_DESC_NOSTR" \
            "$COMMENTS_LINK_NOSTR"

    fi

fi

########################################################################
## COPY LOCALHOST IPFS URL TO CLIPBOARD
[[ $(which xclip) ]] &&\
        echo "$myIPFS/ipfs/$IPFSREPFILEID/$URLENCODE_FILE_NAME" | xclip -selection c
########################################################################

########################################################################
# echo "DUNIKEY PASS $PASS"
echo "NEW $TyPE ($file) ADDED. $myIPFS/ipfs/$IPFSREPFILEID/$URLENCODE_FILE_NAME"
#~ echo "VIDEO IPNS LINK : $myIPFS/ipns/$KEY/$G1PUB/  = Create 'G1${CAT}.sh' to adapt 20H12 Ŋ1 process"
echo "#### EXCECUTION TIME"
end=`date +%s`
dur=`expr $end - $start`
echo ${MOATS}:${G1PUB}:${PLAYER}:NewFile:$dur:${MEDIAKEY} >> ~/.zen/tmp/${IPFSNODEID}/_timings
cat ~/.zen/tmp/${IPFSNODEID}/_timings | tail -n 1
echo "########################################################################"


[[ ! $3 ]] && zenity --warning --width 300 --text "Votre MEDIA a rejoint ASTROPORT en `expr $end - $start` secondes"

## last line catching
echo "~/Astroport/${PLAYER}/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json"

exit 0


