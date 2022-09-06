#!/bin/bash
########################################################################
# Author: Fred (support@qo-op.com)
# Version: 2020.04.28
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
countMErunning=$(ps auxf --sort=+utime | grep -w $ME | grep -v -E 'color=auto|grep' | wc -l)
[[ $countMErunning -gt 2 ]] && echo "$ME already running $countMErunning time" && exit 0

echo '########################################################################
# \\///
# qo-op
############# '$MY_PATH/$ME'
########################################################################
# ex: ./'$ME'
########################################################################'

echo "CHOOSE THE WAY YOU ARE GIVING ACCES TO YOUR MEDIAKEY !!"
echo "CONCEPT IS HERE. REWRITE NEEDED"
exit 1

########################################################################
########################################################################
IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)
[[ ! $IPFSNODEID ]] && echo 'ERROR missing IPFS Node id !! IPFS is not installed !?' && exit 1
########################################################################
[[ ! -f ~/.zen/secret.dunikey ]] && exit 1
G1PUB=$(cat ~/.zen/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2)
########################################################################
YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
[[ ! $YOU ]] && echo "IPFS NOT RUNNING. EXIT" && exit 1
########################################################################
XZUID=$(cat ~/.zen/ipfs/.$IPFSNODEID/.player)
# echo "## FRIENDS IPFS PINGing"
# for g1pub in $(ls -t ~/.zen/ipfs/.$IPFSNODEID/FRIENDS/); do [[ $g1pub ]] && ipfs ping --timeout=3s -n 3 /ipfs/$(~/.zen/astrXbian/zen/tools/g1_to_ipfs.py $g1pub 2>/dev/null) 2>/dev/null; done


echo "
  _   _   _   _
 / \ / \ / \ / \
( I | P | N | S )
 \_/ \_/ \_/ \_/

ZENTAG / MEDIAKEY : IPNS REFRESH
"
echo "I am /ipns/$IPFSNODEID controling and refreshing my MEDIAKEY IPNS"
########################################################################
# REFRESH IPNS SELF PUBLISH
########################################################################
# ~/.zen/astrXbian/zen/ipns_self_publish.sh
########################################################################

count=0
# [[ ! -d ~/.zen/ipfs/.${IPFSNODEID}/KEY/ ]] && exit 0

## TAKE CARE OF MY KEY
for mediakey in $(ls ~/.zen/ipfs/.${IPFSNODEID}/KEY/ 2>/dev/null | shuf ); # Alternative search
do
    [[ "${mediakey}" == "" ]] && continue ## prevent empty mediakey
#    [[ ! $(echo "${mediakey}" | grep "TMDB_") ]] && continue ## REFRESH ONLY TMDB (level 1), youtube is level 0
    IPNSLINK=$(ipfs key list -l | grep ${mediakey} | cut -d ' ' -f 1)
    [[ "${IPNSLINK}" == "" ]] && continue ## prevent empty IPNSLINK
    echo "We are refreshing http://127.0.0.1:8080/ipns/${IPNSLINK}"
    count=$((count+1)) && echo "$count) "
    FILE_NAME=$(cat ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/${G1PUB}/.ipfs.filename)
    TITLE=$(cat ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/${G1PUB}/.title)

    ## REFRESH MORE THAN 6 HOURS TIMESTAMP KEY
    TIMESTAMP=$(cat ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/${G1PUB}/.timestamp) # INITIAL TIMESTAMP
    [[ -f ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/.timestamp ]] && TIMESTAMP=$(cat ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/.timestamp) # LAST REFRESH
    timestamp=$(date -u +%s%N | cut -b1-13)
    STAMPDIFF=$((timestamp - TIMESTAMP))
    echo "Last Update : $(date -d @$TIMESTAMP | cut -b1-10)" # remove millisecond part
    echo "${mediakey} LAST UPDATED $STAMPDIFF milliseconds AGO"
    [ $STAMPDIFF -lt 21600000 ] && continue     # 6h = 21600000 ms , 10h = 36000000 ms

    source=$(echo $mediakey | cut -d '_' -f 1)

    ANNONCE=$(cat ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/${G1PUB}/.gchange.ad 2>/dev/null)

    ## Use natools to decrypt  "/tmp/${mediakey}_filelink.txt
    [[ -f ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/${G1PUB}/.ipfs.filelink.natools.encrypt ]] && $MY_PATH/tools/natools.py decrypt -f pubsec -k "$HOME/.zen/secret.dunikey" -i "$HOME/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/${G1PUB}/.ipfs.filelink.natools.encrypt" -o "/tmp/${mediakey}_filelink.txt"
    URLENCODE_FILE_NAME=$(cat /tmp/${mediakey}_filelink.txt | rev | cut -d '/' -f 1 | rev | jq -Rr @uri)
    IPFSREPFILEID=$(cat /tmp/${mediakey}_filelink.txt | rev | cut -d '/' -f 2- | rev | cut -d '/' -f 3)

    echo "IPFS MEDIA link :  /ipfs/$IPFSREPFILEID/$URLENCODE_FILE_NAME"

    ## TREAT OLD DATA from new_file_in_astroport.sh (LATER can be removed)
    if [[ ! -f $HOME/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/content.json && -f ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/${G1PUB}/video.json ]]; then
        mediakeyfile=$($MY_PATH/tools/give_me_keystore_filename.py $mediakey)
        $MY_PATH/tools/natools.py privkey -f ipfs-keystore -k $HOME/.ipfs/keystore/$mediakeyfile -F pubsec -o /tmp/${mediakey}.dunikey
        # PubFromDunikey=$(cat /tmp/${mediakey}.dunikey | grep "sec" | cut -d ' ' -f2 | base58 -d | tail -c+33 | base58)
        PubFromDunikey=$(cat /tmp/${mediakey}.dunikey | grep "pub" | cut -d ' ' -f2)
        echo "$PubFromDunikey" > $HOME/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/MEDIAPUBKEY
    fi

    MEDIAPUBKEY=$(cat $HOME/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/MEDIAPUBKEY)
    echo "MEDIA G1 WALLET = $MEDIAPUBKEY"
    BALANCE=$(~/.zen/astrXbian/zen/jaklis/jaklis.py balance -p ${MEDIAPUBKEY}) && [[ $BALANCE == null || "$BALANCE" == "" ]] && BALANCE=0
    ZENBALANCE=$(echo "100 * $BALANCE" | bc -l | cut -d '.' -f 1)

    TUBELINK="https://tube.copylaradio.com$(cat /tmp/${mediakey}_filelink.txt)"
    LOCALTUBELINK="http://127.0.0.1:8080$(cat /tmp/${mediakey}_filelink.txt)"

    ### IPNS LINK CAN EVOLVE (REFRESH EVERY 12 H TO MAINTAIN ALIVE IN THE SWARM)
    ### This index.html is ipns link root, 1st welcome page for MEDIAKEY -> *** Redirect to CONTRACTS or LOGIN processing HERE ***

    echo "=======> Mediakey Welcome index.html
    IPNSLINK=$IPNSLINK
    IPFSNODEID=$IPFSNODEID
    XZUID=$XZUID
    G1PUB=$G1PUB
    TITLE=$TITLE"
    cat /home/$YOU/.zen/astrXbian/www/boris/youtube_watch_step2.html \
        | sed "s/\${IPNSLINK}/$IPNSLINK/g" \
        | sed "s/\${IPFSNODEID}/$IPFSNODEID/g" \
        | sed "s/\${XZUID}/$XZUID/g" \
        | sed "s/\${G1PUB}/$G1PUB/g" \
        | sed "s/\${TITLE}/$TITLE/g" \
        > /tmp/${mediakey}_index.html
        mv  /tmp/${mediakey}_index.html ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/index.html

    [ ! -s ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/index.html ] && echo "Problem creating ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/index.html. EXIT" && exit 1

########################################################################
### Scenario are G1PUB subdivized. Thus each friend can establish own contract
# ~/.zen/ipfs/.${IPFSNODEID}/KEY/${INDEXPREFIX}${REFERENCE}/${G1PUB}/index.html
########################################################################

    ## Write KEY id (provide verification)
    [[ ! -f ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/${G1PUB}/.id ]] && echo ${mediakey} > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/${G1PUB}/.id

## THIS MAKES FRENCH COPY RIGHT LAW RESPECT
## LOCALHOST REDIRECT FOR INTERNAL KODI DEFCON 3 (swarm.key) ASTROPORT STATION MODE
    # echo "<meta charset=\"UTF-8\"><meta http-equiv=\"Refresh\" content=\"0;URL=http://127.0.0.1:8080$(cat /tmp/${mediakey}_filelink.txt)\">" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/${G1PUB}/index.html
    # echo "<meta charset=\"UTF-8\"><meta http-equiv=\"Refresh\" content=\"0;URL=https://tube.copylaradio.com$(cat /tmp/${mediakey}_filelink.txt)\">" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/${G1PUB}/index.html

## DEMO PERIOD
## NICE FINAL STREAMING PAGE # TODO ACTIVATE DOWNLOAD FOR AVI or MKV
    FILETYPE="${LOCALTUBELINK##*.}"
    MIMETYPE="video/$FILETYPE" && HTMLTAG="video"
    [[ "$FILETYPE" == "avi" ]] && MIMETYPE="video/x-msvideo"
    [[ "$FILETYPE" == "mkv" ]] && MIMETYPE="video/x-matroska"
    [[ "$FILETYPE" == "mp3" ]] && MIMETYPE="audio/mpeg" && HTMLTAG="audio"

    echo "=======> Mediakey Contract index.html "
    cat /home/$YOU/.zen/astrXbian/www/boris/youtube_watch_step3.html \
    | sed "s/\${TITLE}/$TITLE/g" \
    | sed "s/\${IPFSNODEID}/$IPFSNODEID/g" \
    | sed "s/\${XZUID}/$XZUID/g" \
    | sed "s/\${IPFSREPFILEID}/$IPFSREPFILEID/g" \
    | sed "s/\${URLENCODE_FILE_NAME}/$URLENCODE_FILE_NAME/g" \
    > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/${G1PUB}/index.html


    if [[ "$source" == "YOUTUBE" ]]
    then
        echo "$source"
        # mutiTUBE - activate .views.counter
        # echo "<meta http-equiv=\"Refresh\" content=\"0;URL=https://tube.copylaradio.com/ipns/$IPNSLINK/${G1PUB}/go\">" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/${G1PUB}/index.html
        # TODO go/index.php from nginx proxy acting act as gateway (= Easy Round robin DNS tube.copylaradio.com is dynamic IP swap swarm nodes from node performance...)
    fi
    # ln -s /$HOME/.zen/astrXbian/www /var/www/astrxbian
    # Testez vos application à même la blockchain en la copiant dans ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/${G1PUB}/go/
    # Proposez de l'ajouter au dépot des applications web2.0 dans ../www/

########################################################################
    # EXAMPLE TO ACTIVATE SECURITY : FORCE SIGNATURE VERIFICATION for each sensible file
########################################################################
    echo "~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/${G1PUB}/.views.counter"
    if [[ ! -f ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/${G1PUB}/.views.counter.sign ]]; then
        echo "0" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/${G1PUB}/.views.counter
        $MY_PATH/tools/natools.py sign -f pubsec -k "$HOME/.zen/secret.dunikey" -i ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/${G1PUB}/.views.counter -o ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/${G1PUB}/.views.counter.sign
    fi

    $MY_PATH/tools/natools.py verify -p "${G1PUB}" -i "$HOME/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/${G1PUB}/.views.counter.sign" -o "/tmp/verified_msg" && echo "c'est bon" || echo "c'est pas bon"
    # Each time a station modify .views.counter it signs, log and timestamp then publish new IPNS to swarm.
    # If a "faulty" blockchain appears (Mediakey collision)...
    # Message are sent to warn friends they have to manualy validate data conflict and merge back their mutual chain.

########################################################################
## CHAIN & IPNS REFRESH
########################################################################
    # ipfs nanochain progression
    I=$(ipfs add -qrH ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/ | tail -n 1)
    echo "CHAIN: $I"
    OLDCHAIN=$(cat ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/.chain)
    echo "OLDCHAIN: $OLDCHAIN"
    if [[ "$OLDCHAIN" != "$I" ]] # MODIFY CHAIN only if something was changed
    then
        echo "UPDATING CHAIN"
        echo "$(date -u +%s%N | cut -b1-13)" > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/.timestamp
        echo $I > ~/.zen/ipfs/.${IPFSNODEID}/KEY/${mediakey}/.chain
    fi
    echo "${mediakey} NAME PUBLISHING "
    # KEY ZenTag IPNS name publish
    J=$(ipfs name publish --quieter -k ${mediakey} /ipfs/${I})

    echo "$id REFRESHED ${I}
    https://tube.copylaradio.com/ipns/$J
    http://127.0.0.1:8080/ipns/$J"
########################################################################
########################################################################
    break ## ONE BY ONE (cron_MINUTE.sh task every 7 mn)
done

########################################################################
########################################################################
## TAKE CARE OF PIN CREATED THROUGH autoPINfriends.sh
## Then refresh MEDIAKEY IPNS/IPFS RELATION
## CORRECT ISSUE : https://git.p2p.legal/axiom-team/astrXbian/issues/25
########################################################################
for ipnslink in $(ls ~/.zen/PIN/*/IPNSLINK  2>/dev/null | shuf ); do
    ipnsid=$(cat $ipnslink)
    ipfsid=$(echo $ipnslink | cut -d '/' -f 6)
    mediakey=$(cat ~/.zen/PIN/${ipfsid}/MEDIAKEY)

#    [[ ! $(echo "${mediakey}" | grep "TMDB_") ]] && continue ## REFRESH ONLY TMDB (level 1), youtube is level 0

    [[ ! $(ipfs key list | grep ${mediakey}) ]] && echo "ERROR MISSING MEDIAKEY" && continue

    ## GET ACTUAL IPNS .chain VALUE
    mkdir -p /tmp/${mediakey}
    echo "${mediakey} GET IPNS"
    ipfs get -o /tmp/${mediakey} /ipns/$ipnsid
    [ $? -ne 0 ] && continue
    [ ! -s /tmp/${mediakey}/index.html ] && continue ## DO NOT REPUBLISH empty index.html

    ## REFRESH MORE THAN 6 HOURS TIMESTAMP KEY
    TIMESTAMP=$(cat /tmp/${mediakey}/.timestamp  2>/dev/null) # LAST REFRESH
    [[ ! $TIMESTAMP ]] && TIMESTAMP=$(cat /tmp/${mediakey}/*/.timestamp 2>/dev/null | tail -n 1 ) # INITIAL TIMESTAMP
    timestamp=$(date -u +%s%N | cut -b1-13)
    STAMPDIFF=$((timestamp - TIMESTAMP))
    echo "Last Update : $(date -d @$TIMESTAMP  | cut -b1-10)" # remove millisecond part
    echo "PIN WAS LAST UPDATED $STAMPDIFF milliseconds AGO"
    [ $STAMPDIFF -lt 39600000 ] && continue     #  11h = 39600000 ms / 12h = 43200000 ms

    echo "Refresh MEDIAKEY PIN"
    NEWIPFS=$(ipfs add -rHq /tmp/${mediakey}/ | tail -n 1)

    ## PUBLISH IT
    ipfs name publish -k ${mediakey} --quieter /ipfs/$NEWIPFS

    echo "$id PIN PUBLISH REFRESHED /ipfs/$NEWIPFS
    https://tube.copylaradio.com/ipns/$ipnsid
    http://127.0.0.1:8080/ipns/$ipnsid"

    rm -Rf /tmp/${mediakey}

    break ## DO ONE BY ONE
done

########################################################################
