#!/bin/bash
########################################################################
# Author: papiche
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.${MOATS}/)
########################################################################
# download_from_kodi_log.sh
########################################################################
echo "Extract uqload links from ~/.kodi/temp/kodi.${OLD}log"
# Detects uqload links and ask for copying it to $HOME/astroport
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
SCRIPT="${0##*/}"

isKodiRunning=$(ps auxf --sort=+utime | grep -w 'kodi-x11' | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1)

if [[ ! $isKodiRunning ]]; then
    echo "Kodi is not running"
fi


# script usage
usage()
{
# if argument passed to function echo it
[ -z "${1}" ] || echo "! ${1}"
# display help
echo "\
# extract played uqload links from kodi log file
$(basename "$0") : current log scraping
$(basename "$0") old scraping"
exit 2
}

IPFSNODEID=$(ipfs --timeout 5s id -f='<id>\n')
[[ ! $IPFSNODEID ]] && IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)
[[ $IPFSNODEID == "" ]] && echo "IPFS APPLICATION. P.LEASE " && exit 1

mkdir -p ~/.zen/tmp/${IPFSNODEID}/uqdl/

## CHOOSE kodi.${OLD}log
[[ $1 == "old" ]] && OLD='old.' || OLD=''

[[ ! $(which kodi) ]] && echo "KODI IS MISSING." && exit 1

    function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

## LOOP
cycle=1
for uqlink in $(cat ~/.kodi/temp/kodi.${OLD}log | grep uqload | grep 'play :' | rev | cut -d '/' -f 1 | rev);
do
    proname=$(cat ~/.kodi/temp/kodi.${OLD}log | grep uqload | grep $uqlink | grep VideoPlayer | cut -d '=' -f 4 | cut -d '&' -f 1)
    uqname=$(urldecode $proname | detox --inline)

    [[ ! $uqname ]] && echo "$uqlink is BAD" && continue
    cycle=$((cycle+1))

    echo "########################################################################"
    echo "MANUAL : uqload_downloader https://uqload.com/$uqlink \"$HOME/Astroport/film/${MOATS}/$uqname.mp4\""

    ! cat ~/.zen/tmp/${IPFSNODEID}/uqdl/commands.fifo | grep -w "$uqname.mp4" && \
    echo "uqload_downloader https://uqload.com/$uqlink \"$HOME/Astroport/$uqname.mp4\"" >> ~/.zen/tmp/${IPFSNODEID}/uqdl/commands.fifo || \
    echo "$uqname.mp4 detected in ~/.zen/tmp/${IPFSNODEID}/uqdl/commands.fifo"

    ## CHECK & MANAGE COPY
    if [[ $(find $HOME/Astroport -name "$uqname.mp4" -type f -print) ]];
    then
        echo "FILE ALREADY IN $HOME/Astroport/"
        continue
    else
        MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
        mkdir -p $HOME/Astroport/film/${MOATS}
            echo "DETECTED MOVIE : $uqname (https://uqload.com/$uqlink)"
            uqload_downloader https://uqload.com/$uqlink "$HOME/Astroport/film/${MOATS}/$uqname.mp4"
            echo "COPY ~/Astroport/film/${MOATS}/$uqname.mp4 DONE"
            #~ ## RUNNING ON ASTROPORT STATION?
            #~ (
                #~ [[ $(which ipfs) && $IPFSNODEID ]] \
                #~ && espeak "Download $uqname done. Adding file to I P F S" \
                #~ && ~/.zen/Astroport.ONE/tools/new_file_in_astroport.sh "$HOME/Astroport/film/${MOATS}/" "$uqname.mp4"
                #~ && CID=$(ipfs add -q ~/Astroport/$uqname.mp4 | tail -n 1) \
                #~ && mkdir -p ~/.zen/tmp/$IPFSNODEID/$PLAYER/Astroport/ \
                #~ && echo "/ipfs/$CID" > ~/.zen/tmp/$IPFSNODEID/Astroport/$uqname.mp4.ipfs \
                #~ && espeak "Added to Station 12345 mapping"
            #~ ) &
    fi
done
echo
echo "########################################################################"
[[ $cycle == 1 && ! ${OLD} ]] && echo "NOTHING IN CURRENT LOG, TRY old ?" && read OLD && [[ "$OLD" != "" ]] && $MY_PATH/$SCRIPT old
echo "DONE... VideoClub Datacenter Virtuel entre amis."
echo "ASTROPORT. Le web des gens."
exit 0
