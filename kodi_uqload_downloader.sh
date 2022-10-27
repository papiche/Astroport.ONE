#!/bin/bash
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
######## YOUTUBE-DL ##########
## NOW INSTALL yt-dlp AND LINK TO youtube-dl
# _             _ _
#| | _____   __| (_)
#| |/ / _ \ / _` | |
#|   < (_) | (_| | |
#|_|\_\___/ \__,_|_|
#                    COPY UQLOAD LINKS DETECTED IN KODI LOG
##############################################
### TODO INSTALL FROM START and AUTO SCRAPE KODI LOG
##############################################
    if [[ ! -f $HOME/.local/bin/uqload_downloader ]]; then
        cd /tmp
        git clone https://github.com/papiche/uqload_downloader.git
        cd uqload_downloader/cli
        ./download_from_kodi_log.sh
        [[ -f $HOME/.local/bin/uqload_downloader ]] && zenity --warning --width ${large} --text "INSTALLATION download_from_kodi_log.sh OK"
        cp download_from_kodi_log.sh $HOME/.local/bin/
    else
        ## UTILISEZ $HOME/.local/bin/download_from_kodi_log.sh
        zenity --warning --width ${large} --text "UTILISEZ download_from_kodi_log.sh en ligne de commande..."
        exit 0
    fi
