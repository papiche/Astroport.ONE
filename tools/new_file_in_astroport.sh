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
# .part file false flag correcting (in case inotify has launched script)
[[ ! -f "${path}${file}" ]] && file="${TITLE%.*}" && extension="${TITLE##*.}" && [[ ! -f "${path}${file}" ]] && er="NO FILE" && echo "$er" && exit 1

MIME=$(file --mime-type -b "${path}${file}")

    ############# EXTEND MEDIAKEY IDENTIFATORS https://github.com/NapoleonWils0n/ffmpeg-scripts
    if [[ $(echo "$MIME" | grep 'video') ]]; then
        ## Create gifanime ##  TODO Search for similarities BEFORE ADD
        echo "(✜‿‿✜) GIFANIME (✜‿‿✜)"
        rm -f ~/.zen/tmp/screen.gif
        ffmpeg -loglevel quiet -ss 1.0 -t 1.6 -loglevel quiet -i "${path}${file}" ~/.zen/tmp/screen.gif
        ANIMH=$(ipfs add -q ~/.zen/tmp/screen.gif)
        echo "/ipfs/$ANIMH"
    fi

# GET PLAYER
PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null);
[[ ! $PLAYER ]] && echo "No current player. Please Login" && exit 1

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

    # CapitalGluedTitle
    CapitalGluedTitle=$(echo "${TITLE}" | sed -r 's/\<./\U&/g' | sed 's/ //g')

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

#~ ### MEDIAKEY FORGE
#~ ########################################################################
#~ ## CREATE NEW ipns KEY : ${MEDIAKEY}
#~ ########################################################################
#~ ## IPFS SELF IPNS DATA STORAGE
#~ ## ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/
#~ ########################################################################
#~ if [[ ! $(ipfs key list | grep -w "${MEDIAKEY}") ]]; then
    #~ echo "CREATING NEW IPNS $MEDIAKEY"
    #~ ## IPNS KEY CREATION ?
    #~ mkdir -p ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}
    #~ KEY=$(ipfs key gen "${MEDIAKEY}")
#~ #    KEYFILE=$(ls -t ~/.ipfs/keystore/ | head -n 1) # get name of last created key (could be fooled during stargate exchange)
    #~ KEYFILE=$(~/.zen/Astroport.ONE/tools/give_me_keystore_filename.py "${MEDIAKEY}") # better method applied
#~ fi

#~ ## IS IT NEW IPNS KEY?
#~ if [[ $KEY ]]; then
    #~ # memorize IPNS key filename for easiest exchange
    #~ echo "$KEYFILE" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipns.key.keystore_filename
    #~ # Publishing IPNS key
    #~ echo "$KEY" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipns.link
    #~ # CREATE .zen = ZEN economic value counter
    #~ touch ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.zen
    #~ # CREATE other encrypted copies for friends depending DEFCON & stars
    #~ # > STARGATE 1 - 2 - 3 - 4 - 5 !!
    #~ ################ ENCRYPT keystore/$KEYFILE
#~ else
    #~ KEY=$(cat ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipns.link)
    #~ KEYFILE=$(cat ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipns.key.keystore_filename)
    #~ echo "## ALREADY EXISTING IPNS KEY $KEYFILE ($KEY)"
#~ fi

#~ [[ ! $KEY ]] && echo "FATAL ERROR" && exit 1
#~ ########################################################################
#~ ## add default metadata (TODO = use json file?)
#~ ########################################################################
#~ echo "${FILE_BSIZE}" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.filesize
#~ echo "${file}" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipfs.filename
#~ echo "${TITLE}" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.title
#~ echo "$(date -u +%s%N | cut -b1-13)" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.timestamp
#~ ## INIT MEDIAKEY .views.counter
#~ echo "0" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.views.counter
#~ ########################################################################

#~ ########################################################################
#~ # Prepare IPFS links (then cyphered to manage exchange regulation)
#~ ########################################################################
#~ echo "/ipfs/$IPFSREPFILEID/${file}" > ~/.zen/tmp/.ipfs.filelink
#~ echo "$IPFSID" > ~/.zen/tmp/.ipfsid
#~ ########################################################################

#~ ########################################################################
#~ ################ ask autoPIN to one shuffle A_boostrap_nodes
#~ ########################################################################
#~ PINIPFSnode=$(cat ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | grep -Ev "#" | shuf | tail -n 1)
#~ nodeid=${PINIPFSnode##*/}
#~ PINnode=$(~/.zen/Astroport.ONE/tools/ipfs_to_g1.py $nodeid)

#~ echo "ASK AUTOPIN to $PINnode"
#~ ## CREATE $PINnode IPFS communication directory
#~ if [[ ! -d ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode} && "$PINnode" != "$G1PUB" ]]; then
    #~ mkdir -p ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}
    #~ ## ENCRYPT .ipfsid & .ipfs.filelink (THESE FILES ARE
    #~ $MY_PATH/natools.py encrypt -p $PINnode -i ~/.zen/tmp/.ipfs.filelink -o "~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}/.ipfs.filelink.encrypt"
    #~ $MY_PATH/natools.py encrypt -p $PINnode -i ~/.zen/tmp/.ipfsid -o "~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}/.ipfsid.encrypt"
    #~ # .ipfsid.encrypt is searched by each Station running ./zen/tools/autoPINfriends.sh
#~ fi

#~ ## Ask PIN to myself
#~ mkdir -p ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${G1PUB}
#~ $MY_PATH/natools.py encrypt -p $G1PUB -i ~/.zen/tmp/.ipfs.filelink -o "~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${G1PUB}/.ipfs.filelink.encrypt"
#~ $MY_PATH/natools.py encrypt -p $G1PUB -i ~/.zen/tmp/.ipfsid -o "~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${G1PUB}/.ipfsid.encrypt"


#~ ########################################################################
#~ ## GREAT natools can convert IPNS MEDIAKEY into .dunikey file
#~ ########################################################################
#~ # CREATING QRCODE
#~ $MY_PATH/natools.py privkey -f ipfs-keystore -k $HOME/.ipfs/keystore/$KEYFILE -F pubsec -o ~/.zen/tmp/${MEDIAKEY}.dunikey
#~ # PubFromDunikey=$(cat ~/.zen/tmp/${MEDIAKEY}.dunikey | grep "sec" | cut -d ' ' -f2 | base58 -d | tail -c+33 | base58) ## HOWTO EXTRACT PUBKEY FROM SECKEY
#~ PubFromDunikey=$(cat ~/.zen/tmp/${MEDIAKEY}.dunikey | grep "pub" | cut -d ' ' -f2)
#~ qrencode -s 6 -o "$HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/QR.png" "$PubFromDunikey"
#~ echo "$PubFromDunikey" > $HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/MEDIAPUBKEY

#~ ########################################################################
#~ ## MEDIAKEY => DUNIKEY + PASS 6 DIGITS openssl protection
#~ ########################################################################
#~ PASS=$(echo "${RANDOM}${RANDOM}${RANDOM}${RANDOM}" | tail -c-7) && echo "$PASS" > ~/.zen/tmp/${MEDIAKEY}.pass
#~ openssl enc -aes-256-cbc -salt -in ~/.zen/tmp/${MEDIAKEY}.dunikey -out "$HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/dunikey.enc" -k $PASS

#~ ## STATION & BOOTSTRAP ACCESS TO PASS
#~ $MY_PATH/natools.py encrypt -p $G1PUB -i ~/.zen/tmp/${MEDIAKEY}.pass -o $HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.pass.encrypt
#~ $MY_PATH/natools.py encrypt -p $PINnode -i ~/.zen/tmp/${MEDIAKEY}.pass -o $HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}/.pass.encrypt

#~ ## DECODE MEDIAKEY.dunikey ##
#~ # ~/.zen/Astroport.ONE/tools/natools.py decrypt -f pubsec -k "$HOME/.zen/secret.dunikey" -i "$HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.pass.encrypt" -o "~/.zen/tmp/${MEDIAKEY}.pass"
#~ # openssl enc -aes-256-cbc -d -in "$HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/dunikey.enc" -out "~/.zen/tmp/${MEDIAKEY}.dunikey" -k $(cat "~/.zen/tmp/${MEDIAKEY}.pass")
#~ rm ~/.zen/tmp/${MEDIAKEY}.dunikey

#~ ########################################################################
#~ ## GET .ipfs/keystore file MAHE .ipns.mediakey.encrypt
#~ # used in ipns_TAG_refresh.sh & autoPINfriends.sh (TODO RUN AGAIN?)
#~ ########################################################################
#~ $MY_PATH/natools.py encrypt -p $G1PUB -i $HOME/.ipfs/keystore/$KEYFILE -o $HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipns.mediakey.encrypt
#~ $MY_PATH/natools.py encrypt -p $PINnode -i $HOME/.ipfs/keystore/$KEYFILE -o $HOME/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}/.ipns.mediakey.encrypt

#~ ## Init zen, views counters & visitor
#~ echo "0" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}/.zen
#~ echo "0" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}/.views.counter
#~ echo "anonymous" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/${PINnode}/.visitor
#~ ########################################################################
#~ # MEMORIZE my PIN
#~ mkdir -p ~/.zen/PIN/${IPFSREPFILEID}/
#~ touch ~/.zen/PIN/${IPFSREPFILEID}/${G1PUB}
#~ # echo "$(ipfs key list -l | grep ${MEDIAKEY} | cut -d ' ' -f 1)" > ~/.zen/PIN/${ipfsrepidfile}/IPNSLINK #  NO!!  CHOOSE TODO Would let PINing nodes change index.html///

#~ ########################################################################
#~ ## encrypt links for myself
#~ ########################################################################
#~ $MY_PATH/natools.py encrypt -p ${G1PUB} -i ~/.zen/tmp/.ipfs.filelink -o ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipfs.filelink.natools.encrypt
#~ $MY_PATH/natools.py encrypt -p ${G1PUB} -i ~/.zen/tmp/.ipfsid -o ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.ipfsid.encrypt
#~ rm ~/.zen/tmp/.ipfs.filelink
#~ rm ~/.zen/tmp/.ipfsid
#~ ########################################################################

#~ ########################################################################
#~ ## ADD "ajouter_video.txt" and "video.json" will be SELF IPNS publish data
#~ ## ENCRYPT TO STOP CLEAR DATA LEAKING
#~ [[ -f ~/astroport/${TyPE}/${REFERENCE}/ajouter_video.txt ]] && cp -f ~/astroport/${TyPE}/${REFERENCE}/ajouter_video.txt ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/
#~ [[ -f ~/astroport/${TyPE}/${REFERENCE}/screen.png ]] && cp -f ~/astroport/${TyPE}/${REFERENCE}/screen.png ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/
#~ [[ -f ~/astroport/${TyPE}/${REFERENCE}/youtube.png ]] && cp -f ~/astroport/${TyPE}/${REFERENCE}/youtube.png ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/screen.png
#~ [[ -f ~/astroport/${TyPE}/${REFERENCE}/video.json ]] &&\
    #~ cp -f ~/astroport/${TyPE}/${REFERENCE}/video.json ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/ &&\
    #~ cp -f ~/astroport/${TyPE}/${REFERENCE}/video.json ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/
#~ ########################################################################

#~ ########################################################################
#~ ## EXPLANATIONS
#~ ########################################################################
#~ # What is being in ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/
#~ # is published on http://${myIP}:8080/ipns/$KEY/ AND ipfs ls /ipns/$KEY/
#~ ########################################################################
#~ ########################################################################
#~ # CONTRACTS, are small App (fulljs or jquery + nginx backend app server)
#~ # They must decrypt IPFS after succeeding a chalenge (, +/- n zen, ...)
#~ ########################################################################
#~ # Contract App Examples (ipns_TAG_refresh.sh makes MEDIAKEY evolution)
#~ # Counting video views = +1 .views.counter => decrypt key
#~ # Balancing Zen wallets = -n form source = +n for destination => decrypt key
#~ ########################################################################
#~ # Astroport/Gchange USE as public/private media copy friend of friends swarm
#~ # one star level (no encrypt)
#~ # index.html is presenting Astroport/Kodi service then redirect to
#~ # $G1PUB/index.html contains redirection to ipfs link
#~ ## NEW RELEASE
#~ ## Create TW5 index.html to give easy control access to MEDIAKEY and KEY owner
#~ ########################################################################

#~ ########################################################################
#~ ## IPNS access to index.html
#~ ## Level 1 (not crypted) -> Redirect to ipfs streaming link

#~ IPNSLINK=$(ipfs key list -l | grep -w ${MEDIAKEY} | cut -d ' ' -f 1)
#~ ## FIRST REDIRECT PAGE ${MEDIAKEY}/index.html
#~ # https://tube.copylaradio.com/ipns/$IPNSLINK
#~ #envsubst < ./www/boris/youtube_watch_step2.html > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/index.html

    #~ echo "=======> Mediakey Welcome index.html "
    #~ cat ~/.zen/Astroport.ONE/templates/boris/youtube_watch_step2.html \
        #~ | sed "s/_IPNSLINK_/$IPNSLINK/g" \
        #~ | sed "s/_IPFSNODEID_/$IPFSNODEID/g" \
        #~ | sed "s/_PLAYER_/$PLAYER/g" \
        #~ | sed "s/_G1PUB_/$G1PUB/g" \
        #~ | sed "s/_TITLE_/$TITLE/g" \
        #~ > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/index.html

#~ ## SECOND REDIRECT PAGE ${MEDIAKEY}/${G1PUB}/index.html
#~ # https://tube.copylaradio.com/ipns/$IPNSLINK/${G1PUB}/

#~ # envsubst < ../www/boris/youtube_watch_step3.html > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/index.html
    #~ echo "=======> Mediakey Contract index.html "
    #~ cat ~/.zen/Astroport.ONE/templates/boris/youtube_watch_step3.html \
    #~ | sed "s/_TITLE_/$TITLE/g" \
    #~ | sed "s/_IPFSNODEID_/$IPFSNODEID/g" \
    #~ | sed "s/_PLAYER_/$PLAYER/g" \
    #~ | sed "s/_IPFSREPFILEID_/$IPFSREPFILEID/g" \
    #~ | sed "s/_URLENCODE_FILE_NAME_/$URLENCODE_FILE_NAME/g" \
    #~ > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/index.html


#~ # echo "<meta http-equiv=\"Refresh\" content=\"0;URL=http://${myIP}:8080/ipfs/$IPFSREPFILEID/$URLENCODE_FILE_NAME\">" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/index.html
#~ ########################################################################
#~ ## TODO ACTIVATE "./zen/ipns_TAG_refresh.sh" (SACEM & Netflix Buziness is HERE!! Add your crypto/contracts there)
#~ ########################################################################

#~ ########################################################################
#~ ########################################################################
#~ ## PUBLISH new IPNS
#~ ########################################################################
#~ echo "$(date -u +%s%N | cut -b1-13)" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/.timestamp

#~ echo "ipfs add -rHq ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/"
#~ NEWIPFS=$(ipfs add -rHq ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/ | tail -n 1 )
#~ [[ "$NEWIPFS" == "" ]] && echo "~~~ FAILURE ~~~ ipfs add -rHq ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/ | tail -n 1" && exit 1

#~ ## ADD CHAIN BLOCK ZERO (will be updated by ipns_TAG_refresh.sh)
#~ echo $NEWIPFS > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/.chain

#~ echo "ipfs name publish --quieter --key=${MEDIAKEY} $NEWIPFS"
#~ ipfs name publish  -t 720h --quieter --key="${MEDIAKEY}" $NEWIPFS &

#~ IPNS="$(ipfs key list -l | grep -w ${MEDIAKEY} | cut -f 1 -d ' ')"
#~ echo "${MEDIAKEY} : /ipns/$IPNS"

#~ ########################################################################
#~ ########################################################################

########################################################################
# POST TRAITEMENTS
########################################################################
# film/serie PUBLISH "ajouter_video.txt" for KODI
########################################################################
if [[ "${type}" =~ ^(film|serie|youtube|page|video)$ ]]
then
    ## CREATE GCHANGE AD
    ## STOP PUBLISHING TO GCHANGE, NOW PLAYER TW ONLY
    ## ACTIVATE AGAIN TO MAKE ADVERTISMENT OF YOUR MEDIAKEY ACCES

#    if [[ ! -f ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/KEY/${MEDIAKEY}/${G1PUB}/.gchange.ad && ( "${type}" == "film" || "${type}" == "serie") ]]
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
    #~ ########################################################################
    #~ # CREATION DU FICHIER ${PREFIX}ASTRXBIAN FILE : Add Header (TODO DEBUG Kodi Plugin !! )
    #~ mkdir -p ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/
    #~ [[ ! -f ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/${PREFIX}ASTRXBIAN ]] \
    #~ && echo "type;TMDB;YEAR;TITLE;SAISON;GENRES;GROUPES;RES;URLS=http://${myIP}:8080" > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/astroport/kodi/vstream/${PREFIX}ASTRXBIAN

        FILE_RES=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "${path}${file}" | cut -d "x" -f 2)
        RES=${FILE_RES%?}0p

    # REFRESH ajouter_video.txt FILE
    if [[ -f ~/astroport/${TyPE}/${REFERENCE}/ajouter_video.txt ]]
    then
        line=$(cat ~/astroport/${TyPE}/${REFERENCE}/ajouter_video.txt | sed "s/_IPFSREPFILEID_/$IPFSREPFILEID/g" | sed "s/_IPNSKEY_/$IPNS/g" )
    else
        line="$type;${REFERENCE};$YEAR;$TITLE;$SAISON;;${IPNS};$RES;/ipfs/$IPFSREPFILEID/$URLENCODE_FILE_NAME"
    fi
    echo "-------------------- UPDATE ${PREFIX}ASTRXBIAN INDEX -----------------------------"
    echo "$line"
    echo "UPDATE ~/astroport/${TyPE}/${REFERENCE}/ajouter_video.txt"
    echo "$line" > ~/astroport/${TyPE}/${REFERENCE}/ajouter_video.txt

    ########################################################################
    ## TODO: ACTIVATE SUB DEFCON 4 MODE = encrypt/decrypt file in $G1DEST subdirectory
    ########################################################################
#    echo "----------------- REFRESH LOCAL KODI INDEX ----------------------"
#    cat ~/.zen/game/players/$PLAYER/ipfs*/.*/astroport/kodi/vstream/${PREFIX}ASTRXBIAN | sort | uniq > ~/.zen/game/players/$PLAYER/ipfs/.${IPFSNODEID}/${PREFIX}ASTRXBIAN


    echo "----------------- PREPARING TIDDLER ----------------------"
    CAT=$(echo "$type" | sed -r 's/\<./\U&/g' | sed 's/ //g') # CapitalGluedWords
    ## Adapt TMDB url
    [[ $CAT == "Film" ]] && tdb="movie"
    [[ $CAT == "Serie" ]] && tdb="tv"

    GENRE=$(cat ~/astroport/${TyPE}/${REFERENCE}/ajouter_video.txt | cut -d ';' -f 6 | sed 's/|/ /g' | jq -r '@csv' | sed 's/ /_/g' | sed 's/,/ /g' | sed 's/\"//g' )
    echo $GENRE

    ## ASK FOR EXTRA METADATA
[[ ! $3 ]] && OUTPUT=$(zenity --forms --width 480 --title="METADATA" --text="Metadonnées (séparateur espace)" --separator="~" --add-entry="Description" --add-entry="extra tag(s)")
[[ ! $3 ]] && DESCRIPTION=$(awk -F '~' '{print $1}' <<<$OUTPUT)
[[ ! $3 ]] && HASHTAG=$(awk -F '~' '{print $2}' <<<$OUTPUT)

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
        TAGS="G1${CAT} ${PLAYER} ${CapitalGluedTitle} $GENRE ipfs ${HASHTAG}"
        # TyPE="$MIME"
        # CANON="/ipfs/"${IPFSID}
        CANON=''
    else
        TidType="${MIME}"
        TEXT='${MEDIAKEY}'
        TAGS="'$:/isAttachment $:/isIpfs G1${CAT} ${PLAYER} ${CapitalGluedTitle} $GENRE ${HASHTAG}"
        CANON="/ipfs/"${IPFSID}
    fi

    echo "## Creation json tiddler"
    echo '[
  {
    "text": "'${TEXT}'",
    "title": "'${CapitalGluedTitle}'",
    "created": "'${MOATS}'",
    "resolution": "'${RES}'",
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
echo ${MOATS}:${G1PUB}:${PLAYER}:NewFile:$dur >> ~/.zen/tmp/${IPFSNODEID}/_timings
cat ~/.zen/tmp/${IPFSNODEID}/_timings | tail -n 1
echo "########################################################################"


[[ ! $3 ]] && zenity --warning --width 300 --text "Votre MEDIA a rejoint ASTROPORT en `expr $end - $start` secondes"

exit 0


