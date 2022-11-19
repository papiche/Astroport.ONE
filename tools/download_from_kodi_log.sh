#!/bin/bash
########################################################################
# Author: papiche
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# download_from_kodi_log.sh
########################################################################
echo "Extract uqload links from ~/.kodi/temp/kodi.${OLD}log"
# Detects uqload links and ask for copying it to $HOME/astroport
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
SCRIPT="${0##*/}"

# script usage
usage()
{
# if argument passed to function echo it
[ -z "${1}" ] || echo "! ${1}"
# display help
echo "\
# extract uplad links from kodi log file
$(basename "$0") : current log scraping
$(basename "$0") old scraping"
exit 2
}


## CHOOSE kodi.${OLD}log
[[ $1 == "old" ]] && OLD='old.' || OLD=''

[[ ! $(which kodi) ]] && echo "KODI IS MISSING. VISIT https://copylaradio.com" && exit 1

## LOOP
cycle=1
for uqlink in $(cat ~/.kodi/temp/kodi.${OLD}log | grep uqload | grep 'play :' | rev | cut -d '/' -f 1 | rev);
do
    uqname=$(cat ~/.kodi/temp/kodi.${OLD}log | grep uqload | grep $uqlink | grep VideoPlayer | cut -d '=' -f 4 | cut -d '&' -f 1 | cut -d '%' -f 1 | sed 's/\+/_/g' | tail -n 1)
    cycle=$((cycle+1))
    echo "########################################################################"
    echo "MANUAL : uqload_downloader https://uqload.com/$uqlink \"$HOME/astroport/$uqname.mp4\""

    ## ADD TO ASTROPORT
    # IPFSNODEID=$(ipfs id -f='<id>\n')
    IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)
    NODEG1PUB=$(${MY_PATH}/ipfs_to_g1.py ${IPFSNODEID})
    mkdir -p ~/.zen/tmp/${IPFSNODEID}/uqload_downloader/

    ## CREATE APPNAME IPNS KEY (CREATE ONE BY FRIENDS SHARING COPY TASK) HACKING_QUEST TODO Make a better key generation
    [[ ! -f ~/.zen/tmp/${IPFSNODEID}/uqload_downloader/keygen.ipns.key.enc.b16 ]] \
    && ${MY_PATH}/keygen -t ipfs -o ~/.zen/tmp/publish.key "$uqlink" "$IPFSNODEID" \
    && ${MY_PATH}/natools.py encrypt -p ${NODEG1PUB} -i ~/.zen/tmp/publish.key -o ~/.zen/tmp/${IPFSNODEID}/uqload_downloader/keygen.ipns.key.enc \
    && cat ~/.zen/tmp/${IPFSNODEID}/uqload_downloader/keygen.ipns.key.enc | base16 > ~/.zen/tmp/${IPFSNODEID}/uqload_downloader/keygen.ipns.key.enc.b16

    [[ ! $(cat ~/.zen/tmp/${IPFSNODEID}/uqload_downloader/commands.fifo | grep -w "$uqname.mp4") ]] && \
    echo "uqload_downloader https://uqload.com/$uqlink \"$HOME/astroport/$uqname.mp4\"" >> ~/.zen/tmp/${IPFSNODEID}/uqload_downloader/commands.fifo || \
    echo "$uqname.mp4 conflict"

    ## CHECK & MANAGE COPY
    if [[ $(find $HOME/astroport -name "$uqname*" -type f -print) ]];
    then
        echo "COPY ALREADY IN $HOME/astroport/"
    else
        echo "DETECTED MOVIE : $uqname (https://uqload.com/$uqlink)"
        echo "WANT TO COPY ? Yes? Write any character + enter, else just hit enter."
        read YESNO
        if [[ "$YESNO" != "" ]]; then
            ## COPY STREAMING
            uqload_downloader https://uqload.com/$uqlink "$HOME/astroport/$uqname.mp4"
            echo "COPY ~/astroport/$uqname.mp4 DONE"
            ## ARE WE ASTROPORT STATION? https://astroport.com
            [[ "$USER" != "xbian" && ${IPFSNODEID} ]] && ~/.zen/astrXbian/ajouter_video.sh
        else
            continue
        fi
    fi
done
echo
echo "########################################################################"
[[ $cycle == 1 && ! ${OLD} ]] && echo "NOTHING IN CURRENT LOG, TRY old ?" && read OLD && [[ "$OLD" != "" ]] && $MY_PATH/$SCRIPT old
echo "DONE... VideoClub Datacenter Virtuel entre amis. https://copylaradio.com"
echo "ASTROPORT. Le web des gens."
exit 0
