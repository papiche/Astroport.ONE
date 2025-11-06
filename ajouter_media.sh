#!/bin/bash
########################################################################
# Author: Fred (support@qo-op.com)
# Version: 1.0
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# SCRIPT INTERACTIF POUR AJOUTER UN FICHIER à ASTROPORT/TW
#
# 1. CAT: film, serie
# 2. TMDB: ID de la fiche sur https://www.themoviedb.org/
# 3. TITLE:  Titre de la vidéo
# 4. YEAR: Année de la vidéo
# 5. RES: Résolution 1080p, 4K, SD, 720, HD
# 6. SAISON: Pour les séries, c'est le numéro de saison.
# Pour un film, le champ SAISON est utilisé pour renseigner la Saga
# 7. GENRES: Action, Aventure, Fantastique, Animation, etc (choix multiple).
# 8. GROUPES: Stocker la clef IPNS du MEDIAKEY.
#
# https://github.com/Kodi-vStream/venom-xbmc-addons/wiki/Voir-et-partager-sa-biblioth%C3%A8que-priv%C3%A9e#d%C3%A9clarer-des-films
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized

#~ LOWMODE=$(sudo systemctl status ipfs | grep disabled) ## IPFS DISABLED - START ONLY FOR SYNC -
#~ # echo "$USER ALL=(ALL) NOPASSWD:/bin/systemctl" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/systemctl')
#~ if [[ $LOWMODE != "" ]]; then
    #~ espeak "Low Mode"
    #~ sudo systemctl start ipfs
#~ fi

#~ ########################################################################
# REMOVE GtkDialog errors for zenity
shopt -s expand_aliases
alias zenity='zenity 2> >(grep -v GtkDialog >&2)'
alias espeak='espeak >/dev/null 2>&1'

## CHECK IF IPFS DAEMON IS STARTS WELL
floop=0
while [[ ! $(netstat -tan | grep 5001 | grep LISTEN) ]]; do
    sleep 1
    ((floop++)) && [ $floop -gt 5 ] \
        && echo "ERROR. IPFS daemon not running on port 5001" \
        && espeak 'ERROR. I P F S daemon not running' \
        &&  exit 1
done

. "${MY_PATH}/tools/my.sh"
[[ $IPFSNODEID == "" ]] && echo "IPFSNODEID manquant" && espeak "IPFS NODE ID Missing" && exit 1


start=`date +%s`

########################################################################
[[ $(which ipfs) == "" ]] && echo "ERREUR! Installez ipfs" && exit 1
[[ $(which zenity) == "" ]] && echo "ERREUR! Installez zenity" && echo "sudo apt install zenity" && exit 1
[[ $(which ffmpeg) == "" ]] && echo "ERREUR! Installez ffmpeg" && echo "sudo apt install ffmpeg" && exit 1
[[ $(which xdpyinfo) == "" ]] && echo "ERREUR! Installez x11-utils" && echo "sudo apt install x11-utils" && exit 1
[[ $(which tiddlywiki) == "" ]] && echo "ERREUR! Installez tiddlywiki" && echo "sudo npm install -g tiddlywiki" && exit 1

mkdir -p ~/.zen/tmp/
exec 2>&1 >> ~/.zen/tmp/ajouter_media.log

URL="$1"
PLAYER="$2"
CHOICE="$3"
echo ">>> RUNNING 'ajouter_media.sh' URL=$URL PLAYER=$PLAYER CHOICE=$CHOICE"

# Check who is PLAYER  ?
if [[ ${PLAYER} == "" ]]; then

    players=($(ls ~/.zen/game/players 2>/dev/null | grep "@"))

    if [[ ${#players[@]} -ge 1 ]]; then
        espeak "SELECT YOUR PLAYER"
        OUTPUT=$(zenity --list --width 480 --height 200 --title="Choix du PLAYER" --column="Astronaute" "${players[@]}")
        [[ ${OUTPUT} == "" ]] && espeak "No player selected. EXIT" && exit 1
    else
        OUTPUT="${players}"
    fi

    PLAYER=${OUTPUT}

else

    OUTPUT=${PLAYER}

fi

####### NO CURRENT ? PLAYER = .current
[[ ! -d $(readlink ~/.zen/game/players/.current) ]] \
    && rm -f ~/.zen/game/players/.current \
    && ln -s ~/.zen/game/players/${PLAYER} ~/.zen/game/players/.current

echo "ADMIN : "$(cat ~/.zen/game/players/.current/.player)

[[ ${OUTPUT} != ""  ]] \
&& espeak "${OUTPUT} CONNECTED" \
&& . "${MY_PATH}/tools/my.sh"

## NO PLAYER AT ALL
[[ ${OUTPUT} == "" ]] \
&& espeak "Astronaut. Please register." \
&& xdg-open "http://astroport.localhost:1234" \
&& exit 1 \
|| PSEUDO=$(myPlayerUser)

$($MY_PATH/tools/search_for_this_email_in_players.sh ${PLAYER} | tail -n 1)

espeak "Hello $PSEUDO"

G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub)
[[ $G1PUB == "" ]] && espeak "ERROR NO G 1 PUBLIC KEY FOUND - EXIT" && exit 1

ASTRONAUTENS=$(basename $ASTROTW)
[[ $ASTRONAUTENS == "" ]] && echo "ASTRONAUTE manquant" && espeak "Astronaut Key Missing" && exit 1

# Function to find user uploaded cookie file
find_user_cookie_file() {
    # Search for .cookie.txt in user NOSTR directories
    local nostr_dir="$HOME/.zen/game/nostr"
    if [[ -d "$nostr_dir" ]]; then
        # First, try to find cookie for current PLAYER
        if [[ -n "$PLAYER" && -f "$nostr_dir/$PLAYER/.cookie.txt" ]]; then
            echo "--cookies $nostr_dir/$PLAYER/.cookie.txt"
            return 0
        fi
        # Otherwise, find any recent cookie file
        for user_dir in "$nostr_dir"/*@*; do
            if [[ -f "$user_dir/.cookie.txt" ]]; then
                echo "--cookies $user_dir/.cookie.txt"
                return 0
            fi
        done
    fi
    return 1
}

# Function to get user uDRIVE path
get_user_udrive_path() {
    local player="$1"
    if [[ -n "$player" && "$player" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        # Find user directory by email
        local nostr_base_path="$HOME/.zen/game/nostr"
        if [ -d "$nostr_base_path" ]; then
            for email_dir in "$nostr_base_path"/*; do
                if [ -d "$email_dir" ] && [[ "$email_dir" == *"$player"* ]]; then
                    local udrive_path="$email_dir/APP/uDRIVE"
                    mkdir -p "$udrive_path"
                    echo "$udrive_path"
                    return 0
                fi
            done
        fi
    fi
    return 1
}

# Try user uploaded cookies first (priority)
USER_COOKIE=$(find_user_cookie_file)
if [[ -n "$USER_COOKIE" ]]; then
    BROWSER="$USER_COOKIE"
    echo "✅ Using user uploaded cookie file"
else
    # Fallback to browser cookies
    BZER=$(xdg-settings get default-web-browser | cut -d '.' -f 1 | cut -d '-' -f 1)
    [[ $BZER ]] && BROWSER="--cookies-from-browser $BZER " || BROWSER=""
    [[ ! $isLAN ]] && BROWSER=""
fi

# Get user uDRIVE path for file storage
USER_UDRIVE_PATH=$(get_user_udrive_path "$PLAYER")
if [[ -n "$USER_UDRIVE_PATH" ]]; then
    # Check both uDRIVE root and Videos subdirectory
    if [[ -d "$USER_UDRIVE_PATH/Videos" ]]; then
        USER_UDRIVE_PATH="$USER_UDRIVE_PATH/Videos"
    fi
    echo "✅ Using uDRIVE path: $USER_UDRIVE_PATH"
else
    echo "⚠️  Could not determine uDRIVE path for player: $PLAYER"
fi

###
if [ $URL ]; then

    echo "URL: $URL"
    REVSOURCE="$(echo "$URL" | awk -F/ '{print $3}' | rev)_"
    [[ ${CHOICE} == "" ]] && IMPORT=$(zenity --entry --width 640 --title="$URL => Astroport" --text="${PLAYER} Type de media à importer ?" --entry-text="Video" PDF MP3) || IMPORT="$CHOICE"
    [[ $IMPORT == "" ]] && espeak "No choice made. Exit" && exit 1
    [[ $IMPORT == "Video" ]] && IMPORT="Youtube"
    CHOICE="$IMPORT"

fi
###

COINS=$($MY_PATH/tools/G1check.sh $G1PUB | tail -n 1)
echo "$PLAYER wallet = $COINS G1"



########################################################################
## EXCEPTION COPIE PRIVE
# https://www.legifrance.gouv.fr/codes/article_lc/LEGIARTI000006278917/2008-12-11/
if [[ ! -f ~/.zen/game/players/${PLAYER}/legal ]]; then
zenity --width ${large} --height=${haut} --text-info \
       --title="Action conforme avec le Code de la propriété intellectuelle" \
       --html \
       --url="https://fr.wikipedia.org/wiki/Droit_d%27auteur_en_France#Les_exceptions_au_droit_d%E2%80%99auteur" \
       --checkbox="J'ai lu et j'accepte les termes."

case $? in
    0)
        echo "AUTORISATION COPIE PRIVE ASTROPORT OK !"
        echo "$G1PUB" > ~/.zen/game/players/${PLAYER}/legal
    # next step
    ;;
    1)
        echo "Refus conditions"
        rm -f ~/.zen/game/players/${PLAYER}/legal
        exit 1
    ;;
    -1)
        echo "Erreur."
        exit 1
    ;;
esac
fi

## CHANGE ASTROPORT BOOSTRAP
if [[ $1 == "on" ]]; then
    STRAP=$(ipfs bootstrap)
    BOOT=$(zenity --entry --width 300 --title="Catégorie" --text="$STRAP Changez de Bootstrap" --entry-text="Aucun" Astroport Public)
    [[ $BOOT == "Aucun" ]] && ipfs bootstrap rm --all
    [[ $BOOT == "Astroport" ]] && for bootnode in $(cat ${MY_PATH}/A_boostrap_nodes.txt | grep -Ev "#"); do ipfs bootstrap add $bootnode; done
    [[ $BOOT == "Public" ]] && for bootnode in $(cat ${MY_PATH}/A_boostrap_public.txt | grep -Ev "#"); do ipfs bootstrap add $bootnode; done
    REP=$(${MY_PATH}/tools/cron_VRFY.sh ON) && zenity --warning --width 600 --text "$REP"
fi

###
# IS THERE ANY RUNNING IPFS ADD OR PUBLISH IN PROGRESS ?
ISADDING=$(pgrep -au $USER -f 'ipfs add' | grep -v 'pgrep' | tail -n 1 | xargs | cut -d " " -f 1)
ISPUBLISHING=$(pgrep -au $USER -f 'ipfs name publish' | grep -v 'pgrep' | tail -n 1 | xargs | cut -d " " -f 1)
[[ $ISADDING || $ISPUBLISHING ]] \
&& echo "⚠️  IPFS task in progress (PID: ${ISADDING}${ISPUBLISHING}). Wait finish & try later" \
&& espeak "I P F S task in progress. Wait finish & try later" && exit 1

## CHECK IF ASTROPORT/CRON/IPFS IS RUNNING
YOU=$(pgrep -au $USER -f "ipfs daemon" > /dev/null && echo "$USER")
[[ ! $YOU ]] &&  espeak "I P F S not running - EXIT" && exit 1

[[ ! $URL ]] && xdg-open "http://ipfs.localhost:8080/ipns/$ASTRONAUTENS"

########################################################################
espeak "$COINS JUNE Ready !"
########################################################################

########################################################################
# CHOOSE CATEGORY (remove anime, not working!)
[ ! $2 ] && [[ $CHOICE == "" ]] && CHOICE=$(zenity --entry --width 300 --title="Catégorie" --text="Quelle catégorie pour ce media ?" --entry-text="Vlog" Video Film Serie PDF Youtube MP3)
[[ $CHOICE == "" ]] && echo "NO CHOICE MADE" && exit 1

# LOWER CARACTERS
CAT=$(echo "${CHOICE}" | awk '{print tolower($0)}')
# UPPER CARACTERS
CHOICE=$(echo "${CAT}" | awk '{print toupper($0)}')

PREFIX=$(echo "${CAT}" | head -c 1 | awk '{ print toupper($0) }' ) # ex: F, S, A, Y, M ... P W
[[ $PREFIX == "" ]] && exit 1

########################################################################
########################################################################
case ${CAT} in
########################################################################
########################################################################
########################################################################
# CASE ## VLOG
#~ __     ___
#~ \ \   / / | ___   __ _
 #~ \ \ / /| |/ _ \ / _` |
  #~ \ V / | | (_) | (_| |
   #~ \_/  |_|\___/ \__, |
                        #~ |___/
#
########################################################################
    vlog)

    mkdir -p ~/Astroport/${PLAYER}/vlog

    espeak "Ready to record your webcam"

    [ ! $2 ] && zenity --warning --width 300 --text "${PLAYER}. Prêt à enregistrer votre video ?"

    ## RECORD WEBCAM VIDEO
    ${MY_PATH}/tools/vlc_webcam.sh


    exit 0
    ;;

########################################################################
# CASE ## YOUTUBE
#                   _         _
# _   _  ___  _   _| |_ _   _| |__   ___
#| | | |/ _ \| | | | __| | | | '_ \ / _ \
#| |_| | (_) | |_| | |_| |_| | |_) |  __/
# \__, |\___/ \__,_|\__|\__,_|_.__/ \___|
# |___/
########################################################################
    youtube)

    mkdir -p ~/Astroport/${PLAYER}/youtube

    espeak "youtube : video copying"

YTURL="$URL"
[ ! $2 ] && [[ $YTURL == "" ]] && YTURL=$(zenity --entry --width 420 --title "Lien ou identifiant à copier" --text "Indiquez le lien (URL) ou l'ID de la vidéo" --entry-text="")
[[ $YTURL == "" ]] && echo "URL EMPTY " && exit 1

echo "VIDEO $YTURL"
echo "Processing URL: $YTURL"

# Download YouTube video using process_youtube.sh with --no-ipfs option
echo "📥 Downloading YouTube video using process_youtube.sh..."

# Create temporary download directory
TEMP_YOUTUBE_DIR="$HOME/.zen/tmp/youtube_$(date -u +%s%N | cut -b1-13)"
mkdir -p "$TEMP_YOUTUBE_DIR"

# Call process_youtube.sh with --no-ipfs and --output-dir options
YOUTUBE_RESULT=$(${MY_PATH}/IA/process_youtube.sh --no-ipfs --output-dir "$TEMP_YOUTUBE_DIR" "$YTURL" "mp4" "$PLAYER" 2>&1)
YTDLP_EXIT=$?

# Extract only the JSON part between markers
# Look for JSON between "=== JSON OUTPUT START ===" and "=== JSON OUTPUT END ==="
if echo "$YOUTUBE_RESULT" | grep -q "=== JSON OUTPUT START ==="; then
    YOUTUBE_JSON=$(echo "$YOUTUBE_RESULT" | sed -n '/=== JSON OUTPUT START ===/,/=== JSON OUTPUT END ===/p' | grep -v "=== JSON OUTPUT")
else
    # Fallback: extract the last valid JSON object
    YOUTUBE_JSON=$(echo "$YOUTUBE_RESULT" | grep -A 1000 '^{$' | tail -n +1)
fi

# Validate JSON
if ! echo "$YOUTUBE_JSON" | jq '.' >/dev/null 2>&1; then
    echo "❌ ERROR: Invalid JSON from process_youtube.sh"
    echo "Full output:"
    echo "$YOUTUBE_RESULT"
    espeak "Invalid JSON from YouTube processing"
    exit 1
fi

# Debug: Show result
echo "✅ JSON Result:"
echo "$YOUTUBE_JSON" | jq '.'

# Check if download succeeded
if [[ $YTDLP_EXIT -ne 0 ]]; then
    echo "❌ ERROR: YouTube download failed (exit code: $YTDLP_EXIT)"
    espeak "YouTube download failed"
    exit 1
fi

# Extract metadata from JSON result
TITLE=$(echo "$YOUTUBE_JSON" | jq -r '.title // empty')
DURATION=$(echo "$YOUTUBE_JSON" | jq -r '.duration // "0"')
UPLOADER=$(echo "$YOUTUBE_JSON" | jq -r '.uploader // "YouTube"')
FILENAME=$(echo "$YOUTUBE_JSON" | jq -r '.filename // empty')
FILE_PATH_DOWNLOADED=$(echo "$YOUTUBE_JSON" | jq -r '.file_path // empty')

# Validate extracted values
if [[ -z "$FILENAME" || -z "$FILE_PATH_DOWNLOADED" || ! -f "$FILE_PATH_DOWNLOADED" ]]; then
    echo "❌ ERROR: Downloaded file not found or invalid metadata"
    echo "FILENAME: '$FILENAME'"
    echo "FILE_PATH: '$FILE_PATH_DOWNLOADED'"
    ls -lah "$TEMP_YOUTUBE_DIR"
    espeak "Download failed"
    exit 1
fi

# Extract YouTube ID from URL
YID=$(echo "$YTURL" | grep -oE '(?:v=|/)([a-zA-Z0-9_-]{11})' | cut -d'=' -f2 | cut -d'/' -f2)

echo "✅ Downloaded: $FILENAME"
echo "   Title: $TITLE"
echo "   Duration: $DURATION seconds"
echo "   YouTube ID: $YID"
echo "   File: $FILE_PATH_DOWNLOADED"

# Create MEDIAID and MEDIAKEY
REVSOURCE="$(echo "$YTURL" | awk -F/ '{print $3}' | rev)_"
MEDIAID="$REVSOURCE${YID}"
MEDIAKEY="YOUTUBE_${MEDIAID}"

# Create directory structure
FILE_PATH="$HOME/Astroport/${PLAYER}/youtube/$MEDIAID"
mkdir -p ${FILE_PATH}

echo ""
echo "📤 Uploading to IPFS using upload2ipfs.sh..."

# Call upload2ipfs.sh with user's public key for provenance tracking
NPUB_HEX=$(cat ~/.zen/game/nostr/${PLAYER}/HEX 2>/dev/null || echo "")
UPLOAD_OUTPUT_FILE="$TEMP_YOUTUBE_DIR/upload_result.json"

# Call upload2ipfs.sh with the downloaded file
bash "${HOME}/.zen/UPassport/upload2ipfs.sh" \
    "$FILE_PATH_DOWNLOADED" \
    "$UPLOAD_OUTPUT_FILE" \
    "$NPUB_HEX"

UPLOAD_EXIT_CODE=$?

if [[ $UPLOAD_EXIT_CODE -ne 0 ]]; then
    echo "❌ ERROR: upload2ipfs.sh failed with exit code $UPLOAD_EXIT_CODE"
    espeak "Upload to IPFS failed"
    exit 1
fi

# Read upload result
if [[ ! -f "$UPLOAD_OUTPUT_FILE" ]]; then
    echo "❌ ERROR: Upload result file not found: $UPLOAD_OUTPUT_FILE"
    espeak "Upload result not found"
    exit 1
fi

UPLOAD_RESULT=$(cat "$UPLOAD_OUTPUT_FILE")
echo "Upload result:"
echo "$UPLOAD_RESULT" | jq '.'

# Extract values from upload result
IPFS_CID=$(echo "$UPLOAD_RESULT" | jq -r '.cid // empty')
INFO_CID=$(echo "$UPLOAD_RESULT" | jq -r '.info // empty')
THUMBNAIL_CID=$(echo "$UPLOAD_RESULT" | jq -r '.thumbnail_ipfs // empty')
GIFANIM_CID=$(echo "$UPLOAD_RESULT" | jq -r '.gifanim_ipfs // empty')
FILE_HASH=$(echo "$UPLOAD_RESULT" | jq -r '.fileHash // empty')
FILE_SIZE=$(echo "$UPLOAD_RESULT" | jq -r '.fileSize // 0')
MIME_TYPE=$(echo "$UPLOAD_RESULT" | jq -r '.mimeType // "video/mp4"')
UPLOAD_CHAIN=$(echo "$UPLOAD_RESULT" | jq -r '.upload_chain // empty')
DIMENSIONS=$(echo "$UPLOAD_RESULT" | jq -r '.dimensions // empty')

if [[ -z "$IPFS_CID" ]]; then
    echo "❌ ERROR: Failed to get IPFS CID from upload result"
    espeak "IPFS upload failed"
    exit 1
fi

echo ""
echo "✅ IPFS Upload successful!"
echo "   CID: $IPFS_CID"
echo "   Info CID: $INFO_CID"
echo "   Thumbnail CID: $THUMBNAIL_CID"
echo "   GIF CID: $GIFANIM_CID"
echo "   File Hash: ${FILE_HASH:0:16}..."
echo "   Size: $FILE_SIZE bytes"

# Create symbolic link or copy file to Astroport directory
if [[ -n "$USER_UDRIVE_PATH" ]]; then
    # Try to move file to uDRIVE
    if mv "$TEMP_YOUTUBE_DIR/$FILENAME" "$USER_UDRIVE_PATH/$FILENAME" 2>/dev/null; then
        ln -sf "$USER_UDRIVE_PATH/$FILENAME" "${FILE_PATH}/${FILENAME}"
        echo "✅ Moved to uDRIVE and created symbolic link"
    else
        # Fallback: just create symlink to temp file
        ln -sf "$TEMP_YOUTUBE_DIR/$FILENAME" "${FILE_PATH}/${FILENAME}"
        echo "⚠️  Could not move to uDRIVE, using temp file"
    fi
else
    # No uDRIVE, just symlink
    ln -sf "$TEMP_YOUTUBE_DIR/$FILENAME" "${FILE_PATH}/${FILENAME}"
    echo "⚠️  No uDRIVE path, using temp file"
fi

# Get resolution
FILE_RES="720"  # Default
if [[ -e "${FILE_PATH}/${FILENAME}" ]]; then
    FILE_RES=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "${FILE_PATH}/${FILENAME}" 2>/dev/null | cut -d "x" -f 2 || echo "720")
fi
RES=${FILE_RES%?}0p

## CREATE "~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/ajouter_video.txt"
URLENCODE_FILE_NAME=$(echo ${FILENAME} | jq -Rr @uri)
echo "youtube;${MEDIAID};$(date -u +%s%N | cut -b1-13);${TITLE};${SAISON};${GENRES};_IPNSKEY_;${RES};/ipfs/${IPFS_CID}/$URLENCODE_FILE_NAME" > ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/ajouter_video.txt

# Store additional metadata for later use
cat > ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/upload_info.json <<EOF
{
  "ipfs_cid": "$IPFS_CID",
  "info_cid": "$INFO_CID",
  "thumbnail_cid": "$THUMBNAIL_CID",
  "gifanim_cid": "$GIFANIM_CID",
  "file_hash": "$FILE_HASH",
  "file_size": $FILE_SIZE,
  "mime_type": "$MIME_TYPE",
  "upload_chain": "$UPLOAD_CHAIN",
  "dimensions": "$DIMENSIONS",
  "duration": "$DURATION",
  "uploader": "$UPLOADER",
  "youtube_url": "$YTURL",
  "youtube_id": "$YID"
}
EOF

# Set FILE_NAME for new_file_in_astroport.sh
FILE_NAME="$FILENAME"

echo "✅ YouTube video processed successfully!"
espeak "YouTube video ready"

    ;;

########################################################################
# CASE ## WEB
#~ __        __     _
#~ \ \       / /__ | |__
#~  \ \ /\ / / _ \ '_ \
#~   \ V  V /__/ |_) |
#~    \_/\_/ \_|_.__/
#~

    web)

    mkdir -p ~/Astroport/${PLAYER}/web

# URL="https://discuss.ipfs.io/t/limit-ipfs-get-command/3573/6"
        espeak "Mirror web site"
        cd ~/.zen/tmp/

        [ ! $2 ] && [[ $URL == "" ]] && URL=$(zenity --entry --width 300 --title "Lien du site Web à copier" --text "Indiquez le lien (URL)" --entry-text="")

        ## Extract http(s)://domain.tld
        URLSOURCE=$(echo $URL | grep -Eo '^http[s]?://[^/]+')     # URL="https://discuss.ipfs.io"
        DOMAIN=$(echo $URLSOURCE | rev | cut -d '/' -f1 | rev)    # DOMAIN=discuss.ipfs.io
        ARR=($(echo $DOMAIN | sed "s~\.~ ~g")) # ARR=discuss ipfs io
        NIAMOD=$(printf '%s\n' "${ARR[@]}" | tac | tr '\n' '.' ) # NIAMOD=io.ipfs.discuss.
        NIAPATH=$(echo $NIAMOD | sed "s~\.~\/~g") # NIAPATH=io/ipfs/discuss/

        TITLE=$DOMAIN
        GENRES="Web"

        espeak "${ARR[@]}"

        ## CREATE IPNS KEY HOOK JUST FOR FUN
        REVSOURCE="$(echo "$NIAMOD" | rev | sha256sum | cut -d ' ' -f 1)"; echo $REVSOURCE
        MEDIAKEY="$REVSOURCE" # MEDIAKEY=435582881619ee4df9e2723fb9e20bb173b32818094a3e40c9536068ae3730ac

        IPNSKEY=$(ipfs key list -l | grep -w $MEDIAKEY | cut -d ' ' -f 1 )
        if [[ ! $IPNSKEY ]]; then
        # Funny Crypto Level # TODO MAKE IT MORE SECURE # THIS KEY OWNS THE DOMAIN NOW
            ${MY_PATH}/tools/keygen -t ipfs -o ~/.zen/tmp/$MEDIAKEY.ipns "$DOMAIN" "$NIAMOD"
            IPNSKEY=$(ipfs key import $MEDIAKEY -f pem-pkcs8-cleartext ~/.zen/tmp/$MEDIAKEY.ipns)
        fi

        MEDIAID="WEB_${NIAMOD}" # MEDIAID=WEB_io.ipfs.discuss.

        FILE_PATH="$HOME/Astroport/${PLAYER}/web/$MEDIAID";  # FILE_PATH=/home/fred/Astroport/${PLAYER}/web/WEB_io.ipfs.discuss.

            start=`date +%s`

            mkdir -p $FILE_PATH
            cd $FILE_PATH

            espeak "Let's go. " ###################### HTTRACK COPYING

            httrack -wxY --sockets=99 −−max−rate=0 --disable-security-limits −−keep−alive --ext-depth=0 --stay-on-same-domain --robots=0 --keep-links=0 -V "echo \$0 >> $FILE_PATH/files" "$URL" -* +*/$DOMAIN/* -*wget* # -%l "fr"

            cd $FILE_PATH/$DOMAIN/
            grep -rl '../external.html' ./  | xargs sed -i 's~../external.html~external.html~g'

            cp $MY_PATH/templates/external.html $FILE_PATH/$DOMAIN/

            ## G1PUB ENCODE.16 MEDIAKEY
            ${MY_PATH}/tools/natools.py encrypt -p $G1PUB -i $HOME/.zen/tmp/$MEDIAKEY.ipns -o $HOME/.zen/tmp/$MEDIAKEY.ipns.enc
            cat $HOME/.zen/tmp/$MEDIAKEY.ipns.enc | base16 > $FILE_PATH/$DOMAIN/.ipnskey.$G1PUB.enc.16

            ## BLOCKCHAIN IT
            echo "$MOATS" > $FILE_PATH/$DOMAIN/.moats        # TIMESTMAPING
            echo "$IPNSKEY" > $FILE_PATH/$DOMAIN/.ipnshook       # SELF REFERING

            espeak "OK Web is copied. Adding to I P F S now..."

            ### ADD TO IPFS
            IPFSREPFILEID=$(ipfs add -qHwr $FILE_PATH/$DOMAIN/* | tail -n 1)  # ADDING $DOMAIN TO IPFS
            ipfs name publish -k $MEDIAKEY /ipfs/$IPFSREPFILEID   # PUBLISH $MEDIAKEY

            ## CREATE ajouter_video.txt
            echo "web;${MEDIAID};${MOATS};${TITLE};${SAISON};${GENRES};$IPNSKEY;${RES};/ipfs/$IPFSREPFILEID" > ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/ajouter_video.txt

            ## DURATION LOG
            end=`date +%s`
            dur=`expr $end - $start`
            echo ${MOATS}:${G1PUB}:${PLAYER}:${MEDIAID}:$dur >> ~/.zen/tmp/${IPFSNODEID}/_timings
            cat ~/.zen/tmp/${IPFSNODEID}/_timings | tail -n 1

            ## TIDDLER CREATION
            FILE_BSIZE=$(du -b "$FILE_PATH/$DOMAIN/" | awk '{print $1}' | tail -n 1)
            FILE_SIZE=$(echo "${FILE_BSIZE}" | awk '{ split( "B KB MB GB TB PB" , v ); s=1; while( $1>1024 ){ $1/=1024; s++ } printf "%.2f %s", $1, v[s] }')

            ## NB TEXT IS MADE WITH TIDDLERS FIELDS VALUES (LEARN TODO)
            TEXT="<iframe src={{{ [{$:/ipfs/saver/gateway/http/localhost!!text}] [{!!ipfs}] +[join[]] }}} height='360' width='100%'></iframe>
             Web : $URL ----> <a href={{{ [{$:/ipfs/saver/gateway/http/localhost!!text}] [{!!ipfs}] +[join[]] }}}}><<currentTiddler>></a>
            <br>$FILE_SIZE - $dur sec"

echo '[
  {
    "created": "'${MOATS}'",
    "modified": "'${MOATS}'",
    "dur": "'$dur'",
    "title": "'${NIAMOD}'",
    "type": "'text/vnd.tiddlywiki'",
    "text": "'$TEXT'",
    "size": "'${FILE_BSIZE}'",
    "filesize": "'${FILE_SIZE}'",
    "g1pub": "'${G1PUB}'",
    "ipfs": "'/ipfs/${IPFSREPFILEID}'",
    "mediakey": "'${MEDIAKEY}'",
    "ipnskey16": "'$(cat $HOME/.zen/tmp/$MEDIAKEY.ipns.enc | base16)'",
    "ipns": "'/ipns/${IPNSKEY}'",
    "tags": "'ipfs G1Web $PLAYER webmaster@$DOMAIN'"
  }
]
' > ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/${MEDIAKEY}.dragdrop.json

#        zenity --warning --width ${large} --text "Copie $URL dans ${FILE_PATH}/ et /ipns/$IPNSKEY"

        espeak "Done. Tiddler is ready"

    ;;


########################################################################
# CASE ## PDF
 #~ ____
#~ |  _ \ __ _  __ _  ___
#~ | |_) / _` |/ _` |/ _ \
#~ |  __/ (_| | (_| |  __/
#~ |_|   \__,_|\__, |\___|
                #~ |___/

    pdf)

        mkdir -p ~/Astroport/${PLAYER}/pdf

        espeak "Importing file or web page to P D F"
        ## EVOLVE TO ARTICLE
        # httrack --mirror --ext-depth=0 --depth=1 --near --stay-on-same-address --keep-links=0 --path article-x --quiet https://example.com/article-x/

        [ ! $2 ] && [[ $URL == "" ]] && URL=$(zenity --entry --width 500 --title "Convertir lien PDF (ANNULER ET CHOISIR UN FICHIER LOCAL)" --text "Indiquez le lien (URL)" --entry-text="")

        if [[ $URL != "" ]]; then
    ## record one page to PDF
            [ ! $2 ] && [[ ! $(which chromium) ]] &&  zenity --warning --width ${large} --text "Utilitaire de copie de page web absent.. Lancez la commande 'sudo apt install chromium'" && exit 1

            cd ~/.zen/tmp/ && rm -f output.pdf

            # https://peter.sh/experiments/chromium-command-line-switches
            ${MY_PATH}/tools/timeout.sh -t 30 \
            chromium --headless --use-mobile-user-agent --no-sandbox --print-to-pdf "$URL"
        fi

        if [[ $URL == "" ]]; then

            # SELECT FILE TO ADD TO ASTROPORT/KODI
            [ ! $2 ] && FILE=$(zenity --file-selection --title="Sélectionner le fichier à ajouter")
            echo "${FILE}"
            [[ ! -s "${FILE}" ]] && echo "NO FILE" && exit 1

            # Remove file extension to get file name => STITLE
            FILE_PATH="$(dirname "${FILE}")"
            FILE_NAME="$(basename "${FILE}")"
            FILE_EXT="${FILE_NAME##*.}"
            FILE_TITLE="${FILE_NAME%.*}"
            cp "${FILE}" ~/.zen/tmp/output.pdf
            URL="/ipfs.localhost/$FILE_TITLE"
        fi


        [[ ! -s ~/.zen/tmp/output.pdf ]] && espeak "No file Sorry. Exit" && exit 1

        espeak "OK P D F received"

        #~ ## TODO
        #~ ## CONVERT TO DOCX
        #~ pdf2docx convert ~/.zen/tmp/output.pdf
        #~ # THEN TO MD
        #~ pandoc -f docx -t markdown -o ~/.zen/tmp/output.md ~/.zen/tmp/output.docx

        CTITLE=$(echo $URL | rev | cut -d '/' -f 1 | rev)

        [ ! $2 ] && TITLE=$(zenity --entry --width 480 --title "Titre" --text "Quel nom donner à ce fichier ? " --entry-text="${CTITLE}") || TITLE="$CTITLE"
        [[ "$TITLE" == "" ]] && echo "NO TITLE" && exit 1

        FILE_NAME="$(echo "${TITLE}" | detox --inline).pdf" ## TODO make it better
        REVSOURCE="$(echo "$URL" | awk -F/ '{print $3}' | rev | detox --inline)_"

        MEDIAID="$REVSOURCE$(echo "${TITLE}" | detox --inline)"
        MEDIAKEY="PDF_${MEDIAID}"
        FILE_PATH="$HOME/Astroport/${PLAYER}/pdf/$MEDIAID"
        mkdir -p ${FILE_PATH} && mv ~/.zen/tmp/output.pdf ${FILE_PATH}/${FILE_NAME}

        echo "pdf;${MEDIAID};$(date -u +%s%N | cut -b1-13);${TITLE};${SAISON};${GENRES};_IPNSKEY_;${RES};/ipfs/_IPFSREPFILEID_/$FILE_NAME" > ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/ajouter_video.txt

        espeak 'Document ready'

    ;;

########################################################################
# CASE ## MP3
#                _____
# _ __ ___  _ __|___ /
#| '_ ` _ \| '_ \ |_ \
#| | | | | | |_) |__) |
#|_| |_| |_| .__/____/
#          |_|
########################################################################
    mp3)

        mkdir -p ~/Astroport/${PLAYER}/mp3

        [[ $URL == "" ]] && URL=$(zenity --entry --width 500 --title "Lien Youtube à convertir en MP3" --text "Indiquez le lien (URL)" --entry-text="")
        [[ $URL == "" ]] && echo "URL EMPTY" && exit 1
        
        echo "Processing URL: $URL"
        
        espeak "OK."
        
        # Use process_youtube.sh for MP3 processing with player email
        echo "Using process_youtube.sh for MP3 download..."
        echo "Command: ${MY_PATH}/IA/process_youtube.sh --debug \"$URL\" \"mp3\" \"$PLAYER\""
        
        # Check if process_youtube.sh exists and is executable
        if [[ ! -f "${MY_PATH}/IA/process_youtube.sh" ]]; then
            echo "ERROR: process_youtube.sh not found at ${MY_PATH}/IA/process_youtube.sh"
            espeak "process_youtube.sh not found"
            exit 1
        fi
        
        if [[ ! -x "${MY_PATH}/IA/process_youtube.sh" ]]; then
            echo "ERROR: process_youtube.sh is not executable"
            espeak "process_youtube.sh not executable"
            exit 1
        fi
        
        MP3_RESULT=$(${MY_PATH}/IA/process_youtube.sh --debug "$URL" "mp3" "$PLAYER")
        MP3_EXIT_CODE=$?
        echo "process_youtube.sh exit code: $MP3_EXIT_CODE"
        
        # Debug: Show the raw result
        echo "Raw MP3_RESULT: $MP3_RESULT"
        
        # Check if the result is valid JSON
        if ! echo "$MP3_RESULT" | jq . >/dev/null 2>&1; then
            echo "Invalid JSON returned from process_youtube.sh"
            echo "Raw output: $MP3_RESULT"
            espeak "Invalid JSON from YouTube processing"
            exit 1
        fi
        
        # Check if process_youtube.sh succeeded
        if echo "$MP3_RESULT" | jq -e '.error' >/dev/null 2>&1; then
            ERROR_MSG=$(echo "$MP3_RESULT" | jq -r '.error')
            echo "MP3 processing failed: $ERROR_MSG"
            espeak "MP3 processing failed"
            exit 1
        fi
        
        # Extract values from JSON result with better error handling
        IPFS_URL=$(echo "$MP3_RESULT" | jq -r '.ipfs_url // empty' 2>/dev/null)
        FILE_TITLE=$(echo "$MP3_RESULT" | jq -r '.title // empty' 2>/dev/null)
        DURATION=$(echo "$MP3_RESULT" | jq -r '.duration // empty' 2>/dev/null)
        UPLOADER=$(echo "$MP3_RESULT" | jq -r '.uploader // empty' 2>/dev/null)
        FILE_NAME=$(echo "$MP3_RESULT" | jq -r '.filename // empty' 2>/dev/null)
        
        # Debug: Show extracted values
        echo "Extracted values:"
        echo "  IPFS_URL: '$IPFS_URL'"
        echo "  FILE_TITLE: '$FILE_TITLE'"
        echo "  DURATION: '$DURATION'"
        echo "  UPLOADER: '$UPLOADER'"
        echo "  FILE_NAME: '$FILE_NAME'"
        
        if [[ -z "$FILE_TITLE" || -z "$IPFS_URL" ]]; then
            echo "Failed to extract required data from MP3 processing"
            echo "FILE_TITLE: '$FILE_TITLE'"
            echo "IPFS_URL: '$IPFS_URL'"
            espeak "Failed to extract data"
            exit 1
        fi
        
        # Create MEDIAID and MEDIAKEY using YouTube ID
        REVSOURCE="$(echo "$URL" | awk -F/ '{print $3}' | rev)_"
        YOUTUBE_ID=$(echo "$URL" | grep -oE '(?:v=|/)([a-zA-Z0-9_-]{11})' | cut -d'=' -f2 | cut -d'/' -f2)
        MEDIAID="${REVSOURCE}${YOUTUBE_ID}"
        MEDIAKEY="MP3_${MEDIAID}"
        
        # Initialize missing variables for MP3
        SAISON=""
        GENRES="[\"Musique\", \"${PLAYER// /-}\"]"
        RES="Audio"
        
        # Create proper directory structure
        FILE_PATH="$HOME/Astroport/${PLAYER}/mp3/$MEDIAID"
        mkdir -p ${FILE_PATH}
        
        # Create symbolic link to uDRIVE file if available
        FILE_NAME="$FILE_NAME"
        if [[ -n "$USER_UDRIVE_PATH" && -f "$USER_UDRIVE_PATH/$FILE_NAME" ]]; then
            ln -sf "$USER_UDRIVE_PATH/$FILE_NAME" "${FILE_PATH}/${FILE_NAME}"
            echo "Created symbolic link to uDRIVE file: $USER_UDRIVE_PATH/$FILE_NAME"
        else
            echo "⚠️  uDRIVE file not found: $USER_UDRIVE_PATH/$FILE_NAME"
            espeak "Error: MP3 file not found in uDRIVE"
            exit 1
        fi
        
        # Verify the file exists (either direct file or symlink)
        if [[ ! -e "${FILE_PATH}/${FILE_NAME}" ]]; then
            echo "❌ ERROR: MP3 file not accessible at ${FILE_PATH}/${FILE_NAME}"
            espeak "Error: MP3 file not accessible"
            exit 1
        fi
        
        # Create ajouter_video.txt
        URLENCODE_FILE_NAME=$(echo ${FILE_NAME} | jq -Rr @uri)
        echo "mp3;${MEDIAID};$(date -u +%s%N | cut -b1-13);${FILE_TITLE};${SAISON};${GENRES};_IPNSKEY_;${RES};/ipfs/_IPFSREPFILEID_/$URLENCODE_FILE_NAME" > ~/Astroport/${PLAYER}/mp3/${MEDIAID}/ajouter_video.txt
        
        espeak "Ready. MP3 file processed"

        break
    ;;

########################################################################
#   Film                 __ _ _ Serie
#~ _____ _ _              ___     ____            _
#~ |  ___(_) |_ __ ___    ( _ )   / ___|  ___ _ __(_) ___
#~ | |_  | | | '_ ` _ \   / _ \/\ \___ \ / _ \ '__| |/ _ \
#~ |  _| | | | | | | | | | (_>  <  ___) |  __/ |  | |  __/
#~ |_|   |_|_|_| |_| |_|  \___/\/ |____/ \___|_|  |_|\___|
#
########################################################################
    film | serie)

    mkdir -p ~/Astroport/${PLAYER}/film
    mkdir -p ~/Astroport/${PLAYER}/serie

    espeak "please select your file"

# SELECT FILE TO ADD TO ASTROPORT/KODI
FILE=$(zenity --file-selection --title="Sélectionner le fichier à ajouter")
echo "${FILE}"
[[ $FILE == "" ]] && exit 1

# Remove file extension to get file name => STITLE
FILE_PATH="$(dirname "${FILE}")"
FILE_NAME="$(basename "${FILE}")"
FILE_EXT="${FILE_NAME##*.}"
FILE_TITLE="${FILE_NAME%.*}"

# OPEN default browser and search TMDB
zenity --question --width 300 --text "Ouvrir https://www.themoviedb.org pou récupérer le numéro d'identification de $(echo ${FILE_TITLE} | sed 's/_/%20/g') ?"
[ $? == 0 ] && xdg-open "https://www.themoviedb.org/search?query=$(echo ${FILE_TITLE} | sed 's/_/%20/g')"

MEDIAID=$(zenity --entry --title="Identification TMDB" --text="Copiez le nom de la page du film. Ex: 301528-toy-story-4 pour une adresse https://www.themoviedb.org/movie/301528-toy-story-4)" --entry-text="")
[[ $MEDIAID == "" ]] && exit 1
MEDIAID=$(echo $MEDIAID | rev | cut -d '/' -f 1 | rev) ## REmoving/That/Part/keeping/MEDIAID
CMED=$(echo $MEDIAID | cut -d '-' -f 1)
TMTL=$(echo $MEDIAID | cut -d '-' -f 2-) # contient la fin du nom de fichier tmdb (peut servir?)

if ! [[ "$CMED" =~ ^[0-9]+$ ]]
then
        zenity --warning --width ${large} --text "Vous devez renseigner un numéro! Merci de recommencer... Seules les vidéos référencées sur The Movie Database sont acceptées. Sinon importez en mode 'Video'" && exit 1
fi
MEDIAID=$CMED
MEDIAKEY="TMDB_$MEDIAID"

# VIDEO TITLE
### CHECK IF PREVIOUS ajouter_video (usefull for Serie)
[[ -f  ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/ajouter_video.txt ]] \
&& PRE=$(cat ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/ajouter_video.txt | cut -d ';' -f 4) \
|| PRE=${FILE_TITLE}
###
TITLE=$(zenity --entry --width 300 --title "Titre" --text "Indiquez le titre de la vidéo" --entry-text="${PRE}")
[[ $TITLE == "" ]] && exit 1
TITLE=$(echo "${TITLE}" | detox --inline ) # Clean TITLE (NO ;)

# VIDEO YEAR
### CHECK IF PREVIOUS ajouter_video (Serie case)
[[ -f  ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/ajouter_video.txt ]] \
&& PRE=$(cat ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/ajouter_video.txt | cut -d ';' -f 3) \
|| PRE=""
YEAR=$(zenity --entry --width 300 --title "Année" --text "Indiquez année de la vidéo. Exemple: 1985" --entry-text="${PRE}")

# VIDEO RESOLUTION
FILE_RES=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "${FILE}" | cut -d "x" -f 2)
RES=${FILE_RES%?}0p # Rounding. Replace last digit with 0

# VIDEO SEASON or SAGA
### CHECK IF PREVIOUS ajouter_video (Serie case)
[[ -f  ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/ajouter_video.txt ]] \
&& PRE=$(cat ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/ajouter_video.txt | cut -d ';' -f 5 | cut -d '_' -f 2)
[[ "${CAT}" == "serie" ]] && SAISON=$(zenity --entry --width 300 --title "${CHOICE} Saison" --text "Indiquez SAISON et EPISODE. Exemple: S02E05" --entry-text="${PRE}")
[[ "${CAT}" == "film" ]] && SAISON=$(zenity --entry --width 300 --title "${CHOICE} Saga" --text "Indiquez une SAGA (optionnel). Exemple: James Bond" --entry-text="")
[[ $SAISON ]] && SAISON="_$SAISON"

# VIDEO GENRES
FILM_GENRES=$(zenity --list --checklist --title="GENRE" --height=${haut}\
    --text="Choisissez le(s) genre(s) de \"${TITLE}\""\
    --column="Use"\
    --column="Feature"\
    FALSE '+18'\
    FALSE Action\
    FALSE Animation\
    FALSE 'Arts Martiaux'\
    FALSE Aventure\
    FALSE Autre\
    FALSE Biographie\
    FALSE Biopic\
    FALSE Comedie\
    FALSE 'Comedie Dramatique'\
    FALSE 'Comedie Musicale'\
    FALSE Crime\
    FALSE Documentaire\
    FALSE Drame\
    FALSE Divers\
    FALSE Educatif\
    FALSE Enfant\
    FALSE Horreur\
    FALSE Espionnage\
    FALSE Famille\
    FALSE Fantastique\
    FALSE Guerre\
    FALSE Histoire\
    FALSE Historique\
    FALSE Judiciaire\
    FALSE Opera\
    FALSE Medical\
    FALSE Musique\
    FALSE Mystere\
    FALSE Peplum\
    FALSE Policier\
    FALSE Romance\
    FALSE 'Science Fiction'\
    FALSE Soap\
    FALSE Spectacle\
    FALSE Sport\
    FALSE Telefilm\
    FALSE Thriller\
    FALSE Western\
    TRUE ${PLAYER// /-})

# FORMAT GENRES ["genre1","genre2"] # USE  IF YOU ACTIVATE KODI COMPATIBILITY
GENRES="[\"$(echo ${FILM_GENRES} | sed s/\|/\",\"/g)\"]"

    # CONVERT INPUT TO MP4 #######################
    [[ $FILE_EXT != "mp4"  ]] \
    && espeak "Converting to M P 4. Please wait" \
    && echo "CONVERT TO MP4 : ffmpeg -loglevel quiet -i ${FILE_PATH}/${FILE_NAME} -c:v libx264 -c:a aac ${FILE_PATH}/$FILE_TITLE.mp4" \
    && ffmpeg -loglevel quiet -i "${FILE_PATH}/${FILE_NAME}" -c:v libx264 -c:a aac "${FILE_PATH}/$FILE_TITLE.mp4" \
    && FILE_EXT="mp4" && FILE_NAME="$FILE_TITLE.mp4" \
    && espeak "M P 4 ready"

mkdir -p ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/

[[ ! -s "$HOME/Astroport/${PLAYER}/${CAT}/${MEDIAID}/${TITLE}${SAISON}.${FILE_EXT}" ]] \
&& cp "${FILE_PATH}/${FILE_NAME}" "$HOME/Astroport/${PLAYER}/${CAT}/${MEDIAID}/${TITLE}${SAISON}.${FILE_EXT}" \
&& [ $? != 0 ] \
        && zenity --warning --width ${large} --text "(☓‿‿☓) ${FILE_PATH}/${FILE_NAME} vers ~/Astroport - EXIT -" && exit 1

FILE_NAME="${TITLE}${SAISON}.${FILE_EXT}"

## CREATE "~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/ajouter_video.txt"
URLENCODE_FILE_NAME=$(echo ${FILE_NAME} | jq -Rr @uri)
echo "${CAT};${MEDIAID};${YEAR};${TITLE};${SAISON};${GENRES};_IPNSKEY_;${RES};/ipfs/_IPFSREPFILEID_/$URLENCODE_FILE_NAME" > ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/ajouter_video.txt
# _IPFSREPFILEID_ is replaced later
#######################################################
######## NOT CREATING TIDDLER JSON... SWALLOW IS POST-PROCESSED
## new_file_in_astroport.sh ACTIVATES CONTRACT MODE !!
#######################################################
#######################################################

    ;;
# video       _     _
#__   _(_) __| | ___  ___
#\ \ / / |/ _` |/ _ \/ _ \
# \ V /| | (_| |  __/ (_) |
#  \_/ |_|\__,_|\___|\___/
#                           TIMESTAMP INDEX

    video)

    mkdir -p ~/Astroport/${PLAYER}/video

    espeak "Add your personnal video in TW"

    #~ zenity --warning --width 600 --text 'DEV-DEBUG : REGISTER https://git.p2p.legal'

    ## GENERAL MEDIAKEY for uploaded video. Title + Decription + hashtag + hashipfs
    # SELECT FILE TO ADD TO ASTROPORT/KODI
    FILE=$(zenity --file-selection --title="Sélectionner votre vidéo")
    echo "${FILE}"
    [[ $FILE == "" ]] && exit 1

    # Remove file extension to get file name => STITLE
    FILE_PATH="$(dirname "${FILE}")"
    FILE_NAME="$(basename "${FILE}")"
    FILE_EXT="${FILE_NAME##*.}"
    FILE_TITLE="${FILE_NAME%.*}"

    #~ # MUST CONVERT MKV TO MP4
    #~ [[ $FILE_EXT != "mp4"  ]] \
    #~ && ffmpeg -loglevel quiet -i "${FILE_PATH}/${FILE_NAME}" -c:v libx264 -c:a aac "${FILE_PATH}/$FILE_TITLE.mp4" \
    #~ && FILE_EXT="mp4" && FILE_NAME="$FILE_TITLE.mp4"

    # VIDEO TITLE
    TITLE=$(zenity --entry --width 600 --title "Titre" --text "Indiquez le titre de cette vidéo" --entry-text="${FILE_TITLE}")
    [[ $TITLE == "" ]] && exit 1
    TITLE=$(echo "${TITLE}" | detox --inline ) # Clean TITLE (NO ;)

    ## video_timestamp INDEX
    MEDIAID="$(date -u +%s%N | cut -b1-13)"
    mkdir -p ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/
    MEDIAKEY="VIDEO_${MEDIAID}"

    ## CREATE SIMPLE JSON (EXPERIENCE WITH it)
    jq -n --arg ts "$MEDIAID" --arg title "$TITLE" --arg desc "$DESCRIPTION" --arg htag "$HASHTAG" '{"timestamp":$ts,"ipfs":"_IPFSREPFILEID_","ipns":"_IPNSKEY_","title":$title,"desc":$desc,"tag":$htag}' > ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/video.json

    ## MOVE FILE FOR new_file_in_astroport POST TREATMENT
    [[ ! -s "$HOME/Astroport/${PLAYER}/${CAT}/${MEDIAID}/${TITLE}${SAISON}.${FILE_EXT}" ]] \
    && cp "${FILE_PATH}/${FILE_NAME}" "$HOME/Astroport/${PLAYER}/${CAT}/${MEDIAID}/${TITLE}${SAISON}.${FILE_EXT}"

    FILE_NAME="${TITLE}.${FILE_EXT}"

#######################################################
######## NOT CREATING TIDDLER JSON... SWALLOW IS POST-PROCESSED
## new_file_in_astroport.sh FOR OWN CREATION CONTRACTING MODE !!
#######################################################
#######################################################


    ;;

########################################################################
# CASE ## DEFAULT
########################################################################
    *)

    [ ! $2 ] && zenity --warning --width ${large} --text "Impossible d'interpréter votre commande $CAT"
    exit 1

    ;;

esac

########################################################################

########################################################################
########################################################################

########################################################################
########################################################################
# Screen capture
########################################################################
if [[ $(echo $DISPLAY | cut -d ':' -f 1) == "" ]]; then
    sleep 1
    import -window root ~/.zen/tmp/screen.png
fi

###################################
### MOVING FILE TO ~/astroport ####
###################################
mkdir -p ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/
mv ~/.zen/tmp/screen.png ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/screen.png

########################################################################
# ADD $FILE to IPFS / ASTROPORT / KODI
echo "(♥‿‿♥) new_file_in_astroport.sh \"$HOME/Astroport/${PLAYER}/${CAT}/${MEDIAID}/\" \"${FILE_NAME}\"" "$3" "$PLAYER"
[[ -f ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/ajouter_video.txt ]] && cat ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/ajouter_video.txt
# LOG NOISE # [[ -f ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/video.json ]] && cat ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/video.json
########################################################################
## CREATION DU FICHIER ~/Astroport/${PLAYER}/Add_${MEDIAKEY}_script.sh
########################################################################
### AJOUT DANS IPFS  #######################################################
########################################################################
####################################new_file_in_astroport.sh##################
########################################################################
if [[ ! -s ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/${MEDIAKEY}.dragdrop.json ]]; then
    [[ "$CAT" == "film" || "$CAT" == "serie" ]] && CHOICE="TMDB"

    timestamp=$(date -u +%s%N | cut -b1-13)

    ## CREATE BASH SCRIPT

    echo "MEDIAKEY=${MEDIAKEY}" > ~/Astroport/${PLAYER}/Add_${MEDIAKEY}_script.sh
    echo 'exec 2>&1 >> ~/.zen/tmp/ajouter_media.log' >> ~/Astroport/${PLAYER}/Add_${MEDIAKEY}_script.sh

    ## ACTIVATE h265 conversion .?
    #[[ $CHOICE == "TMDB" ]] && echo "echo \"Encoder ${FILE_NAME} en h265 avant import ? Tapez sur ENTER.. Sinon saisissez qqch avant...\"
    #reponse=\$1
    #[[ ! \$reponse ]] && read reponse
    #if [[ ! \$reponse ]]; then
    #    ffmpeg -i \"$HOME/Astroport/${PLAYER}/${CAT}/${MEDIAID}/${FILE_NAME}\" -vcodec libx265 -crf 28 $HOME/Astroport/${PLAYER}/${MEDIAID}.mp4
    #    mv \"$HOME/Astroport/${PLAYER}/${CAT}/${MEDIAID}/${FILE_NAME}\" \"$HOME/Astroport/${PLAYER}/${CAT}/${MEDIAID}/${FILE_NAME}.old\"
    #    mv $HOME/Astroport/${PLAYER}/${MEDIAID}.mp4 \"$HOME/Astroport/${PLAYER}/${CAT}/${MEDIAID}/${FILE_NAME}.mp4\"
    #    ${MY_PATH}/tools/new_file_in_astroport.sh \"$HOME/Astroport/${PLAYER}/${CAT}/${MEDIAID}/\" \"${FILE_NAME}.mp4\"
    #else" >> ~/Astroport/${PLAYER}/Add_${MEDIAKEY}_script.sh

    # $3 is the G1PUB of the PLAYER
    echo "${MY_PATH}/tools/new_file_in_astroport.sh \"$HOME/Astroport/${PLAYER}/${CAT}/${MEDIAID}/\" \"${FILE_NAME}\" \"$G1PUB\" \"$PLAYER\"" >> ~/Astroport/${PLAYER}/Add_${MEDIAKEY}_script.sh

    #[[ $CHOICE == "TMDB" ]] && echo "fi" >> ~/Astroport/${PLAYER}/Add_${MEDIAKEY}_script.sh

    echo "mv ~/Astroport/${PLAYER}/Add_${MEDIAKEY}_script.sh \"$HOME/Astroport/${PLAYER}/${FILE_NAME}_DONE.sh\"
    " >> ~/Astroport/${PLAYER}/Add_${MEDIAKEY}_script.sh

    chmod +x ~/Astroport/${PLAYER}/Add_${MEDIAKEY}_script.sh

    ########################################################################
    echo "(♥‿‿♥) $MEDIAKEY IPFS MIAM (ᵔ◡◡ᵔ)"
#    zenity --warning --width 360 --text "(♥‿‿♥) $MEDIAKEY IPFS MIAM (ᵔ◡◡ᵔ)"

    espeak "Adding $CAT to I P F S. Please Wait"

    ## RUN BASH SCRIPT
    bash ~/Astroport/${PLAYER}/Add_${MEDIAKEY}_script.sh "noh265"

    ## OR PUT IN YOUR QUEUE
    ## CREATING TIMELINE FOR BATCH TREATMENT
    #~ mkdir -p ~/.zen/tmp/${IPFSNODEID}/ajouter_media.sh/
    #~ echo "${MEDIAKEY}" > ~/.zen/tmp/${IPFSNODEID}/ajouter_media.sh/${MOATS}

    ##


fi

#######################################
########################## TIDDLER JSON READY
#######################################
if [[ -s ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/${MEDIAKEY}.dragdrop.json ]]; then
    espeak "Updating T W"

    ########################################################################
    ## ADD TIDDLER TO TW
    ########################################################################
    echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
    ## GETTING LAST TW via IPFS or HTTP GW
    LIBRA=$(head -n 2 ${MY_PATH}/A_boostrap_nodes.txt | tail -n 1 | xargs | cut -d ' ' -f 2)
    rm -f ~/.zen/tmp/astronaut_TW.html > /dev/null 2>&1
    [[ $YOU ]] \
        && echo " ipfs --timeout 120s cat --progress=false /ipns/${ASTRONAUTENS} ($YOU)" \
        && ipfs --timeout 120s cat --progress=false /ipns/${ASTRONAUTENS} > ~/.zen/tmp/astronaut_TW.html
    #~ [[ ! -s ~/.zen/tmp/astronaut_TW.html ]] && echo "curl -m 12 $LIBRA/ipns/${ASTRONAUTENS}" && curl -m 12 -so ~/.zen/tmp/astronaut_TW.html "$LIBRA/ipns/${ASTRONAUTENS}"
    [[ ! -s ~/.zen/tmp/astronaut_TW.html ]] && espeak "WARNING. WARNING. impossible to find your TW online"
    [[ ! -s ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html ]] && espeak "FATAL ERROR. No player TW copy found ! EXIT" && exit 1
    ## TODO : CHECK CACHE LAST MODIFIED
    echo "%%%%%%%%%%%%%% I GOT YOUR TW %%%%%%%%%%%%%%%%%%%%%%%%%%"

    [[ -s ~/.zen/tmp/astronaut_TW.html ]] \
    && cp -f ~/.zen/tmp/astronaut_TW.html ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html \
    && espeak "TW Found" \
    || espeak "USING LOCAL COPY"
    ###############################

    echo "Adding ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/${MEDIAKEY}.dragdrop.json
    To TW $PSEUDO / ${PLAYER} : $myIPFS/ipns/$ASTRONAUTENS"
    tiddlywiki --load ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html \
                --import ~/Astroport/${PLAYER}/${CAT}/${MEDIAID}/${MEDIAKEY}.dragdrop.json "application/json" \
                --output ~/.zen/tmp --render "$:/core/save/all" "newindex.html" "text/plain"

    if [[ -s ~/.zen/tmp/newindex.html ]]; then

        NEWTW=$(ipfs add -Hq ~/.zen/tmp/newindex.html | tail -n 1)
        ################################################
        ## UPDATE TW CHAIN WITH PREVIOUSLY RECORDED CHAIN
        tiddlywiki --load ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html \
            --output ~/.zen/tmp/${MOATS} \
            --render '.' 'Astroport.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Astroport'
        ASTROPORT=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].astroport)
        CURCHAIN=$(cat ~/.zen/tmp/${MOATS}/Astroport.json | jq -r .[].chain | rev | cut -f 1 -d '/' | rev) # Remove "/ipfs/" part
        [[ $CURCHAIN == "" ||  $CURCHAIN == "null" ]] &&  CURCHAIN="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" # AVOID EMPTY
        echo "CURCHAIN=$CURCHAIN"

        echo "$MOATS" > ~/.zen/game/players/$PLAYER/ipfs/moa/.moats
        cp ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain \
            ~/.zen/game/players/${PLAYER}/ipfs/moa/.chain.$(cat ~/.zen/game/players/${PLAYER}/ipfs/moa/.moats)
        echo "$NEWTW" > ~/.zen/game/players/$PLAYER/ipfs/moa/.chain

        echo "# CHAIN : $CURCHAIN -> $NEWTW"
        sed -i "s~$CURCHAIN~$NEWTW~g" ~/.zen/tmp/newindex.html
        ################################################
        cp -f ~/.zen/tmp/newindex.html ~/.zen/game/players/${PLAYER}/ipfs/moa/index.html

        espeak "I P N S Publishing. Please wait..."
        ipfs name publish --key=${PLAYER} /ipfs/$NEWTW

        echo "================================================"
        echo "${PLAYER} : $myIPFS/ipns/$ASTRONAUTENS"
        echo "================================================"
        echo

        [[ $XDG_SESSION_TYPE == 'x11' || $XDG_SESSION_TYPE == 'wayland' ]] && xdg-open "http://ipfs.localhost:8080/ipfs/$NEWTW"

    else

        espeak "Warning. Could not import Tiddler. You must add it by hand."

    fi

    espeak "OK We did it"

else

    espeak "Sorry. No Tiddler found"

fi

end=`date +%s`
dur=`expr $end - $start`
espeak "It tooks $dur seconds to acomplish"

exit 0
