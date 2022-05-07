#!/bin/bash
########################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# COPY ~/astroport/* files to IPFS
# Publish INDEX ~/.zen/ipfs/.*/${PREFIX}ASTRXBIAN
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
G1PUB=$(cat ~/.zen/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2)
# ~/.zen/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/${PREFIX}ASTRXBIAN
# Astropot/Kodi/Vstream source reads ${PREFIX}ASTRXBIAN from http://127.0.0.1:8080/.$IPFNODEID/
# Index File Format (could be enhanced) is using Kodi TMDB enhancement
# https://github.com/Kodi-vStream/venom-xbmc-addons/wiki/Voir-et-partager-sa-biblioth%C3%A8que-priv%C3%A9e#d%C3%A9clarer-des-films
########################################################################
## RUN inotifywait process ~/astroport/ NEW FILE DETECT
# /usr/bin/inotifywait -r -e close_write -m /home/$YOU/astroport | while read dir flags file; do ~/.zen/astrXbian/zen/new_file_in_astroport.sh "$dir" "$file"; done &
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

echo "~/.zen/astrXbian/zen/new_file_in_astroport.sh PATH/ \"$path\" FILE \"$file\""

extension="${file##*.}"
TITLE="${file%.*}"

# .part file false flag correcting (inotify mode)
[[ ! -f "${path}${file}" ]] && file="${TITLE%.*}" && extension="${TITLE##*.}" && [[ ! -f "${path}${file}" ]] && er="NO FILE" && echo "$er" && exit 1

# GET XZUID
[[ -f ~/.zen/ipfs/.$IPFSNODEID/G1SSB/_g1.gchange_title ]] && XZUID=$(cat ~/.zen/ipfs/.$IPFSNODEID/G1SSB/_g1.gchange_title) || XZUID=$(cat /etc/hostname)
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

[[ ! -d ~/.zen/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/ ]] && mkdir -p ~/.zen/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/

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
## CHECK if MEDIAKEY exists -> REFRESH DATA
########################################################################
echo "SEARCH for ;$REFERENCE; in ${PREFIX}ASTRXBIAN"
if [[ ${REFERENCE:0:1} != "0" ]]; then ## REFERENCE COULD BE A PHONE NUMBER (not in TMDB copy force)
    isREFERENCEinINDEX=$(grep ";$REFERENCE;" ~/.zen/ipfs_swarm/.12D*/astroport/kodi/vstream/${PREFIX}ASTRXBIAN )
    if [[ ${isREFERENCEinINDEX} ]]
    then
        if [[ -d ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB} ]]
        then
        # FILE IS MINE, NEW VERSION?! replacing it in INDEX
            ipnslink=$(cat ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipns.link)
            echo "FOUND IPNS ${MEDIAKEY} = $ipnslink"

            # DELETING GCHANGE AD, WILL BE CREATED AGAIN
            gchangeAD=$(cat ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.gchange.ad)
            ~/.zen/astrXbian/zen/jaklis/jaklis.py -k ~/.zen/secret.dunikey -n "https://data.gchange.fr" deleteoffer -i $gchangeAD
            rm ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.gchange.ad
        else
            er="$er | FILE IS ALREADY EXISTING FROM ANOTHER FRIEND" && echo "$er"
            ## SEND messages to warn about need to Unify MEDIAKEY IPNS KEY
            ipfsnodeid=$(echo ${isREFERENCEinINDEX} | tail -n 1 | cut -d '.' -f 3- | cut -d '/' -f 1)
            destg1=$(~/.zen/astrXbian/zen/tools/ipfs_to_g1.py $ipfsnodeid)
            [[ "$IPFSNODEID" != "$ipfsnodeid" ]] && ~/.zen/astrXbian/zen/jaklis/jaklis.py -k ~/.zen/secret.dunikey -n "https://data.gchange.fr" send -d $destg1 -t "MEDIAKEY COLLISION ${MEDIAKEY}" -m "Conflit de MEDIAKEY. Choisir quelle clef IPNS conserver..."
            ##
        fi
    fi
fi


########################################################################
echo "ADDING ${path}${file} to IPFS and create ${PREFIX}ASTRXBIAN INDEX"
echo "~/.zen/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/${PREFIX}ASTRXBIAN"
echo "-----------------------------------------------------------------"

IPFS=$(ipfs add -wq "${path}${file}")
IPFSREPFILEID=$(echo $IPFS | cut -d ' ' -f 2)
IPFSID=$(echo $IPFS | cut -d ' ' -f 1)
[[ $IPFSREPFILEID == "" ]] && echo "ipfs add ERROR" && exit 1
echo "-----------------------------------------------------------------"
echo "IPFS $file DIRECTORY: ipfs ls /ipfs/$IPFSREPFILEID"
echo "-----------------------------------------------------------------"
echo "New $TYPE INDEX ~/.zen/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/${PREFIX}ASTRXBIAN "

URLENCODE_FILE_NAME=$(echo ${file} | jq -Rr @uri)

### MEDIAKEY FORGE
########################################################################
## CREATE NEW ipns KEY : ${MEDIAKEY}
########################################################################
## IPFS SELF IPNS DATA STORAGE
## ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/
########################################################################
if [[ ! $(ipfs key list | grep "${MEDIAKEY}") ]]; then
    ## IPNS KEY CREATION
    mkdir -p ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}
    KEY=$(ipfs key gen "${MEDIAKEY}")
#    KEYFILE=$(ls -t ~/.ipfs/keystore/ | head -n 1) # get name of last created key (could be fooled during stargate exchange)
    KEYFILE=$(~/.zen/astrXbian/zen/tools/give_me_keystore_filename.py "${MEDIAKEY}") # better method applied
fi

## IS IT NEW IPNS KEY?
if [[ $KEY ]]; then
    echo "CREATING NEW IPNS MEDIAKEY"
    # memorize IPNS key filename for easiest exchange
    echo "$KEYFILE" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipns.key.keystore_filename
    # Publishing IPNS key
    echo "$KEY" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipns.link
    # CREATE .zen = ZEN economic value
    touch ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.zen
    # CREATE other encrypted copies for friends depending DEFCON & stars
    # > STARGATE 1 - 2 - 3 - 4 - 5 !!
    ################ ENCRYPT keystore/$KEYFILE
else
    KEY=$(cat ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipns.link)
    KEYFILE=$(cat ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipns.key.keystore_filename)
    echo "## ALREADY EXISTING IPNS KEY $KEYFILE ($KEY)"
fi

[[ ! $KEY ]] && echo "FATAL ERROR" && exit 1
########################################################################
## add default metadata (TODO = use json file?)
########################################################################
FILE_BSIZE=$(du -b "${path}${file}" | awk '{print $1}')
echo "${FILE_BSIZE}" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.filesize
echo "${file}" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipfs.filename
echo "${TITLE}" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.title
echo "$(date -u +%s%N | cut -b1-13)" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.timestamp
## INIT MEDIAKEY .views.counter
echo "0" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.views.counter
########################################################################

########################################################################
# Prepare IPFS links (then cyphered to manage exchange regulation)
########################################################################
echo "/ipfs/$IPFSREPFILEID/${file}" > /tmp/.ipfs.filelink
echo "$IPFSID" > /tmp/.ipfsid
########################################################################

########################################################################
################ ask autoPIN to one shuffle A_boostrap_nodes
########################################################################
PINIPFSnode=$(cat ~/.zen/astrXbian/A_boostrap_nodes.txt | grep -Ev "#" | shuf | tail -n 1)
nodeid=${PINIPFSnode##*/}
PINnode=$(~/.zen/astrXbian/zen/tools/ipfs_to_g1.py $nodeid)

echo "ASK AUTOPIN to $PINnode"
## CREATE $PINnode IPFS communication directory
if [[ ! -d ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode} && "$PINnode" != "$G1PUB" ]]; then
    mkdir -p ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}
    ## ENCRYPT .ipfsid & .ipfs.filelink (THESE FILES ARE
    $MY_PATH/tools/natools.py encrypt -p $PINnode -i /tmp/.ipfs.filelink -o "~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}/.ipfs.filelink.encrypt"
    $MY_PATH/tools/natools.py encrypt -p $PINnode -i /tmp/.ipfsid -o "~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}/.ipfsid.encrypt"
    # .ipfsid.encrypt is searched by each Station running ./zen/tools/autoPINfriends.sh
fi
########################################################################
## GREAT natools can convert IPNS MEDIAKEY into .dunikey file
########################################################################
# CREATING QRCODE
$MY_PATH/tools/natools.py privkey -f ipfs-keystore -k $HOME/.ipfs/keystore/$KEYFILE -F pubsec -o /tmp/${MEDIAKEY}.dunikey
# PubFromDunikey=$(cat /tmp/${MEDIAKEY}.dunikey | grep "sec" | cut -d ' ' -f2 | base58 -d | tail -c+33 | base58) ## HOWTO EXTRACT PUBKEY FROM SECKEY
PubFromDunikey=$(cat /tmp/${MEDIAKEY}.dunikey | grep "pub" | cut -d ' ' -f2)
qrencode -s 6 -o "$HOME/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/QR.png" "$PubFromDunikey"
echo "$PubFromDunikey" > $HOME/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/MEDIAPUBKEY

########################################################################
## MEDIAKEY => DUNIKEY + PASS 6 DIGITS openssl protection
########################################################################
PASS=$(echo "${RANDOM}${RANDOM}${RANDOM}${RANDOM}" | tail -c-7) && echo "$PASS" > /tmp/${MEDIAKEY}.pass
openssl enc -aes-256-cbc -salt -in /tmp/${MEDIAKEY}.dunikey -out "$HOME/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/dunikey.enc" -k $PASS

## STATION & BOOTSTRAP ACCESS TO PASS
$MY_PATH/tools/natools.py encrypt -p $G1PUB -i /tmp/${MEDIAKEY}.pass -o $HOME/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.pass.encrypt
$MY_PATH/tools/natools.py encrypt -p $PINnode -i /tmp/${MEDIAKEY}.pass -o $HOME/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}/.pass.encrypt

## DECODE MEDIAKEY.dunikey ##
# ~/.zen/astrXbian/zen/tools/natools.py decrypt -f pubsec -k "$HOME/.zen/secret.dunikey" -i "$HOME/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.pass.encrypt" -o "/tmp/${MEDIAKEY}.pass"
# openssl enc -aes-256-cbc -d -in "$HOME/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/dunikey.enc" -out "/tmp/${MEDIAKEY}.dunikey" -k $(cat "/tmp/${MEDIAKEY}.pass")
rm /tmp/${MEDIAKEY}.dunikey

########################################################################
## GET .ipfs/keystore file MAHE .ipns.mediakey.encrypt
# used in ipns_TAG_refresh.sh & autoPINfriends.sh
########################################################################
$MY_PATH/tools/natools.py encrypt -p $G1PUB -i $HOME/.ipfs/keystore/$KEYFILE -o $HOME/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipns.mediakey.encrypt
$MY_PATH/tools/natools.py encrypt -p $PINnode -i $HOME/.ipfs/keystore/$KEYFILE -o $HOME/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}/.ipns.mediakey.encrypt

## Init zen, views counters & visitor
echo "0" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}/.zen
echo "0" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}/.views.counter
echo "anonymous" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}/.visitor
########################################################################
# MEMORIZE my PIN
mkdir -p ~/.zen/PIN/${IPFSREPFILEID}/
touch ~/.zen/PIN/${IPFSREPFILEID}/${G1PUB}
# echo "$(ipfs key list -l | grep ${MEDIAKEY} | cut -d ' ' -f 1)" > ~/.zen/PIN/${ipfsrepidfile}/IPNSLINK #  NO!! Would let PINing nodes change index.html///

########################################################################
## encrypt links for myself
########################################################################
$MY_PATH/tools/natools.py encrypt -p ${G1PUB} -i /tmp/.ipfs.filelink -o ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipfs.filelink.natools.encrypt
$MY_PATH/tools/natools.py encrypt -p ${G1PUB} -i /tmp/.ipfsid -o ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipfsid.encrypt
rm /tmp/.ipfs.filelink
rm /tmp/.ipfsid
########################################################################

########################################################################
## ADD "ajouter_video.txt" and "video.json" will be SELF IPNS publish data
## ENCRYPT TO STOP CLEAR DATA LEAKING
[[ -f ~/astroport/${TYPE}/${REFERENCE}/ajouter_video.txt ]] && cp -f ~/astroport/${TYPE}/${REFERENCE}/ajouter_video.txt ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/
[[ -f ~/astroport/${TYPE}/${REFERENCE}/screen.png ]] && cp -f ~/astroport/${TYPE}/${REFERENCE}/screen.png ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/
[[ -f ~/astroport/${TYPE}/${REFERENCE}/video.json ]] &&\
    cp -f ~/astroport/${TYPE}/${REFERENCE}/video.json ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/ &&\
    cp -f ~/astroport/${TYPE}/${REFERENCE}/video.json ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/
########################################################################

########################################################################
## EXPLANATIONS
########################################################################
# What is being in ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/
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
########################################################################

########################################################################
## IPNS access to index.html
## Level 1 (not crypted) -> Redirect to ipfs streaming link

IPNSLINK=$(ipfs key list -l | grep ${MEDIAKEY} | cut -d ' ' -f 1)
## FIRST REDIRECT PAGE ${MEDIAKEY}/index.html
# https://tube.copylaradio.com/ipns/$IPNSLINK
#envsubst < ./www/boris/youtube_watch_step2.html > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/index.html

    echo "=======> Mediakey Welcome index.html "
    cat /home/$YOU/.zen/astrXbian/www/boris/youtube_watch_step2.html \
        | sed "s/\${IPNSLINK}/$IPNSLINK/g" \
        | sed "s/\${IPFSNODEID}/$IPFSNODEID/g" \
        | sed "s/\${XZUID}/$XZUID/g" \
        | sed "s/\${G1PUB}/$G1PUB/g" \
        | sed "s/\${TITLE}/$TITLE/g" \
        > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/index.html

## SECOND REDIRECT PAGE ${MEDIAKEY}/${G1PUB}/index.html
# https://tube.copylaradio.com/ipns/$IPNSLINK/${G1PUB}/

#envsubst < ../www/boris/youtube_watch_step3.html > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/index.html
    echo "=======> Mediakey Contract index.html "
    cat /home/$YOU/.zen/astrXbian/www/boris/youtube_watch_step3.html \
    | sed "s/\${TITLE}/$TITLE/g" \
    | sed "s/\${IPFSNODEID}/$IPFSNODEID/g" \
    | sed "s/\${XZUID}/$XZUID/g" \
    | sed "s/\${IPFSREPFILEID}/$IPFSREPFILEID/g" \
    | sed "s/\${URLENCODE_FILE_NAME}/$URLENCODE_FILE_NAME/g" \
    > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/index.html


# echo "<meta http-equiv=\"Refresh\" content=\"0;URL=http://127.0.0.1:8080/ipfs/$IPFSREPFILEID/$URLENCODE_FILE_NAME\">" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/index.html
########################################################################
## MODIFY INTO "./zen/ipns_TAG_refresh.sh" (add crypto/contracts there)
########################################################################

########################################################################
########################################################################
## PUBLISH new IPNS
########################################################################
echo "$(date -u +%s%N | cut -b1-13)" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/.timestamp

NEWIPFS=$(ipfs add -rHq ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/ | tail -n 1 )
[[ "$NEWIPFS" == "" ]] && echo "~~~ FAILURE ~~~ ipfs add -rHq ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/ | tail -n 1" && exit 1

## ADD CHAIN BLOCK ZERO (will be updated by ipns_TAG_refresh.sh)
echo $NEWIPFS > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/.chain

IPNS=$(ipfs name publish --quieter --key="${MEDIAKEY}" $NEWIPFS)
[[ "$IPNS" == "" ]] && echo "~~~ PROBLEM ~~~ ipfs name publish --quieter --key=${MEDIAKEY} $NEWIPFS" && IPNS="$(ipfs key list -l | grep -w ${MEDIAKEY} | cut -f 1 -d ' ')"
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
    if [[ ! -f ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.gchange.ad && ( "${CAT}" == "film" || "${CAT}" == "serie") ]]
    then

        GOFFER=$(~/.zen/astrXbian/zen/jaklis/jaklis.py -k ~/.zen/secret.dunikey -n "https://data.gchange.fr" setoffer -t "${TITLE} #astroport #${MEDIAKEY}" -d "${TITLE} https://tube.copylaradio.com/ipns/$IPNS/ Faites un don à son portefeuille pour le conserver dans le Mediacenter des Amis - https://CopyLaRadio.com - https://astroport.com" -p $HOME/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/QR.png)
        echo $GOFFER > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.gchange.ad
        NEWIPFS=$(ipfs add -rHq ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/ | tail -n 1 )
        IPNS=$(ipfs name publish --quieter --key="${MEDIAKEY}" $NEWIPFS)
        [[ "$IPNS" == "" ]] && IPNS="$(ipfs key list -l | grep -w ${MEDIAKEY} | cut -f 1 -d ' ')"
        echo "Annonce gchange : $(cat ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.gchange.ad)"

    fi

    ########################################################################
    # CREATION DU FICHIER ${PREFIX}ASTRXBIAN FILE : Add Header
    [[ ! -f ~/.zen/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/${PREFIX}ASTRXBIAN ]] \
    && echo "CAT;TMDB;YEAR;TITLE;SAISON;GENRES;GROUPES;RES;URLS=http://127.0.0.1:8080" > ~/.zen/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/${PREFIX}ASTRXBIAN

    # ADD NEW LINE TO INDEX
    if [[ -f ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/ajouter_video.txt ]]
    then
        line=$(cat ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/ajouter_video.txt | sed "s/_IPFSREPFILEID_/$IPFSREPFILEID/g" | sed "s/_IPNSKEY_/$IPNS/g" )
    else
        FILE_RES=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "${path}${file}" | cut -d "x" -f 2)
        RES=${FILE_RES%?}0p
        line="$CAT;${REFERENCE};$YEAR;$TITLE;$SAISON;;${IPNS};$RES;/ipfs/$IPFSREPFILEID/$URLENCODE_FILE_NAME"
    fi
    echo "-------------------- UPDATE MY INDEX -----------------------------"
    echo "$line"
    echo "$line" >> ~/.zen/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/${PREFIX}ASTRXBIAN
    echo "UPDATE IPNS ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/ajouter_video.txt"
    echo "$line" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/ajouter_video.txt
    ## UPDATE SOURCE ajouter_video.txt FILE
    cp -f ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/ajouter_video.txt ~/astroport/${TYPE}/${REFERENCE}/ajouter_video.txt

    ########################################################################
    ## TODO: ACTIVATE SUB DEFCON 4 MODE = encrypt/decrypt file in $G1DEST subdirectory
    ########################################################################
    echo "----------------- REFRESH LOCAL KODI INDEX ----------------------"
    cat ~/.zen/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/${PREFIX}ASTRXBIAN ~/.zen/ipfs_swarm/.12D*/astroport/kodi/vstream/${PREFIX}ASTRXBIAN | sort | uniq > ~/.zen/ipfs/.${IPFSNODEID}/${PREFIX}ASTRXBIAN

    GENRE=$(cat ~/.zen/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/ajouter_video.txt | cut -d ';' -f 6 | sed 's/|/ /g' )
    MIME=$(file --mime-type "$HOME/astroport/${TYPE}/${REFERENCE}/${file}" | cut -d ':' -f 2 | cut -d ' ' -f 2)
    REAL=$MIME
    if [[ $(echo "$MIME" | grep 'video') ]]; then
        TEXT="<video controls><source src='/ipfs/"${IPFSID}"' type='"${MIME}"'></video><h1>"${TITLE}"</h1>"
        MIME="text/vnd.tiddlywiki"
        TAGS="${CAT} astroport $GENRE"
        CANON=''
    else
        TEXT=''
        TAGS='$:/isAttachment $:/isIpfs astroport '${CAT} $GENRE
        CANON="/ipfs/"${IPFSID}
    fi

    ## Add screen
    SCREENDIR=$(ipfs add -wq "$HOME/astroport/${TYPE}/${REFERENCE}/screen.png" | tail -n 1)

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
    "mediakey": "'${MEDIAKEY}'",
    "ipns": "'${IPNS}'",
    "tmdb": "'${REFERENCE}'",
    "tags": "'${TAGS}'" ' > ~/astroport/${TYPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json

    [[ ${CANON} != "" ]] && echo  ',
    "_canonical_uri": "'${CANON}'"' >> ~/astroport/${TYPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json

    echo '
  }
]
' >> ~/astroport/${TYPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json

# Will be used by caroussel.html template
# CAROUSSEL=$(ipfs add -wq ~/astroport/${TYPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json | head-n 1)



    # COPY TIDDLER JSON TO DESKTOP Journal/${TYPE}
    [[ "$USER" != "xbian" && -d ~/Bureau ]] && mkdir -p ~/Bureau/Journal/${TYPE} && cp ~/astroport/${TYPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json ~/Bureau/Journal/${TYPE}/${TITLE}.dragdrop.json && xdg-open "~/Bureau/Journal/${TYPE}/"
    [[ "$USER" != "xbian" && -d ~/Desktop ]] && mkdir -p ~/Desktop/Journal/${TYPE} && cp ~/astroport/${TYPE}/${REFERENCE}/${MEDIAKEY}.dragdrop.json ~/Desktop/Journal/${TYPE}/${TITLE}.dragdrop.json && xdg-open "~/Desktop/Journal/${TYPE}/"

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
    cat ~/astroport/${CAT}/${MEDIAKEY}/video.json | sed "s/_IPFSREPFILEID_/$IPFSREPFILEID/g" | sed "s/_IPNSKEY_/$IPNS/g"  >> ~/.zen/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/${PREFIX}ASTRXBIAN

fi

#########################################################################
# PUBLISH YOUTUBE video to /astroport/wordpress/ DATA NOT USED ANY MORE... semaphore à régler
#########################################################################
if [[ "${CAT}" == "youtube" ]]
then
    ## CREATE astroport call to Astroport/Wordpress stations
    if [[ ! -d ~/.zen/ipfs/.$IPFSNODEID/astroport/wordpress/${MEDIAKEY} ]]; then
        mkdir -p ~/.zen/ipfs/.$IPFSNODEID/astroport/wordpress/${MEDIAKEY}
        echo "1" >  ~/.zen/ipfs/.$IPFSNODEID/astroport/wordpress/${MEDIAKEY}/do
    fi
fi

########################################################################

########################################################################
# REFRESH IPNS SELF PUBLISH
########################################################################
~/.zen/astrXbian/zen/ipns_self_publish.sh
########################################################################
echo "DUNIKEY PASS $PASS"
echo "NEW $TYPE ($file) ADDED. http://127.0.0.1:8080/ipfs/$IPFSREPFILEID/$URLENCODE_FILE_NAME"
echo "INDEX UPDATED : http://127.0.0.1:8080/ipns/${IPFSNODEID}/.${IPFSNODEID}/${PREFIX}ASTRXBIAN"
echo "VIDEO IPNS LINK : http://127.0.0.1:8080/ipns/$KEY/$G1PUB/"
echo "#### EXCECUTION TIME"
end=`date +%s`
echo Execution time was `expr $end - $start` seconds.
echo "########################################################################"
zenity --warning --width 300 --text "Votre MEDIA a rejoint ASTROPORT en `expr $end - $start` secondes"
exit 0
