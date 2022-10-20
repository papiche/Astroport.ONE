#!/bin/bash
########################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# COPY ~/astroport/* files to IPFS
# Publish INDEX ~/.zen/game/players/$PLAYER/ipfs/.*/${PREFIX}ASTRXBIAN
######## #### ### ## #
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
countMErunning=$(ps auxf --sort=+utime | grep -w $ME | grep -v -E 'color=auto|grep' | wc -l)
[[ $countMErunning -gt 2 ]] && echo "$ME already running $countMErunning time" && exit 0
start=`date +%s`

YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)
[[ ! $IPFSNODEID ]] && echo 'ERROR missing IPFS Node id !! IPFS is not responding !?' && exit 1




# ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/${PREFIX}ASTRXBIAN
# Astropot/Kodi/Vstream source reads ${PREFIX}ASTRXBIAN from http://127.0.0.1:8080/.$IPFNODEID/
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

echo "~/.zen/Astroport.ONE/tools/new_file_in_astroport.sh PATH/ \"$path\" FILE \"$file\" G1PUB \"$G1PUB\" "

extension="${file##*.}"
TITLE="${file%.*}"

# .part file false flag correcting (inotify mode)
[[ ! -f "${path}${file}" ]] && file="${TITLE%.*}" && extension="${TITLE##*.}" && [[ ! -f "${path}${file}" ]] && er="NO FILE" && echo "$er" && exit 1

# GET PLAYER
PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null);
[[ ! $PLAYER ]] && echo "No current player. Please Login" && exit 1

## Indicate what is the IPFSNODEID copying
mkdir -p ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}

[[ ! $(echo "$path" | cut -d '/' -f 4 | grep 'astroport') ]] && er="Les fichiers sont à placer dans ~/astroport/ MERCI" && echo "$er" && exit 1
TYPE=$(echo "$path" | cut -d '/' -f 5 ) # ex: /home/$YOU/astroport/... TYPE(film, youtube, mp3, video, page)/ REFERENCE /
CAT=$(echo "$TYPE" | awk '{ print tolower($0) }')

echo $CAT

PREFIX=$(echo "$TYPE" | head -c 1 | awk '{ print toupper($0) }' ) # ex: F, Y, M ou Y
# File is placed in ROOT ~/astroport ?
if [[ $PREFIX == "" ]]
then
    [[ "$USER" != "xbian" ]] && zenity --warning --width 300 --text "Désolé votre fichier ne peut pas être traité"
    er="$er | WARNING. $TYPE is root file UNTREATED" && echo "$er" && exit 1
fi

########################################################################
# EXTRACT INDEX REFERENCE : TMDB or YOUTUBE (can be extended with new )
########################################################################
case ${CAT} in
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
            er="$er | ERROR: $path BAD TMDB code. Get it from https://www.themoviedb.org/ or use your 06 phone number"
            echo "$er"
            exit 1
        fi
    ;;
    ## TODO ADD "httrack" for website copying
    ## httrack "https://wiki.lowtechlab.org" -O "./wiki.lowtechlab.org" "+*.lowtechlab.org/*" -v -%l "fr"
    ##
    *)
        er="$CAT inconnu" && echo "$er" && exit 1
    ;;
esac

MEDIAKEY="${INDEXPREFIX}${REFERENCE}"

########################################################################
mkdir -p ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/
echo "ADDING ${path}${file} to IPFS and create ${PREFIX}ASTRXBIAN INDEX"
echo "~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/${PREFIX}ASTRXBIAN"
echo "-----------------------------------------------------------------"

IPFS=$(ipfs add -wq "${path}${file}")
IPFSREPFILEID=$(echo $IPFS | cut -d ' ' -f 2)
IPFSID=$(echo $IPFS | cut -d ' ' -f 1)
[[ $IPFSREPFILEID == "" ]] && echo "ipfs add ERROR" && exit 1
echo "-----------------------------------------------------------------"
echo "IPFS $file DIRECTORY: ipfs ls /ipfs/$IPFSREPFILEID"
echo "-----------------------------------------------------------------"
echo "New $TYPE INDEX ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/${PREFIX}ASTRXBIAN "

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
#    KEYFILE=$(ls -t ~/.ipfs/keystore/ | head -n 1) # get name of last created key (could be fooled during stargate exchange)
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
    # CREATE other encrypted copies for friends depending DEFCON & stars
    # > STARGATE 1 - 2 - 3 - 4 - 5 !!
    ################ ENCRYPT keystore/$KEYFILE
else
    KEY=$(cat ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipns.link)
    KEYFILE=$(cat ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipns.key.keystore_filename)
    echo "## ALREADY EXISTING IPNS KEY $KEYFILE ($KEY)"
fi

[[ ! $KEY ]] && echo "FATAL ERROR" && exit 1
########################################################################
## add default metadata (TODO = use json file?)
########################################################################
FILE_BSIZE=$(du -b "${path}${file}" | awk '{print $1}')
echo "${FILE_BSIZE}" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.filesize
echo "${file}" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipfs.filename
echo "${TITLE}" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.title
echo "$(date -u +%s%N | cut -b1-13)" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.timestamp
## INIT MEDIAKEY .views.counter
echo "0" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.views.counter
########################################################################

########################################################################
# Prepare IPFS links (then cyphered to manage exchange regulation)
########################################################################
echo "/ipfs/$IPFSREPFILEID/${file}" > ~/.zen/tmp/.ipfs.filelink
echo "$IPFSID" > ~/.zen/tmp/.ipfsid
########################################################################

########################################################################
################ ask autoPIN to one shuffle A_boostrap_nodes
########################################################################
PINIPFSnode=$(cat ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | grep -Ev "#" | shuf | tail -n 1)
nodeid=${PINIPFSnode##*/}
PINnode=$(~/.zen/Astroport.ONE/tools/ipfs_to_g1.py $nodeid)

echo "ASK AUTOPIN to $PINnode"
## CREATE $PINnode IPFS communication directory
if [[ ! -d ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode} && "$PINnode" != "$G1PUB" ]]; then
    mkdir -p ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}
    ## ENCRYPT .ipfsid & .ipfs.filelink (THESE FILES ARE
    $MY_PATH/natools.py encrypt -p $PINnode -i ~/.zen/tmp/.ipfs.filelink -o "~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}/.ipfs.filelink.encrypt"
    $MY_PATH/natools.py encrypt -p $PINnode -i ~/.zen/tmp/.ipfsid -o "~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}/.ipfsid.encrypt"
    # .ipfsid.encrypt is searched by each Station running ./zen/tools/autoPINfriends.sh
fi

## Ask PIN to myself
mkdir -p ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${G1PUB}
$MY_PATH/natools.py encrypt -p $G1PUB -i ~/.zen/tmp/.ipfs.filelink -o "~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${G1PUB}/.ipfs.filelink.encrypt"
$MY_PATH/natools.py encrypt -p $G1PUB -i ~/.zen/tmp/.ipfsid -o "~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${G1PUB}/.ipfsid.encrypt"


########################################################################
## GREAT natools can convert IPNS MEDIAKEY into .dunikey file
########################################################################
# CREATING QRCODE
$MY_PATH/natools.py privkey -f ipfs-keystore -k $HOME/.ipfs/keystore/$KEYFILE -F pubsec -o ~/.zen/tmp/${MEDIAKEY}.dunikey
# PubFromDunikey=$(cat ~/.zen/tmp/${MEDIAKEY}.dunikey | grep "sec" | cut -d ' ' -f2 | base58 -d | tail -c+33 | base58) ## HOWTO EXTRACT PUBKEY FROM SECKEY
PubFromDunikey=$(cat ~/.zen/tmp/${MEDIAKEY}.dunikey | grep "pub" | cut -d ' ' -f2)
qrencode -s 6 -o "$HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/QR.png" "$PubFromDunikey"
echo "$PubFromDunikey" > $HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/MEDIAPUBKEY

########################################################################
## MEDIAKEY => DUNIKEY + PASS 6 DIGITS openssl protection
########################################################################
PASS=$(echo "${RANDOM}${RANDOM}${RANDOM}${RANDOM}" | tail -c-7) && echo "$PASS" > ~/.zen/tmp/${MEDIAKEY}.pass
openssl enc -aes-256-cbc -salt -in ~/.zen/tmp/${MEDIAKEY}.dunikey -out "$HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/dunikey.enc" -k $PASS

## STATION & BOOTSTRAP ACCESS TO PASS
$MY_PATH/natools.py encrypt -p $G1PUB -i ~/.zen/tmp/${MEDIAKEY}.pass -o $HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.pass.encrypt
$MY_PATH/natools.py encrypt -p $PINnode -i ~/.zen/tmp/${MEDIAKEY}.pass -o $HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}/.pass.encrypt

## DECODE MEDIAKEY.dunikey ##
# ~/.zen/Astroport.ONE/tools/natools.py decrypt -f pubsec -k "$HOME/.zen/secret.dunikey" -i "$HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.pass.encrypt" -o "~/.zen/tmp/${MEDIAKEY}.pass"
# openssl enc -aes-256-cbc -d -in "$HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/dunikey.enc" -out "~/.zen/tmp/${MEDIAKEY}.dunikey" -k $(cat "~/.zen/tmp/${MEDIAKEY}.pass")
rm ~/.zen/tmp/${MEDIAKEY}.dunikey

########################################################################
## GET .ipfs/keystore file MAHE .ipns.mediakey.encrypt
# used in ipns_TAG_refresh.sh & autoPINfriends.sh
########################################################################
$MY_PATH/natools.py encrypt -p $G1PUB -i $HOME/.ipfs/keystore/$KEYFILE -o $HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipns.mediakey.encrypt
$MY_PATH/natools.py encrypt -p $PINnode -i $HOME/.ipfs/keystore/$KEYFILE -o $HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}/.ipns.mediakey.encrypt

## Init zen, views counters & visitor
echo "0" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}/.zen
echo "0" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}/.views.counter
echo "anonymous" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}/.visitor
########################################################################
# MEMORIZE my PIN
mkdir -p ~/.zen/PIN/${IPFSREPFILEID}/
touch ~/.zen/PIN/${IPFSREPFILEID}/${G1PUB}
# echo "$(ipfs key list -l | grep ${MEDIAKEY} | cut -d ' ' -f 1)" > ~/.zen/PIN/${ipfsrepidfile}/IPNSLINK #  NO!!  CHOOSE TODO Would let PINing nodes change index.html///

########################################################################
## encrypt links for myself
########################################################################
$MY_PATH/natools.py encrypt -p ${G1PUB} -i ~/.zen/tmp/.ipfs.filelink -o ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipfs.filelink.natools.encrypt
$MY_PATH/natools.py encrypt -p ${G1PUB} -i ~/.zen/tmp/.ipfsid -o ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipfsid.encrypt
rm ~/.zen/tmp/.ipfs.filelink
rm ~/.zen/tmp/.ipfsid
########################################################################

########################################################################
## ADD "ajouter_video.txt" and "video.json" will be SELF IPNS publish data
## ENCRYPT TO STOP CLEAR DATA LEAKING
[[ -f ~/astroport/${TYPE}/${REFERENCE}/ajouter_video.txt ]] && cp -f ~/astroport/${TYPE}/${REFERENCE}/ajouter_video.txt ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/
[[ -f ~/astroport/${TYPE}/${REFERENCE}/screen.png ]] && cp -f ~/astroport/${TYPE}/${REFERENCE}/screen.png ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/
[[ -f ~/astroport/${TYPE}/${REFERENCE}/youtube.png ]] && cp -f ~/astroport/${TYPE}/${REFERENCE}/youtube.png ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/screen.png
[[ -f ~/astroport/${TYPE}/${REFERENCE}/video.json ]] &&\
    cp -f ~/astroport/${TYPE}/${REFERENCE}/video.json ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/ &&\
    cp -f ~/astroport/${TYPE}/${REFERENCE}/video.json ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/
########################################################################

########################################################################
## EXPLANATIONS
########################################################################
# What is being in ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/
# is published on http://127.0.0.1:8080/ipns/$KEY/ AND ipfs ls /ipns/$KEY/
########################################################################
########################################################################
# CONTRACTS, are small App (fulljs or jquery + nginx backend app server)
# They must decrypt IPFS after succeeding a chalenge (, +/- n zen, ...)
########################################################################
# Contract App Examples (ipns_TAG_refresh.sh makes MEDIAKEY evolution)
# Counting video views = +1 .views.counter => decrypt key
# Balancing Zen wallets = -n form source = +n for destination => decrypt key
########################################################################
# Astroport/Gchange USE as public/private media copy friend of friends swarm
# one star level (no encrypt)
# index.html is presenting Astroport/Kodi service then redirect to
# $G1PUB/index.html contains redirection to ipfs link
## NEW RELEASE
## Create TW5 index.html to give easy control access to MEDIAKEY and KEY owner
########################################################################

########################################################################
## IPNS access to index.html
## Level 1 (not crypted) -> Redirect to ipfs streaming link

IPNSLINK=$(ipfs key list -l | grep -w ${MEDIAKEY} | cut -d ' ' -f 1)
## FIRST REDIRECT PAGE ${MEDIAKEY}/index.html
# https://tube.copylaradio.com/ipns/$IPNSLINK
#envsubst < ./www/boris/youtube_watch_step2.html > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/index.html

    echo "=======> Mediakey Welcome index.html "
    cat ~/.zen/Astroport.ONE/templates/boris/youtube_watch_step2.html \
        | sed "s/_IPNSLINK_/$IPNSLINK/g" \
        | sed "s/_IPFSNODEID_/$IPFSNODEID/g" \
        | sed "s/_PLAYER_/$PLAYER/g" \
        | sed "s/_G1PUB_/$G1PUB/g" \
        | sed "s/_TITLE_/$TITLE/g" \
        > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/index.html

## SECOND REDIRECT PAGE ${MEDIAKEY}/${G1PUB}/index.html
# https://tube.copylaradio.com/ipns/$IPNSLINK/${G1PUB}/

# envsubst < ../www/boris/youtube_watch_step3.html > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/index.html
    echo "=======> Mediakey Contract index.html "
    cat ~/.zen/Astroport.ONE/templates/boris/youtube_watch_step3.html \
    | sed "s/_TITLE_/$TITLE/g" \
    | sed "s/_IPFSNODEID_/$IPFSNODEID/g" \
    | sed "s/_PLAYER_/$PLAYER/g" \
    | sed "s/_IPFSREPFILEID_/$IPFSREPFILEID/g" \
    | sed "s/_URLENCODE_FILE_NAME_/$URLENCODE_FILE_NAME/g" \
    > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/index.html


# echo "<meta http-equiv=\"Refresh\" content=\"0;URL=http://127.0.0.1:8080/ipfs/$IPFSREPFILEID/$URLENCODE_FILE_NAME\">" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/index.html
########################################################################
## TODO ACTIVATE "./zen/ipns_TAG_refresh.sh" (SACEM & Netflix Buziness is HERE!! Add your crypto/contracts there)
########################################################################

########################################################################
########################################################################
## PUBLISH new IPNS
########################################################################
echo "$(date -u +%s%N | cut -b1-13)" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/.timestamp

echo "ipfs add -rHq ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/"
NEWIPFS=$(ipfs add -rHq ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/ | tail -n 1 )
[[ "$NEWIPFS" == "" ]] && echo "~~~ FAILURE ~~~ ipfs add -rHq ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/ | tail -n 1" && exit 1

## ADD CHAIN BLOCK ZERO (will be updated by ipns_TAG_refresh.sh)
echo $NEWIPFS > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/.chain

echo "ipfs name publish --quieter --key=${MEDIAKEY} $NEWIPFS"
IPNS=$(ipfs name publish --quieter --key="${MEDIAKEY}" $NEWIPFS)
[[ "$IPNS" == "" ]] && \
echo "~~~ PROBLEM ~~~ ipfs name publish --quieter --key=${MEDIAKEY} $NEWIPFS" && \
IPNS="$(ipfs key list -l | grep -w ${MEDIAKEY} | cut -f 1 -d ' ')"
echo "${MEDIAKEY} : /ipns/$IPNS"

########################################################################
########################################################################

########################################################################
# POST TRAITEMENTS
########################################################################
# film/serie PUBLISH "ajouter_video.txt" for KODI
########################################################################
if [[ "${CAT}" =~ ^(film|serie|youtube|page|video)$ ]]
then
    ## CREATE GCHANGE AD
    ## STOP PUBLISHING TO GCHANGE, NOW PLAYER TW ONLY
    ## ACTIVATE AGAIN TO MAKE ADVERTISMENT OF YOUR MEDIAKEY ACCES

#    if [[ ! -f ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.gchange.ad && ( "${CAT}" == "film" || "${CAT}" == "serie") ]]
#    then
#
#     GOFFER=$(~/.zen/Astroport.ONE/tools/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "https://data.gchange.fr" setoffer -t "${TITLE} #astroport #${MEDIAKEY}" -d "${TITLE} https://tube.copylaradio.com/ipns/$IPNS/ Faites un don à son portefeuille pour le conserver dans le Mediacenter des Amis - https://CopyLaRadio.com - https://astroport.com" -p $HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/QR.png)
#        echo $GOFFER > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.gchange.ad
#        NEWIPFS=$(ipfs add -rHq ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/ | tail -n 1 )
#        IPNS=$(ipfs name publish --quieter --key="${MEDIAKEY}" $NEWIPFS)
#        [[ "$IPNS" == "" ]] && IPNS="$(ipfs key list -l | grep -w ${MEDIAKEY} | cut -f 1 -d ' ')"
#        echo "Annonce gchange : $(cat ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.gchange.ad)"
#
#    fi

    ########################################################################
    # CREATION DU FICHIER ${PREFIX}ASTRXBIAN FILE : Add Header (TODO DEBUG Kodi Plugin !! )
    mkdir -p ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/
    [[ ! -f ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/${PREFIX}ASTRXBIAN ]] \
    && echo "CAT;TMDB;YEAR;TITLE;SAISON;GENRES;GROUPES;RES;URLS=http://127.0.0.1:8080" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/${PREFIX}ASTRXBIAN

    # ADD NEW LINE TO INDEX
    if [[ -f ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/ajouter_video.txt ]]
    then
        line=$(cat ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/ajouter_video.txt | sed "s/_IPFSREPFILEID_/$IPFSREPFILEID/g" | sed "s/_IPNSKEY_/$IPNS/g" )
    else
        FILE_RES=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "${path}${file}" | cut -d "x" -f 2)
        RES=${FILE_RES%?}0p
        line="$CAT;${REFERENCE};$YEAR;$TITLE;$SAISON;;${IPNS};$RES;/ipfs/$IPFSREPFILEID/$URLENCODE_FILE_NAME"
    fi
    echo "-------------------- UPDATE ${PREFIX}ASTRXBIAN INDEX -----------------------------"
    echo "$line"
    echo "$line" >> ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/${PREFIX}ASTRXBIAN
    echo "UPDATE IPNS ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/ajouter_video.txt"
    echo "$line" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/ajouter_video.txt
    ## UPDATE SOURCE ajouter_video.txt FILE
    cp -f ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/ajouter_video.txt ~/astroport/${TYPE}/${REFERENCE}/ajouter_video.txt

    ########################################################################
    ## TODO: ACTIVATE SUB DEFCON 4 MODE = encrypt/decrypt file in $G1DEST subdirectory
    ########################################################################
    echo "----------------- REFRESH LOCAL KODI INDEX ----------------------"
    cat ~/.zen/game/players/$PLAYER/ipfs*/.*/astroport/kodi/vstream/${PREFIX}ASTRXBIAN | sort | uniq > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/${PREFIX}ASTRXBIAN


    echo "----------------- PREPARING TIDDLER ----------------------"

    GENRE=$(cat ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/ajouter_video.txt | cut -d ';' -f 6 | sed 's/|/ /g' | jq -r '@csv' | sed 's/ /_/g' | sed 's/,/ /g' | sed 's/\"//g' )
    echo $GENRE
    MIME=$(file --mime-type "$HOME/astroport/${TYPE}/${REFERENCE}/${file}" | rev | cut -d ' ' -f 1 | rev)
    REAL=$MIME
    if [[ $(echo "$MIME" | grep 'video') ]]; then
        TEXT="<video controls><source src='/ipfs/"${IPFSID}"' type='"${MIME}"'></video><h1>"${TITLE}"</h1>"
        MIME="text/vnd.tiddlywiki"
        TAGS="${CAT} $GENRE ipfs"
        CANON=''
    else
        TEXT='${MEDIAKEY}'
        TAGS="'$:/isAttachment $:/isIpfs ${CAT} $GENRE"
        CANON="/ipfs/"${IPFSID}
    fi

    ## Add screenshot
    [[ -f $HOME/astroport/${TYPE}/${REFERENCE}/screen.png ]] && SCREENDIR=$(ipfs add -wq "$HOME/astroport/${TYPE}/${REFERENCE}/screen.png" | tail -n 1)
    [[ -f $HOME/astroport/${TYPE}/${REFERENCE}/$CAT.png ]] && SCREENDIR=$(ipfs add -wq "$HOME/astroport/${TYPE}/${REFERENCE}/$CAT.png" | tail -n 1)

    echo "## Creation json tiddler"
    echo '[
  {
    "text": "'${TEXT}'",
    "title": "'${TITLE}'",
    "type": "'${MIME}'",
    "mime": "'${REAL}'",
    "cat": "'${CAT}'",
    "screenshot": "'${SCREENDIR}/screen.png'",
    "ipfsroot": "'${IPFSREPFILEID}'",
    "file": "'${file}'",
    "ipfs": "'/ipfs/${IPFSREPFILEID}/${URLENCODE_FILE_NAME}'",
    "mediakey": "'${MEDIAKEY}'",
    "ipns": "'/ipns/${IPNS}'",
    "tmdb": "'${REFERENCE}'",
    "tags": "'${TAGS}'" ' > ~/astroport/${TYPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json

    [[ ${CANON} != "" ]] && echo  ',
    "_canonical_uri": "'${CANON}'"' >> ~/astroport/${TYPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json

    echo '
  }
]
' >> ~/astroport/${TYPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json

echo "~/astroport/${TYPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json copy into Station Balise"
cp ~/astroport/${TYPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/tiddler.json

## TODO : Do we keep that ?
# echo "SEND TW LINK to GCHANGE MESSAGE"
[[ $3 ]] && ~/.zen/Astroport.ONE/tools/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "https://data.gchange.fr" send -d "$3" -t "${TITLE} ${MEDIAKEY}" -m "MEDIA : https://astroport.com/ipfs/${IPFSREPFILEID}"

# Couldl be used by caroussel.html template
# CAROUSSEL=$(ipfs add -wq ~/astroport/${TYPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json | head-n 1)

# COPY TIDDLER JSON TO DESKTOP Journal/${TYPE}
#    [[ "$USER" != "xbian" && -d ~/Bureau ]] && mkdir -p ~/Bureau/Journal/${TYPE} && cp ~/astroport/${TYPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json "$HOME/Bureau/Journal/${TYPE}/${TITLE}.dragdrop.json" && xdg-open "$HOME/Bureau/Journal/${TYPE}/"
#    [[ "$USER" != "xbian" && -d ~/Desktop ]] && mkdir -p ~/Desktop/Journal/${TYPE} && cp ~/astroport/${TYPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json "$HOME/Desktop/Journal/${TYPE}/${TITLE}.dragdrop.json" && xdg-open "$HOME/Desktop/Journal/${TYPE}/"

fi

## COPY LOCALHOST IPFS URL TO CLIPBOARD
[[ $(which xclip) ]] &&\
    [[ $TEXT == "" ]] &&\
        echo "http://127.0.0.1:8080/ipfs/$IPFSREPFILEID/$URLENCODE_FILE_NAME" | xclip -selection c ||\
        echo "$TEXT" | xclip -selection c

########################################################################
# PUBLISH GENERAL video
########################################################################
if [[ "${CAT}" == "video" ]]
then
    ## REPLACE IPFS / IPNS REFERENCE IN video.json (Maybe cyphered later)
    cat ~/astroport/${CAT}/${MEDIAKEY}/video.json | sed "s/_IPFSREPFILEID_/$IPFSREPFILEID/g" | sed "s/_IPNSKEY_/$IPNS/g"  >> ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/${PREFIX}ASTRXBIAN
fi

########################################################################

########################################################################
echo "DUNIKEY PASS $PASS"
echo "NEW $TYPE ($file) ADDED. http://127.0.0.1:8080/ipfs/$IPFSREPFILEID/$URLENCODE_FILE_NAME"
echo "INDEX UPDATED :  ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/${PREFIX}ASTRXBIAN"
echo "VIDEO IPNS LINK : http://127.0.0.1:8080/ipns/$KEY/$G1PUB/ (MUST Activate 'G1VideoClub.sh' to publish & renew)"
echo "#### EXCECUTION TIME"
end=`date +%s`
echo Execution time was `expr $end - $start` seconds.
echo "########################################################################"
[[ ! $3 ]] && zenity --warning --width 300 --text "Votre MEDIA a rejoint ASTROPORT en `expr $end - $start` secondes"
exit 0


