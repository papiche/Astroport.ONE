#!/bin/bash
########################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# COPY ~/Astroport/* files to IPFS
# Publish INDEX ~/.zen/game/players/$PLAYER/ipfs/.*/${PREFIX}ASTRXBIAN
######## #### ### ## #
start=`date +%s`

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/my.sh"

ME="${0##*/}"
countMErunning=$(ps auxf --sort=+utime | grep -w $ME | grep -v -E 'color=auto|grep' | wc -l)
[[ $countMErunning -gt 2 ]] && echo "$ME already running $countMErunning time" && exit 0

YOU=$(myIpfsApi);
[[ ! $IPFSNODEID ]] && echo 'ERROR missing IPFS Node id !! IPFS is not responding !?' && exit 1

alias zenity='zenity 2> >(grep -v GtkDialog >&2)'

# ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/Astroport/kodi/vstream/${PREFIX}ASTRXBIAN
# Astropot/Kodi/Vstream source reads ${PREFIX}ASTRXBIAN from $myIPFS/.$IPFNODEID/
# Index File Format (could be enhanced) is using Kodi TMDB enhancement
# https://github.com/Kodi-vStream/venom-xbmc-addons/wiki/Voir-et-partager-sa-biblioth%C3%A8que-priv%C3%A9e#d%C3%A9clarer-des-films
########################################################################
## RUN inotifywait process ~/Astroport/ NEW FILE DETECT
# /usr/bin/inotifywait -r -e close_write -m /home/$YOU/astroport | while read dir flags file; do ~/.zen/Astroport.ONE/tools/new_file_in_astroport.sh "$dir" "$file"; done &
# mkdir -p ~/Astroport/youtube
# mkdir -p ~/Astroport/mp3
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

### ECHO COMMAND RECEIVED
echo "$MY_PATH/new_file_in_astroport.sh PATH/ \"$path\" FILE \"$file\" G1PUB \"$G1PUB\" "

################################################
## FILE ANALYSE & IDENTIFICATION TAGGINGS
extension="${file##*.}"
TITLE="${file%.*}"
    # CapitalGluedTitle
    CapitalGluedTitle=$(echo "${TITLE}" | sed -r 's/\<./\U&/g' | sed 's/ //g')

# .part file false flag correcting (in case inotify has launched script)
[[ ! -f "${path}${file}" ]] && file="${TITLE%.*}" && extension="${TITLE##*.}" && [[ ! -f "${path}${file}" ]] && er="NO FILE" && echo "$er" && exit 1

MIME=$(file --mime-type -b "${path}${file}")



    ############# EXTEND MEDIAKEY IDENTIFATORS https://github.com/NapoleonWils0n/ffmpeg-scripts
    if [[ $(echo "$MIME" | grep 'video') ]]; then
        ## Create gifanime ##  TODO Search for similarities BEFORE ADD
        echo "(✜‿‿✜) GIFANIME (✜‿‿✜)"
        $(${MY_PATH}/make_video_gifanim_ipfs.sh "$path" "$file" | tail -n 1)
        [ $HOP -gt 0 ] && espeak "HOP $HOP. File is ready for Astroport Now" && echo "HOP HOP HOP $HOP" && exit 0
        echo "$DUREE GIFANIM ($PROBETIME) : /ipfs/$ANIMH"
    fi

########################################################################
# GET CONNECTED PLAYER
########################################################################
[[ ! $G1PUB ]] && G1PUB=$(cat ~/.zen/game/players/.current/.g1pub 2>/dev/null)

PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null);
[[ ! $PLAYER ]] && echo "(╥☁╥ ) No current player. Please Login" && exit 1

# NOT CURRENT PLAYER (CHECK FOR TW & KEY
[[ $(ipfs key list -l | grep -w $G1PUB) ]] \
&& echo "(ᵔ◡◡ᵔ) INVITATION $G1PUB"  \
&& ASTRONS=$($MY_PATH/g1_to_ipfs.py "$G1PUB") \
&& $MY_PATH/TW.cache.sh $ASTRONS $MOATS \
|| echo "(╥☁╥ ) I cannot help you"

########################################################################

## Indicate IPFSNODEID copying
mkdir -p ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}

### SOURCE IS ~/Astroport/ !!
[[ ! $(echo "$path" | cut -d '/' -f 4 | grep 'Astroport') ]] && er="Les fichiers sont à placer dans ~/Astroport/ MERCI" && echo "$er" && exit 1

### TyPE & type & T = related to ~/astroport location of the infile (mimetype subdivision)
TyPE=$(echo "$path" | cut -d '/' -f 5 ) # ex: /home/$YOU/Astroport/... TyPE(film, youtube, mp3, video, page)/ REFERENCE /
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
        REFERENCE=$(echo "$path" | cut -d '/' -f 6 )
        TITLE="${file%.*}"
    ;;
    youtube)
        INDEXPREFIX="YOUTUBE_"
        REFERENCE=$(echo "$path" | cut -d '/' -f 6 )
        TITLE="${file%.*}"
    ;;
    page)
        INDEXPREFIX="PAGE_"
        REFERENCE=$(echo "$path" | cut -d '/' -f 6 )
        TITLE="${file%.*}"
    ;;
    film | serie)
        INDEXPREFIX="TMDB_"
        REFERENCE=$(echo "$path" | cut -d '/' -f 6 ) # Path contains TMDB id
        if ! [[ "$REFERENCE" =~ ^[0-9]+$ ]] # ${REFERENCE} NOT A NUMBER
        then
            er="$er | ERROR: $path BAD TMDB code. Get it from https://www.themoviedb.org/ or use your a mobile phone number ;)"
            echo "$er"
            exit 1
        fi
    ;;
    ## TODO ADD "httrack" for website copying
    ## httrack "https://wiki.lowtechlab.org" -O "./wiki.lowtechlab.org" "+*.lowtechlab.org/*" -v -%l "fr"
    ##
    *)
        er="$type inconnu" && echo "$er" && exit 1
    ;;
esac

### SET MEDIAKEY
MEDIAKEY="${INDEXPREFIX}${REFERENCE}"
echo ">>>>>>>>>> $MEDIAKEY ($MIME) <<<<<<<<<<<<<<<"

######################### Decimal convert
    rm ~/.zen/tmp/decimal
    echo "$CapitalGluedTitle" > ~/.zen/tmp/convert

    # iteracte through each like
    while read -r -n1 char; do
        arr+=$(printf '%d+' "'$char");
    done <<< ~/.zen/tmp/convert

    printf '%s' "${arr[@]::-3}" > ~/.zen/tmp/decimal
    ## TODO USE IT TO MAKE A MEDIAKEY IMAGE KEY "SONDE" FOR FILTERING ?
    # ISSUE11 : https://git.p2p.legal/qo-op/Astroport.ONE/issues/11
##########################

########################################################################
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
echo IPFS ADD time was $ipfsdur seconds.
###########################################################
############################################
################################
APPNAME="KEY"
echo "-----------------------------------------------------------------"
echo "IPFS $file DIRECTORY: ipfs ls /ipfs/$IPFSREPFILEID"
echo "APP $APPNAME OUTPUT -----------------------------------------------------------------"
echo "$HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/${APPNAME}/${MIME}/${MEDIAKEY}/${G1PUB}/ "

URLENCODE_FILE_NAME=$(echo ${file} | jq -Rr @uri)

### MEDIAKEY FORGE
########################################################################
## CREATE NEW ipns KEY : ${MEDIAKEY}
########################################################################
## IPFS SELF IPNS DATA STORAGE
## ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/
########################################################################
if [[ ! $(ipfs key list | grep -w "${MEDIAKEY}") ]]; then
    echo "CREATING NEW IPNS $MEDIAKEY"
    ## IPNS KEY CREATION ?
    mkdir -p ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}
    KEY=$(ipfs key gen "${MEDIAKEY}")
    KEYFILE=$(~/.zen/Astroport.ONE/tools/give_me_keystore_filename.py "${MEDIAKEY}") # better method applied
fi

## IS IT NEW IPNS KEY?
if [[ $KEY ]]; then
    # memorize IPNS key filename for easiest exchange
    echo "$KEYFILE" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipns.key.keystore_filename
    # Publishing IPNS key
    echo "$KEY" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipns.link
    # CREATE .zen = ZEN economic value counter
    touch ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.zen
    ################ STORE ENCRYPT keystore/$KEYFILE
    cp ~/.ipfs/keystore/$KEYFILE ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/
else
    KEY=$(cat ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipns.link)
    KEYFILE=$(cat ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipns.key.keystore_filename)
    echo "## ALREADY EXISTING IPNS KEY $KEYFILE ($KEY)"
fi


########################################################################
# type TW PUBLISHING
########################################################################
if [[ "${type}" =~ ^(page|film|serie|youtube|video)$ ]]
then

    ## ASK FOR EXTRA METADATA
[[ ! $3 ]] && OUTPUT=$(zenity --forms --width 480 --title="METADATA" --text="Metadonnées (séparateur espace)" --separator="~" --add-entry="Description" --add-entry="extra tag(s)")
[[ ! $3 ]] && DESCRIPTION=$(awk -F '~' '{print $1}' <<<$OUTPUT)
[[ ! $3 ]] && HASHTAG=$(awk -F '~' '{print $2}' <<<$OUTPUT)

    # # # # ${MOATS}_ajouter_video.txt DATA # # # #
    if [[ -f ~/Astroport/${TyPE}/${REFERENCE}/ajouter_video.txt ]]
    then
        line=$(cat ~/Astroport/${TyPE}/${REFERENCE}/ajouter_video.txt | sed "s/_IPFSREPFILEID_/$IPFSREPFILEID/g" | sed "s/_IPNSKEY_/$IPNS/g" )
    else
        line="$type;${REFERENCE};$YEAR;$TITLE;$SAISON;;${IPNS};$RES;/ipfs/$IPFSREPFILEID/$URLENCODE_FILE_NAME"
    fi
    echo "-------------------- ${MOATS}_ajouter_video.txt  -----------------------------"
    echo "$line"
    echo "UPDATE ~/Astroport/${TyPE}/${REFERENCE}/ajouter_video.txt"
    echo "$line" > ~/Astroport/${TyPE}/${REFERENCE}/${MOATS}_ajouter_video.txt

    echo "----------------- GETTING  METADATA ----------------------"
    CAT=$(echo "$type" | sed -r 's/\<./\U&/g' | sed 's/ //g') # CapitalGluedWords
    GENRE=$(cat ~/Astroport/${TyPE}/${REFERENCE}/${MOATS}_ajouter_video.txt | cut -d ';' -f 6 | sed 's/|/ /g' | jq -r '@csv' | sed 's/ /_/g' | sed 's/,/ /g' | sed 's/\"//g' )
    YEAR=$(cat ~/Astroport/${TyPE}/${REFERENCE}/${MOATS}_ajouter_video.txt | cut -d ';' -f 3 )

    ## Adapt TMDB url for season & tag naming
    [[ $CAT == "Film" ]] \
    && TITLE="$TITLE ($YEAR)" \
    && H1="<h1><a target='tmdb' href='https://www.themoviedb.org/movie/"${REFERENCE}"'>"${TITLE}"</a></h1>" \
    && FILETAG="$CapitalGluedTitle"

    [[ $CAT == "Serie" ]] && H1="<h1><a target='tmdb' href='https://www.themoviedb.org/tv/"${REFERENCE}"'>"${TITLE}"</a></h1>" \
    && SAISON=$(cat ~/Astroport/${TyPE}/${REFERENCE}/${MOATS}_ajouter_video.txt | cut -d ';' -f 5 | cut -d '_' -f 2) \
    && FILETAG=$(echo "$CapitalGluedTitle" | cut -d '_' -f 1)

    [[ $CAT == "Youtube" ]] \
    && H1="<h1><a target='youtube' href='https://www.youtube.com/watch?v="$(cat ${REFERENCE} | rev | cut -d '_' -f 1 | rev)"'>"${TITLE}"</a></h1>" \
    && PATCH="Copier"

    echo $GENRE $SAISON

    ## Add screenshot
    [[ -f $HOME/Astroport/${TyPE}/${REFERENCE}/screen.png ]] && ANIMH=$(ipfs add -q "$HOME/Astroport/${TyPE}/${REFERENCE}/screen.png" | tail -n 1) && PROBETIME=0


    if [[ $(echo "$MIME" | grep 'video') ]]; then

        TEXT="<video controls width=100% poster='/ipfs/"${ANIMH}"'><source src='/ipfs/"${IPFSID}"' type='"${MIME}"'></video>
        <br>{{!!filesize}} - {{!!duration}} sec. - vtratio(dur) =  {{!!vtratio}} ({{!!dur}})<br>
        "$H1"<h2>"$DESCRIPTION"</h2>"

        TidType="text/vnd.tiddlywiki" ## MAYBE REAL ONCE TW CAN SHOW ATTACHED IPFS VIDEO (TODO: TESTINGS)
        TAGS="G1${PATCH}${CAT} ${PLAYER} ${FILETAG} $SAISON $GENRE ipfs ${HASHTAG} $YEAR $MIME"
        # TyPE="$MIME"
        # CANON="/ipfs/"${IPFSID}
        CANON=''
    else
        TidType="${MIME}"
        TITLE="$TITLE.$CAT"
        TEXT='${MEDIAKEY}'
        TAGS="'$:/isAttachment $:/isIpfs G1${CAT} ${PLAYER} ${CapitalGluedTitle} $GENRE ${HASHTAG}"
        CANON="/ipfs/"${IPFSID}
    fi

    ## Archive previous dragdrop.json
    [[ -s ~/Astroport/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json ]] \
    && cp ~/Astroport/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json ~/Astroport/${TyPE}/${REFERENCE}/${MOATS}.${MEDIAKEY}.dragdrop.json

    echo "## Creation json tiddler"
    echo '[
  {
    "text": "'${TEXT}'",
    "title": "'${TITLE}'",
    "season": "'${SAISON}'",
    "created": "'${MOATS}'",
    "resolution": "'${RES}'",
    "duree": "'${DUREE}'",
    "duration": "'${DURATION}'",
    "giftime": "'${PROBETIME}'",
    "vtratio": "'${VTRATIO}'",
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
    "tags": "'${TAGS}'" ' > ~/Astroport/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json

    [[ ${CANON} != "" ]] && echo  ',
    "_canonical_uri": "'${CANON}'"' >> ~/Astroport/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json

    echo '
  }
]
' >> ~/Astroport/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json

echo "~/Astroport/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json copy into Station Balise"

#############################################################################
## ARCHIVE FOR IPFSNODEID CACHE SHARING (APPNAME=KEY)
mkdir -p "$HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MIME}/${MEDIAKEY}/${G1PUB}/"
cp ~/Astroport/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json "$HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MIME}/${MEDIAKEY}/${G1PUB}/tiddler.json"
#############################################################################

## TODO : Do we keep that ?
# echo "SEND TW LINK to GCHANGE MESSAGE"
[[ $3 ]] && ~/.zen/Astroport.ONE/tools/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "$myDATA" send -d "$3" -t "${TITLE} ${MEDIAKEY}" -m "MEDIA : $myIPFSGW/ipfs/${IPFSREPFILEID}"

fi

########################################################################
## COPY LOCALHOST IPFS URL TO CLIPBOARD
[[ $(which xclip) ]] &&\
        echo "$myIPFS/ipfs/$IPFSREPFILEID/$URLENCODE_FILE_NAME" | xclip -selection c
########################################################################

########################################################################
# echo "DUNIKEY PASS $PASS"
echo "NEW $TyPE ($file) ADDED. $myIPFS/ipfs/$IPFSREPFILEID/$URLENCODE_FILE_NAME"
echo "VIDEO IPNS LINK : $myIPFS/ipns/$KEY/$G1PUB/  = Create 'G1${CAT}.sh' to adapt 20H12 Ŋ1 process"
echo "#### EXCECUTION TIME"
end=`date +%s`
dur=`expr $end - $start`
echo ${MOATS}:${G1PUB}:${PLAYER}:NewFile:$dur:${MEDIAKEY} >> ~/.zen/tmp/${IPFSNODEID}/_timings
cat ~/.zen/tmp/${IPFSNODEID}/_timings | tail -n 1
echo "########################################################################"


[[ ! $3 ]] && zenity --warning --width 300 --text "Votre MEDIA a rejoint ASTROPORT en `expr $end - $start` secondes"

exit 0


