#!/bin/bash
########################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# COPY ~/astroport/* files to IPFS
# Publish INDEX ~/.zen/game/players/$PLAYER/ipfs/.*/${PREFIX}ASTRXBIAN
######## #### ### ## #
start=`date +%s`

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
countMErunning=$(ps auxf --sort=+utime | grep -w $ME | grep -v -E 'color=auto|grep' | wc -l)
[[ $countMErunning -gt 2 ]] && echo "$ME already running $countMErunning time" && exit 0

YOU=$(ipfs swarm peers >/dev/null 2>&1 && echo "$USER" || ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)
[[ ! $IPFSNODEID ]] && echo 'ERROR missing IPFS Node id !! IPFS is not responding !?' && exit 1

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)
myIP=$(hostname -I | awk '{print $1}' | head -n 1)
isLAN=$(echo $myIP | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")
[[ ! $myIP || $isLAN ]] && myIP="ipfs.localhost"

alias zenity='zenity 2> >(grep -v GtkDialog >&2)'

# ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/${PREFIX}ASTRXBIAN
# Astropot/Kodi/Vstream source reads ${PREFIX}ASTRXBIAN from http://${myIP}:8080/.$IPFNODEID/
# Index File Format (could be enhanced) is using Kodi TMDB enhancement
# https://github.com/Kodi-vStream/venom-xbmc-addons/wiki/Voir-et-partager-sa-biblioth%C3%A8que-priv%C3%A9e#d%C3%A9clarer-des-films
########################################################################
## RUN inotifywait process ~/astroport/ NEW FILE DETECT
# /usr/bin/inotifywait -r -e close_write -m /home/$YOU/astroport | while read dir flags file; do ~/.zen/Astroport.ONE/tools/new_file_in_astroport.sh "$dir" "$file"; done &
# mkdir -p ~/astroport/youtube
# mkdir -p ~/astroport/mp3
########################################################################
path="$1"

if [[ "$path" == "" ]]; then
    echo "## BATCH RUN. READ FIFO FILE."
fi

# Add trailing / if needed
length=${#path}
last_char=${path:length-1:1}
[[ $last_char != "/" ]] && path="$path/"; :

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

        FILE_RES=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "${path}${file}" | cut -d "x" -f 2)
        RES=${FILE_RES%?}0p

        DURATION=$(ffprobe -i "${path}${file}" -show_entries format=duration -v quiet -of csv="p=0" | cut -d '.' -f 1)
        DUREE=$(ffprobe -i "${path}${file}" -show_entries format=duration -sexagesimal -v quiet -of csv="p=0"| cut -d '.' -f 1)

        PROBETIME=$(echo "0.618 * $DURATION" | bc -l | cut -d '.' -f 1)
        [[ ! $PROBETIME ]] && PROBETIME="1.0"

        ## Create gifanime ##  TODO Search for similarities BEFORE ADD
        echo "(✜‿‿✜) GIFANIME (✜‿‿✜)"
        rm -f ~/.zen/tmp/screen.gif
        ffmpeg -loglevel quiet -ss $PROBETIME -t 1.6 -loglevel quiet -i "${path}${file}" ~/.zen/tmp/screen.gif
        ANIMH=$(ipfs add -q ~/.zen/tmp/screen.gif)
        echo "GIFANIM $PROBETIME : /ipfs/$ANIMH"

    fi

########################################################################
# GET CONNECTED PLAYER
########################################################################
[[ ! $G1PUB ]] && G1PUB=$(cat ~/.zen/game/players/.current/.g1pub 2>/dev/null)

PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null);
[[ ! $PLAYER ]] && echo "(╥☁╥ ) No current player. Please Login" && exit 1

# NOT CURRENT PLAYER (CHECK FOR TW & KEY
[[ $G1PUB != $(cat ~/.zen/game/players/.current/.g1pub 2>/dev/null) ]] \
&& [[ $(ipfs key list -l | grep -v $G1PUB) ]] \
&& echo "(ᵔ◡◡ᵔ) INVITATION $G1PUB"  \
&& ASTRONS=$($MY_PATH/tools/g1_to_ipfs.py "$G1PUB") \
&& $MY_PATH/tools/TW.cache.sh $ASTRONS $MOATS \
|| echo "(╥☁╥ ) I cannot help you"

########################################################################

## Indicate IPFSNODEID copying
mkdir -p ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}

### SOURCE IS ~/astroport/ !!
[[ ! $(echo "$path" | cut -d '/' -f 4 | grep 'astroport') ]] && er="Les fichiers sont à placer dans ~/astroport/ MERCI" && echo "$er" && exit 1

### TyPE & type & T = related to ~/astroport location of the infile (mimetype subdivision)
TyPE=$(echo "$path" | cut -d '/' -f 5 ) # ex: /home/$YOU/astroport/... TyPE(film, youtube, mp3, video, page)/ REFERENCE /
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
        ## DIFFERENT TREATMENT
        INDEXPREFIX="PAGE_"
        REFERENCE=$(echo "$path" | cut -d '/' -f 6 )
        TITLE="${file%.*}"
    ;;
    mp3)
        ## DIFFERENT TREATMENT
        INDEXPREFIX="MP3_"
        REFERENCE=$(echo "$path" | cut -d '/' -f 6 )
        TITLE=$(echo "$file" | cut -d "&" -f 2-)
        er="$er | Please use new_mp3_in_astroport.sh ... EXIT"
        echo "$er"
        exit 1
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

## RUBISH ??
########################################################################
mkdir -p ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/
echo "ADDING ${path}${file} to IPFS "
echo "~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/${PREFIX}ASTRXBIAN"
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
    if [[ -f ~/astroport/${TyPE}/${REFERENCE}/ajouter_video.txt ]]
    then
        line=$(cat ~/astroport/${TyPE}/${REFERENCE}/ajouter_video.txt | sed "s/_IPFSREPFILEID_/$IPFSREPFILEID/g" | sed "s/_IPNSKEY_/$IPNS/g" )
    else
        line="$type;${REFERENCE};$YEAR;$TITLE;$SAISON;;${IPNS};$RES;/ipfs/$IPFSREPFILEID/$URLENCODE_FILE_NAME"
    fi
    echo "-------------------- ${MOATS}_ajouter_video.txt  -----------------------------"
    echo "$line"
    echo "UPDATE ~/astroport/${TyPE}/${REFERENCE}/ajouter_video.txt"
    echo "$line" > ~/astroport/${TyPE}/${REFERENCE}/ajouter_video.txt

    ## MOATS TIMESTAMPING
    cp ~/astroport/${TyPE}/${REFERENCE}/ajouter_video.txt ~/astroport/${TyPE}/${REFERENCE}/${MOATS}_ajouter_video.txt

    echo "----------------- GETTING  METADATA ----------------------"
    CAT=$(echo "$type" | sed -r 's/\<./\U&/g' | sed 's/ //g') # CapitalGluedWords
    GENRE=$(cat ~/astroport/${TyPE}/${REFERENCE}/${MOATS}_ajouter_video.txt | cut -d ';' -f 6 | sed 's/|/ /g' | jq -r '@csv' | sed 's/ /_/g' | sed 's/,/ /g' | sed 's/\"//g' )

    ## Adapt TMDB url for season & tag naming
    [[ $CAT == "Film" ]] && tdb="movie"\
    && FILETAG="$CapitalGluedTitle"

    [[ $CAT == "Serie" ]] && tdb="tv" \
    && SAISON=$(cat ~/astroport/${TyPE}/${REFERENCE}/${MOATS}_ajouter_video.txt | cut -d ';' -f 5 | cut -d '_' -f 2) \
    && FILETAG=$(echo "$CapitalGluedTitle" | cut -d '_' -f 1)

    echo $GENRE $SAISON

    ## Add screenshot (TODO : Make it better. Check what to put; if used & usefull
    [[ -f $HOME/astroport/${TyPE}/${REFERENCE}/screen.png ]] && IPSCREEN=$(ipfs add -q "$HOME/astroport/${TyPE}/${REFERENCE}/screen.png" | tail -n 1)
    [[ $IPSCREEN ]] && POSTER=$IPSCREEN

    [[ -f $HOME/astroport/${TyPE}/${REFERENCE}/thumbnail.png ]] && IPTHUMB=$(ipfs add -q "$HOME/astroport/${TyPE}/${REFERENCE}/thumbnail.png" | tail -n 1)
    [[ $IPTHUMB ]] && POSTER=$IPTHUMB

    if [[ $(echo "$MIME" | grep 'video') ]]; then

        TEXT="<video controls width=100% poster='/ipfs/"${ANIMH}"'><source src='/ipfs/"${IPFSID}"' type='"${MIME}"'>
        </video><h1><a target='tmdb' href='https://www.themoviedb.org/"${tdb}"/"${REFERENCE}"'>"${TITLE}"</a></h1>
        <h2>"$DESCRIPTION"</h2>
        <img src='/ipfs/"${POSTER}"' width=33%><br>
    <\$button class='tc-tiddlylink'>
    <\$list filter='[tag[G1${CAT}]]'>
   <\$action-navigate \$to=<<currentTiddler>> \$scroll=no/>
    </\$list>
    Afficher tous les G1${CAT}
    </\$button>"
        TidType="text/vnd.tiddlywiki" ## MAYBE REAL ONCE TW CAN SHOW ATTACHED IPFS VIDEO (TODO: TESTINGS)
        TAGS="G1${CAT} ${PLAYER} ${FILETAG} $SAISON $GENRE ipfs ${HASHTAG}"
        # TyPE="$MIME"
        # CANON="/ipfs/"${IPFSID}
        CANON=''
    else
        TidType="${MIME}"
        TEXT='${MEDIAKEY}'
        TAGS="'$:/isAttachment $:/isIpfs G1${CAT} ${PLAYER} ${CapitalGluedTitle} $GENRE ${HASHTAG}"
        CANON="/ipfs/"${IPFSID}
    fi

    ## Archive previous dragdrop.json
    [[ -s ~/astroport/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json ]] \
    && cp ~/astroport/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json ~/astroport/${TyPE}/${REFERENCE}/${MOATS}.${MEDIAKEY}.dragdrop.json

    echo "## Creation json tiddler"
    echo '[
  {
    "text": "'${TEXT}'",
    "title": "'${CapitalGluedTitle}'",
    "season": "'${SAISON}'",
    "created": "'${MOATS}'",
    "resolution": "'${RES}'",
    "duree": "'${DUREE}'",
    "duration": "'${DURATION}'",
    "giftime": "'${PROBETIME}'",
    "gifanime": "'/ipfs/${ANIMH}'",
    "type": "'${TidType}'",
    "mime": "'${MIME}'",
    "ipfsdur": "'${ipfsdur}'",
    "cat": "'${CAT}'",
    "size": "'${FILE_BSIZE}'",
    "description": "'${DESCRIPTION}'",
    "poster": "'/ipfs/${POSTER}'",
    "ipfsroot": "'/ipfs/${IPFSREPFILEID}'",
    "file": "'${file}'",
    "ipfs": "'/ipfs/${IPFSREPFILEID}/${URLENCODE_FILE_NAME}'",
    "mediakey": "'${MEDIAKEY}'",
    "ipns": "'/ipns/${IPNS}'",
    "tmdb": "'${REFERENCE}'",
    "modified": "'${MOATS}'",
    "tags": "'${TAGS}'" ' > ~/astroport/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json

    [[ ${CANON} != "" ]] && echo  ',
    "_canonical_uri": "'${CANON}'"' >> ~/astroport/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json

    echo '
  }
]
' >> ~/astroport/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json

echo "~/astroport/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json copy into Station Balise"

#############################################################################
## ARCHIVE FOR IPFSNODEID CACHE SHARING (APPNAME=KEY)
mkdir -p "$HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MIME}/${MEDIAKEY}/${G1PUB}/"
cp ~/astroport/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json "$HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MIME}/${MEDIAKEY}/${G1PUB}/tiddler.json"
#############################################################################

## TODO : Do we keep that ?
# echo "SEND TW LINK to GCHANGE MESSAGE"
[[ $3 ]] && ~/.zen/Astroport.ONE/tools/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "https://data.gchange.fr" send -d "$3" -t "${TITLE} ${MEDIAKEY}" -m "MEDIA : http://astroport.com:8080/ipfs/${IPFSREPFILEID}"

# Couldl be used by caroussel.html template
# CAROUSSEL=$(ipfs add -wq ~/astroport/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json | head-n 1)

# COPY TIDDLER JSON TO DESKTOP Journal/${TyPE}
#    [[ "$USER" != "xbian" && -d ~/Bureau ]] && mkdir -p ~/Bureau/Journal/${TyPE} && cp ~/astroport/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json "$HOME/Bureau/Journal/${TyPE}/${TITLE}.dragdrop.json" && xdg-open "$HOME/Bureau/Journal/${TyPE}/"
#    [[ "$USER" != "xbian" && -d ~/Desktop ]] && mkdir -p ~/Desktop/Journal/${TyPE} && cp ~/astroport/${TyPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json "$HOME/Desktop/Journal/${TyPE}/${TITLE}.dragdrop.json" && xdg-open "$HOME/Desktop/Journal/${TyPE}/"

fi

########################################################################
## COPY LOCALHOST IPFS URL TO CLIPBOARD
[[ $(which xclip) ]] &&\
        echo "http://${myIP}:8080/ipfs/$IPFSREPFILEID/$URLENCODE_FILE_NAME" | xclip -selection c
########################################################################

########################################################################
# echo "DUNIKEY PASS $PASS"
echo "NEW $TyPE ($file) ADDED. http://${myIP}:8080/ipfs/$IPFSREPFILEID/$URLENCODE_FILE_NAME"
echo "VIDEO IPNS LINK : http://${myIP}:8080/ipns/$KEY/$G1PUB/  = Create 'G1${CAT}.sh' to adapt 20H12 Ŋ1 process"
echo "#### EXCECUTION TIME"
end=`date +%s`
dur=`expr $end - $start`
echo ${MOATS}:${G1PUB}:${PLAYER}:NewFile:$dur:${MEDIAKEY} >> ~/.zen/tmp/${IPFSNODEID}/_timings
cat ~/.zen/tmp/${IPFSNODEID}/_timings | tail -n 1
echo "########################################################################"


[[ ! $3 ]] && zenity --warning --width 300 --text "Votre MEDIA a rejoint ASTROPORT en `expr $end - $start` secondes"

exit 0


